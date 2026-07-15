Convergence.Simulation = Convergence.Simulation or {}

local Simulation = Convergence.Simulation
local ERROR = Convergence.Constants.ERROR

Simulation.Ready = false
Simulation.Running = false
Simulation.CurrentTick = 0
Simulation.Processors = Simulation.Processors or {}
Simulation.ProcessorOrder = Simulation.ProcessorOrder or {}
Simulation.Queue = Simulation.Queue or {}
Simulation.NextActionID = Simulation.NextActionID or 0
Simulation.History = Simulation.History or {}
Simulation.LastTick = nil
Simulation.TotalErrors = Simulation.TotalErrors or 0
Simulation.TotalActionsProcessed = Simulation.TotalActionsProcessed or 0

local function historyLimit()
    return math.max(
        math.floor(tonumber(Convergence.Config.Simulation.HistoryLimit) or 100),
        1
    )
end

local function addHistory(entry)
    Simulation.History[#Simulation.History + 1] = entry

    while #Simulation.History > historyLimit() do
        table.remove(Simulation.History, 1)
    end
end

local function sortProcessors()
    table.sort(Simulation.ProcessorOrder, function(leftID, rightID)
        local left = Simulation.Processors[leftID]
        local right = Simulation.Processors[rightID]

        if left.priority == right.priority then
            return leftID < rightID
        end

        return left.priority > right.priority
    end)
end

function Simulation.IsReady()
    return Simulation.Ready == true
end

function Simulation.IsRunning()
    return Simulation.Running == true
end

function Simulation.GetCurrentTick()
    return Simulation.CurrentTick
end

function Simulation.GetQueueLength()
    return #Simulation.Queue
end

function Simulation.GetProcessorCount()
    return table.Count(Simulation.Processors)
end

function Simulation.GetLastTick()
    return Simulation.LastTick and table.Copy(Simulation.LastTick) or nil
end

function Simulation.GetHistory(limit)
    limit = math.Clamp(tonumber(limit) or 25, 1, historyLimit())

    local result = {}
    local first = math.max(#Simulation.History - limit + 1, 1)

    for index = first, #Simulation.History do
        result[#result + 1] = table.Copy(Simulation.History[index])
    end

    return result
end

function Simulation.RegisterProcessor(definition)
    if not istable(definition) then
        return false, ERROR.INVALID_ARGUMENT, "Processor definition must be a table."
    end

    local id = Convergence.NormalizeID(definition.id)

    if id == "" then
        return false, ERROR.INVALID_ARGUMENT, "Processor requires a valid ID."
    end

    if Simulation.Processors[id] then
        return false, ERROR.INVALID_ARGUMENT, "Processor already registered: " .. id
    end

    if not isfunction(definition.process) then
        return false, ERROR.INVALID_ARGUMENT, "Processor process field must be a function."
    end

    definition.id = id
    definition.name = tostring(definition.name or id)
    definition.priority = tonumber(definition.priority) or 0
    definition.enabled = definition.enabled ~= false
    definition.runEveryTicks = math.max(
        math.floor(tonumber(definition.runEveryTicks) or 1),
        1
    )

    Simulation.Processors[id] = definition
    Simulation.ProcessorOrder[#Simulation.ProcessorOrder + 1] = id
    sortProcessors()

    Convergence.Events.Publish("simulation.processor.registered", {
        id = id,
        name = definition.name,
        priority = definition.priority,
        runEveryTicks = definition.runEveryTicks
    })

    return true, definition
end

function Simulation.GetProcessor(id)
    return Simulation.Processors[Convergence.NormalizeID(id)]
end

function Simulation.SetProcessorEnabled(id, enabled)
    local processor = Simulation.GetProcessor(id)

    if not processor then
        return false, ERROR.INVALID_ARGUMENT, "Unknown processor."
    end

    processor.enabled = enabled == true

    Convergence.Events.Publish("simulation.processor.enabled.changed", {
        id = processor.id,
        enabled = processor.enabled
    })

    return true, processor
end

function Simulation.Enqueue(actionType, payload, context)
    actionType = Convergence.NormalizeID(actionType)

    if actionType == "" then
        return false, ERROR.INVALID_ARGUMENT, "Action type is invalid."
    end

    Simulation.NextActionID = Simulation.NextActionID + 1

    local action = {
        id = Simulation.NextActionID,
        type = actionType,
        payload = istable(payload) and payload or {},
        context = istable(context) and context or {},
        createdAt = os.time(),
        createdTick = Simulation.CurrentTick
    }

    Simulation.Queue[#Simulation.Queue + 1] = action

    Convergence.Events.Publish("simulation.action.queued", {
        action = table.Copy(action)
    }, action.context)

    return true, action
end

local function processQueuedActions(tickContext)
    local maximum = math.max(
        math.floor(
            tonumber(Convergence.Config.Simulation.MaxQueuedActionsPerTick) or 100
        ),
        1
    )

    local processed = 0

    while processed < maximum and #Simulation.Queue > 0 do
        local action = table.remove(Simulation.Queue, 1)

        Convergence.Events.Publish("simulation.action.processing", {
            action = table.Copy(action),
            tick = tickContext.tick
        }, action.context)

        local allowed, reason = hook.Run(
            "ConvergenceSimulationAction",
            action.type,
            action,
            tickContext
        )

        if allowed == false then
            Convergence.Events.Publish("simulation.action.rejected", {
                action = table.Copy(action),
                reason = tostring(reason or "Rejected by hook.")
            }, action.context)
        else
            Convergence.Events.Publish("simulation.action.processed", {
                action = table.Copy(action),
                tick = tickContext.tick
            }, action.context)
        end

        processed = processed + 1
        Simulation.TotalActionsProcessed = Simulation.TotalActionsProcessed + 1
    end

    return processed
end

local function processProcessor(processor, tickContext)
    if not processor.enabled then
        return {
            id = processor.id,
            skipped = true,
            reason = "disabled",
            durationMilliseconds = 0
        }
    end

    if tickContext.tick % processor.runEveryTicks ~= 0 then
        return {
            id = processor.id,
            skipped = true,
            reason = "cadence",
            durationMilliseconds = 0
        }
    end

    local started = SysTime()

    local ok, result = xpcall(function()
        return processor:process(tickContext)
    end, debug.traceback)

    local durationMilliseconds = (SysTime() - started) * 1000

    if not ok then
        Simulation.TotalErrors = Simulation.TotalErrors + 1

        Convergence.Log.Error("Simulation", "Processor failed.", {
            processor = processor.id,
            error = result,
            tick = tickContext.tick
        })

        Convergence.Events.Publish("simulation.processor.failed", {
            id = processor.id,
            error = result,
            tick = tickContext.tick,
            durationMilliseconds = durationMilliseconds
        })

        return {
            id = processor.id,
            success = false,
            error = result,
            durationMilliseconds = durationMilliseconds
        }
    end

    local maximumMilliseconds = math.max(
        tonumber(Convergence.Config.Simulation.MaxProcessorMilliseconds) or 25,
        1
    )

    if durationMilliseconds > maximumMilliseconds then
        Convergence.Log.Warn("Simulation", "Processor exceeded time budget.", {
            processor = processor.id,
            durationMilliseconds = string.format("%.3f", durationMilliseconds),
            budgetMilliseconds = maximumMilliseconds
        })
    end

    return {
        id = processor.id,
        success = true,
        result = result,
        durationMilliseconds = durationMilliseconds
    }
end

function Simulation.Step(clockTime)
    if not Simulation.Ready then
        return false, ERROR.INVALID_ARGUMENT, "Simulation Engine is not ready."
    end

    if not Simulation.Running then
        return false, ERROR.INVALID_ARGUMENT, "Simulation Engine is not running."
    end

    Simulation.CurrentTick = Simulation.CurrentTick + 1

    local tickContext = {
        tick = Simulation.CurrentTick,
        clock = table.Copy(clockTime or {}),
        startedAt = SysTime(),
        processorResults = {},
        queuedActionsBefore = #Simulation.Queue
    }

    Convergence.Events.Publish("simulation.tick.started", {
        tick = tickContext.tick,
        clock = tickContext.clock,
        queueLength = tickContext.queuedActionsBefore
    })

    local actionsProcessed = processQueuedActions(tickContext)

    for _, processorID in ipairs(Simulation.ProcessorOrder) do
        local processor = Simulation.Processors[processorID]
        local result = processProcessor(processor, tickContext)

        tickContext.processorResults[#tickContext.processorResults + 1] = result

        if result.success == false
            and Convergence.Config.Simulation.StopOnProcessorError then
            break
        end
    end

    tickContext.actionsProcessed = actionsProcessed
    tickContext.queuedActionsAfter = #Simulation.Queue
    tickContext.durationMilliseconds = (SysTime() - tickContext.startedAt) * 1000

    Simulation.LastTick = tickContext
    addHistory(tickContext)

    Convergence.Events.Publish("simulation.tick.completed", {
        tick = tickContext.tick,
        actionsProcessed = actionsProcessed,
        queueLength = tickContext.queuedActionsAfter,
        durationMilliseconds = tickContext.durationMilliseconds,
        processorResults = table.Copy(tickContext.processorResults)
    })

    hook.Run("ConvergenceSimulationTick", tickContext)

    return true, tickContext
end

function Simulation.Start()
    if not Simulation.Ready then
        return false, ERROR.INVALID_ARGUMENT, "Simulation Engine is not ready."
    end

    if Simulation.Running then
        return true
    end

    Simulation.Running = true

    Convergence.Events.Publish("simulation.started", {
        tick = Simulation.CurrentTick
    })

    return true
end

function Simulation.Stop()
    Simulation.Running = false

    Convergence.Events.Publish("simulation.stopped", {
        tick = Simulation.CurrentTick
    })

    return true
end

function Simulation.Initialize()
    if Simulation.Ready then
        return true
    end

    if not Convergence.Database.IsReady() then
        return false, ERROR.DATABASE_ERROR, "Database must be ready first."
    end

    if not Convergence.PlanetService.IsReady() then
        return false, ERROR.INVALID_ARGUMENT, "Planet Service must be ready first."
    end

    Simulation.Ready = true
    Simulation.Start()

    Convergence.Events.Subscribe(
        "clock.tick",
        function(event)
            if Simulation.Running then
                Simulation.Step(event.payload)
            end
        end,
        {
            owner = "simulation_engine",
            priority = 1000
        }
    )

    Convergence.Log.Info("Simulation", "Simulation Engine initialized.", {
        processors = Simulation.GetProcessorCount()
    })

    Convergence.Events.Publish("simulation.ready", {
        processors = Simulation.GetProcessorCount()
    })

    return true
end

hook.Add("ShutDown", "Convergence.Simulation.Shutdown", function()
    Simulation.Stop()
    Convergence.Events.UnsubscribeOwner("simulation_engine")
end)
