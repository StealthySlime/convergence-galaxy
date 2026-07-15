Convergence.StrategicIntelligence =
    Convergence.StrategicIntelligence or {}

local Intelligence = Convergence.StrategicIntelligence

Intelligence.Ready = false
Intelligence.Cache = Intelligence.Cache or {}
Intelligence.LastRefresh = 0
Intelligence.RefreshInterval = 5

local function countOperations(planetID)
    local count = 0
    local critical = 0
    local operations = Convergence.ServiceFacade.Operations

    for _, event in pairs(
        operations and operations.GetAll() or {}
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

local function fleetStrengthAtPlanet(planetID)
    local friendly = 0
    local enemy = 0
    local friendlyIDs = {}
    local enemyIDs = {}

    for _, id in ipairs(Convergence.Factions.GetFriendlyIDs()) do
        friendlyIDs[id] = true
    end

    for _, id in ipairs(Convergence.Factions.GetEnemyIDs()) do
        enemyIDs[id] = true
    end

    local fleets = Convergence.ServiceFacade.Fleets

    for _, fleet in pairs(fleets and fleets.GetAll() or {}) do
        if fleet.currentPlanetID == planetID
            and fleet.status ~= "destroyed" then
            local strength = tonumber(fleet.strength) or 0

            if friendlyIDs[fleet.factionID] then
                friendly = friendly + strength
            elseif enemyIDs[fleet.factionID] then
                enemy = enemy + strength
            end
        end
    end

    return friendly, enemy
end

function Intelligence.AssessPlanet(planetID)
    local planets = Convergence.ServiceFacade.Planets
    local planet = planets and planets.Get(planetID)

    if not planet then
        return nil
    end

    local stability = tonumber(planet:GetStability()) or 0
    local friendlyInfluence =
        Convergence.Factions.GetFriendlyInfluence(planetID)
    local enemyInfluence =
        Convergence.Factions.GetEnemyInfluence(planetID)
    local friendlyFleetStrength, enemyFleetStrength =
        fleetStrengthAtPlanet(planetID)
    local operations, criticalOperations = countOperations(planetID)

    local threat = 0
    threat = threat + math.max(100 - stability, 0) * 0.38
    threat = threat
        + math.max(enemyInfluence - friendlyInfluence, 0) * 0.52
    threat = threat
        + math.max(enemyFleetStrength - friendlyFleetStrength, 0) * 0.002
    threat = threat + operations * 11
    threat = threat + criticalOperations * 14
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
        friendlyInfluence = friendlyInfluence,
        enemyInfluence = enemyInfluence,
        friendlyFleetStrength = friendlyFleetStrength,
        enemyFleetStrength = enemyFleetStrength,
        activeOperations = operations,
        criticalOperations = criticalOperations,
        threat = threat,
        level = level,
        recommendation = recommendation,
        summary = string.format(
            "%s threat. Stability %.0f%%, friendly influence %.1f, enemy influence %.1f, active operations %d.",
            level,
            stability,
            friendlyInfluence,
            enemyInfluence,
            operations
        )
    }
end

function Intelligence.Refresh(force)
    if not force
        and CurTime() - Intelligence.LastRefresh
            < Intelligence.RefreshInterval then
        return Intelligence.Cache
    end

    local result = {}
    local planets = Convergence.ServiceFacade.Planets

    for planetID in pairs(planets and planets.GetAll() or {}) do
        result[planetID] = Intelligence.AssessPlanet(planetID)
    end

    Intelligence.Cache = result
    Intelligence.LastRefresh = CurTime()

    return result
end

function Intelligence.GetAll()
    return Intelligence.Refresh(false)
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
    if not Convergence.Lifecycle
        or not Convergence.Lifecycle.IsReady() then
        return false,
            Convergence.Constants.ERROR.INVALID_ARGUMENT,
            "Core service lifecycle must be ready before Intelligence."
    end

    Intelligence.Ready = true
    Convergence.Services.Register("strategic_intelligence", Intelligence)
    Intelligence.Refresh(true)

    timer.Create("Convergence.Intelligence.Refresh", 5, 0, function()
        Intelligence.Refresh(true)
    end)

    return true
end
