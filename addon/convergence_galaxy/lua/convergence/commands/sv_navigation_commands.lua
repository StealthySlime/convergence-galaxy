local function label(value)
    return value and "PASS" or "FAIL"
end

concommand.Add("convergence_navigation_status", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    local adapter = Convergence.Navigation.GetActiveAdapter()
    local world = Convergence.World.GetState()
    local destinationName =
        adapter and adapter.GetDestination
        and adapter:GetDestination()
        or nil
    local resolvedDestination =
        adapter and adapter.ResolvePlanet
        and adapter:ResolvePlanet(destinationName)
        or nil
    local shipPosition =
        adapter and adapter.GetShipPosition
        and adapter:GetShipPosition()
        or nil
    local inHyperspace =
        adapter and adapter.IsInHyperspace
        and adapter:IsInHyperspace()
        or false

    local expectedPlanetID = inHyperspace
        and world.currentPlanetID
        or (
            resolvedDestination
            and resolvedDestination:GetID()
            or world.currentPlanetID
        )

    local synchronizationPass =
        inHyperspace
        or expectedPlanetID == world.currentPlanetID

    print("========== Convergence Synchronization ==========")
    print("Adapter:                 " .. tostring(
        adapter and adapter.ID or "None"
    ))
    print("Adapter available:       " .. label(
        adapter and adapter:IsAvailable()
    ))
    print("SWU hyperspace:          " .. tostring(inHyperspace))
    print("SWU selected target:     " .. tostring(
        destinationName or "None"
    ))
    print("Resolved target ID:      " .. tostring(
        resolvedDestination and resolvedDestination:GetID() or "None"
    ))
    print("SWU ship position:       " .. tostring(
        shipPosition or "Unavailable"
    ))
    print("World current planet:    " .. tostring(
        world.currentPlanetID or "None"
    ))
    print("World destination:       " .. tostring(
        world.destinationPlanetID or "None"
    ))
    print("World travel status:     " .. tostring(
        world.travelStatus or "unknown"
    ))
    local profile = adapter and adapter.ActiveTravelProfile or nil

    print("Target jump duration:    " .. tostring(
        profile and profile.desiredSeconds or "Not calculated"
    ))
    print("External speed modifier: " .. tostring(
        profile and profile.externalModifier or "Not calculated"
    ))
    print("Synchronization:         " .. label(synchronizationPass))
    print("================================================")
end)

concommand.Add("convergence_ui_registry_status", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    print(
        "[Convergence] UI registry validation is clientside. "
        .. "Run convergence_ui_registry_client in the client console."
    )
end)
