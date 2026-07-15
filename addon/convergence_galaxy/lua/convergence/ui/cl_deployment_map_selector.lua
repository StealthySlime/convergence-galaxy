Convergence.UI = Convergence.UI or {}

local UI = Convergence.UI

function UI.OpenDeploymentMapSelector(eventID, event)
    if UI.Mode ~= "director" or not event then
        return
    end

    local regions = event.regions or {}

    if #regions == 0 then
        Derma_Query(
            "This operation has no map regions configured. Deploy without preparing a map?",
            "Deploy Players",
            "DEPLOY",
            function()
                Convergence.Director.Send("deploy", function()
                    net.WriteString(eventID)
                    net.WriteString("")
                end)
            end,
            "CANCEL"
        )
        return
    end

    local frame = vgui.Create("DFrame")
    frame:SetSize(620, 430)
    frame:Center()
    frame:SetTitle("Select Deployment Map — " .. tostring(event.name))
    frame:MakePopup()

    local description = vgui.Create("DLabel", frame)
    description:Dock(TOP)
    description:SetTall(54)
    description:DockMargin(12, 8, 12, 4)
    description:SetWrap(true)
    description:SetText(
        "Choose the destination region/map for this player deployment. "
        .. "Convergence will prepare it, but the GM must still perform the map change."
    )

    local list = vgui.Create("DListView", frame)
    list:Dock(FILL)
    list:DockMargin(12, 4, 12, 8)
    list:SetMultiSelect(false)
    list:AddColumn("Region")
    list:AddColumn("Map")
    list:AddColumn("ID")

    local selectedRegionID = nil

    for _, region in ipairs(regions) do
        local line = list:AddLine(
            tostring(region.name or region.id),
            tostring(region.map or "Not configured"),
            tostring(region.id)
        )
        line.ConvergenceRegionID = region.id

        if event.regionID and event.regionID == region.id then
            list:SelectItem(line)
            selectedRegionID = region.id
        end
    end

    list.OnRowSelected = function(_, _, line)
        selectedRegionID = line.ConvergenceRegionID
    end

    local buttons = vgui.Create("DPanel", frame)
    buttons:Dock(BOTTOM)
    buttons:SetTall(52)
    buttons:DockMargin(12, 0, 12, 10)
    buttons.Paint = nil

    local cancel = UI.Components.CreateButton(
        buttons,
        "CANCEL",
        function()
            frame:Close()
        end,
        true
    )
    cancel:Dock(LEFT)
    cancel:SetWide(180)

    local deploy = UI.Components.CreateButton(
        buttons,
        "PREPARE & DEPLOY",
        function()
            if not selectedRegionID then
                chat.AddText(
                    Color(240, 90, 90),
                    "[Convergence] Select a deployment map first."
                )
                return
            end

            Convergence.Director.Send("deploy", function()
                net.WriteString(eventID)
                net.WriteString(selectedRegionID)
            end)

            frame:Close()
        end
    )
    deploy:Dock(RIGHT)
    deploy:SetWide(220)
end
