Convergence.Simulation.RegisterProcessor({
    id = "fleet_orders",
    name = "Fleet Orders Processor",
    priority = 80,
    runEveryTicks = 1,

    process = function(self, tickContext)
        return {
            processedOrders = Convergence.FleetOrders.Process()
        }
    end
})
