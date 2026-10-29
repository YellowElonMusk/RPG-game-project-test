# Beatbox Battle Score

> **Status**: Designed (pending an independent `/design-review`)
> **Creative Director Review (CD-GDD-ALIGN)**: skipped — lean mode. Acceptance criteria validated by qa-lead (2026-10-29).
> **Author**: user + agents (main session, audio-director, systems-designer; the consults were merged on 2026-10-29, and the rejected proposals are listed under Open Questions)
> **Last Updated**: 2026-10-29
> **Last Verified**: 2026-10-29
> **Implements Pillar**: Pillar 1 (The Joke Is the Mechanic), Pillar 4 (Readable in One Turn)
> **Source**: the user's idea (2026-10-29), recorded in `design/narrative/narrative-requests.md` §5.2 and `design/narrative/narrative-bible.md` §7. Split from Audio Manager (systems index #20), which keeps SFX, buses, volume settings and overworld/camp music.

## Summary

Aliens speak in beatbox, so in a fight **the enemies are the band**. Each alien on the field supplies one layer of a shared beatbox track, so the fight has no background music. A harder fight plays a harder beat, and late-game tracks are denser and faster. When an alien is knocked out, its layer drops out of the mix. When the last one falls, the beat stops dead and the victory sting plays. Fights against humans (the Rat Catchers) use ordinary battle music instead.

> **Quick reference** — Layer: `Presentation` · Priority: `Vertical Slice` (MVP ships one Paris kit, see Detailed Design) · Key deps: `Turn Battle System, Faction Rule Modifiers, Content Data Definitions, Game State & Scene Flow, Audio Manager`

## Overview

The Beatbox Battle Score turns each battle's alien roster into the battle music. Every alien enemy record names a **beat role**: kick, snare, bass, hats, lead or fx. At fight start, the score assigns the roles on the field, picks an **intensity tier** (1–4) from the encounter, and plays that tier's stems in one synchronised loop. During the fight, the score follows the *replayed* battle, not the raw logic: a layer drops out when that alien's knockout beat plays, the beat "drops" when the faction rule escalates (in Paris, when the Permit Ban lifts on round 4), and it cuts for one bar under the squad's battle cry. The score never carries information the screen doesn't also show. It is a comic reward that makes fights sound like a beatbox battle you are winning: every knockout thins the track until only silence and the sting remain.

## Detailed Design

### Core Rules

**R1. Who makes the score.** A battle's score mode comes from its faction's `kind`:
- `alien` → **beatbox mode**: the aliens on the field are the only music. There is no background track.
- `human` (the Rat Catchers) → **band mode**: an ordinary composed battle track that sounds scrappy and human: distorted guitar and bass, a live-feeling kit, and an outlaw harmonica or whistle motif for the bounty hunters. It is deliberately *not* beatbox, so a human fight sounds different within a second, and it is plainer than the beatbox tracks; it never out-cools them.
- A roster mixing aliens and humans uses beatbox mode; the humans contribute no layer (Edge Cases).

**R2. Beat roles.** Each alien enemy record has a `beat_role` and a `fallback_role`, from this fixed set, in **assignment priority order**:

| # | Role | What it is in beatbox terms | Job in the mix |
|---|---|---|---|
| 1 | `kick` | Bass drum: lip "b"/"p" kick | Pulse; holds the fight together |
| 2 | `snare` | Rimshot, "k"/"pf" snare, inward snare at high tiers | Backbeat |
| 3 | `bass` | Lip-buzz or throat bass line | Weight; the "harder" feel |
| 4 | `hats` | "ts"/"t-k" hi-hats, clicks | Speed and density |
| 5 | `lead` | Vocal hook: a sung or chopped phrase | Identity; the boss's voice |
| 6 | `fx` | Scratches, sirens, zips, drops | Punctuation and transitions |

**R3. Assigning the layers** (Formula F2). At fight start, each role is held by at most one alien. A boss always takes `lead`. Every other alien first claims its `beat_role`. Only then do the still-unassigned aliens try their `fallback_role`, so one alien's fallback never steals another's first choice. An alien left over becomes an **extra** on its `beat_role`:
- on `kick`, `snare`, `bass` or `hats`, it is that role's **doubler** and adds the role's ad-lib stem, never a second copy of the same stem;
- on `lead` or `fx`, it plays **one-shot hits** on its own attack animations, with no persistent stem, so it never clashes with the hook.

Each role has at most one doubler. Any further alien plays nothing, but still bobs (Visual/Audio). The assignment is fixed for the fight: a knockout never hands a role to another alien.

**R4. The floor pulse.** If no alien holds `kick`, the score plays the faction kit's **floor pulse**, a quiet, minimal kick-only stem. A one-enemy fight is never silent, and never sounds like a full band.

**R5. Intensity tier.** Every fight plays at one tier from 1 to 4 (Formula F1), chosen at fight start from data and never from RNG. The tier picks each role's stem variant and the tempo (Formula F3). As a guide:
- **Tier 1** (~92 BPM): a basic "boots and cats" pattern with a half-time feel. Sparse, lots of space.
- **Tier 2** (~108 BPM): light syncopation, 8th-note hats, a simple bass line. The arena-energy zone.
- **Tier 3** (~124 BPM): inward snares, triplet fills, a rolling bass, and the lead hook with call and response.
- **Tier 4** (~138 BPM): switches between inward and outward snares, polyrhythmic hats, a wobbling bass and double-time vocal runs. This is the late-game showcase, held to the bar of Dharni-style layering and the festival build of "Sandstorm" (feel only, see R12).

The tier sets each stem's complexity, not how many roles play: the roster decides that (R3).

Within a region, street fights sit lowest, the story encounter higher and the boss highest; later regions start higher.

**R6. Synchronisation.** All stems in a fight share one tempo, one time signature (4/4) and one loop length (`loop_bars`, default 8), and play sample-locked from a single synchronised stream. Every change the score makes (a layer in or out, a drop, a break) lands on a **quantise boundary**: the next beat for knockouts, the next bar for drops and breaks (Formula F5).

**R7. Starting on the beat.** The score starts during the battle wipe's *out* phase (Game State & Scene Flow, Visual/Audio), so **bar 1's downbeat lands on the reveal**. The time before it plays a short count-in from the kit (Formula F6). If the wipe is too short for any count-in, the score starts on the reveal.

**R8. Following the replay, not the logic.** The score listens only to the gated, replayed events from `BattleReplayController` (ADR-0006), never to `BattleCore`'s raw signals. A layer leaves when the player *sees* that alien's knockout, not when the logic resolved it a frame earlier. The player's speed-up latch changes **nothing** in the score: the tempo stays fixed, and only the quantised event times arrive sooner.

**R9. Knockout.** When an alien's knockout beat plays, its layer (or its doubler or one-shot slot) plays a **choke** tail and leaves at a beat boundary (Formula F5). The foundation roles, `kick` and `bass`, get a longer tail, so the floor visibly and audibly drains away rather than vanishing. If that was the `kick` holder, the floor pulse comes in at the same boundary (R4). When the last alien's knockout plays, there is **no choke tail**: every stem cuts on the next beat (F5 with `tail = 0`), and the **victory sting** plays (Audio Manager owns the sting).

**R10. Escalation drop.** A faction rule may declare one **escalation round** (Faction Rule Modifiers). For Bureaucratia it is the round the Permit Ban lifts, `permit_rounds + 1` = round 4, the same moment as the "all-out war" banner. Before it, a kit may hold its stems back. **Bureaucratia plays rounds 1–3 through a low-pass "waiting room" filter** (`prewait_lowpass_hz`, default 800 Hz, data file), matching the Permit Ban's hunker-down mood. When the replay releases the escalation round, the filter opens and all stems switch from their `base` to their `full` variant on the next bar, with an `fx` riser into it if anyone holds `fx`. The tier and tempo do not change. There is at most one drop per fight.

**R11. Boss second hook.** A boss's `lead` has two hooks. When the boss's HP falls to or below `boss_hook_threshold` (default 50%), as shown by the replay's HP change, the lead switches to hook B on the next bar. This happens once.

**R12. Originality (a hard content rule).** Every stem is original. No sample, melody, riff or recognisable rhythm is taken from "Sandstorm", from Dharni, or from any other existing track. The references describe *energy and layering* only, they appear in no player-facing or marketing text, and every kit passes a "could anyone name the source?" listen check before it ships. Every beatbox stem is mouth-made: recorded beatboxing, which processing (pitch, filtering, effects) may alter, but which is never replaced with drum-machine samples. The aliens *are* beatboxing.

**R13. The battle cry break.** When the squad's battle cry plays (about 1 fight in 4; the roll and the line belong to Dialogue, Banter & Quests, narrative bible §5), the score mutes all stems for `cry_break_bars` (default 1) starting at the next bar, and slams back in on the following downbeat. The cry is timed into that silent bar. In band mode, the cry never plays (narrative bible §5: not used against human targets).

**R14. Ending a fight.**
- **Victory**: R9's cut and the sting.
- **Defeat**: all stems cut on the next beat, then the Defeat Prompt's wry sting.
- **Fled**: a record-scratch `fx` (always available, even with no `fx` holder), and all stems cut at once, unquantised.
- **Retry**: the score restarts from the count-in, in sync with the retry wipe, with the original assignment and no carried-over drop.

**R15. Faction kits.** Each alien faction supplies one **beat kit**: a stem set per role per tier, a floor pulse, a count-in, choke tails and ad-libs, built from sounds that tell the faction's joke. **Bureaucratia (Paris, MVP)**:
- the kick is a **stamp thunk**, mouth-made;
- the snare is a staple-gun snap;
- the hats are typewriter clacks;
- the bass is a photocopier drone;
- the fx are the ticket dispenser's "ding" and paper rips;
- the Supervisor's lead is a monotone stamped chant ("Take a number. NEXT."), and hook B speeds it up ("NEXT. NEXT. NEXT.").

MVP ships this one kit, at the tiers Paris uses (1–3). Later factions add their own.

### States and Transitions

| State | Entered when | Exits to |
|---|---|---|
| `Idle` | No battle | `CountIn` on a battle `transition_started` |
| `CountIn` | The wipe's out phase begins | `Playing` on the reveal downbeat |
| `Playing` | Bar 1 downbeat | `Break` (cry), `Ending` (end of battle), `Ducked` (overlay) |
| `Break` | Battle cry at the next bar | `Playing` after `cry_break_bars` |
| `Ducked` | A pause or menu overlay opens (Game State overlay broadcast) | `Playing` when it closes. The loop keeps running at `duck_db`, so the beat never restarts |
| `Ending` | The released `battle_ended`, or Fled | `Idle` after the sting or cut |

Sub-state flags held during `Playing`: `dropped` (R10, once), `boss_hook_b` (R11, once), and the set of live layers.

### Interactions with Other Systems

| System | This system receives | This system provides |
|---|---|---|
| **Turn Battle System** via `BattleReplayController` (ADR-0006) | Gated replay events: the knockout beat per combatant, HP changes, released `round_advanced`, released `battle_ended` | Nothing back. The score never gates or delays the replay |
| **Faction Rule Modifiers** | The faction's escalation round, if any (Bureaucratia: `permit_rounds + 1`) | — |
| **Content Data Definitions** | Enemy `beat_role`, `fallback_role`; faction `kind`, `score_kit_id`, `score_base_tier`; encounter `score_tier_override` (all new fields, see Dependencies) | — |
| **Game State & Scene Flow** | `transition_started` / `transition_finished` for the battle wipe, overlay broadcasts, the retry wipe | — |
| **Audio Manager** | The Music bus, volume settings, the duck level, victory and defeat stings | Requests to play on the Music bus |
| **Dialogue, Banter & Quests** | The battle cry event (rolled, and timed to the next bar) | The next-bar time, so the cry can land in the break |
| **Sprite & Camera Presentation** | — | A beat clock (bar and beat position) that idle bobbing may follow (Visual/Audio) |

## Formulas

**F1. Intensity tier.** The `intensity_tier` formula is defined as:

`intensity_tier = score_tier_override if score_tier_override > 0 else clamp(score_base_tier + (boss_tier_bonus if is_boss else 0), 1, tier_max)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| score_tier_override | int | 0–4 | data file (`enc_` record) | Authored tier for a specific fight, such as the story encounter; 0 means none |
| score_base_tier | int | 1–3 | data file (`faction_` record) | The tier of the faction's ordinary street fights; rises with the region's place in the game |
| is_boss | bool | — | data file (`enc_` descriptor) | The encounter's existing boss flag |
| boss_tier_bonus | int | 0–2 | data file (score config) | How far a boss sits above its faction's street fights; default 2 |
| tier_max | int | 4 | constant | The top tier |

**Output Range:** 1 to 4. An override outside 0–4 is a content validation error at boot, not a runtime clamp.
**Example:** Bureaucratia has `score_base_tier = 1`. A Paris street fight is tier 1. The Permit Counter story encounter has `score_tier_override = 2`, so tier 2. The Supervisor is `1 + 2 = 3`. A region-4 faction with base 3 has street fights at tier 3 and a boss at `clamp(5) = 4`.

**F2. Role assignment.** The `assign_roles` procedure is defined as:

`holder[lead] = boss (if any)`; `line_order` below **excludes the boss**; **pass 1**: `for e in line_order: if holder[e.beat_role] is empty: holder[e.beat_role] = e`; **pass 2**: `for e unassigned in line_order: if holder[e.fallback_role] is empty: holder[e.fallback_role] = e`; **pass 3**: `for e unassigned in line_order: if extra[e.beat_role] is empty and doubler_enabled: extra[e.beat_role] = e` (a doubler stem on kick/snare/bass/hats; one-shots on lead/fx), `else e plays nothing`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| e.beat_role, e.fallback_role | enum | the 6 roles in R2 | data file (`enemy_` record) | This alien's preferred and second-choice roles; they must differ |
| line_order | list | 1–4 enemies | calculated (`enc_` enemy list order) | The battle-line order; it is also the tie-break |
| doubler_enabled | bool | — | data file (score config) | Whether pass 3 runs at all: false turns off both doubler stems and lead/fx one-shots; default true |
| holder[r], extra[r] | map | 0–1 per role | calculated | Who plays each role, and who is its extra |

**Output Range:** with at most 4 aliens on the field, 1 to 4 holders and 0 to 2 extras. An extra needs its role already held, so extras ≤ holders, and holders + extras ≤ 4. Live streams: at most 4 alien streams (holders plus doubler stems), plus the floor pulse when nobody holds `kick`. Choke tails and one-shots are short, overlapping hits, not loops.
**Example:** The Supervisor (`lead`) plus Clerk A (`snare`/`hats`), Clerk B (`snare`/`hats`) and Clerk C (`snare`/`hats`). The Supervisor holds `lead`. Pass 1: A takes `snare`. Pass 2: B takes `hats`. Pass 3: C doubles `snare`. Nobody holds `kick`, so the floor pulse plays. **Two-pass case:** A (`kick`/`snare`), B (`kick`/`bass`), C (`bass`/`hats`). Pass 1: A `kick`, C `bass`. Pass 2: B's `bass` is taken, so B doubles `kick` in pass 3. A single pass would have handed B the `bass` and pushed C off its first choice.

**F3. Tempo.** The `bpm` formula is defined as:

`bpm = tier_bpm[intensity_tier]`; `seconds_per_beat = 60 / bpm`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| tier_bpm | int[4] | 80–150 | data file (score config) | Tempo per tier; default `[92, 108, 124, 138]` (audio-director's ladder) |
| intensity_tier | int | 1–4 | calculated (F1) | — |

**Output Range:** 92 to 138 BPM by default, which gives 0.652 s down to 0.435 s per beat. Each kit's stems are authored at exactly its tiers' tempos; the score never time-stretches.
**Example:** The Supervisor at tier 3 plays at 124 BPM, so 0.484 s per beat and 1.935 s per bar.

**F4. Boss hook threshold.** The `boss_hook_b` condition is defined as:

`boss_hook_b = boss.hp_shown <= floor(boss.max_hp * boss_hook_threshold)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| boss.hp_shown | int | 0–max_hp | calculated (the replay's HP display snapshot) | HP as the player currently sees it |
| boss.max_hp | int | > 0 | data file (`enemy_` record) | — |
| boss_hook_threshold | float | 0.25–0.75 | data file (score config) | Default 0.5 |

**Output Range:** true or false; it latches true once.
**Example:** The Supervisor with 120 max HP switches to hook B on the bar after his shown HP reaches 60 or less; 61 does not switch. With 121 max HP the threshold is `floor(60.5) = 60`, so the switch never happens above 50%.

**F5. Quantised change time.** The `change_time` formula is defined as:

`change_time = loop_start + ceil((now - loop_start + tail) / unit) * unit`, where `unit = seconds_per_beat` for knockouts and `unit = 4 * seconds_per_beat` for drops, breaks and the boss hook, and `tail = ko_tail_beats * seconds_per_beat` for knockouts, otherwise 0

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| now | float (s) | ≥ loop_start | calculated (the stream's playback position, corrected for output latency) | The current musical time |
| loop_start | float (s) | — | calculated | The time of bar 1's downbeat |
| ko_tail_beats | float | 0.5–4 | data file (score config) | The choke tail before the layer leaves: `ko_tail_beats_foundation` (default 4) for `kick` and `bass`, `ko_tail_beats_other` (default 1) for the rest |
| layer_fade_ms | int | 30–250 | data file (score config) | A short fade at `change_time` so a stem never clicks off; default 120 |

**Output Range:** for a knockout, from the tail up to the tail plus one beat after the event: 0.435 s (a 1-beat tail at 138 BPM) to 3.26 s (a 4-beat tail plus one beat at 92 BPM). For bar-quantised changes, from 0 up to one bar (at most 2.61 s at 92 BPM). The last knockout uses `tail = 0` (R9).
**Example:** At 124 BPM (0.484 s per beat), the `snare` holder's knockout plays at 3.30 s into the loop. The tail is 0.484 s, so `ceil(3.784 / 0.484) = 8` beats, and the layer leaves at 3.87 s, fading over 120 ms. Had it held `bass`, the tail would be 1.935 s: `ceil(5.235 / 0.484) = 11` beats, so it leaves at 5.32 s.

**F6. Count-in.** The `count_in_beats` formula is defined as:

`count_in_beats = clamp(floor(wipe_out_s / seconds_per_beat), 0, count_in_max)`; the count-in starts at `reveal_time - count_in_beats * seconds_per_beat`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| wipe_out_s | float (s) | 0–2 | calculated (Game State's wipe out-phase length) | Time available before the reveal |
| count_in_max | int | 0–4 | data file (score config) | Default 4 |

**Output Range:** 0 to 4 beats.
**Example:** A 1.2 s out phase at 124 BPM gives `floor(1.2 / 0.484) = 2` beats of count-in ("ts… ts…"), and bar 1 lands on the reveal.

## Edge Cases

- **If a roster mixes aliens and humans**: beatbox mode; the humans hold no role and bob to nothing. If every alien is knocked out while humans remain, the floor pulse plays alone until the fight ends. That is the joke: the humans have no rhythm.
- **If an alien record has no `beat_role`**: content validation fails at boot (Content Data's fail-fast rule). It is never silently skipped.
- **If `beat_role == fallback_role`**: a validation error.
- **If two bosses are on the field**: the first in line order takes `lead`; the second is treated as a non-boss with its own roles. Only the first drives R11.
- **If a knockout and a drop land on the same bar**: the knockout applies first (on its beat), then the drop switches only the live layers.
- **If the last alien is knocked out during the battle-cry break**: the break ends early and the victory sting plays at the next beat. It never waits out the silent bar.
- **If a revive brings an alien back**: its layer returns at the next bar, on its original role (assignment never changes, R3). If that role is `kick`, the floor pulse leaves.
- **If the speed-up latch makes several knockouts arrive inside one beat**: each is quantised independently and they may leave on the same beat. Nothing is skipped.
- **If the faction has no escalation round** (a neutral rule): R10 never fires. The fight stays on `base` stems throughout.
- **If an overlay opens during `CountIn`**: the count-in continues ducked, so the reveal stays on the beat.
- **If audio output is muted or the Music bus is at 0%**: the score still runs its clock (the beat clock for bobbing stays valid); nothing depends on hearing it.
- **If the stems fail to load**: battle continues silently, and an error is logged with the kit ID. Battle never waits on audio.
- **If the band-mode track is missing for a human fight**: silence plus a logged error, the same as above.

## Dependencies

| System | Direction | Hard/Soft | Interface | Status |
|---|---|---|---|---|
| Turn Battle System (via `BattleReplayController`) | Upstream | Hard | Gated replay events (ADR-0006) | GDD reverse-documented; ADR-0006 Accepted; the replay controller is not built yet |
| Faction Rule Modifiers | Upstream | Soft | An escalation-round query on the active rule. **New**: `FactionRule` gains an optional `score_escalation_round()` (Bureaucratia returns `permit_rounds + 1`) | Owed change |
| Content Data Definitions | Upstream | Hard | **New fields**: `enemy_.beat_role`, `enemy_.fallback_role`; `faction_.score_kit_id`, `faction_.score_base_tier`; `enc_.score_tier_override` (optional, default 0); a `score_config` record for the tuning values; validation rules in Edge Cases | Owed change |
| Game State & Scene Flow | Upstream | Soft | Transition and overlay announcements, the wipe's out-phase length | Approved; no change |
| Audio Manager | Upstream | Hard | The Music bus, settings volumes, the duck level, stings | Not designed (index #20) |
| Dialogue, Banter & Quests | Peer | Soft | The battle-cry event, and the next-bar time | Not designed (index #17) |
| Sprite & Camera Presentation | Downstream | Soft | Reads the beat clock for idle bobbing (optional, Vertical Slice) | Approved; an additive change only |

## Visual/Audio Requirements

> `art-director` not consulted (lean mode: this system's visuals are optional garnish, not read to play). The audio direction above is pending the audio-director consult (OQ-1).

- **Every sound here has a visual twin** (accessibility rule: no audio-only information). A layer leaving = the visible knockout. The drop = the visible "all-out war" banner. Boss hook B = the visible HP bar. The battle cry = its text line. The score adds no new information.
- **Bobbing (Vertical Slice)**: each alien's idle loop bobs on its own role's hits from the beat clock, so the player can *see* who is playing what. A non-player alien bobs on the kick. Under Reduce Motion, bobbing is replaced by a small static "♪" glyph on each playing alien (shape, not colour).
- **Alien speech captions**: when an alien "speaks" in battle text (barks), its line is shown as a caption such as *[aggressive boots-and-cats]*. Dialogue owns the text; this system only names the convention.
- **Bus and mix**: everything plays on the Music bus. The SFX bus (hits, `beat_impact`) ducks the score by `sfx_duck_db` (default −3 dB, fast attack, 150 ms release), so hits always read, even over a dense tier 4 mix. The battle cry needs no separate duck: the stems' own one-bar break (R13) is the duck, so it can never drift out of sync. Victory and defeat stings hard-cut the score, with no crossfade bleed. The score never ducks the UI bus. All stems in a kit share one sample rate and identical loop points, which synchronised playback requires (OQ-2). All stems are mono-compatible, because mono is a planned accessibility option.
- **Rat Catcher band mode**: one composed track per tier used, with the same start-on-the-beat rule (R7) and the same victory/defeat/flee endings (R14). There is no per-enemy layering.

## Game Feel

- **Knockouts should feel like the crowd losing a performer**: the choke tail is audible, and the track gets visibly and audibly thinner. A fight you are winning sounds emptier and emptier.
- **The drop at round 4 is the fight's payoff moment** in Paris: three rounds of held-back beat, then everything opens up with the specials.
- **The battle cry break should land like a mic drop**: silence, the yell, then the slam.
- No change ever lands off the grid. A late change on the beat beats an early change off it.

## UI Requirements

None of its own. It shows no HUD element. Volume lives in the Audio Manager's settings (accessibility requirements, Independent volume controls). The Reduce Motion "♪" glyph is a Presentation asset, not UI.

## Cross-References

| This document | References | Rule or value | Where |
|---|---|---|---|
| R1, R13 | Narrative bible | Aliens speak in beatbox; the Rat Catchers; the battle cry is not used against humans | `design/narrative/narrative-bible.md` §5, §6.5, §7 |
| R7 | Game State & Scene Flow | Battle music starts in the wipe's out phase | `design/gdd/game-state-scene-flow.md` Visual/Audio |
| R8 | ADR-0006 | Gated replay events; speed-up latch | `docs/architecture/adr-0006-battle-replay-ownership.md` |
| R10 | Faction Rule Modifiers / Bureaucratia | `permit_rounds = 3`; specials allowed from round 4 | `data/faction_rules/rule_bureaucratia_permit.tres`; `src/battle/factions/bureaucratia.gd` |
| R14 | Accessibility requirements | Victory/defeat music; no audio-only information | `design/accessibility-requirements.md` Auditory Accessibility |
| F1 | Overworld & Encounters | The `enc_` descriptor fields (`is_boss`, `faction_id`, enemy IDs) | `design/gdd/overworld-exploration-encounters.md` AC-14 |

## Acceptance Criteria

> **Test seam** (qa-lead, 2026-10-29). Split the score in two:
> - a pure `ScoreScheduler` (`RefCounted`) that takes replay events through an injected event-source interface and a `MusicClock` (`now()`, already latency-corrected), and returns timed commands `(t, action, role)`;
> - a thin mixer adapter that applies those commands to the synchronised stream.
>
> Unit tests drive the scheduler with a `FakeClock` advanced by hand, so they never wait for `BattleReplayController`. "Silent" means a sub-stream volume at or below −80 dB; "live" means above −60 dB. "±1 block" means one audio mix block. Tags: **[U]** unit, **[I]** integration, **[M]** manual or content gate.

**Mode and assignment**
- **AC-1 [I] (R1)** GIVEN an encounter whose faction `kind` is `alien`, WHEN the battle starts, THEN no band-mode track is loaded and only role stems and the floor pulse are live. GIVEN `kind` is `human`, THEN the band-mode track is live and no role stem is loaded.
- **AC-2 [U] (R3, F2)** GIVEN the roster Supervisor + three Clerks (`snare`/`hats`), WHEN roles are assigned, THEN the Supervisor holds `lead`, Clerk A `snare`, Clerk B `hats`, and Clerk C is the `snare` doubler on the ad-lib stem (not a second `snare` stem).
- **AC-2b [U] (F2 two-pass)** GIVEN A (`kick`/`snare`), B (`kick`/`bass`), C (`bass`/`hats`) in that line order, WHEN roles are assigned, THEN A holds `kick`, C holds `bass`, and B is the `kick` doubler.
- **AC-2c [I] (R3 one-shots)** GIVEN a non-boss alien whose `beat_role` is `lead` while the boss holds `lead`, WHEN its attack animation plays, THEN one `lead` one-shot is scheduled at that time, and no persistent stem is loaded for it.
- **AC-2d [U] (R3, F2 boss)** GIVEN a boss whose record `beat_role` is `kick`, WHEN roles are assigned, THEN the boss holds `lead` only, and `kick` is free for another alien.
- **AC-2e [U] (R3 nothing left)** GIVEN 4 aliens all `snare`/`hats`, WHEN roles are assigned, THEN `snare` and `hats` are held, `snare` has a doubler, and the fourth alien has no slot. GIVEN `doubler_enabled = false`, THEN no doubler and no one-shot slot exists.
- **AC-2f [U] (R3 fixed)** GIVEN any assignment, WHEN a role holder is knocked out, THEN no other alien's role or slot changes.
- **AC-3 [U] (R4)** GIVEN a one-enemy fight whose alien holds `hats`, WHEN bar 1 starts, THEN exactly 2 sub-streams are live: `hats` and the floor pulse.

**Tier, tempo and start**
- **AC-4 [U] (F1)** GIVEN `score_base_tier = 1`, THEN a street fight is tier 1, an encounter with `score_tier_override = 2` is tier 2, and a boss with `boss_tier_bonus = 2` is tier 3. GIVEN base 3 and a boss, THEN the tier is 4 (clamped). An override of 5 fails boot validation.
- **AC-5 [U] (F3)** GIVEN tier 3 and the default config, THEN `seconds_per_beat == 60 / 124` (±1e-6).
- **AC-5b [M, scriptable] (F3, R6, R15)** GIVEN the Bureaucratia kit, THEN every tier-3 stem is tagged 124 BPM, its length is `loop_bars × 4 × 60 / 124` s (±1 sample), and all stems share one sample rate. The kit holds tiers 1–3 only.
- **AC-6 [U] (R7, F6)** GIVEN a 1.2 s wipe out phase at 124 BPM, THEN `count_in_beats == 2` and the count-in starts at `reveal − 0.968` s. **[I]** on device: bar 1's downbeat is within 20 ms of `transition_finished`.
- **AC-6b [U] (F6 zero)** GIVEN a 0.3 s out phase at 124 BPM, THEN `count_in_beats == 0`, and bar 1 starts at the reveal.
- **AC-6c [U] (States)** GIVEN `Idle`, WHEN a battle `transition_started` arrives, THEN the state is `CountIn`. GIVEN `Ending`, WHEN the sting finishes, THEN the state is `Idle` and no sub-stream is live.

**During the fight**
- **AC-7 [U] (R8, R9, F5)** GIVEN 124 BPM and the `snare` holder's knockout replay event at 3.30 s into the loop, THEN its fade is scheduled to start at 3.871 s (±1 block) and reach −80 dB 120 ms later. GIVEN the same for the `bass` holder, THEN the fade starts at 5.323 s.
- **AC-7b [U] (R8)** GIVEN a `BattleCore` knockout with no matching replay event, THEN the scheduler emits 0 commands.
- **AC-8 [U] (R8)** GIVEN the speed-up latch set mid-fight, THEN `seconds_per_beat` and the stream tempo are unchanged.
- **AC-9 [U] (R9)** GIVEN the `kick` holder's knockout, THEN the floor pulse's fade-in is scheduled for the same `change_time` as the kick's fade-out.
- **AC-10 [U] (R9, R14)** GIVEN the last alien's knockout event at time t, THEN every sub-stream fades out at the next beat after t (with `tail = 0`), and the victory sting is scheduled at that same time.
- **AC-11 [U] (R10)** GIVEN a Bureaucratia fight, WHILE rounds 1–3 play, THEN the Music bus low-pass filter is enabled at 800 Hz. WHEN the replay releases round 4, THEN at the next bar the filter is disabled, every live stem is on its `full` variant, and an `fx` riser is scheduled if `fx` is held. A later `round_advanced` schedules nothing. GIVEN a neutral-rule fight, THEN the filter is never enabled and no variant switch is ever scheduled.
- **AC-12 [U] (R11, F4)** GIVEN the Supervisor at 120 max HP, WHEN shown HP is 61, THEN no switch. WHEN shown HP is 60, THEN hook B is scheduled at the next bar. WHEN he is healed to 120 afterwards, THEN hook B stays.
- **AC-13 [U] (R13, score side)** GIVEN a battle-cry event, THEN every sub-stream is silent from the next bar boundary for exactly `cry_break_bars` bars and live again at the following downbeat. **[I]** the cry's audio starts inside that silent bar.
- **AC-13b [U] (R13 band mode)** GIVEN a human fight, THEN no battle-cry event is accepted and no break is scheduled.

**Endings and states**
- **AC-14 [U] (R14)** GIVEN Fled, THEN the record scratch is scheduled at once, and every sub-stream fades within 50 ms, with no quantise wait. GIVEN Defeat, THEN every sub-stream cuts at the next beat and the defeat sting is scheduled there. GIVEN Retry, THEN the score restarts at its count-in with the same assignment, the filter on (Bureaucratia), and no drop.
- **AC-15 [U] (Ducked)** GIVEN a pause overlay opens mid-bar, WHEN it closes 3.0 s later, THEN the loop position advanced 3.0 s (±1 block), the Music bus was at `duck_db` while it was open, and the loop never restarted.

**Edge cases**
- **AC-16 [I] (Edge: stems missing)** GIVEN a kit ID with no stems on disk and an injected logger, WHEN the battle runs to its end, THEN it completes, no sub-stream is live, and the logger got exactly one error containing the kit ID. The same holds for a missing band-mode track.
- **AC-17 [U] (Edge: mixed roster)** GIVEN 1 alien (`snare`) and 1 human, WHEN the alien is knocked out first, THEN only the floor pulse is live until the battle ends.
- **AC-20 [U] (Edge: validation)** GIVEN an alien record with no `beat_role`, or with `beat_role == fallback_role`, THEN content validation fails at boot, naming the record.
- **AC-21 [U] (Edge: two bosses)** GIVEN two bosses in line order, THEN the first holds `lead` and drives R11. The second is assigned as a non-boss.
- **AC-22 [U] (Edge: same bar)** GIVEN a knockout and the round-4 release in the same bar, THEN the knockout's fade is scheduled before the variant switch, and the switch applies only to stems still live.
- **AC-23 [U] (Edge: last knockout in the break)** GIVEN the cry break is active, WHEN the last alien's knockout arrives, THEN the break ends and the victory sting is scheduled at the next beat, not at the end of the bar.
- **AC-24 [U] (Edge: revive)** GIVEN the `kick` holder was knocked out and is revived, THEN its stem returns at the next bar on `kick`, and the floor pulse leaves at the same time.
- **AC-25 [U] (Edge: speed-up burst)** GIVEN three knockout events inside one beat, THEN three fades are scheduled, each at its own F5 time, and none is dropped.
- **AC-26 [U] (Edge: overlay in count-in)** GIVEN an overlay opens during `CountIn`, THEN bar 1 still starts at the reveal, at `duck_db`.
- **AC-27 [U] (Edge: muted)** GIVEN the Music bus at 0%, THEN the beat clock still reports bar and beat positions identical to an unmuted run.

**Content and performance**
- **AC-18 [M] (R12)** GIVEN any kit submitted for shipping, THEN its review record shows the originality listen check passed (the "removed label" test), a composer declaration of no third-party samples, and that every stem is mouth-made. For tiers 3–4, the record also shows the user's listen sign-off (OQ-7).
- **AC-19 [M] (Performance)** GIVEN the worst case (4 alien streams + the floor pulse, with tails and one-shots firing), WHEN it plays for a 10-minute soak on the min-spec target, THEN the Godot Monitor shows no audio buffer underrun (no dropout heard, and the audio driver's output latency stays stable), and the kit's stems total 24 MB or less on disk, streamed OGG.

## Open Questions

| ID | Question | Owner | Resolve by | Status |
|---|---|---|---|---|
| OQ-1 | **Resolved 2026-10-29.** Consults merged: the tier BPM ladder, the Bureaucratia kit, the round 1–3 low-pass "waiting room", the Rat Catcher style, two-pass assignment, one-shots for extra leads and fx, and longer tails for the foundation roles. **Not adopted:** (a) systems-designer's progress-based F1 (`region_index` × `occupation_stage`). It puts the Paris boss at tier 2 and needs a new encounter `kind` field; the faction base tier, boss bonus and override keep each boss at its region's peak, using existing fields. (b) A mid-fight tier swell (+1 at the drop, +1 at low boss HP). A tier change means a tempo change mid-loop, which the stems can't follow without time-stretching, so the drop switches variants (R10) and the boss switches hooks (R11) instead | main session | — | Resolved |
| OQ-2 | Godot `AudioStreamSynchronized` (added in 4.3) is assumed for R6. Verify on 4.7.2 that per-stream volume can change at runtime without clicks, and record it in an Audio ADR. Fallback: N players started on the same mix frame, with drift correction | technical-director / godot-specialist | Before the first implementation story | Open — HIGH risk (post-cutoff verification) |
| OQ-3 | Do aliens beatbox outside battle (overworld barks as beatbox blips)? This doc covers battle only | narrative-director + audio-director | Dialogue, Banter & Quests GDD | Open |
| OQ-4 | Who produces the stems (a hired beatboxer vs synthesis), and the legal review of R12 before ship | producer | Vertical Slice | Open |
| OQ-5 | **Resolved 2026-10-29** (audio-director): distorted guitar and bass, a live kit, an outlaw harmonica or whistle motif, and plainer than the beatbox (R1) | audio-director | — | Resolved |
| OQ-6 | The wipe's out-phase length isn't pinned in Game State's Formulas; F6 reads whatever it is | game-state owner | Implementation | Open |
| OQ-7 | IP risk: four-on-the-floor plus an arpeggio reads as "Sandstorm" even as homage. The user hears the tier 3–4 stems before final delivery, not only the brief | audio-director + user | Before any tier 3–4 kit is accepted | Open |
| OQ-8 | Scope: up to 6 roles × 4 tiers × base and full variants per kit, plus doublers and one-shots. Size the real Paris matrix (tiers 1–3, and only the roles the Paris roster uses) with `sound-designer` before commissioning | producer + sound-designer | Before the stem commission | Open |
| OQ-9 | Feel: a full-volume tier 4 mix under the speed-up latch may feel mismatched. Consider a small Music trim while the latch is set (a feel tweak that carries no information) | audio-director | Vertical Slice playtest | Open |
