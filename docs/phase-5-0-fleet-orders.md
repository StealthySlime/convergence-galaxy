# Phase 5.0 — Fleet Orders

Fleets now support persistent GM-assigned orders.

## Supported orders

```text
idle
move
patrol
defend
reinforce
invade
blockade
escort
retreat
explore
```

## Commands

```text
convergence_fleet_order <fleet> <order> [planet] [travel_hours]
convergence_fleet_order_clear <fleet>
convergence_fleet_order_test
```

Examples:

```text
convergence_fleet_order republic_first_fleet defend tatooine 6
convergence_fleet_order republic_first_fleet patrol tatooine 2
convergence_fleet_order republic_first_fleet invade reach 8
```

## Initial behavior

- Move, retreat, and reinforce travel to the target and complete.
- Patrol slowly adds faction influence.
- Defend adds stronger faction influence.
- Blockade gradually reduces stability.
- Invade reduces stability faster.
- Additional battle, escort, and exploration behavior will build on this order foundation.

## Visual improvements

- Traveling fleet icons point toward their destination.
- Moving fleets have a subtle engine trail.
- Stationed fleets orbit their planet.
- Icon size scales with fleet strength.
- Hovering a fleet displays its name, faction, strength, status, and order.
- Labels hide at lower zoom levels to reduce clutter.

## Test

1. Restart and confirm schema `5`.
2. Run `convergence_fleet_order_test`; expect `7/7 passed`.
3. Assign a defend order to Tatooine.
4. Refresh the galaxy map and watch the fleet travel.
5. After arrival, confirm Republic influence slowly increases.
