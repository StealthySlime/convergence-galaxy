Convergence.Stability = Convergence.Stability or {}

local Stability = Convergence.Stability
local DB = Convergence.Database

local function getActorName(actor)
    if IsValid(actor) and actor:IsPlayer() then
        return actor:SteamID64() .. ":" .. actor:Nick()
    end

    return tostring(actor or "SYSTEM")
end

function Stability.Get(planetID)
    local planet = Convergence.GetPlanet(planetID)

    if not planet then
        return nil, "Unknown planet."
    end

    DB.EnsurePlanet(planet)

    local row = DB.GetPlanetState(planet.id)
    if not row then
        return planet.defaultStability
    end

    return Convergence.ClampStability(row.stability)
end

function Stability.IsLocked(planetID)
    local planet = Convergence.GetPlanet(planetID)
    if not planet then return false end

    local row = DB.GetPlanetState(planet.id)
    return row and tonumber(row.locked) == 1 or false
end

function Stability.SetLocked(planetID, locked)
    local current, err = Stability.Get(planetID)
    if current == nil then return false, err end

    DB.SetPlanetState(Convergence.NormalizeID(planetID), current, locked)
    hook.Run("ConvergencePlanetLockChanged", planetID, locked)

    return true
end

function Stability.Set(planetID, newValue, context)
    context = context or {}

    local planet = Convergence.GetPlanet(planetID)
    if not planet then
        return false, "Unknown planet."
    end

    if Stability.IsLocked(planet.id) and not context.ignoreLock then
        return false, "Planet stability is locked."
    end

    local previousValue = Stability.Get(planet.id)
    newValue = Convergence.ClampStability(newValue)

    if previousValue == newValue then
        return true, previousValue
    end

    DB.SetPlanetState(planet.id, newValue, Stability.IsLocked(planet.id))

    local entry = {
        planetID = planet.id,
        previousValue = previousValue,
        newValue = newValue,
        delta = newValue - previousValue,
        source = tostring(context.source or "manual"),
        actor = getActorName(context.actor),
        reason = tostring(context.reason or "No reason supplied."),
        createdAt = os.time()
    }

    DB.AddStabilityHistory(entry)

    hook.Run("ConvergenceStabilityChanged", planet.id, previousValue, newValue, entry)

    if Convergence.Network then
        Convergence.Network.BroadcastPlanet(planet.id)
    end

    return true, newValue
end

function Stability.Add(planetID, amount, context)
    local current, err = Stability.Get(planetID)
    if current == nil then return false, err end

    return Stability.Set(planetID, current + (tonumber(amount) or 0), context)
end
