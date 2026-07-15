Convergence.UI.RegisterModule({
    id = "operations",
    name = "Operations",
    order = 45,

    create = function(self, parent)
        local Components = Convergence.UI.Components
        local Theme = Convergence.UI.Theme
        local UI = Convergence.UI
        local data = Convergence.GalaxyData or {}
        local visibleEvents = {}
        local planetFilter = Convergence.NormalizeID(
            UI.OperationPlanetFilter or ""
        )

        for id, event in pairs(data.campaignEvents or {}) do
            if event.status ~= "resolved"
                and event.status ~= "cancelled"
                and (
                    planetFilter == ""
                    or event.planetID == planetFilter
                ) then
                visibleEvents[id] = event
            end
        end

        local root = vgui.Create("DPanel", parent)
        root:Dock(FILL)
        root.Paint = nil

        if planetFilter ~= "" then
            local filterBar = vgui.Create("DPanel", root)
            filterBar:Dock(TOP)
            filterBar:SetTall(48)
            filterBar:DockMargin(12, 12, 12, 0)
            filterBar.Paint = nil

            local planet = (data.planets or {})[planetFilter]
            local planetName = planet and planet.state and planet.state.name
                or planetFilter

            local label = Components.CreateLabel(
                filterBar,
                "Filtered to " .. planetName,
                "Convergence.UI.Body",
                Theme.GetColor("warning")
            )
            label:Dock(LEFT)
            label:SetWide(320)

            local clear = Components.CreateButton(
                filterBar,
                "SHOW ALL OPERATIONS",
                function()
                    UI.OperationPlanetFilter = nil
                    UI.Refresh()
                end
            )
            clear:Dock(RIGHT)
            clear:SetWide(220)
        end

        local scroll = vgui.Create("DScrollPanel", root)
        scroll:Dock(FILL)

        if table.IsEmpty(visibleEvents) then
            Components.CreateEmptyState(
                scroll,
                "No Active Operations",
                planetFilter ~= ""
                    and "This planet has no unresolved operations."
                    or "Galactic Command has no unresolved operations at this time."
            )
            return root
        end

        local priorityColors = {
            critical = Theme.GetColor("danger"),
            high = Theme.GetColor("warning"),
            normal = Theme.GetColor("accent"),
            low = Theme.GetColor("textMuted")
        }

        for id, event in SortedPairs(visibleEvents) do
            local planet = (data.planets or {})[event.planetID]
            local planetName = planet and planet.state and planet.state.name
                or event.planetID
            local selected = UI.SelectedOperationID == id
            local priorityColor =
                priorityColors[event.priority or "normal"]
                or Theme.GetColor("accent")

            local card = Components.CreateCard(scroll, event.name)
            card:Dock(TOP)
            card:SetTall(event.briefing ~= "" and 360 or 285)
            card:DockMargin(12, 12, 12, 0)
            card:SetCursor("hand")

            local originalPaint = card.Paint
            card.Paint = function(self, width, height)
                if originalPaint then
                    originalPaint(self, width, height)
                end

                surface.SetDrawColor(
                    priorityColor.r,
                    priorityColor.g,
                    priorityColor.b,
                    selected and 255 or 190
                )
                surface.DrawRect(0, 0, 5, height)
            end

            card.OnMousePressed = function()
                UI.SelectedOperationID = id
                UI.Refresh()
            end

            Components.CreateStatRow(card, "Planet", planetName)
            Components.CreateStatRow(
                card,
                "Status",
                string.upper(event.status or "unknown")
            )
            Components.CreateStatRow(
                card,
                "Mission Type",
                string.upper(event.eventType or "battle")
            )
            Components.CreateStatRow(
                card,
                "Difficulty / Priority",
                string.format(
                    "%s / %s",
                    string.upper(event.difficulty or "standard"),
                    string.upper(event.priority or "normal")
                ),
                priorityColor
            )
            Components.CreateStatRow(
                card,
                "Player Deployment",
                event.playerControlled and "ACTIVE" or "No",
                event.playerControlled
                    and Theme.GetColor("success")
                    or Theme.GetColor("textMuted")
            )

            if event.secondsRemaining then
                Components.CreateProgressBar(
                    card,
                    1,
                    1,
                    event.playerControlled
                        and Theme.GetColor("success")
                        or priorityColor,
                    event.playerControlled
                        and "Held for player deployment and GM resolution"
                        or string.format(
                            "AI resolution in %dh %02dm",
                            math.floor(event.secondsRemaining / 3600),
                            math.floor((event.secondsRemaining % 3600) / 60)
                        )
                )
            end

            if event.briefing and event.briefing ~= "" then
                local briefing = Components.CreateLabel(
                    card,
                    event.briefing,
                    "Convergence.UI.Body",
                    Theme.GetColor("textMuted")
                )
                briefing:Dock(TOP)
                briefing:DockMargin(0, 4, 0, 0)
            end

            if selected and UI.Mode == "director" then
                local currentPlanetID = Convergence.NormalizeID(
                    data.world and data.world.currentPlanetID or ""
                )
                local atOperationPlanet =
                    currentPlanetID == event.planetID

                local actions = vgui.Create("DPanel", card)
                actions:Dock(BOTTOM)
                actions:SetTall(40)
                actions.Paint = nil

                if event.regionID and event.regionID ~= "" then
                    local prepare = Components.CreateButton(
                        actions,
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
                    prepare:SetWide(170)
                    prepare:SetEnabled(atOperationPlanet)
                    prepare:SetTooltip(
                        atOperationPlanet
                            and "Prepare this operation's configured map region."
                            or "Travel to " .. planetName .. " before preparing."
                    )
                end

                local deploy = Components.CreateButton(
                    actions,
                    "DEPLOY PLAYERS",
                    function()
                        Convergence.UI.OpenDeploymentMapSelector(id, event)
                    end
                )
                deploy:Dock(RIGHT)
                deploy:SetWide(170)
                deploy:SetEnabled(
                    atOperationPlanet
                    and not (
                        data.activeDeployment
                        and data.activeDeployment.eventID
                    )
                    and not event.playerControlled
                )
                deploy:SetTooltip(
                    atOperationPlanet
                        and "Commit this server to the selected operation."
                        or "Travel to " .. planetName .. " before deploying."
                )
            end
        end

        return root
    end
})
