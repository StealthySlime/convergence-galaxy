Convergence.Database = Convergence.Database or {}

local DB = Convergence.Database
local ERROR = Convergence.Constants.ERROR

DB.AdapterName = "sqlite"
DB.Ready = false
DB.Migrations = DB.Migrations or {}

local function getLastError()
    return tostring(sql.LastError() or "")
end

local function hasError()
    local message = getLastError()
    return message ~= "" and message ~= "not an error"
end

function DB.GetAdapterName()
    return DB.AdapterName
end

function DB.IsReady()
    return DB.Ready == true
end

function DB.Escape(value)
    return sql.SQLStr(tostring(value or ""))
end

function DB.Query(query)
    if not isstring(query) or string.Trim(query) == "" then
        return false, ERROR.INVALID_ARGUMENT, "Database query must be a non-empty string."
    end

    local result = sql.Query(query)

    if result == false or hasError() then
        local message = getLastError()

        Convergence.Log.Error("Database", "SQLite query failed.", {
            error = message,
            query = query
        })

        return false, ERROR.DATABASE_ERROR, message
    end

    return true, result
end

function DB.QueryRow(query)
    local success, resultOrCode, message = DB.Query(query)

    if not success then
        return false, resultOrCode, message
    end

    local rows = resultOrCode

    if not istable(rows) or not rows[1] then
        return true, nil
    end

    return true, rows[1]
end

function DB.Execute(query)
    local success, resultOrCode, message = DB.Query(query)

    if not success then
        return false, resultOrCode, message
    end

    return true
end

function DB.Transaction(operations)
    if not istable(operations) or #operations == 0 then
        return false, ERROR.INVALID_ARGUMENT, "Transaction requires at least one operation."
    end

    local beginSuccess, beginCode, beginMessage = DB.Execute("BEGIN")

    if not beginSuccess then
        return false, beginCode, beginMessage
    end

    for index, operation in ipairs(operations) do
        local query = isfunction(operation) and operation() or operation
        local success, errorCode, errorMessage = DB.Execute(query)

        if not success then
            DB.Execute("ROLLBACK")

            return false, errorCode,
                string.format("Transaction operation %d failed: %s", index, errorMessage)
        end
    end

    local commitSuccess, commitCode, commitMessage = DB.Execute("COMMIT")

    if not commitSuccess then
        DB.Execute("ROLLBACK")
        return false, commitCode, commitMessage
    end

    return true
end

function DB.RegisterMigration(version, name, run)
    version = tonumber(version)

    if not version or version < 1 or version % 1 ~= 0 then
        return false, ERROR.INVALID_ARGUMENT, "Migration version must be a positive integer."
    end

    if DB.Migrations[version] then
        return false, ERROR.INVALID_ARGUMENT, "Migration version already registered."
    end

    if not isfunction(run) then
        return false, ERROR.INVALID_ARGUMENT, "Migration run field must be a function."
    end

    DB.Migrations[version] = {
        version = version,
        name = tostring(name or ("Migration " .. version)),
        run = run
    }

    return true
end

function DB.GetMeta(key)
    local success, rowOrCode, message = DB.QueryRow(
        "SELECT value FROM convergence_meta WHERE key = " .. DB.Escape(key)
    )

    if not success then
        return false, rowOrCode, message
    end

    return true, rowOrCode and rowOrCode.value or nil
end

function DB.SetMeta(key, value)
    local query = string.format(
        "INSERT OR REPLACE INTO convergence_meta (key, value) VALUES (%s, %s)",
        DB.Escape(key),
        DB.Escape(value)
    )

    return DB.Execute(query)
end

function DB.GetSchemaVersion()
    local success, valueOrCode, message = DB.GetMeta("schema_version")

    if not success then
        return false, valueOrCode, message
    end

    return true, tonumber(valueOrCode) or 0
end

function DB.RunMigrations()
    local success, currentOrCode, message = DB.GetSchemaVersion()

    if not success then
        return false, currentOrCode, message
    end

    local currentVersion = currentOrCode
    local targetVersion = Convergence.SchemaVersion

    if currentVersion > targetVersion then
        return false, ERROR.DATABASE_ERROR,
            string.format(
                "Database schema %d is newer than addon schema %d.",
                currentVersion,
                targetVersion
            )
    end

    for version = currentVersion + 1, targetVersion do
        local migration = DB.Migrations[version]

        if not migration then
            return false, ERROR.DATABASE_ERROR,
                "Missing database migration version " .. version .. "."
        end

        Convergence.Log.Info("Database", "Running migration.", {
            version = version,
            name = migration.name
        })

        local ok, migrationSuccess, errorCode, errorMessage = xpcall(function()
            return migration.run(DB)
        end, debug.traceback)

        if not ok then
            return false, ERROR.DATABASE_ERROR, migrationSuccess
        end

        if migrationSuccess == false then
            return false, errorCode or ERROR.DATABASE_ERROR,
                errorMessage or "Migration failed."
        end

        local versionSaved, saveCode, saveMessage = DB.SetMeta("schema_version", version)

        if not versionSaved then
            return false, saveCode, saveMessage
        end

        DB.SetMeta("last_migration_at", os.time())

        Convergence.Log.Info("Database", "Migration completed.", {
            version = version,
            name = migration.name
        })
    end

    return true
end

function DB.Initialize()
    if DB.Ready then
        return true
    end

    local metaSuccess, metaCode, metaMessage = DB.Execute([[
        CREATE TABLE IF NOT EXISTS convergence_meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
    ]])

    if not metaSuccess then
        return false, metaCode, metaMessage
    end

    -- Existing Phase 1 installations already have their original tables but no
    -- schema metadata. Migration 1 uses CREATE TABLE IF NOT EXISTS, so adopting
    -- them is safe and preserves all existing planet values and history.
    local migrationSuccess, migrationCode, migrationMessage = DB.RunMigrations()

    if not migrationSuccess then
        return false, migrationCode, migrationMessage
    end

    DB.SetMeta("addon_version", Convergence.Version)

    local createdSuccess, createdValue = DB.GetMeta("created_at")

    if createdSuccess and not createdValue then
        DB.SetMeta("created_at", os.time())
    end

    DB.Ready = true

    for _, planet in pairs(Convergence.GetPlanets()) do
        local ensured, ensureCode, ensureMessage = DB.EnsurePlanet(planet)

        if not ensured then
            DB.Ready = false
            return false, ensureCode, ensureMessage
        end
    end

    hook.Run("ConvergenceDatabaseReady", DB.AdapterName)

    Convergence.Log.Info("Database", "Database initialized.", {
        adapter = DB.AdapterName,
        schema = Convergence.SchemaVersion
    })

    return true
end

function DB.EnsurePlanet(planet)
    if not istable(planet) or not isstring(planet.id) then
        return false, ERROR.INVALID_ARGUMENT, "Invalid planet definition."
    end

    local success, existingOrCode, message = DB.QueryRow(
        "SELECT planet_id FROM convergence_planets WHERE planet_id = " .. DB.Escape(planet.id)
    )

    if not success then
        return false, existingOrCode, message
    end

    if existingOrCode then
        return true
    end

    return DB.Execute(string.format(
        "INSERT INTO convergence_planets (planet_id, stability, locked, updated_at) VALUES (%s, %d, 0, %d)",
        DB.Escape(planet.id),
        Convergence.ClampStability(planet.defaultStability),
        os.time()
    ))
end

function DB.GetPlanetState(planetID)
    local success, rowOrCode, message = DB.QueryRow(
        "SELECT * FROM convergence_planets WHERE planet_id = " .. DB.Escape(planetID)
    )

    if not success then
        return nil, rowOrCode, message
    end

    return rowOrCode
end

function DB.SetPlanetState(planetID, stability, locked)
    return DB.Execute(string.format(
        "UPDATE convergence_planets SET stability = %d, locked = %d, updated_at = %d WHERE planet_id = %s",
        Convergence.ClampStability(stability),
        locked and 1 or 0,
        os.time(),
        DB.Escape(planetID)
    ))
end

function DB.AddStabilityHistory(entry)
    return DB.Execute(string.format(
        [[
            INSERT INTO convergence_stability_history
            (planet_id, previous_value, new_value, delta, source, actor, reason, created_at)
            VALUES (%s, %d, %d, %d, %s, %s, %s, %d)
        ]],
        DB.Escape(entry.planetID),
        tonumber(entry.previousValue) or 0,
        tonumber(entry.newValue) or 0,
        tonumber(entry.delta) or 0,
        DB.Escape(entry.source),
        DB.Escape(entry.actor),
        DB.Escape(entry.reason),
        tonumber(entry.createdAt) or os.time()
    ))
end

function DB.GetStabilityHistory(planetID, limit)
    limit = math.Clamp(tonumber(limit) or 25, 1, 100)

    local success, rowsOrCode, message = DB.Query(string.format(
        "SELECT * FROM convergence_stability_history WHERE planet_id = %s ORDER BY id DESC LIMIT %d",
        DB.Escape(planetID),
        limit
    ))

    if not success then
        return {}, rowsOrCode, message
    end

    return rowsOrCode or {}
end
