Convergence.UI = Convergence.UI or {}

local Theme = Convergence.UI.Theme
local PANEL = {}

local function drawCircleOutline(x, y, radius, color, segments)
    segments = segments or 48
    surface.SetDrawColor(color)

    local previousX = x + radius
    local previousY = y

    for index = 1, segments do
        local angle = math.rad((index / segments) * 360)
        local currentX = x + math.cos(angle) * radius
        local currentY = y + math.sin(angle) * radius

        surface.DrawLine(previousX, previousY, currentX, currentY)

        previousX = currentX
        previousY = currentY
    end
end

local function drawRotatingRing(x, y, radius, rotation, color, segments)
    segments = segments or 36
    surface.SetDrawColor(color)

    for index = 0, segments - 1 do
        if index % 3 ~= 2 then
            local angleA = math.rad(rotation + (index / segments) * 360)
            local angleB = math.rad(rotation + ((index + 0.7) / segments) * 360)

            surface.DrawLine(
                x + math.cos(angleA) * radius,
                y + math.sin(angleA) * radius,
                x + math.cos(angleB) * radius,
                y + math.sin(angleB) * radius
            )
        end
    end
end

function PANEL:Init()
    local configuration = Convergence.Config.Galaxy or {}

    self.Zoom = tonumber(configuration.DefaultZoom) or 1
    self.TargetZoom = self.Zoom

    self.OffsetX = 0
    self.OffsetY = 0
    self.TargetOffsetX = 0
    self.TargetOffsetY = 0

    self.Dragging = false
    self.LastMouseX = 0
    self.LastMouseY = 0
    self.HoveredPlanetID = nil
    self.SelectedPlanetID = nil
    self.NodePositions = {}
    self.HoverAlpha = 0
    self.HoverPlanetID = nil
    self.HoveredFleetID = nil
    self.FleetPositions = {}

    self:SetMouseInputEnabled(true)
end

function PANEL:SetGalaxyData(data)
    self.Data = data or {}
    self:InvalidateLayout(true)
end

function PANEL:SetSelectedPlanet(id)
    self.SelectedPlanetID = id
end

function PANEL:GetSelectedPlanet()
    return self.SelectedPlanetID
end

function PANEL:OnPlanetSelected(id)
end

function PANEL:ResetView()
    local configuration = Convergence.Config.Galaxy or {}

    self.TargetZoom = tonumber(configuration.DefaultZoom) or 1
    self.TargetOffsetX = 0
    self.TargetOffsetY = 0
end

function PANEL:OnMousePressed(code)
    if code == MOUSE_LEFT then
        if self.HoveredPlanetID then
            self.SelectedPlanetID = self.HoveredPlanetID
            self:OnPlanetSelected(self.HoveredPlanetID)
            return
        end

        self.Dragging = true
        self.LastMouseX, self.LastMouseY = self:CursorPos()
        self:MouseCapture(true)
    elseif code == MOUSE_RIGHT then
        self:ResetView()
    end
end

function PANEL:OnMouseReleased(code)
    if code == MOUSE_LEFT and self.Dragging then
        self.Dragging = false
        self:MouseCapture(false)
    end
end

function PANEL:OnMouseWheeled(delta)
    local configuration = Convergence.Config.Galaxy or {}
    local minimum = tonumber(configuration.MinZoom) or 0.65
    local maximum = tonumber(configuration.MaxZoom) or 2.5

    local mouseX, mouseY = self:CursorPos()
    local oldTarget = self.TargetZoom
    local newTarget = math.Clamp(oldTarget + delta * 0.12, minimum, maximum)

    if newTarget == oldTarget then
        return true
    end

    local centerX = self:GetWide() / 2 + self.TargetOffsetX
    local centerY = self:GetTall() / 2 + self.TargetOffsetY
    local worldX = (mouseX - centerX) / oldTarget
    local worldY = (mouseY - centerY) / oldTarget

    self.TargetZoom = newTarget
    self.TargetOffsetX = mouseX - self:GetWide() / 2 - worldX * newTarget
    self.TargetOffsetY = mouseY - self:GetTall() / 2 - worldY * newTarget

    return true
end

function PANEL:Think()
    local configuration = Convergence.Config.Galaxy or {}
    local frameTime = FrameTime()

    if self.Dragging then
        local mouseX, mouseY = self:CursorPos()

        self.TargetOffsetX = self.TargetOffsetX + (mouseX - self.LastMouseX)
        self.TargetOffsetY = self.TargetOffsetY + (mouseY - self.LastMouseY)

        self.LastMouseX = mouseX
        self.LastMouseY = mouseY
    end

    self.Zoom = Lerp(
        math.Clamp(frameTime * (tonumber(configuration.ZoomSmoothing) or 10), 0, 1),
        self.Zoom,
        self.TargetZoom
    )

    self.OffsetX = Lerp(
        math.Clamp(frameTime * (tonumber(configuration.PanSmoothing) or 14), 0, 1),
        self.OffsetX,
        self.TargetOffsetX
    )

    self.OffsetY = Lerp(
        math.Clamp(frameTime * (tonumber(configuration.PanSmoothing) or 14), 0, 1),
        self.OffsetY,
        self.TargetOffsetY
    )

    local mouseX, mouseY = self:CursorPos()
    local hoveredID = nil

    for id, position in pairs(self.NodePositions) do
        local dx = mouseX - position.x
        local dy = mouseY - position.y
        local radius = position.radius + 10

        if dx * dx + dy * dy <= radius * radius then
            hoveredID = id
            break
        end
    end

    self.HoveredPlanetID = hoveredID
    self.HoveredFleetID = nil

    if not hoveredID then
        for id, position in pairs(self.FleetPositions or {}) do
            local dx = mouseX - position.x
            local dy = mouseY - position.y

            if dx * dx + dy * dy <= 14 * 14 then
                self.HoveredFleetID = id
                break
            end
        end
    end

    if hoveredID ~= self.HoverPlanetID then
        self.HoverPlanetID = hoveredID
        self.HoverAlpha = 0
    end

    local targetAlpha = hoveredID and 255 or 0
    self.HoverAlpha = Lerp(math.Clamp(frameTime * 12, 0, 1), self.HoverAlpha, targetAlpha)
end

local function mapToScreen(panel, x, y)
    local width = panel:GetWide()
    local height = panel:GetTall()
    local padding = 95

    local baseX = padding + x * math.max(width - padding * 2, 1)
    local baseY = padding + y * math.max(height - padding * 2, 1)

    local centerX = width / 2
    local centerY = height / 2

    return centerX + (baseX - centerX) * panel.Zoom + panel.OffsetX,
        centerY + (baseY - centerY) * panel.Zoom + panel.OffsetY
end

local function drawStarfield(width, height)
    for index = 1, 130 do
        local x = (index * 157) % math.max(width, 1)
        local y = (index * 263) % math.max(height, 1)
        local shimmer = 35 + math.sin(CurTime() * 1.8 + index) * 20
        local size = index % 13 == 0 and 2 or 1

        surface.SetDrawColor(120, 190, 255, shimmer)
        surface.DrawRect(x, y, size, size)
    end
end

local function drawGrid(panel, width, height)
    local configuration = Convergence.Config.Galaxy or {}
    local drift = CurTime() * (tonumber(configuration.GridDriftSpeed) or 4)

    surface.SetDrawColor(45, 130, 200, 20)

    local spacing = math.max(64 * panel.Zoom, 24)
    local startX = (panel.OffsetX + drift) % spacing
    local startY = (panel.OffsetY + drift * 0.4) % spacing

    for x = startX, width, spacing do
        surface.DrawLine(x, 0, x, height)
    end

    for y = startY, height, spacing do
        surface.DrawLine(0, y, width, y)
    end
end

local function drawScanlines(width, height)
    local configuration = Convergence.Config.Galaxy or {}
    local speed = tonumber(configuration.ScanlineSpeed) or 18
    local offset = (CurTime() * speed) % 8

    surface.SetDrawColor(60, 150, 220, 10)

    for y = offset, height, 8 do
        surface.DrawRect(0, y, width, 1)
    end
end

local function drawHyperlane(left, right, color)
    surface.SetDrawColor(color)
    surface.DrawLine(left.x, left.y, right.x, right.y)

    local dx = right.x - left.x
    local dy = right.y - left.y
    local length = math.sqrt(dx * dx + dy * dy)

    if length <= 0 then
        return
    end

    local speed = tonumber(Convergence.Config.Galaxy.HyperlanePulseSpeed) or 110
    local spacing = 80
    local phase = (CurTime() * speed) % spacing

    for distance = phase, length, spacing do
        local fraction = distance / length
        local x = left.x + dx * fraction
        local y = left.y + dy * fraction

        draw.RoundedBox(3, x - 3, y - 3, 6, 6, Color(110, 210, 255, 190))
    end
end

function PANEL:Paint(width, height)
    draw.RoundedBox(6, 0, 0, width, height, Color(2, 8, 16, 248))

    drawStarfield(width, height)
    drawGrid(self, width, height)

    local data = self.Data or {}
    local planets = data.planets or {}
    local routes = (data.galaxy and data.galaxy.routes) or {}

    self.NodePositions = {}

    for id, planetData in pairs(planets) do
        local map = planetData.map or {}
        local x = tonumber(map.x)
        local y = tonumber(map.y)

        if x and y then
            local screenX, screenY = mapToScreen(self, x, y)

            self.NodePositions[id] = {
                x = screenX,
                y = screenY,
                radius = (tonumber(Convergence.Config.Galaxy.NodeRadius) or 13) * self.Zoom
            }
        end
    end

    for _, route in ipairs(routes) do
        local left = self.NodePositions[route[1]]
        local right = self.NodePositions[route[2]]

        if left and right then
            drawHyperlane(left, right, Color(50, 145, 220, 85))
        end
    end

    local pulse = (math.sin(CurTime() * 3.2) + 1) / 2
    local rotation = CurTime() * 40

    for id, position in pairs(self.NodePositions) do
        local planetData = planets[id] or {}
        local state = planetData.state or {}
        local stability = tonumber(state.stability) or 0
        local color = Theme.GetStabilityColor(stability)
        local hovered = self.HoveredPlanetID == id
        local selected = self.SelectedPlanetID == id

        local radius = position.radius
        local hoverScale = hovered and 1.18 or 1
        local nodeRadius = radius * hoverScale
        local glowRadius = nodeRadius + 8 + (selected and pulse * 9 or 0)

        for layer = 3, 1, -1 do
            local alpha = 12 * layer
            drawCircleOutline(
                position.x,
                position.y,
                glowRadius + layer * 5,
                Color(color.r, color.g, color.b, alpha),
                40
            )
        end

        draw.RoundedBox(
            nodeRadius,
            position.x - nodeRadius,
            position.y - nodeRadius,
            nodeRadius * 2,
            nodeRadius * 2,
            color
        )

        drawCircleOutline(
            position.x,
            position.y,
            nodeRadius + 4,
            Color(220, 245, 255, 180),
            36
        )

        if selected then
            drawRotatingRing(
                position.x,
                position.y,
                nodeRadius + 13 + pulse * 3,
                rotation,
                Color(100, 210, 255, 220),
                42
            )
        elseif hovered then
            drawRotatingRing(
                position.x,
                position.y,
                nodeRadius + 10,
                -rotation * 0.65,
                Color(180, 230, 255, 150),
                30
            )
        end

        draw.SimpleText(
            state.name or id,
            "Convergence.UI.Nav",
            position.x,
            position.y + nodeRadius + 14,
            Theme.GetColor("text"),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_TOP
        )
    end



    self.FleetPositions = {}

    for id, fleet in pairs(data.fleets or {}) do
        local origin = self.NodePositions[fleet.currentPlanetID]

        if origin then
            local x = origin.x
            local y = origin.y
            local angle = CurTime() * 0.35 + (#id * 0.33)

            if fleet.status == "traveling" and fleet.destinationPlanetID then
                local destination = self.NodePositions[fleet.destinationPlanetID]

                if destination then
                    local progress = math.Clamp(tonumber(fleet.progress) or 0, 0, 1)
                    local dx = destination.x - origin.x
                    local dy = destination.y - origin.y
                    x = Lerp(progress, origin.x, destination.x)
                    y = Lerp(progress, origin.y, destination.y)
                    angle = math.atan2(dy, dx)

                    local trailLength = 26
                    surface.SetDrawColor(Theme.GetFactionColor(fleet.factionID, data))
                    surface.DrawLine(
                        x,
                        y,
                        x - math.cos(angle) * trailLength,
                        y - math.sin(angle) * trailLength
                    )
                end
            else
                local orbitRadius = 34
                x = origin.x + math.cos(angle) * orbitRadius
                y = origin.y + math.sin(angle) * orbitRadius
            end

            self.FleetPositions[id] = {x = x, y = y}

            local color = Theme.GetFactionColor(fleet.factionID, data)
            local size = math.Clamp(6 + math.sqrt(math.max(tonumber(fleet.strength) or 1, 1)) / 18, 7, 14)

            surface.SetDrawColor(color)
            draw.NoTexture()
            surface.DrawPoly({
                {
                    x = x + math.cos(angle) * size,
                    y = y + math.sin(angle) * size
                },
                {
                    x = x + math.cos(angle + 2.45) * size,
                    y = y + math.sin(angle + 2.45) * size
                },
                {
                    x = x + math.cos(angle + math.pi) * size * 0.5,
                    y = y + math.sin(angle + math.pi) * size * 0.5
                },
                {
                    x = x + math.cos(angle - 2.45) * size,
                    y = y + math.sin(angle - 2.45) * size
                }
            })

            if self.HoveredFleetID == id then
                drawCircleOutline(
                    x,
                    y,
                    size + 7,
                    Color(color.r, color.g, color.b, 220),
                    28
                )

                local faction = (data.factions or {})[fleet.factionID]
                local tooltip = string.format(
                    "%s\n%s | Strength %s\n%s%s",
                    fleet.name,
                    faction and faction.shortName or fleet.factionID,
                    tostring(fleet.strength or 0),
                    string.upper(fleet.status or "unknown"),
                    fleet.orderType and (" | " .. string.upper(fleet.orderType)) or ""
                )

                local lines = string.Explode("\n", tooltip)
                local mouseX, mouseY = self:CursorPos()
                local boxW, boxH = 265, 76
                local boxX = math.Clamp(mouseX + 18, 8, width - boxW - 8)
                local boxY = math.Clamp(mouseY + 18, 8, height - boxH - 8)

                draw.RoundedBox(5, boxX, boxY, boxW, boxH, Color(4, 16, 29, 245))
                surface.SetDrawColor(color)
                surface.DrawOutlinedRect(boxX, boxY, boxW, boxH, 1)

                for lineIndex, line in ipairs(lines) do
                    draw.SimpleText(
                        line,
                        lineIndex == 1 and "Convergence.UI.Nav" or "Convergence.UI.Small",
                        boxX + 12,
                        boxY + 14 + (lineIndex - 1) * 22,
                        lineIndex == 1 and color or Theme.GetColor("textMuted"),
                        TEXT_ALIGN_LEFT,
                        TEXT_ALIGN_CENTER
                    )
                end
            elseif self.Zoom > 0.95 then
                draw.SimpleText(
                    fleet.name,
                    "Convergence.UI.Small",
                    x,
                    y + size + 5,
                    color,
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_TOP
                )
            end
        end
    end


    local taskForce = data.playerTaskForce

    if taskForce
        and tonumber(taskForce.mapX)
        and tonumber(taskForce.mapY) then

        local taskX, taskY = mapToScreen(
            self,
            tonumber(taskForce.mapX),
            tonumber(taskForce.mapY)
        )

        local size = 10 + (math.sin(CurTime() * 4) + 1)

        surface.SetDrawColor(120, 220, 255, 255)
        draw.NoTexture()
        surface.DrawPoly({
            {x = taskX, y = taskY - size},
            {x = taskX + size, y = taskY + size},
            {x = taskX, y = taskY + size * 0.35},
            {x = taskX - size, y = taskY + size}
        })

        drawCircleOutline(
            taskX,
            taskY,
            size + 7,
            Color(100, 215, 255, 210),
            32
        )

        draw.SimpleText(
            taskForce.name or "PLAYER TASK FORCE",
            "Convergence.UI.Small",
            taskX,
            taskY + size + 7,
            Color(120, 220, 255),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_TOP
        )
    end

    drawScanlines(width, height)

    draw.SimpleText(
        string.format("ZOOM %.0f%%", self.Zoom * 100),
        "Convergence.UI.Small",
        12,
        height - 18,
        Theme.GetColor("textMuted"),
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_CENTER
    )

    draw.SimpleText(
        "LEFT DRAG: PAN   MOUSE WHEEL: ZOOM   RIGHT CLICK: RESET",
        "Convergence.UI.Small",
        width - 12,
        height - 18,
        Theme.GetColor("textMuted"),
        TEXT_ALIGN_RIGHT,
        TEXT_ALIGN_CENTER
    )

    if self.HoveredPlanetID and self.HoverAlpha > 2 then
        self:DrawTooltip(self.HoveredPlanetID, width, height, self.HoverAlpha)
    end
end

function PANEL:DrawTooltip(id, width, height, alpha)
    local data = self.Data or {}
    local planetData = (data.planets or {})[id]

    if not planetData then
        return
    end

    local state = planetData.state or {}
    local dominantFaction = (data.factions or {})[
        planetData.dominantFactionID or ""
    ]
    local dominantAlliance = (data.alliances or {})[
        planetData.dominantAllianceID or ""
    ]

    local mouseX, mouseY = self:CursorPos()
    local tooltipWidth = 310
    local influenceCount = table.Count(planetData.influence or {})
    local tooltipHeight = 154 + influenceCount * 22

    local x = mouseX + 18
    local y = mouseY + 18

    if x + tooltipWidth > width - 8 then
        x = mouseX - tooltipWidth - 18
    end

    if y + tooltipHeight > height - 8 then
        y = mouseY - tooltipHeight - 18
    end

    x = math.Clamp(x, 8, math.max(width - tooltipWidth - 8, 8))
    y = math.Clamp(y, 8, math.max(height - tooltipHeight - 8, 8))

    alpha = math.Clamp(alpha, 0, 255)

    draw.RoundedBox(
        6,
        x,
        y,
        tooltipWidth,
        tooltipHeight,
        Color(4, 16, 29, math.floor(alpha * 0.98))
    )

    surface.SetDrawColor(70, 170, 245, alpha)
    surface.DrawOutlinedRect(x, y, tooltipWidth, tooltipHeight, 1)

    local stabilityColor = Theme.GetStabilityColor(state.stability)

    draw.SimpleText(
        string.upper(state.name or id),
        "Convergence.UI.Header",
        x + 14,
        y + 16,
        Color(225, 242, 255, alpha),
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_CENTER
    )

    draw.SimpleText(
        string.format(
            "Stability: %s%% — %s",
            tostring(state.stability or 0),
            tostring(state.stateName or "Unknown")
        ),
        "Convergence.UI.Body",
        x + 14,
        y + 48,
        Color(stabilityColor.r, stabilityColor.g, stabilityColor.b, alpha),
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_CENTER
    )

    draw.SimpleText(
        "Alliance: " .. (
            dominantAlliance and dominantAlliance.name or "Unclaimed"
        ),
        "Convergence.UI.Small",
        x + 14,
        y + 74,
        Color(135, 170, 195, alpha),
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_CENTER
    )

    draw.SimpleText(
        "Faction: " .. (
            dominantFaction and dominantFaction.name or "None"
        ),
        "Convergence.UI.Small",
        x + 14,
        y + 96,
        Color(135, 170, 195, alpha),
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_CENTER
    )

    draw.SimpleText(
        "Influence",
        "Convergence.UI.Nav",
        x + 14,
        y + 122,
        Color(70, 170, 245, alpha),
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_CENTER
    )

    local lineY = y + 146

    for factionID, amount in SortedPairs(planetData.influence or {}) do
        local faction = (data.factions or {})[factionID]
        local factionColor = Theme.GetFactionColor(factionID, data)

        draw.SimpleText(
            string.format(
                "%s: %.2f",
                faction and faction.shortName or factionID,
                tonumber(amount) or 0
            ),
            "Convergence.UI.Small",
            x + 14,
            lineY,
            Color(factionColor.r, factionColor.g, factionColor.b, alpha),
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )

        lineY = lineY + 22
    end
end

vgui.Register("ConvergenceGalaxyRenderer", PANEL, "DPanel")
