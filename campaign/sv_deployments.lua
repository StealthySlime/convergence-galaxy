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

function Deployments.Start(eventValue, context, selectedRegionID, selectedMap)
    local event = Convergence.CampaignEvents.Get(eventValue)

    if not event then
        return false, ERROR.INVALID_ARGUMENT, "Unknown campaign event."
    end

    local updatingExisting =
        Deployments.Active
        and Deployments.Active.eventID == event.id

    if Deployments.Active
        and not updatingExisting
        and Convergence.Config.Campaign.SingleActiveDeployment ~= false then
        return false, ERROR.INVALID_ARGUMENT,
            "This server already has an active deployment."
    end
    local world = Convergence.World.GetState()
    local currentPlanetID = Convergence.NormalizeID(
        world.currentPlanetID or ""
    )

    if currentPlanetID ~= event.planetID then
        local currentPlanet = Convergence.PlanetService.Get(currentPlanetID)
        local targetPlanet = Convergence.PlanetService.Get(event.planetID)

        return false, ERROR.INVALID_ARGUMENT, string.format(
            "Task force must be at %s before deploying. Current location: %s.",
            targetPlanet and targetPlanet:GetName() or event.planetID,
            currentPlanet and currentPlanet:GetName() or (
                currentPlanetID ~= "" and currentPlanetID or "Unknown"
            )
        )
    end

    selectedRegionID = Convergence.NormalizeID(
        selectedRegionID or event.regionID or ""
    )
    selectedMap = string.Trim(tostring(selectedMap or ""))

    local configuredRegions =
        Convergence.World.GetRegions(event.planetID)
    local selectedRegion = nil
    local customMap = false

    if #configuredRegions > 0 then
        if selectedRegionID == "" then
            return false, ERROR.INVALID_ARGUMENT,
                "Select one of the configured deployment regions."
        end

        selectedRegion = Convergence.World.FindRegion(
            event.planetID,
            selectedRegionID
        )

        if not selectedRegion then
            return false, ERROR.INVALID_ARGUMENT,
                "Selected deployment map is not valid for this planet."
        end

        selectedMap = tostring(selectedRegion.map or "")

        if selectedMap == "" then
            return false, ERROR.INVALID_ARGUMENT,
                "The selected deployment region has no GMod map configured."
        end
    else
        if selectedMap == "" then
            return false, ERROR.INVALID_ARGUMENT,
                "Select a mounted GMod map for this deployment."
        end

        selectedMap = string.StripExtension(
            string.GetFileFromFilename(selectedMap)
        )

        if selectedMap == ""
            or not file.Exists("maps/" .. selectedMap .. ".bsp", "GAME") then
            return false, ERROR.INVALID_ARGUMENT,
                "Selected GMod map is not mounted on the server."
        end

        customMap = true
        selectedRegion = {
            id = "custom_map",
            name = selectedMap,
            map = selectedMap,
            custom = true
        }
    end

    if updatingExisting then
        local prepared, prepareCode, prepareMessage

        if customMap then
            prepared, prepareCode, prepareMessage =
                Convergence.World.PrepareCustomMapTransition(selectedMap)
        else
            prepared, prepareCode, prepareMessage =
                Convergence.World.PrepareMapTransition(selectedRegion.id)
        end

        if not prepared then
            return false, prepareCode, prepareMessage
        end

        Deployments.Active.lockedSnapshot =
            Deployments.Active.lockedSnapshot or {}
        Deployments.Active.lockedSnapshot.regionID = selectedRegion.id
        Deployments.Active.lockedSnapshot.regionName = selectedRegion.name
        Deployments.Active.lockedSnapshot.map = selectedMap
        Deployments.Active.lockedSnapshot.customMap = customMap

        DB.Execute(string.format(
            [[UPDATE convergence_deployments
            SET locked_snapshot_json=%s
            WHERE deployment_id=%s]],
            DB.Escape(
                util.TableToJSON(
                    Deployments.Active.lockedSnapshot
                ) or "{}"
            ),
            DB.Escape(Deployments.Active.id)
        ))

        Convergence.Events.Publish("campaign.deployment.map_updated", {
            deployment = table.Copy(Deployments.Active)
        }, context or {})

        return true, Deployments.Active,
            "Deployment map updated to " .. selectedMap .. "."
    end

    local now = os.time()
    local id = "deployment_" .. event.id .. "_" .. now
    local serverID = Convergence.Config.Campaign.ServerID or "primary"

    local lockedSnapshot = {
        eventID = event.id,
        planetID = event.planetID,
        regionID = selectedRegion and selectedRegion.id or nil,
        regionName = selectedRegion and selectedRegion.name or nil,
        map = selectedMap ~= "" and selectedMap or nil,
        customMap = customMap,
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

    if selectedRegion then
        local prepared, prepareCode, prepareMessage

        if customMap then
            prepared, prepareCode, prepareMessage =
                Convergence.World.PrepareCustomMapTransition(
                    selectedMap
                )
        else
            prepared, prepareCode, prepareMessage =
                Convergence.World.PrepareMapTransition(
                    selectedRegion.id
                )
        end

        if not prepared then
            DB.Execute(
                "DELETE FROM convergence_deployments WHERE deployment_id="
                .. DB.Escape(id)
            )

            Convergence.CampaignEvents.SetPlayerControlled(
                event.id,
                false,
                context or {}
            )

            return false, prepareCode, prepareMessage
        end
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
