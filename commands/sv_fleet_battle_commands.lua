local function canManage(ply)
    return not IsValid(ply) or ply:IsSuperAdmin()
end

concommand.Add("convergence_fleet_battle_status", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    print("========== Autonomous Fleet Battles ==========")
    print("Ready: " .. tostring(Convergence.FleetBattles.Ready))

    local active = Convergence.FleetBattles.GetActive()

    if table.IsEmpty(active) then
        print("Active battles: 0")
    else
        for planetID, result in SortedPairs(active) do
            print(string.format(
                "%-14s friendly=%-8.0f enemy=%-8.0f winner=%s completed=%s",
                planetID,
                tonumber(result.friendlyAfter) or 0,
                tonumber(result.enemyAfter) or 0,
                tostring(result.winner),
                tostring(result.completed)
            ))
        end
    end

    print("==============================================")
end)

concommand.Add("convergence_fleet_battle_tick", function(ply, _, args)
    if not canManage(ply) then
        return
    end

    local planetID = Convergence.NormalizeID(args[1] or "")

    if planetID == "" then
        print("Usage: convergence_fleet_battle_tick <planet>")
        return
    end

    local success, result =
        Convergence.FleetBattles.ResolveTick(planetID)

    if not success then
        print("[Convergence] Fleet battle tick skipped: " .. tostring(result))
        return
    end

    print(string.format(
        "[Convergence] Battle #%d at %s: friendly %.0f, enemy %.0f.",
        tonumber(result.battleID) or 0,
        planetID,
        tonumber(result.friendlyAfter) or 0,
        tonumber(result.enemyAfter) or 0
    ))
end)

concommand.Add("convergence_fleet_battle_test", function(ply)
    if not canManage(ply) then
        return
    end

    local checks = {
        serviceReady = Convergence.FleetBattles.Ready == true,
        processFunction = isfunction(Convergence.FleetBattles.Process),
        resolveFunction = isfunction(Convergence.FleetBattles.ResolveTick),
        fleetMutation = isfunction(Convergence.Fleets.SetStrength),
        planetLookup = isfunction(Convergence.Fleets.GetAtPlanet)
    }

    local passed = 0
    print("========== Fleet Battle Test ==========")

    for name, value in SortedPairs(checks) do
        if value then passed = passed + 1 end
        print(string.format(
            "%-24s %s",
            name,
            value and "PASS" or "FAIL"
        ))
    end

    print(string.format(
        "Result: %d/%d passed",
        passed,
        table.Count(checks)
    ))
    print("=======================================")
end)


concommand.Add("convergence_fleet_destruction_test", function(ply)
    if not canManage(ply) then
        return
    end

    local created, fleet = Convergence.Fleets.Create(
        "Destruction Cleanup Test",
        "covenant",
        "reach",
        10,
        {
            source = "test",
            reason = "Fleet destruction cleanup test."
        }
    )

    local destroyed = created and Convergence.Fleets.SetStrength(
        fleet.id,
        0,
        {
            source = "test",
            reason = "Fleet destruction cleanup test."
        }
    )

    local checks = {
        create = created == true,
        destroy = destroyed == true,
        removedFromActive = fleet
            and Convergence.Fleets.Get(fleet.id) == nil,
        archived = fleet
            and Convergence.Fleets.GetDestroyed(fleet.id) ~= nil,
        excludedFromPlanet = fleet
            and not table.HasValue(
                (function()
                    local ids = {}

                    for _, activeFleet in ipairs(
                        Convergence.Fleets.GetAtPlanet(
                            "reach",
                            false
                        )
                    ) do
                        ids[#ids + 1] = activeFleet.id
                    end

                    return ids
                end)(),
                fleet.id
            )
    }

    local passed = 0

    print("========== Fleet Destruction Test ==========")

    for name, value in SortedPairs(checks) do
        if value then passed = passed + 1 end
        print(string.format(
            "%-26s %s",
            name,
            value and "PASS" or "FAIL"
        ))
    end

    if fleet then
        Convergence.Fleets.Delete(
            fleet.id,
            {
                source = "test",
                reason = "Fleet destruction test cleanup."
            }
        )
    end

    print(string.format(
        "Result: %d/%d passed",
        passed,
        table.Count(checks)
    ))
    print("============================================")
end)
