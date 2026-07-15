Convergence.SWUNavigation = Convergence.SWUNavigation or {}

local Adapter = Convergence.SWUNavigation

Adapter.ID = "swu"
Adapter.LastHyperspace = nil
Adapter.LastDestinationName = nil
Adapter.LastPosition = nil

function Adapter:IsAvailable()
    return SWU ~= nil
        and IsValid(SWU.Controller)
        and IsValid(SWU.NavigationComputer)
end

function Adapter:GetShipPosition()
    if not self:IsAvailable() then
        return nil
    end

    return SWU.Controller:GetShipPos()
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

function Adapter:SyncPlanets()
    if not self:IsAvailable() then
        return false, "SWU navigation computer is unavailable."
    end

    local computer = SWU.NavigationComputer
    computer.allPlanets = computer.allPlanets or computer.Planets or {}
    computer.Planets = computer.Planets or computer.allPlanets

    local seen = {}

    for _, entry in ipairs(computer.allPlanets) do
        seen[Convergence.NormalizeID(entry.name)] = true
    end

    for planetID, mapping in pairs(Convergence.SWUPlanetMapping or {}) do
        local name = tostring(mapping.navigationName or planetID)

        if isvector(mapping.position)
            and not seen[Convergence.NormalizeID(name)] then
            computer.allPlanets[#computer.allPlanets + 1] = {
                name = name,
                pos = Vector(
                    mapping.position.x,
                    mapping.position.y,
                    mapping.position.z
                )
            }
        end
    end

    table.SortByMember(computer.allPlanets, "name", true)
    computer.Planets = table.Copy(computer.allPlanets)

    if computer.SetCurPage then computer:SetCurPage(1) end
    if computer.SetPages then
        computer:SetPages(math.max(
            math.ceil(#computer.Planets / (computer.PlanetsPerPage or 1)),
            1
        ))
    end
    if computer.UpdatePageValue then computer:UpdatePageValue() end

    return true
end

function Adapter:Poll()
    if not self:IsAvailable() then
        return
    end

    local position = self:GetShipPosition()
    local inHyperspace = self:IsInHyperspace()
    local destinationName = self:GetDestination()

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
        local planet = self:ResolvePlanet(destinationName)

        if inHyperspace and planet then
            Convergence.World.BeginHyperspace(planet:GetID(), position)

            hook.Run(
                "ConvergenceNavigationHyperspaceStarted",
                self.ID,
                planet:GetID()
            )
        elseif not inHyperspace
            and planet
            and Convergence.World.GetState().travelStatus == "hyperspace" then

            Convergence.World.Arrive(planet:GetID(), position)

            hook.Run(
                "ConvergenceNavigationHyperspaceEnded",
                self.ID,
                planet:GetID()
            )
        end

        self.LastHyperspace = inHyperspace
    end
end

Convergence.Navigation.RegisterAdapter(Adapter.ID, Adapter)
Convergence.Services.Register("navigation", Convergence.Navigation)

timer.Create("Convergence.Navigation.SWU.Poll", 0.5, 0, function()
    Adapter:Poll()
end)

timer.Create("Convergence.Navigation.SWU.PlanetSync", 5, 0, function()
    if Adapter:IsAvailable() then
        Adapter:SyncPlanets()
        timer.Remove("Convergence.Navigation.SWU.PlanetSync")
    end
end)

concommand.Add("convergence_swu_sync", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end

    local success, message = Adapter:SyncPlanets()

    print(success
        and "[Convergence] SWU navigation planets synchronized."
        or "[Convergence] " .. tostring(message))
end)
