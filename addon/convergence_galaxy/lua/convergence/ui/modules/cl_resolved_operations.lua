Convergence.UI.RegisterModule({
    id = "resolved_operations",
    name = "Resolved Operations",
    order = 50,

    create = function(self, parent)
        local Components = Convergence.UI.Components
        local Theme = Convergence.UI.Theme
        local data = Convergence.GalaxyData or {}
        local root = vgui.Create("DPanel", parent)
        root:Dock(FILL)
        root.Paint = nil
        root.OutcomeFilter = root.OutcomeFilter or "all"

        local filters = vgui.Create("DPanel", root)
        filters:Dock(TOP)
        filters:SetTall(50)
        filters:DockMargin(12, 12, 12, 0)
        filters.Paint = nil

        local options = {
            {"ALL", "all"},
            {"VICTORIES", "victory"},
            {"DRAWS", "draw"},
            {"DEFEATS", "defeat"}
        }

        local scroll = vgui.Create("DScrollPanel", root)
        scroll:Dock(FILL)

        local function rebuild(filter)
            scroll:Clear()

            local resolved = {}

            for id, event in pairs(data.campaignEvents or {}) do
                if event.status == "resolved" then
                    local outcome = tostring(
                        event.resolution
                        and event.resolution.outcome
                        or ""
                    )

                    local matches = filter == "all"
                        or (filter == "victory" and string.find(outcome, "victory", 1, true))
                        or (filter == "draw" and outcome == "draw")
                        or (filter == "defeat" and string.find(outcome, "defeat", 1, true))

                    if matches then
                        resolved[#resolved + 1] = {
                            id = id,
                            event = event
                        }
                    end
                end
            end

            table.sort(resolved, function(left, right)
                return (tonumber(left.event.resolvedAt) or 0)
                    > (tonumber(right.event.resolvedAt) or 0)
            end)

            if #resolved == 0 then
                Components.CreateEmptyState(
                    scroll,
                    "No Matching Operations",
                    "No resolved operations match this filter."
                )
                return
            end

            for _, record in ipairs(resolved) do
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
                card:SetTall(325)
                card:DockMargin(12, 12, 12, 0)

                Components.CreateStatRow(card, "Planet", planetName)
                Components.CreateStatRow(card, "Outcome", outcome)
                Components.CreateStatRow(
                    card,
                    "Resolved",
                    event.resolvedAt
                        and os.date("%Y-%m-%d %H:%M", event.resolvedAt)
                        or "Unknown"
                )
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

                for _, factionID in ipairs(event.friendlyFactions or {}) do
                    local faction = (data.factions or {})[factionID]
                    Components.CreateStatRow(
                        card,
                        (faction and faction.shortName or factionID)
                            .. " Influence",
                        tostring(effects.friendlyInfluence or 0),
                        Theme.GetFactionColor(factionID, data)
                    )
                end

                for _, factionID in ipairs(event.enemyFactions or {}) do
                    local faction = (data.factions or {})[factionID]
                    Components.CreateStatRow(
                        card,
                        (faction and faction.shortName or factionID)
                            .. " Influence",
                        tostring(effects.enemyInfluence or 0),
                        Theme.GetFactionColor(factionID, data)
                    )
                end

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
        end

        for _, option in ipairs(options) do
            local button = Components.CreateButton(
                filters,
                option[1],
                function()
                    rebuild(option[2])
                end
            )
            button:Dock(LEFT)
            button:SetWide(150)
            button:DockMargin(0, 0, 8, 0)
        end

        rebuild("all")
        return root
    end
})
