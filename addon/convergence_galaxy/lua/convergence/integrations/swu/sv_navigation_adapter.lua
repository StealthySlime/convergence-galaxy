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


local function upsertPlanetIntoList(list, name, position)
    if not istable(list) then
        return false
    end

    local normalized = Convergence.NormalizeID(name)

    for _, entry in ipairs(list) do
        if istable(entry)
            and Convergence.NormalizeID(
                entry.name or entry.Name or entry.id or entry.ID
            ) == normalized then
            entry.name = entry.name or name
            entry.Name = entry.Name or name
            entry.pos = Vector(position.x, position.y, position.z)
            entry.position = entry.position
                or Vector(position.x, position.y, position.z)
            entry.Position = entry.Position
                or Vector(position.x, position.y, position.z)
            return true
        end
    end

    list[#list + 1] = {
        name = name,
        Name = name,
        id = normalized,
        pos = Vector(position.x, position.y, position.z),
        position = Vector(position.x, position.y, position.z),
        Position = Vector(position.x, position.y, position.z)
    }

    return true
end

function Adapter:SyncExternalPlanetRegistries()
    if not SWU then
        return 0
    end

    local registries = {
        SWU.Planets,
        SWU.AllPlanets,
        SWU.PlanetList,
        SWU.Config and SWU.Config.Planets,
        SWU.Configuration and SWU.Configuration.Planets,
        SWU.Controller and SWU.Controller.Planets,
        SWU.NavigationComputer and SWU.NavigationComputer.Planets,
        SWU.NavigationComputer and SWU.NavigationComputer.allPlanets
    }

    local writes = 0

    for _, definition in ipairs(
        Convergence.Config.Planets or {}
    ) do
        local planetID = Convergence.NormalizeID(definition.id)
        local mapping = (Convergence.SWUPlanetMapping or {})[planetID]
        local name = mapping and mapping.navigationName
            or definition.swu and definition.swu.name
            or definition.name
            or planetID
        local position = mapping and mapping.position
            or definition.swu and definition.swu.pos

        if isvector(position) then
            -- Guarantee every configured Convergence planet has a mapping.
            Convergence.SWUPlanetMapping[planetID] = {
                navigationName = name,
                position = Vector(position.x, position.y, position.z)
            }

            for _, registry in ipairs(registries) do
                if upsertPlanetIntoList(registry, name, position) then
                    writes = writes + 1
                end
            end

            -- Some SWU builds expose registration functions instead of tables.
            for _, target in ipairs({
                SWU,
                SWU.Configuration,
                SWU.NavigationComputer
            }) do
                if istable(target) then
                    for _, functionName in ipairs({
                        "RegisterPlanet",
                        "AddPlanet",
                        "CreatePlanet"
                    }) do
                        local method = target[functionName]

                        if isfunction(method) then
                            pcall(
                                method,
                                target,
                                name,
                                Vector(position.x, position.y, position.z)
                            )
                        end
                    end
                end
            end
        end
    end

    return writes
end

function Adapter:SyncPlanets()
    if not self:IsAvailable() then
        return false, "SWU navigation computer is unavailable."
    end

    self:SyncExternalPlanetRegistries()

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
    self:SyncExternalPlanetRegistries()
    self:PatchNavigationComputer()
    self:PatchController()

    return true
end


function Adapter:ResetNavigationAfterArrival()
    if not self:IsAvailable() then
        self.ActiveTravelProfile = nil
        self.LastDestinationName = nil
        return
    end

    local computer = SWU.NavigationComputer

    -- Clear the temporary Convergence speed modifier so the next destination
    -- can calculate its own travel profile.
    local externalConVar = SWU.Configuration
        and SWU.Configuration:GetConVar(
            "swu_external_hyperspace_speed_modifier"
        )

    if externalConVar and externalConVar.SetFloat then
        externalConVar:SetFloat(1)
    else
        RunConsoleCommand(
            "swu_external_hyperspace_speed_modifier",
            "1"
        )
    end

    -- Different SWU versions expose different network-var setters. Clear every
    -- supported piece of completed-jump state without assuming one API.
    local resetCalls = {
        {"SetLoading", false},
        {"SetCanJump", false},
        {"SetTargetPlanet", ""},
        {"SetSelectedPlanet", ""},
        {"SetTarget", ""},
        {"SetTargetVector", Vector(0, 0, 0)},
        {"SetEstimatedJumpTime", 0},
        {"SetJumpProgress", 0},
        {"SetProgress", 0}
    }

    for _, call in ipairs(resetCalls) do
        local method = computer[call[1]]

        if isfunction(method) then
            pcall(method, computer, call[2])
        end
    end

    -- Reset search/page state so the navigation list becomes selectable again.
    if isfunction(computer.SetSearchTerm) then
        pcall(computer.SetSearchTerm, computer, "")
    end

    if isfunction(computer.SetCurPage) then
        pcall(computer.SetCurPage, computer, 1)
    end

    if isfunction(computer.UpdatePageValue) then
        pcall(computer.UpdatePageValue, computer)
    end

    -- Some builds store these as ordinary Lua fields rather than network vars.
    computer.TargetPlanet = nil
    computer.SelectedPlanet = nil
    computer.Target = nil
    computer.Loading = false
    computer.CanJumpState = false

    self.ActiveTravelProfile = nil
    self.LastDestinationName = nil

    hook.Run("ConvergenceNavigationComputerReset", self.ID)
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

    if inHyperspace
        and self.ActiveTravelProfile
        and self.ActiveTravelProfile.startedAt
        and CurTime() >= (
            self.ActiveTravelProfile.startedAt
            + self.ActiveTravelProfile.desiredSeconds
            + 5
        ) then
        -- Compatibility fallback for SWU builds that do not apply the
        -- external speed modifier to their exit timer.
        if isfunction(SWU.Controller.ExitHyperspace) then
            pcall(SWU.Controller.ExitHyperspace, SWU.Controller)
        elseif isfunction(SWU.Controller.SetHyperspace) then
            pcall(SWU.Controller.SetHyperspace, SWU.Controller, 0)
        end
    end

    if inHyperspace ~= self.LastHyperspace then
        if inHyperspace then
            if self.ActiveTravelProfile then
                self.ActiveTravelProfile.startedAt = CurTime()
            end

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
                local arrivalPosition =
                    self:GetMappedPosition(arrivalPlanet:GetID())

                if isvector(arrivalPosition)
                    and IsValid(SWU.Controller)
                    and isfunction(SWU.Controller.SetShipPos) then
                    pcall(
                        SWU.Controller.SetShipPos,
                        SWU.Controller,
                        Vector(
                            arrivalPosition.x,
                            arrivalPosition.y,
                            arrivalPosition.z
                        )
                    )
                    position = arrivalPosition
                end

                Convergence.World.Arrive(
                    arrivalPlanet:GetID(),
                    position
                )

                self:ResetNavigationAfterArrival()

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


concommand.Add("convergence_swu_planet_status", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    print("========== Convergence SWU Planet Status ==========")

    for _, definition in ipairs(
        Convergence.Config.Planets or {}
    ) do
        local planetID = Convergence.NormalizeID(definition.id)
        local mapping = (Convergence.SWUPlanetMapping or {})[planetID]
        local name = mapping and mapping.navigationName
            or definition.name
        local navEntry = Adapter:FindSWUPlanetEntry(name)

        print(string.format(
            "%-16s mapping=%-5s navigation=%-5s position=%s",
            planetID,
            mapping and "PASS" or "FAIL",
            navEntry and "PASS" or "FAIL",
            tostring(mapping and mapping.position or "nil")
        ))
    end

    print("===================================================")
end)


concommand.Add("convergence_swu_force_arrival", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    local targetName = Adapter:GetDestination()
    local planet = Adapter:ResolvePlanet(targetName)

    if not planet then
        print("[Convergence] No valid SWU destination is selected.")
        return
    end

    local position = Adapter:GetMappedPosition(planet:GetID())

    if isvector(position)
        and IsValid(SWU.Controller)
        and isfunction(SWU.Controller.SetShipPos) then
        SWU.Controller:SetShipPos(position)
    end

    if IsValid(SWU.Controller)
        and isfunction(SWU.Controller.ExitHyperspace) then
        pcall(SWU.Controller.ExitHyperspace, SWU.Controller)
    elseif IsValid(SWU.Controller)
        and isfunction(SWU.Controller.SetHyperspace) then
        pcall(SWU.Controller.SetHyperspace, SWU.Controller, 0)
    end

    Convergence.World.Arrive(planet:GetID(), position)
    Adapter:ResetNavigationAfterArrival()

    print(
        "[Convergence] Forced synchronized arrival at "
        .. planet:GetName()
        .. "."
    )
end)


concommand.Add("convergence_swu_reset_navigation", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        return
    end

    Adapter:ResetNavigationAfterArrival()

    print(
        "[Convergence] SWU navigation computer reset. "
        .. "A new destination may now be selected."
    )
end)
