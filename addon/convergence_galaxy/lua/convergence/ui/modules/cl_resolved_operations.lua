Convergence.UI.RegisterModule({
    id = "resolved_operations",
    name = "Resolved Operations",
    order = 50,

    create = function(self, parent)
        local Components = Convergence.UI.Components
        local Theme = Convergence.UI.Theme
        local data = Convergence.GalaxyData or {}
        local resolved = {}

        for id, event in pairs(data.campaignEvents or {}) do
            if event.status == "resolved" then
                resolved[id] = event
            end
        end

        local scroll = vgui.Create("DScrollPanel", parent)
        scroll:Dock(FILL)

        if table.IsEmpty(resolved) then
            Components.CreateEmptyState(
                scroll,
                "No Resolved Operations",
                "Completed AI battles and player deployments will be archived here."
            )
            return scroll
        end

        local ordered = {}

        for id, event in pairs(resolved) do
            ordered[#ordered + 1] = {
                id = id,
                event = event
            }
        end

        table.sort(ordered, function(left, right)
            return (tonumber(left.event.resolvedAt) or 0)
                > (tonumber(right.event.resolvedAt) or 0)
        end)

        for _, record in ipairs(ordered) do
            local id = record.id
            local event = record.event
            local planet = (data.planets or {})[event.planetID]
            local planetName = planet and planet.state and planet.state.name
                or event.planetID
            local resolution = event.resolution or {}
            local effects = resolution.effects or {}
            local outcome = string.upper(
                tostring(resolution.outcome or "resolved")
            )

            local card = Components.CreateCard(scroll, event.name)
            card:Dock(TOP)
            card:SetTall(285)
            card:DockMargin(12, 12, 12, 0)

            Components.CreateStatRow(card, "Planet", planetName)
            Components.CreateStatRow(card, "Outcome", outcome)
            Components.CreateStatRow(
                card,
                "Mission Type",
                string.upper(event.eventType or "battle")
            )
            Components.CreateStatRow(
                card,
                "Difficulty",
                string.upper(event.difficulty or "standard")
            )
            Components.CreateStatRow(
                card,
                "Stability Change",
                tostring(effects.stabilityDelta or 0),
                (tonumber(effects.stabilityDelta) or 0) >= 0
                    and Theme.GetColor("success")
                    or Theme.GetColor("danger")
            )
            Components.CreateStatRow(
                card,
                "Friendly Influence",
                tostring(effects.friendlyInfluence or 0)
            )
            Components.CreateStatRow(
                card,
                "Enemy Influence",
                tostring(effects.enemyInfluence or 0)
            )

            if resolution.notes and resolution.notes ~= "" then
                local notes = Components.CreateLabel(
                    card,
                    "GM Notes: " .. resolution.notes,
                    "Convergence.UI.Body",
                    Theme.GetColor("textMuted")
                )
                notes:Dock(TOP)
                notes:DockMargin(0, 8, 0, 0)
            end
        end

        return scroll
    end
})
