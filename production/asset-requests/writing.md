# Writing Request List: story, script and text

> Written 2026-11-04. Sources: `design/narrative/narrative-bible.md`, `design/narrative/narrative-requests.md` §4-5 (your rulings), `design/gdd/overworld-exploration-encounters.md` rules 13-18, the lines already in `data/maps/*.tscn`, `data/encounters/*.tres` and `src/`.

**How to use this**
1. You don't have to write the script. The `writer` agent drafts every line and the `narrative-director` checks it against your guardrails. You approve.
2. What only you can do is in **section 1: decisions**. Each has options and a default. Answer "D-3: B" or "default", in any order, in chat.
3. Section 2 is the full Chapter 1 script inventory, so you can see what exists, what Claude drafts and what waits on a decision.
4. Section 3 is everything else non-art, non-audio the game needs from you (title, credits, studio name, voice).
5. To start the drafting, tell Claude "draft the Paris script" (after answering, or leaving defaults). You get it back as data records plus one readable review page to approve.

**Legend:** **AUTO** = Claude drafts it, you approve. **YOU** = needs your input. **EXISTS** = already in the game (count verified). Every line: max **120 characters**; English with light French in Paris ("Bonjour", "Non!"); Dragon Quest-light (short lines, mostly one-liners; longer scenes only for the story fight, the boss and the ending).

**Your standing rulings (applied to every line):** strong profanity only by substitution ("frak"); heavy parody; macho humour lands on the speaker, never on women as a group; off limits: Nazi material, Jews and Jewish topics, religion, LGBTQ topics; no real brands, politicians or celebrities; no visa, border, deportation or "papers, please" language; no civilian ever says "go back" or "your planet" (only the squad's battle cry does).

---

## 1. Decisions only you can make

| ID | Decision | Options | Default if you don't answer |
|---|---|---|---|
| **D-1** | **The game's title.** Docs say *Go back to your planet!*; `project.godot` says *"Resistance Permit Denied"* | A. *Go back to your planet!* B. *Resistance Permit Denied* C. A as the title, B as Chapter 1's subtitle D. Your own | **C** (the title joke stays; the subtitle sells Paris) |
| **D-2** | **Squad voices (N-4)**: never approved, still the default | A. Approve the four in `narrative-bible.md` §3 (Karen: speak to the manager of the universe; Chef: ban the aliens' food; Florida Man: go viral; Baguette Thrower: Paris's honour, sports commentator in his head). B. Change one or more (one line each) | **A** |
| **D-3** | **Squad personal names.** Today they are titles only | A. Titles only (Karen, Five-Star Chef, Florida Man, Baguette Thrower). B. Titles plus a first name used in banter (e.g. Chef "Gaspard", Baguette Thrower "Didier"). C. Your names | **A** |
| **D-4** | **The alien cell (the player).** It has no portrait and no name in MVP | A. No name; messages end "— Head Office". B. A codename the squad uses, e.g. "The Committee". C. Your name. Voice: terse, slightly too formal, an alien who learned English from spy films | **A** |
| **D-5** | **How alien speech shows on screen (M-5).** Aliens talk in beatbox | A. Translated text, as now ("Take a number."). B. A beatbox caption first, then the text: *[bored boots-and-cats]* "Take a number." C. Captions only for barks, translated text for story scenes | **C** |
| **D-6** | **Is the 99% doom figure right? (M-1)**: the true answer behind the true ending | A. Honest but stale: never re-run, because re-running needs a form nobody filed (the proposal). B. Right, and the squad changes it. C. Your answer | **A** |
| **D-7** | **Chapter 2: which real city does MegaCorp occupy?** | A. London (the City). B. A US tech city (e.g. San Francisco). C. Sydney. D. Mexico City (the bible already mentions light Spanish there). E. Your pick | **A** (UK is in the art bible's region list; keep the US for Liberty-7) |
| **D-8** | **Ending outline.** You ruled: the human route is not a bad ending (the resistance hides and thrives); the true ending needs the alien side | A. Claude drafts a one-page outline of 2 endings + the true ending for your approval. B. You give 3-5 bullet points first | **A** |
| **D-9** | **Recruits beyond the four** (full vision ~10; the art bible mentions a kangaroo) | A. Claude proposes 6 candidates, one per future region, with kits. B. You list them | **A** |
| **D-10** | **The Rat Catchers in Chapter 1?** (human bounty hunters) | A. Not in Chapter 1; first seen in Chapter 2. B. One cameo in Paris (a poster or a single fight). C. A full optional fight with a leader | **A** |
| **D-11** | **The currency's name.** The results screen says "+N Money" | A. "Money". B. "Euros". C. A joke currency, e.g. "Stamps". D. Your name | **A** (works in every region) |
| **D-12** | **The profanity substitution list.** One shared list for every character | A. Claude drafts it (frak and similar invented words) for your OK. B. You list them | **A** |
| **D-13** | **Battle cry in boss and story fights?** Today it rolls in ~1 fight in 4 and is skipped in the authored story and boss fights | A. Keep it that way. B. Also an authored cry in the boss intro | **A** |
| **D-14** | **Alien barks on the overworld (GDD OQ-3):** do Clerks beatbox outside battle too? | A. Text only. B. A beatbox blip under the text | **B** (cheap; one SFX) |
| **D-15** | **Voice acting** | A. None (text only, beatbox aliens). B. Only the battle cry shout, 4 voices. C. Barks for all squad members | **A** |
| **D-16** | **Localization at ship** | A. English only, light French words in Paris. B. English + French text | **A** (your N-9 ruling) |
| **D-17** | **Reputation "only prices and recruits"** (bible X-2): reputation also decides who hunts you and the ending | A. Read "only" as "never battle rules" (the bible's reading). B. Prices and recruits only | **A** |
| **D-18** | **Place names.** Only "Rue des Tampons" exists | A. Claude invents all (Town district, the Ministry's name, 4-6 street names). B. You name the Town | **A** |
| **D-19** | **Sign-off.** Overworld rule 18: no story text ships before you approve the tone checklist record `design/gdd/reviews/overworld-narrative-signoff.md` (it doesn't exist yet) | Approve when Claude hands it over | Claude prepares it with the Paris draft |

---

## 2. Chapter 1 (Paris) script inventory

Counts are targets. "EXISTS" counts are what's in the files today. All of it is **AUTO** unless marked **YOU**.

### 2.1 Story scenes (B-style, longer)

| # | Scene | Where | Lines | Status | Waits on |
|---|---|---|---|---|---|
| 1 | **Opening**: the cell's briefing (ASI Great Filter, the 99%, why Paris), then the four squad intros | Before control, New Game | 12-18 | AUTO, none written | D-2, D-4, D-6 |
| 2 | Chapter title card | After the opening | 1 ("Chapter 1: ...") | AUTO | D-1, D-18 |
| 3 | **Permit Counter** opener (the squad really is skipping the queue: NOW SERVING 000 003 / YOUR NUMBER 4 812 117) | Dungeon first room | 4-6 | AUTO, not written. EXISTS: bark "Take a number.", fled line | D-5 |
| 4 | Permit Counter after the win | Same | 2-3 | AUTO | |
| 5 | **Supervisor** intro (Karen finally meets a manager, and he won't escalate her) | Boss chamber | 6-10 | AUTO | D-2, D-13 |
| 6 | Supervisor post-battle | After Victory | 1 EXISTS ("stamps his own resignation APPROVED, in triplicate...") + 2-3 | AUTO | |
| 7 | **Spare-or-finish** result lines | After the boss | 2 EXIST in code ("bursts into a pile of purple goo" / "scuttles off, muttering about paperwork"); **need narrative sign-off**. Add 1 squad reaction per choice per member (8) | AUTO | D-2 |
| 8 | Walk home: café owner's chapter-end bark | Town, near the café | 1 (GDD: "Sit down before you liberate anything else."), not in data yet | AUTO | |
| 9 | Chapter end scene at the café | After "End the chapter here?" | 8-12 | AUTO | D-8 |

### 2.2 Overworld text

| # | Item | Count needed | EXISTS today | Notes |
|---|---|---|---|---|
| 1 | Town NPC lines (stage 1) | 8-10 | 4 (woman and man in the queue, retired notary, café owner) | Each named NPC also needs a **liberated** line |
| 2 | Segment NPC lines (stage 2) | 6-8 | 2 (café regular "Union rules", street sweeper) | |
| 3 | Dungeon NPC lines (Ministry staff, adopters) | 3-5 | 0 | |
| 4 | Liberated reactions (mixed: some grumble, some quietly pleased; at least one ribs the squad) | 1 per named NPC + 6 generic | 0 dedicated | Pillar 2: no celebrating crowd |
| 5 | Proximity barks (`optional_teach` and others) | 4-6 | 1 (the café regular, doubles as his line) | |
| 6 | Gag, poster and decree texts | 14-18 | 11 (permit poster, 2 decrees "IN FORCE SINCE TUESDAY", queue poster, archive cabinet, ticket machine, stamp cupboard, take-a-number decree, 3 "tell" posters) | Each `line`/`clue` gag also wants an `alt_text` for repeat presses: 0 exist |
| 7 | Checkpoint failure lines | 4-5 | 3 (archive gate, staff stairs, stamp cupboard) + the redirect template "No %s? Back of the queue." | |
| 8 | Clerk barks: notice, give-up shrug, deflated Clerk on a liberated street | 3 sets x 3 variants | 0 | Shown as captions or text (D-5) |
| 9 | **Recruit remarks** (a squad member comments at a spot; MVP needs at least 3, one ribbing the squad) | 3-5 | 2 ids referenced (`remark_paris_stamp_cupboard`, `remark_paris_archive_courtyard`) but **no text exists** | |
| 10 | Payoff card lines ("Street cleared: Rue des Tampons") | 1 template + 4-6 street names | 1 street | D-18 |
| 11 | Map and area names (Town district, segment, the Ministry, boss chamber) | 4 | 0 | D-18 |
| 12 | Item and requirement names: "Form 27-B", "Permit to Approach the Counter" | 2 + descriptions | Names in the GDD only | The Items system is not designed yet |
| 13 | Tape sign | 1 | 1 ("FERMÉ POUR RESTRUCTURATION") | |

### 2.3 Battle text

| # | Item | Count | EXISTS | Notes |
|---|---|---|---|---|
| 1 | **Battle cry**: "Go back to your planet!" (fixed line) + who shouts it | 4 (one per squad member) | 0 | ~1 fight in 4; never in human or authored fights; never extended with border or visa words |
| 2 | Reactions to the cry (squad cringe, aliens unbothered) | 4 squad + 3 alien captions | 0 | The irony stays built in |
| 3 | Squad banter: battle start, special move, ally knocked out, low HP, victory | 5 triggers x 4 members x 2 variants = 40 | 0 | D-2 voices |
| 4 | Enemy captions / barks (Clerk, Supervisor; MegaCorp later) | 3-4 each | 0 | D-5 |
| 5 | Faction rule explanations | 2 Bureaucratia + 1 MegaCorp + 2 neutral | 5 EXIST in code | Review only |
| 6 | Move descriptions (one line each) | 14 moves | 0 (names only) | AUTO |
| 7 | Enemy descriptions (party/bestiary text) | 5 | 0 | Low priority |
| 8 | Character bios for the Party menu | 4 | 0 | D-2, D-3 |
| 9 | Results and level-up lines | templates | EXIST ("Victory!", "+N XP", "+N Money", "Karen reached level 2!") | D-11 |
| 10 | Defeat card text ("CLAIM DENIED"-style, neutral) + Retry / Retreat | 1 + 2 | Retry, Retreat EXIST; the card says "DEFEAT" | AUTO |

### 2.4 Camp, tutorial and UI

| # | Item | Count | EXISTS | Notes |
|---|---|---|---|---|
| 1 | Camp rest card | 1 | 1 ("Resting at camp. Everyone is back on their feet.") | |
| 2 | Camp/café banter scenes (squad at the table) | 2-3 short scenes, 4-6 lines each | 0 | Unlock as the chapter goes on |
| 3 | Tutorial hints: move, talk/interact, Clerks are optional, battle commands, the Permit Ban, flee, camp, save | 8-10 one-liners | 0 | Onboarding is not designed; prefer in-world (the café regular already teaches one) |
| 4 | Interact verbs ("[Confirm] Talk / Look / Rest / Take a ticket / Challenge / Check") | 6 | 6 EXIST | |
| 5 | Prompts: "Rest here?", "End the chapter here?", quit confirm | 3 | 3 EXIST | |
| 6 | Title screen, Pause menu, Settings labels + 6 comfort options with one-line descriptions (Faster battle animations, Speed up boss entrances, Screen Shake, Reduce Blur, Reduce Flashing, Reduce Motion) | ~20 | Buttons EXIST; descriptions 0 | AUTO |
| 7 | Content-error and save-error messages (player-facing) | 4-6 | Developer-worded | AUTO |

**Rough total to draft for Chapter 1:** ~230-280 short lines, of which ~40 exist.

---

## 3. Everything else the game needs from you

| ID | Item | What's needed | Default |
|---|---|---|---|
| O-1 | Title and logo text | D-1, plus a one-line tagline for the title screen and store page | Claude drafts 3 taglines |
| O-2 | Studio name | The name in the credits and on the store | **YOU** (no default) |
| O-3 | Credits | Your name(s) and roles; credits for any hired beatboxer, musician or artist; a line for AI tools if you want one; font and library licences (Godot's MIT notice is required) | Claude assembles the list; you supply names |
| O-4 | Legal check of names | "Karen" and "Florida Man" are meme labels, not people or brands; Michelin is already renamed. Confirm you're comfortable | Treated as fine |
| O-5 | Store page blurb, short and long | For itch.io or Steam later | AUTO when you need it |
| O-6 | Age rating stance | Strong (bleeped) profanity and crude humour: expect a Teen/PEGI 12-16 range | Decide before a store submission |
| O-7 | Localization later | If French or other languages come (D-16), all text is already kept translation-ready (named placeholders, no untranslatable idioms) | Nothing now |

---

## 4. Priority order (one line each)

1. Answer D-1, D-2, D-4, D-5 (they shape every line).
2. Claude drafts: the opening, the Permit Counter, the Supervisor, the spare/finish reactions, the chapter end.
3. Claude drafts: Town and segment NPC lines + liberated variants, recruit remarks, gag `alt_text`s.
4. Claude drafts: battle cry set, squad banter, move descriptions.
5. You approve the sign-off record (D-19).
6. Then D-7 to D-10 for Chapter 2 and the endings; O-2 and O-3 any time before a public build.
