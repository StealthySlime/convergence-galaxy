Convergence.Simulation.RegisterProcessor({
    id = "campaign_events",
    name = "Campaign Event Processor",
    priority = 70,
    runEveryTicks = 1,

    process = function(self, tickContext)
        return {
            autoResolved = Convergence.CampaignEvents.Process(),
            activeDeployment = Convergence.Deployments.GetActive() ~= nil
        }
    end
})
