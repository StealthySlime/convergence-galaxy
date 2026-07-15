# Changelog

## Unreleased

### Fixed

- Restored the Galaxy Renderer registration after the Phase 5.1 integration.
- Removed client proxy-planet injection that could conflict with SWU.

### Added

- Formal service registry.
- Navigation adapter interface.
- Native SWU navigation adapter.
- Separate SWU planet mapping file.
- Navigation diagnostics.

### Changed

- Addon version increased to `0.7.1`.
- SWU is now the sole authority for player navigation and hyperspace.
- Convergence consumes navigation state without emulating the SWU starmap.

## 0.7.0

- Added persistent world state, GM transitions, and encounter protection.
