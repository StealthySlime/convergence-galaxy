concommand.Add("convergence_director", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then
        print("This command must be run by a player.")
        return
    end

    if not Convergence.Permissions.CanOpenDirector(ply) then
        ply:ChatPrint("[Convergence] Galactic Director access denied.")
        return
    end

    Convergence.OpenGalaxyUI(ply, "director")
end)
