# Epic: Overworld Exploration & Encounters

> **Layer**: Feature
> **GDD**: design/gdd/overworld-exploration-encounters.md
> **Architecture Module**: Overworld Exploration & Encounters
> **Status**: Ready
> **Stories**: 136 stories — see the table below

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

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [The leader's displacement matches walk_speed times elapsed time at full tilt](story-001-leader-speed-from-move-input.md) | Logic | Ready | ADR-0012 |
| 002 | [Leader speed scales with move magnitude, and keyboard diagonals never exceed full speed](story-002-leader-speed-scales-with-move-magnitude.md) | Logic | Ready | ADR-0012 |
| 003 | [No action besides move changes the leader's speed](story-003-only-move-changes-leader-speed.md) | Logic | Ready | ADR-0012 |
| 004 | [Diagonal walls slide the leader, and small corner overlaps get an assist](story-004-wall-slide-and-corner-assist.md) | Logic | Ready | ADR-0012 |
| 005 | [Followers never collide, trigger exits or trigger interactions](story-005-followers-have-no-collision-or-triggers.md) | Logic | Ready | ADR-0012 |
| 006 | [Followers hold formation on the leader's recorded trail at fixed spacing](story-006-follower-trail-spacing-formula.md) | Logic | Ready | ADR-0012 |
| 007 | [Followers snap into formation on map entry, teleport, redirect and battle thaw](story-007-followers-snap-on-entry-teleport-redirect-thaw.md) | Logic | Complete | ADR-0012 |
| 008 | [A solo party still records a trail, and a mid-visit recruit joins at the first slot](story-008-solo-party-trail-and-mid-visit-recruit.md) | Logic | Ready | ADR-0012 |
| 009 | [A follower's facing flips only after moving into the new direction, and copies the leader when idle](story-009-follower-facing-flip-hysteresis.md) | Logic | Ready | ADR-0012 |
| 010 | [Followers are never saved, and reload rebuilds them from roster order](story-010-followers-not-saved-rebuilt-from-roster.md) | Logic | Complete | ADR-0012 |
| 011 | [probe() finds the nearest eligible target with a fixed tie order](story-011-probe-nearest-target-tie-order.md) | Logic | Complete | ADR-0012 |
| 012 | [With nothing in reach, confirm does nothing and makes no sound](story-012-confirm-does-nothing-with-no-target.md) | Logic | Complete | ADR-0012 |
| 013 | [No probe or interaction starts during a transition or while any overlay is open](story-013-probe-blocked-during-transition-or-overlay.md) | Logic | Complete | ADR-0012 |
| 014 | [The confirm that closes a Dialogue is consumed, and a held press starts nothing new](story-014-confirm-close-overlay-held-press-guard.md) | Logic | Complete | ADR-0012 |
| 015 | [The interact prompt is drawn over exactly the current probe() result](story-015-interact-prompt-follows-probe-result.md) | Logic | Complete | ADR-0012 |
| 016 | [Spent and resolved interactables drop out of probe(); repeatable ones stay targetable](story-016-interactable-eligibility-rules.md) | Logic | Complete | ADR-0012 |
| 017 | [Every MVP map record ships with zone_rate = 0, enforced in CI](story-017-zone-rate-zero-on-every-mvp-map.md) | Logic | Ready | ADR-0012 |
| 018 | [At runtime, a non-zero zone_rate logs an error and no zone roll ever fires](story-018-zone-roll-suppressed-at-runtime.md) | Logic | Ready | ADR-0012 |
| 019 | [Every faction record used by a shipped map names a resolving patrol_archetype_id](story-019-faction-patrol-archetype-id-resolves.md) | Logic | Ready | ADR-0012 |
| 020 | [A patrolling symbol walks its full loop or pingpong path at v_patrol](story-020-patrol-loop-and-pingpong-traversal.md) | Logic | Ready | ADR-0012 |
| 021 | [Noticing holds for notice_delay_s before Chasing starts, whatever the leader does meanwhile](story-021-notice-delay-before-chasing-starts.md) | Logic | Ready | ADR-0012 |
| 022 | [The notice radius is wider in front than behind, split by the symbol's facing](story-022-notice-front-and-rear-half-plane-radius.md) | Logic | Ready | ADR-0012 |
| 023 | [A leader behind a fence past notice_path_cap_m is never noticed](story-023-notice-respects-bounded-path-cap.md) | Logic | Ready | ADR-0012 |
| 024 | [Returning, Stunned, cooldown and grace all skip the notice test entirely](story-024-deaf-substates-skip-notice-test.md) | Logic | Ready | ADR-0012 |
| 025 | [A leader standing in a SAFE cell is never noticed, even inside the front radius](story-025-safe-cell-leader-never-noticed.md) | Logic | Ready | ADR-0012 |
| 026 | [Noticing faces the leader, and sharp turns pause in a look-back pose on the old facing](story-026-facing-tracks-leader-with-turn-pause.md) | Logic | Ready | ADR-0012 |
| 027 | [Facing hysteresis holds through directional noise and while stopped](story-027-facing-hysteresis-holds-through-noise.md) | Logic | Ready | ADR-0012 |
| 028 | [Notice and repath requests share the per-frame budget fairly](story-028-notice-repath-budget-fairness.md) | Logic | Ready | ADR-0012 |
| 029 | [The notice search never explores past its path-length cap](story-029-bounded-notice-search-cap.md) | Logic | Ready | ADR-0012 |
| 030 | [A leader in another symbol-legal component costs zero A* queries](story-030-cross-component-query-budget.md) | Logic | Ready | ADR-0012 |
| 031 | [Chasing moves at v_chase and repaths no more than once per repath_s](story-031-chase-speed-and-repath-throttle.md) | Logic | Ready | ADR-0012 |
| 032 | [A chase gives up only after path_dist exceeds symbol_giveup_m for giveup_s](story-032-chase-give-up-path-distance.md) | Logic | Ready | ADR-0012 |
| 033 | [Returning walks by A* to the resume point, then resumes Patrol deaf](story-033-returning-to-resume-point.md) | Logic | Ready | ADR-0012 |
| 034 | [Each symbol's chase target offsets sideways by its own marker index](story-034-chase-target-offset.md) | Logic | Ready | ADR-0012 |
| 035 | [The final approach steers straight at the leader only over legal cells](story-035-final-approach-legality.md) | Logic | Ready | ADR-0012 |
| 036 | [A chase into a safe zone never makes contact and gives up on schedule](story-036-chase-gives-up-at-safe-zone.md) | Logic | Ready | ADR-0012 |
| 037 | [Chase pathing edge cases — empty path, deferred repath, unreachable resume](story-037-chase-pathing-edge-cases.md) | Logic | Ready | ADR-0012 |
| 038 | [Contact calls start_encounter exactly once with the record's enc_ ID](story-038-contact-starts-encounter-once.md) | Logic | Ready | ADR-0012 |
| 039 | [Game State receives an encounter descriptor matching the enc_ record field-for-field](story-039-encounter-descriptor-matches-record.md) | Integration | Ready | ADR-0012 |
| 040 | [A map exit crossing on the same frame as contact wins, and contact is skipped](story-040-exit-beats-contact-same-frame.md) | Logic | Ready | ADR-0012 |
| 041 | [A rejected encounter request holds contact pending and retries every frame](story-041-rejected-request-holds-contact-pending.md) | Logic | Ready | ADR-0012 |
| 042 | [Two symbols touching the leader at once pick the smaller closest-approach distance](story-042-two-symbols-contact-tiebreak.md) | Logic | Ready | ADR-0012 |
| 043 | [Victory resolves the symbol per its record's respawn policy](story-043-victory-respawn-policy.md) | Logic | Ready | ADR-0012 |
| 044 | [Fled stuns a non-Static symbol and pushes it back along the contact line](story-044-fled-symbol-stun-and-push.md) | Logic | Ready | ADR-0012 |
| 045 | [A Stunned symbol overlapping the leader never starts a second encounter](story-045-stunned-symbol-grants-no-encounter.md) | Logic | Ready | ADR-0012 |
| 046 | [A flee push with coincident centres goes opposite the leader's facing](story-046-flee-push-coincident-centres.md) | Logic | Ready | ADR-0012 |
| 047 | [Encounter grace starts on transition_finished, never on_thawed](story-047-encounter-grace-starts-on-reveal.md) | Logic | Ready | ADR-0012 |
| 048 | [Grace, notice, give-up, cooldown and stun timers freeze under overlays and transitions](story-048-timers-freeze-under-overlays.md) | Logic | Ready | ADR-0012 |
| 049 | [Overworld → Battle → Overworld preserves a mid-chase snapshot except rule 7's changes](story-049-thaw-preserves-mid-chase-snapshot.md) | Integration | Ready | ADR-0002 |
| 050 | [The first Victory over a symbol grants its payoff and shows a payoff card](story-050-first-victory-grants-payoff.md) | Logic | Complete | ADR-0012 |
| 051 | [Every map's payoff distribution follows the facet, cap and tell rules](story-051-map-payoff-distribution-rules.md) | Logic | Complete | ADR-0012 |
| 052 | [An off-screen Victory plays the off-screen sting and the payoff card together](story-052-offscreen-liberation-payoff-card.md) | Logic | Ready | ADR-0012 |
| 053 | [The occupation stage formula is monotonic and matches the flag-to-stage table](story-053-occupation-stage-formula.md) | Logic | Complete | ADR-0012 |
| 054 | [A flag set mid-visit leaves the stage and active markers unchanged until the next load](story-054-stage-change-waits-for-next-load.md) | Logic | Complete | ADR-0012 |
| 055 | [Paris map records set correct base stages and decree-gag registry rules](story-055-paris-map-stage-and-decree-registry-rules.md) | Logic | Complete | ADR-0012 |
| 056 | [Decree gags stay eligible and exempt from stage caps](story-056-decree-gag-stage-eligibility.md) | Logic | Complete | ADR-0012 |
| 057 | [New Game sets permits_mandatory before the first input, and the segment always loads at stage 2](story-057-new-game-permits-mandatory-timing.md) | Integration | Complete | ADR-0012 |
| 058 | [Active markers follow the marker_activation formula's slots](story-058-marker-activation-slots-by-stage-and-cap.md) | Logic | Complete | ADR-0012 |
| 059 | [Liberated marker IDs persist across respawn, stage raise and save/load](story-059-liberated-set-persists-across-respawn-and-stage.md) | Logic | Complete | ADR-0012 |
| 060 | [On-screen liberation removal times to transition_finished; off-screen to on_thawed](story-060-liberation-removal-timing-on-screen-and-off-screen.md) | Logic | Complete | ADR-0012 |
| 061 | [Retained liberation screenshots — poster, queue, checkpoint, Reduce Motion](story-061-liberation-screenshots-poster-queue-checkpoint.md) | Visual/Feel | Ready | ADR-0012 |
| 062 | [Liberation grumble share meets its floor; respawned Clerks use the deflated look](story-062-liberation-grumble-share-and-deflated-clerk.md) | Logic | Ready | ADR-0012 |
| 063 | [Every map's liberation reaction set includes a ribs_squad entry](story-063-liberation-reaction-ribs-squad-tag.md) | Logic | Complete | ADR-0012 |
| 064 | [Clutter markers with a symbol_id are visible from the patrol they liberate](story-064-clutter-marker-visibility-and-symbol-activity.md) | Logic | Complete | ADR-0012 |
| 065 | [Stage-visual captures meet saturation, luminance and contrast targets](story-065-stage-visual-capture-saturation-and-contrast.md) | Visual/Feel | Ready | ADR-0012 |
| 066 | [Region-liberation presentation override applies on load, before reveal](story-066-region-liberation-presentation-override-on-load.md) | Logic | Complete | ADR-0012 |
| 067 | [Retained liberated-Paris screenshots — golden hour, no faction dressing, no celebration](story-067-liberated-paris-screenshots-golden-hour.md) | Visual/Feel | Ready | ADR-0012 |
| 068 | [The walk home runs after the boss Victory, through the liberated streets, to the café](story-068-walk-home-after-boss-victory.md) | Integration | Complete | ADR-0012 |
| 069 | [Liberated profile/kit fields resolve, and liberation blocks the dungeon route](story-069-liberated-fields-and-dungeon-route-block.md) | Logic | Complete | ADR-0012 |
| 070 | [A checkpoint opens on a met requirement and stays open across save and load](story-070-checkpoint-opens-on-met-requirement.md) | Logic | Complete | ADR-0012 |
| 071 | [Redirect and queue failures lock input, snap the party to the return marker and start grace](story-071-checkpoint-redirect-and-queue-failure.md) | Logic | Complete | ADR-0012 |
| 072 | [An encounter-outcome checkpoint starts its linked fight, and Victory opens it](story-072-checkpoint-encounter-outcome.md) | Logic | Complete | ADR-0012 |
| 073 | [Every checkpoint has exactly one resolving requirement, reachable fight-free on the critical path](story-073-checkpoint-requirement-and-critical-path-reachability.md) | Logic | Complete | ADR-0012 |
| 074 | [Every MapExit, critical-path leg and ChapterFlow step reference resolves](story-074-map-exit-and-critical-path-reference-integrity.md) | Logic | Complete | ADR-0012 |
| 075 | [Town, dungeon, story-encounter and boss placement match the map-structure rules](story-075-town-dungeon-story-encounter-and-boss-placement.md) | Logic | Complete | ADR-0012 |
| 076 | [Retained walk-in screenshot — the Permit Counter is on screen from the pre-dungeon camp](story-076-permit-counter-telegraph-screenshot.md) | Visual/Feel | Complete | ADR-0012 |
| 077 | [No spawn point or patrol segment crowds a safe zone or a return marker](story-077-patrol-and-spawn-safe-zone-clearance.md) | Logic | Complete | ADR-0012 |
| 078 | [Every encounter, symbol, flag, payoff, remark, decree-gag and item reference resolves](story-078-overworld-reference-integrity-check.md) | Logic | Complete | ADR-0012 |
| 079 | [Shipped scenes contain no physics nodes and no live collision on GridMap or TileMapLayer](story-079-no-physics-nodes-in-shipped-maps.md) | Logic | Complete | ADR-0012 |
| 080 | [Every EntryPoint sits clear of every MapExit rectangle, facing into the map](story-080-entry-point-exit-clearance.md) | Logic | Complete | ADR-0012 |
| 081 | [A MapExit re-fires only after the leader leaves and re-enters its rectangle](story-081-map-exit-reentry-requires-leaving-the-rectangle.md) | Logic | Complete | ADR-0012 |
| 082 | [Every symbol's patrol sweep and resume point are symbol-legal at every reachable stage](story-082-patrol-legality-at-every-reachable-stage.md) | Logic | Complete | ADR-0012 |
| 083 | [The ordered search finds a bypass lane round every patrol band on every critical-path leg](story-083-bypass-lane-ordered-search.md) | Logic | Complete | ADR-0012 |
| 084 | [No walk-grid route reaches the dungeon's boss-chamber exit without crossing the story encounter](story-084-story-encounter-not-routable-around.md) | Logic | Complete | ADR-0012 |
| 085 | [The dungeon's pressure floor — at least half the symbols' bands cross the shortest critical path](story-085-dungeon-pressure-floor.md) | Logic | Complete | ADR-0012 |
| 086 | [The first-encounter map's teaching bypass is visibly easy, and its speaker stands before the first notice radius](story-086-first-patrol-bypass-ratio-and-teaching-speaker.md) | Logic | Complete | ADR-0012 |
| 087 | [Every symbol's patrol is on screen from every approach, before the leader can be noticed](story-087-patrol-visibility-before-the-notice-radius.md) | Visual/Feel | Complete | ADR-0012 |
| 088 | [Contact with the boss never finds it moved, and its descriptor forbids Flee but allows Retreat](story-088-boss-contact-descriptor-flags.md) | Integration | Complete | ADR-0012 |
| 089 | [Defeat → Retreat against the boss goes to the pre-dungeon camp once it is passed, or the Town café before](story-089-story-encounter-flee-returns-to-registered-camp.md) | Integration | Complete | ADR-0012 |
| 090 | [A later Retreat, a Save and a reload never un-resolve the boss](story-090-boss-stays-resolved-through-retreat-and-continue.md) | Integration | Complete | ADR-0012 |
| 091 | [The Permit Counter notices nothing, barks once, and only `confirm` starts its fight](story-091-permit-counter-static-behavior.md) | Logic | Complete | ADR-0012 |
| 092 | [Liberation flags, on-screen removal, Dialogue and the stage effect apply in a fixed order](story-092-story-flag-order-after-battle.md) | Integration | Complete | ADR-0012 |
| 093 | [World state mirrors the leader every frame and never auto-saves](story-093-world-state-writes-only-position-and-events.md) | Logic | Complete | ADR-0012 |
| 094 | [A reload moves the leader off a position a new blocker has covered](story-094-load-relocates-off-a-blocked-saved-position.md) | Logic | Complete | ADR-0012 |
| 095 | [Save and load round-trip the camp, interactables, payoffs, liberation and story-flag state](story-095-save-round-trips-camp-interactables-and-flags.md) | Logic | Complete | ADR-0012 |
| 096 | [A Continue made mid-chase starts every symbol in Patrol at its origin](story-096-continue-resets-symbols-to-patrol-origin.md) | Integration | Complete | ADR-0012 |
| 097 | [Every row of the Overworld state table enters and exits correctly](story-097-state-table-transitions.md) | Logic | Complete | ADR-0012 |
| 098 | [`OverworldConfig.validate()` rejects exactly the knob combination that breaks its invariant](story-098-config-invariants-i1-i18.md) | Logic | Complete | ADR-0012 |
| 099 | [`chase_visibility` (I14) passes the shipped camera at 4:3, 16:9 and 21:9, including the tilt-shift blur bounds](story-099-chase-visibility-validates-at-every-aspect.md) | Logic | Complete | ADR-0012 |
| 100 | [Swept contact fires at every approach angle and lateral offset, and never lets a frame skip through a wall](story-100-swept-contact-at-every-approach-angle.md) | Logic | Complete | ADR-0012 |
| 101 | [A chase started at minimum contact distance gives up within one frame of `t_escape`](story-101-symbol-speeds-escape-timing.md) | Logic | Complete | ADR-0012 |
| 102 | [`path_dist` stays a true upper bound on the leader's path distance through a U-shaped corridor](story-102-path-dist-upper-bound-through-a-u-corridor.md) | Logic | Complete | ADR-0012 |
| 103 | [Every map's active symbol count lies within its density band at every reachable stage](story-103-symbol-density-band-per-map.md) | Logic | Complete | ADR-0012 |
| 104 | [The chapter's planned walk share stays under `walk_share_max`](story-104-chapter-walk-budget-share.md) | Logic | Complete | ADR-0012 |
| 105 | [No overworld flow requires a hold or a timed press](story-105-no-held-or-timed-overworld-input.md) | Logic | Complete | ADR-0012 |
| 106 | [Every accessibility cue clears 3:1 contrast against a 4px dilation of its own mask](story-106-event-cue-contrast-against-its-ring.md) | Visual/Feel | Ready | ADR-0012 |
| 107 | [The interact prompt's mask clears 3:1 contrast against its own ring on the same poses](story-107-interact-prompt-contrast-against-its-ring.md) | Visual/Feel | Ready | ADR-0012 |
| 108 | [Retained screenshots cover the interact prompt, name card, payoff card, bark window, camp prompts and the next-destination arrow](story-108-ui-screenshots-prompts-cards-and-prompts.md) | UI | Ready | ADR-0012 |
| 109 | [Each junction node shows the next beacon in the leg's chain](story-109-beacon-chain-walkin-capture.md) | Visual/Feel | Ready | ADR-0012 |
| 110 | [Every leg's junction nodes cover its real branch points](story-110-beacon-junction-coverage-validation.md) | Logic | Ready | ADR-0012 |
| 111 | [The map name card shows only on a map load's reveal](story-111-map-name-card-timing.md) | Logic | Complete | ADR-0012 |
| 112 | [Only the current leg's beacon chain is lit, and the objective line matches the step](story-112-leg-beacon-chain-and-objective-line.md) | Logic | Ready | ADR-0012 |
| 113 | [The camp prompt's cancel does nothing, and Yes has default focus](story-113-camp-prompt-cancel-and-focus.md) | Logic | Complete | ADR-0012 |
| 114 | [Symbol stepping and queries hold their frame budget on the min-spec PC and Steam Deck](story-114-overworld-performance-benchmark.md) | Integration | Ready | ADR-0012 |
| 115 | [Playtest confirms players can both bypass and engage Clerks](story-115-paris-playtest-engagement-report.md) | Integration | Ready | ADR-0012 |
| 116 | [Measure the share of chapter time spent walking against the budget](story-116-paris-walk-share-playtest.md) | Integration | Ready | ADR-0012 |
| 117 | [Every active clutter marker either responds or blocks a route](story-117-clutter-marker-gag-or-blocker-validation.md) | Logic | Ready | ADR-0012 |
| 118 | [Each gag response type behaves as specified](story-118-gag-response-behavior.md) | Logic | Complete | ADR-0012 |
| 119 | [Each faction's first-encounter clue sits on the critical path before the first patrol](story-119-faction-clue-placement-ordering.md) | Logic | Complete | ADR-0012 |
| 120 | [The Paris clue is legible on the Deck and the comprehension check passes](story-120-faction-clue-narrative-signoff-and-comprehension.md) | Config/Data | Ready | ADR-0012 |
| 121 | [Every narrative guardrail item has a passing sign-off entry](story-121-narrative-guardrail-signoff-checklist.md) | Config/Data | Ready | ADR-0012 |
| 122 | [Confirm at a clue poster or decree gag shows its LocText verbatim](story-122-clue-and-decree-loctext-display.md) | Logic | Ready | ADR-0012 |
| 123 | [The optional_teach bark fires on proximity, never blocks movement, and re-arms](story-123-optional-teach-bark-trigger.md) | Logic | Complete | ADR-0012 |
| 124 | [A Clerk respawned onto a liberated street shows the deflated variant](story-124-deflated-clerk-respawn-screenshot.md) | Visual/Feel | Ready | ADR-0012 |
| 125 | [Retained screenshots of every overworld event cue](story-125-event-feedback-screenshot-set.md) | Visual/Feel | Ready | ADR-0012 |
| 126 | [Every overworld SFX event has its visual twin on the same frame](story-126-overworld-sfx-visual-twin-coverage.md) | Logic | Ready | ADR-0012 |
| 127 | [Exterior stage sky luminance stays at or above L* 60](story-127-exterior-stage-sky-luminance.md) | Visual/Feel | Ready | ADR-0012 |
| 128 | [SAFE cell tagging is precise at the 0.01 m boundary](story-128-safe-cell-bake-boundary-precision.md) | Logic | Complete | ADR-0012 |
| 129 | [Symbols, followers and civilians never block or push each other; a touched symbol resumes from its contact point](story-129-symbol-follower-civilian-non-collision.md) | Logic | Complete | ADR-0012 |
| 130 | [The name card, payoff card and bark window each hold for text_hold(text), pausing under overlays](story-130-timed-text-hold-and-overlay-pause.md) | Logic | Complete | ADR-0012 |
| 131 | [AStarGrid2D setup stays frozen after bake, and sprite frames never drift from ow_dt](story-131-astargrid-pathing-setup-invariants.md) | Logic | In Progress | ADR-0012 |
| 132 | [A narrow aspect logs one warning; a freed blocker invalidates stale paths](story-132-aspect-warning-and-freed-blocker-edge-cases.md) | Logic | Complete | ADR-0012 |
| 133 | [Build the perf_overworld fixture, debug flags and the step_symbols() performance monitor](story-133-overworld-performance-fixture-tooling.md) | Integration | Ready | ADR-0012 |
| 134 | [Tag every overworld cue with a capture-ID for the presentation capture tool](story-134-capture-id-tags-for-overworld-cues.md) | Integration | Ready | ADR-0005 |
| 135 | [Build the level-review tool that lists approaches and junction nodes and drives walk-in captures](story-135-level-review-walkin-tool.md) | Integration | Ready | ADR-0012 |
| 136 | [A placeholder Paris Town map you can walk around in, with the leader sprite, followers and the follow camera](story-136-walkable-placeholder-town-map.md) | Integration | Ready | ADR-0012 |

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/overworld-exploration-encounters.md verified
- Logic and Integration stories have passing tests in the test root
- Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/`
  (a lead sign-off too for Visual/Feel)
