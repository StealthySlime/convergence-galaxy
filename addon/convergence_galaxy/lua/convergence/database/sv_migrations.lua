local DB = Convergence.Database

DB.RegisterMigration(1, "Initial persistent galaxy schema", function(database)
    return database.Transaction({
        [[
            CREATE TABLE IF NOT EXISTS convergence_planets (
                planet_id TEXT PRIMARY KEY,
                stability INTEGER NOT NULL,
                locked INTEGER NOT NULL DEFAULT 0,
                updated_at INTEGER NOT NULL
            )
        ]],
        [[
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
        ]],
        [[
            CREATE INDEX IF NOT EXISTS convergence_stability_history_planet_created
            ON convergence_stability_history (planet_id, created_at)
        ]]
    })
end)
