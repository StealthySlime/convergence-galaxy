# Changelog

## Unreleased

### Added

- Framework Event Bus.
- Priority-based and one-time event subscriptions.
- Owner-based subscription cleanup.
- Protected subscriber execution and error isolation.
- Bounded recent-event history and counters.
- `core.loaded`, `planet.stability.changed`, and
  `planet.stability.lock.changed` events.
- Event Bus status and automated test commands.

### Changed

- Addon version increased to `0.1.4`.
- Stability changes now publish structured framework events.

## 0.1.3

- Added cached Planet Service and planet object API.

## 0.1.2

- Fixed database initialization and added stage diagnostics.

## 0.1.1

- Added SQLite abstraction and migrations.

## 0.1.0

- Added initial persistent galaxy scaffold.
