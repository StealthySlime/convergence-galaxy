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
        alliances = {}
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
