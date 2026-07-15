Convergence.Factions = Convergence.Factions or {}

local Factions = Convergence.Factions
local ERROR = Convergence.Constants.ERROR

Factions.Registry = Factions.Registry or {}
Factions.Aliases = Factions.Aliases or {}

Factions.ALIGNMENT = {
    PLAYER = "player",
    ALLY = "ally",
    NEUTRAL = "neutral",
    ENEMY = "enemy"
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

local function registerAlias(alias, factionID)
    alias = Convergence.NormalizeID(alias)

    if alias ~= "" then
        Factions.Aliases[alias] = factionID
    end
end

local function validate(definition)
    if not istable(definition) then
        return false, ERROR.INVALID_ARGUMENT,
            "Faction definition must be a table."
    end

    local id = Convergence.NormalizeID(definition.id)

    if id == "" then
        return false, ERROR.INVALID_ARGUMENT,
            "Faction definition requires a valid ID."
    end

    if Factions.Registry[id] then
        return false, ERROR.INVALID_ARGUMENT,
            "Faction is already registered: " .. id
    end

    local alignment = Convergence.NormalizeID(definition.alignment)

    if not table.HasValue(Factions.ALIGNMENT, alignment) then
        return false, ERROR.INVALID_ARGUMENT,
            "Faction alignment is invalid: " .. tostring(definition.alignment)
    end

    return true, id
end

function Factions.Register(definition)
    local valid, resultOrCode, errorMessage = validate(definition)

    if not valid then
        return false, resultOrCode, errorMessage
    end

    local id = resultOrCode
    local normalized = table.Copy(definition)

    normalized.id = id
    normalized.name = tostring(normalized.name or id)
    normalized.shortName = tostring(normalized.shortName or normalized.name)
    normalized.description = tostring(normalized.description or "")
    normalized.alignment = Convergence.NormalizeID(normalized.alignment)
    normalized.color = normalizeColor(normalized.color)
    normalized.icon = tostring(normalized.icon or "")
    normalized.aliases = istable(normalized.aliases)
        and table.Copy(normalized.aliases)
        or {}
    normalized.tags = istable(normalized.tags)
        and table.Copy(normalized.tags)
        or {}
    normalized.enabled = normalized.enabled ~= false
    normalized.metadata = istable(normalized.metadata)
        and table.Copy(normalized.metadata)
        or {}

    Factions.Registry[id] = normalized

    registerAlias(id, id)
    registerAlias(normalized.name, id)
    registerAlias(normalized.shortName, id)

    for _, alias in ipairs(normalized.aliases) do
        registerAlias(alias, id)
    end

    hook.Run("ConvergenceFactionRegistered", id, normalized)

    if Convergence.Events then
        Convergence.Events.Publish("faction.registered", {
            factionID = id,
            name = normalized.name,
            alignment = normalized.alignment
        })
    end

    return true, normalized
end

function Factions.ResolveID(value)
    local normalized = Convergence.NormalizeID(value)

    if normalized == "" then
        return nil
    end

    if Factions.Registry[normalized] then
        return normalized
    end

    return Factions.Aliases[normalized]
end

function Factions.Get(value)
    local id = Factions.ResolveID(value)

    if not id then
        return nil
    end

    return Factions.Registry[id]
end

function Factions.GetAll()
    return Factions.Registry
end

function Factions.Count()
    return table.Count(Factions.Registry)
end

function Factions.Exists(value)
    return Factions.ResolveID(value) ~= nil
end

function Factions.GetByAlignment(alignment)
    alignment = Convergence.NormalizeID(alignment)

    local results = {}

    for id, faction in pairs(Factions.Registry) do
        if faction.alignment == alignment and faction.enabled then
            results[id] = faction
        end
    end

    return results
end

function Factions.GetEnemies()
    return Factions.GetByAlignment(Factions.ALIGNMENT.ENEMY)
end

function Factions.GetPlayerFactions()
    return Factions.GetByAlignment(Factions.ALIGNMENT.PLAYER)
end
