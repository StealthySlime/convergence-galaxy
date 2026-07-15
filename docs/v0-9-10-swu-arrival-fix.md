# Version 0.9.10 — SWU Arrival and Registry Fix

## Fixed planet IDs

`Config.Planets` is an array. Version 0.9.9 incorrectly used its numeric array
indexes as planet IDs in one synchronization path, producing diagnostic rows
named `1`, `2`, and `3`.

Planet mappings now always use `definition.id`.

## Reach coordinates

Reach now uses coordinates in the same practical scale as the installed SWU
universe. The previous very large coordinate could leave some SWU builds in
hyperspace indefinitely.

## Ship Position/GOTO

Planet lists are now synchronized on both the server and client. Run the
following in the client console after updating:

```text
convergence_swu_client_sync
```

Then reopen the Configuration menu.

## Hyperspace fallback

If an SWU build fails to apply the external travel modifier to its exit timer,
Convergence exits hyperspace after the configured practical duration plus a
five-second grace period, moves the SWU universe position to the selected
planet, and records arrival.

Emergency admin command:

```text
convergence_swu_force_arrival
```
