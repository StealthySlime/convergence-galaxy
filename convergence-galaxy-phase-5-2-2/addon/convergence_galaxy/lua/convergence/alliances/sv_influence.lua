Convergence.Influence = Convergence.Influence or {}

local Influence = Convergence.Influence
local DB = Convergence.Database
local ERROR = Convergence.Constants.ERROR

Influence.Cache = Influence.Cache or {}
Influence.Ready = false

function Influence.IsReady()
    return Influence.Ready == true
end

function Influence.Initialize()
    if Influence.Ready then
        return true
    end

    local success, rowsOrCode, errorMessage =
        DB.Query("SELECT * FROM convergence_planet_influence")

    if not success then
        return false, rowsOrCode, errorMessage
    end

    Influence.Cache = {}

    for _, row in ipairs(rowsOrCode or {}) do
        Influence.Cache[row.planet_id] = Influence.Cache[row.planet_id] or {}
        Influence.Cache[row.planet_id][row.faction_id] =
            tonumber(row.influence) or 0
    end

    Influence.Ready = true

    Convergence.Events.Publish("influence.ready", {
        planets = table.Count(Influence.Cache)
    })

    return true
end

function Influence.Get(planetValue, factionValue)
    local planet = Convergence.PlanetService.Get(planetValue)
    local factionID = Convergence.Factions.ResolveID(factionValue)

    if not planet or not factionID then
        return 0
    end

    return (Influence.Cache[planet:GetID()] or {})[factionID] or 0
end

function Influence.GetPlanetInfluence(planetValue)
    local planet = Convergence.PlanetService.Get(planetValue)

    if not planet then
        return {}
    end

    return table.Copy(Influence.Cache[planet:GetID()] or {})
end

function Influence.Set(planetValue, factionValue, amount, context)
    local planet = Convergence.PlanetService.Get(planetValue)
    local factionID = Convergence.Factions.ResolveID(factionValue)

    if not planet then
        return false, ERROR.UNKNOWN_PLANET, "Unknown planet."
    end

    if not factionID then
        return false, ERROR.INVALID_ARGUMENT, "Unknown faction."
    end

    amount = math.max(tonumber(amount) or 0, 0)

    local previous = Influence.Get(planet:GetID(), factionID)

    local success, errorCode, errorMessage = DB.Execute(string.format(
        [[
            INSERT OR REPLACE INTO convergence_planet_influence
            (planet_id, faction_id, influence, updated_at)
            VALUES (%s, %s, %f, %d)
        ]],
        DB.Escape(planet:GetID()),
        DB.Escape(factionID),
        amount,
        os.time()
    ))

    if not success then
        return false, errorCode, errorMessage
    end

    Influence.Cache[planet:GetID()] =
        Influence.Cache[planet:GetID()] or {}
    Influence.Cache[planet:GetID()][factionID] = amount

    Convergence.Events.Publish("planet.influence.changed", {
        planetID = planet:GetID(),
        factionID = factionID,
        previous = previous,
        current = amount,
        delta = amount - previous
    }, context or {})

    return true, amount
end

function Influence.Add(planetValue, factionValue, amount, context)
    local current = Influence.Get(planetValue, factionValue)

    return Influence.Set(
        planetValue,
        factionValue,
        current + (tonumber(amount) or 0),
        context
    )
end

function Influence.GetDominantFaction(planetValue)
    local influence = Influence.GetPlanetInfluence(planetValue)
    local dominantID = nil
    local dominantValue = -math.huge

    for factionID, amount in pairs(influence) do
        if amount > dominantValue then
            dominantID = factionID
            dominantValue = amount
        end
    end

    if not dominantID then
        return nil, 0
    end

    return Convergence.Factions.Get(dominantID), dominantValue
end

function Influence.GetDominantAlliance(planetValue)
    local totals = {}

    for factionID, amount in pairs(
        Influence.GetPlanetInfluence(planetValue)
    ) do
        local alliance = Convergence.Alliances.GetForFaction(factionID)

        if alliance then
            totals[alliance.id] = (totals[alliance.id] or 0) + amount
        end
    end

    local dominantID = nil
    local dominantValue = -math.huge

    for allianceID, amount in pairs(totals) do
        if amount > dominantValue then
            dominantID = allianceID
            dominantValue = amount
        end
    end

    if not dominantID then
        return nil, 0
    end

    return Convergence.Alliances.Get(dominantID), dominantValue
end
