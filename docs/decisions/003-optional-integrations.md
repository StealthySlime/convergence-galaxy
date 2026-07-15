# ADR 003: Treat SAM and SWU as optional adapters

- **Status:** Accepted
- **Date:** 2026-07-15

## Context

The framework benefits from SAM administration and the SWU star map, but neither
third-party addon should become required for database boot or campaign state.

## Decision

Implement each dependency under `integrations/` as an optional adapter. Do not
modify or redistribute third-party source files.

## Consequences

The core remains portable and resilient to dependency updates. Integration
features may disable themselves when a dependency changes.
