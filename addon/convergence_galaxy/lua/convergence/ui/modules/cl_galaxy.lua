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

        local left = Components.CreateCard(body, "PLANETS")
        left:Dock(LEFT)
        left:SetWide(math.max(ScrW() * 0.36, 430))
        left:DockMargin(0, 0, 12, 0)

        local scroll = vgui.Create("DScrollPanel", left)
        scroll:Dock(FILL)

        for id, planetData in SortedPairs(data.planets or {}) do
            local state = planetData.state or {}

            local row = vgui.Create("DButton", scroll)
            row:Dock(TOP)
            row:SetTall(54)
            row:DockMargin(0, 0, 0, 6)
            row:SetText("")

            row.Paint = function(button, width, height)
                local selected = Convergence.UI.SelectedPlanetID == id
                local fill = selected
                    and Theme.GetColor("accentDim")
                    or Color(12, 30, 48, 230)

                if button:IsHovered() and not selected then
                    fill = Color(20, 48, 73, 235)
                end

                draw.RoundedBox(4, 0, 0, width, height, fill)

                draw.SimpleText(
                    state.name or id,
                    "Convergence.UI.Nav",
                    12,
                    15,
                    Theme.GetColor("text"),
                    TEXT_ALIGN_LEFT,
                    TEXT_ALIGN_CENTER
                )

                draw.SimpleText(
                    string.format("%s%% — %s", state.stability or 0, state.stateName or "Unknown"),
                    "Convergence.UI.Small",
                    12,
                    38,
                    Theme.GetColor("textMuted"),
                    TEXT_ALIGN_LEFT,
                    TEXT_ALIGN_CENTER
                )
            end

            row.DoClick = function()
                Convergence.UI.SelectedPlanetID = id
                Convergence.UI.RefreshActiveModule()
            end
        end

        local inspector = Components.CreateCard(body, "PLANET INSPECTOR")
        inspector:Dock(FILL)

        local selectedID = Convergence.UI.SelectedPlanetID

        if not selectedID or not (data.planets or {})[selectedID] then
            local firstID = next(data.planets or {})
            selectedID = firstID
            Convergence.UI.SelectedPlanetID = firstID
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

        Components.CreateStatRow(inspector, "Planet", state.name or selectedID)
        Components.CreateStatRow(
            inspector,
            "Stability",
            string.format("%s%% — %s", state.stability or 0, state.stateName or "Unknown")
        )
        Components.CreateStatRow(
            inspector,
            "Dominant Alliance",
            dominantAlliance and dominantAlliance.name or "Unclaimed"
        )
        Components.CreateStatRow(
            inspector,
            "Dominant Faction",
            dominantFaction and dominantFaction.name or "None"
        )

        local influenceTitle = Components.CreateLabel(
            inspector,
            "Faction Influence",
            "Convergence.UI.Nav",
            Theme.GetColor("accent")
        )
        influenceTitle:Dock(TOP)
        influenceTitle:DockMargin(0, 14, 0, 8)

        for factionID, amount in SortedPairs(selected.influence or {}) do
            local faction = data.factions and data.factions[factionID]
            Components.CreateStatRow(
                inspector,
                faction and faction.shortName or factionID,
                string.format("%.2f", tonumber(amount) or 0)
            )
        end

        return root
    end
})
