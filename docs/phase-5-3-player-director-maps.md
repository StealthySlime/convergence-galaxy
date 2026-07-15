# Phase 5.3 — Player Command and GM Director Maps

The project now provides two interfaces backed by one renderer and one galaxy
snapshot system.

## Player map

Open with:

```text
convergence_galaxy
```

The player map includes:

- known planets
- the player task force
- Republic and UNSC fleets
- public enemy contacts
- public stability, alliance, and influence information

It does not include hidden enemy fleets, enemy orders, region map names, or
internal world-management data.

## GM map

Open with:

```text
convergence_director
```

Admins receive:

- every registered fleet
- enemy faction identity and strength
- active fleet orders and targets
- planet regions and map associations
- current encounter and NPC-spawn state
- navigation-adapter state
- campaign counts and GM workflow guidance

## Visibility model

Fleet visibility currently supports:

```text
full
contact
hidden
```

Friendly Republic and UNSC fleets are fully visible to players. Enemy fleets
are hidden unless their metadata marks them as `public` or `contact`.
Directors always receive full information.

This is the foundation for future sensors, reconnaissance, and fog of war.
