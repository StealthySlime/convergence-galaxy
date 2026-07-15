Convergence.SWUNavigation = Convergence.SWUNavigation or {}

local Adapter = Convergence.SWUNavigation

Adapter.ID = "swu"
Adapter.LastHyperspace = nil
Adapter.LastDestinationName = nil
Adapter.LastPosition = nil
Adapter.PatchedComputer = nil
Adapter.PatchedController = nil
Adapter.OriginalControllerSetShipPos = nil
Adapter.ActiveTravelProfile = nil

local function getSWUConfig()
    return (Convergence.Config.World and Convergence.Config.World.SWU) or {}
end

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

function Adapter:IsConvergenceDestination(name)
    return self:ResolvePlanet(name) ~= nil
end

function Adapter:GetMappedPosition(planetID)
    local mapping = (Convergence.SWUPlanetMapping or {})[
        Convergence.NormalizeID(planetID)
    ]

    return mapping and mapping.position or nil
end

function Adapter:FindSWUPlanetEntry(name)
    if not self:IsAvailable() then
        return nil
    end

    local normalized = Convergence.NormalizeID(name)
    local computer = SWU.NavigationComputer

    for _, entry in ipairs(computer.allPlanets or computer.Planets or {}) do
        if istable(entry)
            and Convergence.NormalizeID(entry.name) == normalized
            and isvector(entry.pos) then
            return entry
        end
    end

    return nil
end

function Adapter:RefreshMappedCoordinates()
    if not self:IsAvailable() then
        return
    end

    for planetID, mapping in pairs(Convergence.SWUPlanetMapping or {}) do
        local entry = self:FindSWUPlanetEntry(
            mapping.navigationName or planetID
        )

        -- Existing SWU universe data is authoritative. This also means the GM
        -- Ship Position/GOTO screen and Convergence use exactly the same point.
        if entry and isvector(entry.pos) then
            mapping.position = Vector(entry.pos.x, entry.pos.y, entry.pos.z)
        end
    end
end

function Adapter:ResolveNearestRegisteredPlanet(position)
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

function Adapter:ReconcileGMPosition(position, actor)
    if self:IsInHyperspace() or not isvector(position) then
        return false
    end

    self:RefreshMappedCoordinates()

    local planet, distanceSquared =
        self:ResolveNearestRegisteredPlanet(position)

    local radius = math.max(
        tonumber(getSWUConfig().PlanetArrivalRadius) or 8,
        0.1
    )

    if not planet or distanceSquared > radius * radius then
        return false
    end

    local state = Convergence.World.GetState()

    if state.currentPlanetID == planet:GetID()
        and state.travelStatus ~= "hyperspace" then
        Convergence.World.SetShipPosition(position)
        return true
    end

    Convergence.World.Arrive(planet:GetID(), position)

    Convergence.Events.Publish("world.gm_teleport.arrived", {
        planetID = planet:GetID(),
        actor = IsValid(actor) and actor:SteamID64() or "unknown",
        position = {
            x = position.x,
            y = position.y,
            z = position.z
        }
    }, {
        actor = actor,
        source = "swu_gm_goto",
        reason = "SWU GM Ship Position/GOTO changed the task-force location."
    })

    hook.Run(
        "ConvergenceNavigationGMTeleport",
        self.ID,
        planet:GetID(),
        actor
    )

    return true
end

function Adapter:GetRawTravelSeconds()
    if not self:IsAvailable() then
        return 0
    end

    local computer = SWU.NavigationComputer
    local target = computer:GetTargetVector()
    local ship = SWU.Controller:GetShipPos()
    local acceleration =
        SWU.GlobalConfig
        and SWU.GlobalConfig.hyperspaceAcceleration
        and tonumber(SWU.GlobalConfig.hyperspaceAcceleration.x)
        or 0

    if not isvector(target) or not isvector(ship) or acceleration <= 0 then
        return tonumber(computer:GetEstimatedJumpTime()) or 0
    end

    return ship:Distance(target) / acceleration
end

function Adapter:GetDesiredTravelSeconds(rawSeconds)
    local settings = getSWUConfig()
    local minimum = math.max(
        tonumber(settings.MinimumHyperspaceSeconds) or 45,
        5.1
    )
    local maximum = math.max(
        tonumber(settings.MaximumHyperspaceSeconds) or 180,
        minimum
    )
    local divisor = math.max(
        tonumber(settings.EstimateDivisor) or 60,
        0.01
    )

    return math.Clamp(rawSeconds / divisor, minimum, maximum)
end

function Adapter:ApplyTravelProfile()
    if not self:IsAvailable() then
        return false
    end

    local computer = SWU.NavigationComputer
    local rawSeconds = self:GetRawTravelSeconds()

    if rawSeconds <= 0 then
        return false
    end

    local desiredSeconds = self:GetDesiredTravelSeconds(rawSeconds)
    local baseModifier = 1
    local baseConVar = SWU.Configuration
        and SWU.Configuration:GetConVar("swu_hyperspace_speed_modifier")

    if baseConVar then
        baseModifier = math.max(baseConVar:GetFloat(), 0.01)
    end

    local externalModifier = math.max(
        rawSeconds / desiredSeconds / baseModifier,
        0.01
    )

    local externalConVar = SWU.Configuration
        and SWU.Configuration:GetConVar(
            "swu_external_hyperspace_speed_modifier"
        )

    if externalConVar and externalConVar.SetFloat then
        externalConVar:SetFloat(externalModifier)
    else
        RunConsoleCommand(
            "swu_external_hyperspace_speed_modifier",
            tostring(externalModifier)
        )
    end

    -- Keep the visible SWU estimate useful to players instead of displaying
    -- several real-world hours while the external modifier shortens the jump.
    computer:SetEstimatedJumpTime(math.max(desiredSeconds, 5.1))

    self.ActiveTravelProfile = {
        rawSeconds = rawSeconds,
        desiredSeconds = desiredSeconds,
        baseModifier = baseModifier,
        externalModifier = externalModifier,
        targetPlanet = computer:GetTargetPlanet()
    }

    return true, self.ActiveTravelProfile
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

        if Adapter:IsConvergenceDestination(planetName) then
            timer.Simple(
                (tonumber(entity.ProgressCalculationDuration) or 5) + 0.05,
                function()
                    if IsValid(entity)
                        and entity:GetTargetPlanet() == planetName then
                        Adapter:ApplyTravelProfile()
                    end
                end
            )
        end
    end

    self.PatchedComputer = computer
    return true
end

function Adapter:PatchController()
    if not self:IsAvailable() then
        return false
    end

    local controller = SWU.Controller

    if self.PatchedController == controller then
        return true
    end

    if not isfunction(controller.SetShipPos) then
        return false
    end

    local originalSetShipPos = controller.SetShipPos
    self.OriginalControllerSetShipPos = originalSetShipPos

    controller.SetShipPos = function(entity, newPosition)
        local oldPosition = entity:GetShipPos()
        originalSetShipPos(entity, newPosition)

        if not isvector(oldPosition) or not isvector(newPosition) then
            return
        end

        if entity:IsInHyperspace() then
            return
        end

        local threshold = math.max(
            tonumber(getSWUConfig().TeleportDeltaThreshold) or 50,
            0.1
        )

        if oldPosition:DistToSqr(newPosition) < threshold * threshold then
            return
        end

        -- SWU's admin configuration uses swu_setShipPos, which calls this
        -- setter directly. Reconcile on the next tick after the new value is
        -- fully networked and persisted.
        timer.Simple(0, function()
            if IsValid(entity) then
                Adapter:ReconcileGMPosition(entity:GetShipPos())
            end
        end)
    end

    self.PatchedController = controller
    return true
end

function Adapter:SyncPlanets()
    if not self:IsAvailable() then
        return false, "SWU navigation computer is unavailable."
    end

    local computer = SWU.NavigationComputer

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
            seen[Convergence.NormalizeID(entry.name)] = entry

            local planet = self:ResolvePlanet(entry.name)
            local mapping = planet
                and (Convergence.SWUPlanetMapping or {})[planet:GetID()]
                or nil

            if mapping and isvector(entry.pos) then
                mapping.position = Vector(
                    entry.pos.x,
                    entry.pos.y,
                    entry.pos.z
                )
            end
        end
    end

    for planetID, mapping in pairs(Convergence.SWUPlanetMapping or {}) do
        local name = tostring(mapping.navigationName or planetID)
        local key = Convergence.NormalizeID(name)

        if isvector(mapping.position) and not seen[key] then
            local entry = {
                name = name,
                pos = Vector(
                    mapping.position.x,
                    mapping.position.y,
                    mapping.position.z
                )
            }

            allPlanets[#allPlanets + 1] = entry
            seen[key] = entry
        end
    end

    table.SortByMember(allPlanets, "name", true)

    computer.allPlanets = allPlanets
    computer.Planets = table.Copy(allPlanets)
    computer.PlanetsPerPage =
        math.max(tonumber(computer.PlanetsPerPage) or 5, 1)

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

    self:RefreshMappedCoordinates()
    self:PatchNavigationComputer()
    self:PatchController()

    return true
end

function Adapter:Poll()
    if not self:IsAvailable() then
        return
    end

    self:PatchNavigationComputer()
    self:PatchController()

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

hook.Add("OnEntityCreated", "Convergence.Navigation.SWU.EntitiesCreated", function(entity)
    timer.Simple(1, function()
        if not IsValid(entity) then
            return
        end

        local class = entity:GetClass()

        if class == "swu_navigation_computer" then
            Adapter.PatchedComputer = nil
            Adapter:SyncPlanets()
        elseif class == "swu_controller" then
            Adapter.PatchedController = nil
            Adapter:PatchController()
        end
    end)
end)

concommand.Add("convergence_swu_sync", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    local success, message = Adapter:SyncPlanets()

    print(success
        and "[Convergence] SWU planets, coordinates, GM GOTO tracking, and travel profile synchronized."
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
    local profile = Adapter.ActiveTravelProfile

    print("========== SWU Jump Status ==========")
    print("Target:                 " .. tostring(computer:GetTargetPlanet()))
    print("Loading:                " .. tostring(computer:GetLoading()))
    print("Displayed jump time:    " .. tostring(computer:GetEstimatedJumpTime()))
    print("Can jump:               " .. tostring(computer:CanJump()))
    print("Controller allowed:     " .. tostring(
        SWU.Controller:GetCanJumpIntoHyperspace()
    ))
    print("Hyperspace state:       " .. tostring(SWU.Controller:GetHyperspace()))
    print("Raw SWU estimate:       " .. tostring(
        profile and profile.rawSeconds or Adapter:GetRawTravelSeconds()
    ))
    print("Target travel duration: " .. tostring(
        profile and profile.desiredSeconds or "Not calculated"
    ))
    print("External speed modifier:" .. tostring(
        profile and profile.externalModifier or "Not calculated"
    ))
    print("=====================================")
end)

concommand.Add("convergence_swu_reconcile_position", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    if not Adapter:IsAvailable() then
        print("[Convergence] SWU navigation is unavailable.")
        return
    end

    local success = Adapter:ReconcileGMPosition(
        SWU.Controller:GetShipPos(),
        ply
    )

    print(success
        and "[Convergence] Current SWU position matched and synchronized."
        or "[Convergence] Current SWU position is not close to a registered Convergence planet.")
end)
