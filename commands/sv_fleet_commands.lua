local function canManage(ply)
    return not IsValid(ply) or ply:IsSuperAdmin()
end

local function context(ply, reason)
    return {actor = ply, source = "console", reason = reason}
end

concommand.Add("convergence_fleets", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end

    print("========== Convergence Fleets ==========")
    for id, fleet in SortedPairs(Convergence.Fleets.GetAll()) do
        print(string.format(
            " - %s (%s): faction=%s strength=%d status=%s at=%s destination=%s",
            fleet.name, id, fleet.factionID, fleet.strength, fleet.status,
            fleet.currentPlanetID, tostring(fleet.destinationPlanetID or "None")
        ))
    end
    print("Active fleets: " .. Convergence.Fleets.Count())
    print("Destroyed archive: " .. Convergence.Fleets.CountDestroyed())
end)

concommand.Add("convergence_fleets_destroyed", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end

    print("========== Destroyed Convergence Fleets ==========")

    for id, fleet in SortedPairs(Convergence.Fleets.GetDestroyed()) do
        print(string.format(
            " - %s (%s): faction=%s last_planet=%s",
            fleet.name,
            id,
            fleet.factionID,
            tostring(fleet.currentPlanetID or "Unknown")
        ))
    end

    print("Destroyed fleets: " .. Convergence.Fleets.CountDestroyed())
end)

concommand.Add("convergence_fleet_create", function(ply, _, args)
    if not canManage(ply) then return end

    local faction, planet, strength = args[1], args[2], tonumber(args[3])
    local name = table.concat(args, " ", 4)

    if not faction or not planet or not strength or name == "" then
        print("Usage: convergence_fleet_create <faction> <planet> <strength> <name>")
        return
    end

    local ok, result, message = Convergence.Fleets.Create(
        name, faction, planet, strength, context(ply, "Fleet created by GM.")
    )

    print(ok and ("Created " .. result.name .. " (" .. result.id .. ")")
        or string.format("Failed [%s]: %s", result, message))
end)

concommand.Add("convergence_fleet_move", function(ply, _, args)
    if not canManage(ply) then return end

    local ok, result, message = Convergence.Fleets.Move(
        args[1], args[2], tonumber(args[3]),
        context(ply, "Fleet movement ordered by GM.")
    )

    print(ok and (result.name .. " is traveling to " .. result.destinationPlanetID)
        or string.format("Failed [%s]: %s", result, message))
end)

concommand.Add("convergence_fleet_delete", function(ply, _, args)
    if not canManage(ply) then return end

    local ok, code, message = Convergence.Fleets.Delete(
        args[1], context(ply, "Fleet deleted by GM.")
    )

    print(ok and "Fleet deleted."
        or string.format("Failed [%s]: %s", code, message))
end)

concommand.Add("convergence_fleet_test", function(ply)
    if not canManage(ply) then return end

    local checks = {}
    local created, fleet = Convergence.Fleets.Create(
        "Automated Fleet Test", "republic", "coruscant", 500,
        {source = "test", reason = "Automated fleet test."}
    )

    checks.create = created == true and fleet ~= nil
    checks.cache = fleet and Convergence.Fleets.Get(fleet.id) ~= nil

    local moved = fleet and Convergence.Fleets.Move(
        fleet.id, "tatooine", 0.01,
        {source = "test", reason = "Automated fleet movement test."}
    )

    checks.move = moved == true
    checks.traveling = fleet and fleet.status == "traveling"
    checks.progress = fleet and Convergence.Fleets.GetTravelProgress(fleet) >= 0

    local deleted = fleet and Convergence.Fleets.Delete(
        fleet.id, {source = "test", reason = "Automated cleanup."}
    )

    checks.delete = deleted == true
    checks.removed = fleet and Convergence.Fleets.Get(fleet.id) == nil

    local passed = 0
    print("========== Convergence Fleet Test ==========")

    for name, value in SortedPairs(checks) do
        if value then passed = passed + 1 end
        print(string.format("%-32s %s", name, value and "PASS" or "FAIL"))
    end

    print(string.format("Result: %d/%d passed", passed, table.Count(checks)))
end)


concommand.Add("convergence_fleet_admin_test", function(ply)
    if not canManage(ply) then
        return
    end

    local checks = {}
    local created, fleet = Convergence.Fleets.Create(
        "Fleet Admin Test",
        "republic",
        "coruscant",
        500,
        {source = "test", reason = "Fleet administration test."}
    )

    checks.create = created == true

    local renamed = fleet and Convergence.Fleets.Rename(
        fleet.id,
        "Fleet Admin Test Renamed",
        {source = "test", reason = "Fleet administration test."}
    )
    checks.rename = renamed == true

    local relocated = fleet and Convergence.Fleets.Relocate(
        fleet.id,
        "reach",
        {source = "test", reason = "Fleet administration test."}
    )
    checks.relocate = relocated == true
        and fleet.currentPlanetID == "reach"

    local strength = fleet and Convergence.Fleets.SetStrength(
        fleet.id,
        750,
        {source = "test", reason = "Fleet administration test."}
    )
    checks.strength = strength == true and fleet.strength == 750

    local deleted = fleet and Convergence.Fleets.Delete(
        fleet.id,
        {source = "test", reason = "Fleet administration test cleanup."}
    )
    checks.delete = deleted == true

    local passed = 0

    print("========== Fleet Administration Test ==========")

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
    print("===============================================")
end)


concommand.Add("convergence_fleet_logistics_test", function(ply)
    if not canManage(ply) then
        return
    end

    local checks = {}
    local created, fleet = Convergence.Fleets.Create(
        "Fleet Logistics Test",
        "republic",
        "reach",
        100,
        {source = "test", reason = "Fleet logistics test."}
    )

    checks.create = created == true

    local updated = fleet and Convergence.Fleets.UpdateLogistics(
        fleet.id,
        {
            commander = "Admiral Test",
            homePlanetID = "coruscant",
            experience = 750,
            morale = 85,
            supplies = 70,
            composition = {
                venator = 2,
                arquitens = 4,
                v19 = 100
            }
        },
        {source = "test", reason = "Fleet logistics test."}
    )

    checks.update = updated == true
    checks.commander = fleet and fleet.commander == "Admiral Test"
    checks.rank = fleet
        and Convergence.FleetLogistics.GetExperienceRank(
            fleet.experience
        ).name == "Veteran"
    checks.rating = fleet
        and Convergence.Fleets.GetCombatRating(fleet) > 0

    local stationed = Convergence.Fleets.GetStationedAtPlanet("reach")
    local found = false

    for _, stationedFleet in ipairs(stationed) do
        if fleet and stationedFleet.id == fleet.id then
            found = true
            break
        end
    end

    checks.stationedLookup = found

    if fleet then
        Convergence.Fleets.Delete(
            fleet.id,
            {source = "test", reason = "Fleet logistics test cleanup."}
        )
    end

    local passed = 0
    print("========== Fleet Logistics Test ==========")

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
    print("==========================================")
end)
