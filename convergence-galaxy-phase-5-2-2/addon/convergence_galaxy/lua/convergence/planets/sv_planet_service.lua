Convergence.PlanetService = Convergence.PlanetService or {}

local Service = Convergence.PlanetService
local ERROR = Convergence.Constants.ERROR

Service.Cache = Service.Cache or {}
Service.Ready = false

local Planet = {}
Planet.__index = Planet

local function resolve(value)
    return Convergence.ResolvePlanetID(value)
end

local function createPlanet(definition, state)
    local object = setmetatable({
        id = definition.id,
        definition = definition,
        stability = Convergence.ClampStability(state.stability),
        stabilityLocked = tonumber(state.locked) == 1,
        updatedAt = tonumber(state.updated_at) or os.time(),
        revision = 1
    }, Planet)

    return object
end

function Planet:GetID()
    return self.id
end

function Planet:GetName()
    return self.definition.name
end

function Planet:GetDefinition()
    return self.definition
end

function Planet:GetAliases()
    return table.Copy(self.definition.aliases or {})
end

function Planet:GetStability()
    return self.stability
end

function Planet:GetStabilityState()
    return Convergence.GetStabilityState(self.stability)
end

function Planet:IsStabilityLocked()
    return self.stabilityLocked == true
end

function Planet:GetUpdatedAt()
    return self.updatedAt
end

function Planet:GetRevision()
    return self.revision
end

function Planet:ToPublicTable()
    local state = self:GetStabilityState()

    return {
        id = self:GetID(),
        name = self:GetName(),
        stability = self:GetStability(),
        stateID = state.id,
        stateName = state.name,
        locked = self:IsStabilityLocked(),
        updatedAt = self:GetUpdatedAt(),
        revision = self:GetRevision()
    }
end

function Planet:_ApplyPersistedState(stability, locked, updatedAt)
    self.stability = Convergence.ClampStability(stability)
    self.stabilityLocked = locked == true
    self.updatedAt = tonumber(updatedAt) or os.time()
    self.revision = self.revision + 1
end

function Service.IsReady()
    return Service.Ready == true
end

function Service.Get(value)
    local id = resolve(value)

    if not id then
        return nil
    end

    return Service.Cache[id]
end

function Service.GetAll()
    return Service.Cache
end

function Service.Count()
    return table.Count(Service.Cache)
end

function Service.GetByAlias(value)
    return Service.Get(value)
end

function Service.Initialize()
    if Service.Ready then
        return true
    end

    if not Convergence.Database.IsReady() then
        return false, ERROR.DATABASE_ERROR, "Database must be ready first."
    end

    Service.Cache = {}

    for id, definition in pairs(Convergence.GetPlanetDefinitions()) do
        local state, errorCode, errorMessage =
            Convergence.Database.GetPlanetState(id)

        if not state then
            return false, errorCode or ERROR.DATABASE_ERROR,
                errorMessage or ("Missing persistent state for " .. id)
        end

        Service.Cache[id] = createPlanet(definition, state)
        hook.Run("ConvergencePlanetStateLoaded", id, Service.Cache[id])
    end

    Service.Ready = true

    Convergence.Log.Info("Planets", "Planet service initialized.", {
        count = Service.Count()
    })

    hook.Run("ConvergencePlanetServiceReady", Service.Count())

    return true
end

function Service.Reload(value)
    local id = resolve(value)

    if not id then
        return false, ERROR.UNKNOWN_PLANET, "Unknown planet."
    end

    local state, errorCode, errorMessage =
        Convergence.Database.GetPlanetState(id)

    if not state then
        return false, errorCode or ERROR.DATABASE_ERROR,
            errorMessage or "Planet state could not be loaded."
    end

    local definition = Convergence.GetPlanetDefinition(id)
    local object = Service.Cache[id]

    if not object then
        object = createPlanet(definition, state)
        Service.Cache[id] = object
    else
        object:_ApplyPersistedState(
            state.stability,
            tonumber(state.locked) == 1,
            state.updated_at
        )
    end

    hook.Run("ConvergencePlanetReloaded", id, object)

    return true, object
end

function Service.ApplyStability(value, stability, locked, updatedAt)
    local planet = Service.Get(value)

    if not planet then
        return false, ERROR.UNKNOWN_PLANET, "Unknown planet."
    end

    planet:_ApplyPersistedState(stability, locked, updatedAt)

    hook.Run("ConvergencePlanetCacheUpdated", planet:GetID(), planet)

    return true, planet
end
