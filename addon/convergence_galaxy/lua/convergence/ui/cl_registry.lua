Convergence.UI = Convergence.UI or {}

local UI = Convergence.UI

UI.Modules = UI.Modules or {}
UI.ModuleOrder = UI.ModuleOrder or {}

function UI.RegisterModule(definition)
    if not istable(definition) then
        return false, "Module definition must be a table."
    end

    local id = Convergence.NormalizeID(definition.id)

    if id == "" then
        return false, "Module requires a valid ID."
    end

    if not isfunction(definition.create) then
        return false, "Module requires a create function."
    end

    definition.id = id
    definition.name = tostring(definition.name or id)
    definition.order = tonumber(definition.order) or 100
    definition.icon = tostring(definition.icon or "")
    definition.adminOnly = definition.adminOnly == true
    definition.directorOnly = definition.directorOnly == true

    -- Allow safe client reloads without producing duplicate-registration errors.
    UI.Modules[id] = definition

    local existsInOrder = false

    for _, existingID in ipairs(UI.ModuleOrder) do
        if existingID == id then
            existsInOrder = true
            break
        end
    end

    if not existsInOrder then
        UI.ModuleOrder[#UI.ModuleOrder + 1] = id
    end

    table.sort(UI.ModuleOrder, function(leftID, rightID)
        local left = UI.Modules[leftID]
        local right = UI.Modules[rightID]

        if not left then return false end
        if not right then return true end

        if left.order == right.order then
            return left.name < right.name
        end

        return left.order < right.order
    end)

    return true, definition
end

function UI.GetModule(id)
    return UI.Modules[Convergence.NormalizeID(id)]
end

function UI.GetModulesForPlayer(ply, mode)
    mode = Convergence.NormalizeID(mode or UI.Mode or "player")

    local result = {}

    for _, id in ipairs(UI.ModuleOrder) do
        local module = UI.Modules[id]

        if module then
            local allowed = true

            if module.adminOnly
                and not (IsValid(ply) and ply:IsAdmin()) then
                allowed = false
            end

            if module.directorOnly and mode ~= "director" then
                allowed = false
            end

            if allowed then
                result[#result + 1] = module
            end
        end
    end

    return result
end

function UI.ValidateRegistry()
    local errors = {}

    if not isfunction(UI.RegisterModule) then
        errors[#errors + 1] = "RegisterModule is missing."
    end

    if not isfunction(UI.GetModule) then
        errors[#errors + 1] = "GetModule is missing."
    end

    if not isfunction(UI.GetModulesForPlayer) then
        errors[#errors + 1] = "GetModulesForPlayer is missing."
    end

    for _, id in ipairs(UI.ModuleOrder) do
        if not UI.Modules[id] then
            errors[#errors + 1] = "Module order references missing module: " .. id
        end
    end

    return #errors == 0, errors
end
