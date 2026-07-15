# Convergence Galaxy — Architecture Constitution

**Document version:** 1.0  
**Target addon version:** 0.1.0+  
**Status:** Authoritative development blueprint

This document defines the required architecture, naming conventions, data
ownership, extension boundaries, persistence rules, networking rules, hooks,
permissions, and integration strategy for Convergence Galaxy.

The project is a persistent galactic campaign framework for Garry's Mod. It is
designed to operate independently while optionally integrating with SAM and the
Star Wars Universe interactive star-map addon.

---

## 1. Architectural goals

The framework must:

1. Preserve campaign state across map changes and server restarts.
2. Keep the core usable when SAM, SWU, DarkRP, or other optional addons are absent.
3. Store every important campaign change as an auditable transaction.
4. Separate framework logic from specific campaign content.
5. Expose stable APIs and hooks for future modules.
6. Keep the server authoritative for all persistent state.
7. Avoid editing or redistributing third-party addon files.
8. Fail safely when an integration or content module is unavailable.
9. support SQLite first and allow a future MySQL adapter.
10. remain understandable enough to maintain over a multi-year campaign.

---

## 2. Project identity and namespace

The canonical Lua namespace is:

```lua
Convergence
```

Do not introduce additional global namespaces such as `CG`, `CGalaxy`, or
`ConvergenceGalaxy`. Short local aliases may be used inside individual files:

```lua
local Galaxy = Convergence
local DB = Convergence.Database
```

Canonical identity constants:

```lua
Convergence.Name = "Convergence Galaxy"
Convergence.Version = "0.1.0"
Convergence.SchemaVersion = 1
```

All network strings, hooks, SQL tables, console commands, and SAM privileges
must use the `Convergence` or `convergence_` prefix.

---

## 3. Repository layout

```text
convergence-galaxy/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   └── workflows/
├── addon/
│   └── convergence_galaxy/
│       ├── addon.txt
│       ├── lua/
│       │   ├── autorun/
│       │   │   └── convergence_init.lua
│       │   └── convergence/
│       │       ├── core/
│       │       ├── database/
│       │       ├── planets/
│       │       ├── stability/
│       │       ├── factions/
│       │       ├── events/
│       │       ├── missions/
│       │       ├── fleets/
│       │       ├── resources/
│       │       ├── research/
│       │       ├── timeline/
│       │       ├── network/
│       │       ├── commands/
│       │       ├── permissions/
│       │       ├── integrations/
│       │       │   ├── sam/
│       │       │   └── swu/
│       │       └── ui/
│       ├── materials/
│       │   └── convergence/
│       └── resource/
├── config/
├── docs/
├── migrations/
│   ├── sqlite/
│   └── mysql/
├── CHANGELOG.md
├── LICENSE
└── README.md
```

Third-party addons must not be copied into the repository.

---

## 4. Realm and file naming rules

Garry's Mod realm prefixes are mandatory:

```text
sh_  shared
sv_  server only
cl_  client only
```

Examples:

```text
sh_planets.lua
sv_database.lua
cl_star_map.lua
```

The autorun loader is the only file that should manually define the initial
global namespace. Modules must assume the loader has run.

Load order:

1. shared configuration
2. shared utilities
3. shared registries and schemas
4. server database
5. server services
6. server networking
7. server integrations
8. client networking
9. client UI
10. client integrations

A module must never depend on alphabetical file loading.

---

## 5. Core services

The authoritative service namespaces are:

```lua
Convergence.Config
Convergence.Modules
Convergence.Database
Convergence.Planets
Convergence.Stability
Convergence.Factions
Convergence.Events
Convergence.Missions
Convergence.Fleets
Convergence.Resources
Convergence.Research
Convergence.Timeline
Convergence.Network
Convergence.Permissions
Convergence.Integrations
Convergence.UI
```

Each service must expose functions rather than expecting external code to edit
its internal tables directly.

Bad:

```lua
Convergence.Planets["tatooine"].stability = 10
```

Correct:

```lua
Convergence.Stability.Set("tatooine", 10, context)
```

---

## 6. Module contract

Feature modules register through a shared module registry.

```lua
Convergence.RegisterModule({
    id = "stability",
    name = "Planetary Stability",
    version = "1.0.0",
    dependencies = {},
    optionalDependencies = {"sam", "swu"},
    initialize = function(self) end,
    shutdown = function(self) end
})
```

Required module fields:

| Field | Type | Purpose |
|---|---|---|
| `id` | string | Stable machine identifier |
| `name` | string | Display name |
| `version` | string | Semantic version |
| `dependencies` | table | Required internal modules |
| `optionalDependencies` | table | Optional integrations |
| `initialize` | function | Start service |
| `shutdown` | function | Cleanup service |

A module that fails initialization must log the error and disable itself without
preventing the entire addon from loading.

---

## 7. Planet identity

Every planet has a permanent normalized ID:

```lua
{
    id = "tatooine",
    name = "Tatooine",
    aliases = {"Tatooine Prime"},
    defaultStability = 75,
    swu = {
        names = {"Tatooine"},
        externalID = nil
    }
}
```

Rules:

- IDs are lowercase.
- Spaces become underscores.
- IDs cannot change after campaign data exists.
- Display names may change.
- SWU names are aliases, not authoritative IDs.
- Runtime campaign state is not stored in the definition table.

Planet registry API:

```lua
Convergence.RegisterPlanet(definition)
Convergence.GetPlanet(planetID)
Convergence.GetPlanets()
Convergence.ResolvePlanetID(value)
Convergence.IsPlanetRegistered(planetID)
```

---

## 8. Data ownership

The following data is configuration:

- planet definitions
- faction definitions
- stability thresholds
- permission defaults
- event and mission templates
- SWU mapping rules

The following data is persistent runtime state:

- stability
- ownership
- active effects
- active events
- active missions
- fleets
- resources
- research progress
- travel locks
- campaign timeline
- transaction history

Runtime state must never be written back into Lua configuration files.

---

## 9. Database abstraction

All SQL must go through `Convergence.Database`.

Public database contract:

```lua
Convergence.Database.Initialize()
Convergence.Database.Query(query, callback)
Convergence.Database.Execute(query, parameters, callback)
Convergence.Database.Transaction(operations, callback)
Convergence.Database.GetAdapterName()
Convergence.Database.IsReady()
```

The first adapter is SQLite. Future adapters may include MySQL through mysqloo.

No feature module may call `sql.Query` directly after the database abstraction
is fully implemented.

Database writes must be server-side only.

---

## 10. Database schema

### 10.1 `convergence_meta`

Tracks schema and addon metadata.

| Column | Type | Notes |
|---|---|---|
| `key` | TEXT PK | Metadata key |
| `value` | TEXT | Metadata value |

Required keys:

```text
schema_version
addon_version
created_at
last_migration_at
```

### 10.2 `convergence_planets`

| Column | Type | Notes |
|---|---|---|
| `planet_id` | TEXT PK | Stable planet ID |
| `stability` | INTEGER | 0–100 |
| `owner_faction_id` | TEXT NULL | Current owner |
| `travel_locked` | INTEGER | 0 or 1 |
| `stability_locked` | INTEGER | 0 or 1 |
| `created_at` | INTEGER | Unix time |
| `updated_at` | INTEGER | Unix time |

### 10.3 `convergence_stability_history`

| Column | Type |
|---|---|
| `id` | INTEGER PK |
| `planet_id` | TEXT |
| `previous_value` | INTEGER |
| `new_value` | INTEGER |
| `delta` | INTEGER |
| `source` | TEXT |
| `source_id` | TEXT NULL |
| `actor_type` | TEXT |
| `actor_id` | TEXT |
| `actor_name` | TEXT |
| `reason` | TEXT |
| `metadata_json` | TEXT |
| `created_at` | INTEGER |

### 10.4 `convergence_factions`

| Column | Type |
|---|---|
| `faction_id` | TEXT PK |
| `display_name` | TEXT |
| `metadata_json` | TEXT |
| `created_at` | INTEGER |
| `updated_at` | INTEGER |

### 10.5 `convergence_events`

| Column | Type |
|---|---|
| `event_id` | TEXT PK |
| `template_id` | TEXT |
| `planet_id` | TEXT |
| `state` | TEXT |
| `phase` | TEXT |
| `data_json` | TEXT |
| `started_at` | INTEGER |
| `expires_at` | INTEGER NULL |
| `updated_at` | INTEGER |

### 10.6 `convergence_missions`

Uses the same instance pattern as events and additionally stores assignment,
objectives, contribution state, success rewards, and failure penalties.

### 10.7 `convergence_world_changes`

Stores persistent spawned compositions, disabled map entities, convergence
zones, infrastructure state, and reconstruction information.

### 10.8 `convergence_timeline`

Stores player-facing campaign history.

| Column | Type |
|---|---|
| `id` | INTEGER PK |
| `planet_id` | TEXT NULL |
| `category` | TEXT |
| `title` | TEXT |
| `description` | TEXT |
| `visibility` | TEXT |
| `metadata_json` | TEXT |
| `created_at` | INTEGER |

### 10.9 `convergence_audit_log`

Stores administrative changes beyond stability transactions.

Never delete audit rows through the normal UI. Archival tools may be added later.

---

## 11. Migrations

Every schema modification must be represented by an ordered migration.

```text
migrations/sqlite/001_initial.sql
migrations/sqlite/002_factions.sql
migrations/sqlite/003_events.sql
```

Migration rules:

- Never edit a migration that has been released.
- Add a new migration instead.
- Run migrations inside a transaction when supported.
- Update `schema_version` only after success.
- Abort addon write operations if migration state is invalid.
- Log migration start, success, and failure.

---

## 12. Transaction context

Every persistent state mutation receives a context table:

```lua
local context = {
    source = "sam_command",
    sourceID = "stability_set",
    actor = ply,
    reason = "Reactor destroyed during campaign.",
    metadata = {
        eventID = "evt_1234"
    },
    bypassLock = false
}
```

Required mutation functions reject missing reasons for GM/admin actions.

System-generated changes may use a structured reason.

---

## 13. Stability service

Public API:

```lua
Convergence.Stability.Get(planetID)
Convergence.Stability.Set(planetID, value, context)
Convergence.Stability.Add(planetID, delta, context)
Convergence.Stability.SetLocked(planetID, locked, context)
Convergence.Stability.GetState(value)
Convergence.Stability.GetHistory(planetID, options, callback)
```

Rules:

- Clamp stability between configured minimum and maximum.
- Do not write a transaction when the value did not change.
- Respect stability locks unless explicitly bypassed by an authorized system.
- Fire hooks only after a successful database write.
- Network only the changed planet.
- Store previous value, new value, and delta.

Canonical stability states:

| Value | State ID |
|---:|---|
| 81–100 | `stable` |
| 61–80 | `strained` |
| 41–60 | `unstable` |
| 21–40 | `critical` |
| 1–20 | `convergence` |
| 0 | `collapse` |

Thresholds remain configurable.

---

## 14. Events

Event lifecycle:

```text
pending
starting
active
succeeded
failed
cancelled
cleanup
archived
```

Event template contract:

```lua
Convergence.Events.RegisterTemplate({
    id = "dimensional_incursion",
    name = "Dimensional Incursion",
    version = 1,

    canStart = function(context) return true end,
    start = function(instance) end,
    restore = function(instance) end,
    tick = function(instance) end,
    finish = function(instance, outcome) end,
    cleanup = function(instance) end
})
```

All active event instances must survive restart.

An event template update must not make existing stored instances unreadable.
Templates should include a version and migration path for their `data_json`.

---

## 15. Missions

Mission lifecycle:

```text
available
assigned
active
completed
failed
expired
cancelled
archived
```

Mission templates define:

- eligibility
- target planet
- objectives
- duration
- rewards
- stability effects
- faction effects
- cleanup behavior

Mission progress must be server validated. Client messages may request actions
but cannot award progress directly.

---

## 16. Factions

Faction definitions are registered in Lua. Faction runtime state is stored in
the database.

Public API:

```lua
Convergence.Factions.Register(definition)
Convergence.Factions.Get(factionID)
Convergence.Factions.SetPlanetOwner(planetID, factionID, context)
Convergence.Factions.GetPlanetOwner(planetID)
Convergence.Factions.AddInfluence(planetID, factionID, amount, context)
```

External DarkRP jobs, regiment systems, or whitelist groups should map to
Convergence faction IDs through adapters.

---

## 17. Fleets and travel

Fleet records represent campaign objects, not necessarily physical entities.

A fleet may have:

- faction
- current planet
- destination
- departure time
- arrival time
- strength
- supply
- status
- public visibility

Travel authorization API:

```lua
local allowed, reason, modifiers =
    Convergence.CanTravel(ply, originPlanetID, destinationPlanetID, context)
```

Canonical hook:

```lua
hook.Run(
    "ConvergenceCanTravel",
    ply,
    originPlanetID,
    destinationPlanetID,
    context
)
```

SWU remains responsible for its normal navigation implementation. Convergence
may allow, deny, or modify travel through an adapter.

---

## 18. Networking

Naming format:

```text
Convergence.<Area>.<Action>
```

Examples:

```text
Convergence.Planet.Request
Convergence.Planet.State
Convergence.Map.Open
Convergence.Admin.Action
Convergence.History.Request
Convergence.History.Response
```

Networking rules:

- Register all network strings server-side.
- Validate entity, player, planet, permission, length, and rate limits.
- Never trust client-provided stability, ownership, rewards, or event outcomes.
- Use compact primitive fields for frequent state updates.
- Use compressed JSON only for bounded, infrequent payloads.
- Set hard maximum payload sizes.
- Paginate history and audit responses.
- Rate limit requests per player.
- Do not send private GM data to unauthorized clients.

Client state is a read-only cache.

---

## 19. Hooks

Hooks are the extension contract. Hook names use PascalCase after the prefix.

Core hooks:

```lua
ConvergenceLoaded(version)
ConvergenceDatabaseReady(adapterName)
ConvergencePlanetRegistered(planetID, definition)
ConvergencePlanetStateLoaded(planetID, state)
ConvergenceStabilityChanging(planetID, previous, proposed, context)
ConvergenceStabilityChanged(planetID, previous, current, transaction)
ConvergencePlanetOwnerChanged(planetID, previousFaction, currentFaction, context)
ConvergencePlanetTravelLockChanged(planetID, locked, context)
ConvergenceEventStarted(instance)
ConvergenceEventFinished(instance, outcome)
ConvergenceMissionStarted(instance)
ConvergenceMissionFinished(instance, outcome)
ConvergenceTimelineEntryCreated(entry)
ConvergenceSWUDetected()
ConvergenceSAMDetected()
```

`ConvergenceStabilityChanging` may veto a change by returning `false, reason`.
Post-change hooks cannot retroactively cancel a committed transaction.

---

## 20. Permissions

Canonical permissions:

```text
convergence.view
convergence.view_private
convergence.map.open
convergence.admin.open
convergence.stability.set
convergence.stability.add
convergence.stability.lock
convergence.history.view
convergence.events.start
convergence.events.stop
convergence.missions.manage
convergence.planets.owner
convergence.planets.travel
convergence.timeline.create
convergence.cleanup
convergence.superadmin
```

Permission resolution order:

1. explicit Convergence provider
2. SAM provider when installed
3. fallback Garry's Mod admin checks

Public API:

```lua
Convergence.Permissions.Has(ply, privilege)
Convergence.Permissions.Register(privilege, description, defaultAccess)
Convergence.Permissions.GetProvider()
```

Never scatter direct `ply:IsSuperAdmin()` checks throughout feature modules.

---

## 21. SAM integration

SAM is optional.

The SAM adapter must:

- register Convergence privileges
- register concise commands
- use the same core service APIs as the GUI
- require reasons for persistent GM mutations
- write normal audit records
- expose a command that opens GM map mode

Proposed commands:

```text
!galaxy
!galaxyadmin
!planetstatus <planet>
!stability <planet>
!stabilityset <planet> <value> <reason>
!stabilityadd <planet> <delta> <reason>
!stabilitylock <planet>
!stabilityunlock <planet>
!stabilityhistory <planet>
!planetevent <planet> <event>
!planetowner <planet> <faction>
!planettravellock <planet>
!planettravelunlock <planet>
```

Commands are convenience interfaces. They must not contain campaign logic.

---

## 22. SWU integration

The Star Wars Universe addon is an optional external dependency.

Integration rules:

- Do not modify SWU source files.
- Do not redistribute SWU code or assets.
- Detect SWU at runtime.
- Maintain an explicit mapping between SWU planet objects and Convergence IDs.
- Use hooks, wrappers, or safe UI extension points.
- Fail cleanly after SWU updates.
- Keep the base Convergence map UI available as a fallback.

Adapter responsibilities:

1. Discover SWU planets.
2. Resolve external names or IDs.
3. Attach stability and campaign metadata.
4. extend the selected-planet information panel.
5. draw status markers or overlays.
6. open GM planet controls.
7. intercept or advise travel requests when supported.
8. log unsupported mappings.

Mapping example:

```lua
Convergence.Integrations.SWU.RegisterPlanetMapping({
    convergenceID = "tatooine",
    swuNames = {"Tatooine"},
    aliases = {}
})
```

Unknown SWU planets should remain visible but display:

```text
Campaign data unavailable
```

They must not be assigned a guessed identity.

---

## 23. Star-map UI

The star map has two modes.

### Player mode

Shows only authorized public information:

- planet name
- stability
- stability state
- owner
- public events
- public missions
- travel status
- public timeline
- known fleet presence

### GM mode

Adds:

- exact internal values
- stability adjustment
- stability locking
- event controls
- mission controls
- owner controls
- travel controls
- timeline publishing
- audit history
- cleanup tools

A GM action follows this path:

```text
UI request
→ network validation
→ permission check
→ service API
→ database transaction
→ audit record
→ hook
→ network state update
→ UI confirmation
```

The UI must never write state directly.

---

## 24. UI design standards

- Use Derma and scalable layout containers.
- Avoid fixed positioning where possible.
- Support 16:9 and ultrawide resolutions.
- Define shared spacing and typography constants.
- Avoid animations that continuously run while the map is closed.
- Use tooltips for unfamiliar campaign terms.
- Clearly distinguish public information from GM-only information.
- Display a reason and source for recent state changes.
- Require confirmation for destructive actions.
- Disable controls while an action is pending.
- Show server-returned errors rather than assuming success.

---

## 25. Logging

Log levels:

```text
DEBUG
INFO
WARN
ERROR
AUDIT
```

Public API:

```lua
Convergence.Log.Debug(area, message, fields)
Convergence.Log.Info(area, message, fields)
Convergence.Log.Warn(area, message, fields)
Convergence.Log.Error(area, message, fields)
Convergence.Log.Audit(action, context, fields)
```

Logs should include:

- module
- action
- planet ID when relevant
- actor
- result
- error details
- timestamp

Do not log secrets or entire unbounded network payloads.

---

## 26. Error handling

Service methods return:

```lua
true, result
```

or:

```lua
false, errorCode, errorMessage
```

Example:

```lua
false, "planet_locked", "Planet stability is locked."
```

Use stable error codes for UI localization and command output.

Expected errors should not throw Lua exceptions. Unexpected programmer errors
should be logged with stack traces.

---

## 27. Security and abuse prevention

Required controls:

- server-authoritative state
- permission checks
- input normalization
- network rate limits
- maximum string lengths
- bounded JSON payloads
- transaction deduplication IDs
- per-source stability limits
- per-player contribution cooldowns
- event entity limits
- cleanup ownership tags
- no arbitrary client-supplied Lua
- no SQL concatenation after parameter support is available
- no client-selected reward amounts
- no client-selected admin identity

Every spawned event entity must be tagged with its event instance ID.

---

## 28. Persistence and restart recovery

At startup:

1. load configuration
2. initialize database adapter
3. run migrations
4. register planet definitions
5. ensure planet rows exist
6. load persistent planet state
7. restore active events
8. restore active missions
9. restore world changes
10. initialize integrations
11. announce database readiness
12. synchronize joining clients on demand

At shutdown:

- stop tick timers
- flush queued writes
- snapshot volatile instance state
- mark clean shutdown time
- avoid creating new events

A server crash should not silently mark active events as successful or failed.

---

## 29. Performance rules

- No full-table SQL query every Think hook.
- No per-frame net messages.
- Cache planet summary state server-side.
- Send deltas after mutations.
- Batch noncritical writes when safe.
- Use timers measured in seconds for campaign simulation.
- Paginate history.
- Limit simultaneous NPC and prop events.
- Avoid repeated SWU planet discovery after mapping is established.
- Profile before introducing broad world scans.

---

## 30. Coding standards

- Four-space indentation.
- One local service alias per file where useful.
- Use early returns.
- Use descriptive names.
- Avoid one-letter variables except simple loops.
- Public functions use PascalCase after namespace.
- Local functions use camelCase.
- Constants use upper snake case only when truly constant.
- Prefer `ipairs` for ordered arrays and `pairs` for maps.
- Validate every public function argument.
- Document public APIs with parameter and return descriptions.
- Do not silently swallow errors.
- Do not create globals outside `Convergence`.

Example:

```lua
--- Adds stability to a registered planet.
-- @param planetID string
-- @param amount number
-- @param context table
-- @return boolean success
-- @return any resultOrError
function Convergence.Stability.Add(planetID, amount, context)
end
```

---

## 31. Versioning

Use semantic versioning:

```text
MAJOR.MINOR.PATCH
```

- Patch: bug fixes without API changes.
- Minor: backward-compatible features.
- Major: breaking API, schema, or configuration changes.

Every release must include:

- changelog entry
- schema compatibility statement
- migration files
- upgrade instructions
- known issues
- tested dependencies

---

## 32. Testing checklist

Before merging a feature:

- server boots without SAM
- server boots without SWU
- server boots with SAM
- server boots with SWU
- SQLite initializes on a clean database
- existing database upgrades correctly
- state survives restart
- map change does not lose state
- unauthorized players cannot mutate state
- malformed net messages are rejected
- history records correct actor and reason
- no Lua errors during cleanup
- duplicate registration is handled
- unknown planets return a clear error
- GM UI shows server-confirmed results

---

## 33. Development phases

### Phase A — v0.1 Persistent core

- loader
- namespace
- logging
- module registry
- database abstraction
- migrations
- planet registry
- stability service
- transaction history
- networking foundation
- console test commands

### Phase B — v0.2 SAM administration

- permission provider
- SAM privileges
- SAM stability commands
- SAM history command
- GM map launcher
- audit viewer foundation

### Phase C — v0.3 SWU map integration

- SWU detection
- planet mapping
- player planet panel
- stability overlays
- GM mode
- travel adapter

### Phase D — v0.4 events and missions

- template registries
- persistent instances
- objective tracking
- restart restoration
- cleanup tools

### Phase E — v0.5 campaign systems

- factions
- ownership
- fleets
- resources
- research
- supply
- timeline

### Phase F — v1.0 campaign release

- stable public API
- complete migrations
- documentation
- recovery tools
- release packaging
- production test cycle

---

## 34. Initial API freeze

The following names are reserved and should not be changed casually:

```lua
Convergence.RegisterPlanet
Convergence.GetPlanet
Convergence.GetPlanets

Convergence.Database.Initialize
Convergence.Database.IsReady

Convergence.Stability.Get
Convergence.Stability.Set
Convergence.Stability.Add
Convergence.Stability.SetLocked
Convergence.Stability.GetHistory

Convergence.Permissions.Has

Convergence.Events.RegisterTemplate
Convergence.Missions.RegisterTemplate

Convergence.Integrations.SWU
Convergence.Integrations.SAM
```

Any breaking change to these APIs requires a major-version review or a
documented deprecation period.

---

## 35. Architectural decision record

Major design changes must be recorded under:

```text
docs/decisions/
```

Format:

```text
001-use-convergence-namespace.md
002-sqlite-first.md
003-swu-as-optional-adapter.md
```

Each decision records:

- context
- decision
- alternatives
- consequences
- date
- status

This prevents future contributors from undoing important decisions without
understanding why they were made.

---

## 36. Final rule

The framework owns persistent campaign state.

SAM, SWU, DarkRP, weapons, armor, loadouts, and future systems are clients of
the framework. They may request changes through public APIs and react through
hooks, but they must not become hidden sources of truth for the galaxy.
