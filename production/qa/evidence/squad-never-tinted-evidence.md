# Evidence: Story 072, the squad is never tinted by a faction's boss flood (AC-67)

**Story**: `production/epics/sprite-camera-presentation/story-072-squad-never-tinted-by-the-boss-flood.md`
**Requirement**: TR-presentation-024 (ADR-0005 §2, §3, §5)
**Captured**: 2026-10-31, Godot 4.7.2 Forward+ (Vulkan), NVIDIA RTX 4080 SUPER, windowed, 1920×1080
**Command**: `godot --path . -s res://tools/capture/squad_tint_capture.gd` (defaults: `--encounter=enc_paris_supervisor --size=1920x1080 --out=res://production/qa/evidence/squad-never-tinted/`)
**Tool exit**: 0 (AC-67 PASS, negative control FAILS as expected, sensitivity control responds)

## Method

- `BattleMode` boots on the shipped Bureaucratia boss encounter (`stage_chapter_interim`) with the shipped squad and the real content boot. The replay plays out, so the first-encounter takeover ends on `boss_bureaucratia` (`blend_p` 1.0). The mode is then frozen.
- Every capture is the same frozen frame on the same stage and camera. Only the `LightingProfile` changes: `battle`, `boss_bureaucratia` and `boss_megacorp` (every shipped `boss_*`), each applied at blend 0, plus the takeover's own end state. Rim globals are written as the Director would write them. UI canvas is hidden for the measured frames.
- Each squad member's pixels come from its own ID-pass mask: only that member visible, rendered through a projection-preserving ID variant of `sprite_actor.gdshader`, so the mask is the card actually drawn. Pixels shared with another member are excluded (`CaptureChecks.exclusive_masks`).
- The ΔE is CIEDE2000 (`ColorDifference`). Limits are mean ≤ 3 and nearest-rank p95 ≤ 6 (`CaptureChecks.squad_tint_verdict`).

## Results (`measurements.json`)

| Comparison vs `battle` | Squad0 | Squad1 | Squad2 | Squad3 | Verdict |
|---|---|---|---|---|---|
| `boss_bureaucratia` | 0.00 / 0.00 | 0.00 / 0.00 | 0.00 / 0.00 | 0.00 / 0.00 | PASS |
| `boss_megacorp` | 0.00 / 0.00 | 0.00 / 0.00 | 0.00 / 0.00 | 0.00 / 0.00 | PASS |
| Real takeover end (`boss_bureaucratia`) | 0.00 / 0.00 | 0.00 / 0.00 | 0.00 / 0.00 | 0.00 / 0.00 | PASS |
| **Negative control**: boss `key_color` = its faction `set_color` (bureaucratia / megacorp) | 21.1 / 43.0 ; 27.0 / 58.6 | 20.8 / 44.2 ; 26.7 / 58.4 | 20.9 / 43.3 ; 31.5 / 58.1 | 26.2 / 44.3 ; 34.5 / 57.4 | FAIL (expected) |
| **Sensitivity control**: KeyLight energy 0 | 35.2 / 69.5 | 32.4 / 69.5 | 37.9 / 67.8 | 41.7 / 71.4 | FAIL (expected) |

Each cell is mean / p95 ΔE. Mask sizes are 6714, 6435, 6903 and 7425 px.

## Files (`production/qa/evidence/squad-never-tinted/`)

- `battle.png`, `boss_bureaucratia.png`, `boss_megacorp.png`: the measured frames, UI hidden. Seen: the squad and enemies are identical across the three.
- `battle_ui.png`, `boss_*_ui.png`, `takeover_end_ui.png`: the same frames with HUD and backdrop, for review.
- `mask_Squad0..3.png`, `id_actors.png`: per-member ID masks. Seen: each mask is that member's silhouette, aligned with the final frame.
- `negative_control_boss_*.png`: Seen: the whole cast visibly blue/purple-tinted.
- `sensitivity_key_off.png`: Seen: the cast dark.
- `cull_leak_boss_*.png`: an observation, not a gate (see below).

## Notes

- **Cull-mask leak observation.** Adding `ACTORS` to the Set/Fill cull masks does not tint the squad: ΔE 0 even at 8× energy in red, probed. In the shipped rig those lights strike the card's unlit side (N·L ≤ 0; the key reaches it through the 180° `KeyRig`). The faction-coloured key is therefore the discriminating negative control. Isolation by cull mask is still covered headlessly by story 003's tests.
- **Visible flood.** The battle stage currently has no 3D set geometry or sky card: the background is the painted canvas backdrop. So the boss profile changes nothing visible in these frames. That is a gap for the sky-card and flood stories (e.g. 036, 038), not for AC-67. Re-run this tool when the sky card lands.

## Sign-off

- [x] Capture-tool output retained (technical-artist, 2026-10-31)
- [ ] Lead sign-off (art-director / lead-programmer): **pending**
