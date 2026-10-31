# Story 047 evidence: every battle stage keeps every actor slot visible above the occlusion threshold

**AC-43 [L]+[VF]** (GDD `sprite-camera-presentation.md`, Formulas `battle_framing` "Visible share"; ADR-0005 §2, §3)
**Date**: 2026-10-31 | **Build**: branch `slimed-down-fork`, Godot 4.7.2

## [L] -- automated

`tests/unit/presentation/visible_share_test.gd` (9 cases, green). `visible_share` now counts the projected
bounds of set geometry tagged as an occluder (`BattleStage.occluders`, cross-checked against the battle
scene's nodes tagged `capture_id = "occluder"`) as well as nearer actors' quads. The threshold is read from
the shipped config (`PresentationValidators.load_config()`), never written in the test.

Measured at the default battle camera (1920x1080), every slot filled, `actor_visible_min = 0.90`:

| Stage | Tagged occluders | Slot shares (0-3 squad, then enemies) | Lowest | Result |
|---|---|---|---|---|
| `battle_default` | 0 | 1.0, 1.0, 1.0, 1.0, 0.9696, 0.9639, 0.9539, 0.9433 | 0.9433 (slot 7) | PASS |
| `battle_boss` | 0 | 1.0, 1.0, 1.0, 1.0, 0.9880, 0.9799, 0.9375 | 0.9375 (slot 6) | PASS |

No stage data needed changing: both shipped formations already pass. Neither shipped stage has 3D set
geometry in front of the actors (the set is the painted backdrop on a canvas layer behind the 3D scene), so
`occluders` is empty on both and the scene cross-check finds no tagged node.

## [VF] -- captures (1280x720, every slot filled, default camera, after the reveal)

Captured with `tools/capture/battle_capture.gd` in ad-hoc mode (no tool changes):

- `story-047-occlusion-and-visibility-pass-the-threshold/battle_default_all_slots.png` -- `battle_default`,
  4 squad + 4 enemies (Clerk, Middle Manager, Supervisor, Clerk), Bureaucratia.
- `story-047-occlusion-and-visibility-pass-the-threshold/battle_boss_all_slots.png` -- `battle_boss`,
  4 squad + 3 enemies (Security Drone, CEO, Security Drone), MegaCorp.

The `_attack_N` / `_beat_end` files in the folder are the tool's automatic follow-on shots of the first
Attack beat; they are not part of this AC.

What was seen (opened and checked):
- Default: all 8 actors visible. The back row stands well above the front row; no enemy is behind a squad
  member and no actor is behind set geometry. Each back-row enemy reads as a full silhouette.
- Boss: all 7 actors visible, same separation; the two drones and the CEO read clearly over the backdrop.
- Observation outside this AC (UI, not set geometry or actors): the leftmost back-row slot (x = -2.1 m)
  sits partly under the left HUD column (party panels / command menu) at 1280x720 -- the Supervisor's left
  arm in the default capture and the CEO's left arm in the boss capture. Flagged for the art director / UI
  owner; not a `visible_share` failure as the GDD defines it.

## Sign-off

- [ ] Art director: "the back row reads" -- PENDING (P-17 human judgement; not given by the implementing agent).
