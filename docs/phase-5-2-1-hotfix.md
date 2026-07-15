# Phase 5.2.1 — Renderer and SWU Hyperspace Hotfix

## Fixed

- Galaxy Renderer now has a dedicated client autorun bootstrap.
- Galaxy module defensively reloads the renderer before creating it.
- SWU destinations now use meaningful universe distances.
- SWU planet synchronization rebuilds from SWU's authoritative universe list.
- Convergence destinations receive SWU's required minimum jump time when needed.
- Added an SWU jump-status diagnostic command.

## Commands

```text
convergence_swu_sync
convergence_swu_jump_status
convergence_galaxy
```

## Test

1. Restart the server and reconnect the client.
2. Run `convergence_swu_sync`.
3. Select Reach or Tatooine on the SWU navigation computer.
4. Wait for its calculation/loading bar to finish.
5. Run `convergence_swu_jump_status`.
6. Confirm:
   - Target is selected.
   - Loading is false.
   - Estimated jump time is at least 5.
   - Can jump is true.
7. Pull the existing SWU hyperspace lever.
8. Open `convergence_galaxy` and confirm the renderer opens.
