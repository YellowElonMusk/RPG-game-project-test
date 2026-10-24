# Story 040: Retained screenshot of Camp

> **Epic**: Game State & Scene Flow
> **Status**: Deferred (2026-10-24): needs the Camp, which does not exist yet; build with the Camp epic
> **Layer**: Foundation
> **Type**: UI
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-004` (Retreat → Camp)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§4 Retreat; §7 Camp performs the full restore on entry)
**ADR Decision Summary**: Camp is reached from the Overworld camp spot or by Retreat from a Defeat; on a Retreat entry Camp performs the party's full restore.
**ADR Version**: ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Evidence only.

**Control Manifest Rules (this layer)**:
- Forbidden: "Never write `last_camp_id` from anything but the machine."
- Required: "A detached Overworld is freed explicitly on Retreat …"
- Required: "Mode/overlay scene paths … come from `TransitionConfig` data."

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-25 [UI]** *(part 3 of 3)* "… Camp; …"

---

## Implementation Notes

*Derived from ADR-0002 §4, §7 and the QA gate:*

- **Retain both entry routes always** (QA fix, not "if the screens differ"): (a) Overworld → Camp from the camp spot, (b) Retreat from a Defeat. "Differ" is a judgment the evidence should let a reviewer make.
- The campfire lighting signature is Presentation's (ADR-0005), so this AC verifies only that Game State reached the mode and, on (b), that the party shows fully restored (the DEFERRED restore check from story 021).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 021: the Retreat machine logic and `full_restore` flag.
- The Camp & Party Management epic: the Camp mode and the restore itself.

---

## Files

- `production/qa/evidence/game-state-040-camp-entry-[date].png`
- `production/qa/evidence/game-state-040-camp-retreat-[date].png`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE; both routes always retained). **DEFERRED** (manual verification note): needs the Camp mode and story 021. The developer implements against these — do not invent new test cases during implementation.*

- **AC-25 (part 3)**: manual check, game-state-040 Camp
  - Setup: a build with the Camp mode; reach Camp (a) from the Overworld camp spot and (b) by Retreat from a Defeat.
  - Verify: the Camp mode is shown in both; (b) shows the party fully restored (HP/MP at max in the Camp UI).
  - Pass condition: two PNGs retained in `production/qa/evidence/` (`game-state-040-camp-entry-[date].png`, `game-state-040-camp-retreat-[date].png`).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: UI
**Required evidence**:
- UI: the two retained screenshots listed in Files, in `production/qa/evidence/`. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-021-retreat-region-default-and-no-camp.md`; the Camp & Party Management epic's Camp mode story (not yet created)
- Unlocks: None
