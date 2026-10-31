# Evidence: Story 060, the flash analyser checks composited frames against flash_rate_max

Story: `production/epics/sprite-camera-presentation/story-060-composite-frame-flash-analysis.md`
AC: GDD `design/gdd/sprite-camera-presentation.md` AC-55b [C] (P-13). Date: 2026-10-31. Engine 4.7.2, Vulkan Forward+, RTX 4080 SUPER, windowed 1280x720, `--fixed-fps 60`.

**Verdict: the analyser is built and tested. AC-55b PASSES with Reduce Flashing Off and FAILS with Reduce Flashing On.** The On failures come from two sources outside the flash gate (Findings 1 and 2 below). The story stays open until they are routed through the gate or capped.

## The analyser (`tools/capture/flash_analyser.gd`, `FlashAnalyser`)

- The analyser uses the GDD `flash_gate` definitions, applied to linear R, G and B.
  - **General:** a luminance change of at least 0.10 whose darker state is below 0.80.
  - **Red:** saturated red (`R/(R+G+B) >= 0.8`) and a change in `(R-G-B)*320` (clamped at 0) of more than 20.
  - **Area:** at least 25% of some 10° window of `(4/9)H x (1/3)H`, placed anywhere on screen.
- **Per-pixel swings:** each pixel's swing is measured from its running extreme. A slow ramp is therefore one transition, and jitter below the threshold is not a transition at all.
- **Coincidence:** a transition stays live for 3 frames, so one large change whose pixels cross the threshold a frame apart is judged as one area.
- **Events and flashes:** a transition event happens on the frame its live area first reaches 25%. A flash is an event that opposes the previous event of the same kind (the gate's N−1 rule).
- **Counting:** general and red flashes are counted separately, per closed one-second window `[t, t+1 s]`.
- **Analysis resolution:** frames are box-halved to 160x90, which gives a 40x30-pixel window.
- **Unit tests:** `tests/unit/presentation/flash_analyser_test.gd`, 18/18 passing. I watched the suite fail against a stub first.

## The run (`tools/capture/flash_sequence_capture.gd`)

- **Setup:** the real `BattleMode` runs under a stand-in ModeHost, with a real `FlashGate` on a frame clock and the shipped flash-source declarations.
- **Frames:** every composited root-viewport frame (world and HUD together) goes to the analyser.
- **Transitions:** the wipe IN and the retry flash are played with the shipped `InterimFadePresenter`, using `transition_config.tres` durations, and are requested from the gate.
- **Reduce Flashing:** each sequence runs twice, with `FlashSettings.reduce_flashing_on` Off and On.
- **Input cadence:** the scripted player picks a command 0.6 s after the menu appears.

| Sequence | Off: max general / red per 1 s | On: max | On: flashes outside the boss flood |
|---|---|---|---|
| boss_takeover (`enc_paris_supervisor`, wipe reveal, full takeover) | 1 / 0 PASS | 1 / 0 | 1 (frame 129: the command menu appears as the hold ends) FAIL |
| hits_1x (4 squad attacks, impact bursts) | 3 / 0 PASS | 3 / 0 | 9 FAIL |
| hits_latched (same, latched; 4 latches engaged) | 3 / 0 PASS | 3 / 0 | 9 FAIL |
| victory (enemy at 1 HP, a knockout, the Victory hold) | 2 / 0 PASS | 2 / 0 | 2 FAIL |
| defeat_retry (forced Defeat, spotlight, retry flash, restore) | 3 / 0 PASS | 3 / 0 | 5 FAIL |
| menu_during_replay (1 s of Menu freeze mid-wind-up) | 2 / 0 PASS | 2 / 0 | 3 FAIL |
| **neg_strobe** (negative control: a full-screen 5 Hz strobe over hits) | **11** / 0 **FAIL as required** | — | — |
| obs_gate_bypassed (latched, no gate) | 3 / 0 | — | observation |
| obs_fast_menu (1x hits, 0.25 s picks) | **4** / 0 FAIL | — | observation |

Per-run evidence is in `composite-flash-sequences/<sequence>_rf_<off|on>/`: `luma_plot.png`, `contact_sheet.png` (one tile every 0.2 s) and up to 4 full frames at events. All numbers are in `measurements.json`.

I opened the following myself:
- `hits_1x_rf_on/luma_plot.png`: a flat mean luma with flash bars at the menu toggles.
- `neg_strobe_rf_off/luma_plot.png`: a 0↔1 strobe, dense flash marks.
- `defeat_retry_rf_on/event_0135.png`: the Defeat frame as the retry fade starts.
- `boss_takeover_rf_off/contact_sheet.png`: the wipe reveal, then the boss on stage.
- Earlier event frames (`event_0021`, `event_0036`): the command-menu panel showing and hiding.

## Findings

1. **The command-menu panel is an ungated flash source.** The panel is roughly 220x230 px, dark over the bright sand. Showing or hiding it covers about 32% of a 10° window with a luminance swing of more than 0.10. Each turn therefore makes a ↓ and an ↑.
   - At a 0.6 s pick it reaches exactly 3 flashes per second, the limit.
   - At a 0.25 s pick (`obs_fast_menu`) it reaches 4, which is over the limit.
   - It is not among the GDD's declared sources (rule 13 lists the Menu backdrop, the Defeat stamp and the results screen) and has no `FlashSourceDecl`. Reduce Flashing therefore cannot cap it. Owner: UI Framework / GDD (declare it, fade it below 0.10, or keep it on screen).
2. **`InterimFadePresenter` ignores `capped`.** With Reduce Flashing On the gate refuses `battle_wipe` and `retry_flash` (recorded in `gate_requests`). The navy fade still plays in full anyway (defeat_retry On: ↓ at 135, ↑ at 146). Owner: Game State / UI (ADR-0008's real presenter).
3. **Impact bursts never reach the area threshold** in these frames, so no event is attributable to them. The gated and bypassed runs measure the same. The gate's bookings (`gate_booked_max_per_window` ≤ 2) never constrained anything here.
4. **Bug found on Retry (not in this story's files):** `BattleHud._on_number_cleared` (`src/battle/ui/battle_hud.gd:318`) casts a float label that has already been freed (`as Label`) and logs `SCRIPT ERROR: Trying to cast a freed object` once per number during `restore_start_snapshot`. The run continues. Owner: gameplay/UI programmer.

## Gaps

- The **Victory confetti, victory burst, results screen, Defeat card stamp and Menu backdrop are not built**. Those sources are absent from the sequences rather than measured.
- **There is no `GameStateMachine`.** The wipe and retry are reproduced with the shipped presenter, and `restore_start_snapshot` takes the uncapped (instant) light path even when the gate capped the flash.
- The **settings service does not exist**, so Reduce Flashing is injected through `FlashSettings`.
- Analysis is at 160x90 on box-averaged sRGB, so edges are approximate. Flat areas, where every transition here happened, are exact.

## Sign-off

Lead sign-off: owed. The story cannot close: AC-55b fails with Reduce Flashing On (Findings 1 and 2).
