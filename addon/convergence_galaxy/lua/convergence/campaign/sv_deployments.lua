Convergence.Deployments = Convergence.Deployments or {}

local Deployments = Convergence.Deployments
local DB = Convergence.Database
local ERROR = Convergence.Constants.ERROR

Deployments.Active = nil
Deployments.Ready = false

function Deployments.Initialize()
    local serverID = Convergence.Config.Campaign.ServerID or "primary"

    local success, rowOrCode, message = DB.QueryRow(string.format(
        [[
            SELECT * FROM convergence_deployments
            WHERE server_id=%s AND status='active'
            ORDER BY started_at DESC LIMIT 1
        ]],
        DB.Escape(serverID)
    ))

    if not success then
        return false, rowOrCode, message
    end

    local row = rowOrCode

    Deployments.Active = row and {
        id = row.deployment_id,
        serverID = row.server_id,
        eventID = row.event_id,
        status = row.status,
        lockedSnapshot = util.JSONToTable(row.locked_snapshot_json or "{}") or {},
        startedAt = tonumber(row.started_at),
        endedAt = tonumber(row.ended_at)
    } or nil

    Deployments.Ready = true
    Convergence.Services.Register("deployments", Deployments)
    return true
end

function Deployments.GetActive()
    return Deployments.Active
end

function Deployments.Start(eventValue, context)
    if Deployments.Active
        and Convergence.Config.Campaign.SingleActiveDeployment ~= false then
        return false, ERROR.INVALID_ARGUMENT,
            "This server already has an active deployment."
    end

    local event = Convergence.CampaignEvents.Get(eventValue)
    if not event then
        return false, ERROR.INVALID_ARGUMENT, "Unknown campaign event."
    end

    local now = os.time()
    local id = "deployment_" .. event.id .. "_" .. now
    local serverID = Convergence.Config.Campaign.ServerID or "primary"

    local lockedSnapshot = {
        eventID = event.id,
        planetID = event.planetID,
        regionID = event.regionID,
        friendlyFactions = table.Copy(event.friendlyFactions),
        enemyFactions = table.Copy(event.enemyFactions),
        difficulty = event.difficulty,
        campaignTime = Convergence.Clock.GetTimeTable()
    }

    local success, code, message = DB.Execute(string.format(
        [[
            INSERT INTO convergence_deployments
            (deployment_id,server_id,event_id,status,locked_snapshot_json,
             started_at,updated_at)
            VALUES (%s,%s,%s,'active',%s,%d,%d)
        ]],
        DB.Escape(id),
        DB.Escape(serverID),
        DB.Escape(event.id),
        DB.Escape(util.TableToJSON(lockedSnapshot) or "{}"),
        now,
        now
    ))

    if not success then
        return false, code, message
    end

    local controlled, controlCode, controlMessage =
        Convergence.CampaignEvents.SetPlayerControlled(
            event.id,
            true,
            context or {}
        )

    if not controlled then
        DB.Execute(
            "DELETE FROM convergence_deployments WHERE deployment_id="
            .. DB.Escape(id)
        )
        return false, controlCode, controlMessage
    end

    Deployments.Active = {
        id = id,
        serverID = serverID,
        eventID = event.id,
        status = "active",
        lockedSnapshot = lockedSnapshot,
        startedAt = now
    }

    Convergence.Events.Publish("campaign.deployment.started", {
        deployment = table.Copy(Deployments.Active)
    }, context or {})

    return true, Deployments.Active
end

function Deployments.End(outcome, notes, context)
    local deployment = Deployments.Active
    if not deployment then
        return false, ERROR.INVALID_ARGUMENT, "No active deployment."
    end

    local success, eventOrCode, message =
        Convergence.CampaignEvents.Resolve(
            deployment.eventID,
            outcome,
            notes,
            context or {}
        )

    if not success then
        return false, eventOrCode, message
    end

    local now = os.time()

    DB.Execute(string.format(
        [[
            UPDATE convergence_deployments
            SET status='resolved',ended_at=%d,updated_at=%d
            WHERE deployment_id=%s
        ]],
        now,
        now,
        DB.Escape(deployment.id)
    ))

    Convergence.Events.Publish("campaign.deployment.ended", {
        deployment = table.Copy(deployment),
        outcome = outcome
    }, context or {})

    Deployments.Active = nil

    return true, eventOrCode
end
