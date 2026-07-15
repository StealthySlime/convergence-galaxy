Convergence.UI = Convergence.UI or {}

local UI = Convergence.UI

local function addLabel(parent, text)
    local label = vgui.Create("DLabel", parent)
    label:Dock(TOP)
    label:SetTall(24)
    label:SetText(text)
    label:SetFont("Convergence.UI.Body")
    label:SetTextColor(UI.Theme.GetColor("textMuted"))
    return label
end

local function addEntry(parent, placeholder)
    local entry = vgui.Create("DTextEntry", parent)
    entry:Dock(TOP)
    entry:SetTall(34)
    entry:DockMargin(0, 0, 0, 8)
    entry:SetPlaceholderText(placeholder or "")
    return entry
end

function UI.OpenOperationEditor()
    if UI.Mode ~= "director" then
        return
    end

    local data = Convergence.GalaxyData or {}
    local frame = vgui.Create("DFrame")
    frame:SetSize(math.min(ScrW() * 0.55, 820), math.min(ScrH() * 0.85, 760))
    frame:Center()
    frame:SetTitle("Create Campaign Operation")
    frame:MakePopup()

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)
    scroll:DockMargin(12, 8, 12, 12)

    addLabel(scroll, "Operation Name")
    local name = addEntry(scroll, "Operation Iron Shield")

    addLabel(scroll, "Planet")
    local planet = vgui.Create("DComboBox", scroll)
    planet:Dock(TOP)
    planet:SetTall(34)
    planet:DockMargin(0, 0, 0, 8)

    for id, planetData in SortedPairs(data.planets or {}) do
        local display = planetData.state and planetData.state.name or id
        planet:AddChoice(display, id)
    end

    addLabel(scroll, "Region ID (optional)")
    local region = addEntry(scroll, "orbit / surface / custom")

    addLabel(scroll, "Mission Type")
    local eventType = vgui.Create("DComboBox", scroll)
    eventType:Dock(TOP)
    eventType:SetTall(34)
    eventType:DockMargin(0, 0, 0, 8)
    for _, value in ipairs({
        "battle", "defense", "assault", "boarding",
        "escort", "recon", "rescue", "investigation"
    }) do
        eventType:AddChoice(string.upper(value), value)
    end
    eventType:ChooseOptionID(1)

    addLabel(scroll, "Difficulty")
    local difficulty = vgui.Create("DComboBox", scroll)
    difficulty:Dock(TOP)
    difficulty:SetTall(34)
    difficulty:DockMargin(0, 0, 0, 8)
    for _, value in ipairs({"minor", "standard", "major", "extreme"}) do
        difficulty:AddChoice(string.upper(value), value)
    end
    difficulty:ChooseOptionID(2)

    addLabel(scroll, "Priority")
    local priority = vgui.Create("DComboBox", scroll)
    priority:Dock(TOP)
    priority:SetTall(34)
    priority:DockMargin(0, 0, 0, 8)
    for _, value in ipairs({"low", "normal", "high", "critical"}) do
        priority:AddChoice(string.upper(value), value)
    end
    priority:ChooseOptionID(2)

    addLabel(scroll, "Friendly Factions (comma separated)")
    local friendly = addEntry(scroll, "republic,unsc")
    friendly:SetValue("republic,unsc")

    addLabel(scroll, "Enemy Factions (comma separated)")
    local enemy = addEntry(scroll, "covenant or cis")

    addLabel(scroll, "Briefing")
    local briefing = vgui.Create("DTextEntry", scroll)
    briefing:Dock(TOP)
    briefing:SetTall(120)
    briefing:DockMargin(0, 0, 0, 12)
    briefing:SetMultiline(true)

    local create = UI.Components.CreateButton(
        scroll,
        "CREATE OPERATION",
        function()
            local _, planetID = planet:GetSelected()
            local _, typeID = eventType:GetSelected()
            local _, difficultyID = difficulty:GetSelected()
            local _, priorityID = priority:GetSelected()

            if not planetID or string.Trim(name:GetValue()) == "" then
                chat.AddText(
                    Color(240, 90, 90),
                    "[Convergence] Select a planet and enter an operation name."
                )
                return
            end

            local function csv(value)
                local result = {}

                for part in string.gmatch(value or "", "[^,]+") do
                    result[#result + 1] =
                        Convergence.NormalizeID(string.Trim(part))
                end

                return result
            end

            Convergence.Director.Send("create_operation", function()
                net.WriteString(name:GetValue())
                net.WriteString(planetID)
                net.WriteString(region:GetValue())
                net.WriteString(typeID or "battle")
                net.WriteString(difficultyID or "standard")
                net.WriteString(priorityID or "normal")
                net.WriteString(briefing:GetValue())
                Convergence.Director.WriteList(csv(friendly:GetValue()))
                Convergence.Director.WriteList(csv(enemy:GetValue()))
            end)

            frame:Close()
        end
    )
    create:Dock(TOP)
end
