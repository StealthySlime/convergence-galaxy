# Changelog

## Unreleased

### Added

- SQLite database abstraction.
- Ordered migration registry and runner.
- Schema metadata through `convergence_meta`.
- Database transaction helper.
- Database diagnostics command.
- Index for planet stability-history queries.
- Safe migration adoption for existing Phase 1 installations.

### Changed

- Addon version increased to `0.1.1`.
- Database initialization now runs during deterministic bootstrap rather than
  relying on an `Initialize` hook.

## 0.1.0

- Added initial repository scaffold.
- Added deterministic core bootstrap.
- Added structured logging.
- Added module lifecycle support.
- Added configuration validation.
- Added planet registry and stability persistence.
