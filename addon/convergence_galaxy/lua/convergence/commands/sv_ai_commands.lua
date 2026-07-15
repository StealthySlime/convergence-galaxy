local function canManage(ply)
    return not IsValid(ply) or ply:IsSuperAdmin()
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
    print(string.format(
        "Next think:           %.1f seconds",
        status.secondsUntilNextThink
    ))
    print("Active operations:    " .. tostring(status.activeOperations))

    for factionID, decision in SortedPairs(status.decisions or {}) do
        print(string.format(
            "%-12s action=%-20s planet=%-12s detail=%s",
            factionID,
            tostring(decision.action),
            tostring(decision.planetID or "none"),
            tostring(decision.detail or "")
        ))
    end

    print("============================================")
end)

concommand.Add("convergence_ai_think", function(ply)
    if not canManage(ply) then
        return
    end

    local success, result = Convergence.FactionAI.Think(true)

    print(
        success
            and "[Convergence] Forced Galactic AI think completed."
            or ("[Convergence] AI think failed: " .. tostring(result))
    )
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
