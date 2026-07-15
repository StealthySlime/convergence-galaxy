Convergence.Director = Convergence.Director or {}

local Director = Convergence.Director

function Director.Send(action, writer)
    net.Start("Convergence.Director.Action")
    net.WriteString(action)

    if isfunction(writer) then
        writer()
    end

    net.SendToServer()
end

function Director.WriteList(values)
    values = istable(values) and values or {}
    net.WriteUInt(math.min(#values, 16), 8)

    for index = 1, math.min(#values, 16) do
        net.WriteString(tostring(values[index]))
    end
end

net.Receive("Convergence.Director.Result", function()
    local success = net.ReadBool()
    local message = net.ReadString()

    chat.AddText(
        success and Color(80, 220, 140) or Color(240, 90, 90),
        "[Convergence] ",
        color_white,
        message
    )

    if success then
        timer.Simple(0.2, function()
            Convergence.RequestGalaxySnapshot(
                Convergence.UI and Convergence.UI.Mode or "director"
            )
        end)
    end
end)
