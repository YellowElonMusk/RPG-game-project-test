# Architecture Traceability Index
Last Updated: 2026-10-21
Engine: Godot 4.7.2

## Coverage Summary
- Total requirements: 35
- Covered: 6 (17%)
- Partial: 10
- Gaps: 19

Coverage counts only **Accepted** ADRs. The one ADR is ADR-0001 (Content Data storage format, Accepted).

## Full Matrix

| Requirement ID | GDD | System | Requirement | ADR Coverage | Status |
|---|---|---|---|---|---|
| TR-content-001 | content-data-definitions.md | Content Data | Record types, permanent prefixed snake_case IDs, aliases | ADR-0001 | ✅ |
| TR-content-002 | content-data-definitions.md | Content Data | Unloaded → Loading → Validating → Ready \| Failed, terminal | ADR-0001 | ✅ |
| TR-content-003 | content-data-definitions.md | Content Data | Full-set validation, two severities, headless check | ADR-0001 | ⚠️ Partial: headless script conflicts with autoload `load_all()`; raw-text unknown-field check fails in exported builds |
| TR-content-004 | content-data-definitions.md | Content Data | `get_record` / `has_record` / `all_records` / `resolve_alias` | ADR-0001 | ✅ |
| TR-content-005 | content-data-definitions.md | Content Data | ID-only references; asset IDs, never paths | ADR-0001 | ✅ |
| TR-content-006 | content-data-definitions.md | Content Data | Data-only records; vocabulary registered before validation | ADR-0001 | ⚠️ Partial: registration cannot run before `load_all()` in the autoload's own `_ready()` |
| TR-content-007 | content-data-definitions.md | Content Data | Immutable after Ready; caller mutation never leaks (AC-5) | ADR-0001 | ⚠️ Partial: shared cached Resources, protected by discipline only |
| TR-content-008 | content-data-definitions.md | Content Data | Structured entries, deterministic order, error screen, log | ADR-0001 | ⚠️ Partial: "report every problem" covered; entry shape, order, screen and log are not |
| TR-content-009 | content-data-definitions.md | Content Data | Boot waits for Ready; Failed never reaches gameplay | ADR-0001 | ✅ |
| TR-content-010 | content-data-definitions.md | Content Data | 500 records, median < 1.0 s (provisional) | ADR-0001 | ⚠️ Partial: ADR calls load "negligible", no budget |
| TR-content-011 | content-data-definitions.md | Content Data | Ranges read from the owner's constants | ADR-0001 | ✅ |
| TR-content-012 | content-data-definitions.md | Content Data | Player-visible strings extractable for localization | — | ❌ Gap |
| TR-gamestate-001 | game-state-scene-flow.md | Game State | Mode + overlay stack, 6 ordered signals | — | ❌ Gap |
| TR-gamestate-002 | game-state-scene-flow.md | Game State | One transition at a time, input lock, rollback | — | ❌ Gap |
| TR-gamestate-003 | game-state-scene-flow.md | Game State | Overworld freeze/restore; Encounter descriptor | — | ❌ Gap |
| TR-gamestate-004 | game-state-scene-flow.md | Game State | Retry vs Retreat | — | ❌ Gap (overlaps shipped `ChapterFlow`) |
| TR-gamestate-005 | game-state-scene-flow.md | Game State | Boot waits on catalog; Content Error mode | ADR-0001 | ⚠️ Partial: ADR covers the wait, not the Content Error mode |
| TR-gamestate-006 | game-state-scene-flow.md | Game State | Data-driven timings, injectable clock/loader | — | ❌ Gap |
| TR-input-001 | input-system.md | Input | 8 actions; bindings as a Content Data record | ADR-0001 | ⚠️ Partial: format applies; no bindings record type defined |
| TR-input-002 | input-system.md | Input | Radial deadzone, menu repeat, injectable clock | — | ❌ Gap |
| TR-input-003 | input-system.md | Input | Device identity by event type / `DEVICE_ID_*` (4.7) | — | ❌ Gap (HIGH engine risk) |
| TR-input-004 | input-system.md | Input | Device lost/restored, focus broadcasts | — | ❌ Gap |
| TR-input-005 | input-system.md | Input | `active_device_changed(kind, pad_style)` | — | ❌ Gap |
| TR-input-006 | input-system.md | Input | No dependency on Game State; pointer to UI, dual focus | — | ❌ Gap |
| TR-stats-001 | stats-damage-resolution.md | Stats & Damage | F2–F8 pipeline, injected constants, < 50 µs | — | ❌ Gap (implemented; retroactive ADR) |
| TR-stats-002 | stats-damage-resolution.md | Stats & Damage | RNG injected, never global | — | ❌ Gap (implemented; retroactive ADR) |
| TR-stats-003 | stats-damage-resolution.md | Stats & Damage | Modifier/override registration by priority | — | ❌ Gap (not implemented) |
| TR-stats-004 | stats-damage-resolution.md | Stats & Damage | Apply-only HP writes; one outcome record per resolution | — | ❌ Gap |
| TR-stats-005 | stats-damage-resolution.md | Stats & Damage | Ranges validated by catalog; no max_hp/max_mp modifiers | ADR-0001 | ⚠️ Partial: range validation covered; the modifier ban is not |
| TR-turnbattle-001 | turn-battle-system.md | Turn Battle | RefCounted state machine, signal-only presentation | — | ❌ Gap (implemented; retroactive ADR) |
| TR-turnbattle-002 | turn-battle-system.md | Turn Battle | Ordered gates; rejected submit returns null | — | ❌ Gap (implemented; retroactive ADR) |
| TR-turnbattle-003 | turn-battle-system.md | Turn Battle | Encounter in; Victory / Fled / Defeat + results-done out | — | ❌ Gap |
| TR-turnbattle-004 | turn-battle-system.md | Turn Battle | Factories replaced by records via the adapter | ADR-0001 | ⚠️ Partial: ADR defines the adapter; migration not done |
| TR-factionrules-001 | faction-rule-modifiers.md | Faction Rules | Stateless 9-method FactionRule contract | — | ❌ Gap (implemented; retroactive ADR) |
| TR-factionrules-002 | faction-rule-modifiers.md | Faction Rules | `rule_id` → class registry owned by Faction Rules | ADR-0001 | ⚠️ Partial: ownership decided, mechanism undefined |

## Known Gaps

| Gap | Suggested ADR | Layer | Engine Risk |
|---|---|---|---|
| TR-gamestate-001..006 | `/architecture-decision game-state-scene-flow` (must also settle the `ChapterFlow` overlap) | Foundation | MEDIUM |
| TR-input-001..006 | `/architecture-decision input-system` | Foundation | HIGH (4.7 device IDs, 4.6 dual focus, SDL3 pad style) |
| TR-content-003/006/007 | Amend ADR-0001 (see the review report) | Foundation | HIGH |
| TR-factionrules-001/002 | Retroactive Faction Rule Modifiers ADR (before ADR-0001's migration) | Feature | LOW |
| TR-stats-001..004 | Retroactive Stats & Damage ADR (also resolve the modifier/override hook) | Core | LOW |
| TR-turnbattle-001..003 | Retroactive Turn Battle ADR (also the Game State outcome handshake) | Feature | LOW |
| TR-content-012 | Localization ADR, deferred to before Alpha (GDD Open Question 2) | Foundation | LOW |

## Superseded Requirements

None. This is the first registered baseline.
