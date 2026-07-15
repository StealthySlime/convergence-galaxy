# Version 0.9.5 — Operations, Director Controls, and SAM

## Director UI

The Director dashboard now supports:

- creating campaign operations
- starting the single player deployment
- extending AI resolution by 30 minutes
- resolving deployments as major victory, victory, draw, defeat, or major defeat
- starting and ending encounters
- viewing current deployment and operation timers

Open with:

```text
convergence_director
```

## Player Operations Center

The Operations page displays:

- operation name
- planet
- status
- mission type
- difficulty and priority
- AI resolution time
- player-deployment state
- briefing

## SAM commands

When SAM is installed:

```text
!convergence
!galaxydirector
!convergenceoperations
```

Permissions:

```text
convergence_director
convergence_campaign
```

Assign these permissions to the GM ranks that should access the Director or
manage campaign operations.

When SAM is missing or its API is unavailable, the addon continues working
through:

```text
convergence_director
```

## Security

Director actions are validated server-side. Opening a client panel or sending a
network message does not bypass SAM or admin permissions.
