Convergence.SWU = Convergence.SWU or {}

hook.Add("InitPostEntity", "Convergence.SWUIntegration", function()
    timer.Simple(0, function()
        if not scripted_ents.GetStored("swu_map") then
            print("[Convergence Galaxy] SWU star map not detected; SWU integration disabled.")
            return
        end

        print("[Convergence Galaxy] SWU star map detected. Adapter integration is ready for development.")
        hook.Run("ConvergenceSWUDetected")
    end)
end)
