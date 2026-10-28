# Story 034: Battle mode wraps BattleCore and BattleHud and owns the start snapshot

> **Epic**: Game State & Scene Flow
> **Status**: Ready (lands in one commit with 033 and 035, when 035 closes)
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-28 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md` (migration story: no GDD acceptance criterion)
**Requirement**: `TR-gamestate-004` (snapshot hooks), `TR-gamestate-003` (built from the descriptor)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§7: snapshot after `BattleCore` is built, `null` = swap failure, HP/MP carryover contract, `start_battle(false)` only; Migration Plan Step 2 bullet 2, Battle mode clause); ADR-0006: Battle Replay Ownership (§5 first-entry call order, Retry order, Exit order, end-of-fight holds; outcome reported only after the replay's last beat); ADR-0010: Turn Battle System (§3 `BattleFactory.build`, the interim enemy-ID table, one RNG per instance not restored on Retry; §5 reporting; §6; §7 `clear_transients`)
**ADR Decision Summary**: A Battle mode scene wraps `BattleCore` + `BattleHud`, builds the fight through `BattleFactory` from the descriptor, clears party transients, starts with `start_battle(false)`, implements `capture_start_snapshot`/`restore_start_snapshot`, and reports outcomes to the machine.
**ADR Version**: ADR-0002 2026-10-21 · ADR-0006 2026-10-22 · ADR-0010 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: `GameMode` subclass with typed-return overrides; `BattleHud` as a child of a mode scene under a disabled `ModeHost` shares story 025's verification item.

**Control Manifest Rules (this layer)**:
- Required: "Under Game State the Battle mode must call `BattleCore.start_battle(false)`, never `retry_battle()`."
- Required: "Clearing the party's per-fight transients belongs to the Battle mode, through `BattleCore.clear_transients(party)` before `start_battle(false)`."
- Forbidden: "Never call `BattleCore.retry_battle()` for Retry under Game State — it full-heals the squad."
- Required: "`mode_entered(BATTLE)` still fires on a same-mode (Retry) row, but listeners must not re-apply entry state …"

---

## Acceptance Criteria

*Migration story: the criterion is ADR-0002 Migration Plan Step 2, bullet 2 (Battle mode clause), made checkable by the derived checks below (QA RC-5).*

- [ ] **Step 2.2** — "… a Battle mode scene wrapping `BattleCore` + `BattleHud` that implements the snapshot hooks and the carryover contract …", with "the retry tests move to the Battle mode."
  1. [ ] Entry builds through `BattleFactory`, clears transients before start, and `capture_start_snapshot()` returns a non-null `BattleStartSnapshot`.
  2. [ ] Retry restores party HP/MP/items/states and the enemy group on the same `BattleCore`, with zero scene loads.
  3. [ ] Victory: the outcome is reported before the end banner shows, `report_results_done` only after confirm on the banner, and carryover damage persists on the requester's own `Combatant`s.
  4. [ ] A boss-count failure (0 or 2 boss enemies on `is_boss`) fails `setup()` and rolls back to the Overworld with no orphans.
  5. [ ] Story 032's retry test, moved to `tests/unit/battle/battle_mode_snapshot_test.gd`, passes with unchanged expected values.
  6. [ ] Grep gates: no `retry_battle(` or `start_battle()` without `false` in `battle_mode.gd`; no `BattleCore.new` outside `battle_factory.gd` and the two harnesses.

---

## Implementation Notes

*Derived from ADR-0002 §7, ADR-0006 §5, ADR-0010 §3/§5/§7 and the QA gate (RC-5):*

- **Landing group:** lands in one commit with 033 and 035 when 035 closes.
- **First-entry call order** (ADR-0006 §5, simplified while no replay controller exists): build through `BattleFactory` → `BattleCore.clear_transients(party)` → boss resolution if `is_boss` (zero or several boss enemies → swap failure → rollback) → `start_battle(false)` → (the machine calls) `capture_start_snapshot()`. Steps involving `BattleReplayController` are N/A until ADR-0006 ships; leave TODO markers at their positions.
- **Retry** (`restore_start_snapshot`): restore party HP/MP and clear transients → `start_battle(false)`. Never `start_battle()` or `retry_battle()` (both full-heal). The light request and the `is_transition_flash_capped()` blend choice (ADR-0006 §5 step 3) belong to Presentation; leave a TODO.
- **Carryover:** the party `Combatant`s are the requester's instances, changed in place.
- **Reporting:** Victory → `report_battle_outcome(VICTORY)` → results screen (interim: BattleHud's end banner, dismissed by `confirm`) → `report_results_done()`. Defeat → `report_battle_outcome(DEFEAT)`. **Fled is not wired** until `battle_fled` exists (ADR-0010 §5); leave a TODO (AC-13 is covered at machine level by 016). With no replay today, reporting on `battle_ended` satisfies "after the last beat" trivially; document it as interim.
- **RNG:** one per Battle-mode instance, not restored on Retry (ADR-0010 §3; GDD OQ-2 pending).
- **Deterministic outcome driving (QA):** each test pins one method, either a seeded RNG with fixture combatants and scripted `submit_action`, or the external `battle_ended.emit` for reporting-order cases.
- **Cross-domain (accepted):** this story adds the minimal `BattleFactory` (with ADR-0010's interim enemy-ID → factory table) and `BattleCore.clear_transients(party)`; Turn Battle (gameplay-programmer) reviews. Content-migration story 029 later makes `BattleFactory` read enemy records and deletes the interim table.
- `battle_debug_harness.tscn` and `battle_hud_demo.tscn` stay as standalone harnesses and may keep calling `retry_battle()` (harness-only).
- Player-observable: the run-and-observe screenshot is taken under 035, once the Battle mode is reachable.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 035: `GameRoot` and the demo.
- Story 041 / content-migration 029: removing the interim enemy table and flag.
- The Battle Replay epic (ADR-0006): the replay controller's gate, takeover and resync.

---

## Files

- `src/battle/battle_mode.gd`, `src/battle/battle_mode.tscn` (extends `GameMode`)
- `src/battle/battle_start_snapshot.gd` (`RefCounted`: party HP/MP, items, states, enemy group)
- `src/battle/battle_factory.gd` (minimal, with ADR-0010's interim table; cross-domain)
- `src/battle/battle_core.gd` (adds `clear_transients(party)`; cross-domain)
- `tests/unit/battle/battle_mode_snapshot_test.gd` (the moved 032 retry test)
- `tests/integration/game_state/game_state_battle_mode_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fixes applied: numbered checks, deterministic outcome driving, grep gates). The developer implements against these — do not invent new test cases during implementation.*

- **Check 1**: `game_state_battle_mode_test.gd :: test_entry_builds_and_snapshots`
  - Given: the real `GameStateMachine` + production loader + `battle_mode.tscn`; a descriptor with interim enemy IDs; a fixture party.
  - When: Overworld (stub) → Battle.
  - Then: `capture_start_snapshot()` returns a non-null `BattleStartSnapshot`; party transients cleared before start; `BattleCore` built only via `BattleFactory`.
- **Check 2**: `test_retry_restores`
  - When: damage the party and kill one enemy, report Defeat, `choose_retry`.
  - Then: party hp/mp/items/states equal the snapshot; the enemy group is back at start values; `BattleCore` `is_same` before/after; counting-loader `begin_swap == 0`.
- **Check 3**: `test_victory_carryover_and_report_order`
  - When: a deterministic win.
  - Then: `report_battle_outcome(VICTORY)` recorded before the end banner shows; `report_results_done` only after a synthetic confirm on the banner; after return, `is_same(party[i], requester squad[i])` and damage taken persists.
- **Check 4**: `test_boss_count_failure_rolls_back`
  - Then: `is_boss` with 0 or 2 boss enemies → `setup` fails → the machine is back in OVERWORLD, error logged, no orphans.
- **Check 5**: `battle_mode_snapshot_test.gd` (unit; the moved 032 retry file) — expected values unchanged from 032.
- **Check 6 (review)**: grep gates as listed in the criterion.
  - Edge cases: Fled wiring is a TODO (016 covers AC-13).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/game_state/game_state_battle_mode_test.gd` — must exist and pass. Gate level: BLOCKING.
- Logic (moved): `tests/unit/battle/battle_mode_snapshot_test.gd` — must pass.

**Status**: [x] Created and passing. Full suite: 575/575, 0 errors, 0 failures, 0 orphans (`godot --headless -s -d GdUnitCmdTool.gd -a res://tests`, exit 0).

---

## Completion Notes

*2026-10-28, implemented by godot-gdscript-specialist.*

- **Files**: `src/battle/battle_mode.gd` + `battle_mode.tscn` (new, extends `GameMode`, hosts `BattleHud` as `%BattleHud`); `src/battle/battle_start_snapshot.gd` (new, `RefCounted`: `party_hp`/`party_mp` arrays, captured/restored by index); `src/battle/battle_factory.gd` (new, minimal `BattleFactory.build()` + inner `BattleBuildResult`, with ADR-0010 §3's interim enemy-ID and faction-id tables); `src/battle/battle_core.gd` (added `static func clear_transients(party)`); `tests/unit/battle/battle_mode_snapshot_test.gd` (new, the moved 032/033 retry test, driving `BattleMode` directly with no `GameStateMachine`); `tests/integration/game_state/game_state_battle_mode_test.gd` (new, Checks 1-4, real `GameStateMachine` + `ModeHostSceneLoader` + `battle_mode.tscn`, `stub_overworld_mode.tscn` for OVERWORLD).
- **Call order implemented** (ADR-0006 §5 simplified per this story's own Implementation Notes, since no `BattleReplayController` exists yet): `setup()` → `BattleFactory.build()` → `BattleCore.clear_transients(party)` → boss-count check (`is_boss` with != 1 boss enemy → leaves `_battle = null`, which fails `capture_start_snapshot()` and rolls back) → connect `battle_ended` → `start_battle(false)` → `hud.setup(battle)`. Connecting `battle_ended` *before* `hud.setup()` is what guarantees `report_battle_outcome()` is recorded before the HUD's own `battle_ended` handler repaints the end banner (Check 3) — signal listeners run in connection order.
- **Reporting**: Victory sets `_awaiting_results_done` and calls `report_battle_outcome(VICTORY)` at once (no replay hold, TODO'd); `handle_action()` calls `report_results_done()` only on a `confirm` press while that flag is set. Defeat reports at once. Fled is not wired (TODO, matches the story's own scope note — AC-13 is machine-level, story 016).
- **Retry**: `restore_start_snapshot()` restores party HP/MP from the snapshot, clears transients, and calls `start_battle(false)` again on the same `BattleCore` — never `start_battle()` or `retry_battle()`. The enemy roster needs no snapshot of its own: `BattleCore.start_battle()` unconditionally `reset_for_battle()`s every enemy on every call, so Retry's fresh full-HP roster is already guaranteed by the existing contract.
- **Deviations (flag for review)**:
  1. `BattleStartSnapshot` captures only `party_hp`/`party_mp`, not items or an explicit enemy-group snapshot. No inventory system exists yet (TODO, later story); the enemy group needs no snapshot per the point above. Documented in the class's own doc comment.
  2. Every ADR-0006 §5 step that names `BattleReplayController` (reveal gate, takeover hold, `resync()`, the retry-flash light hand-off, `cancel_pending_replay()`) is left as an inline `# TODO` comment at its position in `battle_mode.gd`, per this story's Implementation Notes ("Steps involving BattleReplayController are N/A until ADR-0006 ships").
  3. `BattleFactory.build()` takes `(payload, rng)` only — no `catalog`/`FactionRuleRegistry`/`StatsConfig`/`TurnBattleConfig` parameters — since none of those exist in this codebase yet; ADR-0010's full signature is content-migration story 029's job once the enemy-record migration lands. `BattleBuildResult` is a nested class inside `battle_factory.gd` rather than its own file, to stay within the story's Files list.
  4. Check 3's "report_battle_outcome recorded before the end banner shows" is verified by construction (connection order, see above) plus a runtime check that `pending_outcome == VICTORY` while `current_mode` is still `BATTLE` (pre-confirm) — not a signal-level trace of the HUD's own banner repaint, which would need a deeper hook into `BattleHud` than this story's scope covers.
- **Test evidence**: `godot --headless --path . --import` clean, no parse errors. Full gdUnit4 suite green at 575/575 (570 baseline + 5 new: 1 unit `battle_mode_snapshot_test.gd` + 4 integration `game_state_battle_mode_test.gd`), 0 errors, 0 failures, 0 orphans, exit 0. One orphan fix during implementation: `test_entry_builds_and_snapshots`/`test_retry_restores` never leave BATTLE, so the frozen `StubOverworldMode` (detached, not destroyed, on Overworld -> Battle per ADR-0002 §4) was never reattached by a round trip; both now call `loader.free_frozen_overworld()` at the end, the same call production makes on Retreat/Quit to Title.
- **Owed**: Check 6's grep gates (no `retry_battle(`/`start_battle()` without `false` in `battle_mode.gd`; no `BattleCore.new` outside `battle_factory.gd` and the two harnesses) are a review-time check, not run here — a reviewer should confirm them before `/story-done`. Cross-domain review by gameplay-programmer of `BattleCore.clear_transients()` and `BattleFactory` per the story's own cross-domain note.

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-012-failed-swap-rolls-back.md`, `production/epics/game-state-scene-flow/story-017-defeat-prompt-and-retry-snapshot.md`, `production/epics/game-state-scene-flow/story-032-chapter-flow-characterization.md`, `production/epics/game-state-scene-flow/story-033-strip-chapter-flow-chapter-mode.md`
- Unlocks: `production/epics/game-state-scene-flow/story-035-game-root-main-scene.md`, `production/epics/game-state-scene-flow/story-036-victory-dialogue-after-transition.md`, `production/epics/game-state-scene-flow/story-041-remove-interim-enemy-validation-flag.md`, `production/epics/content-migration/story-029-battle-factory-reads-enemy-records.md` (the `BattleFactory` it changes)
