Convergence = Convergence or {}

Convergence.Name = "Convergence Galaxy"
Convergence.Version = "0.1.0"
Convergence.SchemaVersion = 1
Convergence.Root = "convergence/"

local ROOT = Convergence.Root

local function addShared(path)
    if SERVER then
        AddCSLuaFile(path)
    end

    include(path)
end

local function addServer(path)
    if SERVER then
        include(path)
    end
end

local function addClient(path)
    if SERVER then
        AddCSLuaFile(path)
        return
    end

    include(path)
end

-- Core bootstrap
addShared(ROOT .. "core/sh_constants.lua")
addShared(ROOT .. "core/sh_util.lua")
addShared(ROOT .. "core/sh_log.lua")
addShared(ROOT .. "core/sh_modules.lua")
addShared(ROOT .. "core/sh_config.lua")
addShared(ROOT .. "core/sh_planets.lua")

-- Persistent services
addServer(ROOT .. "database/sv_database.lua")
addServer(ROOT .. "stability/sv_stability.lua")
addServer(ROOT .. "network/sv_network.lua")
addServer(ROOT .. "commands/sv_commands.lua")

-- Optional integrations
addServer(ROOT .. "integrations/sam/sv_sam.lua")
addServer(ROOT .. "integrations/swu/sv_swu.lua")

-- Client services
addClient(ROOT .. "network/cl_network.lua")
addClient(ROOT .. "ui/cl_planet_status.lua")
addClient(ROOT .. "integrations/swu/cl_swu.lua")

local valid, errors = Convergence.ValidateConfig()

if not valid then
    for _, message in ipairs(errors) do
        Convergence.Log.Error("Config", message)
    end
end

Convergence.Modules.InitializeAll()

hook.Run("ConvergenceLoaded", Convergence.Version)
Convergence.Log.Info("Core", string.format(
    "%s %s loaded in the %s realm.",
    Convergence.Name,
    Convergence.Version,
    SERVER and "server" or "client"
))
