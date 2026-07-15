Convergence.SWUWorld = Convergence.SWUWorld or {}

local Adapter = Convergence.SWUWorld
Adapter.LastHyperspaceState = nil
Adapter.LastTargetPlanetName = nil
Adapter.LastPersistedPosition = nil

local function available()
    return SWU
        and IsValid(SWU.Controller)
        and IsValid(SWU.NavigationComputer)
end

function Adapter.IsAvailable()
    return available()
end

local function resolvePlanetBySWUName(name)
    local normalized = Convergence.NormalizeID(name)

    for id, planet in pairs(Convergence.PlanetService.GetAll()) do
        local definition = planet:GetDefinition()
        local swuName = definition.swu and definition.swu.name

        if Convergence.NormalizeID(swuName or planet:GetName()) == normalized
            or Convergence.NormalizeID(planet:GetName()) == normalized
            or id == normalized then
            return planet
        end
    end

    return nil
end

local function injectNavigationPlanets()
    if not SWU or not IsValid(SWU.NavigationComputer) then
        return false
    end

    local computer = SWU.NavigationComputer
    computer.Planets = computer.Planets or {}
    computer.allPlanets = computer.allPlanets or computer.Planets

    local seen = {}

    for _, entry in ipairs(computer.allPlanets) do
        seen[Convergence.NormalizeID(entry.name)] = true
    end

    for _, planet in pairs(Convergence.PlanetService.GetAll()) do
        local definition = planet:GetDefinition()
        local swu = definition.swu

        if swu and isvector(swu.pos) then
            local name = tostring(swu.name or planet:GetName())
            local key = Convergence.NormalizeID(name)

            if not seen[key] then
                computer.allPlanets[#computer.allPlanets + 1] = {
                    name = name,
                    pos = Vector(swu.pos.x, swu.pos.y, swu.pos.z)
                }
                seen[key] = true
            end
        end
    end

    table.SortByMember(computer.allPlanets, "name", true)
    computer.Planets = table.Copy(computer.allPlanets)
    computer:SetCurPage(1)
    computer:SetPages(math.max(math.ceil(#computer.Planets / computer.PlanetsPerPage), 1))
    computer:UpdatePageValue()

    return true
end

local function syncPosition(force)
    if not SWU or not IsValid(SWU.Controller) then
        return
    end

    local position = SWU.Controller:GetShipPos()

    if not isvector(position) then
        return
    end

    if force
        or not isvector(Adapter.LastPersistedPosition)
        or Adapter.LastPersistedPosition:DistToSqr(position) >= 0.01 then

        Adapter.LastPersistedPosition = Vector(position.x, position.y, position.z)
        Convergence.World.SetShipPosition(position)
    end
end

local function inspectState()
    if not available() then
        return
    end

    injectNavigationPlanets()
    syncPosition(false)

    local controller = SWU.Controller
    local computer = SWU.NavigationComputer
    local state = controller:GetHyperspace()
    local targetName = computer:GetTargetPlanet()

    if targetName and targetName ~= "" then
        Adapter.LastTargetPlanetName = targetName
    end

    if Adapter.LastHyperspaceState == nil then
        Adapter.LastHyperspaceState = state
        return
    end

    if state ~= Adapter.LastHyperspaceState then
        local destination = resolvePlanetBySWUName(
            targetName ~= "" and targetName or Adapter.LastTargetPlanetName
        )

        if controller:IsInHyperspace() and destination then
            Convergence.World.BeginHyperspace(
                destination:GetID(),
                controller:GetShipPos()
            )
        elseif Adapter.LastHyperspaceState ~= state
            and not controller:IsInHyperspace()
            and destination
            and Convergence.World.GetState().travelStatus == "hyperspace" then

            Convergence.World.Arrive(
                destination:GetID(),
                controller:GetShipPos()
            )
        end

        Adapter.LastHyperspaceState = state
    end
end

timer.Create("Convergence.SWUWorld.Sync", 1, 0, inspectState)

hook.Add("OnEntityCreated", "Convergence.SWUWorld.NavigationCreated", function(entity)
    timer.Simple(1, function()
        if not IsValid(entity) then
            return
        end

        if entity:GetClass() == "swu_navigation_computer" then
            injectNavigationPlanets()
        end
    end)
end)

concommand.Add("convergence_swu_sync", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    local success = injectNavigationPlanets()
    syncPosition(true)

    print(success
        and "[Convergence] SWU navigation planets synchronized."
        or "[Convergence] SWU navigation computer is not available.")
end)
