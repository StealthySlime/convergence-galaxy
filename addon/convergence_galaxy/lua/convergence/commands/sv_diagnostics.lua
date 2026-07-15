local function canUseDiagnostics(ply)
    return not IsValid(ply) or ply:IsAdmin()
end

local function statusLabel(value)
    return value and "PASS" or "FAIL"
end

concommand.Add("convergence_diagnostics", function(ply)
    if not canUseDiagnostics(ply) then
        return
    end

    local DB = Convergence.Database
    local status = DB.GetStatus()
    local schemaSuccess, schemaOrCode, schemaMessage = DB.GetSchemaVersion()

    print("========== Convergence Galaxy Diagnostics ==========")
    print("Addon version:      " .. tostring(Convergence.Version))
    print("Target schema:      " .. tostring(Convergence.SchemaVersion))
    print("Database adapter:   " .. tostring(DB.GetAdapterName()))
    print("Connection:         " .. statusLabel(status.connection))
    print("Metadata:           " .. statusLabel(status.metadata))
    print("Migrations:         " .. statusLabel(status.migrations))
    print("Planet bootstrap:   " .. statusLabel(status.bootstrap))
    print("Database ready:     " .. statusLabel(status.ready))

    if schemaSuccess then
        print("Installed schema:   " .. tostring(schemaOrCode))
    else
        print("Installed schema:   ERROR")
        print("Schema error:       " .. tostring(schemaMessage))
    end

    if status.lastErrorCode then
        print("Last error code:    " .. tostring(status.lastErrorCode))
        print("Last error message: " .. tostring(status.lastErrorMessage))
    end

    local planets = Convergence.GetPlanets()
    print("Registered planets: " .. table.Count(planets))

    for id, definition in SortedPairs(planets) do
        local state, errorCode, errorMessage = DB.GetPlanetState(id)

        if state then
            print(string.format(
                " - %s (%s): stability=%s locked=%s",
                definition.name,
                id,
                tostring(state.stability),
                tostring(tonumber(state.locked) == 1)
            ))
        else
            print(string.format(
                " - %s (%s): ERROR %s %s",
                definition.name,
                id,
                tostring(errorCode),
                tostring(errorMessage)
            ))
        end
    end

    print("====================================================")
end)
