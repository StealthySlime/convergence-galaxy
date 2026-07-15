Convergence.UI = Convergence.UI or {}

local UI = Convergence.UI
local Theme = UI.Theme

UI.Frame = UI.Frame or nil
UI.ActiveModuleID = UI.ActiveModuleID or "galaxy"
UI.SelectedPlanetID = UI.SelectedPlanetID or nil

local function createNavigation(frame)
    local navigation = vgui.Create("DPanel", frame)
    navigation:Dock(LEFT)
    navigation:SetWide(220)
    navigation:DockPadding(10, 80, 10, 12)

    navigation.Paint = function(self, width, height)
        draw.RoundedBox(0, 0, 0, width, height, Color(5, 16, 27, 252))

        surface.SetDrawColor(Theme.GetColor("border"))
        surface.DrawLine(width - 1, 0, width - 1, height)
    end

    local title = vgui.Create("DLabel", navigation)
    title:SetText("GALACTIC COMMAND")
    title:SetFont("Convergence.UI.Header")
    title:SetTextColor(Theme.GetColor("accent"))
    title:SetPos(14, 20)
    title:SizeToContents()

    local subtitle = vgui.Create("DLabel", navigation)
    subtitle:SetText("CONVERGENCE NETWORK")
    subtitle:SetFont("Convergence.UI.Small")
    subtitle:SetTextColor(Theme.GetColor("textMuted"))
    subtitle:SetPos(14, 50)
    subtitle:SizeToContents()

    UI.Navigation = navigation
    UI.NavigationButtons = {}

    for _, module in ipairs(UI.GetModulesForPlayer(LocalPlayer())) do
        local button = vgui.Create("DButton", navigation)
        button:Dock(TOP)
        button:SetTall(42)
        button:DockMargin(0, 0, 0, 6)
        button:SetText("")

        button.Paint = function(self, width, height)
            Theme.DrawButton(
                self,
                width,
                height,
                module.name,
                UI.ActiveModuleID == module.id
            )
        end

        button.DoClick = function()
            UI.SetActiveModule(module.id)
        end

        UI.NavigationButtons[module.id] = button
    end

    local version = vgui.Create("DLabel", navigation)
    version:Dock(BOTTOM)
    version:SetTall(24)
    version:SetFont("Convergence.UI.Small")
    version:SetTextColor(Theme.GetColor("textMuted"))
    version:SetText("Framework " .. tostring(Convergence.Version))
    version:SetContentAlignment(5)

    return navigation
end

local function createHeader(frame)
    local header = vgui.Create("DPanel", frame)
    header:Dock(TOP)
    header:SetTall(62)
    header:DockPadding(18, 0, 14, 0)

    header.Paint = function(self, width, height)
        draw.RoundedBox(0, 0, 0, width, height, Color(7, 19, 31, 250))
        surface.SetDrawColor(Theme.GetColor("border"))
        surface.DrawLine(0, height - 1, width, height - 1)
    end

    local moduleTitle = vgui.Create("DLabel", header)
    moduleTitle:Dock(LEFT)
    moduleTitle:SetWide(430)
    moduleTitle:SetFont("Convergence.UI.Title")
    moduleTitle:SetTextColor(Theme.GetColor("text"))
    moduleTitle:SetText("GALAXY")

    local refresh = vgui.Create("DButton", header)
    refresh:Dock(RIGHT)
    refresh:SetWide(120)
    refresh:DockMargin(8, 12, 0, 12)
    refresh:SetText("REFRESH")
    refresh:SetFont("Convergence.UI.Nav")
    refresh:SetTextColor(Theme.GetColor("text"))

    refresh.Paint = function(self, width, height)
        Theme.DrawButton(self, width, height, "REFRESH", false)
    end

    refresh.DoClick = function()
        Convergence.RequestGalaxySnapshot()
    end

    local close = vgui.Create("DButton", header)
    close:Dock(RIGHT)
    close:SetWide(90)
    close:DockMargin(8, 12, 0, 12)
    close:SetText("CLOSE")
    close:SetFont("Convergence.UI.Nav")
    close:SetTextColor(Theme.GetColor("text"))

    close.Paint = function(self, width, height)
        Theme.DrawButton(self, width, height, "CLOSE", false)
    end

    close.DoClick = function()
        if IsValid(UI.Frame) then
            UI.Frame:Close()
        end
    end

    UI.ModuleTitle = moduleTitle

    return header
end

function UI.SetActiveModule(id)
    local module = UI.GetModule(id)

    if not module then
        return false
    end

    if module.adminOnly and not LocalPlayer():IsAdmin() then
        return false
    end

    UI.ActiveModuleID = module.id

    if IsValid(UI.ModuleTitle) then
        UI.ModuleTitle:SetText(string.upper(module.name))
    end

    UI.RefreshActiveModule()

    return true
end

function UI.RefreshActiveModule()
    if not IsValid(UI.Content) then
        return
    end

    UI.Content:Clear()

    local module = UI.GetModule(UI.ActiveModuleID)

    if not module then
        return
    end

    local ok, result = xpcall(function()
        return module:create(UI.Content)
    end, debug.traceback)

    if not ok then
        Convergence.UI.Components.CreateEmptyState(
            UI.Content,
            "Module Error",
            tostring(result)
        )
    end
end

function UI.Refresh()
    if not IsValid(UI.Frame) then
        return
    end

    UI.RefreshActiveModule()
end

function UI.Open()
    if IsValid(UI.Frame) then
        UI.Frame:MakePopup()
        UI.Frame:SetVisible(true)
        Convergence.RequestGalaxySnapshot()
        return
    end

    local frame = vgui.Create("DFrame")
    frame:SetSize(ScrW(), ScrH())
    frame:SetPos(0, 0)
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:MakePopup()

    frame.Paint = function(self, width, height)
        draw.RoundedBox(0, 0, 0, width, height, Theme.GetColor("background"))

        surface.SetDrawColor(Color(45, 130, 200, 10))

        for x = 0, width, 48 do
            surface.DrawLine(x, 0, x, height)
        end

        for y = 0, height, 48 do
            surface.DrawLine(0, y, width, y)
        end
    end

    UI.Frame = frame

    createNavigation(frame)

    local right = vgui.Create("DPanel", frame)
    right:Dock(FILL)
    right.Paint = nil

    createHeader(right)

    local content = vgui.Create("DPanel", right)
    content:Dock(FILL)
    content.Paint = nil

    UI.Content = content

    UI.SetActiveModule(UI.ActiveModuleID)
    Convergence.RequestGalaxySnapshot()
end

concommand.Add("convergence_ui_client", function()
    UI.Open()
end)

hook.Add("OnScreenSizeChanged", "Convergence.UI.Resize", function()
    if IsValid(UI.Frame) then
        UI.Frame:SetSize(ScrW(), ScrH())
        UI.Frame:SetPos(0, 0)
    end
end)
