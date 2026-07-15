concommand.Add("convergence_galaxy", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then
        print("This command must be run by a player.")
        return
    end

    Convergence.OpenGalaxyUI(ply)
end)

concommand.Add("convergence_ui_open", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then
        return
    end

    Convergence.OpenGalaxyUI(ply)
end)
