# Phase 4.1 — Persistent Fleets

GMs can create, move, list, and delete persistent fleets.

## Commands

```text
convergence_fleet_create <faction> <planet> <strength> <name>
convergence_fleet_move <fleet_id> <destination> <travel_hours>
convergence_fleet_delete <fleet_id>
convergence_fleets
convergence_fleet_test
```

Example:

```text
convergence_fleet_create republic coruscant 2500 Republic First Fleet
convergence_fleet_move republic_first_fleet tatooine 6
```

Fleet movement uses campaign time. The fleet icon travels between planet nodes
and becomes stationed at its destination when the arrival time is reached.

## Test

1. Restart and run `convergence_diagnostics`.
2. Confirm target and installed schema are `4`.
3. Run `convergence_fleet_test`; expect `7/7 passed`.
4. Create a fleet and refresh the Galactic Command UI.
5. Move it and refresh to see it on the route.
6. Restart to verify persistence.
