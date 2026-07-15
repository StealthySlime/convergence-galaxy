Convergence.UI.RegisterModule({
    id = "fleets",
    name = "Fleets",
    order = 50,

    create = function(self, parent)
        local Components = Convergence.UI.Components
        local data = Convergence.GalaxyData or {}
        local scroll = vgui.Create("DScrollPanel", parent)
        scroll:Dock(FILL)

        if table.IsEmpty(data.fleets or {}) then
            Components.CreateEmptyState(
                scroll,
                "No Fleets",
                "GMs can add fleets using convergence_fleet_create."
            )
            return scroll
        end

        for id, fleet in SortedPairs(data.fleets or {}) do
            local faction = (data.factions or {})[fleet.factionID]
            local card = Components.CreateCard(scroll, fleet.name or id)
            card:Dock(TOP)
            card:SetTall(fleet.status == "traveling" and 300 or 250)
            card:DockMargin(12, 12, 12, 0)

            Components.CreateStatRow(card, "ID", id)
            Components.CreateStatRow(
                card,
                "Faction",
                faction and faction.name or fleet.factionID
            )
            Components.CreateStatRow(card, "Strength", tostring(fleet.strength))
            Components.CreateStatRow(card, "Status", string.upper(fleet.status))
            Components.CreateStatRow(card, "Order", string.upper(fleet.orderType or "idle"))
            Components.CreateStatRow(card, "Current Planet", fleet.currentPlanetID)
            Components.CreateStatRow(
                card,
                "Order Target",
                tostring(fleet.orderPlanetID or "None")
            )
            Components.CreateStatRow(
                card,
                "Destination",
                tostring(fleet.destinationPlanetID or "None")
            )

            if fleet.status == "traveling" then
                local etaSeconds = math.max(tonumber(fleet.etaCampaignSeconds) or 0, 0)
                local hours = math.floor(etaSeconds / 60)
                local minutes = math.floor(etaSeconds % 60)

                Components.CreateProgressBar(
                    card,
                    (tonumber(fleet.progress) or 0) * 100,
                    100,
                    Convergence.UI.Theme.GetColor("accent"),
                    string.format(
                        "Travel %.1f%% | ETA %dh %02dm",
                        (tonumber(fleet.progress) or 0) * 100,
                        hours,
                        minutes
                    )
                )
            end
        end

        return scroll
    end
})
