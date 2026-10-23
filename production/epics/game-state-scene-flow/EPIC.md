# Epic: Game State & Scene Flow

> **Layer**: Foundation
> **GDD**: design/gdd/game-state-scene-flow.md
> **Architecture Module**: Game State & Scene Flow (`GameStateMachine`, `GameRoot`, `ModeHost`, `OverlayHost`, the Content Error scene)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories game-state-scene-flow`

## Overview

Game State is the traffic controller. It decides which mode the game is in (Boot,
Content Error, Title, Overworld, Battle, Camp) and which overlays sit on top (Menu,
Dialogue, Defeat Prompt). It performs every transition between them, and the player
feels it as "snap in, snap out, never lost". ADR-0002 splits it into a pure
`RefCounted` `GameStateMachine`, driven only by `tick(delta)` with injected
collaborators, and a thin scene-tree shell: the persistent `GameRoot` main scene,
with `ModeHost` and `OverlayHost` doing child swaps.

This epic follows ADR-0002's Migration Plan in three steps:
- **Step 1: the machine, headless.** The mode/overlay state, the transitions table, OUT → SWAP → IN with input lock and rollback, the six ordered signals, Retry/Retreat and the Defeat Prompt flow, Boot/Content Error, the Menu time-stop, focus-loss Menu, and the §11 in-mode fade and `register_camp`. All of it is tested against a stub loader, a stub presenter and a **synthetic `ActionSource`**, so this step runs in parallel with `input-system`.
- **Step 2: the shell and the ChapterFlow hand-over** (the critical-path risk; the producer asks for at least three stories):
  1. **Strip ChapterFlow.** `src/chapters/chapter_flow.gd` keeps only encounter sequencing, losing battle construction and retry (ADR-0002 §8).
  2. **Battle mode.** It wraps `BattleCore` and `BattleHud` and provides `capture_start_snapshot`/`restore_start_snapshot`.
  3. **GameRoot as the main scene.** `GameRoot` becomes the main scene, with `ContentBootstrap.run()` in `_enter_tree()` (ADR-0004), the Content Error scene and the `TransitionConfig` data. The demo `chapter_flow_demo` is **rewritten to run under Game State**, not deleted (decision 2026-10-23, the reversible option; the user may override).
- **Step 3: remove the interim validation flag.** Delete `validate_enemy_ids_against_catalog = false` once `content-migration` is done.

**Owned here, not in the content epics.**
- `GameRoot` (the composition root's scene).
- The Content Error **scene** (`content-catalog` defines only the error-report format).
- The flash-gate booking of transition flashes (ADR-0005 §12, via the injected `FlashGate`).

**Risks.**
- **Step 2 size.** It is the largest piece of work in the layer.
- **AnimationPlayer freeze.** Whether an `AnimationPlayer` freezes under a disabled `ModeHost` is an open ADR-0002 verification item, confirmed in Step 1.
- **Focus notification.** The focus-loss notification is unverified (ADR-0003).
- **Flee.** Its *design* section in `turn-battle-system.md` is still owed. Game State carries only the Fled outcome (`battle_fled`, ADR-0010 §5).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0002: Game State & Scene Flow (incl. §11) | Pure `GameStateMachine` + `GameRoot` shell, child swap under `ModeHost`, freeze by detach, Retry by snapshot, in-mode fade and `register_camp` | MEDIUM |
| ADR-0004: Content Boot Ordering | `GameRoot._enter_tree()` runs `ContentBootstrap.run()`; Boot waits for Ready | LOW |
| ADR-0005: Sprite & Camera Presentation (§12) | Transition flashes booked through `FlashGate`; capped variants | LOW |
| ADR-0006: Battle Replay Ownership | Outcome reported only after the replay's last beat | LOW |
| ADR-0009: Save/Load & Settings | Save-safety query and the composite `pre_setup` injector hooks | LOW |
| ADR-0010: Turn Battle System (§5) | Fled outcome (`battle_fled`) and `BattleEntryPayload` → `BattleFactory` | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-gamestate-001 | One mode plus an overlay stack via the four entry points; six ordered signals, except the in-mode fade | ADR-0002 (§11) ✅ |
| TR-gamestate-002 | One transition at a time, input locked out-to-in, rollback on a failed swap | ADR-0002 ✅ |
| TR-gamestate-003 | Freeze and restore the Overworld around Battle; Encounter descriptor validated before entry | ADR-0002, ADR-0012 ✅ |
| TR-gamestate-004 | Retry from the start snapshot with no load; Retreat to the last camp registered | ADR-0002 ✅ |
| TR-gamestate-005 | Boot waits for the catalog; Failed → terminal Content Error | ADR-0002, ADR-0004 ✅ |
| TR-gamestate-006 | Timings from data; injectable clock and loader; Menu stops mode time; overruns logged | ADR-0002 ✅ |
| TR-gamestate-007 | Transition flashes booked through the flash gate | ADR-0002 §7, ADR-0005 §12, ADR-0008 §8 ✅ |

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/game-state-scene-flow.md verified (AC-26 on the GTX 1080-class PC and the Steam Deck)
- Logic and Integration stories have passing tests in the test root; tests assert no orphan nodes
- UI stories have retained screenshots in `production/qa/evidence/` (Title, Defeat Prompt, Quit confirmation, Menu over the Defeat Prompt, Content Error)
- The MVP battle loop still plays end to end under Game State (the rewritten demo)
