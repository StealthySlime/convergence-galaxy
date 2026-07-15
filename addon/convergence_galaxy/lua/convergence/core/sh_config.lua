Convergence.Config = Convergence.Config or {}

local Config = Convergence.Config

Config.Debug = false
Config.DefaultStability = 100
Config.MinimumStability = 0
Config.MaximumStability = 100

Config.Clock = {
    TickInterval = 5,
    SecondsPerCampaignHour = 60,
    StartingDay = 1,
    StartingHour = 0,
    AutoStart = true,
    SaveEveryTicks = 12
}

Config.Simulation = {
    MaxQueuedActionsPerTick = 100,
    MaxProcessorMilliseconds = 25,
    HistoryLimit = 100,
    StopOnProcessorError = false
}

Config.Galaxy = {
    MinZoom = 0.65,
    MaxZoom = 2.5,
    DefaultZoom = 1,
    ZoomSmoothing = 10,
    PanSmoothing = 14,
    NodeRadius = 13,
    ScanlineSpeed = 18,
    GridDriftSpeed = 4,
    HyperlanePulseSpeed = 110,
    Routes = {
        {"coruscant", "tatooine"},
        {"coruscant", "reach"},
        {"reach", "tatooine"}
    }
}

Config.StabilityStates = {
    {id = "collapse", name = "Collapse", minimum = 0, maximum = 0},
    {id = "convergence", name = "Convergence", minimum = 1, maximum = 20},
    {id = "critical", name = "Critical", minimum = 21, maximum = 40},
    {id = "unstable", name = "Unstable", minimum = 41, maximum = 60},
    {id = "strained", name = "Strained", minimum = 61, maximum = 80},
    {id = "stable", name = "Stable", minimum = 81, maximum = 100}
}

Config.Planets = {
    {
        id = "coruscant",
        name = "Coruscant",
        defaultStability = 100,
        galaxy = {x = 0.24, y = 0.58, sector = "Core Worlds"}
    },
    {
        id = "tatooine",
        name = "Tatooine",
        defaultStability = 75,
        galaxy = {x = 0.77, y = 0.64, sector = "Outer Rim"}
    },
    {
        id = "reach",
        name = "Reach",
        defaultStability = 60,
        galaxy = {x = 0.56, y = 0.27, sector = "Epsilon Eridani"}
    }
}

function Convergence.ValidateConfig()
    local errors = {}

    if not isnumber(Config.MinimumStability) or not isnumber(Config.MaximumStability) then
        errors[#errors + 1] = "Stability bounds must be numeric."
    elseif Config.MinimumStability >= Config.MaximumStability then
        errors[#errors + 1] = "Minimum stability must be lower than maximum stability."
    end

    if not istable(Config.Clock) then
        errors[#errors + 1] = "Clock configuration must be a table."
    end

    if not istable(Config.Simulation) then
        errors[#errors + 1] = "Simulation configuration must be a table."
    end

    if not istable(Config.Galaxy) then
        errors[#errors + 1] = "Galaxy configuration must be a table."
    end

    if not istable(Config.StabilityStates) or #Config.StabilityStates == 0 then
        errors[#errors + 1] = "At least one stability state must be configured."
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
