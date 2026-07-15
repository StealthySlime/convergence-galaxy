# Version 0.9.9 — Deployment Map Selection and SWU Planet Registration

## Deployment map selector

Clicking Deploy Players now opens a map-selection window containing every
configured region for the operation planet.

The selected region is:

- validated server-side
- locked into the deployment snapshot
- prepared automatically
- shown in the success message

Convergence does not run `changelevel`; the GM still performs the map change.

## SWU planet registration

Every planet in `Config.Planets` is now synchronized into:

- the SWU navigation computer
- discoverable SWU global planet lists
- discoverable Ship Position/GOTO lists
- supported SWU registration functions when available

This prevents a configured Convergence planet such as Reach from appearing on
the strategic map without being created in SWU.

## Diagnostics

Run:

```text
convergence_swu_sync
convergence_swu_planet_status
```

Expected for every configured planet:

```text
mapping=PASS navigation=PASS
```
