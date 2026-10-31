# Evidence: Story 052, no emissive source bleeds through an actor's silhouette (AC-48)

**Story**: `production/epics/sprite-camera-presentation/story-052-no-emissive-behind-actor.md`
**Requirement**: TR-presentation-003, TR-presentation-002 (ADR-0005 §2, §3)
**Captured**: 2026-10-31, Godot 4.7.2 Forward+ (Vulkan), windowed, 1920×1080
**Command**: `godot --path . -s res://tools/capture/emissive_bleed_capture.gd` (defaults: `--size=1920x1080 --out=res://production/qa/evidence/no-emissive-behind-actor/`)
**Tool exit**: 0 (AC-48 PASS on every captured state, controls behave)

## Method

- Each AC-32 lighting state that has a 3D scene boots through the real content boot, the same way `ui_tint_capture.gd` does. The state is then frozen.
- **Silhouette**: the ID pass (`PresentationCapture.apply_id_overrides`, with the actor card's projection kept) with the actors shown. The `actor` and `symbol` pixels make up the silhouette.
- **Emissive mask**: the same ID pass once more, with every actor-layer and `symbol` geometry hidden and every emissive set source drawn in a reserved colour (`EmissiveBleedCheck.emissive_colour()`, #8080ff, outside the ID palette).
- **Verdict**: an emissive pixel inside the silhouette fails (`EmissiveBleedCheck.bleed` / `verdict`). A capture with no actor pixels is invalid and fails.
- **What counts as emissive** (`EmissiveBleedCheck.is_emissive`): geometry off the actor layer that carries the `capture_id` tag `emissive`, or has a `BaseMaterial3D` with `emission_enabled`, or a `ShaderMaterial` that writes `EMISSION`. Geometry under a node with `actor_lighting` metadata is exempt, as the story's implementation notes allow.

## Results (`no-emissive-behind-actor/measurements.json`)

| Capture | Silhouette px | Emissive sources | Emissive px (actors hidden) | Bleed px | Verdict |
|---|---|---|---|---|---|
| `battle` | 39456 | 0 | 0 | 0 | PASS |
| `boss_bureaucratia` | 105642 | 0 | 0 | 0 | PASS |
| `boss_megacorp` | 71334 | 0 | 0 | 0 | PASS |
| `victory_peak` | 36876 | 0 | 0 | 0 | PASS |
| `defeat` | 29889 | 0 | 0 | 0 | PASS |
| `overworld` (town) | 6984 | 0 | 0 | 0 | PASS |
| **control_behind**: emissive quad 1.5 m behind Squad2 (Karen) | | 1 | 172640 | 5079 | **FAIL (expected)** |
| **control_beside**: 0.5 m emissive quad between Squad0 and Squad1, same depth (the Camp-fire case) | | 1 | 30625 | 0 | PASS (expected) |
| **control_actor_lighting**: the behind quad under an `OmniLight3D` tagged `actor_lighting` | | 0 (1 exempt) | 0 | 0 | PASS (expected, exempt) |

**Blocked, not captured**: `title` (TitleMode is a 2D Control scene: no DioramaStage and no actors) and `camp` (InterimCampMode is a 2D card: no Camp diorama and no campfire practical). AC-48 covers "every AC-32 capture", so these two states stay open until the scenes exist. Re-run the tool then.

**Honest scope**: no shipped state has an emissive set source today. The battle set is the painted canvas backdrop, there is no sky card or neon horizon, and the Overworld placeholder set is plain lit boxes. The six PASS rows are therefore true but not yet load-bearing. The controls show the check would catch a real violation.

## Files (`production/qa/evidence/no-emissive-behind-actor/`)

Each capture writes `<name>_final.png`, `_id.png`, `_silhouette.png`, `_actors_hidden.png` and `_bleed.png`. What I saw when I opened them:

- `control_behind_final.png`: a bright yellow quad behind Karen, with her sprite drawn over it (card depth occludes correctly). `control_behind_actors_hidden.png` shows the quad in the reserved blue with the actors gone. `control_behind_bleed.png` is exactly Karen's silhouette where it overlaps the quad.
- `control_beside_final.png`: the quad sits in the gap between the Baguette Thrower and Florida Man and touches neither.
- `boss_bureaucratia_final.png`: the Supervisor boss, a Clerk and the squad over the painted backdrop. Nothing emits.
- `overworld_final.png` / `overworld_silhouette.png`: the town placeholder set with the party stacked at the entry. The silhouette is the party column.

## Sign-off

- [x] Capture-tool output retained (technical-artist, 2026-10-31)
- [ ] Lead sign-off (art-director / lead-programmer): **pending**
- [ ] Title and Camp captures: **blocked** until those modes have 3D scenes
