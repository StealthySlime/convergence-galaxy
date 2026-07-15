local placeholders = {
    {
        id = "research",
        name = "Research",
        order = 60,
        description = "Faction and alliance research projects will appear here."
    },
    {
        id = "events",
        name = "Events",
        order = 70,
        description = "Campaign events and active convergence incidents will appear here."
    },
    {
        id = "administration",
        name = "GM Tools",
        order = 1000,
        adminOnly = true,
        description = "Planet editing, influence controls, events, and campaign administration will appear here."
    }
}

for _, definition in ipairs(placeholders) do
    Convergence.UI.RegisterModule({
        id = definition.id,
        name = definition.name,
        order = definition.order,
        adminOnly = definition.adminOnly,

        create = function(self, parent)
            return Convergence.UI.Components.CreateEmptyState(
                parent,
                definition.name,
                definition.description
            )
        end
    })
end
