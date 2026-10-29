# Game Concept: Go back to your planet!

*Created: 2026-10-12*
*Status: Draft*

---

## Elevator Pitch

> It's a satirical turn-based RPG where you recruit a squad of humanity's worst
> possible heroes to outwit alien civilizations whose absurd ideologies rewrite
> the rules of every battle — and decide which factions, human or alien, you
> help or betray along the way.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Turn-based JRPG (Dragon Quest lineage) + party-based satire RPG |
| **Platform** | PC (Steam / Epic) |
| **Target Audience** | Story/discovery players who love satirical comedy (see Target Player Profile) |
| **Player Count** | Single-player |
| **Session Length** | 30–60 min (one region chapter) |
| **Monetization** | Premium (none decided yet) |
| **Estimated Scope** | Medium–Large (8–10 months, solo, first game); MVP ~6 weeks |
| **Comparable Titles** | South Park: The Stick of Truth, Dragon Quest XI, Mass Effect 2 (squad/loyalty structure) |

---

## Core Fantasy

You assemble the most ridiculous resistance squad on Earth — a baguette
thrower, a Five-Star Chef, Karen, Florida Man — and turn their worst traits into
the exact weapons needed to beat alien civilizations at their own absurd games.
The promise: being the one person clever enough to see through every
ideology's nonsense, and laughing at all of them on the way.

---

## Unique Hook

Like Dragon Quest, **and also** every enemy faction's satire *is* a combat rule
set — Bureaucratia bans special moves for both sides until the permit comes
through after round 3 (the *Permit Ban*), Influencia
enemies grow stronger the more attention you give them, MegaCorp bills you per
turn. Your misfit squad's quirk combos are how you break those rules: the joke
is the mechanic, and the punchline is figuring it out.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** (sensory pleasure) | 5 | Chunky, exaggerated battle animations and punchy impact feedback on combos |
| **Fantasy** (make-believe, role-playing) | 4 | Leading a misfit resistance on an alien-settled Earth |
| **Narrative** (drama, story arc) | 2 | Region chapters, faction storylines, recruit loyalty arcs, 2–3 endings |
| **Challenge** (obstacle course, mastery) | 6 | Cracking each faction's rule; light-to-moderate tactical difficulty |
| **Fellowship** (social connection) | 3 | Party banter and loyalty arcs (companion fellowship, not multiplayer) |
| **Discovery** (exploration, secrets) | 1 | Finding the next joke, the next faction rule, the next combo |
| **Expression** (self-expression, creativity) | 7 | Squad composition and faction allegiance |
| **Submission** (relaxation, comfort zone) | N/A | Not a goal — no grind loops |

### Key Dynamics (Emergent player behaviors)

- Players experiment with squad pairings to find quirk combos ("what would Chef + Florida Man do?").
- Players try to "read" each new faction's rule within the first turn, then exploit it.
- Players share discovered combos and their punchlines as clips and memes.
- Players replay or reload choices to see what the other faction would have offered.

### Core Mechanics (Systems we build)

1. **Turn-based party combat** with a third-person battle camera and DQ-style command menus.
2. **Quirk states & combos** — character moves apply comedic states (*Complained*, *Unionized*, *Gone Viral*, *Notarized*) that teammates cash in for named combos, logged in a **Combo Codex**.
3. **Faction rule sets** — each alien civilization modifies combat rules in a telegraphed way.
4. **Squad recruitment & loyalty** — Mass Effect-style roster; pick an active party at camp; loyalty quests unlock signature quirks.
5. **Faction reputation** — after each alien boss, finish him (human street cred) or let him go (alien points); reputation changes prices, recruit likelihood, who hunts you and the ending, never battle rules. Human (bounty-hunter) bosses and ordinary fights get no prompt.

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** | Choose your squad, and choose which factions to help or betray | Supporting |
| **Competence** | Cracking faction rules and discovering combos; Codex fills up visibly | Core |
| **Relatedness** | Party banter, loyalty arcs, misfits who become genuinely great | Core |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Explorers** — How: discovering faction rules, hidden combos, and every joke in every town (primary).
- [x] **Achievers** — How: completing the Combo Codex, recruiting the full roster, seeing every ending (secondary).
- [ ] **Socializers** — Light: shareable moments only; no multiplayer.
- [ ] **Killers/Competitors** — Not served.

### Flow State Design

- **Onboarding curve**: First 10 minutes in occupied Paris — one recruit, one obvious state (*Complained*), one obvious combo, then the first Bureaucratia enemy whose *Permit Ban* rule is shown on-screen.
- **Difficulty scaling**: New factions introduce new rules rather than bigger numbers; later fights layer two rules or demand specific combos.
- **Feedback clarity**: Every state is iconified on the target; every combo fires a named punchline + animation and a "New Combo!" Codex entry.
- **Recovery from failure**: Retry from the start of the battle instantly; losing teaches the faction's rule rather than punishing.

---

## Core Loop

### Moment-to-Moment (30 seconds)
Pick each squad member's action from a third-person DQ-style menu. Quirk moves
apply comedic states; teammates cash them in for combos while the faction's rule
bends the fight (e.g., no special moves for anyone until the permit arrives). The
satisfaction is the "aha" of a synergy landing, paid off with a named punchline.

### Short-Term (5-15 minutes)
Overworld travel → battle → discover or reuse a combo → log it in the Combo Codex
→ swap squad members at camp to test new pairings.

### Session-Level (30-120 minutes)
One region chapter: arrive in an occupied town → meet human and alien factions →
do a job for one side (reputation) → recruit (or lose) a misfit → dungeon →
faction boss. Natural stopping points: camps and boss clears.

### Long-Term Progression
DQ-style squad levels; loyalty quests that unlock each misfit's signature quirk;
a filling Combo Codex; reputation steering toward one of 2–3 endings. The game is
"done" when Earth is reclaimed — on whichever faction's terms you chose.

### Retention Hooks
- **Curiosity**: The next faction's rule set; untried squad pairings; the other side of a choice.
- **Investment**: Recruits you've built loyalty with; a half-filled Codex.
- **Social**: Shareable combo punchlines and satirical moments.
- **Mastery**: Beating a faction's rule more elegantly; finding the "intended" absurd solution.

---

## Game Pillars

### Pillar 1: The Joke Is the Mechanic
Every gag must do something in play.

*Design test*: If we're debating between a funny cutscene and a funny ability, we choose the ability.

### Pillar 2: Nobody Is Right
Every faction — human or alien — is ridiculous, and every faction has a point.

*Design test*: If a choice has an obviously "good" side, rewrite it until it doesn't.

### Pillar 3: Misfits Make the Combo
Squad members are weak alone and strong together.

*Design test*: If we're debating between buffing one character and adding a cross-character synergy, we choose the synergy.

### Pillar 4: Readable in One Turn
A new player understands any fight's rules within one turn.

*Design test*: If we're debating between a clever hidden rule and a telegraphed one, we choose telegraphed. (Tension with Pillar 1 is deliberate: surprise lives in the punchline, never in the rules.)

### Anti-Pillars (What This Game Is NOT)

- **NOT Fallout-scale branching**: Choices change recruits, dialogue and endings — not whole questlines. Full branching would break Readable in One Turn's simplicity and the first-game scope.
- **NOT punching down**: Satire targets institutions, ideologies and behaviors, never identities or protected groups. Punching down would betray Nobody Is Right.
- **NOT a gear-grind power curve**: Power comes from synergy, not loot. A loot treadmill would undercut Misfits Make the Combo.
- **NOT real-time action or multiplayer**: Different game, different scope.

---

## Visual Identity Anchor

> **Superseded by the art bible.** `design/art/art-bible.md` (Sections 1–4) is the
> authoritative visual direction. This summary is kept in sync with it.

**Direction: Pixel Sprites in a Lit 3D Diorama** ("the Dave the Diver team making a Dragon Quest game"), revised 2026-10-13 from the original low-poly "Chunky Diorama" anchor.

**Visual rule**: *Paint the rules in light and color; tell the jokes in pixels; and never let one hide the other.*

**Supporting principles** (full text and design tests in the art bible):
1. **The Silhouette Is the Punchline**: one oversized prop and one pose per archetype; detail goes into reaction frames.
2. **The Diorama Is the Stage; the Sprites Are the Actors**: calm low-poly toy sets; sprites own the highest contrast.
3. **Every Faction Owns One Color, and That Color Means Its Rule**: Bureaucratia Stamp Red, Influencia Feed Magenta, MegaCorp Terminal Cyan, Liberty-7 Anthem Blue; each also owns a base shape (square, circle, wedge, star).

**Color philosophy**: Flat navy-and-cream Dragon Quest UI; warm storybook key light; faction color means "a rule", never "a result"; Coin Gold for rewards only; no information carried by color alone.

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Dragon Quest XI | Classic turn-based menus, overworld travel, readable fights | Third-person battle camera; faction rules bend combat | Proves simple turn-based combat sustains a long RPG |
| South Park: The Stick of Truth | Satire delivered through RPG systems | Original world; every faction satirized equally | Validates satirical turn-based RPG audience |
| Mass Effect 2 | Recruitable squad, loyalty missions, party banter | Comedic misfits instead of heroic specialists | Proves squad-building drives attachment |
| Undertale | The joke as the mechanic; subverted expectations in combat | 3D, party-based, political satire | Shows mechanical comedy is memorable and shareable |
| Fallout / Skyrim | "Be who you want" faction allegiance | Light reputation only, 2–3 endings | Your own favorite feeling, scaled to first-game scope |

**Non-game inspirations**: South Park (nobody is right), Helldivers' propaganda satire, Dave the Diver's charm, real-world news cycles and institutional absurdity.

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 18–35 |
| **Gaming experience** | Mid-core |
| **Time availability** | 30–60 minute sessions on weeknights, longer on weekends |
| **Platform preference** | PC (Steam) |
| **Current games they play** | South Park RPGs, Dota/Fallout/Skyrim, Helldivers 2 |
| **What they're looking for** | Smart, topical satire they can *play*, not just watch |
| **What would turn them away** | Grind walls, preachy one-sided politics, opaque combat rules |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Undecided — run `/setup-engine` (prior brief used Godot 4 + GDScript; PC target) |
| **Key Technical Challenges** | Data-driven quirk-state/combo system; per-faction rule modifiers on a shared combat core; third-person battle camera staging |
| **Art Style** | Pixel-art sprite characters (~48–64 px) in lit low-poly 3D dioramas (HD-2D family; Godot `Sprite3D`/`AnimatedSprite3D`). See `design/art/art-bible.md` |
| **Art Pipeline Complexity** | Medium. No character rigging; each character is a sprite sheet. Environments are simple low-poly blockouts. Cost drivers are frame-by-frame reaction animation and sprite facings (a fixed battle-camera arc keeps it to ~2 facings) |
| **Audio Needs** | Moderate — comedic SFX, no fight BGM (layered beatbox stems, one per alien enemy; needs an audio GDD), optional barks |
| **Networking** | None |
| **Content Volume** | Full vision: 4 regions, 4 alien factions, ~10 recruits, 2–3 endings, ~8–10 hours |
| **Procedural Systems** | None |

---

## Risks and Open Questions

### Design Risks
- Combos may be fun to *watch* but shallow to *choose* — tactical depth unproven.
- Satire-as-rules could become confusing when two rules stack (Pillar 4 pressure).

### Technical Risks
- Frame-by-frame sprite animation volume (reaction frames × facings × roster) is the main art cost for a first-time developer; mixing pixel scales would make the HD-2D look cheap.
- Faction rule modifiers could tangle the combat core if not data-driven from day one.

### Market Risks
- Storefront and platform tolerance for edgy political satire; content must stay on the right side of "no punching down."
- Satire tied to real events may date quickly.

### Scope Risks
- Writing volume: banter and loyalty arcs grow with every recruit.
- Full vision (8–10 months solo) exceeds a "months" first-game timeline; MVP and vertical slice are the real commitment.

### Open Questions
- Is choosing combos genuinely fun? — answer with a `/prototype` of one Bureaucratia fight with 3–4 recruits.
- How many quirk states can a player track at once? — test in the same prototype (start with 4).
- Which engine? — `/setup-engine`.

---

## MVP Definition

**Core hypothesis**: Players find cracking a faction's rule with misfit quirk combos both fun and funny across a 45–60 minute chapter.

**Required for MVP**:
1. Turn-based party combat with third-person camera and command menus.
2. Quirk states and ~8 combos, with a Combo Codex.
3. One faction rule set: Bureaucratia (the *Permit Ban*: no special moves until round 4).
4. One region: occupied Paris — town, overworld segment, one dungeon.
5. 4 recruits (e.g., Baguette Thrower, Five-Star Chef, Karen, Florida Man), ~8 enemy types, one boss (the Supervisor).
6. The boss spare-or-finish prompt and the two meters (human street cred, alien points); price and recruit hooks may follow.

**Explicitly NOT in MVP** (defer to later):
- Additional factions (Influencia, Liberty-7, MegaCorp) and regions.
- Loyalty quests and multiple endings.
- Final art pass, voice, full soundtrack.
- Loot farming / rare drops.

### Scope Tiers (if budget/time shrinks)

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | Paris, Bureaucratia, 4 recruits, 1 boss | Core combat + combos + boss spare/finish prompt and two meters | ~6 weeks |
| **Vertical Slice** | Paris polished, 6 recruits | + art pass, 1 loyalty quest, banter | +6 weeks |
| **Alpha** | 4 regions / 4 factions, placeholder art | All features, rough | +3 months |
| **Full Vision** | ~10 recruits, 2–3 endings, ~8–10 hrs | All features, polished | ~8–10 months total |

---

## Next Steps

- [ ] Configure the engine (`/setup-engine`)
- [ ] **Prototype core idea** (`/prototype quirk-combos`) — one Bureaucratia fight, 3–4 recruits
- [ ] If prototype PROCEEDS: create the art bible (`/art-bible`), then decompose into systems (`/map-systems`)
- [ ] Design each system (`/design-system [system-name]`) — use prototype learnings in Tuning Knobs and Formulas
- [ ] Review all GDDs (`/review-all-gdds`) and gate (`/gate-check`)
- [ ] Build vertical slice in Pre-Production (`/vertical-slice`)
- [ ] Plan first milestone (`/sprint-plan new`)
