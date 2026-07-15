# Phase 2.4 — Alliance and Influence Framework

## Initial alliances

### Galactic Defense Coalition

- Galactic Republic
- UNSC

### Convergence Invaders

- Covenant
- CIS

The two alliances are hostile.

## Adding alliances

Create a shared definition file under:

```text
lua/convergence/alliances/definitions/
```

Example:

```lua
Convergence.Alliances.Register({
    id = "independent_powers",
    name = "Independent Powers",
    shortName = "Independent",
    color = Color(180, 160, 80),
    factions = {
        "pirates",
        "hutts"
    },
    relationships = {
        galactic_defense_coalition = "neutral",
        convergence_invaders = "hostile"
    }
})
```

## Influence

Influence is persistent per planet and per faction.

```text
convergence_influence_set tatooine republic 50
convergence_influence_add tatooine unsc 20
convergence_influence_add tatooine covenant 10
convergence_influence tatooine
```

The framework calculates both the dominant faction and dominant alliance.

## Tests

```text
convergence_diagnostics
convergence_faction_test
convergence_alliance_test
convergence_alliances
```

Expected:

```text
Registered factions: 4
Player factions: 2
Enemy factions: 2
Total alliances: 2
Faction test: 7/7 passed
Alliance test: 7/7 passed
```
