# Story 023: Each enemy named attack the rules emit is built from its Move record by one adapter, and the Step 0 suite passes unchanged

> **Epic**: Content Migration
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-006`, `TR-turnbattle-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (EffectDescriptor adapter: "each static factory becomes an adapter… constructs today's runtime `Move`/`Combatant` objects exactly as it does now"; Migration Step 3). Also ADR-0010: Turn Battle System (§8: "ADR-0001's migration maps each EffectDescriptor `type` … to one category/effect pair").
**ADR Decision Summary**: One pure adapter maps a Move record's single EffectDescriptor to today's runtime `Move` (category, special effect, power, rounds). `BattleCore` never sees a record.
**ADR Version**: ADR-0001 2026-10-23 · ADR-0010 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "Static factories become adapters: they read the catalog record and build today's runtime `Move` / `Combatant` objects. `BattleCore` never touches a catalog record."
- Forbidden: "Never mutate a record's fields after load, or use a record as live runtime state."
- Guardrail: the adapter runs at construction time, never per frame.

---

## Acceptance Criteria

*Migration criterion from ADR-0001 Migration Step 3 and ADR-0010 §8, scoped to this story:*

- [ ] GIVEN `MoveAdapter.from_record(record: MoveData) -> Move`, WHEN both rules build their named attacks through it from the catalog, THEN story 009's gate passes (005 and 006 green, unchanged), and the adapter's own test maps each of the six descriptor types to its pinned `category`/`special_effect`/`power`/`effect_rounds`, and maps an unregistered type to an error (`push_error`, returns `null`), never to a silent `NONE`.

---

## Implementation Notes

*Derived from ADR-0001 EffectDescriptor adapter and ADR-0010 §8:*

- The map (one `match`; ADR-0010 §8: "a new effect type means a new enum value, a new `match` arm, a new registration and a test"):

  | `type` | `category` | `special_effect` | `power` | `effect_rounds` |
  |---|---|---|---|---|
  | `damage` | ATTACK | NONE | `power` | 0 |
  | `stun` | SPECIAL | STUN | 0 | 0 |
  | `heal_party` | SPECIAL | HEAL_PARTY | `power` | 0 |
  | `heal_single` | SPECIAL | HEAL_SINGLE | `power` | 0 |
  | `damage_debuff` | SPECIAL | DAMAGE_DEBUFF | 0 | `rounds` |
  | `direct_damage` | SPECIAL | DIRECT_DAMAGE | `power` | 0 |

- `target_type` string → `Move.TargetType`; `cost` → `mp_cost`; `display_name` copied. A record with more than one descriptor is an error today: the runtime `Move` holds one effect, so the adapter refuses rather than dropping the extra.
- **Where the catalog comes from in the rules.** Rules are stateless, configured once (ADR-0011 §2). Until story 026, the rules read the catalog autoload in their named-attack builder: the ADR-0001 autoload exception (parameterless factories can't take an injected catalog). Story 026 moves it into `_configure()`.
- The adapter reads values and copies them. It never holds the record (a shared cached `Resource`).
- **Seam edit:** `seam.move(id)` for named attacks now goes through the adapter. If this story lands before 024, add `BattleContentSeam.ensure_catalog()` here: it runs `ContentBootstrap.run(ContentCatalog)` once per test process (a no-op once not UNLOADED), and every seam builder calls it. That is a test-harness call (the allowance ADR-0004 gives harness scenes), **not** lazy-loading in production code, which the manifest forbids; production factories never trigger a load and fail loudly if the catalog isn't READY.
- **Closing condition:** story 009's gate passes, with the Step 0 suite green and its files' hashes unchanged. If a characterization test fails, the adapter is wrong; editing the test or the frozen fixture is never the fix. Re-run the suite in a fresh process, never in the editor session that authored the `.tres` files (`CACHE_MODE_REUSE`).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 026: `_configure()` and rules reading their move IDs from params.
- Story 028: the specials' factories through this adapter.
- Story 030/031: deleting `_named_attack()` and the power constants.

---

## Files

- `src/battle/move_adapter.gd` (`class_name MoveAdapter`, static, pure)
- `src/battle/factions/bureaucratia.gd`, `src/battle/factions/megacorp.gd` (`_named_attack(name, power)` → `MoveAdapter.from_record(catalog.get_record(&"move", id))`)
- `tests/unit/battle/helpers/battle_content_seam.gd` (seam edit; `ensure_catalog()` if first)
- `tests/unit/battle/battle_move_adapter_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Six types map; the gate passes.
  - **Test: six types map.**
    - Given: in-memory `MoveData` per type (no file I/O).
    - When: `MoveAdapter.from_record`.
    - Then: `category`, `special_effect`, `power`, `effect_rounds`, `mp_cost`, `target_type` and `display_name` equal the table.
    - Edge cases: an unknown type gives `null` plus a `push_error` (assert with gdUnit `assert_error`), never NONE. Two descriptors are refused and give `null`. A missing `power` on stun gives 0. Mutating the returned Move leaves the record unchanged.
  - **Test: 009 gate.**
    - Then: 005 and 006 are green and the hash manifest is unchanged.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_move_adapter_test.gd` — must exist and pass, and story 009's gate passes. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-009-characterization-regression-gate.md`, `story-014-author-enemy-named-attack-moves.md`, `story-021-migrated-set-validates-clean.md`
- Unlocks: `production/epics/content-migration/story-026-faction-rule-decisions-from-records.md`, `story-028-squad-specials-adapter.md`
