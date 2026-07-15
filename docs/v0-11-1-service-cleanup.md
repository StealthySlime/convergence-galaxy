# Version 0.11.1 — Service Cleanup and Intelligence Polish

## Central service facade

Subsystems may now resolve registered services through:

```lua
Convergence.ServiceFacade.Planets
Convergence.ServiceFacade.Fleets
Convergence.ServiceFacade.Operations
Convergence.ServiceFacade.Deployments
Convergence.ServiceFacade.Intelligence
Convergence.ServiceFacade.History
Convergence.ServiceFacade.News
Convergence.ServiceFacade.Notifications
```

## Faction classification

The faction registry now exposes friendly, enemy, and neutral classification
helpers plus influence aggregation. Republic and UNSC default to friendly;
Covenant and CIS default to enemy. Future factions may set common alignment
fields instead of requiring intelligence code changes.

## Intelligence

- Fixed the missing `GetEnemyIDs` runtime error.
- Added fleet-strength contribution to threat scoring.
- Added a five-second intelligence cache.
- Added Highest Threat to the Director dashboard.

## Tests

```text
convergence_diagnostics
convergence_living_galaxy_test
convergence_intelligence_status
convergence_service_status
```
