local function canManage(ply)
    return not IsValid(ply) or ply:IsSuperAdmin()
end

local function printCycle(cycle)
    if not cycle then
        print("Last cycle:            None")
        return
    end

    print(string.format(
        "Last cycle:            #%d | success=%s | duration=%.4fs",
        tonumber(cycle.id) or 0,
        tostring(cycle.success),
        tonumber(cycle.duration) or 0
    ))

    for _, stage in ipairs(cycle.stages or {}) do
        print(string.format(
            "  %-28s %-4s %s",
            tostring(stage.name),
            tostring(stage.status),
            tostring(stage.detail or "")
        ))
    end
end

concommand.Add("convergence_ai_status", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    local status = Convergence.FactionAI.GetStatus()

    print("========== Convergence Galactic AI ==========")
    print("Ready:                " .. tostring(status.ready))
    print("Enabled:              " .. tostring(status.enabled))
    print("Think count:          " .. tostring(status.thinkCount))
    print("Cycle ID:             " .. tostring(status.cycleID))
    print(string.format(
        "Next think:           %.1f seconds",
        status.secondsUntilNextThink
    ))
    print("Active operations:    " .. tostring(status.activeOperations))

    for factionID, decision in SortedPairs(status.decisions or {}) do
        print(string.format(
            "%-12s action=%-20s planet=%-12s success=%-5s detail=%s",
            factionID,
            tostring(decision.action),
            tostring(decision.planetID or "none"),
            tostring(decision.success),
            tostring(decision.detail or "")
        ))
    end

    printCycle(status.lastCycle)
    print("============================================")
end)

concommand.Add("convergence_ai_think", function(ply)
    if not canManage(ply) then
        return
    end

    local success, result = Convergence.FactionAI.Think(true)

    if success then
        print(string.format(
            "[Convergence] Forced Galactic AI cycle #%d completed with %d decisions.",
            tonumber(result.id) or 0,
            table.Count(result.decisions or {})
        ))
        printCycle(result)
    else
        print(
            "[Convergence] AI think failed: "
            .. tostring(result)
        )
    end
end)

concommand.Add("convergence_ai_toggle", function(ply, _, args)
    if not canManage(ply) then
        return
    end

    local enabled = tonumber(args[1]) == 1
    Convergence.FactionAI.SetEnabled(enabled)

    print(
        "[Convergence] Galactic AI "
        .. (enabled and "enabled." or "disabled.")
    )
end)

concommand.Add("convergence_ai_test", function(ply)
    if not canManage(ply) then
        return
    end

    local checks = {}
    local assessments = Convergence.StrategicIntelligence.GetAll()
    local highest = Convergence.StrategicIntelligence.GetHighestThreat()
    local weakest =
        Convergence.StrategicIntelligence.GetWeakestFriendlyPlanet()
    local before = Convergence.FactionAI.GetStatus().thinkCount
    local thinkSuccess, cycle = Convergence.FactionAI.Think(true)
    local after = Convergence.FactionAI.GetStatus().thinkCount

    checks.aiReady = Convergence.FactionAI.Ready == true
    checks.generatorReady =
        Convergence.OperationGenerator.Ready == true
    checks.intelligencePlanets =
        table.Count(assessments)
        == table.Count(Convergence.PlanetService.GetAll())
    checks.highestThreat = highest ~= nil
    checks.weakestTarget = weakest ~= nil
    checks.threatBreakdown =
        highest
        and istable(highest.breakdown)
        and table.Count(highest.breakdown) >= 5
    checks.thinkCompleted = thinkSuccess == true
    checks.thinkCountIncremented = after == before + 1
    checks.cycleRecorded =
        cycle
        and tonumber(cycle.id)
        and #cycle.stages >= 4

    local passed = 0

    print("========== Galactic AI Test ==========")

    for name, value in SortedPairs(checks) do
        if value then
            passed = passed + 1
        end

        print(string.format(
            "%-28s %s",
            name,
            value and "PASS" or "FAIL"
        ))
    end

    print(string.format(
        "Result: %d/%d passed",
        passed,
        table.Count(checks)
    ))
    print("======================================")
end)
