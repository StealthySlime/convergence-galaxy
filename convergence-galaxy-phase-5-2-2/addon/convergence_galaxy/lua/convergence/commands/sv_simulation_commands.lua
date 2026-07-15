local function canManage(ply)
    return not IsValid(ply) or ply:IsSuperAdmin()
end

concommand.Add("convergence_simulation_status", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    local lastTick = Convergence.Simulation.GetLastTick()

    print("========== Convergence Simulation Engine ==========")
    print("Ready:                   " .. tostring(Convergence.Simulation.IsReady()))
    print("Running:                 " .. tostring(Convergence.Simulation.IsRunning()))
    print("Simulation tick:         " .. tostring(
        Convergence.Simulation.GetCurrentTick()
    ))
    print("Processors:              " .. tostring(
        Convergence.Simulation.GetProcessorCount()
    ))
    print("Queue length:            " .. tostring(
        Convergence.Simulation.GetQueueLength()
    ))
    print("Actions processed total: " .. tostring(
        Convergence.Simulation.TotalActionsProcessed
    ))
    print("Processor errors total:  " .. tostring(
        Convergence.Simulation.TotalErrors
    ))

    if lastTick then
        print("Last tick duration:      " .. string.format(
            "%.3f ms",
            lastTick.durationMilliseconds or 0
        ))
        print("Last actions processed:  " .. tostring(
            lastTick.actionsProcessed or 0
        ))
    end

    for _, processorID in ipairs(Convergence.Simulation.ProcessorOrder) do
        local processor = Convergence.Simulation.GetProcessor(processorID)

        print(string.format(
            " - %s: enabled=%s priority=%s every=%s",
            processor.id,
            tostring(processor.enabled),
            tostring(processor.priority),
            tostring(processor.runEveryTicks)
        ))
    end

    print("===================================================")
end)

concommand.Add("convergence_simulation_start", function(ply)
    if not canManage(ply) then
        return
    end

    local success, errorCode, errorMessage =
        Convergence.Simulation.Start()

    print(success
        and "Simulation Engine started."
        or string.format("Failed [%s]: %s", errorCode, errorMessage))
end)

concommand.Add("convergence_simulation_stop", function(ply)
    if not canManage(ply) then
        return
    end

    Convergence.Simulation.Stop()
    print("Simulation Engine stopped.")
end)

concommand.Add("convergence_simulation_step", function(ply)
    if not canManage(ply) then
        return
    end

    local wasRunning = Convergence.Simulation.IsRunning()

    if not wasRunning then
        Convergence.Simulation.Start()
    end

    local success, resultOrCode, errorMessage =
        Convergence.Simulation.Step(Convergence.Clock.GetTimeTable())

    if not wasRunning then
        Convergence.Simulation.Stop()
    end

    print(success
        and string.format(
            "Simulation tick %d completed in %.3f ms.",
            resultOrCode.tick,
            resultOrCode.durationMilliseconds
        )
        or string.format("Failed [%s]: %s", resultOrCode, errorMessage))
end)

concommand.Add("convergence_simulation_queue_test", function(ply)
    if not canManage(ply) then
        return
    end

    local success, actionOrCode, errorMessage =
        Convergence.Simulation.Enqueue(
            "test_action",
            {
                message = "Simulation queue test"
            },
            {
                actor = ply,
                source = "console",
                reason = "Simulation queue test."
            }
        )

    print(success
        and ("Queued test action #" .. actionOrCode.id)
        or string.format("Failed [%s]: %s", actionOrCode, errorMessage))
end)

concommand.Add("convergence_simulation_test", function(ply)
    if not canManage(ply) then
        return
    end

    print("========== Convergence Simulation Test ==========")

    local checks = {}

    checks.ready = Convergence.Simulation.IsReady()
    checks.running = Convergence.Simulation.IsRunning()
    checks.processor = Convergence.Simulation.GetProcessor("planets") ~= nil

    local beforeActions = Convergence.Simulation.TotalActionsProcessed
    local queued = Convergence.Simulation.Enqueue("automated_test", {
        value = 1
    }, {
        source = "simulation_test",
        reason = "Automated simulation test."
    })

    checks.queue = queued == true
        and Convergence.Simulation.GetQueueLength() >= 1

    local beforeTick = Convergence.Simulation.GetCurrentTick()
    local stepped, tickResult = Convergence.Simulation.Step(
        Convergence.Clock.GetTimeTable()
    )

    checks.step = stepped == true
        and Convergence.Simulation.GetCurrentTick() == beforeTick + 1

    checks.action = Convergence.Simulation.TotalActionsProcessed
        == beforeActions + 1

    local planetResult = nil

    if stepped then
        for _, result in ipairs(tickResult.processorResults or {}) do
            if result.id == "planets" then
                planetResult = result
                break
            end
        end
    end

    checks.planetProcessor = planetResult ~= nil
        and planetResult.success == true

    local passed = 0

    for name, result in SortedPairs(checks) do
        if result then
            passed = passed + 1
        end

        print(string.format(
            "%-32s %s",
            name,
            result and "PASS" or "FAIL"
        ))
    end

    print(string.format("Result: %d/%d passed", passed, table.Count(checks)))
    print("================================================")
end)
