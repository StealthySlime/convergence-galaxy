util.AddNetworkString("Convergence.Director.Action")
util.AddNetworkString("Convergence.Director.Result")

local ACTION_CREATE = "create_operation"
local ACTION_DEPLOY = "deploy"
local ACTION_RESOLVE = "resolve"
local ACTION_EXTEND = "extend"
local ACTION_ENCOUNTER_START = "encounter_start"
local ACTION_ENCOUNTER_END = "encounter_end"
local ACTION_PREPARE_REGION = "prepare_region"

local function sendResult(ply, success, message)
    net.Start("Convergence.Director.Result")
    net.WriteBool(success == true)
    net.WriteString(tostring(message or ""))
    net.Send(ply)
end

local function context(ply, reason)
    return {
        actor = ply,
        source = "director_ui",
        reason = reason
    }
end

local function readStringList()
    local count = math.min(net.ReadUInt(8), 16)
    local result = {}

    for _ = 1, count do
        result[#result + 1] = Convergence.NormalizeID(net.ReadString())
    end

    return result
end

net.Receive("Convergence.Director.Action", function(_, ply)
    if not Convergence.Permissions.CanManageCampaign(ply) then
        sendResult(ply, false, "Campaign-management permission denied.")
        return
    end

    local action = Convergence.NormalizeID(net.ReadString())

    if action == ACTION_CREATE then
        local name = string.Trim(net.ReadString())
        local planetID = Convergence.NormalizeID(net.ReadString())
        local regionID = Convergence.NormalizeID(net.ReadString())
        local eventType = Convergence.NormalizeID(net.ReadString())
        local difficulty = Convergence.NormalizeID(net.ReadString())
        local priority = Convergence.NormalizeID(net.ReadString())
        local briefing = string.Trim(net.ReadString())
        local friendly = readStringList()
        local enemy = readStringList()

        local success, result, message =
            Convergence.CampaignEvents.Create({
                name = name,
                planetID = planetID,
                regionID = regionID ~= "" and regionID or nil,
                eventType = eventType ~= "" and eventType or "battle",
                difficulty = difficulty ~= "" and difficulty or "standard",
                priority = priority ~= "" and priority or "normal",
                briefing = briefing,
                friendlyFactions = #friendly > 0
                    and friendly
                    or {"republic", "unsc"},
                enemyFactions = enemy,
                aiProgressActive = true,
                status = "available"
            }, context(ply, "GM created operation through Director UI."))

        sendResult(
            ply,
            success,
            success
                and ("Created operation: " .. result.name)
                or string.format("[%s] %s", tostring(result), tostring(message))
        )
        return
    end

    if action == ACTION_DEPLOY then
        local eventID = Convergence.NormalizeID(net.ReadString())
        local success, result, message = Convergence.Deployments.Start(
            eventID,
            context(ply, "GM deployed players through Director UI.")
        )

        sendResult(
            ply,
            success,
            success
                and ("Player deployment started: " .. result.eventID)
                or string.format("[%s] %s", tostring(result), tostring(message))
        )
        return
    end

    if action == ACTION_RESOLVE then
        local outcome = Convergence.NormalizeID(net.ReadString())
        local notes = string.Trim(net.ReadString())
        local success, result, message = Convergence.Deployments.End(
            outcome,
            notes,
            context(ply, "GM resolved deployment through Director UI.")
        )

        sendResult(
            ply,
            success,
            success
                and ("Deployment resolved: " .. result.name)
                or string.format("[%s] %s", tostring(result), tostring(message))
        )
        return
    end

    if action == ACTION_EXTEND then
        local eventID = Convergence.NormalizeID(net.ReadString())
        local seconds = math.floor(net.ReadUInt(32))
        local success, result, message =
            Convergence.CampaignEvents.Extend(eventID, seconds)

        sendResult(
            ply,
            success,
            success
                and ("Extended operation: " .. result.name)
                or string.format("[%s] %s", tostring(result), tostring(message))
        )
        return
    end

    if action == ACTION_ENCOUNTER_START then
        Convergence.World.SetEncounterActive(true, context(
            ply,
            "GM activated encounter through Director UI."
        ))
        sendResult(ply, true, "Encounter activated; NPC spawning is now allowed.")
        return
    end

    if action == ACTION_ENCOUNTER_END then
        Convergence.World.SetEncounterActive(false, context(
            ply,
            "GM ended encounter through Director UI."
        ))
        sendResult(ply, true, "Encounter ended; NPC spawning is disabled.")
        return
    end

    if action == ACTION_PREPARE_REGION then
        local regionID = Convergence.NormalizeID(net.ReadString())
        local success, result, message =
            Convergence.World.PrepareMapTransition(regionID)

        sendResult(
            ply,
            success,
            success
                and string.format(
                    "Prepared %s. GM may change to %s.",
                    result.name,
                    result.map
                )
                or string.format("[%s] %s", tostring(result), tostring(message))
        )
        return
    end

    sendResult(ply, false, "Unknown Director action.")
end)
