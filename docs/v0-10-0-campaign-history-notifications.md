# Version 0.10.0 — Campaign History and Notifications

## Persistent campaign history

Convergence now records major campaign events in SQLite:

- operations created
- player deployments started
- operations resolved
- fleets departing and arriving
- task-force hyperspace travel and arrival
- encounters starting and ending

History survives restarts and appears in the new Campaign History tab.

## Live notifications

Players receive queued HUD transmissions for:

- new operations
- player deployments
- operation outcomes
- fleet arrivals
- player task-force arrivals

Notifications do not pause the simulation and are configurable in
`Config.Campaign`.

## Tests

```text
convergence_diagnostics
convergence_history_test
convergence_history_status
convergence_notification_test
```

Expected:

```text
Campaign history: PASS
Notifications: PASS
Result: 4/4 passed
```
