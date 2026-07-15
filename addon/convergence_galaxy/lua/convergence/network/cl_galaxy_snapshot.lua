Convergence.GalaxyData = Convergence.GalaxyData or {
    version = "unknown",
    generatedAt = 0,
    clock = {},
    planets = {},
    factions = {},
    alliances = {}
}

function Convergence.RequestGalaxySnapshot()
    net.Start("Convergence.Galaxy.RequestSnapshot")
    net.SendToServer()
end

net.Receive("Convergence.Galaxy.Snapshot", function()
    local length = net.ReadUInt(32)

    if length <= 0 or length > 1024 * 1024 then
        return
    end

    local compressed = net.ReadData(length)
    local json = util.Decompress(compressed)

    if not json then
        return
    end

    local decoded = util.JSONToTable(json)

    if not istable(decoded) then
        return
    end

    Convergence.GalaxyData = decoded

    hook.Run("ConvergenceGalaxySnapshotUpdated", decoded)

    if Convergence.UI and IsValid(Convergence.UI.Frame) then
        Convergence.UI.Refresh()
    end
end)

net.Receive("Convergence.Galaxy.Open", function()
    timer.Simple(0, function()
        if Convergence.UI then
            Convergence.UI.Open()
        end
    end)
end)
