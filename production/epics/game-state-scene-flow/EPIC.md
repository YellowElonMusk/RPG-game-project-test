# Epic: Game State & Scene Flow

> **Layer**: Foundation
> **GDD**: design/gdd/game-state-scene-flow.md
> **Architecture Module**: Game State & Scene Flow (`GameStateMachine`, `GameRoot`, `ModeHost`, `OverlayHost`, the Content Error scene)
> **Status**: Ready
> **Stories**: 41 (36 Ready, 5 Blocked) — see the table below

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

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Overworld → Battle fires exactly the four transition signals, once each, in order](story-001-overworld-to-battle-signal-order.md) | Logic | Ready | ADR-0002 |
| 002 | [Every row of the Modes transitions table succeeds from its source mode](story-002-transition-table-rows-succeed.md) | Logic | Ready | ADR-0002, ADR-0012 |
| 003 | [Every from → to pair not in the transitions table is rejected](story-003-invalid-pairs-rejected.md) | Logic | Ready | ADR-0002 |
| 004 | [Boot goes to Title on a Ready catalog and to Content Error on a Failed one](story-004-boot-to-title-or-content-error.md) | Logic | Ready | ADR-0002, ADR-0004 |
| 005 | [Content Error rejects every request except Quit and ignores focus loss](story-005-content-error-rejects-all-but-quit.md) | Logic | Ready | ADR-0002 |
| 006 | [transition_time sums the three phases, and a budget below t_out + t_in logs an error](story-006-transition-time-and-budget-check.md) | Logic | Ready | ADR-0002 |
| 007 | [A slow swap makes the in phase wait and logs a performance warning](story-007-slow-swap-waits-and-warns.md) | Logic | Ready | ADR-0002 |
| 008 | [A running transition rejects any other transition or overlay request](story-008-busy-transition-rejects-requests.md) | Logic | Ready | ADR-0002 |
| 009 | [Of two same-frame transition requests, the first is accepted and the second rejected](story-009-same-frame-requests-first-wins.md) | Logic | Ready | ADR-0002 |
| 010 | [Input during out, swap and in reaches nobody; the first action after transition_finished is delivered](story-010-input-locked-during-transition.md) | Logic | Ready | ADR-0002, ADR-0003 |
| 011 | [Quit during a transition calls the quit hook once, after transition_finished](story-011-quit-waits-for-transition.md) | Logic | Ready | ADR-0002 |
| 012 | [A failed swap returns to the source mode with frozen state restored and input unlocked](story-012-failed-swap-rolls-back.md) | Logic | Ready | ADR-0002, ADR-0009, ADR-0010 |
| 013 | [An invalid Encounter descriptor keeps the game in the Overworld and logs an error](story-013-invalid-descriptor-stays-in-overworld.md) | Logic | Ready | ADR-0002 |
| 014 | [Overworld → Battle → Overworld restores every field of the Overworld snapshot](story-014-overworld-snapshot-exact-restore.md) | Logic | Ready | ADR-0002 |
| 015 | [After Victory, the return to the Overworld starts only after the results screen is done](story-015-victory-waits-for-results.md) | Logic | Ready | ADR-0002, ADR-0010 |
| 016 | [Fled on a descriptor with can_flee = false is rejected and the battle continues](story-016-fled-rejected-when-not-allowed.md) | Logic | Ready | ADR-0002, ADR-0010 |
| 017 | [Defeat opens the Defeat Prompt, and Retry restores the starting snapshot with zero scene loads](story-017-defeat-prompt-and-retry-snapshot.md) | Logic | Ready | ADR-0002, ADR-0005 |
| 018 | [The Defeat Prompt offers Retreat only when retreat_allowed, with no stale flag after Retry](story-018-retreat-offer-no-stale-flag.md) | Logic | Ready | ADR-0002 |
| 019 | [Repeated Retry inputs during the Retry transition cause exactly one restart](story-019-repeated-retry-one-restart.md) | Logic | Ready | ADR-0002 |
| 020 | [A camp registered by walking past becomes the last camp registered; outside writes are rejected](story-020-register-camp-and-retreat-to-it.md) | Logic | Ready | ADR-0002 §11, ADR-0012 |
| 021 | [Retreat goes to the last camp registered, else the region default camp, else is not offered](story-021-retreat-region-default-and-no-camp.md) | Logic | Deferred | ADR-0002 (annotation owed) |
| 022 | [With Dialogue then Menu stacked, only the Menu gets input, and signals fire in stack order](story-022-overlay-stack-input-and-order.md) | Logic | Ready | ADR-0002 |
| 023 | [Dialogue cannot open over the Menu, but the Menu can open over Dialogue](story-023-dialogue-menu-precedence.md) | Logic | Deferred | ADR-0002 |
| 024 | [The Menu cannot be opened by input during a transition, in Boot or in Content Error](story-024-menu-input-gating.md) | Logic | Ready | ADR-0002 |
| 025 | [The open Menu stops mode time and blocks transitions, but Quit to Title still works](story-025-menu-stops-time-quit-to-title.md) | Logic | Ready | ADR-0002 |
| 026 | [Focus loss or device loss opens the Menu, deferred past a transition and ignored in Boot](story-026-focus-loss-opens-menu.md) | Logic | Ready | ADR-0002, ADR-0003 |
| 027 | [A transition requested by a Dialogue line closes the Dialogue before transition_started](story-027-dialogue-closes-before-transition.md) | Logic | Deferred | ADR-0002 §11 |
| 028 | [The in-mode fade fires only transition_started and transition_finished, and is legal only in a bare Overworld](story-028-in-mode-fade.md) | Logic | Ready | ADR-0002 §11, ADR-0009 |
| 029 | [In Battle the Menu offers only settings and quit](story-029-battle-menu-system-entries.md) | Logic | Ready | ADR-0002 |
| 030 | [The Defeat Prompt opens on Retry, ignores cancel, and gets focus back after the Menu](story-030-defeat-prompt-focus-and-cancel.md) | Logic | Ready | ADR-0002, ADR-0008 |
| 031 | [Title opens on New Game with Continue disabled, and Quit asks for confirmation with No focused](story-031-title-focus-and-quit-confirm.md) | Logic | Ready | ADR-0002, ADR-0008, ADR-0009 |
| 032 | [Pin today's ChapterFlow behaviour in characterization tests](story-032-chapter-flow-characterization.md) | Logic | Ready | ADR-0002 (Step 0) |
| 033 | [Strip ChapterFlow to encounter sequencing and host it in ChapterMode](story-033-strip-chapter-flow-chapter-mode.md) | Logic | Ready | ADR-0002, ADR-0010 |
| 034 | [Battle mode wraps BattleCore and BattleHud and owns the start snapshot](story-034-battle-mode-wraps-battle-core.md) | Integration | Ready | ADR-0002, ADR-0006, ADR-0010 |
| 035 | [GameRoot becomes the main scene, with Content Error, TransitionConfig data, and the demo running under Game State](story-035-game-root-main-scene.md) | Integration | Ready (waiting on dependencies) | ADR-0002, ADR-0004, ADR-0003 |
| 036 | [A Victory that triggers story dialogue opens Dialogue only after transition_finished(Overworld)](story-036-victory-dialogue-after-transition.md) | Integration | Deferred | ADR-0002 |
| 037 | [Every transition type meets its budget over 30 runs on the min-spec PC and the Steam Deck](story-037-transition-budget-hardware-bench.md) | Integration | Blocked | ADR-0002 |
| 038 | [Retained screenshots of Title, both Defeat Prompts, the Quit confirmation and Content Error](story-038-screenshots-title-prompts-error.md) | UI | Ready | ADR-0002, ADR-0008 |
| 039 | [Retained screenshots of the system Menu over the Defeat Prompt, the Battle system menu, and the Menu over the live Overworld](story-039-screenshots-menus.md) | UI | Blocked | ADR-0002, ADR-0005, ADR-0008 |
| 040 | [Retained screenshot of Camp](story-040-screenshot-camp.md) | UI | Deferred | ADR-0002 |
| 041 | [Remove the interim validate_enemy_ids_against_catalog flag](story-041-remove-interim-enemy-validation-flag.md) | Logic | Blocked | ADR-0002 (Step 3), ADR-0010 |

Stories 033–035 land in one commit (ADR-0002 Migration Step 2).
Unblocks content-catalog 025 (after 004, 005, 035) and 026 (after 004, 035).

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/game-state-scene-flow.md verified (AC-26 on the GTX 1080-class PC and the Steam Deck)
- Logic and Integration stories have passing tests in the test root; tests assert no orphan nodes
- UI stories have retained screenshots in `production/qa/evidence/` (Title, Defeat Prompt, Quit confirmation, Menu over the Defeat Prompt, Content Error)
- The MVP battle loop still plays end to end under Game State (the rewritten demo)
