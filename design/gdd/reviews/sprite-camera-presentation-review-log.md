# Review Log: Sprite & Camera Presentation

## Review — 2026-10-21 — Verdict: MAJOR REVISION NEEDED
Review mode: full · Workflow: full
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, ux-designer, gameplay-programmer, godot-specialist, art-director, creative-director (senior)
Blocking items: 15 | Recommended: 16
Summary: Vision and structure are sound, but the battle-replay layer (rule 9) describes behavior the runtime cannot drive: BattleCore emits battle_ended and turn_started synchronously, the HUD reads final HP directly, and no ADR names who holds the result until the last beat. That needs an ADR-0005 amendment before the GDD can be finalised. Lighting rules contradict themselves on the boss flood, Victory burst and Defeat staging, and several ACs cannot run headless.
Prior verdict resolved: First review
Rulings (creative-director): MVP protects knockout beats only, combo removed from rules 8/9 until OQ 5b; boss actor key stays neutral, faction hue on sky/set/fill, separate boss set brightness < 1.0 plus a hold beat; Battle Speed decoupled from ff_mult, protected beats at 1x at every speed, no 3x option in MVP.
Findings:
- [BLOCKING] Rule 9 / Interactions: no owner holds the battle result, turn_started and HP display until the replay ends; ADR-0005 amendment needed
- [BLOCKING] Rules 8, 9: multi-hit grouping and rule-trigger/combo flags do not exist in BattleOutcome; scope MVP to one outcome = one beat, knockout-only protection
- [BLOCKING] Interactions table: is-boss and faction come from the ChapterFlow encounter, not Turn Battle
- [BLOCKING] Edge Cases: Retry or mode exit mid-replay must drop the beat queue and held result
- [BLOCKING] Formulas replay_time: beat_min floor applies before speed-up (0.13 s beats at 3x); one dt_max frame can skip a whole beat
- [BLOCKING] Rule 9 / AC-13: damage number timing contradicts AC order and lands on the reaction frame; define reaction_hold
- [BLOCKING] Formulas flash_gate: >= 1/3 s allows 4 flashes in 1 s; no area or red-flash threshold
- [BLOCKING] Rule 13: no Reduce Flashing or Reduce Motion setting
- [BLOCKING] Rule 9 / UI Requirements: input during replay unspecified (buffered Confirm, no replay indicator)
- [BLOCKING] Visual Requirements boss row: "flood nearly full" contradicts B_set formula and AC-24; faction-hued actor key breaks rules 1 and 11
- [BLOCKING] Rule 1 / AC-32: mean-luminance read-order test fails dark costumes, Defeat, Camp fire; use local contrast, exempt emissive set lights
- [BLOCKING] Defeat / Victory: Defeat spotlight target undefined and reads as a funeral; Victory burst lifts set above actors
- [BLOCKING] Rule 2 / depth_spread: Y-locked billboard under pitched camera squashes texels by cos(pitch); DOF blurs near party row
- [BLOCKING] Rule 12 vs ADR-0005 section 3: actors cast SetLight shadows plus blob; MVP needs cast_shadow OFF
- [BLOCKING] Acceptance Criteria: AC-16 contradicts rule 11; AC-8, AC-25, AC-35 not runnable as tagged; rule 10 fallback violates no_mirror; overlay camera hold and 3 edge cases have no AC; colorblind shape untestable
- [RECOMMENDED] Game Feel: follow-camera 75%-in-0.25 s target fails at tau 0.20
- [RECOMMENDED] Formulas hit_punch: Godot round(1.5)=2 so Reduced is not half; "replace if larger" compares peak not current
- [RECOMMENDED] Formulas replay_time: protected beats escape speed_max; speed_cap should use plain_total / (replay_cap - protected_total); example 7.18 should be 7.20; empty round
- [RECOMMENDED] Formulas lighting_blend: blend_time 0 gives NaN; discrete parameters undefined
- [RECOMMENDED] Rule 13: Battle Speed 2x maps to ff_mult; decouple
- [RECOMMENDED] Formulas: d_near <= 0 unchecked; "critically damped" mislabel; campfire rate option eats shared flash budget; linear vs sRGB for "dimmed 30%"
- [RECOMMENDED] Rule 9: auto speed-up compresses the wind-up joke; boss takeover needs a hold beat
- [RECOMMENDED] Rule 10: missing reaction falls back to idle; prefer generic flinch or boot error
- [RECOMMENDED] Rule 3: no_mirror should be per-animation and cover handedness
- [RECOMMENDED] Rule 12: shadow color per lighting state, offset along key
- [RECOMMENDED] Visual Requirements: lighting table missing Title and Overworld variants; AC-34 needs perceptual lightness match (Liberty-7 vs neutral rim)
- [RECOMMENDED] Rule 7: beat-synced audio owner and Menu pause unstated; Menu blur ignores Reduce Blur
- [RECOMMENDED] Edge Cases aspect: <16:9 cuts actors; hit-punch px don't scale with resolution; add 1440p and 21:9 read-order check
- [RECOMMENDED] Rendering: TIME lint misses embedded/visual shaders; draw-call budget omits prepass, cascades, unbatched materials; pin D3D12 vs Vulkan; forbid render scale < 1 / FSR; glow halo
- [RECOMMENDED] Acceptance Criteria: AC-6/7/20 unbounded or float-exact; AC-4/12 mixed units; AC-14 cannot fail; AC-15 needs injectable logger; AC-31 N undefined
- [RECOMMENDED] Rule 9 text: "Four rules" lists five; replay unit is per submit_action, not per round
Reviewed-Content-Hash: design/gdd/sprite-camera-presentation.md 630abf4dd9e5ec5d41ad357b6200ccda0b5b2f84
Reviewed-Content-Hash: design/registry/entities.yaml e34e4fa077a6101a889f20c8fead1ca8776d6485
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md ce9474efabc4e96a62cf7d8e9859316615a4189d

## Review — 2026-10-21 — Verdict: NEEDS REVISION
Review mode: full · Workflow: full
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, ux-designer, gameplay-programmer, godot-specialist, art-director, performance-analyst, creative-director (senior)
Blocking items: 12 (GDD-side) + 6 tracked other-doc follow-ups | Recommended: 19
Summary: Revision 2 resolved the prior vision-level blockers and all creative-director rulings landed; remaining problems are spec precision, not direction. The critical defect is that reaction_hold sits inside the sped-up beat, so the "joke before the number" hold collapses at any speed-up. Timing also needs one authoritative beat clock (impact event, floor padding, missing-animation overrun), the boss takeover must hold the queue, flash safety coverage is incomplete, and about 10 ACs cannot pass or cannot run as written.
Prior verdict resolved: Partly — the 15 prior blockers are addressed in the GDD; #5 and #6 are reintroduced via ADR-0006 and the sped-up hold; #12 and #13 are only partly resolved.
Rulings (creative-director): reaction_hold stays real-time, only the wind-up scales, and a missing-animation impact lands at beat_min - reaction_hold; no global fast-forward toggle, instead a per-replay latch (one tap of fast_forward or Confirm), which needs an Input GDD amendment; the player's own command beat is not protected in MVP (playtest question); boss_hold and blend_boss are protected everywhere (only fast_forward or the latch speeds them, on first entry and on Retry), so line 298 is wrong; draw-call budget is technical-director's call, with a creative preference for per-pass with 2 cascades; other-doc fixes do not gate this GDD, except the art bible §2 boss row, which must be amended in the same changeset.
Findings:
- [BLOCKING] Formulas replay_time / Rule 9: reaction_hold is scaled by speed; missing-animation beat overruns (0.45 > 0.40); floor padding placement undefined under a mid-beat speed change; AC-13 and AC-23 to match
- [BLOCKING] Rule 6 / Rule 9: boss takeover must hold the beat queue and the first turn_started until boss_hold ends; state a hold-API requirement
- [BLOCKING] Rule 9: one beat clock drives sprite frames, punch and audio; require an impact event
- [BLOCKING] Rule 2 / Formulas depth_spread: square-texel check is tautological; θ_ray range wrong; pitch_max 35° gives a 1.22 stretch; overworld stretch must be integer-stable
- [BLOCKING] Tuning Knobs: ranges break speed_auto_max <= battle_speed_mult <= ff_mult <= speed_max; validate or narrow
- [BLOCKING] Rule 6 / Rule 10: boss intro pose is neither required nor a fallback
- [BLOCKING] Rule 13 flash limit: gate must cover attack/comedy VFX, wipes and the flood; WCAG red/area definitions; ACs for the capped retry flash and Reduce Flashing caps
- [BLOCKING] Rule 9 input: focus on last-used/Attack with nothing submitted; new-press-only guard plus ~150 ms grace on command menu, Defeat Prompt and results
- [BLOCKING] Rule 6 / Visual Requirements / AC-34: boss flood saturation and sky coverage unspecified, sky not in k_state; parity must be lavishness, not ±5 L*, keeping art bible §4 bands
- [BLOCKING] Acceptance Criteria: AC-6, 7, 19, 20, 25, 31, 35, 47 cannot pass or cannot run as written; AC-32/34/35 need re-tagging or a scoped capture tool; state the test resolution
- [BLOCKING] Acceptance Criteria: no AC for emissive-behind-actor, Defeat spotlight target, follow camera under the Menu, resize recompute, Battle Speed change mid-replay, UI never tinted
- [BLOCKING] Edge Cases: mid-replay exit (Retry or Quit) must be a stated requirement with an exit hook
- [TRACKED] ADR-0006: floor before speed (line 83); HP at impact (line 202); missing config knobs; enqueue_hold; impact signal; cancel on exiting BATTLE; BattleCore lifetime
- [TRACKED] ChapterFlow: HP restored inside the raw battle_ended; BattleCore built before fight_started
- [TRACKED] ADR-0005: keep_aspect switching on size_changed; 4.7 stretch defaults; h/v_offset parallax caveat; Performance section still bills actor shadow passes
- [TRACKED] Input GDD: per-replay fast_forward latch
- [TRACKED] Art bible §2 boss row is stale against the neutral-key ruling (amend with user approval)
- [TRACKED] Registry: beat_min unit comment says numbers show at impact
- [RECOMMENDED] defeat_hold; floating numbers vs the next reaction; replay-indicator debounce; no prompt during unskippable beats; global Reduce Motion; punch direction, axis scaling and Reduced floor; view-space depth; tau <= 0.17; map smaller than the view; read_order NaN; dimming in L*; Camp wording; Victory settle target; AC-2 node-scale gap; Liberty-7 attribution; silhouette "reads as its joke"; reaction only when hp_delta < 0; boss via Combatant.is_boss; Godot items (tilt-shift near blur, glow threshold, TIME lint scope, driver pin, min-spec)
Reviewed-Content-Hash: design/gdd/sprite-camera-presentation.md ed30edf225fced6f458a92081c5884520806636d
Reviewed-Content-Hash: design/registry/entities.yaml 6f6cc293482a4079d4a134ae65bdd6177d345adb
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md ce9474efabc4e96a62cf7d8e9859316615a4189d
Reviewed-Content-Hash: design/gdd/turn-battle-system.md 8dac8b9330ef30d70675b97e2ef7881ba75a671b
Reviewed-Content-Hash: design/gdd/game-state-scene-flow.md a84c1406aca840d445191a9194cca07e779c6a62
Reviewed-Content-Hash: design/gdd/content-data-definitions.md ff14473d0804712400b702666e07824f7d5a2126
Reviewed-Content-Hash: design/gdd/input-system.md f6b7d3a8e30147ffd4980d0e391507f549864484
Reviewed-Content-Hash: design/art/art-bible.md f5b953f98da7e352bd2ffdc649220f62014eaa76

## Review — 2026-10-22 — Verdict: NEEDS REVISION
Review mode: full · Workflow: full
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, ux-designer, gameplay-programmer, godot-specialist, art-director, performance-analyst, creative-director (senior)
Blocking items: 21 | Recommended: ~45 (incl. tracked)
Summary: Most review-2 blockers are genuinely fixed and the vision, registry alignment and worked examples hold. What remains clusters in rule 9 (no single post-impact clock, no call order for the boss hold entry against the shipped synchronous BattleCore, no impact-marker data source, two clocks on the boss blend), input behaviour that lets reflex Confirm taps or mashing speed protected beats, the boss flood art direction, and a set of ACs that cannot pass. Caution from creative-director: if Revision 4 does not close the replay clock/call-order cluster, move replay timing into ADR-0006 rather than iterating rule 9 a fifth time.
Prior verdict resolved: Mostly. Review-2 blockers on unscaled hold, hold entry, exit hook, load validation, knob ordering, Defeat target, emissive exclusion and the six missing ACs are resolved; the beat clock, new-press guard and flash coverage are only partly resolved; the square-texel check was replaced by a wrong projection model.
Rulings (creative-director): REVERSES review-2 latch ruling: Confirm and the auto speed-up may speed plain beats only, only an explicit fast_forward speeds protected beats, Cancel clears the latch, plus a replay-start guard and a quiet-period anti-mash guard; Defeat Prompt default focus is Retry. REVERSES review-2 flood ruling: flood chroma capped at ~60-70% of signature chroma, one flood swatch per faction in art bible §4, parity through coverage/gradient/energy. Gating split: the GDD must state the call order and name ADR-0002 Migration Step 2 as a hard prerequisite (gates); doing the migration gates story readiness; the Input GDD contradiction gates (resolved by the latch ruling plus an Input amendment); ADR-0005 drift gates ADR acceptance only. Texel formula is BLOCKING. AC-31 defects gate; budget adequacy stays with technical-director (OQ 13).
Findings:
- [BLOCKING] Formulas depth_spread / rule 2: square-texel aspect must be 1 − tan(θ_ray − pitch)·tan(pitch); cos θ_ray / cos pitch drops 1/cos φ and fails a pitch-0 slot
- [BLOCKING] Rule 6 / rule 9: state the hold-entry call order (first fight and Retry) against synchronous start_battle(); ADR-0002 Step 2 is a hard prerequisite (chapter_flow.gd:124-127, battle_core.gd:90)
- [BLOCKING] Rule 9 / Formulas: impact marker has no data source; add boot-validated impact_frame per attack animation
- [BLOCKING] Rule 9: post-impact clock undefined for target hit/knockout, attacker follow-through and boss intro vs boss_hold; clamp, knockout holds, hit returns to idle
- [BLOCKING] Rule 6: boss blend has two clocks (controller latch vs stage tween) and may play hidden behind the wipe; controller drives it, starting on full reveal
- [BLOCKING] Rule 9: previous floating number overlaps the next reaction frame on the same target
- [BLOCKING] Rule 9 new-press guard: beaten by mashing at 6-8 Hz; quiet-period guard; Defeat Prompt focus Retry
- [BLOCKING] Rule 9: the submitting press or a tap at replay start can latch; guard replay start
- [BLOCKING] Rule 9 latch: Confirm must not speed protected beats; Cancel un-latches; reconcile with Input GDD L176
- [BLOCKING] Rule 13 / flash_gate: exemptions not aggregated across simultaneous sources; one gated play may hold several flash pairs
- [BLOCKING] Rule 6 / AC-34: flooded sky ΔE10 test forces a flat card; conflicting lightness rules; chroma/lightness terms mixed; Feed Magenta band missing
- [BLOCKING] Rule 6 / Visual Requirements: full-chroma flood breaks art bible saturation reservation and boss legibility; cap 60-70%, enemy-vs-flood chroma check
- [BLOCKING] Visual Requirements boss row: "hardest set contrast" unimplemented; key:fill ratio knob plus [C] check; AC-34 "low key angle" contradicts key = Battle
- [BLOCKING] AC-53: cannot pass with alpha-blended UI
- [BLOCKING] AC-48: contradicts rule 1 on emissives in the ring
- [BLOCKING] AC-7: exact float equality on frame 27
- [BLOCKING] AC-36: bullets mis-indented; Retreat/Quit inherit the restore clause
- [BLOCKING] AC-8: impossible combined state; particle clause cannot fail
- [BLOCKING] AC-31: 16.6 ms median flaps under vsync (16.67 ms)
- [BLOCKING] Formulas hit_punch / AC-21: h/v_offset translates the camera (parallax), not a pure screen shift
- [BLOCKING] Rendering constraints / AC-32: pin glow_bloom = 0, threshold in the profile; HDR read impossible on post-tonemap SubViewport output
- [RECOMMENDED] ko_hold, defeat_hold, victory_hold; Slow battle speed; playtest ACs for the fantasy; speed_cap ignores floored plain beats; missing-animation wind-up "real time" vs scaled; float epsilon at the reaction_hold corner; hold_wall below beat_min; punch replace rule cannot fire; Reduced punch 0-1 px; follow-camera bounds clamp; Victory settle brightness; t_last_flash initial value; Reduce Flashing caps all gated sources; replay indicator disclosure; Fast-forward Always setting; number linger; colorblind shape blurred/dimmed; pin red-flash encoding; capture tool mask pass/AA off; AC-35 vacuous at 1080p; AC-55 retag; overworld row shimmer (E2); 5 AC coverage gaps; stretch_y pivot and cull margin; HDR output off; per-preset shadow offset; silhouette test design; registry replay_time variables stale (anim_i; missing dt_max, blend_boss, boss_hold, hold_wall)
- [TRACKED] ADR-0005: actor shadows, boss shake, stretch_y, sky energy, glow threshold, flip mirroring under the override, keep_aspect fov axis, stretch settings in project.godot; AC-31 budget adequacy (draw-call count, 4K run, hitch percentile, Overworld/Camp budgets) under OQ 13
Reviewed-Content-Hash: design/gdd/sprite-camera-presentation.md 6edbe551a71673ffef74a6fead628a8cab73a0b1
Reviewed-Content-Hash: design/registry/entities.yaml 08473c8f9858e26e2ac93ca308ef8fb4224c4c5c
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md ce9474efabc4e96a62cf7d8e9859316615a4189d
Reviewed-Content-Hash: design/gdd/input-system.md f6b7d3a8e30147ffd4980d0e391507f549864484
Reviewed-Content-Hash: design/gdd/game-state-scene-flow.md a84c1406aca840d445191a9194cca07e779c6a62
Reviewed-Content-Hash: design/art/art-bible.md ca1567ea1d5bd6e46b206de89202b6952166212a
Reviewed-Content-Hash: docs/architecture/adr-0005-sprite-camera-presentation.md 20764a52db5a975557d58becbc17a53d1cf1fbcc
Reviewed-Content-Hash: docs/architecture/adr-0006-battle-replay-ownership.md fbef66e4a18531c15d2cbcc4bb8b9e7531d88dfc
Reviewed-Content-Hash: docs/architecture/adr-0002-game-state-scene-flow.md e9bc78265056b6bd35365b634dc3d3f1d16454ce

## Review — 2026-10-22 — Verdict: MAJOR REVISION NEEDED
Review mode: full · Workflow: full
Scope signal: XL
Specialists: game-designer, systems-designer, qa-lead, ux-designer, gameplay-programmer, godot-specialist, art-director, performance-analyst, creative-director (senior)
Blocking items: 17 (grouped) | Recommended: ~40
Summary: Revision 4 honestly closed the review-3 list, and the vision, registry alignment and Input amendment hold. Two core models must now be replaced rather than patched. The Y-locked sprite geometry (keystone lean, per-height texel aspect, overworld squash, back row hidden; AC-35 fails on a correct build) gives way to screen-aligned billboards at the projected foot anchor. Replay timing moves out of rule 9 into ADR-0006, whose current text contradicts rule 9 in at least five places. Both changes shorten the GDD. The Terminal Cyan flood, party-heal and zero-change outcomes, input guard scope and a set of defective ACs also gate.
Prior verdict resolved: Yes for the review-3 list (call order, impact_frame, post-impact clock, single blend clock, number clearing, latch/Cancel, holds, texel formula on the centre column, flood cap, AC-48/7/36/31/21b, Input amendment). The replay clock/call-order cluster is NOT closed against ADR-0006, which triggers the review-3 condition to move it there.
Rulings (creative-director):
- (1) PARTLY REVERSES review 3: one player latch level. Any press (Confirm, fast_forward, a click on the indicator) speeds plain beats only. Knockouts and the first-encounter boss hold are never sped by a press. An opt-in "Speed up all replay beats" setting (default off) covers motor access. One indicator text. Needs a one-line Input GDD follow-up.
- (2) Narrow guard plus feedback:
  - a press must begin after the full reveal;
  - presses within ~0.15 s of any menu opening are blocked for every menu action, Cancel and target selection included;
  - a refused press gets visible and audible feedback;
  - hover never steals default focus.
- (3) Replay timing moves to ADR-0006 now, and the ADR rewrite is done before re-review. The ADR gets:
  - the state machine and signals;
  - the call order, with start_battle(false) and the resync order;
  - the latch and cancel;
  - the advance() event order and leftover dt;
  - the outcome-to-animation map;
  - boss_combatant.
  Rule 9 keeps the player-facing guarantees plus the replay_time formula.
- (4) Defer the automatic speed-up (speed_cap, replay_cap) to an Open Question.
- (5) Boss takeover plays in full on first encounter, with a short settle on Retry.
- (6) Adopt the screen-aligned billboard in this GDD now. Delete stretch_y, the phi check and texel_aspect_tol, and restage the DQ/CT arc. ADR-0005 owns the build.
- AMENDS the review-3 flood ruling:
  - chroma at most ~70% of the signature AND at least a delta-E floor from the planet's native sky;
  - light floods flip to dark-against-light polarity;
  - the enemy-vs-flood margin is relative to the flood;
  - a minimum visible sky share.
- Art bible: the §2 L55 wording gates now; the §4 swatches gate only AC-34's testability.
Findings:
- [BLOCKING] Rule 2 / depth_spread / AC-35: Y-locked quads lean tan(psi)·tan(pitch) off-centre, texel aspect varies over a sprite's height, overworld edge squash is ~15%, depth_spread 0.10 allows a 10% mixed pixel scale, and the back row is ~80% hidden. Adopt screen-aligned billboards and restage
- [BLOCKING] Rule 6/9 vs ADR-0006 and ADR-0002 §7: Retry order is wrong (Game State calls restore_start_snapshot in SWAP; start_battle() full-heals, so it must be start_battle(false)); resync is stale; no reveal-gate API. Move the controller contract to ADR-0006
- [BLOCKING] Rule 9: no outcome-to-animation mapping (Defend plays attack); the same actor in back-to-back beats breaks AC-13
- [BLOCKING] Rule 9 / Edge Cases / AC-14: Family Meal is one outcome with target null and a summed hp_delta, so per-member numbers and displayed HP have no data; Stun and Viral Stunt get no reaction and would show "0"
- [BLOCKING] Rule 9 input: the guard is defined for Confirm only; Cancel and target selection are unguarded; a refused press gets no feedback; no pointer path to the latch; the indicator advertises the knockout-speeding level; Cancel conflicts with Input OQ 1
- [BLOCKING] Rule 6 / flood: the Terminal Cyan flood (C*≈25) matches Canada's native sky; a neutral rim can't reach 3:1 on light floods; the absolute chroma margin is impossible for Cyan and is measured on a desaturated rim band; no minimum sky share; the AC-34 rim clause is vacuous
- [BLOCKING] Art bible §2 L55 still says the signature colour floods the sky
- [BLOCKING] Formulas read_order: the edge band can be empty at 720p (NaN)
- [BLOCKING] Formulas / Tuning Knobs: "any in-range combination passes" is false (blend_victory vs victory_hold); settle <= victory and the key:fill ordering are not validated
- [BLOCKING] Formulas follow_camera / AC-27: a box clamp on a trapezoid ground footprint, unbounded at shallow pitch
- [BLOCKING] AC-53 is vacuous (the UI-alone pass has no world behind it)
- [BLOCKING] AC-45 cannot pass (guard anchor); AC-54/AC-60 use exact float equality at input_quiet
- [BLOCKING] AC-8's particle clause cannot fail headless; AC-32/AC-34 depend on an unbuilt hook and shadow-mask pass with no pending marker
- [BLOCKING] AC-25's aggregation setup is impossible (15% + 15% >= 25%); AC-21 rounding ties; AC-26's inclusive "between"
- [BLOCKING] AC-31: a median of medians can't see hitches; add p99, worst-frame and >33 ms clauses (numbers pending OQ 13)
- [BLOCKING] Lighting presets: change values only, never switch shader features (compile stutter), or warm them at Boot
- [BLOCKING] No playtest AC for the anchor moment (requested in review 3)
- [RECOMMENDED]
  - Let hit reactions run past the hold, and give zero-HP outcomes a status reaction.
  - Battle Speed 2× is ~1.15× in practice.
  - Short boss-takeover variant on Retry.
  - Party jokes are drawn from behind (a restage note).
  - The set light rotates during the blend; blob shadows vs the raking light.
  - Defeat spotlight and Victory burst detail.
  - The 720p punch lasts 2 frames.
  - speed_max is unreachable and flash_rate_reduced is dead (moot after the deferral).
  - hold_wall depends on the guard timing.
  - AC-24, 11, 13, 59, 55, and the red flash in AC-55b.
  - Coverage gaps: indicator screenshot, Victory settle, spotlight width, toy-block shadows, occupied presets.
- [TRACKED]
  - ADR-0005:
    - the hit-punch mechanism (frustum_offset vs fov/keep_aspect);
    - frame vs frame_tex under material_override;
    - TIME lint scope (sky, particle, fog, AnimatedTexture);
    - capture SubViewport settings and the post-exposure glow read;
    - render-scale/stretch pinning and the particle pause owner;
    - shader warm-up and the billboard build details.
  - TD under OQ 13: draw-call value, 4K, Menu blur cost, target hardware, VRAM.
Reviewed-Content-Hash: design/gdd/sprite-camera-presentation.md 3df3b8be1dcabbfdc8680c4f71cdba3b4fbd9dba
Reviewed-Content-Hash: design/registry/entities.yaml 95ab648abcd5b3d9e47886b8e27c278e776b571b
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md ce9474efabc4e96a62cf7d8e9859316615a4189d
Reviewed-Content-Hash: design/gdd/input-system.md 9d02cab7ea6e0e3a142cb9cc23ae119cf6691025
Reviewed-Content-Hash: design/gdd/turn-battle-system.md 8dac8b9330ef30d70675b97e2ef7881ba75a671b
Reviewed-Content-Hash: design/art/art-bible.md ca1567ea1d5bd6e46b206de89202b6952166212a
Reviewed-Content-Hash: docs/architecture/adr-0005-sprite-camera-presentation.md 20764a52db5a975557d58becbc17a53d1cf1fbcc
Reviewed-Content-Hash: docs/architecture/adr-0006-battle-replay-ownership.md fbef66e4a18531c15d2cbcc4bb8b9e7531d88dfc
Reviewed-Content-Hash: docs/architecture/adr-0002-game-state-scene-flow.md e9bc78265056b6bd35365b634dc3d3f1d16454ce

## Review — 2026-10-22 — Verdict: NEEDS REVISION
Review mode: full · Workflow: full
Scope signal: XL
Specialists: game-designer, systems-designer, qa-lead, ux-designer, gameplay-programmer, godot-specialist (probed the 4.7.2 binary), art-director, performance-analyst, creative-director (senior)
Blocking items: ~30 upheld (grouped A–E below; ~49 raised before dedup) | Recommended: ~100
Summary: Revision 5 closed most of review 4. The vision, ADR-0006 citations and every worked example hold. Speed: the opt-in setting gets real motor access, knockout wind-ups become plain beats with the slump hold at 1×, and the indicator gets a passive state. The visual model is restructured around dusk floods, a backdrop sky card, constant integer texels and a shift-lens battle camera. A measured shader-compile contract replaces "values never features". Mechanism and measurement procedure move to ADR-0005, ADR-0006 and a presentation test plan. The next pass is a targeted review, not a sixth full one.
Prior verdict resolved: Mostly (15/17 design-side review-4 blockers closed; the blocked-hit drift and the weak AC-66 remain)
Rulings (creative-director):
- (1) NARROWS rev-2: with "Speed up all replay beats" On, protected content takes the plain-beat speed, Battle Speed included, with no press. Default: Battle Speed never speeds protected content. Rename the setting literally (e.g. "Speed up boss entrances"). Delete "never shortens a hold".
- (2) Knockout wind-ups are plain beats. hold_i = max(ko_hold, time from impact to the KO landing frame), always 1×, keyed on knockout, not on protected. Takeover protection stays. Future combo protection protects the landing, not the wind-up.
- (3) The indicator gets a passive (verbless, dimmed) state whenever no press would change anything left in the replay; a press then gets refusal feedback. A latched indicator click un-latches. Strict battle_speed_mult < ff_mult (defaults 1.5 / 2.0). Label "Faster battle animations: Off/On". Fix "[Cancel] normal speed".
- (4) Art direction (D1–D4 adopted, user to ratify):
  - D1 dusk floods (all L* ≤ ~35, neon horizon). REVERSES the rev-4 light-flood polarity flip: delete flood_light_l and the polarity branch.
  - D2 a backdrop sky card (unlit, uniforms, tagged sky).
  - D3 constant integer texels: T = H/360 px, with depth for occlusion only.
  - D4 a shift-lens battle camera (level camera + vertical frustum_offset; pitch_max goes).
  - GS-B1 stays for the pitched Overworld/Camp cameras, as an upright-card occlusion guarantee.
- (5) REPLACES rev-4 "values never shader features": after the Boot warm-up, no preset or state cycle compiles a pipeline. AC-64 becomes [P] on the RENDERING_INFO_PIPELINE_COMPILATIONS_* counters. The list of compiling parameters goes to ADR-0005.
- (6) Gating split:
  - the GDD gates on contradictions, guarantees, formulas/knobs and defective ACs;
  - the ADRs gate on mechanism;
  - stories gate on tools, budgets and test infrastructure.
- (7) Over-specified: cut mechanism and procedure. Rules become guarantees + knobs + formulas; ACs become observable outcomes + test-plan IDs.
Findings:
- [BLOCKING] Rule 9/13 (A): the motor path (ruling 1) and L246 vs L557; KO protection (ruling 2); the indicator lies during protected content (ruling 3); battle_speed_mult = ff_mult makes the latch a no-op
- [BLOCKING] Rule 9 input (A): held nav repeats move focus after the guard; the 1 px pointer focus contradicts Input pointer_switch_px (needs an Input GDD amendment)
- [BLOCKING] Rule 10 (A): no `victory` animation in the required/fallback set
- [BLOCKING] Rule 9 (B): a blocked hit is `status` in L149 vs `hit` in ADR §7, Edge Cases and AC-14b; the Family Meal healer is also healed, so the actor-as-reactor precedence is undefined
- [BLOCKING] Header/AC-56 (B): stale L8 auto speed-up note; Status mismatch; no defeat_hold fixture
- [BLOCKING] Rules 2/4/6 (C): the sky can't be in frame; the polarity dead band; the rim/edge bands lie inside the outline texel; enemy-vs-flood passes red-on-red (ΔE≈4); the native-sky floor 20 vs 15 and an out-of-gamut example; mixed pixel scale uncontrolled; screen-aligned constant-depth occlusion clips upper bodies into the set behind them; rows overlap (needs a row-separation formula)
- [BLOCKING] Rule 13 / flash_gate (D): books at request time, not when the pair lands (5 flashes/s possible); the boss flood can't be both capped and reach its swatch; no composite-frame flash test, and Menu/Defeat stamp/results are missing as sources; red encoding unpinned; hard limits not validated at load
- [BLOCKING] read_order (D): a perimeter average passes one-sided invisibility (use sectors)
- [BLOCKING] follow_camera (D): the horizon/footprint check breaks below 16:9 (effective F_v)
- [BLOCKING] ACs (E): AC-2/19/58 vs ADR-0005 and headless-unobservable; AC-26 "strictly between"; AC-21 ties; AC-22/AC-7 threshold frames; AC-25 exact 0.10; squad untint untested; AC-24 Victory times undefined; AC-8 [C] can't fail; AC-66 gates nothing
- [RECOMMENDED] Raise blend_boss/boss_hold toward ~1.0 s each; zero the hold on Defend/no-reactor beats; set a pacing target + OQ16 trigger; input during end-of-fight holds; MVP owner of the refusal tick; mashing Confirm spends MP via last-used focus; AccessKit + UI text contrast; numbers visible ~0.1 s when latched; flash_rate_reduced dead; brightness ranges not chained; Victory settle duration; Retry light pop under a capped flash; no-effect specials; missing AC-14b moves; MP floats; HUD reads the live round; AC tags → [I]; spies on the wrong object; deterministic RNG; [UI] screenshot ACs; uncovered rules
- [TRACKED → ADR-0005] screen-aligned billboard (still Y-locked); upright-plane DEPTH; PROJECTION_FRUSTUM + frustum_offset formula; sky backdrop mesh (the Environment sky doesn't shift with frustum_offset; observed); rim excludes the outline; integer-texel mechanism; capture-tool build step 1c + story; ID-pass spec (SubViewport doesn't inherit MSAA/AA; shadow atlas 2048 vs 4096; observed); measured compile contract + same-config warm-up; backend pin (resolves to Vulkan; observed, contradicting engine-reference rendering.md); GlobalUniformSink (global_shader_parameter_get returns null at runtime; observed); actor shadows; translation shake
- [TRACKED → ADR-0006] snapshots at turn_started/battle_ended (stale is_defending; AC-14 fails); display_resynced() + a SWAP reset on Retry; tolerance per event, not per beat; KO-keyed holds; speed rules from rulings 1–3; end-hold cancel on exit; Retry cancel at transition_started(BATTLE, BATTLE); clear squad transients on first entry
- [TRACKED → test plan / TD] AC-31: target hardware and budgets; mode-time windows; wall-clock interval metric; cold-start definition; draw-call clause Pending (150 vs an estimated 190–275); the flash-analyser tool
Reviewed-Content-Hash: design/gdd/sprite-camera-presentation.md 569d07ef08c0c7a9fec591f31a17ee8417c76c76
Reviewed-Content-Hash: design/registry/entities.yaml 7c5c1d7d6e13c683599ad8489f835c116be250ed
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md ce9474efabc4e96a62cf7d8e9859316615a4189d
Reviewed-Content-Hash: design/gdd/input-system.md 85c43bb090321613c96679e7f2351beed2e0b8c2
Reviewed-Content-Hash: design/gdd/turn-battle-system.md 8dac8b9330ef30d70675b97e2ef7881ba75a671b
Reviewed-Content-Hash: design/art/art-bible.md 5493bc58da41f223042b00adface6bd64d1851e0
Reviewed-Content-Hash: docs/architecture/adr-0005-sprite-camera-presentation.md 20764a52db5a975557d58becbc17a53d1cf1fbcc
Reviewed-Content-Hash: docs/architecture/adr-0006-battle-replay-ownership.md c70e27e445be64fa80fdfa54037977f367d5fdbd
Reviewed-Content-Hash: docs/architecture/adr-0002-game-state-scene-flow.md e9bc78265056b6bd35365b634dc3d3f1d16454ce
