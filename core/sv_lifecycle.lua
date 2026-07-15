Convergence.Lifecycle = Convergence.Lifecycle or {}

local Lifecycle = Convergence.Lifecycle

Lifecycle.Ready = false
Lifecycle.StartedAt = Lifecycle.StartedAt or SysTime()
Lifecycle.LastValidation = Lifecycle.LastValidation or {}

Lifecycle.CoreServices = {
    {
        id = "planets",
        name = "Planet Service",
        object = function()
            return Convergence.PlanetService
        end,
        ready = function(service)
            return service
                and service.IsReady
                and service.IsReady()
        end
    },
    {
        id = "factions",
        name = "Faction Registry",
        object = function()
            return Convergence.Factions
        end,
        ready = function(service)
            return service
                and service.Count
                and service.Count() > 0
        end
    },
    {
        id = "influence",
        name = "Influence Service",
        object = function()
            return Convergence.Influence
        end,
        ready = function(service)
            return service ~= nil
                and isfunction(service.Get)
                and isfunction(service.Add)
        end
    },
    {
        id = "stability",
        name = "Stability Service",
        object = function()
            return Convergence.Stability
        end,
        ready = function(service)
            return service ~= nil
                and isfunction(service.Get)
                and isfunction(service.Add)
        end
    },
    {
        id = "fleets",
        name = "Fleet Service",
        object = function()
            return Convergence.Fleets
        end,
        ready = function(service)
            return service
                and service.IsReady
                and service.IsReady()
        end
    },
    {
        id = "fleet_orders",
        name = "Fleet Order Service",
        object = function()
            return Convergence.FleetOrders
        end,
        ready = function(service)
            return service ~= nil
        end
    },
    {
        id = "simulation",
        name = "Simulation Engine",
        object = function()
            return Convergence.Simulation
        end,
        ready = function(service)
            return service
                and service.IsReady
                and service.IsReady()
        end
    },
    {
        id = "clock",
        name = "Galaxy Clock",
        object = function()
            return Convergence.Clock
        end,
        ready = function(service)
            return service
                and service.IsReady
                and service.IsReady()
        end
    },
    {
        id = "alliances",
        name = "Alliance Registry",
        object = function()
            return Convergence.Alliances
        end,
        ready = function(service)
            return service ~= nil
                and isfunction(service.GetAll)
        end
    }
}

local function registerDefinition(definition)
    local service = definition.object()

    if not istable(service) then
        return false, "Service object is unavailable."
    end

    local success, resultOrMessage =
        Convergence.Services.Register(definition.id, service)

    if not success then
        return false, resultOrMessage
    end

    return true, service
end

function Lifecycle.RegisterCoreServices()
    local failures = {}

    for _, definition in ipairs(Lifecycle.CoreServices) do
        local success, message = registerDefinition(definition)

        if not success then
            failures[#failures + 1] = string.format(
                "%s: %s",
                definition.name,
                tostring(message)
            )
        end
    end

    if #failures > 0 then
        return false,
            Convergence.Constants.ERROR.INVALID_ARGUMENT,
            table.concat(failures, "; ")
    end

    return true
end

function Lifecycle.Validate()
    local validation = {}
    local allReady = true

    for _, definition in ipairs(Lifecycle.CoreServices) do
        local service = Convergence.Services.Get(definition.id)
        local registered = service ~= nil
        local ready = registered and definition.ready(service) == true

        validation[definition.id] = {
            id = definition.id,
            name = definition.name,
            registered = registered,
            ready = ready
        }

        if not ready then
            allReady = false
        end
    end

    Lifecycle.LastValidation = validation
    return allReady, validation
end

function Lifecycle.Bootstrap()
    local registered, registerCode, registerMessage =
        Lifecycle.RegisterCoreServices()

    if not registered then
        return false, registerCode, registerMessage
    end

    local valid, validation = Lifecycle.Validate()

    if not valid then
        local missing = {}

        for id, state in pairs(validation) do
            if not state.ready then
                missing[#missing + 1] = id
            end
        end

        table.sort(missing)

        return false,
            Convergence.Constants.ERROR.INVALID_ARGUMENT,
            "Services not ready: " .. table.concat(missing, ", ")
    end

    Lifecycle.Ready = true

    Convergence.Services.Register("lifecycle", Lifecycle)

    Convergence.Events.Publish("core.services.ready", {
        services = table.Copy(validation),
        startupSeconds = SysTime() - Lifecycle.StartedAt
    }, {
        source = "lifecycle",
        reason = "Core service lifecycle completed."
    })

    hook.Run(
        "ConvergenceServicesReady",
        table.Copy(validation)
    )

    Convergence.Log.Info(
        "Lifecycle",
        "Core services registered and validated.",
        {
            count = table.Count(validation),
            startupSeconds = SysTime() - Lifecycle.StartedAt
        }
    )

    return true, validation
end

function Lifecycle.IsReady()
    return Lifecycle.Ready == true
end

function Lifecycle.GetStatus()
    return table.Copy(Lifecycle.LastValidation)
end

function Lifecycle.Repair()
    local registered, code, message =
        Lifecycle.RegisterCoreServices()

    if not registered then
        return false, code, message
    end

    local valid, validation = Lifecycle.Validate()
    Lifecycle.Ready = valid

    return valid, validation
end
