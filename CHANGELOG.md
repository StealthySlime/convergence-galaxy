# Changelog

## Unreleased

### Fixed

- Director-only pages leaking into the Player Command map for admins.
- Player view retaining the Director page after switching modes.
- SWU and Convergence using different coordinate sources.
- Arrival resolving from a stale destination instead of the ship's actual
  universe position.
- Persistent world state remaining stuck in hyperspace after a missed state
  transition.

### Changed

- Addon version increased to `0.8.1`.
- `sh_planet_mapping.lua` is now the sole source of SWU universe coordinates.

## 0.8.0

- Added separate Player Command and GM Director maps.
