Convergence.UI = Convergence.UI or {}

local Theme = Convergence.UI.Theme

local PANEL = {}

function PANEL:Init()
    self.Zoom = 1
    self.OffsetX = 0
    self.OffsetY = 0
    self.Dragging = false
    self.LastMouseX = 0
    self.LastMouseY = 0
    self.HoveredPlanetID = nil
    self.SelectedPlanetID = nil
    self.NodePositions = {}
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
        self.Zoom = 1
        self.OffsetX = 0
        self.OffsetY = 0
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
    local oldZoom = self.Zoom
    local newZoom = math.Clamp(oldZoom + delta * 0.1, minimum, maximum)

    if newZoom == oldZoom then
        return true
    end

    local mouseX, mouseY = self:CursorPos()
    local centerX = self:GetWide() / 2 + self.OffsetX
    local centerY = self:GetTall() / 2 + self.OffsetY
    local worldX = (mouseX - centerX) / oldZoom
    local worldY = (mouseY - centerY) / oldZoom

    self.Zoom = newZoom
    self.OffsetX = mouseX - self:GetWide() / 2 - worldX * newZoom
    self.OffsetY = mouseY - self:GetTall() / 2 - worldY * newZoom

    return true
end

function PANEL:Think()
    if self.Dragging then
        local mouseX, mouseY = self:CursorPos()
        self.OffsetX = self.OffsetX + (mouseX - self.LastMouseX)
        self.OffsetY = self.OffsetY + (mouseY - self.LastMouseY)
        self.LastMouseX = mouseX
        self.LastMouseY = mouseY
    end

    local mouseX, mouseY = self:CursorPos()
    self.HoveredPlanetID = nil

    for id, position in pairs(self.NodePositions) do
        local dx = mouseX - position.x
        local dy = mouseY - position.y
        local radius = position.radius + 8

        if dx * dx + dy * dy <= radius * radius then
            self.HoveredPlanetID = id
            break
        end
    end
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
    surface.SetDrawColor(110, 180, 255, 70)

    for index = 1, 90 do
        local x = (index * 157) % math.max(width, 1)
        local y = (index * 263) % math.max(height, 1)
        local size = index % 11 == 0 and 2 or 1
        surface.DrawRect(x, y, size, size)
    end
end

local function drawGrid(panel, width, height)
    surface.SetDrawColor(45, 130, 200, 18)

    local spacing = 64 * panel.Zoom
    if spacing < 24 then
        spacing = 24
    end

    local startX = panel.OffsetX % spacing
    local startY = panel.OffsetY % spacing

    for x = startX, width, spacing do
        surface.DrawLine(x, 0, x, height)
    end

    for y = startY, height, spacing do
        surface.DrawLine(0, y, width, y)
    end
end

function PANEL:Paint(width, height)
    draw.RoundedBox(6, 0, 0, width, height, Color(3, 10, 18, 245))
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

    surface.SetDrawColor(Theme.GetColor("border"))

    for _, route in ipairs(routes) do
        local left = self.NodePositions[route[1]]
        local right = self.NodePositions[route[2]]

        if left and right then
            surface.DrawLine(left.x, left.y, right.x, right.y)
        end
    end

    local pulse = (math.sin(CurTime() * 3) + 1) / 2

    for id, position in pairs(self.NodePositions) do
        local planetData = planets[id] or {}
        local state = planetData.state or {}
        local stability = tonumber(state.stability) or 0
        local color = Theme.GetStabilityColor(stability)
        local hovered = self.HoveredPlanetID == id
        local selected = self.SelectedPlanetID == id

        local radius = position.radius
        local glowRadius = radius + 6 + (selected and pulse * 8 or 0)

        surface.SetDrawColor(color.r, color.g, color.b, selected and 70 or 35)
        draw.NoTexture()
        surface.DrawCircle(position.x, position.y, glowRadius, color.r, color.g, color.b, 60)

        draw.RoundedBox(
            radius,
            position.x - radius,
            position.y - radius,
            radius * 2,
            radius * 2,
            color
        )

        if hovered or selected then
            surface.SetDrawColor(255, 255, 255, 230)
            surface.DrawOutlinedRect(
                position.x - radius - 5,
                position.y - radius - 5,
                radius * 2 + 10,
                radius * 2 + 10,
                1
            )
        end

        draw.SimpleText(
            state.name or id,
            "Convergence.UI.Nav",
            position.x,
            position.y + radius + 12,
            Theme.GetColor("text"),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_TOP
        )
    end

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

    if self.HoveredPlanetID then
        self:DrawTooltip(self.HoveredPlanetID, width, height)
    end
end

function PANEL:DrawTooltip(id, width, height)
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

    draw.RoundedBox(6, x, y, tooltipWidth, tooltipHeight, Color(5, 18, 31, 252))
    surface.SetDrawColor(Theme.GetColor("accent"))
    surface.DrawOutlinedRect(x, y, tooltipWidth, tooltipHeight, 1)

    local stabilityColor = Theme.GetStabilityColor(state.stability)

    draw.SimpleText(
        string.upper(state.name or id),
        "Convergence.UI.Header",
        x + 14,
        y + 16,
        Theme.GetColor("text"),
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
        stabilityColor,
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
        Theme.GetColor("textMuted"),
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
        Theme.GetColor("textMuted"),
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_CENTER
    )

    draw.SimpleText(
        "Influence",
        "Convergence.UI.Nav",
        x + 14,
        y + 122,
        Theme.GetColor("accent"),
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
            factionColor,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )

        lineY = lineY + 22
    end
end

vgui.Register("ConvergenceGalaxyRenderer", PANEL, "DPanel")
