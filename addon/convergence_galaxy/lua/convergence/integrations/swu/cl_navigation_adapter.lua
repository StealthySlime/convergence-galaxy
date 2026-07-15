Convergence.SWUNavigationClient = Convergence.SWUNavigationClient or {}

local Client = Convergence.SWUNavigationClient

local function upsert(list, name, position)
    if not istable(list) then
        return false
    end

    local normalized = Convergence.NormalizeID(name)

    for _, entry in ipairs(list) do
        if istable(entry)
            and Convergence.NormalizeID(
                entry.name or entry.Name or entry.id or entry.ID
            ) == normalized then
            entry.name = name
            entry.Name = name
            entry.id = normalized
            entry.pos = Vector(position.x, position.y, position.z)
            entry.position = Vector(position.x, position.y, position.z)
            entry.Position = Vector(position.x, position.y, position.z)
            return true
        end
    end

    list[#list + 1] = {
        name = name,
        Name = name,
        id = normalized,
        ID = normalized,
        pos = Vector(position.x, position.y, position.z),
        position = Vector(position.x, position.y, position.z),
        Position = Vector(position.x, position.y, position.z)
    }

    return true
end

function Client.SyncPlanetLists()
    if not SWU then
        return 0
    end

    local lists = {
        SWU.Planets,
        SWU.AllPlanets,
        SWU.PlanetList,
        SWU.Config and SWU.Config.Planets,
        SWU.Configuration and SWU.Configuration.Planets,
        SWU.Configuration and SWU.Configuration.ShipPositions,
        SWU.Controller and SWU.Controller.Planets,
        SWU.NavigationComputer and SWU.NavigationComputer.Planets,
        SWU.NavigationComputer and SWU.NavigationComputer.allPlanets
    }

    local writes = 0

    for _, definition in ipairs(Convergence.Config.Planets or {}) do
        local planetID = Convergence.NormalizeID(definition.id)
        local mapping = (Convergence.SWUPlanetMapping or {})[planetID]

        if mapping and isvector(mapping.position) then
            for _, list in ipairs(lists) do
                if upsert(
                    list,
                    mapping.navigationName or definition.name or planetID,
                    mapping.position
                ) then
                    writes = writes + 1
                end
            end
        end
    end

    return writes
end

hook.Add("InitPostEntity", "Convergence.SWU.ClientPlanetSync", function()
    timer.Create("Convergence.SWU.ClientPlanetSyncRetry", 1, 10, function()
        if SWU then
            Client.SyncPlanetLists()
        end
    end)
end)

hook.Add("OnScreenSizeChanged", "Convergence.SWU.ClientPlanetRefresh", function()
    timer.Simple(0, Client.SyncPlanetLists)
end)

concommand.Add("convergence_swu_client_sync", function()
    local writes = Client.SyncPlanetLists()

    print(
        "[Convergence] Client SWU planet-list writes: "
        .. tostring(writes)
    )
end)
