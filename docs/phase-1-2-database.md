# Phase 1.2 — Database Abstraction and Migrations

This update replaces direct initialization SQL with a database service.

## Added

- SQLite adapter boundary
- consistent success/error return values
- query, row, execute, and transaction helpers
- migration registration and ordered execution
- `convergence_meta` schema metadata
- addon and schema version tracking
- safe adoption of existing Phase 1 data
- indexed stability-history lookup
- diagnostics command

## Existing data safety

Existing Phase 1 installations already contain:

- `convergence_planets`
- `convergence_stability_history`

Migration 1 uses `CREATE TABLE IF NOT EXISTS`. It does not delete or recreate
those tables, so saved stability values and history remain intact.

## Test procedure

1. Replace the addon files and restart the server.
2. Confirm Tatooine remains at the previously saved value.
3. Run:
   ```text
   convergence_diagnostics
   ```
4. Confirm:
   - addon version is `0.1.1`
   - target schema is `1`
   - installed schema is `1`
   - database adapter is `sqlite`
   - database ready is `true`
5. Run:
   ```text
   convergence_stability_add tatooine 1 Migration test
   ```
6. Restart again and confirm the new value persists.
