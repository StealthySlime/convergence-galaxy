# Phase 3.1 — Galactic Command UI Framework

This phase introduces the first player-visible Galactic Command interface.

## Included

- full-screen Derma application shell
- Republic holographic theme
- modular navigation registry
- player and admin-only modules
- live galaxy snapshot networking
- campaign clock display
- planet overview and inspector
- faction and alliance pages
- placeholder pages for fleets, research, events, and GM tools
- refresh and close controls
- resolution-aware full-screen layout

## Opening the interface

Run as a player:

```text
convergence_galaxy
```

A client-only development command is also available:

```text
convergence_ui_client
```

## Current modules

- Galaxy
- Planets
- Factions
- Alliances
- Fleets
- Research
- Events
- GM Controls — admins only

## Data flow

```text
Client opens Galactic Command
→ server builds authorized galaxy snapshot
→ snapshot is compressed and networked
→ client updates its read-only cache
→ active UI module is rebuilt
```

## Test procedure

1. Install the update and restart.
2. Join the server as a player.
3. Run:
   ```text
   convergence_galaxy
   ```
4. Confirm the full-screen interface opens.
5. Confirm the Galaxy page displays:
   - campaign time
   - three planets
   - current stability
   - dominant alliance and faction
   - influence values
6. Test the Planets, Factions, and Alliances pages.
7. Confirm GM Controls appears only for admins.
8. Use the Refresh button after changing influence or stability.
9. Confirm the updated values appear without reconnecting.

## Next phase

Phase 3.2 will replace the list-based Galaxy page with an interactive,
zoomable and pannable galaxy renderer containing reusable planet nodes.
