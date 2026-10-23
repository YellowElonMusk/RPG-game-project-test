# Story 039: Retained screenshots of the system Menu over the Defeat Prompt, the Battle system menu, and the Menu over the live Overworld

> **Epic**: Game State & Scene Flow
> **Status**: Blocked — BLOCKED: no epic builds the Menu overlay scene (the pause/party/Codex/settings hub, the UI Framework's per GDD UI Requirements and ADR-0008), and no live Overworld scene exists (`ChapterMode` has no world; Overworld Exploration has no epic yet).
> **Layer**: Foundation
> **Type**: UI
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md`
**Requirement**: `TR-gamestate-001`, `TR-gamestate-006` (the frozen, blurred diorama behind the Menu)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§5: "menus show the frozen, blurred diorama behind flat UI"); ADR-0005: Sprite & Camera Presentation (§8 the Menu backdrop blur over a frozen frame); ADR-0008: UI Framework (§8 `MenuBackdrop`)
**ADR Decision Summary**: The Menu sits over the frozen mode, shown as a blurred diorama behind flat UI. In Battle (including over the Defeat Prompt) it offers only settings and quit.
**ADR Version**: ADR-0002 2026-10-21 · ADR-0005 2026-10-22 · ADR-0008 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Evidence only.

**Control Manifest Rules (this layer)**:
- Required: "Menu stops time by disabling `ModeHost.process_mode = PROCESS_MODE_DISABLED`."
- Forbidden: "Never use `SceneTree.paused` to implement the Menu's time stop."
- Required: "Mode/overlay scene paths … come from `TransitionConfig` data."

---

## Acceptance Criteria

*From GDD `design/gdd/game-state-scene-flow.md`, scoped to this story:*

- [ ] **AC-25 [UI]** *(part 2 of 3)* "… the system Menu over the Defeat Prompt; Menu over the live Overworld scene; Battle system menu; …"

---

## Implementation Notes

*Derived from ADR-0002 §5, ADR-0005 §8, ADR-0008 §8:*

- The machine side (entries payload, time stop, stacking over the prompt) is fully covered by stories 025, 029 and 030. This story is only the retained look.
- If the producer wants it sooner, the Battle-system-menu and Menu-over-Defeat shots could use a minimal system Menu built in this epic, but that would be cross-domain (UI Framework).
- Reach the Defeat Prompt with story 035's `--debug-force-outcome=defeat`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 038: the screens this epic builds.
- The UI Framework epic: the Menu overlay scene itself.

---

## Files

- `production/qa/evidence/game-state-039-menu-over-defeat-[date].png`
- `production/qa/evidence/game-state-039-battle-system-menu-[date].png`
- `production/qa/evidence/game-state-039-menu-over-overworld-[date].png` (plus a second frame 2 s later)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). **DEFERRED** (manual verification note): needs the UI Framework Menu overlay and a live Overworld map. The developer implements against these — do not invent new test cases during implementation.*

- **AC-25 (part 2)**: manual check, game-state-039 Menu screens
  - Setup: a build with the UI Framework Menu overlay and a live Overworld map; `commands.run`.
  - Verify: (1) the system Menu over the Defeat Prompt shows only settings and quit, with the prompt visible beneath; (2) the Battle system Menu shows only settings and quit; (3) the Menu over the live Overworld shows the full entry list over the frozen, blurred diorama (no animation advancing behind it across two shots taken 2 s apart).
  - Pass condition: three PNGs retained (plus the second frame for (3)); entries match story 029's pinned lists.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: UI
**Required evidence**:
- UI: the retained screenshots listed in Files, in `production/qa/evidence/`. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/game-state-scene-flow/story-025-menu-stops-time-quit-to-title.md`, `production/epics/game-state-scene-flow/story-029-battle-menu-system-entries.md`, `production/epics/game-state-scene-flow/story-030-defeat-prompt-focus-and-cancel.md`, `production/epics/game-state-scene-flow/story-035-game-root-main-scene.md`; the UI Framework epic's Menu overlay story (not yet created); the Overworld epic's first map (not yet created)
- Unlocks: None
