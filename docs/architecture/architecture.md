# Go back to your planet! — Master Architecture

## Document Status
- Version: 5 (synced to ADR-0012 rev 3 Accepted, the ADR-0002 §11 revision, ADR-0005 §14 and `architecture-review-2026-10-23.md`)
- Last Updated: 2026-10-23
- Engine: Godot 4.7.2
- GDDs Covered: content-data-definitions.md, game-state-scene-flow.md, input-system.md, sprite-camera-presentation.md, stats-damage-resolution.md, turn-battle-system.md, faction-rule-modifiers.md, overworld-exploration-encounters.md (rev 4, Approved)
- ADRs Referenced: ADR-0001 to ADR-0013. ADR-0001 was Accepted 2026-10-21; ADR-0002 to ADR-0011 and ADR-0013 were Accepted 2026-10-22. ADR-0012 was Accepted 2026-10-23; all 13 are Accepted.
- TD-ARCHITECTURE: 2026-10-21 — CONCERNS, REVISED after CONCERNS (v2)
- LP-FEASIBILITY: 2026-10-21 — CONCERNS, REVISED after CONCERNS (v2)
- v3 changes: the Architecture Document Coverage findings of `architecture-review-2026-10-22.md` (BattleReplayController and FlashGate added, the Sprite & Camera row rewritten for ADR-0005 rev 3, the enemy-phase replay data flow added, the TR baseline pointed at `tr-registry.yaml`), plus status updates for the five ADRs accepted today
- v4 changes: the Architecture Document Coverage findings of `architecture-review-2026-10-22b.md` and `-22c.md`. Module rows rewritten for ADR-0007 (Stats), ADR-0008 (UI Framework), ADR-0009 (Save/Load & Settings), ADR-0010 (Turn Battle), ADR-0011 (Faction Rules) and ADR-0012 (Overworld, Proposed). New rows for Localization (ADR-0013) and Settings. Content Boot registrants updated. New data flows for damage resolution and settings delivery, and the save path rewritten. ADR Audit extended to 13 ADRs. TR baseline and Required ADRs brought up to date
- v5 changes (2026-10-23): ADR-0012 Accepted (Overworld module row rewritten: `SymbolBrain`, `WorldState.camp_returns`/`chapter_step`, ADR-0002 §11 in-mode fade and `register_camp`); ADR-0005 §14 (overworld profiles, travelling light, DOF mapping); TR baseline 83 requirements across 8 GDDs; Required ADRs and Open Questions updated.

## Engine Knowledge Gap Summary
Engine: Godot 4.7.2 | LLM Training Covers: up to ~4.3 | Post-Cutoff: 4.4, 4.5, 4.6, 4.7

- **HIGH RISK**:
  - **Rendering**: ADR-0005 pins the approach and probed most of it on 4.7.2 (`PROJECTION_FRUSTUM` + `frustum_offset`, the clip-space sprite quad, pipeline-compilation counters, runtime global uniforms, `SubViewport` defaults). The backend is pinned to **Vulkan with both fallbacks off** (Vulkan is the 4.7.2 default on Windows; the engine reference was corrected). `AreaLight3D` and HDR output are deliberately **not used**. Still open: ADR-0005 Verification Required items (12)–(16), measured in its Migration Step 1 spike, including on the Steam Deck.
  - **UI**: 4.6 dual focus and AccessKit (4.5+). ADR-0003 fixes the input side (routed, then re-injected navigation). ADR-0008 (Accepted) fixes the UI side, with probes on 4.7.2: one focus owner plus hidden focus (`grab_focus(hide_focus)` stated per path), `canvas_items` integer stretch refit to the window size every frame the size changes, plain-`Control` roots for full-rect children, and AccessKit properties. Code-set text is translated exactly once (ADR-0013). Still open: font sharpness at 3× and 4×, and `get_final_transform()` mapping (ADR-0008 Verification items 9 and 10).
  - **Input**: ADR-0003 verified the device-ID constants, `InputMap.action_erase_events()` and re-injection on 4.7.2. Still open: real pad names under SDL3, and Steam Input on the Deck ("Steam Virtual Gamepad").
  - **Physics/Jolt**: not used. ADR-0012 (Accepted) moves the party with a pure `GroundMover` on a baked `WalkGrid`, with no physics engine for movement or triggers. The risk returns only if that ADR is rejected.
- **MEDIUM RISK**: Animation (Tween/IK changes; `AnimatedSprite3D` `stop()` and `animation` both reset `frame` to 0, probed, ADR-0005 §1), Audio (one default flipped: `area_mask`).
- **LOW RISK**: Core scripting fundamentals (`RefCounted`, `Resource`, signals, `RandomNumberGenerator`, typed `Dictionary[K, V]`): exercised in the shipped battle code and probed for the ADRs. Node lifecycle order was **measured**, not assumed (ADR-0004: an autoload's `_ready()` runs after the main scene's `_enter_tree()`).

This project is deep in post-cutoff territory. The working policy: every API a
story's implementation depends on is verified against this exact engine build
(a throwaway headless or windowed script, deleted after) before it is trusted,
rather than assumed from training data. Every ADR to date has been handled this
way, and the control manifest (`docs/architecture/control-manifest.md`) records
the verified behaviours as rules.

## System Layer Map

```
┌─────────────────────────────────────────────────────────────────┐
│ PRESENTATION  │ UI Framework (ADR-0008 Accepted; battle HUD built, the
│               │ framework not built), Audio Manager (not built),
│               │ Onboarding & Tutorial (not built)
├─────────────────────────────────────────────────────────────────┤
│ FEATURE       │ Turn Battle System (built; ADR-0010 Accepted, retroactive:
│               │ check_command, BattleFactory and Flee not built),
│               │ BattleReplayController (ADR-0006 Accepted, not built),
│               │ SquadSpecials (built), ChapterFlow (built — becomes the
│               │ interim Overworld under ADR-0002), Faction Rule Modifiers
│               │ (built, 2/4 factions; ADR-0011 Accepted, retroactive),
│               │ Quirk State System (not built), Combo System & Codex (not
│               │ built), Enemy AI (collapses into Faction Rule Modifiers at
│               │ MVP scope), Overworld Exploration & Encounters (not built —
│               │ GDD Approved, ADR-0012 Accepted), Camp & Party
│               │ Management (not built), Leveling & Loyalty (not built,
│               │ Vertical Slice), Faction Reputation & Endings (not built,
│               │ MVP-lite→Alpha), Items/Equipment & Shops (not built,
│               │ Vertical Slice)
├─────────────────────────────────────────────────────────────────┤
│ CORE          │ Sprite & Camera Presentation (ADR-0005 Accepted, not
│               │ built), Stats & Damage Resolution (built; ADR-0007
│               │ Accepted, retroactive: DamageResolver not built), Squad
│               │ Roster & Recruitment (not built), Dialogue/Banter & Quests
│               │ (not built), Save/Load & Settings (ADR-0009 Accepted, no
│               │ GDD, not built, Vertical Slice)
├─────────────────────────────────────────────────────────────────┤
│ FOUNDATION    │ Game State & Scene Flow (ADR-0002 Accepted, not built),
│               │ Input System (ADR-0003 Accepted, not built), Content Data
│               │ Definitions (ADR-0001 + ADR-0004 Accepted, implementation
│               │ next), Localization (ADR-0013 Accepted; a cross-cutting
│               │ leaf utility, not built)
├─────────────────────────────────────────────────────────────────┤
│ PLATFORM      │ Godot 4.7.2 engine/OS — no project code, no epic
└─────────────────────────────────────────────────────────────────┘
```

Layer order reused from `design/gdd/systems-index.md`'s own dependency map.
**Build-order note**: Overworld Exploration & Encounters is "the system
requested next" only in the sense of *design* priority. Its three prerequisite
ADRs (Game State & Scene Flow, Input System, Sprite & Camera Presentation) are
Accepted, its GDD is Approved (rev 4) and its own ADR-0012 is Accepted (2026-10-23). What remains before its code starts is
the implementation of those three prerequisite systems (Game State, Input,
Sprite & Camera) and the overworld test plan. See Required ADRs.

## Module Ownership

| System | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| Content Data Definitions | Record catalog, ID/alias resolution, Ready/Failed state | `get_record`/`has_record`/`all_records`/`resolve_alias`, `register_known_effect_types`, `register_record_validator` (ADR-0004) | — (Foundation) | `Resource`, `ResourceLoader.load()`, `ResourceLoader.list_directory()` (4.4+, verified on 4.7.2 in the editor; re-verify on an export) |
| Content Boot Ordering | The one list of every registrant | `ContentBootstrap.run(catalog)` (no-op unless `UNLOADED`); its boot result returns `PresentationConfig` and the `FactionRuleRegistry` to `GameRoot` | Content Data; every registrant: Turn Battle, Faction Rule Modifiers (`FactionRuleRegistry` and rule-record validators, ADR-0011), Stats range validators (ADR-0007 §7), Input bindings validator, presentation validators, `LocFieldsValidator` for every record type (ADR-0013) | Node lifecycle order, **measured on 4.7.2** (ADR-0004) |
| Game State & Scene Flow | Current mode, overlay stack, transition lifecycle, input lock, detached Overworld instance (lifetime only), battle-start snapshot handle (contents are Battle mode's), `mode_time` | **ADR-0002 (Accepted)**: `request_transition(target, payload)`, `open_overlay(kind, payload)`/`close_overlay()`, `report_battle_outcome()`, `choose_retry()`/`choose_retreat()`, `get_move_vector(caller)`, `is_transition_flash_capped()`; signals `transition_started(from, to)`, `mode_exited(from)`, `mode_entered(to)`, `transition_finished(to)`, `overlay_opened(kind)`, `overlay_closed(kind)` | Content Data (Ready/Failed), Input (`ActionSource`), FlashGate (injected) | `Node.add_child`/`remove_child`, `process_mode`, `PackedScene.instantiate()`, `ResourceLoader.load()`; detach and freeze behaviour verified on 4.7.2; `@abstract` (4.5). Not yet implemented |
| Input System | Device state, active-device tracking, compiled bindings | **ADR-0003 (Accepted)**: `get_move_vector() -> Vector2`; signals `action_pressed(action)` (including derived `nav_*`), `action_released(action)`, `action_held(action)`, `device_lost()`, `device_restored()`, `focus_lost()`, `focus_gained()`, `active_device_changed(kind, pad_style)`, `pointer_confirm/cancel(position)`, `wheel_step(direction)` | Content Data (`bindings_default` record, validated via ADR-0004's `register_record_validator`) | `InputEvent.DEVICE_ID_MOUSE/KEYBOARD` (4.7), SDL3 positional `JoyButton` (4.5), `InputMap.action_erase_events` + `Input.parse_input_event` on `ui_*`, `ignore_joypad_on_unfocused_application`: verified on 4.7.2. Pad names under SDL3 and Steam Input still need real hardware. Not yet implemented |
| Sprite & Camera Presentation | Sprite rendering at one constant texel scale, per-mode cameras, per-state lighting, the sky card, global shader uniforms | **ADR-0005 (Accepted, rev 3)**: `CharacterSprite` (`show_frame`, `step_ambient`, `reset_to_idle`); `DioramaStage` (one per 3D mode scene: `request_profile(id, blend, clock)` for the owning mode, `bind_profiles`/`apply_profile`/`set_ambient_paused` for the Director only, `set_punch_offset_px`); `PresentationDirector` (applies the entry profile on `mode_entered`, skips same-mode rows, writes `mode_time` and the rim globals through `GlobalUniformSink`); `SpriteProjection` (pure, static) | Game State (`transition_started`, `mode_entered`, overlay signals, `mode_time`), Content Data (`sprite_set_id`, validated via ADR-0004), BattleReplayController clocks as injected `Callable`s (Core never imports the Feature type) | `AnimatedSprite3D` as frame source with a per-sprite `ShaderMaterial` writing a clip-space quad (verified pixel-exact); `Camera3D.PROJECTION_FRUSTUM` + `frustum_offset`, `KEEP_HEIGHT` only (verified); `DirectionalLight3D` cull masks; global shader uniforms (write-only); pipeline-compilation counters; Vulkan pinned, no fallback. `AreaLight3D`, HDR, FXAA/SMAA/TAA **not used**. Not yet implemented |
| FlashGate | Every booked large-area luminance transition, against `flash_rate_max` | **ADR-0005 §12**: `request(source_id, clock, rate) -> handle` (`-1` = play the capped variant), `set_rate`, `book_reserved`, `cancel`, `begin_exempt`/`end_exempt` | A real-time clock and `FlashSettings` (injected); `FlashSourceDecl` data, validated at boot | None beyond GDScript. Consumers: Game State (retry flash, wipes, fades), the Battle mode (replay-clock sources), the UI Framework (Menu backdrop, Defeat card, results). Not yet implemented |
| BattleReplayController | The replay queue (GATE, HOLD, OUTCOME, ROUND, TURN, END), display snapshots, the three beat clocks, the one-level latch | **ADR-0006 (Accepted)**: `enqueue_reveal_gate`/`open_reveal_gate`/`enqueue_takeover`, `advance(delta)`, `request_latch`/`clear_latch`/`set_speed_settings`, `get_display(c)`/`get_display_round()`, `get_windup_progress`/`get_post_impact_time`/`get_hold_time`, `cancel_pending_replay`/`resync`/`dispose`; 14 signals including the gated `turn_started_after_replay`, `round_advanced_after_replay`, `battle_ended_after_replay` and `display_resynced` | Turn Battle (`BattleCore`'s 4 signals, read-only), presentation's `windup`/`ko_landing` `Callable`s, `PresentationConfig` | `RefCounted` + typed signals; typed `Dictionary[Combatant, …]` (probed). LOW risk. One per Battle-mode instance, beside `BattleCore` in `src/battle/`. **Hard prerequisite:** ADR-0002 Migration Step 2. Not yet implemented |
| Stats & Damage Resolution | Nothing stateful between attempts. Per attempt: the `ResolutionHooks` registry, rebuilt by `start_battle()`; `StatsConfig` tuning | **ADR-0007 (Accepted)**: `DamageResolver.resolve(request) -> ResolutionRecord` (pure, static, both `damage` and `heal`), `can_afford`, `effective_stat`; `ResolutionHooks` (`add_stat_modifier`/`add_amount_modifier`/`add_override`/`remove_source`); read-only `Combatant.hp` plus `restore_vitals`; Stats content validators | Content Data (stat blocks, costs, `StatsConfig`), RNG (injected) | `RandomNumberGenerator` (injected), LOW risk. **Partly implemented**: today's `DamageCalculator` has the F3–F7 math; the resolver, hooks, record and HP lint are ADR-0007's migration. `src/battle/stats/` imports no Feature type |
| SquadSpecials | The squad's 4 named specials (stun, heal-party, heal-single, direct-damage) | `make_speak_to_the_manager()`, `make_family_meal()`, `make_appetizer()`, `make_home_run()`. `calculate_heal()` is replaced by `DamageResolver`'s `heal` kind (ADR-0007), and Defend/Viral Stunt become registered modifiers | Turn Battle System (`Move`/`SpecialEffect`), Stats & Damage (`DamageResolver`) | **Implemented** — `src/battle/squad/specials.gd`. No owning system in `systems-index.md` yet; closest fit is Turn Battle System or a future Quirk State System (see Open Questions) |
| ChapterFlow | Today: multi-fight sequencing, `BattleCore` construction, retry. **After ADR-0002 Migration Step 2:** encounter sequencing only (which fight is next, its roster, boss detection, HP/MP carryover, `chapter_won`), inside a placeholder `ChapterMode` that fills the Overworld slot | Today: `fight_started`, `fight_lost`, `chapter_won`. After Step 2: an `EncounterDescriptor` per fight; `chapter_won` | Today: Turn Battle, Faction Rule Modifiers. After Step 2: Game State (`request_transition`, `on_thawed`) | **Implemented** — `src/chapters/chapter_flow.gd`. QQ-01 resolved by ADR-0002 §8; it stops constructing `BattleCore` at Step 2 and is deleted when Overworld Exploration ships |
| Squad Roster & Recruitment | Join/leave state, active party | join/leave events | Content Data (Character records) | Not yet implemented |
| Dialogue, Banter & Quests | Dialogue state, quest flags | overlay open/close | Game State, Input, Content Data | `RichTextLabel` — 4.7 image-sizing change if inline icons used |
| Save/Load & Settings | Save slots (hashed two-line JSON, atomic write), the participant registry, playtime; the settings file and service (binding overrides, Faster battle animations, Speed up boss entrances, Screen Shake, Reduce Blur/Flashing/Motion, text scale) | **ADR-0009 (Accepted)**: `SaveService` (`list_slots`, `save_to_slot`, `read_slot`, `preflight`, `commit_if_loaded` bound into ADR-0002's `SceneLoader.payload_commit`, `reset_all_to_new_game`); `SaveParticipant` (`save_key`, `schema_version`, `capture`, `migrate`, `stage`, `commit`); `SettingsService` (`get_value`, `value_changed`, `pending_notices`) with narrow per-consumer views (`FlashSettings`, `UiSettings`, `PresentationSettings`) built in the composition root | Game State (`is_save_safe()`, SWAP), Content Data (IDs only), Input (`apply_overrides`, capture mode via ADR-0008's `InputCapture`), UI Framework (`pre_setup`) | `FileAccess`, `JSON`; nothing from `user://` is loaded as a `Resource` or through the variant parser. Advisory before the first save story: fsync and `.bak` fallback on `CORRUPT`, `JSON.stringify(full_precision)`, RNG state as a string, Deck suspend notification (22b F6–F8). No GDD yet. Not yet implemented |
| Turn Battle System | Battle state machine, outcome log | **ADR-0010 (Accepted, retroactive)**: `BattleCore.new(squad, enemies, rng, rule)`, `check_command(move, target) -> CommandCheck` (pure), `submit_action(move, target) -> BattleOutcome` (`null` on a failed check), `start_battle(false)` under Game State, `retry_battle()` (harness only), `clear_transients(party)`; 4 signals plus `battle_fled` (END-class in ADR-0006); `BattleFactory.build(payload, catalog, rules, …)` in the Battle mode | Stats & Damage (`DamageResolver`), Faction Rule Modifiers (`FactionRuleRegistry`, `EnemyAction`), Content Data | **Implemented** core, LOW risk. Not yet built: `check_command`, `BattleFactory`, Flee (its rules wait for a Flee section in the GDD). Presentation reads outcomes only through BattleReplayController (TR-turnbattle-005); only the Battle mode reports Victory/Fled/Defeat, after the replay |
| Quirk State System | Active states per combatant | apply/consume, duration | Turn Battle, Stats & Damage | Not yet implemented — relationship to today's `SpecialEffect` enum (owned by `SquadSpecials`/Turn Battle System) is `INTENT UNKNOWN` |
| Combo System & Codex | Combo matching, Codex unlocks | combo-fired event | Quirk State, Turn Battle | Not yet implemented |
| Faction Rule Modifiers | Per-faction rule/AI/presentation, stateless per battle | **ADR-0011 (Accepted, retroactive)**: 10-method `FactionRule` contract (`specials_allowed`, `move_allowed`, `apply_round_upkeep`, `register_resolution_hooks`, `choose_enemy_action -> EnemyAction`, banner/tooltip text, identity/banner colours); `FactionRuleRegistry` (`register`, `create`, `known_rule_classes`, `validator_for`); the `FactionRule` record type (`rule_class`, `params`, `texts`, `colors`, `ref_ids`) | Turn Battle (consulted by), Stats & Damage (hooks), Content Data, Localization (`texts` through `LocText`) | **Implemented** (Bureaucratia, MegaCorp), LOW risk. Not yet built: the registry, rule records, `Combatant.record_id` (MegaCorp's AI still tells enemies apart by name) |
| Enemy AI | Collapses into Faction Rule Modifiers at MVP scope | — | — | — |
| Overworld Exploration & Encounters | Map state, the party's map and position (`WorldState`, single owner, incl. `camp_returns` and the interim `chapter_step`), symbol AI, encounters, checkpoints, camp registration | **ADR-0012 (Accepted 2026-10-23)**: `GroundMover.step()` (pure) on a `WalkGrid` baked from a `TileMapLayer` (SAFE tags, batched `set_blocked`, 4-connected components, pinned `AStarGrid2D`); pure `SymbolBrain`; `OverworldMode` (`start_encounter`, `on_thawed`, `probe()`); injected `WorldState`; `map_`/`enc_`/`ostage_` record types; `MapEntryPayload`, `CampEntryPayload`; `OverworldConfig.validate()` (I1–I18); `tools/ci/validate_maps.gd` | Game State (incl. ADR-0002 §11 `request_in_mode_fade`, `register_camp`), Input (`get_move_vector()`), Content Data, Sprite & Camera (its diorama, `FollowCamera` from `WalkGrid.bounds()`, the §14 overworld profiles and travelling light), Save/Load (a participant), Localization (`LocText`), Dialogue | No physics engine. `TileMapLayer` read at load time only. 2 ms p99 budget (`performance.per_system.overworld_ms`). Not yet implemented |
| Camp & Party Management | Active squad at camp | swap-party hook | Squad Roster, Game State | Not yet implemented |
| Leveling & Loyalty | XP/level, loyalty, unlocks | — | Stats & Damage, Squad Roster, Dialogue | Not yet implemented (Vertical Slice) |
| Faction Reputation & Endings | Reputation counters, ending choice | — | Squad Roster, Dialogue | Not yet implemented (MVP-lite → Alpha) |
| Items, Equipment & Shops | Inventory, shop stock | — | Content Data, Stats & Damage | Not yet implemented (Vertical Slice) |
| UI Framework | Battle UI, menus, HUD, dialogue UI; the `UiTransitionPresenter`; the overlay focus stack; the menu input guard (TR-presentation-012); the window stretch refit; the project `Theme` and live text scale; the replay indicator | **ADR-0008 (Accepted)**: `UiService` (under `GameRoot/Services`; the second and last resolver holder; `refit_canvas()`, `world_to_ui()`); `UiContext` handed to every mode and overlay through ADR-0002's `pre_setup` hook; components `FocusScope`, `MenuGuard`, `PointerFocusSync`; `UiNavigator` (the only `Input.parse_input_event` caller besides InputSystem); `PromptFacade`; `UiFeedback.refuse()`; `InputCapture` (for ADR-0009) | Input (`InputResolver`, polled), Game State (six announcements, `pre_setup`), FlashGate, BattleReplayController's displayed state and indicator signals, Settings (`UiSettings` view), Localization | `Control` focus with `grab_focus(hide_focus)` stated per path, `canvas_items` + `expand` + integer stretch refit on a per-frame window-size check (22c E1), `min_size` 640×360, AccessKit properties, `Theme.set_font_size()`; all probed on 4.7.2. **Partially implemented** (battle HUD only); the framework is not built |
| Audio Manager | Music/SFX bus state | cue reactions | Game State, Turn Battle, BattleReplayController (`beat_impact` for the hit sound), Combo, Faction Rules, Overworld | `AudioStreamPlayer`, bus API — 4.7 `area_mask` default flip, MEDIUM risk |
| Onboarding & Tutorial | Tutorial-step gating | — | Turn Battle, Quirk State, Combo, UI Framework | none beyond UI Framework's own |
| Localization | The string-context convention, `LOC_FIELDS` per record type, the extraction and check tools | **ADR-0013 (Accepted)**: `LocText.of(record, field)`/`of_key`/`fmt` (leaf utility); `tr(source, context)` with `<screen>.<purpose>` contexts in code; `LocFieldsValidator` registered for every record type; `extract_records.gd`/`extract_scenes.gd` and a check tool (headless) | Content Data (record IDs and plain-text fields), Content Boot Ordering (validator registration) | `TranslationServer`, gettext `.po`/`.pot`, `Control.translation_context`, `auto_translate_mode` (DISABLED on the leaf control that shows code-set text; children inherit), pseudolocalization; probed on 4.7.2. POT generation is editor-only, hence the project tools. Locale list not decided. Not yet implemented |

## Data Flow

1. **Input path** (event-driven, not per-frame simulation — a turn-based menu
   game): device event → `InputSystem` (the only engine-input reader) →
   `InputResolver` (resolves an action) → `GameStateMachine` (routes to the top
   overlay or the current mode via `handle_action()`, applies the input lock)
   → the owning system acts → signals fire → UI Framework redraws. Menu
   navigation is then re-injected into native `Control` focus by the UI
   Framework's helper, focus-bounded and press-only (ADR-0003 §5).
2. **Signal path**: Game State & Scene Flow's 6 named signals and the
   Battle-side signals below are the established model. Presentation listens
   and never calls back into mutating methods. All synchronous, same-thread:
   no threading anywhere in this project.
3. **Battle replay path** (ADR-0006): the player submits a command →
   `BattleCore.submit_action()` resolves it **and every enemy action after
   it** synchronously, emitting `action_resolved` per outcome, then
   `round_advanced`, `turn_started` or `battle_ended`, all in one call stack →
   `BattleReplayController` queues each signal with a display snapshot →
   the Battle mode's `_process` calls `advance(delta)` on mode time →
   per beat: `beat_started` → `beat_impact` (the hit sound, the punch) →
   `beat_finished` (displayed HP/MP/status change) → `CharacterSprite`s,
   `DioramaStage` and `BattleHud` read the three clocks and `get_display()` →
   only after the last beat, the gated `turn_started_after_replay` opens the
   command menu, or `battle_ended_after_replay` starts the end-of-fight light
   and hold, then `report_battle_outcome()` to Game State. A reveal gate holds
   everything until `transition_finished(BATTLE)`, and a boss fight's takeover
   is a HOLD entry ahead of the first turn. The Menu freezes all of it, because
   `ModeHost` is disabled and `advance()` is not called.
4. **Flash path** (ADR-0005 §12): every large-area luminance source
   (Game State's retry flash and wipes, replay beats, the UI's Menu backdrop
   and Defeat card) books its transitions with `FlashGate` at their landing
   time; a refused booking plays its capped variant, and its timing never
   changes.
5. **Save/load path** (ADR-0009): a save is taken only while
   `is_save_safe()`. `SaveService` asks each registered `SaveParticipant` to
   `capture()` its section, then writes the slot atomically. Sections store
   catalog IDs plus runtime state only; the catalog itself is never serialized
   (Rule 7, read-only). A load runs in two halves. First,
   `read_slot()` → `preflight()` verify, migrate and `stage()` every section
   with no side effects, before any transition starts. Then, during ADR-0002's
   SWAP phase, `SceneLoader.payload_commit` calls `commit_if_loaded()`, and
   each participant `commit()`s, before the target mode is instantiated. A
   `false` there is a swap failure and rolls back.
6. **Damage resolution path** (ADR-0007): `BattleCore` builds a
   `ResolutionRequest` per effect → `DamageResolver.resolve()` reads
   `effective_stat()` through the attempt's `ResolutionHooks` (modifiers and
   overrides registered by squad passives and by `FactionRule.register_resolution_hooks()`
   at `start_battle()`) and `StatsConfig` → the resolver alone writes HP → one
   `ResolutionRecord` per effect is carried in `BattleOutcome` → the replay
   path (3).
7. **Settings delivery path** (ADR-0009 §7–§8): `SettingsService` is built
   first in `GameRoot._ready()` and loads its file with no catalog dependency,
   so it works on Content Error too. The composition root wraps it in narrow
   views (`FlashSettings` for `FlashGate`, `UiSettings` for `UiService`,
   `PresentationSettings` for the Battle mode through `pre_setup`, and the
   replay speed settings for `BattleReplayController.set_speed_settings()`).
   Each view relays `value_changed(key)` as its own `changed`, so a change
   applies live. Binding overrides go to `InputResolver.apply_overrides()`.
8. **Initialization order** (ADR-0004, measured on 4.7.2): engine start →
   `ContentCatalog` autoload `_init()`/`_enter_tree()` (state `UNLOADED`) →
   `GameRoot._enter_tree()` runs `ContentBootstrap.run()` (registers every
   vocabulary and validator, then `load_all()` → `READY` | `FAILED`) →
   children's `_enter_tree()` → the autoload's `_ready()` (which touches no
   catalog state) → children's `_ready()` → `GameRoot._ready()` builds
   `SettingsService` first (ADR-0009 §7), then the `InputResolver` (overrides
   applied), `GameStateMachine`, `FlashGate`, `PresentationDirector` and
   `UiService` (created after the resolver, machine and gate; it refits the
   window, ADR-0008 §1, §9), plus `SaveService` → the first tick in Boot
   reads the terminal state → Title or Content Error. Boot also runs the
   presentation warm-up behind the Boot screen (ADR-0005 §11).

## API Boundaries

- **`ContentCatalog`** (Foundation, ADR-0001 + ADR-0004): `get_record(type, id)`,
  `has_record(type, id)`, `all_records(type)` (ID-sorted), `resolve_alias(id)`,
  `state`, `register_known_effect_types(...)`, `register_record_validator(type, validator)`.
  Guarantee: `Ready` is terminal and immutable; a rejected lookup
  never returns partial data; `load_all()` is called only by
  `ContentBootstrap.run()`. Invariant: callers never mutate a returned
  `Resource`.
- **`GameStateMachine`** (Foundation, ADR-0002): the one door in for mode
  changes and overlays (`request_transition`, `open_overlay`/`close_overlay`,
  `request_quit`), battle reporting (`report_battle_outcome`,
  `report_results_done`, `choose_retry`, `choose_retreat`), and queries
  (`get_move_vector(caller)`, `is_input_owner`, `is_save_safe`,
  `is_transition_flash_capped`, `mode_time`). Guarantees: exactly one
  transition at a time, rejected (`REJECTED_BUSY`, never queued) if one is
  running; the four transition signals fire in a fixed order; input is locked
  for the whole transition; never an autoload, injected through `setup()`.
  `GameMode`/`GameOverlay` are the base classes modes and overlays extend.
- **`InputResolver`** (Foundation, ADR-0003): fed raw events by an
  `InputSystem` node under `GameRoot/Services`. It satisfies ADR-0002's
  `ActionSource` (`action_pressed`/`action_released` including the derived
  `nav_*` steps, `focus_lost`, `device_lost`, `get_move_vector()`), and also
  emits `action_held`, `focus_gained`, `device_restored`,
  `active_device_changed(kind, pad_style)` and the raw `pointer_*`/
  `wheel_step`. Guarantees: no `InputMap` use for gameplay; the built-in
  `ui_*` navigation actions carry no device events; the resolver is held only
  by Game State and the UI Framework service; modes never poll Input.
- **`BattleCore`** (Feature, implemented — `src/battle/battle_core.gd`):
  `BattleCore.new(squad, enemies, rng, faction_rule)`,
  `submit_action(move, target) -> BattleOutcome`,
  `start_battle(reset_squad := true)`, `retry_battle()`,
  `get_living_squad()`/`get_living_enemies()`/`get_active_combatant()`, 4
  signals (`turn_started`, `action_resolved`, `round_advanced`,
  `battle_ended`), plus ADR-0010's `check_command()`, `clear_transients()` and
  a fifth signal, `battle_fled`. Guarantee: a rejected action changes no
  state, returns `null`. Only BattleReplayController connects to its signals
  in the Battle mode.
- **`BattleReplayController`** (Feature, ADR-0006): see Module Ownership.
  Guarantees: the command menu opens, and the outcome reaches Game State, only
  after the replay's last beat; at most one timed entry finishes per
  `advance()` and leftover `dt` is dropped, so a slow frame never skips a beat;
  the displayed state equals the live state on every released TURN; Retry and
  every exit cancel the replay; a replay never changes a result.
- **Presentation** (Core, ADR-0005): `DioramaStage.request_profile()` is the
  only call a mode makes into lighting; `PresentationDirector` is the only
  writer of global shader uniforms (`mode_time`, `actor_rim_color`,
  `actor_rim_strength`) and the only caller of `apply_profile()`.
  Guarantees: one texel scale `T = max(1, floor(H/360))` for every sprite at
  every depth; the battle camera never moves, rotates or zooms in a fight;
  nothing compiles a rendering pipeline in play after Boot; Core never
  references a Feature type.
- **`FlashGate`** (Core service, ADR-0005 §12): `request`, `set_rate`,
  `book_reserved`, `cancel`, `begin_exempt`/`end_exempt`. Guarantee: no closed
  one-second window holds more than `flash_rate_max` flashes; the gate never
  delays a source, it only caps it; closing transitions are never dropped.
- **`FactionRule`** (Feature, implemented — `src/battle/factions/faction_rule.gd`;
  ADR-0011): 10-method hook contract, neutral defaults on the base class, no
  per-battle state; built only by `FactionRuleRegistry.create()` from a
  `FactionRule` record. Guarantee: `BattleCore` never branches on which
  subclass is active; fields are written only in `_configure()`.
- **`SquadSpecials`** (Feature, implemented — `src/battle/squad/specials.gd`):
  4 named-special factories. Guarantee: every special resolves through Turn
  Battle System's existing `Move`/`SpecialEffect` dispatch and, under ADR-0007,
  through `DamageResolver` — no parallel resolution path.
- **`DamageResolver`** (Core, ADR-0007): `resolve(request) -> ResolutionRecord`,
  pure and static. Guarantees: the only code that changes HP during a battle
  (`Combatant.hp` is read-only); one record per effect; RNG injected; hooks
  rebuilt per attempt; `src/battle/stats/` never imports a Feature type.
- **`BattleFactory`** (Feature, ADR-0010): the only production path from an
  `EncounterDescriptor` plus the party to a `BattleCore`. `check_command()` is
  the one legality check, shared by the HUD and `submit_action()`.
- **`UiService` / `UiContext`** (Presentation, ADR-0008): the only UI owner;
  every mode and overlay gets a `UiContext` through `pre_setup`. Guarantees:
  Game State imports nothing from Presentation; every `grab_focus()` states
  `hide_focus`; only `refit_canvas()` sets `content_scale_size`; no screen
  reads a fixed 640×360.
- **`SaveService` / `SaveParticipant` / `SettingsService`** (Core, ADR-0009):
  one participant per persisting system. Guarantees: `stage()` has no side
  effects and `commit()` cannot fail; saves hold IDs, never definitions;
  nothing from `user://` is loaded as a `Resource`; Core sees settings only
  through narrow views.
- **`LocText`** (leaf, ADR-0013): `of(record, field)`, `of_key`, `fmt`.
  Guarantees: English source text everywhere; each control is translated
  exactly once; every record type declares its `LOC_FIELDS`, checked at boot.

## ADR Audit

| ADR | Layer | Status | Engine Compat | GDD Linkage | Conflicts |
|---|---|---|---|---|---|
| ADR-0001: Content Data Storage Format | Foundation | Accepted (amended by ADR-0004) | ✅ Godot 4.7.2 | ✅ | None |
| ADR-0002: Game State & Scene Flow | Foundation | Accepted | ✅ | ✅ TR-gamestate-001..007 | None |
| ADR-0003: Input System | Foundation | Accepted | ✅ | ✅ TR-input-001..009 (001, 006, 009 partial) | None |
| ADR-0004: Content Boot Ordering | Foundation | Accepted | ✅ | ✅ | None |
| ADR-0005: Sprite & Camera Presentation | Core | Accepted (rev 3) | ✅ | ✅ TR-presentation-001..008, 010, 014..024; TR-gamestate-007 | None |
| ADR-0006: Battle Replay Ownership | Feature | Accepted (rev 4; amended by ADR-0010) | ✅ | ✅ TR-presentation-005, 009..011, 013, 021; TR-turnbattle-005 | None. The ADR-0005 ↔ ADR-0006 dependency cycle was cut on 2026-10-22 (ADR-0005 moved to ADR-0006's Enables row) |
| ADR-0007: Stats & Damage Resolution | Core | Accepted (retroactive; amended by ADR-0011) | ✅ | ✅ TR-stats-001..005 (005 partial: `Enemy.reward`) | None |
| ADR-0008: UI Framework | Presentation | Accepted (§9 refit trigger corrected after the 22c review) | ✅ | ✅ TR-presentation-012, 022 (UI); TR-input-006, 009 | None |
| ADR-0009: Save/Load & Settings | Core | Accepted | ✅ (22b F6–F8 advisory) | ✅ TR-input-001 (persistence), TR-presentation-022 | None |
| ADR-0010: Turn Battle System | Feature | Accepted (retroactive) | ✅ | ✅ TR-turnbattle-001..004 | None. Flee rules wait for a GDD section |
| ADR-0011: Faction Rule Modifiers | Feature | Accepted (retroactive) | ✅ | ✅ TR-factionrules-001, 002 | None |
| ADR-0012: Overworld Exploration & Encounters | Feature | **Accepted** 2026-10-23 | ✅ | ✅ TR-overworld-001..019 (`architecture-review-2026-10-23.md`) | None. Amends ADR-0001, ADR-0002 (§11 revision) and ADR-0005 (§14) |
| ADR-0013: Localization | Foundation (cross-cutting) | Accepted | ✅ | ✅ TR-content-012 | None |

Dependency order (`.claude/scripts/adr-dep-graph.sh`, acyclic, 40 edges):
ADR-0001 → ADR-0002 → ADR-0004 → ADR-0006 → ADR-0003 → ADR-0005 → ADR-0007 →
ADR-0013 → ADR-0008 → ADR-0011 → ADR-0009 → ADR-0010, with ADR-0012
(Accepted 2026-10-23) after ADR-0001–0005 and ADR-0013. All 13 ADRs are Accepted.

Open advisory items from the 2026-10-22 review, not yet folded into their
ADRs: E5 (ADR-0005, `ALPHA_SCISSOR` and early-z), E6 (ADR-0006, the boss-light
`clock` lambda outlives `dispose()`), E7 and E8 (ADR-0002, `AnimationPlayer`
freeze item closed; free a detached Overworld on quit), E9 (ADR-0003, Steam
Input `pad_style` row), E10 (ADR-0005, Shader Baker on a Linux export built
from Windows). The control manifest lists each one.

### Technical Requirements Baseline

The baseline lives in **`docs/architecture/tr-registry.yaml`** (83 requirements
across 8 GDDs as of 2026-10-23), with the GDD-to-ADR matrix in
`docs/architecture/requirements-traceability.md`. This document no longer keeps
its own copy: v2's 17-row table used provisional IDs from before the registry
existed, and the registry is now the only source of IDs.

Coverage at `architecture-review-2026-10-23.md` plus ADR-0012's acceptance and ADR-0005 §14: 79 of 83 covered by
Accepted ADRs, 0 resting on Proposed ADRs, 4 partial, 0 gaps. The 4 partials:
- TR-content-007/008/010 (Content Data, **Foundation**): immutability is
  protected by discipline only; the report entry shape and `ERROR_SCREEN_CAP`
  are in no ADR; there is no 500-record load benchmark. Close with an ADR-0001
  amendment or catalog-story notes.
- TR-stats-005 (Stats, Core): `Enemy.reward` ranges land with the
  enemy-record migration.

Not yet in the registry: Flee (needs a section in `turn-battle-system.md`). The
Overworld's 19 requirements are TR-overworld-001..019.

## Required ADRs

**Done (Accepted 2026-10-21/22):** ADR-0001 Content Data Storage, ADR-0002 Game
State & Scene Flow, ADR-0003 Input System, ADR-0004 Content Boot Ordering,
ADR-0005 Sprite & Camera Presentation, ADR-0006 Battle Replay Ownership,
ADR-0007 Stats & Damage Resolution (retroactive), ADR-0008 UI Framework,
ADR-0009 Save/Load & Settings, ADR-0010 Turn Battle System (retroactive),
ADR-0011 Faction Rule Modifiers (retroactive), ADR-0013 Localization.

**Accepted 2026-10-23:** ADR-0012 Overworld Exploration & Encounters (GDD rev 4
Approved; TR-overworld-001..019). It needs no physics, so the Jolt question is
closed. Its ADR-0002 §11 revision and ADR-0005 §14 amendment are in effect.


**Owed amendments (not new ADRs):** an ADR-0001 amendment for the
TR-content-007/008/010 partials; ADR-0009's advisory F6–F8 before the first
save story.

**Next ADRs (none blocking the current milestone):** Audio Manager (bus layout,
takes over the UI refusal tick), Quirk State / Combo System (blocked on QQ-02),
Dialogue Banter & Quests (NPC payload, global story flags), Squad Roster
(party source), Enemy AI (may move AI behind `Enemy.ai_profile_id`).

**Can defer to implementation:**
- Audio Manager bus architecture (Vertical Slice priority, not built)
- Quirk State / Combo System architecture (blocked on the open design
  question already carried in `turn-battle-system.md`, not an architecture gap)

## Performance Budget

User decision 2026-10-22, recorded in `project.yaml` `performance` and `platform`:

| Target | Value |
|---|---|
| Frame rate / frame budget | 60 fps / 16.6 ms |
| Frame time over a scripted battle | p99 ≤ 16.6 ms, worst frame ≤ 33 ms |
| Draw calls in a battle | ≤ 300 for all 3D passes (including `SetLight`'s shadow cascades) + ≤ 100 canvas/HUD, counted separately (`draw_call_limit: 400`) |
| Binding hardware | a GTX 1080-class desktop GPU with 8 GB RAM at 1920×1080, and Steam Deck at 1280×800 (native Linux export) |
| Memory ceiling | not set yet (`memory_ceiling_mb`); ADR-0005's P-14 reports peak RAM and VRAM so one can be chosen |

The battle stage is where nearly all frame cost lands; the rest of the game is
event-driven, with no continuous simulation loop. ADR-0005's Validation
Criteria carry the acceptance test (P-14): a failure on either device blocks
the story that ships the battle stage. Per-system costs: `GameStateMachine.tick()`,
`InputResolver` and `BattleReplayController.advance()` each do constant,
allocation-free work per frame (ADR-0002, ADR-0003, ADR-0006).

## Architecture Principles

1. **Gameplay values are data, never hardcoded.** The coding standard this
   project already states, now backed by ADR-0001's concrete mechanism, and
   by `TransitionConfig`, `InputConfig`, `PresentationConfig` and
   `LightingProfile` for tuning.
2. **The joke is the mechanic** (Pillar 1). Satire is expressed through
   combat rules (Faction Rule Modifiers), not just text — already proven by
   Bureaucratia's permit ban and MegaCorp's billing.
3. **Readable in One Turn** (Pillar 4). Every system's state is legible
   without a tutorial: Turn Battle System's full outcome log plus signals,
   the replay that shows every outcome beat by beat, and Game State & Scene
   Flow's single predictable transition door are all expressions of this.
4. **One door in, per system** — with one explicit, bounded exception.
   `request_transition()`/`open_overlay()`, `ContentCatalog`'s single lookup
   API, `FactionRule`'s single hook contract, `DioramaStage.request_profile()`
   — no system reaches around another's owned state. **Exception**:
   `ContentCatalog` is a Godot autoload singleton (ADR-0001), justified only
   because it is read-only after `Ready`. This is not precedent for a
   *mutable* singleton anywhere else: Game State (ADR-0002) and Input
   (ADR-0003) both faced the same question and are injected through
   `setup()`, not autoloads.
5. **RNG is always injected, never global** (Stats & Damage F6). Already
   enforced throughout the shipped battle code; carries forward to every new
   system.
6. **Logic cores are `RefCounted` and headless; scene-tree shells are thin.**
   `GameStateMachine`, `InputResolver` and `BattleReplayController` never touch
   the scene tree, an autoload by name, `Time` or `Engine`; time enters only
   through `tick(delta)`/`advance(delta)`, collaborators only through
   injection. Every test drives the core directly (ADR-0002, ADR-0003,
   ADR-0006).
7. **Lower layers never import higher ones.** Foundation's `src/data/` imports
   nothing from `src/boot/` or Feature code (ADR-0004); Core presentation never
   references the Feature-layer replay controller and takes its clocks as
   `Callable`s (ADR-0005, ADR-0006).

## Open Questions

- ~~**Scene-transition implementation mechanism / ChapterFlow overlap
  (QQ-01)**~~: **resolved** by ADR-0002 (Accepted 2026-10-22). A
  `RefCounted` `GameStateMachine` driven by a persistent `GameRoot` swaps modes
  as children of `ModeHost`; the Overworld is frozen by detaching it; Game
  State becomes ChapterFlow's parent, and ChapterFlow stays as the interim
  Overworld until Overworld Exploration ships.
- **Overworld movement/map representation**: **resolved** by ADR-0012
  (continuous movement on a logical ground plane, `GroundMover` on a
  `WalkGrid` baked from a `TileMapLayer`, no physics), Accepted 2026-10-23
  after its GDD was Approved.
- **Quirk State / Combo System's relationship to today's `SpecialEffect`
  enum (QQ-02)** (owned by `SquadSpecials`): `INTENT UNKNOWN`, carried from
  `turn-battle-system.md`'s own Open Questions. ADR-0006 §10 leaves a slot for
  combo protection and outcome grouping when `BattleOutcome` gains them.
- ~~**UI focus under 4.6+ dual focus, and AccessKit (4.5+) (QQ-03)**~~:
  **resolved** by ADR-0003 (input side) and ADR-0008 (Accepted 2026-10-22):
  native focus with `FocusScope`, hidden focus per path, `MenuGuard`,
  `PointerFocusSync` with `pointer_switch_px`, prompt labels through
  `PromptFacade`, AccessKit properties. The screen-reader commitment is
  still pending a user/CD decision.
- ~~**Save/Load serialization format**~~: **resolved** by ADR-0009 (hashed
  two-line JSON per slot, participants, preflight then SWAP commit).
- **Does randomness repeat on Retry?** (Game State & Scene Flow's Open
  Question #2): built as a fresh RNG on Retry. That was an autonomous pick
  logged for the user's veto on 2026-10-22 and is not yet confirmed.
- **Memory ceiling**: not set; waits for ADR-0005's P-14 measurement.
