Convergence.UI.RegisterModule({
    id = "factions",
    name = "Factions",
    order = 30,

    create = function(self, parent)
        local Components = Convergence.UI.Components
        local data = Convergence.GalaxyData or {}

        local scroll = vgui.Create("DScrollPanel", parent)
        scroll:Dock(FILL)

        for id, faction in SortedPairs(data.factions or {}) do
            local card = Components.CreateCard(scroll, faction.name or id)
            card:Dock(TOP)
            card:SetTall(150)
            card:DockMargin(12, 12, 12, 0)

            Components.CreateStatRow(card, "ID", id)
            Components.CreateStatRow(card, "Alignment", faction.alignment or "unknown")
            Components.CreateStatRow(card, "Short Name", faction.shortName or faction.name or id)

            local description = Components.CreateLabel(
                card,
                faction.description or "",
                "Convergence.UI.Small",
                Convergence.UI.Theme.GetColor("textMuted")
            )
            description:Dock(TOP)
            description:DockMargin(0, 8, 0, 0)
        end

        return scroll
    end
})
