Convergence.Planets = Convergence.Planets or {}

function Convergence.RegisterPlanet(definition)
    if not istable(definition) then
        return false, "Planet definition must be a table."
    end

    local id = Convergence.NormalizeID(definition.id)

    if id == "" then
        return false, "Planet definition is missing an ID."
    end

    definition.id = id
    definition.name = tostring(definition.name or id)
    definition.defaultStability = Convergence.ClampStability(
        definition.defaultStability or Convergence.Config.DefaultStability
    )

    Convergence.Planets[id] = definition
    hook.Run("ConvergencePlanetRegistered", id, definition)

    return true
end

function Convergence.GetPlanet(id)
    return Convergence.Planets[Convergence.NormalizeID(id)]
end

function Convergence.GetPlanets()
    return Convergence.Planets
end

for _, definition in ipairs(Convergence.Config.Planets) do
    Convergence.RegisterPlanet(table.Copy(definition))
end
