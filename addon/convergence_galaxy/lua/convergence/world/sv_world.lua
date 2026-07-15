Convergence.World = Convergence.World or {}

local World = Convergence.World
local DB = Convergence.Database
local ERROR = Convergence.Constants.ERROR

World.Ready = false
World.State = World.State or {}

local function persist()
    local state = World.State
    local shipPos = state.swuShipPos

    return DB.Execute(string.format(
        [[
            UPDATE convergence_world_state
            SET current_planet_id = %s,
                destination_planet_id = %s,
                active_region_id = %s,
                current_map = %s,
                travel_status = %s,
                encounter_active = %d,
                swu_ship_x = %s,
                swu_ship_y = %s,
                swu_ship_z = %s,
                updated_at = %d
            WHERE id = 1
        ]],
        state.currentPlanetID and DB.Escape(state.currentPlanetID) or "NULL",
        state.destinationPlanetID and DB.Escape(state.destinationPlanetID) or "NULL",
        state.activeRegionID and DB.Escape(state.activeRegionID) or "NULL",
        DB.Escape(game.GetMap()),
        DB.Escape(state.travelStatus or "stationed"),
        state.encounterActive and 1 or 0,
        shipPos and tostring(shipPos.x) or "NULL",
        shipPos and tostring(shipPos.y) or "NULL",
        shipPos and tostring(shipPos.z) or "NULL",
        os.time()
    ))
end

function World.IsReady()
    return World.Ready == true
end

function World.Initialize()
    local success, rowOrCode, message = DB.QueryRow(
        "SELECT * FROM convergence_world_state WHERE id = 1"
    )

    if not success then
        return false, rowOrCode, message
    end

    local row = rowOrCode

    if not row then
        return false, ERROR.DATABASE_ERROR, "World state row is missing."
    end

    World.State = {
        currentPlanetID = row.current_planet_id,
        destinationPlanetID = row.destination_planet_id,
        activeRegionID = row.active_region_id,
        currentMap = game.GetMap(),
        travelStatus = row.travel_status or "stationed",
        encounterActive = tonumber(row.encounter_active) == 1,
        swuShipPos = row.swu_ship_x and Vector(
            tonumber(row.swu_ship_x) or 0,
            tonumber(row.swu_ship_y) or 0,
            tonumber(row.swu_ship_z) or 0
        ) or nil
    }

    -- Encounters never survive a map restart automatically.
    World.State.encounterActive = false
    World.State.currentMap = game.GetMap()
    World.Ready = true
    persist()

    Convergence.Events.Publish("world.ready", {
        state = World.GetPublicState()
    })

    return true
end

function World.GetState()
    return World.State
end

function World.GetPublicState()
    local state = table.Copy(World.State)
    local definition = state.currentPlanetID
        and Convergence.PlanetService.Get(state.currentPlanetID)
        or nil

    state.taskForceName =
        Convergence.Config.World.PlayerTaskForceName
        or "Player Task Force"
    state.currentPlanetName = definition and definition:GetName() or nil

    return state
end

function World.GetCurrentPlanet()
    return Convergence.PlanetService.Get(World.State.currentPlanetID)
end

function World.GetDestinationPlanet()
    return Convergence.PlanetService.Get(World.State.destinationPlanetID)
end

function World.GetRegions(planetValue)
    local planet = Convergence.PlanetService.Get(
        planetValue or World.State.currentPlanetID
    )

    if not planet then
        return {}
    end

    return table.Copy(planet:GetDefinition().regions or {})
end

function World.FindRegion(planetValue, regionValue)
    local normalized = Convergence.NormalizeID(regionValue)

    for _, region in ipairs(World.GetRegions(planetValue)) do
        if Convergence.NormalizeID(region.id) == normalized
            or Convergence.NormalizeID(region.name) == normalized then
            return region
        end
    end

    return nil
end

function World.SetShipPosition(position)
    if not isvector(position) then
        return false, ERROR.INVALID_ARGUMENT, "Ship position must be a Vector."
    end

    World.State.swuShipPos = Vector(position.x, position.y, position.z)
    persist()
    return true
end

function World.BeginHyperspace(destinationValue, position)
    local destination = Convergence.PlanetService.Get(destinationValue)

    if not destination then
        return false, ERROR.UNKNOWN_PLANET, "Unknown hyperspace destination."
    end

    World.State.destinationPlanetID = destination:GetID()
    World.State.travelStatus = "hyperspace"

    if isvector(position) then
        World.State.swuShipPos = Vector(position.x, position.y, position.z)
    end

    persist()

    Convergence.Events.Publish("world.hyperspace.started", {
        originPlanetID = World.State.currentPlanetID,
        destinationPlanetID = destination:GetID(),
        taskForceName = Convergence.Config.World.PlayerTaskForceName
    })

    return true
end

function World.Arrive(destinationValue, position)
    local destination = Convergence.PlanetService.Get(destinationValue)

    if not destination then
        return false, ERROR.UNKNOWN_PLANET, "Unknown arrival destination."
    end

    World.State.currentPlanetID = destination:GetID()
    World.State.destinationPlanetID = nil
    World.State.travelStatus = "arrived"
    World.State.activeRegionID = "orbit"

    if isvector(position) then
        World.State.swuShipPos = Vector(position.x, position.y, position.z)
    end

    persist()

    Convergence.Events.Publish("world.arrived", {
        planetID = destination:GetID(),
        taskForceName = Convergence.Config.World.PlayerTaskForceName,
        regions = World.GetRegions(destination:GetID())
    })

    return true
end

function World.SetEncounterActive(active, context)
    active = active == true
    World.State.encounterActive = active
    persist()

    Convergence.Events.Publish("world.encounter.changed", {
        active = active,
        planetID = World.State.currentPlanetID,
        regionID = World.State.activeRegionID
    }, context or {})

    return true
end

function World.IsEncounterActive()
    return World.State.encounterActive == true
end

function World.IsMainMap()
    return Convergence.Config.World.MainMaps[game.GetMap()] == true
end

function World.CanSpawnNPC()
    if not Convergence.Config.World.ProtectNPCSpawning then
        return true
    end

    if not World.IsMainMap() then
        return World.IsEncounterActive()
    end

    return false
end

function World.PrepareMapTransition(regionValue)
    local region = World.FindRegion(World.State.currentPlanetID, regionValue)

    if not region then
        return false, ERROR.INVALID_ARGUMENT, "Unknown region."
    end

    World.State.activeRegionID = region.id
    World.State.encounterActive = false
    persist()

    return true, region
end

hook.Add("PlayerSpawnedNPC", "Convergence.World.BlockNPCs", function(ply, npc)
    if not World.CanSpawnNPC() and IsValid(npc) then
        npc:Remove()

        if IsValid(ply) then
            ply:ChatPrint(
                "[Convergence] NPC spawning is disabled until a GM activates an encounter."
            )
        end
    end
end)

hook.Add("OnEntityCreated", "Convergence.World.BlockScriptedNPCs", function(entity)
    timer.Simple(0, function()
        if not IsValid(entity) or not entity:IsNPC() then
            return
        end

        if not World.CanSpawnNPC() then
            entity:Remove()
        end
    end)
end)
