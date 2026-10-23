# Overworld Exploration & Encounters

> **Status**: Approved (rev 4, design review 2026-10-23)
> **Author**: user + agents (`/design-system`, autonomous mode)
> **Last Updated**: 2026-10-23
> **Last Verified**: 2026-10-23
> **Design Review**: 2026-10-23 NEEDS REVISION three times, then APPROVED after targeted verification of rev 4 (round 1: 18 blocking; round 2: 24; round 3: ~30 local; `reviews/overworld-exploration-encounters-review-log.md`). Rev 2 addressed round 1, rev 3 round 2, **rev 4 addresses round 3**. Rulings taken by creative-director, open to user veto (OQ-15 to OQ-17, OQ-20 to OQ-22): one telegraphed story encounter per region, started by `confirm` only; liberated regions get a presentation override and a walk home; facing-weighted notice; stage raises only on the faction's schedule and only on maps still ahead of the player.
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-23 — CONCERNS (8 items); items 1–7 folded in (gag interactables, faction-rule clue, Bureaucratia given its point and mixed liberation reactions, boss victory liberates the region, deflated respawn, patrol archetype per faction, recruit_remark hook); item 8 is OQ-1 (blocking for the first overworld story)
> **Implements Pillar**: Pillar 1 (The Joke Is the Mechanic), Pillar 4 (Readable in One Turn), Pillar 2 (Nobody Is Right); concept aesthetic #1 Discovery

## Summary

The overworld is where the squad walks through small diorama maps of an
occupied region (MVP: Paris, a linear chain of Town → overworld segment →
dungeon → boss chamber). The leader moves with three recruits trailing behind.
Players read the occupation's satire at a glance, interact with it, rest at
camps, and choose which fights to take. Every street battle starts from a visible
Compliance Clerk they can avoid or walk into, and each region has one announced story fight; there are no random encounters.
The faction's own schedule raises each map's occupation stage ahead of the squad, and victories clear the
clutter locally on screen. The system owns movement, symbol patrol and chase,
interaction, checkpoints, map exits, camp spots and the persistent world state
that Game State freezes around battles and saves at safe moments.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Game State & Scene Flow, Input System, Content Data Definitions, Sprite & Camera Presentation, Squad Roster & Recruitment (provisional), Dialogue Banter & Quests (provisional)`

## Overview

Overworld Exploration & Encounters is the part of the game the player walks
around in. The squad's leader moves freely across small, hand-built diorama
maps of an occupied region (Paris in the MVP), with up to three recruits
trailing behind. Along the way the player reads the occupation at a glance,
pokes at its satirical clutter (checkpoints, forms, posters, queues), talks to
locals, rests at camp spots, and chooses which fights to take. Every fight
starts from a **visible enemy on the map**, such as a Bureaucratia Compliance
Clerk walking a patrol route. The player can see it, avoid it, or walk into it
on purpose. There are no hidden random encounters in the MVP. Story progress
raises each occupied map, ahead of the squad and on the faction's own schedule, through the art bible's occupation stages
(Contested → Occupied → Saturated). The player's victories clear the clutter
locally, so liberation is something you can see on the street.

**The data and rules layer.** Maps and encounters are content records:
- `map_` records hold a map's display name, lighting profile and occupation-stage parameters;
- `enc_` records hold the descriptor Turn Battle needs.

The system owns movement on the map's walkable area, symbol patrol and chase,
interaction, map exits, camp spots and post-battle consequences. It also owns
the persistent **world state**: where the party stands, which enemies are
beaten, which interactables are opened, and each map's occupation stage. Game
State freezes and restores that state around every battle and saves it at safe
moments.

The implementation approach is ADR-0012 (Overworld Exploration & Encounters,
Proposed):
- continuous movement on a 2D ground plane against a walk grid baked from the map, with **no physics engine**;
- maps and encounters as data;
- one encounter pipeline;
- an injected `WorldState`.

This GDD settles what ADR-0012 left to design: symbols only, follower display,
occupation stages, the Paris layout, and every provisional value it named.

**Why the game needs it.** Without the overworld, the game is ChapterFlow's
fixed sequence of fights: no Discovery (the concept's first target aesthetic),
no choice over which fights to take, and no place for the satire to live
outside battle. The overworld is where Pillar 1 meets the player before any
battle begins, and where "Readable in One Turn" extends to space.

## Player Fantasy

**Mischief in a Toy Paris.** Occupied Paris is a toy-table diorama, and every
street is a joke you can walk into. The aliens have filed the city under their
own rules: posters stack up, landmarks get new labels, clerks walk patrol
routes. You can read all of it at a glance. You are the squad that wanders in
and pokes things: tearing a notice, cutting a line of tape, stepping into a
patrol on purpose. Exploring here means finding the next gag. Each one is a
clue to a faction rule or the setup for a fight. The player should feel
curious, slightly naughty, and always one step ahead of the occupiers.

**The anchor moment.** You step onto a Paris street and read the occupation as
one joke: a red-tape barrier, a queue of Parisians trading forged queue numbers,
a Bureaucratia clerk patrolling with a clipboard. You know what you're dealing with before
anyone speaks. Then you choose: dodge the clerk, or walk straight into him.

This system carries the concept's first target aesthetic, **Discovery**, and
serves three pillars:
- **Pillar 1, The Joke Is the Mechanic.** The occupation's gags are interactable or route-blocking, not set dressing.
- **Pillar 4, Readable in One Turn.** It is applied to space: who runs a block, where the danger walks, and where the exits and camps are, all readable without UI text.
- **Pillar 2, Nobody Is Right.** Locals are part of the joke too. They treat the occupation as one more strike.

**Fantasy guardrails.** The overworld must never feel like:
1. **A chore or a toll road.** No encounter the player couldn't see coming, and no fights you have to farm. Every street fight is optional. The only exception is each region's single **story encounter** (rule 13a). It is visible from a distance, announced before the player reaches it, and preceded by a camp. The player chooses *when* to take it, not *whether*. A fight the player couldn't see coming is a design failure.
2. **Real oppression.** No rubble, victims, cages or violence against humans. Occupation is shown as *inconvenience*, never suffering. Escalation is more paperwork, never more harm.
3. **One side's propaganda.** Parisians are neither helpless nor saintly. Their jokes come from how they behave under the occupation, never from being French: they game the permit system, run a black market in stamps, and file counter-forms.
4. **A set you only walk past.** If a gag on the map does nothing when you interact with it, cut it or make it an interactable.
5. **Hard to read.** Encounter threats, exits and camp spots are legible on screen without reading UI text.
6. **A historical re-enactment, or a story about migrants.** An occupied Paris with checkpoints, an organised opposition and a liberation maps closely onto 1940–44. Aliens who are made to queue, filed and told to go home also map onto immigration and detention. The game's title makes both worse, so the overworld must never use either template. **Exclusion list** (the first item on the tone checklist, rule 18):
   - no "papers, please" phrasing; Clerks check *forms*, *stamps* and *queue numbers*, never identity papers. Stamps may be forged (guardrail 3); **identity documents** are never forged, checked or confiscated;
   - Clerks process **forms and permits, never people**. No sign, line or label says a person is processed, registered, interned or admitted;
   - no shaming or punishment of collaborators: locals who join in are **enthusiastic adopters**, marked by **behaviour** that only makes life harder for themselves (form hobbyists, people who queue for fun, queue-number collectors), never by enforcing anything on their neighbours, played for comedy about their eagerness and never judged;
   - no civilian marked by anything worn: no badges, stars, ribbons, armbands or tags;
   - no 1944-style liberation tableau, such as crowds in the street, flags, or the occupiers marched off;
   - no banners hung on facades or monuments; faction signage is bolted-on office hardware (filing boxes, stamp-shaped street signs, in-trays);
   - no queues for food or rations; queues are for forms, stamps and queue numbers;
   - no secret meeting room; the café camp is an ordinary café;
   - "resistance", "maquis", "underground" and "collaborator" never appear in player-facing text. In this document the player's side is **the squad**;
   - no visa, residency, deportation, border or asylum vocabulary, in either direction;
   - no overworld civilian line or bark says "go back", "your planet", or anything else about where the aliens came from. The title's own joke belongs to the narrative bible, not to street civilians (OQ-21);
   - no uniforms, insignia, armbands or salutes modelled on real occupying forces.

   **Composite test.** The list is checked item by item, but the allegory comes from combinations, so each faction × stage set also gets one composite check (rule 18 item a2): a reviewer looks at the set's highest-stage capture together with all of its lines and asks, "Does this read as occupied 1940s Paris, or as border control, with the faction swapped in?" The answer must be no.

> Framing chosen with `creative-director`, which offered three candidates: "Mischief in a Toy Paris", "The Squad Goes for a Walk" (first drafted under a name rev 3 retired, guardrail 6) and "Reading the Occupation". The recommended one was taken (autonomous mode, logged). Squad companionship is layered on later through recruit remarks at interactables, which Dialogue/Banter owns.

## Detailed Design

### Core Rules

**0. Terms used throughout.**
- **Critical path.** Each `map_` record lists one or more `critical_path` legs. A leg is `{id, from: EntryPoint id, to: MapExit id | symbol_id | CampSpot id}`. A leg may end at an exit, at the story encounter or the boss (a `symbol_id`), or at a camp (the chapter's final step). The `to` exits are the map's **required exits**; every other exit is optional. Each ChapterFlow step names the `{map_id, leg_id}` it sends the player along, so the **current leg** is always known (rule 19).
- **Leg length.** `L_crit(leg, stage)` is the walk-grid shortest path between a leg's two ends at that stage, with closed checkpoints handled as in rule 12's ordered search. It is the only definition: the walk budget uses the bypass-lane variant `L_bypass(leg, stage)` (rule 12), taken as its maximum over the map's reachable stages.
- **Requirement source.** Every checkpoint requirement (an item or a flag) names where it is obtained: `obtained_at` is a `pickup` Interactable, a gag `change`, an NPC line that sets a flag, a chapter-step flag, or a `victory_payoff`. CI checks every requirement against its source (rule 10).
- **Safe zone.** Every cell whose nearest point lies within `safe_radius_m` of an EntryPoint, a MapExit trigger rectangle or a CampSpot, or within the smaller `return_safe_radius_m` of a checkpoint or story-encounter **return marker** (rule 10). The small radius keeps a redirect landing safe without swallowing the patrol area around a gate. Safe cells are tagged `SAFE` when the walk grid is baked. Rasterising is conservative, so a cell any part of which is in range counts.
- **Blocked cell.** A cell the leader cannot enter. It is either baked wall, or a cell covered at runtime by an active route-blocking marker (a closed checkpoint, a queue, tape). Opening or liberating the marker frees its cells again (rule 9, rule 10).
- **Symbol-legal cell.** A cell that is neither blocked nor `SAFE`. Symbols path and move only over symbol-legal cells.

**1. Movement: one speed, no held input.**
- The leader moves at `walk_speed · min(1, |move|)`, so a stick's partial tilt walks proportionally slower and keyboard input always gives full speed.
- There is no run button, held or toggled. The accessibility commitment forbids held inputs, and MVP maps are short enough that walking is not a chore.
- A press-to-toggle "Fast Walk" setting may be revisited at Vertical Slice if playtests find traversal slow.
- Movement, collision, wall-slide and corner assist follow ADR-0012 §2.

**2. Party on the map: leader plus followers.**
- Only the leader has a position in logic. Only the leader collides, triggers encounters, probes interactions and crosses exits.
- Up to 3 followers are cosmetic `CharacterSprite`s, in Squad Roster order. Each replays the leader's recorded path at a fixed spacing, `follower_spacing_m`. Followers have no collision and no logic, and nothing can touch them.
- Followers snap to formation behind the leader on map entry, on a teleport, after a checkpoint redirect and after a battle thaw.
- Followers are not saved. They are rebuilt from the roster on load.

This serves Pillar 3: the squad is visible while you explore. It settles the
point ADR-0012 left open.

**3. Interaction.**
- **Target.** One query, `probe()`, finds the target. It looks for an **eligible** `Interactable`, `NpcSpawn`, `CampSpot` or `confirm`-started Static symbol (rule 13a) whose position lies within `interact_reach_m` of the **probe point**, `facing · body_radius` ahead of the leader's centre. The target nearest the probe point wins. On an exact tie the order is NPC, then CampSpot, then Static symbol, then Interactable.
- **Eligibility.** A target is eligible only while `confirm` would do something:
  - an **open** checkpoint, a `change` gag already changed, and a liberated marker drop out of `probe()`;
  - a `line` or `clue` gag stays eligible and repeats its line (a short alternate line if the record has one). A granted clue adds no second rumour;
  - a decree gag (rule 8) stays eligible and shows its text (rule 16);
  - NPCs and CampSpots are always eligible;
  - a Static symbol is eligible only while unresolved. While the story encounter is unresolved, its own boom checkpoint is **not** a `probe()` target, so the fight always starts through the Static symbol and rule 7's Static branch always applies.
- **Prompt.** The on-map interact prompt (UI Requirements) is drawn over the current `probe()` result. `confirm` acts on that same result, so the prompt always marks what `confirm` will do.
- **Nothing in reach.** `confirm` does nothing and makes no sound.
- **Pointer input** is ignored (`input-system.md` rule 3).
- **Lockouts.** No probe runs and no interaction starts while a transition is running or **any** overlay is open, Dialogue included. Input inside an overlay belongs to the overlay. The `confirm` press that closes an overlay is consumed by the overlay and never reaches `probe()`: the carry-over idea of `interaction-patterns.md` P2, applied when an overlay closes. A new `confirm` is accepted only after release, so closing a line cannot reopen it.

**4. Encounter model: visible symbols only.**
- In MVP every battle starts from contact with a visible `EncounterSymbol`, on every map, dungeon included.
- In the fiction, each symbol is **its faction's patrol archetype**, data-defined per faction (`faction_` record, `patrol_archetype_id`) so each faction's patrol is its own joke (Pillar 1). Bureaucratia's is the **Compliance Clerk**: a functionary with a clipboard who stamps anything that stands still and counts things that don't need counting. Future factions bring their own (an influencer-scout, a collections agent, a zealous recruiter).
- The zone mechanism stays in code and data (ADR-0012 §9), but every MVP `map_` record sets `zone_rate = 0`. At 0, no zone roll is made, so no zone encounter can happen.
- Every street fight is one the player can see coming and choose to take or avoid. The one exception is the region's story encounter (rule 13a), which the player can see coming but cannot route around.

**5. Symbol behaviour.** Symbols run the sub-states below. Sub-states advance only in Exploring, in marker order, on the overworld clock `ow_dt` (Formulas).

| Sub-state | Behaviour | Exits |
|---|---|---|
| **Patrol** | Walks its marker's patrol path at `v_patrol`. The path is a polyline marked `loop` (closed: last vertex back to first) or `pingpong` (walks back the way it came). At each `pingpong` end, and at each `loop` vertex that turns by more than 90°, it pauses for `turn_pause_s` in a look-back pose before its facing flips, so a player sneaking behind it gets a warning. During the pause the **old** facing still decides the half-planes; the flip happens at the pause's end. | → **Noticing** when the notice test (below) passes. |
| **Noticing** | Stops, turns to face the leader, shows the notice cue. Does not move. | → **Chasing** after `notice_delay_s`, whatever the leader does meanwhile. |
| **Chasing** | Moves at `v_chase` along an `AStarGrid2D` path over symbol-legal cells toward its **chase target** (below). Repaths at most every `repath_s`, and only if the target cell changed or a `set_blocked` call invalidated the path. Shows the chase cue. | → **Returning** when the give-up test passes. → contact (below). |
| **Returning** | Walks at `v_patrol`, by A* over symbol-legal cells (inside the query budget), back to the **resume point**: the point on its patrol path where it left Patrol. Then resumes Patrol from there, in the direction it was going. **Deaf and intangible**: no notice test, no contact. | → **Patrol** on reaching the resume point, and the notice test stays off for `renotice_cooldown_s` after that. |
| **Stunned** | After a Fled battle (non-Static symbols only): sits for `flee_grace_s`. **Deaf and intangible**: no notice test, no contact. | → **Returning** when the stun ends. |
| **Static** | The boss and the story encounter only (rules 13, 13a). Never moves, never notices, is never pushed or stunned, shows no cue. Each Static marker sets `start_on`: `contact_or_confirm` (the boss) or `confirm` (the story encounter). | Starts its encounter per `start_on`. |

- **Facing.** A symbol's logical facing is its movement direction, **snapped to the displayed sprite facing** (the four diagonals the `CharacterSprite` shows, ADR-0005 §1), so the half-plane the player sees is the half-plane that notices. The snap has hysteresis: the facing changes only when the movement direction is more than 45° + 5° from the current diagonal, and a symbol that is not moving (turn pause, Noticing, contact pending, Stunned) keeps its last facing. When a turn lands exactly between two diagonals, the one nearer the previous facing wins; if still tied, the lower index (NE 0, SE 1, SW 2, NW 3). A leader exactly on the dividing line (dot product 0) counts as in front.
- **Notice test.** It runs only in Patrol, outside the cooldown, and outside encounter grace (rule 7). The cheap checks run first, in this order, and the first that fails ends the test without any search:
  1. the leader's centre is within the **notice radius**: `symbol_chase_m` across the symbol's front half-plane and `symbol_notice_rear_m` across its rear half-plane, measured centre to centre. A player can slip behind a Clerk, but not past its nose;
  2. the leader is not in a `SAFE` cell;
  3. the leader's cell and the symbol's cell lie in the same **symbol-legal component**. The walk grid keeps **4-connected** component labels (matching the A* diagonal rule), recomputed once per frame after that frame's `set_blocked` calls. A fenced-off leader is rejected at once;
  4. a **bounded search** (uniform-cost, Dijkstra-style, over symbol-legal cells with √2 diagonal steps, stopping at path length `notice_path_cap_m`) reaches the leader's chase target with `path_dist` ≤ `notice_path_cap_m`. The search never explores beyond the cap, so its cost is bounded inside a component. Its **waypoints** are cached per symbol until the symbol's cell or the leader's cell changes, or a `set_blocked` call clears the cache; `path_dist` end gaps are recomputed from the exact centres on every use.

  A Clerk never notices a leader it could not reach, such as one on the far side of a fence.
- **Query budget.** Notice searches, chase repaths and Returning paths share `repath_per_frame_max` per frame. A **round-robin cursor** serves the oldest deferred request first, so no symbol is starved: every request is served within `⌈N_req / repath_per_frame_max⌉` frames. A notice query deferred by the budget counts as "not noticed this frame".
- **A* origins.** Every search starts from the symbol-legal cell nearest the symbol's centre (ties: lowest cell index), so a symbol never searches from a solid cell. `allow_partial_path` is always false.
- **Chase target.** The symbol-legal cell nearest the leader (ties: lowest cell index), offset sideways by `(marker index mod 3 − 1) · body_radius` perpendicular to **that symbol's own** symbol-to-leader vector, so two Clerks chasing together stay visibly two. The offset is dropped when the offset point is not on a symbol-legal cell. **Final approach:** the symbol steers straight at the leader's offset point instead of the cell centre only when **all** of these hold: the leader's cell is still the path's target cell; the leader is not in a `SAFE` cell; and every cell the straight segment crosses (swept by `body_radius`) is symbol-legal. The step goes through `GroundMover` with the symbol mask, so a symbol never ends a frame on a non-legal cell. Otherwise it follows the path. A symbol therefore reaches a leader who stands still on open ground.
- **Path distance.** `path_dist(t) = arc(c_S → w_last) + |w_last − c_L(t₀)| + d_L(t₀ → t)`: the remaining arc length along the stored path, plus the gap from the path's end to where the leader was when the path was computed (`t₀`), plus the distance the leader has walked since. The three parts join into one real route from the symbol to the leader, so their sum is at least the shortest route: `path_dist` is a true **upper bound** on the leader's path distance. The gap is only a real route segment when it is walkable, so **if the leader stood in a `SAFE` cell at `t₀`, or the straight gap crosses a cell the leader cannot walk, the gap counts as +∞** until the next repath (give-up can only come earlier). A stale path can therefore only make give-up earlier, never later. A chase that starts reuses the notice search's path as its first path. A path whose repath is deferred is **pending**: the old path is kept, and a pending path is never "empty".
- **Give-up test.** It runs in Chasing and passes once, for `giveup_s` without a break, **either** `path_dist` exceeds `symbol_giveup_m`, **or** the leader stands in a `SAFE` cell, **or** the path is empty (A* returned nothing, and nothing is pending). Straight-line distance is never used, so a switchback cannot hold a chase open.
- **Contact.** It counts only in Patrol, Noticing and Chasing, and for a Static symbol whose `start_on` is `contact_or_confirm`. It never counts during encounter grace, or while the leader is in a `SAFE` cell. Eligibility (sub-state, grace, `SAFE`) is read **after** this frame's movement. It is a **swept** test: contact happens when, at any point during the frame's movement, the distance between the leader's and the symbol's centres is ≤ 2·`body_radius`. The first contact calls `start_encounter(enc_id, symbol)`. A symbol touched during Patrol stores its patrol position as its resume point.
- **Contact pending.** While `start_encounter` is rejected (a transition is already running), the touched symbol holds still and keeps its sub-state. It moves again only if the overlap ends.
- **Symbols and each other.** Symbols do not collide with each other, with followers or with civilians.
- **Patrol legality.** Every cell a patrol segment sweeps (± `body_radius`), and every resume point, is symbol-legal at every reachable stage where that symbol is active (checked in CI). A stage blocker therefore never lands on a live patrol.
- **No route.** If the resume point cannot be reached, the symbol holds still where it is, deaf, until the map reloads, and one warning is logged. Patrol legality makes this a data error, never a shipped state.
- **The deflated variant** (rule 9) changes the look only, never this behaviour.

**6. No ambush or first-strike bonus.** Turn Battle's turn order is fixed: the
squad phase always resolves before the enemy phase (`turn-battle-system.md`
§3.1), and there is no initiative or surprise hook. Who touched whom, and from
what direction, has no mechanical effect. At most it picks a contact animation.
Revisit only if Turn Battle adds a battle-entry modifier.

**7. After battle.** Thawing happens in two steps.
- **Step 1, in `on_thawed`, after `mode_entered(Overworld)` and before the reverse wipe reveals anything.** All state changes are applied here:
  - **Victory.** The symbol is resolved per its record's `respawn` policy. Normal Clerks use `on_map_reenter`: gone until the map is left and loaded again. The boss and the story encounter use `never`. The record's `victory_payoff` is granted (rule 7a). Liberation state is written (rule 9), and linked markers **outside** the camera footprint are removed and their blocked cells freed.
  - **Fled (non-Static symbol).** The symbol enters Stunned and is moved back up to `flee_push_m` at once (Edge Cases). The leader never moves.
  - **Fled (Static story encounter).** The symbol is not stunned or pushed. Under the wipe, the leader is placed at the story encounter's return marker (in a `SAFE` cell), facing away, and a gag line is queued: on `transition_finished` it opens as an automatic Dialogue with P2's `input_guard`, so a `confirm` still held or mashed from the battle cannot skip it (rule 13a). Fleeing is a joke, never a loop back into the fight.
  - **Both.** Followers re-form behind the leader.
  - **Fleeing costs nothing** beyond the fight itself. Walking in and fleeing to see a lineup is allowed: it is free information (Pillar 4), and the Clerk is stunned, not resolved.
- **Step 2, on `transition_finished`, once the scene is revealed.** Encounter grace (`encounter_grace_s`) starts. On-screen liberation plays (rule 9). A **payoff card** shows for every payoff granted by this Victory (rule 7a). The reverse wipe therefore never uses up grace or hides the payoff.
- **Grace.** During grace no symbol notices, and none makes contact. Any symbol in Noticing or Chasing when grace starts switches to Returning. Grace also starts on `transition_finished` after **every** map load, Continue included, and after every checkpoint redirect (rule 10).
- **Defeat, Retry and Retreat** follow `game-state-scene-flow.md` rule 8. Retreat discards the frozen overworld, so nothing above applies.

**7a. Victory payoff.** Fighting must be worth something in MVP, where XP and money have no shop yet. Every non-boss, non-story `enc_` record linked from a symbol names exactly one `victory_payoff` (`none` included):
- `clue`: a faction-rule hint. It is added to the Combo Codex as a **rumour**, which a later battle confirms. Until Combo System & Codex exists, an interim stub dialogue line shows the hint. Each `clue` on a map reveals a **distinct facet** of the faction rule (for Bureaucratia: what approves a target, how long Approved lasts, who can stamp). No two `clue` payoffs in a region repeat a facet, and none repeats the free first-encounter poster (rule 16);
- `open`: a linked checkpoint opens (rule 10), saved as opened. It leads to authored **optional content**: an **optional pocket** (a dead-end room or courtyard holding a `change` gag plus a recruit remark or clue facet, never loot; see Rules for payoffs) or a **shortcut** (on the dungeon, a route back to the pre-dungeon camp that makes a boss retry cheaper);
- `item`: a key item that meets the requirement of an optional-pocket checkpoint. An item from a fight never gates the critical path (rule 10);
- `none`: no payoff, and no tell. The missing prop is itself the tell (Pillar 4), and the ordinary victory feedback still plays, so it reads as a joke at the Clerk's expense ("He had nothing. He was just very keen."), never as a bug.

**Rules for payoffs.**
- The payoff is granted only on the **first** Victory over that marker's symbol. A respawned Clerk gives none.
- Every non-Town, non-boss map has at least one `open` payoff, and at least half of its symbols carry `clue` or `open` (checked in CI).
- `none` is limited to at most ⌊N_sym/3⌋ symbols per map. It is never used on a Static symbol, nor on the first symbol a player can reach on a map (the first symbol along the critical path).
- **Optional pockets are worth the fight.** Each pocket holds a gag with a `change` response **and** either a `recruit_remark` or a clue facet.
- The first-encounter poster covers the facet **"what approves a target"** (a stamp), so `clue` payoffs in Paris draw from the other facets: how long Approved lasts, and who can stamp.
- **Readable before the choice (Pillar 4).** Each payoff has a **tell** on the map, within `R_vis` of a vertex of the symbol's patrol: a sealed envelope pinned to the Clerk's clipboard for `item`, a rolled poster for `clue`, and the closed gate itself for `open`. CI checks the gate's or prop's placement.
- **Payoff card.** On the reveal after the Victory, a non-blocking card like the map name card names what was granted ("Shortcut opened: Rue des Tampons", "Rumour noted in the Codex", "Got: Form 27-B"). Off-screen results are therefore never audio-only.
- The story encounter's payoff is opening its own checkpoint (rule 13a). The boss's is region liberation (rule 13).

Whether to fight is then a real choice: avoiding a fight keeps the route easy, and taking it buys a visible pocket, a shortcut or an edge in battle.

**8. Occupation stages.** Each occupied map has a stage: **1 Contested**, **2 Occupied** or **3 Saturated** (the art bible §2 gradient).
- **Raising a stage.** Only the faction's own schedule raises a stage. A map's stage comes from story flags through that map's flag-to-stage table, and stages never go down.
  - **Never a reprisal.** No stage-raising flag is set by a player Victory, by the player entering a map, or by any other squad action against the faction (Pillar 2: the squad never brings the occupation down on the locals). Raising flags are set on **ChapterFlow step changes** that read as the faction's calendar (for example, a decree "in force since Tuesday").
  - **Only ahead of the player.** A raising flag may only be set on a step **before** any step in which a map it raises can first be loaded, so the player never sees the map at the lower stage and the raise is never set behind them. Checked against the step list and the walk grid in CI: no route from the chapter's start reaches a raised map before its flag is set.
- **When it applies.** The stage is computed only when a map loads. A flag set during a visit takes effect on that map's next load, so clutter never pops in on screen.
- **Announcing it: decree gags.** Every stage-raising flag names a **decree gag**, its own marker kind (`decree_gag`): a poster or notice that is the in-world announcement ("BY ORDER: ALL QUEUES NOW REQUIRE A QUEUE TO JOIN THEM. IN FORCE SINCE TUESDAY."). A decree gag:
  - is placed at **every** usable EntryPoint of the raised map, inside or at the edge of that entry's safe zone, so a stage never rises without a visible cause whichever way the player arrives;
  - is active at and above its new stage (the decree stays in force), and is exempt from the stage caps and from the "no faction clutter in a safe zone" rule (rule 12, Visual/Audio);
  - never blocks a route, and is always eligible for `confirm`, which shows its text (rule 3, rule 16);
  - may instead be triggered on first sight (the story encounter's decree, rule 13a);
  - is removed, like all clutter, by region liberation (rule 9).
- **What a stage sets.** Stage parameters are data keyed by **faction × stage**: civilian density, the caps per clutter kind, symbol patrol density, and the lighting profile. This settles `sprite-camera-presentation.md` Open Question 6, which left occupied and dungeon lighting to this GDD. Faction hue still tints only sky, set and fill, and the actors' key and rim stay neutral (presentation rule 11). Caps never fall as the stage rises (Formulas, invariant I13).
- **Placement.** Map authors place candidate markers (posters, queues, checkpoints, civilians, symbols), each tagged with a `min_stage`. A marker is active when the map's stage is at least its `min_stage` and its kind is still under that stage's cap, taken in marker order. Placement is never procedural.
- **Civilians.** Civilians are `NpcSpawn`s drawn from the stage's pool, including **enthusiastic adopters** marked by behaviour that only inconveniences themselves, such as form hobbyists, people who queue for fun and queue-number collectors (guardrail 6). No civilian enforces the faction's rules on another. Their density drops as the stage rises. Civilians do not collide.
- **Tone.** All clutter reads as comic bureaucracy: forms, stamps, queues, permits, hold music. Each faction × stage content set passes the tone checklist (rule 18) before it ships.
- **Paris stages (MVP).** The gradient rises on the way to the Ministry, and every stage is seen in order:
  - Town: Contested (1). It has no Clerks, so the lightest occupation fits the hub.
  - Overworld segment: base Contested (1), table {`permits_mandatory`: 2}. The decree is already in force on arrival ("IN FORCE SINCE TUESDAY"): `permits_mandatory` is set on the chapter's **opening** step, before the player has control, so the occupier acts first and nothing the squad does causes it. The segment therefore always loads at stage 2: its only **reachable** stage is 2 (Formulas, `occupation_stage`), and no stage-1 content is authored for it.
  - Dungeon: Saturated (3), the Ministry's own ground.
  - Town stage 2 and 3 content is **cut from MVP**: nothing in MVP routes the player back through an unliberated Town.

**9. Local liberation.** A clutter marker (poster, queue or checkpoint) may name one `symbol_id` and/or one `liberation_flag`. Every clutter marker is also liberated by its map's `region_liberation_flag` (a `map_` field), which the region's boss victory sets (rule 13).
- **Placement.** A marker that names a `symbol_id` must lie within `R_vis` (Formulas, `chase_visibility`) of at least one vertex of that symbol's patrol path, so winning the fight shows its result. Contact can happen anywhere along a chase, so a marker may still be off-screen at the reveal: that case is handled by the off-screen sting **and** the payoff card (rule 7a). The symbol must also be active at every stage where its marker is active, or the marker could not be liberated before the boss falls. Both are checked in CI.
- **Timing.** When the symbol is beaten, or the flag is set, the marker joins the map's liberated set in `on_thawed` (rule 7, step 1).
  - A marker **outside** the camera footprint is removed there, under the wipe, so it is already clear when the player walks to it. On `transition_finished` a short off-screen liberation sting plays, and its visual twin is a line on the payoff card ("Street cleared: Rue des Tampons"), so the win is both heard and seen.
  - A marker **inside** the footprint stays visible until `transition_finished` (rule 7, step 2). It then plays its removal on screen, finishing within `liberation_duration_s`: posters come down, queues break up, a resolved checkpoint opens.
  - Blocked cells are freed when the marker leaves the liberated set's "pending" list: at once if it is off-screen, and at the end of its removal if it is on-screen.
- **Reactions are mixed (Pillar 2).** The share of civilians who grumble is data, with a floor of `liberation_grumble_min`. Some grumble that the queue was the only orderly thing in Paris. At least one reaction per map ribs the squad, for example a café owner sweeping up the torn posters and glaring at the leader.
- **Saving.** The liberated set per map is saved in world state.
- **Permanence.** A liberated marker stays liberated when its Clerk respawns, and when a later stage raise reactivates its area. The Clerk itself still respawns per its `respawn` policy, so a cleared street still has a patrol to avoid or fight. A Clerk respawned onto a liberated street uses a **deflated** look (a sheepish pose, no clipboard flourish) with unchanged behaviour (rule 5).
- **Region liberation is evaluated on every load,** not stored as a list of marker IDs. While `region_liberation_flag` is set, every clutter marker and decree gag on that map is treated as liberated, including markers a later stage would add, and **every symbol on that map is inactive**, beaten or not. No Clerk chases anyone through liberated Paris.

**10. Checkpoints.** A checkpoint is one generic `Interactable` kind, reskinned per faction. A **closed** checkpoint blocks its cells (rule 0), so it is a route-blocker.
- **Requirement.** Each checkpoint has exactly one: an item ID or a story flag.
- **Success.** If the requirement is met when the player presses `confirm`, the stamp moment plays, the checkpoint opens, and it stays open (saved). Its cells are freed.
- **Failure.** Otherwise the data-chosen failure outcome plays:
  - **`redirect`:** a dialogue line that names the missing requirement in plain words ("No Form 27-B? Back of the queue."), then a **redirect**;
  - **`queue`:** a comedic queue dialogue, then a redirect. Never a wait, hold or timed input;
  - **`encounter`:** a linked Clerk encounter starts, and winning it opens the checkpoint.
- **Redirect.** It is an input-locked dip-fade (P9) with no faction color, through the flash gate. It is a **same-instance** Game State transition: the overworld stays loaded, symbols keep their state, no `mode_entered` fires, and Game State still locks input, defers the Menu, reports not save-safe and emits `transition_finished` (ADR-0002 amendment, OQ-3 item 12). Under the fade the leader is placed at the checkpoint's **return marker**, facing away from the checkpoint. The camera snaps, followers snap, and encounter grace starts on reveal (rule 7). Every return marker is a safe-zone source (rule 0), so a redirect never lands next to a patrol and never sends the player far back.
- **No grind blocks.** A checkpoint never asks for XP, level or currency.
- **On the critical path:**
  - A closed checkpoint is allowed if its requirement's source (`obtained_at`, rule 0) lies **earlier on the same leg** and is reachable without any fight: a `pickup`, a gag `change`, an NPC line or a chapter-step flag. A `victory_payoff` never counts as a critical-path source.
  - A checkpoint with the `encounter` outcome is **not allowed**, except as the region's story encounter (rule 13a).
  - Every critical-path requirement can therefore be met on the critical path, whatever fights the player has avoided. CI proves it with rule 12's ordered search.

**11. Map structure (MVP Paris).** The maps form a linear chain: **Town hub → overworld segment → dungeon → boss chamber**, with a `MapExit` both ways on every link.

| Map | Contents |
|---|---|
| **Town** | No symbols. It holds the **region default camp**: a `CampSpot` at an ordinary café near the Town's entry, its terrace and counter, not a back room. A neutral human "third place", never a secret base (Pillar 2, guardrail 6). The chapter ends here (rule 13) |
| **Overworld segment** | Sparse symbols. The first-encounter map: it holds the faction-rule clue and the "Clerks are optional" teaching beat (rule 16), and at least one optional pocket behind an `open` payoff (rule 7a) |
| **Dungeon** | Denser symbols. Its first room holds the **pre-dungeon `CampSpot`** (on the dungeon map, inside the entry's safe zone) and, beyond it, the region's **story encounter** (rule 13a). It holds an optional pocket and a shortcut back to the pre-dungeon camp, each behind an `open` payoff |
| **Boss chamber** | Its own small map, reached through a `MapExit` from the dungeon's final room. That exit may be checkpoint-gated |

**Map exits.**
- Crossing a `MapExit` rectangle requests a fade to the target map's `EntryPoint` (ADR-0012 §4).
- An exit fires only when the leader's centre **enters** its rectangle from outside. A leader placed inside one (by a load) must leave it first.
- Every EntryPoint lies at least `body_radius + entry_clearance_m` outside every MapExit rectangle, and faces into the map. A held `move` therefore never bounces the leader straight back out.

Future regions follow the same pattern: a default camp in a culturally local
neutral space.

**12. Safe zones, bypass lanes and pressure.**
- **Safe zones.** No symbol spawn point and no patrol **segment** (the closing segment of a `loop` path included) comes within `safe_radius_m` of any EntryPoint, MapExit trigger rectangle or CampSpot, or within `symbol_chase_m + body_radius` of any return marker (so a redirect never lands inside a patrol's notice radius once grace ends). Distance is measured segment to rectangle for exits and segment to point otherwise. Return markers and the load relocation of rule 15 never lie inside a MapExit rectangle. Checked in CI.
- **Symbols never enter safe zones.** `SAFE` cells are not symbol-legal (rule 0), so chase and push stop at the edge. A leader in a safe zone cannot be noticed or touched, and a chase on them gives up (rule 5).
- **Visibility.** A Clerk's patrol is on screen before the leader reaches its notice radius, from every approach (Formulas, `chase_visibility`). An approach is each walk-grid entry into the disc of radius `see_m` around the patrol. A walk-in screenshot per symbol and approach ([VF]) confirms that no set occluder hides a patrol inside `see_m`. Interior walls taller than `wall_h_max` within `see_m` of a patrol are cut away, or the patrol is moved.
- **Bypass lane.** On every non-boss map, **at least one** route along each critical-path leg stays out of every symbol's notice radius. Checked in CI, at **every reachable stage**, by an **ordered search** per leg:
  - **Bands.** Every cell whose centre lies within `symbol_chase_m + cell_m/√2` of any active patrol segment is treated as blocked, as is every blocked cell (baked wall, active route-blocker).
  - **Checkpoints.** A closed checkpoint is treated as open once its requirement's fight-free source (rule 10) is reachable earlier on that leg, through the band-blocked grid. Checkpoints behind `open` payoffs stay closed, since they need a fight.
  - **Story encounter.** The story encounter is Static and has no patrol band. A leg that crosses it is split into two searches: from the leg's start to any cell within `interact_reach_m` of the story encounter, with bands applied; then from the cell beyond its checkpoint to the leg's end, with that checkpoint open. Nothing else is exempt.
  - **Leg ends.** A leg that ends at a symbol (the story encounter or the boss) ends at any cell within `interact_reach_m` of it; a leg that ends at a CampSpot ends in its safe zone.
  - Each search must succeed. Its path is `L_bypass(leg, stage)`. On the boss chamber, which has no patrols, `L_bypass = L_crit`.
- **The story encounter cannot be routed round.** With **every** `open` and `item` checkpoint opened, every walk-grid route from the dungeon's EntryPoint to its boss-chamber exit still crosses the story encounter's checkpoint cells, and every symbol whose payoff opens the dungeon shortcut is reachable only beyond that checkpoint. Checked in CI.
- **Pressure floor (dungeon).** On the dungeon, at every reachable stage, at least ⌈N_sym/2⌉ symbols' blocked bands cross the shortest critical path, where "shortest" means `L_crit` with no bands applied and checkpoints handled as in the ordered search. `L_bypass` is also at least `bypass_ratio_min` times `L_crit`. The dread is real: avoiding Clerks takes route-reading, never just walking. Checked in CI.
- **Pressure floor tie-break.** When several shortest paths tie, the band count is taken over all of them, and the floor must hold on each.
- **First patrol.** On the first-encounter map, the first patrol along the critical path has `L_bypass / L_crit ≤ first_bypass_ratio_max` for its **section** of the leg: the leg cells on `L_crit` from the last cell before the first patrol's band to the first cell after it. The teaching bypass is therefore visibly easy (rule 16). Checked in CI.

**13. Boss.**
- The Minister of Forms is a `Static` `EncounterSymbol` (rule 5) with `start_on = contact_or_confirm`. It sits on a symbol-legal cell in the boss chamber, outside every `SAFE` cell and at least `safe_radius_m + 2·body_radius + cell_m` from every safe-zone source in the chamber (checked in CI), so contact is always possible and never starts on arrival. `confirm` at it also starts the fight.
- Its record sets `is_boss = true`, `can_flee = false`, `retreat_allowed = true` and `respawn = never`.
- Retreat after a Defeat goes to the last camp **registered** (rule 13a): the pre-dungeon camp once the squad has passed it, otherwise the Town café.
- Victory sets the region's `region_liberation_flag` (`paris_liberated`). Each Paris map applies it on its next load, before the scene is revealed (rule 9). That map then gets the **liberated presentation** (rule 17), which is the region's biggest visible payoff. The stage value itself never goes down (rule 8). Other consequences follow rule 14.
- **The walk home (guaranteed payoff; creative-director amendment, round 3).** After the boss's post-battle story Dialogue, the chapter enters its **last act**, two steps long: step A, from the segment's dungeon-side EntryPoint to its Town exit; then step B, from the Town's segment-side EntryPoint to the café CampSpot. The step changes from A to B when the squad enters Town. A map-change fade takes the squad from the boss chamber to the **overworld segment's dungeon-side EntryPoint**. The squad walks back through the liberated streets it fought on, through Town, to the café. That walk is the liberation payoff: mechanics and theme say the same thing.
  - **The way back is closed.** During the last act the segment's exit to the dungeon is disabled and shows an in-world blocker: barrier tape reading "FERMÉ POUR RESTRUCTURATION" (no crowd, guardrail 6). The boss chamber and the dungeon cannot be reached after the boss.
  - **The leg is short.** The last act's two legs are budgeted in `chapter_walk_budget` and targets under 60 s of walking.
  - **The end is announced.** The beacon (rule 19) is on the café. When the leader comes within `interact_reach_m · 2` of the café, the café owner barks ("Sit down before you liberate anything else."). `confirm` at the café on the final step (B) opens a P15 prompt, **"End the chapter here?"**, with **No** focused by default and its own verb and `accessibility_name` ("End chapter"), never the camp's "Rest". Yes ends the chapter. No, or `cancel`, returns to the free roam.
  - The closing image therefore always plays, and the chapter never ends by accident.
- **Liberated maps.** Once `region_liberation_flag` is set, every symbol on that region's maps is inactive (rule 9). Their patrol markers are replaced by the city's **own** paperwork: civilians queueing at the mairie for forms that long predate the occupation, a satire of French administration in its own right (Pillar 2), never "the locals running the occupier's system".
- **The scene does not celebrate** (guardrail 6). Locals go back to their usual strikes and complaints. Each liberated map keeps at least one grumbler NPC and one item where Bureaucratia had a point (a queue-number machine someone keeps using), in its `liberated_kit_id`.

**13a. The story encounter.** Each region has exactly one telegraphed fight that the critical path cannot route around. In Paris it is the **Permit Counter** in the dungeon's first room, beyond the pre-dungeon camp: a Clerk behind a counter, stamping, in front of a closed boom.
- **Placement.** It is a `Static` symbol with `start_on = confirm`, standing on the walkable cell **in front of** a closed checkpoint whose outcome is `encounter`. It is never pushed or stunned (rule 5). A `confirm`-started Static symbol never makes contact, so it is **exempt** from the symbol-legal placement rule: its cell may be tagged `SAFE` (for example, a cell that lies partly inside its own return marker's small disc, since rasterising is conservative). Its return marker lies at least `return_safe_radius_m + body_radius` and at most `interact_reach_m · 3` from it, on the camp side (checked in CI).
- **Starting it: "take a number".** Only `confirm` at the Counter starts the fight. Touching it does nothing, so the player chooses when (guardrail 1). Winning opens the checkpoint and the way on. A **ticket dispenser** on the counter is the visible affordance, and the interact prompt shows the **ticket** kind icon (UI Requirements). The first time the leader touches the Counter, the Clerk barks "Take a number.", tying back to the camp decree, so bumping into it never reads as a bug.
- **Fleeing it.** Fled places the squad at the Counter's return marker under the battle wipe (rule 7). On the reveal, an automatic Dialogue (with P2's `input_guard`) has the Clerk say: "Your number was called. You were absent. Please take a new number." No stun, no push, and nothing can restart the fight until the player presses `confirm` again.
- **Bureaucratia has a point (Pillar 2).** The Counter's board reads "NOW SERVING: 000 003 / YOUR NUMBER: 4 812 117". The squad really is skipping the queue, and the fight's opening line says so. The squad needs a "Permit to Approach the Counter" it does not have, which is the joke and the checkpoint's requirement text.
- **Telegraphed.** Its distance from the pre-dungeon CampSpot's **safe-zone edge** is at most `story_sight_m` along the walk grid, and it is on screen from that edge: checked by the visibility edge `R_e` in its direction (Formulas, `chase_visibility`), plus a [VF] walk-in (AC-30b). On first sight a **decree gag** in the camp's safe zone announces it ("ALL PERMITS MUST BE PROCESSED. TAKE A NUMBER."). That decree is first-sight-triggered and raises no stage (rule 8).
- **Passing a CampSpot registers it.** When the leader enters a CampSpot's safe zone, that camp becomes the **last camp registered**: the Retreat target and the return point. No rest is needed, so a defeat never sends the squad back through the region. This extends `game-state-scene-flow.md` rule 9, where only *entering* camp records it. Game State stays the only writer of `last_camp_id`: the Overworld asks it to register the camp (ADR-0002 amendment, OQ-3 item 13; OQ-18).
- Its record sets `respawn = never`, `can_flee = true` and `retreat_allowed = true`. Its `victory_payoff` is empty: opening its own checkpoint is the payoff (rule 7a).
- **Purpose.** The fight puts every player through at least one Bureaucratia battle before the boss, so the Approved rule is met in battle at least once (the MVP core hypothesis).

**14. Story flags after battle.** Flags set by a battle are applied in this order:
1. In `on_thawed`: liberation state and off-screen removal (rule 7, step 1).
2. On `transition_finished`: on-screen liberation plays (rule 9).
3. Story Dialogue opens once the on-screen removal has finished, or at once if there is none (`game-state-scene-flow.md` Edge Cases).
4. Stage effects of a new flag wait for the affected map's next load (rule 8).

**15. Save moments.**
- World state holds:
  - map, position and facing;
  - the last camp registered;
  - resolved symbols, opened interactables, granted payoffs;
  - liberated markers and `stage_stored` per map;
  - the interim story flags.
- **Position and facing** are written to world state every frame. Every other field is written when its event happens. Nothing about world state emits a per-frame change signal, and nothing per-frame reaches the save or autosave path.
- The save file itself is written only at Game State's safe moments: in Overworld or Camp, with no overlay except the Menu, and no transition running. This system never writes saves.
- **On load,** if the saved position now lies in a blocked cell (a stage raise activated a blocker there), the leader is moved to the nearest walkable cell by breadth-first search over the walk grid. If none is within 5 m, the leader goes to the map's first EntryPoint.

**16. Gags, clues, teaching and recruit remarks.** The Player Fantasy promises that the squad pokes the occupation, and that each gag is a clue.
- **Gag interactables.** Posters, notices and tape are an `Interactable` kind, `gag`. On `confirm`, a gag gives one of three responses, chosen in data:
  - `line`: a dialogue beat (the joke);
  - `change`: a small state change (a notice torn down, tape cut), saved as opened;
  - `clue`: a faction-rule hint, which also adds a Codex rumour (rule 7a).

  **Every active clutter marker either responds to `confirm` or blocks a route** (Player Fantasy guardrail 4). Purely decorative clutter is set dressing, not a clutter marker.
- **Text in the world is also text on screen.** Every clue poster and decree gag carries its text as a `LocText` string in its record. The sprite's painted text is a bonus. On `confirm`, the Dialogue overlay shows that string verbatim, so it scales with the text-size setting, is localized (ADR-0013) and reaches a screen reader.
- **Faction-rule clue.** Each faction's first-encounter map places at least one clue (its marker tagged `faction_clue`), readable **as on-screen art without interacting**, and legible on the Steam Deck's 7" screen (AC-50b). Interacting adds the joke and the rumour. The clue sits within `interact_reach_m` of a cell on the critical path, and comes before the first notice radius along that path.
  - **Clearance.** To make room for the clue, the first-encounter map's first patrol is at least `safe_radius_m + symbol_chase_m + first_patrol_clearance_m` from the entry along the critical path. Clutter is barred from safe zones, so the clue sits in the band beyond the safe zone and before the first patrol. A civilian NPC inside the safe zone may carry the clue instead.
  - **Wording.** The clue is worded **from the target's side**, because the rule is that an enemy ignores damage until it is Approved. Paris uses a poster reading "UNAPPROVED INJURIES WILL NOT BE PROCESSED", plus a mime gag: a Clerk shrugs off a thrown baguette until a colleague stamps him. The narrative checklist (rule 18) includes a comprehension check.
- **Clerks are optional: the teaching beat.** On the first-encounter map, before the first patrol, a marker tagged `optional_teach` tells the player that Clerks can be avoided ("They won't follow you past the café paving. Union rules."). It is **never gated on `confirm`**: it is a proximity bark from a civilian (shown in an opaque bark window, P14, when the leader comes within `interact_reach_m · 2`; it re-arms once the leader has moved beyond twice that distance, and the speaker also answers `confirm` with the same line) or on-screen art. The speaker stands within `interact_reach_m · 2` of a critical-path cell, before the first notice radius (checked in CI). The first patrol is laid out so the bypass is visibly easy: a straight approach with an obvious side lane (rule 12, `first_bypass_ratio_max`). No tutorial pop-up.
- **Recruit remarks.** Any interactable may carry an optional `recruit_remark` reference. Dialogue/Banter attaches a squad member's comment at that spot. MVP ships at least three remarks in Paris, at least one of which ribs the squad itself (Pillar 2: the squad is fair game too).

**17. The liberated region (presentation override).** Once a map's `region_liberation_flag` is set, that map loads with its **liberated presentation**. The stage value is kept (rule 8), but the presentation layer reverses it:
- the lighting profile becomes the map's `liberated_profile_id` (a `map_` field): for exteriors, the base golden-hour profile with no faction fill; for interiors, the Dungeon row with the fluorescent faction fill removed;
- the stage's set kit is replaced by the map's `liberated_kit_id`. Every faction set-dressing addition is removed, the Paris skyline landmark included (the Eiffel Tower loses its in-trays). The kit keeps at least one grumbler and one "Bureaucratia had a point" item (rule 13);
- civilian density and the ambience bed return to stage 1's;
- every symbol is inactive (rule 9);
- the map name card shows the liberated subtitle (UI Requirements).

Only the maps the last act can reach need both fields: in MVP, the overworld
segment and the Town (checked in CI). The dungeon and the boss chamber are
closed behind the squad (rule 13), so they need neither.

This follows the art bible: "Liberation runs the gradient in reverse. The return of golden-hour light is the reward."

**18. Narrative guardrails and sign-off.**
- **Scope.** The checklist covers every faction × stage content set (clutter, civilians, lines, decree gags), every clue, the story encounter's lines, the recruit remarks, the boss chamber, the post-battle story Dialogue, the liberated set, and every other piece of player-facing overworld text: payoff cards, map names and name-card subtitles, street names, checkpoint denial lines, `objective_text`, barks and the chapter-end prompt.
- **Tone checklist.** Each item in scope ships only after it passes. The narrative-director records the result in `design/gdd/reviews/overworld-narrative-signoff.md`, one entry per item with: item ID, reviewer(s), the ticks below, date, and the reviewed content's hash. The **art-director co-signs (a) and (a2)**, since half of the exclusion list is visual. Which ticks apply depends on the entry:
  - **every entry** ticks (a);
  - **each faction × stage set and each map's liberated set** (the units that hold many items) also ticks (a2) and (b)–(d);
  - **a line-only item** (a decree, a card, a denial line, a bark, a Dialogue) ticks (a) plus a **lines-only composite read**: the composite question of guardrail 6 asked of its text alone;
  - **a clue** also ticks (e).

  The ticks:
  - (a) nothing from guardrail 6's exclusion list;
  - (a2) the composite test (guardrail 6) passes on the set's highest-stage capture plus all its lines;
  - (b) at least one item where Bureaucratia has a point, such as a genuinely orderly queue, or a permit that opens a shortcut;
  - (c) at least one item where the Parisians look ridiculous;
  - (d) at least one item where the squad looks ridiculous;
  - (e) for a clue, a comprehension check: at least 60% of at least 5 playtesters predict the faction rule before their **first Bureaucratia battle** (the wording is fixed in the test plan).
- **Visual brief for decree posters** (input for the art-director): office-memo or in-tray styling, never the layout of occupation-era public notices (black-bordered, bilingual, red-headed). "BY ORDER" is acceptable as text.
- **Fail path.** A set that fails is reworked and re-checked. It does not ship with a waiver.
- **Interim MVP story-flag registry.** Until Dialogue, Banter & Quests is designed, the region's story flags are fixed in this table. The narrative-director owns its content. Every flag a map, checkpoint, marker or Dialogue reads must appear here (checked in CI).

| Flag | Set by | Trigger | Raises a stage? | Player-visible beat | Maps affected |
|---|---|---|---|---|---|
| `permits_mandatory` | ChapterFlow step change | The chapter's opening step, before the player has control (the faction's calendar; no squad action can trigger it) | Yes: overworld segment 1 → 2, before any load of the segment is possible | Decree gags at **both** of the segment's EntryPoints: "PERMITS NOW MANDATORY FOR HAVING PERMITS. IN FORCE SINCE TUESDAY." | Overworld segment |
| `counter_cleared` | Story encounter Victory | The Permit Counter beaten | No | The boom lifts; the Counter Clerk's post-battle line | Dungeon (opens the Counter checkpoint) |
| `form_27b_stamped` | Gag `change` | Stamping a form at the dungeon's self-service stamp kiosk (its fight-free `obtained_at` source) | No | The kiosk thunks; the form shows in the Menu | Dungeon: the requirement of the boss-chamber exit's checkpoint. In MVP that exit **is** gated |
| `paris_liberated` (`region_liberation_flag`) | Boss Victory | Minister of Forms defeated | No (presentation override, rule 17) | Post-battle story Dialogue, then the walk home (rule 13), and the segment's dungeon exit taped off | All Paris maps |

Per-marker `liberation_flag`s in MVP Paris are all `paris_liberated`. A
marker that needs another flag adds it to this table first. The camp decree
(rule 13a) is first-sight-triggered and sets no flag.

**19. Where to go next (navigation assist).** The overworld has no HUD, but the accessibility commitment requires a visible next-destination marker (`design/accessibility-requirements.md`, Navigation assists).
- **Diegetic beacon chain (the committed minimum).** Each leg carries an authored chain of **waypoint beacons**: lantern banners on poles at `beacon_h_m`, with painted cream chevrons brighter than those on optional exits. The last beacon marks the leg's end (rule 0: an exit, the story encounter, the boss or the café camp). Beacons light for the current leg only; banners on other legs are unlit set dressing. `beacon_h_m ≥ wall_h_max + 0.5`, so a banner rises above any wall into the camera's view (invariant I18).
- **Junctions.** Each leg lists authored **junction nodes**: its start EntryPoint, one per room it crosses, and one at every cell of the leg's `L_crit` or `L_bypass` path where the walk grid branches toward a different required or optional end, at every reachable stage. CI checks that the junctions cover every such branch cell, so a level designer cannot leave a choice point unmarked.
- **What it guarantees.** From each junction node, the **next** beacon in the chain is on screen. A per-map, per-leg [VF] walk-in proves it (AC-45e). Nothing is promised between junctions, where there is no choice to make.
- **Optional marker.** A "Show next destination" setting (default off) adds a small screen-edge arrow pointing **along the walk-grid path** to the beacon (never in a straight line through walls). It has a shape glyph, never a colour-only cue. It stays optional: guardrail 5 says the map must be legible without UI.
- **Objective line.** The Menu shows a one-line objective from the current chapter step's `objective_text`. ChapterFlow is the interim source until Dialogue, Banter & Quests is designed.

### States and Transitions

| State | Entry | Exit |
|---|---|---|
| **Exploring** | Placement finishes on map load and the reveal ends (`transition_finished`), or the player returns from any state below | `confirm` on: an NPC, a gag with a `line` or `clue` response, or a checkpoint whose outcome is `redirect` or `queue` → Interacting. A gag with a `change` response → plays its change, stays in Exploring. A checkpoint whose requirement is met → its stamp moment plays, it opens, stays in Exploring. A checkpoint whose outcome is `encounter`, `confirm` on a `confirm`-started Static symbol, or contact with a symbol (rule 5) → EncounterStarting. A CampSpot → CampPrompt, except the café on the chapter's final step, where `confirm` opens the P15 "End the chapter here?" prompt (No focused; Yes ends the chapter, rule 13). A `MapExit` is crossed → MapChanging. `menu`, or focus loss → Paused |
| **Interacting / Dialogue** | The Dialogue overlay opens (NPC, gag line or clue, checkpoint `redirect` or `queue` line) | The overlay closes → Exploring, or → Redirecting for a failed checkpoint. The overlay ends in a request (a story fight) → EncounterStarting |
| **Redirecting** | A failed checkpoint's line closes | Same-instance, input-locked dip-fade (rule 10). The leader, camera and followers are placed under the fade → Exploring on `transition_finished`, with encounter grace started |
| **CampPrompt** | `confirm` on a CampSpot opens the P15 "Rest here?" prompt | Yes → Camp request (the mode exits). No or `cancel` → Exploring. Leaving camp later is a map load (`MapEntryPayload` to the camp's return EntryPoint): the name card, grace and `on_map_reenter` respawns all apply |
| **EncounterStarting** | `start_encounter()` is called | The transition is accepted → Frozen. It is rejected → Exploring, with the touched symbol held in **contact pending** (rule 5), and contact is tested again next frame |
| **Frozen (in battle)** | The battle wipe's out phase starts | `on_thawed(Victory or Fled)` applies rule 7 step 1, then → Exploring on `transition_finished` (rule 7 step 2). Retreat or Quit → the instance is discarded |
| **MapChanging** | An exit request is accepted | The new map finishes placement and is revealed → Exploring. If the new map fails to load, the old one is restored (rollback) |
| **Paused (Menu)** | The Menu opens (player input or focus loss) | The Menu closes → Exploring; mode time resumes |

Symbol sub-states and grace timers advance only in Exploring, so neither the
Menu, Dialogue, the CampPrompt nor any transition uses up grace.

### Interactions with Other Systems

| System | Data in | Data out | Owner |
|---|---|---|---|
| Game State & Scene Flow | Mode and transition announcements, input lock, the `on_thawed` result | Battle, map-change and camp requests (Encounter descriptor, map entry, camp entry); a save-safety query | Game State |
| Input System | `move` vector, `confirm`, `menu` | — | Input |
| Content Data Definitions | `map_`, `enc_` and occupation-stage records | — (validated at boot and in CI) | Content Data |
| Sprite & Camera Presentation | — | The lighting profile resolved per map × faction × stage (or the liberated profile, rule 17), map bounds, the leader's anchor, camera snaps, follower sprites, the notice, chase, stun and liberation cues | Presentation |
| Combo System & Codex (undesigned) | — | Faction-rule rumours from `clue` payoffs and gags (rules 7a, 16) | Combo & Codex (an interim stub line until designed) |
| ChapterFlow (interim chapter source) | The current chapter step: its `objective_text`, its `{map_id, leg_id}`, and step changes that set scheduled flags (rule 18) | — | ChapterFlow, until Dialogue, Banter & Quests is designed |
| Turn Battle System | Outcome: Victory, Fled or Defeat | Encounter descriptor | Shared fields (Game State rule 6) |
| Dialogue, Banter & Quests (undesigned, provisional) | The overlay closed, plus any follow-up request | NPC or checkpoint dialogue reference (an interim stub overlay shows the line) | Dialogue |
| Camp & Party Management (undesigned) | A leave-camp request | Camp entry, and the region's default camp | Camp |
| Squad Roster & Recruitment (undesigned) | Party members and their order | — (leader and followers drawn from that order) | Squad Roster |
| Save/Load & Settings | The restored save (Continue) | The overworld save section: world state, including liberated markers | Save/Load (format); Overworld (content) |
| Faction Reputation & Endings (undesigned) | Flags that may raise a stage (only under rule 8: scheduled, ahead of the player, never a reprisal) or set liberation flags | Liberation and checkpoint events, as reputation inputs | Faction Reputation |
| Onboarding & Tutorial | — | Teaching through placement: Town has no Clerks; the first-encounter map teaches that Clerks are optional and carries the faction-rule clue (rule 16). No tutorial pop-ups | Overworld |

> Specialists consulted (`workflow: full`, review mode `full`):
> - `game-designer` (primary), for the core rules, states and interactions;
> - `level-designer`, for the map chain, density, safe zones, sightlines and map sizes;
> - `world-builder`, for occupation stages, checkpoints, Compliance Clerks, enthusiastic-adopter civilians (renamed from "complicit" in rev 2) and the café camp.
>
> The user decided the four contested calls on 2026-10-22: symbols only, stages raised by story with victories clearing locally, leader plus followers, and the linear Paris chain.

## Formulas

All lengths are in metres on the ground plane (`cell_m` = 1.0). All times are
mode time. Every `data file` value lives in `OverworldConfig` or in the
records (ADR-0012 §9), and none is a literal in code. **Path distance**
(`path_dist`, rule 5) means arc length along an `AStarGrid2D` path over
symbol-legal cells (rule 0) plus the end gaps to the two centres, never a
straight line. **The overworld clock:** every timer, step and formula here uses
`ow_dt = min(delta, dt_max)`, accumulated only in Exploring. That is the
"injectable mode clock" of the test harness.

### Load-time invariants (one list)

Every invariant below is checked at boot and in CI. A failure names the
invariant's ID and the knobs involved, so an out-of-range combination cannot
ship. The formulas that follow refer to these IDs.

| ID | Invariant | Default check |
|---|---|---|
| I1 | `f_patrol < f_chase ≤ 0.85` | 0.6 < 0.8 ≤ 0.85 |
| I2 | `t_escape(2·body_radius) ≤ escape_max_s` (open ground; `symbol_speeds`) | 9.93 ≤ 10 |
| I3 | `(encounter_grace_s − t_react) · (walk_speed − v_chase) ≥ 2·body_radius` | 1.6 × 0.7 = 1.12 ≥ 0.6 |
| I4 | `symbol_giveup_m ≥ symbol_chase_m + 2` | 6.5 ≥ 5 |
| I5 | `flee_grace_s · walk_speed ≥ symbol_giveup_m` | 10.5 ≥ 6.5 |
| I6 | `flee_grace_s ≥ encounter_grace_s` | 3 ≥ 2 |
| I7 | `safe_radius_m > symbol_chase_m + 2·body_radius` | 4.5 > 3.6 |
| I8 | `body_radius < cell_m / 2` | 0.3 < 0.5 |
| I9 | `corner_assist_m ≤ body_radius + 0.1` | 0.25 ≤ 0.4 |
| I10 | `D_min ≤ D_max` for each map type | 150 ≤ 250; 80 ≤ 120 |
| I11 | `walk_speed · dt_max < cell_m` | 0.35 < 1.0 |
| I12 | `0.5 · symbol_chase_m ≤ symbol_notice_rear_m ≤ symbol_chase_m` | 1.5 ≤ 1.5 ≤ 3.0 |
| I13 | `cap(faction, s, k) ≤ cap(faction, s+1, k)` for every kind k | per record |
| I14 | `chase_visibility` valid at 4:3, 16:9 and 21:9 | needs the shipped camera (OQ-1) |
| I15 | `notice_path_cap_m ≥ symbol_chase_m · √2` (it can fail inside the safe ranges, e.g. `symbol_chase_m` 3.5 with a cap below 4.95) | 4.5 ≥ 4.24 |
| I16 | `notice_path_cap_m + walk_speed · notice_delay_s ≤ symbol_giveup_m − 0.5` (the leader walks during the notice delay, so a chase never starts already past give-up) | 4.5 + 1.4 = 5.9 ≤ 6.0 |
| I17 | `turn_pause_s ≥ t_react + (symbol_chase_m − symbol_notice_rear_m) / walk_speed` (a sneak in the rear band can react and walk out of the front radius before the facing flips) | 0.9 ≥ 0.4 + 1.5/3.5 = 0.83 |
| I18 | `beacon_h_m ≥ wall_h_max + 0.5` | 3.5 ≥ 3.0 |

### symbol_speeds

The symbol_speeds formula is defined as:

`v_patrol = f_patrol · walk_speed;  v_chase = f_chase · walk_speed;  t_escape(d0) = max(0, symbol_giveup_m − d0) / (walk_speed − v_chase) + giveup_s`

It is subject to invariants I1–I3.

**Variables:**
| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| walk_speed | float (m/s) | 3.0–4.0 | data file | The leader's full-tilt speed |
| f_patrol | float | 0.4–0.7 | data file | Patrol speed as a fraction of `walk_speed` |
| f_chase | float | 0.7–0.85 | data file | Chase speed as a fraction of `walk_speed` |
| d0 | float (m) | 2·body_radius – (notice_path_cap_m + walk_speed · notice_delay_s) | calculated | `path_dist` between leader and symbol when the chase starts. I16 keeps it below `symbol_giveup_m`, so a chase never starts already given up |
| symbol_giveup_m | float (m) | 6–8 | data file | Path distance the leader must keep for the symbol to give up |
| giveup_s | float (s) | 1.0–2.5 | data file | How long the give-up test must hold without a break |
| t_react | float (s) | 0.3–0.6 | data file | Player reaction time assumed by the grace check (I3) |
| body_radius | float (m) | 0.25–0.40 | data file | Collision radius of the leader and of symbols |
| escape_max_s | float (s) | 8–12 | data file | Longest allowed worst-case escape |
| t_escape | float (s) | calculated | calculated | Time from chase start until the symbol gives up |

**Output Range:** `v_chase < walk_speed` always, so on open ground every chase
can be outrun. `t_escape` is an **open-ground bound**: when the symbol has to
path around walls, its path to the leader is longer and the escape is faster.
Two cases are not open ground, and the rules close both:
- A leader in a dead end ends the chase by reaching a safe zone, or the symbol gives up when its path empties (rule 5).
- A switchback cannot hold a chase open, because give-up uses path distance.

A symbol never chases twice in a row, because Returning is deaf and the
re-notice cooldown follows (rule 5). Untested, the safe ranges could reach
about 19 s; I2 rejects any such combination.

**Why I2 needs no repath term.** `path_dist` (rule 5) is the arc left on the
stored path, plus the gap to where the leader was when that path was
computed, plus the distance the leader has walked since. Each part is a real
route segment (the end gap spans at most one cell next to the target cell), so
`path_dist` is the length of a real route and therefore an upper bound on the
true path distance. A stale or deferred path can only make give-up come
**earlier** than the open-ground bound, never later.

**Example:** `walk_speed` 3.5 m/s, so `v_patrol` = 2.1 and `v_chase` = 2.8 m/s; the party gains 0.7 m/s. `symbol_giveup_m` is 6.5 m.
- **Typical:** the Noticing symbol stands still. The leader turns away during the 0.4 s notice delay, so `d0` = 3.0 + 1.4 = 4.4 m and `t_escape` = 2.1 / 0.7 + 1.5 = **4.5 s**.
- **Worst case** (from contact range, 0.6 m): 5.9 / 0.7 + 1.5 = **9.93 s** ≤ 10.
- **Chase start (I16):** the farthest a chase can start is `notice_path_cap_m + walk_speed · notice_delay_s` = 4.5 + 1.4 = 5.9 m, below give-up (6.5 m) with 0.6 m to spare.
- **Grace (I3):** (2.0 − 0.4) × 0.7 = 1.12 m ≥ 0.6, so the party can get clear during grace even after reacting.

At `f_chase` 0.9 (rejected by I1) the same cases give 7.8 s typical, 19.2 s worst, and a 0.56 m grace gap that fails I3.

### chase_visibility (load-time validation, I14)

The chase_visibility formula is defined per footprint edge `e` (near, far, and the two slanted sides) as:

`see_m = symbol_chase_m + body_radius + (walk_speed + v_patrol) · see_lead_s`
`w_near = h · cos(F_v_eff/2) · tan(F_h/2) / sin(pitch + F_v_eff/2)`
`d_side = (w_near · (a_near + a_far) + a_near · (w_far − w_near)) / L,  L = √((w_far − w_near)² + (a_near + a_far)²)`
`n_side = ((a_near + a_far) / L, (w_far − w_near) / L)`
`R_e = dist_e − (|n_e,x| · dz_x + |n_e,y| · dz_y) − walk_speed · tau`
`R_vis = min(R_near, R_far, R_side)`
`s_blur = see_m + dz_y + walk_speed · tau`
`valid ⇔ R_vis ≥ see_m at 4:3, 16:9 and 21:9  ∧  dof_near_end ≤ d_cam(−s_blur) − H_max · sin(pitch)  ∧  dof_far_begin ≥ d_cam(+s_blur)`

The blur bounds are measured from the **leader**, not from the camera focus:
the leader can sit up to `dz_y + walk_speed·tau` from the focus along the view
axis, so a Clerk `see_m` beyond the leader is up to `s_blur` from the focus.
The near bound also subtracts the tallest actor's height term, because an
upright card's top is nearer the camera than its feet.

Each edge subtracts only the dead zone's reach along that edge's normal. That
reach is `dz_y` for the near and far edges, and the projection
`|n_x|·dz_x + |n_y|·dz_y` for a slanted side. The camera lag is subtracted
from every edge, because the leader can move toward any of them.

**Variables:**
| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| a_near, a_far, w_far, F_v_eff, F_h, h, pitch | float | per `follow_camera` | calculated / data file (presentation) | The overworld camera's ground footprint, from `sprite-camera-presentation.md` `follow_camera` |
| w_near | float (m) | > 0 | calculated | Half-width of the footprint's near edge |
| dist_e | float (m) | > 0 | calculated | Distance from the camera focus to edge e: `a_near`, `a_far` or `d_side` |
| n_e | Vector2 | unit | calculated | Edge e's outward normal on the ground (`(0, 1)` for near and far) |
| dz_x, dz_y | float (m) | — | calculated (presentation) | Dead-zone half-sizes, read as `dz% · w_far` and `dz% · a_near` (OQ-2). Validated at the **shipped** `dz%` |
| tau | float (s) | 0.15–0.18 | data file (presentation) | Camera smoothing constant; `walk_speed·tau` is the steady follow lag. Validated at the shipped value |
| see_lead_s | float (s) | 0.2–0.3 | data file | How long a symbol is on screen before the leader can reach its notice radius. Narrowed in rev 3: at the proposed h 12 m and default dz, tau and other knobs, I14 allows at most about 0.34 |
| see_m | float (m) | calculated | calculated | Distance at which a patrolling symbol must already be on screen |
| d_cam(s) | float (m) | > 0 | calculated (presentation geometry) | **View-space depth** (not Euclidean distance) of the ground point `s` metres from the focus along the view's ground axis. On flat ground depth depends only on that forward offset, so checking along the axis suffices. Godot's DOF depth semantics are confirmed by ADR-0005 Step 1 (OQ-5) |
| s_blur | float (m) | calculated | calculated | Farthest offset from the focus at which a symbol within `see_m` of the leader can be |
| H_max | float (m) | per sprite set | data file (presentation) | Tallest overworld actor's card height |
| dof_near_end, dof_far_begin | float (m) | — | data file (presentation tilt-shift) | Where the near blur ends and the far blur begins |
| R_vis | float (m) | calculated | calculated | Smallest guaranteed on-screen distance from the leader, in any direction |

**Output Range:** pass or fail at every supported aspect. 16:10 lies between
4:3 and 16:9. A failure is a boot and CI validation error naming the aspect and
the edge (or the blur bound) that failed. Sprites are never exempted from
tilt-shift. Instead, the blur bounds keep every point within `see_m` of the
leader sharp.

**Example:** `see_m` = 3.0 + 0.3 + 5.6 × 0.25 = **4.70 m**. The camera is presentation's example (pitch 30°, F_v 20°) with dz 10% and tau 0.17, so the lag is 0.595 m.
- **At h 10 m, FAIL.** At 16:9 and 21:9 the near edge binds: 5.40 − 0.54 − 0.595 = 4.27. At 4:3 the side binds: 4.26.
- **At h 11.5 m, PASS** at all three aspects: 4:3 4.99 (side), 16:9 5.00 (near), 21:9 5.00 (near).
- **At the knob ceilings** (dz 12%, tau 0.18), h 11.5 fails at 4:3 (4.68).
- **Thresholds:** **h ≥ 10.9 m** at the defaults and **h ≥ 11.6 m** at the ceilings. Presentation is asked for **h = 12.0 m**, which passes at any `dz` and `tau` in their safe ranges **at the default overworld knobs** (OQ-1). It does not pass with every overworld knob at its ceiling: `see_lead_s` 0.5 would need h ≥ 13.8 m, which is why its range is now 0.2–0.3. I14 always validates the shipped combination.
- **Blur:** at the defaults `s_blur` = 4.70 + 0.54 + 0.595 = **5.84 m**; the tilt-shift bounds must keep ±5.84 m from the focus sharp, less the `H_max` term on the near side.

The previous revision combined the dead zone as a corner distance. That
over-asked (12.2 m) at 16:9 and still failed at 21:9.

### follower_trail

The follower_trail formula is defined as:

`each frame, walk the leader's segment [p_prev, p_leader] and append a point every trail_sample_m of arc length;  pos_i = point at arc length s_i = i · follower_spacing_m back along [p_leader, trail newest→oldest];  N_buf = ⌈n_f · follower_spacing_m / trail_sample_m − ε⌉ + 2`

**Variables:**
| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| n_f | int | 0–3 | calculated (roster size − 1) | Number of followers |
| follower_spacing_m | float (m) | 0.7–1.1 | data file | Arc-length gap between neighbours |
| trail_sample_m | float (m) | 0.05–0.25 | data file | Distance between recorded trail points |
| ε | float | 1e-6 | constant | Guards the ceiling against floating-point round-up |
| s_i | float (m) | 0–3.3 | calculated | Arc distance of follower i behind the leader |
| pos_i | Vector2 | — | calculated | Follower i's position (linear interpolation along the trail) |
| N_buf | int | ≤ 68 | calculated | Trail buffer length |

A follower faces from `pos_i` toward the trail point at `s_i − trail_sample_m`,
with a flip hysteresis of `trail_sample_m`. Followers move with the leader's
travelled distance, not with time, so they stop when the leader stops and
never bunch up.

**Output Range:** the train is at most 3.3 m long. Points are sub-sampled
inside each frame's segment, so spacing never exceeds `trail_sample_m`,
however long the frame is. A follower therefore cuts a corner by at most
`trail_sample_m / 2` (0.075 m at default).

**Example:** spacing 0.9 and sample 0.15 with 3 followers give `N_buf` = 20. Follower 3 trails 2.7 m behind. Round a 90° corner, follower 2 is still on the leader's path, 1.8 m back. On a 0.10 s frame the leader moves 0.35 m and two points are appended, 0.15 m apart.

### symbol_density (level-review budget)

The symbol_density formula is defined as:

`N_min = round_half_up(W / D_max(type)),  N_max = round_half_up(W / D_min(type));  require N_min ≤ N_sym(stage) ≤ N_max;  r_c = symbol_chase_m + body_radius;  coverage = Σ_j (π · r_c² + 2 · r_c · L_patrol,j) / (W · cell_m²)`

**Variables:**
| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| W | int | > 0 | calculated (walk grid) | Walkable cells on the map (a count, so never fractional) |
| D_min, D_max | int (cells per symbol) | overworld 150 / 250, dungeon 80 / 120 | data file | Density band per map type. The Town has no band: it must hold 0 symbols |
| N_sym(stage) | int | ≥ 0 | calculated | Active non-boss, non-story symbols, checked at every reachable stage |
| L_patrol,j | float (m) | ≥ 0 | calculated | Length of symbol j's patrol path (closing segment included) |
| coverage | float | 0–1+ | calculated | Share of walkable area inside the symbols' notice bands, ignoring overlap (an observation, not a gate) |

**Output Range:** a count band per map. The Town is 0. The boss chamber holds
the boss only. Every other map holds at least one symbol (`N_min` is raised
to 1 when the rounding gives 0), so the pressure floor and the payoff share
are never empty. `W` counts baked walkable cells, `SAFE` cells included.
Coverage is reported per map. It uses the front radius `r_c` and ignores the
smaller rear radius and overlap, so it overstates the true coverage. The bypass and pressure checks
(rule 12) are the gates, not coverage.

**Example:**
- Overworld segment 40×30 m, 60% walkable: W = 720, so **3–5** symbols. 4 symbols with 6 m patrols cover (34.2 + 39.6) × 4 / 720 = **41%**.
- Dungeon 25×50 m, 45% walkable: W = 563, so **5–7** symbols. 6 symbols with 6 m patrols cover **79%** before overlap and walls trim it. So dungeon Clerks need short patrols in wide rooms, and the pressure floor (rule 12) keeps some of them on the path.

### occupation_stage

The occupation_stage formula is defined as:

`stage_new = clamp(max({base_stage} ∪ { s : (f, s) ∈ stage_table, f ∈ flags }), 1, 3);  stage = max(stage_new, stage_stored);  stage_stored ← stage` (computed only on map load)

The union with `{base_stage}` defines the empty case: with no table flag set, `stage_new` = `base_stage`.

**Variables:**
| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| base_stage | int | 1–3 | data file (`map_` record) | The map's starting stage (Paris: Town 1, overworld segment 1 raised to 2 before first entry, dungeon 3) |
| stage_table | {flag → int} | values 1–3 | data file (`map_` record) | Story flags that raise the stage |
| flags | set | — | calculated (world state) | Story flags set so far |
| stage_stored | int | 0–3 (0 = never loaded) | calculated (world state, saved) | The highest stage applied so far |

**Output Range:** an integer 1–3 that never decreases. Maps with no
`base_stage` (camp interiors, the boss chamber) have no stage. A map's
**reachable stages** are the stages it can have on **any load the ChapterFlow step list allows**: CI walks the step list in order, takes the flags set before each step in which the map can be loaded, and applies the formula. Every check that says "at every reachable stage" uses this set.
The liberated presentation (rule 17) does not change the stage.

**Example:** the overworld segment has `base_stage` 1 and the table {`permits_mandatory`: 2}. `permits_mandatory` is set on the chapter's opening step, before any step in which the segment can be loaded, so on its first load `stage_new` = 2 and `stage_stored` (0, never loaded) becomes 2. Its reachable stages are {2}; stage 1 is never shown, and CI does not validate stage-1 content for it.

### marker_activation

The marker_activation formula is defined as:

`E_k = [m of kind k with m.min_stage ≤ stage], sorted by (min_stage, marker order);  slot(m) = index_in(E_k, m) < cap(faction, stage, k);  visible(m) = slot(m) ∧ m ∉ liberated(map) ∧ ¬region_liberated(map)`

Sorting by `min_stage` first means markers that become candidates at a new
stage always join the end of the list, so they never displace a marker that
already held a slot. Decree gags are their own kind and are not capped
(rule 8).

**Variables:**
| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| min_stage | int | 1–3 | data file (marker) | Lowest stage at which the marker is a candidate |
| cap(faction, stage, k) | int | ≥ 0, non-decreasing in stage (I13) | data file (faction × stage record) | How many markers of kind k may be active |
| marker order | int | unique | data file (scene child order) | A total order, so ties cannot happen |
| liberated(map) | set | — | calculated (world state) | Liberated marker IDs |
| region_liberated(map) | bool | — | calculated (flags, every load) | The map's `region_liberation_flag` is set |

**Output Range:** 0 to `cap` visible markers per kind. A liberated marker
**keeps its slot**, so liberating it never pulls in a replacement, and the
street visibly empties. Caps never fall as the stage rises (I13), so a marker
that is visible at one stage keeps its slot at the next.

**Example:** stage 2, poster cap 4. Posters in marker order, with `min_stage` in brackets: P1(1), P2(2), P3(3), P4(1), P5(2), P6(1).
- At stage 2, `E` sorted is P1, P4, P6, P2, P5. P1, P4, P6 and P2 take the four slots, and P5 stays hidden.
- Liberating P2 leaves 3 posters showing. P5 stays hidden: a liberated marker keeps its slot.
- At stage 3 with cap 4 (I13 allows an equal cap), `E` is P1, P4, P6, P2, P5, P3. The same four keep their slots, and P3 joins only past them.
- At stage 3 with cap 7, all six are candidates and the five not liberated show.
- Once `region_liberated`, none show.

### frame_step_safety (load-time validation, I11) and swept contact

The frame_step_safety formula is defined as:

`walk_speed · dt_max < cell_m`
`contact ⇔ min over t ∈ [0, 1] of |(c_L0 − c_S0) + t · (Δ_L − Δ_S)| ≤ 2 · body_radius`

The second line is the swept contact test (rule 5). `c_L0` and `c_S0` are the
centres of the leader and the symbol at the start of the frame, and `Δ_L`,
`Δ_S` are this frame's displacements. The minimum is the closest approach of a
segment to the origin, which costs one dot product per pair: with
`a = c_L0 − c_S0` and `b = Δ_L − Δ_S`, `t* = clamp(−(a·b) / |b|², 0, 1)`. When
`|b|² < 1e-8` (neither body moved relative to the other, for example a
Noticing Clerk and a still leader), the distance is `|a|`.

**Variables:** `dt_max` is Presentation's knob (`sprite-camera-presentation.md`
Tuning Knobs, 0.05–0.10 s, shared with the follow camera). It is **referenced,
not duplicated**: the Overworld reads Presentation's value. The other variables
are as defined above.

**Output Range:** pass or fail. The first line rules out a slow frame carrying
the leader through a one-cell wall. The swept test rules out a grazing pass
between the leader and a symbol at any approach angle, so no separate speed
limit is needed for contact.

**Example:** 3.5 × 0.10 = 0.35 < 1.0: **PASS**. A leader and a symbol crossing at right angles, 0.35 m and 0.28 m per frame and 0.5 m apart sideways, would miss a test made only at the frame's end. The swept test catches them.

### chapter_walk_budget (level-review budget)

The chapter_walk_budget formula is defined as:

`T_walk = k_tort · Σ_legs max_stage L_bypass(leg, stage) · passes(leg) / walk_speed;  walk_share = T_walk / T_chapter ≤ walk_share_max`

**Variables:**
| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| L_bypass(leg, stage) | float (m) | — | calculated (walk grid, rule 12) | A leg's bypass-lane length at a stage (the route an avoiding player walks), taken at its maximum over the map's reachable stages |
| passes(leg) | int | 1–3 | calculated (ChapterFlow step list) | How many ChapterFlow steps name that leg. Counted from the data, never typed by hand |
| k_tort | float | 1.2–1.8 | data file | Allowance for exploring, escapes, redirects and walk-backs that the critical path does not include |
| T_chapter | float (s) | 2700–3600 | data file (concept target: 45–60 min) | Chapter length |
| walk_share_max | float | 0.10–0.20 | data file | Largest share of the chapter spent walking |

**Output Range:** `walk_share` runs from 0 to 1; the gate is `walk_share_max`
(default 0.15). The formula is a planning budget. AC-48 checks the real
share in playtests.

**Example** (rev 4 chain; each term is one step's leg, and boss retries are covered by `k_tort`, never counted as passes): Town entry to segment exit 35 m, segment 60 m, dungeon 110 m, boss chamber 10 m, then the last act's two steps: segment dungeon-side entry to Town 60 m, and Town to the café 35 m. Total 310 m. With `k_tort` 1.4 at 3.5 m/s that is 124 s, or **3.4–4.6%** of the chapter. At 3.0 m/s it is **5.4%**; at the extreme `k_tort` 1.8 and 3.0 m/s, **6.9%**. The last act alone is 95 m, about **27 s** of walking, under its 60 s target (rule 13). The margin under 15% is what allows rule 1 to drop a run button, pending the playtest.

> Formulas first proposed by `systems-designer` at authoring. Two changes from the game-designer's first values (autonomous, logged):
> - `f_chase` went from 0.9 to **0.8**: escape from contact fell from 16.9 s to 9.2 s.
> - `symbol_chase_m` went from 3.5 to **3.0 m**: it leaves room for bypass lanes at 4–6 m junctions.
>
> Rev 2 (design review 2026-10-23) applied the systems-designer, ai-programmer and godot-specialist findings: one invariant list, path-distance give-up, per-edge `chase_visibility` with 21:9 and blur bounds, swept contact, capsule coverage, sub-sampled trail, and the empty-set stage case.
>
> Rev 3 (second review, 2026-10-23): a defined `path_dist` (an upper bound, so I2 stands), I16 (`notice_path_cap_m` default 9 → 5, which ends the notice/give-up loop), I17 (turn pause), blur bounds measured from the leader with the card-height term, `see_lead_s` narrowed to 0.2–0.3, marker slots sorted by `min_stage`, the swept-contact zero case, `N_min ≥ 1`, and a walk budget counted from the step list.
>
> Rev 4 (third review, 2026-10-23): `path_dist` redefined as a real route length (arc + gap at compute time + leader travel since), I16 now includes the notice-delay walk (`symbol_giveup_m` 6 → 6.5, `notice_path_cap_m` 5 → 4.5), I17 tied to the rear-band escape time (`turn_pause_s` 0.9), I18 for the beacon height, and reachable stages derived from the step list.

## Edge Cases

Each frame in Exploring runs in this order, on `ow_dt` (Formulas):
1. move the leader;
2. check map exits;
3. step the symbols, in marker order;
4. check contact (swept, `frame_step_safety`), reading eligibility after the steps;
5. check interaction requests.

All overworld logic, the follow camera and the sprites run in `_process`;
nothing runs in `_physics_process`. `process_priority` sorts every node
globally, whatever the tree order, so the values are pinned: `OverworldMode`
−10, `FollowCamera` 0, `CharacterSprite`s +10. The camera therefore never lags
a frame behind and never adds `walk_speed·dt` to the `chase_visibility` lag
term.

**One clock.** Sprite animation is driven from `ow_dt` too (the sprite's frame
and progress are advanced by the mode, or its animation player runs in manual
mode with `advance(ow_dt)`), so animation never drifts from logic, however many
hitches occur.

Notice searches, repaths and Returning paths share `repath_per_frame_max` per
frame through the round-robin cursor (rule 5): the oldest deferred request goes first. A deferred repath keeps its old path
(pending, never empty); a deferred notice query means no notice that frame.

**Walk-grid pathing setup.** On 4.7.2 (probed), `AStarGrid2D.update()`
rebuilds the grid only when it is dirty, which only `region`, `cell_size` or
`offset` changes cause; that rebuild clears every solid flag and weight. A
query on a dirty grid returns an empty path silently. So: `update()` is called
once, at bake; those three properties are never changed afterwards; walls,
`SAFE` cells and active blockers are applied after it; every later change goes
through `set_blocked()` (a batched `set_blocked(cells, on)` with one component
relabel per frame); and debug builds assert `not is_dirty()` before every
query (ADR-0012 amendment).

- **If contact and a MapExit crossing happen on the same frame**: the exit request wins, and contact is not checked that frame. This cannot happen in shipped maps: exits sit inside safe zones, where contact does not count (rule 12).
- **If `start_encounter` is rejected** (a transition is already running): nothing changes. The symbol is held in contact pending (rule 5), and contact is tested again next frame while the two still overlap. The rejection is logged once per contact, not once per frame.
- **If two symbols touch the leader on the same frame**: the symbol with the smaller closest-approach distance starts the encounter. On an exact tie, the earlier one in marker order does. MVP battles never merge symbols. The other symbol is switched to Returning when grace starts (rule 7).
- **If a symbol overlaps the leader during grace**: nothing happens: a Noticing or Chasing symbol was switched to Returning when grace started, and a Patrol symbol stays in Patrol but cannot make contact during grace. Contact counts again only after grace ends, and only if that symbol has re-entered Patrol, Noticing or Chasing by then.
- **If a stunned symbol overlaps the leader**: nothing happens. Stunned symbols are intangible (rule 5).
- **If a chase path is empty** (the leader stands somewhere a symbol cannot reach, and no repath is pending): the give-up test counts it as "beyond" (rule 5). The symbol stands still and gives up after `giveup_s`, then returns. It cannot re-notice that leader at once, for three reasons: Returning is deaf and the cooldown follows; the notice test needs a reachable path; and I16 keeps the notice range inside the give-up range. So a fence never makes the notice cue flicker.
- **If a symbol's first repath is deferred**: it chases along the notice test's path, which is pending, not empty. The give-up timer does not start.
- **If the resume point is unreachable** (for example, a blocker became active behind the symbol): the symbol holds still, deaf, until the map reloads, and logs one warning.
- **If the leader stands just inside a safe zone with a Clerk at the edge**: the Clerk gives up after `giveup_s` (rule 5) and walks away. It never camps at an exit or a camp.
- **If the flee push meets a wall, a blocked cell, a safe zone or another symbol**: the push is applied instantly in `on_thawed`, under the wipe. The symbol moves one cell at a time along the leader-to-symbol line, stepping **4-connected** (never diagonally between two blocked corners), and stops at the first cell that is not symbol-legal (0 to `flee_push_m`). Static symbols are never pushed. Symbols do not collide with each other, so another symbol does not stop it. If the two centres coincide, the push goes along the direction opposite the leader's facing. The leader is never moved. The stun still lasts `flee_grace_s`, so escape holds even with no push (I5).
- **If the map changes, or the leader is teleported or redirected**: the trail is cleared and the followers snap into formation. The trail is filled with points behind the leader (opposite its facing) along walkable cells. If a wall blocks, the remaining followers stack at the last walkable point.
- **If the party has one member**: there are no followers. The trail is still recorded, so a recruit who joins mid-visit appears correctly.
- **If a flag would lower a stage** (a flag removed, a migration, a data error): `stage = max(stage_new, stage_stored)`, so the stage holds, and a development warning is logged.
- **If two markers compete for the last cap slot**: marker order is a total order, so the earlier marker takes it.
- **If a liberated marker's symbol respawns**: the marker stays liberated. Beating the respawned Clerk again liberates nothing new and grants no payoff (rule 7a).
- **If a checkpoint's requirement is already met when the map loads**: it stays closed until `confirm`. On `confirm` it opens with no failure branch, and the stamp moment is the joke.
- **If a stage raise activates a blocker on the saved position**: on load the leader moves to the nearest walkable cell (rule 15). If none is within 5 m, the leader goes to the map's first EntryPoint.
- **If a blocker is freed while a symbol's path ran round it**: `set_blocked` invalidates stored paths and the notice cache, and updates the component labels. The symbol's next repath (in its stagger turn) uses the freed cells. Nothing is recomputed out of turn.
- **If a frame takes longer than `dt_max`**: movement, symbols and every timer advance by at most `dt_max`. The swept contact test still checks the whole step. Timers run slower in wall time on that frame only.
- **If the window is resized**: Presentation recomputes the footprint. `chase_visibility` is checked at 4:3, 16:9 and 21:9, so no supported aspect breaks it. Aspects narrower than 4:3 are unsupported, and a warning is logged.
- **If the Menu opens mid-chase** (focus loss included): `ow_dt` stops accumulating, so the chase, notice, give-up, cooldown and grace timers freeze and resume exactly where they were.
- **If the player saves mid-chase, then Continues**: per-visit symbol state is not saved. On Continue, symbols start at their patrol origins in Patrol, and `on_map_reenter` respawn is **not** applied. Encounter grace starts on the reveal of **every** map load.
- **If a patrol would pass over a MapExit, EntryPoint or CampSpot**: CI rejects any patrol **segment** within `safe_radius_m` of one, the closing segment of a `loop` path included. At runtime, symbols cannot enter `SAFE` cells at all.
- **If an MVP `map_` record has `zone_rate > 0`**: CI fails. At runtime the value is treated as 0 and an error is logged.
- **If the boss is defeated**: `respawn = never` is written to world state in `on_thawed`. A Retreat in any later fight discards only the frozen overworld, so the boss stays resolved, after a Continue too.
- **If the party loses to the boss**: Retry or Retreat (`retreat_allowed` is true). Retreat leaves the boss unresolved and goes to the last camp registered, which is the pre-dungeon camp, since the leader must pass it to reach the boss (rule 13a). A Fled result against the boss is impossible, because Game State refuses Flee when `can_flee` is false.
- **If the squad flees the story encounter**: the Permit Counter is not stunned or pushed. The leader is placed at its return marker under the wipe, and the "number called" line plays on the reveal (rule 13a). The checkpoint stays closed, and only a new `confirm` restarts the fight.
- **If the boss falls and the player is still in the boss chamber**: the walk home (rule 13) always follows the post-battle Dialogue. The walk home lands at the overworld segment's dungeon-side entry with the dungeon exit taped off, so the chapter cannot end without the liberated streets and Town being shown.
- **If Retreat happens before any camp is registered**: the party goes to the Town café, Paris's default camp (`game-state-scene-flow.md` Edge Cases).
- **If the Map name card and a story Dialogue are both due on the same load**: the Dialogue waits until the card has faded (UI Requirements).

> Edge cases first proposed by `systems-designer`. Rev 2 adds the cases raised by the ai-programmer, godot-specialist and level-designer at review. Rev 3 adds the second review's cases (pending paths, 4-connected push, pathing setup, process order, the walk home).

## Dependencies

**Upstream (this system depends on):**

| System | Hard / Soft | Interface | Status |
|---|---|---|---|
| Game State & Scene Flow | Hard | Mode lifecycle, freeze and thaw around battles (`on_thawed`), transition requests (battle, map change, camp), input lock, Menu pause, safe save moments, the Retry/Retreat contract and the default-camp rule | Designed (`game-state-scene-flow.md`); ADR-0002 Accepted |
| Input System | Hard | `move` vector, `confirm`, `menu`; pointer ignored in the overworld | Designed (`input-system.md`); ADR-0003 Accepted |
| Content Data Definitions | Hard | `map_`, `enc_` and occupation-stage records (new types, ADR-0012); generic reference validation | Designed (`content-data-definitions.md`); ADR-0001 Accepted. **Rule 1's record-type list needs `map_`, `enc_` and occupation-stage types** |
| Sprite & Camera Presentation | Hard | Follow camera (bounds, anchor, snap on teleport), `CharacterSprite` for the leader, followers, Clerks and civilians, upright-card occlusion, lighting profiles per faction × stage, comfort settings | In Review (`sprite-camera-presentation.md`); ADR-0005 Accepted. **This GDD settles its Open Question 6** |
| Squad Roster & Recruitment | Hard (provisional) | Party members and their order (leader, followers, battle party) | Not designed. Until it is, ADR-0012 §5's interim party source (ChapterFlow's) supplies the party |
| Dialogue, Banter & Quests | Soft (provisional) | NPC and checkpoint dialogue overlay; story flags | Not designed. An interim stub overlay shows a single line; story flags live in world state until Dialogue claims them |
| Turn Battle System | Hard (via Game State) | Consumes the Encounter descriptor; reports Victory / Fled / Defeat | Reverse-documented (`turn-battle-system.md`); ADR-0010 Accepted. No direct call between the two systems |
| Combo System & Codex | Soft (provisional) | Receives faction-rule rumours from `clue` payoffs and gags (rules 7a, 16) | Not designed (MVP). Until it is, an interim stub dialogue line shows the hint |
| ChapterFlow (interim) | Soft (provisional) | The current chapter step: its `objective_text` and which critical-path exit is next (rule 19) | Built (`src/chapters/`). Replaced by Dialogue, Banter & Quests when designed |
| Accessibility requirements | Hard (standard) | Navigation assist (next-destination marker), no held or timed input, colour-only and SFX audits | `design/accessibility-requirements.md` (Standard tier). Rule 19's diegetic beacon is the committed minimum, with the guarantee it states (the next waypoint beacon on screen from every junction node, AC-45e); the screen-edge arrow is an optional extra |

**Downstream (depend on this system):**

| System | Hard / Soft | What it needs from the Overworld |
|---|---|---|
| Camp & Party Management | Hard | Camp spots, the region default camp, the return point when leaving camp |
| Save/Load & Settings | Hard | The `overworld` save section (world state: map, position, resolved symbols, opened interactables, liberated markers) |
| Faction Reputation & Endings | Soft | Liberation and checkpoint events; may set flags that raise stages or liberate markers |
| Dialogue, Banter & Quests | Soft | NPC spawns and dialogue references; story flags (moved out of world state when Dialogue is designed) |
| Onboarding & Tutorial | Soft | Teaching through placement (no Clerks in Town; the first Clerk visible with a bypass lane) |
| Audio Manager | Soft | Event hooks: notice, chase, contact, liberation, map ambience per stage |

**Bidirectional consistency (follow-ups for other documents):**
- `game-state-scene-flow.md` lists Overworld as a dependent (Dependencies table, "Hard"). Consistent.
- `input-system.md` lists Overworld as a consumer of `move` and `confirm`. Consistent.
- `sprite-camera-presentation.md` lists Overworld as a **provisional** dependent ("no GDD"). Its dependency row and Open Question 6 should now point here.
- `content-data-definitions.md` Rule 1 must add `map_`, `enc_` and occupation-stage record types (already noted in architecture review 22b).
- `systems-index.md` row 11: Needs Revision (second review 2026-10-23) → In Review after rev 3 → Approved after re-review.
- `game-state-scene-flow.md` rule 9 records the last camp only on camp *entry*. Rule 13a also registers it when the leader *passes* a CampSpot (OQ-18).
- `sprite-camera-presentation.md` and ADR-0005: lighting resolved per map × faction × stage, plus the liberated profile (rule 17); the travelling interior light (Visual/Audio); and tilt-shift blur bounds instead of a sprite exemption (`chase_visibility`). See OQ-5.
- `design/accessibility-requirements.md`: the Navigation assists row can point at rule 19 (OQ-7).

## Tuning Knobs

All knobs live in `OverworldConfig` (project config) or in the records, never as code literals. The **Invariants** column names the load-time checks (Formulas, I1–I18) that bound each knob beyond its own safe range.

| Knob | Default | Safe range | Source | Too low | Too high | Invariants |
|---|---|---|---|---|---|---|
| walk_speed | 3.5 m/s | 3.0–4.0 | OverworldConfig | Walking takes a bigger share of the chapter (`chapter_walk_budget`) | Camera lag grows; `chase_visibility` tightens | I1–I3, I5, I11, I14, I16, I17 |
| cell_m | 1.0 m | 1.0 (fixed in MVP) | OverworldConfig | — | — | I8, I11 |
| body_radius | 0.3 m | 0.25–0.40 | OverworldConfig | Sprites visibly overlap walls | Doorways jam | I3, I7, I8, I9 |
| corner_assist_m | 0.25 m | 0–0.4 | OverworldConfig | Snags on corners | Visibly cuts through walls | I9 |
| dt_max | *Presentation's* | 0.05–0.10 s | `sprite-camera-presentation.md` | — | Breaks `frame_step_safety` | I11 |
| follower_spacing_m | 0.9 m | 0.7–1.1 | OverworldConfig | Followers overlap (> ~30% silhouette) | The train blocks the view in 2 m corridors | — |
| trail_sample_m | 0.15 m | 0.05–0.25 | OverworldConfig | Larger buffer (negligible cost) | Followers visibly cut corners | — |
| interact_reach_m | 1.2 m | 1.0–1.5 | OverworldConfig | `confirm` fails when the leader is adjacent | Reaches targets across a 2 m corridor | — |
| f_patrol | 0.6 | 0.4–0.7 | OverworldConfig | Patrols read as idle | Patrols read as chases | I1 |
| f_chase | 0.8 | 0.7–0.85 | OverworldConfig | Chases carry no threat | Escapes run long | I1, I2, I3 |
| symbol_chase_m | 3.0 m | 2.5–3.5 | OverworldConfig | Clerks feel blind | Fails `chase_visibility`; no room for bypass lanes | I4, I7, I12, I14, I15 |
| symbol_notice_rear_m | 1.5 m | 1.5–3.0 | OverworldConfig | Sneaking behind a Clerk is free | Sneaking is impossible (equal to the front) | I12 |
| notice_path_cap_m | 4.5 m | 4.3–5.0 | OverworldConfig | A Clerk ignores a leader round a corner | A chase starts already past give-up (I16) | I15, I16 |
| renotice_cooldown_s | 3 s | 2–5 | OverworldConfig | Give-up and re-notice loop | A Clerk ignores a leader walking straight into it | (I16 is the structural guard) |
| see_lead_s | 0.25 s | 0.2–0.3 | OverworldConfig | A Clerk pops in right at its radius | Needs a higher camera (about 0.34 is the ceiling at h 12 m) | I14 |
| notice_delay_s | 0.4 s | 0.3–0.6 | OverworldConfig | The notice cue goes unread | A free 2 m head start makes escape trivial | I16 |
| t_react | 0.4 s | 0.3–0.6 | OverworldConfig | Grace check too optimistic | Over-constrains grace | I3 |
| repath_s | 0.5 s | 0.25–1.0 | OverworldConfig | CPU (small) | The chase lags around corners | — |
| repath_per_frame_max | 2 | 1–4 | OverworldConfig | Chases lag when many Clerks chase at once | Frame spikes when many repath at once | — |
| symbol_giveup_m | 6.5 m | 6–8 | OverworldConfig | Notice and give-up flicker | Long chases | I2, I4, I5, I16 |
| giveup_s | 1.5 s | 1.0–2.5 | OverworldConfig | Give-up flicker | Adds directly to escape time | I2 |
| escape_max_s | 10 s | 8–12 | OverworldConfig | Over-constrains the other knobs | Allows tedious chases | I2 |
| flee_grace_s | 3 s | 2–4 | OverworldConfig | Re-caught right after fleeing | Fleeing is risk-free | I5, I6 |
| flee_push_m | 2 m | 1–3 | OverworldConfig | The symbol re-overlaps at once | Pushes into walls and gets truncated | — |
| encounter_grace_s | 2 s | 1.5–3 | OverworldConfig | Fails the grace check | A second Clerk is free to dodge | I3, I6 |
| safe_radius_m | 4.5 m | 4.0–6.0 | OverworldConfig | Patrols crowd exits and camps | Patrols have no room on small maps | I7 |
| first_patrol_clearance_m | 3 m | 2–5 | OverworldConfig | No room for the faction-rule clue (rule 16) | The first-encounter map runs long | — |
| bypass_ratio_min | 1.2 | 1.1–1.5 | OverworldConfig | Dungeon bypasses are trivial | Avoiding every Clerk becomes a slog | — |
| first_bypass_ratio_max | 1.1 | 1.05–1.2 | OverworldConfig (level review) | — | The teaching bypass is not visibly easy (rule 16) | — |
| turn_pause_s | 0.9 s | 0.9–1.4 | OverworldConfig | A sneak gets caught by a turn they could not react to | Patrols read as idle | I17 |
| entry_clearance_m | 1.0 m | 0.5–2.0 | OverworldConfig (level review) | A held `move` bounces the leader back out | Wasted space at every entry | — |
| story_sight_m | 12 m | 8–16 | OverworldConfig (level review) | The story encounter is not in view from its camp | The camp sits far from the fight | — |
| beacon_h_m | 3.5 m | 3.0–4.5 (and ≥ `wall_h_max` + 0.5) | OverworldConfig (level review) | The banner is hidden by the camera pitch | Banners crowd the skyline | I18 |
| wall_h_max | 2.5 m | 2.0–3.0 | OverworldConfig (level review) | Interiors read as low | Walls hide patrols inside `see_m` | I14 (level review), I18 |
| D_min / D_max, overworld | 150 / 250 | 120–300 | OverworldConfig | Too crowded; bypass lanes vanish | An empty segment | I10 |
| D_min / D_max, dungeon | 80 / 120 | 60–150 | OverworldConfig | Too crowded | No dread | I10 |
| k_tort | 1.4 | 1.2–1.8 | OverworldConfig | Underestimates walking | Over-constrains map sizes | — |
| walk_share_max | 0.15 | 0.10–0.20 | OverworldConfig | Shrinks the maps | Walking becomes a chore | — |
| liberation_duration_s | 1.0 s | 0.6–1.5 | OverworldConfig | The removal is missed | The payoff drags; the player waits | — |
| liberation_grumble_min | 0.2 | 0.1–0.4 | occupation-stage record | Liberation reads as one-sided (Pillar 2) | The payoff reads as unwelcome | — |
| name_card_s | 2.0 s | 1.5–3.0 | OverworldConfig | The card is missed | It lingers over the scene | — |
| prompt_min_px | 12 px | 10–16 | OverworldConfig (UI, on the 640×360 canvas, ADR-0008) | The pip is unreadable on the Steam Deck's 7" screen | The pip hides the target | — |
| return_safe_radius_m | 1.5 m | 1.0–2.0 | OverworldConfig (level review) | A redirect can land next to a patrol | The disc swallows the patrol area near a gate | — |
| text_hold_base_s, text_hold_per_word_s | 1.0 s, 0.3 s | 0.8–1.5, 0.25–0.4 | OverworldConfig (UI) | Timed text cannot be read on the Deck | Cards linger over the scene | — |
| zone_rate | 0 (every MVP map) | 0 in MVP | `map_` record | — | Any value > 0 fails CI in MVP (symbols only) | — |
| base_stage, stage_table | per map | 1–3 | `map_` record | — | — | — |
| Stage parameters (caps, civilian density, fill weight, sky card, kit, ambience) | per faction × stage | see Visual/Audio | occupation-stage record | — | — | I13 |

**How the knobs interact:**
- **Escape:** `f_chase`, `walk_speed`, `symbol_giveup_m` and `giveup_s` jointly bound `escape_max_s` (I2). `f_chase`, `encounter_grace_s` and `t_react` are tied by the grace check (I3). Fleeing needs `flee_grace_s` long enough to walk out of give-up range (I5) and at least as long as grace (I6).
- **Visibility:** `symbol_chase_m`, `see_lead_s`, `walk_speed`, `f_patrol` and the presentation camera's h, pitch, F_v, dz and tau are bound together by `chase_visibility` (I14), as are the tilt-shift blur bounds. Raising `walk_speed` costs visibility twice: once in the lead distance and once in the camera lag.
- **Sneaking:** `symbol_notice_rear_m` trades sneak space against threat (I12).
- **Safe zones:** `safe_radius_m` must exceed `symbol_chase_m` + 2·`body_radius` (I7).
- **Density and lanes:** `symbol_chase_m`, the density band and patrol lengths together set coverage (`symbol_density`). Raising any of them makes bypass lanes harder to keep. `bypass_ratio_min` pushes the other way in the dungeon.

## Visual/Audio Requirements

**[A11Y]** marks an accessibility-relevant item (`design/accessibility-requirements.md`, Standard tier). Every cue has a non-color backup, and every sound has a visual twin.

### Event feedback

| Event | Visual | Notes |
|---|---|---|
| **Clerk notice** [A11Y] | A cream paper-slip pop-up with an ink "!" appears above the Clerk (rectangular, Bureaucratia's shape vocabulary), together with a notice pose: clipboard snaps up, head turns toward the leader | Holds for `notice_delay_s`, then shrinks to a small "!" tag that stays above the Clerk through Chasing until it gives up. The chase state is therefore readable as a still image. Never flashes, never tint-only |
| **Chase** | A hurried walk with the clipboard held forward, a small paper trail behind, and the small "!" tag | No radius ring; visibility comes from rule 12. Reduce Motion stills the paper trail; the "!" tag stays |
| **Stun after Fled** [A11Y] | The Clerk sits amid scattered papers while 2–3 form slips orbit his head for `flee_grace_s` | Read from the **seated pose and the scattered papers**, which are static. The orbiting slips are extra motion. Under Reduce Motion the slips hold still and the pose still reads |
| **Contact → battle** | The Clerk holds his notice pose for one beat, then Game State's battle wipe plays | For a Bureaucratia encounter the wipe may use Stamp Red and a stamp / form-page shape (presentation rule 11), through the flash gate. Followers snap into formation under the wipe |
| **Local liberation** (the visible reward) | Starts on `transition_finished`, once the street is revealed (rule 7 step 2). Posters peel and flutter down as cream paper. Queue civilians react, mixed: at least `liberation_grumble_min` of them grumble that the queue was the only orderly thing in Paris, and the rest are pleased in a small, individual way, such as a shrug, a stretch or a nod. There is no crowd tableau (guardrail 6). Then they walk off to new idle spots or doorways. A checkpoint lifts its boom, the tape snaps, and the booth sign flips to a shape-based "closed" glyph. Markers removed off-screen get a short liberation sting | No Coin Gold (gold is loot only). **Vertical Slice option:** a warm sun-patch fades in over the liberated spot (≥ 1 s, never a flash) — the occupation gradient in reverse, at local scale. Reduce Motion: a quick fade instead of falling posters |
| **Checkpoint denial / redirect** [A11Y] | The booth plays a "DENIED" stamp (Bureaucratia rule UI: square shape plus text). After the line, a neutral dip-fade (never faction color), and the leader reappears at the return marker facing away from the checkpoint | Open vs. closed reads by **geometry** (boom down or up, tape across or gone), never by color |
| **Interact prompt** [A11Y] | **One composite element** (UI Requirements) over the current `probe()` target (rule 3): a cream rounded-rectangle pip with an Outline Ink border. It shows a **kind icon**: a speech bubble (NPC), a cup (camp), a hand (object or gag) or a ticket (a fight started by `confirm`: the Permit Counter, the boss). It also shows the **P6 button glyph** for `confirm` on the active device | ≥ 3:1 non-text contrast. Neutral UI grammar, never faction-shaped. Hidden during transitions, overlays and redirects |
| **Map exits** [A11Y] | Diegetic: a street opening framed by a lamp post or arch, pavement running on out of the set, and painted cream chevrons on the ground pointing out. The **critical-path exit** for the current chapter step also carries the beacon: a lantern banner, with brighter chevrons (rule 19) | The beacon's guarantee is rule 19's (the next waypoint beacon is on screen from every junction node of the leg), proven per map by AC-45e. The beacon is the navigation assist's visible next-destination marker. The optional screen-edge arrow has a shape glyph |
| **Camp spot** | A café or bakery door with warm window-light spill, an awning, and a chalkboard with a cup icon | The cup / fire sign is used for every camp in every region |
| **Safe zones** [A11Y] | Inside `safe_radius_m`: no faction clutter, warmer native light, civilians at ease, and a paving change (café-terrace cobbles), so the boundary is geometric. A Clerk that gives up at the edge plays a shrug-and-turn, which teaches the boundary | "No faction clutter in a safe zone" is a level-review check. Decree gags are the one exception (rule 8) |
| **Tilt-shift** [A11Y] | Actors stay sharp because the blur bounds keep every point within `see_m` of the leader in focus (`chase_visibility`, I14). Built-in depth of field cannot exempt individual sprites, so the design does not rely on an exemption | Reduce Blur applies (presentation rule 13) |

### Occupation stages (Bureaucratia Paris)

**Lighting rule (user ruling, 2026-10-22):** the key light stays Storybook
Amber at every stage. Stages flatten the scene by **raising the faction-tinted
fill**, which lifts the shadows. A stage makes the scene flatter and busier,
never darker. The actors' key and rim stay neutral (presentation rule 11).

| Stage | Set dressing | Light |
|---|---|---|
| 1 Contested | Flyers, a few bolted-on stamp-shaped street signs, a few queue barriers (no hanging banners, guardrail 6) | Faction fill ~15%; native golden sky |
| 2 Occupied | Red-striped awnings, filing-box extensions bolted onto facades, stamp-shaped street signs, checkpoint booths, queues | Fill ~40%, flat and sourceless ("fluorescent"); a low stamp-red haze band at the horizon |
| 3 Saturated | Large surfaces at mid-saturation; the skyline landmark replaced (the Eiffel Tower clad in in-trays and filing cabinets); pneumatic tubes; drifting forms | Fill ~60% (the cap); the sky's upper gradient tinted but kept at **L\* ≥ 60**, so the boss dusk flood (L\* ≤ 35) stays a separate event |

**Interiors (user ruling, 2026-10-22).** Indoor maps, including the Paris
dungeon (the Ministry), use the art bible's **Dungeon** row: cool ambient, a
warm light pool that travels with the squad, high contrast. The faction fill
reads as flat office fluorescent. The mood is comic dread, bureaucratic-gothic.
The travelling light pool is a light type that ADR-0005's lighting profile does
not yet have. It needs an ADR-0005 amendment: it affects the set only, and is
warmed at Boot so it causes no pipeline hitch (OQ-5). Until then, interiors
ship without it. A Godot 4.7.2 probe (review 2) found that the first
`OmniLight3D` in a scene adds a surface pipeline and enabling its shadow adds a
specialization pipeline, while moving it adds none. So the light must exist
from the map's first frame, never be toggled, keep a shadow flag fixed per
profile, and be present (with its shipped shadow flag) when Boot warms the
interior set materials.

**Liberated presentation (rule 17).** Once a region is liberated, each of its
maps loads with:
- its base golden-hour profile, with no faction fill;
- its `liberated_kit_id` set, with no faction set dressing, and the skyline landmark restored;
- stage-1 civilian density;
- the stage-1 ambience bed.

It is the gradient run fully in reverse (art bible §2). The stage value itself
is unchanged (rule 8).

**Data per faction × stage:** `sky_card` (top and horizon colors),
`faction_fill_weight`, `fill_energy`, `set_kit_id`, `ambient_particle_density`
(stilled by Reduce Motion), `ambience_bed_id`, and the density caps (rule 8).
**Fixed outside the data:** the key light, the actors' key and rim (neutral),
and the shadow color (the preset's warm dark).

**Validation (capture-measured):**
- set saturation stays below sprite saturation;
- mean scene luminance at stage 3 is at least stage 1's;
- `actor_contrast_min` 3.0 holds on overworld captures.

### Followers

- `follower_spacing_m` keeps silhouette overlap at or below ~30%. The leader's head and prop stay visible when walking away from the camera. Normal depth sorting; the leader wins ties.
- When the leader stops, followers close up to their spacing and stop. They never stack on one point. Snaps are instant, never lerped.
- Each follower faces along its own path, with hysteresis (a minimum distance moved before it flips), so it never flickers. When idle, followers copy the leader's facing.
- Followers are never tinted, transparent or faction-lit. Each has its own blob shadow (presentation rule 12).

### Minimal MVP animation set

| Actor | Clips |
|---|---|
| Leader and each recruit | Walk (4–6 frames) and idle (2–4 frames), front-3/4 and back-3/4; left and right by mirroring. Back-3/4 idle may reuse the battle idle |
| Compliance Clerk | Patrol walk ×2 facings, chase walk ×2, notice (2–3 frames, front), stunned (2-frame loop), give-up shrug (2 frames, may slip to Vertical Slice); a **deflated** patrol variant for a Clerk respawned onto a liberated street (sheepish pose, no clipboard flourish; may reuse patrol frames with a different prop). No defeat clip: the Clerk is removed under the wipe, and liberation shows the result |
| Minister of Forms (on map) | Idle only |
| Permit Counter (story encounter) | Idle only (a Clerk behind a counter, stamping) plus a 2-frame "number called" beat. Never stunned |
| Civilians | 3–4 body types with palette swaps; idle and queue-shuffle share frames; disperse = walk plus a 2-frame pleased or grumble beat. After region liberation, a "queueing at the mairie" idle replaces the Clerk patrols (rule 13) |
| Props | Poster peel, tape snap and boom lift are 3D tweens, not sprite frames |

### Audio direction (mood; the Audio Manager owns layers, triggers and mix)

| Event | Sound mood | Visual twin |
|---|---|---|
| Notice | Pen-click "ahem" | "!" slip + notice pose |
| Chase | Hurried footsteps, paper rustle | Chase pose + paper trail |
| Stun | Dazed paper flutter | Orbiting slips |
| Liberation | Paper tear, scattered individual reactions (pleased and grumbling), never a crowd roar | Clutter removal |
| Off-screen liberation | A short paper-tear sting | The payoff card's "Street cleared" line (rule 7a) |
| Checkpoint denial | Stamp thunk (Bureaucratia's signature sound, kept for rule moments, never the notice) | DENIED stamp + redirect |

**Ambience per stage:**
- stage 1: Paris street life;
- stage 2: adds office hum and distant typing;
- stage 3: dense comic bureaucracy (hold music, gibberish PA announcements).

Busier, never menacing (Player Fantasy guardrail 2).

### Art bible principles applied, and follow-ups

**Principles that apply most directly:**
- Principle 2: actors read before the set; Clerks stay sharp.
- Principle 3: faction hue only in set, sky and fill, always paired with the rectangle / stamp shape.
- The §2 occupation gradient.
- §3: civilians are rounder and lower-contrast than the squad.

**Art bible additions owed** (Open Questions):
- §2: the stage-light rule (raise the fill) and the stage-sky L\* floor.
- §2: the interior ruling.
- §3: an overworld icon grammar (notice slip, interact pip, exit chevron, camp sign).
- §6: prop density per stage, the safe-zone kit, and liberation as the gradient in reverse.

**Accessibility follow-up:** add rows to the color-only audit for the Clerk
notice, checkpoint state, occupation stage, safe zone and interact cue. Add
the SFX rows above (each now has a visual twin) to the gameplay-critical SFX audit.

> 📌 **Asset Spec**: Visual/Audio requirements are defined. Once the art bible
> additions are approved, run `/asset-spec system:overworld-exploration-encounters`
> to produce per-asset descriptions from this section.

> Specialist consulted: `art-director`. The user ruled on both lighting conflicts on 2026-10-22: raise the fill, never darken; interiors use the Dungeon row with fluorescent fill.

## Game Feel

**Movement feels like moving a toy, not steering a vehicle.**
- **Response:** the leader starts and stops on the frame `move` changes. There is no acceleration ramp and no slide-out (ADR-0012 §2: velocity is the input direction times `walk_speed`). A stick's partial tilt walks slower, in proportion.
- **Contact with geometry:** walls slide the leader along their face, and they never stop it dead (axis-separated collision). Corner assist nudges the leader past a corner it nearly cleared, so tight Paris streets never feel sticky.
- **The camera** is attached, not elastic. It does not move for small steps inside its dead zone, catches up smoothly beyond it, and never rotates (`sprite-camera-presentation.md` Game Feel; follow camera).

**Clerks read as comic, never threatening.**
- A Clerk's notice cue lands *before* it moves (`notice_delay_s`). The player always gets a beat to decide.
- A chasing Clerk is visibly slower than the party (`symbol_speeds`). Escaping should feel easy and a little cheeky. Being chased costs nothing mechanically. At most there is a comic beat, such as a Clerk that gives up and stamps the air behind you.
- Clerks notice less behind them (`symbol_notice_rear_m`), so slipping behind one to tear its notice is a small skill moment ("slightly naughty").
- Walking into a Clerk on purpose should feel like a choice, not a trap, and a worthwhile one: the first Victory over each Clerk buys a clue, a pocket, a shortcut or a key (rule 7a), and its tell shows which before the player decides.
- After a Fled battle, the stunned, pushed-back Clerk is a small joke at its expense. It is not a punishment for the player. Fleeing the Permit Counter is a joke too: "Your number was called. You were absent."

**Liberation is a payoff moment.** After a Victory that frees a street, the
battle wipe reverses onto the street *as it was*. Once the wipe has finished
(`transition_finished`), the linked clutter clears while the player watches:
posters fall, the queue disperses, the checkpoint lifts. It plays in full view
and is over within `liberation_duration_s` (art-director's Visual/Audio
rules). No input is required, and the player can walk away during it. Encounter
grace starts at the same moment, so watching the payoff never costs the player
their head start.

**The region's payoff.** After the boss, the walk home (rule 13) fades the
squad into a Paris in golden light, with the skyline restored, the Clerks gone
and the locals back to their own paperwork and grumbling. Ending the chapter
at the café is the closing image (rule 17). It is guaranteed, and it is never a
celebration (guardrail 6).

**Pacing.**
- Small maps with exits always in view, so the player never feels lost (level-designer map sizes, Formulas `chapter_walk_budget`).
- Street encounters are always optional and visible. The single story encounter is visible and announced. The anti-pillar "no grind walls" is a feel target too: the player never sighs at a fight they didn't see coming.

**Accessibility feel.**
- No held or timed input anywhere: movement is the only continuous input, and the player can stop at any time.
- Reduce Motion stills ambient set motion and makes the liberation clear-out a quick fade instead of falling posters. Screen Shake never applies to the overworld, which has none.

## UI Requirements

The overworld has **no persistent HUD** (Pillar 4 applied to space: the world
itself shows who runs a block, where the danger walks, and where the exits and
camps are). On-map UI is limited to:

| Element | When | Pattern (`design/ux/interaction-patterns.md`) | Notes |
|---|---|---|---|
| Interact prompt | Whenever `probe()` (rule 3) returns an eligible target, and no transition, overlay or redirect is running | P6 Device-Aware Prompt | **One composite element** above the target: a kind icon (speech bubble, cup, hand or ticket) plus the device's `confirm` glyph, at least `prompt_min_px` logical pixels tall and scaled with the text-size setting, drawn on the UI canvas (outside tilt-shift and depth of field). The verb ("Talk", "Rest", "Inspect", "Take a number", "End chapter") is its `accessibility_name`, not on-screen text. It is never a full-screen prompt. It is drawn from the same `probe()` result that `confirm` uses, so it always marks what `confirm` will do |
| Dialogue / checkpoint lines | NPC, gag `line` / `clue`, decree gag text, checkpoint redirect, queue joke, story Dialogue | P7 Overlay with Backdrop + P14 Confirm-Gated Text | Uses the Dialogue overlay (an interim stub until Dialogue is designed). The closing `confirm` is consumed by the overlay (rule 3). A denial line names the missing requirement in plain words. Poster and decree text is shown verbatim from its `LocText` string (rule 16). A story Dialogue that opens on its own (rule 14) applies P2's `input_guard`, so a mashed `confirm` is not eaten |
| Map name card | Only on a map load's reveal, never after a battle thaw or a redirect | — (new; added to the pattern library by OQ-11) | The map's name plus a flavour subtitle from the faction × stage record (for example "Rue des Formulaires" with "Now with extra queues"). After region liberation it shows the liberated subtitle (for example "Under new management: nobody's"). It never shows the stage word. Non-blocking and input-transparent, drawn on an opaque panel (P14 legibility) at body text scale. It holds for `text_hold(text)` (Timed text, below), then fades. A story Dialogue due on the same load waits for it to fade. `accessibility_live` is polite, so a screen reader announces it |
| Payoff card | On the reveal after a Victory that granted a payoff or cleared an off-screen marker (rule 7a) | — (new; OQ-11, same family as the name card) | One line per result ("Shortcut opened: Rue des Tampons", "Rumour noted in the Codex", "Street cleared"). Non-blocking, input-transparent, opaque panel at body text scale. It holds for `text_hold(text)` (below), summed over its lines. **Its hold pauses while any overlay is open**, and a `clue` payoff's interim stub line is queued until the card has faded, so the card is never hidden under an overlay. `accessibility_live` polite |
| Bark window | A proximity bark fires (the `optional_teach` beat, rule 16) | P14 Confirm-Gated Text legibility, without the gate | A short line in an opaque window above the speaker. Non-blocking and input-transparent. Holds for `text_hold(text)`; re-arms once the leader has moved beyond twice its trigger distance, and the speaker also answers `confirm` with the same line. A bark due while the name card shows waits until the card has faded |
| Camp prompt | `confirm` at a CampSpot | P15 Binary Choice Prompt | "Rest here?" Yes / No. **Yes** has the default focus: the player chose to press `confirm` on the camp, and resting costs nothing (the camp is added to P15's Used In list with this reason, OQ-11). `cancel` acts as No and closes the prompt without doing anything. On the chapter's final step, the café's `confirm` opens the chapter-end prompt instead (next row) |
| Chapter-end prompt | `confirm` at the region default camp on the chapter's final step (rule 13) | P15 Binary Choice Prompt | "End the chapter here?" Yes / No. **No** has the default focus, because the step cannot be undone. Its prompt verb and `accessibility_name` are "End chapter", never "Rest". Yes ends the chapter; No or `cancel` returns to the free roam |
| Next-destination arrow (optional) | The "Show next destination" setting is on (default off) | — (new; OQ-11) | A small screen-edge arrow with a shape glyph, pointing along the walk-grid path to the next beacon in the current leg's chain (rule 19). Hidden while that beacon is on screen |
| Menu | `menu` | P8 Pausing Menu | Party, Codex, settings, and the **objective line** (rule 19). Menu content belongs to UI Framework |

Pointer input does nothing in the overworld, except inside open UI windows (`input-system.md` rule 3). This is a known, intentional limitation: a player who relies only on a mouse cannot press `confirm` on the map. The accessibility doc records it as a Known Intentional Limitation (OQ-7). A one-handed keyboard layout is considered at the Vertical Slice remap.

**Timed text.** Every timed, non-blocking text element (name card, payoff card, bark window) holds for `text_hold(text) = max(name_card_s, text_hold_base_s + words(text) · text_hold_per_word_s)`, so a longer line always gets more reading time (for example, the 9-word teaching bark holds 3.7 s). Its hold pauses while any overlay is open. A player who misses a bark can always get it again: barks re-arm and their speakers answer `confirm`.

> **📌 UX Flag — Overworld Exploration & Encounters**: this system has UI
> requirements: the interact prompt, the map name card, the payoff card, the bark window, the camp prompt, the chapter-end prompt and the optional next-destination arrow. In
> Pre-Production, run `/ux-design` for the overworld on-map UI **before**
> writing epics. Stories that reference UI cite `design/ux/[screen].md`, not
> this GDD.

## Cross-References

| This GDD references | Document | What is referenced |
|---|---|---|
| Freeze and restore, battle entry and exit, Retry/Retreat, the default camp, Menu and Dialogue overlays, safe save moments, transition types | `design/gdd/game-state-scene-flow.md` | Rules 5–11, Transitions table, Edge Cases (Retreat before any camp; story flags after battle; dialogue after victory) |
| `move` / `confirm` / `menu`; pointer ignored in the overworld; no held inputs | `design/gdd/input-system.md` | Action table, rules 3–6 |
| Record types, stable IDs, reference validation | `design/gdd/content-data-definitions.md` | Rules 1, 3, 8 |
| Follow camera, upright-card occlusion, two facings, overworld and variant lighting, faction-color scope, comfort settings | `design/gdd/sprite-camera-presentation.md` | Rules 2–3, 6, 11, 13; `follow_camera` formula; Open Question 6 (settled here) |
| Fixed squad-then-enemy turn order (no ambush hook) | `design/gdd/turn-battle-system.md` | §3.1 |
| Occupation gradient, mood rows, faction shape vocabularies, colorblind shape backup | `design/art/art-bible.md` | §2–§4 |
| No held/timed input; color-only audit; visual equivalents for audio; next-destination marker | `design/accessibility-requirements.md` | Motor, Visual, Auditory sections; Navigation assists (rule 19) |
| On-map prompt, overlay and carry-over patterns | `design/ux/interaction-patterns.md` | P2, P6, P7, P8, P9, P14, P15 |
| Lighting profile schema, pipeline warm-up | `docs/architecture/adr-0005-sprite-camera-presentation.md` (Accepted) | Lighting profiles; Boot warm-up (amendment needed, OQ-5) |
| "Liberation runs the gradient in reverse" | `design/art/art-bible.md` | §2 (rule 17) |
| Architecture (movement, maps and encounters as data, `WorldState`, encounter pipeline) | `docs/architecture/adr-0012-overworld-exploration-encounters.md` (Proposed) | §1–§9 |
| MVP scope (Paris: town, overworld segment, one dungeon, one boss) | `design/gdd/game-concept.md` | MVP Definition |

## Acceptance Criteria

**Test harness.** Tests drive the system through its request API with stubbed neighbours:
- a Game State stub that can accept or reject a battle request and emits `on_thawed` and `transition_finished` separately;
- a stub battle outcome;
- an injectable mode clock;
- a synthetic `move` / `confirm` source;
- a stub roster.

Expected values are **computed from `OverworldConfig` and the records through
the Formulas**, never from literals. Each formula test also runs once with a
non-default config.

**Timing rule.** No assertion falls on a threshold frame. A timed transition at
`T` is tested with a `dt` chosen so that `T/dt` is not a whole number, and
asserted at `T − dt` (before) and `T + dt` (after). `AStarGrid2D` is configured
deterministically (ADR-0012). Path tests assert length and properties, never
exact cell lists.

**Test plan.** The overworld test plan
(`production/qa/test-plans/overworld-exploration-encounters-test-plan.md`) owns
fixtures and tolerances. It must exist before any [L] story in this system
passes `/story-readiness`.

**Evidence tags:**

| Tag | Meaning | Where | Gate |
|---|---|---|---|
| [L] | Logic, gdUnit4 headless | `tests/unit/overworld/` | BLOCKING |
| [D] | Data validation over every shipped `map_` / `enc_` / stage record, map scene and ChapterFlow step, run at boot and in CI | `tests/unit/overworld/data/` | BLOCKING |
| [I] | Integration, against the real Game State | `tests/integration/overworld/` | BLOCKING |
| [C] | Capture-measured | Presentation capture tool, ADR-0005 Step 1c; logs in `production/qa/evidence/captures/` | BLOCKING (it measures Visual items) |
| [VF] | Retained screenshot plus art-director sign-off | Screenshots in `production/qa/evidence/`; sign-off recorded in `production/qa/evidence/signoff-overworld.md` | BLOCKING |
| [UI] | Retained screenshot | `production/qa/evidence/` | BLOCKING |
| [N] | Narrative sign-off record | `design/gdd/reviews/overworld-narrative-signoff.md` | BLOCKING |
| [P] | Benchmark log | `production/qa/evidence/perf/` | BLOCKING at the Vertical Slice gate; **NOT ASSESSED** until its tooling story ships (AC-46) |
| [PT] | Playtest report | `production/qa/evidence/playtest-overworld-[date].md` | ADVISORY: a playtest goal recorded as evidence, not a gate, except the one item AC-50b makes BLOCKING |

**Tooling owed.** Some criteria need tools that do not exist yet. Each is a named story in the overworld test plan and must ship before its AC can be assessed; until then the AC reports **NOT ASSESSED**, never a pass:
- the `perf_overworld` fixture map, debug no-contact and no-give-up flags, and a Performance monitor around symbol stepping (AC-46);
- per-cue capture-ID tags in the presentation capture tool, ADR-0005 §14 (AC-44a/b, AC-32, AC-45e, AC-54);
- a level-review tool that lists each symbol's approaches and each leg's junction nodes, and places walk-in captures (AC-30i, AC-32, AC-45e).
- a playtest logger (symbol engaged/bypassed when it comes within `see_m`, walking-time share) and a scripted hold before the player's first Bureaucratia battle for the AC-50b question (AC-47, AC-48, AC-50b; test plan OW-T04). Until it ships, AC-50b is asked at the first Bureaucratia battle's first command prompt.

**Movement, party and interaction (rules 1–3)**
- **AC-1a [L] (R1)** GIVEN `move` at full tilt for N frames, THEN the leader's displacement is `walk_speed · Σdt` (within 1e-4).
- **AC-1b [L] (R1)** GIVEN `move` at magnitude 0.5, THEN speed is `0.5 · walk_speed`. GIVEN magnitude 1.4 (a diagonal keyboard vector before normalising), THEN speed is `walk_speed`.
- **AC-1c [L] (R1)** No input action other than `move` changes the leader's speed. The actions tested are `confirm`, `cancel` and `menu`, held and pressed.
- **AC-2 [L] (R1)** GIVEN the leader walking diagonally into a wall, THEN it slides along the wall face with non-zero tangential speed. GIVEN a corner overlap of at most `corner_assist_m`, THEN it passes without stopping.
- **AC-3 [L] (R2)** GIVEN a symbol, an exit and an interactable that overlap a follower's position but not the leader's circle, THEN no contact, exit or interaction fires.
- **AC-4 [L] (R2, `follower_trail`)** GIVEN 3 followers and a scripted path with a 90° corner, at `dt` values of 1/60 s and `dt_max`:
  - every frame, follower `i` lies on the recorded trail at arc length `i · follower_spacing_m` (± `trail_sample_m` / 2);
  - no follower is further than `trail_sample_m` / 2 from the leader's walked polyline;
  - the buffer length equals `N_buf`;
  - when the leader stops, every follower stops on the same frame.
- **AC-5a [L] (R2, Edge Cases)** GIVEN a map entry, a teleport, a checkpoint redirect or a battle thaw, THEN on that frame the trail is cleared and followers sit at spacing behind the leader, opposite its facing, on walkable cells. When a wall blocks, the remaining followers share the last walkable point.
- **AC-5b [L] (R2)** GIVEN a party of one, THEN there are no followers but the trail is still recorded. A recruit added mid-visit appears at `s_1`.
- **AC-5c [L] (`follower_trail`)** A follower's facing flips only after it has moved at least `trail_sample_m` in the new direction. When idle, followers copy the leader's facing.
- **AC-6 [L] (R2)** The saved world state contains no follower data. After a load, the followers equal the roster order minus the leader.
- **AC-7a [L] (R3)** GIVEN an NPC, a CampSpot and an Interactable within `interact_reach_m` of the probe point, THEN `confirm` targets the one nearest the probe point. On an exact tie the order is NPC, CampSpot, `confirm`-started Static symbol, Interactable (the fixture includes one of each). GIVEN an unresolved story encounter, THEN its boom checkpoint is never returned. GIVEN a target within reach of the leader's centre but not of the probe point, THEN it is not targeted.
- **AC-7b [L] (R3)** With nothing in reach, `confirm` opens nothing and the audio spy records zero events. Pointer events cause no interaction.
- **AC-7c [L] (R3)** During a transition, or with any overlay open (Menu, Dialogue, CampPrompt), `probe()` is not called and `confirm` starts nothing.
- **AC-7d [L] (R3)** GIVEN a Dialogue line opened at an NPC, WHEN the `confirm` that closes it is pressed and then **held for at least 10 frames**, THEN the overlay closes and no new interaction starts while it is held. A release followed by a new press starts one.
- **AC-7e [L] (R3, UI)** On every frame of a scripted walk past 3 targets, the interact prompt is drawn above exactly one target, the `probe()` result (or is hidden when there is none). It is hidden while a transition, overlay or redirect runs. (Absorbs the former AC-44c.)
- **AC-7f [L] (R3, eligibility)** GIVEN an open checkpoint, a `change` gag already changed and a liberated marker within reach, THEN `probe()` returns none of them and no prompt is drawn. GIVEN a `line` gag already used, THEN it is still targeted and repeats its line (or its alternate). GIVEN a granted `clue` gag used again, THEN no second rumour is added.

**Encounters and symbols (rules 4–7)**
- **AC-8 [D] (R4)** Every MVP `map_` record has `zone_rate = 0`. A fixture with `zone_rate = 0.1` fails CI, naming the record.
- **AC-8c [L] (R4)** At runtime a fixture map with `zone_rate = 0.1` logs an error, and the zone-roll spy records zero rolls over `ceil(60 / dt_max)` frames.
- **AC-8b [D] (R4)** Every `faction_` record used by a shipped map names a `patrol_archetype_id` that resolves.
- **AC-9a [L] (R5)** GIVEN a patrolling symbol with a `loop` path, THEN it traverses every segment, the closing one included, at `v_patrol`. With a `pingpong` path it reverses at each end.
- **AC-9b [L] (R5, notice)** GIVEN the leader entering the front half-plane at a centre distance below `symbol_chase_m`, with a reachable path, THEN the symbol is in Noticing on that frame's step. It is still in Noticing at `notice_delay_s − dt` and in Chasing at `notice_delay_s + dt`. GIVEN the leader leaving the radius during the delay, THEN Chasing still starts.
- **AC-9c [L] (R5, facing)** GIVEN the leader in the rear half-plane at a distance between `symbol_notice_rear_m` and `symbol_chase_m`, THEN no notice. Inside `symbol_notice_rear_m`, THEN notice.
- **AC-9d [L] (R5, reachability)** GIVEN the leader within the notice radius but behind a fence with no path within `notice_path_cap_m`, THEN no notice on any frame over 10 s.
- **AC-9e [L] (R5, deaf states)** GIVEN a symbol in Returning, Stunned or the re-notice cooldown, or any symbol during encounter grace, THEN the notice test does not run, whatever the leader's position.
- **AC-9f [L] (R5, SAFE)** GIVEN the leader in a `SAFE` cell inside a patrolling symbol's front radius with a reachable path, THEN no notice on any frame over 10 s.
- **AC-9g [L] (R5, facing and turns)** GIVEN Noticing, THEN the symbol's facing points at the leader (snapped to the displayed facing). GIVEN a `pingpong` end, and separately a `loop` vertex turning by more than 90°, THEN the symbol is stationary in its look-back pose from arrival to `turn_pause_s − dt` with the **old** facing deciding the half-planes, and its facing has flipped at `turn_pause_s + dt`. A `loop` vertex turning by 90° or less causes no pause. GIVEN the leader exactly on the half-plane boundary, THEN the front radius applies.
- **AC-9i [L] (R5, facing hysteresis)** GIVEN a symbol moving exactly along a screen axis (between two diagonals), with ±1e-6 noise added to its direction each frame for 10 s, THEN its facing never changes. GIVEN a stopped symbol (turn pause, Noticing, contact pending, Stunned), THEN its facing never changes. The facing changes only when the direction is more than 50° from the current diagonal.
- **AC-9j [L] (R5, budget fairness)** GIVEN N symbols all requesting a search on the same frame with `repath_per_frame_max` B, THEN every request is served within `⌈N/B⌉` frames, the oldest deferred request first, whatever the marker order; Returning paths count toward B.
- **AC-9k [L] (R5, bounded notice search)** GIVEN a leader 3 m from a symbol in the same component but 60 m round a wall, THEN the notice search visits no cell whose path length exceeds `notice_path_cap_m`, and no notice occurs. The cached waypoints are per symbol, and two symbols in the same cell with different marker indices get different chase targets.
- **AC-9h [L] (R5, query budget)** GIVEN a leader in a different symbol-legal component from 6 patrolling symbols with the leader inside their radii, THEN the pathfinder spy records **zero** A* queries (the component check rejects them). GIVEN the same component, THEN notice queries plus repaths never exceed `repath_per_frame_max` on any frame, and a repeated (symbol cell, leader cell) pair is served from the cache.
- **AC-10a [L] (R5)** GIVEN Chasing, THEN the symbol's speed is `v_chase`, and the pathfinder spy records at most one repath per `repath_s`, none while the target cell is unchanged and no `set_blocked` call happened, and at most `repath_per_frame_max` queries (notice and repath together) across all symbols on any frame.
- **AC-10b [L] (R5, give-up)** GIVEN a chase in a switchback fixture where the straight-line distance stays under `symbol_giveup_m` but `path_dist` exceeds it from time `t₀`, with `dt` chosen so that `giveup_s/dt` is not whole, THEN the symbol is still Chasing at `t₀ + giveup_s − dt` and Returning at `t₀ + giveup_s + dt`. The test's `path_dist` is recomputed from the stored path each frame, per rule 5.
- **AC-10c [L] (R5, Returning)** GIVEN give-up, THEN the symbol walks by A* at `v_patrol` to its stored resume point, then resumes Patrol in its earlier direction. It notices nothing until `renotice_cooldown_s` after rejoining (asserted at `− dt` and `+ dt`), and no contact occurs while it is Returning, even when it walks through the leader.
- **AC-10d [L] (R5, chase target)** GIVEN a leader standing still at an off-centre point of a cell, THEN a chasing symbol reaches contact within `(path_dist₀ / v_chase) + 2·dt`. GIVEN symbols chasing with marker indices i = 0, 1, 2, THEN each target's offset from its nearest-cell point equals `|(i mod 3) − 1| · body_radius`, perpendicular to **that symbol's own** symbol-to-leader vector, and the offset is dropped when the offset point is not symbol-legal. Ties for the nearest cell go to the lowest cell index.
- **AC-10e [L] (R5, final approach legality)** GIVEN a leader standing one cell inside a `SAFE` edge, a leader who rounds a wall corner between repaths, and a diagonal approach past a blocked corner, THEN on every frame the symbol's centre lies on a symbol-legal cell, the final approach is used only while the leader's cell is the path's target and every crossed cell is legal, and every A* query starts from a symbol-legal cell.
- **AC-11 [L] (R5, R12)** GIVEN a chase toward a leader who enters a safe zone at `t₀`, THEN on no frame does the symbol's centre enter a `SAFE` cell, and no contact occurs. The symbol is still Chasing at `t₀ + giveup_s − dt` and Returning at `t₀ + giveup_s + dt`.
- **AC-12 [L] (R5, Edge Cases)** GIVEN a pathfinder that returns an empty path at `t₀` during a chase, with nothing pending, THEN the symbol holds still, is still Chasing at `t₀ + giveup_s − dt` and Returning at `t₀ + giveup_s + dt`. GIVEN a first repath deferred by the budget, THEN the symbol follows the notice path and its give-up timer does not start. GIVEN an unreachable resume point, THEN it holds still, notices nothing until reload, and logs exactly one warning.
- **AC-13 [L] (R5, R6)** GIVEN contact, THEN `start_encounter` is called once with the record's `enc_` ID. The descriptor is identical whatever the contact direction or which body moved.
- **AC-14 [I] (R4/R5 × Game State rule 6)** GIVEN contact with a symbol whose `enc_` record is a fixture, THEN the Encounter descriptor Game State receives equals the record field for field: `encounter_id`, enemy IDs, `battle_stage_id`, `faction_id`, `is_boss`, `can_flee`, `retreat_allowed`.
- **AC-15 [L] (Edge Cases)** GIVEN contact and a MapExit crossing on the same frame, THEN only the exit request is made.
- **AC-16 [L] (Edge Cases)** GIVEN `start_encounter` rejected for 30 frames while the bodies overlap, THEN the symbol does not move, the request is retried every frame, one rejection is logged, and the first accepted frame enters Frozen.
- **AC-17 [L] (Edge Cases)** GIVEN two symbols in contact on the same frame, THEN the one with the smaller closest-approach distance starts the encounter. On an exact tie, the earlier one in marker order does. On `transition_finished` after the thaw, the other is in Returning.
- **AC-18 [L] (R7)** GIVEN Victory over a normal Clerk, THEN it is absent until the map is reloaded through a MapExit, and present after that. GIVEN Victory over a `respawn = never` record, THEN it is absent after any number of reloads.
- **AC-19a [L] (R7, Edge Cases)** GIVEN Fled from a non-Static symbol, THEN in `on_thawed` the symbol is Stunned, and it is moved along the leader-to-symbol line by `flee_push_m` in 4-connected cell steps, or less if a non-symbol-legal cell comes first. The leader's position is unchanged.
- **AC-19b [L] (R5, R7)** GIVEN a Stunned symbol overlapping the leader at any time during `flee_grace_s`, THEN no encounter starts. It is Stunned at `flee_grace_s − dt` and Returning at `flee_grace_s + dt`.
- **AC-19c [L] (Edge Cases)** GIVEN Fled with coincident centres, THEN the push goes along the direction opposite the leader's facing.
- **AC-20a [L] (R7)** GIVEN Victory, Fled, any map load or a redirect, THEN grace starts on `transition_finished`, not on `on_thawed`. An overlapping eligible symbol starts no encounter at `encounter_grace_s − dt` after that, and does start one at `encounter_grace_s + dt`.
- **AC-20b [L] (R7)** Grace, notice, give-up, cooldown and stun timers do not advance while the Menu, Dialogue or CampPrompt is open, or while a transition runs.
- **AC-21 [I] (R7 × `game-state-scene-flow.md` AC-11)** GIVEN a mid-chase snapshot (symbol sub-states, timers, positions, trail, liberated sets), WHEN Overworld → Battle → Overworld runs with Fled, THEN every field equals the snapshot except those rule 7 changes (stun, push, grace, follower snap, and every Noticing or Chasing symbol switched to Returning when grace starts). The same holds for Victory, except for the resolved symbol, its payoff and its liberation.
- **AC-21b [L] (R7a)** GIVEN a first Victory over a symbol with each payoff type, THEN `clue` adds one Codex rumour (or calls the interim stub), `open` opens the linked checkpoint, and `item` adds the item. On `transition_finished` the payoff card shows one line naming the result. A second Victory over the respawned Clerk grants nothing and shows no card.
- **AC-21c [D] (R7a)** On each non-Town, non-boss map: at least one symbol carries an `open` payoff that leads to an optional pocket or (on the dungeon) the dungeon shortcut; at least half of the non-story symbols carry `clue` or `open`; no two `clue` payoffs in the region share a facet, and none repeats the first-encounter poster's facet; each payoff's tell (gate, envelope prop or rolled poster) lies within `R_vis` of a vertex of its symbol's patrol; every payoff reference resolves; and no `item` payoff meets a critical-path requirement. At most ⌊N_sym/3⌋ symbols per map carry `none`, never a Static symbol and never the first symbol along the critical path; every optional pocket holds a `change` gag plus a recruit remark or a clue facet.
- **AC-21d [L] (R9, R7a)** GIVEN a Victory whose linked marker is outside the footprint, THEN on `transition_finished` the audio spy records the off-screen sting **and** the payoff card shows a "Street cleared" line on the same frame.

**Stages and liberation (rules 8, 9, 17; `occupation_stage`, `marker_activation`)**
- **AC-22 [L] (`occupation_stage`)** Parametrized over `base_stage`, stage tables and flag sets (the empty set included): the stage equals the formula. A fixture removing a raising flag keeps the stage and logs a warning. Over any sequence of loads, the stage never decreases.
- **AC-23 [L] (R8)** GIVEN a flag set mid-visit, THEN the stage and the active markers are unchanged until that map's next load.
- **AC-23b [D] (R8, R18)** Paris `map_` records have `base_stage` Town 1, overworld segment 1 and dungeon 3. Civilian density is non-increasing across stages 1–3, and caps are non-decreasing (I13). Maps with no `base_stage` report no stage. For every stage-raising flag in the registry:
  - its trigger is a ChapterFlow step change, and **never** a player Victory, a map entry or another squad action;
  - it is set on a step **before** every step in which any map it raises can be loaded, and a walk-grid search from the chapter's start over every map reachable before that step finds no route into a raised map (for `permits_mandatory`, set on the opening step, the check is trivially met);
  - it names a decree gag at **every** EntryPoint of each raised map that any MapExit targets, each resolving to a `decree_gag` marker.

  The overworld segment's reachable stages, derived from the step list, are exactly {2}.

  Every flag that any map, checkpoint, marker or Dialogue reads appears in the registry.
- **AC-23c [L] (R8)** A decree gag is active only at or above its new stage, is not counted against any cap, never blocks a cell, is eligible for `confirm`, and is inactive once `region_liberation_flag` is set.
- **AC-23d [I] (R8, R18 registry)** On a New Game, `permits_mandatory` is set before the first input is accepted; the overworld segment's first load is at stage 2, with its decree gag at both EntryPoints, whatever route the player takes through Town. Beating any symbol, entering any map or registering any camp sets no stage-raising flag (flag spy).
- **AC-24 [L] (`marker_activation`)** Using the P1–P6 example and a randomized-order fixture, the active markers equal the formula, sorted by (`min_stage`, marker order). At stage 2, P1, P4, P6 and P2 hold the slots. Liberating P2 shows 3 posters, and P5 stays hidden. At stage 3 with an equal cap of 4, the same four keep their slots.
- **AC-25 [L] (R9, Edge Cases)** GIVEN Victory over a linked Clerk, THEN its marker IDs join the map's liberated set in `on_thawed`. When that Clerk respawns, and after a stage raise, those markers stay hidden. Beating the respawned Clerk adds nothing. The liberated set survives save and load.
- **AC-26a [L] (R9, R7)** On the mode clock, an on-screen marker's removal has not started at `transition_finished − dt`, has started at `transition_finished + dt`, and is complete, with its cells freed, at `transition_finished + liberation_duration_s + dt`. An off-screen marker is removed in `on_thawed`, and its cells are freed then. A Dialogue due from the same battle opens after the on-screen removal ends.
- **AC-26b [VF] (R9)** Retained before / after screenshot pairs of one poster, one queue and one checkpoint liberated in Paris, plus one Reduce Motion frame captured mid-fade.
- **AC-26d [L] (R9)** GIVEN a liberation with N reacting civilians, THEN at least `ceil(liberation_grumble_min · N)` play the grumble beat. GIVEN a Clerk respawned onto a liberated street, THEN its sprite set is the deflated variant and its behaviour parameters equal the normal Clerk's.
- **AC-26e [D] (R9)** Each map's liberation reaction set has at least one entry tagged `ribs_squad` (AC-51 confirms the tag is honest).
- **AC-26c [D] (R9)** Every clutter marker that names a `symbol_id` lies within `R_vis` of at least one vertex of that symbol's patrol, and that symbol is active at every reachable stage where the marker is active.
- **AC-27 [C] (stage visuals)** On Paris captures at stages 1–3, using the capture tool's masks: the mean HSV saturation of set pixels is below that of sprite pixels; stage 3's mean scene luminance is at least stage 1's; `actor_contrast_min` ≥ 3.0.
- **AC-27b [L] (R13, R17)** GIVEN `region_liberation_flag` set, WHEN each Paris map loads, THEN, before the first revealed frame:
  - every clutter marker is treated as liberated, including those of a higher stage;
  - the stage value is unchanged;
  - the lighting profile is the map's `liberated_profile_id` and the set kit is `liberated_kit_id`;
  - civilian density and the ambience bed equal stage 1's;
  - **every** symbol is inactive, beaten or not, and the mairie-queue civilians, at least one grumbler and one "Bureaucratia had a point" item are active.
- **AC-27c [VF] (R17)** Retained screenshots of each Paris map at its highest stage and again after region liberation: golden-hour light (the Dungeon row without fluorescent fill for interiors), no faction set dressing, the skyline landmark restored, and no celebration tableau.
- **AC-27d [I] (R13, walk home)** GIVEN a boss Victory, THEN after the post-battle Dialogue the next transition is a map change to the overworld segment's dungeon-side EntryPoint with the liberated presentation; the segment's exit to the dungeon is disabled and shows the "FERMÉ POUR RESTRUCTURATION" tape; the current leg ends at the Town café CampSpot. A spy shows that chapter-end is called only from Yes in the "End the chapter here?" prompt at the café on the final step (B). Entering Town during step A advances the step to B. Pressing `cancel` and `menu` during the post-battle Dialogue and the fade, and Save → Continue during the free roam, each still lead to the segment load and the same café end. In the prompt, No has the default focus and No or `cancel` returns to the free roam.
- **AC-27e [D] (R17)** The overworld segment and the Town have both `liberated_profile_id` and `liberated_kit_id`, and each resolves. With `paris_liberated` set and the step in the last act (A or B), no walk-grid route from the segment reaches the dungeon or the boss chamber.

**Checkpoints, maps, boss, flags and save (rules 10–15, 13a)**
- **AC-28a [L] (R10)** GIVEN a met requirement, THEN `confirm` opens the checkpoint, its cells are freed, and it stays open across save and load. GIVEN the requirement already met on load, THEN it stays closed until `confirm`.
- **AC-28b [L] (R10)** GIVEN an unmet requirement with `redirect` or `queue`, THEN after the line the state is Redirecting, input is locked, and the leader is placed at the return marker facing away. The camera and followers snap, and grace starts on `transition_finished`, when every Noticing or Chasing symbol switches to Returning (rule 7). Every other symbol's sub-state, position and timers equal their pre-redirect values, and no `mode_entered` fires (same-instance transition). `queue` uses no timed or held input.
- **AC-28c [L] (R10)** GIVEN an unmet requirement with `encounter`, THEN the linked encounter starts, and a Victory opens the checkpoint.
- **AC-29 [D] (R10, rule 0)** Every checkpoint has exactly one requirement (an item or a flag), never XP, level or currency, and every requirement names an `obtained_at` source that resolves. On every critical-path leg, at every reachable stage, a fixed-point search over the leg's cells succeeds when it opens a checkpoint only after reaching that checkpoint's fight-free source earlier on the leg; `victory_payoff` sources never count. No critical-path checkpoint has the `encounter` outcome except the region's story encounter. Every return marker is a safe-zone source (with `return_safe_radius_m`), so it lies in a `SAFE` cell, and no return marker lies inside a MapExit rectangle. Here "the leg's cells" are the cells reachable from the leg's start, and a chapter-step flag source counts as reached when it is set on or before the leg's step.
- **AC-30a [D] (R11, rule 0)** For every shipped map, every MapExit target exists with a reciprocal exit. Every `critical_path` leg names an existing EntryPoint and an existing MapExit, story-encounter or boss `symbol_id`, or CampSpot. Every ChapterFlow step names an existing `{map_id, leg_id}`.
- **AC-30b [D] (R11, R13, R13a)** Town has 0 symbols and a CampSpot flagged as the region default. The dungeon's first room holds a CampSpot and the story encounter. The story encounter stands on a walkable cell in front of its checkpoint (it is exempt from the symbol-legal rule, rule 13a); its walk-grid distance from the CampSpot's safe-zone edge is at most `story_sight_m`; the visibility edge `R_e` in its direction from that edge is at least its distance; and its return marker lies between `return_safe_radius_m + body_radius` and `interact_reach_m · 3` from it, on the camp side. The boss lies outside every `SAFE` cell, at least `safe_radius_m + 2·body_radius + cell_m` from every safe-zone source in the boss chamber.
- **AC-30i [VF] (R13a, telegraph)** A retained walk-in screenshot with the leader at the pre-dungeon CampSpot's safe-zone edge, facing the Counter, shows the Permit Counter on screen; art-director sign-off in `production/qa/evidence/signoff-overworld.md`.
- **AC-30c [D] (R12)** No spawn point or patrol segment (closing segment included) lies within `safe_radius_m` of any EntryPoint or CampSpot (segment-to-point) or MapExit trigger rectangle (segment-to-rectangle), or within `symbol_chase_m + body_radius` of any return marker.
- **AC-30d [D] (references)** Every `enc_`, `symbol_id`, `liberation_flag`, `victory_payoff`, `recruit_remark`, decree-gag and item reference resolves.
- **AC-30e [D] (ADR-0012)** The scene contains no node of these classes: `CollisionObject3D` or `CollisionObject2D` (bodies and areas), `SoftBody3D`, `RayCast3D`, `ShapeCast3D`, `RayCast2D`, `ShapeCast2D`, `SpringArm3D`, any `Joint3D`/`Joint2D`, `PhysicalBoneSimulator3D`. Shipped maps contain no `CSGShape3D` at all (CSG is baked to `MeshInstance3D` in the editor, or with `bake_static_mesh()` one frame after tree entry). Every `GridMap` has `collision_layer` = `collision_mask` = 0, and `mesh_library.get_item_shapes(id)` is empty for every used item (`GridMap.collision_layer` defaults to 1 on 4.7.2, so the authoring default must be changed). Every `TileMapLayer` has `collision_enabled` off (it defaults to on, so this authoring default must also be changed).
- **AC-30f [D] (R11, map exits)** Every EntryPoint lies at least `body_radius + entry_clearance_m` outside every MapExit rectangle and faces into the map.
- **AC-30g [L] (R11, map exits)** GIVEN a leader placed inside a MapExit rectangle by a load, THEN no exit fires until the leader has left the rectangle and entered it again. GIVEN a `move` held for `ceil(2/dt)` frames across a map change, THEN the leader does not cross back.
- **AC-30h [D] (R5, patrol legality)** For every symbol, at every reachable stage where it is active, every cell its patrol segments sweep (± `body_radius`) and its patrol origin are symbol-legal.
- **AC-31 [D] (R12, bypass lane)** For every non-boss map, at every reachable stage, rule 12's **ordered search** succeeds on every critical-path leg: patrol bands and blocked cells closed; a checkpoint opened only after its fight-free source is reached earlier on the leg; `open`-payoff checkpoints closed; and a leg that crosses the story encounter split into its two searches (before it, to any cell within `interact_reach_m` of it, with bands; beyond its checkpoint with the checkpoint open). Legs ending at a symbol end within `interact_reach_m` of it. Nothing else is exempt.
- **AC-31d [D] (R12, no route round the story encounter)** On the dungeon, with every `open` and `item` checkpoint opened, every walk-grid route from its EntryPoint to its boss-chamber exit crosses the story encounter's checkpoint cells, and every symbol whose payoff opens the dungeon shortcut is reachable only beyond that checkpoint.
- **AC-31b [D] (R12, pressure floor)** On the dungeon, at every reachable stage, at least ⌈N_sym/2⌉ symbols' bands cross the leg's `L_crit` path (no bands applied, checkpoints handled as in the ordered search), and `L_bypass ≥ bypass_ratio_min · L_crit`.
- **AC-31c [D] (R12, R16)** On the first-encounter map, the first patrol's section of the leg (rule 12: from the last cell before its band to the first cell after it, on `L_crit`) has `L_bypass / L_crit ≤ first_bypass_ratio_max`. The `optional_teach` speaker stands within `interact_reach_m · 2` of a critical-path cell before the first notice radius.
- **AC-32 [VF] (R12, visibility)** The level-review tool and the capture-ID tags (both Tooling owed) list, for each symbol on each shipped map at each reachable stage, its approaches: walk-grid entries into the `see_m` disc, deduplicated by 45° sector. For each approach the symbol is **frozen at the patrol point nearest the approach** and the leader is placed at `see_m + 0.1 m` from it. The capture shows the symbol unoccluded: at least 50% of its sprite mask visible in the capture-ID pass. A retained screenshot per approach, plus the art-director sign-off. This AC covers set occluders only, since AC-39 proves the camera geometry.
- **AC-33a [I] (R13)** GIVEN contact with the boss, THEN the boss had not moved before contact, and the descriptor has `can_flee = false` and `retreat_allowed = true`.
- **AC-33b [I] (R13, R13a)** After passing the pre-dungeon CampSpot's safe zone without resting, then Defeat → Retreat, the party is at the pre-dungeon camp, and the boss is unresolved. With no camp registered yet, Retreat goes to the Town café.
- **AC-33c [I] (R13)** After Victory over the boss, then a Retreat in a later fight, then Save, Continue and a reload, the boss stays absent.
- **AC-33d [L] (R13a)** The Permit Counter is Static and notices nothing. Contact with it starts nothing on any frame over 10 s of overlap, and the first contact plays the "Take a number." bark once; `confirm` at it starts its encounter, and the prompt shows the ticket icon. After Fled: it is not stunned or pushed, the leader is at its return marker in a `SAFE` cell when the wipe reveals, the "number called" line opens as an automatic Dialogue on `transition_finished` and a `confirm` held from the battle does not skip it (`input_guard`), the checkpoint stays closed, and no encounter starts until a new `confirm`. Victory opens the checkpoint and it never respawns. Its camp decree is inactive before the leader first has the Counter on screen and active after.
- **AC-34 [I] (R14)** GIVEN a Victory that sets a liberation flag and a story flag, THEN these happen in order:
  1. liberation state is written in `on_thawed`;
  2. on-screen removal starts on `transition_finished`;
  3. Dialogue opens after the removal ends;
  4. the stage effect appears only on the next load.
- **AC-35 [L] (R15)** After any frame step, world state's map, position and facing equal the leader's. Other world-state fields change only on their events (a frame-step spy sees no write to them), and no world-state change signal is emitted on a frame with no event. The Overworld never calls the save writer (spy). (Save safety during transitions and overlays is Game State's to test: `game-state-scene-flow.md`.)
- **AC-35b [L] (R15, Edge Cases)** GIVEN a save whose position now lies in a cell blocked by a newly active blocker, THEN on load the leader is at the nearest walkable cell. If none is within 5 m, the leader is at the first EntryPoint.
- **AC-35c [L] (R15)** Save and load round-trips the last camp registered, opened interactables (gag `change` responses included), granted payoffs, liberated sets, `stage_stored` and the interim story flags.
- **AC-36 [I] (Edge Cases)** GIVEN a save made mid-chase with a resolved `on_map_reenter` Clerk, WHEN Continue runs, THEN every symbol is in Patrol at its origin, the resolved Clerk stays absent, and grace starts on the reveal.

**States, load-time validation and frame safety**
- **AC-37 [L] (States and Transitions)** Parametrized over every row of the table: each entry produces its state, and each listed exit produces its target. A rejected encounter returns to Exploring. A failed map load restores the old map.
- **AC-38 [L] (invariants)** The default config passes. One fixture per invariant I1–I13 and I15–I18 breaks only that invariant, and its error names that ID (for I15, `symbol_chase_m` 3.5 with `notice_path_cap_m` 4.5; for I16, `notice_path_cap_m` 5 with `symbol_giveup_m` 6; for I17, `turn_pause_s` 0.5; for I18, `beacon_h_m` 3.0 with `wall_h_max` 3.0). For example: `f_chase` 0.9 (I1), `encounter_grace_s` 0.5 (I3), `symbol_giveup_m` 5 with `symbol_chase_m` 3.5 (I4), `flee_grace_s` 2 with `walk_speed` 3.0 and `symbol_giveup_m` 8 (I5), and `dt_max` 0.3 with `walk_speed` 4.0 (I11).
- **AC-39 [L] (`chase_visibility`, I14)** With presentation's example camera (pitch 30°, F_v 20°), h 10 m fails and names the binding aspect and edge. h 11.5 m passes at 4:3, 16:9 and 21:9 at the default dz and tau. Blur fixtures: `dof_far_begin` below `d_cam(+s_blur)` fails; `dof_near_end` above `d_cam(−s_blur) − H_max·sin(pitch)` fails; a fixture that passes when measured from the focus but fails with the leader at the dead-zone edge (`s_blur` vs `see_m`) fails. The shipped config passes at all three aspects.
- **AC-40 [L] (Edge Cases, swept contact)** GIVEN a 0.25 s frame (injected `dt`), THEN movement and every timer advance by exactly `dt_max`. Over a fixture set of approach angles 0°–90° in 15° steps, lateral offsets 0 to 2·`body_radius` and both bodies at full speed, every pair whose closest approach is ≤ 2·`body_radius` produces contact, and no other pair does. GIVEN zero relative displacement (`|b|² < 1e-8`), THEN contact equals `|a| ≤ 2·body_radius` with no division. A leader at `walk_speed` never crosses a 1-cell wall.
- **AC-40b [L] (`symbol_speeds`)** GIVEN open ground and a chase starting at `d0` = 2·`body_radius` + 0.05 m (so no contact on the first frame), with the leader walking straight away at `walk_speed`, THEN the symbol is Chasing at `t_escape(d0) − dt` and Returning at `t_escape(d0) + dt`.
- **AC-40c [L] (`path_dist`)** GIVEN a U-shaped corridor in which the leader rounds a wall end between repaths, THEN on every frame `path_dist` is at least the true walk-grid path distance from symbol to leader, and from the first frame on which `path_dist > symbol_giveup_m`, it stays above `symbol_giveup_m` on every frame until Returning, unless the true path distance falls below it.
- **AC-41 [D] (`symbol_density`)** At every reachable stage, each map's `N_sym` lies within `[N_min, N_max]`, with `N_min` at least 1 on every map other than Town and the boss chamber. Town has 0, and the boss chamber holds the boss only. Coverage is reported, not gated.
- **AC-42 [D] (`chapter_walk_budget`)** `walk_share` ≤ `walk_share_max`, where each leg's length is its `L_bypass` maximum over reachable stages and `passes(leg)` is counted from the ChapterFlow step list. A fixture step list that names a leg twice doubles that leg's term.

**Accessibility, UI and navigation**
- **AC-43 [L] (accessibility)** No overworld action requires a hold or a timed press (input-map audit). Every flow completes with discrete presses plus `move`.
- **AC-44a [C] (accessibility)** Each cue node carries a capture-ID tag (Tooling owed: ADR-0005 §14 tags in the §13 capture tool). On grayscale conversions of the test plan's named capture poses (Town, overworld segment and dungeon, at every reachable stage, at 1080p), each of these cues has a luminance contrast of at least 3:1 against a ring formed by a 4 px dilation of its mask: the notice slip, the chase "!" tag, the stunned pose, the checkpoint open and closed states, the safe-zone paving edge, map exits with the beacon, and the camp sign.
- **AC-44b [C] (accessibility)** On the same poses, the interact prompt's mask measures at least 3:1 contrast against its 4 px ring.
- **AC-45 [UI]** Retained screenshots of:
  - the interact prompt with each of its four kind icons, on keyboard, on one gamepad style, and on the Steam Deck (which reports `pad_style` `xbox`, `input-system.md` rule 4), at the default and the largest text size;
  - the map name card at a normal stage and with the liberated subtitle;
  - the payoff card, the bark window and a decree gag's text, each on the Steam Deck at text scale 1.0 and 1.5;
  - the camp prompt with Yes focused, and the chapter-end prompt with No focused;
  - the optional next-destination arrow;
  - the Menu objective line.
- **AC-45e [VF] (R19, beacon chain)** For each map, each leg and each reachable stage, the level-review tool places the leader at every junction node of the leg. Each capture shows the **next** beacon in the chain with at least 50% of its mask visible in the capture-ID pass (both Tooling owed). Retained screenshots plus the art-director sign-off.
- **AC-45f [D] (R19, junction coverage)** Every leg's junction nodes include its start EntryPoint, one node per room it crosses, and every critical-path cell where the walk grid branches toward a different required or optional end. Every leg ends in a beacon, and I18 holds.
- **AC-45b [L] (UI)** The map name card appears on a map load's reveal and never after a thaw or a redirect. It is fully shown at `text_hold(text) − dt` after the reveal and fading at `text_hold(text) + dt`. A story Dialogue due on the same load opens after it fades. Its text never contains a stage word.
- **AC-45c [L] (R19)** On each map, only the current leg's beacon chain is lit, and its last beacon is on the leg's end (exit, story encounter, boss or café). The objective line equals the step's `objective_text`. With the setting on, the arrow points along the walk-grid path's next segment toward the beacon, and is hidden while the beacon is on screen.
- **AC-45d [L] (UI)** In the camp prompt, `cancel` closes it with no camp request, and Yes has the default focus.

**Performance and playtest**
- **AC-46 [P]** In a release export (not the editor), on a named GTX 1080-class PC (`project.yaml` `min_spec`; the machine is recorded in the log) and on a Steam Deck (1280×800):
  - **Map and setup:** the `perf_overworld` fixture map (Tooling owed), at stage 3, exterior, with N equal to the **shipped dungeon's** `N_max` at stage 3. 3 followers, the stage's full civilian count and tilt-shift on. Debug flags disable contact and give-up, so states persist for the whole run.
  - **Run, case A (chase):** every symbol chases a leader who walks a scripted loop. **Case B (fenced patrol):** every symbol patrols with the leader inside its radius, in the same component but behind a long detour, and the test hook moves the leader back and forth between two adjacent cells every frame (or a debug `notice_cache_off` flag, Tooling owed), so the notice cache misses and the bounded search runs within the budget every frame. Each case is a 120 s run after a 10 s warm-up, vsync off, with pipelines pre-warmed (ADR-0005).
  - **Pass:** p99 frame time ≤ `frame_time_p99_ms` and worst frame ≤ `frame_time_worst_ms` (`project.yaml`). Symbol stepping, notice queries and repaths together take ≤ 2 ms per frame at p99, measured by a custom Performance monitor around `step_symbols()` (the overworld share of the frame budget; OQ-19).
  - **Record:** the log is kept in `production/qa/evidence/perf/`.
- **AC-47 [PT]** A playtest report with at least 5 first-time players on the Paris chapter. For each symbol that comes within `see_m`, the facilitator logs it as *engaged* or *bypassed*. Fixed survey wording (in the test plan) asks Q3, "I was pulled into a fight I didn't choose", and Q4, "Fights felt like grind", each answered Yes or No. **Goal:** every player has at least 1 bypass and at least 1 engaged street Clerk, and the facilitator logs which payoff types each engaged Clerk carried. At most 1 player answers Yes to Q3 or Q4. (The rule-comprehension item is not here: it is BLOCKING, in AC-50b.)
- **AC-48 [PT]** From timestamped session recordings in the same playtest, record the share of chapter time spent moving on the overworld and compare it with `walk_share_max`. A survey item asks whether walking felt slow. The result feeds OQ-9 (Fast Walk).

**Gags, clues, narrative and region liberation (rules 13, 16, 18)**
- **AC-49 [D] (R16)** For every shipped map at every reachable stage, every active clutter marker is either a `gag` interactable with a response or a route-blocker on the walk grid.
- **AC-49b [L] (R16)** Each gag response type behaves as specified. `line` opens Dialogue. `change` plays its change without an overlay and saves it as opened. `clue` opens Dialogue and adds one rumour. A `recruit_remark` reference is optional, and the record validates with or without one.
- **AC-50 [D] (R16)** On each faction's first-encounter map, at least one marker tagged `faction_clue` lies within `interact_reach_m` of a cell on the critical path. Distances are **arc lengths along the leg's `L_crit` path from the leg's start EntryPoint** (for the Paris segment, the Town-side one). The clue comes before the first point within any notice radius, and the first patrol lies at least `safe_radius_m + symbol_chase_m + first_patrol_clearance_m` along it. A marker tagged `optional_teach` satisfies the same ordering, and it is a proximity bark or on-screen art, never a `confirm`-only line.
- **AC-50b [N] (R16, R18)** The narrative sign-off record has an entry for the Paris clue with: the on-screen text legible without interaction, shown by a retained Steam Deck capture at 1280×800; and the comprehension check passed. That check is run in the AC-47 playtest **before the player's first Bureaucratia battle**, with the fixed wording in the test plan, and passes when at least 60% of the players (at least 5) state that the enemy takes no damage until it is Approved. This one playtest item is BLOCKING through this AC.
- **AC-51 [N] (R8, R18)** The narrative sign-off record has a passing entry for every item in rule 18's scope: every faction × stage content set, the decree gags, the story encounter's lines, the recruit remarks, the boss chamber, the post-battle story Dialogue, the liberated set and the other player-facing text rule 18 lists. Every entry ticks (a); each faction × stage set and each liberated set also ticks (a2) and (b)–(d); each line-only item also ticks the lines-only composite read; each clue also ticks (e). Each entry records the art-director's co-signature on (a) and (a2) where they apply, and carries the content hash. Paris ships at least three recruit remarks, at least one of which ribs the squad, and the record confirms that every liberation reaction tagged `ribs_squad` really ribs the squad.
- **AC-51c [L] (R16)** On `confirm` at a clue poster or a decree gag, the Dialogue overlay shows the record's `LocText` string verbatim, through the localization path (ADR-0013), at the current text size.
- **AC-51d [L] (R16)** The `optional_teach` bark fires when the leader comes within `interact_reach_m · 2` of its speaker, with no input, and never blocks movement. It does not fire again until the leader has moved beyond twice that distance, then fires again on re-entry. `confirm` at the speaker shows the same line. A bark due while the name card shows waits until the card has faded.
- **AC-51b [VF] (R9)** A retained screenshot of a Clerk respawned onto a liberated street, showing the deflated variant.

**Feedback, audio, presentation and edge coverage (rev 3)**
- **AC-52 [VF] (Visual/Audio, event feedback)** Retained screenshots, with the art-director sign-off, of each event cue: the notice slip, the chase pose and "!" tag, the stun, the contact hold, the checkpoint denial, an exit with and without the beacon, the camp sign, the ticket dispenser, and the safe-zone paving. Chase and stun are also captured under Reduce Motion, showing a still pose that still reads. One capture each of Paris stages 1 (Town), 2 (overworld segment) and 3 (dungeon), and one of the "FERMÉ POUR RESTRUCTURATION" tape.
- **AC-53 [L] (Visual/Audio, twins)** For every overworld SFX event in the audio table, the event spy records the sound together with its visual twin on the same frame (the payoff card counts for the off-screen sting).
- **AC-54 [C] (stage visuals)** On Paris captures of every exterior stage, the mean CIELAB L\* (sRGB, D65) of the top 25% (by row of its bounding box) of the sky mask (capture-ID `SKY`; Tooling owed) is at least 60.
- **AC-56 [L] (rule 0, SAFE bake)** GIVEN a cell whose nearest point lies 0.01 m inside `safe_radius_m` of an EntryPoint while its centre lies outside, THEN it is tagged `SAFE`; a cell 0.01 m outside is not. The same holds for a MapExit rectangle (nearest point to the rectangle) and a CampSpot at `safe_radius_m`, and for return markers at `return_safe_radius_m`.
- **AC-57 [L] (R5, misc.)** Two symbols, a follower and a civilian occupying the same point never block or push one another. A symbol touched during Patrol stores its patrol position at contact as its resume point and resumes from it after a Fled battle.
- **AC-58 [L] (UI, timed text)** The name card, the payoff card and the bark window each hold for `text_hold(text)` (asserted at `− dt` and `+ dt`), and each hold pauses while any overlay is open. A `clue` Victory's interim stub line opens only after the payoff card has faded.
- **AC-59 [L] (pathing setup, one clock)** After bake, `AStarGrid2D.is_dirty()` is false before every query, and `region`, `cell_size` and `offset` never change. A `set_blocked` round trip on one cell leaves every other cell's solid flag unchanged. Over a run with injected hitches, a sprite's animation frame always equals the frame computed from the accumulated `ow_dt`.
- **AC-55 [L] (Edge Cases)** GIVEN a window aspect narrower than 4:3, THEN exactly one warning is logged and the game runs. GIVEN a blocker freed while a symbol's path ran round it, THEN the stored path and notice cache are invalidated, and the symbol's next repath in its stagger turn crosses the freed cells.

> Criteria first drafted by `qa-lead`. Rev 2 applied the review's qa-lead findings: threshold frames, split bundles, evidence locations, measurable rewrites and coverage gaps. It added the review's other specialist items as new ACs. Rev 3 applied the second review: the timing rule on every timed AC, gate levels for every tag, Tooling owed with NOT ASSESSED, AC-44c folded into AC-7e, and new ACs 7f, 8c, 9f–9h, 10d, 21d, 23c, 23d, 26d, 27d, 27e, 30f–30h, 31c, 40b, 45e, 51c, 51d and 52–55. Rev 4 applied the third review: 9i–9k, 10e, 23b/23d, 26e, 27d/27e, 30b, 30i, 31d, 40b, 40c, 45e, 45f, 51d and 56–59, with the targeted verification's rewrites.

## Open Questions

| # | Question | Owner | Target | Resolution |
|---|---|---|---|---|
| OQ-1 | **The overworld camera must clear `chase_visibility` (I14).** With the per-edge formula (rev 2), presentation's example (pitch 30°, F_v 20°) needs **h ≥ 10.9 m** at the default dz and tau, and **h ≥ 11.6 m** at their ceilings. **h = 12.0 m** is proposed, or an equivalent pitch or field-of-view change. The tilt-shift blur bounds must also keep everything within `see_m` sharp. The presentation GDD has no overworld camera defaults yet. | Sprite & Camera Presentation owner + art-director | Before the first overworld story | Unresolved |
| OQ-2 | Confirm presentation's dead-zone reading: `dz_x` = dz%·`w_far` and `dz_y` = dz%·`a_near`, or is the "half-extent" on y `(a_near + a_far)/2`? If `follow_camera` means otherwise, `chase_visibility` uses its values. | Presentation owner | With OQ-1 | Unresolved |
| OQ-3 | **ADR-0012 amendments** before it can be Accepted (rev 2 list):<br>0. `map_` gains `region_liberation_flag`, `liberated_kit_id`, `critical_path` legs, `base_stage` and `stage_table`. A `gag` Interactable kind with responses `line` / `change` / `clue`. An optional `recruit_remark`. `faction_` gains `patrol_archetype_id`. Marker tags `faction_clue` and `optional_teach`.<br>1. A new occupation-stage record type, keyed by faction × stage. It holds caps (non-decreasing), civilian density, the lighting profile, `sky_card`, the set kit, ambience, the name-card subtitle and `liberation_grumble_min`. It also names a decree gag per raising flag.<br>2. Markers gain `min_stage`, with `symbol_id` / `liberation_flag` on clutter markers. Patrol paths are marked `loop` / `pingpong`.<br>3. `enc_` gains `victory_payoff` (`clue` / `open` / `item`).<br>4. `WorldState` gains liberated-marker sets, `stage_stored` per map, granted payoffs and `last_camp_registered`. This bumps the save schema. (Rev 4: `last_camp_registered` is not a WorldState field; see item 13.) Only position and facing are written per frame.<br>5. `WalkGrid` gains a `SAFE` cell tag baked from safe zones, and a runtime **blocker overlay**: one `set_blocked(cell, on)` path that updates both the leader's grid and the symbols' `AStarGrid2D`. Save positions are relocated on load.<br>6. `GroundMover.step` takes a speed parameter, a blocked-cell mask and a waypoint arrival tolerance. `AStarGrid2D` is pinned (`DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES`, jumping off, a fixed heuristic) for determinism. The corner-assist algorithm is specified.<br>7. Swept contact, and the per-frame order (exit before contact). Repaths are staggered by `repath_per_frame_max`.<br>8. The lighting profile is resolved per map × faction × stage (or liberated) before the map enters the tree. The ADR-0005 coordination is in OQ-5.<br>9. `validate_maps.gd` gains every [D] check in this GDD: safe-zone segments, `zone_rate`, bypass per stage, pressure floor, clue ordering, return markers in `SAFE`, payoff share, marker-to-patrol `R_vis`, and the collision sources of AC-30e.<br>10. New `OverworldConfig` fields (Tuning Knobs) and the invariant list I1–I18.<br>11. A control-manifest rule: no `Engine.time_scale` (next to the existing `SceneTree.paused` ban). Still absent from `control-manifest.md` at review 2.<br>**Rev 3 additions:**<br>12. **ADR-0002:** a same-instance in-mode fade transition for the checkpoint redirect (locks input, defers the Menu, not save-safe, emits the transition signals, no swap, no `mode_entered`).<br>13. **ADR-0002:** a machine-side `register_camp(camp_id)` so passing a CampSpot registers it while the machine stays the only writer of `last_camp_id` (rule 13a; replaces item 4's `last_camp_registered` in WorldState).<br>14. `SymbolBrain` contract: the six sub-states, `start_on` for Static, resume point (including contact in Patrol), cooldown, facing snapped to the displayed facing, turn pause, component check, notice cache, shared query budget, `path_dist`, pending paths, chase target and final approach, contact pending.<br>15. §5 thaw: Stunned plus 4-connected push for non-Static symbols; Static never pushed; Fled at the story encounter places the leader at its return marker under the wipe; grace starts on `transition_finished`; the payoff card.<br>16. Marker schema: Static symbol with `start_on`; checkpoint fields (requirement, `obtained_at`, outcome, return marker, linked `enc_`); `decree_gag` kind; `pickup` kind; payoff tells; `critical_path` legs with `to` = exit, `symbol_id` or CampSpot; `liberated_profile_id`; ChapterFlow steps naming `{map_id, leg_id}`.<br>17. `WorldState.on_map_entered()` takes the entry path, so Continue (`LoadedSave`) skips `on_map_reenter` respawn.<br>18. `WalkGrid`: connected-component labels for symbol-legal cells, updated by `set_blocked`, which also invalidates stored paths and the notice cache. `AStarGrid2D.update()` once at bake, then walls, `SAFE` cells and blockers applied, never `update()` again (probed: `update()` clears solids).<br>19. One overworld clock `ow_dt = min(delta, dt_max)` accumulated only in Exploring; `dt_max` read from Presentation, removed from `OverworldConfig`; `OverworldMode` processes before the camera and sprites (`process_priority`). Follower trail owned by `OverworldMode` (rule 2).<br>20. Performance section: notice-query cost, component labels, the 2 ms budget (OQ-19), the fenced-patrol benchmark case (AC-46). Also `validate_maps.gd`: the AC-30e class list, the GridMap default, the ordered bypass search, patrol legality, EntryPoint clearance, payoff tells, the step-list checks.<br>**Rev 4 additions (round 3):**<br>21. `SymbolBrain`: facing hysteresis and hold-when-stopped; old facing during the turn pause; round-robin query budget with Returning inside it; cheap checks before any search; bounded notice search with per-symbol waypoint cache; A* origins snapped to legal cells; final-approach legality and the symbol mover mask; `path_dist` as arc + gap at compute + leader travel.<br>22. `WalkGrid`: 4-connected component labels; batched `set_blocked(cells, on)` with one relabel per frame; `AStarGrid2D` `region`/`cell_size`/`offset` frozen after bake, `is_dirty()` debug assert, `allow_partial_path = false`.<br>23. Clock and order: sprite animation driven from `ow_dt`; `_process` only; `process_priority` −10 / 0 / +10 for mode / camera / sprites.<br>24. `validate_maps.gd`: Counter and boss placement, `return_safe_radius_m` discs, no-route-round-the-story-encounter, junction coverage, I18, `SpringArm3D` and the CSG ban, reachable stages from the step list.<br>25. The walk home: the boss-chamber → segment map change, the last-leg exit disable, the P15 chapter-end prompt. | technical-director (`/architecture-decision` amend ADR-0012); **items 12–13 also need the Game State owner** (ADR-0002 amendments) | Before ADR-0012 acceptance | Unresolved |
| OQ-4 | `content-data-definitions.md` Rule 1 must add the `map_`, `enc_` and occupation-stage record types. | Content Data owner | With OQ-3 | **Resolved 2026-10-23:** Rule 1 has `map_`, `enc_`, `ostage_` and `faction.patrol_archetype_id` |
| OQ-5 | `sprite-camera-presentation.md` and **ADR-0005**:<br>• point the Overworld dependency row and Open Question 6 at this GDD;<br>• lighting profiles per faction × stage and a liberated profile;<br>• `sky_card`;<br>• the travelling interior light pool (a set-only `OmniLight3D` warmed at Boot), or drop it;<br>• tilt-shift blur bounds per `chase_visibility` (measured from the leader, with `H_max`), in place of any sprite exemption; confirm that Godot DOF uses view-space depth (Step 1);<br>• the interior light exists from the first frame, is never toggled, keeps a fixed shadow flag, and is present during Boot warm-up (probe, review 2);<br>• per-cue capture-ID tags in the capture tool (§13) for AC-44a/b, AC-32. | Presentation owner + technical-director | Next presentation revision; before overworld art | Unresolved |
| OQ-6 | Art bible additions:<br>• §2: the stage-light rule (raise the fill, never darker) and the stage-sky L\* ≥ 60 floor;<br>• §2: the interior (Dungeon row) ruling;<br>• §2: the liberated presentation (rule 17);<br>• §3: the overworld icon grammar (notice slip and "!" tag, interact prompt, exit beacon, camp sign);<br>• §6: prop density per stage, the safe-zone kit, and liberation as the gradient in reverse;<br>• §3/§6: the guardrail-6 visual exclusions (no hanging banners, no worn badges, bolted-on signage) and the payoff tells (envelope, rolled poster). | art-director | Before overworld art production | Unresolved (the user ruled the two lighting questions on 2026-10-22) |
| OQ-7 | Accessibility doc:<br>• colour-only audit rows (Clerk notice and chase tag, checkpoint state, occupation stage, safe zone, interact prompt, exit beacon);<br>• the gameplay-critical SFX audit rows (Visual/Audio);<br>• point the Navigation assists row at rule 19;<br>• a Known Intentional Limitation row for "pointer ignored in the overworld", with the one-handed layout note;<br>• `accessibility_name` and live-region notes for the prompt, name card, payoff card and bark window under its OQ-1;<br>• clue and decree text shown as LocText on `confirm` (rule 16). | ux-designer | Next accessibility doc update | Unresolved |
| OQ-8 | **Defaults set autonomously, open to user veto:**<br>• Paris stages (rev 4): Town Contested (1); overworld segment base 1, always first loaded at 2 because `permits_mandatory` is set on the chapter's opening step; dungeon Saturated (3). Town stages 2–3 and segment stage 1 are not authored in MVP.<br>• Liberated areas keep liberation while their Clerk respawns per `on_map_reenter`.<br>• `f_chase` 0.8 and `symbol_chase_m` 3.0 (changed from the first proposal; see Formulas). | User | Next review | Unresolved |
| OQ-9 | A press-to-toggle "Fast Walk" setting, if playtests find traversal slow (AC-48; `chapter_walk_budget` predicts 6–9% of the chapter). | game-designer | Vertical Slice playtest | Deferred |
| OQ-10 | Ambush or first-strike: revisit only if Turn Battle adds a battle-entry modifier (rule 6). | game-designer | When the Turn Battle GDD is revised | Deferred |
| OQ-11 | The map name card, the payoff card, the bark window and the optional next-destination arrow are not in the interaction pattern library, and the camp prompt's Yes default must be added to P15's Used In list with its reason. Add them, or fold them into the overworld UX spec. | ux-designer | `/ux-design` for the overworld on-map UI | Unresolved |
| OQ-12 | Squad Roster supplies the party order (leader, followers). Until it is designed, ChapterFlow's interim party source is used (ADR-0012 §5). | game-designer | Squad Roster GDD | Provisional |
| OQ-13 | Story flags and NPC dialogue references. Rule 18's **interim MVP flag registry** fixes Paris's flags now. Dialogue, Banter & Quests later replaces the interim stub overlay, the registry and the interim `story_flags` in world state (ADR-0012 §4). | narrative-director + game-designer | Registry: before the first overworld story. Hand-over: Dialogue GDD | Partly resolved (rev 2; rev 3 re-timed the raises, added flag rows and the "every read flag is registered" check) |
| OQ-14 | ~~A liberated marker linked to a Clerk should sit within view of that Clerk's patrol.~~ | level-designer | — | **Resolved (rev 2):** rule 9 Placement and AC-26c |
| OQ-15 | **Story encounter (creative-director ruling, open to user veto).** Each region has one telegraphed, unavoidable fight (Paris: the Permit Counter, renamed from "Intake Desk" in rev 3 because "intake" reads as processing people), started by `confirm` only (rev 3), and guardrail 1 is reworded to allow it. The alternative is fully optional fights everywhere, relying only on victory payoffs (rule 7a) to motivate fights. | User | Before re-review | Default applied |
| OQ-16 | **Liberated presentation (creative-director ruling, open to user veto).** After the boss, the stage value stays but the presentation reverses to golden hour (rule 17). This keeps the 2026-10-22 ruling "stages never go down" while honouring the art bible's "the return of golden-hour light is the reward". Is this a stage decrease in disguise, or acceptable? | User | Before re-review | Default applied; rev 3 adds the guaranteed walk home (rule 13) and keeps it uncelebrated |
| OQ-17 | **Facing-weighted notice (creative-director ruling, open to user veto).** Clerks notice at 1.5 m behind them versus 3.0 m in front (rule 5), which allows sneaking. The alternative is an all-round radius. | User | Before re-review | Default applied |
| OQ-18 | `game-state-scene-flow.md` rule 9: "last camp visited" becomes "last camp registered". Passing a CampSpot's safe zone also registers it (rule 13a), so Retreat from the boss never sends the squad back across the region. | Game State owner | Next Game State revision; with OQ-3 | **Resolved 2026-10-23:** Game State rules 2, 4 and 9 synced; ADR-0002 §11 |
| OQ-19 | The overworld's share of the frame budget (2 ms at p99 for symbol AI, AC-46). | technical-director | Before the first overworld story | **Resolved 2026-10-23:** `project.yaml` `performance.per_system.overworld_ms: 2.0` (user accepted) |
| OQ-20 | **Stage raises (creative-director ruling, open to user veto).** Raises happen only on the faction's schedule (ChapterFlow step changes, never a player Victory or map entry) and only on maps the player has not yet entered. Paris MVP therefore has one raise (`permits_mandatory`, segment 1 → 2, set on the chapter's opening step since rev 4), the Town moves to stage 1, and Town stages 2–3 are cut. MVP never shows a stage rising on screen; the raise exists as decree flavour ("in force since Tuesday"). The alternatives were a required return leg (rejected as a toll road, guardrail 1) or keeping raises the player never sees. | User | Next review | Default applied |
| OQ-21 | The title's own joke ("Go back to your planet!") versus guardrail 6: this GDD bars "go back" lines from overworld civilians and barks only. The project-wide rule (who may say it, where, and how it avoids punching down) belongs in the narrative bible with creative-director sign-off. | narrative-director + creative-director | Before any dialogue writing | Unresolved |
| OQ-22 | **Permit Counter and walk home (creative-director rulings, open to user veto).** The story encounter starts on `confirm` only, and Fled sends the squad to its return marker with a gag line. After the boss, a fade takes the squad to the overworld segment's dungeon-side entry (rev 4, CD amendment), the way back is taped off, and the squad walks the liberated streets home to the café, where a P15 prompt (No by default) ends the chapter. `victory_payoff: none` is allowed with limits (rev 4). | User | Next review | Default applied |
| OQ-23 | Keyboard Esc is `cancel` and does nothing in Exploring, but PC players expect it to open the pause Menu (`input-system.md` OQ-1). Settle before the first overworld story. | Input owner + ux-designer | Before the first overworld story | Unresolved |
