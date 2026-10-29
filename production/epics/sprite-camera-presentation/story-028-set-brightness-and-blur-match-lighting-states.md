# Story 028: set_brightness_and_blur matches the lighting curve in every battle-family state

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-004`, `TR-presentation-022`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation; ADR-0009: Save/Load & Settings (the Reduce Blur comfort setting)
**ADR Decision Summary**: `PresentationDirector` applies `LightingProfile`s on `mode_entered` and blends via `request_profile`'s clock or a tween; Reduce Blur is one of the six comfort settings that must be applied live, and scales blur only, never brightness, including the frozen Menu backdrop. ADR-0009's `SettingsService` is the eventual source for Reduce Blur; no consumer holds it directly — each gets a narrow view built in the composition root.
**ADR Version**: ADR-0005 2026-10-22; ADR-0009 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: ADR-0005's rendering domain carries HIGH knowledge risk (4.5–4.7 rendering changes: Shader Baker, glow-before-tonemapping, AgX controls). This story's math (`set_brightness`, the Victory curve, sky energy, `set_key_fill_ratio_boss`) is headless and pure, but it is implemented against `LightingProfile`/`PresentationConfig` data whose shape ADR-0005 §5 defines — no new engine verification is required for the formula itself.

**Control Manifest Rules (this layer)**:
- Required: "`LightingProfile` and `PresentationConfig` are data (`.tres`). Every lighting/FOV/camera/texel/timing value comes from them, never literals" (Stages and lighting, ADR-0005 §3–§5).
- Required: "No consumer holds `SettingsService`. Each gets its narrow view (`UiSettings`, `FlashSettings`, `PresentationSettings`)... `SettingsService` imports no Presentation or Feature type" (Save/Load & Settings, ADR-0009 §7).
- Forbidden: "Never let a mode scene light itself with no Director — there must be one always-processing owner of the global uniforms" (ADR-0005).

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-24 [L]** (P-06) `set_brightness_and_blur`: **Steady states** — set brightness equals `B_native × k_state` in Battle, Boss takeover and Defeat, with `k_state < 1.0` in all three. **Victory**, at the defaults with `dt = 1/60`, measured on the Battle stage's lighting state whether or not the results screen covers it: set brightness is `0.70 × B_native` on frame 0, `0.90 ×` on frame 18 (`t = blend_victory`) and `0.85 ×` from frame 42 on (`t = blend_victory + victory_settle`); on every frame it equals the Victory curve within 1e-4 and never exceeds `set_brightness_victory × B_native`; the actors' key and rim equal their Battle values within 1e-4 on frame 0 and from frame 42 on, and are strictly above them with `0 < t < blend_victory + victory_settle`. **Victory after a boss fight**: set brightness is `0.85 × B_native` on frame 0 and never below it before the peak; the sky's color equals the flood swatch's on every frame of Victory. **Sky**: sky energy equals `B_sky_native × k_state` in every non-takeover battle-family state. **Boss takeover**: the flooded fill's energy equals the set light's divided by `set_key_fill_ratio_boss`, and the set light's direction equals the stage's Battle preset's. **Reduce Blur** scales blur only, never brightness, including the Menu backdrop's blur, and applies to the frozen frame while the Menu is open.

---

## Implementation Notes

*Derived from ADR-0005 Decision §5 (`LightingProfile`/`PresentationConfig`) and ADR-0009 §7 (settings views):*

- Every field this AC measures (`key`/`rim` colour and energy, sky gradient energy, `set_key_fill_ratio_boss`, `blend_time`) is a `LightingProfile` or `PresentationConfig` field (§5) — the test builds fixture profiles, never literal expected values baked into the test, except where the AC itself names the boundary (e.g. `k_state < 1.0`).
- Victory and Defeat blends run on a tween at 1×, never the replay's clock (ADR-0005 §3): this story's curve math models that tween's output at named frames, independent of the replay controller (see `story-027`, which is out of scope here).
- `set_key_fill_ratio_boss` is validated at boot to stay above every non-boss profile's `SetLight`/`FillLight` ratio (ADR-0005 §9) — this story only needs the computed fill energy to honour it at runtime; the boot check itself belongs to `story-032` and `story-034`.
- Reduce Blur reaches this system through `PresentationSettings`, the narrow view ADR-0009 §7 builds in the composition root (`src/boot/settings_views.gd`) — this story's production code must not hold `SettingsService` directly, and the settings-service story itself is a named dependency below, not a blocker.
- The Menu's frozen-frame blur (ADR-0005 §8) is unaffected by brightness: Reduce Blur changes only the blur amount applied to that already-frozen frame, never a lighting value.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-032-missing-boss-preset-fails-boot.md`: boot validation of `set_key_fill_ratio_boss` ordering and the missing-preset content error.
- `story-038-boss-takeover-faction-parity.md`: the capture-measured swatch and sky parity across factions.
- `story-048-reduce-motion-zeroes-ambient-motion.md`: the Reduce Motion comfort setting (a separate knob from Reduce Blur).

---

## Files

- `src/presentation/lighting_profile.gd`
- `src/presentation/presentation_director.gd`
- `tests/unit/presentation/set_brightness_and_blur_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/set_brightness_and_blur_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-001-windowed-engine-spike.md` (the spike settles `B_native`, `B_sky_native` and the profile values this formula blends toward); the settings service (ADR-0009, `src/save/settings_service.gd`, not yet built — this story's production code only needs `PresentationSettings`' shape, not a working service)
- Unlocks: None
