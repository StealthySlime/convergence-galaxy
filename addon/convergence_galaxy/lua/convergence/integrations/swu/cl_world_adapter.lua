Convergence.SWUWorldClient = Convergence.SWUWorldClient or {}

local Adapter = Convergence.SWUWorldClient
Adapter.Proxies = Adapter.Proxies or {}

local function makeProxy(id, position)
    local proxy = {
        ConvergenceProxy = true,
        ConvergencePlanetID = id,
        UniversePosition = Vector(position.x, position.y, position.z)
    }

    function proxy:GetUniversePos()
        return self.UniversePosition
    end

    function proxy:GetId()
        return self.ConvergencePlanetID
    end

    return proxy
end

local function injectMapPlanets()
    if not SWU or not istable(SWU.Map) then
        return
    end

    local data = Convergence.GalaxyData or {}
    local existing = {}

    for _, object in ipairs(SWU.Map) do
        if object.ConvergenceProxy then
            existing[object.ConvergencePlanetID] = object
        elseif object.GetId then
            local ok, id = pcall(object.GetId, object)
            if ok then
                existing[Convergence.NormalizeID(id)] = object
            end
        end
    end

    for id, planetData in pairs(data.planets or {}) do
        local swu = planetData.swu

        if swu and swu.pos and not existing[id] then
            local position = Vector(
                tonumber(swu.pos.x) or 0,
                tonumber(swu.pos.y) or 0,
                tonumber(swu.pos.z) or 0
            )

            local proxy = makeProxy(id, position)
            SWU.Map[#SWU.Map + 1] = proxy
            Adapter.Proxies[id] = proxy
        end
    end
end

hook.Add(
    "ConvergenceGalaxySnapshotUpdated",
    "Convergence.SWUWorldClient.Snapshot",
    injectMapPlanets
)

timer.Create("Convergence.SWUWorldClient.Sync", 2, 0, injectMapPlanets)
