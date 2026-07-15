# Convergence Architecture

## Authority chain

```text
SWU Navigation
    ↓
Navigation Adapter
    ↓
World Service
    ↓
Persistent Database
    ↓
Galaxy Snapshot
    ↓
Player Command / GM Director
```

SWU owns physical navigation. Convergence owns persistent campaign state.
Only a GM may change the active GMod map or activate an encounter.

## Runtime layers

### Strategic layer

Always running:

- planets
- factions
- alliances
- influence
- stability
- fleets
- orders
- galaxy clock

### World layer

Tracks:

- player task-force current planet
- selected destination
- hyperspace status
- current GMod map
- active region

### Encounter layer

Controls:

- whether NPC spawning is allowed
- live RP battle state
- later campaign-event resolution

NPC spawning is not permitted on protected command maps.
