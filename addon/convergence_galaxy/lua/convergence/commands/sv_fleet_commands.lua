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
    print("Total fleets: " .. Convergence.Fleets.Count())
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
