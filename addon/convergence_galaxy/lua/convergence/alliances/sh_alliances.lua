Convergence.Alliances = Convergence.Alliances or {}

local Alliances = Convergence.Alliances
local ERROR = Convergence.Constants.ERROR

Alliances.Registry = Alliances.Registry or {}
Alliances.Aliases = Alliances.Aliases or {}
Alliances.FactionMembership = Alliances.FactionMembership or {}

Alliances.RELATION = {
    ALLIED = "allied",
    NEUTRAL = "neutral",
    HOSTILE = "hostile"
}

local function normalizeColor(value)
    if IsColor(value) then
        return Color(value.r, value.g, value.b, value.a)
    end

    if istable(value) then
        return Color(
            math.Clamp(tonumber(value.r or value[1]) or 255, 0, 255),
            math.Clamp(tonumber(value.g or value[2]) or 255, 0, 255),
            math.Clamp(tonumber(value.b or value[3]) or 255, 0, 255),
            math.Clamp(tonumber(value.a or value[4]) or 255, 0, 255)
        )
    end

    return Color(255, 255, 255)
end

local function registerAlias(alias, allianceID)
    alias = Convergence.NormalizeID(alias)

    if alias ~= "" then
        Alliances.Aliases[alias] = allianceID
    end
end

function Alliances.Register(definition)
    if not istable(definition) then
        return false, ERROR.INVALID_ARGUMENT,
            "Alliance definition must be a table."
    end

    local id = Convergence.NormalizeID(definition.id)

    if id == "" then
        return false, ERROR.INVALID_ARGUMENT,
            "Alliance definition requires a valid ID."
    end

    if Alliances.Registry[id] then
        return false, ERROR.INVALID_ARGUMENT,
            "Alliance is already registered: " .. id
    end

    local normalized = table.Copy(definition)

    normalized.id = id
    normalized.name = tostring(normalized.name or id)
    normalized.shortName = tostring(normalized.shortName or normalized.name)
    normalized.description = tostring(normalized.description or "")
    normalized.color = normalizeColor(normalized.color)
    normalized.icon = tostring(normalized.icon or "")
    normalized.aliases = istable(normalized.aliases)
        and table.Copy(normalized.aliases)
        or {}
    normalized.factions = istable(normalized.factions)
        and table.Copy(normalized.factions)
        or {}
    normalized.relationships = istable(normalized.relationships)
        and table.Copy(normalized.relationships)
        or {}
    normalized.tags = istable(normalized.tags)
        and table.Copy(normalized.tags)
        or {}
    normalized.enabled = normalized.enabled ~= false

    Alliances.Registry[id] = normalized

    registerAlias(id, id)
    registerAlias(normalized.name, id)
    registerAlias(normalized.shortName, id)

    for _, alias in ipairs(normalized.aliases) do
        registerAlias(alias, id)
    end

    for _, factionValue in ipairs(normalized.factions) do
        local factionID = Convergence.Factions.ResolveID(factionValue)

        if factionID then
            Alliances.FactionMembership[factionID] = id
        else
            Convergence.Log.Warn("Alliances", "Alliance references unknown faction.", {
                alliance = id,
                faction = tostring(factionValue)
            })
        end
    end

    hook.Run("ConvergenceAllianceRegistered", id, normalized)

    Convergence.Events.Publish("alliance.registered", {
        allianceID = id,
        name = normalized.name,
        factionCount = #normalized.factions
    })

    return true, normalized
end

function Alliances.ResolveID(value)
    local normalized = Convergence.NormalizeID(value)

    if normalized == "" then
        return nil
    end

    if Alliances.Registry[normalized] then
        return normalized
    end

    return Alliances.Aliases[normalized]
end

function Alliances.Get(value)
    local id = Alliances.ResolveID(value)

    if not id then
        return nil
    end

    return Alliances.Registry[id]
end

function Alliances.GetAll()
    return Alliances.Registry
end

function Alliances.Count()
    return table.Count(Alliances.Registry)
end

function Alliances.GetForFaction(factionValue)
    local factionID = Convergence.Factions.ResolveID(factionValue)

    if not factionID then
        return nil
    end

    local allianceID = Alliances.FactionMembership[factionID]

    if not allianceID then
        return nil
    end

    return Alliances.Registry[allianceID]
end

function Alliances.GetFactionIDs(allianceValue)
    local alliance = Alliances.Get(allianceValue)

    if not alliance then
        return {}
    end

    local results = {}

    for _, factionValue in ipairs(alliance.factions) do
        local factionID = Convergence.Factions.ResolveID(factionValue)

        if factionID then
            results[#results + 1] = factionID
        end
    end

    return results
end

function Alliances.GetRelationship(leftValue, rightValue)
    local left = Alliances.Get(leftValue)
    local right = Alliances.Get(rightValue)

    if not left or not right then
        return Alliances.RELATION.NEUTRAL
    end

    if left.id == right.id then
        return Alliances.RELATION.ALLIED
    end

    local explicit = left.relationships[right.id]

    if explicit then
        return Convergence.NormalizeID(explicit)
    end

    local reverse = right.relationships[left.id]

    if reverse then
        return Convergence.NormalizeID(reverse)
    end

    return Alliances.RELATION.NEUTRAL
end

function Alliances.AreAllied(leftValue, rightValue)
    return Alliances.GetRelationship(leftValue, rightValue)
        == Alliances.RELATION.ALLIED
end

function Alliances.AreHostile(leftValue, rightValue)
    return Alliances.GetRelationship(leftValue, rightValue)
        == Alliances.RELATION.HOSTILE
end
