Convergence = Convergence or {}

Convergence.Name = "Convergence Galaxy"
Convergence.Version = "0.8.2"
Convergence.SchemaVersion = 6
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

local function addSharedDirectory(path)
    local files = file.Find(path .. "*.lua", "LUA")
    table.sort(files)

    for _, fileName in ipairs(files) do
        addShared(path .. fileName)
    end
end

local function addClientDirectory(path)
    local files = file.Find(path .. "*.lua", "LUA")
    table.sort(files)

    for _, fileName in ipairs(files) do
        addClient(path .. fileName)
    end
end

addShared(ROOT .. "core/sh_constants.lua")
addShared(ROOT .. "core/sh_util.lua")
addShared(ROOT .. "core/sh_log.lua")
addShared(ROOT .. "core/sh_modules.lua")
addShared(ROOT .. "core/sh_services.lua")
addShared(ROOT .. "navigation/sh_navigation.lua")
addShared(ROOT .. "core/sh_events.lua")
addShared(ROOT .. "core/sh_config.lua")
addShared(ROOT .. "core/sh_planets.lua")

addShared(ROOT .. "factions/sh_factions.lua")
addSharedDirectory(ROOT .. "factions/definitions/")

addShared(ROOT .. "alliances/sh_alliances.lua")
addSharedDirectory(ROOT .. "alliances/definitions/")

addServer(ROOT .. "database/sv_database.lua")
addServer(ROOT .. "database/sv_migrations.lua")

addServer(ROOT .. "simulation/sv_engine.lua")
addServer(ROOT .. "simulation/sv_clock.lua")
addServer(ROOT .. "simulation/processors/sv_planet_processor.lua")
addServer(ROOT .. "simulation/processors/sv_fleet_processor.lua")
addServer(ROOT .. "simulation/processors/sv_fleet_order_processor.lua")

addServer(ROOT .. "alliances/sv_influence.lua")
addServer(ROOT .. "planets/sv_planet_service.lua")
addServer(ROOT .. "stability/sv_stability.lua")
addServer(ROOT .. "world/sv_world.lua")
addServer(ROOT .. "fleets/sv_fleets.lua")
addServer(ROOT .. "fleets/sv_orders.lua")

addServer(ROOT .. "network/sv_network.lua")
addServer(ROOT .. "network/sv_galaxy_snapshot.lua")
addShared(ROOT .. "integrations/swu/sh_planet_mapping.lua")
addServer(ROOT .. "integrations/swu/sv_navigation_adapter.lua")
addClient(ROOT .. "network/cl_network.lua")
addClient(ROOT .. "network/cl_galaxy_snapshot.lua")
addClient(ROOT .. "integrations/swu/cl_navigation_adapter.lua")

addServer(ROOT .. "commands/sv_commands.lua")
addServer(ROOT .. "commands/sv_diagnostics.lua")
addServer(ROOT .. "commands/sv_planet_tests.lua")
addServer(ROOT .. "commands/sv_event_tests.lua")
addServer(ROOT .. "commands/sv_clock_commands.lua")
addServer(ROOT .. "commands/sv_simulation_commands.lua")
addServer(ROOT .. "commands/sv_faction_commands.lua")
addServer(ROOT .. "commands/sv_alliance_commands.lua")
addServer(ROOT .. "commands/sv_fleet_commands.lua")
addServer(ROOT .. "commands/sv_fleet_order_commands.lua")
addServer(ROOT .. "commands/sv_world_commands.lua")
addServer(ROOT .. "commands/sv_navigation_commands.lua")
addServer(ROOT .. "commands/sv_ui_commands.lua")
addServer(ROOT .. "commands/sv_director_commands.lua")

addClient(ROOT .. "ui/cl_theme.lua")
addClient(ROOT .. "ui/cl_registry.lua")
addClient(ROOT .. "ui/cl_components.lua")
addClient(ROOT .. "ui/cl_galaxy_renderer.lua")
addClient(ROOT .. "ui/cl_visibility.lua")
addClientDirectory(ROOT .. "ui/modules/")
addClient(ROOT .. "ui/cl_main.lua")

addServer(ROOT .. "integrations/sam/sv_sam.lua")
addServer(ROOT .. "integrations/swu/sv_swu.lua")
addClient(ROOT .. "integrations/swu/cl_swu.lua")

local valid, errors = Convergence.ValidateConfig()

if not valid then
    for _, message in ipairs(errors) do
        Convergence.Log.Error("Config", message)
    end
end

if SERVER then
    local ready, errorCode, errorMessage = Convergence.Database.Initialize()

    if not ready then
        Convergence.Log.Error("Database", "Database initialization failed.", {
            code = errorCode,
            error = errorMessage
        })
    else
        local planetsReady, planetCode, planetMessage =
            Convergence.PlanetService.Initialize()

        if not planetsReady then
            Convergence.Log.Error("Planets", "Planet service initialization failed.", {
                code = planetCode,
                error = planetMessage
            })
        end

        local influenceReady, influenceCode, influenceMessage =
            Convergence.Influence.Initialize()

        if not influenceReady then
            Convergence.Log.Error("Influence", "Influence service initialization failed.", {
                code = influenceCode,
                error = influenceMessage
            })
        end

        local fleetsReady, fleetCode, fleetMessage =
            Convergence.Fleets.Initialize()

        if not fleetsReady then
            Convergence.Log.Error("Fleets", "Fleet service initialization failed.", {
                code = fleetCode,
                error = fleetMessage
            })
        end

        local worldReady, worldCode, worldMessage =
            Convergence.World.Initialize()

        if not worldReady then
            Convergence.Log.Error("World", "World service initialization failed.", {
                code = worldCode,
                error = worldMessage
            })
        end

        local simulationReady, simulationCode, simulationMessage =
            Convergence.Simulation.Initialize()

        if not simulationReady then
            Convergence.Log.Error("Simulation", "Simulation Engine initialization failed.", {
                code = simulationCode,
                error = simulationMessage
            })
        end

        local clockReady, clockCode, clockMessage =
            Convergence.Clock.Initialize()

        if not clockReady then
            Convergence.Log.Error("Clock", "Galaxy Clock initialization failed.", {
                code = clockCode,
                error = clockMessage
            })
        end
    end
end

Convergence.Modules.InitializeAll()

Convergence.Events.Publish("core.loaded", {
    version = Convergence.Version,
    realm = SERVER and "server" or "client"
})

hook.Run("ConvergenceLoaded", Convergence.Version)

Convergence.Log.Info("Core", string.format(
    "%s %s loaded in the %s realm.",
    Convergence.Name,
    Convergence.Version,
    SERVER and "server" or "client"
))
