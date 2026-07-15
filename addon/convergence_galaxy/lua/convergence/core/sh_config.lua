Convergence.Config = Convergence.Config or {}

local Config = Convergence.Config

Config.Debug = false
Config.DefaultStability = 100
Config.MinimumStability = 0
Config.MaximumStability = 100

Config.StabilityStates = {
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

Config.Planets = {
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

function Convergence.ValidateConfig()
    local errors = {}

    if not isnumber(Config.MinimumStability) or not isnumber(Config.MaximumStability) then
        errors[#errors + 1] = "Stability bounds must be numeric."
    elseif Config.MinimumStability >= Config.MaximumStability then
        errors[#errors + 1] = "Minimum stability must be lower than maximum stability."
    end

    if not istable(Config.StabilityStates) or #Config.StabilityStates == 0 then
        errors[#errors + 1] = "At least one stability state must be configured."
    end

    local seenStates = {}

    for index, state in ipairs(Config.StabilityStates or {}) do
        local id = Convergence.NormalizeID(state.id)

        if id == "" then
            errors[#errors + 1] = "Stability state #" .. index .. " has no valid ID."
        elseif seenStates[id] then
            errors[#errors + 1] = "Duplicate stability state ID: " .. id
        else
            seenStates[id] = true
        end

        if not isnumber(state.minimum) or not isnumber(state.maximum) then
            errors[#errors + 1] = "Stability state " .. id .. " has invalid bounds."
        elseif state.minimum > state.maximum then
            errors[#errors + 1] = "Stability state " .. id .. " has reversed bounds."
        end
    end

    local seenPlanets = {}

    for index, planet in ipairs(Config.Planets or {}) do
        local id = Convergence.NormalizeID(planet.id)

        if id == "" then
            errors[#errors + 1] = "Planet #" .. index .. " has no valid ID."
        elseif seenPlanets[id] then
            errors[#errors + 1] = "Duplicate planet ID: " .. id
        else
            seenPlanets[id] = true
        end
    end

    Convergence.Log.MinimumLevel = Config.Debug
        and Convergence.Constants.LOG_LEVELS.DEBUG
        or Convergence.Constants.LOG_LEVELS.INFO

    return #errors == 0, errors
end
