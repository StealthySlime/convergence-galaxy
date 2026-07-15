Convergence.Modules = Convergence.Modules or {}

local Modules = Convergence.Modules

Modules.Registry = Modules.Registry or {}
Modules.Order = Modules.Order or {}
Modules.Initialized = Modules.Initialized or {}

local function validateDefinition(definition)
    if not istable(definition) then
        return false, "Module definition must be a table."
    end

    local id = Convergence.NormalizeID(definition.id)

    if id == "" then
        return false, "Module definition requires a valid ID."
    end

    if Modules.Registry[id] then
        return false, "Module already registered: " .. id
    end

    if definition.initialize ~= nil and not isfunction(definition.initialize) then
        return false, "Module initialize field must be a function."
    end

    if definition.shutdown ~= nil and not isfunction(definition.shutdown) then
        return false, "Module shutdown field must be a function."
    end

    return true, id
end

function Convergence.RegisterModule(definition)
    local valid, result = validateDefinition(definition)

    if not valid then
        Convergence.Log.Error("Modules", result)
        return false, Convergence.Constants.ERROR.INVALID_ARGUMENT, result
    end

    local id = result

    definition.id = id
    definition.name = tostring(definition.name or id)
    definition.version = tostring(definition.version or "0.0.0")
    definition.dependencies = definition.dependencies or {}
    definition.optionalDependencies = definition.optionalDependencies or {}
    definition.enabled = definition.enabled ~= false

    Modules.Registry[id] = definition
    Modules.Order[#Modules.Order + 1] = id

    Convergence.Log.Debug("Modules", "Registered module.", {
        id = id,
        version = definition.version
    })

    return true, definition
end

function Modules.Get(id)
    return Modules.Registry[Convergence.NormalizeID(id)]
end

function Modules.IsInitialized(id)
    return Modules.Initialized[Convergence.NormalizeID(id)] == true
end

local function dependenciesReady(definition)
    for _, dependencyID in ipairs(definition.dependencies) do
        dependencyID = Convergence.NormalizeID(dependencyID)

        if not Modules.Registry[dependencyID] then
            return false, "Required module is not registered: " .. dependencyID
        end

        if not Modules.Initialized[dependencyID] then
            return false, "Required module is not initialized: " .. dependencyID
        end
    end

    return true
end

function Modules.Initialize(id)
    id = Convergence.NormalizeID(id)

    local definition = Modules.Registry[id]

    if not definition then
        return false, Convergence.Constants.ERROR.INVALID_ARGUMENT,
            "Unknown module: " .. id
    end

    if Modules.Initialized[id] then
        return true, definition
    end

    if not definition.enabled then
        Convergence.Log.Info("Modules", "Module disabled by configuration.", {id = id})
        return true, definition
    end

    local ready, dependencyError = dependenciesReady(definition)

    if not ready then
        Convergence.Log.Error("Modules", dependencyError, {id = id})

        return false,
            Convergence.Constants.ERROR.MODULE_DEPENDENCY_MISSING,
            dependencyError
    end

    if definition.initialize then
        local ok, result = xpcall(function()
            return definition:initialize()
        end, debug.traceback)

        if not ok then
            Convergence.Log.Error("Modules", "Module initialization failed.", {
                id = id,
                error = result
            })

            return false,
                Convergence.Constants.ERROR.MODULE_INITIALIZATION_FAILED,
                result
        end
    end

    Modules.Initialized[id] = true
    hook.Run("ConvergenceModuleInitialized", id, definition)

    Convergence.Log.Info("Modules", "Initialized module.", {
        id = id,
        version = definition.version
    })

    return true, definition
end

function Modules.InitializeAll()
    for _, id in ipairs(Modules.Order) do
        Modules.Initialize(id)
    end
end

function Modules.ShutdownAll()
    for index = #Modules.Order, 1, -1 do
        local id = Modules.Order[index]
        local definition = Modules.Registry[id]

        if Modules.Initialized[id] and definition and definition.shutdown then
            local ok, err = xpcall(function()
                definition:shutdown()
            end, debug.traceback)

            if not ok then
                Convergence.Log.Error("Modules", "Module shutdown failed.", {
                    id = id,
                    error = err
                })
            end
        end

        Modules.Initialized[id] = nil
    end
end

hook.Add("ShutDown", "Convergence.Modules.Shutdown", function()
    Modules.ShutdownAll()
end)
