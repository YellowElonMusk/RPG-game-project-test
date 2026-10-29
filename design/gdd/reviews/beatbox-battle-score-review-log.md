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
