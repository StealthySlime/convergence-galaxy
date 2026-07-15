Convergence.StrategicIntelligence =
    Convergence.StrategicIntelligence or {}

local Intelligence = Convergence.StrategicIntelligence

Intelligence.Ready = false

local function countOperations(planetID)
    local count = 0
    local critical = 0

    for _, event in pairs(
        Convergence.CampaignEvents.GetAll() or {}
    ) do
        if event.planetID == planetID
            and event.status ~= "resolved"
            and event.status ~= "cancelled" then
            count = count + 1

            if event.priority == "critical" then
                critical = critical + 1
            end
        end
    end

    return count, critical
end

local function enemyInfluence(planetID)
    local total = 0

    for _, factionID in ipairs(
        Convergence.Factions.GetEnemyIDs() or {}
    ) do
        total = total + (
            tonumber(
                Convergence.Influence.Get(planetID, factionID)
            ) or 0
        )
    end

    return total
end

local function friendlyInfluence(planetID)
    local total = 0

    for _, factionID in ipairs({"republic", "unsc"}) do
        total = total + (
            tonumber(
                Convergence.Influence.Get(planetID, factionID)
            ) or 0
        )
    end

    return total
end

function Intelligence.AssessPlanet(planetID)
    local planet = Convergence.PlanetService.Get(planetID)

    if not planet then
        return nil
    end

    local stability = tonumber(planet:GetStability()) or 0
    local enemy = enemyInfluence(planetID)
    local friendly = friendlyInfluence(planetID)
    local operations, criticalOperations = countOperations(planetID)

    local threat = 0
    threat = threat + math.max(100 - stability, 0) * 0.45
    threat = threat + math.max(enemy - friendly, 0) * 0.7
    threat = threat + operations * 12
    threat = threat + criticalOperations * 15
    threat = math.Clamp(threat, 0, 100)

    local level = "LOW"
    local recommendation = "Maintain current posture."

    if threat >= (
        tonumber(
            Convergence.Config.Campaign.IntelligenceThreatCritical
        ) or 80
    ) then
        level = "CRITICAL"
        recommendation =
            "Immediate fleet deployment and player intervention recommended."
    elseif threat >= (
        tonumber(
            Convergence.Config.Campaign.IntelligenceThreatWarning
        ) or 55
    ) then
        level = "HIGH"
        recommendation =
            "Reinforce the system and prepare a player operation."
    elseif threat >= 30 then
        level = "MODERATE"
        recommendation =
            "Increase patrols and monitor hostile influence."
    end

    return {
        planetID = planetID,
        planetName = planet:GetName(),
        stability = stability,
        friendlyInfluence = friendly,
        enemyInfluence = enemy,
        activeOperations = operations,
        criticalOperations = criticalOperations,
        threat = threat,
        level = level,
        recommendation = recommendation,
        summary = string.format(
            "%s threat. Stability %.0f%%, friendly influence %.1f, enemy influence %.1f, active operations %d.",
            level,
            stability,
            friendly,
            enemy,
            operations
        )
    }
end

function Intelligence.GetAll()
    local result = {}

    for planetID in pairs(
        Convergence.PlanetService.GetAll() or {}
    ) do
        result[planetID] = Intelligence.AssessPlanet(planetID)
    end

    return result
end

function Intelligence.GetHighestThreat()
    local highest = nil

    for _, assessment in pairs(Intelligence.GetAll()) do
        if not highest or assessment.threat > highest.threat then
            highest = assessment
        end
    end

    return highest
end

function Intelligence.Initialize()
    Intelligence.Ready = true
    Convergence.Services.Register("strategic_intelligence", Intelligence)
    return true
end
