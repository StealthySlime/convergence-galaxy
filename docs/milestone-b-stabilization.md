# Milestone B — Stabilization (Version 0.8.2)

This release adds no new campaign gameplay. It stabilizes the existing
navigation, world-state, and UI layers.

## Navigation authority

SWU remains authoritative for:

- selected destination
- hyperspace start and end
- physical jump presentation
- ship position during travel

Convergence records the SWU-selected destination when hyperspace starts and
sets that same destination as the current planet when hyperspace ends.

`GetShipPos()` remains useful for displaying continuous travel, but it is not
used to override a completed SWU destination because SWU may expose position
in a visual or locally transformed coordinate space.

## Player task-force marker

- While traveling: marker follows normalized SWU coordinates.
- After arrival: marker is pinned to the current planet's strategic-map node.
- The Player and Director maps receive the same authoritative location.

## UI loading order

The loader order is:

```text
Theme
Registry
Components
Renderer
Visibility
Modules
Main Window
```

The module registry supports safe client reloads and validates itself with:

```text
convergence_ui_registry_client
```

## Synchronization test

1. Select Tatooine in SWU.
2. Use the existing SWU hyperspace control.
3. During travel, run:
   ```text
   convergence_navigation_status
   ```
4. After arrival, run it again.
5. Expected:
   ```text
   Resolved target ID:      tatooine
   World current planet:    tatooine
   World destination:       None
   World travel status:     arrived
   Synchronization:         PASS
   ```
6. Open:
   ```text
   convergence_galaxy
   convergence_director
   ```
7. Both maps should place the player task force at Tatooine.
8. The server map must remain unchanged until a GM changes it.
