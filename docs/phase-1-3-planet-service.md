# Phase 1.3 — Planet Service

This update moves runtime planet access behind a cached service API.

## Added

- server-side planet object model
- startup cache populated from SQLite
- lookup by ID, display name, or alias
- public planet getters
- revision tracking
- cache update hooks
- explicit reload support
- network delta revision values
- planet-service diagnostics
- planet-service test command

## Public API

```lua
local planet = Convergence.PlanetService.Get("tatooine")

planet:GetID()
planet:GetName()
planet:GetStability()
planet:GetStabilityState()
planet:IsStabilityLocked()
planet:GetUpdatedAt()
planet:GetRevision()
planet:ToPublicTable()
```

Registry APIs:

```lua
Convergence.GetPlanetDefinition(value)
Convergence.GetPlanetDefinitions()
Convergence.ResolvePlanetID(value)
Convergence.IsPlanetRegistered(value)
```

## Test procedure

1. Replace the addon and restart.
2. Run:
   ```text
   convergence_diagnostics
   ```
3. Confirm `Planet service: PASS`.
4. Confirm Tatooine still has the previous persistent value.
5. Run:
   ```text
   convergence_planet_test
   ```
6. Confirm `5/5 passed`.
7. Change Tatooine:
   ```text
   convergence_stability_add tatooine 1 Planet service test
   ```
8. Run `convergence_diagnostics` and confirm its revision increased.
9. Restart and confirm the stability value remains saved.
