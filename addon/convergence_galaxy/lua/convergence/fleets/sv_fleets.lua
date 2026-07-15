Convergence.Fleets = Convergence.Fleets or {}

local Fleets = Convergence.Fleets
local DB = Convergence.Database
local ERROR = Convergence.Constants.ERROR

Fleets.Cache = Fleets.Cache or {}
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
        status = row.status or "stationed"
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

    for _, row in ipairs(rowsOrCode or {}) do
        local fleet = fromRow(row)
        Fleets.Cache[fleet.id] = fleet
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

function Fleets.Count()
    return table.Count(Fleets.Cache)
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
        (fleet_id,name,faction_id,current_planet_id,strength,status,created_at,updated_at)
        VALUES (%s,%s,%s,%s,%d,'stationed',%d,%d)]],
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
        status = "stationed"
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
    local fleet = Fleets.Get(id)

    if not fleet then
        return false, ERROR.INVALID_ARGUMENT, "Unknown fleet."
    end

    local success, code, message = DB.Execute(
        "DELETE FROM convergence_fleets WHERE fleet_id=" .. DB.Escape(fleet.id)
    )

    if not success then return false, code, message end

    Fleets.Cache[fleet.id] = nil
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
