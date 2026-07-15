Convergence.OperationGenerator =
    Convergence.OperationGenerator or {}

local Generator = Convergence.OperationGenerator

Generator.Ready = false
Generator.LastCreatedAt = Generator.LastCreatedAt or {}

local function hasUnresolvedAIEvent(planetID)
    for _, event in pairs(
        Convergence.CampaignEvents.GetAll() or {}
    ) do
        if event.planetID == planetID
            and event.status ~= "resolved"
            and event.status ~= "cancelled"
            and event.effects
            and event.effects.generatedByAI then
            return true
        end
    end

    return false
end

local function chooseEnemyFaction()
    local enemies = Convergence.Factions.GetEnemyIDs()
    return enemies[math.random(1, math.max(#enemies, 1))]
end

local function difficultyForThreat(threat)
    if threat >= 75 then
        return "extreme", "critical"
    elseif threat >= 55 then
        return "major", "high"
    elseif threat >= 35 then
        return "standard", "normal"
    end

    return "minor", "low"
end

function Generator.CanGenerate(planetID)
    local cooldown =
        tonumber(
            Convergence.Config.Campaign.AIOperationCooldownSeconds
        ) or 900
    local last = tonumber(Generator.LastCreatedAt[planetID]) or 0

    return CurTime() - last >= cooldown
        and not hasUnresolvedAIEvent(planetID)
end

function Generator.GenerateDefense(assessment, enemyFactionID, context)
    if not assessment or not Generator.CanGenerate(assessment.planetID) then
        return false, "Operation generation is on cooldown or already active."
    end

    enemyFactionID = enemyFactionID or chooseEnemyFaction()

    if not enemyFactionID then
        return false, "No enemy faction is registered."
    end

    local difficulty, priority =
        difficultyForThreat(assessment.threat)
    local name = "Defense of " .. assessment.planetName

    local success, eventOrCode, message =
        Convergence.CampaignEvents.Create({
            name = name,
            eventType = "defense",
            planetID = assessment.planetID,
            regionID = "surface",
            difficulty = difficulty,
            priority = priority,
            briefing = string.format(
                "Hostile %s activity has reached actionable levels. Defend %s and prevent further destabilization.",
                enemyFactionID,
                assessment.planetName
            ),
            friendlyFactions =
                Convergence.Factions.GetFriendlyIDs(),
            enemyFactions = {enemyFactionID},
            status = "available",
            aiProgressActive = true,
            effects = {
                generatedByAI = true,
                threatAtCreation = assessment.threat
            }
        }, context or {
            source = "operation_generator",
            reason = "Strategic AI generated a defensive operation."
        })

    if not success then
        return false, eventOrCode, message
    end

    Generator.LastCreatedAt[assessment.planetID] = CurTime()

    Convergence.Events.Publish("ai.operation.generated", {
        operation = table.Copy(eventOrCode),
        assessment = table.Copy(assessment)
    }, context or {})

    return true, eventOrCode
end

function Generator.Initialize()
    Generator.Ready = true
    Convergence.Services.Register("operation_generator", Generator)
    return true
end
