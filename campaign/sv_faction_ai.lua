Convergence.FactionAI = Convergence.FactionAI or {}

local AI = Convergence.FactionAI

AI.Ready = false
AI.Enabled = true
AI.LastThinkAt = AI.LastThinkAt or 0
AI.NextThinkAt = AI.NextThinkAt or 0
AI.ThinkCount = AI.ThinkCount or 0
AI.CycleID = AI.CycleID or 0
AI.Decisions = AI.Decisions or {}
AI.LastCycle = AI.LastCycle or nil
AI.CycleHistory = AI.CycleHistory or {}
AI.MaxCycleHistory = 25

local function campaignStamp()
    return table.Copy(Convergence.Clock.GetTimeTable())
end

local function pushStage(cycle, name, status, detail)
    cycle.stages[#cycle.stages + 1] = {
        name = name,
        status = status,
        detail = tostring(detail or ""),
        at = SysTime()
    }
end

local function finishCycle(cycle, success, message)
    cycle.success = success == true
    cycle.message = tostring(message or "")
    cycle.finishedAt = CurTime()
    cycle.duration = SysTime() - cycle.startedSysTime

    AI.LastCycle = cycle
    AI.CycleHistory[#AI.CycleHistory + 1] = table.Copy(cycle)

    while #AI.CycleHistory > AI.MaxCycleHistory do
        table.remove(AI.CycleHistory, 1)
    end

    hook.Run(
        "ConvergenceFactionAIThinkCompleted",
        cycle.id,
        cycle.success,
        table.Copy(cycle)
    )
end

local function recordDecision(cycle, factionID, action, planetID, detail, success)
    local decision = {
        factionID = factionID,
        action = action,
        planetID = planetID,
        detail = tostring(detail or ""),
        success = success ~= false,
        decidedAt = os.time(),
        campaignTime = campaignStamp(),
        cycleID = cycle.id
    }

    AI.Decisions[factionID] = decision
    cycle.decisions[factionID] = table.Copy(decision)

    Convergence.Events.Publish("ai.decision.made", {
        decision = table.Copy(decision)
    }, {
        source = "faction_ai",
        reason = "Strategic faction decision completed."
    })

    return decision
end

local function unresolvedOperationCount()
    local count = 0

    for _, event in pairs(
        Convergence.CampaignEvents.GetAll() or {}
    ) do
        if event.status ~= "resolved"
            and event.status ~= "cancelled" then
            count = count + 1
        end
    end

    return count
end

local function availableFleet(factionID)
    for _, fleet in pairs(Convergence.Fleets.GetAll() or {}) do
        if fleet.factionID == factionID
            and fleet.status == "stationed"
            and (
                fleet.orderType == "idle"
                or fleet.orderType == nil
                or fleet.orderType == ""
            ) then
            return fleet
        end
    end

    return nil
end

local function processFriendlyFaction(cycle, factionID)
    local highest =
        Convergence.StrategicIntelligence.GetHighestThreat()

    if not highest then
        recordDecision(
            cycle,
            factionID,
            "hold",
            nil,
            "No threat assessment is available.",
            false
        )
        return false
    end

    local threshold =
        tonumber(
            Convergence.Config.Campaign.AIFriendlyReinforceThreat
        ) or 35
    local fleet = availableFleet(factionID)

    if not fleet then
        recordDecision(
            cycle,
            factionID,
            "monitor",
            highest.planetID,
            string.format(
                "Monitoring %s at %.1f%% threat; no idle fleet is available.",
                highest.planetName,
                highest.threat
            ),
            true
        )
        return true
    end

    if highest.threat < threshold then
        local success, resultOrCode, message =
            Convergence.FleetOrders.Assign(
                fleet.id,
                "patrol",
                fleet.currentPlanetID,
                {
                    influencePerTick = 0.05,
                    aiControlled = true
                },
                {
                    source = "faction_ai",
                    reason = "Low threat; fleet assigned local patrol."
                }
            )

        recordDecision(
            cycle,
            factionID,
            success and "patrol" or "hold",
            fleet.currentPlanetID,
            success
                and string.format(
                    "%s assigned to patrol %s.",
                    fleet.name,
                    fleet.currentPlanetID
                )
                or string.format(
                    "Patrol order failed [%s]: %s",
                    tostring(resultOrCode),
                    tostring(message)
                ),
            success
        )

        return success
    end

    local success, resultOrCode, message =
        Convergence.FleetOrders.Assign(
            fleet.id,
            "reinforce",
            highest.planetID,
            {
                travelHours =
                    tonumber(
                        Convergence.Config.Campaign.AIFleetTravelHours
                    ) or 6,
                aiControlled = true
            },
            {
                source = "faction_ai",
                reason = "Fleet sent to highest-threat friendly planet."
            }
        )

    recordDecision(
        cycle,
        factionID,
        success and "reinforce" or "hold",
        highest.planetID,
        success
            and string.format(
                "%s ordered to reinforce %s at %.1f%% threat.",
                fleet.name,
                highest.planetName,
                highest.threat
            )
            or string.format(
                "Reinforcement order failed [%s]: %s",
                tostring(resultOrCode),
                tostring(message)
            ),
        success
    )

    return success
end

local function processEnemyFaction(cycle, factionID)
    local target =
        Convergence.StrategicIntelligence.GetWeakestFriendlyPlanet()

    if not target then
        recordDecision(
            cycle,
            factionID,
            "hold",
            nil,
            "No viable strategic target is available.",
            false
        )
        return false
    end

    local fleet = availableFleet(factionID)

    if fleet then
        local success, resultOrCode, message =
            Convergence.FleetOrders.Assign(
                fleet.id,
                "invade",
                target.planetID,
                {
                    travelHours =
                        tonumber(
                            Convergence.Config.Campaign.AIFleetTravelHours
                        ) or 6,
                    aiControlled = true
                },
                {
                    source = "faction_ai",
                    reason = "Enemy AI selected a strategic invasion target."
                }
            )

        recordDecision(
            cycle,
            factionID,
            success and "invade" or "hold",
            target.planetID,
            success
                and string.format(
                    "%s ordered to invade %s.",
                    fleet.name,
                    target.planetName
                )
                or string.format(
                    "Invasion order failed [%s]: %s",
                    tostring(resultOrCode),
                    tostring(message)
                ),
            success
        )

        return success
    end

    local threshold =
        tonumber(
            Convergence.Config.Campaign.AIEnemyAttackOpportunity
        ) or 34
    local exposure = math.max(
        tonumber(target.threat) or 0,
        100 - (tonumber(target.stability) or 100)
    )

    if exposure >= threshold then
        local success, operationOrCode, message =
            Convergence.OperationGenerator.GenerateDefense(
                target,
                factionID,
                {
                    source = "faction_ai",
                    reason = "Enemy AI generated an attack opportunity."
                }
            )

        recordDecision(
            cycle,
            factionID,
            success and "generate_operation" or "observe",
            target.planetID,
            success
                and ("Generated " .. operationOrCode.name)
                or string.format(
                    "Operation generation unavailable [%s]: %s",
                    tostring(operationOrCode),
                    tostring(message)
                ),
            success
        )

        return success
    end

    recordDecision(
        cycle,
        factionID,
        "observe",
        target.planetID,
        string.format(
            "%s exposure %.1f is below the attack threshold %.1f.",
            target.planetName,
            exposure,
            threshold
        ),
        true
    )

    return true
end

function AI.Think(force)
    if not AI.Ready then
        return false, "Faction AI is not ready."
    end

    if not AI.Enabled then
        return false, "Faction AI is disabled."
    end

    local now = CurTime()

    if not force and now < AI.NextThinkAt then
        return false, "Faction AI is waiting for its next think cycle."
    end

    -- Advance state before any subsystem work. Even a partial cycle is visible
    -- and receives a cycle ID, preventing misleading thinkCount=0 output.
    AI.ThinkCount = AI.ThinkCount + 1
    AI.CycleID = AI.CycleID + 1
    AI.LastThinkAt = now
    AI.NextThinkAt = now + math.max(
        tonumber(
            Convergence.Config.Campaign.AIThinkIntervalSeconds
        ) or 120,
        30
    )

    local cycle = {
        id = AI.CycleID,
        thinkCount = AI.ThinkCount,
        forced = force == true,
        startedAt = now,
        startedSysTime = SysTime(),
        campaignTime = campaignStamp(),
        stages = {},
        decisions = {},
        success = false
    }

    pushStage(cycle, "cycle_started", "PASS", "Think cycle state advanced.")

    local refreshOK, refreshResult = pcall(
        Convergence.StrategicIntelligence.Refresh,
        true
    )

    if not refreshOK then
        pushStage(
            cycle,
            "intelligence_refresh",
            "FAIL",
            refreshResult
        )
        finishCycle(cycle, false, refreshResult)
        return false, refreshResult
    end

    pushStage(
        cycle,
        "intelligence_refresh",
        "PASS",
        string.format(
            "%d planets assessed.",
            table.Count(refreshResult or {})
        )
    )

    local friendlyIDs = Convergence.Factions.GetFriendlyIDs()
    local enemyIDs = Convergence.Factions.GetEnemyIDs()

    pushStage(
        cycle,
        "faction_discovery",
        "PASS",
        string.format(
            "%d friendly and %d enemy factions.",
            #friendlyIDs,
            #enemyIDs
        )
    )

    for _, factionID in ipairs(friendlyIDs) do
        local ok, result = pcall(
            processFriendlyFaction,
            cycle,
            factionID
        )

        pushStage(
            cycle,
            "friendly_" .. factionID,
            ok and "PASS" or "FAIL",
            ok and tostring(result) or tostring(result)
        )
    end

    for _, factionID in ipairs(enemyIDs) do
        local ok, result = pcall(
            processEnemyFaction,
            cycle,
            factionID
        )

        pushStage(
            cycle,
            "enemy_" .. factionID,
            ok and "PASS" or "FAIL",
            ok and tostring(result) or tostring(result)
        )
    end

    pushStage(
        cycle,
        "cycle_complete",
        "PASS",
        string.format(
            "%d decisions recorded; %d unresolved operations.",
            table.Count(cycle.decisions),
            unresolvedOperationCount()
        )
    )

    finishCycle(cycle, true, "Strategic think cycle completed.")

    return true, table.Copy(cycle)
end

function AI.GetStatus()
    return {
        ready = AI.Ready,
        enabled = AI.Enabled,
        lastThinkAt = AI.LastThinkAt,
        nextThinkAt = AI.NextThinkAt,
        secondsUntilNextThink = math.max(AI.NextThinkAt - CurTime(), 0),
        thinkCount = AI.ThinkCount,
        cycleID = AI.CycleID,
        decisions = table.Copy(AI.Decisions),
        lastCycle = AI.LastCycle and table.Copy(AI.LastCycle) or nil,
        cycleHistory = table.Copy(AI.CycleHistory),
        activeOperations = unresolvedOperationCount()
    }
end

function AI.SetEnabled(enabled)
    AI.Enabled = enabled == true

    if AI.Enabled then
        AI.NextThinkAt = CurTime() + 5
    end

    return AI.Enabled
end

function AI.Initialize()
    AI.Enabled =
        Convergence.Config.Campaign.AIEnabled ~= false
    AI.Ready = true
    AI.NextThinkAt = CurTime() + 10

    Convergence.Services.Register("faction_ai", AI)

    timer.Create(
        "Convergence.FactionAI.Think",
        5,
        0,
        function()
            AI.Think(false)
        end
    )

    return true
end
