# Story 137: The game boots into the overworld, and a visible symbol starts a real battle and thaws back

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-29)
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md` (rules 5–7: symbols, contact, the battle round trip)
**ADR Governing Implementation**: ADR-0012 Migration Plan steps 4–5 and §8 "Retiring the interim"; ADR-0002 §8 (ChapterMode's interim role).
**ADR Decision Summary**: `ChapterMode`'s fixed fight sequence is deleted once one map with one `EncounterSymbol` has a playable Victory, Fled and Defeat loop under Game State. The chapter's fights become `enc_` records.

Stories 020–049 built the symbol brain, contact, `start_encounter`, respawn, flee and thaw as pure, tested parts. Story 136 built a walkable placeholder Town map reachable only from a debug entry point. Nothing yet places a symbol on that map or puts `OverworldMode` in `GameRoot`'s Overworld slot, so none of it is playable.

## Acceptance Criteria

- [x] **AC-137a [I] (assembly)** GIVEN New Game from the Title, THEN Game State enters Overworld with `OverworldMode` on the placeholder Paris Town map (not `ChapterMode`), with `WorldState`, the content catalog's `enc_` records and the squad's party source injected.
- [x] **AC-137b [I] (symbols)** The map holds at least two `EncounterSymbol` markers, each naming an `enc_` record (data, never inline), with a patrol path; each is drawn as a placeholder `CharacterSprite` that moves with its `SymbolBrain`.
- [x] **AC-137c [I] (round trip)** GIVEN the leader touches a symbol, THEN Game State transitions to Battle with that record's descriptor and the squad's `Combatant`s. Victory returns to the map with the symbol resolved per its respawn policy; Fled returns with the symbol stunned and pushed; Defeat opens the Defeat Prompt, whose Retry restarts the same fight.
- [x] **AC-137d [I] (interim retired)** `ChapterMode`'s fight sequence is no longer reachable from New Game. `ChapterFlow` keeps only the step list (ADR-0012 §8); tests that only covered the removed sequence are deleted or moved, never skipped.
- [x] **AC-137e [UI evidence]** Retained windowed screenshots in `production/qa/evidence/story-137-playable-overworld-loop/`: a symbol visible on the map, the battle it started, and the map after Victory without that symbol. The main session opens each one before closing the story.

## Implementation Notes

- Encounter records: add at least two `enc_` records under `data/encounters/` for the Paris street fights (Clerks; `faction_id` bureaucratia; `can_flee = true`; `retreat_allowed` per Game State rule 8). Keep the existing chapter fights' rosters so balance does not move.
- Placement uses the marker/scene approach ADR-0012 §4–5 names; no physics nodes (ADR-0012 §2–3).
- The party source is the squad that `ChapterFlow` builds today (same `Combatant` instances, HP/MP carrying over).
- Run-and-observe is required (`.claude/docs/run-and-observe.md`): a parse check is not a run.

## Out of Scope

- Map changes and exits (`map_exit_requested` stays a stub), camps and Retreat targets beyond what Game State already supplies, payoffs (050–052), stages (053+), the story encounter and boss (075).
- The Beatbox Battle Score (Vertical Slice).

## Files

- `src/overworld/overworld_mode.gd`, `overworld_map.gd`, a new `encounter_symbol.gd` if a marker node is needed
- `src/boot/` or `src/game_state/` GameRoot wiring
- `src/chapters/chapter_flow.gd`, `chapter_mode.gd`
- `data/encounters/*.tres`, the placeholder map scene
- `tests/integration/overworld/playable_overworld_loop_test.gd`

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/overworld/playable_overworld_loop_test.gd` passes; screenshots per AC-137e.
**Status**: [x] `playable_overworld_loop_test.gd` 5/5 pass; full suite 813/813 (2026-10-29). Screenshots retained in `production/qa/evidence/story-137-playable-overworld-loop/`.

## Dependencies

- Depends on: stories 020–049, 136 (all implemented)
- Unlocks: story 033's successor cleanup; the first real playtest of the overworld loop

## Completion Notes

*Implemented 2026-10-29, awaiting /story-done.*

- **Records:** `data/encounters/enc_paris_clerks_west.tres`, `enc_paris_clerks_east.tres` (one `enemy_clerk` each, as the old regular fights; `faction_bureaucratia`; `can_flee = true`; `retreat_allowed = false`, as ChapterFlow had it, since no camp exists; `respawn = false`; `battle_stage_id` keeps the interim `stage_chapter_interim`).
- **Placement:** new `EncounterSymbol` (`Marker3D`, data only: `encounter_id`, `symbol_id`, `patrol_path` in ground metres, `path_mode`). `OverworldMap` gains `map_id` and `symbol_markers()`. `OverworldMode.load_map()` enters the map in `WorldState` and registers one `SymbolBrain` per marker; it adds `get_encounter_sources()`. `OverworldView.sync_symbol_sprites()` draws one placeholder `CharacterSprite` per symbol and drops it on Victory.
- **GameRoot:** `transition_config.tres` Overworld slot -> `overworld_mode.tscn`. `pre_setup` injects a fresh `WorldState`, the catalog and `ChapterFlow.build_squad()` (built once per OverworldMode, same `Combatant`s every battle). A `PresentationDirector` is added, as in `overworld_demo.gd`.
- **Retired:** `chapter_mode.gd/.tscn` and `chapter_flow_demo.gd/.tscn` are deleted. `ChapterFlow` keeps only the squad builder (the party source). No step-list data exists yet, so `ChapterSteps` and `WorldState.chapter_step` are a TODO.
- **Tests removed** (they only covered the fight sequence): `chapter_mode_test.gd` (4), `chapter_flow_sequencing_test.gd`, `chapter_flow_descriptor_test.gd`, `chapter_flow_carryover_test.gd` and their helpers `chapter_flow_probe.gd` and `chapter_flow_expected.gd`, plus `test_demo_loop_scripted` in `game_state_game_root_boot_test.gd`. The new test now covers that loop. Two boot tests were updated: New Game now settles in OVERWORLD, and quit-mid-battle starts its battle through `start_encounter`.
- **Validator fixture:** the two `enc_` records are truthfully reported as "Nothing references this record", because map markers are not records. They were added to `expected_migrated_warnings.txt`. `_entry_keys()` now strips its key so that an empty field can match, which it could not before.
- **Screenshots (read back):** `01`: the dark-grey symbol sprite on the tan floor, up and left of the orange leader. `02`: the Bureaucratia battle against one Clerk, with the four-character squad at full HP. `03`: the map after Victory, with the leader alone and no symbol sprite in frame. The camera had not fully settled, so the framing differs from `01`.
- Status synced 2026-10-30 from commit 3947071.
