# Version 0.13.0 — Living Galaxy AI

## Threat Engine 2.0

Every planet now exposes an explainable threat breakdown:

- low stability
- hostile influence advantage
- enemy fleet advantage
- active, major, and critical operations
- nearby hostile pressure
- strategic exposure

## Faction AI

Every think cycle:

- Republic and UNSC reinforce the highest-threat system when an idle fleet is
  available.
- Covenant and CIS order idle fleets to invade a strategic opportunity.
- When an enemy faction has no fleet, it may generate an AI campaign operation
  against a sufficiently exposed planet.
- All decisions are recorded in history and Galactic News.

The default think interval is two real minutes and may be changed through
`Config.Campaign.AIThinkIntervalSeconds`.

## AI operation safeguards

- One unresolved AI-generated operation per planet.
- Per-planet generation cooldown.
- Existing player and AI operations remain visible to the GM.
- AI battles continue using the existing one-to-two-hour resolution system.

## Director tools

New Director tabs:

```text
Galactic AI
Intelligence
```

The Galactic AI tab shows the next think cycle and each faction's most recent
decision. Intelligence now shows the reason behind every threat score.

## Commands

```text
convergence_ai_status
convergence_ai_think
convergence_ai_toggle 0
convergence_ai_toggle 1
convergence_ai_test
```

Expected:

```text
Result: 6/6 passed
```
