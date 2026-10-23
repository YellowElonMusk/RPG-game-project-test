# Story 002: Every row of the Modes transitions table succeeds from its source mode

> **Epic**: Game State & Scene Flow
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§3, §4, §9); ADR-0012: Overworld Exploration (annotation a: fresh-instance `OVERWORLD → OVERWORLD` map change; annotation b: `CampEntryPayload`)
**ADR Decision Summary**: The transitions table is a `const` in the machine. Each row is reached through its own trigger; `CampEntryPayload` is recorded into `last_camp_id` during SWAP; a map change is a fresh instance; Retry loads nothing.
**ADR Version**: ADR-0002 2026-10-21 · ADR-0012 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure machine against the stub loader. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "Mode swap = child swap under `ModeHost`. `SceneTree.change_scene_to_*` is never used."
- Required: "Mode/overlay scene paths, transition timings and budgets come from `TransitionConfig` data, never literals."
- Forbidden: "Never write `last_camp_id` from anything but the machine (`CampEntryPayload` or `register_camp`)."

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-3 [L]** Parametrized over every row of the Modes transitions table: from the source mode, the request succeeds and the mode becomes the target.

---

## Implementation Notes

*Derived from ADR-0002 §3, §4, §9 and the QA gate (RC-2, RC-3):*

- **This is the end-of-Step-1 aggregate (QA RC-2).** The outcome rows need the triggers built in 015 (results done), 016 (Fled), 017 (Retry), 018 (Retreat offer) and 020 (registered-camp Retreat), and the Quit-to-Title rows need 025. This story no longer depends on the Blocked story 021: its Battle → Camp row uses a **registered** camp.
- **GDD anchor.** A test-side `EXPECTED_ROWS` table, transcribed from GDD §States and Transitions with a comment citing it, must equal the set of `(from, to)` pairs in `GameStateMachine.TRANSITIONS` (in-mode fade row excluded), and each row's transition type must equal the GDD's. Without it, a wrong row in the `const` would pass both this story and 003.
- **Drive each row through its own trigger** (draft §2 item 7, accepted): Title → Overworld through `request_transition`; Overworld → Battle with a valid `BattleEntryPayload`; Battle → Overworld through `report_battle_outcome(VICTORY)` + `report_results_done()`, and through `FLED` on `can_flee = true`; Battle → Battle through Defeat → `choose_retry()`; Battle → Camp through Defeat → `choose_retreat()` after `register_camp("camp_a")`; Overworld ⇄ Camp; Overworld → Overworld (map change: a fresh instance, so the loader is asked for a swap); Overworld/Camp/Battle → Title; Boot → Title and Boot → Content Error through the stub catalog (asserted in depth by 004). "Any except Content Error → Title" reads as Overworld/Camp/Battle → Title, the modes where the Menu can open.
- **Quit to Title from the Menu** — pinned (ruling 2026-10-23; to be recorded in ADR-0002 by technical-director, batched annotation): no new entry point. `request_transition(TITLE)` is accepted while `MENU` is the top overlay; the machine pops every overlay top-down before `transition_started`, re-enables `ModeHost` and frees any frozen Overworld (built in 025).
- **The exit row covers both halves of the GDD's "Title / Menu → (exit)"**: `request_quit()` from Title, and from the Menu open over Overworld, Camp and Battle.
- **`CampEntryPayload` is recorded during SWAP** (ADR-0012 annotation b): Overworld → Camp sets `last_camp_id = payload.camp_id`. Assert it between `mode_exited` and `mode_entered`.
- Battle → Battle must **not** call `begin_swap` (zero loads; in depth in 017).
- Use gdUnit4 parameterized tests, one case per row, named `FROM_TO_trigger`, so a failure names the row.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: every pair *not* in the table.
- Story 004: Boot in depth.
- Story 028: the in-mode fade row (listed in a comment, excluded here).
- Story 021: the region-default camp fallback.

---

## Files

- `src/game_state/game_state_machine.gd` (row handling, if anything remains)
- `tests/unit/game_state/game_state_transition_table_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fixes applied: reordered after 015–018 and 020, GDD anchor, Menu → exit). The developer implements against these — do not invent new test cases during implementation.*

- **AC-3 (anchor)**: `test_table_matches_gdd`
  - Given: `EXPECTED_ROWS`, GDD-transcribed: BOOT→TITLE, BOOT→CONTENT_ERROR, TITLE→OVERWORLD, OVERWORLD→BATTLE, BATTLE→OVERWORLD, BATTLE→BATTLE, BATTLE→CAMP, OVERWORLD→CAMP, CAMP→OVERWORLD, OVERWORLD→OVERWORLD, OVERWORLD/CAMP/BATTLE→TITLE.
  - When: the test reads the `GameStateMachine.TRANSITIONS` keys.
  - Then: the two sets are equal, and each row's transition type equals the GDD's (`fade` / `battle_wipe` / `battle_wipe_reverse` / `retry_flash` / `none`).
- **AC-3 (rows)**: `test_row_succeeds` (parameterized, one case per row, case name `FROM_TO_trigger`)
  - Given: the machine placed in the row's source mode through the fixture path; stub loader DONE after one PENDING.
  - When: the row's own trigger runs: `request_transition` (Title→Overworld, Overworld→Battle with a valid payload, Overworld→Camp with `CampEntryPayload("camp_a")`, Camp→Overworld, Overworld→Overworld map change); `report_battle_outcome(VICTORY)` + `report_results_done()`; `report_battle_outcome(FLED)` on `can_flee = true`; DEFEAT → `choose_retry()`; DEFEAT → `choose_retreat()` after `register_camp("camp_a")`; Menu open + `request_transition(TITLE)` from each of Overworld/Camp/Battle; stub catalog READY / FAILED for the Boot rows.
  - Then: `current_mode` == target after `transition_finished`; `phase == IDLE`; Overworld→Camp leaves `last_camp_id == "camp_a"` (recorded during SWAP: asserted via `get_debug_state()` between `mode_exited` and `mode_entered`); Overworld→Overworld map change calls `begin_swap` once (fresh instance); Battle→Battle calls `begin_swap` zero times.
- **AC-3 (exit rows)**: `test_exit_rows`
  - Given: (a) Title, IDLE; (b) the Menu open over each of Overworld, Camp, Battle.
  - When: `request_quit()`.
  - Then: returns `OK`; `quit_spy.calls == 1`.
  - Edge cases: the in-mode fade row is listed in a comment and excluded (028 owns it); Title→Title is absent from the table.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_transition_table_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-015-victory-waits-for-results.md`, `production/epics/game-state-scene-flow/story-016-fled-rejected-when-not-allowed.md`, `production/epics/game-state-scene-flow/story-017-defeat-prompt-and-retry-snapshot.md`, `production/epics/game-state-scene-flow/story-018-retreat-offer-no-stale-flag.md`, `production/epics/game-state-scene-flow/story-020-register-camp-and-retreat-to-it.md`, `production/epics/game-state-scene-flow/story-025-menu-stops-time-quit-to-title.md` (Quit-to-Title rows; added at write time because the Menu → Title cases need it)
- Unlocks: `production/epics/game-state-scene-flow/story-003-invalid-pairs-rejected.md`
