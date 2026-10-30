# Story 002: The capture tool renders the deterministic passes the [C] acceptance criteria measure

> **Epic**: Sprite & Camera Presentation
> **Status**: In Progress (implemented 2026-10-30, awaiting /story-done)
> **Layer**: Core
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-023`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: Migration Step 1c builds `tools/capture/presentation_capture.gd` as its own story: an offscreen `SubViewport` with explicitly-set MSAA, screen-space AA and positional shadow atlas size, running the ID pass, the shadow mask, unlit-albedo mode, UI-alone, and the glow-input hook, or recording "Pending" if the glow hook fails.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: A `SubViewport` does not inherit the project's MSAA, screen-space AA or positional shadow atlas size (2048 vs 4096, observed) — item (8) — so every one of those settings must be set explicitly on the capture `SubViewport`, never assumed. The glow-input hook (item 15) is still unverified entering this story; story 001's spike result decides whether it lands or this tool records "Pending" for AC-32's glow clause.

**Control Manifest Rules (this layer)**:
- Required: The capture tool sets `SubViewport` MSAA, screen-space AA and the positional shadow atlas size explicitly — a `SubViewport` does not inherit the project's settings (observed) — source: ADR-0005
- Forbidden: Never let the capture tool assume a `SubViewport` inherits project rendering settings; every pass must set them explicitly rather than relying on defaults — source: ADR-0005
- Guardrail: The capture tool is a Visual/Feel-class tool that runs windowed on the development PC, not headless — source: ADR-0005 §13

---

## Acceptance Criteria

*From ADR-0005 §13 (Migration Step 1c) and the test plan's P-09 specification, scoped to this story:*

- [x] The tool opens an offscreen `SubViewport` and sets its MSAA, screen-space AA and positional shadow atlas size explicitly from the project settings, and records what it set
- [x] It renders an **ID pass** on the same frame, through per-class override materials (actors, set elements, the sky card, and the §14 capture-ID tags: `SKY`, `notice_slip`, `chase_tag`, `stun_pose`, `checkpoint_open`, `checkpoint_closed`, `safe_paving`, `beacon`, `camp_sign`, `interact_prompt`, `symbol`)
- [x] It renders the **set-light shadow mask**
- [x] It renders in **unlit-albedo mode**
- [x] It renders the **UI layer alone**
- [x] It implements the **glow-input hook** (reading the glow input before tonemapping, the compositor hook), or records a "Pending" result naming item (15) if it fails
- [x] It writes a measurements file that downstream [C] stories read for pass/fail

---

## Implementation Notes

*Derived from ADR-0005 §13 and Key Interfaces:*

- This is a Visual/Feel tool (it needs a GPU and a windowed run), built as its own story per the Migration Plan — it is not assumed to exist, and no [C]-measured feature story may close its clause until this one is Done.
- Every [C] clause in the GDD names this tool and gates the story that ships the measured feature, never this GDD's approval (per the Acceptance Criteria doc's evidence-tag note).
- The flash analyser (P-13) is explicitly a separate story — do not build it here.
- Follow the capture `SubViewport`'s explicit-settings rule exactly as §13 states it: nothing may be left at the `SubViewport` default.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The flash analyser (P-13): a separate, later story
- Every [C]-measured feature story that *consumes* this tool's output (this batch: story 010, story 025)

---

## Files

- `tools/capture/presentation_capture.gd`
- `tests/integration/presentation/capture_tool_test.gd`
- `tools/capture/capture_main.gd` (added: the windowed `-s` entry point; the library is a `Node` class so the test can instantiate it)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/presentation/capture_tool_test.gd` — must exist and pass

**Status**: [x] Created and passing: `tests/integration/presentation/capture_tool_test.gd` 10/10; full suite 1555/1555 (2026-10-30). Windowed run evidence: `production/qa/evidence/story-002-capture-tool/`.

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-001-windowed-engine-spike.md`
- Unlocks: every `[C]`-tagged story in this epic (this batch: story 010, story 025)

---

## Completion Notes

*Implemented 2026-10-30. `PresentationCapture` (`tools/capture/presentation_capture.gd`) is a `Node` library; `tools/capture/capture_main.gd` is the windowed runner (`godot --path . -s res://tools/capture/capture_main.gd [-- --scene=res://x.tscn --out=res://dir/]`). Without `--scene` it captures a built-in fixture diorama.*

- **Viewport settings:** every row of `VIEWPORT_SETTINGS` (MSAA 3D, screen-space AA, TAA, debanding, positional shadow atlas size/16-bit/quadrants, 3D scaling, mesh LOD) is assigned from the project settings and recorded in `measurements.json` → `viewport_settings`.
- **ID pass:** flat unlit per-class `ShaderMaterial` overrides (sprites keep their frame's alpha cut-out), a neutral camera `Environment` (linear tonemap, no glow), UI culled. Classes: `actor`, `set` and the §14 tags read from node metadata `capture_id` (`sky` normalises to `SKY`). Channel levels 0/128/255 make the read-back robust to ±24 rounding.
- **Shadow mask:** set-light shadow on vs off diff. **Unlit albedo:** `DEBUG_DRAW_UNSHADED`. **UI alone:** `disable_3d` + transparent background.
- **Glow input:** `probe_glow_hook()` finds no `CompositorEffect` callback after `POST_TRANSPARENT` on 4.7.2, so it records **Pending, item (15)**, consistent with story 001's FAIL.
- All passes run on one frozen frame (scene processing disabled during the capture).
- **Deviations / known limits:** the ID override replaces the actor shader, so an actor in the ID pass is drawn as a plain card, without §2's clip-space projection. The sky tag is read from metadata, but no shipped sky card carries `capture_id` yet (the sky card belongs to a later story). The extra runner file is listed under Files.
