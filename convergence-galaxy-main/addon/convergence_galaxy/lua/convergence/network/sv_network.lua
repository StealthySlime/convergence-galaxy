util.AddNetworkString("ConvergenceGalaxy.PlanetState")
util.AddNetworkString("ConvergenceGalaxy.RequestPlanetState")

Convergence.Network = Convergence.Network or {}
local Network = Convergence.Network

function Network.WritePlanet(planetID)
    local planet = Convergence.GetPlanet(planetID)
    if not planet then return false end

    local stability = Convergence.Stability.Get(planet.id)
    local state = Convergence.GetStabilityState(stability)

    net.WriteString(planet.id)
    net.WriteString(planet.name)
    net.WriteUInt(stability, 7)
    net.WriteString(state.id)
    net.WriteString(state.name)
    net.WriteBool(Convergence.Stability.IsLocked(planet.id))

    return true
end

function Network.SendPlanet(ply, planetID)
    net.Start("ConvergenceGalaxy.PlanetState")
    if not Network.WritePlanet(planetID) then return end
    net.Send(ply)
end

function Network.BroadcastPlanet(planetID)
    net.Start("ConvergenceGalaxy.PlanetState")
    if not Network.WritePlanet(planetID) then return end
    net.Broadcast()
end

net.Receive("ConvergenceGalaxy.RequestPlanetState", function(_, ply)
    local planetID = net.ReadString()
    Network.SendPlanet(ply, planetID)
end)
