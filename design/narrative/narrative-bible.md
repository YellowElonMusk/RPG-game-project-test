# Narrative Bible: Go back to your planet!

> **Status**: Draft v1, 2026-10-29
> **Owner**: `narrative-director` (this file); the user holds creative authority
> **Source of truth**: `design/narrative/narrative-requests.md` §4 (the user's answers, 2026-10-29) and §5 (expanded rules, conflicts C-1..C-6)
> **Also checked against**: `design/gdd/game-concept.md` (Pillars, Anti-Pillars, MVP); `design/gdd/overworld-exploration-encounters.md` (Fantasy guardrails 1-6, rules 13, 13a, 18); `design/gdd/faction-rule-modifiers.md` (Bureaucratia, the Permit Ban); `data/characters/*.tres`; `data/enemies/enemy_supervisor.tres`, `enemy_clerk.tres`; `data/faction_rules/rule_bureaucratia_permit.tres`

## 0. How to read this file

**Canon levels** (`.claude/rules/narrative.md`), on every lore entry:

| Level | Meaning |
|---|---|
| **Established** | The user said it (§4 answer), or a shipped/approved doc fixes it. Writers build on it. |
| **Provisional** | A narrative-director *Interpretation* or proposal that fills a gap. Usable now; the user can veto. |
| **Under Review** | A conflict or open question. Do not write content that depends on it until it is ruled. |

**DEFAULT — not user-approved** marks a §2 default the user did not answer (only N-4). Treat it as Provisional, and easy to swap.

**Mystery rule.** Every mystery gets a documented true answer, even if players never learn it (§1.4). True answers proposed here are Provisional or Under Review until the user rules.

---

## 1. Premise

### 1.1 The Great Filter is ASI — **Established** (N-1)
- The answer to the Fermi paradox: civilisations die at **artificial superintelligence**.
- An **alien alliance** saw Earth on the verge of ASI while humans still fight over Earth's finite resources, instead of reaching for the universe's unlimited living space, energy and resources.
- The alliance's judgment: **99%** that ASI either wipes humanity out, or leaves Earth and drops humanity back to feudal states.
- So they stepped in and took over. In their eyes, humanity is done for.

### 1.2 Every faction is a civilisation in symbiosis with its own AI — **Established** (N-1)
- Each alien faction grew socially and politically alongside its technology until it reached symbiosis with its own AI or ASI. They are the survivors of the filter.
- *Interpretation* — **Provisional**: each faction's **ideology is the shape of its symbiosis**, and that shape is its combat rule (Pillar 1). Bureaucratia survived because its AI acts only through procedure: nothing happens without a form, so nothing can run away. Its slowness is its safety mechanism (§4.2).

### 1.3 Pillar 2 still holds — **Established** (C-5)
The aliens are right about the danger, but condescending, slow and smug about the fix. Humans are wrong about plenty, but the aliens' fix is to run Earth for them. Both sides get mocked.

### 1.4 Mysteries and their true answers

| # | Mystery | True answer | Canon |
|---|---|---|---|
| M-1 | Is the 99% figure right? | *Proposed:* the figure is honest but **stale**. The alliance's ASIs computed it from pre-occupation Earth and never re-ran it, because re-running it needs a form nobody filed. Humanity's odds change once it is shown it can cooperate across species. The true ending (§6.6) is the alliance re-running the numbers with the squad's record as evidence. | Under Review |
| M-2 | Who is "the Illuminati"? | The player's hidden alien cell (§2). | Established |
| M-3 | Does the squad know its handler is alien? | *Proposed:* no. The squad thinks it works for a shadowy human elite, so its battle cry is directed by aliens. The reveal belongs to the late game, before the true ending. | Provisional |
| M-4 | Why does the cell love Earth? | *Proposed:* its members grew up on Earth's broadcast culture (food, sport, TV, bad decisions) and think a species this ridiculous is worth keeping. | Provisional |
| M-5 | How do players read alien speech if aliens beatbox (§7)? | *Proposed:* the audio is beatbox; dialogue boxes show the cell's translation as normal text. Existing lines such as the Clerk's "Take a number." stand as written. | Under Review |

---

## 2. The player — **Established** (N-2) unless marked

- The player is a **shadowy figure or organisation that people believe is the Illuminati**.
- It is really a **small group of aliens** who love Earth culture, believe humanity is worth saving, and are organising a resistance.
- *Interpretation* — **Provisional**: the cell is the **unseen handler**. It never appears on the map. It directs the squad through orders and briefings (delivery format belongs to the Dialogue, Banter & Quests GDD).
- **On the map, the front squad member is the leader** (N-2 mechanically = option B). The overworld's leader-plus-three-followers trail needs no change. — **Established** (consistent with overworld rule set and story 006).
- *Interpretation* — **Provisional**: the cell has no portrait and no name card in MVP. Its voice is terse and slightly too formal, the voice of an alien who learned English from spy films.

---

## 3. The squad's voices — **DEFAULT — not user-approved** (N-4)

Built from each kit in `data/characters/`. Every line a writer drafts for a squad member must match this table. All four must be fair game (overworld rule 16 tick (d); Pillar 2).

| Member | Kit (data) | Wants | Worst trait | Voice profile | Never |
|---|---|---|---|---|---|
| **Karen** | *Speak to the Manager*: stuns one enemy, not bosses ("he *is* the manager") | To speak to the manager of the *universe* | Weaponised entitlement | Clipped, imperative, escalating; demands and ultimatums; treats every alien as staff | Wins an argument on the merits; is ever polite first |
| **Five-Star Chef** *(renamed from Michelin Chef, user 2026-10-29, §9 X-5)* | *Appetizer* (heal one), *Family Meal* (heal party) | The aliens' terrible food banned | Snob, perfectionist | Theatrical disdain; kitchen-brigade orders; rates everything like a critic | Praises anything without a "but"; mocks a cuisine by its nationality |
| **Florida Man** | *Viral Stunt* | To go viral | Fearless because he never thinks | Run-on enthusiasm; headline-shaped boasts; narrates his own stunts for an audience that is not there | Plans ahead; hesitates |
| **Baguette Thrower** | *Home Run* | To defend Paris's honour | Overly proud | Grandiose; a sports commentator in his own head, calling his own throws; light French (§9) | Gets a joke *from being French* rather than from his pride (overworld guardrail 3) |

- Why they join: the cell recruits each by offering exactly what they want (*Provisional*).
- They do not know each other's wants are being exploited (*Provisional*; feeds M-3).

---

## 4. Bureaucratia in Paris

### 4.1 Faction core — **Established**
- Alien faction (`faction_bureaucratia`, kind `alien`), Stamp Red, square shape (art bible).
- Combat rule, as built: **the Permit Ban**. Specials are banned for both sides until the permit arrives in round 3; Bureaucratia hunkers down meanwhile and focuses anyone at half HP or lower (`faction-rule-modifiers.md`; `rule_bureaucratia_permit.tres`). See §9 X-1 for a wording conflict with older docs.
- Combat conditions carry **little story weight** (§6.1): the rule is a mechanic first.

### 4.2 What Bureaucratia gets right — **Established** (N-6 C: both)
- **Fair queues.** Nobody cuts in. They look slow as hell but are well organised, like Japanese society.
- **The metro point** (the user's own example): in Japan everyone queues to board the metro; in the West everyone rushes in. Rushing looks faster, but the orderly way fills the train more, and better.
- **Permits that make the city work.** Permits genuinely open shortcuts that improve the city.
- Overworld rule 18 tick (b) is satisfied by either kind of item. Existing examples to keep: the Permit Counter board (the squad really is skipping the queue), the queue-number machine someone keeps using after liberation.
- *Interpretation* — **Provisional**: this is also why Bureaucratia survived the filter (§1.2). Fair procedure is how it keeps its AI on a leash.

### 4.3 The Supervisor is the Paris boss — **Established** (N-5 C)
- The **Supervisor** (`enemy_supervisor`, `is_boss = true`; moves Pen Jab, Red Tape, Mass Audit, Final Notice) is the Paris region boss. The "Minister of Forms" is retired; see §10.
- Immune to Karen's stun: "he *is* the manager" (`is_manager()`). His story identity is that joke: Karen finally meets a manager, and he will not escalate her.
- The **Permit Counter** story encounter (overworld rule 13a) stays a Clerk fight. No mid-boss is added.

### 4.4 Locals — **Established** (overworld guardrails 3 and 6)
- Locals who join in are **enthusiastic adopters**: form hobbyists, people who queue for fun, queue-number collectors. Their eagerness only makes life harder for themselves. Comedy, never judgment, never enforcement on neighbours.
- Parisians game the system (forged *stamps*, stamp black market, counter-forms). Their jokes come from behaviour, never from being French.

---

## 5. The battle cry: "Go back to your planet!" — **Established** (N-3 A); closes OQ-21

- **Who:** the squad only. **Never** a street civilian, bark or overworld line (overworld guardrail 6 still holds, C-4).
- **When:** at the start of about **1 combat in 4**.
- **How it plays:** as cringe. The squad thinks it is heroic; everyone else winces.
- *Interpretation* — **Provisional**, rules that keep it from punching down:
  - it is never endorsed: no character agrees with it, and the narrative never rewards it;
  - the irony is built in: the squad shouting it is being directed by aliens (M-3);
  - it is never extended with visa, border, residency or deportation words (guardrail 6);
  - it is **not** used in bounty-hunter fights (the targets are human), and the story encounter and boss use authored openers instead of the random roll;
  - aliens answer it in beatbox and are unbothered.
- The rate (≈25%) is a tuning knob for the Dialogue, Banter & Quests GDD, not a fixed constant here.

---

## 6. Reputation: spare or finish the boss — **Established** (N-7 C, §5.1; boss-only per user 2026-10-29) unless marked

### 6.1 Combat conditions carry little story weight
Permit and faction combat conditions work like **Pokémon abilities**: they impose combat conditions or effects only. Writers do not build plot on them.

### 6.2 The boss choice — **Established** (user, 2026-10-29)
Asking after every fight would be tiresome, so the choice comes **only after a boss**, the way Diablo has you clear the mobs before the boss. Ordinary fights end with no prompt. When a boss is beaten, the player chooses:
- **Finish him off** → **human street cred**;
- **Let him go** → **alien points**.

*Interpretation* — **Provisional**: "finish" is shown cartoon-style (he poofs, flattens, or gets filed away), never as harm with victims (guardrail 2). Wording must avoid deportation/removal vocabulary (guardrail 6). See §9 X-3.

### 6.3 What reputation changes
- **How NPCs see you**: shop prices and how likely someone is to join you.
- **Never battle rules** (concept Core Mechanic 5 holds).
- *Interpretation* — **Provisional**: reputation also decides who hunts you (§6.5) and gates the true ending (§6.6), because the user's own §5.1 says so. "Only prices and recruits" is read as "only how NPCs treat you, never the rules of a fight". See §9 X-2.

### 6.4 Route curves
| Route | Early game | Late game |
|---|---|---|
| **Human-famous** (street cred) | Easier: more allies, cheaper prices | Harder: aliens retaliate harder; more professional alien **peacekeepers** |
| **Alien-friendly** (alien points) | Harder | Alien tech and alien allies |

Exact curves belong to the game-designer (Faction Reputation & Endings GDD).

### 6.5 Bounty hunters
- Not every enemy is an alien. **Human resistance bounty hunters** sometimes come after the squad, believing it is a treasonous rat.
- *Interpretation* — **Provisional**: their frequency rises with alien points.
- So the world has **two resistances**: the cell's (secret, alien-run) and the humans' (public, hunting the squad). Players should be able to tell them apart by name; see §9 X-4.

### 6.6 The true ending needs the alien side
Only by siding with the aliens can the squad later convince them that humanity deserves another chance and should not be wiped out (ties to M-1).

**The human route is not the bad ending** — **Established** (user, 2026-10-29). It drives the human resistance into hiding, but the resistance keeps thriving and the fight stays alive. That ending is about refusing to cooperate with the aliens, not about losing. This answers §9 X-6.

---

## 7. Beatbox aliens — **Established** (Bonus, §5.2) unless marked

- Aliens **speak in beatbox**.
- **Each alien supplies one type of beat.** The enemies on the field together make one beatbox track.
- **A harder fight gets a harder beat.** Late-game tracks are more complex.
- **Fights have no background music.** The aliens' beatbox is the score.
- References (Darude's "Sandstorm", the beatboxer Dharni) are **feel only**. Every track is original; nothing is copied or sampled.
- Narrative input for audio-director (theirs to decide): each alien's beat could echo its job, e.g. a Clerk's layer built on the stamp thunk already used for rule moments.
- **Open question — Under Review**: human bounty hunters do not beatbox. Proposed (*Interpretation*): ordinary battle music for those fights, which also makes them sound different. Needs the audio GDD (C-6).

---

## 8. Tone and limits — **Established** (N-8) unless marked

### 8.1 Rating and register
- **Strong profanity, bleeped by substitution**: "frak" for "fuck", and so on. *Provisional:* the writer keeps one shared substitution list, so every character uses the same fake words.
- **Heavy parody.**
- Tone reference, in the user's words: **Duke Nukem-style macho, sexist humour, played so it is obvious the game does not take itself seriously.** **Established** (user, 2026-10-29): the macho voice is the butt of the joke. It lands on the speaker, never on women as a group (Anti-Pillar: no punching down).
- **Real-world brands, politicians and celebrities: no**, unless the use is certain to be legally and publicly safe. Parody uses invented names.

### 8.2 Off-limits topics — **Established**
Jews; WWII; religion in general; LGBTQ topics. Nothing else is off limits by N-8 (but see 8.3).

### 8.3 The updated guardrail set (overworld guardrails reconciled with N-8 and C-1)

| # | Guardrail | Status | Canon |
|---|---|---|---|
| G-1 | Not a chore or a toll road (overworld guardrail 1) | Unchanged | Established |
| G-2 | No real oppression: no rubble, victims, cages or violence against humans; escalation is paperwork (guardrail 2) | Unchanged | Established |
| G-3 | Parisians neither helpless nor saintly; jokes from behaviour, not nationality (guardrail 3) | Unchanged | Established |
| G-4 | No set you only walk past (guardrail 4) | Unchanged | Established |
| G-5 | Readable without UI text (guardrail 5) | Unchanged | Established |
| G-6a | No WWII-occupation template: no 1944 liberation tableau, no secret meeting room, no banners on facades, no occupation-era notice layouts, no uniforms/insignia/salutes of real forces | Unchanged; now also required by N-8 (WWII) | Established |
| G-6b | No "papers, please"; forms and permits are processed, never people; identity documents never forged, checked or confiscated | Unchanged | Established |
| G-6c | No migrant/border template: no visa, residency, deportation, border or asylum vocabulary, either direction | Kept (user, 2026-10-29). N-8 does not lift it, and the title makes it the highest risk | Established |
| G-6d | Enthusiastic adopters, never shamed or punished; no one marked by anything worn | Unchanged | Established |
| G-6e | No food or ration queues | Unchanged | Established |
| G-6f | **"resistance" is now allowed** in player-facing text | **Changed** (C-1) | Established |
| G-6g | **"maquis" and "collaborator" stay banned** (WWII) | Unchanged | Established |
| G-6h | "underground" (as a movement) stays banned; C-1 did not lift it and it reads as WWII | *Interpretation* | Provisional |
| G-6i | No civilian says "go back", "your planet", or anything about where aliens came from; only the squad's battle cry (§5) | Unchanged; OQ-21 closed | Established |
| G-7 | Off-limits topics: Jews, WWII, religion, LGBTQ | New (N-8) | Established |
| G-8 | No real brands, politicians or celebrities unless certainly safe | New (N-8) | Established |
| G-9 | Profanity only through substitution words | New (N-8) | Established |
| G-10 | Macho/sexist humour must land on the speaker | New (user, 2026-10-29) | Established |

The composite test (overworld guardrail 6) and the rule 18 sign-off still apply to every set.

---

## 9. Language and density — **Established** (N-9 A widened; N-10 A)

- **English**, with light local flavour per region: light **French** in Paris ("Bonjour", "Non!"), light **Spanish** in Mexico, and the same for each other region.
- Flavour words are single, obvious words or short exclamations, readable without translation.
- **Dragon Quest-light**: short lines, fast, mostly barks and one-liners. *Provisional:* longer scenes only for the story encounter, the boss and the ending (the N-10 default text).
- **Every line ≤ 120 characters** (dialogue box limit, `.claude/rules/narrative.md`).
- Localization-ready: named placeholders for variables (`{rounds_left}`, not positional), no idioms that cannot be translated. Text is `LocText` (overworld rule 16; ADR-0013).

### 9.1 Contradictions found while writing this bible (new; not in C-1..C-6)

| # | Contradiction | Where | Proposed resolution |
|---|---|---|---|
| X-1 | Older docs describe Bureaucratia as "enemies ignore damage until *Approved*"; the built rule is the **Permit Ban** (no specials until round 3). The Paris clue poster ("UNAPPROVED INJURIES WILL NOT BE PROCESSED", the stamped-Clerk mime) teaches the old rule, so it would fail the rule 18 (e) comprehension check. | `game-concept.md` Unique Hook, MVP item 3; overworld rules 13a ("Approved rule"), 16 (clue wording) | Rewrite the hook and the clue to teach the Permit Ban. Needs user ruling + game-designer. |
| X-2 | N-7 says reputation "only" affects prices and recruits, but the same answer adds retaliation, peacekeepers, bounty hunters and the ending gate. The overworld GDD also lets reputation raise stages. | `narrative-requests.md` §5.1; overworld Interactions table (Faction Reputation row) | Read "only" as "never battle rules" (§6.3). User to confirm. |
| X-3 | "Finish them off" against guardrail 2 (no violence) and guardrail 6 (no removal vocabulary). Also: is there a spare/finish prompt after a **bounty-hunter** (human) fight? | §6.2; guardrails 2, 6 | **Partly resolved (user, 2026-10-29):** the prompt comes after bosses only, so ordinary bounty-hunter fights have none. Still open: the cartoon look of "finish", and whether a human boss gets the prompt. |
| X-4 | Two different "resistances" (the cell's, the bounty hunters') can confuse players. | §2, §6.5 | Give the human hunters a distinct invented group name. Writer to propose. |
| X-5 | **"Michelin" is a real brand** (tyres, guide); N-8 bars real brands unless certainly safe. | `char_michelin_chef.tres` `display_name`; concept; asset list | **Resolved (user, 2026-10-29):** rename to **Five-Star Chef**. The user does not consider "Michelin" a problem, but prefers the brand-free name. The `display_name` and the docs need the rename; the file id can stay. |
| X-6 | Pillar 2 design test: "if a choice has an obviously good side, rewrite it." Locking the true ending behind the alien side gives completionists an obvious side. | Concept Pillar 2; §6.6 | **Resolved (user, 2026-10-29):** the human ending is not a bad ending. The resistance is driven into hiding but keeps thriving, and the fight stays alive (§6.6). |
| X-7 | N-8 "sexist humour" against Anti-Pillar "NOT punching down: never identities or protected groups". | Concept Anti-Pillars; §8.1 | **Resolved (user, 2026-10-29):** G-10, the joke is on the macho speaker. No punching down. |
| X-8 | N-8 says nothing else is off limits; guardrail 6's migrant/border exclusion is not WWII, so N-8 could be read as lifting it. | Overworld guardrail 6; §8.3 G-6c | **Resolved (user, 2026-10-29):** keep the ban. |
| X-9 | The per-fight reputation reward makes optional street fights worth farming, against guardrail 1 ("no fights you have to farm"). | Guardrail 1; §6.2 | **Resolved:** the choice is boss-only (user, 2026-10-29), and bosses do not respawn, so there is nothing to farm. |
| X-10 | Spare/finish after the **boss**: ordering against rule 14 (flags, then story Dialogue, then walk home) is undefined. | Overworld rules 13, 14 | Define in Dialogue, Banter & Quests GDD. |

---

## 10. Doc changes owed (do NOT edit here; route through `/propagate-design-change`)

### `design/gdd/game-concept.md`
1. **MVP item 5** (line ~266): "one boss (the Minister of Forms)" → "one boss (the Supervisor)". (C-2)
2. **MVP item 6** (line ~267): "One reputation choice that wins or loses one recruit" → "The boss spare-or-finish prompt and the two meters (human street cred, alien points); price and recruit hooks may follow." (C-3)
3. **Core Mechanic 5** (line ~80): "story choices shift standing … changing recruits, dialogue and endings (not battle rules)" → "after each boss, finish him (human street cred) or let him go (alien points); reputation changes prices, recruit likelihood, who hunts you and the ending, never battle rules." (C-3)
4. **Scope Tiers table**, MVP row: "+ 1 choice" → "+ boss spare/finish prompt and two meters". (C-3)
7. **Michelin Chef → Five-Star Chef** everywhere, including `data/characters/char_michelin_chef.tres` `display_name` and `design/art/asset-list.md`. (X-5)
5. **Audio Needs** (Technical Considerations): "per-faction music themes" → "no fight BGM; layered beatbox stems, one per alien enemy". (C-6)
6. **Unique Hook / MVP item 3**: "*Approved* / forms" → the Permit Ban. (X-1, pending ruling)

### `design/gdd/overworld-exploration-encounters.md`
1. **Guardrail 6, word-list bullet** (line ~105): allow "resistance"; keep "maquis", "underground" and "collaborator" banned. (C-1)
2. **Guardrail 6, "go back" bullet** (line ~107) and **OQ-21** (line ~1389): mark resolved, pointing to this bible §5. (C-4)
3. **Rule 13** (line ~305): "The Minister of Forms" → "The Supervisor". (C-2)
4. **Rule 18 flag registry**, `paris_liberated` row (line ~395): "Minister of Forms defeated" → "Supervisor defeated". (C-2)
5. **Minimal MVP animation set** (line ~1010): "Minister of Forms (on map)" → "Supervisor (on map)". (C-2)
6. **Interactions table, Faction Reputation row** (line ~439) and **Dependencies** (line ~853): add the post-boss spare/finish prompt as a reputation input. (C-3)
7. **Rules 13a and 16** clue wording: re-teach the Permit Ban. (X-1, pending ruling)

### Other docs touched by C-3
- `design/gdd/systems-index.md` lines ~20, ~80, ~164: the "one choice that wins or loses one recruit" scope and "lose a recruit" wording → spare/finish meters and recruit likelihood.
- Audio: an audio GDD is needed before any fight sound work starts (C-6).
