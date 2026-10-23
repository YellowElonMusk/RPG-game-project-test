# Systems Index: Go back to your planet!

> **Status**: Draft
> **Created**: 2026-10-13
> **Last Updated**: 2026-10-21
> **Source Concept**: design/gdd/game-concept.md
> **TD-SYSTEM-BOUNDARY**: skipped — lean mode · **PR-SCOPE**: skipped — lean mode · **CD-SYSTEMS**: skipped — lean mode

---

## Overview

A satirical turn-based RPG: the player recruits a squad of mismatched "misfit" heroes and fights alien factions whose ideologies rewrite the rules of battle, while choices shift standing with human and alien factions. The mechanical scope is a classic Dragon Quest-style battle loop (Pillar 4, Readable in One Turn) extended with three bespoke layers: **quirk states** that characters apply to targets, **combos** that cash those states into named punchlines (Pillars 1 and 3), and **faction rule modifiers** that bend the battle rules per alien civilization (Pillars 1 and 2). Around it sit a small overworld, a camp for squad selection, recruitment and loyalty, and a light reputation system that selects recruits, dialogue and 2–3 endings. The 21 systems below are sized for a solo first-time developer: several are deliberately "lite" at MVP (Enemy AI uses scripted patterns, Reputation is one choice, Camp is a squad swap).

**Per-system notes (what each is for):**
- **Content Data Definitions** — characters, quirks, combos, enemies, factions and items as external data, not code; the bottleneck every other system reads.
- **Turn Battle System** — turn order, command menus, targeting, win/lose, instant retry; defines the hook contract the rule systems plug into.
- **Quirk State / Combo & Codex / Faction Rule Modifiers** — the game's identity; each one is a plug-in to Turn Battle through events.
- **Squad Roster, Camp, Leveling & Loyalty** — the Mass Effect-style misfit squad: who joins, who fights, how they grow.
- **Faction Reputation & Endings** — choices that change recruits and dialogue, not battle rules (anti-pillar: no Fallout-scale branching).
- **UI Framework** — one set of UI specs covering battle UI, menus, HUD, dialogue UI and accessibility, built to the art bible's shape and color grammar.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Game State & Scene Flow (inferred) | Core | MVP | Approved | design/gdd/game-state-scene-flow.md | Content Data Definitions, Input System |
| 2 | Input System (inferred) | Core | MVP | Approved | design/gdd/input-system.md | Content Data Definitions (soft — bindings data) |
| 3 | Content Data Definitions (inferred) | Core | MVP | Approved | design/gdd/content-data-definitions.md | — |
| 4 | Sprite & Camera Presentation (inferred) | Core | MVP | In Review | design/gdd/sprite-camera-presentation.md | Game State & Scene Flow, Content Data Definitions, Turn Battle System (hard, Battle only) |
| 5 | Turn Battle System | Gameplay | MVP | Reverse-Documented | design/gdd/turn-battle-system.md | Game State & Scene Flow, Input System, Content Data Definitions, Stats & Damage Resolution |
| 6 | Stats & Damage Resolution (inferred) | Gameplay | MVP | Designed | design/gdd/stats-damage-resolution.md | Content Data Definitions |
| 7 | Quirk State System | Gameplay | MVP | Not Started | — | Turn Battle System, Stats & Damage Resolution |
| 8 | Combo System & Codex | Gameplay | MVP | Not Started | — | Quirk State System, Turn Battle System, Stats & Damage Resolution |
| 9 | Faction Rule Modifiers | Gameplay | MVP | Reverse-Documented | design/gdd/faction-rule-modifiers.md | Turn Battle System, Quirk State System, Stats & Damage Resolution |
| 10 | Enemy AI (inferred) | Gameplay | MVP | Not Started | — | Turn Battle System, Stats & Damage Resolution, Faction Rule Modifiers |
| 11 | Overworld Exploration & Encounters | Gameplay | MVP | Approved | design/gdd/overworld-exploration-encounters.md | Game State & Scene Flow, Input System, Content Data Definitions, Sprite & Camera Presentation, Dialogue Banter & Quests |
| 12 | Squad Roster & Recruitment | Progression | MVP | Not Started | — | Content Data Definitions |
| 13 | Camp & Party Management | Progression | MVP | Not Started | — | Squad Roster & Recruitment, Game State & Scene Flow |
| 14 | Leveling & Loyalty | Progression | Vertical Slice | Not Started | — | Stats & Damage Resolution, Squad Roster & Recruitment, Dialogue Banter & Quests |
| 15 | Faction Reputation & Endings | Progression | MVP (lite) → Alpha (full) | Not Started | — | Squad Roster & Recruitment, Dialogue Banter & Quests |
| 16 | Items, Equipment & Shops (inferred) | Economy | Vertical Slice | Not Started | — | Content Data Definitions, Stats & Damage Resolution |
| 17 | Dialogue, Banter & Quests | Narrative | MVP | Not Started | — | Game State & Scene Flow, Input System, Content Data Definitions |
| 18 | UI Framework (battle UI, menus, HUD, dialogue UI, accessibility) (inferred) | UI | MVP (battle first) | Not Started | — | Input System, Sprite & Camera Presentation, Turn Battle System, Quirk State System, Combo System & Codex, Faction Rule Modifiers, Camp & Party Management, Items Equipment & Shops, Dialogue Banter & Quests, Stats & Damage Resolution |
| 19 | Save/Load & Settings (inferred) | Persistence | Vertical Slice | Not Started | — | Game State & Scene Flow, Content Data Definitions |
| 20 | Audio Manager (inferred) | Audio | Vertical Slice | Not Started | — | Game State & Scene Flow, Turn Battle System, Combo System & Codex, Faction Rule Modifiers, Overworld Exploration & Encounters |
| 21 | Onboarding & Tutorial (inferred) | Meta | Vertical Slice | Not Started | — | Turn Battle System, Quirk State System, Combo System & Codex, UI Framework |

> **UX flag — Stats & Damage Resolution:** has UI requirements (battle HUD, command menu, camp party screen, results screen). Run `/ux-design` for each before writing epics.

---

## Categories

| Category | Description | Systems |
|----------|-------------|---------|
| **Core** | Foundation systems everything depends on | Game State & Scene Flow, Input, Content Data Definitions, Sprite & Camera Presentation |
| **Gameplay** | The systems that make the game fun | Turn Battle, Stats & Damage, Quirk States, Combo & Codex, Faction Rule Modifiers, Enemy AI, Overworld |
| **Progression** | How the player grows over time | Squad Roster, Camp, Leveling & Loyalty, Faction Reputation & Endings |
| **Economy** | Resource creation and consumption | Items, Equipment & Shops |
| **Persistence** | Save state and continuity | Save/Load & Settings |
| **UI** | Player-facing information displays | UI Framework |
| **Audio** | Sound and music systems | Audio Manager |
| **Narrative** | Story and dialogue delivery | Dialogue, Banter & Quests |
| **Meta** | Systems outside the core game loop | Onboarding & Tutorial |

---

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP** | Required for the core loop to function. Without these, you can't test "is this fun?" | First playable prototype (Paris chapter, Bureaucratia, 4 recruits, 1 boss) | Design FIRST |
| **Vertical Slice** | Required for one complete, polished area. Demonstrates the full experience. | Vertical slice / demo | Design SECOND |
| **Alpha** | All features present in rough form. Complete mechanical scope, placeholder content OK. | Alpha milestone (4 regions / 4 factions) | Design THIRD |
| **Full Vision** | Polish, edge cases, nice-to-haves, and content-complete features. | Beta / Release | Design as needed |

**Scope note.** 16 MVP systems is heavy for a solo first-time developer's ~6-week MVP. Several are "lite" at MVP: Enemy AI (scripted patterns), Faction Reputation (one choice that wins or loses one recruit), Camp (squad swap only), UI Framework (battle UI first). If the MVP proves too large, cut in this order: Camp, Reputation, Enemy AI complexity.

**Alpha / Full Vision content (not new systems):** the rule sets for Influencia, MegaCorp and Liberty-7 reuse Faction Rule Modifiers; full multi-faction Reputation and Endings and the remaining accessibility options arrive at Alpha / Full Vision.

---

## Dependency Map

### Foundation Layer (no dependencies)

1. **Game State & Scene Flow** — moves between overworld, battle, camp and menus; foundational because every mode transition goes through it. *Depends on Content Data Definitions (boot waits for Ready) and Input System (it routes Input's actions); Input must not depend back on it (see its GDD).*
2. **Input System** — KB/M plus full gamepad and remapping; everything interactive reads it
3. **Content Data Definitions** — characters, quirks, combos, enemies, factions as data; the bottleneck (coding standard: gameplay values are data-driven)

### Core Layer (depends on foundation)

1. **Sprite & Camera Presentation** — depends on: Game State & Scene Flow, Content Data Definitions
2. **Stats & Damage Resolution** — depends on: Content Data Definitions
3. **Squad Roster & Recruitment** — depends on: Content Data Definitions
4. **Dialogue, Banter & Quests** — depends on: Game State & Scene Flow, Input System, Content Data Definitions
5. **Save/Load & Settings** — depends on: Game State & Scene Flow, Content Data Definitions (other systems register their own state with it)

### Feature Layer (depends on core)

Design order within this layer: Turn Battle first, then the systems that plug into it.

1. **Turn Battle System** — depends on: Game State & Scene Flow, Input System, Content Data Definitions, Stats & Damage Resolution
2. **Quirk State System** — depends on: Turn Battle System, Stats & Damage Resolution
3. **Combo System & Codex** — depends on: Quirk State System, Turn Battle System, Stats & Damage Resolution
4. **Faction Rule Modifiers** — depends on: Turn Battle System, Quirk State System, Stats & Damage Resolution
5. **Enemy AI** — depends on: Turn Battle System, Stats & Damage Resolution, Faction Rule Modifiers
6. **Overworld Exploration & Encounters** — depends on: Game State & Scene Flow, Input System, Content Data Definitions, Sprite & Camera Presentation, Dialogue Banter & Quests
7. **Camp & Party Management** — depends on: Squad Roster & Recruitment, Game State & Scene Flow
8. **Leveling & Loyalty** — depends on: Stats & Damage Resolution, Squad Roster & Recruitment, Dialogue Banter & Quests
9. **Faction Reputation & Endings** — depends on: Squad Roster & Recruitment, Dialogue Banter & Quests
10. **Items, Equipment & Shops** — depends on: Content Data Definitions, Stats & Damage Resolution

### Presentation Layer (depends on features)

1. **UI Framework** — depends on: Input System, Sprite & Camera Presentation, Turn Battle System, Quirk State System, Combo System & Codex, Faction Rule Modifiers, Camp & Party Management, Items Equipment & Shops, Dialogue Banter & Quests, Stats & Damage Resolution
2. **Audio Manager** — depends on: Game State & Scene Flow, Turn Battle System, Combo System & Codex, Faction Rule Modifiers, Overworld Exploration & Encounters

### Polish Layer (depends on everything)

1. **Onboarding & Tutorial** — depends on: Turn Battle System, Quirk State System, Combo System & Codex, UI Framework

**Bottleneck systems** (many depend on them; a mistake ripples everywhere): Content Data Definitions, Turn Battle System, Stats & Damage Resolution.
**Leaf systems** (nothing depends on them; can be designed late): Onboarding & Tutorial, Audio Manager, Faction Reputation's endings.

---

## Recommended Design Order

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | Content Data Definitions | MVP | Foundation | systems-designer, godot-specialist | M |
| 2 | Game State & Scene Flow | MVP | Foundation | game-designer, godot-specialist | S |
| 3 | Input System | MVP | Foundation | game-designer, ux-designer | S |
| 4 | Stats & Damage Resolution | MVP | Core | systems-designer | M |
| 5 | Sprite & Camera Presentation | MVP | Core | art-director, technical-artist | M |
| 6 | Squad Roster & Recruitment | MVP | Core | game-designer | M |
| 7 | Dialogue, Banter & Quests | MVP | Core | narrative-director, writer | M |
| 8 | Turn Battle System | MVP | Feature | game-designer, systems-designer | L |
| 9 | Quirk State System | MVP | Feature | systems-designer | M |
| 10 | Combo System & Codex | MVP | Feature | systems-designer | M |
| 11 | Faction Rule Modifiers | MVP | Feature | systems-designer | M |
| 12 | Enemy AI | MVP | Feature | game-designer, ai-programmer | M |
| 13 | Overworld Exploration & Encounters | MVP | Feature | level-designer | M |
| 14 | Camp & Party Management | MVP | Feature | game-designer | S |
| 15 | Faction Reputation & Endings | MVP (lite) → Alpha | Feature | narrative-director | M |
| 16 | UI Framework | MVP (battle first) | Presentation | ux-designer, art-director | L |
| 17 | Save/Load & Settings | Vertical Slice | Core | game-designer | M |
| 18 | Leveling & Loyalty | Vertical Slice | Feature | systems-designer, narrative-director | M |
| 19 | Items, Equipment & Shops | Vertical Slice | Feature | economy-designer | M |
| 20 | Audio Manager | Vertical Slice | Presentation | audio-director | S |
| 21 | Onboarding & Tutorial | Vertical Slice | Polish | ux-designer | S |

Effort: S = 1 session, M = 2–3 sessions, L = 4+ sessions (a session is one focused design conversation producing a complete GDD).

---

## Circular Dependencies

- **Turn Battle System ↔ Quirk State / Combo / Faction Rule Modifiers**: Battle needs the rules to run, and the rules run on Battle. *Resolution*: the Turn Battle GDD defines hook points (before turn, on damage, on state applied, on turn end); the rule systems plug into them through events, so Battle never depends on them.
- **Squad Roster ↔ Faction Reputation**: Reputation can make the player lose a recruit, and a recruit's presence changes what Reputation offers. *Resolution*: Roster exposes join/leave events; Reputation drives them; Roster never depends on Reputation.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| Turn Battle System (hook contract) | Design | The hook contract is the make-or-break design; a poor one tangles Quirk, Combo and Faction Rules | Design Turn Battle's hooks before the rule systems; keep the combat core data-driven from day one |
| Quirk State / Combo System | Design | Combos may be fun to watch but shallow to choose | `/prototype quirk-combos` (one Bureaucratia fight, 3–4 recruits) before the GDDs for these |
| Sprite & Camera Presentation | Technical | Mixed pixel scales and `Sprite3D` filtering/scaling in Godot 4.7 could make the HD-2D look cheap | Early technical test of one sprite in a lit 3D diorama at the shared pixels-per-unit; follow the art bible's production notes |
| Dialogue, Banter & Quests | Scope | Banter and loyalty arcs grow with every recruit and pairing | Hold the MVP to 4 recruits; scripted banter pairs only; write once, reuse |
| Faction Rule Modifiers | Design | Four sets of rule-bending logic must stay clear and fair (Pillar 4) | Build only Bureaucratia at MVP; make rules data-driven so new factions are content, not code |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 21 |
| Design docs started | 8 |
| Design docs reviewed | 0 |
| Design docs approved | 0 |
| MVP systems designed | 8/16 |
| Vertical Slice systems designed | 0/5 |

---

## Next Steps

- [x] Review and approve this systems enumeration
- [ ] Run `/prototype quirk-combos` to test the highest design risk before writing the combat GDDs
- [ ] Design MVP-tier systems first (use `/design-system [system-name]`), starting with Content Data Definitions
- [ ] Run `/design-review` on each completed GDD
- [ ] Run `/gate-check technical-setup` when MVP systems are designed
- [ ] Validate the highest-risk systems with `/vertical-slice` before committing to Production
