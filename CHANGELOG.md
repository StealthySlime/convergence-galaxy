# Changelog

## Unreleased

### Added

- Persistent Galaxy Clock.
- Campaign day, hour, minute, and tick tracking.
- Pause, resume, time-scale, set-time, and advance-time controls.
- Periodic clock persistence and restart recovery.
- `clock.ready`, `clock.started`, `clock.stopped`, `clock.tick`,
  `clock.paused.changed`, `clock.scale.changed`, `clock.time.changed`, and
  `clock.time.advanced` events.
- Galaxy Clock diagnostics and automated test command.
- Schema migration 2 for `convergence_clock`.

### Changed

- Addon version increased to `0.2.0`.
- Database schema increased to version `2`.

## 0.1.4

- Added framework Event Bus.

## 0.1.3

- Added cached Planet Service and planet object API.

## 0.1.2

- Fixed database initialization and added stage diagnostics.

## 0.1.1

- Added SQLite abstraction and migrations.

## 0.1.0

- Added initial persistent galaxy scaffold.
