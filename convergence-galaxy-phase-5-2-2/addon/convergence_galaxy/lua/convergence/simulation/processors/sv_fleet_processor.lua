Convergence.Simulation.RegisterProcessor({
    id = "fleets",
    name = "Fleet Movement Processor",
    priority = 90,
    runEveryTicks = 1,

    process = function(self, tickContext)
        return {
            fleets = Convergence.Fleets.Count(),
            arrivals = Convergence.Fleets.ProcessArrivals()
        }
    end
})
