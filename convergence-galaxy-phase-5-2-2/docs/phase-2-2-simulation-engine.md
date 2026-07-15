# Phase 2.2 — Simulation Engine

The Simulation Engine provides a deterministic processing pipeline driven by
the persistent Galaxy Clock.

## Added

- ordered processor registry
- processor priorities and cadences
- protected processor execution
- processor time-budget warnings
- queued simulation actions
- bounded tick history
- tick timing and diagnostics
- start, stop, and manual-step controls
- initial Planet State Processor
- automated simulation tests

## Processing order

Each simulation tick performs:

1. begin tick
2. process queued actions
3. run enabled processors in priority order
4. record timing and processor results
5. publish completion events

## Processor API

```lua
Convergence.Simulation.RegisterProcessor({
    id = "example",
    name = "Example Processor",
    priority = 50,
    runEveryTicks = 1,

    process = function(self, tickContext)
        return {
            processed = true
        }
    end
})
```

## Queue API

```lua
Convergence.Simulation.Enqueue(
    "example_action",
    {
        planetID = "tatooine"
    },
    {
        source = "example",
        reason = "Demonstration."
    }
)
```

## Commands

```text
convergence_simulation_status
convergence_simulation_start
convergence_simulation_stop
convergence_simulation_step
convergence_simulation_queue_test
convergence_simulation_test
```

## Test procedure

1. Replace the addon and restart.
2. Run:
   ```text
   convergence_diagnostics
   ```
3. Confirm:
   - Simulation Engine `PASS`
   - Simulation running `PASS`
4. Wait at least one Galaxy Clock interval and run diagnostics again.
5. Confirm Simulation tick increased.
6. Run:
   ```text
   convergence_simulation_test
   ```
7. Confirm `7/7 passed`.
8. Run:
   ```text
   convergence_simulation_status
   ```
9. Restart and confirm existing planet stability and Galaxy Clock state remain.
