Convergence.CampaignNotifications =
    Convergence.CampaignNotifications or {}

local Notifications = Convergence.CampaignNotifications

util.AddNetworkString("Convergence.Campaign.Notification")

Notifications.Ready = false

local function send(recipients, data)
    net.Start("Convergence.Campaign.Notification")
    net.WriteString(tostring(data.title or "Galactic Command"))
    net.WriteString(tostring(data.message or ""))
    net.WriteString(Convergence.NormalizeID(data.severity or "info"))
    net.WriteFloat(
        tonumber(data.duration)
        or tonumber(
            Convergence.Config.Campaign.NotificationDurationSeconds
        )
        or 8
    )

    if recipients then
        net.Send(recipients)
    else
        net.Broadcast()
    end
end

function Notifications.Broadcast(data)
    send(nil, data or {})
end

function Notifications.Send(ply, data)
    if IsValid(ply) then
        send(ply, data or {})
    end
end

function Notifications.Initialize()
    if Notifications.Ready then
        return true
    end

    Convergence.Events.Subscribe(
        "campaign.event.created",
        function(event)
            local operation = event.payload.event or {}

            Notifications.Broadcast({
                title = "NEW OPERATION",
                message = string.format(
                    "%s — %s",
                    tostring(operation.name or "Unknown Operation"),
                    tostring(operation.planetID or "Unknown Planet")
                ),
                severity = operation.priority == "critical"
                    and "critical"
                    or "warning"
            })
        end,
        {owner = "campaign_notifications"}
    )

    Convergence.Events.Subscribe(
        "campaign.deployment.started",
        function(event)
            local deployment = event.payload.deployment or {}
            local operation =
                Convergence.CampaignEvents.Get(deployment.eventID)

            Notifications.Broadcast({
                title = "PLAYER DEPLOYMENT",
                message = operation
                    and string.format(
                        "%s at %s",
                        operation.name,
                        operation.planetID
                    )
                    or tostring(deployment.eventID),
                severity = "warning"
            })
        end,
        {owner = "campaign_notifications"}
    )

    Convergence.Events.Subscribe(
        "campaign.event.resolved",
        function(event)
            local operation = event.payload.event or {}
            local resolution = operation.resolution or {}
            local outcome = tostring(resolution.outcome or "resolved")

            Notifications.Broadcast({
                title = string.upper(
                    string.gsub(outcome, "_", " ")
                ),
                message = tostring(operation.name or "Operation")
                    .. " at "
                    .. tostring(operation.planetID or "Unknown"),
                severity = string.find(outcome, "victory", 1, true)
                    and "success"
                    or string.find(outcome, "defeat", 1, true)
                        and "danger"
                        or "info"
            })
        end,
        {owner = "campaign_notifications"}
    )

    if Convergence.Config.Campaign.NotifyPlayersOfFleetArrivals ~= false then
        Convergence.Events.Subscribe(
            "fleet.arrived",
            function(event)
                local fleet = event.payload.fleet or {}

                Notifications.Broadcast({
                    title = "FLEET ARRIVAL",
                    message = string.format(
                        "%s arrived at %s.",
                        tostring(fleet.name or "Fleet"),
                        tostring(fleet.currentPlanetID or "Unknown")
                    ),
                    severity = "info",
                    duration = 6
                })
            end,
            {owner = "campaign_notifications"}
        )
    end

    if Convergence.Config.Campaign.NotifyPlayersOfTaskForceTravel ~= false then
        Convergence.Events.Subscribe(
            "world.arrived",
            function(event)
                Notifications.Broadcast({
                    title = "TASK FORCE ARRIVAL",
                    message = "Arrived at "
                        .. tostring(
                            event.payload.currentPlanetID
                            or "Unknown"
                        )
                        .. ".",
                    severity = "success",
                    duration = 6
                })
            end,
            {owner = "campaign_notifications"}
        )
    end

    Notifications.Ready = true
    Convergence.Services.Register("campaign_notifications", Notifications)

    return true
end
