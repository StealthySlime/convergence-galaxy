Convergence.FleetOrders = Convergence.FleetOrders or {}

local Orders = Convergence.FleetOrders
local Fleets = Convergence.Fleets
local DB = Convergence.Database
local ERROR = Convergence.Constants.ERROR

Orders.Types = {
    idle = true,
    move = true,
    patrol = true,
    defend = true,
    reinforce = true,
    invade = true,
    blockade = true,
    escort = true,
    retreat = true,
    explore = true
}

local function normalizeOrder(orderType)
    return Convergence.NormalizeID(orderType)
end

local function saveOrder(fleet)
    return DB.Execute(string.format(
        [[UPDATE convergence_fleets
        SET order_type=%s,order_planet_id=%s,
        order_started_campaign_seconds=%s,order_metadata_json=%s,updated_at=%d
        WHERE fleet_id=%s]],
        DB.Escape(fleet.orderType or "idle"),
        fleet.orderPlanetID and DB.Escape(fleet.orderPlanetID) or "NULL",
        fleet.orderStartedCampaignSeconds
            and tostring(tonumber(fleet.orderStartedCampaignSeconds) or 0)
            or "NULL",
        DB.Escape(util.TableToJSON(fleet.orderMetadata or {}) or "{}"),
        os.time(),
        DB.Escape(fleet.id)
    ))
end

function Orders.Assign(fleetValue, orderType, targetPlanetValue, metadata, context)
    local fleet = Fleets.Get(fleetValue)
    orderType = normalizeOrder(orderType)

    if not fleet then
        return false, ERROR.INVALID_ARGUMENT, "Unknown fleet."
    end

    if not Orders.Types[orderType] then
        return false, ERROR.INVALID_ARGUMENT, "Unknown fleet order."
    end

    local targetPlanet = nil

    if targetPlanetValue and tostring(targetPlanetValue) ~= "" then
        targetPlanet = Convergence.PlanetService.Get(targetPlanetValue)

        if not targetPlanet then
            return false, ERROR.UNKNOWN_PLANET, "Unknown order target planet."
        end
    end

    if orderType ~= "idle" and not targetPlanet then
        return false, ERROR.INVALID_ARGUMENT, "This order requires a target planet."
    end

    fleet.orderType = orderType
    fleet.orderPlanetID = targetPlanet and targetPlanet:GetID() or nil
    fleet.orderStartedCampaignSeconds = Convergence.Clock.GetCampaignSeconds()
    fleet.orderMetadata = istable(metadata) and table.Copy(metadata) or {}

    local success, code, message = saveOrder(fleet)

    if not success then
        return false, code, message
    end

    Convergence.Events.Publish("fleet.order.assigned", {
        fleet = table.Copy(fleet),
        orderType = orderType,
        targetPlanetID = fleet.orderPlanetID
    }, context or {})

    return true, fleet
end

function Orders.Clear(fleetValue, context)
    return Orders.Assign(fleetValue, "idle", nil, {}, context)
end

function Orders.Process()
    local processed = 0

    for _, fleet in pairs(Fleets.GetAll()) do
        local order = fleet.orderType or "idle"

        if order ~= "idle" then
            processed = processed + 1

            if fleet.status == "stationed"
                and fleet.orderPlanetID
                and fleet.currentPlanetID ~= fleet.orderPlanetID then

                local hours = tonumber(fleet.orderMetadata.travelHours) or 6
                Fleets.Move(
                    fleet.id,
                    fleet.orderPlanetID,
                    hours,
                    {
                        source = "fleet_order",
                        reason = "Fleet order initiated travel."
                    }
                )
            elseif fleet.status == "stationed"
                and fleet.currentPlanetID == fleet.orderPlanetID then

                if order == "move" or order == "retreat" or order == "reinforce" then
                    Orders.Clear(fleet.id, {
                        source = "fleet_order",
                        reason = "Fleet completed destination order."
                    })
                elseif order == "defend" then
                    local amount = tonumber(fleet.orderMetadata.influencePerTick) or 0.15

                    Convergence.Influence.Add(
                        fleet.currentPlanetID,
                        fleet.factionID,
                        amount,
                        {
                            source = "fleet_order",
                            reason = fleet.name .. " is defending the planet."
                        }
                    )
                elseif order == "patrol" then
                    local amount = tonumber(fleet.orderMetadata.influencePerTick) or 0.08

                    Convergence.Influence.Add(
                        fleet.currentPlanetID,
                        fleet.factionID,
                        amount,
                        {
                            source = "fleet_order",
                            reason = fleet.name .. " is patrolling the system."
                        }
                    )
                elseif order == "blockade" or order == "invade" then
                    local stabilityLoss = order == "invade" and 0.4 or 0.2

                    Convergence.Stability.Add(
                        fleet.currentPlanetID,
                        -stabilityLoss,
                        {
                            source = "fleet_order",
                            reason = fleet.name .. " is executing a " .. order .. " order."
                        }
                    )
                end
            end
        end
    end

    return processed
end
