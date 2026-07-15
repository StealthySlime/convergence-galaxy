Convergence = Convergence or {}
Convergence.Version = "0.1.0"
Convergence.Name = "Convergence Galaxy"

local root = "convergence/"

local function includeShared(path)
    if SERVER then
        AddCSLuaFile(path)
    end

    include(path)
end

local function includeServer(path)
    if SERVER then
        include(path)
    end
end

local function includeClient(path)
    if SERVER then
        AddCSLuaFile(path)
    else
        include(path)
    end
end

includeShared(root .. "core/sh_config.lua")
includeShared(root .. "core/sh_util.lua")
includeShared(root .. "core/sh_planets.lua")

includeServer(root .. "database/sv_database.lua")
includeServer(root .. "stability/sv_stability.lua")
includeServer(root .. "network/sv_network.lua")
includeServer(root .. "commands/sv_commands.lua")
includeServer(root .. "integrations/sam/sv_sam.lua")
includeServer(root .. "integrations/swu/sv_swu.lua")

includeClient(root .. "network/cl_network.lua")
includeClient(root .. "ui/cl_planet_status.lua")
includeClient(root .. "integrations/swu/cl_swu.lua")

hook.Run("ConvergenceLoaded", Convergence.Version)

print(string.format("[%s] Loaded version %s", Convergence.Name, Convergence.Version))
