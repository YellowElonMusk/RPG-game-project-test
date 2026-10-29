# Beatbox Battle Score

> **Status**: In Review. Revision 4 (2026-10-29) answers the third `/design-review` (NEEDS REVISION, 3 blocking, 7 recommended, `reviews/beatbox-battle-score-review-log.md`); revisions 2 and 3 answered the first two. It needs a re-review in a fresh session.
> **Creative Director Review (CD-GDD-ALIGN)**: skipped — lean mode. Acceptance criteria validated by qa-lead (2026-10-29).
> **Author**: user + agents (main session, audio-director, systems-designer; the consults were merged on 2026-10-29, and the rejected proposals are listed under Open Questions)
> **Last Updated**: 2026-10-29
> **Last Verified**: 2026-10-29 (against `game-state-scene-flow.md` Formulas, ADR-0006 §3 and §7, `content-data-definitions.md` rule 1, and `data/enemies/*.tres`)
> **Implements Pillar**: Pillar 1 (The Joke Is the Mechanic), Pillar 4 (Readable in One Turn)
> **Source**: the user's idea (2026-10-29), recorded in `design/narrative/narrative-requests.md` §5.2 and `design/narrative/narrative-bible.md` §7. Split from Audio Manager (systems index #20), which keeps SFX, buses, volume settings and overworld/camp music.

## Summary

Aliens speak in beatbox, so in a fight **the enemies are the band**. It works like Incredibox: each alien on the field performs its own beatbox part, and together they make the track, so the fight has no background music. Two to five enemies make a decent song; a late-game pack of eight is a full club-worthy beatbox remix. A harder fight plays a harder beat, and late-game tracks are denser and faster. When an alien is knocked out, its layer drops out of the mix. When the last one falls, the beat stops dead and the victory sting plays. Fights against humans only (the Rat Catchers) use ordinary battle music instead.

> **Quick reference** — Layer: `Presentation` · Priority: `Vertical Slice` (MVP ships one Paris kit, see Detailed Design) · Key deps: `Turn Battle System, Faction Rule Modifiers, Content Data Definitions, Game State & Scene Flow, Audio Manager`

## Overview

The Beatbox Battle Score turns each battle's alien roster into the battle music. Every alien enemy record names a **beat role**: kick, snare, bass, hats, lead or fx. When the battle starts, the score assigns the roles on the field, picks an **intensity tier** (1–4) from the encounter, and plays that tier's stems in one synchronised loop whose first downbeat lands on the reveal. During the fight, the score follows the *replayed* battle, not the raw logic. A layer drops out when that alien's knockout lands on screen, and in fights authored to build, the beat "drops" when the faction rule escalates (in Paris, when the Permit Ban lifts on round 4). The score never carries information the screen doesn't also show. It is a comic reward that makes fights sound like a beatbox battle you are winning: every knockout thins the track until only silence and the sting remain.

## Player Fantasy

*"I'm not fighting the aliens, I'm out-performing them."* The model is Incredibox (structure only, R12): every character on stage plays a different part, and the more of them there are, the better it sounds. A street gang of three is a decent groove; a late-game horde of eight is a club banger you have to take apart one performer at a time. Every fight opens with the enemy crew dropping a beat at you, and every knockout takes a performer off the stage, until the last hit cuts the track dead and the sting plays. The player should laugh the first time a Clerk's typewriter hats vanish mid-bar, and grin when a boss's chant speeds up because they've hurt it. It's a reward layer: it makes winning *sound* like winning, and it never asks the player to listen for anything they need.

## Detailed Design

### Core Rules

**R1. Who makes the score.** An enemy is **alien** when its record's `faction_id` resolves to a faction whose `kind` is `alien` (Content Data rule 1); every other enemy is **human**. A battle's score mode comes from its roster:
- at least one alien → **beatbox mode**: the aliens on the field are the only music. There is no background track. Human enemies in the roster hold no role.
- no alien (the Rat Catchers) → **band mode**: an ordinary composed battle track that sounds scrappy and human: distorted guitar and bass, a live-feeling kit, and an outlaw harmonica or whistle motif for the bounty hunters. It is deliberately *not* beatbox, so a human fight sounds different within a second, and it is plainer than the beatbox tracks; it never out-cools them.

**Which kit and tier.** The *encounter's* faction picks the music, never an enemy's: the kit is `enc_.faction_id`'s `score_kit_id` and the base tier its `score_base_tier` (F1). Every faction that fields enemies carries both fields. An alien faction's kit is a beat kit (R15); a human faction's kit is a **band kit**, one composed track per tier. Mode still comes from the roster (above), so content validation fails at boot, naming the encounter, when a roster with an alien enemy has a human encounter faction, or an all-human roster has an alien one. When a roster mixes two alien factions, every alien plays its own `beat_role` in the encounter faction's kit.

*(Content Data today constrains `enemy_.faction_id` to `alien` factions; the Rat Catchers need a non-alien faction kind. That is an owed Content Data change, see Dependencies.)*

**R2. Beat roles.** Each alien enemy record has a `beat_role` and a `fallback_role`, from this fixed set, in **assignment priority order**:

| # | Role | What it is in beatbox terms | Job in the mix |
|---|---|---|---|
| 1 | `kick` | Bass drum: lip "b"/"p" kick | Pulse; holds the fight together |
| 2 | `snare` | Rimshot, "k"/"pf" snare, inward snare at high tiers | Backbeat |
| 3 | `bass` | Lip-buzz or throat bass line | Weight; the "harder" feel |
| 4 | `hats` | "ts"/"t-k" hi-hats, clicks | Speed and density |
| 5 | `lead` | Vocal hook: a sung or chopped phrase | Identity; the boss's voice |
| 6 | `fx` | Scratches, sirens, zips, drops | Punctuation and transitions |

**R3. Assigning the layers** (Formula F2). At fight start, each role is held by at most one alien. A **boss** is an enemy whose own record has `is_boss = true` (the `enemy_` field, not the encounter's). In a boss encounter it is ADR-0006's `boss_combatant`, of which there is exactly one (a second fails the swap, ADR-0006 §5 step 3). A boss always takes `lead`. Every other alien first claims its `beat_role`. Only then do the still-unassigned aliens try their `fallback_role`, so one alien's fallback never steals another's first choice. An alien left over becomes an **extra** on its `beat_role`:
- on `kick`, `snare`, `bass` or `hats`, it is that role's **doubler** and adds the role's ad-lib stem, never a second copy of the same stem;
- on `lead` or `fx`, it plays **one-shot hits** on its own attack beats (`beat_impact` with it as the actor), with no persistent stem, so it never clashes with the hook.

Each role has at most one doubler. **Every alien on stage plays** (the Incredibox rule): an alien still unplaced after its own two roles and its doubler slot takes the first free role in R2 order, then the first free doubler slot. Six roles with a doubler each give 12 slots, so up to the 8-enemy maximum nobody is left out. Preference wins over fullness: a pack whose roles all sit in the rhythm section doubles those roles before anyone is pushed onto `lead` or `fx`, so an 8-pack can play with `lead` and `fx` empty (F2 Output Range). The assignment is fixed for the fight: a knockout never hands a role to another alien.

**R4. The floor pulse.** If no alien holds `kick`, the score plays the faction kit's **floor pulse**, a quiet, minimal kick-only stem. A one-enemy fight is never silent, and never sounds like a full band.

**R4b. Roster size is the fullness.** A fight fields 1 to 8 enemies. Typical fights have 2–5, and late-game or hard-area fights go up to 8 (Dragon Quest XI's spread). The tier (R5) sets tempo and complexity; the number of live performers sets how full the track is:
- 1 alien: one part over the floor pulse, deliberately thin.
- 2–5 aliens: a decent, complete-sounding song.
- `full_house_min` (default 7) or more live aliens: **Full House**. The kit adds its `full_house` layer, a club treatment of the same mouth-made sounds: a sub-bass drop, sidechain pumping on the kick, filter-sweep build-ups and stacked vocal chops. Heavy processing makes it sound electronic, but every source is still beatbox (R12). The layer joins on bar 1 (in a held encounter, R10, it has no `base` variant and joins at the drop instead, if the live count is still `full_house_min` or more then) and leaves at the next bar once the live count drops below `full_house_min`, so taking an 8-pack apart audibly turns a club remix back into a song, then into silence.

**R4c. Bosses bring a crew.** A boss fight should not be a solo. An encounter with `is_boss = true` fields at least `boss_min_minions` (default 2) alien minions beside the boss, so the boss's `lead` sings over a real band. Boot validation warns, rather than fails, below that, and a lone boss still works (its `lead` over the floor pulse). Paris: the Supervisor fights with two Clerks.

**R5. Intensity tier.** Every fight plays at one tier from 1 to 4 (Formula F1), chosen at fight start from data and never from RNG. The tier picks each role's stem variant and the tempo (Formula F3). As a guide:
- **Tier 1** (~92 BPM): a basic "boots and cats" pattern with a half-time feel. Sparse, lots of space.
- **Tier 2** (~108 BPM): light syncopation, 8th-note hats, a simple bass line. The arena-energy zone.
- **Tier 3** (~124 BPM): inward snares, triplet fills, a rolling bass, and the lead hook with call and response.
- **Tier 4** (~138 BPM): switches between inward and outward snares, polyrhythmic hats, a wobbling bass and double-time vocal runs. This is the late-game showcase, held to the bar of Dharni-style layering and the festival build of "Sandstorm" (feel only, see R12).

The tier sets each stem's complexity, not how many roles play: the roster decides that (R3). Within a region, street fights sit lowest, the story encounter at or above them and the boss highest; later regions start higher. From base tier 2 up, every boss sits at tier 4 (F1's clamp), so late bosses are told apart by their kit and hook, not their tier.

**R6. Synchronisation.** All stems in a fight share one tempo, one time signature (4/4) and one loop length (`loop_bars`, default 8), and play sample-locked from a single synchronised stream. Every change the score makes (a layer out, a drop, a break, a hook switch) lands on a **quantise boundary**: the next beat for knockouts, the next bar for everything else (Formula F5). Only two sounds are unquantised: the intro (R7) and the Fled scratch (R14).

**R7. Starting on the beat.** Game State's battle wipe runs *out*, then a *swap* of unbounded length (the battle scene loads), then *in* (`t_in`, 0.30 s by default). The score can't know when the reveal lands until the swap ends, so it starts in three steps:
1. **Arm** on `transition_started(→ battle)`: request the kit as a **background (threaded) load**, assign roles, compute the tier. No sound. The load never blocks a frame, so the wipe-out never hitches; it has the out and swap phases to finish.
2. **Intro** on `mode_entered(battle)`, the end of the swap: compute bar 1's target time, `t_mode_entered + t_in` (F6), and play the kit's `intro` one-shot (an inhale and a single "ts"), timed by F6 to end on it. If the intro is longer than `t_in`, it is skipped.
3. **Bar 1.** The synchronised stream starts on the first frame at or after the target time. That actual start is bar 1's downbeat and defines `loop_start`; every later quantise boundary (F5) is measured from it, so the grid is sample-locked from there on even though the start itself is frame-quantised. Bar 1 never moves once it has sounded. `transition_finished(battle)` arrives on the first frame at or after the reveal, and the score uses it only as a check: if it lands more than `reveal_tolerance_ms` (20 ms) from bar 1, a warning is logged and nothing is rescheduled. Whether 4.7.2 can start the stream at an exact future mix time, tightening this to ±1 mix block, is part of OQ-2's Audio ADR.

**If the kit is not loaded at `mode_entered`** (a slow disk): the intro is skipped, and bar 1 starts on the first frame the load completes, with a logged warning. The fight never waits for it. A load that fails is the "stems fail to load" edge case.

If the swap fails and the transition rolls back (Game State Edge Cases), the score cancels the load and disarms silently.

**R8. Following the replay, not the logic.** The score listens only to `BattleReplayController`'s gated signals (ADR-0006 §3), never to `BattleCore`'s raw signals. What it reads:

| Score event | ADR-0006 signal | Read from |
|---|---|---|
| Knockout of combatant `c` | `beat_impact(plan)` | each `c` in `plan.reactions` whose reaction is KNOCKOUT. The slump plays during the beat's hold, which the choke tail covers (R9) |
| Attack one-shot (R3 extras) | `beat_impact(plan)` | `plan.actor` |
| HP for the boss hook (R11) | `beat_finished(plan)` | the displayed snapshot, which becomes current before the signal |
| Escalation round (R10) | `round_advanced_after_replay(n)` | `n` |
| Victory / Defeat (R14) | `battle_ended_after_replay(won)` | `won` |
| Fled (R14) | `battle_fled_after_replay()` (ADR-0010 §5's END-class marker) | — |
| Leaving battle (R14) | Game State's `transition_started(from, to)` with `from == battle` and `to != battle` | — |
| Resync | `display_resynced()` | in `Playing` or `Break` only: the live layers are rebuilt from the displayed state at the next bar, with no tails. It also fires during the swap at first entry and on Retry (ADR-0006 §5), while the score is `Armed`; there it is ignored, because arming already builds the layers from the encounter |
| Cancel | `replay_cancelled()` | in `Playing` or `Break` only: any scheduled change not yet applied is discarded, and the loop plays on from the layers already applied. It also fires at the start of every exit and of the Retry flash (ADR-0006 §5), when the score is already `Ending` or `Armed`; there it is ignored, because the exit row (R14) and arming decide what plays |

The player's speed-up latch changes **nothing** in the score: the tempo stays fixed, and only the quantised event times arrive sooner.

**R9. Knockout.** When an alien's knockout event arrives, its stem (or its doubler stem or one-shot slot) **leaves at the next beat** (F5) with a `layer_fade_ms` fade. At that same boundary a separate **choke tail** one-shot plays for `ko_tail_beats`: the foundation roles, `kick` and `bass`, get a longer tail (default 4 beats), so the floor audibly drains away rather than vanishing. The knocked-out alien's loop never keeps playing after the beat it was hit on. If that was the `kick` holder, the floor pulse comes in at the same boundary (R4).

**The final knockout.** The score keeps its own set of enemies shown standing, humans included, and removes each KNOCKOUT reactor as its `beat_impact` arrives. When a knockout empties that set, there is **no choke tail**: every stem, the floor pulse included, cuts on the next beat and the **victory sting** plays there (Audio Manager owns the sting), and the score enters `Ending`. A knockout that leaves only humans standing is an ordinary knockout: tail, floor pulse, and the beat plays on (Edge Cases). The released `battle_ended_after_replay(true)` that follows is then a no-op; it plays the cut and sting itself (R14) only when it arrives with the score still in `Playing` or `Break`.

**R10. Escalation drop.** A faction rule may declare one **escalation round** (Faction Rule Modifiers); for Bureaucratia it is the round the Permit Ban lifts, `permit_rounds + 1` = round 4, the same moment as the "all-out war" banner. The drop only happens in an encounter authored to build to it, `enc_.score_hold_for_escalation = true`:
- **Held encounter** (the faction has an escalation round and the flag is set): stems play their `base` variant, and Bureaucratia plays them through a low-pass "waiting room" filter (`prewait_lowpass_hz`, default 800 Hz), matching the Permit Ban's hunker-down mood. When the replay releases the escalation round, the filter opens and all live stems switch to their `full` variant on the next bar, with an `fx` riser into it if anyone holds `fx`. Tier and tempo don't change. There is at most one drop per fight.
- **Any other encounter**: the stems play `full` from bar 1, with no filter and no drop. Paris street fights (one Clerk, usually over before round 4) are in this group, so they never sit behind the filter.

Paris sets the flag on the Permit Counter story encounter and the Supervisor. The filter sits on the score's own submix (Visual/Audio), never on the shared Music bus, so a fight won before its drop plays the victory sting unfiltered.

**R11. Boss second hook.** A boss whose record names a `score_hook_id` sings that hook's A stem as its `lead`, and the hook has a B stem. A boss without one sings the kit's generic `lead` stem and never switches. When the boss's shown HP falls to or below the F4 threshold, the lead switches to hook B on the next bar. This happens once, and healing never switches it back.

**R12. Originality (a hard content rule).** Every stem is original. No sample, melody, riff or recognisable rhythm is taken from "Sandstorm", from Dharni, from Incredibox, or from any other existing track or game. Incredibox is a reference for structure (each character a part) only. The references describe *energy and layering* only, they appear in no player-facing or marketing text, and every kit passes a "could anyone name the source?" listen check before it ships. Every beatbox stem is mouth-made: recorded beatboxing, which processing (pitch, filtering, effects) may alter, but which is never replaced with drum-machine samples. The aliens *are* beatboxing.

**R13. The battle cry break.** The squad's battle cry plays at the start of about 1 fight in 4 (the roll and the line belong to Dialogue, Banter & Quests; narrative bible §5). When it fires, the score mutes all stems for `cry_break_bars` (default 1) starting at the next bar boundary **after bar 1**, so bar 1 always plays and establishes the beat, then slams back in on the following downbeat. The cry is timed into that silent bar. Authored openers (the story encounter and the boss, narrative bible §5) get no break in MVP. In band mode, the cry never plays (not used against human targets).

**A knockout during the break** that is not the final one is applied silently: the layer is removed at its F5 beat, its choke tail is not played (the break is the silence), and the slam downbeat plays without it. If it held `kick`, the floor pulse comes in with the slam. A Full House layer whose count drops during the break is likewise absent at the slam. The final knockout during a break follows Edge Cases.

**R14. Ending a fight.**
- **Victory**: R9's cut and the sting, started by the final knockout. If `battle_ended_after_replay(true)` arrives while the score is still in `Playing` or `Break` (a victory with no KNOCKOUT reaction), it starts the same cut and sting at the next beat.
- **Defeat**: on `battle_ended_after_replay(false)`, all stems cut on the next beat and the wry defeat sting is requested at that same beat. The Defeat Prompt opens later, after the Battle mode's `defeat_hold`, with the sting already playing or finished; its opening plays nothing of its own.
- **Fled**: on `battle_fled_after_replay()`, a record-scratch `fx` (always available, even with no `fx` holder), and all stems cut at once, unquantised.
- **Leaving battle**: on `transition_started(battle → any other mode)` (the Victory or Fled wipe, Retreat, Quit to Title from the Menu), every stem, the floor pulse, any pending change and any choke tail stop at once with a `layer_fade_ms` fade, and the score goes to `Idle`. A sting already playing belongs to Audio Manager and is not cut. This is the only exit for a fight left mid-`Playing` (Quit from the Menu), where no ending fires.
- **When `Ending` finishes**: every sting is a fixed-length resource, so the score knows its length when it requests it, and returns to `Idle` at the sting's start plus its length (the scratch's length for Fled).
- **Retry**: the score re-arms on the retry wipe (R7), with the original assignment, the held state restored if the encounter is held, and no carried-over drop or hook B.

**R15. Faction kits.** Each alien faction supplies one **beat kit**: a stem set per role per tier (`full` always, `base` only where a held encounter uses it), a floor pulse, an intro, choke tails and ad-libs, built from sounds that tell the faction's joke. **Bureaucratia (Paris, MVP)**:
- the kick is a **stamp thunk**, mouth-made;
- the snare is a staple-gun snap;
- the hats are typewriter clacks;
- the bass is a photocopier drone;
- the fx are the ticket dispenser's "ding" and paper rips;
- the generic `lead` stem, sung by any non-boss alien that holds `lead`, is a mumbled form-reading drone;
- the Supervisor's hook (`enemy_supervisor.score_hook_id`) is a monotone stamped chant ("Take a number. NEXT."), and hook B speeds it up ("NEXT. NEXT. NEXT.").

Boss hooks live in their faction's kit, one A and one B stem per tier the boss uses; the boss's enemy record only names which hook it sings.

MVP ships this one kit, at the tiers Paris uses (1–3). Later factions add their own.

### States and Transitions

| State | Entered when | Exits to |
|---|---|---|
| `Idle` | No battle | `Armed` on `transition_started(→ battle)` |
| `Armed` | Kit load requested, roles and tier computed | `Intro` on `mode_entered(battle)`; `Idle` on a rolled-back transition |
| `Intro` | The intro one-shot and bar 1 are scheduled (F6), or the intro is skipped | `Playing` at the bar 1 downbeat on the audio clock |
| `Playing` | Bar 1 downbeat | `Break` (cry), `Ending` (final knockout, released `battle_ended`, or released `battle_fled`) |
| `Break` | Battle cry, at the next bar after bar 1 | `Playing` after `cry_break_bars`; `Ending` as from `Playing` |
| `Ending` | The final knockout (R9), the released `battle_ended`, or the released `battle_fled` | `Idle` at the sting's start plus its length (R14); `Armed` on `transition_started(→ battle)` (a Retry pressed during the defeat sting cuts the sting) |

**From any state but `Idle`**, `transition_started(battle → any other mode)` goes to `Idle` (R14, Leaving battle). That is how a fight quit from the Menu mid-`Playing` ends; from `Armed` or `Intro` it also cancels the kit load.

Flags: `ducked` is set by `overlay_opened(Menu)` and cleared by `overlay_closed(Menu)` in any state from `Armed` to `Ending`. The loop keeps running with the score submix at `duck_db`, so the beat never restarts and the state underneath (a break, the intro) keeps its times. The Defeat Prompt overlay never ducks: the score is already in `Ending` or `Idle`. Held during `Playing` and `Break`: `held` (R10, until the drop), `boss_hook_b` (R11, once), the set of live layers, and the set of enemies shown standing (R9).

### Interactions with Other Systems

| System | This system receives | This system provides |
|---|---|---|
| **Turn Battle System** via `BattleReplayController` (ADR-0006) | The gated signals in R8's table | Nothing back. The score never gates or delays the replay |
| **Faction Rule Modifiers** | The faction's escalation round, if any (Bureaucratia: `permit_rounds + 1`) | — |
| **Content Data Definitions** | Enemy `faction_id`, `is_boss`, `beat_role`, `fallback_role`, `score_hook_id`, `max_hp`; faction `kind`, `score_kit_id`, `score_base_tier`; encounter `faction_id`, `score_tier_override`, `score_hold_for_escalation`; the `score_config` record (new fields, see Dependencies) | — |
| **Overworld Exploration & Encounters** | The encounter's meaning (it owns `enc_`), including the two new score fields | — |
| **Game State & Scene Flow** | `transition_started`, `mode_entered`, `transition_finished` for the battle and retry wipes, the rollback, overlay broadcasts, `t_in` | — |
| **Audio Manager** | The Music bus, volume settings, the duck level, victory and defeat stings | Requests to play on the score's submix of the Music bus |
| **Dialogue, Banter & Quests** | The battle cry event (rolled, and timed to the break bar) | The break bar's start time, so the cry can land in it |
| **Sprite & Camera Presentation** | — | A beat clock (bar and beat position) that idle bobbing may follow (Visual/Audio) |

## Formulas

**F1. Intensity tier.** The `intensity_tier` formula is defined as:

`intensity_tier = score_tier_override if score_tier_override > 0 else clamp(score_base_tier + (boss_tier_bonus if is_boss else 0), 1, tier_max)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| score_tier_override | int | 0–4 | data file (`enc_` record) | Authored tier for a specific fight, such as the story encounter; 0 means none |
| score_base_tier | int | 1–3 | data file (the `faction_` record named by `enc_.faction_id`, R1) | The tier of the faction's ordinary street fights; rises with the region's place in the game. Human factions carry it too, for band mode |
| is_boss | bool | — | data file (`enc_` record) | The encounter's boss flag (R3's per-enemy flag picks who sings `lead`; this one picks the tier) |
| boss_tier_bonus | int | 0–2 | data file (`score_config`) | How far a boss sits above its faction's street fights; default 2 |
| tier_max | int | 4 | constant | The top tier |

**Output Range:** 1 to 4. Boot validation fails, naming the record, when an override is outside 0–4, or when an encounter's computed tier has no stems in its faction's kit. It warns when an override sits below the faction's street tier.
**Example:** Bureaucratia has `score_base_tier = 1`. A Paris street fight is tier 1. The Permit Counter story encounter has `score_tier_override = 2`, so tier 2. The Supervisor is `1 + 2 = 3`. A region-4 faction with base 3 has street fights at tier 3 and a boss at `clamp(5) = 4`.

**F2. Role assignment.** The `assign_roles` procedure is defined as:

`holder[lead] = boss_combatant in a boss encounter, else the first is_boss enemy in line_order (if any)`; `line_order` below **excludes that boss and every human**; **pass 1**: `for e in line_order: if holder[e.beat_role] is empty: holder[e.beat_role] = e`; **pass 2**: `for e unassigned in line_order: if holder[e.fallback_role] is empty: holder[e.fallback_role] = e`; **pass 3**: `for e unassigned in line_order: if extra[e.beat_role] is empty and doubler_enabled: extra[e.beat_role] = e` (a doubler stem on kick/snare/bass/hats; one-shots on lead/fx); **pass 4** (every alien plays, R3): `for e unassigned in line_order: holder[first empty role in R2 order] = e, else if doubler_enabled: extra[first empty extra slot in R2 order] = e, else e plays nothing`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| e.beat_role, e.fallback_role | enum | the 6 roles in R2 | data file (`enemy_` record) | This alien's preferred and second-choice roles; they must differ |
| line_order | list | 1–8 enemies | calculated (`enc_` enemy list order) | The battle-line order; it is also the tie-break |
| doubler_enabled | bool | — | data file (`score_config`) | Whether extras exist at all: false turns off doubler stems, lead/fx one-shots and pass 4's extra slots; default true |
| holder[r], extra[r] | map | 0–1 per role | calculated | Who plays each role, and who is its extra |

**Output Range:** with at most 8 aliens on the field, 1 to 6 holders and 0 to 4 extras. An extra always sits on a held role, so extras never outnumber holders, and 8 aliens give 4 to 6 holders and 2 to 4 extras. Pass 3 runs before pass 4 (R3: preference wins over fullness), so 8 aliens whose roles are all `kick`/`snare`/`bass`/`hats` give 4 holders and 4 doublers with `lead` and `fx` empty, while 8 aliens all on `snare`/`hats` give 6 holders and 2 extras. Every alien gets a slot whenever `doubler_enabled` (12 slots ≥ 8). Live streams: at most 8 alien streams (holders plus doubler stems), plus the floor pulse when nobody holds `kick` and the Full House layer (R4b). Choke tails, the intro and one-shots are short hits, not loops.
**Example:** The Supervisor (`lead`) plus Clerk A (`snare`/`hats`), Clerk B (`snare`/`hats`) and Clerk C (`snare`/`hats`). The Supervisor holds `lead`. Pass 1: A takes `snare`. Pass 2: B takes `hats`. Pass 3: C doubles `snare`. Nobody holds `kick`, so the floor pulse plays. **Two-pass case:** A (`kick`/`snare`), B (`kick`/`bass`), C (`bass`/`hats`). Pass 1: A `kick`, C `bass`. Pass 2: B's `bass` is taken, so B doubles `kick` in pass 3. A single pass would have handed B the `bass` and pushed C off its first choice.

**F3. Tempo.** The `bpm` formula is defined as:

`bpm = tier_bpm[intensity_tier]`; `seconds_per_beat = 60 / bpm`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| tier_bpm | int[4] | 80–150 | data file (`score_config`) | Tempo per tier; default `[92, 108, 124, 138]` (audio-director's ladder) |
| intensity_tier | int | 1–4 | calculated (F1) | — |

**Output Range:** 92 to 138 BPM by default, which gives 0.652 s down to 0.435 s per beat. Each kit's stems are authored at exactly its tiers' tempos; the score never time-stretches.
**Example:** The Supervisor at tier 3 plays at 124 BPM, so 0.484 s per beat and 1.935 s per bar.

**F4. Boss hook threshold.** The `boss_hook_b` condition is defined as:

`boss_hook_b = boss.hp_shown <= floor(boss.max_hp * boss_hook_threshold)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| boss.hp_shown | int | 0–max_hp | calculated (the displayed snapshot at `beat_finished`) | HP as the player currently sees it |
| boss.max_hp | int | > 0 | data file (`enemy_` record) | — |
| boss_hook_threshold | float | 0.25–0.75 | data file (`score_config`) | Default 0.5 |

**Output Range:** true or false; it latches true once.
**Example:** The Supervisor (`enemy_supervisor`, 110 max HP) switches to hook B on the bar after his shown HP reaches 55 or less; 56 does not switch. With 111 max HP the threshold is `floor(55.5) = 55`, so the switch never happens above 50%.

**F5. Quantised change time.** The `change_time` formula is defined as:

`change_time = loop_start + ceil((now + schedule_lead - loop_start) / unit) * unit`, where `schedule_lead` is one audio mix block, so a change never lands less than one block after it is requested (an event exactly on a beat takes the next one), and `unit = seconds_per_beat` for knockouts and `unit = 4 * seconds_per_beat` for drops, breaks, the boss hook, a resync and a revived layer. A knockout's choke tail starts at `change_time` and lasts `ko_tail_beats * seconds_per_beat`.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| now | float (s) | ≥ loop_start | calculated (`MusicClock.now()`: completed loops × loop length + the stream's playback position, corrected for output latency) | The current musical time. It counts up for the whole fight and never wraps at the loop point, so bar and beat numbers stay meaningful past bar `loop_bars` |
| loop_start | float (s) | — | calculated | The time of bar 1's downbeat |
| schedule_lead | float (s) | one mix block (~0.01) | constant (the output's mix block length) | The least time the mixer needs to apply a change sample-accurately |
| ko_tail_beats | float | 0.5–4 | data file (`score_config`) | The choke tail's length: `ko_tail_beats_foundation` (default 4) for `kick` and `bass`, `ko_tail_beats_other` (default 1) for the rest; 0 for the last knockout |
| layer_fade_ms | int | 30–250 | data file (`score_config`) | A short fade at `change_time` so a stem never clicks off; default 120 |

**Output Range:** a knockout's stem leaves one mix block to one beat after the event (at most 0.652 s at 92 BPM), and its tail ends at most 3.26 s after it (one beat plus a 4-beat tail at 92 BPM). Bar-quantised changes land 0 to one bar after the event (at most 2.61 s at 92 BPM).
**Example:** At 124 BPM (0.484 s per beat), the `snare` holder's knockout lands at 3.30 s into the loop: `ceil(3.30 / 0.484) = 7` beats, so the stem leaves at 3.387 s, fading over 120 ms, and its 1-beat tail ends at 3.871 s. Had it held `bass`, the stem would leave at the same 3.387 s and its 4-beat tail would end at 5.323 s.

**F6. Intro timing.** The `intro_start` formula is defined as:

`intro_start = t_mode_entered + (t_in - intro_len_s)` if `intro_len_s <= t_in`, else no intro; bar 1's downbeat is at `t_mode_entered + t_in`, the reveal

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| t_mode_entered | float (s) | — | calculated (`mode_entered(battle)`) | The end of the swap |
| t_in | float (s) | 0.05–0.50 | data file (Game State's per-transition `t_in`: battle wipe 0.30, Retry 0.05–0.25) | The reveal's length |
| intro_len_s | float (s) | 0.10–0.50 | data file (kit) | The intro one-shot's length |

**Output Range:** the intro ends on the reveal, or doesn't play. Bar 1 starts on the first frame at or after `t_mode_entered + t_in` (R7) and never moves once it sounds; `transition_finished` is only checked against it, and a gap over `reveal_tolerance_ms` (20 ms, more than one 60 Hz frame) logs a warning (R7).
**Example:** The battle wipe's `t_in` is 0.30 s and the Bureaucratia intro is 0.25 s, so the intro starts 0.05 s after `mode_entered` and bar 1 lands on the reveal. On a 0.15 s Retry reveal, the 0.25 s intro is skipped and bar 1 starts clean on the reveal.

## Edge Cases

- **If a roster mixes aliens and humans**: beatbox mode; the humans hold no role and bob to nothing. If every alien is knocked out while humans remain, the last alien's knockout is an ordinary one (R9: tail, no sting), and the floor pulse plays alone until the final knockout cuts it. That is the joke: the humans have no rhythm.
- **If an alien enemy record has no `beat_role`**: content validation fails at boot (Content Data's fail-fast rule), naming the record. A human enemy needs none.
- **If `beat_role == fallback_role`**: a validation error.
- **If two bosses are on the field**: impossible in a boss encounter (ADR-0006 §5 step 3 fails the swap, so the score disarms from `Armed`). In a non-boss encounter, the first `is_boss` enemy in line order takes `lead`; the second is treated as a non-boss with its own roles. Only the first drives R11.
- **If the encounter's faction kind doesn't match the roster's mode** (R1): a content validation error at boot, naming the encounter.
- **If a knockout and a drop land on the same bar**: the knockout applies first (on its beat), then the drop switches only the live layers.
- **If the last alien is knocked out during the battle-cry break**: the break ends early and the victory sting plays at the next beat. It never waits out the silent bar.
- **If a held fight ends before its escalation round**: the drop never happens; the sting plays unfiltered (R10's submix).
- **If `display_resynced` arrives while `Armed`** (first entry and Retry, both during the swap): ignored (R8).
- **If the replay resyncs mid-fight** (`display_resynced` in `Playing` or `Break`): at the next bar, exactly the layers of aliens shown standing are live, with no tails, and the floor pulse follows R4.
- **If the replay is cancelled** (`replay_cancelled`, an exit path): changes not yet applied are dropped and R14's ending plays. A layer never leaves for a knockout the player didn't see.
- **If the battle transition rolls back** (the swap fails): the score disarms from `Armed`; nothing has played.
- **If a revive is ever added** (none exists in Turn Battle today): its layer returns at the next bar on its original role, and the floor pulse leaves if that role is `kick`. Specify and test it with the move.
- **If the speed-up latch makes several knockouts arrive inside one beat**: each is quantised independently and they may leave on the same beat. Nothing is skipped.
- **If the faction has no escalation round** (a neutral rule): R10 never holds. The fight plays `full` stems throughout.
- **If an overlay opens during `Intro`**: the intro and bar 1 keep their times, ducked, so the reveal stays on the beat.
- **If audio output is muted or the Music bus is at 0%**: the score still runs its clock (the beat clock for bobbing stays valid); nothing depends on hearing it.
- **If the stems fail to load**: battle continues silently, and an error is logged with the kit ID. Battle never waits on audio.
- **If the kit is still loading at `mode_entered`**: no intro; bar 1 starts the frame the load completes, with a warning (R7).
- **If the player quits to the title from the Menu mid-fight**: `transition_started(battle → title)` stops everything at once and the score goes `Idle` (R14). The beat never plays into the title screen.
- **If a non-final knockout lands during the cry break**: applied silently with no tail; the layer is gone at the slam (R13).
- **If the band-mode track is missing for a human fight**: silence plus a logged error, the same as above.

## Dependencies

| System | Direction | Hard/Soft | Interface | Status |
|---|---|---|---|---|
| Turn Battle System (via `BattleReplayController`) | Upstream | Hard | Gated replay signals (R8, ADR-0006 §3); a listener only, so ADR-0006 needs no change | GDD reverse-documented, lists this system (2026-10-29); ADR-0006 Accepted; the replay controller is not built yet |
| Faction Rule Modifiers | Upstream | Soft | **New**: `FactionRule` gains an optional `score_escalation_round()` (Bureaucratia returns `permit_rounds + 1`, read from the rule record's `params`) | Listed in its Dependencies (2026-10-29); interface owed |
| Content Data Definitions | Upstream | Hard | **New fields**: `enemy_.beat_role`, `enemy_.fallback_role` (alien enemies); `enemy_.score_hook_id` (optional, bosses); `faction_.score_kit_id`, `faction_.score_base_tier` (every faction that fields enemies; a human faction's kit is a band kit); a validation rule that the encounter faction's kind matches the roster's mode (R1); `enc_.score_tier_override` (default 0), `enc_.score_hold_for_escalation` (default false); a `score_config` record; R1 needs enemies from a non-alien faction (the Rat Catchers) | Added to its rule 1 table as owed (2026-10-29) |
| Overworld Exploration & Encounters | Upstream | Soft | Owns the meaning of the two new `enc_` fields; Paris sets the hold on its story encounter and the Supervisor | Listed in its Dependencies (2026-10-29) |
| Game State & Scene Flow | Upstream | Soft | `transition_started`, `mode_entered`, `transition_finished`, rollback, overlay announcements, `t_in` | Approved; Visual/Audio and Dependencies updated (2026-10-29) |
| Audio Manager | Upstream | Hard | The Music bus and the score's submix under it, settings volumes, the duck level, stings | Not designed (index #20) |
| Dialogue, Banter & Quests | Peer | Soft | The battle-cry event, and the break bar's start time | Not designed (index #17) |
| Sprite & Camera Presentation | Downstream | Soft | Reads the beat clock for idle bobbing (optional, Vertical Slice) | Lists this system (2026-10-29); an additive change only |

## Tuning Knobs

All live in the `score_config` record unless marked. None carries gameplay information, so every one is a feel knob.

| Knob | Default | Safe range | Too low | Too high | Used by |
|---|---|---|---|---|---|
| `tier_bpm` | `[92, 108, 124, 138]` | 80–150, strictly rising | Fights drag; tier 1 feels like a lull | Tier 4 turns frantic and stems are hard to perform | F3, R5 |
| `boss_tier_bonus` | 2 | 0–2 | Bosses sound like street fights | Most bosses clamp to 4 and lose their distinction | F1 |
| `loop_bars` | 8 | 4–16 | Loops repeat audibly | Larger stem files; longer authoring | R6 |
| `ko_tail_beats_foundation` / `_other` | 4 / 1 | 0.5–4 | Layers vanish rather than drain | A tail outlasts the next knockout and muddies the thinning | R9, F5 |
| `layer_fade_ms` | 120 | 30–250 | Clicks | The exit smears across the beat | F5 |
| `doubler_enabled` | true | — | Big rosters sound thin | — | F2 |
| `boss_hook_threshold` | 0.5 | 0.25–0.75 | Hook B arrives too late to enjoy | Hook B arrives before the fight has turned | F4, R11 |
| `prewait_lowpass_hz` (kit) | 800 | 500–3000 | Held stems read as broken audio | No audible "waiting room"; the drop loses its contrast | R10 |
| `cry_break_bars` | 1 | 1–2 | — | The silence outlasts the cry and the fight feels stalled | R13 |
| `duck_db` | −12 dB | −24 to −6 dB | The beat vanishes under menus | The menu fights the music | the `ducked` flag (score submix only) |
| `reveal_tolerance_ms` | 20 | 17–50 | Warnings on every normal frame hitch | A late reveal goes unnoticed | R7, F6 |
| `sfx_duck_db` | −3 dB (150 ms release) | −6 to 0 dB | Hits are buried in a tier 4 mix | The score pumps on every hit | Visual/Audio |
| `full_house_min` | 7 | 6–8 | Ordinary big fights all sound like the club remix and it stops being special | The remix never plays (8 is the cap) | R4b |
| `boss_min_minions` (validation) | 2 | 0–4 | Solo bosses sing over the floor pulse only | Boss fights crowd the stage | R4c |
| `intro_len_s` (kit) | 0.25 s | 0.10–0.50 | The intro is just a click | Skipped on every Retry (F6) | F6 |

## Visual/Audio Requirements

> `art-director` not consulted (lean mode: this system's visuals are optional garnish, not read to play). The audio direction above is merged from the audio-director consult (OQ-1).

- **Every sound here has a visual twin** (accessibility rule: no audio-only information). A layer leaving = the visible knockout. The drop = the visible "all-out war" banner. Boss hook B = the visible HP bar. The battle cry = its text line. The score adds no new information.
- **Bobbing (Vertical Slice)**: each alien's idle loop bobs on its own role's hits from the beat clock, so the player can *see* who is playing what. A non-playing alien bobs on the kick. Under Reduce Motion, bobbing is replaced by a small static "♪" glyph on each playing alien (shape, not colour).
- **Alien speech captions**: when an alien "speaks" in battle text (barks), its line is shown as a caption such as *[aggressive boots-and-cats]*. Dialogue owns the text; this system only names the convention.
- **Bus and mix**: the stems play on a **score submix** under the Music bus; the waiting-room filter (R10) sits on that submix only. Stings play on the Music bus outside it. The menu duck (`duck_db`) also sits on that submix, so it never touches a sting. The SFX bus (hits, `beat_impact`) ducks the score by `sfx_duck_db`, so hits always read, even over a dense tier 4 mix. The battle cry needs no separate duck: the stems' own one-bar break (R13) is the duck, so it can never drift out of sync. Victory and defeat stings hard-cut the score, with no crossfade bleed. The score never ducks the UI bus. All stems in a kit share one sample rate and identical loop points, which synchronised playback requires (OQ-2). All stems are mono-compatible, because mono is a planned accessibility option.
- **Rat Catcher band mode**: one composed track per tier used, with the same start-on-the-beat rule (R7) and the same victory/defeat/flee endings (R14). There is no per-enemy layering.

## Game Feel

- **Knockouts should feel like the crowd losing a performer**: the choke tail is audible, and the track gets visibly and audibly thinner. A fight you are winning sounds emptier and emptier.
- **The drop is the payoff of the fights built for it** (in Paris, the story encounter and the Supervisor): three rounds of held-back beat, then everything opens up with the specials. Street fights don't wait; they open at full energy and drain away.
- **The battle cry break should land like a mic drop**: one bar of beat, silence, the yell, then the slam.
- No change ever lands off the grid. A late change on the beat beats an early change off it.

## UI Requirements

None of its own. It shows no HUD element. Volume lives in the Audio Manager's settings (accessibility requirements, Independent volume controls). The Reduce Motion "♪" glyph is a Presentation asset, not UI.

## Cross-References

| This document | References | Rule or value | Where |
|---|---|---|---|
| R1, R13 | Narrative bible | Aliens speak in beatbox; the Rat Catchers; the cry at fight start, not against humans, authored openers for the story encounter and boss | `design/narrative/narrative-bible.md` §5, §6.5, §7 |
| R1, R3 | Content Data | `enemy_.faction_id`, `enemy_.is_boss`, `faction_.kind` | `design/gdd/content-data-definitions.md` rule 1 |
| R7, F6 | Game State & Scene Flow | Three-phase transition; announcement order; `t_in` 0.30 s (battle), 0.05–0.25 s (Retry); rollback on a failed swap | `design/gdd/game-state-scene-flow.md` rules 3–4, Formulas, Edge Cases |
| R8 | ADR-0006 | Gated signals; `BeatPlan.reactions`; the knockout hold; speed-up latch; `replay_cancelled` on every exit and Retry | `docs/architecture/adr-0006-battle-replay-ownership.md` §3, §5, §6, §7 |
| R8, R14 | ADR-0010 | `battle_fled_after_replay()`, the END-class Fled marker | `docs/architecture/adr-0010-turn-battle-system.md` §5 |
| R10 | Faction Rule Modifiers / Bureaucratia | `permit_rounds = 3`; specials allowed from round 4 | `data/faction_rules/rule_bureaucratia_permit.tres` |
| F4 | Enemy data | Supervisor `max_hp = 110`, `is_boss = true` | `data/enemies/enemy_supervisor.tres` |
| R14 | Accessibility requirements | Victory/defeat music; no audio-only information | `design/accessibility-requirements.md` Auditory Accessibility |
| F1 | Overworld & Encounters | The `enc_` descriptor fields (`is_boss`, `faction_id`, enemy IDs) | `design/gdd/overworld-exploration-encounters.md` AC-14 |

## Acceptance Criteria

> **Test seam** (qa-lead, 2026-10-29). Split the score in two:
> - a pure `ScoreScheduler` (`RefCounted`) that takes replay and transition events through an injected event-source interface and a `MusicClock` (`now()`, already latency-corrected), and returns timed commands `(t, action, role)`;
> - a thin mixer adapter that applies those commands to the synchronised stream.
>
> Unit tests drive the scheduler with a `FakeClock` advanced by hand, so they never wait for `BattleReplayController`. "Silent" means a sub-stream volume at or below −80 dB; "live" means above −60 dB. "±1 block" means one audio mix block. Tags: **[U]** unit, **[I]** integration, **[M]** manual or content gate.

**Mode and assignment**
- **AC-1 [I] (R1)** GIVEN an encounter with at least one enemy whose faction `kind` is `alien`, WHEN the battle starts, THEN no band-mode track is loaded and only role stems and the floor pulse are live. GIVEN no alien enemy, THEN the band-mode track is live and no role stem is loaded.
- **AC-2 [U] (R3, F2)** GIVEN the roster Supervisor + three Clerks (`snare`/`hats`), WHEN roles are assigned, THEN the Supervisor holds `lead`, Clerk A `snare`, Clerk B `hats`, and Clerk C is the `snare` doubler on the ad-lib stem (not a second `snare` stem).
- **AC-2b [U] (F2 two-pass)** GIVEN A (`kick`/`snare`), B (`kick`/`bass`), C (`bass`/`hats`) in that line order, WHEN roles are assigned, THEN A holds `kick`, C holds `bass`, and B is the `kick` doubler.
- **AC-2c [I] (R3 one-shots)** GIVEN a non-boss alien whose `beat_role` is `lead` while the boss holds `lead`, WHEN a `beat_impact` arrives with it as the actor, THEN one `lead` one-shot is scheduled at that time, and no persistent stem is loaded for it.
- **AC-2d [U] (R3, F2 boss)** GIVEN an enemy record with `is_boss = true` and `beat_role = kick`, WHEN roles are assigned, THEN it holds `lead` only, and `kick` is free for another alien.
- **AC-2e [U] (R3 everyone plays)** GIVEN 4 aliens all `snare`/`hats`, WHEN roles are assigned, THEN `snare` and `hats` are held, `snare` has a doubler, and the fourth alien holds `kick` (pass 4, the first free role). GIVEN `doubler_enabled = false`, THEN no doubler and no one-shot slot exists, and the third and fourth aliens hold `kick` and `bass`.
- **AC-2f [U] (R3 fixed)** GIVEN any assignment, WHEN a role holder is knocked out, THEN no other alien's role or slot changes.
- **AC-2g [U] (R3, F2 eight)** GIVEN 8 aliens all `snare`/`hats`, THEN every alien has exactly one slot, all 6 roles are held, and there are 2 extras: the `snare` doubler (pass 3) and the `kick` doubler (pass 4, the first empty extra slot in R2 order). GIVEN 8 aliens, two each of `kick`/`snare`, `snare`/`kick`, `bass`/`hats` and `hats`/`bass` in that line order, THEN `kick`, `snare`, `bass` and `hats` each have a holder and a doubler, and `lead` and `fx` are unheld.
- **AC-2h [U] (R4b Full House)** GIVEN 8 live aliens and `full_house_min = 7`, THEN the `full_house` layer is live from bar 1. WHEN the second knockout lands (6 live), THEN the layer leaves at the next bar boundary. GIVEN 5 aliens, THEN the layer is never loaded.
- **AC-2i [U] (R4c)** GIVEN a boss encounter with fewer than `boss_min_minions` alien minions, THEN boot validation logs a warning naming the encounter and boot continues.
- **AC-2j [U] (R1 kit source)** GIVEN an encounter whose `faction_id` is Bureaucratia and whose roster holds aliens of two alien factions, THEN the Bureaucratia kit and base tier are used and each alien plays its own `beat_role`. GIVEN a roster with an alien enemy and a human encounter faction, or an all-human roster with an alien encounter faction, THEN content validation fails at boot naming the encounter. GIVEN an all-human roster with a human faction, THEN its band kit plays at that faction's `score_base_tier` (F1).
- **AC-2k [U] (R11 hooks)** GIVEN a non-boss alien holding `lead`, THEN the kit's generic `lead` stem is live. GIVEN a boss with no `score_hook_id`, THEN the generic `lead` stem is live and hook B is never scheduled at any HP.
- **AC-3 [U] (R4)** GIVEN a one-enemy fight whose alien holds `hats`, WHEN bar 1 starts, THEN exactly 2 sub-streams are live: `hats` and the floor pulse.

**Tier, tempo and start**
- **AC-4 [U] (F1)** GIVEN `score_base_tier = 1`, THEN a street fight is tier 1, an encounter with `score_tier_override = 2` is tier 2, and a boss encounter with `boss_tier_bonus = 2` is tier 3. GIVEN base 3 and a boss, THEN the tier is 4 (clamped). An override of 5, or a computed tier of 4 against a kit holding tiers 1–3, fails boot validation naming the encounter.
- **AC-5 [U] (F3)** GIVEN tier 3 and the default config, THEN `seconds_per_beat == 60 / 124` (±1e-6).
- **AC-5b [M, scriptable] (F3, R6, R15)** GIVEN the Bureaucratia kit, THEN every tier-3 stem is tagged 124 BPM, its length is `loop_bars × 4 × 60 / 124` s (±1 sample), and all stems share one sample rate. The kit holds tiers 1–3 only.
- **AC-6 [U] (R7, F6)** GIVEN `mode_entered(battle)` at time m, `t_in = 0.30` and a 0.25 s intro, THEN the intro is scheduled at `m + 0.05` and bar 1 at `m + 0.30`. WHEN `transition_finished` arrives at `m + 0.33`, THEN bar 1 is not rescheduled and one warning is logged; at `m + 0.31`, no warning. **[I]** on device: bar 1's downbeat is within `reveal_tolerance_ms` (20 ms) of `transition_finished`.
- **AC-6d [U] (R7 late load)** GIVEN the kit load not complete at `mode_entered(battle)` at time m, WHEN it completes at `m + 0.50`, THEN no intro is scheduled, bar 1 starts at `m + 0.50` (±1 frame) and one warning is logged.
- **AC-6b [U] (F6 skip)** GIVEN `t_in = 0.15` and a 0.25 s intro, THEN no intro is scheduled and bar 1 starts at `m + 0.15`.
- **AC-6c [U] (States)** GIVEN `Idle`, WHEN `transition_started(→ battle)` arrives, THEN the state is `Armed` and no sub-stream is live. WHEN the transition rolls back, THEN the state is `Idle` and nothing was scheduled. GIVEN `Ending`, WHEN the sting finishes, THEN the state is `Idle` and no sub-stream is live. GIVEN `Ending` with the defeat sting playing, WHEN `transition_started(→ battle)` arrives (Retry), THEN the sting is cut and the state is `Armed`. GIVEN `Armed`, WHEN `display_resynced` or `replay_cancelled` arrives, THEN the scheduler emits 0 commands. GIVEN `Ending` with a sting playing, WHEN `replay_cancelled` arrives, THEN the scheduler emits 0 commands. GIVEN `Ending` with a sting of length L requested at time s, THEN the state is `Idle` at s + L.

**During the fight**
- **AC-7 [U] (R8, R9, F5)** GIVEN 124 BPM and a `beat_impact` whose plan has the `snare` holder as a KNOCKOUT reactor at 3.30 s into the loop, THEN the stem's fade is scheduled at 3.387 s (±1 block) and reaches −80 dB 120 ms later, and a 1-beat choke tail is scheduled at 3.387 s. GIVEN the same for the `bass` holder, THEN its fade is also at 3.387 s and its tail lasts 1.935 s.
- **AC-7b [U] (R8)** GIVEN a `BattleCore` knockout with no matching replay signal, THEN the scheduler emits 0 commands.
- **AC-8 [U] (R8)** GIVEN the speed-up latch set mid-fight, THEN `seconds_per_beat` and the stream tempo are unchanged.
- **AC-9 [U] (R9)** GIVEN the `kick` holder's knockout, THEN the floor pulse's fade-in is scheduled for the same `change_time` as the kick's fade-out.
- **AC-7c [U] (F5 lead)** GIVEN 124 BPM and a knockout event exactly on beat 7 (3.387 s), THEN the stem's fade is scheduled at beat 8 (3.871 s), not at 3.387 s.
- **AC-10 [U] (R9, R14)** GIVEN an all-alien roster and the final knockout at time t, THEN every sub-stream fades out at the next beat after t, no choke tail is scheduled, the victory sting is scheduled at that same time, and the state is `Ending`. WHEN `battle_ended_after_replay(true)` then arrives, THEN the scheduler emits 0 commands (exactly one sting).
- **AC-10b [U] (R14 backstop)** GIVEN the score in `Playing` with 2 aliens shown standing, WHEN `battle_ended_after_replay(true)` arrives, THEN every sub-stream cuts at the next beat and exactly one victory sting is scheduled there.
- **AC-11 [U] (R10)** GIVEN a held Bureaucratia encounter, WHILE rounds 1–3 play, THEN the score submix's low-pass is enabled at 800 Hz and the stems are on `base`. WHEN the replay releases round 4, THEN at the next bar the filter is disabled, every live stem is on `full`, and an `fx` riser is scheduled if `fx` is held. A later `round_advanced_after_replay` schedules nothing. GIVEN a Bureaucratia street fight (not held), or a neutral-rule fight, THEN the stems are on `full` from bar 1, the filter is never enabled and no variant switch is scheduled. GIVEN a held fight won in round 2, THEN the victory sting plays on the Music bus outside the filtered submix.
- **AC-12 [U] (R11, F4)** GIVEN the Supervisor at 110 max HP, WHEN shown HP at `beat_finished` is 56, THEN no switch. WHEN it is 55, THEN hook B is scheduled at the next bar. WHEN he is healed to 110 afterwards, THEN hook B stays.
- **AC-13 [U] (R13, score side)** GIVEN a battle-cry event before bar 1, THEN bar 1 plays, every sub-stream is silent for exactly `cry_break_bars` bars from bar 2's downbeat, and live again at the following downbeat. GIVEN the event mid-bar 3, THEN the break starts at bar 4. **[I]** the cry's audio starts inside the silent bar.
- **AC-13b [U] (R13 band mode)** GIVEN a human-only fight, THEN no battle-cry event is accepted and no break is scheduled.

**Endings and states**
- **AC-14 [U] (R14)** GIVEN `battle_fled_after_replay()`, THEN the record scratch is scheduled at once, and every sub-stream fades within 50 ms, with no quantise wait. GIVEN `battle_ended_after_replay(false)`, THEN every sub-stream cuts at the next beat and the defeat sting is scheduled there, and a later `overlay_opened(DefeatPrompt)` schedules nothing. GIVEN Retry, THEN the score re-arms with the same assignment, the held state restored for a held encounter, no drop and no hook B.
- **AC-14b [U] (R14 leaving)** GIVEN the score in `Playing` with a knockout fade pending, WHEN `transition_started(battle, title)` arrives, THEN every sub-stream fades within `layer_fade_ms`, the pending fade is discarded, no sting is requested and the state is `Idle`. The same from `Armed` and `Intro`, with the kit load cancelled.
- **AC-15 [U] (Ducked)** GIVEN a pause overlay opens mid-bar, WHEN it closes 3.0 s later, THEN the loop position advanced 3.0 s (±1 block), the score submix was at `duck_db` while it was open, the Music bus outside it was not ducked, and the loop never restarted. GIVEN the Menu opens during a cry break and closes after it, THEN the break still ends on its scheduled downbeat. GIVEN the Defeat Prompt opens, THEN the `ducked` flag stays clear.

**Edge cases**
- **AC-16 [I] (Edge: stems missing)** GIVEN a kit ID with no stems on disk and an injected logger, WHEN the battle runs to its end, THEN it completes, no sub-stream is live, and the logger got exactly one error containing the kit ID. The same holds for a missing band-mode track.
- **AC-17 [U] (Edge: mixed roster)** GIVEN 1 alien (`snare`) and 1 enemy from a non-alien faction, THEN the human holds no role. WHEN the alien is knocked out first, THEN its choke tail is scheduled, no victory sting is scheduled, and only the floor pulse is live. WHEN the human is then knocked out, THEN the floor pulse cuts at the next beat and the victory sting is scheduled there.
- **AC-20 [U] (Edge: validation)** GIVEN an alien enemy record with no `beat_role`, or with `beat_role == fallback_role`, THEN content validation fails at boot, naming the record. GIVEN a non-alien enemy with no `beat_role`, THEN validation passes.
- **AC-21 [U] (Edge: two bosses)** GIVEN a non-boss encounter with two `is_boss` enemies in line order, THEN the first holds `lead` and drives R11. The second is assigned as a non-boss.
- **AC-22 [U] (Edge: same bar)** GIVEN a knockout and the round-4 release in the same bar, THEN the knockout's fade is scheduled before the variant switch, and the switch applies only to stems still live.
- **AC-23 [U] (Edge: last knockout in the break)** GIVEN the cry break is active, WHEN the last alien's knockout arrives, THEN the break ends and the victory sting is scheduled at the next beat, not at the end of the bar.
- **AC-25 [U] (Edge: speed-up burst)** GIVEN three knockout events inside one beat, THEN three fades are scheduled, each at its own F5 time, and none is dropped.
- **AC-26 [U] (Edge: overlay in intro)** GIVEN an overlay opens during `Intro`, THEN the intro and bar 1 keep their scheduled times, at `duck_db`.
- **AC-27 [U] (Edge: muted)** GIVEN the Music bus at 0%, THEN the beat clock reports bar and beat positions identical to an unmuted run.
- **AC-28 [U] (Edge: resync)** GIVEN 3 live alien layers, WHEN `display_resynced` arrives with one of those aliens shown knocked out, THEN at the next bar exactly the other 2 layers are live and no choke tail is scheduled.
- **AC-29 [U] (Edge: cancel)** GIVEN the score in `Playing` and a knockout fade scheduled but not yet applied, WHEN `replay_cancelled` arrives, THEN that fade is discarded and every other live layer stays live.
- **AC-30 [U] (R13 knockout in break)** GIVEN the cry break active and 3 live aliens including the `kick` holder, WHEN the `kick` holder's knockout arrives mid-break, THEN no choke tail is scheduled, and at the slam downbeat the other 2 layers and the floor pulse are live.
- **AC-31 [U] (R4b held)** GIVEN a held encounter with 8 live aliens and `full_house_min = 7`, THEN the `full_house` layer is not live before the drop and joins at the drop's bar. GIVEN only 6 live at the drop, THEN it never joins.
- **AC-32 [U] (F5 monotonic)** GIVEN `loop_bars = 8` at 124 BPM (loop length 15.484 s), WHEN a knockout arrives 1.0 s into the loop's second pass, THEN `now` is 16.484 s and the fade is scheduled at beat 35 (16.935 s after `loop_start`), not at a time in the first pass.

**Content and performance**
- **AC-18 [M] (R12)** GIVEN any kit submitted for shipping, THEN its review record shows the originality listen check passed (the "removed label" test), a composer declaration of no third-party samples, and that every stem is mouth-made. For tiers 3–4, the record also shows the user's listen sign-off (OQ-7).
- **AC-19 [I] (Performance)** GIVEN the worst case (8 alien streams + the Full House layer, with tails and one-shots firing), WHEN it plays for a 10-minute soak on the min-spec target, THEN the `MusicClock`, sampled every frame, never stalls for more than 2 mix blocks while unpaused and drifts no more than 5 ms from the wall clock; and the kit's stems total 24 MB or less on disk, streamed OGG (a placeholder planning budget with no measured basis yet; OQ-8 sizes the real Paris matrix and confirms or replaces it). The engine API the clock reads is pinned by the Audio ADR (OQ-2).

## Open Questions

| ID | Question | Owner | Resolve by | Status |
|---|---|---|---|---|
| OQ-1 | **Resolved 2026-10-29.** Consults merged: the tier BPM ladder, the Bureaucratia kit, the round 1–3 low-pass "waiting room", the Rat Catcher style, two-pass assignment, one-shots for extra leads and fx, and longer tails for the foundation roles. **Not adopted:** (a) systems-designer's progress-based F1 (`region_index` × `occupation_stage`). It puts the Paris boss at tier 2 and needs a new encounter `kind` field; the faction base tier, boss bonus and override keep each boss at its region's peak, using existing fields. (b) A mid-fight tier swell (+1 at the drop, +1 at low boss HP). A tier change means a tempo change mid-loop, which the stems can't follow without time-stretching, so the drop switches variants (R10) and the boss switches hooks (R11) instead | main session | — | Resolved |
| OQ-2 | Godot `AudioStreamSynchronized` (added in 4.3) is assumed for R6. **NOT SOURCEABLE**: neither it, its stream limit nor a playback-latency query is covered by `docs/engine-reference/godot/`. Verify on 4.7.2 that per-stream volume can change at runtime without clicks, find its sub-stream limit and size one kit's sub-stream count (6 roles × variants, ad-libs, floor pulse, hook B) against it. Also settle whether the stream can start at an exact future mix time (R7 bar 1; otherwise the frame-quantised start R7 already tolerates) and how a kit loads on a thread (R7 Arm). Record all of it in an Audio ADR. Fallback: N players started on the same mix frame, with drift correction | technical-director / godot-specialist | Before the first implementation story | Open — HIGH risk |
| OQ-3 | Do aliens beatbox outside battle (overworld barks as beatbox blips)? This doc covers battle only | narrative-director + audio-director | Dialogue, Banter & Quests GDD | Open |
| OQ-4 | Who produces the stems (a hired beatboxer vs synthesis), and the legal review of R12 before ship | producer | Vertical Slice | Open |
| OQ-5 | **Resolved 2026-10-29** (audio-director): distorted guitar and bass, a live kit, an outlaw harmonica or whistle motif, and plainer than the beatbox (R1) | audio-director | — | Resolved |
| OQ-6 | **Resolved 2026-10-29** (revision 2): Game State pins `t_in` per transition; R7 and F6 now time the intro from `mode_entered` and land bar 1 on `transition_finished`, so the unbounded swap no longer matters | — | — | Resolved |
| OQ-7 | IP risk: four-on-the-floor plus an arpeggio reads as "Sandstorm" even as homage. The user hears the tier 3–4 stems before final delivery, not only the brief | audio-director + user | Before any tier 3–4 kit is accepted | Open |
| OQ-8 | Scope: up to 6 roles × 4 tiers × `full` (and `base` for held encounters) per kit, plus doublers, one-shots and a `full_house` layer per tier where 7+ enemy fights exist. Size the real Paris matrix (tiers 1–3, `base` only at the tiers the held encounters use, and only the roles the Paris roster uses) with `sound-designer` before commissioning | producer + sound-designer | Before the stem commission | Open |
| OQ-9 | Feel: a full-volume tier 4 mix under the speed-up latch may feel mismatched. Consider a small Music trim while the latch is set (a feel tweak that carries no information) | audio-director | Vertical Slice playtest | Open |
| OQ-10 | Roster reality: Paris street fights are one Clerk (one role plus the floor pulse) and end in a round or two, and the Supervisor may also fall before round 4. Revision 2 keeps street fights unfiltered and holds only the story encounter and the Supervisor; whether those reach their drop depends on the difficulty pass (playtest 2026-10-29: "too ez") | game-designer + audio-director | Vertical Slice playtest | Open |
| OQ-12 | **The 8-enemy battle line** (user direction, 2026-10-29: typical 2–5, late-game and hard areas up to 8, bosses with minions). Nothing caps the roster today, but Sprite & Camera's battle staging and read-order checks, Turn Battle's targeting UI and enemy-turn pacing, and the boot validators must be specified and tested for 8 enemies. Owed in those GDDs | game-designer + Sprite & Camera owner | Before the first 6+ enemy encounter is authored | Open |
| OQ-11 | Should an authored opener (story encounter, boss) also get a cry-style break? Off in MVP (R13) | narrative-director | Dialogue, Banter & Quests GDD | Open |
