local function canManage(ply)
    return not IsValid(ply) or ply:IsSuperAdmin()
end

local function context(ply, reason)
    return {actor = ply, source = "console", reason = reason}
end

concommand.Add("convergence_fleet_order", function(ply, _, args)
    if not canManage(ply) then return end

    local fleetID = args[1]
    local orderType = args[2]
    local planetID = args[3]
    local travelHours = tonumber(args[4])

    if not fleetID or not orderType then
        print("Usage: convergence_fleet_order <fleet> <order> [planet] [travel_hours]")
        print("Orders: idle move patrol defend reinforce invade blockade escort retreat explore")
        return
    end

    local ok, result, message = Convergence.FleetOrders.Assign(
        fleetID,
        orderType,
        planetID,
        travelHours and {travelHours = travelHours} or {},
        context(ply, "Fleet order assigned by GM.")
    )

    print(ok
        and string.format(
            "%s assigned order %s%s",
            result.name,
            result.orderType,
            result.orderPlanetID and (" at " .. result.orderPlanetID) or ""
        )
        or string.format("Failed [%s]: %s", result, message))
end)

concommand.Add("convergence_fleet_order_clear", function(ply, _, args)
    if not canManage(ply) then return end

    local ok, result, message = Convergence.FleetOrders.Clear(
        args[1],
        context(ply, "Fleet order cleared by GM.")
    )

    print(ok and "Fleet order cleared."
        or string.format("Failed [%s]: %s", result, message))
end)

concommand.Add("convergence_fleet_order_test", function(ply)
    if not canManage(ply) then return end

    local checks = {}
    local created, fleet = Convergence.Fleets.Create(
        "Order Test Fleet", "republic", "coruscant", 750,
        {source = "test", reason = "Fleet order test."}
    )

    checks.create = created == true and fleet ~= nil

    local assigned = fleet and Convergence.FleetOrders.Assign(
        fleet.id,
        "defend",
        "tatooine",
        {travelHours = 0.01},
        {source = "test", reason = "Assign defend order."}
    )

    checks.assign = assigned == true
    checks.orderType = fleet and fleet.orderType == "defend"
    checks.target = fleet and fleet.orderPlanetID == "tatooine"

    Convergence.FleetOrders.Process()
    checks.travelStarted = fleet and fleet.status == "traveling"

    local cleared = fleet and Convergence.FleetOrders.Clear(
        fleet.id,
        {source = "test", reason = "Clear order."}
    )

    checks.clear = cleared == true
    checks.idle = fleet and fleet.orderType == "idle"

    if fleet then
        Convergence.Fleets.Delete(
            fleet.id,
            {source = "test", reason = "Cleanup fleet order test."}
        )
    end

    local passed = 0
    print("========== Convergence Fleet Order Test ==========")

    for name, value in SortedPairs(checks) do
        if value then passed = passed + 1 end
        print(string.format("%-32s %s", name, value and "PASS" or "FAIL"))
    end

    print(string.format("Result: %d/%d passed", passed, table.Count(checks)))
end)
