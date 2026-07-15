# Changelog

## 0.9.11 — SWU Navigation Reset

### Fixed

- Completed Reach jumps leaving Reach selected permanently.
- Navigation consoles refusing to select another planet after hyperspace exit.
- External hyperspace speed modifier carrying into the next route.
- Completed-jump loading, target, progress, and estimate state remaining set.

### Added

- Automatic navigation-computer reset after every arrival.
- Admin recovery command `convergence_swu_reset_navigation`.

### Changed

- Addon version increased to `0.9.11`.

## 0.9.10 — SWU Arrival and Registry Fix

### Fixed

- Numeric `1`, `2`, and `3` planet IDs caused by iterating the planet array as
  an ID-keyed table.
- Reach using an impractically large SWU coordinate.
- Client Ship Position/GOTO lists not receiving Convergence planets.
- SWU builds remaining in hyperspace after the practical timer elapsed.
- SWU physical position not being reconciled to the selected planet on arrival.

### Added

- Client command `convergence_swu_client_sync`.
- Emergency admin command `convergence_swu_force_arrival`.
- Hyperspace-exit compatibility fallback.

### Changed

- Addon version increased to `0.9.10`.

## 0.9.9 — Deployment Map and SWU Planet Registration

### Added

- Deployment map-selection dialog.
- Server-validated deployment region selection.
- Selected map and region stored in the deployment snapshot.
- Automatic region preparation when deployment starts.
- Synchronization into discoverable SWU planet registries.
- Automatic mapping generation for future configured planets.
- `convergence_swu_planet_status` diagnostics.

### Fixed

- Configured planets such as Reach not appearing in SWU Ship Position/GOTO.
- Deploy Players starting without choosing the destination event map.

### Changed

- Addon version increased to `0.9.9`.

## 0.9.8 — Location-Gated Deployments

### Added

- Server-side planet validation for player deployments.
- Server-side planet validation for operation-region preparation.
- Disabled Prepare Region and Deploy Players controls when the task force is
  not at the operation planet.
- Location-specific tooltips explaining why controls are unavailable.

### Changed

- Prepare Region now sends an operation ID and resolves its region securely on
  the server.
- Addon version increased to `0.9.8`.

## 0.9.7 — Operation Workflow

### Added

- Clickable planet-operation entries.
- Planet-filtered Operations page navigation.
- Priority-colored operation cards.
- Prepare Region and Deploy Players controls on selected operations.
- Resolved-operation filters.
- Resolution date and time.
- Faction-colored influence effects in the archive.

### Changed

- Addon version increased to `0.9.7`.

## 0.9.6

- Added operation badges, planet operation listings, and resolved archive.
