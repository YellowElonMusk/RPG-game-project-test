# Story 074: Retained screenshots of the replay indicator and the refusal pulse

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-011`, `TR-presentation-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Battle Replay Ownership; ADR-0008: UI Framework
**ADR Decision Summary**: ADR-0006's three replay states (passive/active/latched, driven by `press_effective_changed`/`latch_changed`) are shown by ADR-0008 §12's `ReplayIndicator`, a widget built on the UI framework; ADR-0008 §7's `UiFeedback.refuse()` drives the refusal pulse the menu guard (story 058) triggers on a blocked command-menu press.
**ADR Version**: ADR-0006 2026-10-22, ADR-0008 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `ReplayIndicator` is not focusable and never emits or injects `confirm` (ADR-0008 §12); it draws the `fast_forward` glyph from `PromptFacade` and follows the text scale. The refusal pulse uses `offset_transform_*` so containers do not reset it, and is scaled to zero under Reduce Motion (ADR-0008 §7) — this story's 1080p captures should be taken with Reduce Motion off so the pulse is visible.

**Control Manifest Rules (this layer)**:
- Required: `ReplayIndicator` shows ADR-0006's three states, draws the `fast_forward` glyph from the facade, and is never focusable (ADR-0008 §12)
- Required: `UiFeedback.refuse(control)` pulses through `offset_transform_*`, scaled to zero under Reduce Motion, with `control` possibly `null` during a replay refusal (ADR-0008 §7)
- Required: Every player-visible string is English source text with a non-empty translation context (ADR-0008 §11) — applies to any glyph captions shown alongside the indicator

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-69 [UI]** (P-18) Retained screenshots of the replay indicator in its three states and of the refusal pulse on the command menu, at 1080p with keyboard and gamepad glyphs. In each, the indicator's and the pulse's text and glyphs have a WCAG contrast of at least 4.5:1 against their own backing, over Battle and over each faction's boss takeover, and the ux-designer signs the set off.

---

## Implementation Notes

*Derived from ADR-0006 and ADR-0008 Implementation Guidelines:*

This story captures, rather than builds, the replay indicator's three states (passive, active, latched — ADR-0006 §3/§6) and the command-menu refusal pulse (ADR-0008 §7), at 1080p, with both keyboard and gamepad glyphs from `PromptFacade`, over plain Battle and over each faction's boss takeover.
- The three indicator states correspond to `is_press_effective()` false (passive), true with the latch unset (active), and the latch set (latched) — each needs its own screenshot, doubled for keyboard vs. gamepad glyphs, doubled again for Battle vs. each boss takeover background.
- The refusal pulse screenshot is taken on the command menu during its `MenuGuard` window (story 058) so the pulse is actually visible; Reduce Motion must be off for the capture, since the pulse scales to zero under it.
- WCAG contrast (≥ 4.5:1) is measured against each screenshot's own backing — the boss takeover's dusk flood is a different backing than plain Battle, so the contrast check must be run separately for each.
- The ux-designer signs off the full set, not each screenshot individually, per the evidence-gate convention for Visual/UI stories.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-058-menu-input-guard.md`: the refusal pulse's triggering logic (this story only captures its appearance)
- `story-056-comfort-settings-change-mid-replay.md`: the indicator's state transition logic on a settings change

---

## Files

- `production/qa/evidence/replay-indicator-and-refusal-pulse/`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- Retained screenshots of each screen/state touched (three indicator states × keyboard/gamepad × Battle/each boss takeover; the refusal pulse) in `production/qa/evidence/replay-indicator-and-refusal-pulse/`
- ux-designer sign-off on the full set

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `BattleReplayController` (ADR-0006, no epic yet); `production/epics/sprite-camera-presentation/story-058-menu-input-guard.md` (the refusal pulse's trigger); the boss stages (no epic yet, for the boss-takeover backgrounds)
- Unlocks: None
