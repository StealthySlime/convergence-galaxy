Convergence.Events = Convergence.Events or {}

local Events = Convergence.Events
local ERROR = Convergence.Constants.ERROR

Events.Subscribers = Events.Subscribers or {}
Events.NextToken = Events.NextToken or 0
Events.PublishedCount = Events.PublishedCount or 0
Events.ErrorCount = Events.ErrorCount or 0
Events.History = Events.History or {}
Events.HistoryLimit = Events.HistoryLimit or 100

local function normalizeEventName(name)
    name = string.Trim(string.lower(tostring(name or "")))
    name = string.gsub(name, "%s+", ".")
    name = string.gsub(name, "[^%w%._%-]", "")
    name = string.gsub(name, "%.+", ".")
    name = string.Trim(name, ".")

    return name
end

local function addHistory(event)
    Events.History[#Events.History + 1] = event

    while #Events.History > Events.HistoryLimit do
        table.remove(Events.History, 1)
    end
end

function Events.NormalizeName(name)
    return normalizeEventName(name)
end

function Events.Subscribe(name, callback, options)
    name = normalizeEventName(name)
    options = options or {}

    if name == "" then
        return false, ERROR.INVALID_ARGUMENT, "Event name is invalid."
    end

    if not isfunction(callback) then
        return false, ERROR.INVALID_ARGUMENT, "Event callback must be a function."
    end

    Events.NextToken = Events.NextToken + 1

    local token = Events.NextToken

    Events.Subscribers[name] = Events.Subscribers[name] or {}
    Events.Subscribers[name][token] = {
        token = token,
        callback = callback,
        once = options.once == true,
        priority = tonumber(options.priority) or 0,
        owner = tostring(options.owner or "anonymous")
    }

    return true, token
end

function Events.SubscribeOnce(name, callback, options)
    options = table.Copy(options or {})
    options.once = true

    return Events.Subscribe(name, callback, options)
end

function Events.Unsubscribe(name, token)
    name = normalizeEventName(name)
    token = tonumber(token)

    if name == "" or not token then
        return false, ERROR.INVALID_ARGUMENT, "Event name and token are required."
    end

    local subscribers = Events.Subscribers[name]

    if not subscribers or not subscribers[token] then
        return false, ERROR.INVALID_ARGUMENT, "Subscription was not found."
    end

    subscribers[token] = nil

    if table.IsEmpty(subscribers) then
        Events.Subscribers[name] = nil
    end

    return true
end

function Events.UnsubscribeOwner(owner)
    owner = tostring(owner or "")
    local removed = 0

    for name, subscribers in pairs(Events.Subscribers) do
        for token, subscription in pairs(subscribers) do
            if subscription.owner == owner then
                subscribers[token] = nil
                removed = removed + 1
            end
        end

        if table.IsEmpty(subscribers) then
            Events.Subscribers[name] = nil
        end
    end

    return removed
end

function Events.GetSubscriberCount(name)
    name = normalizeEventName(name)

    if name ~= "" then
        return table.Count(Events.Subscribers[name] or {})
    end

    local total = 0

    for _, subscribers in pairs(Events.Subscribers) do
        total = total + table.Count(subscribers)
    end

    return total
end

function Events.GetHistory(limit)
    limit = math.Clamp(tonumber(limit) or 25, 1, Events.HistoryLimit)

    local result = {}
    local first = math.max(#Events.History - limit + 1, 1)

    for index = first, #Events.History do
        result[#result + 1] = table.Copy(Events.History[index])
    end

    return result
end

function Events.Publish(name, payload, context)
    name = normalizeEventName(name)
    payload = istable(payload) and payload or {}
    context = istable(context) and context or {}

    if name == "" then
        return false, ERROR.INVALID_ARGUMENT, "Event name is invalid."
    end

    Events.PublishedCount = Events.PublishedCount + 1

    local event = {
        id = Events.PublishedCount,
        name = name,
        payload = payload,
        context = context,
        timestamp = os.time(),
        realm = SERVER and "server" or "client"
    }

    addHistory(event)

    local subscribers = Events.Subscribers[name] or {}
    local ordered = {}

    for _, subscription in pairs(subscribers) do
        ordered[#ordered + 1] = subscription
    end

    table.sort(ordered, function(left, right)
        if left.priority == right.priority then
            return left.token < right.token
        end

        return left.priority > right.priority
    end)

    for _, subscription in ipairs(ordered) do
        local ok, result = xpcall(function()
            return subscription.callback(event)
        end, debug.traceback)

        if not ok then
            Events.ErrorCount = Events.ErrorCount + 1

            Convergence.Log.Error("Events", "Event subscriber failed.", {
                event = name,
                owner = subscription.owner,
                token = subscription.token,
                error = result
            })
        end

        if subscription.once then
            Events.Unsubscribe(name, subscription.token)
        end
    end

    hook.Run("ConvergenceEventPublished", name, event)

    return true, event
end
