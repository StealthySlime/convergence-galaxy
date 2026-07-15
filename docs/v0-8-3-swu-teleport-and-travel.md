# Version 0.8.3 — SWU GM Teleport and Cinematic Travel

## GM Ship Position / GOTO synchronization

SWU's configuration menu sends `swu_setShipPos`, which changes the controller's
persistent universe position directly.

Convergence now watches the SWU controller's position setter. When a large
non-hyperspace position change lands near a registered Convergence planet:

- the player task force arrives at that planet
- the persistent world state updates
- the Player and Director maps update on refresh
- no GMod map change occurs
- the encounter remains inactive

Manual diagnostic:

```text
convergence_swu_reconcile_position
```

## Hyperspace duration

Raw SWU estimates may represent several real-world hours. Convergence now
converts them into a cinematic but usable duration.

Default range:

```text
Minimum: 45 seconds
Maximum: 180 seconds
```

The duration still scales with distance inside that range.

Configuration:

```lua
Config.World.SWU = {
    MinimumHyperspaceSeconds = 45,
    MaximumHyperspaceSeconds = 180,
    EstimateDivisor = 60,
    TeleportDeltaThreshold = 50,
    PlanetArrivalRadius = 8
}
```

The regular SWU speed selector remains functional. Convergence applies an
external modifier after the user selects a destination, and the visible SWU
estimate is changed to the practical duration.

## Test

### GM GOTO

1. Open SWU Configuration.
2. Choose Ship Position.
3. Select a registered planet and press GOTO.
4. Run:
   ```text
   convergence_world_status
   convergence_navigation_status
   ```
5. Confirm the current planet changed.
6. Refresh Player and Director maps.

### Hyperspace timing

1. Select a destination in the SWU navigation computer.
2. Wait for calculation to finish.
3. Run:
   ```text
   convergence_swu_jump_status
   ```
4. Confirm Target travel duration is between 45 and 180 seconds.
5. Use the normal SWU hyperspace button.
