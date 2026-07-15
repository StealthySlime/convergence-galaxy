Convergence.Planets = Convergence.Planets or {}

local Registry = Convergence.Planets

Registry.Definitions = Registry.Definitions or {}
Registry.Aliases = Registry.Aliases or {}

local function registerAlias(alias, planetID)
    alias = Convergence.NormalizeID(alias)

    if alias == "" then
        return
    end

    Registry.Aliases[alias] = planetID
end

function Convergence.RegisterPlanet(definition)
    if not istable(definition) then
        return false, Convergence.Constants.ERROR.INVALID_ARGUMENT,
            "Planet definition must be a table."
    end

    local id = Convergence.NormalizeID(definition.id)

    if id == "" then
        return false, Convergence.Constants.ERROR.INVALID_ARGUMENT,
            "Planet definition is missing a valid ID."
    end

    if Registry.Definitions[id] then
        return false, Convergence.Constants.ERROR.INVALID_ARGUMENT,
            "Planet is already registered: " .. id
    end

    local normalized = table.Copy(definition)

    normalized.id = id
    normalized.name = tostring(normalized.name or id)
    normalized.aliases = istable(normalized.aliases) and normalized.aliases or {}
    normalized.defaultStability = Convergence.ClampStability(
        normalized.defaultStability or Convergence.Config.DefaultStability
    )

    Registry.Definitions[id] = normalized

    registerAlias(id, id)
    registerAlias(normalized.name, id)

    for _, alias in ipairs(normalized.aliases) do
        registerAlias(alias, id)
    end

    hook.Run("ConvergencePlanetRegistered", id, normalized)

    return true, normalized
end

function Convergence.ResolvePlanetID(value)
    local normalized = Convergence.NormalizeID(value)

    if normalized == "" then
        return nil
    end

    if Registry.Definitions[normalized] then
        return normalized
    end

    return Registry.Aliases[normalized]
end

function Convergence.GetPlanetDefinition(value)
    local id = Convergence.ResolvePlanetID(value)

    if not id then
        return nil
    end

    return Registry.Definitions[id]
end

function Convergence.GetPlanetDefinitions()
    return Registry.Definitions
end

function Convergence.IsPlanetRegistered(value)
    return Convergence.ResolvePlanetID(value) ~= nil
end

-- Compatibility aliases retained for existing integrations.
function Convergence.GetPlanet(value)
    if SERVER and Convergence.PlanetService and Convergence.PlanetService.IsReady() then
        return Convergence.PlanetService.Get(value)
    end

    return Convergence.GetPlanetDefinition(value)
end

function Convergence.GetPlanets()
    if SERVER and Convergence.PlanetService and Convergence.PlanetService.IsReady() then
        return Convergence.PlanetService.GetAll()
    end

    return Convergence.GetPlanetDefinitions()
end

for _, definition in ipairs(Convergence.Config.Planets) do
    local success, errorCode, errorMessage = Convergence.RegisterPlanet(definition)

    if not success then
        Convergence.Log.Error("Planets", errorMessage, {
            code = errorCode
        })
    end
end
