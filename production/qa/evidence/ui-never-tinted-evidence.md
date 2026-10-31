# Evidence: Story 057, the UI layer is never tinted by the world's tonemapper (AC-53)

**Story**: `production/epics/sprite-camera-presentation/story-057-ui-never-tinted-by-the-world.md`
**Requirement**: TR-presentation-024 (ADR-0005 §5, §13; GDD rule 11)
**Captured**: 2026-10-31, Godot 4.7.2 Forward+ (Vulkan), NVIDIA RTX 4080 SUPER, windowed, 1920×1080
**Command**: `godot --path . -s res://tools/capture/ui_tint_capture.gd` (defaults: `--size=1920x1080 --out=res://production/qa/evidence/ui-never-tinted/`)
**Tool exit**: 0 (AC-53 PASS in every scene; the negative control FAILS in every scene; the sensitivity control responds in every scene)

## Method

- `BattleMode` boots with the shipped squad and the real content boot (run once), into each AC-53 scene, then is frozen (`PROCESS_MODE_DISABLED`, GUI input off so no hover moves between passes):
  - `battle_menu`: `enc_paris_clerks_hall`, squad turn, command menu up.
  - `battle_numbers`: the same fight, Attack through the real command menu, frozen on the frame the beat ends (the `-12` damage number).
  - `boss_bureaucratia`: the shipped boss encounter `enc_paris_supervisor`, its takeover played out (blend_p 1.0).
  - `boss_megacorp`: an ad-hoc MegaCorp boss fight (`enemy_ceo`, `enemy_security_drone`; no shipped MegaCorp encounter yet), its takeover played out.
  - `defeat`: forced Defeat, the end hold played out. The DEFEAT banner, plus the Defeat Prompt card (Retry/Retreat) on a canvas layer 10 standing in for GameRoot's `OverlayHost`.
  - `victory_peak`: forced Victory, the mode clock stepped (1/240 s) to the frame the Victory blend completes.
- **UI alone**: the same frozen frame with 3D disabled and the world's backdrop canvas (layer -1, the 3D background) hidden, rendered over black and then over white. A pixel is opaque UI where both agree within 1/255 per channel (`CaptureChecks.ui_opaque_mask`). Translucent pixels (text anti-aliasing, dims) are excluded, as AC-53 scopes it to full-opacity UI. The over-black render is the reference.
- **Verdict**: CIEDE2000 (`ColorDifference`) between the final frame and the UI alone on every opaque pixel. Max ≤ 1.0 (`CaptureChecks.ui_tint_verdict`; "on every pixel" makes it a max test).
- **Why the AgX fixtures.** The shipped battle environment uses the linear tonemapper at exposure 1. On the 8-bit range that is the identity, so the shipped frame alone cannot show a tint. `LightingProfile`'s exposure/AgX fields are not yet applied by `DioramaStage`. Each scene is therefore measured three ways (`UiTintFixture`):
  1. **shipped**: the game's own environment. Must PASS.
  2. **world_agx**: the world under AgX with the scene profile's exposure, AgX white and AgX contrast; the UI where the game draws it. Must PASS.
  3. **ui_through_world** (negative control): the same AgX world with `background_canvas_max_layer` raised to 10, so the HUD (layer 0) and the overlay layer (10) are drawn into the 3D background and tonemapped with it. Must FAIL.
- **Sensitivity control**: the world's own pixels (everything outside the opaque-UI mask) must move by mean ΔE ≥ 1 between shipped and AgX. This proves the tonemapper fixture is live, so the world_agx PASS is not vacuous.

## Results (`ui-never-tinted/measurements.json`)

| Scene | Opaque UI px | shipped max ΔE | world_agx max ΔE | Negative control: max ΔE / failing px | World sensitivity (mean ΔE) |
|---|---|---|---|---|---|
| battle_menu | 179 194 | 0.59 PASS | 0.59 PASS | 12.86 / 179 011, FAIL | 4.72 |
| battle_numbers | 179 383 | 0.59 PASS | 0.59 PASS | 12.86 / 179 098, FAIL | 4.71 |
| boss_bureaucratia | 194 814 | 0.59 PASS | 0.59 PASS | 12.61 / 194 508, FAIL | 4.28 |
| boss_megacorp | 195 054 | 0.85 PASS | 0.85 PASS | 12.61 / 194 746, FAIL | 4.69 |
| defeat | 179 498 | 0.45 PASS | 0.40 PASS | 14.89 / 178 735, FAIL | 6.28 |
| victory_peak | 177 888 | 0.16 PASS | 0.16 PASS | 11.63 / 164 295, FAIL | 4.30 |

Mean ΔE over the opaque UI is ≤ 0.0002 in every passing case. The non-zero maxima are a handful of glyph-edge pixels that are 254/255 opaque: they fall inside the 1-level opacity tolerance, and the world under them shows through by less than one 8-bit level. All of them are below the ΔE 1 limit.

## Files (`production/qa/evidence/ui-never-tinted/`, per scene)

- `<scene>_final.png`: the presented frame. Seen: HUD party cards, enemy card, the faction rule banner, command menu (battle, both bosses), the `-12` damage number (battle_numbers), the DEFEAT banner and Retry/Retreat card (defeat), "VICTORY! Press Enter to continue" with the confetti burst (victory_peak), and MegaCorp's cyan banner and neon stage (boss_megacorp).
- `<scene>_ui_alone.png`: the UI over black. Seen: the same UI with no world behind it, identical in colour to the final frame.
- `<scene>_ui_mask.png`: the opaque-UI mask (white = measured).
- `<scene>_world_agx.png`: the AgX world. Seen: the backdrop and actors visibly flatter and greyer, the UI unchanged.
- `<scene>_ui_through_world.png`: the negative control. Seen: the red rule banner turned a muted brick-orange, and the party cards and menu text greyed. Actors draw over the routed UI.
- `<scene>_ui_through_world_fail.png`: the failing pixels (white). Seen: the entire banner and every card panel are flagged.

## Notes

- **No production change.** The UI already sits outside the world's tonemapper: `BattleMode`'s environment is `BG_CANVAS` with `background_canvas_max_layer = -1`. So only the backdrop layer -1 is the world's background, and the HUD, command menu and GameRoot's overlay layer draw after the tonemapped 3D. A future change that raises that limit, or moves a UI node onto a layer ≤ the limit, is exactly what the negative control catches.
- **Megacorp boss** uses an ad-hoc encounter, because no shipped encounter has `faction_megacorp` yet. Re-run when one ships.
- **Damage numbers** today are the HUD's beat numbers (story 070), so `battle_numbers` covers them. Floating world-space numbers, if added, need this tool re-run.
- **Flood not yet visible.** The boss profiles change nothing on screen yet (no sky card on the battle stage, and the tone fields are not applied; see story 072's note). The world_agx variant covers the tonemapped-world case ahead of that.

## Sign-off

- [x] Capture-tool output retained (technical-artist, 2026-10-31)
- [ ] Lead sign-off (art-director / lead-programmer): **pending**
