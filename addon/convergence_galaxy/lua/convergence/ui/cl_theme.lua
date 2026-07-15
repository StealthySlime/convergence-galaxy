Convergence.UI = Convergence.UI or {}
Convergence.UI.Theme = Convergence.UI.Theme or {}

local Theme = Convergence.UI.Theme

Theme.Name = "Republic Holographic"

Theme.Colors = {
    background = Color(6, 13, 22, 248),
    panel = Color(10, 23, 38, 245),
    panelAlt = Color(15, 34, 55, 245),
    border = Color(45, 130, 200, 180),
    accent = Color(70, 170, 245),
    accentDim = Color(35, 90, 140),
    text = Color(225, 242, 255),
    textMuted = Color(135, 170, 195),
    success = Color(90, 210, 140),
    warning = Color(240, 180, 75),
    danger = Color(235, 85, 85)
}

function Theme.GetColor(name)
    return Theme.Colors[name] or color_white
end

function Theme.DrawPanel(width, height, alternate)
    local color = alternate
        and Theme.GetColor("panelAlt")
        or Theme.GetColor("panel")

    draw.RoundedBox(6, 0, 0, width, height, color)

    surface.SetDrawColor(Theme.GetColor("border"))
    surface.DrawOutlinedRect(0, 0, width, height, 1)
end

function Theme.DrawButton(panel, width, height, text, selected)
    local hovered = panel:IsHovered()
    local fill = Theme.GetColor("panelAlt")

    if selected then
        fill = Theme.GetColor("accentDim")
    elseif hovered then
        fill = Color(25, 58, 88)
    end

    draw.RoundedBox(4, 0, 0, width, height, fill)

    if selected then
        surface.SetDrawColor(Theme.GetColor("accent"))
        surface.DrawRect(0, 0, 3, height)
    end

    draw.SimpleText(
        text,
        "Convergence.UI.Nav",
        14,
        height / 2,
        Theme.GetColor(selected and "text" or "textMuted"),
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_CENTER
    )
end

surface.CreateFont("Convergence.UI.Title", {
    font = "Roboto",
    size = 30,
    weight = 700
})

surface.CreateFont("Convergence.UI.Header", {
    font = "Roboto",
    size = 22,
    weight = 650
})

surface.CreateFont("Convergence.UI.Nav", {
    font = "Roboto",
    size = 17,
    weight = 600
})

surface.CreateFont("Convergence.UI.Body", {
    font = "Roboto",
    size = 16,
    weight = 450
})

surface.CreateFont("Convergence.UI.Small", {
    font = "Roboto",
    size = 13,
    weight = 450
})
