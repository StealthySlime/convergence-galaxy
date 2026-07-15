Convergence.Config = Convergence.Config or {}

Convergence.Config.DefaultStability = 100
Convergence.Config.MinimumStability = 0
Convergence.Config.MaximumStability = 100

Convergence.Config.StabilityStates = {
    {
        id = "collapse",
        name = "Collapse",
        minimum = 0,
        maximum = 0
    },
    {
        id = "convergence",
        name = "Convergence",
        minimum = 1,
        maximum = 20
    },
    {
        id = "critical",
        name = "Critical",
        minimum = 21,
        maximum = 40
    },
    {
        id = "unstable",
        name = "Unstable",
        minimum = 41,
        maximum = 60
    },
    {
        id = "strained",
        name = "Strained",
        minimum = 61,
        maximum = 80
    },
    {
        id = "stable",
        name = "Stable",
        minimum = 81,
        maximum = 100
    }
}

Convergence.Config.Planets = {
    {
        id = "coruscant",
        name = "Coruscant",
        defaultStability = 100
    },
    {
        id = "tatooine",
        name = "Tatooine",
        defaultStability = 75
    },
    {
        id = "reach",
        name = "Reach",
        defaultStability = 60
    }
}
