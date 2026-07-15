local function canManage(ply)
    return not IsValid(ply) or ply:IsSuperAdmin()
end

local function context(ply, reason)
    return {
        actor = ply,
        source = "campaign_command",
        reason = reason
    }
end

local function splitCSV(value)
    local result = {}

    for part in string.gmatch(tostring(value or ""), "[^,]+") do
        result[#result + 1] = Convergence.NormalizeID(part)
    end

    return result
end

concommand.Add("convergence_campaign_create", function(ply, _, args)
    if not canManage(ply) then return end

    local planetID = args[1]
    local difficulty = args[2]
    local enemyCSV = args[3]
    local name = table.concat(args, " ", 4)

    if not planetID or not difficulty or not enemyCSV or name == "" then
        print(
            "Usage: convergence_campaign_create "
            .. "<planet> <difficulty> <enemy1,enemy2> <name>"
        )
        return
    end

    local success, result, message =
        Convergence.CampaignEvents.Create({
            name = name,
            eventType = "battle",
            planetID = planetID,
            difficulty = difficulty,
            enemyFactions = splitCSV(enemyCSV),
            friendlyFactions = {"republic", "unsc"},
            status = "available",
            aiProgressActive = true
        }, context(ply, "GM created campaign event."))

    print(success
        and ("Created campaign event " .. result.name .. " (" .. result.id .. ")")
        or string.format("Failed [%s]: %s", result, message))
end)

concommand.Add("convergence_campaign_list", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end

    print("========== Campaign Events ==========")

    for id, event in SortedPairs(Convergence.CampaignEvents.GetAll()) do
        local remaining = event.autoResolveAt
            and math.max(event.autoResolveAt - os.time(), 0)
            or 0

        print(string.format(
            "%s | %s | planet=%s | status=%s | player=%s | remaining=%ds",
            id,
            event.name,
            event.planetID,
            event.status,
            tostring(event.playerControlled),
            remaining
        ))
    end
end)

concommand.Add("convergence_deployment_start", function(ply, _, args)
    if not canManage(ply) then return end

    local success, result, message =
        Convergence.Deployments.Start(
            args[1],
            context(ply, "GM started player deployment."),
            args[2]
        )

    print(success
        and ("Deployment started for event " .. result.eventID)
        or string.format("Failed [%s]: %s", result, message))
end)

concommand.Add("convergence_deployment_resolve", function(ply, _, args)
    if not canManage(ply) then return end

    local outcome = args[1]
    local notes = table.concat(args, " ", 2)

    local success, result, message =
        Convergence.Deployments.End(
            outcome,
            notes,
            context(ply, "GM resolved player deployment.")
        )

    print(success
        and ("Deployment resolved: " .. result.name)
        or string.format("Failed [%s]: %s", result, message))
end)

concommand.Add("convergence_campaign_extend", function(ply, _, args)
    if not canManage(ply) then return end

    local success, result, message =
        Convergence.CampaignEvents.Extend(args[1], tonumber(args[2]) or 1800)

    print(success
        and ("Extended " .. result.name .. " to " .. os.date("%c", result.autoResolveAt))
        or string.format("Failed [%s]: %s", result, message))
end)

concommand.Add("convergence_campaign_test", function(ply)
    if not canManage(ply) then return end

    local checks = {}

    local created, event = Convergence.CampaignEvents.Create({
        name = "Automated Campaign Test",
        planetID = "tatooine",
        difficulty = "standard",
        enemyFactions = {"cis"},
        friendlyFactions = {"republic", "unsc"},
        aiProgressActive = true
    }, {source = "test", reason = "Campaign test."})

    checks.create = created and event ~= nil
    checks.timer = event and event.autoResolveAt > os.time()

    local deployed = event and Convergence.Deployments.Start(
        event.id,
        {source = "test", reason = "Campaign deployment test."}
    )

    checks.deployment = deployed == true
    checks.singleDeployment = Convergence.Deployments.GetActive() ~= nil
    checks.playerControlled = event and event.playerControlled == true
    checks.aiPausedForCurrent = event and event.aiProgressActive == false

    local resolved = event and Convergence.Deployments.End(
        "victory",
        "Automated test resolution.",
        {source = "test", reason = "Campaign resolution test."}
    )

    checks.resolve = resolved == true
    checks.slotCleared = Convergence.Deployments.GetActive() == nil
    checks.eventResolved = event and event.status == "resolved"

    local passed = 0
    print("========== Campaign Framework Test ==========")

    for name, value in SortedPairs(checks) do
        if value then passed = passed + 1 end
        print(string.format("%-32s %s", name, value and "PASS" or "FAIL"))
    end

    print(string.format("Result: %d/%d passed", passed, table.Count(checks)))
end)
