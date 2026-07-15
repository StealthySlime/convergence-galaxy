local function canTest(ply)
    return not IsValid(ply) or ply:IsSuperAdmin()
end

concommand.Add("convergence_event_test", function(ply)
    if not canTest(ply) then
        return
    end

    print("========== Convergence Event Bus Test ==========")

    local results = {
        standard = false,
        priority = false,
        once = false,
        unsubscribe = false,
        errorIsolation = false
    }

    local executionOrder = {}

    local okA, tokenA = Convergence.Events.Subscribe(
        "test.phase1",
        function()
            executionOrder[#executionOrder + 1] = "low"
            results.standard = true
        end,
        {
            owner = "phase1_test_low",
            priority = 1
        }
    )

    local okB, tokenB = Convergence.Events.Subscribe(
        "test.phase1",
        function()
            executionOrder[#executionOrder + 1] = "high"
        end,
        {
            owner = "phase1_test_high",
            priority = 100
        }
    )

    local onceCount = 0

    Convergence.Events.SubscribeOnce(
        "test.once",
        function()
            onceCount = onceCount + 1
        end,
        {
            owner = "phase1_test_once"
        }
    )

    local unsubscribeCalled = false

    local _, unsubscribeToken = Convergence.Events.Subscribe(
        "test.unsubscribe",
        function()
            unsubscribeCalled = true
        end,
        {
            owner = "phase1_test_unsubscribe"
        }
    )

    Convergence.Events.Unsubscribe("test.unsubscribe", unsubscribeToken)

    local afterErrorCalled = false

    Convergence.Events.Subscribe(
        "test.errors",
        function()
            error("Intentional event-bus test error.")
        end,
        {
            owner = "phase1_test_error",
            priority = 100
        }
    )

    Convergence.Events.Subscribe(
        "test.errors",
        function()
            afterErrorCalled = true
        end,
        {
            owner = "phase1_test_after_error",
            priority = 1
        }
    )

    Convergence.Events.Publish("test.phase1")
    Convergence.Events.Publish("test.once")
    Convergence.Events.Publish("test.once")
    Convergence.Events.Publish("test.unsubscribe")
    Convergence.Events.Publish("test.errors")

    results.priority = executionOrder[1] == "high"
        and executionOrder[2] == "low"
    results.once = onceCount == 1
    results.unsubscribe = unsubscribeCalled == false
    results.errorIsolation = afterErrorCalled == true

    if okA then
        Convergence.Events.Unsubscribe("test.phase1", tokenA)
    end

    if okB then
        Convergence.Events.Unsubscribe("test.phase1", tokenB)
    end

    Convergence.Events.UnsubscribeOwner("phase1_test_once")
    Convergence.Events.UnsubscribeOwner("phase1_test_error")
    Convergence.Events.UnsubscribeOwner("phase1_test_after_error")

    local passed = 0

    for name, result in SortedPairs(results) do
        if result then
            passed = passed + 1
        end

        print(string.format(
            "%-32s %s",
            name,
            result and "PASS" or "FAIL"
        ))
    end

    print(string.format("Result: %d/%d passed", passed, table.Count(results)))
    print("==============================================")
end)

concommand.Add("convergence_event_status", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    print("========== Convergence Event Bus ==========")
    print("Published events: " .. tostring(Convergence.Events.PublishedCount))
    print("Subscriber errors: " .. tostring(Convergence.Events.ErrorCount))
    print("Active subscribers: " .. tostring(
        Convergence.Events.GetSubscriberCount()
    ))

    for _, event in ipairs(Convergence.Events.GetHistory(10)) do
        print(string.format(
            " - #%d %s [%s]",
            event.id,
            event.name,
            event.realm
        ))
    end

    print("===========================================")
end)
