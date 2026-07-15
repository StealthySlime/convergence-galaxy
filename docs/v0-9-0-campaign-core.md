# Version 0.9.0 — Campaign Core

This release introduces the persistent campaign-event and single-deployment
services.

## AI battles

AI-controlled events receive a persistent resolution deadline.

Default durations:

```text
Standard battle: 1–2 hours
Major battle: up to 3 hours
GM extension cap: 4 hours
```

AI events continue progressing while players are deployed elsewhere.

## Player deployment

This server supports one active player deployment.

Starting a deployment:

- locks the selected event's strategic snapshot
- marks that event as player-controlled
- pauses only that event's AI resolution
- leaves every unrelated campaign event and fleet running

When the deployment's original timer expires, it becomes
`awaiting_gm_resolution`; it does not auto-resolve.

## GM resolution

Supported outcomes:

```text
major_victory
victory
draw
defeat
major_defeat
```

Resolution changes planet stability and faction influence persistently.

## Commands

```text
convergence_campaign_create <planet> <difficulty> <enemy1,enemy2> <name>
convergence_campaign_list
convergence_campaign_extend <event_id> <seconds>
convergence_deployment_start <event_id>
convergence_deployment_resolve <outcome> [notes]
convergence_campaign_test
```

## Test

1. Restart and confirm schema `8`.
2. Run:
   ```text
   convergence_campaign_test
   ```
3. Expected:
   ```text
   Result: 9/9 passed
   ```
4. Create two events.
5. Start a deployment for one event.
6. Confirm the other event's timer continues counting down.
7. Resolve the deployment and confirm the deployment slot clears.
