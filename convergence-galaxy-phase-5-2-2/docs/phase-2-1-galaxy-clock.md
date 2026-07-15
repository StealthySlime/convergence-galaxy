# Phase 2.1 — Galaxy Clock

The Galaxy Clock provides persistent campaign time independently of real-world
audit timestamps.

## Added

- persistent campaign tick count
- campaign day, hour, and minute
- configurable campaign-time speed
- pause and resume support
- manual time setting and advancement
- periodic clock persistence
- restart recovery
- clock events
- diagnostics and automated tests

## Configuration

```lua
Convergence.Config.Clock = {
    TickInterval = 5,
    SecondsPerCampaignHour = 60,
    StartingDay = 1,
    StartingHour = 0,
    AutoStart = true,
    SaveEveryTicks = 12
}
```

With the default settings, one real minute equals one campaign hour.

## Commands

```text
convergence_clock_status
convergence_clock_pause
convergence_clock_resume
convergence_clock_scale <0-100>
convergence_clock_set <day> <hour> [minute]
convergence_clock_advance <campaign_hours>
convergence_clock_test
```

## Test procedure

1. Replace the addon and restart.
2. Run:
   ```text
   convergence_diagnostics
   ```
3. Confirm:
   - target schema `2`
   - installed schema `2`
   - Galaxy Clock `PASS`
   - Clock running `PASS`
4. Run:
   ```text
   convergence_clock_status
   convergence_clock_test
   ```
5. Confirm `5/5 passed`.
6. Record the current campaign time.
7. Restart the server and confirm the clock resumes from the saved time.
8. Verify Tatooine's existing stability remains unchanged.
