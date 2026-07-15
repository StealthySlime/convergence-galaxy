concommand.Add("convergence_history_status", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    print("========== Convergence Campaign History ==========")
    print("Ready:        " .. tostring(
        Convergence.CampaignHistory.IsReady()
    ))
    print("Cached rows:  " .. tostring(
        #Convergence.CampaignHistory.GetAll()
    ))

    local recent = Convergence.CampaignHistory.GetRecent(5)

    for _, entry in ipairs(recent) do
        print(string.format(
            "#%d Day %d %02d:%02d | %s | %s",
            tonumber(entry.id) or 0,
            tonumber(entry.campaignDay) or 1,
            tonumber(entry.campaignHour) or 0,
            tonumber(entry.campaignMinute) or 0,
            tostring(entry.category),
            tostring(entry.title)
        ))
    end

    print("==================================================")
end)

concommand.Add("convergence_history_test", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        return
    end

    local before = #Convergence.CampaignHistory.GetAll()
    local success, entry = Convergence.CampaignHistory.Record({
        category = "test",
        eventName = "history.test",
        title = "Campaign History Test",
        summary = "Persistent history record created successfully.",
        severity = "success",
        details = {
            test = true
        }
    })
    local after = #Convergence.CampaignHistory.GetAll()

    print("========== Campaign History Test ==========")
    print("ready                " .. (
        Convergence.CampaignHistory.IsReady() and "PASS" or "FAIL"
    ))
    print("record               " .. (
        success and "PASS" or "FAIL"
    ))
    print("cacheIncrement       " .. (
        after == before + 1 and "PASS" or "FAIL"
    ))
    print("recordID             " .. (
        success and tonumber(entry.id) and "PASS" or "FAIL"
    ))
    print("Result: " .. (
        success and after == before + 1 and tonumber(entry.id)
            and "4/4 passed"
            or "FAILED"
    ))
    print("===========================================")
end)

concommand.Add("convergence_notification_test", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    Convergence.CampaignNotifications.Broadcast({
        title = "GALACTIC COMMAND",
        message = "Campaign notification test successful.",
        severity = "success",
        duration = 6
    })
end)
