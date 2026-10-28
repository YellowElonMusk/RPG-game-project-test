# Story 032: Pin today's ChapterFlow behaviour in characterization tests

> **Epic**: Game State & Scene Flow
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-28 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md` (migration story: no GDD acceptance criterion)
**Requirement**: none directly. It is the safety net for the migration of `TR-gamestate-003` and `TR-gamestate-004`.
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (Ordering Note: "Migration Step 0 … must land before Step 2 touches `chapter_flow.gd`"; Migration Plan Step 0; Validation Criteria: "Step 0 characterization tests pass unchanged after the ChapterFlow refactor")
**ADR Decision Summary**: Before Step 2 strips `ChapterFlow`, today's behaviour is pinned in `tests/unit/chapters/`: fight order (3 regular + boss), per-faction rosters, HP/MP carryover, boss win → `chapter_won`, and the retry semantics as a record of what moves to Battle's snapshot.
**ADR Version**: ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Tests against shipped code. `battle_ended(won: bool)` exists, and `ChapterFlow._init` takes an optional `RandomNumberGenerator` (signatures checked by qa-lead).

**Control Manifest Rules (this layer)**:
- Required: "Characterization tests are written against today's hardcoded factories before migration and rerun unchanged after it."
- Required: "Run each verification or characterization pass in a fresh engine process."
- Forbidden: asserting win rates or balance outcomes in a characterization test.

---

## Acceptance Criteria

*Migration story: the criterion is ADR-0002 Migration Plan Step 0, made checkable by the derived checks below (QA RC-5).*

- [ ] **Step 0** — "Characterization tests first. … pin today's `ChapterFlow` behavior in `tests/unit/chapters/`: the fight order (3 regular + boss), per-faction rosters, HP/MP carryover, and boss win → `chapter_won`. The retry semantics are pinned too, as a record of what moves to Battle's snapshot."
  1. [ ] Fight order is 3 regular + boss per faction.
  2. [ ] The per-faction roster enemy names per fight are pinned.
  3. [ ] HP/MP carries over: fight N+1 starts at fight N's end HP/MP.
  4. [ ] A boss win emits `chapter_won` once.
  5. [ ] Retry semantics: the squad is restored to fight-start HP/MP and gets a fresh full-HP roster (file marked "moves to 034").
  6. [ ] `_clear_squad_transients` effects are pinned.

---

## Implementation Notes

*Derived from ADR-0002 Migration Plan Step 0 and the QA gate (RC-5):*

- Added at story creation (no owner in EPIC.md); without it ADR-0002's Validation Criteria cannot be met.
- **Every assertion goes through a test-side adapter, `tests/unit/chapters/chapter_flow_probe.gd`** (`start()`, `current_fight() -> {index, is_boss, enemy_names}`, `win_current()`, `lose_current()`, `squad_hp_mp()`). Today's probe forces outcomes by emitting `current_battle.battle_ended.emit(won)` on the real signal. **The probe is the only file story 033 may change**; the test files and their expected tables stay byte-identical. That is the operational meaning of "unchanged"; technical-director is asked to confirm it in the batched ADR-0002 annotation.
- Expected tables live in a constants file (`chapter_flow_expected.gd`), not inline.
- Determinism: inject a seeded `RandomNumberGenerator` (ChapterFlow shares one RNG across fights). The seed is test input, not a random seed in an assertion.
- Pin `_clear_squad_transients()` effects too: ADR-0010 §7 moves that responsibility to the Battle mode (`BattleCore.clear_transients`), and the test moves with it in 034.
- Run in a fresh engine process (`ResourceLoader` cache reuse).
- **Do not pin win rates or a "boss must lose" outcome**: naive autoplay cannot beat the Bureaucratia boss and the balance question is open. Pin structure and carryover only.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 033: stripping `ChapterFlow` (may change only the probe).
- Story 034: the retry test's new home in the Battle mode.
- `production/epics/content-migration/`: its own Step 0 pins `tests/unit/battle/`, not `tests/unit/chapters/`.

---

## Files

- `tests/unit/chapters/chapter_flow_probe.gd` (adapter; the only file 033 may change)
- `tests/unit/chapters/chapter_flow_expected.gd` (expected tables)
- `tests/unit/chapters/chapter_flow_sequencing_test.gd` (checks 1, 2, 4)
- `tests/unit/chapters/chapter_flow_carryover_test.gd` (check 3, check 6)
- `tests/unit/chapters/chapter_flow_retry_test.gd` (check 5; marked to move to the Battle mode in 034)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fixes applied: `chapter_flow_probe.gd` adapter, expected tables in a constants file, numbered checks). The developer implements against these — do not invent new test cases during implementation.*

- **Checks 1, 2, 4**: `chapter_flow_sequencing_test.gd :: test_fight_order_and_rosters` (parameterized faction ∈ {bureaucratia, megacorp})
  - Given: a probe over `ChapterFlow.new(faction, fixtures.squad(), rng seeded 12345)`.
  - When: `probe.start()`; `probe.win_current()` ×3, recording `probe.current_fight()` before each win.
  - Then: indices `[0,1,2,3]`, `is_boss` `[false,false,false,true]`, `enemy_names` equal `CHAPTER_EXPECTED[faction]`; boss win → `chapter_won` count == 1.
- **Check 3**: `chapter_flow_carryover_test.gd :: test_hp_mp_carry`
  - When: set squad hp/mp mid-fight via the probe, win.
  - Then: the next fight's start hp/mp equal those values.
- **Check 5**: `chapter_flow_retry_test.gd :: test_loss_restores_start_state`
  - When: lose.
  - Then: squad hp/mp equal the fight-start values; enemies at full HP.
- **Check 6**: `_clear_squad_transients` effects pinned (in the carryover file).
  - Edge cases: no assertion on win rates or a "boss must lose" outcome (boss balance is an open question); each suite runs in a fresh process.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/chapters/chapter_flow_sequencing_test.gd`, `tests/unit/chapters/chapter_flow_carryover_test.gd`, `tests/unit/chapters/chapter_flow_retry_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [x] Created and passing (448/448 suite-wide, 0 errors, 0 failures, 0 orphans)

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-001-install-gdunit4.md`; `production/epics/go-back-to-your-planet/story-006-chapter-flow.md` (Done: the behaviour being pinned)
- Unlocks: `production/epics/game-state-scene-flow/story-033-strip-chapter-flow-chapter-mode.md`, `production/epics/game-state-scene-flow/story-034-battle-mode-wraps-battle-core.md`

---

## Completion Notes

**Files written** (all new, under `tests/unit/chapters/`):
- `chapter_flow_probe.gd` — the adapter (`start()`, `current_fight()`, `win_current()`, `lose_current()`, `squad_hp_mp()`); forces outcomes via the real `current_battle.battle_ended.emit(won)`, never a private method.
- `chapter_flow_expected.gd` — `CHAPTER_EXPECTED` (fight order/roster per faction) and `make_squad()` fixture; no win-rate or balance values.
- `chapter_flow_sequencing_test.gd` — checks 1, 2, 4 (parameterized `bureaucratia`/`megacorp`).
- `chapter_flow_carryover_test.gd` — check 3 (`test_hp_mp_carry`) and check 6 (`test_clear_squad_transients_resets_combat_flags_on_new_fight`).
- `chapter_flow_retry_test.gd` — check 5 (`test_loss_restores_start_state`); marked to move to the Battle mode in Story 034.

No `src/` changes — `chapter_flow.gd` was read-only, per scope.

**Test count**: 5 new test functions (2 parameterized cases + 2 + 1), suite-wide 448/448 passing (up from 443), 0 errors, 0 failures, 0 orphans. Verified via a fresh-process import + full `tests/` run per the Control Manifest rule.

**Deviations**: none from the QA Test Cases. `make_squad()` uses a 2-member fixture squad (arbitrary stat block, not pinned) rather than reusing `tests/unit/battle`'s 4-member fixture, since only carryover/retry *behavior* is pinned here.

**Items owed**: none for this story. Story 033 may change only `chapter_flow_probe.gd`; Story 034 inherits the retry test's intent per its own Battle-mode snapshot.
