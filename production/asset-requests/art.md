# Art Request List: Go back to your planet!

> Written 2026-11-04. Sources: `design/art/art-bible.md` §1-4, `design/art/asset-list.md`, `design/gdd/overworld-exploration-encounters.md` (Visual/Audio), `design/gdd/sprite-camera-presentation.md` (Visual/Audio), `data/maps/*.tscn`, and what is in `assets/` today.

**How to use this**
1. Work top to bottom: section 1 (overworld) is priority #1. The overworld has no art at all right now.
2. Save each PNG at the exact path in the table. Folders that don't exist yet are fine; create them.
3. Pixel rules for every sprite: nearest-neighbour only, 1 px outline in Outline Ink `#1A1418`, transparent background, one pixel scale (64x64 canvas = one human).
4. Animations are one horizontal strip per clip, frames left to right, all frames the same size (`walk` 4 frames of 64x64 = a 256x64 PNG).
5. When a batch is in, tell Claude "overworld squad art is in" (or similar). Claude does the import settings, sprite sets, materials and wiring, and sends you a screenshot.

---

## 0. Fixed rules (read once)

| Rule | Value |
|---|---|
| Style Anchor (paste before every character prompt) | *Pixel art game sprite, 64x64, single character, full body, clean 1-pixel dark outline (#1A1418), limited palette, flat cel shading with one highlight and one shadow tone, no anti-aliasing, no gradients, transparent background, crisp readable silhouette, Dragon Quest / Chrono Trigger era JRPG proportions (about 3 heads tall), comedic caricature of a behaviour and a prop, never of body type or ethnicity, bright storybook feel, centered, feet at bottom.* |
| Negative prompt | blurry, anti-aliased, painterly, 3D render, photorealistic, gradient shading, text, watermark, multiple characters, cropped, background scenery, mixed pixel sizes |
| Pixel density | A ~56 px tall human is ~1.7 m, so **32 px = 1 m**. Use it for textures and set pieces too, so the world and the actors share one pixel size |
| Stamp Red `#D23A2E` | **Bureaucratia only** (its enemies, posters, booths, stamps). Never on squad, civilians, or neutral UI |
| Terminal Cyan `#19C2D6` | **MegaCorp only** |
| Coin Gold `#F5C02C` | Rewards only (loot, Victory) |
| Neutral palette | Ink Navy `#1B2440`, Window Cream `#F4EAD2`, Toy Slate `#6E7A8A`, Heal Leaf `#7BD389`, Storybook Amber `#F6C37A` (light tint only) |
| Saturation | Sets and props are always **less saturated** than the characters. The set is the stage, the sprites are the actors |
| Clean-up | AI pixel art is never on a true grid: downscale with nearest-neighbour, snap to 16-24 colours, delete stray and anti-aliased pixels |

**Guardrails (user rulings, `design/narrative/narrative-bible.md` §8.3).** These are hard rules. An asset that breaks one gets redone.
- No Nazi or WWII-persecution imagery of any kind: no uniforms that look like it, no insignia, salutes, armbands, yellow stars, camps, cages or roundups.
- **No civilian is marked by anything worn**: no armbands, badges, tags or ribbons on civilians. Alien uniforms may carry badges (the Clerk's name badge is fine; user, 2026-11-04).
- No "papers, please". Booths process *forms*, never people. No ID cards, passports, visas, border or customs imagery.
- No rubble, victims, cages or violence against humans. Occupation is paperwork: posters, queues, stamps, filing cabinets.
- No food or ration queues. People queue for forms and numbers.
- No hanging banners over streets at stage 1. No crowd tableaux.
- No religion: **no Notre-Dame, no Sacré-Coeur, no church spires or crosses** in the Paris skyline. Lore (user, 2026-11-04): every church was blown out in the invasion, so they are simply gone. Draw no ruins or rubble in their place either. The Eiffel Tower is fine (daytime only; the night light show is copyrighted).
- No real brands, logos or shop names (café names are invented; no Michelin).

---

## 1. What form the environment art takes (recommendation)

The overworld code builds each map from its walk grid (1 cell = 1 m): one flat floor plane, a 1.2 m box on every blocked cell, plus coloured boxes for NPCs, posters, the camp and checkpoints (`src/overworld/overworld_map.gd`, `build_set()`). The camera is fixed, pitched 30° down, and never rotates.

**Recommendation: a "toy theatre" 2.5D set, in three layers. True 3D models come later.**

| Layer | What you make | Why |
|---|---|---|
| A. Ground textures | Tileable pixel textures at 32 px/m (64x64 = 2x2 m) | Drops straight onto the floor plane and the box tops. Cheap, easy to swap per stage |
| B. Building flats | Facades as upright pixel-art cards (PNG with transparency), standing on the blocked-cell edges, facing the camera | The camera never rotates, so a flat reads as a building. It works like the sprites: one pixel scale, crisp |
| C. Prop sprites | Small props (lamp posts, tables, booths, posters) as billboard sprites on the same 64x64 or 32x32 grid | Same pipeline as the characters, and Claude already wires sprites |

Later, optional: replace layer B with real low-poly `.glb` models (Blender or an image-to-3D tool) for true depth and lighting, which is the art bible's end goal. The flats keep their textures as the models' paint.

---

## 2. PRIORITY 1: overworld characters

### 2.1 Squad walk sprites (4 heroes)

Facings: the GDD minimum is front-3/4 (`down`) and back-3/4 (`up`), with left and right made by mirroring. Movement is free 360°, so **draw three facings: `down`, `up`, `right`**. Claude mirrors `right` into `left`. Keep the same costume and props as the battle sprites in `assets/sprites/squad/`. Idle and walk stay simple; the gags live in battle.

| Clip (file suffix) | Frames | Strip size | Notes |
|---|---|---|---|
| `ow_idle_down` | 2 | 128x64 | Breathing bob, front-3/4 |
| `ow_walk_down` | 4 | 256x64 | Contact, pass, contact, pass |
| `ow_idle_up` | 2 | 128x64 | Back-3/4. May reuse the battle idle if it reads as "walking away" |
| `ow_walk_up` | 4 | 256x64 | |
| `ow_idle_right` | 2 | 128x64 | Side view. Must survive mirroring (no text, no one-handed gag that breaks when flipped) |
| `ow_walk_right` | 4 | 256x64 | |

Paths: `assets/sprites/overworld/squad/<hero>/<hero>_<clip>.png`, where `<hero>` is `karen`, `michelin_chef`, `florida_man` or `baguette_thrower`. Example: `assets/sprites/overworld/squad/karen/karen_ow_walk_down.png`. Total: **24 strips**.

Prompt add-ons (after the Style Anchor):

| Hero | Prompt tail |
|---|---|
| Karen | *walking, [front three-quarter view facing down / seen from behind / side view facing right], middle-aged woman, dramatic asymmetric bob haircut, muted teal-grey cardigan, cream blouse, sunglasses pushed up on head, smartphone in hand, brisk indignant stride* |
| Five-Star Chef | *walking, [view], proud chef, absurdly tall white toque, cream chef's jacket, giant silver ladle carried over shoulder, chest puffed out* |
| Florida Man | *walking, [view], wild-haired man, loud tropical shirt (leaf green and amber flowers on cream), cargo shorts, flip-flops, selfie stick held up filming himself, bandaged knee, cocky swagger* |
| Baguette Thrower | *walking, [view], lanky man, striped navy-and-cream shirt, beret, scarf, enormous golden baguette resting on shoulder like a baseball bat* |

Minimum if you're short on time: `ow_idle_down` + `ow_walk_down` + `ow_walk_up` for all four (12 strips). Claude uses `down` for sides until `right` arrives.

### 2.2 Enemy symbols on the map

| ID / file | Canvas | Clips (frames) | Prompt / direction |
|---|---|---|---|
| `assets/sprites/overworld/enemies/clerk/clerk_ow_patrol_<down/up/right>.png` | 64x64 | walk 4 each | The battle Clerk walking a beat, clipboard held at chest, bored |
| `.../clerk/clerk_ow_chase_<down/up/right>.png` | 64x64 | walk 4 each | Hurried walk, clipboard thrust forward, leaning in |
| `.../clerk/clerk_ow_notice.png` | 64x64 | 3 | Front-3/4: clipboard snaps up, head turns. The "!" slip is a separate icon (2.5) |
| `.../clerk/clerk_ow_stunned.png` | 64x64 | 2 (loop) | Sitting amid scattered papers, dazed. Must read when still (Reduce Motion) |
| `.../clerk/clerk_ow_shrug.png` | 64x64 | 2 | Give-up shrug and half-turn at a safe-zone edge |
| `.../clerk/clerk_ow_deflated_<down/right>.png` | 64x64 | walk 4 each | Respawned onto a liberated street: sheepish, slumped, no clipboard flourish |
| `.../clerk/clerk_ow_counter.png` | 64x64 | idle 4 | **Permit Counter** Clerk seen behind the counter, stamping forms. Never stunned |
| `.../clerk/clerk_ow_counter_called.png` | 64x64 | 2 | "Number called" beat: looks up, points at the board |
| `.../supervisor/supervisor_ow_idle.png` | 128x128 | idle 4 | The boss standing in the boss chamber, front-3/4. Can reuse `supervisor_idle.png` if it reads on the map |

Total: 13 strips. The Clerk's shape and Stamp Red stay identical to the battle sprite (grunts are stamped from one shape; that's the joke).

### 2.3 Paris civilians

The code reads `NpcSpawn` markers. Each named NPC below already has a line in `data/maps/*.tscn`. Art bible §3: civilians are **rounder, smaller, symmetric and lower-contrast** than the squad, in neutral colours (never red or cyan).

| File stem (`assets/sprites/overworld/npcs/`) | Who (marker, map) | Prompt tail |
|---|---|---|
| `npc_cafe_owner` | Café owner sweeping torn posters (`NpcCafeOwner`, Town). Also the chapter-end bark | *round middle-aged café owner in a long apron, rolled sleeves, push broom, sweeping, mildly annoyed* |
| `npc_retired_notary` | Retired notary, grumbler (`NpcGrumbler`, Town) | *elderly man in a slightly too-formal old suit, cane, folded newspaper under arm, nostalgic frown* |
| `npc_queue_woman` | Woman in the queue (`NpcMairieQueueA`, Town) | *woman in a beige raincoat with a tote bag, standing patiently, content* |
| `npc_queue_man` | Man in the queue (`NpcMairieQueueB`, Town) | *man in a knitted cardigan holding a paper queue ticket proudly, stubborn* |
| `npc_cafe_regular` | Café regular, the "Clerks are optional" teacher (`NpcUnionRegular`, segment) | *older man with flat cap and espresso cup, leaning on a café table, knowing smirk* |
| `npc_street_sweeper` | Street sweeper (`NpcStreetSweeper`, segment) | *city street sweeper in a plain green work jacket (no logos, no badges), twig broom, wheeled bin, fed up* |
| `npc_adopter_forms` | Enthusiastic adopter: form hobbyist (generic) | *cheerful person carrying an overstuffed binder of forms, delighted* |
| `npc_adopter_tickets` | Enthusiastic adopter: queue-number collector (generic) | *person proudly holding a long strip of numbered tickets* |
| `npc_adopter_stool` | Enthusiastic adopter: queues for fun (generic) | *person sitting on a folding stool with a thermos, waiting happily* |
| `npc_civ_a` ... `npc_civ_d` | 4 generic body types (tall-thin, short-round, elderly, young adult) for palette swaps | *plain everyday Parisian clothes, neutral colours, simple shapes* |

Clips per civilian, 64x64: `_idle_down` (2, also used as the queue shuffle), `_walk_<down/up/right>` (4 each), `_pleased` (2: shrug, stretch or nod), `_grumble` (2: arms folded, head shake). The café owner and street sweeper also get `_sweep` (4). Minimum for named NPCs: `_idle_down` plus `_pleased` or `_grumble` (their `liberated_role` in the map data says which). ~50 strips for everything; ~15 for the minimum.

### 2.4 Overworld icons and markers (pixel, neutral UI grammar)

| File (`assets/ui/overworld/`) | Size | Frames | Direction |
|---|---|---|---|
| `notice_slip.png` | 24x32 | 1 | Cream paper slip, ink "!", rectangle shape (Bureaucratia's notice). Plus `notice_tag.png` 12x16, the small leftover "!" |
| `stun_slips.png` | 16x16 | 4 | Small form slips orbiting a head |
| `paper_trail.png` | 16x16 | 4 | Loose sheets fluttering behind a chasing Clerk |
| `interact_pip.png` | 32x24 | 1 | Cream rounded rectangle, Outline Ink border (the button glyph sits beside it) |
| `kind_talk.png`, `kind_camp.png`, `kind_hand.png`, `kind_ticket.png` | 16x16 each | 1 | Speech bubble; cup; hand; ticket stub |
| `exit_chevron.png` | 32x32 | 1 | Cream painted chevron decal for the ground; `exit_chevron_bright.png` for the critical path |
| `beacon_lantern.png` | 32x64 | 4 | Lantern banner on a pole, warm glow flicker (navigation beacon, rule 19) |
| `closed_glyph.png` | 16x16 | 1 | Shape-based "closed" sign for a booth (not colour-only) |
| `note_glyph.png` | 12x12 | 1 | "♪" glyph for Reduce Motion (aliens playing) |
| `payoff_card_frame.png` | 9-slice 48x48 | 1 | Small cream card for "Street cleared: Rue des Tampons" |

---

## 3. PRIORITY 2: Paris environment

Ground textures: seamless, 64x64 (2x2 m), top-down, pixel art. Prompt base: *seamless tileable pixel art ground texture, 64x64, top-down orthographic, limited palette, no anti-aliasing, low contrast, soft storybook colours, no text,* + the line below.

| File (`assets/environment/paris/ground/`) | Where | Prompt tail |
|---|---|---|
| `tex_cobble.png` | Town and segment streets | *warm ochre Paris cobblestones, rounded stones, golden-hour palette* |
| `tex_sidewalk.png` | Pavements | *pale limestone sidewalk slabs, slight cracks* |
| `tex_cafe_paving.png` | **Safe zones** (café terrace): must look clearly different so the boundary reads | *small hexagonal terracotta tiles, café terrace* |
| `tex_curb.png` | 64x16 edge strip | *granite curb edge* |
| `tex_ministry_marble.png` | Dungeon halls | *cool grey-white marble floor tiles, polished, institutional* |
| `tex_office_carpet.png` | Dungeon offices | *flat grey-blue office carpet tiles with faint grid* |
| `tex_boss_carpet.png` | Boss chamber | *formal carpet, deep muted red with cream border, mid-saturation* (Bureaucratia ground) |
| `tex_wall_top.png` | Tops of blocked-cell boxes | *dark slate roof or wall-top texture* |

Building flats and big set pieces (32 px/m, transparent PNG, front orthographic, prompt base: *pixel art building facade, flat front orthographic view, toy diorama style, chunky simple shapes, slightly wobbly handmade verticals, limited palette, 1px dark outline, transparent background, no text, no people,* + tail):

| File (`assets/environment/paris/flats/`) | Size | Prompt tail |
|---|---|---|
| `facade_haussmann_a.png`, `_b.png`, `_c.png` | 128x224 | *Haussmann apartment building, cream limestone, wrought-iron balconies, grey mansard roof with dormers, crooked chimney* (vary windows, shutters, doors) |
| `facade_cafe.png` | 128x160 | **The camp café.** *ground-floor café with striped awning, warm lit windows, chalkboard sign showing a coffee cup, terrace tables* (invented name or none) |
| `facade_mairie.png` | 192x224 | *grand town-hall facade, clock, wide steps, columns* (no flag, no crest) |
| `facade_ministry.png` | 192x256 | Dungeon entrance seen from the segment: *imposing office block grafted onto a Paris building, rectangular filing-cabinet extensions, stamp-red trim at mid saturation* |
| `facade_shop_a.png`, `_b.png` | 96x128 | *boulangerie / bookshop ground floor, invented shop sign shapes, no readable text* |
| `wall_interior_ministry.png` | 64x64 tile | *institutional interior wall, wainscot panels, cream and grey* |
| `wall_filing_cabinets.png` | 64x64 tile | *wall of grey filing cabinets with red drawer labels* |
| `skyline_paris.png` | 1280x180 | *distant Paris skyline silhouette strip with the Eiffel Tower, mansard roofs, chimneys, pale blue-grey, daytime* (**no churches or domes with crosses**) |
| `skyline_paris_saturated.png` | 1280x180 | Same, but *the Eiffel Tower clad in stacked in-trays and filing cabinets, red paper banners*. Claude swaps it at stage 3; the liberated set restores the plain one |
| `sky_paris_golden.png` | 640x360 | *golden-hour sky gradient, soft warm clouds, no buildings, painted* (the sky card; stage tints are done in-engine) |

Props (billboard sprites, transparent PNG; prompt base: *pixel art game prop, single object, 1px #1A1418 outline, flat colours, transparent background,* + tail). Path `assets/environment/paris/props/`.

| File | Size | Notes / prompt tail |
|---|---|---|
| `prop_lamp_post.png` | 32x96 | *Paris street lamp, dark green iron*. Also frames map exits |
| `prop_cafe_table.png`, `prop_cafe_chair.png` | 32x32 | *small round bistro table / wicker chair* |
| `prop_bench.png`, `prop_tree_grate.png` | 64x48 / 64x96 | *park bench / plane tree in a round iron grate* |
| `prop_kiosk.png` | 64x96 | *green newspaper kiosk, no readable text* |
| `prop_ticket_machine.png` | 32x48 | **Gag "queue-number machine"** (Town, `gag_ticket_machine`). Stays after liberation |
| `prop_queue_stanchion.png` | 32x32 | *red-rope queue stanchion post*. Plus `prop_queue_rope.png` 32x8 (tiles) |
| `prop_queue_barrier.png` | 64x32 | *metal crowd-control barrier with a red-and-cream stripe* |
| `prop_checkpoint_booth.png` | 64x96 | *small square booth with a stamp-shaped roof sign, rubber stamp on the counter*. Plus `prop_boom_closed.png` / `prop_boom_open.png` 96x32 (boom lift is a 3D tween, so one frame each) |
| `prop_tape.png` | 64x16 | *barrier tape, cream and red diagonal stripes* (the "FERMÉ POUR RESTRUCTURATION" tape; the text is drawn by the game) |
| `prop_filing_cabinet.png`, `prop_filing_cabinet_tipped.png` | 32x48 / 48x32 | Gag `gag_archive_courtyard`: upright, then tipped with forms sliding out |
| `prop_archive_gate.png` | 64x64 | *iron courtyard gate, chained shut, paper tag* |
| `prop_stamp_rack.png`, `prop_stamp_rack_spilled.png` | 32x32 | Gag `gag_stamp_cupboard` |
| `prop_in_tray_poster.png` | 32x32 | *wire in-tray with a rolled-up poster sticking out* (the "tell" markers) |
| `prop_counter.png` | 96x64 | **Permit Counter**: *office counter with a ticket dispenser and a "NOW SERVING" display board* (numbers drawn by the game) |
| `prop_door_staff.png`, `prop_door_stamps.png` | 32x64 | Locked doors (BackStairs, StampCupboardDoor) |
| `prop_pneumatic_tube.png` | 32x64 tile | Stage 3 dressing |
| `prop_desk_typewriter.png` | 64x48 | Dungeon dressing |
| `prop_coffee_corner.png` | 64x64 | **Pre-dungeon camp** in the Ministry: *staff coffee machine on a side table with a cup sign*. The cup sign marks every camp |
| `prop_boss_desk.png` | 128x96 | Boss chamber: *enormous desk with stacked forms and a giant rubber stamp* |
| `prop_stamp_statue.png` | 64x128 | Boss chamber: *giant rubber-stamp statue* |

Faction dressing (posters and attachments). These are what liberation removes, so make each a **separate** PNG. Path `assets/environment/paris/dressing/`.

| File | Size | Stage | Direction |
|---|---|---|---|
| `poster_permit.png` | 32x48 | 1+ | Propaganda-parody poster: big rubber-stamp shape, bold blocks, Stamp Red and cream. **No real text** (the game shows the text on interact); fake block lettering only |
| `poster_decree.png` | 48x64 | 1+ | Official notice board, dense fake print, red stamp in the corner (decree gags) |
| `poster_queue.png` | 32x48 | 1+ | Arrow-and-queue pictogram poster |
| `flyer_scatter.png` | 32x32 | 1 | Loose flyers on the ground |
| `sign_stamp.png` | 32x64 | 1+ | Stamp-shaped street sign bolted on a pole |
| `awning_red_stripe.png` | 128x32 | 2+ | Red-striped awning to lay over facades |
| `facade_filing_box.png` | 64x64 | 2+ | Filing-box extension bolted onto a facade |
| `forms_drifting.png` | 16x16, 4 frames | 3 | Drifting paper (ambient particle; stilled by Reduce Motion) |
| `poster_peel.png` | 32x48, 4 frames | liberation | Poster peeling off and fluttering as cream paper |

---

## 4. PRIORITY 3: battle and UI gaps

Most battle art is in (`assets/sprites/`, `assets/vfx/`, `assets/backgrounds/`, `assets/icons/`). This is only what is genuinely missing.

| # | Asset | Path | Spec | Why |
|---|---|---|---|---|
| 1 | Drone, Middle Manager, CEO `defend` | `assets/sprites/enemies/<id>/<id>_defend.png` | 2 frames, 64x64 (CEO 128x128) | Today `defend` falls back to the idle loop |
| 2 | Drone `hurt` fix at the source | SpriteForge project | — | The fixed hurt frame (no legs) is only in `assets/`; a re-export brings the legs back |
| 3 | Supervisor and CEO `intro` pose | `.../supervisor/supervisor_intro.png`, `.../ceo/ceo_intro.png` | 4 frames, 128x128, at most ~1 s | The boss entrance holds on an intro pose |
| 4 | Split battle backdrops: set without sky | `assets/backgrounds/bg_battle_bureaucratia_set.png` (+ megacorp) | 640x360, **transparent sky** | The boss dusk flood recolours the sky card; a painted-in sky can't change (stories 036/038) |
| 5 | Battle sky cards | `assets/backgrounds/sky_battle_bureaucratia.png` (+ megacorp) | 640x360, sky only | Same reason |
| 6 | Boss-stage faction shape pieces | `assets/environment/battle/shape_bureaucratia_<a/b/c>.png` | 3 flats, ~128x192 each, transparent | Story 041 is blocked: the boss stage needs faction-shape set pieces (giant stamps, filing towers; MegaCorp: glass wedges, growth arrows) |
| 7 | Defeat card | `assets/ui/defeat_card.png` | 256x96 | A rubber-stamped "CLAIM DENIED"-style card in **neutral navy**, never faction red. Text is drawn by the game |
| 8 | Victory confetti | `assets/vfx/confetti.png` | 8x8, 4 frames, 3 colour variants | Cream and Coin Gold flakes |
| 9 | Purple goo pile | `assets/vfx/goo_pile.png` | 128x64, 4 frames | A finished alien boss "explodes into a pile of purple goo". Goo only, no gore |
| 10 | UI window skin | `assets/ui/window_frame.png` | 9-slice 48x48 | Dragon Quest-style navy window, double cream border, chunky pixel corners |
| 11 | Menu cursor | `assets/ui/cursor_hand.png` | 16x16, 2 frames | Pointing hand, cream |
| 12 | Reward icons | `assets/ui/icon_xp.png`, `icon_money.png` | 16x16 | Money uses Coin Gold (reward) |
| 13 | Faction rule badges | `assets/ui/rule_permit.png`, `rule_invoice.png` | 32x32 | Bureaucratia: rectangular form with stamp slots. MegaCorp: angled invoice ticker |
| 14 | Pixel font | `assets/fonts/` | TTF/OTF, **OFL licence** | Pick a free OFL pixel font with é/è/à/ç (French words). Claude can shortlist |
| 15 | Title screen | `assets/ui/title_logo.png` + `assets/backgrounds/bg_title.png` | logo 512x160 transparent; bg 640x360 | Logo text waits on the title decision (writing.md, D-1). Bg: *box-art toy diorama of golden-hour Paris rooftops, tiny squad silhouettes, warm* |
| 16 | Camp backdrop | `assets/backgrounds/bg_camp_cafe.png` | 640x360 | *Night interior of a cosy Paris café, warm lamp and candle light, empty tables*, lowest contrast. Camp has no scene today |
| 17 | Squad portraits | `assets/portraits/<hero>_portrait.png` | 96x96, front-facing | For dialogue name cards. Low priority (the cell itself has no portrait) |

### 4.1 Recruits (battle sets; added 2026-11-04)

Six recruits beyond the four (`design/narrative/recruits.md`). Today each one borrows a starter's strips as a flat recoloured silhouette (`is_placeholder` in its sprite set). The Street Mime (Paris) and the Rush-Hour Commuter (London) can already join, so they come first. Same spec as the four: back-facing, 64x64 frames, one horizontal strip per clip at `assets/sprites/squad/<id>/<id>_<clip>.png`. Clips: `idle` (4), `attack` (4), `defend` (2), `hurt` (2), `ko` (3), `victory` (4), `special` (6), plus a `base` still. Replace the PNGs in place; Claude then clears `is_placeholder` and gives each special its own strip if you draw two.

| # | `<id>` | Recruit | Prompt (after the Style Anchor) | Silhouette must read as |
|---|---|---|---|---|
| R1 | `street_mime` | Street Mime (Paris) | *street mime in a striped shirt, white gloves, braces and a beret-free bare head, palms pressed flat on an invisible wall, exaggerated pose, no face paint beyond a simple white mask* | Flat palms on a wall nobody can see |
| R2 | `rush_hour_commuter` | Rush-Hour Commuter (London) | *office commuter in a grey raincoat, long black umbrella held like a fencing foil, paper coffee cup in the other hand, mid-stride, harried* | The umbrella lunge |
| R3 | `infomercial_host` | Infomercial Host (USA) | *overexcited TV salesman in a loud blazer, headset microphone, holding up a gadget with both hands, huge grin, mid-pitch* | Arms up presenting a product |
| R4 | `boxing_kangaroo` | Boxing Kangaroo (Sydney) | *kangaroo wearing oversized red boxing gloves and a sweatband, boxing stance on its tail* | The gloves (art bible §1) |
| R5 | `goalie` | The Goalie (Toronto) | *ice hockey goalie in huge leg pads, catching glove and plain white mask (no team logos), wide blocking crouch* | The pads, filling the gap |
| R6 | `fitness_instructor` | Fitness Instructor (Mexico City) | *aerobics instructor in a bright tracksuit and headband, whistle in mouth, stopwatch raised, mid-jumping-jack* | Whistle and stopwatch, mid-jump |

Guardrails as section 0: no national flags, team logos or national dress; the joke is the behaviour and the prop.

---

### 4.2 Influencia enemies and backdrops (Chapter 3, Sydney; added 2026-11-04)

Chapter 3 plays today on stand-ins: each Influencia enemy is a MegaCorp enemy's strips recoloured Feed Magenta (`tools/art/influencia_placeholder_sprites.gd`, `is_placeholder` in its sprite set), and the two backdrops are painted by `tools/art/influencia_backdrops.gd`. Same spec as the MegaCorp enemies: front-facing, one horizontal strip per clip at `assets/sprites/enemies/<id>/<id>_<clip>.png`, clips `idle` `attack` `hurt` `ko` and a `base` still (the boss adds `special`, its intro). Faction rule: Feed Magenta `#E83E9C` and the circle shape belong to Influencia only.

| # | `<id>` / file | What | Prompt (after the Style Anchor) | Silhouette must read as |
|---|---|---|---|---|
| I1 | `micro_influencer` | Micro-Influencer (regular) | *alien influencer with a round head, phone on a selfie stick held high, duck-face pout, magenta outfit with circle motifs, posing* | Selfie stick up, posing |
| I2 | `ring_light` | Ring Light (regular, also the overworld patrol) | *floating alien ring light, a glowing circular lamp on spindly tripod legs, one camera eye in the middle, magenta trim* | A bright hoop of light |
| I3 | `mega_influencer` | Mega-Influencer (boss) | *towering alien mega-influencer in a sequinned magenta suit, giant ring light halo behind its head, arms spread for the camera, verified-badge pin* | Arms spread inside a halo |
| I4 | `bg_battle_influencia.png` | Battle backdrop, 640x360 | *sunny harbour beach with an arched steel bridge on the horizon, sea, sand, palm trees, floating magenta notification bubbles, two magenta billboards with a circle logo, no text, no real brands* | Bright, magenta accents |
| I5 | `bg_battle_influencia_boss.png` | Boss backdrop, 640x360 | *the same harbour at a magenta sunset, a giant glowing ring light hanging in the sky over the bridge* | The sky ring |

Guardrails as section 0: no real platforms, logos or brands; no real influencers.

---

## 5. Later (not needed for Chapter 1 to play)

| Asset | Note |
|---|---|
| Liberated Paris variants | Mostly free: the game removes the dressing layer and restores the golden light. Only extras: `npc_*_queue_mairie` idle (civilians queueing at the mairie), a warm sun-patch decal 64x64 |
| Rat Catchers (human bounty hunters) | Battle set (back of a scruffy gang, no uniforms, no armbands) + overworld walk. Waits on writing D-10 |
| MegaCorp overworld region | Chapter 2. Needs the city decision (writing.md D-7), then the same list as sections 2-3 in wedge shapes and Terminal Cyan |
| True 3D low-poly sets | `.glb` per building, once the flats prove the layout |
| Influencia overworld region | Chapter 3 (Sydney) plays on the London-shaped maps with procedural harbour and Content House surfaces (set styles 4 and 5). Same list as sections 2-3 in circle shapes and Feed Magenta |
| Liberty-7 | Not yet in the campaign |

## 6. Priority order (one line each)

1. Squad overworld minimum (2.1 minimum, 12 strips).
2. Ground textures `tex_cobble`, `tex_sidewalk`, `tex_cafe_paving`, `tex_ministry_marble`.
3. Clerk patrol, chase and notice (2.2), plus `notice_slip` and `interact_pip` + kind icons.
4. Facades: 3 Haussmann, the café, the mairie, the Ministry, and `skyline_paris` + `sky_paris_golden`.
5. Named NPC minimum (6 named) and the core props: lamp post, café table, queue stanchion, booth, boom, tape, counter, coffee corner.
6. Faction dressing (posters, signs, awnings) and the gag props.
7. Remaining squad facings, Clerk stun/shrug/deflated, generic civilians and adopters.
8. Battle/UI gaps 1-9, then 10-17.
9. Section 5.
