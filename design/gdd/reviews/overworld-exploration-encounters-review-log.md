# Review Log — Overworld Exploration & Encounters

## Review — 2026-10-23 — Verdict: NEEDS REVISION
Review mode: full · Workflow: full
Scope signal: XL
Specialists: game-designer, systems-designer, level-designer, ai-programmer, ux-designer, qa-lead, godot-specialist, narrative-director; senior: creative-director
Blocking items: 18 | Recommended: ~40
Summary: Fantasy, pillar mapping and arithmetic are sound, but the design has a core-loop defect: in MVP nothing motivates an overworld fight, so avoiding them is dominant and the boss's faction rule goes untaught. It also has a wide band of undefined terms: critical path and required exit, the symbol sub-state machine, safe zones and blockers in the movement model, and liberation timing. The region never looks liberated after the boss, and nothing guards against the real-world parallel to occupied Paris in 1940–44. Heavy-end NEEDS REVISION: a full revision pass and re-review, not a redesign.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Core Rules R4/R7/R9: no non-loot payoff for overworld Victory; avoidance dominant; add one telegraphed dungeon-threshold story encounter + pre-dungeon camp registration
- [BLOCKING] Core Rules R10/R12/R16: "critical path" / "required exit" undefined (AC-29/31/42/50 uncheckable)
- [BLOCKING] Core Rules R12: bypass check ignores checkpoints/blockers/stage, not conservative; no dungeon pressure floor
- [BLOCKING] Core Rules R16: faction-rule clue window can be empty; OQ-14 should be rule + AC
- [BLOCKING] Core Rules R5: no symbol sub-state transition table (re-notice loops, stunned contact, Noticing movement, empty path, leader in safe zone)
- [BLOCKING] Core Rules R5/R12/R16: safe zones and route blockers have no movement/pathing model
- [BLOCKING] Formulas / Tuning Knobs: knob constraints missing from the load-time invariant list
- [BLOCKING] Core Rules R5 / symbol_speeds: give-up distance metric unspecified (Euclidean through walls → endless chase)
- [BLOCKING] Formulas chase_visibility: fails at 21:9; over-strict dead-zone term; sprite DOF exemption impossible
- [BLOCKING] Core Rules R7/R9/R14 + Game Feel: liberation timing contradiction (on_thawed vs transition_finished)
- [BLOCKING] States and Transitions: Exploring exits incomplete (gag, succeeding checkpoint, encounter checkpoint, camp prompt)
- [BLOCKING] Visual/Audio + UI: interact pip vs P6 prompt conflated, trigger mismatch; dialogue re-trigger loop
- [BLOCKING] Visual/Audio: navigation-assist commitment (accessibility doc) silently redefined
- [BLOCKING] Core Rules R8/R13: region never looks liberated post-boss (art bible: golden-hour return is the reward); map card still says Saturated
- [BLOCKING] Player Fantasy: no guardrail against the 1940–44 occupied-Paris parallel ("checking papers", "complicit" civilians, liberation crowd)
- [BLOCKING] Core Rules R8/R16: narrative sign-offs not actionable; no interim MVP story-flag registry
- [BLOCKING] Acceptance Criteria: AC-9/20 threshold frames, AC-26 timing via [VF], AC-44 subjective, AC-46 unrunnable, AC-47/48 no evidence location
- [BLOCKING] Player Fantasy / Onboarding: nothing teaches that Clerks are optional
- [RECOMMENDED] ADR-0012 inputs: GroundMover speed param, waypoint tolerance, diagonal mode, runtime blocker overlay + SAFE bit, swept contact, repath stagger, Engine.time_scale ban, R15 narrowing, AC-30 CSG/GridMap collision
- [RECOMMENDED] ADR-0005 inputs: lighting profile per faction × stage, sky_card, travelling interior light + pipeline warm-up
- [RECOMMENDED] many AC splits/coverage gaps (qa-lead), facing-weighted notice, camp prompt default, redirect hazards, clue wording, stage-raise announcements, recruit remarks
Reviewed-Content-Hash: design/gdd/overworld-exploration-encounters.md 67081b46dcc1e95a5894151329deb8173349d9cd
Reviewed-Content-Hash: design/registry/entities.yaml 386982a9606488385ee82293f1d3729d5251a2b4
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md ce9474efabc4e96a62cf7d8e9859316615a4189d
Reviewed-Content-Hash: design/gdd/input-system.md 59917d823d98ee03f0cd97d8fcc102f4782bbc52
Reviewed-Content-Hash: design/gdd/sprite-camera-presentation.md 1b8c310076c4fa6dcbceb63497c1174b95df0064
Reviewed-Content-Hash: design/art/art-bible.md 3bdf3dc5ecd7ec7873ed70d0fc65d80f2c9b4c18
Reviewed-Content-Hash: design/accessibility-requirements.md c8a7a5edc0eca9817c50a3e774c3846ae1c4c354
Reviewed-Content-Hash: design/ux/interaction-patterns.md 32f2edacaae1c608d88c7309a44a1fe9f6fd6b0d

## Review — 2026-10-23 — Verdict: NEEDS REVISION
Review mode: full · Workflow: full
Scope signal: L
Specialists: game-designer, systems-designer, level-designer, ai-programmer, ux-designer, qa-lead, godot-specialist, narrative-director; senior: creative-director
Blocking items: 24 (after CD downgrades) | Recommended: ~45
Summary: Round-1 structural blockers are fixed (liberation timing, clue window, sub-state table, interact pip). The story beats fire in the wrong place: both registry stage raises respond to the player (contradicting rule 8) and land on maps behind the player, the post-boss payoff is skippable, and the Intake Desk can neither be touched nor safely fled. Also chase-AI correctness bugs (notice/give-up loop, no contact with a still leader, stale path distance) and guardrail-6 gaps (badge-wearers, immigration vocabulary). CD rulings: raises on faction schedule ahead of the player + cut Town stage 3 from MVP; in-mode fade home to the café after the boss; `open` unlocks optional gag pockets + a dungeon shortcut; Desk starts on confirm only, Fled redirects with a gag; beacon on screen from entry + junctions; guardrail 6 extended in part (black-market stamps stay).
Prior verdict resolved: Partly (10 of 18 resolved, 8 partial)
Findings:
- [BLOCKING] Rule 8 / rule 18 registry: stage raises triggered by player Victory/map entry (reprisal pattern) and on maps behind the player (Town stage 3 unseen)
- [BLOCKING] Rule 17 / chapter end: post-boss liberation skippable; unbeaten Clerks still chase; no liberated profile for interiors
- [BLOCKING] Rule 7a: victory payoffs hollow (repeated clue; `open`/`item` unlock nothing; chosen blind)
- [BLOCKING] Player Fantasy guardrail 6: badge-wearers; composite allegory test; immigration vocabulary; art-director co-sign
- [BLOCKING] Rule 8 / safe zones: decree gags contradict the clutter ban; one entry only
- [BLOCKING] Rule 13a: Desk contact impossible; Static pushed on Fled; Fled re-fight loop
- [BLOCKING] Rule 5 / I15: notice_path_cap_m > symbol_giveup_m loop
- [BLOCKING] Rule 5: stationary leader never contacted
- [BLOCKING] Rule 5 / I2: path distance undefined and stale; pending path; I2 ignores repath_s
- [BLOCKING] Rule 5: notice-test A* unbounded and unbudgeted
- [BLOCKING] Rule 5 / rule 12: patrol paths not checked against SAFE cells and stage blockers
- [BLOCKING] Formulas chase_visibility: DOF bound measured from focus, sprite height missing
- [BLOCKING] Rule 10 / rule 12: closed checkpoints fail the bypass search; no requirement-source model
- [BLOCKING] Rule 0 / chapter_walk_budget: legs can't end at Desk/boss; no step-to-leg link; L_crit two definitions
- [BLOCKING] Rule 11: EntryPoint can sit in the reverse MapExit (bounce)
- [BLOCKING] Rule 3: spent interactables still prompt
- [BLOCKING] Rule 19: beacon visibility claim contradicts the camera footprint
- [BLOCKING] Visual/Audio: off-screen payoffs audio-only
- [BLOCKING] Rule 16 / UI: clue and decree text only in sprites (no scale/loc/screen reader)
- [BLOCKING] Rule 10: checkpoint redirect has no carrying transition (needs ADR-0002 same-instance fade)
- [BLOCKING] Formulas / Edge Cases: AStarGrid2D bake order; Continue skips on_map_reenter respawn
- [BLOCKING] ACs: timing rule not applied (10b, 11, 12, 19b, 20a, 26a, 45b); AC-44 capture masks; AC-50b depends on advisory [PT]; tag gate levels; AC-8 split
- [BLOCKING] ACs: coverage sweep (flag registry, SAFE no-notice, lateral offset, liberation, decree gag, beacon, dof_near_end, sky L*, event-feedback VF, SFX twins)
- [BLOCKING] Rule 9: (C7 downgraded by CD to recommended) marker_activation slot claim false
- [RECOMMENDED] optional_teach as proximity bark; AC-46 tooling ownership; AC-32/35; ADR-0012 contract items (SymbolBrain, thaw, marker schema, camp registration, clock, process order, perf); Desk grievance line; grumble persistence; facing turn beat; GridMap collision default; light warm-up; N_min ≥ 1; swept-contact ε; I14 feasible ranges at h 12
Reviewed-Content-Hash: design/gdd/overworld-exploration-encounters.md 8077a80e567cedd163ce5d8c6e8171521db7c363
Reviewed-Content-Hash: design/registry/entities.yaml 0c2c4dcf90daa0bb9b50828cdf446728dc9e895d
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md ce9474efabc4e96a62cf7d8e9859316615a4189d
Reviewed-Content-Hash: design/gdd/input-system.md 59917d823d98ee03f0cd97d8fcc102f4782bbc52
Reviewed-Content-Hash: design/gdd/sprite-camera-presentation.md 1b8c310076c4fa6dcbceb63497c1174b95df0064
Reviewed-Content-Hash: design/art/art-bible.md 3bdf3dc5ecd7ec7873ed70d0fc65d80f2c9b4c18
Reviewed-Content-Hash: design/accessibility-requirements.md c8a7a5edc0eca9817c50a3e774c3846ae1c4c354
Reviewed-Content-Hash: design/ux/interaction-patterns.md 32f2edacaae1c608d88c7309a44a1fe9f6fd6b0d

## Review — 2026-10-23 — Verdict: NEEDS REVISION
Review mode: full · Workflow: full
Scope signal: S–M
Specialists: game-designer, systems-designer, level-designer, ai-programmer, ux-designer, qa-lead, godot-specialist, narrative-director; senior: creative-director
Blocking items: ~30 local (after CD downgrades) | Recommended: ~30
Summary: Rev 3 is structurally sound; what remains is local: the `permits_mandatory` trigger (walkable around), payoff supply, the shortcut bypassing the story encounter, free roam into the boss chamber, empty placement windows (story encounter, return-marker SAFE discs), an infeasible beacon guarantee, symbol-AI arithmetic (path_dist not an upper bound, chase starting past give-up, final approach off legal ground, budget starvation, unbounded notice search, I17), engine wording (AStarGrid2D dirty rebuild, two clocks), timed-text and overlay UX, two satire lines, checklist ticks and AC wording. CD rulings: opening-step decree; walk home lands at the segment's dungeon-side entry with the dungeon exit taped off; `victory_payoff: none` with limits; P15 chapter-end prompt; cut queue marshals and the 2031 board; waypoint-beacon chain. Next round: targeted verification (level-designer, ai-programmer, qa-lead) plus CD text check.
Prior verdict resolved: Mostly (round-2 A1, C3, D2, E1 partial)
Findings:
- [BLOCKING] Rule 18 registry: permits_mandatory trigger can be walked around; segment stage 1 unauthored
- [BLOCKING] Rule 7a: payoff supply below symbol count
- [BLOCKING] Rule 7a/12: dungeon shortcut can bypass the story encounter
- [BLOCKING] Rule 13/17: free roam reaches the boss chamber
- [BLOCKING] Rule 13a: story-encounter placement window empty
- [BLOCKING] Rule 0/10: return-marker SAFE discs swallow patrol areas near gates
- [BLOCKING] Rule 19: beacon guarantee infeasible; beacon_h_m vs wall_h_max
- [BLOCKING] Rule 5: path_dist not an upper bound
- [BLOCKING] Rule 5 / I16: chase can start past give-up
- [BLOCKING] Rule 5: final approach leaves symbol-legal ground
- [BLOCKING] Rule 5: query budget starvation and leaks; unbounded notice search; cache key
- [BLOCKING] Rule 5 / I17: turn warning too short
- [BLOCKING] Edge Cases: AStarGrid2D dirty-rebuild wording; two clocks; 4-connected labels and batched set_blocked
- [BLOCKING] UI: timed text too short; payoff card under overlays; Counter line surface; chapter-end prompt; Static icon
- [BLOCKING] Player Fantasy / rule 13a: queue marshals; 2031 appointment board; checklist ticks
- [BLOCKING] ACs: 28b, 40b, 27d, 10d, 7a, 26d, 46 case B; coverage sweep
- [RECOMMENDED] facing hysteresis; process_priority values; SpringArm3D/CSG ban; AC-31c definition; AC-54/45e thresholds; stray table header; pocket content; Counter bark + ticket prop; absurd permit name; rule 18 scope; test plan file
Reviewed-Content-Hash: design/gdd/overworld-exploration-encounters.md f7c2cfb7d4519e102eb45c391ab4c974b0ebcd55
Reviewed-Content-Hash: design/registry/entities.yaml 66684d233109fb218f2842a824a5cee1db075812
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md ce9474efabc4e96a62cf7d8e9859316615a4189d
Reviewed-Content-Hash: design/gdd/input-system.md 59917d823d98ee03f0cd97d8fcc102f4782bbc52
Reviewed-Content-Hash: design/gdd/sprite-camera-presentation.md 1b8c310076c4fa6dcbceb63497c1174b95df0064
Reviewed-Content-Hash: design/art/art-bible.md 3bdf3dc5ecd7ec7873ed70d0fc65d80f2c9b4c18
Reviewed-Content-Hash: design/accessibility-requirements.md c8a7a5edc0eca9817c50a3e774c3846ae1c4c354
Reviewed-Content-Hash: design/ux/interaction-patterns.md 32f2edacaae1c608d88c7309a44a1fe9f6fd6b0d

## Review — 2026-10-23 — Verdict: APPROVED
Review mode: full (targeted verification round, as ruled by creative-director in round 3) · Workflow: full
Scope signal: S–M
Specialists: level-designer, ai-programmer, qa-lead; senior: creative-director (text items and final sign-off)
Blocking items: 0 (after in-pass fixes) | Recommended: open items logged as OQs
Summary: All round-3 blockers verified RESOLVED or fixed in-pass. In-pass fixes from the verification: the last act split into two steps (A segment→Town, B Town→café); Counter SAFE example reworded; junctions over L_crit ∪ L_bypass at every stage; patrols kept a notice radius from return markers; path_dist gap counts as +∞ when the leader was SAFE or the gap crosses a non-walkable cell; uniform-cost notice search; facing tie-break; budget text in Edge Cases; knob ranges narrowed (notice_path_cap_m 4.3–5.0, turn_pause_s 0.9–1.4); AC-30i split out, AC-40c/46/51/54/56 rewrites; ADR-0012 batched set_blocked and path_dist signature. Creative-director: APPROVED, OQ-21 (title line rule) open, non-blocking.
Prior verdict resolved: Yes
Findings:
- none blocking
- [RECOMMENDED] OQ-21 title-line rule; overworld test plan file still to be created before the first [L] story; Tooling owed stories (perf map, capture-ID tags incl. SKY, level-review tool)
Reviewed-Content-Hash: design/gdd/overworld-exploration-encounters.md c467f44e453ac2cc6b09324ec31238168001511d
Reviewed-Content-Hash: design/registry/entities.yaml 6face4af34701382d84b4f2948e2131540f1b034
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md ce9474efabc4e96a62cf7d8e9859316615a4189d
Reviewed-Content-Hash: design/gdd/input-system.md 59917d823d98ee03f0cd97d8fcc102f4782bbc52
Reviewed-Content-Hash: design/gdd/sprite-camera-presentation.md 1b8c310076c4fa6dcbceb63497c1174b95df0064
Reviewed-Content-Hash: design/art/art-bible.md 3bdf3dc5ecd7ec7873ed70d0fc65d80f2c9b4c18
Reviewed-Content-Hash: design/accessibility-requirements.md c8a7a5edc0eca9817c50a3e774c3846ae1c4c354
Reviewed-Content-Hash: design/ux/interaction-patterns.md 32f2edacaae1c608d88c7309a44a1fe9f6fd6b0d
