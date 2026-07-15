hook.Add("ConvergenceLoaded", "Convergence.SAMIntegration", function()
    if not sam then
        print("[Convergence Galaxy] SAM not detected; SAM integration disabled.")
        return
    end

    print("[Convergence Galaxy] SAM detected. Command integration will be added in v0.2.0.")
end)
