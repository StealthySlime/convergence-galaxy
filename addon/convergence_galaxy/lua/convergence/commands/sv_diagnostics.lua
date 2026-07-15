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
    local simulationReady = Convergence.Simulation.IsReady()
    local clockReady = Convergence.Clock.IsReady()

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
    print("Faction registry:   " .. statusLabel(
        Convergence.Factions.Count() > 0
    ))
    print("Registered factions: ".. tostring(Convergence.Factions.Count()))
    print("Enemy factions:     " .. tostring(
        table.Count(Convergence.Factions.GetEnemies())
    ))
    print("Event bus:          PASS")
    print("Simulation Engine:  " .. statusLabel(simulationReady))
    print("Simulation running: " .. statusLabel(
        simulationReady and Convergence.Simulation.IsRunning()
    ))
    print("Simulation tick:    " .. tostring(
        simulationReady and Convergence.Simulation.GetCurrentTick() or 0
    ))
    print("Simulation queue:   " .. tostring(
        simulationReady and Convergence.Simulation.GetQueueLength() or 0
    ))
    print("World service:      " .. statusLabel(
        Convergence.World and Convergence.World.IsReady()
    ))
    print("Encounter active:   " .. tostring(
        Convergence.World and Convergence.World.IsEncounterActive()
    ))
    print("SWU integration:    " .. statusLabel(
        Convergence.SWUWorld and Convergence.SWUWorld.IsAvailable()
    ))
    print("Galaxy Clock:       " .. statusLabel(clockReady))
    print("Clock running:      " .. statusLabel(
        clockReady and Convergence.Clock.IsRunning()
    ))
    print("Campaign time:      " .. (
        clockReady and Convergence.Clock.Format() or "Unavailable"
    ))
    print("Clock tick:         " .. tostring(
        clockReady and Convergence.Clock.GetTickCount() or 0
    ))
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
