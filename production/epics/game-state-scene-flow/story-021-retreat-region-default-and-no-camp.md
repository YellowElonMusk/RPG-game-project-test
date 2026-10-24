# Story 021: Retreat goes to the last camp registered, else the region default camp, else is not offered

> **Epic**: Game State & Scene Flow
> **Status**: Deferred (2026-10-24): needs the Camp, which does not exist yet; build with the Camp epic
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (shrank from M: the registered-camp Retreat path moved to story 020)
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§4: on Retreat the detached instance is `free()`d explicitly; §7: "A full restore happens only on Retreat, which Camp performs on entry"; TR table: Retreat targets `last_camp_id` or the region default camp; §11 `register_camp`); ADR-0012: Overworld Exploration (§4 `CampSpot.is_region_default`, `camp_returns`)
**ADR Decision Summary**: Retreat targets the last camp registered; with none, the region's default camp; with neither, Retreat is not offered and a content-bug error is logged. Camp performs the party's full restore on entry.
**ADR Version**: ADR-0002 2026-10-21 (Last Verified; §11 revised 2026-10-23) · ADR-0012 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Pure machine plus the loader-level free check in story 014's test file. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "A detached Overworld is freed explicitly on Retreat, on Quit to Title and in `GameRoot._exit_tree()`. Tests must assert no orphan nodes."
- Forbidden: "Never write `last_camp_id` from anything but the machine."
- Required: "Overworld freeze = detach (`remove_child`), never serialize."

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-17 [L]** GIVEN a registered camp, WHEN Retreat is chosen, THEN the mode is Camp at that camp, the party is fully restored, and the frozen overworld snapshot is discarded. GIVEN no camp registered, THEN the region's default camp is used. GIVEN no registered camp and no default camp, THEN Retreat is not offered and an error is logged.

---

## Implementation Notes

*Derived from ADR-0002 §4, §7 and the QA gate (RC-2):*

- **Scope after RC-2:** the region-default fallback, the no-camp non-offer with its error, and the `full_restore` hand-off. The registered-camp Retreat path (`choose_retreat()` → Battle → Camp with `CampEntryPayload(last_camp_id)`, `free_frozen_overworld()`) is story 020's; this story re-asserts it in `test_registered_camp_wins` so AC-17 is checked whole.
- **Default camp source (pending annotation):** `GameMode.get_region_default_camp_id() -> String`, Overworld only, base `""`, queried on the frozen Overworld at Retreat and at Defeat Prompt open.
- Offer rule shared with 018: `offers_retreat = descriptor.retreat_allowed and (last_camp_id != "" or default_camp_id != "")`. When `retreat_allowed` is true but both are empty, log `&"no_camp_for_retreat"` ("this is a content bug") at prompt open and do not offer it.
- **"Party fully restored" (QA fix).** It is not observable at machine level: Camp performs the restore, and `GameMode` has no restore hook. Pin `CampEntryPayload.full_restore: bool`, set `true` on the Retreat path only. The machine test asserts the flag and the party handed over. **DEFERRED (manual verification note):** the real restore semantics are verified by the Camp & Party Management epic's Camp story, and visually by story 040.
- In MVP, `ChapterMode` always sends `retreat_allowed = false` (033), so this path is exercised only by tests until Camp exists.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 020: `register_camp` and the registered-camp Retreat path.
- Story 040: the Camp screenshot.
- Camp & Party Management epic (not yet created): the restore itself.

---

## Files

- `src/game_state/game_state_machine.gd` (Retreat target fallback, no-camp non-offer)
- `src/game_state/game_mode.gd` (`get_region_default_camp_id()`, after annotation)
- `src/game_state/camp_entry_payload.gd` (`full_restore`)
- `tests/unit/game_state/game_state_retreat_test.gd`
- `tests/unit/game_state/doubles/stub_camp_mode.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fixes applied: scope reduced per RC-2, `full_restore` flag pinned; restore semantics DEFERRED). The developer implements against these — do not invent new test cases during implementation.*

- **AC-17 (registered camp)**: `game_state_retreat_test.gd :: test_registered_camp_wins`
  - Given: `register_camp("camp_a")`; stub Overworld `get_region_default_camp_id() == "camp_default"`; BATTLE with `retreat_allowed` true.
  - When: DEFEAT; `choose_retreat()`; run to IDLE.
  - Then: `CampEntryPayload.camp_id == "camp_a"`, `full_restore == true`; `free_frozen_overworld` called once; mode CAMP; `frozen_overworld_id == 0` (loader-level case in 014's file: `is_instance_valid(original)` false, no orphans).
- **AC-17 (region default)**: `test_region_default_used`
  - Given: no camp registered; default `"camp_default"`.
  - Then: `camp_id == "camp_default"`.
- **AC-17 (no camp)**: `test_no_camp_not_offered`
  - Given: no camp, default `""`.
  - Then: `DefeatPromptPayload.offers_retreat == false`; one error code `&"no_camp_for_retreat"` logged at prompt open; `choose_retreat()` rejected.
  - Edge cases: Overworld → Camp entry (non-Retreat) carries `full_restore == false`.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/game_state/game_state_retreat_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-018-retreat-offer-no-stale-flag.md`, `production/epics/game-state-scene-flow/story-020-register-camp-and-retreat-to-it.md`; the ADR-0002 technical-director annotation above
- Unlocks: `production/epics/game-state-scene-flow/story-040-screenshot-camp.md`; the future Camp & Party Management epic
