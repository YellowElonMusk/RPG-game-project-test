# Accessibility Requirements

> Authoring guidance: .claude/docs/templates/guidance/accessibility-requirements-guide.md (load per-section as you author — do not read entirely).

> **Status**: Committed (tier chosen autonomously on 2026-10-22, logged for user veto in `production/session-logs/decision-log.md`)
> **Author**: user + ux-designer (`/ux-design accessibility`, autonomous mode)
> **Last Updated**: 2026-10-22
> **Accessibility Tier Target**: Standard (with the Comprehensive-tier elevations listed below)
> **Platform(s)**: PC — Windows (Steam / Epic) and Linux/SteamOS (Steam Deck, native Linux export)
> **External Standards Targeted**:
> - WCAG 2.1 Level AA (contrast, text resize, non-text contrast 1.4.11; flash thresholds 2.3.1 via the flash gate)
> - AbleGamers CVAA Guidelines: reference only (the game has no communication features, so CVAA does not apply legally)
> - Xbox Accessibility Guidelines (XAG): No (no Xbox release planned); used as a design checklist only
> - PlayStation Accessibility (Sony Guidelines): No
> - Apple / Google Accessibility Guidelines: N/A (no mobile release)
> **Accessibility Consultant**: None engaged
> **Linked Documents**: `design/gdd/systems-index.md`, `design/ux/interaction-patterns.md`, `design/art/art-bible.md` §4, `design/gdd/sprite-camera-presentation.md` rule 13, `design/gdd/input-system.md`, `docs/architecture/adr-0008-ui-framework.md` §10, `docs/architecture/adr-0013-localization.md`
> **Template**: Accessibility Requirements

> **Why this document exists**: Per-screen accessibility annotations belong in
> UX specs. This document captures the project-wide accessibility commitments,
> the feature matrix across all systems, the test plan, and the audit history.
> It is created once during Technical Setup by the UX designer with
> `/ux-design accessibility` — you pick the tier, against the criteria
> accessibility-specialist sets and audits against — then updated as features
> are added and audits are completed. If a feature conflicts with a commitment
> made here, this document wins — change the feature, not the commitment,
> unless the producer approves a formal revision.
>
> **When to update**: After each `/gate-check` pass, after any accessibility
> audit, and whenever a new game system is added to `systems-index.md`.

---

## Accessibility Tier Definition

### Tier Definitions

| Tier | Core Commitment | Typical Effort |
|------|----------------|----------------|
| **Basic** | Critical player-facing text is readable at standard resolution. No feature requires color discrimination alone. Volume controls exist for music, SFX, and voice independently. The game is completable without photosensitivity risk. | Low — primarily design constraints |
| **Standard** | All of Basic, plus: full input remapping on all platforms, subtitle support with speaker identification, adjustable text size, at least one colorblind mode, and no timed input that cannot be extended or toggled. | Medium — requires dedicated implementation work |
| **Comprehensive** | All of Standard, plus: screen reader support for menus, mono audio option, difficulty assist modes, HUD element repositioning, reduced motion mode, and visual indicators for all gameplay-critical audio. | High — requires platform API integration and significant UI architecture |
| **Exemplary** | All of Comprehensive, plus: full subtitle customization (font, size, color, background, position), high contrast mode, cognitive load assist tools, tactile/haptic alternatives for all audio-only cues, and external third-party accessibility audit. | Very High — requires dedicated accessibility budget and specialist consultation |

### This Project's Commitment

**Target Tier**: **Standard**, with selected Comprehensive features elevated (below).

**Rationale**: *Go back to your planet!* is a turn-based JRPG. It has no real-time
input, no aiming, no quick-time events and no timed command window, which
removes the motor barriers that dominate action games almost entirely. A player
can take any amount of time over any decision (Turn Battle System; the input
guard of `sprite-camera-presentation.md` rule 9 is a 0.15 s *protection*, not
a window to hit). The real barriers are visual and cognitive. The game is
reading-heavy: satire delivered through rule banners, quirk descriptions, combo
punchlines and banter. It renders at a 640×360 logical UI scale that runs from
1920×1080 monitors down to a 7-inch Steam Deck screen. And its core mechanic
asks the player to read a faction's rule and track quirk states across a party
(Pillar 4, "Readable in One Turn"). Standard addresses exactly these barriers:
remapping, adjustable text size, a colorblind mode, subtitles with speaker
names, and no unextendable timed input. It is realistic for a solo developer
when most of it rides on decisions that are already made (data-driven
bindings, the theme's live text scale, native `Control` focus with AccessKit,
and the six comfort settings).

Comprehensive as a whole is not committed. A menu screen reader, HUD
repositioning and difficulty assist modes each need design and test capacity
that an 8–10 month solo first game cannot guarantee. Committing to them now
would turn the document into fiction. Dropping to Basic would cost the
players who rely on remapping (a Vertical Slice feature) or adjustable text.
On the Steam Deck in particular, where text is physically about two-thirds the
size it is on a 1080p monitor, text scale is a legibility feature for everyone.

**Features explicitly in scope (beyond tier baseline)**:
- **Reduced motion mode** (Comprehensive): already designed. Screen Shake Full / Reduced / Off, Reduce Motion, Reduce Blur (`sprite-camera-presentation.md` rule 13). It is elevated because the battle's hit-punch and boss takeover are signature camera moments, so it was cheaper to design the off-ramp alongside them than to retrofit it.
- **Photosensitivity protection beyond a warning** (Comprehensive / Exemplary practice): a global flash gate caps every large-area luminance transition at `flash_rate_max` per second against WCAG 2.3.1's general and red-flash definitions, and Reduce Flashing forces every gated source to its capped variant (ADR-0005 §12, `flash_gate` formula). It is elevated because the battle's comedy VFX, the retry flash and the boss dusk flood are all large-area luminance events.
- **Visual equivalents for all gameplay-critical audio** (Comprehensive): cheap in a turn-based game, where every outcome is already shown beat by beat with floating numbers and HUD changes (ADR-0006). It is committed so the Audio Manager can never introduce an audio-only cue.
- **Battle pacing control** (no tier; motor and cognitive comfort): Faster battle animations, Speed up boss entrances, and a one-level fast-forward latch that never skips a beat (`sprite-camera-presentation.md` rules 9 and 13).
- **Native, screen-reader-ready menu controls** (groundwork for Comprehensive): every interactive element is a native `Control` or sets `accessibility_name` (ADR-0008 §10), so AccessKit data exists whether or not a full screen-reader pass is committed (see Open Questions, OQ-1).

**Features explicitly out of scope**:
- HUD element repositioning (Comprehensive): the battle HUD has a fixed layout that the replay and the readable-in-one-turn staging depend on. See Known Intentional Limitations.
- Difficulty assist modes (Comprehensive): not designed. Retry already restarts any lost fight at no cost (Game State Retry). Revisit once Stats & Damage tuning settles. See Known Intentional Limitations.
- Mono audio (Comprehensive): deferred to the Audio Manager. See Known Intentional Limitations.
- Full subtitle customization, high contrast mode, haptic alternatives, and an external audit (Exemplary). See Known Intentional Limitations.
- **Undecided, not out of scope:** a full screen-reader pass for menus (OQ-1). It needs a user / creative-director decision.

---

## Visual Accessibility

The UI is drawn at a **logical** resolution of 640×360 or larger, scaled by an
integer factor `f` (ADR-0008 §9): 3× at 1920×1080 and 2× on the Steam Deck
(1280×800). Text sizes below are therefore given in **logical px** (font size
in the theme), with their physical size at both binding targets. The template's
"24 px at 1080p" maps to 8 logical px. The Steam Deck's 2× factor makes text
physically smaller than at 1080p, on a screen held closer. The Deck is the
binding legibility constraint, and text scale exists for it.

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Minimum text size — menu UI | Standard | All menu screens | Not Started | ≥ 8 logical px at text scale 1.0 (24 px at 1920×1080, 16 px on the Deck). Text scale 1.25 and 1.5 (`UiSettings.text_scale()`, applied live through `Theme.set_font_size()`, ADR-0008 §9) must not clip or overlap. Verified by pseudolocalization screenshots at 640×360 and scale 1.5 (ADR-0013 §6). |
| Minimum text size — subtitles / dialogue boxes | Standard | Dialogue, banter barks, combo punchlines | Not Started | ≥ 10 logical px at scale 1.0 (30 px at 1080p, 20 px on the Deck). The template's 32 px at 1080p target is for TV distance; this is a desk and handheld PC game, so 30 px is accepted. Joke text is the product, and it gets the largest body size. |
| Minimum text size — HUD | Standard | Battle HUD (HP/MP, rule banner, command menu, floating numbers) | Not Started | ≥ 7 logical px for critical values (21 px at 1080p, 14 px on the Deck), ≥ 8 logical px for the command menu. Floating damage numbers ≥ 8 logical px with a 1 px Outline Ink outline. |
| Text contrast — UI text on backgrounds | Standard | All UI text | Not Started | ≥ 4.5:1 body, ≥ 3:1 large (WCAG AA). The navy and cream Dragon Quest windows (art bible) are opaque, so contrast is fixed and measurable. Check the final theme swatches. |
| Text contrast — subtitles | Standard | Dialogue boxes, barks | Not Started | Dialogue and barks are always drawn in opaque windows, never over the diorama, so ≥ 7:1 holds against a known background. A bark shown over the world must use an opaque speech window, not a drop shadow. |
| Non-text contrast — actors | Standard | Battle sprites vs. stage | Designed | `actor_contrast_min` 3.0 (WCAG 1.4.11), measured per sector on reference captures (`sprite-camera-presentation.md` Formulas, ACs). |
| Colorblind mode — Protanopia | Standard | UI/HUD status and rule colors | Not Started | One **UI palette** mode ("Colorblind-friendly UI colors"), covering protanopia and deuteranopia. It swaps the theme's status, rule-banner and HP/MP colors for a CVD-safe set. It does **not** recolor the 3D world: faction world color is backed by faction **shape** (art bible §4) and needs no swap. Shipped with the settings screen (Vertical Slice). |
| Colorblind mode — Deuteranopia | Standard | Same as above | Not Started | Covered by the same palette (red-green). Validate both with a CVD simulator on in-engine screenshots (art bible §4, "Colorblind safety"). |
| Colorblind mode — Tritanopia | Standard | Same as above | Not Started | No separate mode. The default palette is validated under a tritanopia simulation, and any blue/yellow-only distinction gets a non-color backup instead. |
| Color-as-only-indicator audit | Basic | All UI and gameplay | In Progress | Table below. Every row needs a non-color backup before shipping. |
| UI scaling | Standard | All UI | Designed | Text scale 1.0 / 1.25 / 1.5 (ADR-0008 §9). Whole-UI scale follows the window through the integer refit, and the logical canvas grows with the window rather than shrinking the UI. Independent HUD vs. menu scaling is **not** offered (it would break the shared texel grid with sprites, ADR-0008 §9). |
| High contrast mode | Comprehensive | — | Out of Scope | See Known Intentional Limitations. Menus are already opaque flat windows. |
| Brightness/gamma controls | Basic | Global | Not Started | Brightness slider (−50% to +50%) with a calibration image. Applied as a final post-process in **SDR** (ADR-0005 pins SDR output). It must not change the WCAG luminance used by the flash gate's thresholds, so it applies after the gate's luminance definitions are evaluated on source content. |
| Screen flash / strobe warning | Basic | All VFX, transitions | Designed | (1) Photosensitivity notice on first launch, before Title. (2) The flash gate enforces ≤ `flash_rate_max` flashes per second across all sources, including red flash (ADR-0005 §12). (3) Reduce Flashing forces every gated source to its capped variant (rule 13). |
| Motion/animation reduction mode | Standard (elevated) | Hit-punch, ambient motion, blur, transitions | Designed | Screen Shake (Full / Reduced / Off), Reduce Motion (punch off, ambient set motion stilled, calmer victory), Reduce Blur (`sprite-camera-presentation.md` rule 13). Character animation is kept, because it carries the outcome. |
| Subtitles — on/off | Basic | All voiced content | Not Started | MVP has no voice; all dialogue is text. When voiced barks arrive (Vertical Slice+), subtitles default to **On**, since this game's humour lives in the words. |
| Subtitles — speaker identification | Standard | Dialogue, barks | Not Started | Every line shows the speaker's name. Speaker color, if used, is never the only identifier. |
| Subtitles — style customization | Comprehensive | — | Partial | Size follows the text scale; background is always opaque. No font, color or position options (Known Intentional Limitations). |
| Subtitles — sound effect captions | Comprehensive | — | Not Started | Only if the SFX audit below finds an uncovered cue. None are expected (turn-based, everything is shown). |

### Color-as-Only-Indicator Audit

| Location | Color Signal | What It Communicates | Non-Color Backup | Status |
|----------|-------------|---------------------|-----------------|--------|
| Boss stage dusk flood / faction light | Faction hue (Bureaucratia stamp-red, …) | Which faction rules this fight | Faction **shape** on stage (`sprite-camera-presentation.md` rule 11, AC-37) plus the rule banner's text and faction name | Designed |
| Rule banner / rule UI | Faction signature color | The active faction rule | Banner text (`FactionRule.get_banner_text()`), faction shape icon | Not Started |
| HP / MP bars | Bar fill color (and low-HP color, if any) | Remaining health / mana | Numeric `current / max` always shown beside the bar | Not Started |
| Quirk state badges | Badge color | Which quirk state a combatant has | Unique icon glyph per state plus its name on focus / tooltip | Not Started (Quirk State System not designed) |
| Floating numbers | Damage vs. heal color | Damage taken vs. healed | Sign prefix (`−12` / `+12`) and a distinct motion (down vs. up) | Not Started |
| Disabled command options | Greyed text | Command unavailable (`check_command()` failure) | Strike-through or lock icon plus the reason line from `CommandCheck` (ADR-0010) | Not Started |
| Focus indicator | Focus stylebox color | Which control is selected | Focus stylebox has a shape (frame or cursor arrow), not only a tint (ADR-0008 §5) | Not Started |
| Enemy "Approved" / permit state (Bureaucratia) | Stamp color | Whether a target can be damaged | "APPROVED" stamp glyph with text on the sprite and in the tooltip | Not Started |

---

## Motor Accessibility

The game has **no timed inputs**: no QTEs, no real-time combat, no command
timer. Every battle decision waits indefinitely. The only time-based input
behaviours are protective: the 0.15 s menu input guard against carried-over
presses, and menu auto-repeat when a direction is held. The overworld uses
continuous movement (ADR-0012, Proposed) with no time pressure (encounters are
symbol or zone based).

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Full input remapping | Standard | All 8 actions, keyboard and gamepad | Designed (Vertical Slice) | `input-system.md` rule 8 + ADR-0003/0009: a remap screen edits overrides only, rejects conflicts with a clear message, offers "Restore defaults" and a confirm/cancel swap, and persists overrides in settings. Mouse buttons are fixed (pointer confirm/cancel); keyboard can do everything the mouse can. |
| Input method switching | Standard | PC + Deck | Designed | `active_device_changed(kind, pad_style)` swaps prompts live (ADR-0003, ADR-0008 §4). No restart; any device works at any moment. |
| One-hand mode | Standard | All actions | Designed (by construction) | No action requires two simultaneous inputs; every action is a single press. Keyboard-only and gamepad-only play are both complete. No dedicated mode is needed. |
| Hold-to-press alternatives | Standard | `fast_forward` | Designed | The only hold-capable action, `fast_forward`, is a **tap latch**: one tap speeds the rest of the replay, and in Dialogue one tap latches fast text until the Dialogue closes or `cancel` (`input-system.md` rule 1, 2026-10-23). Holding is never required, and `inspect` is a toggle. |
| Rapid input alternatives | Standard | Menu repeat | Designed (Vertical Slice) | Nothing requires rapid presses. Menu scrolling auto-repeats on a held direction (`repeat_delay` 0.40 s, `repeat_interval` 0.08 s). **Designed (Vertical Slice):** `repeat_delay`, `repeat_interval` and the stick `deadzone` become player settings on the remap/settings screen (`input-system.md` rule 8); MVP ships the defaults. |
| Input timing adjustments | Standard | — | N/A | No timed input exists. **Commitment:** any future timed input must ship with a 0.5×–3.0× window multiplier, or be redesigned. |
| Aim assist | Standard | — | N/A | No aiming. |
| Auto-sprint / movement assists | Standard | Overworld movement | Not Started | The Overworld GDD (Approved 2026-10-23, rule 1) has one walking speed and no run button, held or toggled; a press-to-toggle "Fast Walk" is deferred to playtests (its OQ-9). |
| Platforming / traversal assists | — | — | N/A | No platforming. |
| HUD element repositioning | Comprehensive | — | Out of Scope | Known Intentional Limitations. |
| Menu navigation without pointer precision | Standard | All menus | Designed | Every menu is fully navigable by keyboard / d-pad / stick (native focus + `FocusScope`, ADR-0008). Hover moves focus only after `pointer_switch_px` of movement, so a tremor never steals focus (`input-system.md` rule 3). |
| Accidental-press protection | Standard | Command menu, target select, Defeat Prompt, results | Designed | `MenuGuard`: presses carried over from a previous screen and presses within `input_guard` are refused with feedback, never executed (ADR-0008 §6, `sprite-camera-presentation.md` rule 9). |

---

## Cognitive Accessibility

Pillar 4 ("Readable in One Turn") is itself a cognitive accessibility
commitment: a faction's rule must be understandable from what is on screen
during one turn. The highest cognitive load in the game is in battle, where the
player has to track the faction rule, party HP/MP, quirk states and combo
opportunities at once.

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Difficulty options | Standard | Battle | Not Started | **Minimum committed:** free, unlimited Retry of any lost fight from its start (Game State Retry). A granular assist (damage taken / dealt sliders) is **not committed**; it is an Open Question (OQ-3) for the Stats & Damage owner. |
| Pause anywhere | Basic | Overworld, Camp, Battle | Designed | The Menu opens in Overworld, Camp and Battle (in Battle, the system menu) and stops mode time (`game-state-scene-flow.md` rule 10). **Restrictions:** not during a transition (≤ 1.5 s), in Boot, or in Content Error. Each is a short, non-interactive state. The battle itself waits for input at every turn, so it never needs pausing to think. |
| Tutorial persistence | Standard | Onboarding & Tutorial | Not Started | Every tutorial prompt is retrievable from a Help page in the Menu. The Combo Codex records every discovered combo (MVP). |
| Quest / objective clarity | Standard | Dialogue, Banter & Quests; Overworld | Not Started | Current objective visible within 2 presses (Menu → Objective). Exact wording owned by the Dialogue/Quests GDD. |
| Rule clarity (project-specific) | Standard | Faction Rule Modifiers, battle HUD | Not Started | The active rule is always on screen as a banner with plain text and a tooltip (`get_banner_text()` / `get_tooltip_text()`, ADR-0011), and a refused command shows *why* (`CommandCheck.reason`, ADR-0010). The player never has to remember the rule. |
| Visual indicators for audio-only information | Standard (elevated) | All systems | Designed (commitment) | Every outcome is replayed visually beat by beat (ADR-0006). See the SFX audit. |
| Reading time for UI | Standard | All auto-dismissing text | Designed | Battle replays never advance past a beat before `beat_min` and never skip one. Dialogue and results wait for confirm. **No actionable text auto-dismisses.** Damage numbers are transient but duplicated in the HP readout. |
| Battle pacing | Standard (project) | Battle replay | Designed | Default pace plus Faster battle animations and the fast-forward latch; never skips a beat (`sprite-camera-presentation.md` rules 9, 13). |
| Cognitive load documentation | Comprehensive | Per system | Partial | See the Per-Feature Matrix's cognitive column. Battle is flagged above 4 tracked items and needs compensating UI clarity. |
| Navigation assists | Standard | Overworld | Not Started | Pending the Overworld GDD: a visible next-destination marker is the minimum. Fast travel is not committed. |

---

## Auditory Accessibility

MVP has no voice acting ("final art pass, voice, full soundtrack" are explicitly
not in MVP, `game-concept.md`), and the Audio Manager is not designed yet. The
rule this document sets for it: **every sound that changes what the player
should do next has a visual equivalent.** In a turn-based game that shows every
outcome as a beat, the rule is cheap.

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Subtitles for all spoken dialogue | Basic | All voice | N/A for MVP | All dialogue is text in MVP. Any later voice or bark is subtitled at 100%. |
| Closed captions for gameplay-critical SFX | Comprehensive | — | Not Started | Not expected to be needed (audit below). |
| Mono audio option | Comprehensive | — | Out of Scope | Deferred to the Audio Manager (Known Intentional Limitations). |
| Independent volume controls | Basic | Music / SFX / UI (Voice when added) | Not Started | Settings sliders 0–100%, default 80%, persisted by `SettingsService` (ADR-0009), reachable from the Menu in every mode. Owned by the Audio Manager + settings screen. |
| Visual representations for directional audio | Comprehensive | — | N/A | No off-screen threats; battles are fully on screen, and the overworld has no audio-only threat. |
| Hearing aid compatibility mode | Standard | Audio cues | Not Started | Satisfied by the visual-equivalent rule: no information is audio-only, so frequency filtering loses nothing. The Audio Manager GDD must keep it that way. |

### Gameplay-Critical SFX Audit

| Sound Effect | What It Communicates | Visual Backup | Caption Required | Status |
|-------------|---------------------|--------------|-----------------|--------|
| Hit / impact sound (`beat_impact`) | An action landed | Reaction animation, hit-punch (or not, under Reduce Motion), floating number, HP bar change | No | Designed |
| Knockout sound | A combatant is down | KO slump hold animation, HP 0, the combatant leaves the turn order | No | Designed |
| UI refusal tick | A press was refused (guarded or illegal) | Refusal pulse on the control plus the `CommandCheck` reason (ADR-0008 §7) | No | Designed |
| Boss takeover sting | The boss fight began / the rule took over | Full-screen dusk flood takeover and rule banner | No | Designed |
| Combo trigger fanfare | A quirk combo fired | Combo name banner and Codex unlock | No | Not Started (Combo System not designed) |
| Victory / Defeat music | The fight ended | Results screen / Defeat Prompt | No | Designed |

---

## Platform Accessibility API Integration

| Platform | API / Standard | Features Planned | Status | Notes |
|----------|---------------|-----------------|--------|-------|
| Xbox (GDK) | XAG | — | N/A | No Xbox release. |
| PlayStation 5 | Sony guidelines | — | N/A | No PlayStation release. |
| Steam (PC) / Steam Deck | Steam Input, SteamOS | Controller remapping through Steam Input (system level), on top of in-game remapping; Deck controls work with no desktop mode | Not Started | ⚠️ Steam Input on the native Linux Deck reports "Steam Virtual Gamepad"; it maps to `pad_style` `xbox` (`input-system.md` rule 4, 2026-10-23), closing ADR-0003 advisory E9. In-game remapping is still required for keyboard. |
| iOS | VoiceOver | — | N/A | No mobile release. |
| Android | TalkBack | — | N/A | No mobile release. |
| PC (Screen Reader) | AccessKit (Godot 4.5+): Windows UIA / NVDA / Narrator; Linux AT-SPI / Orca | **Groundwork committed:** every interactive element is a native `Control` or sets `accessibility_name` (ADR-0008 §10). `accessibility_live` is set on changing text through `AccessibilityServer.AccessibilityLiveMode` (4.7). **Full menu screen-reader pass: undecided (OQ-1).** | Not Started | Native `Control`s expose names and roles through AccessKit (probed: `accessibility_name`, `accessibility_description`, `accessibility_live`, relations, ADR-0008 Verification item 7). Re-injected `ui_*` navigation keeps native focus, so AccessKit sees real focus changes. |

---

## Per-Feature Accessibility Matrix

| System | Visual Concerns | Motor Concerns | Cognitive Concerns | Auditory Concerns | Addressed | Notes |
|--------|----------------|---------------|-------------------|------------------|-----------|-------|
| Game State & Scene Flow | Wipes and retry flash are large-area luminance | None | Transitions lock input briefly (≤ 1.5 s) | None | Yes | Flash gate covers transitions (TR-gamestate-007); pause via Menu. |
| Input System | Prompt glyphs must match the device | Remapping, hold, repeat | None | None | Partial | Remap screen is Vertical Slice; Steam Input and the Deck report `pad_style` `xbox` (rule 4; E9 closed). Dialogue fast-forward is a tap latch and `inspect` a toggle, so nothing is held. |
| Content Data Definitions | — | — | — | — | N/A | No player-facing surface except via other systems; text is extractable for localization (ADR-0013). |
| Sprite & Camera Presentation | Faction color vs. CVD; actor contrast; flashes; blur; shake | None | Readability of who acts | None | Yes | Shape backup, `actor_contrast_min` 3.0, flash gate, rule 13 comfort settings. |
| Turn Battle System | Disabled options must not be grey-only | None (untimed) | Party HP/MP + rule + quirk states + combos: **> 4 tracked items** | None | Partial | `check_command()` reasons; one rule banner; HUD spec must keep the load legible. |
| Stats & Damage Resolution | Damage vs. heal numbers | None | Numbers must be visible long enough | None | Partial | Sign prefix + HP readout duplicate transient numbers. |
| Quirk State System | Badge colors | None | Tracking states per combatant | None | Not Started | Not designed; icon + name required per state. |
| Combo System & Codex | Combo banner legibility | None | Discovering combos; the Codex as memory aid | Combo fanfare | Not Started | Codex persists discoveries; visual banner for every fanfare. |
| Faction Rule Modifiers | Rule UI faction color | None | Understanding the rule | None | Partial | Banner + tooltip text; shape icon; refusal reasons. |
| Enemy AI | Telegraphed intent, if any | None | Predicting enemy behaviour | None | Not Started | Any intent tell must be visual, not audio-only. |
| Overworld Exploration & Encounters | Encounter symbols vs. CVD | Continuous movement, no held run | Where to go next | None | Designed | GDD Approved 2026-10-23: no held run (rule 1); diegetic beacon chain plus an optional screen-edge arrow (rule 19); symbols read by shape and pose, never colour only. |
| Squad Roster & Recruitment | — | None | Who is in the party | None | Not Started | — |
| Camp & Party Management | Low-contrast firelit scene behind UI | None | Party composition choices | None | Not Started | UI over camp uses opaque windows. |
| Leveling & Loyalty | — | None | Loyalty state visibility | None | Not Started | Vertical Slice. |
| Faction Reputation & Endings | Reputation shown by color? | None | Consequences of a choice | None | Not Started | Any reputation meter needs a number or label. |
| Items, Equipment & Shops | Rarity / stat-change colors | None | Stat comparisons | None | Not Started | Vertical Slice; compare with +/− signs, not only color. |
| Dialogue, Banter & Quests | Text size; bark windows | None | Long text; objective recall | Barks / voice later | Not Started | Opaque windows; speaker names; no auto-advance; objective in Menu. |
| UI Framework | Text size, contrast, focus visibility | Pointer precision | Consistent patterns | Refusal tick | Partial | ADR-0008: native focus, `MenuGuard`, text scale, `accessibility_name`. |
| Save/Load & Settings | — | None | Clear save state | None | Partial | Hosts every accessibility setting; settings live from boot (ADR-0009). |
| Audio Manager | — | None | — | Volume buses, mono | Not Started | Must keep "no audio-only information". |
| Onboarding & Tutorial | Prompt legibility | None | Re-reading tutorials | None | Not Started | Help page in the Menu. |

---

## Accessibility Test Plan

| Feature | Test Method | Test Cases | Pass Criteria | Responsible | Status |
|---------|------------|------------|--------------|-------------|--------|
| Text contrast ratios | Automated — contrast check on theme swatches and UI screenshots | Every text/background pair in `ui_theme.tres`; dialogue windows; HUD | Body ≥ 4.5:1, large ≥ 3:1, dialogue ≥ 7:1 | ux-designer | Not Started |
| Text size and scale | Windowed screenshots (ADR-0013 §6 pipeline) | Title, battle HUD, Menu, settings, dialogue at 1920×1080 and 1280×800, text scale 1.0 and 1.5, plus pseudolocalized | No clipped or overlapping text; sizes meet the minimums above | qa-tester | Not Started |
| Colorblind palette | Manual — CVD simulator on in-engine screenshots | Battle HUD, rule banner, boss stage, quirk badges, in protanopia / deuteranopia / tritanopia simulation, palette on and off | Every row of the color-only audit is distinguishable without color | ux-designer | Not Started |
| Input remapping | Manual | Rebind every action on keyboard and gamepad; play one full battle and a chapter segment; restart | All actions reachable; conflicts rejected with a message; bindings persist; "Restore defaults" works | qa-tester | Not Started |
| Keyboard-only and gamepad-only | Manual | Play the MVP chapter with each device alone | Completable; no pointer-only control | qa-tester | Not Started |
| Flash safety | Automated + capture tool | Flash gate unit tests; capture-measured flash ACs (`sprite-camera-presentation.md` [C] ACs) | No 1 s window exceeds `flash_rate_max`; Reduce Flashing forces capped variants | qa-tester | Not Started |
| Reduced motion | Manual | Screen Shake Off/Reduced, Reduce Motion, Reduce Blur through a full battle and a boss | No hit-punch with Reduce Motion On; ambient motion still; blur reduced per rule 13 | ux-designer | Not Started |
| Platform screen reader (menu groundwork) | Manual — NVDA (Windows), Orca (Linux) | Title, Menu, settings, battle command menu | Every interactive element announces a name and role; focus order matches visual order | ux-designer | Not Started |
| Steam Deck legibility | Manual on hardware | Battle HUD, dialogue, Menu at text scale 1.0 and 1.5 at handheld distance | Critical text readable at scale 1.0; everything readable at 1.5 | producer | Not Started |
| User testing — colorblind | Playtest with CVD participants | MVP chapter with the palette on | No color clarification requested | producer | Not Started |
| User testing — motor | Playtest with one-hand / adaptive setups | MVP chapter on one device | Completable without assistance | producer | Not Started |

---

## Known Intentional Limitations

| Feature | Tier Required | Why Not Included | Risk / Impact | Mitigation |
|---------|--------------|-----------------|--------------|------------|
| HUD element repositioning | Comprehensive | The battle HUD layout is part of the readable-in-one-turn staging and shares the sprite texel grid (ADR-0008 §9); repositioning would need a layout system for a solo team | Players using eye-gaze or with reduced peripheral vision may find some HUD corners hard to scan | Text scale enlarges all HUD text; critical values are grouped; re-evaluate after the battle HUD UX spec |
| Difficulty assist modes | Comprehensive | Not designed; combat balance (Stats & Damage) is still being tuned | Players with cognitive or motor fatigue may find boss fights long | Free unlimited Retry; untimed turns; OQ-3 tracks a damage-taken slider |
| Mono audio | Comprehensive | The Audio Manager is not designed | Players with single-sided deafness may miss stereo-panned cues | No information is audio-only (the visual-equivalent rule), so nothing is lost; add with the Audio Manager |
| Full subtitle customization (font, color, position) | Exemplary | Scope; one pixel font and fixed window art | Players with dyslexia or specific legibility needs | Text scale up to 1.5; opaque high-contrast windows; revisit post-launch |
| High contrast mode | Exemplary | Scope | Low-vision players on busy diorama scenes | Menus and dialogue are already opaque flat windows; actor contrast ≥ 3:1 is enforced |
| Mouse-only overworld play | Standard (input) | The overworld has no click-to-move: movement is the `move` vector from keys, stick or d-pad (`input-system.md` rule 3; Overworld GDD) | A player who can only operate a pointer cannot walk the overworld | Menus, battle and dialogue are fully pointer-operable; keyboard-only and gamepad-only play are complete; a one-handed keyboard layout is considered at the Vertical Slice remap |
| Nintendo confirm/cancel convention in MVP | Standard (input) | The "swap confirm/cancel" setting ships with the Vertical Slice remap screen (`input-system.md` rule 8) | Nintendo-pad players get south = confirm until then | Steam Input's "Nintendo button layout" option; the Vertical Slice swap defaults to on for Nintendo pads |
| Haptic alternatives | Exemplary | Scope | Deaf players relying on rumble | No information is audio-only |
| External accessibility audit | Exemplary | Budget (solo, premium indie) | Blind spots in self-auditing | Internal test plan plus the CVD and motor playtests above |
| Independent HUD vs. menu scaling | Standard (UI scaling row) | A separate HUD scale would break the shared UI/sprite pixel grid (ADR-0008 §9) | Players who want only HUD text larger | A single text scale applies to both |

---

## Audit History

| Date | Auditor | Type | Scope | Findings Summary | Status |
|------|---------|------|-------|-----------------|--------|
| 2026-10-22 | Internal — ux-designer (`/ux-design accessibility`) | Initial commitment | Tier selection and a requirements baseline against the 7 designed GDDs and ADR-0003/0005/0008/0009/0013 | Standard tier committed. Already designed: comfort settings, flash gate, shape-backed faction color, actor contrast, native focus, accidental-press guard, text scale. Open: colorblind UI palette, screen-reader decision (OQ-1), Deck legibility, volume sliders | Committed |

---

## External Resources

| Resource | URL | Relevance |
|----------|-----|-----------|
| WCAG 2.1 (Web Content Accessibility Guidelines) | https://www.w3.org/TR/WCAG21/ | Contrast (1.4.3, 1.4.11), resize (1.4.4), three flashes (2.3.1) — the flash gate's definitions |
| Game Accessibility Guidelines | https://gameaccessibilityguidelines.com | Game-specific checklist by category and cost |
| AbleGamers Player Panel | https://ablegamers.org/player-panel/ | User testing with disabled gamers (motor and CVD playtests) |
| Colour Blindness Simulator (Coblis) | https://www.color-blindness.com/coblis-color-blindness-simulator/ | CVD simulation on screenshots |
| Color Oracle | https://colororacle.org/ | Full-screen CVD simulator, named in the art bible §4 |
| AccessKit | https://accesskit.dev/ | The accessibility layer behind Godot 4.5+ `Control` accessibility |
| Accessible Games Database | https://accessible.games | Research and examples |

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| OQ-1. Commit to a full menu screen-reader pass (NVDA/Orca announcements, focus order, live regions) — Comprehensive's headline feature — or keep only the AccessKit groundwork? Pending since 2026-10-22 (ADR session log: "screen-reader commitment left PENDING (user/CD)"). | User / creative-director | Before the first UI story (battle HUD) | Unresolved |
| OQ-2. Is the Steam Deck's 2× UI factor (8 logical px menu text = 16 physical px on a 7" screen) legible at handheld distance at text scale 1.0, or should the Deck default to scale 1.25? | ux-designer + producer (hardware test) | Battle HUD UI story | Unresolved |
| OQ-3. Add a granular assist (damage taken / dealt slider) beyond free Retry? | systems-designer (Stats & Damage owner) | Before Vertical Slice | Unresolved |
| OQ-4. Does `AccessibilityLiveMode` announce HP changes and replay beats usefully, or is a battle-log text view needed for screen-reader users? Depends on OQ-1. | ui-programmer | With OQ-1 | Unresolved |
| OQ-5. Brightness slider: confirm it can apply after the flash gate's luminance evaluation without breaking ADR-0005's SDR and pipeline-warm-up rules (it may need a canvas-layer approach rather than an `Environment` adjustment). | technical-artist | Settings screen story (Vertical Slice) | Unresolved |
| OQ-6. Player journey map (`design/player-journey.md`) does not exist; author it from `.claude/docs/templates/player-journey.md` to ground per-screen accessibility context. | ux-designer | Pre-Production | Unresolved |
