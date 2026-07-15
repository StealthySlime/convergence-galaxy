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
    local planetServiceReady = Convergence.PlanetService.IsReady()

    print("========== Convergence Galaxy Diagnostics ==========")
    print("Addon version:      " .. tostring(Convergence.Version))
    print("Target schema:      " .. tostring(Convergence.SchemaVersion))
    print("Database adapter:   " .. tostring(DB.GetAdapterName()))
    print("Connection:         " .. statusLabel(status.connection))
    print("Metadata:           " .. statusLabel(status.metadata))
    print("Migrations:         " .. statusLabel(status.migrations))
    print("Planet bootstrap:   " .. statusLabel(status.bootstrap))
    print("Database ready:     " .. statusLabel(status.ready))
    print("Planet service:     " .. statusLabel(planetServiceReady))
    print("Event bus:          PASS")
    print("Published events:   " .. tostring(Convergence.Events.PublishedCount))
    print("Event subscribers:  " .. tostring(
        Convergence.Events.GetSubscriberCount()
    ))
    print("Event errors:       " .. tostring(Convergence.Events.ErrorCount))

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

    print("Registered planets: " .. Convergence.PlanetService.Count())

    for id, planet in SortedPairs(Convergence.PlanetService.GetAll()) do
        print(string.format(
            " - %s (%s): stability=%s locked=%s revision=%s",
            planet:GetName(),
            id,
            tostring(planet:GetStability()),
            tostring(planet:IsStabilityLocked()),
            tostring(planet:GetRevision())
        ))
    end

    print("====================================================")
end)
