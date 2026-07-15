Convergence.StrategicIntelligence =
    Convergence.StrategicIntelligence or {}

local Intelligence = Convergence.StrategicIntelligence

Intelligence.Ready = false
Intelligence.Cache = Intelligence.Cache or {}
Intelligence.LastRefresh = 0
Intelligence.RefreshInterval = 5

local function routeNeighbors(planetID)
    local result = {}

    for _, route in ipairs(Convergence.Config.Galaxy.Routes or {}) do
        if route[1] == planetID then
            result[#result + 1] = route[2]
        elseif route[2] == planetID then
            result[#result + 1] = route[1]
        end
    end

    return result
end

local function operationData(planetID)
    local count = 0
    local critical = 0
    local major = 0
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

            if event.difficulty == "major"
                or event.difficulty == "extreme" then
                major = major + 1
            end
        end
    end

    return count, critical, major
end

local function fleetData(planetID)
    local friendlyStrength = 0
    local enemyStrength = 0
    local friendlyCount = 0
    local enemyCount = 0
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
        local atPlanet = fleet.currentPlanetID == planetID
            or fleet.destinationPlanetID == planetID

        if atPlanet and fleet.status ~= "destroyed" then
            local strength = tonumber(fleet.strength) or 0

            if friendlyIDs[fleet.factionID] then
                friendlyCount = friendlyCount + 1
                friendlyStrength = friendlyStrength + strength
            elseif enemyIDs[fleet.factionID] then
                enemyCount = enemyCount + 1
                enemyStrength = enemyStrength + strength
            end
        end
    end

    return friendlyStrength, enemyStrength, friendlyCount, enemyCount
end

local function neighboringEnemyPressure(planetID)
    local pressure = 0

    for _, neighborID in ipairs(routeNeighbors(planetID)) do
        local friendly =
            Convergence.Factions.GetFriendlyInfluence(neighborID)
        local enemy =
            Convergence.Factions.GetEnemyInfluence(neighborID)

        if enemy > friendly then
            pressure = pressure + math.min((enemy - friendly) * 0.18, 8)
        end
    end

    return math.min(pressure, 16)
end

local function strategicValue(planet)
    local sector = tostring(
        planet:GetDefinition()
        and planet:GetDefinition().galaxy
        and planet:GetDefinition().galaxy.sector
        or ""
    )

    if sector == "Core Worlds" then
        return 95
    elseif sector == "Epsilon Eridani" then
        return 80
    end

    return 55
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
    local friendlyFleetStrength, enemyFleetStrength,
        friendlyFleetCount, enemyFleetCount = fleetData(planetID)
    local operations, criticalOperations, majorOperations =
        operationData(planetID)
    local neighborPressure = neighboringEnemyPressure(planetID)
    local value = strategicValue(planet)

    local breakdown = {}

    breakdown.lowStability =
        math.Clamp((100 - stability) * 0.34, 0, 34)
    breakdown.enemyInfluence =
        math.Clamp(
            math.max(enemyInfluence - friendlyInfluence, 0) * 0.42,
            0,
            20
        )
    breakdown.enemyFleets =
        math.Clamp(
            math.max(enemyFleetStrength - friendlyFleetStrength, 0)
                / 400,
            0,
            22
        )
    breakdown.activeOperations = math.min(operations * 9, 18)
    breakdown.majorOperations = math.min(majorOperations * 6, 12)
    breakdown.criticalOperations = math.min(criticalOperations * 8, 16)
    breakdown.neighborPressure = neighborPressure
    breakdown.strategicExposure =
        math.Clamp((value / 100) * (100 - stability) * 0.08, 0, 8)

    local threat = 0

    for _, contribution in pairs(breakdown) do
        threat = threat + contribution
    end

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
            "Reinforce this system and prepare a player operation."
    elseif threat >= 30 then
        level = "MODERATE"
        recommendation =
            "Increase patrols and monitor hostile activity."
    end

    return {
        planetID = planetID,
        planetName = planet:GetName(),
        stability = stability,
        friendlyInfluence = friendlyInfluence,
        enemyInfluence = enemyInfluence,
        friendlyFleetStrength = friendlyFleetStrength,
        enemyFleetStrength = enemyFleetStrength,
        friendlyFleetCount = friendlyFleetCount,
        enemyFleetCount = enemyFleetCount,
        activeOperations = operations,
        criticalOperations = criticalOperations,
        majorOperations = majorOperations,
        neighboringEnemyPressure = neighborPressure,
        strategicValue = value,
        breakdown = breakdown,
        threat = threat,
        level = level,
        recommendation = recommendation,
        summary = string.format(
            "%s threat. Stability %.0f%%, hostile influence %.1f, enemy fleets %d, active operations %d.",
            level,
            stability,
            enemyInfluence,
            enemyFleetCount,
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

    hook.Run("ConvergenceIntelligenceRefreshed", result)
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

function Intelligence.GetWeakestFriendlyPlanet()
    local weakest = nil

    for _, assessment in pairs(Intelligence.GetAll()) do
        local opportunity =
            (100 - assessment.stability)
            + assessment.enemyInfluence
            - assessment.friendlyFleetStrength / 500

        if not weakest or opportunity > weakest.opportunity then
            weakest = {
                assessment = assessment,
                opportunity = opportunity
            }
        end
    end

    return weakest and weakest.assessment or nil
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
