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

DB.RegisterMigration(2, "Persistent galaxy clock", function(database)
    return database.Transaction({
        [[
            CREATE TABLE IF NOT EXISTS convergence_clock (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                tick_count INTEGER NOT NULL DEFAULT 0,
                campaign_seconds REAL NOT NULL DEFAULT 0,
                paused INTEGER NOT NULL DEFAULT 0,
                time_scale REAL NOT NULL DEFAULT 1,
                updated_at INTEGER NOT NULL
            )
        ]],
        string.format(
            [[
                INSERT OR IGNORE INTO convergence_clock
                (id, tick_count, campaign_seconds, paused, time_scale, updated_at)
                VALUES (1, 0, %f, 0, 1, %d)
            ]],
            (
                ((Convergence.Config.Clock.StartingDay or 1) - 1) * 24
                + (Convergence.Config.Clock.StartingHour or 0)
            ) * (Convergence.Config.Clock.SecondsPerCampaignHour or 60),
            os.time()
        )
    })
end)

DB.RegisterMigration(3, "Planet faction influence", function(database)
    return database.Transaction({
        [[
            CREATE TABLE IF NOT EXISTS convergence_planet_influence (
                planet_id TEXT NOT NULL,
                faction_id TEXT NOT NULL,
                influence REAL NOT NULL DEFAULT 0,
                updated_at INTEGER NOT NULL,
                PRIMARY KEY (planet_id, faction_id)
            )
        ]],
        [[
            CREATE INDEX IF NOT EXISTS convergence_planet_influence_planet
            ON convergence_planet_influence (planet_id)
        ]]
    })
end)


DB.RegisterMigration(4, "Persistent fleets", function(database)
    return database.Transaction({
        [[
            CREATE TABLE IF NOT EXISTS convergence_fleets (
                fleet_id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                faction_id TEXT NOT NULL,
                current_planet_id TEXT NOT NULL,
                destination_planet_id TEXT,
                departure_campaign_seconds REAL,
                arrival_campaign_seconds REAL,
                strength INTEGER NOT NULL DEFAULT 100,
                status TEXT NOT NULL DEFAULT 'stationed',
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            )
        ]],
        [[
            CREATE INDEX IF NOT EXISTS convergence_fleets_planet
            ON convergence_fleets (current_planet_id)
        ]]
    })
end)


DB.RegisterMigration(5, "Fleet orders and missions", function(database)
    return database.Transaction({
        [[
            ALTER TABLE convergence_fleets
            ADD COLUMN order_type TEXT NOT NULL DEFAULT 'idle'
        ]],
        [[
            ALTER TABLE convergence_fleets
            ADD COLUMN order_planet_id TEXT
        ]],
        [[
            ALTER TABLE convergence_fleets
            ADD COLUMN order_started_campaign_seconds REAL
        ]],
        [[
            ALTER TABLE convergence_fleets
            ADD COLUMN order_metadata_json TEXT NOT NULL DEFAULT '{}'
        ]]
    })
end)


DB.RegisterMigration(6, "Persistent world and player task force state", function(database)
    return database.Transaction({
        [[
            CREATE TABLE IF NOT EXISTS convergence_world_state (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                current_planet_id TEXT,
                destination_planet_id TEXT,
                active_region_id TEXT,
                current_map TEXT NOT NULL,
                travel_status TEXT NOT NULL DEFAULT 'stationed',
                encounter_active INTEGER NOT NULL DEFAULT 0,
                swu_ship_x REAL,
                swu_ship_y REAL,
                swu_ship_z REAL,
                updated_at INTEGER NOT NULL
            )
        ]],
        string.format(
            [[
                INSERT OR IGNORE INTO convergence_world_state
                (
                    id, current_planet_id, destination_planet_id,
                    active_region_id, current_map, travel_status,
                    encounter_active, updated_at
                )
                VALUES
                (
                    1, %s, NULL, 'orbit', %s,
                    'stationed', 0, %d
                )
            ]],
            database.Escape(Convergence.Config.World.DefaultPlanetID or "coruscant"),
            database.Escape(game.GetMap()),
            os.time()
        )
    })
end)
