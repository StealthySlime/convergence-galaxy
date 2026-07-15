Convergence.UI.RegisterModule({
    id = "ai_monitor",
    name = "Galactic AI",
    order = 56,
    adminOnly = true,
    directorOnly = true,

    create = function(self, parent)
        local Components = Convergence.UI.Components
        local Theme = Convergence.UI.Theme
        local data = Convergence.GalaxyData or {}
        local ai = data.factionAI or {}
        local decisions = ai.decisions or {}

        local scroll = vgui.Create("DScrollPanel", parent)
        scroll:Dock(FILL)

        local status = Components.CreateCard(scroll, "AI THINK CYCLE")
        status:Dock(TOP)
        status:SetTall(220)
        status:DockMargin(12, 12, 12, 0)

        Components.CreateStatRow(
            status,
            "Status",
            ai.enabled and "ACTIVE" or "PAUSED",
            ai.enabled
                and Theme.GetColor("success")
                or Theme.GetColor("warning")
        )
        Components.CreateStatRow(
            status,
            "Think Cycles",
            tostring(ai.thinkCount or 0)
        )
        Components.CreateStatRow(
            status,
            "Next Think",
            string.format(
                "%dm %02ds",
                math.floor((ai.secondsUntilNextThink or 0) / 60),
                math.floor((ai.secondsUntilNextThink or 0) % 60)
            )
        )
        Components.CreateStatRow(
            status,
            "Active Operations",
            tostring(ai.activeOperations or 0)
        )

        if table.IsEmpty(decisions) then
            Components.CreateEmptyState(
                scroll,
                "No AI Decisions Yet",
                "The first strategic think cycle will run shortly."
            )
            return scroll
        end

        for factionID, decision in SortedPairs(decisions) do
            local faction = (data.factions or {})[factionID]
            local card = Components.CreateCard(
                scroll,
                faction and faction.name or string.upper(factionID)
            )
            card:Dock(TOP)
            card:SetTall(180)
            card:DockMargin(12, 12, 12, 0)

            Components.CreateStatRow(
                card,
                "Decision",
                string.upper(
                    string.gsub(
                        tostring(decision.action or "observe"),
                        "_",
                        " "
                    )
                )
            )
            Components.CreateStatRow(
                card,
                "Target",
                tostring(decision.planetID or "None")
            )
            Components.CreateStatRow(
                card,
                "Campaign Time",
                decision.campaignTime
                    and string.format(
                        "Day %d, %02d:%02d",
                        decision.campaignTime.day or 1,
                        decision.campaignTime.hour or 0,
                        decision.campaignTime.minute or 0
                    )
                    or "Unknown"
            )

            local detail = Components.CreateLabel(
                card,
                tostring(decision.detail or ""),
                "Convergence.UI.Body",
                Theme.GetColor("textMuted")
            )
            detail:Dock(TOP)
            detail:SetWrap(true)
            detail:SetAutoStretchVertical(true)
            detail:DockMargin(0, 10, 0, 0)
        end

        return scroll
    end
})
