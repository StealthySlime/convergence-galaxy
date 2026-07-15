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

    if UI.Modules[id] then
        return false, "Module is already registered: " .. id
    end

    if not isfunction(definition.create) then
        return false, "Module requires a create function."
    end

    definition.id = id
    definition.name = tostring(definition.name or id)
    definition.order = tonumber(definition.order) or 100
    definition.icon = tostring(definition.icon or "")
    definition.adminOnly = definition.adminOnly == true

    UI.Modules[id] = definition
    UI.ModuleOrder[#UI.ModuleOrder + 1] = id

    table.sort(UI.ModuleOrder, function(leftID, rightID)
        local left = UI.Modules[leftID]
        local right = UI.Modules[rightID]

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

function UI.GetModulesForPlayer(ply)
    local result = {}

    for _, id in ipairs(UI.ModuleOrder) do
        local module = UI.Modules[id]

        if not module.adminOnly or (IsValid(ply) and ply:IsAdmin()) then
            result[#result + 1] = module
        end
    end

    return result
end
