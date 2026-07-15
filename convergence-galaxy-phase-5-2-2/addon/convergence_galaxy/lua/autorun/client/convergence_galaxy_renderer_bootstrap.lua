Convergence = Convergence or {}
Convergence.UI = Convergence.UI or {}

local function registerRenderer()
    if vgui.GetControlTable("ConvergenceGalaxyRenderer") then
        return
    end

    if not Convergence.UI.Theme then
        include("convergence/ui/cl_theme.lua")
    end

    include("convergence/ui/cl_galaxy_renderer.lua")
end

hook.Add("InitPostEntity", "Convergence.RendererBootstrap", function()
    registerRenderer()
end)

timer.Simple(0, registerRenderer)
