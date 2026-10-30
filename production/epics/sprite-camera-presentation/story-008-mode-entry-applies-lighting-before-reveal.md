# Story 008: Every mode entry applies its lighting profile fully before the transition reveals it

> **Epic**: Sprite & Camera Presentation
> **Status**: Complete (2026-10-29)
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: `PresentationDirector` applies the entry profile at `blend_time = 0` on `mode_entered`, hidden behind the wipe, except on a same-mode row (Retry) where it rebinds but does not re-apply, because the Battle mode already set the Retry light during SWAP.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff API; relies on `ModeHost`'s `mode_entered` announcement (ADR-0002) firing at the end of SWAP, before the reveal.

**Control Manifest Rules (this layer)**:
- Required: `PresentationDirector` applies the entry profile at `blend_time = 0` on `mode_entered`, hidden behind the wipe; it skips the apply on a same-mode row (Retry) because the owning mode already set the light during SWAP — source: ADR-0005
- Required: `LightingProfile` and `PresentationConfig` are data (`.tres`). Every lighting/FOV/camera/texel/timing value comes from them, never literals — source: ADR-0005
- Forbidden: Never let a mode scene light itself with no Director — there must be one always-processing owner of the global uniforms — source: ADR-0005

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-6 [I]** (P-06) GIVEN each Game State mode entry, THEN on the frame `mode_entered` is handled, while the transition still covers the screen, every lighting parameter its preset does **not** declare animated equals the target preset within 1e-4. Over the next 120 frames, with no blend requested, none of those parameters changes. Parameters declared animated (campfire flicker, ambient motion) stay inside their declared range on every frame.

---

## Implementation Notes

*Derived from ADR-0005 Decision §3–§4:*

- On `mode_entered(to)`, which fires at the end of SWAP before the reveal, the Director takes the group's single `DioramaStage`, calls `stage.bind_profiles(resolver)`, and applies `profiles[stage.profile_id]` with `blend_time = 0`.
- It learns `from`/`to` from `transition_started(from, to)`: on a same-mode row (Battle → Battle for Retry) it rebinds but does **not** apply the entry profile, because the Battle mode already set the Retry light during SWAP.
- Every battle stage enters on `battle` (never a `boss_*` entry profile), so a first-encounter takeover always has a "from" light to blend out of.
- Parameters declared animated (campfire flicker, ambient motion) are exempt from the "unchanged" check and stay inside their declared range instead.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 009 (`production/epics/sprite-camera-presentation/story-009-lighting-blend-completes-without-popping.md`): the `lighting_blend` formula's own timing behaviour
- Story 026 (`production/epics/sprite-camera-presentation/story-026-lighting-blend-formula-is-exact.md`): `lighting_blend` as a pure formula

---

## Files

- `src/presentation/presentation_director.gd`
- `src/presentation/diorama_stage.gd`
- `tests/integration/presentation/mode_entry_lighting_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/presentation/mode_entry_lighting_test.gd` — must exist and pass

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-001-windowed-engine-spike.md`, `production/epics/sprite-camera-presentation/story-003-actor-key-and-rim-lighting-only.md`
- Unlocks: `production/epics/sprite-camera-presentation/story-009-lighting-blend-completes-without-popping.md`, `production/epics/sprite-camera-presentation/story-026-lighting-blend-formula-is-exact.md`

---

## Completion Notes

- `src/presentation/presentation_director.gd` (new): `PresentationDirector extends Node`. `setup(machine, config, sink)` connects `transition_started` (records `from`/`to`) and `mode_entered`. On `mode_entered`, finds the single `active_diorama_stage` group member (none: silent no-op for a 2D mode; more than one: `push_error`, applies none), calls `stage.bind_profiles(_resolve_profile)` always, then — only when `from != to` — resolves `stage.profile_id` and calls `stage.apply_profile(profile, 0.0)`. "One door" (ADR-0005 §3): never calls `stage.request_profile()`. `_resolve_profile()` loads `data/presentation/profiles/<id>.tres` directly by convention (the profile table in the full `PresentationConfig` is a later story — `config`/`sink` are stored, unused, per the ADR's exact `setup()` shape). `TODO(scene-flow)` on `setup()` marks the `GameRoot` wiring as out of scope here.
- `src/presentation/global_uniform_sink.gd` (new): `GlobalUniformSink extends RefCounted`. The base class IS the production sink (`set_global()` calls `RenderingServer.global_shader_parameter_set()` directly); a test double would subclass and override. Unused by the Director this story (`TODO`: story 010's per-frame `mode_time`/rim writes) — built because `setup()`'s ADR-0005 §4 signature requires the type.
- `src/presentation/diorama_stage.gd`: added `const GROUP := &"active_diorama_stage"` and `_enter_tree()`/`_exit_tree()` joining/leaving it (ADR-0005 §3), closing the "later story" TODO Story 003 left on group membership. `camera.current = true` on re-entry stays deferred (`TODO`) — no `camera` export exists yet (a §6 camera story).
- `tests/integration/presentation/mode_entry_lighting_test.gd` (new): drives the real `GameStateMachine` via `GameStateFixtures`, with one `DioramaStage` (real light-rig children, added to the test's own tree) standing in for whichever stage a real scene swap would have live. Three tests: (1) Overworld→Battle entry — a probe connected after the Director's own `mode_entered` listener confirms `machine.phase` is still `SWAP` (pre-reveal) at the moment the rig already matches `battle.tres` within `1e-4`, and the rig is unchanged after 120 further ticks with no blend requested; (2) Defeat→Retry (Battle→Battle, `retry_flash`) — simulates the owning Battle mode's own hidden-SWAP `request_profile(&"boss_bureaucratia", 0.0)` call, then asserts the Director's `mode_entered` handler did **not** overwrite it back to `battle`; (3) no `DioramaStage` in the tree (2D mode) — the transition still completes with no crash/error.
- Deviations: none from the ADR's §3/§4 Key Interfaces shapes. `PresentationConfig`'s profile table and the every-frame global-uniform writes are explicitly out of this story's scope (later stories), as called out above.
- Verified: see Test Evidence Status below.

**Test Evidence Status**: `tests/integration/presentation/mode_entry_lighting_test.gd` — 3/3 passing. Full suite: 666/666 green, 0 orphans (`$TEMP/scp008_full.log`).

- Status synced 2026-10-30 from commit b56b4f3.
