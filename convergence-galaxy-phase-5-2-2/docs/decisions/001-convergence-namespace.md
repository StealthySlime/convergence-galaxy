# ADR 001: Keep `Convergence` as the canonical namespace

- **Status:** Accepted
- **Date:** 2026-07-15

## Context

The project needs a stable global namespace for all framework services.
A shorter alias such as `CG` is easier to type but more likely to collide with
other Garry's Mod addons and is less self-documenting.

## Decision

Use `Convergence` as the only canonical global namespace.

Local aliases may be used inside files.

## Consequences

Public APIs remain clear and collision risk is reduced. Function calls are
slightly longer, but public readability is improved.
