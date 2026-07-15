Convergence.UI.RegisterModule({
    id = "planets",
    name = "Planets",
    order = 20,

    create = function(self, parent)
        local Components = Convergence.UI.Components
        local data = Convergence.GalaxyData or {}

        local scroll = vgui.Create("DScrollPanel", parent)
        scroll:Dock(FILL)

        for id, planetData in SortedPairs(data.planets or {}) do
            local state = planetData.state or {}
            local card = Components.CreateCard(scroll, state.name or id)
            card:Dock(TOP)
            card:SetTall(175)
            card:DockMargin(12, 12, 12, 0)

            Components.CreateStatRow(
                card,
                "Stability",
                string.format("%s%% — %s", state.stability or 0, state.stateName or "Unknown")
            )

            Components.CreateStatRow(
                card,
                "Dominant Alliance",
                planetData.dominantAllianceID or "Unclaimed"
            )

            Components.CreateStatRow(
                card,
                "Dominant Faction",
                planetData.dominantFactionID or "None"
            )

            Components.CreateStatRow(
                card,
                "Influence Records",
                tostring(table.Count(planetData.influence or {}))
            )
        end

        return scroll
    end
})
