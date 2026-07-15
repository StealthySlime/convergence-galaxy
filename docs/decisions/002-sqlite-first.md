# ADR 002: SQLite first, database abstraction required

- **Status:** Accepted
- **Date:** 2026-07-15

## Context

The framework needs immediate persistence without requiring external database
software, while leaving room for a production MySQL deployment.

## Decision

Ship SQLite first. Route persistence through `Convergence.Database` and prohibit
feature modules from owning direct SQL access after the abstraction is complete.

## Consequences

Initial installation remains simple. A later MySQL adapter can be added without
rewriting every campaign service.
