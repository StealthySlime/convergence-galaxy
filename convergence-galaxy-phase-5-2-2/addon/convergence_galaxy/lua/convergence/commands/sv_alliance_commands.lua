local function canUse(ply)
    return not IsValid(ply) or ply:IsAdmin()
end

local function canManage(ply)
    return not IsValid(ply) or ply:IsSuperAdmin()
end

concommand.Add("convergence_alliances", function(ply)
    if not canUse(ply) then
        return
    end

    print("========== Convergence Alliances ==========")

    for id, alliance in SortedPairs(Convergence.Alliances.GetAll()) do
        local factions = Convergence.Alliances.GetFactionIDs(id)

        print(string.format(
            " - %s (%s): factions=%s",
            alliance.name,
            id,
            table.concat(factions, ", ")
        ))
    end

    print("Total alliances: " .. Convergence.Alliances.Count())
    print("===========================================")
end)

concommand.Add("convergence_influence", function(ply, _, args)
    if not canUse(ply) then
        return
    end

    local planet = Convergence.PlanetService.Get(args[1] or "")

    if not planet then
        print("Usage: convergence_influence <planet>")
        return
    end

    print("========== Influence: " .. planet:GetName() .. " ==========")

    for factionID, amount in SortedPairs(
        Convergence.Influence.GetPlanetInfluence(planet:GetID())
    ) do
        local faction = Convergence.Factions.Get(factionID)

        print(string.format(
            " - %s: %.2f",
            faction and faction.name or factionID,
            amount
        ))
    end

    local faction, factionAmount =
        Convergence.Influence.GetDominantFaction(planet:GetID())

    local alliance, allianceAmount =
        Convergence.Influence.GetDominantAlliance(planet:GetID())

    print("Dominant faction: " .. (
        faction and (faction.name .. " (" .. factionAmount .. ")")
        or "None"
    ))

    print("Dominant alliance: " .. (
        alliance and (alliance.name .. " (" .. allianceAmount .. ")")
        or "None"
    ))

    print("==============================================")
end)

concommand.Add("convergence_influence_set", function(ply, _, args)
    if not canManage(ply) then
        return
    end

    local planetID = args[1]
    local factionID = args[2]
    local amount = tonumber(args[3])

    if not planetID or not factionID or amount == nil then
        print("Usage: convergence_influence_set <planet> <faction> <amount>")
        return
    end

    local success, resultOrCode, errorMessage =
        Convergence.Influence.Set(planetID, factionID, amount, {
            actor = ply,
            source = "console",
            reason = "Influence set by administrator."
        })

    print(success
        and ("Influence set to " .. tostring(resultOrCode))
        or string.format("Failed [%s]: %s", resultOrCode, errorMessage))
end)

concommand.Add("convergence_influence_add", function(ply, _, args)
    if not canManage(ply) then
        return
    end

    local planetID = args[1]
    local factionID = args[2]
    local amount = tonumber(args[3])

    if not planetID or not factionID or amount == nil then
        print("Usage: convergence_influence_add <planet> <faction> <amount>")
        return
    end

    local success, resultOrCode, errorMessage =
        Convergence.Influence.Add(planetID, factionID, amount, {
            actor = ply,
            source = "console",
            reason = "Influence changed by administrator."
        })

    print(success
        and ("Influence is now " .. tostring(resultOrCode))
        or string.format("Failed [%s]: %s", resultOrCode, errorMessage))
end)

concommand.Add("convergence_alliance_test", function(ply)
    if not canManage(ply) then
        return
    end

    print("========== Convergence Alliance Test ==========")

    local checks = {
        gdc = Convergence.Alliances.Get(
            "galactic_defense_coalition"
        ) ~= nil,
        invaders = Convergence.Alliances.Get(
            "convergence_invaders"
        ) ~= nil,
        republicMembership = (
            Convergence.Alliances.GetForFaction("republic") or {}
        ).id == "galactic_defense_coalition",
        unscMembership = (
            Convergence.Alliances.GetForFaction("unsc") or {}
        ).id == "galactic_defense_coalition",
        covenantMembership = (
            Convergence.Alliances.GetForFaction("covenant") or {}
        ).id == "convergence_invaders",
        cisMembership = (
            Convergence.Alliances.GetForFaction("cis") or {}
        ).id == "convergence_invaders",
        hostility = Convergence.Alliances.AreHostile(
            "galactic_defense_coalition",
            "convergence_invaders"
        )
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
    print("===============================================")
end)
