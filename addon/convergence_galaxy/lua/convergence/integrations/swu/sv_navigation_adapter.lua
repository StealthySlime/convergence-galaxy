Convergence.SWUNavigation = Convergence.SWUNavigation or {}

local Adapter = Convergence.SWUNavigation

Adapter.ID = "swu"
Adapter.LastHyperspace = nil
Adapter.LastDestinationName = nil
Adapter.LastPosition = nil
Adapter.PatchedComputer = nil

function Adapter:IsAvailable()
    return SWU ~= nil
        and IsValid(SWU.Controller)
        and IsValid(SWU.NavigationComputer)
end

function Adapter:GetShipPosition()
    return self:IsAvailable() and SWU.Controller:GetShipPos() or nil
end

function Adapter:IsInHyperspace()
    return self:IsAvailable() and SWU.Controller:IsInHyperspace() or false
end

function Adapter:GetDestination()
    if not self:IsAvailable() then
        return nil
    end

    local name = SWU.NavigationComputer:GetTargetPlanet()

    if name and name ~= "" then
        self.LastDestinationName = name
    end

    return self.LastDestinationName
end

function Adapter:ResolvePlanet(name)
    local normalized = Convergence.NormalizeID(name)

    for planetID, mapping in pairs(Convergence.SWUPlanetMapping or {}) do
        if Convergence.NormalizeID(mapping.navigationName) == normalized
            or Convergence.NormalizeID(planetID) == normalized then
            return Convergence.PlanetService.Get(planetID)
        end
    end

    return Convergence.PlanetService.Get(normalized)
end


function Adapter:ResolveNearestPlanet(position)
    if not isvector(position) then
        return nil, math.huge
    end

    local nearestPlanet = nil
    local nearestDistanceSquared = math.huge

    for planetID, mapping in pairs(Convergence.SWUPlanetMapping or {}) do
        if isvector(mapping.position) then
            local distanceSquared = position:DistToSqr(mapping.position)

            if distanceSquared < nearestDistanceSquared then
                nearestDistanceSquared = distanceSquared
                nearestPlanet = Convergence.PlanetService.Get(planetID)
            end
        end
    end

    return nearestPlanet, nearestDistanceSquared
end

function Adapter:ReconcileArrival(position)
    if self:IsInHyperspace() or not isvector(position) then
        return false
    end

    local nearestPlanet, distanceSquared = self:ResolveNearestPlanet(position)

    -- SWU exits close to the selected universe coordinate. The generous
    -- threshold tolerates offsets applied by the navigation addon while still
    -- preventing unrelated positions from changing the current planet.
    local threshold = 5000
    local withinArrivalRange = nearestPlanet
        and distanceSquared <= threshold * threshold

    if not withinArrivalRange then
        return false
    end

    local world = Convergence.World.GetState()

    if world.currentPlanetID ~= nearestPlanet:GetID()
        or world.travelStatus == "hyperspace" then
        Convergence.World.Arrive(nearestPlanet:GetID(), position)

        hook.Run(
            "ConvergenceNavigationHyperspaceEnded",
            self.ID,
            nearestPlanet:GetID()
        )
    end

    return true
end

function Adapter:IsConvergenceDestination(name)
    local normalized = Convergence.NormalizeID(name)

    for planetID, mapping in pairs(Convergence.SWUPlanetMapping or {}) do
        if normalized == Convergence.NormalizeID(planetID)
            or normalized == Convergence.NormalizeID(mapping.navigationName) then
            return true
        end
    end

    return false
end

function Adapter:PatchNavigationComputer()
    if not self:IsAvailable() then
        return false
    end

    local computer = SWU.NavigationComputer

    if self.PatchedComputer == computer then
        return true
    end

    if not isfunction(computer.SelectPlanet) then
        return false
    end

    local originalSelectPlanet = computer.SelectPlanet

    computer.SelectPlanet = function(entity, planetName)
        originalSelectPlanet(entity, planetName)

        -- SWU intentionally disables its lever when EstimatedJumpTime is below
        -- five seconds. Custom Convergence destinations must remain usable.
        if Adapter:IsConvergenceDestination(planetName)
            and entity:GetTargetPlanet() == planetName
            and entity:GetEstimatedJumpTime() > 0
            and entity:GetEstimatedJumpTime() < 5 then
            entity:SetEstimatedJumpTime(5.1)
        end
    end

    self.PatchedComputer = computer
    return true
end

function Adapter:SyncPlanets()
    if not self:IsAvailable() then
        return false, "SWU navigation computer is unavailable."
    end

    local computer = SWU.NavigationComputer

    -- Rebuild from SWU's authoritative universe first, then append only the
    -- Convergence destinations that do not already exist.
    if isfunction(computer.LoadPlanets) then
        computer:LoadPlanets()
    else
        computer.Planets = computer.Planets or {}
        computer.allPlanets = computer.allPlanets or computer.Planets
    end

    local allPlanets = computer.allPlanets or computer.Planets or {}
    local seen = {}

    for _, entry in ipairs(allPlanets) do
        if istable(entry) and entry.name then
            seen[Convergence.NormalizeID(entry.name)] = true
        end
    end

    for planetID, mapping in pairs(Convergence.SWUPlanetMapping or {}) do
        local name = tostring(mapping.navigationName or planetID)
        local key = Convergence.NormalizeID(name)

        if isvector(mapping.position) and not seen[key] then
            allPlanets[#allPlanets + 1] = {
                name = name,
                pos = Vector(
                    mapping.position.x,
                    mapping.position.y,
                    mapping.position.z
                )
            }
            seen[key] = true
        end
    end

    table.SortByMember(allPlanets, "name", true)

    computer.allPlanets = allPlanets
    computer.Planets = table.Copy(allPlanets)
    computer.PlanetsPerPage = math.max(tonumber(computer.PlanetsPerPage) or 5, 1)

    if computer.SetSearchTerm then
        computer:SetSearchTerm("")
    end

    if computer.SetCurPage then
        computer:SetCurPage(1)
    end

    if computer.SetPages then
        computer:SetPages(math.max(
            math.ceil(#computer.Planets / computer.PlanetsPerPage),
            1
        ))
    end

    if computer.UpdatePageValue then
        computer:UpdatePageValue()
    end

    self:PatchNavigationComputer()

    return true
end

function Adapter:Poll()
    if not self:IsAvailable() then
        return
    end

    self:PatchNavigationComputer()

    local position = self:GetShipPosition()
    local inHyperspace = self:IsInHyperspace()
    local destinationName = self:GetDestination()
    local selectedPlanet = self:ResolvePlanet(destinationName)

    if isvector(position)
        and (
            not isvector(self.LastPosition)
            or self.LastPosition:DistToSqr(position) > 0.001
        ) then
        self.LastPosition = Vector(position.x, position.y, position.z)
        Convergence.World.SetShipPosition(position)
    end

    if self.LastHyperspace == nil then
        self.LastHyperspace = inHyperspace
        return
    end

    if inHyperspace ~= self.LastHyperspace then
        if inHyperspace then
            if selectedPlanet then
                Convergence.World.BeginHyperspace(
                    selectedPlanet:GetID(),
                    position
                )

                hook.Run(
                    "ConvergenceNavigationHyperspaceStarted",
                    self.ID,
                    selectedPlanet:GetID()
                )
            end
        else
            -- SWU's selected destination is authoritative after a completed
            -- jump. GetShipPos may use a local/visual coordinate system that
            -- does not exactly match injected universe coordinates.
            local worldDestination =
                Convergence.World.GetState().destinationPlanetID

            local arrivalPlanet = selectedPlanet
                or Convergence.PlanetService.Get(worldDestination)

            if arrivalPlanet then
                Convergence.World.Arrive(
                    arrivalPlanet:GetID(),
                    position
                )

                hook.Run(
                    "ConvergenceNavigationHyperspaceEnded",
                    self.ID,
                    arrivalPlanet:GetID()
                )
            end
        end

        self.LastHyperspace = inHyperspace
    end
end

Convergence.Navigation.RegisterAdapter(Adapter.ID, Adapter)
Convergence.Services.Register("navigation", Convergence.Navigation)

timer.Create("Convergence.Navigation.SWU.Poll", 0.5, 0, function()
    Adapter:Poll()
end)

timer.Create("Convergence.Navigation.SWU.PlanetSync", 2, 0, function()
    if Adapter:IsAvailable() then
        Adapter:SyncPlanets()
        timer.Remove("Convergence.Navigation.SWU.PlanetSync")
    end
end)

hook.Add("OnEntityCreated", "Convergence.Navigation.SWU.ComputerCreated", function(entity)
    timer.Simple(1, function()
        if IsValid(entity) and entity:GetClass() == "swu_navigation_computer" then
            Adapter.PatchedComputer = nil
            Adapter:SyncPlanets()
        end
    end)
end)

concommand.Add("convergence_swu_sync", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    local success, message = Adapter:SyncPlanets()

    print(success
        and "[Convergence] SWU navigation planets synchronized and lever compatibility applied."
        or "[Convergence] " .. tostring(message))
end)

concommand.Add("convergence_swu_jump_status", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    if not Adapter:IsAvailable() then
        print("[Convergence] SWU navigation is unavailable.")
        return
    end

    local computer = SWU.NavigationComputer

    print("========== SWU Jump Status ==========")
    print("Target:              " .. tostring(computer:GetTargetPlanet()))
    print("Loading:             " .. tostring(computer:GetLoading()))
    print("Estimated jump time: " .. tostring(computer:GetEstimatedJumpTime()))
    print("Can jump:            " .. tostring(computer:CanJump()))
    print("Controller allowed:  " .. tostring(
        SWU.Controller:GetCanJumpIntoHyperspace()
    ))
    print("Hyperspace state:    " .. tostring(SWU.Controller:GetHyperspace()))
    print("=====================================")
end)
