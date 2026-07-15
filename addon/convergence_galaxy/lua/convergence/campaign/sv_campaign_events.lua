Convergence.CampaignEvents = Convergence.CampaignEvents or {}

local Events = Convergence.CampaignEvents
local DB = Convergence.Database
local ERROR = Convergence.Constants.ERROR

Events.Cache = Events.Cache or {}
Events.Ready = false

local VALID_STATUS = {
    pending = true,
    available = true,
    active = true,
    awaiting_gm_resolution = true,
    resolved = true,
    cancelled = true
}

local function decode(value, fallback)
    local result = util.JSONToTable(value or "")
    return istable(result) and result or fallback
end

local function normalizeEvent(row)
    return {
        id = row.event_id,
        name = row.name,
        eventType = row.event_type,
        planetID = row.planet_id,
        regionID = row.region_id,
        friendlyFactions = decode(row.friendly_factions_json, {}),
        enemyFactions = decode(row.enemy_factions_json, {}),
        briefing = row.briefing or "",
        difficulty = row.difficulty or "standard",
        priority = row.priority or "normal",
        status = VALID_STATUS[row.status] and row.status or "pending",
        playerControlled = tonumber(row.player_controlled) == 1,
        aiProgressActive = tonumber(row.ai_progress_active) == 1,
        awaitingGMResolution = tonumber(row.awaiting_gm_resolution) == 1,
        autoResolveAt = tonumber(row.auto_resolve_at),
        resolution = decode(row.resolution_json, {}),
        effects = decode(row.effects_json, {}),
        createdAt = tonumber(row.created_at) or os.time(),
        startedAt = tonumber(row.started_at),
        resolvedAt = tonumber(row.resolved_at),
        updatedAt = tonumber(row.updated_at) or os.time()
    }
end

local function makeID(name)
    local base = Convergence.NormalizeID(name)
    if base == "" then base = "campaign_event" end

    local id = base
    local suffix = 1
    while Events.Cache[id] do
        suffix = suffix + 1
        id = base .. "_" .. suffix
    end

    return id
end

local function durationForDifficulty(difficulty)
    local config = Convergence.Config.Campaign or {}
    local minimum = tonumber(config.AIBattleMinimumSeconds) or 3600
    local maximum = tonumber(config.AIBattleMaximumSeconds) or 7200

    difficulty = Convergence.NormalizeID(difficulty)

    if difficulty == "minor" then
        return math.floor(minimum * 0.75)
    elseif difficulty == "major" or difficulty == "extreme" then
        return tonumber(config.MajorBattleMaximumSeconds) or 10800
    end

    return math.random(minimum, maximum)
end

function Events.Initialize()
    local success, rowsOrCode, message =
        DB.Query("SELECT * FROM convergence_campaign_events")

    if not success then
        return false, rowsOrCode, message
    end

    Events.Cache = {}

    for _, row in ipairs(rowsOrCode or {}) do
        local event = normalizeEvent(row)
        Events.Cache[event.id] = event
    end

    Events.Ready = true
    Convergence.Services.Register("campaign_events", Events)
    return true
end

function Events.IsReady()
    return Events.Ready
end

function Events.Get(id)
    return Events.Cache[Convergence.NormalizeID(id)]
end

function Events.GetAll()
    return Events.Cache
end

function Events.Count()
    return table.Count(Events.Cache)
end

function Events.Create(data, context)
    data = istable(data) and data or {}

    local planet = Convergence.PlanetService.Get(data.planetID)
    if not planet then
        return false, ERROR.UNKNOWN_PLANET, "Unknown event planet."
    end

    local name = string.Trim(tostring(data.name or ""))
    if name == "" then
        return false, ERROR.INVALID_ARGUMENT, "Event name is required."
    end

    local id = makeID(name)
    local now = os.time()
    local status = VALID_STATUS[data.status] and data.status or "available"
    local difficulty = Convergence.NormalizeID(data.difficulty or "standard")
    local autoResolveAt = tonumber(data.autoResolveAt)

    if not autoResolveAt and data.aiProgressActive ~= false then
        autoResolveAt = now + durationForDifficulty(difficulty)
    end

    local friendly = istable(data.friendlyFactions)
        and data.friendlyFactions or {"republic", "unsc"}
    local enemy = istable(data.enemyFactions)
        and data.enemyFactions or {}
    local effects = istable(data.effects) and data.effects or {}

    local success, code, message = DB.Execute(string.format(
        [[
            INSERT INTO convergence_campaign_events
            (
                event_id,name,event_type,planet_id,region_id,
                friendly_factions_json,enemy_factions_json,briefing,
                difficulty,priority,status,player_controlled,
                ai_progress_active,awaiting_gm_resolution,auto_resolve_at,
                resolution_json,effects_json,created_at,updated_at
            )
            VALUES
            (
                %s,%s,%s,%s,%s,
                %s,%s,%s,
                %s,%s,%s,0,
                %d,0,%s,
                '{}',%s,%d,%d
            )
        ]],
        DB.Escape(id),
        DB.Escape(name),
        DB.Escape(Convergence.NormalizeID(data.eventType or "battle")),
        DB.Escape(planet:GetID()),
        data.regionID and DB.Escape(data.regionID) or "NULL",
        DB.Escape(util.TableToJSON(friendly) or "[]"),
        DB.Escape(util.TableToJSON(enemy) or "[]"),
        DB.Escape(tostring(data.briefing or "")),
        DB.Escape(difficulty),
        DB.Escape(Convergence.NormalizeID(data.priority or "normal")),
        DB.Escape(status),
        data.aiProgressActive == false and 0 or 1,
        autoResolveAt and tostring(autoResolveAt) or "NULL",
        DB.Escape(util.TableToJSON(effects) or "{}"),
        now,
        now
    ))

    if not success then
        return false, code, message
    end

    local event = {
        id = id,
        name = name,
        eventType = Convergence.NormalizeID(data.eventType or "battle"),
        planetID = planet:GetID(),
        regionID = data.regionID,
        friendlyFactions = friendly,
        enemyFactions = enemy,
        briefing = tostring(data.briefing or ""),
        difficulty = difficulty,
        priority = Convergence.NormalizeID(data.priority or "normal"),
        status = status,
        playerControlled = false,
        aiProgressActive = data.aiProgressActive ~= false,
        awaitingGMResolution = false,
        autoResolveAt = autoResolveAt,
        resolution = {},
        effects = effects,
        createdAt = now,
        updatedAt = now
    }

    Events.Cache[id] = event

    Convergence.Events.Publish("campaign.event.created", {
        event = table.Copy(event)
    }, context or {})

    return true, event
end

function Events.SetPlayerControlled(id, active, context)
    local event = Events.Get(id)
    if not event then
        return false, ERROR.INVALID_ARGUMENT, "Unknown campaign event."
    end

    active = active == true
    event.playerControlled = active
    event.aiProgressActive = not active
    event.awaitingGMResolution = active
    event.status = active and "active" or event.status
    event.startedAt = event.startedAt or os.time()
    event.updatedAt = os.time()

    local success, code, message = DB.Execute(string.format(
        [[
            UPDATE convergence_campaign_events
            SET player_controlled=%d,
                ai_progress_active=%d,
                awaiting_gm_resolution=%d,
                status=%s,
                started_at=%s,
                updated_at=%d
            WHERE event_id=%s
        ]],
        active and 1 or 0,
        active and 0 or 1,
        active and 1 or 0,
        DB.Escape(event.status),
        event.startedAt and tostring(event.startedAt) or "NULL",
        event.updatedAt,
        DB.Escape(event.id)
    ))

    if not success then
        return false, code, message
    end

    Convergence.Events.Publish("campaign.event.player_control.changed", {
        eventID = event.id,
        active = active
    }, context or {})

    return true, event
end

local function applyResolutionEffects(event, outcome)
    local config = Convergence.Config.Campaign or {}
    local stabilityDelta = 0
    local friendlyInfluence = 0
    local enemyInfluence = 0

    if outcome == "major_victory" then
        stabilityDelta = (config.DefaultVictoryStability or 10) + 10
        friendlyInfluence = (config.DefaultInfluenceChange or 15) + 10
        enemyInfluence = -10
    elseif outcome == "victory" then
        stabilityDelta = config.DefaultVictoryStability or 10
        friendlyInfluence = config.DefaultInfluenceChange or 15
        enemyInfluence = -5
    elseif outcome == "draw" then
        stabilityDelta = 0
        friendlyInfluence = 2
        enemyInfluence = 2
    elseif outcome == "defeat" then
        stabilityDelta = config.DefaultDefeatStability or -15
        friendlyInfluence = -5
        enemyInfluence = config.DefaultInfluenceChange or 15
    elseif outcome == "major_defeat" then
        stabilityDelta = (config.DefaultDefeatStability or -15) - 10
        friendlyInfluence = -10
        enemyInfluence = (config.DefaultInfluenceChange or 15) + 10
    end

    if stabilityDelta ~= 0 then
        Convergence.Stability.Add(
            event.planetID,
            stabilityDelta,
            {
                source = "campaign_resolution",
                reason = event.name .. " resolved as " .. outcome
            }
        )
    end

    for _, factionID in ipairs(event.friendlyFactions or {}) do
        if friendlyInfluence ~= 0 then
            Convergence.Influence.Add(
                event.planetID,
                factionID,
                friendlyInfluence,
                {
                    source = "campaign_resolution",
                    reason = event.name .. " friendly result"
                }
            )
        end
    end

    for _, factionID in ipairs(event.enemyFactions or {}) do
        if enemyInfluence ~= 0 then
            Convergence.Influence.Add(
                event.planetID,
                factionID,
                enemyInfluence,
                {
                    source = "campaign_resolution",
                    reason = event.name .. " enemy result"
                }
            )
        end
    end

    return {
        stabilityDelta = stabilityDelta,
        friendlyInfluence = friendlyInfluence,
        enemyInfluence = enemyInfluence
    }
end

function Events.Resolve(id, outcome, notes, context)
    local event = Events.Get(id)
    if not event then
        return false, ERROR.INVALID_ARGUMENT, "Unknown campaign event."
    end

    outcome = Convergence.NormalizeID(outcome)
    local allowed = {
        major_victory = true,
        victory = true,
        draw = true,
        defeat = true,
        major_defeat = true
    }

    if not allowed[outcome] then
        return false, ERROR.INVALID_ARGUMENT, "Invalid event outcome."
    end

    local effects = applyResolutionEffects(event, outcome)
    local now = os.time()

    event.status = "resolved"
    event.playerControlled = false
    event.aiProgressActive = false
    event.awaitingGMResolution = false
    event.resolvedAt = now
    event.updatedAt = now
    event.resolution = {
        outcome = outcome,
        notes = tostring(notes or ""),
        effects = effects
    }

    local success, code, message = DB.Execute(string.format(
        [[
            UPDATE convergence_campaign_events
            SET status='resolved',
                player_controlled=0,
                ai_progress_active=0,
                awaiting_gm_resolution=0,
                resolution_json=%s,
                resolved_at=%d,
                updated_at=%d
            WHERE event_id=%s
        ]],
        DB.Escape(util.TableToJSON(event.resolution) or "{}"),
        now,
        now,
        DB.Escape(event.id)
    ))

    if not success then
        return false, code, message
    end

    Convergence.Events.Publish("campaign.event.resolved", {
        event = table.Copy(event)
    }, context or {})

    return true, event
end

function Events.Extend(id, seconds)
    local event = Events.Get(id)
    if not event then
        return false, ERROR.INVALID_ARGUMENT, "Unknown campaign event."
    end

    local maxExtension =
        tonumber(Convergence.Config.Campaign.MaximumGMExtensionSeconds)
        or 14400
    seconds = math.Clamp(math.floor(tonumber(seconds) or 1800), 60, maxExtension)

    event.autoResolveAt = math.max(event.autoResolveAt or os.time(), os.time())
        + seconds
    event.updatedAt = os.time()

    local success, code, message = DB.Execute(string.format(
        [[
            UPDATE convergence_campaign_events
            SET auto_resolve_at=%d,updated_at=%d
            WHERE event_id=%s
        ]],
        event.autoResolveAt,
        event.updatedAt,
        DB.Escape(event.id)
    ))

    if not success then
        return false, code, message
    end

    return true, event
end

local function autoOutcome(event)
    local friendly = #event.friendlyFactions
    local enemy = #event.enemyFactions
    local roll = math.random()

    if friendly > enemy then roll = roll + 0.12 end
    if enemy > friendly then roll = roll - 0.12 end

    if roll >= 0.78 then return "major_victory" end
    if roll >= 0.55 then return "victory" end
    if roll >= 0.42 then return "draw" end
    if roll >= 0.18 then return "defeat" end
    return "major_defeat"
end

function Events.Process()
    local now = os.time()
    local resolved = 0

    for _, event in pairs(Events.Cache) do
        if event.status ~= "resolved"
            and event.status ~= "cancelled"
            and event.aiProgressActive
            and not event.playerControlled
            and event.autoResolveAt
            and now >= event.autoResolveAt then

            local success = Events.Resolve(
                event.id,
                autoOutcome(event),
                "Automatically resolved by the strategic simulation.",
                {
                    source = "campaign_ai",
                    reason = "AI battle timer expired."
                }
            )

            if success then
                resolved = resolved + 1
            end
        elseif event.playerControlled and event.autoResolveAt
            and now >= event.autoResolveAt then
            event.awaitingGMResolution = true
            event.status = "awaiting_gm_resolution"
        end
    end

    return resolved
end
