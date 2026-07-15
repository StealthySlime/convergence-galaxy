Convergence.Database = Convergence.Database or {}

local DB = Convergence.Database

function DB.Initialize()
    sql.Query([[
        CREATE TABLE IF NOT EXISTS convergence_planets (
            planet_id TEXT PRIMARY KEY,
            stability INTEGER NOT NULL,
            locked INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL
        )
    ]])

    sql.Query([[
        CREATE TABLE IF NOT EXISTS convergence_stability_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            planet_id TEXT NOT NULL,
            previous_value INTEGER NOT NULL,
            new_value INTEGER NOT NULL,
            delta INTEGER NOT NULL,
            source TEXT NOT NULL,
            actor TEXT NOT NULL,
            reason TEXT NOT NULL,
            created_at INTEGER NOT NULL
        )
    ]])

    if sql.LastError() ~= "" then
        ErrorNoHalt("[Convergence Galaxy] SQLite initialization error: " .. sql.LastError() .. "\n")
    end
end

function DB.Escape(value)
    return sql.SQLStr(tostring(value or ""))
end

function DB.EnsurePlanet(planet)
    local existing = sql.QueryRow(
        "SELECT planet_id FROM convergence_planets WHERE planet_id = " .. DB.Escape(planet.id)
    )

    if existing then
        return
    end

    sql.Query(string.format(
        "INSERT INTO convergence_planets (planet_id, stability, locked, updated_at) VALUES (%s, %d, 0, %d)",
        DB.Escape(planet.id),
        planet.defaultStability,
        os.time()
    ))
end

function DB.GetPlanetState(planetID)
    return sql.QueryRow(
        "SELECT * FROM convergence_planets WHERE planet_id = " .. DB.Escape(planetID)
    )
end

function DB.SetPlanetState(planetID, stability, locked)
    sql.Query(string.format(
        "UPDATE convergence_planets SET stability = %d, locked = %d, updated_at = %d WHERE planet_id = %s",
        Convergence.ClampStability(stability),
        locked and 1 or 0,
        os.time(),
        DB.Escape(planetID)
    ))
end

function DB.AddStabilityHistory(entry)
    sql.Query(string.format(
        [[
            INSERT INTO convergence_stability_history
            (planet_id, previous_value, new_value, delta, source, actor, reason, created_at)
            VALUES (%s, %d, %d, %d, %s, %s, %s, %d)
        ]],
        DB.Escape(entry.planetID),
        entry.previousValue,
        entry.newValue,
        entry.delta,
        DB.Escape(entry.source),
        DB.Escape(entry.actor),
        DB.Escape(entry.reason),
        entry.createdAt
    ))
end

function DB.GetStabilityHistory(planetID, limit)
    limit = math.Clamp(tonumber(limit) or 25, 1, 100)

    return sql.Query(string.format(
        "SELECT * FROM convergence_stability_history WHERE planet_id = %s ORDER BY id DESC LIMIT %d",
        DB.Escape(planetID),
        limit
    )) or {}
end

hook.Add("Initialize", "Convergence.Database.Initialize", function()
    DB.Initialize()

    for _, planet in pairs(Convergence.GetPlanets()) do
        DB.EnsurePlanet(planet)
    end
end)
