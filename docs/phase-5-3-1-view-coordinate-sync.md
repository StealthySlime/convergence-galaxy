# Phase 5.3.1 — View Separation and Coordinate Synchronization

## Fixed

- The Player Command map no longer displays the Director or GM Tools pages,
  even when the player is an admin.
- Switching from the Director map back to the Player map resets to the Galaxy
  page instead of retaining the Director page.
- SWU planet coordinates now come exclusively from
  `sh_planet_mapping.lua`.
- Arrival is determined from the ship's real SWU position and the nearest
  mapped planet.
- Stale `hyperspace` world states are repaired automatically after missed
  transitions or addon reloads.
- Navigation diagnostics now display the nearest mapped planet and distance.

## Test

Player view:

```text
convergence_galaxy
```

Expected sidebar:

```text
Galaxy
Planets
Factions
Alliances
Fleets
Research
Events
```

Director view:

```text
convergence_director
```

Expected additional pages:

```text
Director
GM Tools
```

Coordinate test:

1. Select Tatooine in SWU.
2. Complete hyperspace.
3. Run:
   ```text
   convergence_navigation_status
   convergence_world_status
   ```
4. `Nearest planet` and `Current planet` should both report Tatooine.
5. Open either map and confirm the player task-force marker is at Tatooine.
