# Story 035: GameRoot becomes the main scene, with Content Error, TransitionConfig data, and the demo running under Game State

> **Epic**: Game State & Scene Flow
> **Status**: Ready (waiting on dependencies: input-system 001, 003, 025 and content-migration 013 must be Done first; not ADR-blocked, every governing ADR is Accepted)
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/game-state-scene-flow.md` (migration story: no GDD acceptance criterion)
**Requirement**: `TR-gamestate-005` (Boot waits; Content Error scene), `TR-gamestate-006` (`TransitionConfig` data; real clock through `_process`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Game State & Scene Flow (§2 scene layout: `ModeHost`, `OverlayHost` layer 10, `TransitionLayer` layer 20, `Services`; §9; Implementation Guidelines; Migration Plan Step 2 bullets 2–4); ADR-0004: Content Boot Ordering (§2; Migration Plan items 3–4); ADR-0003: Input System (§1 the resolver passed straight to `bind_action_source`; §2; §7 fallback bindings when FAILED); ADR-0008: UI Framework (§2, §8 `pre_setup`; `UiTransitionPresenter`, *interim presenter here*); ADR-0009: Save/Load & Settings (§6 `payload_commit`, no-op until SaveService)
**ADR Decision Summary**: `GameRoot` is the persistent main scene. `_enter_tree()` only runs `ContentBootstrap.run()`; `_ready()` builds the config, the input resolver and `InputSystem`, and the machine with its collaborators, then ticks it from `_process`. Mode swaps are child swaps; there is no scene change, no `SceneTree.paused`, and Game State is never an autoload.
**ADR Version**: ADR-0002 2026-10-21 · ADR-0004 2026-10-23 · ADR-0003 2026-10-21 · ADR-0008 2026-10-22 · ADR-0009 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Lifecycle order is measured, not documented (an autoload's `_ready()` runs **after** the main scene's `_enter_tree()`). A detached Overworld is orphaned on quit mid-battle (manifest advisory E8). Headless `GameRoot` in the gdUnit4 scene runner. `OS.get_cmdline_user_args()` cannot be set from inside a test (hence the seam below).

**Control Manifest Rules (this layer)**:
- Required: "`GameRoot._enter_tree()` calls only `ContentBootstrap.run()`. Everything else is built in `GameRoot._ready()` …"
- Forbidden: "Never call `SceneTree.change_scene_to_file()`, `change_scene_to_packed()` or `reload_current_scene()` anywhere in the project."
- Required: "Game State must never be an autoload. Delivered to every consumer through `setup()`."
- Required (Input): "Fallback bindings (a code constant) are used only when the catalog is `FAILED`."
- Engine verification: "⚠️ A detached Overworld is orphaned on quit mid-battle (advisory … E8): `GameRoot` should free it on `NOTIFICATION_PREDELETE`/`WM_CLOSE_REQUEST`."

---

## Acceptance Criteria

*Migration story: the criterion is ADR-0002 Migration Plan Step 2, bullets 2 (Title/Content Error/Defeat Prompt scenes), 3 and 4, plus EPIC Step 2.3, made checkable by the derived checks below (QA RC-5).*

- [ ] **Step 2.3** — "… minimal Title, Content Error and Defeat Prompt scenes." · "Set `run/main_scene` to `game_root.tscn` (currently intentionally unset)." · "Rewrite `chapter_flow_demo.gd` to boot through `GameRoot` …" (EPIC decision 2026-10-23: rewritten, not deleted) · "`ContentBootstrap.run()` in `_enter_tree()` (ADR-0004), the Content Error scene and the `TransitionConfig` data."
  1. [ ] On a valid data root, `GameRoot` boots to TITLE; `data/config/transition_config.tres` loads from disk and passes `validate()` with zero errors; the machine's action source is the `InputResolver` instance.
  2. [ ] On a Failed data root, `GameRoot` boots to CONTENT_ERROR; the scene text equals `ValidationReportText.build_error_screen_text(report)`; the log file is written; only Quit is actionable; the resolver was built from `make_fallback_bindings()`.
  3. [ ] The rewritten demo plays the MVP loop end to end with **scripted outcomes**: Title → New Game → four fights (VICTORY each) → `chapter_won`, and one DEFEAT → Retry → VICTORY mid-chapter.
  4. [ ] Quitting mid-battle (freeing `GameRoot` with a frozen Overworld) leaves no orphan nodes.
  5. [ ] `resolve_data_root(args)` is unit-tested.
  6. [ ] Review checklist: `project.godot` `run/main_scene == res://src/game_state/game_root.tscn`; `_enter_tree` body is one `ContentBootstrap.run` call; no `change_scene_*` / `SceneTree.paused` / Game State autoload in the project; the run-and-observe screenshot is retained.

---

## Implementation Notes

*Derived from ADR-0002 §2/§9, ADR-0004 §2, ADR-0003 §1/§2/§7, ADR-0008 §2/§8, ADR-0009 §6 and the QA gate (RC-5, RC-6):*

- **Landing group:** 033, 034 and this story land in **one commit when this story closes** (ADR-0002 Migration Step 2).
- **`_enter_tree()`** calls only `ContentBootstrap.run(ContentCatalog, data_root)`.
- **Data-root injection (QA fix).** Pin `static func resolve_data_root(args: PackedStringArray) -> String` (default `res://data`; `--data-root=<path>` overrides), unit-tested, plus a `data_root_override: String` the integration test sets before `add_child`. `_enter_tree` still contains one call, whose argument is `data_root_override if not empty else resolve_data_root(OS.get_cmdline_user_args())`. This is the injection point content-catalog 025/026 asked the owning epic to decide; record it for ADR-0004's Key Interfaces annotation.
- **`_ready()`, in order (manifest):** `SettingsService` *(absent: skip)* → `TransitionConfig` (`ResourceLoader.load`, then story 006's `validate`) → `InputConfig` → `InputResolver` (fallback bindings from `make_fallback_bindings()` if the catalog is `FAILED`, ADR-0003 §7) → **`InputSystem` under `GameRoot/Services`, wired with `InputSystem.setup(resolver)`**, the injection seam pinned in `production/epics/input-system/story-025-focus-lost-and-gained.md` → `GameStateMachine(loader, presenter, config, ContentCatalog, quit_hook = get_tree().quit, log, flash_gate = null)` → `machine.bind_action_source(resolver)` → `FlashGate` / `PresentationDirector` / `UiService` / `SaveService` *(absent: skip, with TODO lines in this order)*. `_process` calls `machine.tick(delta)`. `process_mode = PROCESS_MODE_ALWAYS`.
- `pre_setup` and `payload_commit` are bound to no-op Callables until UiService/SaveService exist. ADR-0012 annotation (c) later makes `pre_setup` a composite injector (also assigns `world_state`).
- **Interim presenter:** `interim_fade_presenter.gd` (Ink Navy `#1B2440` fade on `TransitionLayer`, real clock, fire-and-forget, plus the input-lock `MOUSE_FILTER_STOP` blocker), replaced by ADR-0008's `UiTransitionPresenter`.
- **Content Error scene:** plain text from `ValidationReportText.build_error_screen_text()`, writes the log via `build_log_text()`, Quit only (calls `machine.request_quit()` directly). Not translated (ADR-0013). No art, animation or faction styling, so it works when visual content is what failed.
- **`TransitionConfig` data:** `data/config/transition_config.tres` with the GDD Formulas defaults and the mode and overlay path tables. Its disk load is asserted here (story 006 tests `validate` in memory only).
- **Orphans / E8:** free the detached Overworld in `_exit_tree()` and on `NOTIFICATION_PREDELETE` / `NOTIFICATION_WM_CLOSE_REQUEST`.
- **Debug-build-only launch arguments (QA RC-6),** guarded by `OS.is_debug_build()` and ignored otherwise: `--debug-force-outcome=<victory|defeat>` (forces the next battle's outcome) and `--debug-retreat-descriptor` (builds one descriptor with `retreat_allowed = true` and registers a fake camp). They make check 3 and story 038's shots reachable without autoplay: naive autoplay cannot beat the Bureaucratia boss, and the balance question stays out of this gate.
- **Demo rewrite:** `chapter_flow_demo.gd` boots through `GameRoot` (ADR-0004 Migration item 4) and runs `ChapterMode` battles; it is rewritten, not deleted.
- Player-observable: retain the run-and-observe screenshot `production/qa/evidence/game-state-035-demo-under-game-state-[date].png` (also covers 034's Battle mode).
- Never `change_scene_*`, never `SceneTree.paused`, never a Game State autoload.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 036: Victory → Dialogue ordering under `GameRoot`.
- Story 037: the hardware benchmark.
- Story 038: the screenshots.
- `production/epics/content-catalog/story-025-error-screen-on-launch.md` and `production/epics/content-catalog/story-026-failed-catalog-blocks-boot.md`: their own evidence, unblocked by this story.

---

## Files

- `src/game_state/game_root.gd`, `src/game_state/game_root.tscn`
- `src/game_state/modes/content_error_mode.gd`, `src/game_state/modes/content_error_mode.tscn`
- `src/game_state/interim_fade_presenter.gd`
- `src/game_state/debug_launch_args.gd` (debug-build-only forced outcome and retreat-enabled descriptor)
- `data/config/transition_config.tres`
- `project.godot` (`run/main_scene = "res://src/game_state/game_root.tscn"`)
- `src/chapters/chapter_flow_demo.gd`, `src/chapters/chapter_flow_demo.tscn` (rewritten)
- `tests/integration/game_state/game_state_game_root_boot_test.gd`
- `tests/unit/game_state/game_root_data_root_test.gd`
- `production/qa/evidence/game-state-035-demo-under-game-state-[date].png`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; GAPS fixes applied: numbered checks, `resolve_data_root` seam, scripted outcomes via debug-build launch args, input and faction dependencies). The developer implements against these — do not invent new test cases during implementation.*

- **Check 1**: `game_state_game_root_boot_test.gd :: test_boots_to_title_on_valid_root`
  - Given: `GameRoot` instantiated with `data_root_override` = the content-catalog fixture `valid_one_of_each`.
  - When: `add_child`; await frames until the machine's phase == IDLE (bounded).
  - Then: mode TITLE; the `TransitionConfig` loaded from `data/config/transition_config.tres` passed `validate()` with zero errors; the machine's action source is the `InputResolver` instance.
- **Check 2**: `test_boots_to_content_error_on_failed_root`
  - Given: fixture `one_error_rest_valid`.
  - Then: mode CONTENT_ERROR; the scene text equals `ValidationReportText.build_error_screen_text(report)`; the log file was written; only Quit is actionable; the resolver was built from `make_fallback_bindings()`.
- **Check 3**: `test_demo_loop_scripted`
  - Then: Title → New Game → four scripted fights (VICTORY each, via forced outcome) → `chapter_won`; one scripted DEFEAT → Retry → VICTORY mid-chapter.
- **Check 4**: `test_quit_mid_battle_no_orphans`
  - When: enter Battle, `queue_free` `GameRoot`.
  - Then: no orphan nodes (exit 101 fails).
- **Check 5 (unit)**: `game_root_data_root_test.gd` — `resolve_data_root([]) == "res://data"`; `(["--data-root=res://x"]) == "res://x"`.
- **Check 6 (review checklist)**: `project.godot` `run/main_scene == res://src/game_state/game_root.tscn`; `GameRoot._enter_tree` body is one `ContentBootstrap.run` call; no `change_scene_*` / `SceneTree.paused` / Game State autoload in the project; run-and-observe screenshot retained at `production/qa/evidence/game-state-035-demo-under-game-state-[date].png`.
  - Edge cases: debug launch args ignored when `OS.is_debug_build()` is false.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/game_state/game_state_game_root_boot_test.gd` — must exist and pass. Gate level: BLOCKING.
- Unit: `tests/unit/game_state/game_root_data_root_test.gd` — must pass.
- Run-and-observe: `production/qa/evidence/game-state-035-demo-under-game-state-[date].png` retained (coding standards: "A parse check is not a run").

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on (this epic): `production/epics/game-state-scene-flow/story-004-boot-to-title-or-content-error.md`, `story-005-content-error-rejects-all-but-quit.md`, `story-006-transition-time-and-budget-check.md`, `story-013-invalid-descriptor-stays-in-overworld.md`, `story-014-overworld-snapshot-exact-restore.md`, `story-025-menu-stops-time-quit-to-title.md`, `story-030-defeat-prompt-focus-and-cancel.md`, `story-031-title-focus-and-quit-confirm.md`, `story-033-strip-chapter-flow-chapter-mode.md`, `story-034-battle-mode-wraps-battle-core.md` (all under `production/epics/game-state-scene-flow/`)
- Depends on (content-catalog): `production/epics/content-catalog/story-002-load-one-of-each-type.md` (`ContentBootstrap.run(catalog, data_root)`), `production/epics/content-catalog/story-009-one-error-fails-catalog.md`, `production/epics/content-catalog/story-024-error-screen-text.md`
- Depends on (input-system): `production/epics/input-system/story-001-default-bindings-press-release.md` (`InputResolver`), `production/epics/input-system/story-003-bindings-validation.md` (`make_fallback_bindings()`), `production/epics/input-system/story-025-focus-lost-and-gained.md` (the `InputSystem` shell node and its `setup(resolver)` seam; HIGH engine risk)
- Depends on (content-migration): `production/epics/content-migration/story-013-author-faction-records.md` (faction records, so `ChapterMode` descriptors pass validation)
- Unlocks: `production/epics/game-state-scene-flow/story-036-victory-dialogue-after-transition.md`, `story-037-transition-budget-hardware-bench.md`, `story-038-screenshots-title-prompts-error.md`, `story-039-screenshots-menus.md`, `story-041-remove-interim-enemy-validation-flag.md`; `production/epics/content-catalog/story-025-error-screen-on-launch.md` (with 004, 005), `production/epics/content-catalog/story-026-failed-catalog-blocks-boot.md` (with 004)
