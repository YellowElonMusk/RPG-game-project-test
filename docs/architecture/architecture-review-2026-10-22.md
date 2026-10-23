## Architecture Review Report
Date: 2026-10-22
Mode: full
Workflow: full
Engine: Godot 4.7.2
GDDs Reviewed: 7 system GDDs (content-data-definitions, game-state-scene-flow, input-system, sprite-camera-presentation, stats-damage-resolution, turn-battle-system, faction-rule-modifiers), plus game-concept.md and systems-index.md read for context
ADRs Reviewed: 6 (ADR-0001 Accepted; ADR-0002 to ADR-0006 Proposed)

Freshness check: the 2026-10-21 report did not cover this run. Since then, 5 ADRs are new, the engine reference (`breaking-changes.md`, `modules/rendering.md`) and `project.yaml` changed, and 1 GDD is new. Full re-run.

Reviewed-Content-Hash: docs/architecture/adr-0001-content-data-storage-format.md dd9f9d6d285974c5b1ccd20228dd60f3dd9f9ce7
Reviewed-Content-Hash: docs/architecture/adr-0002-game-state-scene-flow.md 789b4e55e08ca89a2167d8ac9818bab973209494
Reviewed-Content-Hash: docs/architecture/adr-0003-input-system.md 25cf8e41d352b3dc8137b4d693b4efc508a694a3
Reviewed-Content-Hash: docs/architecture/adr-0004-content-boot-ordering.md 3b0a5d7fa4a8e4442b28800900fe88208b047d7a
Reviewed-Content-Hash: docs/architecture/adr-0005-sprite-camera-presentation.md db602a91074919ead13be930beab3682b0929fef
Reviewed-Content-Hash: docs/architecture/adr-0006-battle-replay-ownership.md 0e7ded43b545f36e83ef7ee901996e566b914509
Reviewed-Content-Hash: design/gdd/content-data-definitions.md ff14473d0804712400b702666e07824f7d5a2126
Reviewed-Content-Hash: design/gdd/faction-rule-modifiers.md db710305b56cd2971696d709497f1671afe24173
Reviewed-Content-Hash: design/gdd/game-concept.md ce9474efabc4e96a62cf7d8e9859316615a4189d
Reviewed-Content-Hash: design/gdd/game-state-scene-flow.md a84c1406aca840d445191a9194cca07e779c6a62
Reviewed-Content-Hash: design/gdd/input-system.md 4fa1e791aaaa3f3cfb013fd0bace4d686f054b21
Reviewed-Content-Hash: design/gdd/sprite-camera-presentation.md 415652405a2661ceee57442cc53da58855b55a11
Reviewed-Content-Hash: design/gdd/stats-damage-resolution.md fe1a2b64b4dd493d7805f4c80713c07413b01a52
Reviewed-Content-Hash: design/gdd/systems-index.md 0ffcec918ff97d9e127b4dd7fd5619235198160f
Reviewed-Content-Hash: design/gdd/turn-battle-system.md 8dac8b9330ef30d70675b97e2ef7881ba75a671b
Reviewed-Content-Hash: docs/architecture/tr-registry.yaml 00b37b6ef797e1216662dadca0f846e058059d6d
Reviewed-Content-Hash: docs/architecture/architecture.md 669f5ee6e4488d79c15e10a03678019ed174326b
Reviewed-Content-Hash: docs/engine-reference/godot/VERSION.md ddeee991a78c7e94b4e1b0d0e3605dcebd9d5fa7
Reviewed-Content-Hash: docs/engine-reference/godot/breaking-changes.md d8b0b79b0c75a8865a5a605e28e18646d322a473
Reviewed-Content-Hash: docs/engine-reference/godot/current-best-practices.md a45cd2c39a8ec53eaa3e924f39f93594e62085fd
Reviewed-Content-Hash: docs/engine-reference/godot/deprecated-apis.md 6a1353983e1db0d7bc0cc41a568b039495b5413c
Reviewed-Content-Hash: docs/engine-reference/godot/modules/animation.md ee51f50a46f8c63b771f62fe438947d4d84c59e3
Reviewed-Content-Hash: docs/engine-reference/godot/modules/audio.md c72af247505908a04f84a1dd3e765939efe700bd
Reviewed-Content-Hash: docs/engine-reference/godot/modules/input.md 3406b1b813858898696e510ea0accfcc7df98af8
Reviewed-Content-Hash: docs/engine-reference/godot/modules/navigation.md 7ae18ffbd2c3230cb19d610373225bfba187a472
Reviewed-Content-Hash: docs/engine-reference/godot/modules/networking.md 6606880462a2241014f77feb9610c5611e659ec6
Reviewed-Content-Hash: docs/engine-reference/godot/modules/physics.md 3b6ac8947f3f3e8c9ac9e6e0ff6cac06fdb8d805
Reviewed-Content-Hash: docs/engine-reference/godot/modules/rendering.md 2e5cf829bd091a51ad8193de7cc96e5dce63ed1d
Reviewed-Content-Hash: docs/engine-reference/godot/modules/ui.md 30ad166ab8c4e92c15aa37ed3464483b92b7845b
Reviewed-Content-Hash: project.yaml 56d084762df56e95eeb6f11deff3535b827a2c8e
Reviewed-Content-Hash: .claude/docs/technical-preferences.md 04f85c80c582806a0f79dc2135708193a8058403
Reviewed-Content-Hash: .claude/skills/architecture-review/SKILL.md 1a9d28aadbcbd26b5fc6b8ed1c64d73ae82b7b73
Reviewed-Content-Hash: .claude/skills/architecture-review/references/1-load.md 9a65759ebdbb2cb1f9744775bfed18cb25e76347
Reviewed-Content-Hash: .claude/skills/architecture-review/references/2-extract-requirements.md d08ea0b0e9ab9760b0d8bfe0cd9115f0bc40f8e2
Reviewed-Content-Hash: .claude/skills/architecture-review/references/3-traceability.md bb7b6b65c5e5e5b8869fa692413aa831615dede7
Reviewed-Content-Hash: .claude/skills/architecture-review/references/4-conflicts.md 0d30f8173b23248a32523a365b606dd1ce9642ab
Reviewed-Content-Hash: .claude/skills/architecture-review/references/5-engine.md 318ecbc1361d430badaf5dd8ce4cfc6ab0dff0ca
Reviewed-Content-Hash: .claude/skills/architecture-review/references/6-document-coverage.md dcce78482ec2ce60048989b6f9d1f797dd0a9a0e
Reviewed-Content-Hash: .claude/skills/architecture-review/references/7-report.md a007fd66bdac87812dc272e4b14cd231174e979d
Reviewed-Content-Hash: .claude/skills/architecture-review/references/8-write.md bf6d8946fc7b9e19eda7f65503a5c8f593a0d2b1
Reviewed-Content-Hash: .claude/skills/architecture-review/references/9-handoff.md fd5f681f4c3517c6a2e388c6d78075d82dded22e

---

### Traceability Summary
Total requirements: 64 (35 existing + 29 registered today)
✅ Covered (Accepted ADR): 6
🟡 Covered (Proposed ADR): 38
⚠️ Partial: 11
❌ Gaps: 9

Full matrix: `docs/architecture/requirements-traceability.md`.

**New TR-IDs registered (29):**
- `TR-presentation-001..024`: the first IDs for `sprite-camera-presentation.md`. ADR-0005 and ADR-0006 must back-fill them before acceptance.
- `TR-gamestate-007`: transition flashes go through the flash gate.
- `TR-input-007..009`: one press with no echoes, the `nav_*` actions, `pointer_switch_px`.
- `TR-turnbattle-005`: outcomes reach presentation only through the replay controller.

**Revised:** `TR-content-001`, now 8 record types including `bindings_`.

**Back-fill map for ADR-0005 / ADR-0006 `## GDD Requirements Addressed`:**

| ADR | TR-IDs |
|---|---|
| ADR-0005 | presentation-001, 002, 003, 004, 005 (with 0006), 006, 007, 008, 010 (with 0006), 014, 015, 016, 017, 018, 019, 020, 021, 022 (partial), 023, 024; gamestate-007 (with 0002) |
| ADR-0006 | presentation-005, 009, 010, 011, 013, 021; turnbattle-005 |
| ADR-0002 | gamestate-001..007; presentation-008 (mode time) |

### Coverage Gaps (no ADR exists)
- ❌ **TR-stats-001..004**: `stats-damage-resolution.md`, Stats & Damage (**Core**). Pipeline, injected RNG, modifier/override registration, Apply-only HP writes.
  - Suggested: `/architecture-decision stats-damage-resolution` (retroactive; the code exists).
  - Domain: Gameplay core · Engine Risk: LOW.
- ❌ **TR-turnbattle-001/002**: `turn-battle-system.md`, Turn Battle (Feature). The RefCounted state machine and the ordered gates.
  - Suggested: retroactive Turn Battle ADR, which should also pin the Fled / results-done handshake.
  - Engine Risk: LOW.
- ❌ **TR-factionrules-001**: `faction-rule-modifiers.md` (Feature).
  - Suggested: retroactive Faction Rule Modifiers ADR.
  - Engine Risk: LOW.
- ❌ **TR-presentation-012**: the menu input guard, safe default focus and refusal feedback (Presentation). ADR-0006 Alternative 5 rejects a guard inside the controller, so it belongs to the UI Framework.
  - Suggested: `/architecture-decision ui-framework`, which also covers TR-input-006/009 (partial) and QQ-03.
  - Engine Risk: HIGH (4.6 dual focus, 4.5 AccessKit).
- ❌ **TR-content-012**: localization extraction.
  - Suggested: a Localization ADR, deferred to before Alpha.
  - Engine Risk: LOW.

Partial (11): TR-content-007, TR-content-008, TR-content-010, TR-input-001, TR-input-006, TR-input-009, TR-stats-005, TR-turnbattle-003, TR-turnbattle-004, TR-factionrules-002 and TR-presentation-022. Two of them point at a missing **Save/Load & Settings ADR**: TR-presentation-022 needs the settings service, and TR-input-001 needs persisted binding overrides.

### Cross-ADR Conflicts

> Known conflict-prone areas: `docs/consistency-failures.md` did not exist at the start of this run, so there was no prior pattern to surface.

**🔴 Conflict: ADR-0005 vs ADR-0006 (Dependency cycle)**
- ADR-0005 claims: it depends on ADR-0006 for the beat clocks (L51).
- ADR-0006 claims: it depends on ADR-0005, whose `CharacterSprite`, `DioramaStage` and `PresentationConfig` "consume and configure this controller" (L69).
- Impact: neither can be accepted first. In code it is not a cycle: Core takes the clocks as `Callable`s and never imports the Feature controller (godot-specialist).
- Resolution options:
  1. **(Recommended)** Move ADR-0005 from ADR-0006's **Depends On** row to its **Enables** row. The graph then becomes 0006 → 0002 and 0005 → 0006.
  2. Accept both in one step, as both ADRs' notes plan. This works, but the graph stays cyclic and `adr-dep-graph.sh` keeps reporting it.

**LOW: ADR-0006 is internally inconsistent on typed Dictionaries.** Its Engine Compatibility row (L63) says it uses an untyped `Dictionary` because `Dictionary[K, V]` is NOT SOURCEABLE. But `BeatPlan` (L467–468) uses `Dictionary[Combatant, …]` ("compiles on 4.7.2, probed"), and ADR-0005 L325 uses `Dictionary[StringName, FlashSourceDecl]`. Fix: update the L63 row to "typed Dictionary probed on 4.7.2".

No data-ownership, state-authority or performance-budget conflicts were found. The flash gate is owned by ADR-0005 §12 and injected into ADR-0002's machine. ADR-0002's amendment matches. Mode time is owned by ADR-0002 and only read by ADR-0005 and ADR-0006.

### ADR Dependency Order
From `adr-dep-graph.sh`. Every ADR has a filled Depends On row.

```
Foundation (no dependencies):
  1. ADR-0001: Content Data storage format: Accepted
Depends on Foundation:
  2. ADR-0002: Game State & Scene Flow (requires 0001)
  3. ADR-0004: Content Boot Ordering (requires 0001, 0002)
  4. ADR-0003: Input System (requires 0001, 0002, 0004)
Blocked by cycle until it is cut or the pair is co-accepted:
  5. ADR-0006: Battle Replay Ownership (requires 0002, [0005])
  6. ADR-0005: Sprite & Camera Presentation (requires 0001, 0002, 0004, 0006)
```

⚠️ **The handoff note's acceptance order is wrong.** It says ADR-0004 before ADR-0002, but ADR-0004 L34 states "ADR-0004 cannot be Accepted before ADR-0002", and the graph agrees. The godot-specialist recommends accepting them together or 0002 first. **Correct order: ADR-0002 → ADR-0004 → (ADR-0003) → ADR-0006 → ADR-0005**, after the cycle edge is cut.

Every edge into a Proposed ADR is unresolved until that ADR is accepted. ADR-0001 (Accepted) carries a pending amendment from ADR-0004 (Proposed), so the Accepted foundation still states a lifecycle premise measured false on 4.7.2 until ADR-0004 is accepted.

### GDD Revision Flags
No GDD revision flags from engine findings. Every GDD assumption checked is consistent with verified engine behaviour. The Vulkan pin, KEEP_HEIGHT with a widened vertical view below 16:9, and `AnimatedSprite3D` stepping are all ADR-level mechanisms that meet the GDD as written.

Not engine-driven, but found while extracting (GDD-to-GDD/ADR drift; no systems-index status change):
- `sprite-camera-presentation.md` Tuning Knobs: `battle_draw_call_budget` default 150 "(Pending, OQ 13)", "far below `project.yaml`'s 2000". Reality: ADR-0005 Performance and `project.yaml` say 300 3D + 100 canvas, `draw_call_limit: 400` (user decision 2026-10-22). Update the knob row and close OQ 13.
- `input-system.md` header follow-up and Game Feel still say **"Speed up all replay beats"** and "no press ever speeds a knockout". The presentation GDD rev 6/7 renamed the setting to **"Speed up boss entrances"**, and knockout wind-ups are now plain beats (CD ruling 2). Update the two sentences.

### Engine Compatibility Issues
Engine: Godot 4.7.2. ADRs with an Engine Compatibility section: 6 / 6.
- Deprecated API references: none. ADR-0002 bans `change_scene_*` and `reload_current_scene`.
- Stale version references: none. All six target 4.7.2.
- Post-cutoff API conflicts: none between ADRs.
- Reference self-inconsistency (LOW): `current-best-practices.md` L83 still says D3D12 is the Windows default. `rendering.md` and `breaking-changes.md` were corrected to Vulkan.

#### Engine Specialist Findings (godot-specialist, probed on 4.7.2 headless)
| # | Severity | ADR | Finding | Blocks |
|---|---|---|---|---|
| E1 | MEDIUM | 0005 | `AnimatedSprite3D.stop()` and assigning `animation` both reset `frame` to 0 (probed). Fix the order in §1 and Key Interfaces L288: `stop()` once in `setup()`, then `animation` before `frame`, or use `set_frame_and_progress()` (probed). Otherwise beat-driven frames snap to 0 | ADR-0005 acceptance |
| E2 | MEDIUM | 0005 | AC-64 / §11 compile contract doesn't define "empty shader cache". `rendering_device/pipeline_cache/enable` and `shader_compiler/shader_cache/enabled` default to true. Name what is cleared (the user-dir Vulkan pipeline cache, `.godot/shader_cache`), and note that driver caches (NVIDIA, Mesa/RADV, Steam Fossilize on the Deck) are invisible to the counters | ADR-0005 acceptance |
| E3 | MEDIUM | 0005 | Verification Required (L45) still lists items (10) the clip-space quad being pixel-exact and (11) the `frustum_offset` sign as open. §6 L167 says the sign is verified, and Review History L569 says the quad is VERIFIED. Reconcile the table | ADR-0005 acceptance |
| E4 | LOW | 0005 | `fallback_to_d3d12` and `fallback_to_opengl3` exist and default to **true** (probed). §10 must set both to false explicitly; the setting names are now verified | — |
| E5 | LOW | 0005 | "Early-z stays on" (L98) is overstated: `ALPHA_SCISSOR` discards in the depth prepass. This affects performance only | — |
| E6 | LOW | 0006 | The boss-light `clock` lambda (L223) outlives `dispose()` (L346). The stage should drop its `clock` when the blend completes and on `_exit_tree` | — |
| E7 | LOW | 0002 | Open item (3) is closed: an `AnimationPlayer` under a disabled `ModeHost` holds its position and resumes (probed). Update L28 and L301 | — |
| E8 | LOW | 0002 | A detached Overworld is orphaned on quit mid-battle. `GameRoot` should free it on `NOTIFICATION_PREDELETE` / `WM_CLOSE_REQUEST` | — |
| E9 | LOW | 0003 | Steam Input on the native Linux Deck shows a virtual pad ("Steam Virtual Gamepad"), so `pad_style` needs a Deck/Steam row. `ui_select` exists with 2 events (closes L28's last caveat) | — |
| E10 | LOW | 0005 | Shader Baker plus global uniforms on a Linux export built from a Windows host is unchecked. Already deferred to the first export (L464) | — |

Specialist gate summary: ADR-0002 has nothing blocking (fold in E7, E8). ADR-0004 has nothing blocking (accept with or after 0002). ADR-0005 is blocked by E1, E2, E3 and the cycle. ADR-0006 is blocked only by the cycle (E6 advisory).

### Architecture Document Coverage
`docs/architecture/architecture.md` exists.
- Every system in `systems-index.md` appears in the layer map. ✓
- **Missing modules:**
  - `BattleReplayController` (ADR-0006) has no row in Module Ownership or Data Flow.
  - The `FlashGate` service (ADR-0005 §12, consumed by Game State and the UI) is not in the API boundaries.
  - The Sprite & Camera row (L76) predates ADR-0005 rev 2/3.
  - The "enemy-phase replay" data flow (BattleCore → controller → presentation/HUD) is undocumented.
- The Technical Requirements Baseline (L164) still says "17 provisional requirements … TR registry is still empty". It is stale: the registry now holds 64. Point it at `tr-registry.yaml`.
- No orphaned architecture.

---

### Verdict: FAIL

The verdict is FAIL for two reasons:
1. **Core-layer requirements are uncovered.** TR-stats-001..004 have no ADR. Stats & Damage is Core, and the code already exists, so a retroactive ADR is needed.
2. **A blocking cross-ADR conflict.** The ADR-0005 ↔ ADR-0006 dependency cycle.

Most of the remaining coverage (38 of 64) rests on Proposed ADRs, which would cap the verdict at CONCERNS even with both fixed.

The FAIL does not block the immediate plan, which is to accept ADR-0002, ADR-0004, ADR-0006 and ADR-0005. Neither cause is in those ADRs' scope, except the cycle, which is a one-line fix.

### Blocking Issues (must resolve before PASS)
1. Cut the ADR-0006 → ADR-0005 Depends On edge (move it to Enables).
2. ADR-0005: fix E1 (the `AnimatedSprite3D` frame-reset order), E2 (define the cache state for AC-64) and E3 (reconcile the verification table). Back-fill the TR-IDs.
3. ADR-0006: back-fill the TR-IDs; fix the L63 typed-Dictionary row.
4. Accept ADR-0002 → ADR-0004 → ADR-0003 → ADR-0006 → ADR-0005.
5. Retroactive Stats & Damage ADR (TR-stats-001..004).

### Required ADRs
1. **Stats & Damage Resolution** (retroactive, Core): TR-stats-001..004, plus the modifier ban in TR-stats-005.
2. **UI Framework** (Presentation, HIGH engine risk): TR-presentation-012, TR-input-006/009, QQ-03 (dual focus, AccessKit), the re-injection helper from ADR-0003.
3. **Save/Load & Settings** (Core): TR-presentation-022, TR-input-001 overrides.
4. **Turn Battle System** (retroactive, Feature): TR-turnbattle-001/002, plus the Fled / results-done handshake (TR-turnbattle-003).
5. **Faction Rule Modifiers** (retroactive, Feature): TR-factionrules-001/002, before ADR-0001's migration Step 3.
6. **Overworld Exploration & Encounters**: no GDD yet; blocked on the above.
7. **Localization** (before Alpha): TR-content-012.
