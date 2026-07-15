Convergence.UI.RegisterModule({
    id = "campaign_history",
    name = "Campaign History",
    order = 55,

    create = function(self, parent)
        local Components = Convergence.UI.Components
        local Theme = Convergence.UI.Theme
        local data = Convergence.GalaxyData or {}
        local history = table.Copy(data.campaignHistory or {})

        local root = vgui.Create("DPanel", parent)
        root:Dock(FILL)
        root.Paint = nil

        local filterBar = vgui.Create("DPanel", root)
        filterBar:Dock(TOP)
        filterBar:SetTall(52)
        filterBar:DockMargin(12, 12, 12, 0)
        filterBar.Paint = nil

        local scroll = vgui.Create("DScrollPanel", root)
        scroll:Dock(FILL)

        local severityColors = {
            success = Theme.GetColor("success"),
            warning = Theme.GetColor("warning"),
            critical = Theme.GetColor("danger"),
            danger = Theme.GetColor("danger"),
            info = Theme.GetColor("accent")
        }

        local function rebuild(category)
            scroll:Clear()

            local filtered = {}

            for _, entry in ipairs(history) do
                if category == "all" or entry.category == category then
                    filtered[#filtered + 1] = entry
                end
            end

            table.sort(filtered, function(left, right)
                return (tonumber(left.id) or 0)
                    > (tonumber(right.id) or 0)
            end)

            if #filtered == 0 then
                Components.CreateEmptyState(
                    scroll,
                    "No Campaign History",
                    "No history records match this filter."
                )
                return
            end

            for _, entry in ipairs(filtered) do
                local color = severityColors[entry.severity]
                    or Theme.GetColor("accent")
                local card = Components.CreateCard(scroll, entry.title)
                card:Dock(TOP)
                card:SetTall(entry.summary ~= "" and 150 or 118)
                card:DockMargin(12, 12, 12, 0)

                local originalPaint = card.Paint
                card.Paint = function(self, width, height)
                    if originalPaint then
                        originalPaint(self, width, height)
                    end

                    surface.SetDrawColor(
                        color.r,
                        color.g,
                        color.b,
                        220
                    )
                    surface.DrawRect(0, 0, 5, height)
                end

                Components.CreateStatRow(
                    card,
                    "Campaign Time",
                    string.format(
                        "Day %d, %02d:%02d",
                        tonumber(entry.campaignDay) or 1,
                        tonumber(entry.campaignHour) or 0,
                        tonumber(entry.campaignMinute) or 0
                    )
                )
                Components.CreateStatRow(
                    card,
                    "Category",
                    string.upper(entry.category or "campaign"),
                    color
                )

                if entry.planetID then
                    local planet = (data.planets or {})[entry.planetID]
                    Components.CreateStatRow(
                        card,
                        "Planet",
                        planet
                            and planet.state
                            and planet.state.name
                            or entry.planetID
                    )
                end

                if entry.summary and entry.summary ~= "" then
                    local summary = Components.CreateLabel(
                        card,
                        entry.summary,
                        "Convergence.UI.Body",
                        Theme.GetColor("textMuted")
                    )
                    summary:Dock(TOP)
                    summary:DockMargin(0, 8, 0, 0)
                end
            end
        end

        local filters = {
            {"ALL", "all"},
            {"OPERATIONS", "operation"},
            {"DEPLOYMENTS", "deployment"},
            {"FLEETS", "fleet"},
            {"TASK FORCE", "task_force"},
            {"ENCOUNTERS", "encounter"}
        }

        for _, option in ipairs(filters) do
            local button = Components.CreateButton(
                filterBar,
                option[1],
                function()
                    rebuild(option[2])
                end
            )
            button:Dock(LEFT)
            button:SetWide(145)
            button:DockMargin(0, 0, 8, 0)
        end

        rebuild("all")
        return root
    end
})
