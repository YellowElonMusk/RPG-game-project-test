# Evidence: Story 074, the replay indicator and the refusal pulse

Story: `production/epics/sprite-camera-presentation/story-074-replay-indicator-and-refusal-pulse-screenshots.md`
AC: GDD `design/gdd/sprite-camera-presentation.md` AC-69 [UI] (P-18). Date: 2026-11-03. Engine 4.7.2, Vulkan Forward+, RTX 4080 SUPER, windowed 1920x1080.

**Verdict: AC-69's measured half PASSES.** All 21 shots are retained, and each one's text clears 4.5:1 against its own backing. The ux-designer's sign-off on the set is still owed.

## What had to be built first

The story was written to capture the widget, but the widget did not exist yet. ADR-0008 §7 and §12 specify the pieces, and they are built in this story:
- **`ReplayIndicator`** (`src/battle/ui/replay_indicator.gd`) is a navy window with a cream border in the bottom-right corner. It has three states, using the GDD's wording: "[fast_forward] Speed up", "Speeding up · [Cancel] Stop", and a dimmed "Playing the turn". It shows on every replay frame, boss takeover included, and on no other frame. A click emits `indicator_clicked()`, which `BattleMode` routes as `ReplayInputRouter.ACTION_INDICATOR_CLICK`, never as Confirm. It is not focusable.
- **`PromptGlyphs`** (`src/ui/prompt_glyphs.gd`) is an INTERIM stand-in for `PromptFacade`. It labels a prompt from the shipped bindings: key names on keyboard, face names by pad style on gamepad.
- **`RefusalPulse`** (`src/ui/refusal_pulse.gd`) is a side-to-side pulse through 4.7's `offset_transform_position`, using `UiConfig.refusal_pulse_px` and `refusal_pulse_time` (new `data/config/ui_config.tres`: 2 px, 0.12 s). It is zero under Reduce Motion.
- **`BattleMode`:** a latch press that changes nothing now calls `UiFeedback.refuse()` with the indicator when it is visible, and the pulse plays on it. Before this story the refusal callable was empty.

## The run (`tools/capture/replay_indicator_capture.gd`)

- **Backgrounds:** Battle (`enc_paris_clerks_hall`), the Bureaucratia boss (`enc_paris_supervisor`, takeover played) and the MegaCorp boss (ad-hoc CEO fight, takeover played).
- **States:** active (just after Attack is submitted), latched (one Confirm during the replay), and passive (the replay walked on to the first frame where no press would change anything).
- **Prompts:** keyboard, and gamepad with Xbox names.
- **Refusal pulse:** on the command menu's focused button, captured near the peak of its outward travel.
- **Contrast:** the backing is the median of a ring inset 5 px inside the widget; the text colour is the label pixel with the highest contrast against that backing. A widget that is not fully on screen makes the shot invalid, never a pass.

| Shot | Ratio | Result |
|---|---|---|
| active, keyboard ("[Shift] Speed up") / gamepad ("[X] Speed up"), all 3 backgrounds | 11.33:1 | PASS |
| latched, keyboard ("Speeding up · [Escape] Stop") / gamepad ("… [B] Stop"), all 3 backgrounds | 11.33:1 | PASS |
| passive ("Playing the turn", dimmed), both devices, all 3 backgrounds | 6.09:1 | PASS |
| refusal pulse on the focused command button, all 3 backgrounds | 14.31:1 (offset 1.33 to 1.39 px at capture) | PASS |

The ratios are identical across backgrounds because both widgets are opaque UI: world light never tints them (AC-53).

I opened these myself:
- `battle_passive_key.png`: "Playing the turn", dimmed, readable, bottom right, clear of the actors.
- `boss_megacorp_latched_pad.png`: "Speeding up · [B] Stop" over the neon MegaCorp stage, fully on screen.
- `battle_refusal_pulse.png`: the command menu with Attack focused. A 1.4 px shift cannot be seen in a still, which is expected for a 2 px pulse.

**Bug the capture found:** the first run showed the indicator running off the right edge ("[X] S" was all that showed). It still measured as passing, because only the visible sliver was sampled. Two fixes followed. The box now grows left and up from a pinned corner, with a regression test that I watched fail against the old code. The tool now refuses any widget that is not fully on screen.

Unit tests: `tests/unit/battle/replay_indicator_test.gd`, 9 tests.

## Gaps

- **The boss takeover backgrounds show no dusk flood.** This is a known gap (the sky card and boss flood are a 2D backdrop, and the boss light isn't visible). The boss shots are taken over the boss stage as it currently renders, and they will need a re-run once the flood is visible. Because the widgets are opaque, the ratios will not change.
- **The pulse is shown on the command menu by calling it directly.** `MenuGuard` is still not wired into the battle command menu (an open gap). The pulse appearance is the real one, but the guard window that would trigger it in play is not.
- **Glyphs are text labels, not images.** The UI service will also set the device from the Input System and re-label on `active_device_changed`; for now `BattleMode` defaults to keyboard prompts (TODO(ui-service)).
- **Text scale:** there is no text-scale setting yet, so the indicator does not follow one.

## Sign-off

ux-designer sign-off on the full set: owed.
