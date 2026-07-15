Convergence.UI.RegisterModule({
    id = "galactic_news",
    name = "Galactic News",
    order = 58,

    create = function(self, parent)
        local Components = Convergence.UI.Components
        local Theme = Convergence.UI.Theme
        local data = Convergence.GalaxyData or {}
        local news = table.Copy(data.galacticNews or {})

        local scroll = vgui.Create("DScrollPanel", parent)
        scroll:Dock(FILL)

        table.sort(news, function(left, right)
            return (tonumber(left.createdAt) or 0)
                > (tonumber(right.createdAt) or 0)
        end)

        if #news == 0 then
            Components.CreateEmptyState(
                scroll,
                "No Galactic News",
                "Major campaign developments will be reported here."
            )
            return scroll
        end

        local severityColors = {
            success = Theme.GetColor("success"),
            warning = Theme.GetColor("warning"),
            critical = Theme.GetColor("danger"),
            danger = Theme.GetColor("danger"),
            info = Theme.GetColor("accent")
        }

        for _, article in ipairs(news) do
            local accent = severityColors[article.severity]
                or Theme.GetColor("accent")
            local card = Components.CreateCard(scroll, article.headline)
            card:Dock(TOP)
            card:SetTall(article.body ~= "" and 230 or 150)
            card:DockMargin(12, 12, 12, 0)

            local originalPaint = card.Paint
            card.Paint = function(self, width, height)
                if originalPaint then
                    originalPaint(self, width, height)
                end

                surface.SetDrawColor(accent.r, accent.g, accent.b, 235)
                surface.DrawRect(0, 0, 6, height)
            end

            Components.CreateStatRow(
                card,
                "Campaign Time",
                string.format(
                    "Day %d, %02d:%02d",
                    tonumber(article.campaignDay) or 1,
                    tonumber(article.campaignHour) or 0,
                    tonumber(article.campaignMinute) or 0
                )
            )

            if article.subheadline and article.subheadline ~= "" then
                Components.CreateStatRow(
                    card,
                    "Report",
                    article.subheadline,
                    accent
                )
            end

            if article.planetID then
                local planet = (data.planets or {})[article.planetID]
                Components.CreateStatRow(
                    card,
                    "Location",
                    planet
                        and planet.state
                        and planet.state.name
                        or article.planetID
                )
            end

            if article.body and article.body ~= "" then
                local body = Components.CreateLabel(
                    card,
                    article.body,
                    "Convergence.UI.Body",
                    Theme.GetColor("textMuted")
                )
                body:Dock(TOP)
                body:SetWrap(true)
                body:SetAutoStretchVertical(true)
                body:DockMargin(0, 10, 0, 0)
            end
        end

        return scroll
    end
})
