local function canUseDiagnostics(ply)
    return not IsValid(ply) or ply:IsAdmin()
end

concommand.Add("convergence_diagnostics", function(ply)
    if not canUseDiagnostics(ply) then
        return
    end

    local DB = Convergence.Database
    local schemaSuccess, schemaOrCode, schemaMessage = DB.GetSchemaVersion()

    print("========== Convergence Galaxy Diagnostics ==========")
    print("Addon version: " .. tostring(Convergence.Version))
    print("Target schema: " .. tostring(Convergence.SchemaVersion))
    print("Database adapter: " .. tostring(DB.GetAdapterName()))
    print("Database ready: " .. tostring(DB.IsReady()))

    if schemaSuccess then
        print("Installed schema: " .. tostring(schemaOrCode))
    else
        print("Installed schema: ERROR " .. tostring(schemaOrCode))
        print("Schema error: " .. tostring(schemaMessage))
    end

    local planetCount = table.Count(Convergence.GetPlanets())
    print("Registered planets: " .. planetCount)

    for id, definition in SortedPairs(Convergence.GetPlanets()) do
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
