Convergence.UI.RegisterModule({
    id = "intelligence",
    name = "Intelligence",
    order = 57,
    adminOnly = true,
    directorOnly = true,

    create = function(self, parent)
        local Components = Convergence.UI.Components
        local Theme = Convergence.UI.Theme
        local data = Convergence.GalaxyData or {}
        local assessments = data.strategicIntelligence or {}

        local scroll = vgui.Create("DScrollPanel", parent)
        scroll:Dock(FILL)

        if table.IsEmpty(assessments) then
            Components.CreateEmptyState(
                scroll,
                "No Intelligence Data",
                "Strategic assessments are not currently available."
            )
            return scroll
        end

        local ordered = {}

        for _, assessment in pairs(assessments) do
            ordered[#ordered + 1] = assessment
        end

        table.sort(ordered, function(left, right)
            return (tonumber(left.threat) or 0)
                > (tonumber(right.threat) or 0)
        end)

        for _, assessment in ipairs(ordered) do
            local threat = tonumber(assessment.threat) or 0
            local accent = threat >= 80
                and Theme.GetColor("danger")
                or threat >= 55
                    and Theme.GetColor("warning")
                    or threat >= 30
                        and Theme.GetColor("accent")
                        or Theme.GetColor("success")

            local card = Components.CreateCard(
                scroll,
                assessment.planetName
            )
            card:Dock(TOP)
            card:SetTall(255)
            card:DockMargin(12, 12, 12, 0)

            Components.CreateStatRow(
                card,
                "Threat Level",
                string.format(
                    "%s — %.0f%%",
                    assessment.level,
                    threat
                ),
                accent
            )
            Components.CreateProgressBar(
                card,
                threat,
                100,
                accent,
                string.format("%.0f%% THREAT", threat)
            )
            Components.CreateStatRow(
                card,
                "Stability",
                string.format("%.0f%%", assessment.stability or 0)
            )
            Components.CreateStatRow(
                card,
                "Friendly Influence",
                string.format("%.1f", assessment.friendlyInfluence or 0)
            )
            Components.CreateStatRow(
                card,
                "Enemy Influence",
                string.format("%.1f", assessment.enemyInfluence or 0)
            )
            Components.CreateStatRow(
                card,
                "Active Operations",
                tostring(assessment.activeOperations or 0)
            )

            local recommendation = Components.CreateLabel(
                card,
                "Recommendation: " .. tostring(
                    assessment.recommendation
                ),
                "Convergence.UI.Body",
                accent
            )
            recommendation:Dock(TOP)
            recommendation:SetWrap(true)
            recommendation:SetAutoStretchVertical(true)
            recommendation:DockMargin(0, 10, 0, 0)
        end

        return scroll
    end
})
