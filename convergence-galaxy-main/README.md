# Convergence Galaxy

A persistent galactic campaign framework for Garry's Mod.

## Current milestone

**v0.1.0 — Persistent Galaxy Core**

This initial scaffold provides:

- Shared addon namespace and loader
- Modular server/client/shared file loading
- Planet registry
- SQLite persistence
- Stability state storage
- Stability transaction logging
- Basic networking
- Console commands for testing
- SAM and Star Wars Universe integration placeholders

## Installation

Copy the `addon/convergence_galaxy` folder into:

```text
garrysmod/addons/
```

The addon will create its SQLite tables automatically in the server's `garrysmod/data/` database.

## Dependencies

Optional integrations:

- SAM Admin Mod
- Star Wars Universe: Interactive Star Map (Workshop ID `2735358488`)

Neither dependency is bundled in this repository.

## Development

The entry point is:

```text
addon/convergence_galaxy/lua/autorun/convergence_init.lua
```

Core modules are located under:

```text
addon/convergence_galaxy/lua/convergence/
```

## License

All original Convergence Galaxy code is currently reserved for private development.
Third-party addons and assets are not included.
