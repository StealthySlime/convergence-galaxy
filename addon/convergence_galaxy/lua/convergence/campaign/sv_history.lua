Convergence.CampaignHistory = Convergence.CampaignHistory or {}

local History = Convergence.CampaignHistory
local DB = Convergence.Database
local ERROR = Convergence.Constants.ERROR

History.Cache = History.Cache or {}
History.Ready = false
History.Subscriptions = History.Subscriptions or {}

local function decode(value)
    local decoded = util.JSONToTable(value or "")
    return istable(decoded) and decoded or {}
end

local function normalizeRow(row)
    return {
        id = tonumber(row.history_id),
        category = row.category,
        eventName = row.event_name,
        title = row.title,
        summary = row.summary or "",
        planetID = row.planet_id,
        factionID = row.faction_id,
        fleetID = row.fleet_id,
        operationID = row.operation_id,
        outcome = row.outcome,
        severity = row.severity or "info",
        details = decode(row.details_json),
        campaignDay = tonumber(row.campaign_day) or 1,
        campaignHour = tonumber(row.campaign_hour) or 0,
        campaignMinute = tonumber(row.campaign_minute) or 0,
        campaignSeconds = tonumber(row.campaign_seconds) or 0,
        createdAt = tonumber(row.created_at) or os.time()
    }
end

local function addToCache(entry)
    History.Cache[#History.Cache + 1] = entry

    local limit = math.max(
        tonumber(Convergence.Config.Campaign.HistorySnapshotLimit) or 250,
        25
    )

    while #History.Cache > limit do
        table.remove(History.Cache, 1)
    end
end

local function planetName(planetID)
    local planet = Convergence.PlanetService.Get(planetID)
    return planet and planet:GetName() or tostring(planetID or "Unknown")
end

local function factionName(factionID)
    local faction = Convergence.Factions.Get(factionID)
    return faction and faction.name or tostring(factionID or "Unknown")
end

function History.IsReady()
    return History.Ready == true
end

function History.GetAll()
    return History.Cache
end

function History.GetRecent(limit)
    limit = math.Clamp(
        math.floor(tonumber(limit) or 100),
        1,
        math.max(#History.Cache, 1)
    )

    local result = {}
    local first = math.max(#History.Cache - limit + 1, 1)

    for index = first, #History.Cache do
        result[#result + 1] = table.Copy(History.Cache[index])
    end

    return result
end

function History.Record(data)
    if not History.Ready then
        return false, ERROR.INVALID_ARGUMENT, "Campaign history is not ready."
    end

    data = istable(data) and data or {}
    local title = string.Trim(tostring(data.title or ""))

    if title == "" then
        return false, ERROR.INVALID_ARGUMENT, "History title is required."
    end

    local time = Convergence.Clock.GetTimeTable()
    local createdAt = os.time()
    local category = Convergence.NormalizeID(data.category or "campaign")
    local eventName = Convergence.Events.NormalizeName(
        data.eventName or "campaign.history"
    )
    local severity = Convergence.NormalizeID(data.severity or "info")
    local details = istable(data.details) and data.details or {}

    local success, code, message = DB.Execute(string.format(
        [[
            INSERT INTO convergence_campaign_history
            (
                category,event_name,title,summary,planet_id,faction_id,
                fleet_id,operation_id,outcome,severity,details_json,
                campaign_day,campaign_hour,campaign_minute,
                campaign_seconds,created_at
            )
            VALUES
            (
                %s,%s,%s,%s,%s,%s,
                %s,%s,%s,%s,%s,
                %d,%d,%d,%f,%d
            )
        ]],
        DB.Escape(category),
        DB.Escape(eventName),
        DB.Escape(title),
        DB.Escape(tostring(data.summary or "")),
        data.planetID and DB.Escape(data.planetID) or "NULL",
        data.factionID and DB.Escape(data.factionID) or "NULL",
        data.fleetID and DB.Escape(data.fleetID) or "NULL",
        data.operationID and DB.Escape(data.operationID) or "NULL",
        data.outcome and DB.Escape(data.outcome) or "NULL",
        DB.Escape(severity),
        DB.Escape(util.TableToJSON(details) or "{}"),
        time.day,
        time.hour,
        time.minute,
        time.campaignSeconds,
        createdAt
    ))

    if not success then
        return false, code, message
    end

    local id = tonumber(sql.QueryValue("SELECT last_insert_rowid()")) or 0
    local entry = {
        id = id,
        category = category,
        eventName = eventName,
        title = title,
        summary = tostring(data.summary or ""),
        planetID = data.planetID,
        factionID = data.factionID,
        fleetID = data.fleetID,
        operationID = data.operationID,
        outcome = data.outcome,
        severity = severity,
        details = table.Copy(details),
        campaignDay = time.day,
        campaignHour = time.hour,
        campaignMinute = time.minute,
        campaignSeconds = time.campaignSeconds,
        createdAt = createdAt
    }

    addToCache(entry)

    hook.Run("ConvergenceCampaignHistoryRecorded", entry)
    return true, entry
end

local function subscribe(name, callback)
    local success, token = Convergence.Events.Subscribe(
        name,
        callback,
        {
            owner = "campaign_history",
            priority = -100
        }
    )

    if success then
        History.Subscriptions[#History.Subscriptions + 1] = {
            name = name,
            token = token
        }
    end
end

function History.BindEvents()
    Convergence.Events.UnsubscribeOwner("campaign_history")
    History.Subscriptions = {}

    subscribe("campaign.event.created", function(event)
        local operation = event.payload.event or {}

        History.Record({
            category = "operation",
            eventName = event.name,
            title = "New Operation: " .. tostring(operation.name or "Unknown"),
            summary = string.format(
                "%s operation created at %s.",
                string.upper(operation.difficulty or "standard"),
                planetName(operation.planetID)
            ),
            planetID = operation.planetID,
            operationID = operation.id,
            severity = operation.priority == "critical"
                and "critical"
                or operation.priority == "high"
                    and "warning"
                    or "info",
            details = {
                status = operation.status,
                eventType = operation.eventType,
                difficulty = operation.difficulty,
                priority = operation.priority
            }
        })
    end)

    subscribe("campaign.deployment.started", function(event)
        local deployment = event.payload.deployment or {}
        local operation = Convergence.CampaignEvents.Get(deployment.eventID)

        History.Record({
            category = "deployment",
            eventName = event.name,
            title = "Player Deployment Started",
            summary = operation
                and string.format(
                    "%s deployed to %s.",
                    operation.name,
                    planetName(operation.planetID)
                )
                or ("Deployment started for " .. tostring(deployment.eventID)),
            planetID = operation and operation.planetID or nil,
            operationID = deployment.eventID,
            severity = "warning",
            details = deployment.lockedSnapshot or {}
        })
    end)

    subscribe("campaign.event.resolved", function(event)
        local operation = event.payload.event or {}
        local resolution = operation.resolution or {}
        local outcome = tostring(resolution.outcome or "resolved")

        History.Record({
            category = "operation",
            eventName = event.name,
            title = string.format(
                "%s — %s",
                tostring(operation.name or "Operation"),
                string.upper(outcome)
            ),
            summary = string.format(
                "Operation at %s resolved as %s.",
                planetName(operation.planetID),
                string.gsub(outcome, "_", " ")
            ),
            planetID = operation.planetID,
            operationID = operation.id,
            outcome = outcome,
            severity = string.find(outcome, "victory", 1, true)
                and "success"
                or string.find(outcome, "defeat", 1, true)
                    and "danger"
                    or "info",
            details = resolution
        })
    end)

    subscribe("ai.decision.made", function(event)
        local decision = event.payload.decision or {}

        History.Record({
            category = "ai_decision",
            eventName = event.name,
            title = string.format(
                "%s Strategic Decision",
                string.upper(tostring(decision.factionID or "Unknown"))
            ),
            summary = tostring(decision.detail or decision.action or ""),
            planetID = decision.planetID,
            factionID = decision.factionID,
            severity = decision.action == "invade"
                or decision.action == "generate_operation"
                    and "warning"
                    or "info",
            details = decision
        })
    end)

    subscribe("fleet.departed", function(event)
        local fleet = event.payload.fleet or {}

        History.Record({
            category = "fleet",
            eventName = event.name,
            title = tostring(fleet.name or "Fleet") .. " Departed",
            summary = string.format(
                "%s departed %s for %s.",
                tostring(fleet.name or "Fleet"),
                planetName(fleet.currentPlanetID),
                planetName(fleet.destinationPlanetID)
            ),
            planetID = fleet.destinationPlanetID,
            factionID = fleet.factionID,
            fleetID = fleet.id,
            severity = "info",
            details = fleet
        })
    end)

    subscribe("fleet.arrived", function(event)
        local fleet = event.payload.fleet or {}

        History.Record({
            category = "fleet",
            eventName = event.name,
            title = tostring(fleet.name or "Fleet") .. " Arrived",
            summary = string.format(
                "%s arrived at %s.",
                tostring(fleet.name or "Fleet"),
                planetName(fleet.currentPlanetID)
            ),
            planetID = fleet.currentPlanetID,
            factionID = fleet.factionID,
            fleetID = fleet.id,
            severity = "info",
            details = fleet
        })
    end)

    subscribe("world.hyperspace.started", function(event)
        local destination = event.payload.destinationPlanetID

        History.Record({
            category = "task_force",
            eventName = event.name,
            title = "Task Force Entered Hyperspace",
            summary = "Destination: " .. planetName(destination),
            planetID = destination,
            severity = "info",
            details = event.payload
        })
    end)

    subscribe("world.arrived", function(event)
        local currentPlanetID = event.payload.currentPlanetID

        History.Record({
            category = "task_force",
            eventName = event.name,
            title = "Task Force Arrived",
            summary = "Arrived at " .. planetName(currentPlanetID) .. ".",
            planetID = currentPlanetID,
            severity = "success",
            details = event.payload
        })
    end)

    subscribe("world.encounter.changed", function(event)
        local active = event.payload.active == true

        History.Record({
            category = "encounter",
            eventName = event.name,
            title = active and "Encounter Started" or "Encounter Ended",
            summary = active
                and "NPC spawning and live encounter controls were enabled."
                or "The live encounter was closed.",
            planetID = Convergence.World.GetState().currentPlanetID,
            severity = active and "warning" or "info",
            details = event.payload
        })
    end)
end

function History.Initialize()
    local limit = math.max(
        tonumber(Convergence.Config.Campaign.HistorySnapshotLimit) or 250,
        25
    )

    local success, rowsOrCode, message = DB.Query(string.format(
        [[
            SELECT * FROM convergence_campaign_history
            ORDER BY history_id DESC
            LIMIT %d
        ]],
        limit
    ))

    if not success then
        return false, rowsOrCode, message
    end

    History.Cache = {}

    for index = #(rowsOrCode or {}), 1, -1 do
        addToCache(normalizeRow(rowsOrCode[index]))
    end

    History.Ready = true
    History.BindEvents()
    Convergence.Services.Register("campaign_history", History)

    return true
end
