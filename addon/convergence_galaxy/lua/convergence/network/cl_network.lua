Convergence.ClientPlanets = Convergence.ClientPlanets or {}

net.Receive("ConvergenceGalaxy.PlanetState", function()
    local planetID = net.ReadString()
    local incoming = {
        id = planetID,
        name = net.ReadString(),
        stability = net.ReadUInt(7),
        stateID = net.ReadString(),
        stateName = net.ReadString(),
        locked = net.ReadBool(),
        revision = net.ReadUInt(32)
    }

    local existing = Convergence.ClientPlanets[planetID]

    if existing and existing.revision and existing.revision > incoming.revision then
        return
    end

    Convergence.ClientPlanets[planetID] = incoming

    hook.Run(
        "ConvergenceClientPlanetUpdated",
        planetID,
        Convergence.ClientPlanets[planetID]
    )
end)

function Convergence.RequestPlanetState(planetID)
    net.Start("ConvergenceGalaxy.RequestPlanetState")
    net.WriteString(Convergence.NormalizeID(planetID))
    net.SendToServer()
end
