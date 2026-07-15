# Phase 3.2 — Interactive Galaxy Renderer

## Added

- interactive star-map renderer
- mouse-wheel zoom
- left-drag panning
- right-click reset
- reusable planet nodes
- route lines
- stability-colored nodes
- selected-node pulse
- exact stability percentage on hover
- hover state, dominant alliance, dominant faction, and influence
- tooltip screen-boundary protection
- data-driven planet positions and sectors

## Current controls

```text
Left click planet: Select
Left drag empty space: Pan
Mouse wheel: Zoom
Right click: Reset view
```

## Planet coordinates

Planet definitions may include:

```lua
galaxy = {
    x = 0.24,
    y = 0.58,
    sector = "Core Worlds"
}
```

Coordinates are normalized from `0` to `1`.

## Test

1. Open:
   ```text
   convergence_galaxy
   ```
2. Confirm the list is replaced by the map.
3. Hover every planet and confirm the exact stability percentage appears.
4. Confirm the tooltip remains inside the map near every edge.
5. Zoom with the mouse wheel.
6. Pan by dragging empty space.
7. Click a planet and confirm the right inspector changes.
8. Right-click empty space and confirm the view resets.
