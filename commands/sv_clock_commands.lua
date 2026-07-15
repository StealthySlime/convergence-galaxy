local function canManage(ply)
    return not IsValid(ply) or ply:IsSuperAdmin()
end

local function actorContext(ply, source, reason)
    return {
        actor = ply,
        source = source,
        reason = reason
    }
end

concommand.Add("convergence_clock_status", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    local time = Convergence.Clock.GetTimeTable()

    print("========== Convergence Galaxy Clock ==========")
    print("Ready:            " .. tostring(Convergence.Clock.IsReady()))
    print("Running:          " .. tostring(time.running))
    print("Paused:           " .. tostring(time.paused))
    print("Tick:             " .. tostring(time.tick))
    print("Campaign time:    " .. Convergence.Clock.Format())
    print("Campaign seconds: " .. string.format("%.2f", time.campaignSeconds))
    print("Time scale:       " .. tostring(time.timeScale))
    print("==============================================")
end)

concommand.Add("convergence_clock_pause", function(ply)
    if not canManage(ply) then
        return
    end

    local success, resultOrCode, errorMessage =
        Convergence.Clock.SetPaused(
            true,
            actorContext(ply, "console", "Clock paused by administrator.")
        )

    print(success
        and ("Galaxy Clock paused at " .. Convergence.Clock.Format())
        or string.format("Failed [%s]: %s", resultOrCode, errorMessage))
end)

concommand.Add("convergence_clock_resume", function(ply)
    if not canManage(ply) then
        return
    end

    local success, resultOrCode, errorMessage =
        Convergence.Clock.SetPaused(
            false,
            actorContext(ply, "console", "Clock resumed by administrator.")
        )

    print(success
        and ("Galaxy Clock resumed at " .. Convergence.Clock.Format())
        or string.format("Failed [%s]: %s", resultOrCode, errorMessage))
end)

concommand.Add("convergence_clock_scale", function(ply, _, args)
    if not canManage(ply) then
        return
    end

    local scale = tonumber(args[1])

    if scale == nil then
        print("Usage: convergence_clock_scale <0-100>")
        return
    end

    local success, resultOrCode, errorMessage =
        Convergence.Clock.SetTimeScale(
            scale,
            actorContext(ply, "console", "Clock scale changed by administrator.")
        )

    print(success
        and ("Galaxy Clock scale set to " .. tostring(scale))
        or string.format("Failed [%s]: %s", resultOrCode, errorMessage))
end)

concommand.Add("convergence_clock_set", function(ply, _, args)
    if not canManage(ply) then
        return
    end

    local day = tonumber(args[1])
    local hour = tonumber(args[2])
    local minute = tonumber(args[3]) or 0

    if not day or not hour then
        print("Usage: convergence_clock_set <day> <hour> [minute]")
        return
    end

    local success, resultOrCode, errorMessage =
        Convergence.Clock.SetCampaignTime(
            day,
            hour,
            minute,
            actorContext(ply, "console", "Campaign time set by administrator.")
        )

    print(success
        and ("Galaxy Clock set to " .. Convergence.Clock.Format())
        or string.format("Failed [%s]: %s", resultOrCode, errorMessage))
end)

concommand.Add("convergence_clock_advance", function(ply, _, args)
    if not canManage(ply) then
        return
    end

    local hours = tonumber(args[1])

    if not hours then
        print("Usage: convergence_clock_advance <campaign_hours>")
        return
    end

    local success, resultOrCode, errorMessage =
        Convergence.Clock.AdvanceCampaignHours(
            hours,
            actorContext(ply, "console", "Campaign time advanced by administrator.")
        )

    print(success
        and ("Galaxy Clock advanced to " .. Convergence.Clock.Format())
        or string.format("Failed [%s]: %s", resultOrCode, errorMessage))
end)

concommand.Add("convergence_clock_test", function(ply)
    if not canManage(ply) then
        return
    end

    print("========== Convergence Galaxy Clock Test ==========")

    local before = Convergence.Clock.GetTimeTable()
    local originalPaused = before.paused
    local originalScale = before.timeScale

    local checks = {}

    checks.ready = Convergence.Clock.IsReady()

    local paused = Convergence.Clock.SetPaused(true, {
        source = "clock_test",
        reason = "Automated pause test."
    })

    checks.pause = paused == true and Convergence.Clock.IsPaused()

    local scaled = Convergence.Clock.SetTimeScale(2, {
        source = "clock_test",
        reason = "Automated scale test."
    })

    checks.scale = scaled == true and Convergence.Clock.GetTimeScale() == 2

    local beforeAdvance = Convergence.Clock.GetCampaignSeconds()

    local advanced = Convergence.Clock.AdvanceCampaignHours(1, {
        source = "clock_test",
        reason = "Automated advance test."
    })

    checks.advance = advanced == true
        and Convergence.Clock.GetCampaignSeconds() > beforeAdvance

    local saved = Convergence.Clock.Save()
    checks.save = saved == true

    Convergence.Clock.SetTimeScale(originalScale, {
        source = "clock_test",
        reason = "Restore original scale."
    })

    Convergence.Clock.SetPaused(originalPaused, {
        source = "clock_test",
        reason = "Restore original pause state."
    })

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
    print("Current time: " .. Convergence.Clock.Format())
    print("===================================================")
end)
