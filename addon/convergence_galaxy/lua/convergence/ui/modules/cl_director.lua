Convergence.UI.RegisterModule({
    id = "director",
    name = "Director",
    order = 5,
    adminOnly = true,

    create = function(self, parent)
        local Components = Convergence.UI.Components
        local Theme = Convergence.UI.Theme
        local data = Convergence.GalaxyData or {}
        local director = data.director or {}
        local world = data.world or {}

        if Convergence.UI.Mode ~= "director" then
            return Components.CreateEmptyState(
                parent,
                "Director View Required",
                "Open the GM map with convergence_director."
            )
        end

        local root = vgui.Create("DPanel", parent)
        root:Dock(FILL)
        root:DockPadding(12, 12, 12, 12)
        root.Paint = nil

        local status = Components.CreateCard(root, "CAMPAIGN DIRECTOR")
        status:Dock(TOP)
        status:SetTall(245)
        status:DockMargin(0, 0, 0, 12)

        Components.CreateStatRow(
            status,
            "Current GMod Map",
            tostring(director.currentMap or game.GetMap())
        )
        Components.CreateStatRow(
            status,
            "Current Planet",
            tostring(world.currentPlanetName or world.currentPlanetID or "Unknown")
        )
        Components.CreateStatRow(
            status,
            "Travel Status",
            string.upper(tostring(world.travelStatus or "unknown"))
        )
        Components.CreateStatRow(
            status,
            "Encounter Active",
            tostring(director.encounterActive == true),
            director.encounterActive
                and Theme.GetColor("success")
                or Theme.GetColor("warning")
        )
        Components.CreateStatRow(
            status,
            "NPC Spawning Allowed",
            tostring(director.npcSpawningAllowed == true),
            director.npcSpawningAllowed
                and Theme.GetColor("success")
                or Theme.GetColor("danger")
        )
        Components.CreateStatRow(
            status,
            "Navigation Adapter",
            director.navigationAvailable and "ONLINE" or "OFFLINE",
            director.navigationAvailable
                and Theme.GetColor("success")
                or Theme.GetColor("danger")
        )
        Components.CreateStatRow(
            status,
            "Planets / Fleets",
            string.format(
                "%s / %s",
                tostring(director.registeredPlanetCount or 0),
                tostring(director.registeredFleetCount or 0)
            )
        )

        local help = Components.CreateCard(root, "GM WORKFLOW")
        help:Dock(FILL)

        local label = Components.CreateLabel(
            help,
            [[1. Use the SWU navigation console and hyperspace control.
2. Review arrival and available regions.
3. Prepare a region with convergence_world_prepare <region>.
4. Change maps only when the GM is ready.
5. Activate NPC spawning with convergence_encounter_start.
6. End the encounter with convergence_encounter_end.

The player map hides secret enemy fleets and internal orders. The Director map receives the complete strategic snapshot.]],
            "Convergence.UI.Body",
            Theme.GetColor("textMuted")
        )
        label:Dock(FILL)

        return root
    end
})
