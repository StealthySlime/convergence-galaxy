# Phase 1.4 — Event Bus

This update introduces a framework-level event bus for decoupled communication
between campaign services.

## Added

- named event publication
- persistent subscription tokens
- priority ordering
- one-time subscriptions
- owner-based cleanup
- protected callbacks with error isolation
- bounded recent-event history
- publication and error counters
- stability and lock events
- diagnostic and automated test commands

## Public API

```lua
local success, token = Convergence.Events.Subscribe(
    "planet.stability.changed",
    function(event)
        print(event.payload.planetID)
    end,
    {
        owner = "example_module",
        priority = 10
    }
)

Convergence.Events.Publish("example.event", {
    value = 1
})

Convergence.Events.Unsubscribe("planet.stability.changed", token)
Convergence.Events.UnsubscribeOwner("example_module")
```

## Canonical events introduced

```text
core.loaded
planet.stability.changed
planet.stability.lock.changed
```

## Test procedure

1. Replace the addon and restart.
2. Run:
   ```text
   convergence_diagnostics
   ```
3. Confirm the Event Bus section is present.
4. Run:
   ```text
   convergence_event_test
   ```
5. Confirm `5/5 passed`.
6. The intentional subscriber error is expected to print one protected test
   error. The remaining subscriber must still run and the test must pass.
7. Run:
   ```text
   convergence_event_status
   ```
8. Change stability and confirm `planet.stability.changed` appears in history:
   ```text
   convergence_stability_add tatooine 1 Event bus test
   convergence_event_status
   ```
