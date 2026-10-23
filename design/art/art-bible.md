# Art Bible: Go back to your planet!

> **Status**: Draft
> **Owned By**: art-director
> **Last Updated**: 2026-10-22 (§2 boss row and §4 dusk flood swatches, per the Sprite & Camera Presentation GDD revision 6, ruling D1; provisional until the user ratifies D1–D4, GDD Open Question 18)
> **Art Director Sign-Off (AD-ART-BIBLE)**: SKIPPED 2026-10-13 — lean mode

`/art-bible` writes these nine sections in this order and replaces each
section's `[To be designed]` line as that section is approved. A section still
holding its placeholder is incomplete; a later run fills only those.

## 1. Visual Identity Statement

> **The Visual Rule:** *Paint the rules in light and color; tell the jokes in pixels; and never let one hide the other.*

The look is **pixel-art sprite characters standing inside lit, low-poly 3D toy dioramas**: what you'd get if the Dave the Diver team made a Dragon Quest game. That means bright, staged fantasy-adventure, populated by a squad of misfits who are funny the instant they appear. The rule above breaks every tie. Lighting, color and big readable shapes carry the **information**: which faction, which rule, whose turn, what state. Frame-by-frame sprite animation carries the **comedy**. If a gag animation obscures a rule, or a rule indicator flattens a gag, the asset fails.

### Principle 1: The Silhouette Is the Punchline
*Serves: Pillar 1 (The Joke Is the Mechanic), Pillar 3 (Misfits Make the Combo)*

Every recruit and every alien must read as a joke from a black-fill silhouette at battle-camera distance: the Baguette Thrower's loaf, Karen's haircut-and-pointing-finger pose, the kangaroo's gloves. Toriyama-style economy wins: a few bold shapes, one oversized prop, a clear pose. Because the joke is the mechanic, the silhouette also tells the player what the character *does*. The prop is the weapon, and the pose is the ability. Detail is spent on **reaction frames** (the huge telegraphed wind-up, the defeated slump, the smug combo pose), not on costume trim. The squad should look gloriously mismatched when lined up. That clash is the visual promise of Pillar 3. Caricature targets *behaviors, archetypes and props*, never body or ethnic features. We exaggerate what someone does, not who they are.

**Design test:** When it's ambiguous whether to add detail or push the shape, push the pose or prop. If two characters are confusable in silhouette, redesign one before adding any detail.

### Principle 2: The Diorama Is the Stage; the Sprites Are the Actors
*Serves: Pillar 4 (Readable in One Turn)*

The 3D world is a handcrafted toy set: chunky low-poly forms, simple materials, warm storybook light, soft tilt-shift depth falloff. Its job is to give each region its mood and then step back. The sprites own the highest contrast, the crispest edges and the most saturated accents on screen. The eye goes to the actors first, the rule indicators second, the set last. That hierarchy is how a new player reads a fight in one turn. The stage stays calm so the jokes and rule-states can be loud in front of it.

**Design test:** When an environment element competes with a character or rule-state indicator for saturation, contrast or motion, the environment yields.

### Principle 3: Every Faction Owns One Color, and That Color Means Its Rule
*Serves: Pillar 2 (Nobody Is Right), Pillar 4 (Readable in One Turn)*

Each alien civilization gets one signature color: Bureaucratia stamp-red, with Influencia and MegaCorp each assigned their own in Section 4. That color saturates its diorama, its propaganda posters, its enemy palette, and **the UI for its battle rule**: the red APPROVED/DENIED stamp, the attention meter, the per-turn invoice. The player learns "this color = this rule" without a tutorial line. The squad and neutral UI never borrow a faction color, so the meaning stays clean. Helldivers-style, every faction gets the same lavish propaganda-poster parody, its own best-looking region and its own beauty shot. No faction is coded as the obvious villain through uglier art. Visually, nobody is right. Faction color is always paired with a matching **shape or icon** (stamp outline, eye glyph, barcode) so the meaning survives for colorblind players.

**Design test:** When a color choice is ambiguous, a faction's signature color may appear only if it's telling the player something about that faction or its rule. Otherwise, use the neutral palette.

### Production Notes (not decisions; for discussion)

- **Sprite resolution class:** One fixed character height (~48–64 px for humanoids; large aliens as clean multiples) at one shared pixels-per-unit across *all* sprites, nearest-neighbor filtering, no sub-pixel rotation or scaling of pixel art. Mixed pixel scales are the #1 way HD-2D looks cheap. Lower resolution also means fewer pixels to animate per frame, which is where a solo dev's hours go.
- **What stays 3D vs pixel:** Environments, props, lighting, shadows and most VFX scaffolding (particles, decals, screen flashes) stay 3D/shader, cheap to reuse. Characters, enemies, rule-state icons and comedy VFX (stamps, "Gone Viral" hearts) are pixel art. Pixel budget goes to actors, not tiles.
- **Camera vs sprite facings:** A free third-person battle camera multiplies sprite directions. Constraining it to a fixed arc (party from behind-3/4, enemies front-3/4) means ~2 facings per character, mirrored where possible, roughly halving animation workload. **Decided 2026-10-13 (user): fixed battle camera, Chrono Trigger / Dragon Quest style.** No free camera rotation in battle, so sprites are authored for the fixed arc (~2 facings per character, mirrored where possible).

## 2. Mood & Atmosphere

Every state has its own lighting signature, so a player glancing at the screen knows where they are before reading anything (Pillar 4). Warm storybook light is home base. The further a state is from the player's control, the more the light cools, flattens, or is taken over by a faction.

| State | Emotional target | Lighting | Mood-carrying element | Descriptors | Energy (1–5) |
|---|---|---|---|---|---|
| Overworld | Curiosity, mischief | Warm golden hour, soft contrast, long shadows | Tilt-shift blur at diorama edges ("a toy table") | cozy, wandering, miniature, sunny | 2 |
| Occupied town | Absurd oppression | Faction light logic over a warm base; flatter contrast | Faction posters and banners multiplying along streets | smothered, petty, over-signed, uneasy | 3 |
| Dungeon | Comic dread | Cool ambient, one warm pool around the party, high contrast | A light pool that travels with the squad | cramped, echoing, bureaucratic-gothic | 3 |
| Battle | Focused play | Neutral key light on sprites; background dimmed 30% and blurred | Rim light on every combatant | crisp, staged, readable, punchy | 4 |
| Boss battle | Escalation | The sky falls into a deep **dusk** in the faction's hue, and faction light takes over the set and the fill, with the hardest set contrast in the game (a low-energy fill; the set light keeps its Battle direction). The actors keep their neutral key and rim, so the squad reads light against the dark and still reads as itself | The sky card floods with the faction's **dusk flood swatch** (§4): its signature hue at mid-saturation (at most ~65% of the signature chroma, lower where dusk can't hold it), L\* 35 or darker, keeping its gradient and clouds, with a **neon horizon** band glowing lighter in the same hue. Clearly different from the planet's own sky. Full signature saturation stays reserved for the actors and rule UI | operatic, overbearing, ridiculous | 5 |
| Camp | Belonging | Night firelight, lowest contrast | Campfire flicker on the sprites | warm, intimate, loose, funny | 1 |
| Victory | Release | White-warm burst settling back to golden hour | Cream confetti and the squad's fanfare poses | triumphant, silly, bright | 4 |
| Defeat | "Try again, you learned something" | Desaturated, single overhead spotlight | A rubber-stamped "CLAIM DENIED"-style card (neutral navy, not faction red) | brief, wry, instructive, never cruel | 2 |
| Menus | Calm control | Frozen, blurred diorama behind flat UI | Navy and cream Dragon Quest-style windows | orderly, quiet, legible | 1 |

**Notes.** Defeat must be fast and gentle, never punishing: its card is a joke, not a death screen. Battle uses a neutral key light on purpose, so faction color in enemies and rule UI never competes with scene lighting.

**Occupation gradient.** As a faction's influence grows, a region moves through four stages. At every stage, environment saturation stays below sprite saturation, so Principle 2's read order holds.

| Stage | Light | Faction color in the set | Geometry |
|---|---|---|---|
| 0 Free | Native region light | None | Native shapes |
| 1 Contested | Native light with a small faction-tinted fill | Posters, flyers, one banner per street | Faction props start appearing |
| 2 Occupied | ~40% faction fill. Bureaucratia: flat office fluorescent. Influencia: ring-light pink. MegaCorp: cyan neon dusk. Liberty-7: blue-white stadium-floodlit parade noon with firework flashes | Awnings, facades, street furniture | Faction shapes attached to buildings |
| 3 Saturated | Faction light dominates; shadows flatten | Large surfaces at mid-saturation (full saturation reserved for enemies and rule UI) | Faction geometry replaces skyline landmarks |

Liberation runs the gradient in reverse. The return of golden-hour light is the reward.

## 3. Shape Language

**Silhouette philosophy (Principle 1, Pillar 4).** One defining trait per archetype: one oversized prop, one pose. Test: fill the sprite solid black at 32 px. If its role isn't readable, cut detail and enlarge the prop. Detail belongs in reaction frames, not the idle silhouette. Exaggeration goes on props, posture and behavior, never on body type or ethnic features.

**Faction shape vocabularies (Principle 3, Pillar 2).** Each faction owns one base shape. It repeats across its enemies, architecture, posters and rule UI, and it doubles as the colorblind backup for faction color.

| Group | Base shape | Vocabulary | Comedy logic |
|---|---|---|---|
| Squad / civilians | Organic, lumpy, asymmetric | Patched coats, mismatched props, irregular outlines | Misfits don't match (Pillar 3) |
| Bureaucratia | Square / rectangle | Boxes, stacked files, stamps, queue barriers, grids | Stiff, stackable, red tape you can see |
| Influencia | Circle | Ring lights, notification dots, bubbles, round billboards, domes | Smooth, glossy, endlessly loopable |
| MegaCorp | Wedge / triangle | Growth arrows, angled glass slabs, sharp collars, extruded towers | Aggressive, upward, pointy invoices |
| Liberty-7 | Star | Stars, shields, flagpoles, epaulettes, monument pyramids | Puffed-up chests, everything at "salute" |

Every faction's vocabulary gets equal parody density (Pillar 2). No faction is drawn as the "reasonable" one.

**Hero vs. supporting shapes (Principles 1 and 2).**
- **Squad heroes:** one strong diagonal, asymmetry, the biggest prop on screen, the highest-contrast outline.
- **Civilians:** rounder, smaller, symmetric, lower-contrast palette. They read as audience, not actors.
- **Faction grunts:** identical silhouettes stamped from the faction shape. The conformity is the joke, and their sameness makes the squad's oddness pop.
- **Bosses:** the faction shape scaled to absurdity, e.g. a Bureaucratia filing-cabinet tower or an Influencia selfie-moon.

**Environment geometry (Principle 2).** Chunky low-poly sets built like toy blocks: thick, bevel-free, slightly wobbly verticals so they feel handmade. Free regions use native shapes (Paris: mansard roofs, soft arches, crooked chimneys). Occupation bolts faction geometry onto them, so a skyline's silhouette shows who controls it. Sets avoid thin, high-frequency detail that would fight the sprites.

**UI shape grammar (Pillar 4, Principle 3).**
- **Neutral / squad UI:** Dragon Quest-style rounded rectangles with a double cream border and chunky pixel corners. This is the "safe" shape.
- **Faction rule UI takes that faction's shape:** Bureaucratia's Approval meter is a rectangular form with stamp slots; Influencia's attention meter is a circular ring with a count bubble; MegaCorp's billing is an angled invoice ticker; Liberty-7 uses star-badge pips. If it's shaped like a faction, it's a faction rule.
- **Quirk states:** torn-edge sticker tags tilted a few degrees, in the human/organic grammar, so they never read as faction UI.
- **Combo punchlines:** full-width title-card banners, the one UI element allowed to break the window frame.

## 4. Color System

**Primary palette.**

| Name | Hex | Role |
|---|---|---|
| Stamp Red | #D23A2E | Bureaucratia only (fixed). Lifted slightly from pure stamp red so it doesn't go black under protanopia |
| Ink Navy | #1B2440 | UI windows, deep night shadow, neutral base |
| Window Cream | #F4EAD2 | UI text and borders, paper, highlights |
| Storybook Amber | #F6C37A | Key-light tint only; never a surface or UI color |
| Toy Slate | #6E7A8A | Environment mid-tone: stone, roofs, pavement |
| Outline Ink | #1A1418 | Sprite outlines and darkest value; reserved for actors |
| Heal Leaf | #7BD389 | Healing and restoration |
| Coin Gold | #F5C02C | Rewards only (loot, victory): the classic RPG payoff |

**Faction signatures.** Faction colors are separated by lightness band or by how they shift under color-vision deficiency, so they stay apart even when hue fails.

| Faction | Name | Hex | Lightness | Rationale |
|---|---|---|---|---|
| Bureaucratia | Stamp Red | #D23A2E | Mid-dark | Ink, rejection |
| Influencia | Feed Magenta | #E83E9C | Mid | Notification and like-heart hot pink; attention bait |
| MegaCorp | Terminal Cyan | #19C2D6 | Light | Cold neon, screens, corporate cyberpunk |
| Liberty-7 | Anthem Blue | #2F5BEA | Mid-dark | The flag's other color: loud, saturated, sure of itself |

Stamp Red and Anthem Blue share a lightness band but stay apart: under protanopia/deuteranopia red turns olive while blue stays blue, and under tritanopia red stays red while blue shifts teal. The squad/neutral palette (navy, cream, slate, leaf, gold) never uses the four faction colors. Liberty-7 UI elements drawn on navy windows get a cream outline, because Anthem Blue shares a hue family with Ink Navy.

**Dusk flood swatches (boss takeover).** Each faction has exactly one flood swatch, used for every one of its boss stages and never adjusted per stage. Its rule (Sprite & Camera Presentation GDD, Formulas `flood`):
- **Hue:** the faction's signature hue.
- **Chroma:** `min(0.65 × signature chroma, the largest chroma sRGB can show at the swatch's L* midpoint and hue)`. Terminal Cyan is gamut-capped near C\* 21 at dusk, so its lavishness comes from the gradient and the neon horizon, not chroma.
- **Lightness:** an L\* range at or below 35 (deep dusk). Only the neon horizon band may glow lighter, up to 15 L\* above the range, in the same hue.
- **Stars (user condition on D1, 2026-10-22):** every dusk sky shows some stars: small, sparse points in the upper sky, clear of the neon horizon band. They are sky detail, not set lights, and follow the GDD's star rule (Formulas `flood`) for size (one texel), peak lightness (L* ≤ 80) and twinkle.
- **Distance from the stage:** at least ΔE2000 15 from the native sky of every boss stage of that faction. A stage that fails re-authors its own sky; the swatch never moves.

| Faction | Hue | Flood chroma | L\* range | Status |
|---|---|---|---|---|
| Bureaucratia | 35.9° (Stamp Red) | C\* 46.9 (e.g. #81271E at L\* 30) | ≤ 35 | Provisional; values set in the Step 1 capture tuning pass |
| Influencia | Feed Magenta's | 0.65 × signature, gamut-capped | ≤ 35 | To tune at Step 1 |
| MegaCorp | 213.5° (Terminal Cyan) | C\* 20.5, gamut-capped (quoted at its L\*_mid of 30) | ≤ 35 | Provisional; values set in the Step 1 capture tuning pass |
| Liberty-7 | 295.6° (Anthem Blue) | C\* 54.9 at L\* 30 | ≤ 35 | To tune at Step 1 |

**Semantic usage.** All semantic colors are neutral. Faction color means "a rule", never "a result".

| Meaning | Treatment | Why |
|---|---|---|
| Damage | Chalk-white numbers, Outline Ink border, impact burst, screen shake | Red belongs to Bureaucratia; motion carries the hurt |
| Critical | Larger cream numbers with a jagged frame | Size beats hue for emphasis |
| Heal | Heal Leaf with a "+" glyph and rising motion | Green means growth, universally learned |
| Buff | Target brightens and saturates slightly; cream up-chevron | Adding something reads as adding light |
| Debuff | Target desaturates toward Bruise Grey #8C8798; down-chevron | Taking something away reads as draining color |
| Quirk states | Cream sticker tag plus a unique ink icon: Complained (scribble speech bubble), Unionized (linked hands), Gone Viral (share-arrow burst), Notarized (navy wax seal, deliberately not red) | One family look, told apart by icon |
| Combo | Cream-and-navy title card; each participant's portrait in their own sprite colors | The misfits' mismatch is the color story (Pillar 3) |
| Reward | Coin Gold #F5C02C with sparkle and coin/item glyph; lightest band | The classic RPG payoff, shown only in loot and victory moments |

**Region temperature rules.** Each region has a native light temperature, which occupation pushes toward the faction's light (Section 2).
- **Paris:** warm golden-hour amber, ochre stone.
- **USA:** high-noon neutral-warm, hard shadows.
- **UK:** overcast cool grey-green, soft diffuse light.
- **Australia:** hot white sun; outback earth pushed ochre-orange and kept below Stamp Red's saturation.
- **Canada:** crisp cool blue-white.

No region's native ground or sky may match a faction hex above 50% saturation.

**UI vs. world.** World color is lit, graded and blurred. UI is flat, unlit and fixed: navy and cream, with faction color appearing only inside that faction's rule UI and gold only in reward UI. UI never takes the scene's color grade, so it reads the same at noon, at night, and under a boss flood.

**Colorblind safety.** Hues are approximate and must be validated in a CVD simulator (e.g. Color Oracle) on in-engine screenshots before they're locked.

| Pair | Risk | Condition | Backup cue |
|---|---|---|---|
| Stamp Red / Feed Magenta | High | Tritanopia (both pink-red) | Square vs. circle UI; stamp thunk vs. notification ping SFX |
| Feed Magenta / Terminal Cyan | Medium | Protanopia, deuteranopia (both bluish) | Circle vs. wedge; cyan sits a lightness band higher |
| Anthem Blue / Feed Magenta | Medium | Protanopia, deuteranopia (both blue) | Star vs. circle; magenta is lighter; anthem sting vs. notification ping |
| Anthem Blue / Terminal Cyan | Medium | Tritanopia | Star vs. wedge; large lightness gap |
| Anthem Blue / Ink Navy | Low | All (same hue family) | Navy is far darker and duller; Liberty-7 pips get a cream outline on navy |
| Stamp Red / Heal Leaf | Medium | Protanopia, deuteranopia | "+" glyph, rising motion, heal chime |
| Terminal Cyan / Heal Leaf | Medium | Tritanopia | Wedge UI vs. "+" glyph |
| Coin Gold / Heal Leaf | Medium | Protanopia, deuteranopia (both yellowish) | Coin glyph vs. "+" glyph and rising motion; coin chime vs. heal chime |
| Coin Gold / Window Cream | Low-Medium | Tritanopia (both light pinkish) | Coin glyph; gold appears only in reward contexts |
| Coin Gold / Stamp Red | Low | Protanopia, deuteranopia | Large lightness gap; coin vs. square |

**Rule:** no information is carried by color alone. Every faction and semantic color is paired with a shape or icon, and the most important ones also with a sound.

## 5. Character Design Direction

[To be designed] — the player character's visual archetype, how players tell
enemies, NPCs and allies apart at a glance, expression and pose style, and how
much detail survives at game camera distance (LOD philosophy).

## 6. Environment Design Language

[To be designed] — architectural style and its tie to the world's culture,
texture philosophy (painted, PBR or stylised, and why), prop density rules per
area type, and environmental storytelling guidelines.

## 7. UI/HUD Visual Direction

[To be designed] — diegetic versus screen-space HUD, typography (personality,
weight, size hierarchy, minimum readable size), iconography style, UI animation
feel, and any art-direction versus readability conflict and how it was decided.

## 8. Asset Standards

[To be designed] — file formats, naming convention, texture resolution tiers,
LOD levels, export settings, and the engine's hard limits (poly budgets per
asset category, texture memory, material slots). Where an art preference and a
technical limit disagree, record both and the trade-off chosen.

## 9. Reference Direction

[To be designed] — 3–5 references (games, films, art styles or artists). For
each: the specific element to take from it, and what to avoid so the result
does not read as a copy.
