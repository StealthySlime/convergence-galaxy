# Phase 1 — Persistent Core

Phase 1 establishes the stable framework that all later campaign systems use.

## Completed in this package

### Core bootstrap

- canonical namespace and version constants
- deterministic realm-aware loader
- shared constants and error codes
- structured logging service
- module registry and lifecycle
- configuration validation
- graceful module shutdown

### Existing scaffold retained

- planet registry
- SQLite persistence
- stability storage
- stability history
- basic networking
- developer console commands
- SAM and SWU placeholders

## Test procedure

1. Copy `addon/convergence_galaxy` into `garrysmod/addons/`.
2. Start a development server.
3. Confirm the console contains:
   - `Convergence Galaxy 0.1.0 loaded`
   - module initialization messages
4. Run:
   ```text
   convergence_planets
   ```
5. Restart the server and confirm planet stability persists.
6. Test:
   ```text
   convergence_stability_set tatooine 50 Phase 1 test
   convergence_stability_add tatooine 5 Recovery test
   ```
7. Confirm there are no Lua errors on shutdown.

## Next Phase 1 work

- replace direct SQLite calls with a database adapter
- add ordered database migrations
- add schema metadata
- register core services as modules
- add permission provider abstraction
- add diagnostics command
