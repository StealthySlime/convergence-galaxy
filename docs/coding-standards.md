# Coding Standards

This document supplements `architecture.md`.

## Lua

- Four spaces; no tabs.
- Keep server authority explicit.
- Use realm prefixes.
- Keep files focused on one service or feature.
- Use early returns and argument validation.
- Do not create globals outside `Convergence`.
- Use public service functions instead of editing tables directly.
- Always return useful failure codes and messages.

## Git

Recommended branches:

```text
main
develop
feature/<short-name>
fix/<short-name>
docs/<short-name>
```

Commit examples:

```text
feat(stability): add transaction history
fix(database): prevent duplicate planet inserts
docs(architecture): define SWU adapter contract
```

## Pull requests

Every pull request should state:

- purpose
- affected modules
- schema changes
- new hooks or network messages
- test steps
- dependency requirements
- rollback considerations
