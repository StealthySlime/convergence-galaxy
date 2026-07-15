# Changelog

## 0.8.2 — Stabilization

### Fixed

- Replaced the malformed UI registry introduced during the view-separation
  update.
- Prevented `RegisterModule` and `GetModule` load failures.
- Made SWU's completed selected destination authoritative on hyperspace exit.
- Prevented local SWU ship coordinates from incorrectly overriding arrival.
- Pinned the player task-force marker to the authoritative planet after
  arrival.
- Kept continuous SWU-coordinate movement while actively in hyperspace.

### Added

- UI registry validation command.
- Expanded SWU/World synchronization diagnostics.
- Stabilization, architecture, and milestone documentation.

### Changed

- Addon version increased to `0.8.2`.

## 0.8.1

- Added Player/Director view separation and coordinate synchronization.
