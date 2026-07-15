Convergence.UI.RegisterModule({
    id = "operations",
    name = "Operations",
    order = 45,

    create = function(self, parent)
        local Components = Convergence.UI.Components
        local Theme = Convergence.UI.Theme
        local data = Convergence.GalaxyData or {}
        local visibleEvents = {}

        for id, event in pairs(data.campaignEvents or {}) do
            if event.status ~= "resolved" and event.status ~= "cancelled" then
                visibleEvents[id] = event
            end
        end

        local scroll = vgui.Create("DScrollPanel", parent)
        scroll:Dock(FILL)

        if table.IsEmpty(visibleEvents) then
            Components.CreateEmptyState(
                scroll,
                "No Active Operations",
                "Galactic Command has no unresolved operations at this time."
            )
            return scroll
        end

        for id, event in SortedPairs(visibleEvents) do
            local planet = (data.planets or {})[event.planetID]
            local planetName = planet and planet.state and planet.state.name
                or event.planetID
            local card = Components.CreateCard(scroll, event.name)
            card:Dock(TOP)
            card:SetTall(event.briefing ~= "" and 330 or 255)
            card:DockMargin(12, 12, 12, 0)

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
                )
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
                        or Theme.GetColor("warning"),
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
        end

        return scroll
    end
})
