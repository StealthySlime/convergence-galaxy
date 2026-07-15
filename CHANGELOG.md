# Changelog

## Unreleased

### Added

- Deterministic Simulation Engine.
- Ordered simulation processor registry.
- Processor priorities and configurable execution cadence.
- Protected processor execution and performance-budget warnings.
- Queued simulation actions.
- Simulation tick history and timing metrics.
- Start, stop, manual-step, status, queue-test, and automated-test commands.
- Initial Planet State Processor.
- Simulation events for lifecycle, ticks, processors, and queued actions.

### Changed

- Addon version increased to `0.2.1`.
- Galaxy Clock ticks now drive Simulation Engine ticks.

## 0.2.0

- Added persistent Galaxy Clock and schema migration 2.

## 0.1.4

- Added framework Event Bus.

## 0.1.3

- Added cached Planet Service and planet object API.

## 0.1.2

- Fixed database initialization and added stage diagnostics.

## 0.1.1

- Added SQLite abstraction and migrations.

## 0.1.0

- Added initial persistent galaxy scaffold.
