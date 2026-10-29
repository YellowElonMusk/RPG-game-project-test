# Story 007: Battle command menu — pick Attack, Defend or a special, then a target

> **Epic**: Go back to your planet!
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: N/A (epic is minimal tier — no control manifest)
> **Last Updated**: 2026-10-29 (implemented, awaiting /story-done)

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 1 — "Battle core: turn-based combat with Attack,
Defend, specials, MP, win/lose and retry." Story 001 built the core and story 005
the display-only HUD. Neither gave the player a way to choose a move, so the game
booting under `GameRoot` (game-state-scene-flow story 035) reaches a battle the
player cannot act in. This story closes that gap.

**ADR Governing Implementation**: N/A for this epic's tier. The Game State epic's
ADRs constrain it, though: input reaches Battle mode only through
`GameMode.handle_action()` (ADR-0002), action names come only from `InputActions`
(ADR-0003), and focus navigation uses the INTERIM `InterimFocusNav` helper until
ADR-0008's `FocusScope`/`UiNavigator` exist (same tag as `DefeatPrompt`, story 030).

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM

**Reference**: `prototypes/battle-concept/battle.gd` (`_show_chooser`, `_set_targeting`,
`_on_target`) proved the flow: a command list for the active squad member, then a
target pick for moves that need one. It is throwaway code, so match its behaviour
without importing it.

---

## Acceptance Criteria

- [ ] **AC-1** On each squad turn, a command menu for the active combatant lists
      Attack, Defend and that combatant's specials, each with its MP cost. A
      special the active faction rule currently forbids (`specials_allowed()` /
      `move_allowed()`), or that the combatant cannot afford, is shown disabled
      with the reason. Choosing a move that needs a target (single enemy or single
      ally) moves to a target pick among the living valid targets. Confirming
      submits the action through `BattleCore.submit_action()`; cancel during the
      target pick returns to the command list. The menu hides outside
      `SQUAD_TURN`, and while Victory waits for its results confirm. Every step
      works by keyboard/pad (`InputActions` via `handle_action()`) and by mouse.
      The battle party is the four squad characters from `data/characters/`
      (Karen, Michelin Chef, Florida Man, Baguette Thrower), each with their
      specials, replacing the "Hero A"/"Hero B" placeholder squad.

---

## Implementation Notes

- **Where it lives.** `src/battle/ui/battle_command_menu.gd` and `.tscn`, a child of
  `battle_mode.tscn` next to `%BattleHud`. `BattleMode.handle_action()` forwards
  actions to the menu while it is visible. The existing results-done confirm keeps
  priority while Victory is pending.
- **Reads, never owns, battle state.** The menu reads
  `BattleCore.get_active_combatant()`, `get_living_enemies()`, `get_living_squad()`,
  `round_number`, `faction_rule` and `state`. It listens to `turn_started` /
  `battle_ended` to rebuild or hide itself, and writes only through
  `submit_action()`.
- **Move list per combatant.** `src/battle/squad/squad_moves.gd` (`SquadMoves`):
  `static func moves_for(combatant: Combatant) -> Array[Move]` returns Attack, Defend
  and the combatant's specials. Specials come from an INTERIM table of `move_id` →
  `SquadSpecials` factory (`move_speak_to_the_manager` → `make_speak_to_the_manager()`,
  and so on for all five). The table is keyed on the `move_ids` of the character
  record the combatant was built from. Tag it `TODO(content-migration)`:
  content-migration story 028 (squad specials adapter) replaces it with
  record-driven moves.
- **The real squad.** `ChapterMode._default_squad()` builds its combatants from the
  four `char_*` records (stats from the records, never literals in code), read
  through the `ContentCatalog` autoload via the main loop, as `GameRoot.catalog()`
  does. It keeps each combatant's record id so `SquadMoves` can look up its
  `move_ids`. Combatant order is the records' sorted id order.
- **Disabled reasons** use the faction rule's existing text hooks, plus a plain
  "Not enough MP (needs N)". Write no per-faction branches in the menu.
- **Focus:** the command list opens with Attack focused. The target pick opens on
  the first valid target. Navigation goes through `InterimFocusNav`, and buttons
  get explicit focus neighbours, because headless geometric focus search proved
  unreliable in story 031.
- No numeric gameplay literals in the menu. Costs and power come from `Move`.

---

## Out of Scope

- Item use (brief: out of scope for the MVP), Flee (Fled wiring is owed separately,
  story 016's note), and any final art. Placeholder panels are fine.
- Record-driven squad specials (content-migration story 028) and enemy roster
  records (content-migration story 029).
- Enemy turn presentation and pacing (ADR-0006's `BattleReplayController`). Enemy
  turns still resolve synchronously inside `submit_action()`.

---

## Files

- `src/battle/ui/battle_command_menu.gd`, `src/battle/ui/battle_command_menu.tscn`
- `src/battle/battle_mode.gd`, `src/battle/battle_mode.tscn`
- `src/battle/squad/squad_moves.gd`
- `src/chapters/chapter_mode.gd` (squad built from character records)
- `tests/unit/battle/battle_command_menu_test.gd`
- `tests/unit/battle/squad_moves_test.gd`
- `production/qa/evidence/story-007-battle-command-menu/` (screenshots)

---

## QA Test Cases

*No qa-lead specs at this tier; derived from AC-1.*

- **`squad_moves_test.gd`**:
  - `moves_for()` returns Attack, Defend and exactly the record's specials for each
    of the four characters (Chef has two).
  - An enemy or unknown combatant gets Attack and Defend only.
- **`battle_command_menu_test.gd`**, a real `BattleCore` with the real squad and a
  Bureaucratia Clerk:
  - On `SQUAD_TURN` the list shows the active combatant's moves with costs.
  - Specials are disabled in round 1 under Bureaucratia's permit ban, with the
    rule's reason.
  - Confirm on Attack, then confirm on the first enemy, calls `submit_action()` and
    the enemy's HP drops.
  - Cancel in the target pick returns to the list, with no action submitted.
  - Defend submits with no target pick.
  - The menu is hidden after `battle_ended`.
  - An unaffordable special is disabled with the MP reason.

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- Unit tests above, which must pass (`qa.level: standard`).
- Retained screenshots in `production/qa/evidence/story-007-battle-command-menu/`:
  the command list on a squad turn (specials disabled by the permit), and the
  target pick.
- **Not waived** — UI evidence is never advisory.

**Status**: [x] Created and passing (2026-10-29: squad_moves_test.gd + battle_command_menu_test.gd; full suite 594/594). Screenshots retained: production/qa/evidence/story-007-battle-command-menu/01-command-list.png, 02-target-pick.png (stamped).

---

## Dependencies

- Depends on: `production/epics/go-back-to-your-planet/story-001-battle-core.md`,
  `story-003-squad-specials.md`, `story-005-battle-hud.md`;
  `production/epics/game-state-scene-flow/story-034-battle-mode-wraps-battle-core.md`,
  `story-035-game-root-main-scene.md`; `production/epics/content-migration/story-018-author-squad-special-moves.md`
  (the `char_*` records)
- Unlocks: a human-playable chapter (the first real playtest)

---

## Completion Notes

*2026-10-29, implementation (autonomous run). The implementing agent ran out of turns twice without reporting; the main session verified the work, fixed two visible defects, captured the evidence and wrote these notes.*

- **Files**:
  - `src/battle/squad/squad_moves.gd` (`SquadMoves.moves_for()`: Attack, Defend, plus specials from an interim `move_id` → `SquadSpecials` table tagged `TODO(content-migration)` for story 028);
  - `src/battle/combatant.gd` (an interim `move_ids` field, empty for enemies and record-less test squads);
  - `src/battle/ui/battle_command_menu.gd`/`.tscn`;
  - `src/battle/battle_mode.gd`/`.tscn` (the menu sits next to `%BattleHud`; the Victory results confirm keeps priority);
  - `src/chapters/chapter_mode.gd` (the party is built from the four `char_*` records in sorted id order);
  - `tests/unit/battle/squad_moves_test.gd`, `tests/unit/battle/battle_command_menu_test.gd`.
- **Fixes made by the main session after looking at a windowed run**:
  1. **No visible focus**: `grab_focus()` silently does nothing when the menu rebuilds on `turn_started` before it is in the tree, so keyboard and pad players saw no selection. Focus is now grabbed immediately when the menu is in the tree and again deferred (`_grab_focus_now_and_deferred()`).
  2. **Overlap**: the command panel overlapped the bottom of the fourth squad card, so its top edge moved from -220 to -200.
- **Run result**: OBSERVED. `01-command-list.png` shows Baguette Thrower's turn: Attack focused, Defend, and Home Run disabled with the Bureaucratia permit reason. `02-target-pick.png` shows Confirm on Attack opening the target pick with the Clerk focused. The captures were made with a scratch `-s` script that boots `chapter_flow_demo.tscn -- --stop-at=0` and sends one Confirm.
- **Advisory**:
  - The disabled reason repeats the whole banner text, which is verbose.
  - "(MP 0)" is shown on Attack and Defend.
  - Moves are still resolved through `SquadSpecials` factories, not records (content-migration 028).
  - Enemy turns resolve instantly inside `submit_action()`, so the player sees only the end state of each round (ADR-0006 replay pacing).
