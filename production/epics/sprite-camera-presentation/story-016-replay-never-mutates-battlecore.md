# Story 016: The replay never mutates BattleCore, and the HUD always shows each combatant's live values

> **Epic**: Sprite & Camera Presentation
> **Status**: Complete (2026-10-30)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Battle Replay Ownership (primary), ADR-0005: Sprite & Camera Presentation (secondary — HUD reads displayed state)
**ADR Decision Summary**: `BattleReplayController` holds a display snapshot after each queued signal and never modifies `BattleCore`; the HUD reads HP, MP, status, round and floating numbers only through the replay's displayed state, which equals each combatant's live values on every released turn and when the queue drains.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: ADR-0006 itself is LOW risk. No post-cutoff API; `combatant_display.gd` is a plain value copy.

**Control Manifest Rules (this layer)**:
- Required: Core never imports Feature: `DioramaStage` and `CharacterSprite` must never reference `BattleReplayController`. The owning mode connects controller signals and passes clocks as `Callable`s — source: ADR-0005
- Forbidden: Never let the HUD read `combatant.hp` directly during a replay — it must read only the replay's displayed snapshot — source: ADR-0006 (Context, Problem Statement)

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- **AC-14 [L]** (P-04) GIVEN any replay driven to completion, THEN no `BattleCore` mutator is called, and every combatant's HP and status are identical before and after the replay. On every released turn, and when the queue drains, the HUD's displayed HP, MP, Defend, stun and Viral Stunt values equal each combatant's live values. That includes after Family Meal, after MegaCorp's per-round bill, on the turn a Defend wears off, and on the turn after a stunned enemy's skipped turn.

---

## Implementation Notes

*Derived from ADR-0006 Summary, Context and Key Interfaces (`combatant_display.gd`):*

- `BattleReplayController` queues every `BattleCore` signal with a display snapshot taken after each one; the queue's job is to hold and release these snapshots, never to call back into `BattleCore`.
- `CombatantDisplay` (a value copy, `src/battle/combatant_display.gd`) is what the HUD actually reads — never `combatant.hp` directly — so the display can lag the queue by exactly the beats still playing.
- The two silent-mutation cases named in ADR-0006's Context — MegaCorp's per-round bill (no outcome emitted) and a stun cleared silently when the stunned enemy's turn is skipped — must still show up correctly in the displayed snapshot at the right point in the replay, even though `BattleCore` changed them with no outcome.
- `turn_started`, `round_advanced` and `battle_ended` are held and released only after every outcome emitted before them has finished its beat (ADR-0006 Requirements).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 015 (`production/epics/sprite-camera-presentation/story-015-battle-replay-plays-beats-in-order.md`): beat ordering, impact timing and animation frames
- Story 017 (`production/epics/sprite-camera-presentation/story-017-move-outcome-shapes-match-the-table.md`): per-move pose/reaction/number/punch shape

---

## Files

- `src/battle/battle_replay_controller.gd`
- `src/battle/combatant_display.gd`
- `tests/unit/presentation/battle_replay_hud_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/presentation/battle_replay_hud_test.gd` — must exist and pass

**Status**: [x] Created and passing (2026-10-30): 1/1

---

## Dependencies

- Depends on: `BattleReplayController` (ADR-0006, no epic yet), `production/epics/sprite-camera-presentation/story-015-battle-replay-plays-beats-in-order.md`
- Unlocks: `production/epics/sprite-camera-presentation/story-017-move-outcome-shapes-match-the-table.md`

---

## Completion Notes

Snapshots (CombatantDisplay copies of every combatant plus round) are recorded at all four BattleCore emissions and released at beat_finished / marker release; the controller never calls a BattleCore mutator. Test drives a real seeded BattleCore (MegaCorp billing, Karen Defend then Speak to the Manager, Chef Family Meal) and checks display == live on every released TURN and on drain, live state unchanged by the replay, and a lagging HP mid-replay. HUD rewiring (BattleHud reading get_display) is not done: no BattleHud change was in scope.

**Files**: src/battle/battle_replay_controller.gd, src/battle/beat_plan.gd, src/battle/combatant_display.gd, src/battle/replay_input_router.gd, tests/unit/battle/helpers/replay_test_kit.gd, tests/unit/presentation/battle_replay_hud_test.gd
