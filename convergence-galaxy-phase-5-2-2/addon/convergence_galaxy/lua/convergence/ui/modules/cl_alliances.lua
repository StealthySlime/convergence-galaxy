Convergence.UI.RegisterModule({
    id = "alliances",
    name = "Alliances",
    order = 40,

    create = function(self, parent)
        local Components = Convergence.UI.Components
        local data = Convergence.GalaxyData or {}

        local scroll = vgui.Create("DScrollPanel", parent)
        scroll:Dock(FILL)

        for id, alliance in SortedPairs(data.alliances or {}) do
            local card = Components.CreateCard(scroll, alliance.name or id)
            card:Dock(TOP)
            card:SetTall(170)
            card:DockMargin(12, 12, 12, 0)

            Components.CreateStatRow(card, "ID", id)
            Components.CreateStatRow(
                card,
                "Member Factions",
                table.concat(alliance.factions or {}, ", ")
            )

            local description = Components.CreateLabel(
                card,
                alliance.description or "",
                "Convergence.UI.Small",
                Convergence.UI.Theme.GetColor("textMuted")
            )
            description:Dock(TOP)
            description:DockMargin(0, 8, 0, 0)
        end

        return scroll
    end
})
