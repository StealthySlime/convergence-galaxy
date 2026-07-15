Convergence.UI.RegisterModule({
    id = "director",
    name = "Director",
    order = 5,
    adminOnly = true,
    directorOnly = true,

    create = function(self, parent)
        local Components = Convergence.UI.Components
        local Theme = Convergence.UI.Theme
        local data = Convergence.GalaxyData or {}
        local director = data.director or {}
        local world = data.world or {}
        local deployment = data.activeDeployment
        local allEvents = data.campaignEvents or {}
        local events = {}

        for id, event in pairs(allEvents) do
            if event.status ~= "resolved" and event.status ~= "cancelled" then
                events[id] = event
            end
        end

        local root = vgui.Create("DScrollPanel", parent)
        root:Dock(FILL)

        local status = Components.CreateCard(root, "CAMPAIGN DIRECTOR")
        status:Dock(TOP)
        status:SetTall(250)
        status:DockMargin(12, 12, 12, 0)

        Components.CreateStatRow(
            status,
            "Current GMod Map",
            tostring(director.currentMap or game.GetMap())
        )
        Components.CreateStatRow(
            status,
            "Current Planet",
            tostring(world.currentPlanetName or world.currentPlanetID or "Unknown")
        )
        Components.CreateStatRow(
            status,
            "Travel Status",
            string.upper(tostring(world.travelStatus or "unknown"))
        )
        Components.CreateStatRow(
            status,
            "Encounter Active",
            tostring(director.encounterActive == true),
            director.encounterActive
                and Theme.GetColor("success")
                or Theme.GetColor("warning")
        )
        Components.CreateStatRow(
            status,
            "Active Deployment",
            deployment and tostring(deployment.eventID) or "None",
            deployment
                and Theme.GetColor("success")
                or Theme.GetColor("textMuted")
        )
        Components.CreateStatRow(
            status,
            "Visible Operations",
            tostring(table.Count(events))
        )

        local controls = Components.CreateCard(root, "QUICK CONTROLS")
        controls:Dock(TOP)
        controls:SetTall(150)
        controls:DockMargin(12, 12, 12, 0)

        local create = Components.CreateButton(
            controls,
            "CREATE OPERATION",
            function()
                Convergence.UI.OpenOperationEditor()
            end
        )
        create:Dock(TOP)
        create:DockMargin(0, 0, 0, 8)

        local encounterRow = vgui.Create("DPanel", controls)
        encounterRow:Dock(TOP)
        encounterRow:SetTall(38)
        encounterRow.Paint = nil

        local encounterStart = Components.CreateButton(
            encounterRow,
            "START ENCOUNTER",
            function()
                Convergence.Director.Send("encounter_start")
            end
        )
        encounterStart:Dock(LEFT)
        encounterStart:SetWide(210)

        local encounterEnd = Components.CreateButton(
            encounterRow,
            "END ENCOUNTER",
            function()
                Convergence.Director.Send("encounter_end")
            end,
            true
        )
        encounterEnd:Dock(RIGHT)
        encounterEnd:SetWide(210)

        local deploymentCard = Components.CreateCard(root, "CURRENT DEPLOYMENT")
        deploymentCard:Dock(TOP)
        deploymentCard:SetTall(deployment and 260 or 110)
        deploymentCard:DockMargin(12, 12, 12, 0)

        if deployment then
            local event = events[deployment.eventID]

            Components.CreateStatRow(
                deploymentCard,
                "Operation",
                event and event.name or deployment.eventID
            )
            Components.CreateStatRow(
                deploymentCard,
                "Planet",
                event and event.planetID or "Unknown"
            )

            local outcomes = vgui.Create("DPanel", deploymentCard)
            outcomes:Dock(TOP)
            outcomes:SetTall(82)
            outcomes.Paint = nil

            local labels = {
                {"MAJOR VICTORY", "major_victory", false},
                {"VICTORY", "victory", false},
                {"DRAW", "draw", false},
                {"DEFEAT", "defeat", true},
                {"MAJOR DEFEAT", "major_defeat", true}
            }

            for index, info in ipairs(labels) do
                local button = Components.CreateButton(
                    outcomes,
                    info[1],
                    function()
                        Derma_StringRequest(
                            "Resolve Deployment",
                            "Optional GM notes:",
                            "",
                            function(notes)
                                Convergence.Director.Send("resolve", function()
                                    net.WriteString(info[2])
                                    net.WriteString(notes or "")
                                end)
                            end
                        )
                    end,
                    info[3]
                )
                button:SetWide(150)
                button:Dock(LEFT)
                button:DockMargin(index > 1 and 6 or 0, 0, 0, 0)
            end
        else
            Components.CreateLabel(
                deploymentCard,
                "No player deployment is active. Select an operation below and deploy it.",
                "Convergence.UI.Body",
                Theme.GetColor("textMuted")
            ):Dock(TOP)
        end

        local operations = Components.CreateCard(root, "OPERATIONS MANAGEMENT")
        operations:Dock(TOP)
        operations:SetTall(math.max(150, table.Count(events) * 118 + 55))
        operations:DockMargin(12, 12, 12, 12)

        if table.IsEmpty(events) then
            Components.CreateLabel(
                operations,
                "No campaign operations exist.",
                "Convergence.UI.Body",
                Theme.GetColor("textMuted")
            ):Dock(TOP)
        else
            for id, event in SortedPairs(events) do
                local currentPlanetID = Convergence.NormalizeID(
                    world.currentPlanetID or ""
                )
                local atOperationPlanet =
                    currentPlanetID == event.planetID
                local targetPlanet =
                    (data.planets or {})[event.planetID]
                local targetPlanetName =
                    targetPlanet
                    and targetPlanet.state
                    and targetPlanet.state.name
                    or event.planetID

                local row = vgui.Create("DPanel", operations)
                row:Dock(TOP)
                row:SetTall(105)
                row:DockMargin(0, 0, 0, 8)
                row:DockPadding(10, 8, 10, 8)

                row.Paint = function(self, width, height)
                    draw.RoundedBox(4, 0, 0, width, height, Color(4, 20, 34, 220))
                end

                local title = Components.CreateLabel(
                    row,
                    event.name,
                    "Convergence.UI.Header",
                    Theme.GetColor("text")
                )
                title:Dock(TOP)

                local info = Components.CreateLabel(
                    row,
                    string.format(
                        "%s | %s | %s | %s",
                        string.upper(event.status or "unknown"),
                        tostring(event.planetID),
                        string.upper(event.difficulty or "standard"),
                        event.secondsRemaining
                            and (math.ceil(event.secondsRemaining / 60) .. "m remaining")
                            or "No timer"
                    ),
                    "Convergence.UI.Small",
                    Theme.GetColor("textMuted")
                )
                info:Dock(TOP)

                local buttons = vgui.Create("DPanel", row)
                buttons:Dock(BOTTOM)
                buttons:SetTall(34)
                buttons.Paint = nil

                if event.regionID and event.regionID ~= "" then
                    local prepare = Components.CreateButton(
                        buttons,
                        "PREPARE REGION",
                        function()
                            Convergence.Director.Send(
                                "prepare_region",
                                function()
                                    net.WriteString(id)
                                end
                            )
                        end
                    )
                    prepare:Dock(LEFT)
                    prepare:SetWide(150)
                    prepare:DockMargin(0, 0, 8, 0)
                    prepare:SetEnabled(atOperationPlanet)
                    prepare:SetTooltip(
                        atOperationPlanet
                            and "Prepare this operation's configured map region."
                            or "Travel to " .. targetPlanetName
                                .. " before preparing."
                    )
                end

                local deploy = Components.CreateButton(
                    buttons,
                    "DEPLOY",
                    function()
                        Convergence.UI.OpenDeploymentMapSelector(id, event)
                    end
                )
                deploy:Dock(LEFT)
                deploy:SetWide(130)
                deploy:SetEnabled(
                    atOperationPlanet
                    and not deployment
                    and not event.playerControlled
                )
                deploy:SetTooltip(
                    atOperationPlanet
                        and "Start the player deployment."
                        or "Travel to " .. targetPlanetName
                            .. " before deploying."
                )

                local extend = Components.CreateButton(
                    buttons,
                    "+30 MIN",
                    function()
                        Convergence.Director.Send("extend", function()
                            net.WriteString(id)
                            net.WriteUInt(1800, 32)
                        end)
                    end
                )
                extend:Dock(LEFT)
                extend:SetWide(130)
                extend:DockMargin(8, 0, 0, 0)
            end
        end

        return root
    end
})
