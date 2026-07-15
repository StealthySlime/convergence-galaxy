concommand.Add("convergence_news_test", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    local article = Convergence.GalacticNews.Publish({
        headline = "GNN TEST BULLETIN",
        subheadline = "Living Galaxy systems online",
        body = "Galactic News Network publishing and snapshot delivery are operational.",
        category = "test",
        severity = "success",
        planetID = Convergence.World.GetState().currentPlanetID
    })

    print(
        article
            and "[Convergence] GNN article published."
            or "[Convergence] GNN publish failed."
    )
end)

concommand.Add("convergence_daily_report", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    local article = Convergence.GalacticNews.PublishDailyReport()

    print(
        article
            and "[Convergence] Daily campaign report published."
            or "[Convergence] Daily report failed."
    )
end)

concommand.Add("convergence_intelligence_status", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    print("========== Strategic Intelligence ==========")

    for planetID, assessment in SortedPairs(
        Convergence.StrategicIntelligence.GetAll()
    ) do
        print(string.format(
            "%-14s threat=%5.1f level=%-8s stability=%5.1f ops=%d",
            planetID,
            assessment.threat,
            assessment.level,
            assessment.stability,
            assessment.activeOperations
        ))
    end

    print("============================================")
end)

concommand.Add("convergence_living_galaxy_test", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        return
    end

    local checks = {}
    local before = #Convergence.GalacticNews.GetAll()
    local article = Convergence.GalacticNews.Publish({
        headline = "Living Galaxy Test",
        body = "Automated test article.",
        severity = "success"
    })

    checks.newsReady = Convergence.GalacticNews.Ready == true
    checks.newsPublish = article ~= nil
    checks.newsCache = #Convergence.GalacticNews.GetAll() == before + 1
    checks.intelligenceReady =
        Convergence.StrategicIntelligence.Ready == true
    checks.intelligencePlanets =
        table.Count(
            Convergence.StrategicIntelligence.GetAll()
        ) == table.Count(
            Convergence.PlanetService.GetAll()
        )

    local passed = 0
    print("========== Living Galaxy Test ==========")

    for name, value in SortedPairs(checks) do
        if value then passed = passed + 1 end
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
    print("========================================")
end)
