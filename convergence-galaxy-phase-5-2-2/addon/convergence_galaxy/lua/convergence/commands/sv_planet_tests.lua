local function canTest(ply)
    return not IsValid(ply) or ply:IsSuperAdmin()
end

concommand.Add("convergence_planet_test", function(ply)
    if not canTest(ply) then
        return
    end

    print("========== Convergence Planet Service Test ==========")

    local checks = {
        {
            name = "Service ready",
            pass = Convergence.PlanetService.IsReady()
        },
        {
            name = "Count matches definitions",
            pass = Convergence.PlanetService.Count()
                == table.Count(Convergence.GetPlanetDefinitions())
        },
        {
            name = "Lookup by ID",
            pass = Convergence.PlanetService.Get("tatooine") ~= nil
        },
        {
            name = "Lookup by display name",
            pass = Convergence.PlanetService.Get("Tatooine") ~= nil
        },
        {
            name = "Unknown lookup rejected",
            pass = Convergence.PlanetService.Get("not_a_real_planet") == nil
        }
    }

    local passed = 0

    for _, check in ipairs(checks) do
        if check.pass then
            passed = passed + 1
        end

        print(string.format(
            "%-32s %s",
            check.name,
            check.pass and "PASS" or "FAIL"
        ))
    end

    print(string.format("Result: %d/%d passed", passed, #checks))
    print("====================================================")
end)
