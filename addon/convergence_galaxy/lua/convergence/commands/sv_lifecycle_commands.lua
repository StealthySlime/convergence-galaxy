local function canManage(ply)
    return not IsValid(ply) or ply:IsSuperAdmin()
end

local function printStatus()
    local valid, states = Convergence.Lifecycle.Validate()

    print("========== Convergence Core Lifecycle ==========")

    for id, state in SortedPairs(states) do
        print(string.format(
            "%-16s registered=%-5s ready=%-5s",
            id,
            state.registered and "PASS" or "FAIL",
            state.ready and "PASS" or "FAIL"
        ))
    end

    print("-----------------------------------------------")
    print("Lifecycle ready: " .. tostring(valid))
    print("===============================================")

    return valid
end

concommand.Add("convergence_lifecycle_status", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    printStatus()
end)

concommand.Add("convergence_lifecycle_repair", function(ply)
    if not canManage(ply) then
        return
    end

    local success, resultOrCode, message =
        Convergence.Lifecycle.Repair()

    if not success then
        print(string.format(
            "[Convergence] Lifecycle repair failed [%s]: %s",
            tostring(resultOrCode),
            tostring(message)
        ))
        return
    end

    print("[Convergence] Lifecycle repair completed.")
    printStatus()
end)

concommand.Add("convergence_lifecycle_test", function(ply)
    if not canManage(ply) then
        return
    end

    local valid, states = Convergence.Lifecycle.Validate()
    local passed = 0
    local total = 0

    print("========== Core Lifecycle Test ==========")

    for id, state in SortedPairs(states) do
        total = total + 1
        local success = state.registered and state.ready

        if success then
            passed = passed + 1
        end

        print(string.format(
            "%-24s %s",
            id,
            success and "PASS" or "FAIL"
        ))
    end

    print(string.format("Result: %d/%d passed", passed, total))
    print("Overall: " .. (valid and "PASS" or "FAIL"))
    print("=========================================")
end)
