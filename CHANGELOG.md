# Changelog

## Unreleased

### Fixed

- Database initialization no longer treats a stale `sql.LastError()` from an
  unrelated addon as a failed Convergence query.
- Database readiness and schema metadata now complete correctly.
- Migration transactions now use Garry's Mod's SQLite transaction helpers.

### Added

- Explicit connection, metadata, migration, and planet-bootstrap status stages.
- Detailed database diagnostics with PASS/FAIL reporting.

### Changed

- Addon version increased to `0.1.2`.

## 0.1.1

- Added SQLite database abstraction.
- Added ordered migration registry and runner.
- Added schema metadata through `convergence_meta`.
- Added diagnostics command.

## 0.1.0

- Added initial persistent galaxy scaffold.
