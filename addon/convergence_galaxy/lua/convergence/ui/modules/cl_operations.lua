Convergence.UI.RegisterModule({
    id = "operations",
    name = "Operations",
    order = 45,

    create = function(self, parent)
        local Components = Convergence.UI.Components
        local Theme = Convergence.UI.Theme
        local data = Convergence.GalaxyData or {}
        local events = data.campaignEvents or {}

        local scroll = vgui.Create("DScrollPanel", parent)
        scroll:Dock(FILL)

        if table.IsEmpty(events) then
            Components.CreateEmptyState(
                scroll,
                "No Active Operations",
                "There are no visible campaign operations at this time."
            )
            return scroll
        end

        for id, event in SortedPairs(events) do
            local planet = (data.planets or {})[event.planetID]
            local planetName = planet and planet.state and planet.state.name
                or event.planetID
            local card = Components.CreateCard(scroll, event.name)
            card:Dock(TOP)
            card:SetTall(250)
            card:DockMargin(12, 12, 12, 0)

            Components.CreateStatRow(card, "ID", id)
            Components.CreateStatRow(card, "Planet", planetName)
            Components.CreateStatRow(
                card,
                "Status",
                string.upper(event.status or "unknown")
            )
            Components.CreateStatRow(
                card,
                "Difficulty",
                string.upper(event.difficulty or "standard")
            )
            Components.CreateStatRow(
                card,
                "Priority",
                string.upper(event.priority or "normal")
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
                local minutes = math.ceil(event.secondsRemaining / 60)

                Components.CreateProgressBar(
                    card,
                    event.secondsRemaining,
                    math.max(event.secondsRemaining, 1),
                    Theme.GetColor("warning"),
                    string.format(
                        event.playerControlled
                            and "Held for GM resolution"
                            or "AI resolution in %d minutes",
                        minutes
                    )
                )
            end
        end

        return scroll
    end
})
