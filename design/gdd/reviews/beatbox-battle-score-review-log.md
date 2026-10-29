# Beatbox Battle Score — Review Log

## Review — 2026-10-29 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean mode)
Blocking items: 6 | Recommended: 9
Summary: The concept and the assignment and quantise maths hold up, and every formula example checks out. But the start-on-the-beat timing contradicts Game State's real wipe numbers, the replay hookup names events ADR-0006 doesn't emit, and under the current Paris rosters (one 40 HP Clerk against four, fights over before round 4) players would hear a two-stem, 800 Hz-muffled loop and almost never the drop the GDD calls Paris's payoff.
Prior verdict resolved: First review
Findings:
- [BLOCKING] R7/F6/AC-6/OQ-6: battle t_out is pinned at 0.35 s (0.15–0.50), so count_in_beats is 0 at every tier; F6's 0–2 s range and AC-6's 1.2 s are impossible; "reveal" is undefined and an unbounded swap sits between out and in, so bar 1 can't be scheduled at out-phase start
- [BLOCKING] R8/R9/Interactions: ADR-0006 emits beat_started/beat_impact/beat_finished(plan), round_advanced_after_replay, battle_ended_after_replay, display_resynced, replay_cancelled; the GDD names none, doesn't say which marks "the player sees the knockout", and doesn't handle resync or cancel
- [BLOCKING] R9/F5: does the knocked-out alien's stem keep looping through the choke tail (up to 3.26 s), or stop with a separate tail sample? F5 fades the stem only after the tail
- [BLOCKING] R10/Game Feel vs current Paris rosters: street fights end before round 4, so most Paris fights are all-muffled and the "payoff drop" rarely fires; also, a win before round 4 plays the sting through the low-pass if the filter is on the Music bus
- [BLOCKING] R1/Edge mixed roster/AC-17/AC-20: `kind` is per faction and an encounter has one faction_id, so a mixed roster can't be detected, and validation can't know which enemies need beat_role
- [BLOCKING] Dependencies: none of the six related GDDs mention this system; Content Data fields, FactionRule.score_escalation_round and the ADR-0006 consumer are owed changes
- [RECOMMENDED] F1/F2: is_boss for F1 is the encounter flag, but "a boss takes lead" and the two-bosses case need the enemy-record flag (enemy_supervisor.tres is_boss = true); say which
- [RECOMMENDED] F4/AC-12: the Supervisor's max_hp is 110 in data, not 120; use a named fixture or 110 (threshold 55)
- [RECOMMENDED] R13: the bible puts the cry at the start of the fight, and the story encounter and boss use authored openers; say where the break lands (bar 1? bar 2?) and whether openers get one
- [RECOMMENDED] R10: put the waiting-room filter on the score's own submix, not the shared Music bus the stings use
- [RECOMMENDED] Tuning Knobs (advisory at standard): about 15 knobs are scattered; duck_db has no default or range
- [RECOMMENDED] F1/R5: base 2 and base 3 bosses both clamp to 4, and at base 3 a story override can't sit between street and boss; add a boot check that the computed tier exists in the kit
- [RECOMMENDED] Edge revive: no revive exists in the battle system; mark it speculative or drop AC-24
- [RECOMMENDED] AC-19: "no dropout heard" and "latency stays stable" aren't measurable; name a Performance monitor and a threshold
- [RECOMMENDED] OQ-2: AudioStreamSynchronized's stream cap and runtime volume behaviour on 4.7.2 aren't sourceable from docs/engine-reference; size the per-kit sub-stream count against it
Reviewed-Content-Hash: design/gdd/beatbox-battle-score.md 3ecef42f4da8d815db406299f4a495085c304fbc
Reviewed-Content-Hash: design/registry/entities.yaml b7efb174ffc61286e6bbb670ecef6dd143c578b5
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-state-scene-flow.md b65a7535b61dd17a260c4c004385526dd7612415
Reviewed-Content-Hash: design/gdd/turn-battle-system.md bfd1c3df45b9c6ed09a1109eb2973bcf0bf401d8
Reviewed-Content-Hash: design/gdd/faction-rule-modifiers.md 1812a7f6bd58080ebc680ca89b34742f9258d55b
Reviewed-Content-Hash: design/gdd/content-data-definitions.md 92373198b9110a2897377e3b8e2c8b5f10d2d16f
Reviewed-Content-Hash: design/gdd/sprite-camera-presentation.md 1b8c310076c4fa6dcbceb63497c1174b95df0064
Reviewed-Content-Hash: design/gdd/overworld-exploration-encounters.md 7a44660f28e3c56b44ce27386638e2736d774941
Reviewed-Content-Hash: design/narrative/narrative-bible.md 004b0c144abc39bb5ce7b014530fe1264c347d7e
Reviewed-Content-Hash: design/accessibility-requirements.md d189369b593125eb126ab47313b12e3f1f5ea02d
Reviewed-Content-Hash: docs/architecture/adr-0006-battle-replay-ownership.md e0850122343bf2036da37a113b75e78492f9f30a

## Review — 2026-10-29 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean mode)
Blocking items: 4 | Recommended: 6
Summary: Revision 2 resolves all six earlier blockers: the replay signals, the choke tail, the per-enemy alien test, the Paris held/unheld split and the bidirectional dependencies are all correct against ADR-0006, Game State and the data. Four new defects block. The last-alien rule sounds the victory sting while humans still stand. F2's stated output, and AC-2g, contradict its own pass order. Nothing names which faction record supplies the kit and tier, now that alien-ness is decided per enemy. And bar 1 can't "follow transition_finished" after it has already been scheduled.
Prior verdict resolved: Yes (all 6 prior blockers addressed; residuals below)
Findings:
- [BLOCKING] R9/R14/Edge mixed roster/AC-10: "last alien's knockout" cuts the stems and plays the victory sting, but in a mixed roster humans still stand (the Edge case says the floor pulse plays on); and the sting has two triggers (R9's knockout and R14's battle_ended_after_replay(true)) with no rule for which fires it or how the second is ignored
- [BLOCKING] F2 output range/AC-2g: pass 3 (doublers) runs before pass 4 (free roles), so 8 aliens on kick/snare/bass/hats give 4 holders + 4 extras with lead and fx empty, not "6 holders and 2 extras"; decide the intended order and fix the claim and AC-2g's unspecified fixture
- [BLOCKING] R1/R15/F1: with alien-ness per enemy, nothing says which faction record supplies score_kit_id and score_base_tier (enc_.faction_id? the first alien's?), what a roster from two alien factions does, or where band mode's tier comes from (score_base_tier is alien-only)
- [BLOCKING] R7/F6/States: bar 1 is scheduled ahead at mode_entered + t_in, then must "follow transition_finished" if they differ by more than one mix block; a started downbeat can't move, and a frame-quantised signal routinely differs by more than one block (16.7 ms vs ~10 ms). Pick one source and make the tolerance match AC-6's 20 ms
- [RECOMMENDED] R8: display_resynced also fires during SWAP at first entry and on Retry (ADR-0006 §5 step 8, Retry step 7), while the score is Armed; say it is ignored outside Playing and add an AC
- [RECOMMENDED] Edge two bosses/AC-21/F2/F4: ADR-0006 §5 step 3 fails a boss encounter with more than one is_boss enemy; scope the edge to non-boss encounters and use boss_combatant for lead and R11
- [RECOMMENDED] States: Ducked is a state that exits only to Playing, so a pause during Break loses the break; make it a flag. Also say whether Ending -> Armed on a Retry pressed during the defeat sting, and that the Defeat Prompt overlay doesn't duck
- [RECOMMENDED] R3/R11/R15: say whether the lead hook belongs to the kit or the boss enemy, where hooks A/B live in data, and what a non-boss lead holder sings
- [RECOMMENDED] F5: ceil gives zero lead time for an event exactly on a beat; add a minimum scheduling lead (one mix block) before the boundary, else take the next one
- [RECOMMENDED] Ducked/AC-15/Visual-Audio: the duck is on the Music bus in AC-15 but the stings share that bus; say whether duck_db applies to the score submix or the bus
Reviewed-Content-Hash: design/gdd/beatbox-battle-score.md 01db337bfefff9401ebee2de96e7693f3375d470
Reviewed-Content-Hash: design/registry/entities.yaml b7efb174ffc61286e6bbb670ecef6dd143c578b5
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-state-scene-flow.md c757b301c857826be59addc3e21b98851103c02c
Reviewed-Content-Hash: design/gdd/turn-battle-system.md eb7148a0607e41c959c12152725ea00a4398a651
Reviewed-Content-Hash: design/gdd/faction-rule-modifiers.md 2e711a51a5b94753efcbd7784a71afd1ee95adbd
Reviewed-Content-Hash: design/gdd/content-data-definitions.md 496b2a01d759b8200b11bdf5681dce8be00589ef
Reviewed-Content-Hash: design/gdd/sprite-camera-presentation.md 1a951d3366b993a0af286da7eae803c16ba3c89b
Reviewed-Content-Hash: design/gdd/overworld-exploration-encounters.md ef9da0fe8878bea2f6d2768eb8985d5f388aa120
Reviewed-Content-Hash: design/narrative/narrative-bible.md 004b0c144abc39bb5ce7b014530fe1264c347d7e
Reviewed-Content-Hash: docs/architecture/adr-0006-battle-replay-ownership.md e0850122343bf2036da37a113b75e78492f9f30a

## Review — 2026-10-29 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean mode)
Blocking items: 3 | Recommended: 7
Summary: Revision 3 fixes all four rev-2 blockers. The humans-still-standing sting, the kit and tier source, bar-1 scheduling and F2's pass order are now correct, and every formula example checks out. Three new defects block. AC-2g's first fixture contradicts F2: the eighth alien doubles `kick`, not `hats`. Nothing triggers Fled, because ADR-0010 adds `battle_fled_after_replay()` and R8 doesn't read it. And no state exits on leaving battle while Playing (Quit to Title from the Menu), so the loop would play on into the title screen.
Prior verdict resolved: Yes (all 4 rev-2 blockers addressed)
Findings:
- [BLOCKING] AC-2g/F2: 8 aliens all snare/hats give extras on snare (pass 3) and kick (pass 4, the first empty extra slot in R2 order), not snare and hats
- [BLOCKING] R8/R14/States: Fled has no source signal; ADR-0010 §5 adds battle_fled_after_replay(), absent from R8's table
- [BLOCKING] States/R8: transition_started(BATTLE → non-battle) is unhandled; replay_cancelled fires only if something was queued and R14 has no branch for Quit/exit, so Playing never ends
- [RECOMMENDED] R8: replay_cancelled also fires at the start of the Retry OUT (ADR-0006 Retry) while the score is Ending or Armed; say it is ignored outside Playing/Break
- [RECOMMENDED] R7: "scheduled on the audio clock" needs a mechanism; a player can't start at a future mix time (NOT SOURCEABLE for 4.7.2), so say the stream starts at mode_entered with lead-in silence, or fold it into OQ-2's ADR
- [RECOMMENDED] R7 Arm: loading a kit synchronously on transition_started hitches the wipe-out; load threaded across out+swap, and say what happens if it isn't ready at mode_entered
- [RECOMMENDED] R13: a non-final knockout during the cry break (its fade and tail in silence) is unspecified
- [RECOMMENDED] F5: `now` is the stream's playback position, which wraps every loop; define a monotonic music time so bar numbers stay meaningful
- [RECOMMENDED] R14/States: the defeat sting's timing against the Defeat Prompt (opens after defeat_hold), and how Ending knows the sting finished, are unstated
- [RECOMMENDED] R10/R4b: say whether the full_house layer has a base variant and sits under the held filter
Reviewed-Content-Hash: design/gdd/beatbox-battle-score.md 98a49dc273752f6efcd5d2c9258c713e2c6c28b0
Reviewed-Content-Hash: design/registry/entities.yaml b7efb174ffc61286e6bbb670ecef6dd143c578b5
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-state-scene-flow.md c757b301c857826be59addc3e21b98851103c02c
Reviewed-Content-Hash: design/gdd/content-data-definitions.md f4ea2de1495f757543cdbecf870cb627e901670a
Reviewed-Content-Hash: design/gdd/overworld-exploration-encounters.md ef9da0fe8878bea2f6d2768eb8985d5f388aa120
Reviewed-Content-Hash: docs/architecture/adr-0006-battle-replay-ownership.md e0850122343bf2036da37a113b75e78492f9f30a
Reviewed-Content-Hash: docs/architecture/adr-0010-turn-battle-system.md dd7e58e6e387ec673a7f550dc09047c599366e7d
