# Epic: Overworld Exploration & Encounters

> **Layer**: Feature
> **GDD**: design/gdd/overworld-exploration-encounters.md
> **Architecture Module**: Overworld Exploration & Encounters
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories overworld-exploration-encounters`

## Overview

This epic builds the part of the game the player walks around in: the Dragon Quest / Chrono Trigger loop that the MVP battle slice left out.

- The squad's leader moves across small hand-built diorama maps of an occupied region (Paris in the MVP), and up to three recruits follow the leader's path.
- Every fight starts from a visible enemy symbol on the map, such as a Bureaucratia Compliance Clerk on a patrol route. The player can avoid it, or walk into it on purpose.
- Touching the symbol starts the battle through Game State. Afterwards the same Overworld instance thaws: the Victory clears the symbol and its clutter, Fled stuns it.
- Maps and encounters are content records (`map_`, `enc_`, `ostage_`).
- Story progress raises each map's occupation stage on the faction's schedule, and a boss victory liberates the region.

ADR-0012 fixes the architecture:

- a pure `GroundMover.step()` on a `WalkGrid` baked from a `TileMapLayer` at load (no physics engine);
- a pure `SymbolBrain` for patrol, notice and chase;
- `OverworldMode` as the Game State mode scene, with `start_encounter` and `on_thawed`;
- an injected `WorldState`, the single owner of the party's map and position;
- `OverworldConfig.validate()` and a map validator CI tool.

It depends on Game State (Done), Input (`get_move_vector()`), Content Data, and Sprite & Camera Presentation, whose diorama, follow camera and overworld profiles (ADR-0005 §14) come from that epic. It also consumes Dialogue (talking to locals, encounter barks) and Localization (`LocText`); neither system has an epic yet, so stories that need them name them as dependencies. This epic replaces the interim `ChapterMode` stand-in and retires `ChapterFlow` (architecture.md: "deleted when Overworld Exploration ships").

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0012: Overworld Exploration & Encounters | `GroundMover`/`WalkGrid` (no physics), pure `SymbolBrain`, `OverworldMode`, injected `WorldState`, map/encounter/stage records, `OverworldConfig.validate()`, `validate_maps.gd` | LOW–MEDIUM |
| ADR-0002: Game State & Scene Flow | Freeze by detach and `on_thawed`, the encounter descriptor, the transitions, `register_camp`, §11 in-mode fade | HIGH |
| ADR-0003: Input System | `get_move_vector()`; no pointer movement in the overworld | HIGH |
| ADR-0005: Sprite & Camera Presentation (§6 follow camera, §14 overworld profiles) | Upright-card sprites at the feet, the follow camera formula, per faction × stage lighting profiles, the travelling light | HIGH |
| ADR-0001: Content Data Storage (amended by ADR-0012) | `map_`/`enc_`/`ostage_` record types, no file paths in records | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-overworld-001 | Leader moves continuously on a 2D ground plane at walk_speed * min(1, |move|) with no run button and no physics engine; axis-separated collision against the baked walk grid with wall slide and corner assist; frame-rate independent on one overworld clock ow_dt = min(delta, dt_max) accumulated only in Exploring | ADR-0012 ✅ |
| TR-overworld-002 | Walk grid baked once at map load from an editor TileMapLayer; SAFE cells rasterised conservatively from EntryPoints, MapExits, CampSpots (safe_radius_m) and return markers (return_safe_radius_m); a single batched set_blocked path for runtime blockers; 4-connected symbol-legal component labels relabelled once per frame | ADR-0012 ✅ |
| TR-overworld-003 | Every MVP battle starts from contact with (or confirm at) a visible EncounterSymbol; zone encounters exist in code and data but zone_rate is 0 on every MVP map; each faction names a patrol_archetype_id | ADR-0012 ✅ |
| TR-overworld-004 | Symbol sub-state machine Patrol / Noticing / Chasing / Returning / Stunned / Static with facing-weighted notice snapped to the displayed facing (hysteresis), turn pause, re-notice cooldown, path-distance give-up using an upper-bound path_dist, pending paths, final approach only over symbol-legal cells, contact pending, and Static start_on (contact_or_confirm | confirm) | ADR-0012 ✅ |
| TR-overworld-005 | Deterministic grid pathing: AStarGrid2D pinned (diagonal only if no obstacles, octile, no jumping, allow_partial_path false), update() only at bake with region/cell_size/offset frozen, origins snapped to legal cells; bounded notice search; notice, repath and Returning queries share repath_per_frame_max through a round-robin cursor; symbol stepping plus queries <= 2 ms p99 on GTX 1080 and Steam Deck | ADR-0012 ✅ |
| TR-overworld-006 | Leader-symbol contact is a swept circle test (closest approach over the frame <= 2 * body_radius) with no physics query; fixed per-frame order move -> exits -> symbols -> contact -> interaction; contact never counts in SAFE cells or during encounter grace | ADR-0012 ✅ |
| TR-overworld-007 | Encounters start only through start_encounter from an enc_ record (EncounterDescriptor -> request_transition BATTLE); two-step thaw: all state changes in on_thawed under the wipe (resolve, payoff, liberation, stun/push or Static return), then grace, on-screen liberation and the payoff card on transition_finished | ADR-0012 ✅ |
| TR-overworld-008 | First-Victory payoffs per enc_ record (clue with a distinct facet, open to an optional pocket or shortcut, item, or limited none) granted once and announced by a non-blocking payoff card | ADR-0012 ✅ |
| TR-overworld-009 | Occupation stage per map from base_stage plus a flag-to-stage table, computed only on load and never decreasing (stage_stored); stage-raising flags set only on scheduled ChapterFlow steps before the raised map can be loaded; faction x stage records hold caps, civilian density, lighting profile, sky card, set kit and ambience; markers activate by min_stage and caps sorted by (min_stage, marker order) | ADR-0012 ✅ |
| TR-overworld-010 | Local liberation of linked clutter markers (off-screen removal in on_thawed, on-screen removal after transition_finished, cells freed) saved per map; region liberation evaluated on every load applies the liberated profile and kit and deactivates every symbol | ADR-0012 ✅ |
| TR-overworld-011 | Checkpoints with exactly one requirement whose obtained_at source is fight-free on the critical path; failure outcomes redirect / queue / encounter; the redirect is a same-instance Game State fade that keeps symbol state, locks input and emits transition_finished | ADR-0012 ✅ |
| TR-overworld-012 | Maps are map_ records with scenes found by ID convention; critical-path legs end at an exit, a symbol or a camp and each ChapterFlow step names {map_id, leg_id}; map change swaps to a fresh OverworldMode instance with rollback; exits fire only on entering their rectangle and EntryPoints sit clear of them | ADR-0012 ✅ |
| TR-overworld-013 | Passing a CampSpot's safe zone registers it as the Retreat target through Game State, which stays the only writer of last_camp_id; entering camp carries a CampEntryPayload; the region default camp ends the chapter through a P15 prompt on the final step | ADR-0012 ✅ |
| TR-overworld-014 | An injected WorldState is the single owner of map, position and facing (written every frame) and of state that outlives a visit (resolved symbols, opened interactables, liberated markers, stage_stored, payoffs, interim story flags); saves happen only at Game State safe moments; Continue places from the save without on_map_reenter respawn and relocates a now-blocked position | ADR-0012 ✅ |
| TR-overworld-015 | One probe() picks the nearest eligible target with a fixed tie order and drives both the interact prompt and confirm; no probe during transitions or overlays; the confirm that closes an overlay is consumed; pointer input is ignored on the map | ADR-0012 ✅ |
| TR-overworld-016 | Load-time validation: OverworldConfig invariants I1-I18 at boot and in CI; validate_maps.gd checks every data criterion (no physics nodes by class, placement and safe zones, ordered bypass search, story encounter not routable round, beacon junction coverage, stage-raise rules, density and walk budgets, references) | ADR-0012 ✅ |
| TR-overworld-017 | Presentation: the lighting profile is resolved per map x faction x stage, or the liberated profile, before the stage enters the tree; the overworld camera must satisfy chase_visibility at 4:3, 16:9 and 21:9 including tilt-shift blur bounds measured from the leader; followers are cosmetic trail sprites; sprite animation is driven by ow_dt; process_priority mode < camera < sprites | ADR-0012 ✅, ADR-0005 §14 ✅ |
| TR-overworld-018 | All player-facing overworld text (posters, decrees, cards, barks, prompts) is LocText shown verbatim on confirm; timed non-blocking text holds by length (text_hold) and pauses under overlays | ADR-0012 ✅ |
| TR-overworld-019 | Interim MVP story-flag registry: every flag a map, checkpoint, marker or Dialogue reads is registered and CI-checked; story flags live in WorldState until Dialogue, Banter & Quests claims them; no Engine.time_scale anywhere | ADR-0012 ✅ |

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/overworld-exploration-encounters.md verified
- Logic and Integration stories have passing tests in the test root
- Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/`
  (a lead sign-off too for Visual/Feel)
