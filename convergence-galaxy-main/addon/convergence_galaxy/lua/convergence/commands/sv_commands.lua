local function canManage(ply)
    return not IsValid(ply) or ply:IsSuperAdmin()
end

concommand.Add("convergence_planets", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end

    for id, planet in SortedPairs(Convergence.GetPlanets()) do
        local stability = Convergence.Stability.Get(id)
        local state = Convergence.GetStabilityState(stability)

        print(string.format(
            "[Convergence] %s (%s): %d%% - %s",
            planet.name,
            id,
            stability,
            state.name
        ))
    end
end)

concommand.Add("convergence_stability_set", function(ply, _, args, raw)
    if not canManage(ply) then return end

    local planetID = args[1]
    local value = tonumber(args[2])
    local reason = string.Trim(string.sub(raw, #(args[1] or "") + #(args[2] or "") + 3))

    if not planetID or value == nil then
        print("Usage: convergence_stability_set <planet_id> <0-100> [reason]")
        return
    end

    local ok, result = Convergence.Stability.Set(planetID, value, {
        actor = ply,
        source = "console",
        reason = reason ~= "" and reason or "Console stability adjustment."
    })

    print(ok and ("Stability set to " .. result) or ("Failed: " .. tostring(result)))
end)

concommand.Add("convergence_stability_add", function(ply, _, args, raw)
    if not canManage(ply) then return end

    local planetID = args[1]
    local amount = tonumber(args[2])
    local reason = string.Trim(string.sub(raw, #(args[1] or "") + #(args[2] or "") + 3))

    if not planetID or amount == nil then
        print("Usage: convergence_stability_add <planet_id> <amount> [reason]")
        return
    end

    local ok, result = Convergence.Stability.Add(planetID, amount, {
        actor = ply,
        source = "console",
        reason = reason ~= "" and reason or "Console stability adjustment."
    })

    print(ok and ("Stability is now " .. result) or ("Failed: " .. tostring(result)))
end)
