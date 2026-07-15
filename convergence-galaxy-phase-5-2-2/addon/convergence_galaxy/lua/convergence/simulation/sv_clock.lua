Convergence.Clock = Convergence.Clock or {}

local Clock = Convergence.Clock
local DB = Convergence.Database
local ERROR = Convergence.Constants.ERROR

Clock.Ready = false
Clock.Running = false
Clock.TickCount = 0
Clock.CampaignSeconds = 0
Clock.Paused = false
Clock.TimeScale = 1
Clock.LastRealTick = 0
Clock.UnsavedTicks = 0

local TIMER_NAME = "Convergence.Clock.Tick"

local function campaignHourLength()
    return math.max(
        tonumber(Convergence.Config.Clock.SecondsPerCampaignHour) or 60,
        1
    )
end

local function saveEveryTicks()
    return math.max(
        math.floor(tonumber(Convergence.Config.Clock.SaveEveryTicks) or 12),
        1
    )
end

function Clock.IsReady()
    return Clock.Ready == true
end

function Clock.IsRunning()
    return Clock.Running == true
end

function Clock.IsPaused()
    return Clock.Paused == true
end

function Clock.GetTickCount()
    return Clock.TickCount
end

function Clock.GetCampaignSeconds()
    return Clock.CampaignSeconds
end

function Clock.GetTimeScale()
    return Clock.TimeScale
end

function Clock.GetDay()
    return math.floor(Clock.CampaignSeconds / (campaignHourLength() * 24)) + 1
end

function Clock.GetHour()
    local totalHours = math.floor(Clock.CampaignSeconds / campaignHourLength())
    return totalHours % 24
end

function Clock.GetMinute()
    local fraction = (Clock.CampaignSeconds % campaignHourLength())
        / campaignHourLength()

    return math.floor(fraction * 60)
end

function Clock.GetTimeTable()
    return {
        tick = Clock.GetTickCount(),
        campaignSeconds = Clock.GetCampaignSeconds(),
        day = Clock.GetDay(),
        hour = Clock.GetHour(),
        minute = Clock.GetMinute(),
        paused = Clock.IsPaused(),
        running = Clock.IsRunning(),
        timeScale = Clock.GetTimeScale()
    }
end

function Clock.Format()
    return string.format(
        "Day %d, %02d:%02d",
        Clock.GetDay(),
        Clock.GetHour(),
        Clock.GetMinute()
    )
end

function Clock.Save()
    if not Clock.Ready then
        return false, ERROR.INVALID_ARGUMENT, "Galaxy Clock is not ready."
    end

    local success, errorCode, errorMessage = DB.Execute(string.format(
        [[
            UPDATE convergence_clock
            SET tick_count = %d,
                campaign_seconds = %f,
                paused = %d,
                time_scale = %f,
                updated_at = %d
            WHERE id = 1
        ]],
        Clock.TickCount,
        Clock.CampaignSeconds,
        Clock.Paused and 1 or 0,
        Clock.TimeScale,
        os.time()
    ))

    if success then
        Clock.UnsavedTicks = 0
    end

    return success, errorCode, errorMessage
end

function Clock.Load()
    local success, rowOrCode, message = DB.QueryRow(
        "SELECT * FROM convergence_clock WHERE id = 1"
    )

    if not success then
        return false, rowOrCode, message
    end

    if not rowOrCode then
        return false, ERROR.DATABASE_ERROR, "Galaxy Clock row is missing."
    end

    Clock.TickCount = tonumber(rowOrCode.tick_count) or 0
    Clock.CampaignSeconds = tonumber(rowOrCode.campaign_seconds) or 0
    Clock.Paused = tonumber(rowOrCode.paused) == 1
    Clock.TimeScale = math.max(tonumber(rowOrCode.time_scale) or 1, 0)
    Clock.LastRealTick = SysTime()
    Clock.UnsavedTicks = 0

    return true
end

function Clock.SetPaused(paused, context)
    if not Clock.Ready then
        return false, ERROR.INVALID_ARGUMENT, "Galaxy Clock is not ready."
    end

    paused = paused == true

    if Clock.Paused == paused then
        return true, Clock.GetTimeTable()
    end

    Clock.Paused = paused

    Convergence.Events.Publish("clock.paused.changed", {
        paused = paused,
        time = Clock.GetTimeTable()
    }, context or {})

    Clock.Save()

    return true, Clock.GetTimeTable()
end

function Clock.SetTimeScale(scale, context)
    if not Clock.Ready then
        return false, ERROR.INVALID_ARGUMENT, "Galaxy Clock is not ready."
    end

    scale = tonumber(scale)

    if not scale or scale < 0 or scale > 100 then
        return false, ERROR.INVALID_ARGUMENT,
            "Time scale must be between 0 and 100."
    end

    local previous = Clock.TimeScale
    Clock.TimeScale = scale

    Convergence.Events.Publish("clock.scale.changed", {
        previous = previous,
        current = scale,
        time = Clock.GetTimeTable()
    }, context or {})

    Clock.Save()

    return true, Clock.GetTimeTable()
end

function Clock.SetCampaignTime(day, hour, minute, context)
    day = math.max(math.floor(tonumber(day) or 1), 1)
    hour = math.Clamp(math.floor(tonumber(hour) or 0), 0, 23)
    minute = math.Clamp(math.floor(tonumber(minute) or 0), 0, 59)

    local previous = Clock.GetTimeTable()
    local totalHours = ((day - 1) * 24) + hour + (minute / 60)

    Clock.CampaignSeconds = totalHours * campaignHourLength()

    Convergence.Events.Publish("clock.time.changed", {
        previous = previous,
        current = Clock.GetTimeTable()
    }, context or {})

    Clock.Save()

    return true, Clock.GetTimeTable()
end

function Clock.AdvanceCampaignHours(hours, context)
    hours = tonumber(hours)

    if not hours then
        return false, ERROR.INVALID_ARGUMENT, "Hours must be numeric."
    end

    local previous = Clock.GetTimeTable()

    Clock.CampaignSeconds = math.max(
        Clock.CampaignSeconds + (hours * campaignHourLength()),
        0
    )

    Convergence.Events.Publish("clock.time.advanced", {
        hours = hours,
        previous = previous,
        current = Clock.GetTimeTable()
    }, context or {})

    Clock.Save()

    return true, Clock.GetTimeTable()
end

function Clock.Tick()
    if not Clock.Ready or Clock.Paused then
        Clock.LastRealTick = SysTime()
        return
    end

    local now = SysTime()
    local elapsed = math.max(now - Clock.LastRealTick, 0)
    Clock.LastRealTick = now

    Clock.TickCount = Clock.TickCount + 1
    Clock.CampaignSeconds = Clock.CampaignSeconds
        + (elapsed * Clock.TimeScale)

    Clock.UnsavedTicks = Clock.UnsavedTicks + 1

    local time = Clock.GetTimeTable()

    Convergence.Events.Publish("clock.tick", time, {
        source = "galaxy_clock"
    })

    hook.Run("ConvergenceClockTick", time)

    if Clock.UnsavedTicks >= saveEveryTicks() then
        local saved, errorCode, errorMessage = Clock.Save()

        if not saved then
            Convergence.Log.Error("Clock", "Failed to persist Galaxy Clock.", {
                code = errorCode,
                error = errorMessage
            })
        end
    end
end

function Clock.Start()
    if not Clock.Ready then
        return false, ERROR.INVALID_ARGUMENT, "Galaxy Clock is not ready."
    end

    if Clock.Running then
        return true
    end

    local interval = math.max(
        tonumber(Convergence.Config.Clock.TickInterval) or 5,
        1
    )

    timer.Create(TIMER_NAME, interval, 0, function()
        Clock.Tick()
    end)

    Clock.Running = true
    Clock.LastRealTick = SysTime()

    Convergence.Events.Publish("clock.started", {
        interval = interval,
        time = Clock.GetTimeTable()
    })

    return true
end

function Clock.Stop()
    if timer.Exists(TIMER_NAME) then
        timer.Remove(TIMER_NAME)
    end

    Clock.Running = false

    if Clock.Ready then
        Clock.Save()
    end

    Convergence.Events.Publish("clock.stopped", {
        time = Clock.GetTimeTable()
    })

    return true
end

function Clock.Initialize()
    if Clock.Ready then
        return true
    end

    if not DB.IsReady() then
        return false, ERROR.DATABASE_ERROR, "Database must be ready first."
    end

    local loaded, errorCode, errorMessage = Clock.Load()

    if not loaded then
        return false, errorCode, errorMessage
    end

    Clock.Ready = true

    if Convergence.Config.Clock.AutoStart then
        Clock.Start()
    end

    Convergence.Log.Info("Clock", "Galaxy Clock initialized.", {
        tick = Clock.TickCount,
        time = Clock.Format(),
        paused = Clock.Paused,
        scale = Clock.TimeScale
    })

    Convergence.Events.Publish("clock.ready", {
        time = Clock.GetTimeTable()
    })

    return true
end

hook.Add("ShutDown", "Convergence.Clock.Shutdown", function()
    Clock.Stop()
end)
