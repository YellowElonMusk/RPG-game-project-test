# Story 033: Strip ChapterFlow to encounter sequencing and host it in ChapterMode

> **Epic**: Game State & Scene Flow
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (Complete)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md` (migration story: no GDD acceptance criterion)
**Requirement**: `TR-gamestate-003` (descriptor in), `TR-gamestate-004` (Retry no longer in ChapterFlow)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§7 HP/MP carryover: the party `Combatant`s are the requester's own instances; §8 and its 2026-10-23 step-list note; Migration Plan Step 2 bullet 1 and the `ChapterMode` clause of bullet 2); ADR-0010: Turn Battle System (§3 interim enemy-ID table; §5 `can_flee`; §7 transients move to the Battle mode); ADR-0012: Overworld Exploration (§8 retirement condition; the step list survives as interim data)
**ADR Decision Summary**: `ChapterFlow` keeps only encounter sequencing and builds Encounter descriptors; `ChapterMode`, a stand-in Overworld `GameMode`, requests each battle from the machine. Battle construction, the snapshot pair and the retry loop leave `ChapterFlow`.
**ADR Version**: ADR-0002 2026-10-21 (Status revised 2026-10-23 for the §8 step-list note) · ADR-0010 2026-10-22 · ADR-0012 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: `ChapterMode extends GameMode`: `@abstract` subclass, typed-return overrides need an explicit `return`, and detach tolerance on the real stand-in (verified pattern from story 014).

**Control Manifest Rules (this layer)**:
- Forbidden: "After [ADR-0002] Migration Step 2, `ChapterFlow` must not construct `BattleCore`, connect to `battle_ended`, or hold a fight-start snapshot." (The manifest's Forbidden list says "ADR-0001" here; it is a typo for ADR-0002's own Migration Plan, flagged for `/create-control-manifest update`.)
- Required: "Clearing the party's per-fight transients belongs to the Battle mode, through `BattleCore.clear_transients(party)` before `start_battle(false)`. `ChapterFlow._clear_squad_transients()` goes away."
- Required: "Mode scripts tolerate `_exit_tree()`/`_enter_tree()` without `_ready()` running again."
- Required: "Every `GameMode`/`GameOverlay` override with a typed return ends in an explicit `return`."

---

## Acceptance Criteria

*Migration story: the criterion is ADR-0002 Migration Plan Step 2, bullet 1 (+ the `ChapterMode` clause), made checkable by the derived checks below (QA RC-5).*

- [ ] **Step 2.1** — "Remove `BattleCore` construction, the `battle_ended` connection, the snapshot/restore pair and the `fight_lost` retry loop from `chapter_flow.gd`. Add descriptor building (with `retreat_allowed = false`) and an `advance_on_victory()` entry point." · "Create `ChapterMode` (stand-in Overworld) …" · "Step 0's sequencing and carryover tests must still pass unchanged; the retry tests move to the Battle mode."
  1. [ ] Story 032's test files are byte-identical and pass; only `tests/unit/chapters/chapter_flow_probe.gd` changed (asserted with `git diff --stat` in review).
  2. [ ] Grep gate: `chapter_flow.gd` contains no `BattleCore.new`, `battle_ended`, `_fight_start_snapshot`, `fight_lost`, `_clear_squad_transients`.
  3. [ ] `build_next_descriptor()` produces the pinned fields.
  4. [ ] `ChapterMode` requests BATTLE with a payload whose `party` holds the same `Combatant` instances.
  5. [ ] `on_thawed(VICTORY)` advances; `on_thawed(FLED)` repeats the fight.

---

## Implementation Notes

*Derived from ADR-0002 §7, §8, ADR-0010 §3/§5/§7 and the QA gate (RC-5):*

- **Landing group.** 033, 034 and 035 are developed and reviewed separately but land in **one commit when 035 closes** (ADR-0002 Migration Step 2: "as one story and one commit, so the playable chapter loop never breaks in between"). This state passes its own tests; the demo is not playable until 035.
- `ChapterFlow` keeps **only** sequencing: which fight is next, its roster (now `enemy_ids`), boss detection (`is_boss`), and `chapter_won`. HP/MP carryover now happens **by construction**: `BattleEntryPayload.party` holds the requester's own `Combatant` instances, changed in place (§7).
- Every descriptor: `retreat_allowed = false` (until Camp exists, so no "no camp" error is logged on each loss); `can_flee` per ADR-0010 §5 (`false` at the boss); `faction_id` = a **known faction record** ID (until content-migration story 013 ships faction records these descriptors fail validation, which is why 035 depends on it); `enemy_ids` = ADR-0010's interim IDs (`enemy_clerk`, `enemy_supervisor`, `enemy_security_drone`, `enemy_middle_manager`, `enemy_ceo`); `battle_stage_id` = an interim placeholder, recorded in Completion Notes.
- **"Unchanged" (QA RC-5).** Only the probe adapter may change. If a sequencing test would need rewriting, that is a stop: flag it to technical-director rather than editing the test. The retry test file moves to 034 (the one ADR-sanctioned move), not deleted. **The meaning of "unchanged" is owed a technical-director confirmation** in the batched ADR-0002 annotation.
- `ChapterMode` (extends `GameMode`): on a step, `machine.request_transition(Mode.BATTLE, BattleEntryPayload)`; `on_thawed(id, VICTORY)` → `advance_on_victory()`; `on_thawed(id, FLED)` → stays on the same fight. It reads movement only through `machine.get_move_vector(self)` (none today) and actions only through `handle_action()`; it never references Input.
- A Defeat never reaches `ChapterFlow`: Retry/Retreat happen entirely inside Game State and Battle.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 034: the Battle mode, `BattleFactory`, `clear_transients`, the moved retry test.
- Story 035: `GameRoot`, the demo rewrite.
- ADR-0002 Migration Step 4: retiring `ChapterMode` when the Overworld ships (Overworld epic).

---

## Files

- `src/chapters/chapter_flow.gd` (changed: removes `BattleCore` construction, `battle_ended`, `_fight_start_snapshot`/`_restore_squad_snapshot`, `fight_lost`, `_clear_squad_transients`; adds `build_next_descriptor() -> EncounterDescriptor` and `advance_on_victory()`; keeps `chapter_won`)
- `src/chapters/chapter_mode.gd`, `src/chapters/chapter_mode.tscn`
- `tests/unit/chapters/chapter_flow_probe.gd` (the only 032 file that may change)
- `tests/unit/chapters/chapter_flow_descriptor_test.gd`
- `tests/unit/chapters/chapter_mode_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fixes applied: numbered checks, probe-only change rule). The developer implements against these — do not invent new test cases during implementation.*

- **Check 3**: `chapter_flow_descriptor_test.gd :: test_descriptor_fields` (parameterized fight index 0..3, both factions)
  - Then: `encounter_id` non-empty and unique per fight; `enemy_ids` == the ADR-0010 interim IDs for that fight; `faction_id` == the faction record ID; `is_boss` true only at index 3; `can_flee` false at the boss; `retreat_allowed` false; `battle_stage_id` == the recorded placeholder.
- **Check 4**: `chapter_mode_test.gd :: test_requests_battle_with_own_party`
  - Given: `ChapterMode` set up with a recording stub machine.
  - When: the step starts.
  - Then: `request_transition(BATTLE, payload)` recorded once; `is_same(payload.party[i], squad[i])` for all i.
- **Check 5**: `test_thaw_victory_advances` / `test_thaw_fled_repeats`
  - Then: `on_thawed(id, VICTORY)` → next descriptor index +1; FLED → same index; VICTORY at the boss → `chapter_won` once.
- **Checks 1–2 (review)**: 032's test files byte-identical (`git diff --stat`), passing; grep gate on `chapter_flow.gd`.
  - Edge cases: `ChapterMode` tolerates `_exit_tree`/`_enter_tree` without a second `_ready` (counts); no Input reference (code review).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/chapters/chapter_flow_descriptor_test.gd`, `tests/unit/chapters/chapter_mode_test.gd`, and story 032's sequencing and carryover suites unchanged — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (full suite green; see Completion Notes)

---

## Completion Notes

*2026-10-28, implemented by godot-gdscript-specialist.*

- **Files**: `src/chapters/chapter_flow.gd` (stripped to sequencing: `build_next_descriptor()`, `advance_on_victory()`, `chapter_won`; no `BattleCore`, no `battle_ended`, no snapshot pair, no `fight_lost`); `src/chapters/chapter_mode.gd` + `chapter_mode.tscn` (new); `tests/unit/chapters/chapter_flow_probe.gd` (changed, per rule); `tests/unit/chapters/chapter_flow_descriptor_test.gd` (new, Check 3); `tests/unit/chapters/chapter_mode_test.gd` (new, Checks 4-5).
- **Deviations (flag for review)**:
  1. `src/chapters/chapter_flow_demo.gd`/`.tscn` **deleted**, not in the Files list. It referenced the removed `fight_started`/`fight_lost`/`current_battle` API and would not parse against the new `ChapterFlow`; Story 035 ("the demo rewrite") was already going to replace it.
  2. `tests/unit/chapters/chapter_flow_retry_test.gd` **removed from `tests/unit/chapters/`** (not rewritten in place) since the retry mechanics it pins no longer exist in `ChapterFlow`. Per Implementation Notes this test "moves to 034, not deleted" — it is not recreated here because Story 034's Battle mode doesn't exist yet; 034 should add its own version under `tests/unit/battle/`.
  3. `tests/unit/chapters/chapter_flow_carryover_test.gd`'s transient-clear test still passes only because `chapter_flow_probe.gd`'s `win_current()` now clears the squad's transient flags itself, standing in for the Battle mode's future `BattleCore.clear_transients(party)` call (documented in the probe's class doc comment) — not a ChapterFlow behavior.
  4. `ChapterMode` never calls `request_transition()` from `setup()`/`on_thawed()` directly (both run while `GameStateMachine._phase` is still `SWAP`, confirmed by reading `game_state_machine.gd`, which would hit the busy gate). It connects once to `machine.transition_finished` in `setup()` and requests the next fight only once that fires with `OVERWORLD` (phase already `IDLE` by then). This is implied, not spelled out, by the story's Implementation Notes — flagging for technical-director confirmation alongside the "unchanged" annotation the story already owes.
- **Recorded placeholders**: `EncounterDescriptor.battle_stage_id` = `ChapterFlow.BATTLE_STAGE_ID_INTERIM` = `"stage_chapter_interim"`.
- **Test evidence**: `godot --headless --path . --import` clean (no parse errors); full gdUnit4 suite green at 567/567 (558 baseline − 1 retry test moved out + 8 descriptor param cases + 1 uniqueness test + 3 ChapterMode tests − 2 carryover/sequencing unchanged... net +9 test cases, 0 failures, 0 errors, 0 orphans).
- **Owed**: technical-director confirmation of the "unchanged" scope for 032's suites (per Implementation Notes) and of the `transition_finished`-deferred request pattern; Story 034 to recreate the retry test under `tests/unit/battle/`.

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-013-invalid-descriptor-stays-in-overworld.md`, `production/epics/game-state-scene-flow/story-014-overworld-snapshot-exact-restore.md`, `production/epics/game-state-scene-flow/story-032-chapter-flow-characterization.md`
- Unlocks: `production/epics/game-state-scene-flow/story-034-battle-mode-wraps-battle-core.md`, `production/epics/game-state-scene-flow/story-035-game-root-main-scene.md`

---

## Completion Notes

**Completed**: 2026-10-29
**Criteria**: 1/1 passing (Step 2.3, the ChapterFlow/ChapterMode half)
**Deviations**: `src/chapters/chapter_flow_demo.gd`/`.tscn` were deleted here (not in the story's Files list) because they referenced the removed `fight_started`/`fight_lost`/`current_battle` API and would not parse against the stripped `ChapterFlow`; story 035 rewrote them (confirmed landed in the same commit). `tests/unit/chapters/chapter_flow_retry_test.gd` was removed, not rewritten, since the retry mechanics it pinned no longer exist in `ChapterFlow`; story 034 recreated the retry characterization under `tests/unit/battle/` (confirmed). Landed in one squashed commit with stories 034 and 035 (`76233f3`), per this story's own Implementation Notes ("lands in one commit when 035 closes").
**Test Evidence**: `tests/unit/chapters/chapter_flow_descriptor_test.gd`, `chapter_mode_test.gd` — confirmed passing in the full suite (581/581, 0 failures, 2026-10-29)
**Reviewed by**: self, no independent review (lean mode — LP-CODE-REVIEW and QL-TEST-COVERAGE skipped)
