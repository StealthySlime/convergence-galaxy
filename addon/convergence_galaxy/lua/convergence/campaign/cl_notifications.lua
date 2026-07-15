Convergence.CampaignNotificationsClient =
    Convergence.CampaignNotificationsClient or {}

local Client = Convergence.CampaignNotificationsClient

Client.Queue = Client.Queue or {}
Client.Active = Client.Active or nil

local colors = {
    info = Color(65, 165, 225),
    warning = Color(245, 181, 62),
    critical = Color(245, 85, 85),
    danger = Color(225, 70, 70),
    success = Color(82, 208, 135)
}

surface.CreateFont("Convergence.Notification.Title", {
    font = "Roboto Condensed",
    size = 28,
    weight = 900
})

surface.CreateFont("Convergence.Notification.Body", {
    font = "Roboto",
    size = 20,
    weight = 500
})

local function activateNext()
    if Client.Active or #Client.Queue == 0 then
        return
    end

    Client.Active = table.remove(Client.Queue, 1)
    Client.Active.startedAt = CurTime()
end

net.Receive("Convergence.Campaign.Notification", function()
    Client.Queue[#Client.Queue + 1] = {
        title = net.ReadString(),
        message = net.ReadString(),
        severity = net.ReadString(),
        duration = math.max(net.ReadFloat(), 2)
    }

    activateNext()
end)

hook.Add("HUDPaint", "Convergence.CampaignNotifications", function()
    activateNext()

    local active = Client.Active

    if not active then
        return
    end

    local elapsed = CurTime() - active.startedAt
    local duration = active.duration

    if elapsed >= duration then
        Client.Active = nil
        activateNext()
        return
    end

    local fade = 1

    if elapsed < 0.35 then
        fade = math.Clamp(elapsed / 0.35, 0, 1)
    elseif elapsed > duration - 0.5 then
        fade = math.Clamp((duration - elapsed) / 0.5, 0, 1)
    end

    local width = math.min(ScrW() * 0.46, 720)
    local height = 112
    local x = (ScrW() - width) / 2
    local y = ScrH() * 0.12
    local accent = colors[active.severity] or colors.info

    draw.RoundedBox(
        6,
        x,
        y,
        width,
        height,
        Color(2, 13, 24, math.floor(235 * fade))
    )

    surface.SetDrawColor(
        accent.r,
        accent.g,
        accent.b,
        math.floor(255 * fade)
    )
    surface.DrawRect(x, y, 6, height)

    draw.SimpleText(
        active.title,
        "Convergence.Notification.Title",
        x + 24,
        y + 22,
        Color(
            accent.r,
            accent.g,
            accent.b,
            math.floor(255 * fade)
        ),
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_TOP
    )

    draw.SimpleText(
        active.message,
        "Convergence.Notification.Body",
        x + 24,
        y + 63,
        Color(230, 240, 248, math.floor(255 * fade)),
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_TOP
    )
end)
