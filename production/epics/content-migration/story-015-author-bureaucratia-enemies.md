# Story 015: `enemy_clerk` and `enemy_supervisor` exist as Enemy records whose stat blocks, boss flag, faction and named attacks equal the shipped Bureaucratia roster (merged with story 016)

> **Epic**: Content Migration
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-28

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Migration Step 2). Also ADR-0011: Faction Rule Modifiers (§5, "rosters become `Enemy` records with `faction_id`") and ADR-0007: Stats & Damage Resolution (§7).
**ADR Decision Summary**: The shipped Bureaucratia roster becomes Enemy records with ID-only references to their faction and moves, moved exactly as shipped.
**ADR Version**: ADR-0001 2026-10-23 · ADR-0011 2026-10-22 · ADR-0007 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Load records in tests with `ResourceLoader.load(path, "", CACHE_MODE_IGNORE)`.

**Control Manifest Rules (this layer)**:
- Required: "One record = one `.tres` file at `data/[type_plural]/[id].tres`; the filename without extension must equal the record's `id`."
- Required: "Every required field has an enforced validity rule."
- Forbidden: "Never use `@export var x: OtherResourceType` for a cross-reference."
- Guardrail: none.

---

## Acceptance Criteria

*Migration criterion from ADR-0001 Migration Step 2 and ADR-0011 §5, scoped to this story:*

- [ ] GIVEN `data/enemies/enemy_clerk.tres` and `enemy_supervisor.tres`, WHEN loaded, THEN `display_name`, `stat_block` (Clerk 40/0/11/6/8; Supervisor 110/0/15/10/9), `is_boss` (false / true), `faction_id = faction_bureaucratia`, `move_ids` (Clerk: `move_pen_jab`, `move_red_tape`, `move_late_fee`; Supervisor: `move_pen_jab`, `move_red_tape`, `move_mass_audit`, `move_final_notice`), `reward = {xp 0, money 0}`, `sprite_set_id = "sprite_placeholder"` and `ai_profile_id = ""` equal the pins.

*Merged from story 016, 2026-10-24:*

*Migration criterion from ADR-0001 Migration Step 2 and ADR-0011 §5, scoped to this story:*

- [ ] GIVEN `data/enemies/enemy_security_drone.tres`, `enemy_middle_manager.tres` and `enemy_ceo.tres`, WHEN loaded, THEN stat blocks (36/0/12/8/10; 44/0/10/6/8; 120/0/15/10/9), `is_boss` (CEO only), `faction_id = faction_megacorp`, `move_ids` (Drone: `move_laser_scan`; Middle Manager: `move_upsell`; CEO: `move_layoffs`, `move_hostile_takeover`), `reward = {xp 0, money 0}`, `sprite_set_id = "sprite_placeholder"` and `ai_profile_id = ""` equal the pins.

---

## Implementation Notes

*Derived from ADR-0001 Migration Step 2, the draft's Q9/Q10 resolutions and the QA gate (RC-3):*

- **The Supervisor is moved exactly as shipped** (110 HP, 15 ATK, 10 DEF, 9 SPD). If a reviewer suggests "while we're here…", the answer is the open balance question, not this story. Content is never retuned.
- `move_ids` lists every move the AI can emit for that enemy, in the order the rule's branches use them. Today the moves are not data on the combatant (the rule builds them). The list documents and validates reachability; the **rule's params** (story 017) decide which one is used, so the AI never reads `move_ids`. Record that split.
- `ai_profile_id` is a *reserved* reference (Enemy AI). Leave it empty; don't create a stub type.
- `sprite_set_id = "sprite_placeholder"` unless real sets exist. ADR-0005 maps the placeholder to a checkerboard; a missing sprite set would fail a Presentation `sprite_set_exists` validator, which story 021 surfaces.
- **Reward (Q10).** `reward = {xp = 0, money = 0}`: "as-is" (today nobody earns anything) and inside 0–9999. The economy designer sets real values later.
- **Ranges are not asserted here.** Range checks belong to the owners' validators (stories 012, 020, 021); asserting literal bounds here would duplicate the owner's range (TR-content-011 is not this story's).
- **Expected values (RC-3).** Stats and display names assert against the frozen `CharacterizationExpected`; record-only values (`faction_id`, `move_ids`, `reward`, `sprite_set_id`) go in `MigratedRecordsExpected` (not under story 009's gate).
- Records go under `data/enemies/<id>.tres`, reference their script under `src/data/records/` by path, and are never written by code at runtime. Cases go in the shared `battle_migrated_records_test.gd`.

*Merged from story 016, 2026-10-24:*

*Derived from ADR-0001 Migration Step 2 and the QA gate (RC-3); same rules as story 015:*

- **Content is moved as-is and never retuned.**
- The display name "Middle Manager" is still authored exactly, because the HUD shows it, but after story 026 nothing branches on it.
- `move_ids` documents and validates reachability; the rule's params (story 017) decide which move is used, so the AI never reads `move_ids`.
- `ai_profile_id` stays empty (reserved). `sprite_set_id = "sprite_placeholder"` unless real sets exist (ADR-0005 checkerboard). `reward = {0, 0}` (Q10).
- Ranges are not asserted here (owners' validators, stories 012, 020, 021).
- **Expected values (RC-3).** Stats and display names assert against the frozen `CharacterizationExpected`; record-only values go in `MigratedRecordsExpected` (not under story 009's gate).
- Records go under `data/enemies/<id>.tres`, reference their script under `src/data/records/` by path, and are never written by code at runtime. Cases go in the shared `battle_migrated_records_test.gd`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 016: the MegaCorp enemies.
- Story 020: `reward` range validation.
- Story 024: the roster adapter.

---

## Files

- `data/enemies/enemy_clerk.tres`, `enemy_supervisor.tres`
- `data/enemies/enemy_security_drone.tres`, `enemy_middle_manager.tres`, `enemy_ceo.tres` (merged story 016)
- `tests/unit/battle/fixtures/migrated_records_expected.gd` (enemy block)
- `tests/unit/battle/battle_migrated_records_test.gd` (enemy cases)

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revisions applied: F1-range clause and TR-content-011 dropped; `sprite_set_id = sprite_placeholder`; `ai_profile_id = ""`; `MigratedRecordsExpected` (RC-3)). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Clerk and Supervisor records.
  - Given: both `.tres` files.
  - Then: `display_name` and `stat_block` equal the frozen fixture (Clerk 40/0/11/6/8, Supervisor 110/0/15/10/9); `is_boss` F/T; `faction_id == "faction_bureaucratia"`; `move_ids` equals the pinned ordered lists; `reward == {xp 0, money 0}`; `sprite_set_id` as pinned.
  - Edge cases: each move emitted in story 006's Bureaucratia scenarios maps by name to an ID in that enemy's `move_ids`, so the reachability claim is a test.

*Merged from story 016, 2026-10-24:*

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revisions applied as story 015: F1-range clause and TR-content-011 dropped; `sprite_set_id = sprite_placeholder`; `MigratedRecordsExpected`). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Three MegaCorp enemy records.
  - Given: the three `.tres` files.
  - Then: as story 015, with 36/0/12/8/10, 44/0/10/6/8 and 120/0/15/10/9 (CEO boss), `faction_id == "faction_megacorp"`, and `move_ids` Drone [`move_laser_scan`], Manager [`move_upsell`], CEO [`move_layoffs`, `move_hostile_takeover`].
  - Edge cases: the "Middle Manager" display name is exact. Each move emitted in story 006's MegaCorp scenarios maps by name to an ID in that enemy's `move_ids`.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Config/Data
**Required evidence**:
- Config/Data: smoke check pass (`production/qa/smoke-*.md`). Gate level: ADVISORY.
- Supporting: the Bureaucratia enemy cases in `tests/unit/battle/battle_migrated_records_test.gd` pass.

**Status**: [ ] Not yet created

*Merged from story 016, 2026-10-24:*

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Config/Data
**Required evidence**:
- Config/Data: smoke check pass (`production/qa/smoke-*.md`). Gate level: ADVISORY.
- Supporting: the MegaCorp enemy cases in `tests/unit/battle/battle_migrated_records_test.gd` pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-003-characterize-bureaucratia-roster.md`, `story-013-author-faction-records.md`, `story-014-author-enemy-named-attack-moves.md`
- Unlocks: `production/epics/content-migration/story-017-author-faction-rule-records.md`, `story-020-enemy-reward-range-validation.md`, `story-021-migrated-set-validates-clean.md`, `story-024-bureaucratia-roster-adapter.md`

## Completion Notes
**Completed**: 2026-10-28
**Criteria**: 2/2 passing
**Deviations**: Implemented together with stories 014 and 017 (see story 014's Completion Notes). Smoke report (`production/qa/smoke-2026-10-23.md`) predates these files; re-run `/smoke-check`. ADR-0007 §7's stat-block range validators are not registered yet (Stats epic doesn't exist) — ranges are not asserted here, by this story's own design, not a gap.
**Test Evidence**: `tests/unit/battle/battle_migrated_records_test.gd` — exists and passes (full suite: 313/313, 0 errors, 0 failures, 0 orphans)
**Reviewed by**: `/code-review` (self-invoked this session, covering stories 014/015/017 together) — APPROVED
