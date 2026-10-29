# Narrative Requests — what the story needs from you

> **Status**: Open — waiting on the user's answers
> **Created**: 2026-10-29
> **Owner of the answers**: the user (creative authority); `narrative-director` turns them into the narrative bible
> **Companion to**: `design/art/asset-list.md` (the same idea, for art)

## 0. How this works

**What I generate automatically during the build.** Once the decisions in §2 are settled, the `writer` agent drafts every line and the `narrative-director` agent checks it against the guardrails. That covers:
- civilian lines and barks;
- decree-gag texts and clue texts;
- the story encounter's lines;
- recruit remarks;
- the boss-chamber and post-battle story Dialogue;
- liberated-set reactions;
- battle banter;
- item and move descriptions.

You do not need to write any of it.

**What needs you.** The story *decisions*: premise, characters' voices, the boss, the one big choice, and limits. These shape everything else. A machine-guessed premise would make every later line carry the guess.

**You can skip any question.** Each one below has a **Default if unanswered**. If you don't answer, I build with the default and mark it `DEFAULT — not user-approved` in the narrative bible, so it is easy to find and change later. Answer as briefly as you like: "A", "default", or a sentence in your own words.

**Sign-off.** The overworld design (rule 18) says no story text ships until it passes a tone checklist, recorded in `design/gdd/reviews/overworld-narrative-signoff.md`. The agents run the checks. Approving the final record is yours.

## 1. Already decided — no need to answer

| Fact | Source |
|---|---|
| Satirical, Dragon Quest-style RPG; humanity's worst possible heroes vs. alien factions whose ideologies are combat rules | `design/gdd/game-concept.md` (pitch, hook) |
| Pillar 2, **Nobody Is Right**: every side, humans and aliens alike, gets mocked | `game-concept.md` Pillars |
| The squad: Karen, Michelin Chef, Florida Man, Baguette Thrower | `game-concept.md` MVP; `data/characters/` |
| First region: occupied Paris (town → overworld segment → dungeon → boss chamber); first faction: Bureaucratia (forms, stamps, permits) | `game-concept.md` MVP; Overworld GDD |
| Tone guardrails: no WWII-occupation or immigration/border allegory, no "papers, please", no "resistance"/"collaborator" words, no badges/armbands, and the rest of the list | Overworld GDD, Fantasy guardrails 1–6 |
| Paris story flags: `permits_mandatory`, `counter_cleared`, `form_27b_stamped`, `paris_liberated` | Overworld GDD rule 18 registry |
| Locals who join the occupation are **enthusiastic adopters** (form hobbyists, people who queue for fun), played for comedy | Overworld GDD guardrail 6 |
| No street civilian says "go back" or "your planet"; the title's joke belongs to the story itself | Overworld GDD guardrail 6 (OQ-21) |

## 2. Decisions needed from you

### N-1. The premise: how did the aliens take Earth?
The opening needs one sentence of backstory.
- **A.** They didn't invade. They *won a tender*: Earth outsourced its governments to the lowest bidder.
- **B.** A cosmic misunderstanding: Earth's "please send help" radio message was read as a job ad, and every faction applied at once.
- **C.** Plain invasion. Militaries fell in an afternoon, because the aliens out-paperworked them.
- **D.** Your own idea.

**Default if unanswered: B.** It sets up "nobody is right" from the first line, and every faction has an equally silly claim to be there.

### N-2. Who is the player?
- **A.** A silent leader the player names, who recruits the four. Dragon Quest style.
- **B.** No separate leader: the player controls the squad as a group, and the squad member up front is the leader.
- **C.** One of the four is the protagonist (say which).

**Default if unanswered: A.** It fits the overworld design, which has a leader with three followers, and Dragon Quest.

### N-3. The title joke: "Go back to your planet!"
The overworld forbids civilians from saying it, so the story owns it. Who says it, and when?
- **A.** The squad's battle cry, played as cringe: the squad thinks it's heroic, and everyone else winces.
- **B.** Said once, at the very end, by a surprising character, flipping who "your planet" means.
- **C.** Only the title; never said in the game.
- **D.** Your own idea.

**Default if unanswered: B.** A single payoff keeps the joke from going stale and stays clear of the guardrails.

### N-4. Each squad member's voice and reason to join
One line each is enough: what they want, and their worst trait. Defaults, built from their kits:
- **Karen.** Wants to speak to the manager of the *universe*. Weaponised entitlement. Her special stuns, but not bosses, because "he *is* the manager".
- **Michelin Chef.** Wants the aliens' terrible food banned. Snob, perfectionist. Heals by force-feeding the squad.
- **Florida Man.** Wants to go viral. Fearless because he never thinks.
- **Baguette Thrower.** Defends Paris's honour. Overly proud, and a sports commentator in his own head.

**Default if unanswered: the four lines above.**

### N-5. The Paris boss: Minister of Forms, or the Supervisor?
**Conflict in the current files.** The game concept and the overworld design name the Paris boss the **Minister of Forms**. The built battle content (the prototype carried forward) uses the **Supervisor**.
- **A.** The Minister of Forms is the region boss, and the Supervisor is a mid-boss: the story encounter, the "Permit Counter".
- **B.** One character: rename the Supervisor to the Minister of Forms.
- **C.** Keep the Supervisor as the boss, and update the docs.

**Default if unanswered: A.** It matches the overworld design's two set-piece fights: the story encounter, then the boss.

### N-6. What does Bureaucratia get *right*?
Pillar 2, and rule 18 tick (b), require at least one place where the occupiers have a point.
- **A.** Their queues are genuinely fair: nobody cuts in.
- **B.** Their permits actually open shortcuts that make the city work better.
- **C.** Both.

**Default if unanswered: C.**

### N-7. The one big choice (MVP: a reputation choice that wins or loses one recruit)
- **A.** Help an enthusiastic adopter keep their beloved form-filing job after liberation, or expose them. One answer costs you the Chef, who despises bureaucracy, or Karen, who loves it.
- **B.** Take a forged permit shortcut, which is faster but makes the Baguette Thrower quit over his honour, or do it the long, legal way.
- **C.** Your own idea.

**Default if unanswered: B.** It is short, readable in one moment, and fits Pillar 4, Readable in One Turn.

### N-8. Limits and rating
- Profanity level: none / mild ("damn") / strong.
- Topics off-limits for jokes, beyond the guardrails already listed.
- Real-world brands, politicians or celebrities: never / parody only.

**Default if unanswered:** mild profanity, no extra topics, parody only with no real names.

### N-9. Language
- **A.** English only, with a little light French in Paris ("Bonjour", "Non!").
- **B.** English and French text at ship.

**Default if unanswered: A.** Localization is out of scope until the Localization epic exists (ADR-0013).

### N-10. How much dialogue?
- **A.** Dragon Quest-light: short lines, fast, mostly barks and one-liners.
- **B.** South Park-heavy: longer scenes, more banter between fights.

**Default if unanswered: A** for the overworld (the GDD's readability rules), with B-style scenes only for the story encounter, the boss and the ending.

## 3. What happens after you answer

1. `narrative-director` writes `design/narrative/narrative-bible.md` from your answers, with defaults marked.
2. The Dialogue, Banter & Quests system gets its design doc (`/design-system`, currently "Not Started").
3. The `writer` agent drafts the Paris content set for each stage (Contested, Occupied, Saturated), plus the story encounter, the boss and the liberation, as content records.
4. Each set runs the guardrail checklist. Results go to `design/gdd/reviews/overworld-narrative-signoff.md` for your final approval.

## 4. Your answers

*Write them here, or just tell me in the chat; I'll copy them in.*

| ID | Answer | Date |
|---|---|---|
| N-1 | | |
| N-2 | | |
| N-3 | | |
| N-4 | | |
| N-5 | | |
| N-6 | | |
| N-7 | | |
| N-8 | | |
| N-9 | | |
| N-10 | | |
