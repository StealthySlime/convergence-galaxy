Convergence.FleetLogistics = Convergence.FleetLogistics or {}

local Logistics = Convergence.FleetLogistics

Logistics.UnitRatings = {
    venator = 300,
    acclamator = 70,
    arquitens = 30,
    cr90 = 12,
    v19 = 1.2,
    arc170 = 1.8,
    laat = 0.8,
    ccs = 330,
    sdv = 85,
    seraph = 1.5,
    infantry = 0.08,
    clones = 0.1,
    marines = 0.1
}

Logistics.ExperienceRanks = {
    {minimum = 0, name = "Recruit", multiplier = 0.90},
    {minimum = 100, name = "Regular", multiplier = 1.00},
    {minimum = 300, name = "Experienced", multiplier = 1.06},
    {minimum = 700, name = "Veteran", multiplier = 1.12},
    {minimum = 1400, name = "Elite", multiplier = 1.20},
    {minimum = 2500, name = "Legendary", multiplier = 1.30}
}

function Logistics.NormalizeComposition(composition)
    local result = {}

    for unitID, amount in pairs(istable(composition) and composition or {}) do
        unitID = Convergence.NormalizeID(unitID)
        amount = math.max(math.floor(tonumber(amount) or 0), 0)

        if unitID ~= "" and amount > 0 then
            result[unitID] = amount
        end
    end

    return result
end

function Logistics.GetExperienceRank(experience)
    experience = math.max(math.floor(tonumber(experience) or 0), 0)
    local selected = Logistics.ExperienceRanks[1]

    for _, rank in ipairs(Logistics.ExperienceRanks) do
        if experience >= rank.minimum then
            selected = rank
        end
    end

    return selected
end

function Logistics.CalculateBaseRating(composition)
    local rating = 0

    for unitID, amount in pairs(
        Logistics.NormalizeComposition(composition)
    ) do
        rating = rating
            + (tonumber(Logistics.UnitRatings[unitID]) or 1)
            * amount
    end

    return rating
end

function Logistics.CalculateCombatRating(fleet)
    if not fleet then
        return 0
    end

    local base = Logistics.CalculateBaseRating(fleet.composition)

    -- Legacy fleets without a composition keep their existing usable rating.
    if base <= 0 then
        base = tonumber(fleet.strength) or 0
    end

    local rank = Logistics.GetExperienceRank(fleet.experience)
    local morale = math.Clamp(tonumber(fleet.morale) or 100, 0, 100)
    local supplies = math.Clamp(tonumber(fleet.supplies) or 100, 0, 100)

    local readiness = 0.5 + (morale / 100) * 0.25
        + (supplies / 100) * 0.25

    return math.max(
        math.floor(base * rank.multiplier * readiness),
        0
    )
end
