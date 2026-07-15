# Version 0.12.0 — Core Service Lifecycle

This release registers and validates the older Convergence subsystems through
the same service registry used by newer campaign systems.

Registered core services:

```text
planets
factions
influence
stability
fleets
fleet_orders
simulation
clock
alliances
```

The lifecycle runs after database-backed services initialize and before
Campaign History, Galactic News, and Strategic Intelligence begin.

Intelligence now refuses to initialize until the required core lifecycle is
ready, preventing empty assessments and startup race conditions.

## Commands

```text
convergence_lifecycle_status
convergence_lifecycle_test
convergence_lifecycle_repair
convergence_service_status
convergence_living_galaxy_test
```

Expected:

```text
Overall: PASS
Living Galaxy Test: 5/5 passed
Highest Threat: <planet>
```
