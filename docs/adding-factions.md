# Adding Factions

Faction definitions are simple shared Lua files.

## Location

```text
addon/convergence_galaxy/lua/convergence/factions/definitions/
```

Use a filename beginning with `sh_`, for example:

```text
sh_banished.lua
```

## Minimal definition

```lua
Convergence.Factions.Register({
    id = "banished",
    name = "The Banished",
    alignment = "enemy"
})
```

## Full definition

```lua
Convergence.Factions.Register({
    id = "banished",
    name = "The Banished",
    shortName = "Banished",
    alignment = "enemy",
    color = Color(150, 40, 30),
    icon = "materials/convergence/factions/banished.png",
    aliases = {
        "atriox forces"
    },
    tags = {
        "halo",
        "enemy",
        "mercenary"
    },
    description = "A hostile mercenary empire.",
    metadata = {
        universe = "halo"
    }
})
```

## Rules

- `id` must remain permanent once persistent campaign data references it.
- IDs are lowercase and normalized automatically.
- Display names may be changed safely.
- Aliases allow commands and integrations to resolve alternate names.
- Do not place faction behavior directly in definition files.
- Future AI, ownership, fleets, and modifiers should reference the stable ID.
