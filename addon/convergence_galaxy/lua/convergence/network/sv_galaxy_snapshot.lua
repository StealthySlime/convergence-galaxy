util.AddNetworkString("Convergence.Galaxy.Open")
util.AddNetworkString("Convergence.Galaxy.RequestSnapshot")
util.AddNetworkString("Convergence.Galaxy.Snapshot")

local MODE_PLAYER = "player"
local MODE_DIRECTOR = "director"

local function canOpen(ply)
    return IsValid(ply) and ply:IsPlayer()
end

local function normalizeMode(ply, requested)
    requested = Convergence.NormalizeID(requested)

    if requested == MODE_DIRECTOR and IsValid(ply) and ply:IsAdmin() then
        return MODE_DIRECTOR
    end

    return MODE_PLAYER
end

local function getPlayerAllianceIDs()
    local ids = {}

    for id in pairs(Convergence.Factions.GetPlayerFactions()) do
        ids[id] = true
    end

    return ids
end

local function getFleetVisibility(fleet, mode, playerFactionIDs)
    if mode == MODE_DIRECTOR then
        return true, "full"
    end

    if playerFactionIDs[fleet.factionID] then
        return true, "full"
    end

    -- Enemy fleets are hidden by default. A future sensor/intelligence service
    -- can promote them to "contact" or "full" without changing the UI.
    local metadata = fleet.metadata or fleet.orderMetadata or {}
    local visibility = Convergence.NormalizeID(metadata.visibility or "hidden")

    if visibility == "public" then
        return true, "full"
    end

    if visibility == "contact" then
        return true, "contact"
    end

    return false, "hidden"
end

local function buildSnapshot(ply, requestedMode)
    local mode = normalizeMode(ply, requestedMode)
    local playerFactionIDs = getPlayerAllianceIDs()

    local snapshot = {
        version = Convergence.Version,
        generatedAt = os.time(),
        viewMode = mode,
        isDirector = mode == MODE_DIRECTOR,
        clock = Convergence.Clock.GetTimeTable(),
        galaxy = {
            routes = table.Copy(Convergence.Config.Galaxy.Routes or {})
        },
        planets = {},
        factions = {},
        alliances = {},
        fleets = {},
        world = Convergence.World.GetPublicState(),
        campaignEvents = {},
        activeDeployment = Convergence.Deployments.GetActive()
    }

    for id, planet in pairs(Convergence.PlanetService.GetAll()) do
        local dominantFaction, dominantFactionInfluence =
            Convergence.Influence.GetDominantFaction(id)

        local dominantAlliance, dominantAllianceInfluence =
            Convergence.Influence.GetDominantAlliance(id)

        local definition = planet:GetDefinition()

        snapshot.planets[id] = {
            state = planet:ToPublicTable(),
            map = table.Copy(definition.galaxy or {}),
            swu = (
                Convergence.SWUPlanetMapping
                and Convergence.SWUPlanetMapping[id]
                and isvector(Convergence.SWUPlanetMapping[id].position)
            ) and {
                name = Convergence.SWUPlanetMapping[id].navigationName
                    or planet:GetName(),
                pos = {
                    x = Convergence.SWUPlanetMapping[id].position.x,
                    y = Convergence.SWUPlanetMapping[id].position.y,
                    z = Convergence.SWUPlanetMapping[id].position.z
                }
            } or nil,
            regions = mode == MODE_DIRECTOR
                and table.Copy(definition.regions or {})
                or nil,
            influence = Convergence.Influence.GetPlanetInfluence(id),
            dominantFactionID = dominantFaction and dominantFaction.id or nil,
            dominantFactionInfluence = dominantFactionInfluence or 0,
            dominantAllianceID = dominantAlliance and dominantAlliance.id or nil,
            dominantAllianceInfluence = dominantAllianceInfluence or 0
        }
    end

    for id, faction in pairs(Convergence.Factions.GetAll()) do
        snapshot.factions[id] = {
            id = id,
            name = faction.name,
            shortName = faction.shortName,
            alignment = faction.alignment,
            color = {
                r = faction.color.r,
                g = faction.color.g,
                b = faction.color.b,
                a = faction.color.a
            },
            icon = faction.icon,
            description = faction.description
        }
    end

    for id, alliance in pairs(Convergence.Alliances.GetAll()) do
        snapshot.alliances[id] = {
            id = id,
            name = alliance.name,
            shortName = alliance.shortName,
            factions = Convergence.Alliances.GetFactionIDs(id),
            color = {
                r = alliance.color.r,
                g = alliance.color.g,
                b = alliance.color.b,
                a = alliance.color.a
            },
            description = alliance.description
        }
    end

    for id, fleet in pairs(Convergence.Fleets.GetAll()) do
        local visible, intelligenceLevel =
            getFleetVisibility(fleet, mode, playerFactionIDs)

        if visible then
            snapshot.fleets[id] = {
                id = fleet.id,
                name = intelligenceLevel == "contact"
                    and "Unknown Contact"
                    or fleet.name,
                factionID = intelligenceLevel == "contact"
                    and nil
                    or fleet.factionID,
                currentPlanetID = fleet.currentPlanetID,
                destinationPlanetID = fleet.destinationPlanetID,
                departureCampaignSeconds = fleet.departureCampaignSeconds,
                arrivalCampaignSeconds = fleet.arrivalCampaignSeconds,
                strength = intelligenceLevel == "contact"
                    and nil
                    or fleet.strength,
                status = fleet.status,
                progress = Convergence.Fleets.GetTravelProgress(fleet),
                etaCampaignSeconds = Convergence.Fleets.GetETASeconds(fleet),
                orderType = mode == MODE_DIRECTOR
                    and (fleet.orderType or "idle")
                    or nil,
                orderPlanetID = mode == MODE_DIRECTOR
                    and fleet.orderPlanetID
                    or nil,
                intelligenceLevel = intelligenceLevel,
                playerVisible = true
            }
        end
    end

    for id, event in pairs(Convergence.CampaignEvents.GetAll()) do
        if event.status ~= "cancelled"
            and (
                mode == MODE_DIRECTOR
                or event.status == "available"
                or event.status == "active"
                or event.status == "awaiting_gm_resolution"
            ) then
            snapshot.campaignEvents[id] = {
                id = event.id,
                name = event.name,
                eventType = event.eventType,
                planetID = event.planetID,
                regionID = mode == MODE_DIRECTOR and event.regionID or nil,
                friendlyFactions = table.Copy(event.friendlyFactions),
                enemyFactions = mode == MODE_DIRECTOR
                    and table.Copy(event.enemyFactions)
                    or {},
                briefing = event.briefing,
                difficulty = event.difficulty,
                priority = event.priority,
                status = event.status,
                playerControlled = event.playerControlled,
                awaitingGMResolution = event.awaitingGMResolution,
                autoResolveAt = event.autoResolveAt,
                secondsRemaining = event.autoResolveAt
                    and math.max(event.autoResolveAt - os.time(), 0)
                    or nil
            }
        end
    end

    local world = Convergence.World.GetState()
    local currentPlanetData =
        snapshot.planets[world.currentPlanetID or ""]
    local shipPos = world.swuShipPos

    local taskForceMapX =
        currentPlanetData and tonumber(currentPlanetData.map.x) or 0.5
    local taskForceMapY =
        currentPlanetData and tonumber(currentPlanetData.map.y) or 0.5

    -- During hyperspace, display continuous movement using SWU position.
    -- Once arrived/stationed, pin the marker to the authoritative planet node.
    if world.travelStatus == "hyperspace" and isvector(shipPos) then
        local minimumX, maximumX = math.huge, -math.huge
        local minimumY, maximumY = math.huge, -math.huge

        for _, planetData in pairs(snapshot.planets) do
            if planetData.swu and planetData.swu.pos then
                minimumX = math.min(minimumX, planetData.swu.pos.x)
                maximumX = math.max(maximumX, planetData.swu.pos.x)
                minimumY = math.min(minimumY, planetData.swu.pos.y)
                maximumY = math.max(maximumY, planetData.swu.pos.y)
            end
        end

        if minimumX < math.huge and minimumY < math.huge then
            local rangeX = math.max(maximumX - minimumX, 0.001)
            local rangeY = math.max(maximumY - minimumY, 0.001)

            taskForceMapX = math.Clamp(
                (shipPos.x - minimumX) / rangeX,
                0,
                1
            )
            taskForceMapY = math.Clamp(
                1 - ((shipPos.y - minimumY) / rangeY),
                0,
                1
            )
        end
    end

    snapshot.playerTaskForce = {
        name = Convergence.Config.World.PlayerTaskForceName,
        currentPlanetID = world.currentPlanetID,
        destinationPlanetID = world.destinationPlanetID,
        travelStatus = world.travelStatus,
        mapX = taskForceMapX,
        mapY = taskForceMapY,
        swuPosition = mode == MODE_DIRECTOR and isvector(shipPos) and {
            x = shipPos.x,
            y = shipPos.y,
            z = shipPos.z
        } or nil
    }

    if mode == MODE_DIRECTOR then
        snapshot.director = {
            currentMap = game.GetMap(),
            encounterActive = Convergence.World.IsEncounterActive(),
            npcSpawningAllowed = Convergence.World.CanSpawnNPC(),
            navigationAvailable =
                Convergence.Navigation.GetActiveAdapter() ~= nil,
            registeredFleetCount = Convergence.Fleets.Count(),
            registeredPlanetCount = Convergence.PlanetService.Count()
        }
    end

    return snapshot
end

local function sendSnapshot(ply, requestedMode)
    if not canOpen(ply) then
        return
    end

    local mode = normalizeMode(ply, requestedMode)
    local json = util.TableToJSON(buildSnapshot(ply, mode), false) or "{}"
    local compressed = util.Compress(json)

    net.Start("Convergence.Galaxy.Snapshot")
    net.WriteString(mode)
    net.WriteUInt(#compressed, 32)
    net.WriteData(compressed, #compressed)
    net.Send(ply)
end

function Convergence.OpenGalaxyUI(ply, requestedMode)
    if not canOpen(ply) then
        return false
    end

    local mode = normalizeMode(ply, requestedMode)

    net.Start("Convergence.Galaxy.Open")
    net.WriteString(mode)
    net.Send(ply)

    timer.Simple(0, function()
        if IsValid(ply) then
            sendSnapshot(ply, mode)
        end
    end)

    return true
end

net.Receive("Convergence.Galaxy.RequestSnapshot", function(_, ply)
    local requestedMode = net.ReadString()
    sendSnapshot(ply, requestedMode)
end)
