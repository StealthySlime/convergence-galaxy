# Changelog

## Unreleased

### Added

- Cached server-side Planet Service.
- Planet object API with stability, state, lock, update time, and revision getters.
- Planet resolution by ID, display name, and aliases.
- Planet cache reload and update hooks.
- Network revision tracking for planet state.
- Planet Service diagnostic and test commands.

### Changed

- Addon version increased to `0.1.3`.
- Stability service now uses the Planet Service cache instead of querying SQLite.
- Planet console output now uses Planet objects.
- Client planet updates reject older revisions.

## 0.1.2

- Fixed database initialization.
- Added stage-specific database diagnostics.

## 0.1.1

- Added SQLite abstraction and migrations.

## 0.1.0

- Added initial persistent galaxy scaffold.
