Convergence.FleetBattles = Convergence.FleetBattles or {}

local Battles = Convergence.FleetBattles

Battles.Ready = false
Battles.Active = Battles.Active or {}
Battles.LastResults = Battles.LastResults or {}
Battles.BattleCount = Battles.BattleCount or 0

local function factionSide(factionID)
    for _, id in ipairs(Convergence.Factions.GetFriendlyIDs()) do
        if id == factionID then
            return "friendly"
        end
    end

    for _, id in ipairs(Convergence.Factions.GetEnemyIDs()) do
        if id == factionID then
            return "enemy"
        end
    end

    return "neutral"
end

local function groupFleets(planetID)
    local groups = {
        friendly = {},
        enemy = {},
        neutral = {}
    }

    for _, fleet in ipairs(
        Convergence.Fleets.GetAtPlanet(planetID, false)
    ) do
        local side = factionSide(fleet.factionID)
        groups[side][#groups[side] + 1] = fleet
    end

    return groups
end

local function totalStrength(fleets)
    local total = 0

    for _, fleet in ipairs(fleets or {}) do
        total = total + math.max(tonumber(fleet.strength) or 0, 0)
    end

    return total
end

local function strongestFaction(fleets)
    local totals = {}

    for _, fleet in ipairs(fleets or {}) do
        totals[fleet.factionID] =
            (totals[fleet.factionID] or 0)
            + (tonumber(fleet.strength) or 0)
    end

    local bestID = nil
    local bestValue = -1

    for factionID, value in pairs(totals) do
        if value > bestValue then
            bestID = factionID
            bestValue = value
        end
    end

    return bestID, bestValue
end

local function damageFleetGroup(fleets, totalDamage, context)
    local total = totalStrength(fleets)

    if total <= 0 then
        return 0
    end

    local applied = 0

    for _, fleet in ipairs(fleets) do
        local share = (tonumber(fleet.strength) or 0) / total
        local damage = math.max(math.floor(totalDamage * share), 1)
        local newStrength = math.max(
            (tonumber(fleet.strength) or 0) - damage,
            0
        )

        Convergence.Fleets.SetStrength(
            fleet.id,
            newStrength,
            context
        )

        applied = applied + damage
    end

    return applied
end

local function operationExists(planetID)
    for _, event in pairs(
        Convergence.CampaignEvents.GetAll() or {}
    ) do
        if event.planetID == planetID
            and event.status ~= "resolved"
            and event.status ~= "cancelled"
            and (
                event.eventType == "fleet_battle"
                or event.eventType == "defense"
            ) then
            return true
        end
    end

    return false
end

local function maybeGenerateOperation(planetID, friendly, enemy)
    if operationExists(planetID) then
        return
    end

    local friendlyStrength = totalStrength(friendly)
    local enemyStrength = totalStrength(enemy)
    local lower = math.min(friendlyStrength, enemyStrength)
    local higher = math.max(friendlyStrength, enemyStrength)

    if higher <= 0 then
        return
    end

    local closeness = lower / higher
    local threshold = tonumber(
        Convergence.Config.Campaign.FleetBattleOperationThreshold
    ) or 0.25

    if closeness < threshold then
        return
    end

    local planet = Convergence.PlanetService.Get(planetID)
    local enemyFactionID = strongestFaction(enemy)

    Convergence.CampaignEvents.Create({
        name = "Fleet Battle of " .. (
            planet and planet:GetName() or planetID
        ),
        eventType = "fleet_battle",
        planetID = planetID,
        regionID = "orbit",
        difficulty = closeness > 0.75 and "major" or "standard",
        priority = closeness > 0.75 and "high" or "normal",
        briefing =
            "Opposing fleets have entered combat in orbit. "
            .. "Galactic Command may commit players or allow AI resolution.",
        friendlyFactions = Convergence.Factions.GetFriendlyIDs(),
        enemyFactions = enemyFactionID and {enemyFactionID}
            or Convergence.Factions.GetEnemyIDs(),
        status = "available",
        aiProgressActive = true,
        effects = {
            generatedByAI = true,
            generatedByFleetBattle = true
        }
    }, {
        source = "fleet_battles",
        reason = "Opposing fleets met at the same planet."
    })
end

local function applyStrategicEffects(
    planetID,
    friendlyBefore,
    enemyBefore,
    friendlyAfter,
    enemyAfter
)
    local friendlyFactionID = strongestFaction(
        Convergence.Fleets.GetAtPlanet(planetID, false)
    )

    local margin = math.abs(friendlyAfter - enemyAfter)
    local scale = math.Clamp(margin / 1000, 0.2, 3)

    if friendlyAfter > enemyAfter then
        for _, factionID in ipairs(
            Convergence.Factions.GetFriendlyIDs()
        ) do
            Convergence.Influence.Add(
                planetID,
                factionID,
                0.3 * scale,
                {
                    source = "fleet_battle",
                    reason = "Friendly orbital superiority."
                }
            )
        end

        Convergence.Stability.Add(
            planetID,
            0.15 * scale,
            {
                source = "fleet_battle",
                reason = "Friendly fleet advantage stabilized the system."
            }
        )
    elseif enemyAfter > friendlyAfter then
        local enemyID = strongestFaction(
            groupFleets(planetID).enemy
        )

        if enemyID then
            Convergence.Influence.Add(
                planetID,
                enemyID,
                0.45 * scale,
                {
                    source = "fleet_battle",
                    reason = "Enemy orbital superiority."
                }
            )
        end

        Convergence.Stability.Add(
            planetID,
            -0.25 * scale,
            {
                source = "fleet_battle",
                reason = "Enemy fleet advantage destabilized the system."
            }
        )
    end
end

function Battles.ResolveTick(planetID)
    local groups = groupFleets(planetID)
    local friendlyBefore = totalStrength(groups.friendly)
    local enemyBefore = totalStrength(groups.enemy)

    if friendlyBefore <= 0 or enemyBefore <= 0 then
        Battles.Active[planetID] = nil
        return false, "No opposing fleets."
    end

    Battles.BattleCount = Battles.BattleCount + 1

    local minimum = tonumber(
        Convergence.Config.Campaign.FleetBattleDamageMinimum
    ) or 0.08
    local maximum = tonumber(
        Convergence.Config.Campaign.FleetBattleDamageMaximum
    ) or 0.22

    local friendlyEfficiency = math.Rand(minimum, maximum)
    local enemyEfficiency = math.Rand(minimum, maximum)

    local damageToEnemy = math.max(
        math.floor(friendlyBefore * friendlyEfficiency),
        1
    )
    local damageToFriendly = math.max(
        math.floor(enemyBefore * enemyEfficiency),
        1
    )

    local context = {
        source = "fleet_battle",
        reason = "Autonomous orbital fleet engagement."
    }

    local appliedFriendlyDamage =
        damageFleetGroup(groups.friendly, damageToFriendly, context)
    local appliedEnemyDamage =
        damageFleetGroup(groups.enemy, damageToEnemy, context)

    local refreshed = groupFleets(planetID)
    local friendlyAfter = totalStrength(refreshed.friendly)
    local enemyAfter = totalStrength(refreshed.enemy)

    maybeGenerateOperation(
        planetID,
        refreshed.friendly,
        refreshed.enemy
    )

    applyStrategicEffects(
        planetID,
        friendlyBefore,
        enemyBefore,
        friendlyAfter,
        enemyAfter
    )

    local result = {
        battleID = Battles.BattleCount,
        planetID = planetID,
        friendlyBefore = friendlyBefore,
        enemyBefore = enemyBefore,
        friendlyAfter = friendlyAfter,
        enemyAfter = enemyAfter,
        friendlyDamage = appliedFriendlyDamage,
        enemyDamage = appliedEnemyDamage,
        resolvedAt = os.time(),
        completed = friendlyAfter <= 0 or enemyAfter <= 0,
        winner = friendlyAfter > enemyAfter
            and "friendly"
            or enemyAfter > friendlyAfter
                and "enemy"
                or "draw"
    }

    Battles.LastResults[planetID] = table.Copy(result)

    if result.completed then
        Battles.Active[planetID] = nil
    else
        Battles.Active[planetID] = result
    end

    Convergence.Events.Publish("fleet.battle.tick", {
        result = table.Copy(result)
    }, context)

    if result.completed then
        Convergence.Events.Publish("fleet.battle.resolved", {
            result = table.Copy(result)
        }, context)
    end

    return true, result
end

function Battles.Process()
    local processed = 0

    for planetID in pairs(
        Convergence.PlanetService.GetAll() or {}
    ) do
        local groups = groupFleets(planetID)

        if #groups.friendly > 0 and #groups.enemy > 0 then
            local success = Battles.ResolveTick(planetID)

            if success then
                processed = processed + 1
            end
        else
            Battles.Active[planetID] = nil
        end
    end

    return processed
end

function Battles.GetActive()
    return Battles.Active
end

function Battles.GetLastResults()
    return Battles.LastResults
end

function Battles.Initialize()
    Battles.Ready = true
    Convergence.Services.Register("fleet_battles", Battles)
    return true
end
