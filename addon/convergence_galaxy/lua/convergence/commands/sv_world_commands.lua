local function canManage(ply)
    return not IsValid(ply) or ply:IsSuperAdmin()
end

concommand.Add("convergence_world_status", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    local state = Convergence.World.GetPublicState()

    print("========== Convergence World Status ==========")
    print("Task force:       " .. tostring(state.taskForceName))
    print("Current planet:   " .. tostring(state.currentPlanetID))
    print("Destination:      " .. tostring(state.destinationPlanetID))
    print("Travel status:    " .. tostring(state.travelStatus))
    print("Current map:      " .. game.GetMap())
    print("Active region:    " .. tostring(state.activeRegionID))
    print("Encounter active: " .. tostring(state.encounterActive))
    print("NPC spawning:     " .. tostring(Convergence.World.CanSpawnNPC()))
    print("SWU available:    " .. tostring(
        Convergence.SWUWorld and Convergence.SWUWorld.IsAvailable()
    ))
    print("==============================================")
end)

concommand.Add("convergence_world_regions", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    local planet = Convergence.World.GetCurrentPlanet()

    if not planet then
        print("No current planet.")
        return
    end

    print("========== Regions: " .. planet:GetName() .. " ==========")

    for _, region in ipairs(
        Convergence.World.GetRegions(planet:GetID())
    ) do
        print(string.format(
            " - %s (%s): map=%s",
            region.name,
            region.id,
            region.map
        ))
    end
end)

concommand.Add("convergence_world_prepare", function(ply, _, args)
    if not canManage(ply) then
        return
    end

    local success, resultOrCode, message =
        Convergence.World.PrepareMapTransition(args[1])

    print(success
        and string.format(
            "Prepared region %s. The GM may now change to map %s.",
            resultOrCode.name,
            resultOrCode.map
        )
        or string.format("Failed [%s]: %s", resultOrCode, message))
end)

concommand.Add("convergence_world_change_map", function(ply, _, args)
    if not canManage(ply) then
        return
    end

    local success, regionOrCode, message =
        Convergence.World.PrepareMapTransition(args[1])

    if not success then
        print(string.format("Failed [%s]: %s", regionOrCode, message))
        return
    end

    print("[Convergence] GM-initiated map change to " .. regionOrCode.map)
    RunConsoleCommand("changelevel", regionOrCode.map)
end)

concommand.Add("convergence_encounter_start", function(ply)
    if not canManage(ply) then
        return
    end

    Convergence.World.SetEncounterActive(true, {
        actor = ply,
        source = "console",
        reason = "Encounter started by GM."
    })

    print("Encounter activated. NPC spawning is now allowed on this encounter map.")
end)

concommand.Add("convergence_encounter_end", function(ply)
    if not canManage(ply) then
        return
    end

    Convergence.World.SetEncounterActive(false, {
        actor = ply,
        source = "console",
        reason = "Encounter ended by GM."
    })

    print("Encounter ended. NPC spawning is disabled.")
end)

concommand.Add("convergence_world_test", function(ply)
    if not canManage(ply) then
        return
    end

    local state = Convergence.World.GetState()
    local checks = {
        ready = Convergence.World.IsReady(),
        state = istable(state),
        currentPlanet = Convergence.World.GetCurrentPlanet() ~= nil,
        regions = #Convergence.World.GetRegions() > 0,
        encounterDefaultOff = not Convergence.World.IsEncounterActive(),
        npcGuard = not Convergence.World.CanSpawnNPC()
            or not Convergence.World.IsMainMap()
    }

    local passed = 0
    print("========== Convergence World Test ==========")

    for name, value in SortedPairs(checks) do
        if value then passed = passed + 1 end
        print(string.format("%-32s %s", name, value and "PASS" or "FAIL"))
    end

    print(string.format("Result: %d/%d passed", passed, table.Count(checks)))
end)
