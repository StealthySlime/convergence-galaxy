Convergence.GalaxyData = Convergence.GalaxyData or {
    version = "unknown",
    generatedAt = 0,
    viewMode = "player",
    clock = {},
    planets = {},
    factions = {},
    alliances = {},
    fleets = {}
}

function Convergence.RequestGalaxySnapshot(mode)
    mode = Convergence.NormalizeID(
        mode
        or (Convergence.UI and Convergence.UI.Mode)
        or "player"
    )

    net.Start("Convergence.Galaxy.RequestSnapshot")
    net.WriteString(mode)
    net.SendToServer()
end

net.Receive("Convergence.Galaxy.Snapshot", function()
    local mode = net.ReadString()
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

    decoded.viewMode = mode
    Convergence.GalaxyData = decoded

    if Convergence.UI then
        Convergence.UI.Mode = mode
    end

    hook.Run("ConvergenceGalaxySnapshotUpdated", decoded)

    if Convergence.UI and IsValid(Convergence.UI.Frame) then
        Convergence.UI.Refresh()
    end
end)

net.Receive("Convergence.Galaxy.Open", function()
    local mode = net.ReadString()

    timer.Simple(0, function()
        if Convergence.UI then
            Convergence.UI.Open(mode)
        end
    end)
end)
