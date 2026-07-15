Convergence.SWUPlanetMapping = Convergence.SWUPlanetMapping or {
    coruscant = {
        navigationName = "Coruscant",
        position = Vector(-387.5, -555.2, 0)
    },
    tatooine = {
        navigationName = "Tatooine",
        position = Vector(650, -420, 0)
    },
    reach = {
        navigationName = "Reach",
        position = Vector(220, 180, 0)
    }
}

-- Config.Planets is an array. Always key mappings by definition.id rather than
-- the numeric ipairs/pairs index.
for _, definition in ipairs(Convergence.Config.Planets or {}) do
    local planetID = Convergence.NormalizeID(definition.id)

    if planetID ~= ""
        and not Convergence.SWUPlanetMapping[planetID]
        and definition.swu
        and isvector(definition.swu.pos) then
        Convergence.SWUPlanetMapping[planetID] = {
            navigationName = definition.swu.name
                or definition.name
                or planetID,
            position = Vector(
                definition.swu.pos.x,
                definition.swu.pos.y,
                definition.swu.pos.z
            )
        }
    end
end
