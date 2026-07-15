Convergence.SWU = Convergence.SWU or {}

hook.Add("InitPostEntity", "Convergence.SWUClientIntegration", function()
    if scripted_ents.GetStored("swu_map") then
        hook.Run("ConvergenceSWUClientDetected")
    end
end)
