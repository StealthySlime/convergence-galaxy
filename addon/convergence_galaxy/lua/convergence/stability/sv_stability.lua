Convergence.Stability = Convergence.Stability or {}

local Stability = Convergence.Stability
local DB = Convergence.Database
local Planets = Convergence.PlanetService
local ERROR = Convergence.Constants.ERROR

local function getActorName(actor)
    if IsValid(actor) and actor:IsPlayer() then
        return actor:SteamID64() .. ":" .. actor:Nick()
    end

    return tostring(actor or "SYSTEM")
end

function Stability.Get(planetID)
    local planet = Planets.Get(planetID)

    if not planet then
        return nil, ERROR.UNKNOWN_PLANET, "Unknown planet."
    end

    return planet:GetStability()
end

function Stability.IsLocked(planetID)
    local planet = Planets.Get(planetID)

    if not planet then
        return false
    end

    return planet:IsStabilityLocked()
end

function Stability.SetLocked(planetID, locked, context)
    context = context or {}

    local planet = Planets.Get(planetID)

    if not planet then
        return false, ERROR.UNKNOWN_PLANET, "Unknown planet."
    end

    locked = locked == true

    local success, errorCode, errorMessage = DB.SetPlanetState(
        planet:GetID(),
        planet:GetStability(),
        locked
    )

    if not success then
        return false, errorCode, errorMessage
    end

    Planets.ApplyStability(
        planet:GetID(),
        planet:GetStability(),
        locked,
        os.time()
    )

    hook.Run("ConvergencePlanetLockChanged", planet:GetID(), locked, context)

    if Convergence.Network then
        Convergence.Network.BroadcastPlanet(planet:GetID())
    end

    return true, planet
end

function Stability.Set(planetID, newValue, context)
    context = context or {}

    local planet = Planets.Get(planetID)

    if not planet then
        return false, ERROR.UNKNOWN_PLANET, "Unknown planet."
    end

    if planet:IsStabilityLocked() and not context.ignoreLock then
        return false, ERROR.PLANET_LOCKED, "Planet stability is locked."
    end

    local previousValue = planet:GetStability()
    newValue = Convergence.ClampStability(newValue)

    if previousValue == newValue then
        return true, planet
    end

    local allowed, vetoReason = hook.Run(
        "ConvergenceStabilityChanging",
        planet:GetID(),
        previousValue,
        newValue,
        context
    )

    if allowed == false then
        return false, ERROR.INVALID_ARGUMENT,
            tostring(vetoReason or "Stability change was rejected.")
    end

    local updatedAt = os.time()

    local stateSaved, saveCode, saveMessage = DB.SetPlanetState(
        planet:GetID(),
        newValue,
        planet:IsStabilityLocked()
    )

    if not stateSaved then
        return false, saveCode, saveMessage
    end

    local entry = {
        planetID = planet:GetID(),
        previousValue = previousValue,
        newValue = newValue,
        delta = newValue - previousValue,
        source = tostring(context.source or "manual"),
        actor = getActorName(context.actor),
        reason = tostring(context.reason or "No reason supplied."),
        createdAt = updatedAt
    }

    local historySaved, historyCode, historyMessage =
        DB.AddStabilityHistory(entry)

    if not historySaved then
        Convergence.Log.Error("Stability", "State changed but history write failed.", {
            planet = planet:GetID(),
            code = historyCode,
            error = historyMessage
        })
    end

    Planets.ApplyStability(
        planet:GetID(),
        newValue,
        planet:IsStabilityLocked(),
        updatedAt
    )

    hook.Run(
        "ConvergenceStabilityChanged",
        planet:GetID(),
        previousValue,
        newValue,
        entry
    )

    if Convergence.Network then
        Convergence.Network.BroadcastPlanet(planet:GetID())
    end

    return true, planet
end

function Stability.Add(planetID, amount, context)
    local current, errorCode, errorMessage = Stability.Get(planetID)

    if current == nil then
        return false, errorCode, errorMessage
    end

    return Stability.Set(planetID, current + (tonumber(amount) or 0), context)
end
