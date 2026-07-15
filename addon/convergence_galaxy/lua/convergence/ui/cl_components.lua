Convergence.UI = Convergence.UI or {}
Convergence.UI.Components = Convergence.UI.Components or {}

local Components = Convergence.UI.Components
local Theme = Convergence.UI.Theme

function Components.CreateCard(parent, title)
    local panel = vgui.Create("DPanel", parent)
    panel:DockPadding(14, 42, 14, 14)

    panel.Paint = function(self, width, height)
        Theme.DrawPanel(width, height, true)

        draw.SimpleText(
            title,
            "Convergence.UI.Header",
            14,
            20,
            Theme.GetColor("text"),
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )

        surface.SetDrawColor(Theme.GetColor("border"))
        surface.DrawLine(14, 36, width - 14, 36)
    end

    return panel
end

function Components.CreateLabel(parent, text, font, color)
    local label = vgui.Create("DLabel", parent)
    label:SetFont(font or "Convergence.UI.Body")
    label:SetTextColor(color or Theme.GetColor("text"))
    label:SetText(text or "")
    label:SetWrap(true)
    label:SetAutoStretchVertical(true)

    return label
end

function Components.CreateStatRow(parent, labelText, valueText)
    local row = vgui.Create("DPanel", parent)
    row:SetTall(28)
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, 5)
    row.Paint = nil

    local label = Components.CreateLabel(
        row,
        labelText,
        "Convergence.UI.Body",
        Theme.GetColor("textMuted")
    )
    label:Dock(LEFT)
    label:SetWide(170)

    local value = Components.CreateLabel(
        row,
        valueText,
        "Convergence.UI.Body",
        Theme.GetColor("text")
    )
    value:Dock(FILL)
    value:SetContentAlignment(6)

    return row, value
end

function Components.CreateEmptyState(parent, title, description)
    local wrapper = vgui.Create("DPanel", parent)
    wrapper:Dock(FILL)
    wrapper.Paint = nil

    local titleLabel = Components.CreateLabel(
        wrapper,
        title,
        "Convergence.UI.Header",
        Theme.GetColor("text")
    )
    titleLabel:Dock(TOP)
    titleLabel:SetContentAlignment(5)
    titleLabel:DockMargin(30, 80, 30, 10)

    local descriptionLabel = Components.CreateLabel(
        wrapper,
        description,
        "Convergence.UI.Body",
        Theme.GetColor("textMuted")
    )
    descriptionLabel:Dock(TOP)
    descriptionLabel:SetContentAlignment(5)
    descriptionLabel:DockMargin(80, 0, 80, 0)

    return wrapper
end
