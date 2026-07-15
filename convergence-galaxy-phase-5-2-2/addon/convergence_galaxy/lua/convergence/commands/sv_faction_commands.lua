local function canUse(ply)
    return not IsValid(ply) or ply:IsAdmin()
end

concommand.Add("convergence_factions", function(ply)
    if not canUse(ply) then
        return
    end

    print("========== Convergence Factions ==========")

    for id, faction in SortedPairs(Convergence.Factions.GetAll()) do
        local alliance = Convergence.Alliances.GetForFaction(id)

        print(string.format(
            " - %s (%s): alignment=%s alliance=%s enabled=%s",
            faction.name,
            id,
            faction.alignment,
            alliance and alliance.name or "None",
            tostring(faction.enabled)
        ))
    end

    print("Total factions: " .. Convergence.Factions.Count())
    print("Player factions: " .. table.Count(
        Convergence.Factions.GetPlayerFactions()
    ))
    print("Enemy factions: " .. table.Count(
        Convergence.Factions.GetEnemies()
    ))
    print("==========================================")
end)

concommand.Add("convergence_faction_test", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        return
    end

    print("========== Convergence Faction Test ==========")

    local checks = {
        republic = Convergence.Factions.Get("republic") ~= nil,
        unsc = Convergence.Factions.Get("unsc") ~= nil,
        covenant = Convergence.Factions.Get("covenant") ~= nil,
        cis = Convergence.Factions.Get("cis") ~= nil,
        alias = Convergence.Factions.Get("separatists") ~= nil,
        enemyCount = table.Count(Convergence.Factions.GetEnemies()) == 2,
        playerCount = table.Count(
            Convergence.Factions.GetPlayerFactions()
        ) == 2
    }

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
    print("==============================================")
end)
