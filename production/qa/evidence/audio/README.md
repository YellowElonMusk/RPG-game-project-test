# Audio Manager evidence (2026-11-04)

Audio can't be screenshotted, so this folder holds headless logs instead.

## What was verified

| Check | How | Result |
|---|---|---|
| Every id in `data/config/audio_events.tres` resolves to a file that loads as an `AudioStream` (68 ids: 32 music, 14 ambience, 22 SFX), and the overworld's six code-fired ids are all listed | `godot --headless --path . -s res://tools/audio/audio_smoke.gd` → `smoke.txt` | 68 ids, 0 failures |
| Routing in a real game: Title plays `mus_title`; New Game plays `mus_paris_town` with `amb_paris_stage1`; the dungeon `mus_paris_dungeon` with `amb_paris_stage3`; the street `mus_paris_segment` with `amb_paris_stage2`; touching a patrol fires `notice` then `bt_encounter_start`; the fight drops the bed and plays the `bx_floor_pulse` beatbox placeholder; one round of Attacks fires `bt_hit` and `bt_ko_enemy`; no id was missing | `godot --headless --path . -s res://tools/audio/audio_play_log.gd` → `play_log.txt` | PASS |
| Table rule (first existing file wins), missing files silent and logged once, Music/SFX bus routing, crossfade start/middle/settle, loops vs stings, SFX repeat gap, the beatbox seam, map-id → music rules, beat/UI SFX rules | `tests/unit/audio/audio_manager_test.gd` (12) | pass |
| GameRoot wiring: title/New Game music and bed, overworld `sfx_cue` → SFX, UI clicks only when walking isn't the input | `tests/integration/game_state/game_root_audio_test.gd` (2) | pass |
| Full suite with the Audio Manager wired in (on top of the Rat Catchers commit 4e4c17b) | gdUnit4, all of `res://tests` | 2281 tests, 0 failures |

`fading=true` in the play log is expected: headless frames run uncapped, so 60 frames is far less than the 0.8 s crossfade.

## What was not verified

- **How it sounds.** The placeholders are quiet synth blips, chord loops and filtered noise (`tools/audio/gen_placeholder_audio.gd`). Nobody has listened to them on speakers; a listen pass is owed.
- Loop seams of real OGG assets (none exist yet).
