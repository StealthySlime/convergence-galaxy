Convergence.UI.RegisterModule({
    id = "galaxy",
    name = "Galaxy",
    order = 10,

    create = function(self, parent)
        local Theme = Convergence.UI.Theme
        local Components = Convergence.UI.Components
        local data = Convergence.GalaxyData or {}

        local root = vgui.Create("DPanel", parent)
        root:Dock(FILL)
        root:DockPadding(12, 12, 12, 12)
        root.Paint = nil

        local header = Components.CreateCard(root, "GALAXY OVERVIEW")
        header:Dock(TOP)
        header:SetTall(115)
        header:DockMargin(0, 0, 0, 12)

        local clock = data.clock or {}

        Components.CreateStatRow(
            header,
            "Campaign Time",
            string.format(
                "Day %s, %02d:%02d",
                tostring(clock.day or 1),
                tonumber(clock.hour) or 0,
                tonumber(clock.minute) or 0
            )
        )

        Components.CreateStatRow(
            header,
            "Registered Planets",
            tostring(table.Count(data.planets or {}))
        )

        local body = vgui.Create("DPanel", root)
        body:Dock(FILL)
        body.Paint = nil

        local mapCard = Components.CreateCard(body, "GALAXY MAP")
        mapCard:Dock(FILL)
        mapCard:DockMargin(0, 0, 12, 0)

        local inspector = Components.CreateCard(body, "PLANET INSPECTOR")
        inspector:Dock(RIGHT)
        inspector:SetWide(math.max(ScrW() * 0.31, 420))

        local renderer = vgui.Create("ConvergenceGalaxyRenderer", mapCard)
        renderer:Dock(FILL)
        renderer:SetGalaxyData(data)

        local selectedID = Convergence.UI.SelectedPlanetID

        if not selectedID or not (data.planets or {})[selectedID] then
            selectedID = next(data.planets or {})
            Convergence.UI.SelectedPlanetID = selectedID
        end

        renderer:SetSelectedPlanet(selectedID)

        renderer.OnPlanetSelected = function(_, id)
            Convergence.UI.SelectedPlanetID = id
            Convergence.UI.RefreshActiveModule()
        end

        local selected = selectedID and data.planets[selectedID] or nil

        if not selected then
            Components.CreateEmptyState(
                inspector,
                "No planet data",
                "The server has not sent any planet records yet."
            )
            return root
        end

        local state = selected.state or {}
        local dominantFaction = data.factions
            and data.factions[selected.dominantFactionID or ""]
            or nil
        local dominantAlliance = data.alliances
            and data.alliances[selected.dominantAllianceID or ""]
            or nil
        local stabilityColor = Theme.GetStabilityColor(state.stability)

        Components.CreateStatRow(inspector, "Planet", state.name or selectedID)
        Components.CreateStatRow(
            inspector,
            "Stability",
            string.format("%s%% — %s", state.stability or 0, state.stateName or "Unknown"),
            stabilityColor
        )

        Components.CreateProgressBar(
            inspector,
            state.stability or 0,
            100,
            stabilityColor,
            string.format("%s%% %s", state.stability or 0, string.upper(state.stateName or "Unknown"))
        )

        Components.CreateStatRow(
            inspector,
            "Sector",
            selected.map and selected.map.sector or "Unknown"
        )
        Components.CreateStatRow(
            inspector,
            "Dominant Alliance",
            dominantAlliance and dominantAlliance.name or "Unclaimed"
        )
        Components.CreateStatRow(
            inspector,
            "Dominant Faction",
            dominantFaction and dominantFaction.name or "None",
            dominantFaction and Theme.GetFactionColor(dominantFaction.id, data) or nil
        )

        local influenceTitle = Components.CreateLabel(
            inspector,
            "Faction Influence",
            "Convergence.UI.Nav",
            Theme.GetColor("accent")
        )
        influenceTitle:Dock(TOP)
        influenceTitle:DockMargin(0, 14, 0, 8)

        local maxInfluence = 1
        for _, amount in pairs(selected.influence or {}) do
            maxInfluence = math.max(maxInfluence, tonumber(amount) or 0)
        end

        for factionID, amount in SortedPairs(selected.influence or {}) do
            local faction = data.factions and data.factions[factionID]
            local factionColor = Theme.GetFactionColor(factionID, data)

            Components.CreateProgressBar(
                inspector,
                tonumber(amount) or 0,
                maxInfluence,
                factionColor,
                string.format(
                    "%s  %.2f",
                    faction and faction.shortName or factionID,
                    tonumber(amount) or 0
                )
            )
        end

        return root
    end
})
