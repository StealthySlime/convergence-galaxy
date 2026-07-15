# Phase 2.3 — Data-Driven Faction Framework

This update introduces a shared faction registry before planet modifiers and
ownership are implemented.

Initial factions:

- Galactic Republic — player aligned
- Covenant — enemy
- Confederacy of Independent Systems — enemy

## Adding a new faction

Create one shared Lua file under:

```text
addon/convergence_galaxy/lua/convergence/factions/definitions/
```

Example:

```lua
Convergence.Factions.Register({
    id = "banished",
    name = "The Banished",
    shortName = "Banished",
    alignment = "enemy",
    color = Color(150, 40, 30),
    icon = "",
    aliases = {
        "atriox forces"
    },
    tags = {
        "halo",
        "enemy"
    },
    description = "A hostile mercenary empire."
})
```

The loader automatically discovers every `.lua` file in the definitions folder.
No core-file edit is required.

## Supported alignments

```text
player
ally
neutral
enemy
```

## Public API

```lua
Convergence.Factions.Register(definition)
Convergence.Factions.Get(value)
Convergence.Factions.GetAll()
Convergence.Factions.ResolveID(value)
Convergence.Factions.Exists(value)
Convergence.Factions.GetEnemies()
Convergence.Factions.GetPlayerFactions()
Convergence.Factions.GetByAlignment(alignment)
```

## Commands

```text
convergence_factions
convergence_faction_test
```

## Test procedure

1. Replace the addon and restart.
2. Run:
   ```text
   convergence_diagnostics
   ```
3. Confirm:
   - Faction registry `PASS`
   - Registered factions `3`
   - Enemy factions `2`
4. Run:
   ```text
   convergence_factions
   convergence_faction_test
   ```
5. Confirm `6/6 passed`.
