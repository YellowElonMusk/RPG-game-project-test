# Story 060: The flash analyser checks composited frames against flash_rate_max

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-015`, `TR-presentation-022`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation; ADR-0009: Save/Load & Settings
**ADR Decision Summary**: ADR-0005 §12's `FlashGate` books every declared source's transitions so no closed one-second window exceeds `flash_rate_max`; this story measures that guarantee on the final composited frame (world and UI together) rather than on any one source in isolation, with Reduce Flashing (ADR-0009 §8) off and on.
**ADR Version**: ADR-0005 2026-10-22, ADR-0009 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: The flash analyser is a new tool (P-13), separate from the capture tool, and is explicitly allowed to record "Pending" if its own build or the capture tool's item (15) glow-input hook fails (ADR-0005 Migration Step 1c). It runs at 60 fps against scripted sequences, reading the final composited frame — the same frame the capture tool's UI-alone pass (story 057) also reads, but here combined with the world rather than diffed against it.

**Control Manifest Rules (this layer)**:
- Required: `FlashGate.request()` refuses when a closed one-second window would hold more than `flash_rate_max` flashes; `set_rate()` re-books unlanded transitions and drops only not-yet-started ones on refusal (ADR-0005 §12)
- Required: With Reduce Flashing On, `request()` always returns `-1` (ADR-0005 §12)
- Required: `flash_rate_max` is at most 3 per second and validated at boot (ADR-0005 §9, §12)

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-55b [C]** (P-13) (composite frames; Pending: capture tool and flash analyser) The flash analyser runs on the final composited frames, world and UI together, of each scripted sequence in P-13 at 60 fps. Those include a boss battle's reveal and takeover; a Victory with confetti into the results screen; a Defeat, the stamp and a Retry; and a Menu opened and closed during a replay. Each sequence runs with Reduce Flashing Off and On. No one-second window holds more than `flash_rate_max` general or red flashes. With Reduce Flashing On, none holds a flash other than the reserved boss flood's.

---

## Implementation Notes

*Derived from ADR-0005 and ADR-0009 Implementation Guidelines:*

This builds the flash analyser tool itself (P-13), a sibling to the capture tool, and runs it over four scripted sequences (boss reveal/takeover, Victory → results, Defeat → stamp → Retry, Menu open/close during a replay), each twice — once with Reduce Flashing off, once on.
- The analyser samples the final composited frame (world + UI) at 60 fps and classifies each transition as general or red, then checks every closed one-second sliding window against `flash_rate_max`.
- With Reduce Flashing On, `FlashGate.request()` always returns `-1` (§12), so every gated source must already be playing its capped variant; the only flashes that may appear in that run are the reserved boss flood's.
- If the analyser cannot be built to spec (item 15's glow-input hook, shared with the capture tool), this story records "Pending" per the ADR's own allowance rather than inventing a workaround.
- This story depends on story 059's `FlashSourceDecl`s existing and validating clean — the analyser measures the *composited result* of those declarations, not the declarations themselves.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-059-flash-coverage-declared-for-every-source.md`: declaring and boot-validating each individual source
- `story-068-reduce-flashing-halves-campfire-flicker.md`: the campfire-specific flicker-swing check

---

## Files

- `tools/capture/flash_analyser.gd`
- `production/qa/evidence/composite-flash-sequences/`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- A retained capture-tool/analyser output in `production/qa/evidence/composite-flash-sequences/`
- Sign-off in `production/qa/evidence/composite-flash-sequences-evidence.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-002-capture-tool.md` (the capture tool); `production/epics/sprite-camera-presentation/story-059-flash-coverage-declared-for-every-source.md` (the source declarations this analyser measures against); the settings service (ADR-0009, not built, for Reduce Flashing)
- Unlocks: None
