Convergence.FactionAI = Convergence.FactionAI or {}

local AI = Convergence.FactionAI

AI.Ready = false
AI.Enabled = true
AI.LastThinkAt = 0
AI.NextThinkAt = 0
AI.ThinkCount = 0
AI.Decisions = AI.Decisions or {}

local function recordDecision(factionID, action, planetID, detail)
    AI.Decisions[factionID] = {
        factionID = factionID,
        action = action,
        planetID = planetID,
        detail = detail,
        decidedAt = os.time(),
        campaignTime = Convergence.Clock.GetTimeTable()
    }

    Convergence.Events.Publish("ai.decision.made", {
        decision = table.Copy(AI.Decisions[factionID])
    }, {
        source = "faction_ai",
        reason = "Strategic faction decision completed."
    })
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
            and (fleet.orderType == "idle" or not fleet.orderType) then
            return fleet
        end
    end

    return nil
end

local function reinforceFriendlyFaction(factionID)
    local highest =
        Convergence.StrategicIntelligence.GetHighestThreat()

    if not highest then
        recordDecision(factionID, "hold", nil, "No threat assessment.")
        return false
    end

    local threshold =
        tonumber(
            Convergence.Config.Campaign.AIFriendlyReinforceThreat
        ) or 35
    local fleet = availableFleet(factionID)

    if not fleet then
        recordDecision(
            factionID,
            "monitor",
            highest.planetID,
            "No idle fleet available."
        )
        return false
    end

    if highest.threat < threshold then
        local success = Convergence.FleetOrders.Assign(
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
            factionID,
            success and "patrol" or "hold",
            fleet.currentPlanetID,
            "Threat below reinforcement threshold."
        )
        return success
    end

    local success = Convergence.FleetOrders.Assign(
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
        factionID,
        success and "reinforce" or "hold",
        highest.planetID,
        success
            and (fleet.name .. " ordered to reinforce.")
            or "Fleet order failed."
    )

    return success
end

local function attackWithEnemyFaction(factionID)
    local target =
        Convergence.StrategicIntelligence.GetWeakestFriendlyPlanet()

    if not target then
        recordDecision(factionID, "hold", nil, "No target available.")
        return false
    end

    local fleet = availableFleet(factionID)

    if fleet then
        local success = Convergence.FleetOrders.Assign(
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
            factionID,
            success and "invade" or "hold",
            target.planetID,
            success
                and (fleet.name .. " ordered to invade.")
                or "Fleet invasion order failed."
        )

        return success
    end

    local threshold =
        tonumber(
            Convergence.Config.Campaign.AIEnemyAttackOpportunity
        ) or 34

    if target.threat >= threshold
        or (100 - target.stability) >= threshold then
        local success, operation =
            Convergence.OperationGenerator.GenerateDefense(
                target,
                factionID,
                {
                    source = "faction_ai",
                    reason = "Enemy AI generated an attack opportunity."
                }
            )

        recordDecision(
            factionID,
            success and "generate_operation" or "observe",
            target.planetID,
            success
                and ("Generated " .. operation.name)
                or "Operation generation unavailable."
        )

        return success
    end

    recordDecision(
        factionID,
        "observe",
        target.planetID,
        "Target opportunity below attack threshold."
    )

    return false
end

function AI.Think(force)
    if not AI.Ready or not AI.Enabled then
        return false, "Faction AI is disabled."
    end

    local now = CurTime()

    if not force and now < AI.NextThinkAt then
        return false, "Faction AI is waiting for its next think cycle."
    end

    Convergence.StrategicIntelligence.Refresh(true)

    for _, factionID in ipairs(
        Convergence.Factions.GetFriendlyIDs()
    ) do
        reinforceFriendlyFaction(factionID)
    end

    for _, factionID in ipairs(
        Convergence.Factions.GetEnemyIDs()
    ) do
        attackWithEnemyFaction(factionID)
    end

    AI.LastThinkAt = now
    AI.NextThinkAt = now + math.max(
        tonumber(
            Convergence.Config.Campaign.AIThinkIntervalSeconds
        ) or 120,
        30
    )
    AI.ThinkCount = AI.ThinkCount + 1

    hook.Run("ConvergenceFactionAIThinkCompleted", AI.ThinkCount)

    return true, AI.Decisions
end

function AI.GetStatus()
    return {
        ready = AI.Ready,
        enabled = AI.Enabled,
        lastThinkAt = AI.LastThinkAt,
        nextThinkAt = AI.NextThinkAt,
        secondsUntilNextThink = math.max(AI.NextThinkAt - CurTime(), 0),
        thinkCount = AI.ThinkCount,
        decisions = table.Copy(AI.Decisions),
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
