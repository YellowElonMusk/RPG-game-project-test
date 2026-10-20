# Test Evidence: Battle HUD — bars, rule banner, floating numbers, tooltips

> **Story**: `production/epics/go-back-to-your-planet/story-005-battle-hud.md`
> **Story Type**: UI
> **Date**: 2026-10-20
> **Tester**: Claude (orchestrating session), solo mode
> **Build / Commit**: uncommitted working tree, story-005 implementation

---

## What Was Tested

The real battle HUD (`src/battle/ui/battle_hud.gd`/`.tscn`): HP/MP bars per combatant,
a rule banner driven by the active `FactionRule`'s text/color, floating damage/heal
numbers, hover tooltips, and knocked-out card styling — rendered against both
Bureaucratia and MegaCorp to confirm neither is hardcoded into the HUD. Captured via
`godot --write-movie` launching `src/battle/ui/battle_hud_demo.gd`/`.tscn`, a
`--state=`-driven scaffold built for this evidence pass (not shipped gameplay).

**Acceptance criteria covered**: AC1–AC7 (all criteria in the story).

---

## Acceptance Criteria Results

| # | Criterion (from story) | Result | Notes |
|---|----------------------|--------|-------|
| AC1 | Every squad member's current and max HP shown as a bar | PASS | Visible in all 5 captures |
| AC2 | Every squad member's current and max MP shown as a bar | PASS | Visible in all 5 captures (enemy cards correctly omit an MP bar — enemies have 0 max MP) |
| AC3 | Banner shows the active faction's rule and updates with its state | PASS | `02` vs `03` show the same Bureaucratia banner changing text and color (red → amber) as the round crosses `PERMIT_ROUNDS`; `04` shows MegaCorp's distinct billing banner |
| AC4 | Damage/heal amounts appear as floating numbers near the affected combatant | PASS | `01` shows a floating "-8" above the Clerk card from a staged Attack. First capture attempt showed nothing — traced to a demo-script timing bug (the staged action ran before Godot's first layout pass, so the float spawned off-screen from a stale `global_position`), fixed by deferring two frames in `battle_hud_demo.gd`; re-captured and confirmed visible. |
| AC5 | Hovering a card/control shows a tooltip explaining the rule | PASS (checked by looking, not screenshot) | A live mouse-hover state cannot be produced by a non-interactive `--write-movie` capture, and the story's own Required Evidence list does not ask for one. Verified instead by code: `battle_hud.gd`'s `_card_tooltip()`/`_refresh_banner()` set `tooltip_text` from `faction_rule.get_tooltip_text()`/`get_combatant_tooltip_note()`, confirmed independently by both the GDScript API review and the UI architecture review. |
| AC6 | Both factions' rules correctly reflected, not just one | PASS | `battle_hud.gd` contains zero `is BureaucratiaRule`/`is MegaCorpRule` branches (verified by direct inspection in two independent reviews); `02`/`03` (Bureaucratia) and `04` (MegaCorp) each render their own distinct banner text/color/identity color through the same code path |
| AC7 | A knocked-out combatant's card visibly differs from a living one | PASS | `05` shows Hero A dimmed (lower modulate) with "KNOCKED OUT" replacing its HP/MP line, beside a normal, undimmed Hero B |

---

## Screenshots

All captured at 1152×648 (the project's unset-viewport default; `--resolution 1280x720` sizes only the window) via `godot --path . --windowed --resolution 1280x720 --write-movie <path> --quit-after <N> res://src/battle/ui/battle_hud_demo.tscn -- --state=<state>`. Filenames below are each capture's last frame.

| # | Filename | What It Shows | Acceptance Criterion |
|---|----------|--------------|----------------------|
| 1 | `01-normal-battle00000039.png` | Fresh Bureaucratia battle, HP/MP bars, pending-permit banner, a floating "-8" damage number mid-animation above the Clerk | AC1, AC2, AC4 |
| 2 | `02-permit-pending00000014.png` | Bureaucratia banner, round 1: red, "permit arrives in 3 rounds" | AC3 |
| 3 | `03-permit-granted00000014.png` | Bureaucratia banner, round forced past `PERMIT_ROUNDS`: amber, "PERMIT GRANTED — All-out war!" | AC3 |
| 4 | `04-megacorp-billing00000014.png` | MegaCorp banner (cyan identity color), billing rule text, MegaCorp's own enemy roster (Security Drone/Middle Manager/CEO) | AC3, AC6 |
| 5 | `05-knockout00000014.png` | Hero A dimmed and marked "KNOCKED OUT", Hero B normal | AC7 |

---

## Test Conditions

- **Game state at start**: fresh `BattleCore` constructed directly in the demo scaffold (2 squad members, that faction's 3-enemy roster), no save/menu involved
- **Platform / hardware**: Windows 11, NVIDIA GeForce RTX 4080 SUPER, Vulkan 1.4.351 Forward+
- **Framerate during test**: fixed 60 FPS (Movie Maker mode)
- **Special setup**: `src/battle/ui/battle_hud_demo.gd`/`.tscn`, a launch scaffold built for this story's evidence capture (not part of the shipped game) — reads `--state=`/`--faction=` to reach each required state with no interaction

---

## Observations

- The demo scaffold's "normal" state initially failed to show its floating number (see AC4 above) — a genuine, now-fixed bug in the scaffold's timing, not in `battle_hud.gd` itself. Flagging because it's a real Godot gotcha (Control rects are invalid until the first layout pass) worth remembering for any future same-frame UI+action scaffolding.
- Two independent specialist reviews (GDScript API correctness, UI/scene architecture) both ran clean — no blocking findings. One non-blocking architecture note: the squad/enemy columns don't expand to fill the 1280-wide layout, leaving an empty right-of-center gap; worth a look if a center panel (log, portraits) is planned for a later pass, but not a defect against this story's acceptance criteria.
- Accent colors (`#D23A2E` Bureaucratia red, `#19C2D6` MegaCorp cyan) are reused from the prototype's cited art-bible values, not a fresh art-director deliverable for this HUD specifically.
- Tooltips are mouse-hover only; no gamepad/keyboard-focus equivalent exists yet. No reduced-motion gating on the floating-number tween (short, decorative, no information conveyed exclusively through motion).

---

## Sign-Off

Solo project — no separate art-director/designer exists yet. Reviewed and approved
by the orchestrating session itself (opened and visually inspected each of the 5
screenshots above against its acceptance criterion), consistent with this
project's `review_mode: solo` ("self, no independent review" — the same standing
this session's `/story-done` runs have used throughout). Not a claim that the
user personally reviewed these images.

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Lead (self-review, solo mode) | Claude (orchestrating session) | 2026-10-20 | [x] Approved |

---

*Template: `.claude/docs/templates/test-evidence.md`*
