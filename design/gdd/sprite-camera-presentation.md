# Sprite & Camera Presentation

> **Status**: In Review (revision 7, pending a short re-review)
> **Author**: user + agents
> **Last Updated**: 2026-10-22
> **Last Verified**: 2026-10-22
> **Implements Pillar**: Readable in One Turn (lighting signatures, actor-first read order); The Joke Is the Mechanic (silhouettes and reaction frames)
> **Creative Director Review (CD-GDD-ALIGN)**: REVISED 2026-10-21. Concerns resolved: every faction's boss light is equally lavish, and a missing preset is a boot error; combo grouping is an open question; a Battle Speed toggle was added. (The original "punchlines are protected from the automatic speed-up" item no longer applies: the automatic speed-up is deferred, Open Question 16, and protection now covers the boss entrance only, rule 9.)
> **Revision history** (full findings and rulings: `design/gdd/reviews/sprite-camera-presentation-review-log.md`):
> - **Revisions 2–4 (2026-10-21/22)** answered three reviews. They introduced the replay controller (ADR-0006), unscaled reaction holds, the boot-validated `impact_frame`, the flash gate's coverage of every source, chained knob ranges, and the end-of-fight holds.
> - **Revision 5 (2026-10-22)** answered the fourth review (MAJOR REVISION NEEDED). It brought in one latch level, the menu input guard with feedback, deferral of the automatic speed-up, a full boss takeover on first encounter with a settle on Retry, screen-aligned billboards, and the amended flood ruling.
> - **Revision 6 (2026-10-22)** answers the fifth review (NEEDS REVISION, ~30 blocking items in groups A–E). Creative-director rulings applied:
>   - **(1)** With **"Speed up boss entrances"** On (the renamed "Speed up all replay beats"), the boss entrance takes the plain-beat speed, Battle Speed included, with no press. By default nothing speeds it.
>   - **(2)** Knockout wind-ups are plain beats. The knockout hold is `max(ko_hold, the slump's landing time)`, always at 1×.
>   - **(3)** The replay indicator gets a passive state, and a press that changes nothing gets the refusal feedback. Clicking the indicator while latched un-latches. `battle_speed_mult` is strictly below `ff_mult` (1.5 / 2.0). The setting is labelled "Faster battle animations: Off/On".
>   - **(4)** Dusk floods (no polarity flip), a backdrop sky card, constant integer texels (`T = H/360`) and a level, shift-lens battle camera. Upright-card occlusion stays for the pitched Overworld and Camp cameras.
>   - **(5)** A measured shader-compile contract replaces "presets change values, never features".
>   - **(6)** The gating split.
>   - **(7)** Mechanism and procedure moved out: to ADR-0005, to ADR-0006 and to the new test plan `production/qa/test-plans/sprite-camera-presentation-test-plan.md`. Rules are now guarantees, knobs and formulas, and ACs are observable outcomes with test-plan procedure IDs.
>
>   The four (D1–D4) art-direction rulings were adopted in autonomous mode and **ratified by the user on 2026-10-22**, D1 on condition that dusk skies show some stars (Open Question 18, resolved).
> - **Revision 7 (2026-10-22)** answers the sixth review (targeted; NEEDS REVISION, 11 local blockers). Flash bookings follow each source's own clock and re-book on freeze or speed change; a capped variant is capped on red as well as luminance. The dusk sky is dark outside a `horizon_band_frac` band, with a mean-L\* ceiling and the user's **stars** (single-texel, sparse, slow twinkle, area-exempt). read_order sectors are judged in a fixed order (geometry, size, lights), and the enemy-vs-flood test is per sector. The Victory curve starts from the captured light (no dip after a boss), the flood stays through Victory, and the results screen opens over the settle. The quad's left edge is `x_a − floor(frame_w·T/2)`. AC-24, AC-25 and AC-68 fixed; AC-4, AC-11, AC-14b, AC-26, AC-34, AC-55, AC-56 and AC-69 tightened; the test plan gains the frame-0 convention, the AC-67 step and the new read-order and flood steps. Steam Deck (1280×800, `T = 2`, 16:10) is a target.

## Summary

Sprite & Camera Presentation decides how the game world looks on screen:
- every character is a pixel-art sprite drawn at one on-screen pixel scale, lit inside a low-poly 3D toy diorama;
- every mode has a fixed camera;
- every game state (overworld, battle, boss takeover, camp, victory, defeat, the frozen Menu) has its own lighting signature.

For the player, a glance tells them where they are and what's at stake before reading anything, and the jokes land in crisp reaction frames because the scenery always steps back. It also replays each resolved action beat by beat (through the Battle mode's `BattleReplayController`, ADR-0006), so an instantly resolved enemy phase stays readable. And it freezes the whole world while the Menu is open.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Game State & Scene Flow, Content Data Definitions, Turn Battle System`

## Overview

Sprite & Camera Presentation decides how everything in the game world is shown: how characters and enemies are drawn, where each mode's camera stands and how it may move, and which lighting signature the game is in at any moment. Characters, enemies and comedy effects are pixel-art sprites standing inside lit, low-poly 3D toy dioramas. Every sprite texel is the same whole number of screen pixels in every mode and at every distance, the set always stays calmer than the actors, and each game state (overworld, battle, boss battle, camp, victory, defeat, menus) has its own lighting, so the player knows where they are before reading anything. Cameras are fixed per mode: a level, fixed battle camera framing a Dragon Quest / Chrono Trigger arc, a fixed-angle follow camera on the overworld, and fixed framing in camp and on the title screen.

The player never operates this system, but they see it in every frame. It makes the Visual Rule true in play: *paint the rules in light and color; tell the jokes in pixels; and never let one hide the other.* Lighting and color carry information (whose fight this is, which faction's rule is in force, whether the squad won or lost), and the sprites carry the comedy. Without it, the game would still play, but each fight would need a tutorial line to say where you are, and gags would compete with the scenery for the eye.

This document states **what the player sees, when it changes, and what must never happen**, with the formulas and knobs behind it. **How** it is built lives elsewhere:
- `docs/architecture/adr-0005-sprite-camera-presentation.md`: the sprite shader, the diorama stage, the lighting profiles, the cameras, the sky card, the flash gate service and the compile contract;
- `docs/architecture/adr-0006-battle-replay-ownership.md`: the battle replay controller (queue, clocks, latch, call order);
- `production/qa/test-plans/sprite-camera-presentation-test-plan.md`: the test harness, the capture tool, the flash analyser, the benchmark and the playtest procedures that the ACs name.

Where this document and an ADR seem to differ, the ADR is the mechanism and this document is the requirement it must meet.

## Player Fantasy

**"One glance tells you where you are, and the stage steps back so the joke can land."**

The player never operates this system. They feel it on every screen as the sense that the game is always staged for them. Each state has its own light. The overworld sits in golden hour like a toy left on a sunny table, camp glows with firelight, and the Menu freezes the world into a soft blur behind calm navy windows. A glance tells the player where they are before they have read anything. When a battle wipe opens, the set dims and softens, and every combatant stands out in crisp rim light. The player sees who is fighting and what rule they are up against within one turn. Because the stage has stepped back, the jokes can be loud: the oversized wind-up, the smug combo pose and the slump all land in sharp pixels with nothing pulling the eye away. When a boss arrives, the sky goes to a deep dusk in its faction's color with a neon horizon, and the player knows the fight has escalated without being told. Defeat is a brief spotlight and a wry stamp, never a funeral.

**Anchor moment:** the first battle wipe opening on a dimmed diorama with the whole squad rim-lit in front of it. If that frame reads at a glance and the first reaction frame gets a laugh, the system is doing its job.

**Pillars served:**
- **Pillar 4, Readable in One Turn**: "A new player understands any fight's rules within one turn." Light tells you the state and the stakes.
- **Pillar 1, The Joke Is the Mechanic**: "Every gag must do something in play." The stage yields so the reaction frames carry the comedy.
- **Pillar 2, Nobody Is Right**, through every faction's boss takeover getting an equally lavish light.

These follow the art bible's Visual Rule: *paint the rules in light and color; tell the jokes in pixels; and never let one hide the other.*

> Framing chosen with `creative-director` (three candidates: readability, punchline stage, light-as-territory). The recommended one, readability with the punchline as its payoff, was taken. Light-as-territory, the occupation gradient and liberation, belongs mainly to the Overworld GDD and appears here only as the boss takeover.

## Detailed Design

### Core Rules

**1. Actors before the set (read order).** In every mode, the eye goes to the actors first, the rule indicators second and the set last (art bible Principle 2). Concretely:
- **Actors have their own light.** An actor is lit by its own key light and its rim, plus any practical light the stage tags as lighting actors (the campfire, so its flicker plays on the squad). An actor never takes the environment's ambient light, the fill or the set light. The actor key is never faction-colored: neutral in Battle, warm in Overworld and Camp (Visual Requirements).
- **The set has its own light**, which never touches an actor.
- **Every actor keeps a rim in every lighting state**, including a boss takeover. The rim sits on the ring of texels just inside the actor's Outline Ink outline, never on the outline itself. It is permanent, never situational.
- **Every actor stands out from the set around it, on every side.** The test is local and per side, not a whole-frame or whole-perimeter average, so a dark costume, the Defeat state and the Camp fire are judged fairly, and an actor can't pass on its bright side while vanishing on its dark side. On each state's reference capture, the contrast between the actor's rim band and a ring of set pixels around its silhouette reaches `actor_contrast_min` in every sector of the ring (Formulas, `read_order`).
- **Set saturation stays below the actors'.** This is judged by the art director rather than measured, since a deliberately grey character is legal.
- **Emissive set lights** (the campfire, lamps, signs) are tagged in the stage and left out of the ring. They are allowed to be bright, as long as they are not behind an actor's silhouette at the default camera.
- **Set brightness.** In Battle, the set sits at `set_brightness_battle` of its native lit brightness (Formulas; 0.70 by default, the art bible's "dimmed 30%"). In a boss takeover it sits at `set_brightness_boss`, which is at least the Battle level and always below 1.0.
- **The environment yields.** Any environment element that the per-state screenshot review (AC-32) finds drawing the eye before an actor is filed as a content bug.

**2. One pixel scale on screen, everywhere.** Every sprite in every mode (squad, enemies, NPCs, comedy VFX) is drawn so that **each of its texels covers exactly `T × T` screen pixels**, with `T = max(1, floor(H_screen / 360))` (Formulas, `texel_scale`). That is 3 px at 1080p, 4 px at 1440p, 6 px at 2160p and 2 px at 720p.
- **Distance never changes a sprite's size.** A sprite near the camera and one far from it have the same texel size on screen. Depth decides only what hides what (occlusion) and where a sprite stands in the frame. So mixed pixel scale can't happen in any mode, at any window size.
- **Fixed sizes.** Humanoids are one fixed height, the single `humanoid_height_px` value (48–64 texels) in presentation data. Large aliens are clean integer multiples of it.
- **Filtering is nearest-neighbor, always.**
- **No rotation or rescaling, ever.** A sprite is never scaled or rotated: not for juice, not for a gag. A gag that needs a bigger sprite is a separate, bigger sprite drawn at the same scale.
- **Sprites face the screen.** Every sprite's quad is parallel to the screen, so every texel is square.
- **Feet stay planted, and texels never crawl.** The bottom-centre of a sprite's quad sits on the screen point where its foot anchor on the ground projects, snapped to whole screen pixels every frame, in every mode. The quad's left edge is that snapped point minus `floor(frame_w · T / 2)` pixels, so a quad an odd number of pixels wide still starts on a whole pixel and every texel column is exactly `T` px (Formulas `texel_scale`). A walking sprite therefore never shows a sub-pixel phase crawl. Because its size is constant, its texel rows never change height either.
- **Occlusion is an upright card at the feet.** For occlusion, each sprite behaves as an upright card standing at its foot anchor, facing the camera's direction across the ground. Set geometry in front of its feet hides it, and geometry behind its feet never cuts into its upper body. With the level battle camera (rule 4), that card is the sprite's own screen-facing quad. With the pitched Overworld and Camp cameras, the card is upright while the quad faces the screen, and the guarantee still holds (ADR-0005 owns the build).
- **Depth of field never blurs an actor.** In Battle, the background blur starts behind the farthest actor slot, and there is no near blur, so the party row in front of the camera stays sharp.

**3. Two facings, mirrored with exceptions.** Each character is authored with exactly two facings, `back` (party side, back three-quarters) and `front` (enemy side, front three-quarters). The opposite left/right direction comes from mirroring. In Battle, mirroring follows the formation side; in the Overworld, it follows movement direction. **Never mirrored:** an animation whose art carries text, a printed glyph or a directional faction shape (a stamp, an eye glyph, a barcode, an arrow), or whose joke depends on handedness (a right-handed baguette swing that would turn left-handed). The `no_mirror` flag is set **per animation** in the sprite set's art data, so a character whose idle is safe to mirror but whose stamp attack is not only needs the stamp attack drawn twice. A `no_mirror` animation is authored for both directions, or for the one direction it is used in. No camera may expose a third facing (rule 4).

**4. Cameras are fixed per mode.**
- **Battle: a level camera with a shifted lens.** One fixed camera per battle stage, on the Dragon Quest / Chrono Trigger arc (the party seen from behind three-quarters, the enemies from the front). It is **level**: it never tilts up or down. It frames the ground by shifting its lens instead, which places the horizon `horizon_frac` of the way down the frame (Formulas, `battle_framing`). So the set's verticals stay vertical, and the upright sprites stand like the set's own verticals rather than leaning back against them.
  - The camera never moves, rotates, zooms or changes its field of view during a fight.
  - The only motion allowed is the hit-punch (rule 8), which is a small extra lens shift of the whole view.
- **Staging the arc.** Sprites are the same size at every depth (rule 2), so rows are separated by where they stand in the frame:
  - the party row stands nearest the camera, lowest in frame;
  - the enemy row stands farther back, higher in frame by perspective;
  - the sky shows above the horizon, at least `sky_share_min` of the frame on a boss stage (rule 6);
  - every actor is at least `actor_visible_min` (90%) visible at the default camera, not hidden by another actor or by set geometry. Rows stand far enough apart in the frame, or their slots are staggered sideways, so that no back-row enemy is mostly hidden behind a party member (Formulas, `battle_framing`);
  - the party's back-three-quarter jokes are staged to read from behind: the gag's shape sits in the silhouette and the side the camera sees, never only on the face (Visual Requirements).

  Each battle stage is checked against these limits when it loads.
- **Overworld:** a follow camera at one fixed downward angle. It moves with the party and never rotates. It settles smoothly, never overshoots or bounces, and does not move while any overlay is open. Its view never shows ground beyond the map at any supported window shape (Formulas, `follow_camera`).
- **Camp and Title:** fixed framing, with no follow and no hit-punch. Camp's camera may look down at a fixed angle.

**5. One lighting signature per state, switched invisibly.** Each state has the signature in the States table below. When Game State enters a mode, that mode's signature is already in place by the time the transition reveals the scene: the switch happens fully hidden behind the wipe or fade, so the player never sees a light pop. A boss battle enters directly in Battle light and then takes over (rule 6).

**6. In-mode changes are visible blends.** Three changes happen inside a mode, and all three are blends the player is meant to watch.

**Boss takeover.** At the start of a boss fight, over `blend_boss`, the sky goes to a deep **dusk** in the boss faction's hue with a neon horizon, the set and fill lights take the faction's hue, and the set's contrast hardens. The actors' key and rim stay neutral (rules 1 and 11), and the set rises only to `set_brightness_boss`, still below 1.0. When the blend ends:
- **The sky is the faction's dusk flood.** Each faction has one flood swatch in art bible §4: its signature hue, a chroma, and an L\* range at or below `flood_l_max` (35, deep dusk). The sky is a backdrop card behind the set (ADR-0005), so it is always where the camera can see it. It keeps a gradient and clouds, and a **neon horizon band** just above the horizon glows lighter in the same hue; nothing else in the sky is lighter than the swatch. **Some stars** show in the upper sky (user condition on D1): sparse, single-texel, gently twinkling, and never counted as a flash. At least `sky_match_min` of the visible sky pixels match the swatch's hue and chroma (Formulas, `flood`).
- **The sky is seen.** Every boss stage is framed so that, at the default battle camera, the sky covers at least `sky_share_min` (20%) of the frame. A takeover the player can't see the sky in is not a takeover.
- **The flood is mid-saturation, never full.** The flood's chroma is at most `flood_chroma_frac` (≤ 70%) of the faction's signature chroma, and lower where a dusk lightness can't hold that chroma (Terminal Cyan at dusk holds about C\* 21; Formulas). The art bible keeps full saturation for the actors and rule UI.
- **The flood is unmistakably not the stage's own sky.** Every boss stage's own sky is at least `flood_native_de_min` (ΔE2000 15) from its faction's flood swatch. The swatch is one per faction and never changes per stage. A stage whose own sky is too close (a night stage under Anthem Blue's dusk) has its own sky re-authored.
- **The squad reads light against the dark.** Every flood is dark, so the neutral rim carries the read on every faction's takeover, and one read-order test serves all of them. There is no special case.
- **A boss stays readable in front of its own flood.** Every enemy's costume differs from the flood around it by at least `enemy_flood_de_min` (ΔE2000 15), so a red boss can't vanish into a red sky (Formulas, `read_order`). Parity between factions is lavishness, carried by coverage, gradient, the horizon glow and energy, not by equal lightness or chroma (Visual Requirements).
- **The set has the hardest contrast in the game.** The flooded fill runs at low energy, so the set's key-to-fill ratio reaches `set_key_fill_ratio_boss`, higher than in any other state. The set light keeps the stage's Battle direction. The actor key is unchanged.
- **A hold of `boss_hold` follows the blend.** The boss plays its required `intro` animation (rule 10) in the new light, its frames on the takeover's own clock (ADR-0006). If `intro` is shorter than `boss_hold`, it holds its last frame. An `intro` longer than `boss_hold` at 1× is a boot content error.

**How the takeover plays.**
- **It holds the battle.** No beat plays and no command menu opens until the takeover has finished.
- **It starts when the player can see it.** It begins on the first fully revealed frame after the battle wipe (`t_blend = 0` on that frame), never behind the wipe.
- **It plays in full on first encounter**, the blend and then the hold, at 1×. It is the one **protected** moment in MVP: no press and no setting shortens it, unless the player has turned on "Speed up boss entrances" (rule 13). Then it plays at the plain-beat speed: faster with Faster battle animations On, and faster again once latched, with no press needed for the first.
- **On Retry it only settles.** The takeover's end-state light is applied hidden behind the retry flash, so a Retry never makes the player watch the blend again. When the retry flash ends, the boss holds the last frame of its `intro` for `boss_retry_hold` before the first command menu. The settle plays at the plain-beat speed.
- **One clock drives it.** The blend and the boss's `intro` frame both come from the takeover's own clock (ADR-0006). The stage runs no animation of its own for it.
- **Prerequisite.** None of this can be built until the Battle mode, not `ChapterFlow`, constructs and starts `BattleCore` (ADR-0002 Migration Step 2: Dependencies).

**Victory.** A white-warm burst over `blend_victory` raises the actors' key and rim, and the squad plays its `victory` fanfare poses (rule 10). The set rises from wherever it is (its Battle level, or its boss level after a boss fight) to at most `set_brightness_victory`, still below 1.0, at the burst's peak (the end of `blend_victory`). It then settles over `victory_settle` toward the stage's own native light, at `set_brightness_victory_settle`, still below 1.0. That is golden hour on most overworld-style stages, but a dungeon stage settles to its own light. So the fanfare poses stay the brightest thing on screen.

**Defeat.** Over `blend_defeat`, the set desaturates and drops to `set_brightness_defeat`, and one soft, wide, neutral (not cold-blue) overhead spotlight pools on the **party row's formation centre**, so the squad stays lit and readable in its knockout poses. It is a wry curtain call, not a funeral: no vignette to black, no slow fade, and the actors keep their key and rim.

**The end of the fight gets its moment.**
- After the last beat, the Battle mode starts the Victory or Defeat blend and waits `victory_hold` or `defeat_hold` (each at least as long as its blend) before it reports the outcome to Game State. So the results screen and the Defeat Prompt open only after the fanfare or the curtain-call poses have been seen.
- These holds always play at 1×.
- A press during them does nothing and is not buffered.
- Leaving the battle during them (Quit to Title from the Menu) cancels them, and nothing from them plays later.

The Battle mode requests each change when its own battle-flow beat arrives: the takeover when a boss fight starts (it knows the fight is a boss fight, and which faction, from its encounter descriptor, ADR-0002 §7), and Victory or Defeat when the replay releases the end of the battle after the last beat. This system decides only how they look. Durations and levels are in Formulas and Tuning Knobs.

**7. The Menu freezes the world.** While the Menu is open, nothing in the world moves: no sprite animation, no camera motion, no lighting blend, no flicker, water, foliage or particles. The frozen frame stays visible behind the Menu, blurred (UI Framework draws the blur, rule 11). Closing the Menu resumes everything exactly where it stopped. Dialogue and the Defeat Prompt do **not** freeze the world: they block input, not time.

Battle replay beats freeze too, because the replay runs on the Battle mode's mode time (ADR-0006). Beat-synced sound (hit and knockout effects) belongs to the Audio Manager, which times it from the replay's beat events, not from its own clock. A held beat therefore fires no sound under the Menu. Whether music ducks under the Menu is the Audio Manager's decision.

**8. Hit-punch.** A beat whose outcome lowers a target's HP may shift the battle view by `shake_amplitude` for `shake_duration` (Formulas, `hit_punch`), decaying once with no ringing. The rules:
- **At most one punch per beat.** In MVP one outcome is one beat (rule 9), so a move that resolves as several outcomes gives one punch per outcome. Grouping several outcomes into one punch waits for Open Question 5b.
- **It starts on the beat's impact**, together with the target's reaction (rule 9). Its time starts at 0 on that frame and runs at 1×, whatever the speed settings.
- **A big beat knocks harder.** A knockout, or a hit by the encounter's boss (named by the Battle mode's encounter descriptor), uses the large amplitude.
- **Punches never overlap.** Two impacts are always at least one reaction hold apart, that hold never speeds up, and the load rule `D < reaction_hold` (Formulas, `replay_time`) keeps every punch shorter than it.
- **Never during the boss takeover**, its blend or its hold. A punch requested then is dropped, not deferred.
- **It follows the comfort settings.** It never plays when Screen Shake is Off or Reduce Motion is On, and plays at the Reduced amplitude when Screen Shake is Reduced (rule 13).
- **It looks the same size at every resolution.** The amplitude is set in pixels at 1080p and scales with the window's height.
- **It moves everything by the same whole pixels.** Near actors, far actors and the set all shift by the same whole number of screen pixels, so nothing shimmers and there is no parallax. The camera's position, rotation and field of view never change (ADR-0005 owns the mechanism).
- **The HUD never shakes**, and a sprite's foot position on the ground never slides.

**9. Actor beats play at animation pace (battle sequencing).** Turn Battle resolves instantly: one submitted command resolves that squad member's action and every enemy action that follows it, up to the next squad turn or the end of the battle, all in one call. The Battle mode's `BattleReplayController` holds all of it, and this system **replays** it one beat at a time, in order, at animation pace. It never renders what Turn Battle has already computed all at once.

This rule states what the player sees. ADR-0006 owns how: the controller's states, signals, call order, clocks, latch and outcome-to-animation map. Formulas' `replay_time` gives the timing it implements.

**A replay** is everything between one command menu and the next (or the end of the battle). The boss takeover before the first turn (rule 6) is a replay too. Each outcome is one beat.

**Inside one beat**, in this order:
1. **Wind-up.** The actor plays its action up to the impact, which is the action animation's `impact_frame`:
   - a special plays its own animation (the generic `attack` if it has none);
   - Defend plays the actor's `defend` pose, never an attack.

   The wind-up is the only part of a beat that ever speeds up.
2. **Impact.** On one frame, everyone the outcome affected reacts together, and the hit sound plays:
   - **HP lost:** `hit`, or `knockout` if the combatant fell. The hit-punch starts (rule 8).
   - **HP gained:** a `heal` reaction where the art has one; otherwise the combatant keeps its pose.
   - **A target whose HP didn't change:** an Attack that did no damage reacts with `hit`. Any other move that changed no HP (Speak to the Manager's stun, Viral Stunt's debuff) reacts with `status`, or `hit` where there is no `status` art. There is no punch.
   - **The actor never reacts to its own action.** If the actor's own HP changed (a party heal that includes the healer), it keeps its action pose and still gets its number at the beat's end.

   A party-wide heal reacts on every healed member other than the actor. A number still showing over any reacting combatant from an earlier beat is cleared on this frame, so each new reaction frame is clean.
3. **Reaction hold.** The reaction frame is held clean, with no number over it. The hold always plays at 1×: no speed setting or press shortens it, though the Menu still freezes it. The joke is seen before the number.
   - A plain beat holds for `reaction_hold`.
   - **A knockout beat holds until the slump has landed**: `ko_hold`, or longer if the knockout animation's landing frame comes later (Formulas, `replay_time`). The slump is the punchline.
   - **A beat with no reactor** (Defend) has no hold.
   - **The floor.** If a beat would otherwise end before `beat_min`, the hold is extended to fill the gap: padding always sits on the reaction frame, never before the wind-up.
4. **Number.** When the hold ends, the beat ends:
   - the HP bars move to their new values;
   - a floating number appears over **each** combatant whose HP changed, so a party heal shows one number per healed member;
   - **a combatant whose HP didn't change gets no number, never a "0"**;
   - MP and status tags update at the same moment. There are no MP numbers in MVP.

   The HUD reads all of this, and the round counter, only through the replay's displayed state (ADR-0006). The number then rises and fades on its own while the next beat starts.

**Between beats and turns.**
- **Round changes.** MegaCorp's per-round MP bill, which belongs to no outcome, shows when the round changes, after the round's last beat, together with the new round number.
- **Turn changes.** The changes the battle makes as a turn begins (a Defend wearing off, a stun clearing) show when that turn is released, never earlier and never stale.

**After a beat:**
- the actor returns to `idle`;
- a combatant that reacted with `hit`, `heal` or `status` plays the rest of its reaction, then returns to `idle`;
- a knocked-out combatant plays `knockout` to its last frame and holds it until the battle ends or is retried.

An actor or reactor in the very next beat goes straight into it instead. So an enemy that Defends and then Attacks in one turn goes straight from its `defend` pose into its attack wind-up, with no idle in between.

**One clock.** Every beat-driven frame (the wind-up, the follow-through, every reaction and the boss's `intro`), the hit-punch and the beat's sound run on the replay's clocks. No beat-driven animation runs on its own sprite timer. Picture, punch and sound can't come apart at any speed, and the Menu freezes all of them together.

**Five guarantees:**
1. **The squad's next command menu opens only when the replay has finished.**
2. **Victory or Defeat is shown only after the last beat**, and the results screen or Defeat Prompt only after the end-of-fight hold (rule 6). The Defeat Prompt never opens over an unfinished animation.
3. **A beat never changes the battle result**; it only shows it.
4. **Every beat lasts at least `beat_min`**, after any speed-up, and no beat is ever skipped, even on a slow frame.
5. **The reaction hold is never shortened**, and **the first boss entrance is never sped up** unless the player turned on "Speed up boss entrances". Knockout wind-ups are plain wind-ups. When Turn Battle gains a combo or rule-trigger flag (Open Question 5b), those beats' landings, not their wind-ups, join the protected set. There is no automatic speed-up in MVP (Open Question 16).

**Speeding up a replay (the latch).** During a replay, one press latches a speed-up for the rest of that replay. Any of these presses does it:
- Confirm;
- `fast_forward`;
- a click on the replay indicator.

Once latched:
- every remaining wind-up plays at `ff_mult`;
- the Retry settle and, with "Speed up boss entrances" On, the first boss entrance play at `ff_mult` too.

The latch clears in three ways:
- **Cancel** clears it from the next frame, and so does a second click on the indicator, while any latch-dependent time remains in the replay. The pace returns to the player's setting (Faster battle animations or 1×). When nothing left would change, Cancel is refused like any ineffective press, and the latch simply ends with the replay (ADR-0006 §6).
- The latch also clears when the replay ends, so every replay starts unlatched.

There is one latch level and no global fast-forward toggle. `battle_speed_mult` is always clearly below `ff_mult`, so a press always helps even with Faster battle animations On. Holding `fast_forward` works as well, since its first press latches.

**A press that changes nothing is refused, visibly.** If nothing left in the replay would play differently after the press, the press gets the same "not yet" pulse and refusal tick as a too-early menu press (below). Some examples:
- Confirm while already latched;
- Cancel while not latched;
- any press while only knockout holds, or a first boss entrance with "Speed up boss entrances" Off, remain.

**Presses count only after the reveal.** Nothing in a battle accepts a press until the battle wipe or the retry flash has fully revealed the scene. Presses made while it is still covered do nothing.

**Input during a replay, and during the end-of-fight hold, is never buffered.** During a replay, Confirm, `fast_forward` and Cancel only set or clear the latch, so a press made during a replay can never pick a command in the menu that opens afterwards. During the end-of-fight hold, they do nothing. Cancel in battle never opens the Menu: Input Open Question 1's "Cancel with nothing to cancel opens the Menu" applies only in the Overworld and Camp, and in battle the Menu is opened by the `menu` action alone.

**Replay indicator.** For the whole replay, including the boss takeover, a small prompt shows that the game is playing out the turn. It has three states:
- **Active, unlatched:** "[fast_forward] Speed up".
- **Latched:** "Speeding up · [Cancel] Stop".
- **Passive** (dimmed, no verb): "Playing the turn". It shows whenever no press would change anything left in the replay, so the prompt never offers something it can't do.

The prompt is also a pointer target. Clicking it latches while active and unlatched, un-latches while latched, and is refused while passive.

**When a menu opens (input guard).** The command menu, target selection, the Defeat Prompt and the results screen open with the focus on an option and **nothing submitted**:
- the command menu focuses the command this squad member used last, if it is still available and costs no MP, or Attack otherwise. So a player mashing Confirm never spends MP by accident;
- target selection focuses the first living target;
- the Defeat Prompt focuses Retry, the cheapest mistake;
- the results screen focuses its one continue option.

For `input_guard` (0.15 s) after any of these opens, **every** menu action is refused: Confirm, Cancel, a direction, target selection and a pointer click alike. After that, every new press counts. Some other rules apply around the guard:
- **A refused press is never silent.** The focused option gives a short visible "not yet" pulse, and a soft refusal tick plays (the UI Framework plays it in MVP; the Audio Manager takes it over when it exists), so a player who pressed too early knows the game heard them.
- **Nothing held carries in.** A key, button or direction held since before the menu opened does nothing until it is released: no confirm, and no navigation repeats. Only a press that begins after the menu opens counts, once the guard has passed.
- **A resting pointer never steals the default focus.** Focus follows the pointer only after it has moved at least `pointer_switch_px` (Input rule 3) since the menu opened. A bumped desk doesn't move the focus.
- **OS key-repeat echoes never count as presses** (Input rule 2).

**Leaving mid-replay.** Every way out of a battle (Retry, Retreat, Quit to Title, or the mode being freed) cancels the replay, and the end-of-fight hold, at the start of its transition. Nothing from the dropped replay plays later: no beat, sound, number, punch, or Victory or Defeat light. A takeover cancelled partway leaves no half-blended light: the next state's light is applied behind the transition or the retry flash.

**Retry starts clean.** Behind the retry flash, the battle's display is reset to the restored battle: every number is cleared, every sprite returns to `idle` (knockout poses included), the HP bars show the restored values, and the punch and the indicator are gone. The first frame after the flash shows the battle as it starts.

There's no distinct "miss" reaction in MVP, because the battle data carries no miss flag (Open Questions).

**10. Missing art.**
- A character or enemy whose art reference is unknown stops the game at boot as a content error (Content Data rule 8). The only legal stand-in is the explicit placeholder art, a checkerboard, so missing art is always visible, never silent.
- **Required animations are checked at boot too.** A missing required animation is a boot content error, like missing art, so a battle never shows an idle where a reaction, a boss entrance or a fanfare should be, or an attack where a Defend should be. The required set:

  | Required animation | In which sprite sets | In which facings |
  |---|---|---|
  | `idle`, `attack`, `defend`, `hit`, `knockout` | every battle sprite set | each facing it is used in (both facings, or the mirrored one where mirroring is allowed) |
  | `victory` (the fanfare pose) | every squad sprite set | `back` |
  | `intro` | every sprite set an encounter names as its boss | `front` |

  The same boot check fails:
  - an action animation (`attack`, `defend` or a move-specific one) with no valid `impact_frame`;
  - a `knockout` with no valid `land_frame` (the frame where the slump lands; rule 9);
  - an `intro` longer than `boss_hold` at 1× (rule 6);
  - two move-specific animations in one set keyed by the same move name (Open Question 17).
- **Optional animations fall back at runtime.** Each missing optional animation falls back in the same facing, a warning is logged, and the battle is never blocked:

  | Missing animation | Falls back to |
  |---|---|
  | A move-specific animation (a special move's own wind-up, a future combo pose) | the generic `attack` |
  | `status` | `hit` |
  | `heal` | the combatant's current pose (no reaction) |
- **A fallback never breaks `no_mirror`.** Mirroring the opposite facing is a legal fallback only for an animation that may be mirrored (rule 3). For a `no_mirror` animation with no same-facing art, the checkerboard placeholder is shown instead, which only a debug build that skipped validation can reach.

**11. Faction color lives only where it means the faction's rule (art bible Principle 3).** A faction's signature color may appear in the light only during that faction's boss takeover, and in the overworld occupation stages the Overworld system will define. It never tints:
- the squad's sprites, their outlines or their rim light. Actors never take the ambient, fill or set light (rule 1), so a flooded scene can't tint them;
- the neutral Battle, Camp, Victory, Defeat or Menu light;
- fades and the retry flash.

In a boss takeover, the faction's hue goes on the sky, the set light and the fill light only; the actors' key and rim stay neutral (rule 6).

Faction color in light is always accompanied by that faction's shape on screen, so the meaning survives for colorblind players. Concretely, every boss stage carries at least one set-dressing element tagged as its faction shape (art bible: Bureaucratia's rectangles and stamps, MegaCorp's wedges and growth arrows), and it is inside the battle camera's view for the whole takeover (AC-37). Wipes may carry faction color only when the encounter belongs to that faction (Game State's Visual Requirements). The Menu's blur, the HUD, damage numbers and the Defeat card belong to the UI Framework and never take the scene's color.

**12. Shadows.** Every actor has a blob ground shadow under its foot anchor, in a chunky "toy block" style that the art director signs off (AC-34). The rules:
- **one shadow per actor.** In MVP, actor sprites cast no light shadows at all; the blob is their only shadow. This avoids a doubled shadow, the blob plus a cut-out shadow from the set light. A shadow traced from the sprite's outline, replacing the blob, is a stretch goal (Open Questions);
- **only one light in a scene casts shadows**: the set light, for the diorama's own geometry;
- **the blob's color comes from the current lighting state** (each preset's neutral shadow color: warm-dark in golden hour, a dim neutral in Defeat, never cold). It never carries faction color, even in a boss takeover;
- **the blob is offset along the set light's direction** by `shadow_offset`, so it falls the same way as the diorama's own shadows. The actor key light casts nothing, so following it would contradict the set.

**13. Comfort settings.** Six player settings change what this system shows; the UI Framework owns the settings screen.
- **Faster battle animations: Off (the default) or On.** On plays every wind-up and the Retry settle at `battle_speed_mult` (1.5×), with the same no-skip guarantee and the same `beat_min` floor. It never speeds the first boss entrance unless "Speed up boss entrances" is also On. It exists so players with motor limits don't have to press a button in every enemy phase. Only wind-ups speed up, and the reaction hold never does, so a typical replay with it On ends only about 1.3× sooner (Formulas, `replay_time` example). There is no 3× option in MVP.
- **Speed up boss entrances: Off (the default) or On.** On lets the first-encounter boss takeover play at the plain-beat speed: `battle_speed_mult` with Faster battle animations On, and `ff_mult` once latched. With Faster battle animations On, that needs no press at all. It is for players who can't sit through the entrance every time.
- **Screen Shake:** Full (the default), Reduced (half amplitude rounded down, same duration; Formulas) or Off.
- **Reduce Blur:** Off (the default) or On. On cuts the overworld tilt-shift, the battle background blur and the Menu's backdrop blur (drawn by the UI Framework) to `reduce_blur_factor` of their normal strength. It keeps the battle background dimmed, so it still reads as inactive.
- **Reduce Flashing:** Off (the default) or On. On makes **every gated source** (the victory burst, attack and comedy VFX, the retry flash, the wipes, the Menu and Defeat card transitions) always play its capped variant, a soft swell rather than a flash, even when the flash limit would allow the full one. Campfire flicker's swing is halved. The boss flood is a single slow change, never a flash on its own, and is unaffected.
- **Reduce Motion:** Off (the default) or On. On turns the hit-punch off, whatever Screen Shake says. It also stills ambient set motion (water, foliage, drifting particles) and swaps the victory confetti for a still sparkle. Lighting blends, sprite animation and the overworld follow camera are unchanged: they carry information, not decoration.

**Flash limit.** Flashing never exceeds `flash_rate_max` flashes in any one second, counted on what reaches the screen from all sources together (Formulas, `flash_gate`, which also gives WCAG's general-flash, red-flash and area definitions). **Every source that can change luminance over a large area goes through one gate:**
- this system's victory burst and boss flood;
- every attack and comedy VFX (impact bursts, the faction stamp, confetti);
- Game State's retry flash, wipes and fades;
- the UI's large-area transitions: the Menu's backdrop opening and closing, the Defeat card's stamp, and the results screen opening.

Each source is declared in its data as one of four classes:
- **Gated:** before playing, the source asks the gate, declaring when its luminance changes will land. If refused, it plays its **capped variant**: the same effect with no transition at all, a soft swell rather than a flash. Its luminance swing stays below `flash_luma_delta` **and** it makes no red transition (a refused red stamp swells in a desaturated or darker red), or else it covers less than `flash_area_min`. A source's transitions are declared on **its own clock** (the mode or replay clock it plays on), so if that clock freezes or changes speed, the gate re-books what hasn't landed yet (Formulas `flash_gate`).
- **Reserved:** a source that must reach its end state, the boss flood. Its changes are always booked, and the sources around it yield. Boot validation proves that the reserved sequences alone never exceed the limit.
- **Exempt by area:** the effect never covers `flash_area_min` on its own (a small hit spark). Exemptions add up: if the effects playing at once would together cover `flash_area_min`, the next one is treated as gated.
- **Exempt by swing:** the effect never swings `flash_luma_delta` (campfire flicker, a slow fade).

The classes, the declared changes and the hard limits are checked at boot. A source that declares no exemption is gated. Game State's and the UI's sources reach the gate through a service this system exposes (ADR-0005). Game State's GDD must adopt it (Open Question 11).

### States and Transitions

**Lighting states**

| State | Entered when | Switch | Leaves to |
|---|---|---|---|
| Title | Game State enters Title | Instant, hidden behind the fade | Overworld (fade) |
| Overworld | Game State enters Overworld (including returning from Battle or Camp) | Instant, hidden behind the fade or the reversed battle wipe | Battle, Camp, Title; Occupied/Dungeon variant on a map change |
| Overworld variant (Occupied town stages 1–3, Dungeon) | Overworld enters a map the Overworld system marks as occupied or dungeon (**provisional** until the Overworld GDD exists) | Instant, hidden behind that map's fade | Overworld or another variant |
| Battle | Game State enters Battle | Instant, hidden behind the battle wipe | Boss takeover, Victory, Defeat |
| Boss takeover | First encounter: the Battle mode starts a boss fight (boss and faction from its encounter descriptor). Retry of a boss fight: the retry flash | First encounter: a blend over `blend_boss` from the first fully revealed frame, then `boss_hold` on the boss's `intro`, both ahead of the first turn. Retry: instant, hidden behind the retry flash, then the `boss_retry_hold` settle | Victory, Defeat |
| Victory | The replay releases the battle's end as a squad win, after the last beat | Blend over `blend_victory` to the burst's peak, then the settle over `victory_settle`; the results screen opens after `victory_hold` | Overworld (after the results screen, via the reversed wipe) |
| Defeat | The replay releases the battle's end as a squad loss, after the last beat | Blend over `blend_defeat`; the Defeat Prompt opens after `defeat_hold` | Battle or, in a boss fight, Boss takeover (Retry: instant, hidden behind the retry flash), or Camp (Retreat: fade) |
| Camp | Game State enters Camp | Instant, hidden behind the fade | Overworld (fade) |

**Overlay effect (on top of any state)**

| Overlay | World motion | Lighting | Camera |
|---|---|---|---|
| Menu open | Frozen (rule 7) | Unchanged (frozen mid-blend if one was running) | Frozen |
| Dialogue open | Continues | Unchanged | The Overworld follow camera holds position |
| Defeat Prompt open | Continues | Defeat | Fixed battle camera |

**Retry** returns the battle hidden behind the retry flash, with Battle light (never Defeat light) and a clean display (rule 9). In a boss fight it returns the takeover's end-state light instead, and the boss settles for `boss_retry_hold` when the flash ends. The blend is not replayed on Retry (rule 6). If Reduce Flashing or the flash limit makes the retry flash play capped, it no longer hides the change, so the light change becomes a blend over `blend_defeat` starting with the flash rather than an instant swap: never a pop.

### Interactions with Other Systems

| System | Flows into this system | Flows out of this system | Who owns the interface |
|---|---|---|---|
| Game State & Scene Flow | Mode entered/exited; overlay opened/closed; transition started/finished; mode time, which stops under the Menu | The flash gate service, for the retry flash, wipes and fades | Game State owns the announcements and their order (ADR-0002); this system never polls |
| Content Data Definitions | Each Character/Enemy record's art reference (`sprite_set_id`) | Boot-time validation: an unknown reference, a missing required animation or a missing boss preset fails the catalog | Content Data owns the record and its validation; this system owns the table that maps art references to art, and the lighting presets (presentation settings, not content records) |
| Turn Battle System | The resolved outcomes, in order (who acted, on whom, the HP change, whether the target was knocked out), the round and turn changes, and battle won or lost. All of it arrives through `BattleReplayController` (ADR-0006), never from `BattleCore`'s signals directly. Boss or not and faction come from the Battle mode's encounter descriptor, not from Turn Battle | Nothing back into the battle rules | Turn Battle owns *what happened and when*. The Battle mode owns *requesting* the boss-takeover, victory and defeat signatures and drives the replay (ADR-0006). This system owns *how they look*. A beat can never change a battle result |
| Input System | One `pressed` per physical press, at its start, with no key-repeat echoes; navigation repeat; pointer events and the `pointer_switch_px` threshold | — | Input owns press semantics (its rules 2 and 3); the latch and the guard rely on them |
| Overworld Exploration & Encounters (**provisional**, no GDD) | The party position and facing, which the follow camera tracks; region/map type (free, occupied stage 1–3, dungeon) | Nothing | Overworld will own movement and map types; the follow camera's feel and the variant lighting are defined here |
| UI Framework (no GDD yet) | The comfort settings (rule 13) | A frozen world frame behind the Menu; a guarantee that no world lighting ever tints UI; the flash gate service, for the Menu backdrop, the Defeat card stamp and the results screen | The UI Framework draws the Menu blur, the HUD, damage numbers, the replay indicator, the Defeat card and button prompts. It runs the menu input guard with its refusal feedback, and the refusal tick in MVP (rule 9). It shows HP, MP, status, the round and the floating numbers through the replay's displayed state (ADR-0006) |
| Audio Manager (Vertical Slice) | — | — | No direct link. Both react to the same Game State announcements independently. Beat-synced battle sounds come from the same replay beat events this system plays to (the hit sound on impact), so sound and picture never drift. It takes over the refusal tick from the UI Framework when it exists |

> Specialists consulted (`workflow: full`, review mode `full`): `game-designer` (rules, states, interactions), `art-director` (per-state lighting intent, faction-color scope, mirroring exceptions, shadow look, rulings D1–D4), `technical-artist` (pixel scale, budgets, shadows, render edge cases), `ux-designer` (camera feel, shake, comfort settings, flash limit, input guard), `gameplay-programmer` (battle sequencing against the shipped synchronous `BattleCore`, testability), and `creative-director` (rulings across five reviews). Revision 6 moved every mechanism to ADR-0005 and ADR-0006, and every test procedure to the presentation test plan (ruling 7).

## Formulas

> Source: `systems-designer`, building on the `technical-artist`, `ux-designer` and `art-director` consultations; revised against five `/design-review`s. Every value is a **starting target** to tune on the development PC. Variables marked `data file` are tuning knobs. Rule names map as follows: `shake_amplitude` = `A_beat`, `shake_duration` = `D`, and `blend_boss`, `blend_victory` and `blend_defeat` are `blend_time` per state. Colors are CIELAB (D65), and ΔE is CIEDE2000, throughout.

### texel_scale

The texel_scale formula is defined as:

`T = max(1, floor(H_screen / texel_base_lines))`. Every sprite's quad is `frame_w × T` by `frame_h × T` screen pixels, in every mode and at every depth (rule 2). Its bottom-centre is the projected foot anchor, rounded to whole pixels (round-half-away-from-zero) every frame: `(x_a, y_a)`. Its pixel rectangle is

`x_left = x_a − floor(frame_w · T / 2)`, `y_bottom = y_a`,

so both edges always fall on whole pixels, including when `frame_w · T` is odd (an odd `frame_w` at `T = 3`), and every texel column and row is exactly `T` px.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| T | int (px) | ≥ 1 | calculated | Screen pixels per sprite texel, on each axis |
| H_screen | int (px) | ≥ 720 | calculated | Window height |
| texel_base_lines | int | 360 | constant | The logical sprite resolution's height (creative-director ruling 4, D3) |
| frame_w, frame_h | int (texels) | per sprite set | data file (sprite set) | The animation frame's size; a humanoid's `frame_h` covers `humanoid_height_px` |

**Output Range:** `T` is 2 at 720p, 3 at 1080p, 4 at 1440p and 6 at 2160p. Between those heights it rounds down, so at 900p `T = 2` and a 64-texel sprite is 128 px tall: 14% of the frame, against 18% at 1080p. Sprites never blur or mix scales at any height, but their size relative to the frame steps with `T`. Sub-720p windows are unsupported.
**Example:** a 64-texel-tall sprite at 1440p is `64 × 4 = 256` px tall, wherever it stands. A foot anchor projecting to (812.5, 900.49) is drawn at (813, 900). At 1080p a 33-texel-wide frame is 99 px wide, so its left edge is `813 − 49 = 764` and its right edge 863: 33 columns of exactly 3 px.

**Steam Deck (1280×800, 16:10):** `T = floor(800/360) = 2`, so a 64-texel humanoid is 128 px, 16% of the frame height. 16:10 is below 16:9, so the battle camera's widened vertical view applies (Formulas `battle_framing`, `F_v_eff`).

### battle_framing

The battle_framing formula is defined as (rule 4, a level camera with a vertical lens shift):

```
f_px     = H_screen / (2 · tan(F_v_eff / 2))        vertical focal length in pixels
y_h      = horizon_frac · H_screen                 horizon row, from the top of the frame
y_foot(z) = y_h + h_cam · f_px / z                 row of a foot anchor at view depth z
q        = frame_h · T                             a sprite's quad height in pixels
row_gap  = y_foot(z_near) − y_foot(z_far) = h_cam · f_px · (1/z_near − 1/z_far)
```

A battle stage is valid iff all of these hold, at every supported window shape:
- `0 < z_near ≤ z_far`, and every actor's quad lies fully inside the frame;
- every slot's `visible_share ≥ actor_visible_min`;
- the background blur begins at a view depth of at least `z_far + dof_margin`, with near blur off;
- on a boss stage, `horizon_frac ≥ sky_share_min`. This is necessary, not sufficient: the capture measures the real `sky_share`, after set dressing above the horizon (AC-34).

**Visible share.** `visible_share` is the share of a slot's quad that is **not** covered by the quad of an actor with a smaller `z`, or by the projected bounds of set geometry tagged as an occluder. Every quad is the full frame of the actor's `idle`. Rectangles make the check conservative: a real silhouette covers less than its quad. For two actors directly in line, one behind the other, the farther one's share is `min(1, row_gap / q)`. So rows need `row_gap ≥ actor_visible_min · q`, or their slots are staggered sideways until every share passes.

**`F_v_eff`** is the vertical field of view actually shown: `F_v` at 16:9 and wider, and larger below 16:9, where the camera keeps the 16:9 horizontal view (`follow_camera` gives the formula). Depths are view-space: the distance along the camera's forward axis, which for a level camera is the horizontal distance.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| F_v, F_v_eff | float (°) | — | data file (`battle_fov`) / calculated | Vertical field of view at 16:9, and as shown at the current aspect |
| horizon_frac | float | 0.15–0.40 (default 0.30) | data file (stage) | Where the horizon sits, as a share of the frame height from the top. Set by the lens shift |
| h_cam | float (m) | > 0 | data file (stage) | Camera height above the ground plane |
| z, z_near, z_far | float (m) | > 0 | calculated | View depth of a foot anchor; of the nearest and farthest slot, per-slot stagger included |
| y_h, y_foot, q, row_gap | float (px) | — | calculated | Horizon row, foot row, quad height, and the row distance between the nearest and farthest slots |
| visible_share | float | 0–1 | calculated | Share of a slot's quad not covered by nearer actors or tagged occluders |
| actor_visible_min | float | 0.85–0.95 (default 0.90) | data file | Smallest share of any actor that must be visible at the default battle camera |
| dof_margin | float (m) | 0.5–2.0 (default 1.0) | data file | Gap in view depth between the farthest slot and where the background blur begins |

**Output Range:** `y_foot` falls toward `y_h` as `z` grows, so farther rows stand higher in the frame. A stage over any limit fails validation when it loads, so a hidden-actor or blurred-actor battle can't ship.
**Example:** 1920×1080, `F_v = 20°` (`f_px = 3062.5`), `h_cam = 1.6` m, `horizon_frac = 0.30` (`y_h = 324`), `T = 3`, 64-texel frames (`q = 192`):
- party at `z = 9.0` m: `y_foot = 324 + 4900 / 9.0 = 868.4`;
- enemies at `z = 15.0` m: `y_foot = 324 + 326.7 = 650.7`, so `row_gap = 217.8 ≥ 0.90 × 192 = 172.8`. Every enemy is fully visible even directly behind a party member;
- enemies at `z = 12.0` m instead: `y_foot = 732.3`, `row_gap = 136.1`, so an enemy directly behind a party member would be only `136.1 / 192 = 71%` visible. Those slots are staggered sideways until every share reaches 0.90;
- the background blur starts at `15.0 + 1.0 = 16.0` m of view depth or farther.

### read_order

The read_order formula is defined as:

For each valid sector `s` of the ring, `C_s = (max(L_edge,s, L_ring,s) + 0.05) / (min(L_edge,s, L_ring,s) + 0.05)`. An actor passes iff `C_s ≥ actor_contrast_min` in **every** valid sector.

This is WCAG's contrast-ratio formula, applied locally and per side.

**Bands.** They are measured in texels and are `T` px per texel on screen, so no band is ever 0 pixels wide:
- **the edge band**, `L_edge`, is the ring of texels just inside the actor's Outline Ink outline, where its rim sits. It is `edge_tx` texels wide, and Outline Ink is never part of it;
- **the costume band** is `body_tx` texels just inside the edge band;
- **the ring**, `L_ring`, is `ring_tx` texels of set pixels just outside the silhouette's outline.

**Sectors.**
- The edge band and the ring are split into 8 equal angular sectors around the centre of the actor's quad, and each sector compares its own edge band with its own ring. So an actor whose left side vanishes into the set fails even when its other sides are bright.
- Each sector is judged in this order:
  1. **Geometry first.** Ring pixels below the foot anchor's row (the ground contact and the blob shadow), pixels of any other actor, and the stars of a dusk sky (Formulas `flood`) are removed. What is left is the sector's **full ring**. So a flat-based actor (a filing-cabinet boss) and an actor partly behind another (up to the `actor_visible_min` overlap, rule 4) are judged only on the set they actually stand against.
  2. **Too small to judge.** A sector whose edge band or full ring holds fewer than `band_tx_min` texels is skipped.
  3. **Lights in the ring.** Set pixels tagged emissive are removed from the full ring. A sector where fewer than half of its full ring's pixels remain fails: the actor is staged too close to a light. Only this step can fail a sector for what was removed.
- A capture with fewer than 5 valid sectors for any actor is **invalid**: a tool error that must be fixed, never a pass, a fail or a NaN. (A flat-based actor loses its bottom sector to step 1, which is why the floor is 5, not 6.)

**Enemy against flood (boss takeover only).** Luminance alone can't tell a Stamp Red boss from a Stamp Red sky. In every boss takeover capture, each enemy also passes, in **every** valid sector `s` (the same sectors and exclusions as above):

`ΔE(mean Lab of its costume band in s, mean Lab of its ring in s) ≥ enemy_flood_de_min`.

It is per sector for the same reason as the contrast test: a red boss half in front of the red sky and half in front of a grey set must fail on its sky side, not pass on the average. It is measured on the costume band, not on the rim-lit edge, because the neutral rim desaturates the edge.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| L_edge,s, L_ring,s | float | 0–1 | calculated | Mean relative luminance (linear, WCAG definition) of the edge band and of the ring in sector `s`, on a reference capture |
| edge_tx | int (texels) | 1 | constant | Width of the edge band: the one texel ring the rim lights |
| body_tx | int (texels) | 1–3 (default 2) | data file | Width of the costume band |
| ring_tx | int (texels) | 2–4 (default 3) | data file | Width of the set ring |
| band_tx_min | int (texels) | 3 | constant | Fewest texels a sector's edge band or full ring may hold to be judged. In texels, so a sector's validity doesn't change with the resolution |
| actor_contrast_min | float | 3.0–4.5 (default 3.0) | data file | Minimum local contrast (WCAG 1.4.11's 3:1 for non-text graphics) |
| enemy_flood_de_min | float (ΔE) | 12–20 (default 15) | data file | Smallest color difference between an enemy's costume and the flood around it |

**Output Range:** `C_s` runs 1–21. Saturation is not part of the pass test: a deliberately grey character (a robot clerk) is legal, so set saturation is judged by the art director in AC-32. The enemy-against-flood test applies only in boss takeovers.
**Example:**
- **On a dusk flood:** a ring on Stamp Red's dusk sky at L\* 30 has `L_ring = 0.062`. A rim-lit edge sector at `L_edge = 0.40` gives `0.45 / 0.112 = 4.02`, which passes. A sector where a dark costume holds the rim down to `L_edge = 0.20` (the rim runs round the whole perimeter, but a dark costume texel under it stays dark) gives `0.25 / 0.112 = 2.23`, which fails, however bright the actor's other sectors are. The fix is the costume's edge colour, not the light.
- **Enemy against flood:** the old light-flood case, a costume at L\* 48 C\* 62 on a ring of the same lightness at C\* 47, gives ΔE 4.3 and fails. A costume at L\* 45 C\* 62 against Stamp Red's dusk ring (L\* 30, C\* 46.9) gives ΔE 13.5 and fails too. Lifted to L\* 50 C\* 65, it gives 18.3 and passes.
- **720p:** `T = 2`, so the edge band is 2 px wide.

### flood

The flood formula is defined as (boss takeover, rule 6):

`h_flood = h_signature`; `C*_flood = min(flood_chroma_frac × C*_signature, C*_max(L*_mid, h_signature))`. Here `C*_max` is the largest chroma sRGB can display at the swatch's L\* midpoint and hue, and every swatch's L\* range lies at or below `flood_l_max`.

A sky pixel **matches** iff `|Δh| ≤ flood_hue_tol` and `|C*_pixel − C*_flood| ≤ flood_chroma_tol`. The **horizon band** is the rows from `y_h − horizon_band_frac · H_screen` down to the horizon row `y_h` (a continuous boundary: a row is in the band iff its centre is at or below `y_h − horizon_band_frac · H_screen`). **Stars** are tagged sky detail (below) and are left out of every sky test except the star rule. A takeover's sky passes iff all of these hold:
- at least `sky_match_min` of the visible non-star sky pixels match;
- **lightness, outside the horizon band:** every non-star sky pixel's L\* lies between the swatch's lower L\* bound minus `flood_l_gradient` and its upper bound. The gradient and clouds may go darker, never lighter;
- **lightness, inside the horizon band:** every non-star sky pixel's L\* lies within the swatch's range widened by `flood_l_gradient` on each side. Only the neon horizon glows lighter;
- the mean L\* of all visible non-star sky pixels is at most `flood_l_max`, so the sky as a whole is dark;
- `sky_share ≥ sky_share_min`;
- `ΔE(swatch at its L\*_mid, native_sky) ≥ flood_native_de_min` for every boss stage of that faction;
- **the star rule** holds (below).

Hue and chroma are compared in LCh, and lightness is left out of the match, so the sky keeps its gradient, clouds and horizon glow.

**Stars (user condition on D1).** Every dusk flood shows some stars. They are sky-card detail, not set lights:
- at the default battle camera, at least `star_count_min` stars are visible, all above the horizon band;
- each star is a single texel, `T × T` px, like every other sprite pixel (rule 2);
- the stars together cover at most `star_share_max` of the visible sky, so the sky still reads as the flood;
- a star may twinkle: its brightness follows a smooth cycle on `mode_time` (so it freezes with the Menu, rule 7) with a period of at least `star_twinkle_period_min` and its own phase. The whole starfield's area is far below `flash_area_min`, so twinkling is exempt from the flash gate by area (Formulas `flash_gate`), and no star counts as a flash source;
- stars are removed from actors' rings with the geometry (Formulas `read_order`, step 1), so a star behind a shoulder never fails or passes an actor;
- stars are drawn as `T`-scaled screen-space points on the sky layer, snapped to whole pixels like sprites (rule 2), never baked into the sky card's texture, where perspective would resize them;
- a star's peak lightness is at most L\* 80, so it reads as a star and not as a light.

`native_sky` is the mean color of the stage's own sky in its Battle capture. The swatches live in art bible §4 (Open Question 7). A stage that fails the native-sky floor re-authors its own sky. A swatch never moves per stage.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| C\*_signature, h_signature | float | per faction | registry (`signature_color`) | Chroma and hue of the faction's signature color |
| flood_chroma_frac | float | 0.60–0.70 (default 0.65) | data file | Flood chroma as a share of the signature chroma, before the gamut cap |
| C\*_max | float | per L\*, h | calculated | sRGB's largest displayable chroma at that lightness and hue |
| flood_l_max | float (L\*) | 30–40 (default 35) | data file | Highest L\* any swatch's range may reach: the dusk ceiling (ruling 4, D1) |
| flood_hue_tol | float (°) | 5–10 (default 8) | data file | Largest hue difference for a matching sky pixel |
| flood_chroma_tol | float (C\*) | 6–12 (default 10) | data file | Largest chroma difference for a matching sky pixel |
| sky_match_min | float | 0.85–0.95 (default 0.90) | data file | Share of visible sky pixels that must match |
| L\*_mid | float (L\*) | per swatch | art bible §4 | The midpoint of the swatch's L\* range. The one lightness at which the gamut cap, the swatch's quoted colour and the native-sky ΔE are all computed |
| flood_l_gradient | float (L\*) | 10–15 (default 15) | data file | How far sky lightness may stray outside the swatch range: darker anywhere (gradient, clouds), lighter only inside the horizon band (the neon glow) |
| horizon_band_frac | float | 0.05–0.12 (default 0.08) | data file | Height of the horizon band, as a share of the frame height, just above the horizon row |
| star_count_min | int | 8–40 (default 16) | data file | Fewest stars visible above the horizon band at the default battle camera on a dusk flood |
| star_share_max | float | 0.002–0.01 (default 0.005) | data file | Largest share of the visible sky the stars may cover together |
| star_twinkle_period_min | float (s) | 1.0–4.0 (default 1.5) | data file | Shortest twinkle cycle of any star |
| sky_share | float | 0–1 | calculated | Visible sky pixels over all frame pixels at the default battle camera |
| sky_share_min | float | 0.15–0.30 (default 0.20) | data file | Smallest share of the frame the sky must cover on a boss stage |
| flood_native_de_min | float (ΔE) | 10–20 (default 15) | data file | Smallest color difference between a flood swatch and the native sky of a stage it floods |

**Output Range:** `C*_flood` is at most 70% of the signature chroma, and lower where dusk can't hold it. Every flood is dark (mean sky L\* ≤ `flood_l_max`, and nothing lighter than the swatch outside the horizon band), with a lighter horizon and some stars. The test fails a sky left at its native color, one flooded at full chroma, a light sky with a dark horizon, a flood that resembles the stage's own sky, a starless flood, and a stage that barely shows its sky. With `flood_l_max` 35, a ring on the sky away from the horizon is at most L\* 35 (`Y ≤ 0.085`), so the read-order example above holds on every flood.
**Example:**
- **Stamp Red** (`#D23A2E`, L\* 48.2, C\* 72.1, h 35.9°): `0.65 × 72.1 = 46.9`, which sRGB can show at L\* 30 (`#81271E`), so `C*_flood = 46.9`. A sky pixel at C\* 50, hue 40°, matches (`3.1 ≤ 10`, `4.1 ≤ 8`); one at the full C\* 72 does not.
- **Terminal Cyan** (`#19C2D6`, L\* 72.0, C\* 38.4, h 213.5°): `0.65 × 38.4 = 25.0`, but at its `L*_mid` of 30 sRGB holds only C\* 20.5 at that hue, so `C*_flood = 20.5`, quoted at L\* 30. (Rule 6's "about 21" is this value.) Its lavishness comes from the gradient and the horizon glow, not chroma (Visual Requirements).
- **Native-sky floor:** Canada's blue-white sky (L\* 80, C\* 20, h 240°) against Terminal Cyan's dusk swatch (L\* 32, C\* 20.5) is ΔE 45.3, which passes. A night stage's sky (L\* 22, C\* 24, h 265°, inside sRGB, whose limit there is about C\* 24.9) against Anthem Blue's dusk swatch (L\* 30, C\* 54.9, h 295.6°) is ΔE 10.5, which fails 15. That stage re-authors its sky, for example to a warm night (L\* 22, C\* 18, h 50°): ΔE 33.4, which passes.
- **Sky share:** a 1920×1080 frame with 450,000 sky pixels has `sky_share = 0.217`, which passes.
- **Horizon band and stars:** at 1080p the horizon band is `0.08 × 1080 = 86.4` rows above `y_h`. A cloud at L\* 40 on Stamp Red's ≤ 35 range fails if it sits above the band, and passes inside it (≤ 35 + 15). At `T = 3`, 16 stars are 144 px, 0.03% of a 450,000-pixel sky, far under `star_share_max` (2,250 px) and far under `flash_area_min`.

### follow_camera

The follow_camera formula is defined as:

`offset = target − cam; excess = offset − clamp(offset, −dz, +dz)` (per axis); `cam += excess × (1 − exp(−min(dt, dt_max) / tau))`; then `cam.x = clamp_or_centre(cam.x, map_min.x + w_far, map_max.x − w_far)` and `cam.y = clamp_or_centre(cam.y, map_min.y + a_near, map_max.y − a_far)`

`clamp_or_centre(v, lo, hi) = (lo ≤ hi) ? clamp(v, lo, hi) : (lo + hi) / 2`. Ground axes: `x` is sideways on screen; `y` points away from the camera along the ground.

The last step keeps the view's **ground footprint** inside the map. A pitched camera sees the ground as a trapezoid, narrow near the camera and wide far from it. The footprint's extents around the camera's focus point are constants of the mode's fixed camera, computed at load and again on every window resize:

```
F_v_eff = 2 · atan( tan(F_v / 2) · max(1, (16/9) / aspect) )
F_h     = 2 · atan( tan(F_v_eff / 2) · aspect )
d_near = h / tan(pitch + F_v_eff/2)      d_focus = h / tan(pitch)      d_far = h / tan(pitch − F_v_eff/2)
a_near = d_focus − d_near                a_far  = d_far − d_focus
w_far  = h · cos(F_v_eff/2) · tan(F_h/2) / sin(pitch − F_v_eff/2)
```

**Effective vertical field of view.** At 16:9 and wider, the vertical view is fixed (`F_v_eff = F_v`) and wider windows show more at the sides. Below 16:9, the camera keeps the 16:9 horizontal view, so the vertical view grows. Every footprint and horizon value uses `F_v_eff`, which closes the sub-16:9 gap.

`w_far` is the half-width of the footprint's far edge, its widest part. Clamping `x` by it is conservative: the narrower near corners are then inside too. On an axis where the map is smaller than the footprint, the bounds would invert, so the camera is centred on that axis instead. The overworld camera is validated at load to have `pitch − F_v_eff/2 ≥ horizon_margin` at the **narrowest supported aspect, 4:3**, where `F_v_eff` is largest. Otherwise `d_far` would be unbounded, and the camera would show sky past the map.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| target, cam | Vector2 (ground-plane m) | — | calculated | The party's anchor point and the camera's focus point |
| dz | Vector2 | 8–12% of the footprint's half-extent per axis (default 10%) | data file | Dead-zone half-size; movement inside it does not move the camera |
| tau | float (s) | 0.15–0.18 (default 0.17) | data file | Time for the camera to cover 63% of the remaining excess. The ceiling of 0.18 keeps the Game Feel target (75% within 0.25 s): `1 − e^(−0.25/0.18) = 0.751` |
| dt_max | float (s) | 0.05–0.10 (default 0.10) | data file | Largest frame step used, protecting against lurches on a slow frame |
| dt | float (s) | ≥ 0 | calculated | Frame step in mode time; 0 while the Menu is open |
| map_min, map_max | Vector2 (ground-plane m) | `map_min < map_max` | data file (map) | The map's ground-plane bounds |
| h | float (m) | > 0 | data file (mode camera) | Camera height above the ground plane |
| pitch, F_v | float (°) | `pitch − F_v_eff(4:3)/2 ≥ horizon_margin` | data file | The camera's fixed pitch, and its vertical field of view at 16:9 |
| aspect, F_v_eff, F_h | float / float (°) | aspect 4:3 to 21:9 | calculated | Window aspect, and the vertical and horizontal fields of view it gives |
| horizon_margin | float (°) | 3–10 (default 5) | data file | How far below the horizon the footprint's far edge must stay |
| a_near, a_far, w_far | float (m) | > 0 | calculated | Distance from the focus to the footprint's near and far edges, and the far edge's half-width |

**Output Range:** each frame the camera moves 0–100% of the excess, never past the target, and the view never shows ground beyond the map at any supported aspect. It is first-order exponential smoothing: no overshoot, no bounce and no lead. It is frame-rate independent while `dt ≤ dt_max` (above 1 / `dt_max` fps); below that, the camera catches up more slowly in wall time.
**Example:**
- **Smoothing:** excess 2.0 m, `dt = 1/60`, `tau = 0.17` → factor `1 − e^(−0.098) = 0.093`, so the camera moves 0.187 m this frame. After 0.25 s it has covered `1 − e^(−1.47) = 77%` of the excess.
- **Footprint at 16:9:** `h = 10` m, `pitch = 30°`, `F_v = 20°` (`tan(F_h/2) = 16/9 × tan 10° = 0.3135`):
  - `d_near = 11.92`, `d_focus = 17.32` and `d_far = 27.47`, so `a_near = 5.40` m and `a_far = 10.15` m;
  - `w_far = 10 × cos 10° × 0.3135 / sin 20° = 9.03` m.

  On a 60 × 40 m map, the focus stays within `x ∈ [9.03, 50.97]` and `y ∈ [5.40, 29.85]`. On a 16 m wide map, `9.03 > 6.97`, so `x` is centred at 8.0 m.
- **At 4:3:** `F_v_eff = 2 · atan(tan 10° × 1.333) = 26.46°`, so the horizon check is `30 − 13.23 = 16.77 ≥ 5`, which passes. The footprint is recomputed with 26.46°.

### hit_punch

The hit_punch formula is defined as:

`A_full = round(A_beat × H_screen / 1080); A_peak = A_full (Full), (A_full > 0 ? max(1, floor(A_full / 2)) : 0) (Reduced), 0 (Off, or Reduce Motion On); offset(t) = round(dir × A_peak × (1 − t / D)²)` for `0 ≤ t < D`, else `0`

`round` is round-half-away-from-zero, so an exact .5 is never a coin toss: 0.5 rounds to 1 and −0.5 to −1. The offset moves the whole view, every depth at once, by `offset` whole screen pixels (rule 8). ADR-0005 maps it onto the battle camera's lens shift.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| A_beat | float (px at 1080p) | normal 2–4 (default 3); big beat 6–8 (default 7) | data file | Peak shift at 1080p; a big beat is a knockout or a hit by a boss |
| H_screen | int (px) | ≥ 720 | calculated | Window height |
| A_peak | int (px) | 0–16 at 2160p; linear in height | calculated | Peak shift after resolution and the comfort settings. Reduced is half of Full rounded down, but never below 1 px while Full is above 0, so it never silently becomes Off |
| D | float (s) | 0.08–0.12 (default 0.10), and `< reaction_hold` | data file | Punch duration |
| dir | Vector2 | unit, horizontal or vertical | calculated | Direction of the shift, fixed for the whole punch; never a rotation |
| t | float (s) | 0–D | calculated | Time since the beat's impact, at 1× (rule 9) |

**Output Range:** 0 to `A_peak` px. It decays monotonically and never changes sign, so there is no ringing. Because `D < reaction_hold` and impacts are at least one hold apart, a punch always ends before the next one starts.
**Example:** big beat, Reduced, 1080p → `A_full = 7`, `A_peak = max(1, floor(3.5)) = 3`. At `t = 0.05`: `3 × 0.25 = 0.75`, which rounds to 1 px. The same beat at 2160p: `A_full = 14`, `A_peak = 7`, and at `t = 0.05` the shift is `round(1.75) = 2` px. A normal beat on Reduced at 720p with `A_beat = 2`: `A_full = round(1.33) = 1`, so `A_peak = 1`. A tie: `A_peak = 2` at `t = D/2` gives `2 × 0.25 = 0.5`, which rounds to 1 px.

### lighting_blend

The lighting_blend formula is defined as:

`p = (blend_time ≤ 0) ? 1 : smoothstep(0, 1, clamp(t_blend / blend_time, 0, 1)); L = lerp(L_from, L_to, p)` for every continuous lighting parameter. Colors are interpolated in linear space. A discrete parameter (an on/off flag, a choice between two blur modes) switches from `L_from` to `L_to` when `p ≥ 0.5`.

**Nothing compiles in play.** After Boot's warm-up, no lighting change compiles a rendering pipeline: no preset switch, blend, discrete switch, or full cycle through a mode's states. This is a measured contract (AC-64), checked on the engine's pipeline-compilation counters. A discrete parameter that changes the pipeline is allowed only if every combination it can produce in play is warmed at Boot. ADR-0005 lists which parameters compile and how Boot warms them. A stutter on the first boss takeover would read as the game breaking at its most important moment.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| blend_time | float (s) | `blend_boss` 0.60–1.00 (default 0.90); `blend_victory` and `blend_defeat` 0.25–0.35 (default 0.30). Mode entry is 0 | data file | The blend's length |
| t_blend | float (s) | 0–blend_time | calculated | Mode time since the blend started; frozen while the Menu is open. The boss takeover's comes from its own clock (ADR-0006), at the speed rule 9 gives it. A Retry applies the takeover's end state with `blend_time = 0`. Victory and Defeat blends always run at 1× |
| L_from, L_to | lighting values | per parameter | calculated / data file | The current (captured) values and the target lighting preset |

**Output Range:** `p` runs 0–1, easing in and out. `L` always lies between the two presets, and a frozen `t_blend` holds `L` exactly. Mode entry uses `blend_time = 0`, so `p = 1` on the first frame (rule 5).
**Example:** boss takeover at the default 0.90 s, `t_blend = 0.45` → `p = smoothstep(0.5) = 0.5`, so the light is halfway to the faction preset.

### replay_time

The replay_time formula is defined as (one replay, rule 9; implemented by ADR-0006):

```
w_i      = Σ over frames k < impact_frame of duration_k / fps        wind-up at 1×, from the action animation
k_i      = Σ over frames k < land_frame of duration_k / fps          slump time at 1×, from the knockout animation
hold_i   = 0                                   no combatant reacts (Defend)
         = max(ko_hold, max k_i over the beat's knockouts)         any combatant is knocked out
         = reaction_hold                       otherwise
speed_p  = max(latched ? ff_mult : 1, battle_speed_on ? battle_speed_mult : 1)   the plain-beat speed
speed_i  = debug ? 1 : speed_p                 every beat in MVP; holds never scale
— every frame, dt = min(mode-time step, dt_max) —
wind-up:  progress += dt × speed_i;  impact on the first frame where progress ≥ w_i
hold:     post += dt  (1×, from 0 on the impact frame)
end:      the first frame where post ≥ hold_i AND elapsed ≥ beat_min  (elapsed = 1× time since the beat started)
— at constant speed this gives, before rounding to whole frames —
wall_i    = max(w_i / speed_i + hold_i, beat_min)
wall_time = Σ wall_i                                (0 for a replay with no outcomes)
— the boss takeover (rule 6) —
takeover_full   = (blend_boss + boss_hold) / (speed_up_boss ? speed_p : 1)     first encounter, protected
takeover_settle = boss_retry_hold / speed_p                                      Retry
press_effective = some time remains, in the entry in progress or the queue, whose speed depends on `latched`
```

- **Knockouts are plain beats.** A knockout's wind-up speeds up like any other. Only its hold differs: it lasts until the slump has landed, and never less than `ko_hold`.
- **Protection.** In MVP only the first-encounter takeover is protected. Future combo and rule-trigger beats (Open Question 5b) will protect their landing hold, never their wind-up.
- **"1×"** means mode time at normal pace: it still stops under the Menu, but no speed setting shortens it.
- **A speed change mid-beat is well defined.** The beat's end is a condition, not a precomputed length. So after latching, un-latching, or a setting change made under the Menu, the rest of the wind-up runs at the new speed, the hold is unaffected, and the floor is checked against the time actually elapsed.
- **Whole frames.** Leftover `dt` is dropped at every event (ADR-0006), so each event lands on the first frame at or after its formula time, and a beat starts on the frame the previous one ends. A measured time is therefore its formula value rounded up to whole frames. **Tests allow one frame step per event**, so a time spanning several events (a whole replay) allows one step for each.
- **`press_effective`** decides the indicator's passive state and whether a press is refused (rule 9). The latch-dependent time is:
  - any remaining wind-up;
  - a remaining Retry settle;
  - a remaining first-encounter takeover, if `speed_up_boss` is On.
- **The debug path.** In a debug build that skipped validation, a beat with no action animation uses `w_i = beat_min − reaction_hold` at `speed_i = 1`, whatever the latch or settings, so impact always lands at that time.
- **The takeover is not a beat**, so the `beat_min` floor doesn't apply to it. Its clock starts on the first fully revealed frame. The boss's `intro` follows that clock, so a sped-up intro plays faster rather than being cut off.

**Load-time validation.** The presentation config fails validation, as a boot content error, unless all of these hold:
- `battle_speed_mult ≤ ff_mult − 0.25`, so a press always helps;
- `reaction_hold ≤ beat_min − 0.10`, so a debug-path beat still has a wind-up of at least 0.10 s;
- `reaction_hold ≤ ko_hold`;
- `D < reaction_hold`, so hit-punches never overlap (rule 8);
- `dt_max < beat_min`;
- `boss_retry_hold ≤ blend_boss + boss_hold`;
- `blend_victory ≤ victory_hold` and `blend_defeat ≤ defeat_hold`;
- `set_brightness_battle ≤ set_brightness_boss`, `set_brightness_victory_settle ≤ set_brightness_victory`, and `set_brightness_victory ≥ set_brightness_boss + 0.05`;
- `set_key_fill_ratio_boss` is greater than the set key:fill ratio of every non-boss lighting preset;
- `flash_rate_max ≤ 3`, and the constants `flash_luma_delta = 0.10` and `flash_area_min = 0.25` (Formulas, `flash_gate`);
- the overworld camera passes `pitch − F_v_eff(4:3)/2 ≥ horizon_margin`.

Every comparison allows a tolerance of 1e-6 in the passing direction, so a config exactly on a boundary (for example `reaction_hold = 0.30` with `beat_min = 0.40`) passes regardless of floating-point rounding. The safe ranges in Tuning Knobs are chained so that every rule above passes for any in-range values, **except** the key:fill rule and the overworld horizon rule, which compare against per-preset and per-camera data and are checked, not guaranteed by ranges.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| w_i | float (s) | ≥ 0 | calculated | Wind-up of outcome *i* at 1×: the summed durations of its action animation's frames before `impact_frame` |
| impact_frame | int | 0 to frame count − 1 | data file (sprite set, per action animation) | The frame on which impact lands; boot-validated |
| land_frame | int | 0 to frame count − 1 | data file (sprite set, `knockout`) | The frame on which the knockout slump lands; boot-validated |
| k_i | float (s) | ≥ 0 | calculated | Slump time at 1× of a knocked-out combatant in beat *i* |
| duration_k, fps | float | > 0 | data file (sprite set) | Each frame's relative duration and the animation's frames per second |
| reaction_hold | float (s) | 0.20–0.30 (default 0.25) | data file | How long a plain reaction frame is held clean before the number. Never sped up |
| ko_hold | float (s) | 0.40–0.60 (default 0.50) | data file | The shortest hold on a knockout beat. Never sped up |
| hold_i | float (s) | 0, `reaction_hold`, or ≥ `ko_hold` | calculated | The hold used by beat *i* |
| beat_min | float (s) | 0.40–0.50 (default 0.40) | data file | Shortest a beat may play, after any speed-up |
| latched | bool | — | calculated | The replay latch (rule 9); false at the start of every replay |
| battle_speed_on | bool | — | player setting | "Faster battle animations" (rule 13) |
| speed_up_boss | bool | — | player setting | "Speed up boss entrances" (rule 13) |
| ff_mult | float | 2.0–2.5 (default 2.0) | data file | Wind-up speed once latched. **Proposal; Turn Battle to ratify** (the Input GDD gives `fast_forward`'s effect to Turn Battle and Dialogue) |
| battle_speed_mult | float | 1.25–1.75 (default 1.5) | data file | Wind-up speed with Faster battle animations On |
| speed_p, speed_i | float | 1 to `ff_mult` | calculated | The plain-beat speed, and the speed beat *i* plays at |
| dt_max | float (s) | 0.05–0.10 (default 0.10) | data file | Largest mode-time step the replay clock takes per frame (shared with the follow camera) |
| blend_boss, boss_hold | float (s) | see Tuning Knobs | data file | The first-encounter takeover's blend and hold |
| boss_retry_hold | float (s) | 0.20–0.40 (default 0.30) | data file | The Retry settle |
| press_effective | bool | — | calculated | Whether a press would change anything left in the replay |
| wall_time | float (s) | ≥ 0 | calculated | Real playback time of the replay |

**Output Range:**
- **Speed:** each wind-up plays at 1×–`ff_mult` and each hold at 1×. No beat plays shorter than `beat_min`, and no beat is ever skipped.
- **When speeds change:** latching and un-latching take effect on the next frame. The latch lasts until Cancel, a second indicator click, or the replay's end.
- **Length:** there is no cap. A replay with many beats runs long; only the player's latch or setting shortens it (Open Question 16).

**Example:** 10 beats, each a 0.65 s wind-up. One is a knockout whose slump lands 0.35 s after impact (hold `max(0.50, 0.35) = 0.50` s), one is a Defend (no hold), and the other 8 are plain hits (`reaction_hold` 0.25 s):
- **1×, no latch:** 8 hits at `0.65 + 0.25 = 0.90` s, the knockout at `0.65 + 0.50 = 1.15` s, and the Defend at `max(0.65, 0.40) = 0.65` s, so `wall_time = 7.20 + 1.15 + 0.65 = 9.00` s.
- **Latched from the first beat** (`ff_mult = 2.0`): hits at `0.325 + 0.25 = 0.575` s (4.60 s for 8), the knockout at `0.325 + 0.50 = 0.825` s, and the Defend at `max(0.325, 0.40) = 0.40` s, so 5.825 s.
- **Faster battle animations On, no latch** (`battle_speed_mult = 1.5`): hits at `0.433 + 0.25 = 0.683` s (5.467 s), the knockout at 0.933 s and the Defend at 0.433 s, so 6.833 s. That is 1.32× shorter than 1×, not 1.5×, because the holds never scale (rule 13). Latched as well, it is the latched 5.825 s.
- **A late slump:** a knockout whose slump lands 0.70 s after impact holds 0.70 s, not 0.50 s.
- **The floor:** a hit with a 0.2 s wind-up, latched, would last `0.1 + 0.25 = 0.35` s, so its hold is extended by 0.05 s to reach 0.40 s.
- **The debug path with no animation:** impact lands at `0.40 − 0.25 = 0.15` s, and a hit lasts 0.40 s at any speed.
- **The takeover** at the defaults:
  - first encounter: `0.90 + 0.90 = 1.80` s, at any setting and latched or not, unless "Speed up boss entrances" is On. Then it is 1.20 s with Faster battle animations On and no press, and 0.90 s latched;
  - the Retry settle: 0.30 s, 0.20 s with Faster battle animations On, and 0.15 s latched.

### set_brightness_and_blur

The set_brightness_and_blur formula is defined as:

`B_set = B_native × k_state`, with `k_state` = `set_brightness_battle` (Battle), `set_brightness_boss` (Boss takeover), `set_brightness_defeat` (Defeat), the Victory curve below, and 1.0 elsewhere. `B_sky = B_sky_native × k_state` in every state except the boss takeover, where the sky's color and lightness come from the flood swatch (Formulas, `flood`). `B_fill_boss = B_set / set_key_fill_ratio_boss`, and `blur = blur_base × (reduce_blur ? reduce_blur_factor : 1.0)`.

**The Victory curve**, with `t` the mode time since Victory began:
- for `t ≤ blend_victory`: `k = lerp(k_from, set_brightness_victory, smoothstep(t / blend_victory))`. `k_from` is the set brightness captured on Victory's first frame: `set_brightness_battle` after an ordinary fight, `set_brightness_boss` after a boss fight (lighting_blend's captured `L_from`, so Victory never starts with a drop). The burst's peak is at `t = blend_victory`;
- then `k = lerp(set_brightness_victory, set_brightness_victory_settle, smoothstep(min(1, (t − blend_victory) / victory_settle)))`, which stays at the settle level once it is reached.

Load-time rule: `set_brightness_victory ≥ set_brightness_boss + 0.05`, so the burst always rises, even after a boss.

The actors' key and rim follow the same curve shape, from their Battle values up to the burst and back to their Battle values at the settle. They are therefore equal to their Battle values at `t = 0` and from the end of the settle on, and strictly above them in between.

**After a boss fight**, the sky stays at the flood swatch through Victory and its results screen. Only the set, fill and actors follow the Victory curve. The stage's native sky comes back hidden behind the next transition (rule 5), so a dark flood never jumps to a light sky on screen.

**The settle and the results screen.** `victory_hold` (0.40 s) is shorter than the burst plus settle (0.70 s at the defaults), on purpose: the fanfare poses are what the hold protects. The results screen opens over the settle, and whatever part of the battle stays visible behind it keeps settling on mode time. Nothing waits for the settle.

Brightness scales the set light's **energy** and the sky card's energy, both linear (scene-referred) quantities. The art bible's "dimmed 30%" is read as linear energy × 0.70. The sky is part of the set for read order, so it follows `k_state`, except in the boss takeover, where the swatch alone sets its lightness (rule 6). In the takeover the flooded fill runs at `1 / set_key_fill_ratio_boss` of the set light, the lowest fill of any state, which is what gives the set its hard contrast.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| B_native, B_sky_native | float | per stage | data file (stage) | The set light's and the sky card's authored energy |
| set_brightness_battle | float | 0.60–0.75 (default 0.70) | data file | Battle set brightness relative to native (art bible: "dimmed 30%") |
| set_brightness_boss | float | 0.75–0.85 (default 0.85) | data file | Boss takeover set brightness; at least the Battle level and always below 1.0 |
| set_key_fill_ratio_boss | float | 4.0–6.0 (default 4.0) | data file | Set light energy over flooded fill energy in a boss takeover. Must be higher than every other preset's set key:fill ratio |
| set_brightness_victory | float | 0.90–0.95 (default 0.90) | data file | Set brightness at the Victory burst's peak |
| set_brightness_victory_settle | float | 0.75–0.85 (default 0.85) | data file | Set brightness the Victory light settles at |
| victory_settle | float (s) | 0.30–0.50 (default 0.40) | data file | How long the Victory light takes to settle after the burst's peak |
| set_brightness_defeat | float | 0.30–0.50 (default 0.40) | data file | Set brightness outside the Defeat spotlight |
| blur_base | float | per effect | data file (lighting preset) | Normal tilt-shift, background or Menu backdrop blur strength |
| reduce_blur_factor | float | 0.20–0.40 (default 0.30) | data file | Share of blur kept when Reduce Blur is On |

**Output Range:** in every battle-family state (Battle, Boss takeover, every frame of Victory, Defeat), `B_set` stays below native: 30–95%. `B_sky` does too, except in the takeover. Blur is 20–100% of base. Reduce Blur never changes dimming.
**Example:**
- **Reduce Blur:** a background blur of strength 6 with Reduce Blur On gives 1.8; the set stays at 0.70 brightness.
- **Boss takeover:** a set authored at energy 2.0 runs at `2.0 × 0.85 = 1.7`, and its flooded fill at `1.7 / 4.0 = 0.425`.
- **Victory** at the defaults: `k` is 0.70 at `t = 0`, 0.80 at `t = 0.15`, and 0.90 at the peak (`t = 0.30`). It is 0.875 at `t = 0.50` and 0.85 from `t = 0.70` on.
- **Victory after a boss fight:** `k_from = 0.85`, so `k` is 0.875 at `t = 0.15` and 0.90 at the peak: a smaller burst, but never a dip.

### flash_gate

The flash_gate formula is defined as:

A **transition** is one large-area luminance or red change, as WCAG 2.2 SC 2.3.1 and its Understanding document define it:
- **General:** a change in relative luminance of at least `flash_luma_delta` (0.10 of the maximum), where the darker state is below 0.80.
- **Red:** a change involving a saturated red. A pixel is saturated red when `R / (R + G + B) ≥ 0.8`, and a transition counts when `(R − G − B) × 320` changes by more than 20, with negative values clamped to 0. **R, G and B are the linear 0–1 values of WCAG's relative-luminance definition**, never gamma-encoded.
- **Area:** a change counts only if it covers at least `flash_area_min` (25%) of some **10° window**, a rectangle `(4/9)·H × (1/3)·H` pixels for window height `H`. That is WCAG's 341 × 256 px field at 1024 × 768, scaled with height, and the window can sit anywhere on screen.

**Counting.** The gate keeps every booked transition at the real time it **lands** on screen. A booked transition counts as one flash if it opposes the booked transition before it. N alternating transitions are therefore N − 1 flashes: a conservative count, since WCAG pairs them.

**Landing time.** A source declares each transition as an offset `o` on **its own clock** `c` (mode time, a replay clock, or real time for Game State's transitions). While that clock runs at rate `r` (1 at 1×, `battle_speed_mult` with Faster battle animations On, `ff_mult` when latched, 0 while the Menu freezes it), an unlanded transition is booked at

`t_land = t_now + (o − c_now) / r`.

When the rate is **scheduled** to change before `o` (a replay clock runs the wind-up at speed and the hold at 1×, rule 9), `t_land` integrates over that known schedule instead of assuming the current rate holds. Only **unscheduled** changes re-book.

- **Unscheduled rate changes re-book.** Whenever a source's clock changes rate unexpectedly (the Menu freezes or resumes it, the latch engages or clears, a speed setting changes, or a frame is clamped to `dt_max`), the gate removes that source's unlanded transitions and books them again at their new `t_land`. A frozen clock (`r = 0`) holds its unlanded transitions unbooked until it resumes, but they still **count as pending at their resume-time landing** for any request evaluated during the freeze (the Menu's own close transition is judged with them in).
- **A started flash always finishes.** A ↓ (or ↑) that closes an already-landed opposite transition of the same source is a **closing** transition. It is never dropped and, on re-booking, books with reserved priority, so a raised screen always returns to rest and the return never needs a capped form.
- **If a re-booking would exceed the limit**, only the source's **not-yet-started** transitions (those with no landed partner) are dropped, and the source plays the rest of its effect in its capped variant from that frame. Its closing transitions still land. A reserved source keeps its bookings, and gated sources yield to it.
- So the guarantee is about what lands on screen, at any clock speed and across any Menu pause.

**Requests.**
- **Gated sources.** A gated source requests the gate at real time `t_req`, declaring its transitions as offsets on its own clock. The request is allowed iff, with those transitions booked at their `t_land`, no closed one-second window holds more than `flash_rate_max` flashes. If it is allowed, they are booked and the full variant plays. If it is refused, nothing is booked and the capped variant plays.
- **Reduce Flashing.** With it On, every gated request is refused.
- **Reserved sources** (the boss flood) book unconditionally. Boot validation checks every scripted reserved sequence (a battle reveal, then the boss flood) on its own against the limit at every speed it can play at: 1×, the largest `battle_speed_mult`, and the largest `ff_mult` (with "Speed up boss entrances" On), so later gated sources simply yield to it.
- **Capped variants** are checked at boot on their declared frames: no general transition **and** no red transition, or below `flash_area_min`. A luminance-only cap is not a cap.
- **Area-exempt sources** start exempt only if `A_exempt + their declared area < flash_area_min`. Otherwise they request like a gated source.
- **Swing-exempt sources** never request.

The gate never delays a source, so Game State's fixed-length retry flash and wipes keep their timing.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| flash_rate_max | float (flashes per s) | 1–3 (default 3) | data file | Most flashes in any one second, across all sources. A safety ceiling, validated `≤ 3` at load |
| flash_luma_delta | float | 0.10 relative luminance | constant (validated at load) | A change at or above this is a general transition |
| flash_area_min | float | 0.25 of a 10° window | constant (validated at load) | Smallest area that counts |
| t_req, o | float (s) | — | calculated / data file (source) | Request time (real), and each declared transition's offset on the source's own clock |
| c_now, r | float | c ≥ 0; r ∈ {0} ∪ [1, ff_mult] | calculated | The source's clock reading now, and its current rate against real time |
| t_land | float (s) | ≥ t_now | calculated | Real time an unlanded transition is booked at; re-computed on every rate change |
| A_exempt | float | 0–1 of a 10° window | calculated | Summed declared flashing area of the area-exempt effects currently playing |

The window and the bookings are in **real** time, on purpose, so opening the Menu can't reset the gate. Only the offsets are on each source's own clock; `t_land` converts them.

**Output Range:** at most `flash_rate_max` (3) flashes in any one-second window, counted at landing, from all sources together. Campfire flicker must keep its swing below `flash_luma_delta` at all times. It never counts, so it never uses up the budget.
**Example:** three comedy stamps, each with an up transition at +0.05 s and a down one at +0.15 s, are requested at 0.00, 0.20 and 0.40 s.
- The first two are allowed and book 0.05 ↑, 0.15 ↓, 0.25 ↑ and 0.35 ↓: flashes at 0.15, 0.25 and 0.35.
- The third would add 0.45 ↑, a fourth flash inside the second [0.15, 0.45], so it is refused and plays capped.
- A gate that booked flashes at request time instead would have seen only three requests in that second, allowed the third, and put five flashes on screen by this gate's N − 1 count.
- **Menu pause:** a stamp requested at mode time 0 with ↑ at +0.05 and ↓ at +0.15 is frozen by the Menu at mode time 0.10, real time 0.10. Its ↓ is unbooked. The Menu closes at real time 3.00, so the ↓ is re-booked at `3.00 + (0.15 − 0.10) / 1 = 3.05`, where the gate counts it against whatever else lands near 3.05, including the Menu's own close transition.

## Edge Cases

> Source: `systems-designer`, from Sections C and D; render-side cases from `technical-artist`.

**Freezing and interruption**
- **If the Menu opens mid-blend, mid-hit-punch or mid-replay**: mode time stops, so the blend, the punch and the current beat all hold exactly. Closing the Menu resumes them from the same point with no catch-up jump (rule 7).
- **If Retry is chosen in a boss fight**: the takeover is not replayed. Its end-state light is applied hidden behind the retry flash, and when the flash ends the boss settles for `boss_retry_hold` before the first command menu (rule 6).
- **If Retry is chosen while anything from the old battle is still playing** (only reachable through a debug path, since the Defeat Prompt opens after the last beat and the hold): everything is cancelled when the retry transition starts, before the battle is restored, and nothing from it plays later. The first frame after the retry flash shows the restored battle with a clean display (rule 9).
- **If the retry flash plays capped** (Reduce Flashing On, or the flash limit refused it): it no longer covers the screen, so the Defeat-to-Battle light change becomes a blend over `blend_defeat` from the start of the flash, never a pop (States and Transitions).
- **If the Battle mode is left mid-replay or mid-hold** (Retreat, Quit to Title, or the mode freed): every exit path cancels the replay and the end-of-fight hold at the start of the transition, not as a best effort. No beat, sound, number or Victory/Defeat light from that battle plays afterwards. A takeover cancelled partway leaves no half-blended light: the next mode's entry light is applied behind the transition (rule 5).
- **If a new lighting change is requested while a blend is running**: the light as it is at that moment becomes the new starting point, and the new blend runs in full from there. The light never pops.
- **If a press is made during a first-encounter boss takeover**:
  - with "Speed up boss entrances" Off, nothing speeds it, so the press is refused visibly (rule 9), and the indicator is passive;
  - with it On, the press latches, and the rest of the takeover plays at `ff_mult`.
- **If a press is made during the Retry settle**: it latches like any plain beat.
- **If a press is made during a Victory or Defeat blend and hold**: it does nothing and is not buffered. The end of the fight is always seen in full.
- **If a press is made while the wipe or retry flash still covers the screen**: it does nothing, and it doesn't carry over (rule 9).
- **If Reduce Blur is toggled while the Menu is open**: the frozen frame updates its blur immediately. It is a display setting, not world motion, and works as a live preview.
- **If the Screen Shake or Reduce Motion setting changes mid-punch**: the new setting applies on the next frame. Off (or Reduce Motion On) stops the shift immediately, and Reduced recomputes `A_peak` with the punch's elapsed time unchanged.
- **If Faster battle animations or Speed up boss entrances is changed mid-replay** (only possible through the Menu, which freezes the replay): the new setting applies from the next frame after the Menu closes, and the indicator's state is recomputed then.

**Battle replay**
- **If the same combatant reacts in consecutive beats**: its earlier floating number is cleared on the new beat's impact, so the new reaction frame is clean (rule 9). Punches can't overlap (rule 8).
- **If the same actor acts in consecutive beats** (an enemy that Defends and then Attacks in one turn): it goes straight from its first action into the next wind-up, with no `idle` in between (rule 9).
- **If an outcome is Defend**: the actor plays its `defend` pose. There is no reaction, no hold, no punch and no number; the beat lasts its wind-up or `beat_min`, whichever is longer.
- **If an outcome is a party-wide heal** (Family Meal): every healed member other than the healer plays its heal reaction on the impact frame. The healer keeps its action pose. Each healed member, the healer included, gets its own "+n" number at the beat's end. A member already at full HP isn't healed, so it gets no number.
- **If an Attack does no damage** (fully blocked): the target plays `hit`. There is no punch and no number, never a "0".
- **If an outcome changes no HP but has a target** (Speak to the Manager, Viral Stunt): the target plays its `status` reaction (or `hit` where it has no `status` art). There is no punch and no number. The status tag appears on the HUD at the beat's end.
- **If an enemy skips its turn** (stunned) **or an action is skipped because its target is already knocked out**: Turn Battle emits no outcome, so there is no beat. The cleared stun shows on the HUD when the next turn is released. The stun's payoff is not shown in MVP (Open Question 5b).
- **If a Defend wears off as a squad member's turn begins**: the HUD shows it when that turn is released, together with the command menu, never earlier and never left stale (rule 9).
- **If MegaCorp's per-round bill drains MP**: it belongs to no outcome. It shows on the HUD when the round changes, after the round's last beat, with the new round number.
- **If several combatants are knocked out in one beat**: the hold lasts until the latest slump has landed, and never less than `ko_hold`.
- **If an actor is knocked out mid-replay and that ends the battle**: its knockout beat plays in full, then any remaining beats, then Victory or Defeat. The result is never shown before the last beat (rule 9).
- **If a required animation is missing, an action animation has no valid `impact_frame`, a `knockout` has no valid `land_frame`, a boss `intro` is longer than `boss_hold`, or two move-specific animations share a move name**: the boot fails with a content error (rule 10). **If an optional animation is missing**: the fallback in rule 10's table plays and a warning is logged. A `no_mirror` animation never falls back to a mirrored facing.
- **If a replay is long** (many beats, many knockouts): it plays in full at the speeds the player chose. There is no automatic cap in MVP (Open Question 16), and no beat is cut or skipped.
- **If a replay contains no outcomes** (a command that resolves nothing visible): it takes no time, and the next turn or the battle's end is released on the same frame.
- **If a frame takes very long (a delta spike)**: the camera follow and the replay clock both use at most `dt_max` per frame, and at most one beat ends per frame. Every beat lasts at least `beat_min` (0.40 s) and `dt_max` is at most 0.10 s, so no beat can be skipped; the replay may run slightly long.
- **If Confirm is pressed during a replay**: it latches the speed-up and nothing else, or is refused visibly if latching would change nothing. It is never buffered as a command (rule 9).
- **If the Confirm that submitted a command is still held as the replay starts**: holding produces no new press, so it latches nothing. A **new** tap after the replay has started does latch.
- **If Cancel is pressed during a replay**: the latch clears from the next frame, if it was set, and the rest of the replay plays at the player's setting. If it wasn't set, the press is refused visibly. Cancel never opens the Menu in battle.
- **If a player is mashing Confirm as a menu opens** (command menu, target selection, Defeat Prompt, results screen): every press within `input_guard` of the menu opening is refused, with the "not yet" pulse and tick. The first new press after the guard counts. The default focus keeps a mistaken press cheap: Retry on the Defeat Prompt, and never an MP-costing command in the command menu.
- **If a direction is held as a menu opens**: it doesn't navigate, and its repeats don't either, until it is released and pressed again (rule 9).
- **If the pointer is resting over a button when a menu opens**: the default focus is kept until the pointer has moved at least `pointer_switch_px` (rule 9).
- **If the last-used command is no longer available, or costs MP** (its resource is spent, its item used up): the command menu focuses Attack.
- **If a replay ends with the latch set**: the latch is cleared with the replay, and the next replay starts unlatched.

**Cameras and framing**
- **If the overworld party teleports (map change, warp, retreat to camp)**: the camera snaps to the new position during the transition's hidden swap phase, with no smoothing. Smoothing would show a pan across the new map.
- **If the dead zone meets a map edge**: the camera stops where the view's ground footprint touches the map's bounds, and the party may move outside the dead zone near edges. The view never shows ground beyond the map (Formulas, `follow_camera`).
- **If a map is smaller than the footprint on an axis**: the camera is centred on the map on that axis and doesn't follow along it. This is the one case where the view reaches past the map's bounds, so such a map's set dressing must extend beyond its bounds far enough to fill the view; the clear color is never visible.
- **If the overworld camera's far edge would reach the horizon at 4:3** (`pitch − F_v_eff/2 < horizon_margin`): the camera config fails validation at load. This is a content bug, not a play case.
- **If the window is wider than 16:9 (21:9)**: the vertical view is fixed, and wider windows reveal more set at the sides. Battle slots are framed for 16:9, so 21:9 shows extra scenery, never cut-off actors. Set dressing must cover the view at 21:9.
- **If the window is narrower than 16:9 (16:10, 4:3)**: the camera keeps the 16:9 *horizontal* view instead, and the narrower window reveals more set above and below. Actors are never cut at the sides. Set dressing and the sky card must cover the extra height at 4:3.
- **If the window changes size**: `T`, the follow camera's footprint and dead zone, and the hit-punch's `A_peak` are recalculated from the new size, and the punch stays in whole screen pixels. A sprite's size on screen steps with `T`, never smoothly.
- **If a battle stage fails any load check** (`z_near ≤ 0`, an actor quad outside the frame, `actor_visible_min`, `dof_margin`, `horizon_frac < sky_share_min` on a boss stage): the stage fails validation when it loads, and the battle does not use it. This is a content bug, caught in testing, not in play.

**Rendering**
- **If two actors stand at exactly the same depth**: they could flicker against each other, so each formation slot is staggered by a small fixed depth step per slot index. The stagger must still pass `battle_framing`.
- **If an actor stands partly behind set geometry (a pillar, a counter)**: normal occlusion applies and the set hides the hidden part. Actors are not drawn "always on top". Battle stages are authored so every actor is at least `actor_visible_min` visible at the default camera (Formulas, `battle_framing`).
- **If a sprite in the pitched Overworld or Camp stands just in front of a wall or prop**: it occludes as an upright card at its foot anchor, so its upper body draws in front of what stands behind its feet and is hidden only by what stands in front of them (rule 2).
- **If a sprite stands far from the camera**: it is drawn at the same texel size as a near one. Only its position in the frame and its occlusion show the distance (rule 2).
- **If the victory burst and the retry flash would together exceed the flash limit**: the limit is global and wins. The retry flash's timing is fixed by Game State and cannot wait, so a refused retry flash plays its capped variant. Safety wins over the look.
- **If an alien faction has no boss lighting preset**: the game stops at boot with a content error (Content Data rule 8), exactly as for missing art (rule 10). No faction can ship with a weaker boss fight than the others (Pillar 2). If a preset is somehow still absent at runtime, for example in a debug build that skipped validation, the boss fight stays in plain Battle light, an error is logged and the fight still plays.

## Dependencies

**Upstream (this system depends on):**

| System | Nature | Interface |
|---|---|---|
| Game State & Scene Flow | Hard | Mode-entered, transition and overlay announcements, in Game State's fixed order; the mode time, which stops while the Menu is open (Game State rule 10). Without these, lighting is never switched and the Menu can't freeze the world |
| Content Data Definitions | Hard | The `sprite_set_id` on every Character and Enemy record. An unknown reference fails the boot (Content Data rule 8); this system supplies the check (ADR-0004's validator hook). Content Data never names art files (its rule 3) |
| Turn Battle System | Hard, for Battle | Each resolved outcome in order (actor, target, HP change, knocked out), the round and turn changes, and battle won or lost. All of it arrives through the Battle mode's `BattleReplayController` (ADR-0006), never from `BattleCore`'s signals directly. Boss or not and faction are **not** Turn Battle's: the Battle mode reads them from its encounter descriptor (ADR-0002 §7). Read only: this system never changes a result (rule 9) |
| Input System | Hard, for Battle input | One `pressed` per physical press, at its start, with no key-repeat echoes (its rule 2 and AC-2); navigation repeat only from a held press; focus following the pointer only after `pointer_switch_px` of movement (its rule 3). Rule 9's latch and input guard rely on these |

**Hard prerequisite: ADR-0002 Migration Step 2.** Rules 6 and 9 can't be built against today's code. `ChapterFlow._start_fight` constructs `BattleCore` and calls `start_battle()` before it emits `fight_started` (`src/chapters/chapter_flow.gd:124-127`), and `start_battle()` emits the first `turn_started` synchronously (`src/battle/battle_core.gd:90`), so neither the reveal gate nor the takeover can be queued ahead of it. A loss also builds a fresh `BattleCore` (`chapter_flow.gd:140`), which breaks ADR-0006's one controller per Battle-mode instance. This prerequisite gates story readiness for any story implementing rules 6 or 9, not this GDD's approval.

**Downstream (these systems depend on this one):**

| System | Nature | What it relies on |
|---|---|---|
| Overworld Exploration & Encounters | Hard (**provisional**, no GDD) | The follow camera; the overworld and variant lighting (occupied stages, dungeon). It must provide the party position and facing, plus each map's type |
| UI Framework | Hard (no GDD) | It relies on these from rule 9:<br>• the beat timing for when to show HP, MP, status, the round and the per-combatant numbers, read through the replay's displayed state;<br>• the three-state replay indicator, clickable to latch and un-latch;<br>• the no-buffering rule during a replay and the end-of-fight hold;<br>• the menu input guard, with its refusal feedback (the tick is the UI's in MVP);<br>• default focus, which never lands on an MP cost, and which neither a held input nor a resting pointer moves;<br>• clearing a combatant's old number on its next impact, and the clean display on Retry.<br>It also relies on the frozen frame behind the Menu, and on the guarantee that world light never tints UI. It owns the Menu blur, the Defeat card, the HUD and the comfort-settings screen (six settings, rule 13). It routes the Menu backdrop, the Defeat card stamp and the results screen through the flash gate |
| Turn Battle System (presentation side) | Soft | The battle mode's command menu waits for the replay to finish (rule 9); the battle still resolves correctly without any visuals |
| Beatbox Battle Score | Soft (Vertical Slice, 2026-10-29) | Nothing from this system; it *provides* a beat clock (bar and beat) that alien idle bobbing may follow, with a static glyph under Reduce Motion (`beatbox-battle-score.md` Visual/Audio). **Owed here (user direction 2026-10-29):** battle staging and read-order checks for up to 8 enemies (its OQ-12) |
| Audio Manager | Soft (Vertical Slice) | No Game State link through this system; both listen to Game State independently. Beat-synced battle sounds use the same replay beat events (the hit sound on impact), and it takes over the refusal tick |

**Bidirectional notes:**
- `game-state-scene-flow.md` already lists Sprite & Camera Presentation as a hard downstream dependent ("Mode announcements to apply lighting and camera"). ✓ Its flash-gate adoption is Open Question 11.
- `content-data-definitions.md`'s Interactions table already lists Sprite & Camera Presentation (`sprite_set_id`, `animation_id`, faction color and shape; "maps asset IDs to files"). ✓ Rule 10's boot check for required animations runs through the same validator hook (ADR-0004).
- `input-system.md` lists Turn Battle and Dialogue as `fast_forward`'s consumers and describes the battle-replay latch (its rule 1 and Game Feel), citing this GDD's rule 9. ✓ Its rule 3 now says focus follows the pointer only after `pointer_switch_px` of movement (amended 2026-10-22 for revision 6). ✓
- `turn-battle-system.md` lists this system as a hard downstream consumer that replays its outcomes through `BattleReplayController`, with the command menu waiting for the replay (its Dependencies). ✓
- `systems-index.md` row 4 lists Turn Battle System (hard, Battle only). ✓
- Overworld, UI Framework and Audio Manager have no GDDs; their own GDDs must list this system as upstream.

## Tuning Knobs

All knobs live in presentation data (the presentation settings and lighting presets, ADR-0005), never in code. Defaults are starting targets. `battle_fov` and each stage's camera values are set by the early technical test (ADR-0005 Migration Step 1).

**Look and staging**

| Knob | Default | Safe range | Affects | Too low | Too high |
|---|---|---|---|---|---|
| `humanoid_height_px` | set in Step 1 | 48–64 texels | The single humanoid sprite height; large aliens are integer multiples | Jokes don't read at battle distance | Animation cost per frame rises; sprites crowd the frame (64 texels is 18% of the height) |
| `battle_fov` | set in Step 1 | narrow enough that rows separate (`battle_framing`) | Battle framing; how far apart rows stand in the frame | Rows bunch together; the set feels flat | Wide-angle distortion of the set |
| `horizon_frac` (per stage) | 0.30 | 0.15–0.40 | Where the horizon sits; how much sky a battle shows | Too little sky for a boss takeover | The floor and rows are squeezed into the bottom of the frame |
| `actor_visible_min` | 0.90 | 0.85–0.95 | How much of every actor must be visible at the default battle camera (rule 4) | Back-row actors hide behind the party | Formations spread so wide they no longer read as an arc |
| `dof_margin` | 1.0 m | 0.5–2.0 | Gap in view depth between the farthest actor and the background blur | Back-row actors soften at the edges | The set behind the actors stops reading as "behind" |
| `actor_contrast_min` | 3.0 | 3.0–4.5 | Local, per-side actor-to-set contrast required (rule 1) | Dark costumes melt into dark sets | Sets must be so dark they stop reading as places |
| `body_tx` / `ring_tx` | 2 / 3 texels | 1–3 / 2–4 | Size of the bands the contrast and color checks compare (the edge band is always 1 texel) | The checks sample noise | The ring reaches unrelated set areas; the costume band reaches the actor's interior detail |
| `set_brightness_battle` | 0.70 | 0.60–0.75 | How far the battle set steps back | The set disappears, and the location stops reading | The set competes with actors (breaks Principle 2) |
| `set_brightness_boss` | 0.85 | 0.75–0.85, always ≥ the Battle level and ≤ `set_brightness_victory` − 0.05 | How far the faction flood lifts the set | The takeover barely registers | The set rivals the actors; the flood reads as a wash |
| `set_key_fill_ratio_boss` | 4.0 | 4.0–6.0, and above every non-boss preset's ratio (validated at load) | Set contrast in a boss takeover ("the hardest set contrast in the game") | The takeover set looks flat and washed | Shadows go black and the set stops reading as a place |
| `flood_chroma_frac` | 0.65 | 0.60–0.70 | Flood saturation as a share of the faction's signature chroma, before the gamut cap | The flood reads as a tint, not a takeover | The sky out-saturates the actors; the boss disappears into its own flood |
| `flood_l_max` | 35 L\* | 30–40 | The dusk ceiling for every flood swatch | Floods read as night, and the horizon glow carries everything | Floods lighten, and the squad's rim stops standing out against them |
| `flood_hue_tol` / `flood_chroma_tol` / `sky_match_min` / `flood_l_gradient` | 8° / 10 / 0.90 / 15 L\* | 5–10° / 6–12 / 0.85–0.95 / 10–15 | How strictly the flooded sky must match its swatch (Formulas, `flood`) | Skies are forced into a flat card | Unflooded patches of sky pass |
| `horizon_band_frac` | 0.08 | 0.05–0.12 | Height of the band above the horizon where the sky may glow lighter than the swatch | The neon horizon is a thin line | Half the sky glows and the flood stops reading as dusk |
| `star_count_min` / `star_share_max` / `star_twinkle_period_min` | 16 / 0.005 / 1.5 s | 8–40 / 0.002–0.01 / 1.0–4.0 s | The dusk sky's stars (user condition on D1) | The sky reads starless | Stars crowd the flood; fast twinkle reads as shimmer |
| `flood_native_de_min` | 15 ΔE | 10–20 | How different a flood must be from a boss stage's own sky | A takeover on a sky of similar color goes unnoticed | More boss stages must re-author their skies |
| `sky_share_min` | 0.20 | 0.15–0.30 | How much of a boss stage's frame the sky must cover | The takeover happens off-screen | Battle stages lose their floor and set to the sky |
| `enemy_flood_de_min` | 15 ΔE | 12–20 | How different an enemy's costume must be from the flood around it | A boss blends into its own flood | Faction costumes must stray far from their faction's own color |
| `set_brightness_victory` | 0.90 | 0.90–0.95, always < 1.0 and ≥ `set_brightness_boss` + 0.05 | Set peak during the Victory burst | The win feels muted | The set outshines the fanfare poses |
| `set_brightness_victory_settle` | 0.85 | 0.75–0.85, so always ≤ `set_brightness_victory` | Set level the Victory light settles at | The results screen sits on a gloomy set | The set outshines the squad after the burst |
| `set_brightness_defeat` | 0.40 | 0.30–0.50 | Set level outside the Defeat spotlight | Reads as a funeral | The loss doesn't register |
| `shadow_offset` | set in Step 1 | 0–0.5 × the foot width | How far the blob shadow sits along the set light's direction | Shadows look pasted on | The shadow detaches from the feet |
| `reduce_blur_factor` | 0.30 | 0.20–0.40 | Blur kept with Reduce Blur On | Battle depth separation is lost | The option fails players who need it |
| `battle_draw_call_budget` | 300 for all 3D passes (including `SetLight`'s shadow cascades) + 100 for canvas/HUD, counted separately (user decision 2026-10-22; Open Question 13 closed) | Fixed by `project.yaml` `performance.draw_call_limit` (400 = 300 + 100); changing it is a technical-director call | Battle render cost for 8 actors, the diorama, the sky card and VFX (3D), and the HUD (canvas) | Constrains set dressing | Leaves no headroom for later modes |

**Camera and punch**

| Knob | Default | Safe range | Affects | Too low | Too high |
|---|---|---|---|---|---|
| Follow `dz` (dead zone) | 10% of the footprint's half-extent | 8–12% | How much the party moves before the camera does | Camera twitches with walk animation | The party nears the screen edge before the camera reacts |
| Follow `tau` | 0.17 s | 0.15–0.18 | How tightly the camera follows. Above 0.18 the 75%-in-0.25 s feel target fails | Feels rigid and nervous | Feels laggy, and the party drifts off-center |
| `dt_max` | 0.10 s | 0.05–0.10 | Lurch protection on slow frames; also the replay clock's largest step | Camera lags on ordinary frame-rate dips | A hitch produces a visible lurch; must stay below `beat_min` |
| `horizon_margin` | 5° | 3–10° | How far below the horizon the overworld view's far edge must stay, at 4:3 | The far edge nears the horizon and the follow clamp loosens | Forces a steep pitch or a narrow field of view |
| `A_beat` normal / big | 3 / 7 px at 1080p | 2–4 / 6–8 | Hit-punch strength, scaled with window height | Hits feel weightless | Hits feel like a malfunction; discomfort |
| `D` (punch duration) | 0.10 s | 0.08–0.12, and `< reaction_hold` | Hit-punch length | The knock isn't seen | Rumble instead of a knock; overlapping punches |

**Lighting beats**

| Knob | Default | Safe range | Affects | Too low | Too high |
|---|---|---|---|---|---|
| `blend_boss` | 0.90 s | 0.60–1.00 | The first-encounter dusk flood | The escalation isn't noticed | The fight start feels stalled |
| `boss_hold` | 0.90 s | 0.60–1.20 | Boss intro pose held in the new light before the first command menu, first encounter | The takeover blurs into the first turn | The fight start drags |
| `boss_retry_hold` | 0.30 s | 0.20–0.40 | The Retry settle on the boss's intro pose | The retried fight starts with no beat to re-read the boss | Every Retry feels taxed |
| `blend_victory` / `blend_defeat` | 0.30 s | 0.25–0.35 | End-of-fight beats | Reads as a pop | Taxes the retry loop |
| `victory_settle` | 0.40 s | 0.30–0.50 | How long the Victory light takes to settle after the burst | The burst snaps off | The settle drags on long after the results screen has covered the battle (it always opens over part of the settle; rule 6) |
| `victory_hold` / `defeat_hold` | 0.40 s | 0.35–0.60, so always ≥ the matching blend | How long the fanfare or curtain-call poses are seen before the results screen or Defeat Prompt opens | The end of the fight is covered before it is seen | The retry loop feels taxed |
| `input_guard` | 0.15 s | 0.10–0.20 | How long after a menu opens every menu action is refused, with feedback (rule 9) | A press already on its way lands on a menu the player hasn't seen | A deliberate quick press is refused and feels laggy |

**Battle replay**

| Knob | Default | Safe range | Affects | Too low | Too high |
|---|---|---|---|---|---|
| `beat_min` | 0.40 s | 0.40–0.50 | Shortest a beat may play, after speed-up | Actions blur together; a phase can't be followed | Enemy phases drag; speeding up stops helping |
| `reaction_hold` | 0.25 s | 0.20–0.30, and ≤ `beat_min` − 0.10 | How long a plain reaction frame is held clean before the number; never sped up | The number covers the joke | Every beat drags |
| `ko_hold` | 0.50 s | 0.40–0.60, and ≥ `reaction_hold` | The shortest knockout hold (longer if the slump lands later); never sped up | The knockout punchline is lost in the next wind-up | Enemy phases with several knockouts drag |
| `battle_speed_mult` | 1.5 | 1.25–1.75, and ≤ `ff_mult` − 0.25 | Wind-up speed with Faster battle animations On | The setting barely helps | The latch stops adding anything on top of it |
| `ff_mult` | 2.0 | 2.0–2.5 | Wind-up speed once latched | The latch barely helps | Wind-up gags blur (**Turn Battle to ratify**) |

**Safety**

| Knob | Default | Safe range | Affects | Too low | Too high |
|---|---|---|---|---|---|
| `flash_rate_max` | 3 per s | 1–3 | Photosensitivity limit, across all flashes, counted at landing | Victory burst and VFX play capped more often | **Never above 3**: a safety limit, validated at load |

**Knobs that interact:**
- **`battle_speed_mult` and `ff_mult`:** a wind-up plays at the larger of `battle_speed_mult` (with Faster battle animations On) and `ff_mult` (once latched). `battle_speed_mult ≤ ff_mult − 0.25` is validated at load, and the ranges are chained, so a press always helps.
- **`beat_min`, `reaction_hold` and `ko_hold`:** `beat_min` floors every beat after speed-up. The holds are never sped up, so they are a fixed cost on every beat: raising either lengthens every replay at every speed. A knockout animation whose `land_frame` lands later than `ko_hold` lengthens its beats too. The load rules `reaction_hold ≤ beat_min − 0.10` and `reaction_hold ≤ ko_hold` always pass within the ranges.
- **`D` and `reaction_hold`:** `D < reaction_hold` is validated at load (the ranges give at most 0.12 against at least 0.20), so a punch always ends before the next impact.
- **`beat_min` and `dt_max`:** `dt_max < beat_min` is validated at load (at most 0.10 against at least 0.40), so a slow frame can never cross a whole beat.
- **`blend_*` and `*_hold`; the Victory and Battle/boss brightness pairs; `boss_retry_hold` and the takeover:** each pair is validated at load, and the ranges are chained so every in-range combination passes:
  - `blend_victory` and `blend_defeat` are at most 0.35, against holds of at least 0.35;
  - the Victory settle level is at most 0.85, against a peak of at least 0.85;
  - the Battle level is at most 0.75, against a boss level of at least 0.75;
  - `boss_retry_hold` is at most 0.40, against `blend_boss + boss_hold` of at least 1.20.
- **`set_key_fill_ratio_boss` and the other presets:** the ranges can't guarantee this rule, because the other presets' ratios are per-preset data. It is checked at load.
- **`battle_fov`, `h_cam`, `horizon_frac` and the slot depths:** together they set where each row stands in the frame (`battle_framing`). Changing any of them requires re-checking every battle stage.
- **`pitch`, the overworld field of view and `horizon_margin`:** the overworld camera needs `pitch − F_v_eff/2 ≥ horizon_margin` at 4:3, where `F_v_eff` is about 1.33 times `F_v` for small angles.
- **`set_brightness_battle` and `reduce_blur_factor`:** with Reduce Blur On, dimming carries the whole "background is inactive" read, which is why the Battle level stays at or below 0.75.
- **`set_brightness_boss` and `actor_contrast_min`:** the boss flood lifts the set closest to the actors of any battle state. Every boss stage must still pass the local contrast check at `set_brightness_boss`.
- **`flood_chroma_frac`, `flood_l_max`, `flood_native_de_min`, `enemy_flood_de_min` and faction costumes:** a darker dusk ceiling lowers the chroma sRGB can hold for some hues (Terminal Cyan), and it eases the native-sky floor on daylight stages while tightening it on night stages. Tune them together, per faction, on the Step 1 captures.
- **Screen Shake setting × `A_beat`:** Reduced halves `A_beat`, rounded down, with a 1 px floor. A big beat on Reduced (3 px at 1080p) equals a normal beat on Full (3 px), and a normal beat on Reduced is 1 px, so the big/normal difference shrinks on Reduced. That is accepted: Reduced trades emphasis for comfort.

> `systems-designer`'s formulas were used to derive these knobs and their interactions. Every knob above comes directly from the Formulas variable tables, plus the levels set by creative-director rulings:
> - the 2026-10-21 reviews set `set_brightness_boss`, `boss_hold` and `battle_speed_mult`;
> - the third and fourth reviews set `flood_chroma_frac`, `set_key_fill_ratio_boss`, `ko_hold`, `victory_hold`, `defeat_hold`, `boss_retry_hold`, `input_guard`, `flood_native_de_min`, `sky_share_min` and `actor_visible_min`;
> - the fifth review:
>   - added `horizon_frac`, `flood_l_max`, `enemy_flood_de_min`, `victory_settle`, `body_tx` and `ring_tx`;
>   - raised `blend_boss` and `boss_hold` to 0.90 s;
>   - lowered `battle_speed_mult` to 1.5;
>   - removed `pixels_per_unit`, `depth_spread_max`, `pitch_max`, `flood_light_l`, `enemy_flood_chroma_rel`, `edge_px`, `ring_px`, `body_px` and `flash_rate_reduced`.

## Visual/Audio Requirements

> Source: `art-director` consultation (owner of `design/art/art-bible.md`). Audio: none of its own; Audio Manager reacts to Game State directly.

**Per-state lighting intent** (the targets each lighting preset must hit; exact values are tuned in the early technical test):

| State | Actor key light | Set brightness (vs. its native lit look) | Blur | Must stay neutral |
|---|---|---|---|---|
| Title | Neutral-warm, ~4500 K, the title diorama posed like a box-art shot | 100% | Light tilt-shift | All UI; the logo never takes the scene's grade |
| Overworld | Warm golden hour, ~2900–3200 K | 100% | Moderate-to-strong tilt-shift at the diorama edges ("a toy table") | Sprite outline ink; all UI |
| Overworld variants (occupied stages 1–3, dungeon) — **provisional** | Defined by the Overworld GDD (Open Question 6). Fixed here: the actor key and rim stay neutral; faction hue may tint only the sky, set and fill (rule 11) | Below 100%, falling with occupation stage | As Overworld | Sprite outline ink; rim; all UI |
| Battle (non-boss) | Neutral, ~5600 K | `set_brightness_battle` (~70%) | Light; it separates the layers. It starts behind the farthest actor (rule 2) | Rim light (white or cream, never faction-tinted) |
| Boss takeover (per faction) | Actor key and rim **neutral**, as in Battle. The sky card goes to the faction's **dusk flood**: its hue at mid-saturation (capped where dusk can't hold it), L\* at or below `flood_l_max`, a gradient, clouds and a **neon horizon** glowing lighter in the same hue. The set light takes the hue (in its Battle direction) and the fill runs at low energy, so the set's key:fill reaches `set_key_fill_ratio_boss`, the hardest set contrast in the game. The squad reads light against the dark | `set_brightness_boss` (~85%), always below native | Same as Battle | Actor key and rim, sprite outline ink, damage numbers, navy and cream UI |
| Camp | Warm firelight, ~1800–2200 K, with flicker whose swing stays below `flash_luma_delta` (never a flash). The fire's light reaches the actors (rule 1) | Lowest of any state; the fire itself is emissive and exempt from the contrast ring | Little or none (intimate framing) | Squad UI and quirk stickers |
| Victory | A white-warm burst on the actors' key and rim, settling toward the stage's native light | Rises from Battle level to `set_brightness_victory` (~90%) at the burst's peak, then settles at `set_brightness_victory_settle` (~85%), always below the actors | Minimal during the burst | Coin Gold stays reserved for rewards; it is never a faction cue |
| Defeat | Desaturated set; one soft, wide, neutral (~5000 K, never cold blue) overhead spotlight pooled on the party row's formation centre; actors keep their key and rim | `set_brightness_defeat` (~40%) outside the spotlight | Slight, so the Defeat card stays legible | No faction color anywhere |
| Menu | Unchanged, frozen | Unchanged | Heavier than any in-mode state (drawn by the UI); scaled by `reduce_blur_factor` with Reduce Blur On | UI never takes the scene's color grade |

**Event visuals:**
- **Mode entry:** no visible light change at all; it is hidden behind the wipe or fade (rule 5).
- **Boss takeover:** on first encounter, a visible, deliberate fall into the faction's dusk across the sky and set over `blend_boss`, the horizon igniting in neon, starting on the first fully revealed frame. Then the `boss_hold` beat on the boss's intro pose. The player watches the rule-space change while the squad stays lit as itself. On Retry the light is already there when the flash clears, and the boss settles briefly.
- **Victory:** a white-warm burst (gated by the flash limit; a soft swell with Reduce Flashing On) with cream and gold confetti (a still sparkle with Reduce Motion On) and the squad's `victory` fanfare poses, settling back.
- **Defeat:** the spotlight pools in on the squad's knockout poses. The Defeat card (UI) stamps in fast and gently, "brief, never cruel".
- **Hit-punch:** the whole view shifts and settles; a sprite's foot position never smears or slides.
- **Shadow:** one chunky toy-block blob per actor, in the current lighting state's neutral shadow color, offset the same way as the diorama's own shadows.

**Rendering constraints** (each is player-visible as blurred, smeared or haloed pixels, or a hitch):
- **Native resolution only.** The 3D render scale is fixed at 1.0. FSR, other upscalers and any render scale below 1 are off, since they blur texels.
- **Whole-pixel texels.** Every sprite texel is `T × T` screen pixels, in one color, at every window size from 720p to 2160p (rule 2).
- **No glow halos on actors.** Glow takes only emissive set lights (the campfire, signs, the Victory burst source, the neon horizon). Every lighting preset carries its own glow threshold, set above the brightest rim-lit actor pixel in that state (the Victory burst's peak included, since it raises the rim), and glow bloom is fixed at 0, because a non-zero bloom makes everything glow whatever the threshold.
- **SDR output.** HDR output (new in Godot 4.7) stays off: the flash and contrast thresholds assume SDR sRGB output.
- **One pinned backend.** The rendering backend that runs on the development PC is pinned in the project settings, so the look the art director signed off is the look that ships (ADR-0005).
- **No `TIME` in world shaders, wherever they live.** World shaders read the `mode_time` that stops under the Menu (ADR-0005).
- **No shader compile in play** (Formulas, `lighting_blend`).
- **Screen-facing sprites, upright-card occlusion.** No sprite is drawn "always on top" (rule 2).

**Animation and style constraints:**
- Reaction frames (the wind-up, the hit reaction, the knockout slump, the smug combo pose, the fanfare) get the animation detail budget. Idle and walk stay minimal.
- **Never mirror** text, printed glyphs, directional faction shapes or handedness gags (rule 3, flagged per animation).
- **Party jokes are drawn to read from behind.** The squad is seen from behind three-quarters in Battle, so a recruit's gag lives in the silhouette, the pose and the prop, never only in a facial expression the camera can't see. Each squad sprite set passes the silhouette test in its `back` facing, and its `victory` pose reads from behind too.
- **Every battle sprite set has a `defend` pose**, an action animation with its own `impact_frame`, so Defend never borrows an attack, and a `knockout` with its `land_frame` (rule 10).
- **Sprites don't shrink with distance**, so a back-row enemy is drawn at full size; its distance reads from its place in the frame and from what stands in front of it (rule 2).
- **Silhouette test:** every actor must read as its joke as a solid black fill at its actual on-screen height under the default battle camera, and still read at a 32 px black-fill thumbnail (art bible Principle 1). It passes when at least 2 of 3 reviewers, shown only the fill, pick the character from a lineup of 6.

> 📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:sprite-camera-presentation` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## Game Feel

> Source: `ux-designer` consultation. Numbers are starting targets in Formulas and Tuning Knobs, to be tuned by feel on the development PC.

- **The world is still; only the actors are loud.** The diorama never moves on its own except for slow ambient motion (water, foliage, flicker). The camera never drifts, and anything that moves fast is an actor or a comedy effect.
- **The overworld camera feels attached, not elastic.** Small steps inside the dead zone don't move it. Beyond that it catches up smoothly, covering at least 75% of the excess within 0.25 s (77% at the default `tau`; `tau`'s safe range stops at 0.18 s to keep this true). It never overshoots, and never "hunts" back and forth. It doesn't lead ahead of the party, so the toy-table framing stays put.
- **Hits land with a single knock.** A hit-punch is short, sharp and decays once. It is never a rumble, and never more than one per beat. A big beat (knockout, boss hit) knocks harder, not longer.
- **Blends read as intentional, never sluggish.** A boss takeover is the one slow beat: about a second of the sky falling into dusk, then a held second on the boss's intro pose, because it is the fight escalating. It plays in full once. A Retry skips straight to the flooded light with a short settle, so the retry loop never feels taxed. Victory and Defeat land fast. These blend times sit in the same band as Game State's transition timings, so the game has one rhythm.
- **Battles read beat by beat.** Every outcome gets its own beat: the wind-up, then the impact with the reaction and the knock, a clean moment on the reaction frame, then the number. The player can follow a whole enemy phase.
  - Faster battle animations and a tap of Confirm, `fast_forward` or the replay prompt all speed up the wind-ups. Cancel, or a second click on the prompt, puts the pace back.
  - No beat is ever skipped. The clean moment on the reaction frame always lasts the same, so the joke lands at any speed, and a knockout's slump is always seen landing.
  - Nothing speeds up the first boss entrance unless the player has opted in with "Speed up boss entrances". There is no automatic speed-up (Open Question 16).
- **The game is visibly busy, not frozen, and never offers what it can't do.** During a replay a small "press to speed up" prompt shows, and a press visibly takes effect (the prompt switches to "speeding up"). When nothing left can be sped up, the prompt dims to a quiet "playing the turn", and a press is answered with the refusal pulse, so a press never feels like a dropped input.
- **An early press is answered, not swallowed.** A press that lands in the moment a menu opens is refused with a small visible pulse and a soft tick, so the player learns the rhythm instead of thinking the game dropped their input.
- **Comfort first.** Faster battle animations, Speed up boss entrances, Screen Shake, Reduce Blur, Reduce Flashing and Reduce Motion are real options. No flashing ever exceeds the flash-rate limit.

## UI Requirements

This system draws no UI. These are the guarantees it gives the UI Framework, and the requirements it places on it:

- **The world never tints the UI.** HUD, menus, the Defeat card, damage numbers and button prompts are never lit by the diorama's light or take its color grade. They stay readable over every lighting state, including the boss takeover's dusk flood and the Defeat desaturation.
- **The Menu shows a truly frozen world.** Behind an open Menu, nothing animates: no shader motion, particles or light flicker bleeds through (rule 7). The UI Framework draws the blur over that frozen frame.
- **Numbers, HP, MP, status and the round wait for the beat.** The UI shows them when the replay releases them (rule 9), never when Turn Battle computed them, and only through the replay's displayed state (ADR-0006). Each combatant whose HP changed gets its own number, and a combatant whose HP didn't change gets none, never a "0". There are no MP numbers in MVP.
- **An old number never covers a new reaction.** On a beat's impact, any number still showing over a combatant that reacts in that beat is removed on that frame.
- **The command menu waits for the replay.** The squad's next command menu opens only when the replay releases the next turn (rule 9).
- **Retry starts clean.** When the replay reports a resync (Retry), every number is cleared and the HUD shows the restored values, behind the retry flash.
- **No press before the reveal, and none buffered.** Nothing accepts a press while the battle wipe or retry flash still covers the screen. During a replay, Confirm, `fast_forward` and a click on the replay indicator latch the speed-up, Cancel clears it while any latch-dependent time remains (otherwise it is refused, and the latch ends with the replay), and nothing carries into the next menu. During the end-of-fight hold, presses do nothing (rule 9).
- **Input guard with feedback.** The command menu, target selection, the Defeat Prompt and the results screen open with the default focus of rule 9 and nothing submitted.
  - For `input_guard` after opening, they refuse every menu action (Confirm, Cancel, directions, pointer clicks).
  - Each refused press gets a short visible pulse on the focused option and a soft tick. The UI Framework plays the tick in MVP.
  - A key or direction held since before opening does nothing until released. OS key-repeat echoes never count.
  - Focus follows the pointer only after it has moved `pointer_switch_px` since opening.
- **Replay indicator.** For the whole replay (including the boss takeover), a small prompt shows in one of three states (rule 9): "[fast_forward] Speed up", with the button glyph from the Input System's current device; "Speeding up · [Cancel] Stop"; or a dimmed "Playing the turn". It is clickable: a click latches, un-latches, or is refused, following those states. It sits outside the band the actors occupy and follows the UI's text scale.
- **Comfort settings.** The settings screen offers these, with this system's defaults (rule 13):
  - Faster battle animations (Off / On);
  - Speed up boss entrances (Off / On);
  - Screen Shake (Full / Reduced / Off);
  - Reduce Blur (Off / On);
  - Reduce Flashing (Off / On);
  - Reduce Motion (Off / On).

  The UI Framework owns the screen and its persistence (Save/Load & Settings, Vertical Slice). Reduce Blur also scales the Menu's backdrop blur.
- **Large UI transitions go through the flash gate.** The Menu backdrop opening and closing, the Defeat card's stamp and the results screen opening each declare their transitions and play capped when refused (rule 13).
- **The HUD never shakes.** A hit-punch moves the world view only; HUD elements stay fixed.

> **📌 UX Flag — Sprite & Camera Presentation**: This system has UI requirements (the comfort settings, beat-timed damage numbers, the replay indicator, the frozen-world Menu backdrop). In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for each screen or HUD element this system contributes to **before** writing epics. Stories that reference UI should cite `design/ux/[screen].md`, not this GDD directly.

## Cross-References

| This GDD references | Document | What is referenced |
|---|---|---|
| Visual Rule; Principles 1–3; one pixel scale, nearest filtering, no scale or rotation; fixed battle camera (2026-10-13); ~2 facings | `design/art/art-bible.md` | §1 (principles, production notes) |
| Per-state lighting signatures; the dusk boss flood; occupation gradient | `design/art/art-bible.md` | §2 (Mood & Atmosphere) |
| Faction signature colors; the flood swatches | `design/art/art-bible.md` | §4 (Color System) |
| Lighting applied on `mode_entered`; Menu stops mode time; wipe, fade and flash colors and timings | `design/gdd/game-state-scene-flow.md` | Rules 4, 10, 11; Formulas (transition budgets); Visual/Audio Requirements |
| Art referenced by asset ID; validation fails the boot | `design/gdd/content-data-definitions.md` | Rules 3 and 8; Interactions table |
| Outcomes, knockout, battle end, synchronous enemy phase | `design/gdd/turn-battle-system.md` | Battle flow and the outcome log |
| `fast_forward` (a press latches the replay speed-up; `cancel` clears it); one `pressed` per physical press, no key-repeat echoes; navigation repeat; pointer focus after `pointer_switch_px` | `design/gdd/input-system.md` | Rules 1, 2, 3; AC-2; Open Question 1 (Esc and the Menu) |
| Pillars 1, 2, 4 | `design/gdd/game-concept.md` | Game Pillars |
| The build: sprite shader and projection, texel scale, diorama stage, sky card, level shift-lens camera, lighting profiles, compile contract and Boot warm-up, flash gate service, backend pin | `docs/architecture/adr-0005-sprite-camera-presentation.md` | Decision (revision 2) |
| The whole replay controller contract: states and signals, reveal gate and takeover hold, call order on first entry, Retry and exit, the beat clocks, the latch and its effectiveness, the outcome-to-animation map, displayed state and resync | `docs/architecture/adr-0006-battle-replay-ownership.md` | Decision (revision 3) |
| Encounter descriptor (boss, faction); Retry restore; Battle mode lifecycle | `docs/architecture/adr-0002-game-state-scene-flow.md` | §2, §5, §7 |
| Test harness, capture tool, flash analyser, benchmark and playtest procedures named by the ACs | `production/qa/test-plans/sprite-camera-presentation-test-plan.md` | Procedures P-01 onward |
| Photosensitivity thresholds (general and red flash, area); non-text contrast 3:1 | WCAG 2.2 | 2.3.1; 1.4.11 |
| Review findings this revision answers | `design/gdd/reviews/sprite-camera-presentation-review-log.md` | Review of 2026-10-22 (the fifth; NEEDS REVISION) |

## Acceptance Criteria

> Source: `qa-lead`, validated against Sections C, D and E and the project's testing standards; revised against five `/design-review`s. Each AC states an **observable outcome** and names the test-plan procedure that runs it (`P-nn` in `production/qa/test-plans/sprite-camera-presentation-test-plan.md`). The plan owns the harness, the stubs, the tolerances, the capture tool, the flash analyser, the benchmark and the playtest protocol (ruling 7). Tests of the controller's own mechanism (queue, clocks, latch, map) are ADR-0006's Validation Criteria; tests of the build (shader, stage, compile warm-up) are ADR-0005's. The ACs here test what the player sees.
>
> IDs are never renumbered: a rewritten AC keeps its ID, and a retired one is marked as retired. AC-1 to AC-35 date from the first draft; AC-36 onward were added in revisions 2–6.

**Evidence tags:**
- **[L]** Logic, headless gdUnit4 (`tests/unit/presentation/`; the controller's own tests are in `tests/unit/battle/`).
- **[I]** Integration, headless (`tests/integration/presentation/`).
- **[C]** Capture-measured on the development PC: automatic pass/fail from the capture tool (P-09), which needs a GPU and a windowed run. **The tool does not exist yet.** It is built in ADR-0005 Migration Step 1c, with its own story. Every [C] clause gates the story that ships the measured feature, never this GDD's approval.
- **[VF]** Retained screenshot plus art-director sign-off (P-17), in `production/qa/evidence/` (BLOCKING).
- **[UI]** Retained screenshot (P-18), in `production/qa/evidence/` (BLOCKING).
- **[P]** Benchmark on the development PC (P-14, P-15).
- **[PT]** Playtest with first-time players (P-16).

All [L] and [I] tests follow P-02's conventions:
- expected values come from the presentation data through the Formulas, never from literals;
- every formula test also runs once with a non-default config;
- the battle RNG is seeded;
- times are checked within one frame step **per event**;
- no assertion lands on a threshold frame: a threshold sits half a frame from any frame boundary, and the test asserts the frames on each side of it.

**Read order, scale, facings (rules 1–3)**
- **AC-1 [L]** (P-06) In every shipped lighting preset:
  - the actor key lights only actors, and the set and fill lights only the set;
  - the actor material takes no ambient light, and every actor's rim strength is above 0;
  - every `boss_<faction>` preset's actor key and rim colors equal the Battle preset's.
- **AC-2 [L]** (P-03) For any foot anchor, camera and frame size, the sprite projection returns:
  - a quad of exactly `frame_w × T` by `frame_h × T` pixels, with its bottom-centre at the projected foot anchor rounded half away from zero;
  - with `T` equal to 2, 3, 4, 6 and 2 at heights of 720, 1080, 1440, 2160 and 900.

  Every `CharacterSprite`'s shader inputs equal that function's output on every frame, in Battle and the Overworld, including at the near and far ends of a stage and at the frame's corners. Every sprite set:
  - is filtered nearest;
  - has node scale (1, 1, 1) and rotation 0 before, during and after a hit-punch and a replay;
  - has a humanoid frame height of `humanoid_height_px`, with large-alien heights integer multiples of it.
- **AC-3 [L]** (P-06) GIVEN an animation flagged `no_mirror`, WHEN its sprite is placed on the mirrored side, THEN its authored opposite-direction art is used and it is not mirrored, while the same set's unflagged animations are mirrored. GIVEN an unflagged set, THEN mirroring follows formation side (Battle) or movement direction (Overworld).

**Cameras (rule 4)**
- **AC-4 [L]** (P-07) GIVEN a full battle with hit-punches, THEN the battle camera's position and rotation never change and its pitch is 0. Its `size`, `near` and `keep_aspect` (always `KEEP_HEIGHT`) never change except on a window resize. Only its lens shift changes, and on every frame it equals the stage's base shift plus the `hit_punch` offset.
- **AC-5 [L]** (P-07) GIVEN Camp or Title, WHEN a hit resolves or the party moves, THEN the camera transform and lens shift are unchanged.

**Lighting (rules 5–6)**
- **AC-6 [I]** (P-06) GIVEN each Game State mode entry, THEN on the frame `mode_entered` is handled, while the transition still covers the screen, every lighting parameter its preset does **not** declare animated equals the target preset within 1e-4. Over the next 120 frames, with no blend requested, none of those parameters changes. Parameters declared animated (campfire flicker, ambient motion) stay inside their declared range on every frame.
- **AC-7 [L]** (P-06) GIVEN a boss-takeover, victory or defeat blend with `dt = 1/60` and a `blend_time` of 26.5 frames (counting the request frame as frame 0):
  - on frame 26, `p < 1 − 1e-4`;
  - on frame 27, `p = 1` and the blend reports complete;
  - on every frame, every continuous parameter equals `lerp(L_from, L_to, p)` within 1e-4.

  Mode entry gives `p = 1` on its first frame, with no NaN in any parameter.

**Menu freeze (rule 7)**
- **AC-8 [I]+[C]** (P-01, P-08) Three cases, each frozen by opening the Menu: (a) mid-wind-up of a beat, (b) on the third frame of a running hit-punch, (c) mid-blend of a first-encounter boss takeover.
  - **[I]:** over 300 frames with the Menu open, the probe reads unchanged values for the `mode_time` global, every lighting parameter, the camera's lens shift, every sprite's frame, and the replay's state and clocks, and no beat, hold, number or sound event fires. On the frame after the Menu closes, each value has moved by no more than one `dt_max` step of its formula. Every particle node in the mode scene reports it is not processing, and none under `ModeHost` is set to always process.
  - **[C], live, with a control:** two frames of the running game's main viewport, case (a) on a stage with a moving-particle fixture, grabbed 1 s of real time apart with the Menu open, are pixel-identical in the world layer. The same two grabs with the Menu closed differ, so the check can fail. Pending: the capture tool.
- **AC-9 [L]** (P-06) GIVEN Dialogue or the Defeat Prompt open, WHEN mode time advances, THEN sprite animation advances.

**Hit-punch (rule 8)**
- **AC-10 [L]** (P-04) GIVEN a replay of N outcomes that lower HP, THEN exactly one punch starts per beat, on that beat's impact frame. A knockout beat, or a beat whose actor is the encounter's boss, uses the big amplitude. GIVEN a heal, Defend, Speak to the Manager, Viral Stunt or a 0-damage Attack, THEN no punch starts.
- **AC-11 [L]** (P-04) GIVEN a punch requested directly (bypassing the replay, which never releases a beat before the takeover ends, AC-45) during a boss-takeover blend or its hold, THEN it is dropped: no punch plays, then or later, and nothing is deferred.
- **AC-12 [L]** (P-04) GIVEN a punch, THEN every actor's world position (in metres) is unchanged on every frame.

**Battle replay (rule 9)**
- **AC-13 [I]** (P-04) GIVEN an outcome log of N entries from a real, seeded `BattleCore`, played unlatched, latched, and with Faster battle animations On, THEN:
  - **order:** beats play in log order, and each outcome starts, impacts and ends exactly once, in that order;
  - **impact:** lands on the first frame where the wind-up reaches `w_i`, computed from the action animation's `impact_frame`. On that frame every reacting combatant's reaction and the punch (if any) start, and the actor shows no reaction;
  - **end:** comes `hold_i` of 1× time after impact, or later when the `beat_min` floor extends it. No number shows before the end;
  - **frames:** on every frame before impact, the actor's frame follows the wind-up clock, and from impact to the end, every reaction frame follows the post-impact clock, at every tested speed. An animation that has run out shows its last frame;
  - **after the beat:** the actor is in `idle`; a `hit`, `heal` or `status` reactor finishes its reaction, then is in `idle`; a knocked-out combatant holds the last frame of `knockout` until the battle ends;
  - **back-to-back actor:** GIVEN a Bureaucratia enemy turn of Defend then Attack, THEN on the second beat's first frame that enemy shows `attack` frame 0, and on no frame between the two beats does it show `idle`;
  - **debug path:** with validation skipped and no action animation, impact lands at `beat_min − reaction_hold` at every speed.
- **AC-14 [L]** (P-04) GIVEN any replay driven to completion, THEN no `BattleCore` mutator is called, and every combatant's HP and status are identical before and after the replay. On every released turn, and when the queue drains, the HUD's displayed HP, MP, Defend, stun and Viral Stunt values equal each combatant's live values. That includes after Family Meal, after MegaCorp's per-round bill, on the turn a Defend wears off, and on the turn after a stunned enemy's skipped turn.
- **AC-14b [L]** (P-04) (outcome shapes) GIVEN each shipped move resolved by a real, seeded `BattleCore`, THEN:

  | Move | Actor pose | Reactions | Numbers | Punch |
  |---|---|---|---|---|
  | Attack (damaging) | `attack` | target `hit`, or `knockout` if it fell | one, over the target | yes |
  | Attack (0 damage, fixture) | `attack` | target `hit` | none | no |
  | Defend | `defend` | none | none | no |
  | Family Meal (3 living members including the healer, one at full HP) | its move-specific animation or `attack` | `heal` (or no change in pose) on each healed member other than the healer | one per healed member, the healer included; none for the one at full HP | no |
  | Appetizers (single heal) | its move-specific animation or `attack` | target `heal` (or no change in pose) | one, over the target | no |
  | Home Run (direct damage) | its move-specific animation or `attack` | target `hit`, or `knockout` if it fell | one, over the target | yes |
  | Speak to the Manager | its move-specific animation or `attack` | target `status`, or `hit` when the set has no `status` art | none | no |
  | Viral Stunt | its move-specific animation or `attack` | target `status`, or `hit` when the set has no `status` art | none | no |

  No number anywhere reads "0".

**Missing art (rule 10)**
- **AC-15 [L]** (P-06) GIVEN a sprite set missing a required animation from rule 10's table in a facing it uses (including a squad set's `victory`), THEN boot ends in Content Error naming the set and animation. GIVEN a missing optional animation, THEN rule 10's fallback plays, the logger receives exactly one warning, and the battle completes. GIVEN a debug run that skipped validation and a `no_mirror` animation with no same-facing art, THEN the checkerboard placeholder plays, and the opposite facing is never mirrored.

**Faction color, shadows, comfort (rules 11–13)**
- **AC-16 [L]** (P-06) GIVEN every lighting preset, THEN the squad's rim color and outline ink equal the presentation config's in every state. In every preset that is not `boss_*` or `occupied_*`, no light color is within ΔE 10 of any faction's signature color. In every preset, the shadow color is at least ΔE 10 from every faction's signature color.
- **AC-17 [L]** (P-06) GIVEN any scene, THEN exactly one light casts shadows (the set light), and every actor sprite casts none. Each actor has exactly one blob shadow, at its foot anchor offset by `shadow_offset` along the set light's ground-projected direction, colored with the current preset's shadow color.
- **AC-18 [L]** (P-04) GIVEN Screen Shake Off, or Reduce Motion On at any Screen Shake setting, THEN the punch offset is always 0. GIVEN Reduced, THEN `A_peak = max(1, floor(A_full / 2))` whenever `A_full > 0`, with the same duration; at 720p with `A_beat = 2` it is 1, not 0.

**Formulas**
- **AC-19 [L]** (P-07) **battle_framing**. Comparisons use a tolerance of 1e-6.
  - Each slot's foot row equals `y_foot(z)` within 0.5 px.
  - A fixture formation whose most-covered slot has `visible_share` exactly `actor_visible_min` passes; one at 0.01 below fails at load.
  - Two fixture slots directly in line pass exactly when `row_gap ≥ actor_visible_min · q`.
  - A stage also fails with `z_near ≤ 0`, with an actor quad 1 px outside the frame at any of 16:9, 21:9 and 4:3, with background blur starting 0.01 m of view depth before `z_far + dof_margin`, or (a boss stage) with `horizon_frac` 0.01 below `sky_share_min`.
  - The formula example's numbers are reproduced.
- **AC-20 [L]** (P-07) **follow_camera**:
  - an offset inside the dead zone moves the camera 0, and each frame's movement equals the formula within 1e-4 m;
  - with a static target starting outside the dead zone, runs at 60 fps and at 30 fps agree within 1e-3 m at every shared 1/30 s step, and the camera never passes the target;
  - a frame with `dt = 0.5` moves the camera exactly as `dt = dt_max` does;
  - with the dead zone at 0 and a static target 2 m away, at `tau` = 0.15, 0.17 and 0.18 and 60 fps, at least 75% of the distance is covered by frame 15;
  - **footprint:** the Formulas example camera gives `a_near`, `a_far` and `w_far` of 5.40, 10.15 and 9.03 m at 16:9, within 1e-2. With the target driven into every edge and corner of a 60 × 40 m map, at 16:9, 21:9 and 4:3, the ground hits of the view's four corner rays lie inside the map on every frame;
  - **horizon:** a camera config with `pitch − F_v_eff(4:3)/2` 0.1° below `horizon_margin` fails at load, even though it passes at 16:9.
- **AC-21 [L]** (P-04) **hit_punch**. The offset function, called directly, equals the formula exactly in whole pixels at 1080p and at 2160p. That includes the tie: `A_peak = 2` at `t = D/2` gives 1 px. In play, sampled at `dt = 1/60` with `D = 0.105` s so that no frame lands on a tie or on `D`:
  - the offset never changes sign and never exceeds `A_peak`;
  - it is 0 from the first frame at or after `D`;
  - it starts on the impact frame.

  Over a full replay latched at `ff_mult`, no punch starts while another is non-zero.
- **AC-21b [C]** (P-09) (pure shift; Pending: capture tool) On a Battle capture at a punch's peak and one with no punch, the ID pass of every near actor, far actor and set element is displaced by the same whole number of pixels, `A_peak` in the punch direction.
- **AC-22 [L]** (P-06) **lighting_blend**:
  - at `t_blend = blend_time / 2`, called directly, `p = 0.5`;
  - a blend requested mid-blend starts from the current values, and no frame-to-frame change exceeds the formula's largest single-frame step;
  - `blend_time = 0` gives `p = 1` with no NaN;
  - with a 26.5-frame blend, a discrete parameter has its old value on frame 13 and its new value on frame 14.
- **AC-23 [L]** (P-04) **replay_time**, parametrized over these cases:
  - an empty replay, a plain-only replay, a replay with a Defend, and a replay with a knockout whose slump lands before `ko_hold` and one whose slump lands after it;
  - latched from the first beat, latched mid-beat, and latched then Cancel mid-replay;
  - Faster battle animations On, unlatched and latched;
  - beats floored by `beat_min`;
  - the debug path with no animation.

  In each case:
  - every beat's wall time and the total equal the formula within one frame step per event;
  - every outcome starts, impacts and ends exactly once;
  - **the hold never scales:** at every speed, impact to end equals `hold_i` within one frame, unless the floor extends it. A Defend has no hold;
  - **knockouts are plain:** latched, a knockout's wind-up plays at `ff_mult` like any other, and its hold is `max(ko_hold, k_i)`;
  - **a mid-beat latch:** the rest of the wind-up plays at `ff_mult` from the next frame, and the hold is unchanged;
  - **the floor:** padding lands in the hold, so the impact frame matches the unfloored case;
  - **Cancel:** after Cancel, wind-ups return to 1×, or `battle_speed_mult` with Faster battle animations On, from the next frame;
  - **the latch clears:** the next replay starts unlatched;
  - **no automatic speed-up:** unlatched with the setting Off, every wind-up plays at exactly 1×, however long the replay;
  - **Victory and Defeat** blends and holds play at 1× even when the replay ending the battle was latched.
- **AC-24 [L]** (P-06) **set_brightness_and_blur**:
  - **Steady states:** set brightness equals `B_native × k_state` in Battle, Boss takeover and Defeat, with `k_state < 1.0` in all three.
  - **Victory**, at the defaults with `dt = 1/60`, measured on the Battle stage's lighting state whether or not the results screen covers it (rule 6), with frames counted by P-02's convention:
    - set brightness is `0.70 × B_native` on frame 0, `0.90 ×` on frame 18 (the peak, `t = blend_victory`) and `0.85 ×` from frame 42 on (`t = blend_victory + victory_settle`);
    - on every frame, it equals the Victory curve within 1e-4 and never exceeds `set_brightness_victory × B_native`;
    - the actors' key and rim equal their Battle values within 1e-4 on frame 0 and from frame 42 on, and are strictly above them on every frame with `0 < t < blend_victory + victory_settle`.
  - **Victory after a boss fight:** set brightness is `0.85 × B_native` on frame 0 and never below it before the peak; the sky's color equals the flood swatch's on every frame of Victory.
  - **Sky:** sky energy equals `B_sky_native × k_state` in every non-takeover battle-family state.
  - **Boss takeover:** the flooded fill's energy equals the set light's divided by `set_key_fill_ratio_boss`, and the set light's direction equals the stage's Battle preset's.
  - **Reduce Blur** scales blur only, never brightness, including the Menu backdrop's blur, and applies to the frozen frame while the Menu is open.
- **AC-25 [L]** (P-05) **flash_gate**. The gate is driven with an injected real-time clock in integer microseconds, and transitions declared as offsets.
  - **Landing, not request:** three stamps declaring ↑ +50,000 µs and ↓ +150,000 µs, requested at 0, 200,000 and 400,000 µs: the first two are allowed and the third is refused and plays capped. With a limit of 5 passed directly into the gate under test (not through the presentation config, whose load rule caps it at 3), all three are allowed.
  - **Counting:** a fixed sequence of one stamp every 100,000 µs for 10 s never books more than `flash_rate_max` flashes in any closed one-second window. N alternating booked transitions count as N − 1 flashes.
  - **Refusal:** a refused request books nothing and plays the capped variant. With Reduce Flashing On, every gated request is refused.
  - **Reserved:** a boss flood books its transition even when the gate would refuse a gated source. A gated source that would then exceed the limit is refused. A fixture reserved sequence that alone exceeds the limit fails boot validation.
  - **Menu:** with the one-second window already holding `flash_rate_max` booked flashes, a request 200,000 µs later that would add one more is refused, with the Menu opened and closed in between. The Menu's own open and close transitions are gated requests too; in this fixture they are refused, so they play capped and book nothing.
  - **Frozen source:** a stamp is allowed and frozen by the Menu between its ↑ and its ↓. While frozen its ↓ is unbooked but counts as pending at its resume-time landing, so the Menu's close transition is judged with it in (and refused, playing capped, when the window would overflow). On resume the ↓ is re-booked with reserved priority and **always lands**: the screen returns to rest. Across the whole sequence (stamp, Menu open, Menu close, resume) no closed one-second window of the composite frame holds more than `flash_rate_max` flashes.
  - **Clock rate:** a gated two-flash source (↑↓↑↓) allowed at 1× and latched after its first ↑ has its unlanded transitions re-booked at their compressed landing times on the latch frame. If that would exceed the limit, its first ↓ (a closing transition) still lands, and its second ↑↓ are dropped and play capped. A transition after a scheduled wind-up-to-hold rate change lands on the frame its schedule-integrated `t_land` predicts, within one frame step.
  - **Capped means capped:** every source's capped variant, measured on its fixture frames, has no general transition (`< flash_luma_delta`) **and** no red transition, or stays below `flash_area_min`. A fixture whose capped variant is a saturated-red swing fails boot validation.
  - **Aggregation:** with two area-exempt sparks each declaring 10% of a window playing, a third declaring 10% goes through the gate. One declaring 4% starts exempt.
  - **Definitions**, on fixture frame pairs:
    - a 0.11 swing with the darker state at 0.78 is a transition, and a 0.09 swing is not;
    - a 0.11 swing with the darker state at 0.82 is not;
    - a saturated-red fixture pair chosen so the two encodings disagree (a pair that is a red transition on linear R, G, B and is not on gamma-encoded values) is classified as a transition;
    - a change over 26% of one 10° window counts, and over 24% it does not.

**Edge cases**
- **AC-26 [L]** (P-04) (Retry and cancel in a boss fight) GIVEN Retry in a boss fight with a full (uncapped) retry flash, with Faster battle animations and Speed up boss entrances both Off (AC-45 covers the other speeds), THEN:
  - every lighting parameter equals the takeover's end-state preset within 1e-4 on every frame from the first frame the retry flash stops fully covering the screen;
  - the boss shows the last frame of its `intro` for `boss_retry_hold` before the first command menu opens.

  GIVEN a capped retry flash, THEN the light moves from Defeat to the takeover end state as one blend over `blend_defeat` from the flash's start, with no frame-to-frame change larger than the blend's largest step. GIVEN a first-encounter takeover cancelled mid-blend by an exit, THEN every lighting parameter equals the next mode's entry preset on the first frame that mode is revealed.
- **AC-27 [L]** (P-07) GIVEN a warp, map change or retreat, THEN the camera snaps during the hidden swap phase (zero smoothing frames). At a map edge, the ground hits of the view's four corner rays lie inside the map's bounds. GIVEN a map narrower than the footprint on one axis, THEN the camera's position on that axis equals the centre of its clamp bounds on every frame.
- **AC-28 [I]** (P-06) GIVEN an alien Faction record with no `boss_<faction>` lighting preset, THEN boot ends in Content Error. GIVEN a debug run that skipped validation, THEN the boss fight stays in Battle light, the logger receives one error, and the fight completes.

**Cross-system**
- **AC-29 [I]** (P-01, P-04) (Game State, Turn Battle) With a real, seeded `BattleCore`, the controller and a stub Game State:
  - GIVEN a battle entry, THEN the first command menu opens only after the reveal, and in a boss fight only after the takeover.
  - GIVEN a command that ends the battle, THEN the outcome reaches Game State only after the last beat and the end-of-fight hold, and the Defeat Prompt opens only after that.
  - GIVEN a command that does not, THEN the command menu opens only when the next turn is released.
  - The HUD has no connection to `BattleCore`'s own turn, round or end signals.
- **AC-30 [I]** (P-06) (Content Data) GIVEN a Character record with an unknown `sprite_set_id`, THEN boot ends in Content Error. GIVEN the checkerboard placeholder ID, THEN boot reaches Title.

**Performance**
- **AC-31 [P]** (P-14) On each binding device, a GTX 1080-class desktop (8 GB RAM) at 1920×1080 and a Steam Deck at 1280×800 (native Linux export), in a windowed release export, the battle benchmark (8 actors, a boss takeover restarted every 2.0 s of mode time, vsync off, 5 runs of 600 frames after a 120-frame warm-up) meets these:
  - the 99th-percentile frame time over all runs is at most 16.6 ms (`performance.frame_time_p99_ms`);
  - no frame in any run exceeds 33 ms (`performance.frame_time_worst_ms`);
  - on every measured frame, 3D draw calls stay at or below 300 and canvas draw calls at or below 100, counted separately (`battle_draw_call_budget`).

  A failure on either device fails the criterion. A 3840×2160 run on the desktop is measured and reported, but doesn't gate. Peak RAM and VRAM are reported so a memory ceiling can be set. Limits and hardware: user decision 2026-10-22 (Open Question 13, closed), recorded in `project.yaml` and ADR-0005 Performance Implications.

**Screens (capture-measured, then signed off)**
- **AC-32 [C]+[VF]** (P-09, P-10, P-17) (Pending: capture tool) One capture per lighting state (Title, Overworld, Battle, each faction's boss takeover, Camp, the Victory burst's peak, Defeat) at 1920×1080. Battle and one boss takeover are also captured at 1280×720, 2560×1440 and 2560×1080 (21:9).
  - **[C] Read order:** every actor passes `read_order` in every valid sector, with emissive and below-the-feet ring pixels excluded. An invalid capture is a tool error, never a pass or a fail. The 720p capture must be valid.
  - **[C] No glow on actors** (Pending: the glow-input hook): from the engine's glow input, before tonemapping, the brightest actor pixel is below that state's glow threshold, including at the Victory burst's peak. Glow bloom is 0 in every preset.
  - **[VF] Sign-off:** the art director signs off the read order (actors first, rule UI second, set last) and the set's saturation.
- **AC-33 [VF]** (P-17) A black-fill silhouette sheet at battle height and at 32 px, with every squad member in its `back` facing (idle and `victory`) and every enemy in its `front` facing. Each character passes the 2-of-3 lineup test.
- **AC-34 [C]+[VF]** (P-09, P-11, P-17) (Pending: capture tool) One boss takeover per faction, captured on the last frame of the hold. Parity is **lavishness, not lightness or chroma**: each faction's dusk swatch sits in its own place, and Terminal Cyan's gamut-capped chroma is expected.
  - **[L] the same structure for every faction:** in every `boss_<faction>` preset:
    - `blend_boss`, `boss_hold`, `boss_retry_hold`, `set_key_fill_ratio_boss` and `flood_chroma_frac` have the same values;
    - the set light's direction equals the stage's Battle preset's;
    - the set and fill light hues are within `flood_hue_tol` of the faction's signature hue;
    - the actor key and rim equal the Battle preset's;
    - every swatch's L\* range is at or below `flood_l_max`, and its chroma equals `min(flood_chroma_frac × C*_signature, C*_max)`.
  - **[C] the flooded sky:** on the ID pass's sky pixels, shrunk by 2 px at the sky's edges:
    - at least `sky_match_min` of them match the flood's hue and chroma;
    - above the horizon band, no non-star sky pixel is lighter than the swatch's upper L\* bound; inside the band, none is lighter than that bound plus `flood_l_gradient`; nowhere is one darker than the lower bound minus `flood_l_gradient`;
    - the mean L\* of the non-star sky pixels is at most `flood_l_max`;
    - the sky's L\* standard deviation is at least 2, so a flat card fails.
  - **[C] stars:** at least `star_count_min` stars are visible above the horizon band, covering at most `star_share_max` of the sky, each exactly one texel (`T × T` px).
  - **[C] the sky is seen and is not the stage's own:** `sky_share ≥ sky_share_min`, and the swatch at its `L*_mid` is at least `flood_native_de_min` from the stage's native sky.
  - **[C] enemy against flood:** in every valid sector, every enemy's costume band is at least `enemy_flood_de_min` from its ring.
  - **[C] hardest set contrast** (Pending: the set-light shadow mask): the ratio of mean lit-set to mean shadowed-set luminance is higher in each boss takeover than in that stage's Battle capture.
  - **[C] cross-checks:** the faction shape is in view (AC-37); the squad is untinted (AC-67); the HUD is untinted (AC-53).
  - **[VF] side-by-side review:** the art director reviews all faction takeovers together. No faction's takeover is less lavish, uglier or villain-coded than another's (Pillar 2), the horizon glow reads, and the blob shadows match the specified look.
  - **Pending:** the swatches are set at Step 1 (Open Question 7). Until then, the sky's L\* clause is part of the [VF] sign-off, and the rest of the AC runs.
- **AC-35 [C]+[VF]** (P-09, P-12, P-17) (Pending: capture tool)
  - **[C] Coverage:** Battle and Overworld at 16:9 (1920×1080), 21:9 (2560×1080) and 4:3 (1440×1080). Every actor's silhouette lies fully inside the frame, and no pixel of the ID pass is the sentinel clear class.
  - **[C] Whole-pixel texels:** the same Battle scene in the unlit-albedo mode at 1280×720, 1920×1080, 2560×1440 and 3840×2160, plus 1600×900, for every sprite, near and far, including those nearest the frame's corners:
    - every texel covers exactly a `T × T` block of screen pixels on the expected grid;
    - each block is one color, so no texel is blended or split;
    - the near and far rows' blocks are the same size.
  - **[C] Lit spread:** in the normal lit mode, each block's internal ΔE spread is at most 3, because lighting varies slightly across a texel.
  - **[VF] Sign-off:** the art director confirms the texels look crisp at every size, the sprites don't read as leaning against or cutting into the set, and the constant-size rows read as near and far.

**Added in revision 2**
- **AC-36 [L]** (P-04) (Retry or exit mid-replay) GIVEN a stub battle that emits 5 outcomes and a turn, played through 2 beats:
  - **Retry**, when the retry transition starts:
    - no beat, number or released-marker event fires for a discarded entry, and the end-of-fight hold, if running, is cancelled;
    - behind the flash, the display resets: every number is cleared, every sprite is in `idle` (knockout poses included), the punch offset is 0 and the indicator is hidden;
    - the displayed HP and MP equal the restored party values and the full-reset enemy values;
    - the next replay starts from an empty queue.
  - **Retreat and Quit:** when a transition away from Battle starts mid-replay or mid-hold, no event fires for a discarded entry, and no Victory or Defeat light plays afterwards.
  - **On every path, on the next frame:** the punch offset is 0, the latch is cleared, and no beat-driven sprite animation advances.
- **AC-37 [I]** (P-07) (colorblind shape, rule 11) GIVEN each boss stage, THEN at least one node tagged as that faction's shape exists, and its bounds lie inside the battle camera's view on every frame of the takeover blend and hold.
- **AC-38 [L]** (P-05) (input during a replay, the indicator):
  - **Pressing:** while active and unlatched, Confirm, `fast_forward` and an indicator click each latch, and no command is submitted. While latched, Cancel and an indicator click each un-latch from the next frame.
  - **Refusal:** a press that changes nothing (Confirm while latched, Cancel while unlatched, any press while passive) produces exactly one refusal event and changes nothing. Cancel never opens the Menu.
  - **Passive state:** the indicator is passive on exactly the frames where `press_effective` is false. With only knockout holds left, it is passive. During a first-encounter takeover, it is passive with "Speed up boss entrances" Off and active with it On.
  - **Text:** the indicator shows on every frame of a replay (the boss takeover included) and on no other frame, with the state's text from the frame after each change.
  - **After the replay:** the command menu that opens afterwards focuses the default of rule 9, with nothing submitted.
- **AC-39 [L]** (P-04) (slow frame) GIVEN `dt_max = 0.1`, WHEN a 0.5 s frame arrives mid-replay, THEN at most one beat ends on it, and every outcome still starts and ends exactly once.
- **AC-40 [L]** (P-07) (overlay camera hold) GIVEN Dialogue open in the Overworld, WHEN the party anchor moves, THEN the follow camera's position is unchanged until the Dialogue closes.
- **AC-41 [L]** (P-04) (setting change mid-punch) GIVEN a running punch, WHEN Screen Shake changes to Off (or Reduce Motion turns On), THEN the next frame's offset is 0. WHEN it changes to Reduced, THEN the next frame's offset uses the new `A_peak` at the unchanged elapsed `t`.
- **AC-42 [L]** (P-07) (same-depth stagger) GIVEN every battle formation, THEN no two actor slots share a view depth, and the staggered stage still passes `battle_framing`.
- **AC-43 [L]+[VF]** (P-07, P-17) (occlusion and visibility)
  - **[L]** every shipped battle stage, with every slot filled, passes `visible_share ≥ actor_visible_min` for every slot.
  - **[VF]** for each battle stage at its default camera, one capture with every slot filled: no actor is hidden by set geometry or by another actor beyond the limit, and the back row reads, signed off by the art director.
- **AC-44 [L]** (P-06) (Reduce Motion) GIVEN Reduce Motion On, THEN the punch offset is 0, ambient set motion parameters are 0, and the Victory confetti is the still variant. Lighting blends, sprite animation and the follow camera behave exactly as with it Off.
- **AC-45 [I]** (P-01, P-04) (boss takeover, rule 6) GIVEN a boss fight with a real, seeded `BattleCore`, the controller and a stub Game State:
  - **Starts on reveal:** the takeover blend is at `p = 0` on every frame before the reveal, and has started on the first frame after it.
  - **First encounter, protected:** with "Speed up boss entrances" Off, the takeover lasts `blend_boss + boss_hold` within one frame per event, with Faster battle animations On and with the replay latched. With it On, it lasts `(blend_boss + boss_hold) / battle_speed_mult` with Faster battle animations On and no press, and `/ ff_mult` latched.
  - **One clock:** on every frame, the stage's takeover blend equals `smoothstep(clamp(t_hold / blend_boss, 0, 1))` within 1e-4, and the boss's `intro` frame follows `t_hold − blend_boss`, where `t_hold` is the takeover's clock.
  - **Holds the battle:** no beat starts and no command menu opens before the takeover ends.
  - **Retry settles:** the settle lasts `boss_retry_hold` at 1×, `/ battle_speed_mult` with Faster battle animations On, and `/ ff_mult` latched, each within one frame per event.
- **AC-46 [L]** (P-07) (aspect) GIVEN window sizes of 16:9, 21:9, 16:10 and 4:3, THEN every actor slot's quad lies inside the battle camera's view, and the camera keeps the 16:9 horizontal view below 16:9 and the 16:9 vertical view above it.
- **AC-47 [L]** (P-06) (rendering constraints)
  - **Project settings:**
    - a 3D render scale of exactly 1.0, with no upscaler;
    - HDR output off;
    - screen-space AA and TAA off;
    - the rendering backend pinned to the one ADR-0005 names.
  - **Presets:** every lighting preset has glow bloom 0 and its own glow threshold.
  - **The world-shader lint** fails three fixtures under a mode-scene path:
    - a shader file reading `TIME`;
    - a scene with embedded shader code reading `TIME`;
    - a visual shader with a Time node.

    It passes a UI shader outside `ModeHost` that reads `TIME`.

**Added in revision 3**
- **AC-48 [C]** (P-09, P-10) (emissive behind an actor; Pending: capture tool) On every AC-32 capture, rendered once more with the actors hidden, no emissive pixel lies inside any actor's silhouette. Emissive pixels beside an actor are allowed, so a Camp fire beside the squad passes.
- **AC-49 [L]** (P-06) (Defeat spotlight) GIVEN Defeat with party rows of 1, 2, 3 and 4 members, THEN the spotlight's ground-plane centre equals the party row's formation centre within 1e-4 m, and every party actor's key and rim strengths equal their Battle values.
- **AC-50 [L]** (P-07) (follow camera under the Menu) GIVEN the Overworld with the Menu open, WHEN the party anchor moves, THEN the camera is unchanged on every frame while the Menu is open. WHEN the Menu closes, THEN the first frame's movement equals one formula step with `dt ≤ dt_max`: no catch-up jump.
- **AC-51 [L]** (P-03, P-07) (resize) The resize is driven through an injected viewport size, so the test runs headless.
  - GIVEN a punch running at 1920×1080, WHEN the window is resized to 2560×1440, THEN on the next frame `T` is 4 and `A_peak` is recomputed from the new height, with the punch's elapsed `t` unchanged and the offset in whole pixels.
  - GIVEN the Overworld, WHEN the window is resized from 16:9 to 21:9 and then to 4:3, THEN the footprint and dead zone are recomputed from the new fields of view each time.
- **AC-52 [L]** (P-04) (settings changed mid-replay) GIVEN a replay frozen by the Menu mid-wind-up, WHEN Faster battle animations is turned On and the Menu closes, THEN wind-ups play at `battle_speed_mult` from the next frame. WHEN instead "Speed up boss entrances" is turned On during a frozen first-encounter takeover, THEN the takeover plays at the plain-beat speed from the next frame, and the indicator turns active.
- **AC-53 [C]** (P-09) (UI never tinted; Pending: capture tool) For Battle, each faction's boss takeover, Defeat and the Victory peak, the final presented frame (HUD, a command menu, the Defeat card and damage numbers at full opacity) matches the UI layer rendered alone within ΔE 1 on every pixel where the UI is opaque. A fixture build that routes the UI through the world's tonemapper fails, as a negative control.
- **AC-54 [L]** (P-05) (menu input guard) For the command menu, target selection, the Defeat Prompt and the results screen, on the mode-time clock at `dt = 1/60`, with a test config of `input_guard = 9.5 / 60` s:
  - **During the guard:** a press of Confirm, Cancel, a direction, or a pointer click on frames 1 to 9 after the screen opens changes nothing, and each produces exactly one refusal event.
  - **After the guard:** a new press on frame 10 or later is accepted.
  - **Held inputs:** a Confirm held since before the screen opened never confirms, however long it is held. A direction held since before it opened never moves the focus, through any number of repeat intervals, until it is released and pressed again.
  - **Echoes:** OS key-repeat echo events are never presses.
  - **Pointer:** a pointer resting over a non-default button as the screen opens leaves the default focus in place. A pointer moving `pointer_switch_px − 1` px in total leaves it too. Reaching `pointer_switch_px` moves the focus to the button under it.
  - **Default focus:** in the command menu, the member's last-used command if it is available and costs no MP, otherwise Attack. In target selection, the first living target. In the Defeat Prompt, Retry. On the results screen, its continue option.
- **AC-55 [L]** (P-05) (flash coverage) Every flash-capable source in the shipped data is declared gated, reserved, exempt-by-area or exempt-by-swing, with its transitions. The sources are:
  - the victory burst and the boss flood;
  - each attack and comedy VFX;
  - Game State's retry flash, wipes and fades;
  - the Menu backdrop's open and close, the Defeat card's stamp, and the results screen's opening.

  A fixture source declared exempt whose data exceeds its exemption fails boot validation. A gated source refused by the gate plays its capped variant, whose declared frames have no general transition and no red transition, or cover less than `flash_area_min`. Every source's transitions are declared on a named clock (mode, replay or real). A dusk-flood starfield is declared exempt-by-area, and its summed area is below `flash_area_min`.
- **AC-55b [C]** (P-13) (composite frames; Pending: capture tool and flash analyser) The flash analyser runs on the final composited frames, world and UI together, of each scripted sequence in P-13 at 60 fps. Those include a boss battle's reveal and takeover; a Victory with confetti into the results screen; a Defeat, the stamp and a Retry; and a Menu opened and closed during a replay. Each sequence runs with Reduce Flashing Off and On. No one-second window holds more than `flash_rate_max` general or red flashes. With Reduce Flashing On, none holds a flash other than the reserved boss flood's.
- **AC-56 [L]** (P-06) (config validation) Fixture configs, each breaking one load rule by a clear margin (at least 0.01), end boot in a content error naming that rule:
  - `battle_speed_mult > ff_mult − 0.25`;
  - `reaction_hold > beat_min − 0.10`;
  - `reaction_hold > ko_hold`;
  - `D ≥ reaction_hold`;
  - `dt_max ≥ beat_min`;
  - `boss_retry_hold > blend_boss + boss_hold`;
  - `victory_hold < blend_victory`;
  - `defeat_hold < blend_defeat`;
  - `set_brightness_battle > set_brightness_boss`;
  - `set_brightness_victory_settle > set_brightness_victory`;
  - `set_brightness_victory < set_brightness_boss + 0.05`;
  - a capped variant with a red transition, or a reserved sequence over the limit at the largest `ff_mult`;
  - a `set_key_fill_ratio_boss` at or below a non-boss preset's ratio;
  - `flash_rate_max > 3`, or a `flash_luma_delta` or `flash_area_min` other than its constant;
  - an overworld camera failing the horizon check at 4:3.

  A config exactly on each boundary passes. Every corner of the range-chained knobs passes, and so do one config with every knob at its minimum and one with every knob at its maximum. Those two leave out the two rules the ranges cannot guarantee (the set key:fill ratio against non-boss presets, and the overworld horizon check), which are tested by their own fixtures above.
- **AC-57 [L]** (P-06) (boss intro required) GIVEN an encounter naming a boss whose sprite set has no `front` `intro`, THEN boot ends in a content error naming the set.
- **AC-58 [L]** (P-03) (pixel snap in every mode) GIVEN a sprite whose foot anchor moves 0.37 screen pixels per frame for 120 frames, in the Overworld and in Battle, THEN its quad's bottom-centre is a whole pixel on every frame, and its size never changes.

**Added in revision 4**
- **AC-59 [L]** (P-04) (old number cleared) GIVEN two consecutive beats on the same target, latched, THEN on the second beat's impact frame the first beat's number is removed, and no number is over the target from that frame until the second beat ends.
- **AC-60 [L]** (P-05) (presses before the reveal and at the replay's start)
  - GIVEN battle entry, WHEN Confirm or `fast_forward` is pressed on any frame while the wipe still covers the screen, THEN nothing is latched, nothing is submitted, and nothing carries over.
  - GIVEN a command submitted with Confirm and the key held into the replay, THEN the latch stays off for the whole replay.
  - GIVEN a new Confirm tap 5 frames after the replay starts, THEN the replay is latched.
- **AC-61 [L]** (P-06) (impact and landing data) Each of these ends boot in a content error naming the set and animation:
  - an `attack` or `defend` with no `impact_frame`, or one equal to its frame count;
  - a `knockout` with no `land_frame`, or one equal to its frame count;
  - a boss whose `intro` lasts longer than `boss_hold` at 1×;
  - a set with two move-specific animations keyed by the same move name.

  An `attack` with frame durations 1, 1, 2, 1 at 10 fps and `impact_frame` 3 gives `w_i = 0.4` s. A `knockout` with the same durations and `land_frame` 2 gives `k_i = 0.2` s.
- **AC-62 [L]** (P-04, P-05) (end-of-fight holds) GIVEN a battle won or lost on its last beat:
  - the outcome reaches Game State `victory_hold` or `defeat_hold` after the last beat ends, within one frame, and the Victory or Defeat blend has completed by then;
  - a latch set during the final replay doesn't shorten either hold;
  - a Confirm or Cancel pressed during the hold does nothing and doesn't carry into the results screen or Defeat Prompt;
  - Quit to Title during the hold cancels it, and the outcome is never reported.
- **AC-63 [L]** (P-06) (Reduce Flashing on flicker) GIVEN Camp with Reduce Flashing On, THEN the campfire flicker's luminance swing is half its swing with the setting Off, within 1e-4, on every frame.

**Added in revision 5**
- **AC-64 [P]** (P-15) (nothing compiles in play) In a windowed release export on the development PC, after Boot's warm-up, from a freshly launched export with an empty shader cache:
  - the scripted state cycle (each mode's entry; Battle, every faction's boss takeover, Victory and Defeat; Camp; Menu open and close) leaves every `Performance.PIPELINE_COMPILATIONS_*` counter unchanged;
  - no frame exceeds 33 ms (`performance.frame_time_worst_ms`).

  A fixture preset that switches an un-warmed feature makes the counters rise, as a negative control.
- **AC-65 [L]** (P-04) (outcome numbers and the round on the HUD) GIVEN the AC-14b moves resolved in one replay, THEN:
  - the HUD shows exactly the numbers in AC-14b, each over its own combatant, at its beat's end;
  - the HP, MP and status shown before each beat ends equal the previous beat's values;
  - MegaCorp's per-round MP bill and the new round number appear on the frame the round change is released, not before.
- **AC-66 [PT]** (P-16) (the anchor moment, Player Fantasy) Five first-time players play from the title into their first battle and their first boss fight, with no explanation.
  - **The first frame reads:** within 5 s of the first battle wipe opening, at least 4 of 5 can point to "my side" and "the enemies" and say they're in a fight.
  - **The first reaction lands:** at least 3 of 5 visibly react (a smile, a laugh, a comment) to the first reaction frame of their first hit.
  - **The boss reads:** at least 4 of 5 say, unprompted or when asked "what changed?", that the fight escalated or that the enemy's side took over the place.

  **It gates the first-playable milestone.** A missed threshold blocks that gate until this GDD's Player Fantasy, staging or lighting is revised and a rerun with five new players passes. It is logged as a design problem, not a bug.

**Added in revision 6**
- **AC-67 [C]** (P-09) (the squad is never tinted; Pending: capture tool) On each faction's boss takeover capture and the same stage's Battle capture, each squad member's actor pixels differ by at most ΔE 3 on average and ΔE 6 at the 95th percentile.
- **AC-68 [L]+[C]** (upright-card occlusion, pitched cameras), in the Overworld and Camp, for a sprite standing 0.5 m in front of a fixture wall:
  - **[L]** (P-03): the pure card-depth function returns, for every fixture view ray through the sprite's pixel rectangle, the view-space depth (metres) of that ray's intersection with the upright card at the foot anchor, within 1e-4 of the analytic value.
  - **[C]** (P-09; Pending: capture tool): on an Overworld capture of the fixture, every ID-pass pixel of the sprite's upper half is present in front of the wall, and every ID-pass pixel of its bottom `2` texels behind a fixture prop placed in front of its feet is absent.
- **AC-69 [UI]** (P-18) Retained screenshots of the replay indicator in its three states and of the refusal pulse on the command menu, at 1080p with keyboard and gamepad glyphs. In each, the indicator's and the pulse's text and glyphs have a WCAG contrast of at least 4.5:1 against their own backing, over Battle and over each faction's boss takeover, and the ux-designer signs the set off.

## Open Questions

| # | Question | Owner | Resolve by |
|---|---|---|---|
| 1 | **Exact sprite height (inside 48–64 texels), `battle_fov`, and each battle stage's `h_cam`, `horizon_frac` and slot depths**: set from the early technical test's captures | art-director + technical-artist | ADR-0005 Migration Step 1 |
| 2 | **Cut-out sprite shadows**: MVP uses one blob shadow per actor, with actor shadow casting off (rule 12). A shadow traced from the sprite's outline is a stretch goal that would *replace* the blob, never add to it, if Step 1 shows the shader can cast it correctly | technical-artist, art-director final call | Step 1 |
| 3 | **`fast_forward` replay speed** (`ff_mult`): proposed here, but the Input GDD gives `fast_forward`'s effect to Turn Battle and Dialogue | Turn Battle owner | Next Turn Battle GDD revision |
| 4 | **A distinct wind-up before the result**: today the wind-up and impact are one beat played after Turn Battle resolves. A separate "move chosen" moment would need a new Turn Battle signal (`action_started`) | lead-programmer + Turn Battle owner | Before the Combo System's punchline animations are designed |
| 5 | **A "miss" reaction**: Turn Battle's outcome data has no miss/evade flag, so MVP has no miss animation | game-designer + Turn Battle owner | Turn Battle revision, if misses become a mechanic |
| 5b | **Outcome grouping (Pillar 3)**: in MVP each outcome replays as its own beat with its own punch, so a cross-character combo or a multi-hit move plays as separate beats with no shared "smug combo pose". `BattleOutcome` needs a grouping and a combo / rule-trigger flag, so grouped outcomes replay as one shared beat ending in a joint pose, with one punch. The flag protects the beat's **landing hold**, never its wind-up (creative-director ruling 2 of the fifth review; ADR-0006 adds one clause) | Turn Battle owner + Combo System designer | Combo System & Codex GDD |
| 5c | ~~Battle Speed depends on `ff_mult`~~ **Resolved in revision 2.** | — | — |
| 6 | **Occupied-town and dungeon lighting** (occupation stages 1–3, the travelling party light pool): the exact stage-3 saturation and the trigger that sets a map's type belong to the Overworld GDD | art-director + Overworld designer | Overworld Exploration & Encounters GDD/ADR |
| 7 | **The four dusk flood swatches and the battle blur strength.** One swatch per faction goes into art bible §4: its hue, its chroma (`min(flood_chroma_frac × C*_signature, C*_max)`, so Terminal Cyan's is gamut-capped near C\* 21), and an L\* range at or below `flood_l_max`. Each must sit at least `flood_native_de_min` from the native sky of every boss stage of that faction; a failing stage re-authors its sky. The values come from the art director's tuning pass. Until then, AC-34's sky-lightness clause is part of its sign-off | art-director | Step 1, then the first playable |
| 8 | **Minimum actor-to-set contrast as a number**: `actor_contrast_min` is a provisional 3.0 (WCAG 1.4.11), now judged per sector (Formulas, `read_order`). The art director confirms or raises it against the Step 1 captures | art-director + ux-designer | Step 1; before the art bible's §8 Asset Standards is written |
| 9 | ~~**Rendering backend**~~ **Resolved in revision 6.** The godot-specialist observed 4.7.2 resolving to Vulkan on the development PC, against the engine reference's D3D12 default. ADR-0005 pins Vulkan, and `docs/engine-reference/godot/modules/rendering.md` needs a correction note | — | — |
| 10 | **Art bible §5–§8 are unwritten** (character design, environment, UI, asset standards). Rule 10's required-animation set (including `victory` and `land_frame`) and fallback, and the per-animation mirroring exceptions, were proposed here and need art-director confirmation | art-director | `/art-bible` completion |
| 11 | **Other-document follow-ups (revision 6).** The fifth review's gating split (ruling 6): this GDD gates on contradictions, guarantees, formulas, knobs and defective ACs; the ADRs gate on mechanism; stories gate on tools, budgets and test infrastructure.<br>**Done 2026-10-22:**<br>• Input GDD rule 3: focus follows the pointer only after `pointer_switch_px` of movement;<br>• ADR-0005 revision 2: the screen-aligned, constant-`T` sprite projection; upright-card depth; the level shift-lens camera on `PROJECTION_FRUSTUM` with the punch as extra lens shift; the sky card; a rim that excludes the outline; actors without ambient; the capture tool's build step (1c) and its own story; the ID pass's explicit `SubViewport` settings; the compile contract, its compiling-parameter list and same-config warm-up; the Vulkan pin; a uniform sink for the globals; actor shadows off; the `FlashGate` service with landing-time booking and reserved sources;<br>• ADR-0006 revision 3: snapshots at the turn and end markers, `display_resynced` and the Retry display reset, cancelling at `transition_started(BATTLE, BATTLE)`, the per-event tolerance, the knockout-keyed hold and the no-reactor hold, the speed rules of rulings 1–3 and `press_effective`, cancelling the end-of-fight hold on exit, clearing squad transients on first entry, the actor never in its own reactions, and the displayed round;<br>• art bible §2's boss row and §4's flood rule: dusk floods with a neon horizon, and swatch values at Step 1;<br>• the registry (`replay_time`, `flash_gate`);<br>• the test plan, `production/qa/test-plans/sprite-camera-presentation-test-plan.md`.<br>**Still open: the Game State GDD.** It must:<br>• route the retry flash, wipes and fades through the flash gate, declaring their transitions;<br>• open the Defeat Prompt and results screen when the Battle mode reports the outcome, after `defeat_hold` or `victory_hold`;<br>• give faction-tinted wipes the faction shape too.<br>No new announcement is needed: the Battle mode cancels on `transition_started(BATTLE, BATTLE)` and opens the gate on that row's `transition_finished(BATTLE)` | technical-director (ADRs); Game State owner | Game State: before its own stories |
| 12 | **Should the player's own command beat's landing be protected?** In MVP no beat is protected, and only wind-ups ever speed up. If playtests show players miss their own gags, the beat's landing hold could lengthen (never its wind-up) | game-designer, from playtest | First playtest with the replay in place |
| 13 | ~~**Draw-call budget, counting rule and coverage.**~~ **RESOLVED 2026-10-22 (user decision on the technical director's proposal).** 300 draw calls for all 3D passes (including `SetLight`'s cascades) + 100 for canvas/HUD, counted separately; p99 ≤ 16.6 ms and worst ≤ 33 ms; binding hardware a GTX 1080-class desktop at 1080p and Steam Deck at 1280×800; 2160p measured but not gating (AC-31, `project.yaml`, ADR-0005). Still open, not blocking AC-31: the Menu blur's cost, Overworld and Camp budgets (with the Overworld ADR), and a memory/VRAM ceiling (`memory_ceiling_mb`, set from P-14's measured peak) | technical-director | Closed (remainders tracked in ADR-0005) |
| 14 | ~~**Overworld texel-row stability**~~ **Resolved in revision 6.** Constant `T` (rule 2) means a sprite's texel rows never change height as it walks, and the anchor snap fixes its phase | — | — |
| 15 | ~~**Engine mechanisms to confirm**~~ **Moved in revision 6** to ADR-0005's Verification Required. Those items are the lens shift and the punch on `frustum_offset`, the constant-`T` quad and upright-card depth, the sky card under the lens shift, reading the glow input, manual sprite frames, flip mirroring through the shader, and which lighting parameters compile | godot-specialist + technical-artist | Step 1 |
| 16 | **The automatic replay speed-up** (deferred by the fourth review's ruling 4). MVP has none: a replay plays at the speeds the player chose, however long it is. **Trigger:** bring it back if, in the first playtest with a full enemy phase of 4+ actors, the median enemy phase at the players' own settings runs over 8 s, or players say the phases drag. It would be one more term in the plain-beat speed (ADR-0006), computed once per replay, and never applied to protected content | game-designer + ux-designer, from playtest | First playtest with a full enemy phase of 4+ actors |
| 17 | **Move-specific animations keyed by display name.** `BattleOutcome` carries `move_name`, not a move ID, so a move's own animation is looked up by its display name, with duplicates rejected at boot (rule 10). That breaks under localization or a renamed move. When ADR-0001's content migration gives moves IDs, switch the key | lead-programmer + Content Data owner | ADR-0001 move-record migration |
| 18 | ~~**Ratify the fifth review's art-direction rulings (D1–D4).**~~ **RESOLVED 2026-10-22: the user ratified all four.** D1 (dusk floods) on one condition: **every dusk sky shows some stars** (rule 6, Formulas `flood`, art bible §4). D2 (sky card), D3 (constant integer texels) and D4 (level shift-lens battle camera) are approved as written | user | Closed |
| 19 | **Sprite size steps with `T` at in-between window heights.** At 900p (`T = 2`) a sprite is 80% of its 1080p size relative to the frame. Accept it, or render the world at the nearest multiple of 360 lines and scale by whole pixels | technical-artist + art-director | Step 1 |
| 20 | **Recommended items from the fifth review, not adopted in revision 6:**<br>• a minimum on-screen time for a number when the same target is hit again quickly while latched;<br>• AccessKit labels and UI text contrast for the indicator and refusal pulse (UI Framework);<br>• effects for specials that change nothing | ux-designer + UI Framework owner | UI Framework GDD |
