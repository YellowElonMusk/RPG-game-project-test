# Asset List & Generation Prompts — Chapter 1 (Bureaucratia + MegaCorp)

> **Status**: Draft (2026-10-28) · **Source**: `design/art/art-bible.md` §1–§4
> **Scope**: every asset the current playable slice references — the 4-hero squad,
> 5 enemies, the moves and effects they use, battle backdrops, faction icons, and
> the HUD pieces. Overworld maps are listed last as **not needed yet** (no
> Overworld epic exists).
>
> Art bible §5–§9 (character direction, environments, UI, asset standards,
> references) are still `[To be designed]`. The sizes, frame counts and file
> names below are a **proposal** filling that gap — adopt or change them, but
> pick one and keep it: mixed pixel scales are the art bible's #1 warning.

---

## 0. How to use this list

1. **Generate one base sprite per character first** (the idle frame), using the
   Style Anchor below + that character's prompt. Get all 9 bases looking like
   they belong in one game *before* animating anything.
2. **Clean every image** (AI pixel art is almost never on a true grid):
   - downscale to the target size with **nearest-neighbour** (never bilinear);
   - snap to a limited palette (16–24 colours per character, Outline Ink
     `#1A1418` as the outline);
   - remove anti-aliased edge pixels and stray single pixels;
   - transparent background, PNG.
3. **Animate from the cleaned base**, either with a pixel-art-specific
   generator that animates from a reference image, or by hand in Aseprite /
   LibreSprite. General image generators can't hold a character consistent
   across frames; use them for bases and concepts, not frame-by-frame animation.
4. Drop files at the paths in each table (§7). Tell Claude the files are in and
   it wires them up (import settings, sprite sets, record `sprite_set_id`s).

**Fixed technical rules (art bible §1 Production Notes):**

| Rule | Value |
|---|---|
| Filtering | Nearest-neighbour, no sub-pixel scaling or rotation |
| Hero / grunt frame canvas | **64×64 px**, character ~52–58 px tall, feet at y = 60 |
| Boss frame canvas | **128×128 px** (exact 2× of the hero canvas) |
| Pixels-per-unit | One value for every sprite (same canvas grid = same scale) |
| Outline | 1 px, Outline Ink `#1A1418`; actors only |
| Facings | Squad: **back-3/4** (facing up-right, toward enemies). Enemies: **front-3/4** (facing down-left, toward the squad). One facing each — fixed camera, no mirroring needed |
| Background | Transparent PNG |

---

## 1. Style Anchor (paste before every character/enemy prompt)

> Pixel art game sprite, 64x64, single character, full body, clean 1-pixel dark
> outline (#1A1418), limited palette, flat cel shading with one highlight and
> one shadow tone, no anti-aliasing, no gradients, transparent background,
> crisp readable silhouette, Dragon Quest / Chrono Trigger era JRPG proportions
> (about 3 heads tall), comedic caricature of a behaviour and a prop — never of
> body type or ethnicity, bright storybook feel, centered, feet at bottom.

**Negative / avoid (if the tool supports it):** blurry, anti-aliased, painterly,
3D render, photorealistic, gradient shading, text, watermark, multiple
characters, cropped, background scenery, mixed pixel sizes.

---

## 2. The Squad (organic, lumpy, asymmetric — art bible §3)

Neutral palette only: navy, cream, slate, leaf, gold, plus each hero's own
colours. **Never** Stamp Red `#D23A2E` or Terminal Cyan `#19C2D6` (those mean a
faction rule). Each hero = one oversized prop + one pose.

Facing for all squad sprites: **back-3/4, facing up and to the right**.

### 2.1 Karen — `char_karen`
**Prop / pose:** the asymmetric "can I speak to your manager" haircut and an
accusing pointing finger; phone held up like a weapon.

> Prompt: *[Style Anchor]* A middle-aged woman with a dramatic asymmetric
> bob haircut (short at the back, long angled front), seen from behind at a
> three-quarter angle facing up-right, one arm thrust forward pointing
> accusingly, other hand raising a smartphone, sensible cardigan in muted
> teal-grey and cream, oversized sunglasses pushed up on her head, posture
> stiff with indignation.

### 2.2 Michelin Chef — `char_michelin_chef`
**Prop / pose:** a towering chef's toque (taller than his head) and a giant
ladle or plate held high.

> Prompt: *[Style Anchor]* A proud chef seen from behind at a three-quarter
> angle facing up-right, wearing an absurdly tall white toque and cream chef's
> jacket, holding a huge silver ladle raised like a sceptre in one hand and a
> covered dish on the other palm, chest puffed out, small rosette medal pinned
> to the jacket.

### 2.3 Florida Man — `char_florida_man`
**Prop / pose:** filming himself, phone on a selfie stick; tropical shirt,
flip-flops, a chaotic pose.

> Prompt: *[Style Anchor]* A wild-haired man seen from behind at a
> three-quarter angle facing up-right, loud tropical print shirt (leaf green
> and amber flowers on cream), cargo shorts, flip-flops, holding a selfie stick
> high with a phone filming himself, other arm flung out mid-stunt, bandage on
> one knee, unhinged confident energy.

### 2.4 Baguette Thrower — `char_baguette_thrower`
**Prop / pose:** a baguette longer than his arm, held like a baseball bat.

> Prompt: *[Style Anchor]* A lanky man in a striped navy-and-cream shirt and a
> beret, seen from behind at a three-quarter angle facing up-right, holding an
> enormous golden baguette like a baseball bat over his shoulder, batter's
> stance, knees bent, scarf flying, focused.

### 2.5 Squad animations (per hero, 64×64 frames)

| Animation | Frames | Notes |
|---|---|---|
| `idle` | 4 | Gentle bob / breathing loop. The silhouette must read at 32 px |
| `attack` | 4 | Wind-up (big, telegraphed) → strike → follow-through → recover |
| `special` | 6 | The hero's signature move (see below); the comedy frame lives here |
| `defend` | 2 | Brace pose, held |
| `hurt` | 2 | Recoil, flash-friendly (the engine adds the white flash) |
| `ko` | 3 | Comic slump, ends on a held "defeated" frame |
| `victory` | 4 | Fanfare pose, loopable |

Special-move frame direction:
- **Karen — Speak to the Manager:** finger jab + phone thrust, mouth wide mid-rant; last frame a smug crossed-arms hold.
- **Chef — Appetizer / Family Meal:** two specials share one animation: lifts the dish cover with a flourish, steam puff (Family Meal can reuse it with a bigger steam cloud VFX, §5).
- **Florida Man — Viral Stunt:** leaps with the selfie stick, freeze-frame thumbs-up at the top.
- **Baguette Thrower — Home Run:** full baseball swing, baguette bending on contact, big follow-through.

**Portraits** (`portrait_id`, used by combo title cards later): one 96×96
head-and-shoulders per hero, front-facing, same palette. Not needed for this
week's build.

---

## 3. Bureaucratia enemies (square / rectangle, Stamp Red `#D23A2E` — art bible §3–§4)

Grunts are **identical silhouettes stamped from the square** — the conformity is
the joke. Facing: **front-3/4, facing down-left**. Faction colour appears on the
enemy itself (allowed: it tells the player which rule is active).

### 3.1 Clerk — `enemy_clerk` (64×64)
> Prompt: *[Style Anchor]* An alien office clerk with a perfectly square,
> box-shaped head and boxy body, seen from the front at a three-quarter angle
> facing down-left, stamp-red (#D23A2E) uniform with a cream collar and a
> rectangular name badge, holding a rubber stamp in one hand and a tall stack of
> paper files in the other, bored half-lidded eyes, rigid upright posture.

### 3.2 Supervisor (boss) — `enemy_supervisor` (128×128)
"The faction shape scaled to absurdity": a filing-cabinet tower of a man.

> Prompt: *[Style Anchor, but 128x128]* A towering alien bureaucrat whose body
> is a stacked filing cabinet with drawers for a torso, square head with a tiny
> visor cap, stamp-red (#D23A2E) and cream colour scheme, two giant rubber
> stamps for hands, papers spilling out of open drawers, front three-quarter
> view facing down-left, smug and enormous, rectangular shoulders, boss-like
> menace played for comedy.

### 3.3 Bureaucratia animations

| Animation | Clerk | Supervisor | Moves that use it |
|---|---|---|---|
| `idle` | 4 | 4 | — |
| `attack` | 4 | 4 | Pen Jab (weak jab), Red Tape (focus attack), Late Fee |
| `special` | — | 6 | Mass Audit (hits everyone: papers fly), Final Notice (giant stamp slam) |
| `defend` | 2 | 2 | Hunker-down while the permit is pending |
| `hurt` | 2 | 2 | — |
| `ko` | 3 | 4 | Clerk: papers scatter. Supervisor: drawers burst open |

---

## 4. MegaCorp enemies (wedge / triangle, Terminal Cyan `#19C2D6`)

Facing: **front-3/4, facing down-left**.

### 4.1 Security Drone — `enemy_security_drone` (64×64)
> Prompt: *[Style Anchor]* A hovering corporate security drone shaped like a
> sharp triangular wedge, angled glass panels, terminal-cyan (#19C2D6) glowing
> scanner eye in the centre, small thruster flames underneath, a corporate
> barcode decal on the side, front three-quarter view facing down-left, cold
> and sleek.

### 4.2 Middle Manager — `enemy_middle_manager` (64×64)
> Prompt: *[Style Anchor]* An alien middle manager in a sharp-collared suit
> with pointy angular shoulders, triangular wedge-shaped head, terminal-cyan
> (#19C2D6) tie and lanyard, holding a tablet showing an upward growth-arrow
> chart, fake enthusiastic grin, front three-quarter view facing down-left.

### 4.3 CEO (boss) — `enemy_ceo` (128×128)
> Prompt: *[Style Anchor, but 128x128]* A towering alien CEO whose silhouette
> is an extruded glass skyscraper wedge, sharp triangular collar rising behind
> the head like a tower, terminal-cyan (#19C2D6) neon trim, giant golden
> growth-arrow pin, one hand holding an oversized pen like a sword, other hand
> on a stack of invoices, front three-quarter view facing down-left, arrogant
> boss pose.

### 4.4 MegaCorp animations

| Animation | Drone | Manager | CEO | Moves that use it |
|---|---|---|---|---|
| `idle` | 4 (hover bob) | 4 | 4 | — |
| `attack` | 4 | 4 | 4 | Laser Scan (cyan beam), Upsell (tablet thrust) |
| `special` | — | — | 6 | Layoffs (hits everyone: pink-slip storm), Hostile Takeover (pen slash) |
| `hurt` | 2 | 2 | 2 | — |
| `ko` | 3 | 3 | 4 | Drone: sparks and drops. CEO: tower cracks |

---

## 5. Effects & icons (pixel art)

| Asset | Size | Frames | Prompt / direction |
|---|---|---|---|
| Impact burst (generic hit) | 32×32 | 4 | Chalk-white starburst with Outline Ink border. No red (art bible §4: red is Bureaucratia's) |
| Heal sparkle | 32×32 | 5 | Heal Leaf `#7BD389` rising "+" glyphs |
| Stun stars (Speak to the Manager) | 32×16 | 4 | Small cream stars circling a head |
| "Gone Viral" burst (Viral Stunt debuff) | 32×32 | 4 | Share-arrow burst with tiny hearts, cream on navy |
| Steam cloud (Family Meal) | 48×32 | 4 | Soft cream steam puffs, pixel-stepped not blurred |
| Stamp slam (APPROVED / DENIED) | 64×32 | 3 | Stamp Red rectangle stamp outline with block letters "APPROVED" / "DENIED" |
| Cyan laser (Laser Scan) | 64×8 | 3 | Terminal Cyan horizontal beam with a white core |
| Pink slips (Layoffs) | 16×16 | 4 | Fluttering paper slips; tint them **cream**, not pink — Feed Magenta belongs to Influencia |
| Faction icon — Bureaucratia (`icon_faction_bureaucratia`) | 32×32 | 1 | Square rubber-stamp outline in Stamp Red; must read in black and white |
| Faction icon — MegaCorp (`icon_faction_megacorp`) | 32×32 | 1 | Upward wedge / growth arrow in Terminal Cyan; must read in black and white |
| Quirk tags (later) | 32×16 | 1 each | Torn cream sticker tags: Complained (scribble speech bubble), Unionized (linked hands), Gone Viral (share arrow), Notarized (navy wax seal) |

Generic prompt for small icons:
> *Pixel art icon, 32x32, single symbol, 1-pixel #1A1418 outline, flat colours,
> no anti-aliasing, transparent background, readable as a silhouette:* [description above].

---

## 6. Battle stage backdrops

The art bible's real target is a **lit low-poly 3D diorama** (Principle 2),
which image generators can't produce as a usable 3D scene. For this week, use
**one 2D painted backdrop per faction**, shown behind the sprites at 30% dimmed
and blurred (art bible §2, Battle row). True 3D dioramas come later (Blender,
or an image-to-3D tool, then a cleanup pass).

| Asset | Size | Prompt |
|---|---|---|
| `bg_battle_bureaucratia` | 640×360 (16:9; the engine scales it) | *Isometric toy diorama of an alien government office, chunky low-poly blocks, tilt-shift miniature look, endless rectangular queue barriers, stacked filing cabinets, a giant red rubber-stamp statue, stamp-red (#D23A2E) posters and banners at mid-saturation on warm storybook golden-hour lighting, flat office fluorescent fill, soft shadows, calm and uncluttered (characters will stand in front), no people, no text* |
| `bg_battle_megacorp` | 640×360 | *Isometric toy diorama of an alien corporate plaza, chunky low-poly blocks, tilt-shift miniature look, angled glass skyscraper wedges, upward growth-arrow sculptures, terminal-cyan (#19C2D6) neon trim at mid-saturation, cyan neon dusk sky, soft shadows, calm and uncluttered (characters will stand in front), no people, no text* |
| `bg_battle_bureaucratia_boss` | 640×360 | Same as the Bureaucratia backdrop, but the sky floods a **deep dusk red** (around `#81271E`, dark) with a **glowing red neon horizon band** and a few sparse small stars in the upper sky; harder contrast |
| `bg_battle_megacorp_boss` | 640×360 | Same as the MegaCorp backdrop, but the sky is a **deep dark teal dusk** (low saturation, dark) with a **glowing cyan neon horizon band** and sparse small stars |

Keep backdrops **less saturated than the sprites**. The environment always
yields to the actors (Principle 2).

---

## 7. Proposed file layout

`assets/` doesn't exist yet. Proposed (rename freely, but tell Claude):

```
assets/
  sprites/
    squad/karen/karen_idle.png, karen_attack.png, karen_special.png, ...
    squad/michelin_chef/...
    squad/florida_man/...
    squad/baguette_thrower/...
    enemies/clerk/clerk_idle.png, ...
    enemies/supervisor/...
    enemies/security_drone/...
    enemies/middle_manager/...
    enemies/ceo/...
  vfx/impact_burst.png, heal_sparkle.png, stamp_slam.png, ...
  icons/icon_faction_bureaucratia.png, icon_faction_megacorp.png
  backgrounds/bg_battle_bureaucratia.png, ...
```

Each animation file = **one horizontal strip** of equal-size frames, left to
right (e.g. `karen_idle.png` = 256×64 for 4 frames of 64×64). One strip per
animation keeps re-exports simple.

---

## 8. Priority order

1. **Bases for the 4 heroes + 5 enemies** (idle frame only): enough to replace
   the checkerboards and play-test.
2. **The 2 faction battle backdrops.**
3. **`attack`, `hurt`, `ko`** for everyone: makes battles read.
4. **The 4 hero specials + the boss specials**: where the comedy lives.
5. **Effects (§5)**, then `defend`/`victory`, then the boss backdrops.
6. Later: portraits, quirk tags, overworld (below).

## 9. Not needed yet

- **Overworld maps, the Compliance Clerk patrol sprite (`patrol_compliance_clerk`),
  towns, camp:** no Overworld or Camp epic exists, so nothing would load them.
- **Influencia and Liberty-7:** factions planned in the art bible, not in Chapter 1.
- **3D dioramas:** after the 2D backdrops prove the battle layout.

**Rough volume for priority 1–5:** ~9 base sprites, ~55 animation strips
(~200 frames), ~10 effects/icons, 4 backdrops.
