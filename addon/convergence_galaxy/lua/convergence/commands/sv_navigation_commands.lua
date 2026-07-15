concommand.Add("convergence_navigation_status", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end

    local adapter = Convergence.Navigation.GetActiveAdapter()

    print("========== Convergence Navigation ==========")
    print("Active adapter: " .. tostring(
        adapter and adapter.ID or "None"
    ))
    print("Available:      " .. tostring(
        adapter and adapter:IsAvailable() or false
    ))
    print("Hyperspace:     " .. tostring(
        Convergence.Navigation.IsInHyperspace()
    ))
    print("Destination:    " .. tostring(
        Convergence.Navigation.GetDestination()
    ))

    local position = Convergence.Navigation.GetCurrentPosition()
    print("Ship position:  " .. tostring(position or "Unavailable"))

    if position
        and adapter
        and adapter.ResolveNearestPlanet then
        local nearest, distanceSquared =
            adapter:ResolveNearestPlanet(position)

        print("Nearest planet: " .. tostring(
            nearest and nearest:GetName() or "None"
        ))
        print("Distance:       " .. tostring(
            math.sqrt(distanceSquared or 0)
        ))
    end
    print("============================================")
end)
