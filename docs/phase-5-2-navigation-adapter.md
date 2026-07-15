# Phase 5.2 — Navigation Adapter Cleanup

## Changes

- Added a formal service registry.
- Added a navigation-adapter interface.
- SWU is the authoritative player-navigation system.
- Convergence reads SWU position, destination, and hyperspace state through one
  adapter.
- Removed client-side proxy planets and fake starmap entities.
- Moved SWU navigation names and coordinates into a separate mapping file.
- Restored the known-good galaxy renderer and added the player-task-force
  marker safely.
- Existing world state, GM map transitions, and encounter guards remain.

## Configuration

Edit SWU mappings here:

```text
lua/convergence/integrations/swu/sh_planet_mapping.lua
```

Example:

```lua
tatooine = {
    navigationName = "Tatooine",
    position = Vector(3.2, -1.4, 0)
}
```

## Commands

```text
convergence_navigation_status
convergence_swu_sync
convergence_world_status
convergence_world_test
```

## Test

1. Restart.
2. Run `convergence_diagnostics`.
3. Run `convergence_navigation_status`.
4. Run `convergence_swu_sync`.
5. Open `convergence_galaxy`; the renderer should open without a missing VGUI
   component error.
6. Select a destination in SWU and use its existing hyperspace control.
7. Confirm world status changes to `hyperspace`, then `arrived`.
8. Confirm no automatic GMod map change occurs.
