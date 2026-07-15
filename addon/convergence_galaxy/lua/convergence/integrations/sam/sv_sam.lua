Convergence.SAM = Convergence.SAM or {}

local Integration = Convergence.SAM
Integration.Registered = false

local function openDirector(ply)
    if not Convergence.Permissions.CanOpenDirector(ply) then
        if IsValid(ply) then
            ply:ChatPrint("[Convergence] Galactic Director access denied.")
        end
        return
    end

    Convergence.OpenGalaxyUI(ply, "director")
end

local function openOperations(ply)
    if not Convergence.Permissions.CanOpenDirector(ply) then
        return
    end

    Convergence.OpenGalaxyUI(ply, "director")

    timer.Simple(0.5, function()
        if IsValid(ply) then
            ply:ConCommand("convergence_ui_open_module operations")
        end
    end)
end

local function registerPermission(id, title)
    if not sam or not sam.permissions or not isfunction(sam.permissions.add) then
        return
    end

    pcall(sam.permissions.add, id, title, "superadmin")
end

local function registerCommand(name, permission, helpText, callback)
    if not sam or not sam.command or not isfunction(sam.command.new) then
        return false
    end

    local ok, command = pcall(sam.command.new, name)

    if not ok or not command then
        return false
    end

    if isfunction(command.SetPermission) then
        command:SetPermission(permission, "superadmin")
    end

    if isfunction(command.Help) then
        command:Help(helpText)
    end

    if isfunction(command.OnExecute) then
        command:OnExecute(function(ply)
            callback(ply)
        end)
    end

    if isfunction(command.End) then
        command:End()
    end

    return true
end

function Integration.Register()
    if Integration.Registered then
        return true
    end

    if not sam then
        print("[Convergence Galaxy] SAM not detected; console commands remain available.")
        return false
    end

    registerPermission(
        Convergence.Permissions.Director,
        "Open the Convergence Galactic Director"
    )
    registerPermission(
        Convergence.Permissions.Campaign,
        "Manage Convergence campaign operations"
    )

    local directorRegistered = registerCommand(
        "convergence",
        Convergence.Permissions.Director,
        "Open the Convergence Galactic Director.",
        openDirector
    )

    registerCommand(
        "galaxydirector",
        Convergence.Permissions.Director,
        "Open the Convergence Galactic Director.",
        openDirector
    )

    registerCommand(
        "convergenceoperations",
        Convergence.Permissions.Director,
        "Open the Convergence Director for campaign operations.",
        openOperations
    )

    Integration.Registered = directorRegistered

    print(
        Integration.Registered
            and "[Convergence Galaxy] SAM commands registered: !convergence, !galaxydirector, !convergenceoperations"
            or "[Convergence Galaxy] SAM detected, but its command API was not compatible. Console commands remain available."
    )

    return Integration.Registered
end

hook.Add("InitPostEntity", "Convergence.SAMIntegration", function()
    timer.Simple(1, Integration.Register)
end)

hook.Add("SAM.Loaded", "Convergence.SAMIntegrationLoaded", function()
    timer.Simple(0, Integration.Register)
end)
