Convergence.GalacticNews = Convergence.GalacticNews or {}

local News = Convergence.GalacticNews

News.Cache = News.Cache or {}
News.Ready = false
News.LastDailyReportDay = nil

local function add(article)
    News.Cache[#News.Cache + 1] = article

    local limit = math.max(
        tonumber(Convergence.Config.Campaign.NewsSnapshotLimit) or 100,
        20
    )

    while #News.Cache > limit do
        table.remove(News.Cache, 1)
    end
end

local function campaignTimestamp()
    local time = Convergence.Clock.GetTimeTable()

    return {
        day = time.day,
        hour = time.hour,
        minute = time.minute,
        campaignSeconds = time.campaignSeconds
    }
end

local function planetName(planetID)
    local planet = Convergence.PlanetService.Get(planetID)
    return planet and planet:GetName() or tostring(planetID or "Unknown")
end

function News.GetAll()
    return News.Cache
end

function News.GetRecent(limit)
    limit = math.Clamp(
        math.floor(tonumber(limit) or 50),
        1,
        math.max(#News.Cache, 1)
    )

    local result = {}
    local first = math.max(#News.Cache - limit + 1, 1)

    for index = first, #News.Cache do
        result[#result + 1] = table.Copy(News.Cache[index])
    end

    return result
end

function News.Publish(data)
    data = istable(data) and data or {}

    local stamp = campaignTimestamp()
    local article = {
        id = string.format(
            "gnn_%d_%d_%d_%d",
            stamp.day,
            stamp.hour,
            stamp.minute,
            #News.Cache + 1
        ),
        headline = tostring(data.headline or "Galactic News Update"),
        subheadline = tostring(data.subheadline or ""),
        body = tostring(data.body or ""),
        category = Convergence.NormalizeID(data.category or "general"),
        severity = Convergence.NormalizeID(data.severity or "info"),
        planetID = data.planetID,
        factionID = data.factionID,
        operationID = data.operationID,
        campaignDay = stamp.day,
        campaignHour = stamp.hour,
        campaignMinute = stamp.minute,
        createdAt = os.time()
    }

    add(article)

    hook.Run("ConvergenceGalacticNewsPublished", article)

    return article
end

local function countResolvedToday()
    local day = Convergence.Clock.GetTimeTable().day
    local counts = {
        total = 0,
        victories = 0,
        defeats = 0,
        draws = 0
    }

    for _, entry in ipairs(
        Convergence.CampaignHistory.GetAll() or {}
    ) do
        if entry.campaignDay == day
            and entry.category == "operation"
            and entry.outcome then
            counts.total = counts.total + 1

            if string.find(entry.outcome, "victory", 1, true) then
                counts.victories = counts.victories + 1
            elseif string.find(entry.outcome, "defeat", 1, true) then
                counts.defeats = counts.defeats + 1
            elseif entry.outcome == "draw" then
                counts.draws = counts.draws + 1
            end
        end
    end

    return counts
end

local function averageStability()
    local total = 0
    local count = 0
    local weakestID = nil
    local weakestValue = math.huge

    for planetID, planet in pairs(
        Convergence.PlanetService.GetAll() or {}
    ) do
        local value = tonumber(planet:GetStability()) or 0
        total = total + value
        count = count + 1

        if value < weakestValue then
            weakestValue = value
            weakestID = planetID
        end
    end

    return count > 0 and total / count or 0, weakestID, weakestValue
end

function News.PublishDailyReport()
    local time = Convergence.Clock.GetTimeTable()
    local counts = countResolvedToday()
    local average, weakestID, weakestValue = averageStability()

    local article = News.Publish({
        headline = "GALACTIC DAILY REPORT",
        subheadline = "Campaign Day " .. tostring(time.day),
        category = "daily_report",
        severity = weakestValue < 40 and "warning" or "info",
        planetID = weakestID,
        body = string.format(
            "Operations resolved: %d\nVictories: %d\nDefeats: %d\nDraws: %d\nAverage planetary stability: %.1f%%\nHighest strategic concern: %s (%.0f%% stability)",
            counts.total,
            counts.victories,
            counts.defeats,
            counts.draws,
            average,
            planetName(weakestID),
            weakestValue == math.huge and 0 or weakestValue
        )
    })

    News.LastDailyReportDay = time.day
    return article
end

function News.Process()
    if not News.Ready then
        return
    end

    local day = Convergence.Clock.GetTimeTable().day
    local interval = math.max(
        tonumber(Convergence.Config.Campaign.DailyReportIntervalDays) or 1,
        1
    )

    if not News.LastDailyReportDay
        or day - News.LastDailyReportDay >= interval then
        News.PublishDailyReport()
    end
end

function News.Initialize()
    if News.Ready then
        return true
    end

    Convergence.Events.Subscribe(
        "campaign.event.created",
        function(event)
            local operation = event.payload.event or {}

            News.Publish({
                headline = "NEW OPERATION ANNOUNCED",
                subheadline = tostring(operation.name or "Unknown Operation"),
                body = string.format(
                    "%s forces have reported a %s operation at %s. Galactic Command is reviewing deployment options.",
                    string.upper(tostring(operation.priority or "normal")),
                    tostring(operation.eventType or "battle"),
                    planetName(operation.planetID)
                ),
                category = "operation",
                severity = operation.priority == "critical"
                    and "critical"
                    or operation.priority == "high"
                        and "warning"
                        or "info",
                planetID = operation.planetID,
                operationID = operation.id
            })
        end,
        {owner = "galactic_news"}
    )

    Convergence.Events.Subscribe(
        "campaign.event.resolved",
        function(event)
            local operation = event.payload.event or {}
            local resolution = operation.resolution or {}
            local outcome = tostring(resolution.outcome or "resolved")
            local victory = string.find(outcome, "victory", 1, true) ~= nil

            News.Publish({
                headline = victory
                    and "COALITION FORCES CLAIM VICTORY"
                    or string.find(outcome, "defeat", 1, true)
                        and "COALITION SUFFERS DEFEAT"
                        or "BATTLE ENDS WITHOUT DECISIVE RESULT",
                subheadline = tostring(operation.name or "Operation"),
                body = string.format(
                    "%s at %s concluded as %s. Strategic effects have been applied to the campaign.",
                    tostring(operation.name or "Operation"),
                    planetName(operation.planetID),
                    string.gsub(outcome, "_", " ")
                ),
                category = "battle_report",
                severity = victory
                    and "success"
                    or string.find(outcome, "defeat", 1, true)
                        and "danger"
                        or "info",
                planetID = operation.planetID,
                operationID = operation.id
            })
        end,
        {owner = "galactic_news"}
    )

    Convergence.Events.Subscribe(
        "fleet.arrived",
        function(event)
            local fleet = event.payload.fleet or {}

            News.Publish({
                headline = "FLEET MOVEMENT CONFIRMED",
                subheadline = tostring(fleet.name or "Fleet"),
                body = string.format(
                    "%s has arrived at %s.",
                    tostring(fleet.name or "Fleet"),
                    planetName(fleet.currentPlanetID)
                ),
                category = "fleet",
                severity = "info",
                planetID = fleet.currentPlanetID,
                factionID = fleet.factionID
            })
        end,
        {owner = "galactic_news"}
    )

    News.Ready = true
    News.LastDailyReportDay = Convergence.Clock.GetTimeTable().day
    Convergence.Services.Register("galactic_news", News)

    timer.Create("Convergence.GalacticNews.Process", 10, 0, function()
        News.Process()
    end)

    return true
end
