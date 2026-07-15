# Phase 5.1 — World and SWU Starmap Integration

This phase separates strategic simulation, the current GMod world, and
GM-controlled encounters.

## Rules implemented

- Convergence never changes maps automatically.
- The existing SWU hyperspace lever remains the in-game jump control.
- The player task force always appears on the Convergence galaxy map.
- SWU ship position is synchronized into persistent Convergence world state.
- Convergence planets are added to the SWU navigation-computer list.
- Client-side proxy planets add Convergence worlds to the SWU physical starmap.
- Arrival does not change the server map.
- Only a superadmin/GM command may prepare or perform a map transition.
- NPC spawning is blocked until a GM activates an encounter.

## GM commands

```text
convergence_world_status
convergence_world_regions
convergence_world_prepare <region>
convergence_world_change_map <region>
convergence_encounter_start
convergence_encounter_end
convergence_swu_sync
convergence_world_test
```

## Travel flow

1. Select a Convergence planet using the SWU navigation computer.
2. Pull the existing SWU hyperspace lever.
3. Convergence records the player task force as traveling.
4. The task-force marker follows the SWU ship position.
5. SWU exits hyperspace near the selected destination.
6. Convergence records arrival and remains on the current GMod map.
7. A GM reviews available regions with `convergence_world_regions`.
8. The GM changes maps only when ready.
9. The GM runs `convergence_encounter_start` on an encounter map before NPCs
   may be spawned.

## Planet configuration

```lua
swu = {
    name = "Tatooine",
    pos = Vector(3.2, -1.4, 0)
},
regions = {
    {id = "orbit", name = "Tatooine Orbit", map = "rp_venator"},
    {id = "mos_eisley", name = "Mos Eisley", map = "rp_tatooine"}
}
```

Replace the example map names and SWU coordinates with the maps and positions
used by the server.
