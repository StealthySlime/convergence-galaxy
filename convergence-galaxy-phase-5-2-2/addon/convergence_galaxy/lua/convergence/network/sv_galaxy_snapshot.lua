util.AddNetworkString("Convergence.Galaxy.Open")
util.AddNetworkString("Convergence.Galaxy.RequestSnapshot")
util.AddNetworkString("Convergence.Galaxy.Snapshot")

local function canOpen(ply)
    return IsValid(ply) and ply:IsPlayer()
end

local function buildSnapshot()
    local snapshot = {
        version = Convergence.Version,
        generatedAt = os.time(),
        clock = Convergence.Clock.GetTimeTable(),
        galaxy = {
            routes = table.Copy(Convergence.Config.Galaxy.Routes or {})
        },
        planets = {},
        factions = {},
        alliances = {},
        fleets = {},
        world = Convergence.World.GetPublicState()
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
            swu = definition.swu and {
                name = definition.swu.name,
                pos = {
                    x = definition.swu.pos.x,
                    y = definition.swu.pos.y,
                    z = definition.swu.pos.z
                }
            } or nil,
            regions = table.Copy(definition.regions or {}),
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
        snapshot.fleets[id] = {
            id = fleet.id,
            name = fleet.name,
            factionID = fleet.factionID,
            currentPlanetID = fleet.currentPlanetID,
            destinationPlanetID = fleet.destinationPlanetID,
            departureCampaignSeconds = fleet.departureCampaignSeconds,
            arrivalCampaignSeconds = fleet.arrivalCampaignSeconds,
            strength = fleet.strength,
            status = fleet.status,
            progress = Convergence.Fleets.GetTravelProgress(fleet),
            etaCampaignSeconds = Convergence.Fleets.GetETASeconds(fleet),
            orderType = fleet.orderType or "idle",
            orderPlanetID = fleet.orderPlanetID
        }
    end


    local world = Convergence.World.GetState()
    local shipPos = world.swuShipPos

    if isvector(shipPos) then
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

        local rangeX = math.max(maximumX - minimumX, 0.001)
        local rangeY = math.max(maximumY - minimumY, 0.001)

        snapshot.playerTaskForce = {
            name = Convergence.Config.World.PlayerTaskForceName,
            currentPlanetID = world.currentPlanetID,
            destinationPlanetID = world.destinationPlanetID,
            travelStatus = world.travelStatus,
            mapX = math.Clamp((shipPos.x - minimumX) / rangeX, 0, 1),
            mapY = math.Clamp(1 - ((shipPos.y - minimumY) / rangeY), 0, 1),
            swuPosition = {
                x = shipPos.x,
                y = shipPos.y,
                z = shipPos.z
            }
        }
    else
        local current = snapshot.planets[world.currentPlanetID or ""]

        snapshot.playerTaskForce = {
            name = Convergence.Config.World.PlayerTaskForceName,
            currentPlanetID = world.currentPlanetID,
            destinationPlanetID = world.destinationPlanetID,
            travelStatus = world.travelStatus,
            mapX = current and current.map.x or 0.5,
            mapY = current and current.map.y or 0.5
        }
    end

    return snapshot
end

local function sendSnapshot(ply)
    if not canOpen(ply) then
        return
    end

    local json = util.TableToJSON(buildSnapshot(), false) or "{}"
    local compressed = util.Compress(json)

    net.Start("Convergence.Galaxy.Snapshot")
    net.WriteUInt(#compressed, 32)
    net.WriteData(compressed, #compressed)
    net.Send(ply)
end

function Convergence.OpenGalaxyUI(ply)
    if not canOpen(ply) then
        return false
    end

    net.Start("Convergence.Galaxy.Open")
    net.Send(ply)

    timer.Simple(0, function()
        if IsValid(ply) then
            sendSnapshot(ply)
        end
    end)

    return true
end

net.Receive("Convergence.Galaxy.RequestSnapshot", function(_, ply)
    sendSnapshot(ply)
end)
