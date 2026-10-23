# Story 014: Synthetic joy names map to `xbox`, `playstation`, `nintendo`, `xbox` for Steam Virtual Gamepad and Steam Deck, and `generic` otherwise

> **Epic**: Input System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Input System — Event Resolution, Bindings Data and GUI Integration (§4 `pad_style_patterns`, Risks: SDL3 names); ADR-0008: UI Framework (§4, glyph consumer)
**ADR Decision Summary**: `pad_style` (`xbox`/`playstation`/`nintendo`/`generic`) is resolved from the active pad's joy name through `InputConfig.pad_style_patterns`, a project config of case-insensitive `"substring:style"` rows where the first match wins; `generic` is the safe fallback.
**ADR Version**: ADR-0003 2026-10-21; ADR-0008 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `Input.get_joy_name()` contents under the 4.5+ SDL3 driver are unverified (ADR-0003 Verification item 4). The manifest advisory E9, "Steam Input on the native Linux Deck shows 'Steam Virtual Gamepad'", is not yet folded into ADR-0003.

**Control Manifest Rules (this layer)**:
- Required: "**Bindings are a catalog record** (`bindings_` prefix); **tuning values** (deadzone, repeat timing, `pointer_switch_px`, pad-style patterns) are a project config (`InputConfig`), not a catalog record"
- Engine Verification Required: "⚠️ **Real Xbox/PlayStation/Nintendo pad names under SDL3 are not yet verified** (needs hardware); `generic` is the safe fallback"
- Engine Verification Required: "⚠️ **Steam Input on the native Linux Deck shows "Steam Virtual Gamepad"** (advisory, not yet folded in, E9): `pad_style` needs a Deck/Steam row"

---

## Acceptance Criteria

*From GDD `design/gdd/input-system.md`, scoped to this story:*

- [ ] **AC-12** Parametrized over synthetic device events carrying a joy name (no physical controller attached): a known Xbox name → `xbox`, a known PlayStation name → `playstation`, a known Nintendo name → `nintendo`, "Steam Virtual Gamepad" and a Steam Deck name → `xbox`, an unrecognized name → `generic`. Real-hardware names are a manual verification item (ADR-0003), not this AC.

---

## Implementation Notes

*Derived from ADR-0003 §4 and Risks:*

- **Where the joy name comes from (pinned).** Godot input events carry no joy name. The name enters through `on_joy_connection(device, true, joy_name)`: the shell passes `Input.get_joy_name(device)`. The resolver stores device → joy name. When that pad becomes active (a meaningful press from that device follows), `pad_style` is resolved from it. A pad that sends input without any `on_joy_connection` call gives `generic`.
- **Patterns.** `pad_style_patterns: PackedStringArray` of `"substring:style"` entries, matched **case-insensitively** against the joy name. The style vocabulary is `xbox | playstation | nintendo | generic`.
- **Default patterns.** Include Xbox (`xbox`), PlayStation (`playstation`, `dualsense`, `dualshock`, `ps4`, `ps5`), Nintendo (`nintendo`, `switch`, `pro controller`, `joy-con`), and **Steam/Deck rows** (`steam virtual gamepad:xbox`, `steam deck:xbox`). GDD rule 4 (2026-10-23 design review) mandates that "Steam Deck ... reports `xbox`". That resolves manifest advisory E9. Note in Completion Notes that ADR-0003 §4 needs an annotation for the Deck/Steam row.
- **Matching.** Pattern order is significant: the first match wins.
- **Expected styles are literals (pinned).** The style a name maps to **is** the requirement, so it is a literal fixture, never computed by running the matcher over the config (that would be tautological). Expected styles live in `tests/unit/input/fixtures/joy_names.gd`:

  | Joy name | Style |
  |---|---|
  | `"Xbox Series X Controller"` | `xbox` |
  | `"XBOX 360 CONTROLLER"` (case) | `xbox` |
  | `"DualSense Wireless Controller"` | `playstation` |
  | `"PS4 Controller"` | `playstation` |
  | `"Nintendo Switch Pro Controller"` | `nintendo` |
  | `"Steam Virtual Gamepad"` | `xbox` |
  | `"Steam Deck Controller"` | `xbox` |
  | `"Acme USB Pad"` | `generic` |
  | `""` | `generic` |

  The non-default case uses a literal pattern list (e.g. `["acme:nintendo"]`) with literal expectations. The fixture names are synthetic stand-ins; real SDL3 names are the deferred manual item below.
- **Manual verification (deferred, logged in `production/qa/evidence/`).** Real Xbox, PlayStation, Nintendo and Steam Deck hardware names under SDL3 are checked by hand when hardware is available (the epic's Definition of Done item). This is not part of this story's automated done gate and does not block it. If a real name falls through to `generic`, add a pattern row and log the observed name.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 015: which of two pads sets the style.
- Story 025: the shell's `joy_connection_changed` → `on_joy_connection` wiring.
- UI Framework epic: glyph selection from `pad_style` (ADR-0008 §4).

---

## Files

- `src/input/input_resolver.gd` (`pad_style` getter, joy-name matcher)
- `src/input/input_config.gd` (`pad_style_patterns` default)
- `data/config/input_config.tres`
- `tests/unit/input/fixtures/joy_names.gd`
- `tests/unit/input/input_pad_style_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, fixes applied: hand-written literal joy-name fixture, joy name enters through `on_joy_connection`). The developer implements against these — do not invent new test cases during implementation.*

**AC-12** — synthetic joy names map to the expected pad styles.

```
Test: joy names map to pad styles
Given: R with DEFAULT; for each fixture row, on_joy_connection(0, true, name)
When:  feed pad south on device 0
Then:  rec holds active_device_changed(GAMEPAD, expected_style) and pad_style == expected_style
Edge cases:
  - matching is case-insensitive (the XBOX row)
  - first match wins: a name matching two patterns takes the earlier row's style (fixture: a custom list ["pad:generic", "acme:nintendo"] with "Acme Pad" gives generic)
  - the non-default pattern list maps "Acme USB Pad" to nintendo
  - a pad that sends input without any on_joy_connection call gives generic
DEFERRED: real Xbox, PlayStation, Nintendo and Steam Deck hardware names under SDL3; manual, logged to production/qa/evidence/
```

**Manual verification (deferred, logged in `production/qa/evidence/`):** connect each real pad (Xbox, PlayStation, Nintendo, Steam Deck / Steam Virtual Gamepad) to a 4.7.2 build, record `Input.get_joy_name(device)` and the resolved `pad_style`, and log the result in `production/qa/evidence/`. Pass condition: each pad resolves to its named style (Deck and Steam Virtual Gamepad → `xbox`).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/input/input_pad_style_test.gd` — must exist and pass. Gate level: BLOCKING.
- Manual (deferred, not part of the done gate): real-hardware joy-name log in `production/qa/evidence/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/input-system/story-012-active-device-changed.md`
- Unlocks: `production/epics/input-system/story-015-first-pad-sets-style.md`
