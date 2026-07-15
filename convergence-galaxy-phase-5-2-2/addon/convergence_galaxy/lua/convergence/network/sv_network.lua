util.AddNetworkString("ConvergenceGalaxy.PlanetState")
util.AddNetworkString("ConvergenceGalaxy.RequestPlanetState")

Convergence.Network = Convergence.Network or {}
local Network = Convergence.Network

function Network.WritePlanet(planetID)
    local planet = Convergence.PlanetService.Get(planetID)

    if not planet then
        return false
    end

    local data = planet:ToPublicTable()

    net.WriteString(data.id)
    net.WriteString(data.name)
    net.WriteUInt(data.stability, 7)
    net.WriteString(data.stateID)
    net.WriteString(data.stateName)
    net.WriteBool(data.locked)
    net.WriteUInt(math.max(data.revision, 0), 32)

    return true
end

function Network.SendPlanet(ply, planetID)
    net.Start("ConvergenceGalaxy.PlanetState")

    if not Network.WritePlanet(planetID) then
        return false
    end

    net.Send(ply)
    return true
end

function Network.BroadcastPlanet(planetID)
    net.Start("ConvergenceGalaxy.PlanetState")

    if not Network.WritePlanet(planetID) then
        return false
    end

    net.Broadcast()
    return true
end

net.Receive("ConvergenceGalaxy.RequestPlanetState", function(_, ply)
    local planetID = net.ReadString()
    Network.SendPlanet(ply, planetID)
end)
