Convergence.UI = Convergence.UI or {}
Convergence.UI.Visibility = Convergence.UI.Visibility or {}

local Visibility = Convergence.UI.Visibility

Visibility.Levels = {
    public = 1,
    coalition = 2,
    contact = 3,
    hidden = 4
}

function Visibility.IsDirector()
    return Convergence.UI.Mode == "director"
end

function Visibility.CanSeeFleet(fleet)
    if Visibility.IsDirector() then
        return true
    end

    return fleet and fleet.playerVisible ~= false
end

function Visibility.GetFleetDisplay(fleet, data)
    if not fleet then
        return nil
    end

    if fleet.intelligenceLevel == "contact" and not Visibility.IsDirector() then
        return {
            id = fleet.id,
            name = "Unknown Contact",
            factionID = nil,
            strength = nil,
            status = fleet.status,
            currentPlanetID = fleet.currentPlanetID,
            destinationPlanetID = fleet.destinationPlanetID,
            progress = fleet.progress,
            orderType = nil,
            intelligenceLevel = "contact"
        }
    end

    return fleet
end
