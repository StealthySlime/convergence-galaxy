Convergence.Simulation.RegisterProcessor({
    id = "planets",
    name = "Planet State Processor",
    priority = 100,
    runEveryTicks = 1,

    process = function(self, tickContext)
        local processed = 0

        for id, planet in pairs(Convergence.PlanetService.GetAll()) do
            hook.Run("ConvergenceSimulatePlanet", planet, tickContext)
            processed = processed + 1

            Convergence.Events.Publish("simulation.planet.processed", {
                planetID = id,
                revision = planet:GetRevision(),
                tick = tickContext.tick
            })
        end

        return {
            planetsProcessed = processed
        }
    end
})
