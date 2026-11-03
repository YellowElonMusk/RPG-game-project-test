# Audio Request List: Go back to your planet!

> Written 2026-11-04. Sources: `design/gdd/beatbox-battle-score.md` (R1-R15, F1-F6, Visual/Audio), `design/gdd/overworld-exploration-encounters.md` (Audio direction), `design/narrative/narrative-bible.md` §7, `src/overworld/overworld_sfx.gd`, `data/occupation_stages/*.tres`, `data/encounters/*.tres`. **There is no audio in the project yet**: no files and no Audio Manager. The code only fires event ids.

**How to use this**
1. Work top to bottom. Section 1 (the Paris beatbox kit) is what makes fights sound like this game; section 2 (overworld music and ambience) makes Paris feel alive.
2. Save each file at the exact path in the tables (create the folders).
3. Formats: **music and loops = OGG Vorbis, 44.1 kHz, quality 6+**; **short SFX = WAV, 16-bit, 44.1 kHz, mono** unless the table says stereo.
4. Loops must be cut sample-exact: start on the first downbeat, end exactly at the loop length, no fade, no reverb tail baked past the end.
5. When a batch is in, tell Claude ("Paris beatbox tier 1 is in"). Claude wires the Audio Manager, the buses and the loop points, and runs a listen test.

---

## 0. Fixed rules

| Rule | Value |
|---|---|
| **Fights have no background music** (user ruling) | The aliens on the field *are* the music: each alien performs one beatbox layer, and together they make the track. A knockout drops that alien's layer; the last knockout cuts the beat dead and the victory sting plays |
| **Everything is original** (R12) | Darude's "Sandstorm" and the beatboxer Dharni are for *energy and layering feel only*. Incredibox is a reference for *structure* only. No sample, melody, riff or recognisable rhythm from them or any track. Never name them in a prompt to an AI tool |
| **Sounds mouth-made** (R12, as amended 2026-11-04) | AI-generated a cappella beatbox is fine (user ruling). Every stem must still *sound* like a mouth: reject anything that sounds like a drum machine or instruments |
| Loudness, music | -16 LUFS integrated, true peak -1 dBTP |
| Loudness, beatbox | The **full** tier mix (every layer at once) lands near -16 LUFS. Mix the stems *together*, then export each one solo with no further gain change |
| Loudness, ambience | -26 LUFS integrated (a bed under the music) |
| Loudness, stings | -14 LUFS short-term, true peak -1 dBTP |
| SFX peaks | Battle and overworld -3 dBFS peak; UI -12 dBFS peak (quiet and dry) |
| Mono | Everything must sound fine summed to mono (mono is a planned accessibility option) |
| Every sound has a visual twin | Nothing may carry information only by sound (accessibility rule). Already true of every event below |
| Tone | Busier, never menacing. Comic bureaucracy, not dread (overworld guardrail 2) |

---

## 1. PRIORITY 1: the Bureaucratia beatbox kit (Paris)

**How it works (GDD R2-R5).** Each alien type has a **beat role**: kick, snare, bass, hats, lead or fx. Each fight plays at one **intensity tier**; the tier sets the tempo and how complex each stem is.

| Tier | BPM | Loop (8 bars of 4/4) | Exact length | Samples at 44.1 kHz | Feel | Used in Paris by |
|---|---|---|---|---|---|---|
| 1 | 92 | 32 beats | 20.870 s | 920,348 | Basic "boots and cats", half-time, lots of space | All Clerk street fights (2-5 Clerks) |
| 2 | 108 | 32 beats | 17.778 s | 784,000 | Light syncopation, 8th-note hats | Permit Counter story fight (5 Clerks) |
| 3 | 124 | 32 beats | 15.484 s | 682,839 | Inward snares, triplet fills, call-and-response hook | Supervisor boss (+3 Clerks) |
| 4 | 138 | 32 beats | 13.913 s | 613,565 | Showcase layering | Not in Paris |

**Who plays what in Paris** (GDD F2; roles proposed in the GDD, not yet in the data):

| Enemy | `beat_role` / fallback | Sound (R15) |
|---|---|---|
| Clerk | snare / hats | Snare = a mouth **staple-gun snap**. Hats = **typewriter clacks** |
| Supervisor (boss) | always `lead` | Hook A: a monotone stamped chant, "Take a number. NEXT." Hook B (at 50% HP): faster, "NEXT. NEXT. NEXT." |
| (5th Clerk in a 5-Clerk fight) | pushed onto kick | Kick = a mouth **stamp thunk** |
| (nobody holds kick) | floor pulse | A quiet, minimal kick-only stem so a fight is never silent |

Sound vocabulary for the whole kit: stamp thunk (kick), staple-gun snap (snare), typewriter clacks (hats), photocopier drone (bass), ticket-dispenser "ding" and paper rips (fx), mumbled form-reading drone (generic lead). All mouth-made.

**Variants.** `full` is the normal stem. `base` is a held-back version for the two fights that "build" (Permit Counter, Supervisor): rounds 1-3 play `base` behind a low-pass "waiting room" filter (the game applies the filter), then on round 4 the permit arrives and everything switches to `full`. Make `base` sparser (fewer hits, no fills), same tempo, same length.

**Key (proposal; the GDD doesn't fix one):** every pitched part (photocopier bass, the chant) in **D minor**, so all stems of the kit fit together.

### 1.1 Loop stems (OGG, stereo, mono-safe, exact length per tier)

Path: `assets/audio/beatbox/bureaucratia/`. Name: `bx_bur_t<tier>_<role>_<variant>.ogg`. An `adlib` stem is what a second alien on the same role adds (never a copy of the main stem).

| # | File | Tier | Needed because |
|---|---|---|---|
| 1 | `bx_bur_t1_snare_full.ogg` | 1 | Every street fight |
| 2 | `bx_bur_t1_hats_full.ogg` | 1 | Every street fight |
| 3 | `bx_bur_t1_snare_adlib_full.ogg` | 1 | 3+ Clerks |
| 4 | `bx_bur_t1_hats_adlib_full.ogg` | 1 | 4+ Clerks |
| 5 | `bx_bur_t1_kick_full.ogg` | 1 | 5 Clerks (`enc_paris_clerks_keen`) |
| 6 | `bx_bur_t1_floor_pulse.ogg` | 1 | Whenever nobody holds kick |
| 7-16 | `bx_bur_t2_{snare,hats,snare_adlib,hats_adlib,kick}_{base,full}.ogg` | 2 | Permit Counter (5 Clerks, held) |
| 17 | `bx_bur_t2_floor_pulse.ogg` | 2 | After the kick Clerk is knocked out |
| 18-23 | `bx_bur_t3_{snare,hats,snare_adlib}_{base,full}.ogg` | 3 | Supervisor's 3 Clerks (held) |
| 24-27 | `bx_bur_t3_hook_supervisor_{a,b}_{base,full}.ogg` | 3 | The boss hook; B can arrive before the drop, so it needs `base` too |
| 28 | `bx_bur_t3_floor_pulse.ogg` | 3 | No kick in the boss fight |

**28 loops.** Not needed for Paris (skip unless rosters grow): bass, generic lead, fx loops, any `full_house` layer (that only happens with 7+ enemies).

### 1.2 One-shots (WAV, mono)

| File (`assets/audio/beatbox/bureaucratia/`) | Length | Direction |
|---|---|---|
| `bx_bur_intro.wav` | 0.25 s max | An inhale and a single "ts". Plays as the battle wipe reveals |
| `bx_bur_t{1,2}_tail_kick.wav` | 4 beats at that tier | The stamp-thunk floor draining away when the kick Clerk falls |
| `bx_bur_t{1,2,3}_tail_snare.wav`, `bx_bur_t{1,2,3}_tail_hats.wav` | 1 beat | A short choke when that layer leaves |
| `bx_bur_t3_tail_lead.wav` | 1 beat | Only if the boss falls before his Clerks |
| `bx_scratch_fled.wav` | ~0.6 s | A mouth record-scratch when the squad flees (shared by all kits) |
| `bx_bur_fx_ding.wav`, `bx_bur_fx_rip.wav` | < 0.5 s | Ticket "ding", paper rip. Spare one-shots for later rosters |

### 1.3 Paste-ready brief (for a beatboxer, or an AI tool)

> *Original a cappella beatbox loop, no instruments, no singing except where stated, [92 / 108 / 124] BPM, 4/4, exactly 8 bars, starts on the downbeat, seamless loop. Comedic office theme: the kick sounds like a rubber stamp thunking on a desk, the snare like a staple gun, the hi-hats like typewriter keys, made with the mouth. Tier [1: sparse, half-time, lots of space / 2: light syncopation, 8th-note hats / 3: inward snares, triplet fills, tight and driving]. Export each layer (kick, snare, hats, ad-libs) as a separate solo stem of identical length.*

> *Supervisor hook (lead), D minor, 124 BPM, 8 bars: a deadpan monotone chant of the words "Take a number. NEXT." like a bored official calling the queue, rhythmic and stamped, with beatbox accents between phrases. Hook B: the same voice speeding up, "NEXT. NEXT. NEXT.", more urgent, same key and length.*

**Who makes the stems (GDD OQ-4, resolved 2026-11-04): you, with an AI audio tool.** Generate each layer as its own solo stem where the tool allows it; if it only gives a full mix, generate the mix and Claude can split it, though solo stems loop much more cleanly. Before any tier 3 stem is accepted, you listen to it for "could anyone name the source?" (GDD OQ-7).

---

## 2. PRIORITY 2: overworld music and ambience

> **Proposal.** The Audio Manager (owner of overworld and camp music) has no GDD yet. The overworld GDD defines only the ambience beds. Default: each map plays a music loop with its ambience bed underneath; the ambience keeps playing when the music ducks under a dialogue box.

### 2.1 Music (OGG, stereo, -16 LUFS, seamless loop)

All prompts: instrumental, no vocals, no lyrics. Add "seamless loop" and trim to a whole number of bars yourself.

| # | File (`assets/audio/music/`) | Where | Length | Paste-ready prompt |
|---|---|---|---|---|
| 1 | `mus_paris_town.ogg` | Town hub (stage 1) | 60-90 s loop | *Instrumental, 100 BPM, F major, light and mischievous storybook JRPG town theme, plucked strings, clarinet, soft accordion colour (light, not a parody), brushed snare, toy glockenspiel, golden-hour warmth, curious and cosy, Dragon Quest town feel, seamless loop* |
| 2 | `mus_paris_occupied.ogg` | Overworld segment (stage 2) | 60-90 s | *Same melody idea as a cosy town theme but stiffened: 100 BPM, F major turning modal, rigid staccato strings, typewriter and rubber-stamp percussion, ticking clock, comic bureaucratic tension, never scary, seamless loop* |
| 3 | `mus_paris_ministry.ogg` | Dungeon: the Ministry (stage 3) | 90-120 s | *Comic dread in a giant government office, 84 BPM, D minor, pizzicato strings, bassoon, muted brass, lift-music (hold music) electric piano drifting in and out, echoing hallway reverb, bureaucratic-gothic, funny not frightening, seamless loop* |
| 4 | `mus_paris_boss_chamber.ogg` | Boss chamber before the fight | 45-60 s | *Tense, quiet build, 70 BPM, D minor, low sustained strings, slow ticking clock, a single distant stamp thud every 4 bars, pompous and absurd, minimal, seamless loop* (the fight itself is beatbox) |
| 5 | `mus_paris_liberated.ogg` | Every Paris map after the boss | 60-90 s | *The cosy Paris town theme in full bloom, 104 BPM, F major, warm strings, clarinet melody, light percussion, sunny relief, a little wry, not triumphant, seamless loop* |
| 6 | `mus_camp_cafe.ogg` | Camp (the café at night) | 60 s | *Intimate late-night café, 76 BPM, Bb major, solo nylon guitar and soft upright bass, a little vibraphone, warm, loose, funny-sweet, seamless loop* |
| 7 | `mus_title.ogg` | Title screen | 60-90 s | *Bold comedic JRPG overture, 112 BPM, C major, brass fanfare opening, strings and snare march with a beatbox groove underneath, adventurous and tongue-in-cheek, seamless loop after an 8-bar intro* |
| 8 | `mus_chapter_end.ogg` | Chapter 1 ending / credits | 90-120 s, no loop | *Gentle wry ending theme, 96 BPM, F major, the town melody on solo clarinet over strings, warm, a little bittersweet, ends on a soft held chord* |

### 2.2 Stings (OGG, stereo, -14 LUFS, no loop)

| File (`assets/audio/stings/`) | Length | Prompt / direction |
|---|---|---|
| `stg_victory.ogg` | 2-3 s | *Short triumphant comedic JRPG victory fanfare, brass and snare, ends on a bright major chord.* Plays where the beat cuts dead on the last knockout |
| `stg_victory_boss.ogg` | 3-4 s | A bigger version of the same fanfare |
| `stg_defeat.ogg` | 2 s | *Wry, gentle "wah-wah" defeat sting, muted trombone, ends on a soft rubber-stamp thud.* Brief, never cruel |
| `stg_level_up.ogg` | 1.5 s | *Short bright level-up chime, glockenspiel arpeggio* |
| `stg_chapter_clear.ogg` | 4 s | *Fanfare for finishing a chapter, warm brass* |
| `stg_liberation.ogg` | 1.5 s | Paper tear into a small warm swell (on-screen liberation; no crowd roar) |

### 2.3 Ambience beds (OGG, stereo, -26 LUFS, seamless, 60-120 s)

The first three ids already exist in `data/occupation_stages/ostage_bureaucratia_stage{1,2,3}.tres`.

| # | File (`assets/audio/ambience/`) | Where | Direction |
|---|---|---|---|
| 1 | `amb_paris_stage1.ogg` | Town; every liberated map | Paris street life: distant traffic, footsteps on cobbles, café cups and chatter (no clear words), pigeons, a bicycle bell |
| 2 | `amb_paris_stage2.ogg` | Overworld segment | Stage 1, thinner, plus office hum, distant typing, an occasional far-off stamp |
| 3 | `amb_paris_stage3.ogg` | The Ministry (dungeon) | Dense comic bureaucracy: fluorescent hum, typing pools, hold music leaking from a phone, gibberish PA announcements (made-up syllables, no real words), pneumatic tubes |
| 4 | `amb_boss_chamber.ogg` | Boss chamber (proposal) | Big empty office: slow wall clock, air conditioning, papers shuffling |
| 5 | `amb_camp_cafe.ogg` | Camp | Night café: soft room tone, a coffee machine hiss, a clock, a low hearth or radiator crackle |

---

## 3. PRIORITY 3: sound effects (WAV, 16-bit, 44.1 kHz, mono)

### 3.1 Ids the code already fires (`src/overworld/overworld_sfx.gd`, `OverworldSfx.ALL`)

| Event id | File (`assets/audio/sfx/overworld/`) | Sound | Visual twin |
|---|---|---|---|
| `notice` | `sfx_ow_notice.wav` | Pen click plus a polite "ahem" | "!" slip and notice pose |
| `chase` | `sfx_ow_chase.wav` (loopable, 2 s) | Hurried footsteps, paper rustle | Chase pose, paper trail |
| `stun` | `sfx_ow_stun.wav` | Dazed paper flutter | Orbiting form slips |
| `liberation` | `sfx_ow_liberation.wav` | Paper tear and scattered individual reactions (a pleased "ah", a grumble). Never a crowd roar | Posters coming down |
| `liberation_off_screen` | `sfx_ow_liberation_off.wav` | Short paper-tear sting | Payoff card "Street cleared" |
| `checkpoint_denied` | `sfx_ow_checkpoint_denied.wav` | **Stamp thunk**, Bureaucratia's signature sound, kept for rule moments | DENIED stamp |

### 3.2 UI (proposed ids; `assets/audio/sfx/ui/`)

| File | Sound |
|---|---|
| `sfx_ui_move.wav` | Soft paper tick (cursor move) |
| `sfx_ui_confirm.wav` | Small bright click-pop |
| `sfx_ui_cancel.wav` | Low soft pop |
| `sfx_ui_refused.wav` | The "soft tick" for an early or refused press (`src/ui/ui_feedback.gd`); quieter than move |
| `sfx_ui_menu_open.wav`, `sfx_ui_menu_close.wav` | Paper slide in / out |
| `sfx_ui_text_blip.wav` | Dialogue text blip for humans (short, pitched) |
| `sfx_ui_text_blip_alien.wav` | A tiny beatbox "ts/k" blip for alien speakers (proposal; GDD OQ-3 is open) |
| `sfx_ui_prompt_pop.wav` | The interact pip appearing |
| `sfx_ui_save.wav` | Save confirmed |

### 3.3 Overworld (proposed; `assets/audio/sfx/overworld/`)

| File | Sound |
|---|---|
| `sfx_ow_step_cobble_{1..4}.wav` | Footsteps on cobbles (4 variations) |
| `sfx_ow_step_marble_{1..4}.wav`, `sfx_ow_step_carpet_{1..4}.wav` | Ministry floors |
| `sfx_ow_map_exit.wav` | Soft whoosh under the fade |
| `sfx_ow_checkpoint_open.wav` | Stamp thunk "APPROVED", boom lift creak, tape snap |
| `sfx_ow_ticket_take.wav` | Ticket dispenser pull and "ding" (Permit Counter, "Take a number.") |
| `sfx_ow_gag_cabinet.wav` | Filing cabinet tipping over, paper avalanche |
| `sfx_ow_gag_stamps.wav` | A rack of rubber stamps clattering |
| `sfx_ow_gag_poster.wav` | Poster tear-down |
| `sfx_ow_door_locked.wav` | Rattled locked door |
| `sfx_ow_camp_rest.wav` | Cup on saucer, contented sigh (rest jingle can be `stg_level_up`-style) |
| `sfx_ow_beacon.wav` | Very soft lantern shimmer (optional) |

### 3.4 Battle (proposed; `assets/audio/sfx/battle/`)

| File | Used by |
|---|---|
| `sfx_bt_wipe_bureaucratia.wav`, `sfx_bt_wipe_megacorp.wav` | The battle-start wipe (stamp slam / glass slice) |
| `sfx_bt_hit.wav`, `sfx_bt_hit_heavy.wav`, `sfx_bt_crit.wav` | Generic impacts (chalk-white impact burst) |
| `sfx_bt_defend.wav` | Brace |
| `sfx_bt_ko_squad.wav`, `sfx_bt_ko_enemy.wav` | Knockout slump (comic) |
| `sfx_bt_heal.wav` | Heal chime (Appetizer, Family Meal) |
| `sfx_bt_buff.wav`, `sfx_bt_debuff.wav` | Rising / draining |
| `sfx_bt_stun.wav` | Speak to the Manager: an outraged "excuse me?!" stab (non-verbal is fine), then stun stars |
| `sfx_bt_home_run.wav` | Home Run: baguette crunch plus a bat crack |
| `sfx_bt_viral.wav` | Viral Stunt: phone shutter, whoosh, a swell of "likes" pops |
| `sfx_bt_steam.wav` | Family Meal steam puff and cloche lift |
| `sfx_bt_pen_jab.wav`, `sfx_bt_red_tape.wav`, `sfx_bt_late_fee.wav` | Clerk and Supervisor attacks (pen click-stab, tape rip, cash-drawer clunk) |
| `sfx_bt_mass_audit.wav`, `sfx_bt_final_notice.wav` | Supervisor specials (paper storm; giant stamp slam) |
| `sfx_bt_permit_arrived.wav` | The Permit Ban lifts (round 4 "all-out war" banner): a big APPROVED stamp |
| `sfx_bt_laser_scan.wav`, `sfx_bt_upsell.wav`, `sfx_bt_layoffs.wav`, `sfx_bt_hostile_takeover.wav` | MegaCorp moves (laser sweep, tablet swipe, pink-slip flutter, pen slash) |
| `sfx_bt_megacorp_bill.wav` | MegaCorp billing each round: receipt printer chatter |
| `sfx_bt_goo.wav` | "Finish him off": a wet comic splat into purple goo |
| `sfx_bt_spare.wav` | "Let him go": scuttling footsteps and muttering paper |
| `sfx_bt_xp_tick.wav`, `sfx_bt_money.wav` | Results screen counters |

### 3.5 Voice (optional; decide in writing.md D-15)

| File | Note |
|---|---|
| `vo_cry_<hero>.wav` x4 | The battle cry "Go back to your planet!" shouted by each squad member, timed into the one silent bar. Only if you want voice. Text-only works without it |

---

## 4. Later

| Item | Note |
|---|---|
| MegaCorp beatbox kit | Proposed roles: Security Drone hats/fx (laser zaps, servo whirrs), Middle Manager bass/snare (server-hum bass, swipe snare), CEO lead hook (a smug chant, e.g. "Growth. Growth. GROWTH."). Kick = elevator "ding-thunk". Avoid notification pings (those belong to Influencia). Tiers from Chapter 2's base tier, 2-4 |
| Rat Catchers band mode | Human bounty-hunter fights: one composed track per tier, *scrappy distorted guitar and bass, live drum kit, outlaw harmonica or whistle motif*, plainer than the beatbox. `assets/audio/music/mus_battle_ratcatchers_t{1..3}.ogg`, same exact 8-bar lengths as section 1 |
| Rain or night variants of the ambience | Not designed |

## 5. Priority order (one line each)

1. Beatbox tier 1 (stems 1-6, `bx_bur_intro`, the tier 1 tails) plus `stg_victory` and `stg_defeat`: every street fight then has its score.
2. UI basics: move, confirm, cancel, refused.
3. The six code-fired overworld SFX (3.1).
4. `mus_paris_town`, `amb_paris_stage1`, `mus_camp_cafe`.
5. Beatbox tiers 2 and 3 (Permit Counter and Supervisor).
6. The other overworld music and ambience beds, `mus_title`.
7. Battle SFX (3.4), then the rest of the overworld SFX (3.3).
8. Section 4.
