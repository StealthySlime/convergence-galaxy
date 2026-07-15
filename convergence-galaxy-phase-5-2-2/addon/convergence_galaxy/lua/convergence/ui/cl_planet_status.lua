concommand.Add("convergence_planet_status", function(_, _, args)
    local planetID = Convergence.NormalizeID(args[1])

    if planetID == "" then
        print("Usage: convergence_planet_status <planet_id>")
        return
    end

    Convergence.RequestPlanetState(planetID)

    timer.Simple(0.25, function()
        local planet = Convergence.ClientPlanets[planetID]

        if not planet then
            print("[Convergence] No planet data received.")
            return
        end

        print(string.format(
            "[Convergence] %s: %d%% - %s%s",
            planet.name,
            planet.stability,
            planet.stateName,
            planet.locked and " [LOCKED]" or ""
        ))
    end)
end)
