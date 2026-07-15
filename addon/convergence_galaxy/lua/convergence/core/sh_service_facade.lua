Convergence.ServiceFacade = Convergence.ServiceFacade or {}

local Facade = Convergence.ServiceFacade

Facade.Aliases = Facade.Aliases or {
    Planets = "planets",
    Factions = "factions",
    Influence = "influence",
    Stability = "stability",
    Fleets = "fleets",
    Operations = "campaign_events",
    Deployments = "deployments",
    History = "campaign_history",
    News = "galactic_news",
    Notifications = "campaign_notifications",
    Intelligence = "strategic_intelligence",
    Navigation = "navigation",
    World = "world",
    Simulation = "simulation",
    Clock = "clock",
    Alliances = "alliances",
    FleetOrders = "fleet_orders",
    Lifecycle = "lifecycle",
    FactionAI = "faction_ai",
    OperationGenerator = "operation_generator"
}

local function resolve(alias)
    local serviceID = Facade.Aliases[alias]
    return serviceID and Convergence.Services.Get(serviceID) or nil
end

setmetatable(Facade, {
    __index = function(_, key)
        return resolve(key)
    end
})

function Facade.Get(alias)
    return resolve(alias)
end

function Facade.IsAvailable(alias)
    return resolve(alias) ~= nil
end

function Facade.Validate()
    local status = {}

    for alias in pairs(Facade.Aliases) do
        status[alias] = Facade.IsAvailable(alias)
    end

    return status
end
