Convergence.ClientPlanets = Convergence.ClientPlanets or {}

net.Receive("ConvergenceGalaxy.PlanetState", function()
    local planetID = net.ReadString()

    Convergence.ClientPlanets[planetID] = {
        id = planetID,
        name = net.ReadString(),
        stability = net.ReadUInt(7),
        stateID = net.ReadString(),
        stateName = net.ReadString(),
        locked = net.ReadBool()
    }

    hook.Run("ConvergenceClientPlanetUpdated", planetID, Convergence.ClientPlanets[planetID])
end)

function Convergence.RequestPlanetState(planetID)
    net.Start("ConvergenceGalaxy.RequestPlanetState")
    net.WriteString(Convergence.NormalizeID(planetID))
    net.SendToServer()
end
