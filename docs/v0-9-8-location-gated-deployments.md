# Version 0.9.8 — Location-Gated Deployments

Operations can only be prepared or deployed when the player task force is
physically located at the operation's planet.

## Enforcement

The rule is enforced both clientside and serverside:

- Prepare Region is disabled when the task force is elsewhere.
- Deploy Players is disabled when the task force is elsewhere.
- Manually sending the network action cannot bypass the rule.
- Console deployment commands also use the same server-side validation.

Example:

```text
Operation planet: Reach
Current planet: Tatooine

Prepare Region: disabled
Deploy Players: disabled
```

After traveling to Reach through SWU or using an authorized GM GOTO:

```text
Current planet: Reach

Prepare Region: enabled
Deploy Players: enabled
```

Preparing a region still does not change the active GMod map automatically.
The GM remains responsible for the map change.
