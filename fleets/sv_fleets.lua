Convergence.Fleets = Convergence.Fleets or {}

local Fleets = Convergence.Fleets
local DB = Convergence.Database
local ERROR = Convergence.Constants.ERROR

Fleets.Cache = Fleets.Cache or {}
Fleets.Destroyed = Fleets.Destroyed or {}
Fleets.Ready = false

local function uniqueID(name)
    local base = Convergence.NormalizeID(name)
    if base == "" then base = "fleet" end

    local id = base
    local index = 1

    while Fleets.Cache[id] do
        index = index + 1
        id = base .. "_" .. index
    end

    return id
end

local function decodeMetadata(value)
    return util.JSONToTable(value or "{}") or {}
end

local function fromRow(row)
    return {
        id = row.fleet_id,
        name = row.name,
        factionID = row.faction_id,
        currentPlanetID = row.current_planet_id,
        destinationPlanetID = row.destination_planet_id,
        departureCampaignSeconds = tonumber(row.departure_campaign_seconds),
        arrivalCampaignSeconds = tonumber(row.arrival_campaign_seconds),
        strength = tonumber(row.strength) or 100,
        status = row.status or "stationed",
        orderType = row.order_type or "idle",
        orderPlanetID = row.order_planet_id,
        orderStartedCampaignSeconds = tonumber(row.order_started_campaign_seconds),
        orderMetadata = decodeMetadata(row.order_metadata_json),
        commander = row.commander or "",
        homePlanetID = row.home_planet_id or row.current_planet_id,
        experience = tonumber(row.experience) or 0,
        morale = tonumber(row.morale) or 100,
        supplies = tonumber(row.supplies) or 100,
        composition = decodeMetadata(row.composition_json),
        statistics = decodeMetadata(row.statistics_json)
    }
end

function Fleets.IsReady()
    return Fleets.Ready
end

function Fleets.Initialize()
    local success, rowsOrCode, message =
        DB.Query("SELECT * FROM convergence_fleets")

    if not success then
        return false, rowsOrCode, message
    end

    Fleets.Cache = {}
    Fleets.Destroyed = {}

    for _, row in ipairs(rowsOrCode or {}) do
        local fleet = fromRow(row)

        if fleet.status == "destroyed"
            or (tonumber(fleet.strength) or 0) <= 0 then
            fleet.status = "destroyed"
            fleet.strength = 0
            Fleets.Destroyed[fleet.id] = fleet
        else
            Fleets.Cache[fleet.id] = fleet
        end
    end

    Fleets.Ready = true
    Convergence.Events.Publish("fleets.ready", {count = table.Count(Fleets.Cache)})
    return true
end

function Fleets.Get(id)
    return Fleets.Cache[Convergence.NormalizeID(id)]
end

function Fleets.GetAll()
    return Fleets.Cache
end

function Fleets.GetDestroyed(id)
    if id then
        return Fleets.Destroyed[Convergence.NormalizeID(id)]
    end

    return Fleets.Destroyed
end

function Fleets.GetAllIncludingDestroyed()
    local result = table.Copy(Fleets.Cache)

    for id, fleet in pairs(Fleets.Destroyed) do
        result[id] = table.Copy(fleet)
    end

    return result
end

function Fleets.Count()
    return table.Count(Fleets.Cache)
end

function Fleets.CountDestroyed()
    return table.Count(Fleets.Destroyed)
end

function Fleets.Create(name, factionValue, planetValue, strength, context)
    local factionID = Convergence.Factions.ResolveID(factionValue)
    local planet = Convergence.PlanetService.Get(planetValue)

    if not factionID then
        return false, ERROR.INVALID_ARGUMENT, "Unknown faction."
    end

    if not planet then
        return false, ERROR.UNKNOWN_PLANET, "Unknown planet."
    end

    name = string.Trim(tostring(name or ""))
    if name == "" then
        return false, ERROR.INVALID_ARGUMENT, "Fleet name is required."
    end

    local id = uniqueID(name)
    local now = os.time()
    strength = math.Clamp(math.floor(tonumber(strength) or 100), 1, 1000000)

    local success, code, message = DB.Execute(string.format(
        [[INSERT INTO convergence_fleets
        (fleet_id,name,faction_id,current_planet_id,strength,status,
         order_type,order_metadata_json,created_at,updated_at)
        VALUES (%s,%s,%s,%s,%d,'stationed','idle','{}',%d,%d)]],
        DB.Escape(id), DB.Escape(name), DB.Escape(factionID),
        DB.Escape(planet:GetID()), strength, now, now
    ))

    if not success then return false, code, message end

    local fleet = {
        id = id,
        name = name,
        factionID = factionID,
        currentPlanetID = planet:GetID(),
        strength = strength,
        status = "stationed",
        orderType = "idle",
        orderMetadata = {},
        commander = "",
        homePlanetID = planet:GetID(),
        experience = 0,
        morale = 100,
        supplies = 100,
        composition = {},
        statistics = {
            battles = 0,
            victories = 0,
            defeats = 0,
            shipsLost = 0
        }
    }

    Fleets.Cache[id] = fleet
    Convergence.Events.Publish("fleet.created", {fleet = table.Copy(fleet)}, context or {})
    return true, fleet
end

function Fleets.Move(id, destinationValue, hours, context)
    local fleet = Fleets.Get(id)
    local destination = Convergence.PlanetService.Get(destinationValue)

    if not fleet then
        return false, ERROR.INVALID_ARGUMENT, "Unknown fleet."
    end

    if not destination then
        return false, ERROR.UNKNOWN_PLANET, "Unknown destination."
    end

    if destination:GetID() == fleet.currentPlanetID then
        return false, ERROR.INVALID_ARGUMENT, "Fleet is already there."
    end

    hours = math.max(tonumber(hours) or 1, 0.01)
    local departure = Convergence.Clock.GetCampaignSeconds()
    local arrival = departure
        + hours * math.max(tonumber(Convergence.Config.Clock.SecondsPerCampaignHour) or 60, 1)

    local success, code, message = DB.Execute(string.format(
        [[UPDATE convergence_fleets SET destination_planet_id=%s,
        departure_campaign_seconds=%f,arrival_campaign_seconds=%f,
        status='traveling',updated_at=%d WHERE fleet_id=%s]],
        DB.Escape(destination:GetID()), departure, arrival, os.time(),
        DB.Escape(fleet.id)
    ))

    if not success then return false, code, message end

    fleet.destinationPlanetID = destination:GetID()
    fleet.departureCampaignSeconds = departure
    fleet.arrivalCampaignSeconds = arrival
    fleet.status = "traveling"

    Convergence.Events.Publish("fleet.departed", {fleet = table.Copy(fleet)}, context or {})
    return true, fleet
end

function Fleets.Delete(id, context)
    local normalizedID = Convergence.NormalizeID(id)
    local fleet = Fleets.Get(normalizedID)
        or Fleets.GetDestroyed(normalizedID)

    if not fleet then
        return false, ERROR.INVALID_ARGUMENT, "Unknown fleet."
    end

    local success, code, message = DB.Execute(
        "DELETE FROM convergence_fleets WHERE fleet_id=" .. DB.Escape(fleet.id)
    )

    if not success then return false, code, message end

    Fleets.Cache[fleet.id] = nil
    Fleets.Destroyed[fleet.id] = nil
    Convergence.Events.Publish("fleet.deleted", {fleet = table.Copy(fleet)}, context or {})
    return true
end

function Fleets.GetTravelProgress(fleet)
    if not fleet or fleet.status ~= "traveling" then return 0 end

    local departure = tonumber(fleet.departureCampaignSeconds) or 0
    local arrival = tonumber(fleet.arrivalCampaignSeconds) or departure

    if arrival <= departure then return 1 end

    return math.Clamp(
        (Convergence.Clock.GetCampaignSeconds() - departure)
        / (arrival - departure),
        0,
        1
    )
end

function Fleets.GetETASeconds(fleet)
    if not fleet or fleet.status ~= "traveling" then return 0 end

    return math.max(
        (tonumber(fleet.arrivalCampaignSeconds) or 0)
        - Convergence.Clock.GetCampaignSeconds(),
        0
    )
end

function Fleets.ProcessArrivals()
    local nowCampaign = Convergence.Clock.GetCampaignSeconds()
    local arrivals = 0

    for _, fleet in pairs(Fleets.Cache) do
        if fleet.status == "traveling"
            and fleet.destinationPlanetID
            and nowCampaign >= (tonumber(fleet.arrivalCampaignSeconds) or math.huge) then

            local destination = fleet.destinationPlanetID
            local success = DB.Execute(string.format(
                [[UPDATE convergence_fleets SET current_planet_id=%s,
                destination_planet_id=NULL,departure_campaign_seconds=NULL,
                arrival_campaign_seconds=NULL,status='stationed',updated_at=%d
                WHERE fleet_id=%s]],
                DB.Escape(destination), os.time(), DB.Escape(fleet.id)
            ))

            if success then
                fleet.currentPlanetID = destination
                fleet.destinationPlanetID = nil
                fleet.departureCampaignSeconds = nil
                fleet.arrivalCampaignSeconds = nil
                fleet.status = "stationed"
                arrivals = arrivals + 1

                Convergence.Events.Publish("fleet.arrived", {
                    fleet = table.Copy(fleet),
                    planetID = destination
                })
            end
        end
    end

    return arrivals
end


function Fleets.SetStrength(id, strength, context)
    local fleet = Fleets.Get(id)

    if not fleet then
        return false, ERROR.INVALID_ARGUMENT, "Unknown fleet."
    end

    strength = math.max(math.floor(tonumber(strength) or 0), 0)
    local newStatus = strength <= 0 and "destroyed" or fleet.status

    local success, code, message = DB.Execute(string.format(
        [[UPDATE convergence_fleets SET strength=%d,status=%s,updated_at=%d
        WHERE fleet_id=%s]],
        strength,
        DB.Escape(newStatus),
        os.time(),
        DB.Escape(fleet.id)
    ))

    if not success then
        return false, code, message
    end

    local previous = fleet.strength
    fleet.strength = strength
    fleet.status = newStatus

    Convergence.Events.Publish("fleet.strength.changed", {
        fleet = table.Copy(fleet),
        previous = previous,
        current = strength,
        delta = strength - (tonumber(previous) or 0)
    }, context or {})

    if strength <= 0 then
        local destroyedSnapshot = table.Copy(fleet)

        -- Destroyed fleets remain in SQLite for history and diagnostics, but
        -- are removed from the active cache immediately. This removes their
        -- marker, prevents AI orders, and stops them participating in combat.
        Fleets.Cache[fleet.id] = nil
        Fleets.Destroyed[fleet.id] = destroyedSnapshot

        Convergence.Events.Publish("fleet.destroyed", {
            fleet = destroyedSnapshot
        }, context or {})

        hook.Run(
            "ConvergenceFleetRemovedFromActiveMap",
            destroyedSnapshot
        )

        return true, destroyedSnapshot
    end

    return true, fleet
end

function Fleets.GetAtPlanet(planetValue, includeTraveling)
    local planet = Convergence.PlanetService.Get(planetValue)
    local result = {}

    if not planet then
        return result
    end

    for _, fleet in pairs(Fleets.Cache) do
        local atPlanet = fleet.currentPlanetID == planet:GetID()
        local inbound = includeTraveling
            and fleet.status == "traveling"
            and fleet.destinationPlanetID == planet:GetID()

        if (atPlanet or inbound) and fleet.status ~= "destroyed" then
            result[#result + 1] = fleet
        end
    end

    return result
end


function Fleets.Rename(id, newName, context)
    local fleet = Fleets.Get(id)

    if not fleet then
        return false, ERROR.INVALID_ARGUMENT, "Unknown active fleet."
    end

    newName = string.Trim(tostring(newName or ""))

    if newName == "" then
        return false, ERROR.INVALID_ARGUMENT, "Fleet name is required."
    end

    local success, code, message = DB.Execute(string.format(
        [[UPDATE convergence_fleets
        SET name=%s,updated_at=%d
        WHERE fleet_id=%s]],
        DB.Escape(newName),
        os.time(),
        DB.Escape(fleet.id)
    ))

    if not success then
        return false, code, message
    end

    local previous = fleet.name
    fleet.name = newName

    Convergence.Events.Publish("fleet.renamed", {
        fleet = table.Copy(fleet),
        previous = previous
    }, context or {})

    return true, fleet
end

function Fleets.Relocate(id, planetValue, context)
    local fleet = Fleets.Get(id)
    local planet = Convergence.PlanetService.Get(planetValue)

    if not fleet then
        return false, ERROR.INVALID_ARGUMENT, "Unknown active fleet."
    end

    if not planet then
        return false, ERROR.UNKNOWN_PLANET, "Unknown planet."
    end

    local success, code, message = DB.Execute(string.format(
        [[UPDATE convergence_fleets
        SET current_planet_id=%s,destination_planet_id=NULL,
        departure_campaign_seconds=NULL,arrival_campaign_seconds=NULL,
        status='stationed',order_type='idle',order_planet_id=NULL,
        order_started_campaign_seconds=NULL,order_metadata_json='{}',
        updated_at=%d WHERE fleet_id=%s]],
        DB.Escape(planet:GetID()),
        os.time(),
        DB.Escape(fleet.id)
    ))

    if not success then
        return false, code, message
    end

    local previousPlanetID = fleet.currentPlanetID
    fleet.currentPlanetID = planet:GetID()
    fleet.destinationPlanetID = nil
    fleet.departureCampaignSeconds = nil
    fleet.arrivalCampaignSeconds = nil
    fleet.status = "stationed"
    fleet.orderType = "idle"
    fleet.orderPlanetID = nil
    fleet.orderStartedCampaignSeconds = nil
    fleet.orderMetadata = {}

    Convergence.Events.Publish("fleet.relocated", {
        fleet = table.Copy(fleet),
        previousPlanetID = previousPlanetID
    }, context or {})

    return true, fleet
end


function Fleets.GetCombatRating(fleetValue)
    local fleet = istable(fleetValue)
        and fleetValue
        or Fleets.Get(fleetValue)

    return Convergence.FleetLogistics.CalculateCombatRating(fleet)
end

function Fleets.GetStationedAtPlanet(planetValue)
    local planet = Convergence.PlanetService.Get(planetValue)
    local result = {}

    if not planet then
        return result
    end

    for _, fleet in pairs(Fleets.Cache) do
        if fleet.currentPlanetID == planet:GetID()
            and fleet.status == "stationed"
            and (tonumber(fleet.strength) or 0) > 0 then
            result[#result + 1] = fleet
        end
    end

    table.sort(result, function(left, right)
        return tostring(left.name) < tostring(right.name)
    end)

    return result
end

function Fleets.UpdateLogistics(id, changes, context)
    local fleet = Fleets.Get(id)

    if not fleet then
        return false, ERROR.INVALID_ARGUMENT, "Unknown active fleet."
    end

    changes = istable(changes) and changes or {}

    local commander = changes.commander ~= nil
        and string.Trim(tostring(changes.commander))
        or fleet.commander
    local homePlanetID = changes.homePlanetID ~= nil
        and Convergence.NormalizeID(changes.homePlanetID)
        or fleet.homePlanetID
    local experience = changes.experience ~= nil
        and math.max(math.floor(tonumber(changes.experience) or 0), 0)
        or fleet.experience
    local morale = changes.morale ~= nil
        and math.Clamp(tonumber(changes.morale) or 100, 0, 100)
        or fleet.morale
    local supplies = changes.supplies ~= nil
        and math.Clamp(tonumber(changes.supplies) or 100, 0, 100)
        or fleet.supplies
    local composition = changes.composition ~= nil
        and Convergence.FleetLogistics.NormalizeComposition(
            changes.composition
        )
        or fleet.composition
    local statistics = changes.statistics ~= nil
        and table.Copy(changes.statistics)
        or fleet.statistics

    if homePlanetID ~= ""
        and not Convergence.PlanetService.Get(homePlanetID) then
        return false, ERROR.UNKNOWN_PLANET, "Unknown home planet."
    end

    local proposed = table.Copy(fleet)
    proposed.commander = commander
    proposed.homePlanetID = homePlanetID
    proposed.experience = experience
    proposed.morale = morale
    proposed.supplies = supplies
    proposed.composition = composition
    proposed.statistics = statistics

    local combatRating =
        Convergence.FleetLogistics.CalculateCombatRating(proposed)

    local success, code, message = DB.Execute(string.format(
        [[UPDATE convergence_fleets SET
        commander=%s,home_planet_id=%s,experience=%d,
        morale=%f,supplies=%f,composition_json=%s,
        statistics_json=%s,strength=%d,updated_at=%d
        WHERE fleet_id=%s]],
        DB.Escape(commander),
        homePlanetID ~= "" and DB.Escape(homePlanetID) or "NULL",
        experience,
        morale,
        supplies,
        DB.Escape(util.TableToJSON(composition) or "{}"),
        DB.Escape(util.TableToJSON(statistics) or "{}"),
        combatRating,
        os.time(),
        DB.Escape(fleet.id)
    ))

    if not success then
        return false, code, message
    end

    fleet.commander = commander
    fleet.homePlanetID = homePlanetID
    fleet.experience = experience
    fleet.morale = morale
    fleet.supplies = supplies
    fleet.composition = composition
    fleet.statistics = statistics
    fleet.strength = combatRating

    Convergence.Events.Publish("fleet.logistics.updated", {
        fleet = table.Copy(fleet)
    }, context or {})

    return true, fleet
end
