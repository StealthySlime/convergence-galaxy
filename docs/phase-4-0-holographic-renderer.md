# Phase 4.0 — Holographic Renderer

This update upgrades the interactive galaxy view into a Republic-style
holographic tactical display.

## Added

- smooth zoom interpolation
- smooth panning interpolation
- drifting grid
- animated scanlines
- shimmering starfield
- animated hyperlane traffic pulses
- layered planet glow
- rotating hover rings
- rotating selected-planet targeting ring
- faded tooltip transitions
- animated node hover scaling

## Controls

```text
Left click planet: Select
Left drag empty space: Pan
Mouse wheel: Smooth zoom
Right click: Smooth reset
```

## Test procedure

1. Open:
   ```text
   convergence_galaxy
   ```
2. Confirm zoom eases rather than snapping.
3. Confirm panning eases smoothly.
4. Select a planet and confirm its targeting ring rotates.
5. Hover a different planet and confirm:
   - node grows slightly
   - hover ring rotates
   - tooltip fades in
   - exact stability percentage remains visible
6. Confirm moving light pulses travel along each hyperlane.
7. Right-click and confirm the camera smoothly resets.
