# Architecture

Convergence Galaxy is split into independent modules.

## Core

Responsible for:

- namespace creation
- file loading
- module registration
- hooks
- version reporting

## Database

SQLite is the default persistence layer. The API is intentionally isolated so
a MySQL adapter can be introduced later.

## Planet registry

Planet definitions are configuration data. Runtime state is stored separately.

## Stability

Every stability change is written as a transaction containing:

- planet ID
- previous value
- new value
- delta
- source
- actor
- reason
- timestamp

## Integrations

Third-party integrations must remain adapters. They should not be required for
the core addon to boot.
