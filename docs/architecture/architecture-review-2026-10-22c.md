## Architecture Review Report
Date: 2026-10-22 (third run of the day)
Mode: full
Workflow: full
Engine: Godot 4.7.2
GDDs Reviewed: 7 system GDDs (content-data-definitions, game-state-scene-flow, input-system, sprite-camera-presentation rev 7, stats-damage-resolution, turn-battle-system, faction-rule-modifiers), plus game-concept.md and systems-index.md for context
ADRs Reviewed: 13 (ADR-0001 to ADR-0011 and ADR-0013 Accepted; ADR-0012 Proposed)

Freshness check against `architecture-review-2026-10-22b.md`: 11 ADRs changed (0001–0004, 0006–0011, 0013: the 22b fixes, five acceptances and the amendment annotations). All GDDs, the TR registry, `architecture.md`, the engine reference, `project.yaml` and this skill are unchanged. No `UNRESOLVED` pattern. Full re-run (autonomous, logged), because single-gdd scoping would have covered nearly every system.

Reviewed-Content-Hash: docs/architecture/adr-0001-content-data-storage-format.md ab67bef98298864964489d994cd55a06fe85b26e
Reviewed-Content-Hash: docs/architecture/adr-0002-game-state-scene-flow.md ac9ed338e7b6c2ffbd952f494e78c4b056970cd0
Reviewed-Content-Hash: docs/architecture/adr-0003-input-system.md 6da5598d989e3160995983e1d7c01c0886c1718f
Reviewed-Content-Hash: docs/architecture/adr-0004-content-boot-ordering.md 6958f6a1795c1e67c4d356c55fac4addb8cc2408
Reviewed-Content-Hash: docs/architecture/adr-0005-sprite-camera-presentation.md e7f5b9505c22de224e10fcb89b8167c94348c75b
Reviewed-Content-Hash: docs/architecture/adr-0006-battle-replay-ownership.md e0850122343bf2036da37a113b75e78492f9f30a
Reviewed-Content-Hash: docs/architecture/adr-0007-stats-damage-resolution.md cec133dd8b12b93668a5c9fc8d9bf3ebb5c162d3
Reviewed-Content-Hash: docs/architecture/adr-0008-ui-framework.md 275ec5ca65123bddbfac73ed661f476dbdb9bd20
Reviewed-Content-Hash: docs/architecture/adr-0009-save-load-settings.md 7c50d04e4f03c4f99074ddc4a478c264a1267cbe
Reviewed-Content-Hash: docs/architecture/adr-0010-turn-battle-system.md dd7e58e6e387ec673a7f550dc09047c599366e7d
Reviewed-Content-Hash: docs/architecture/adr-0011-faction-rule-modifiers.md 64ed8bfdd58327022090c63324bb1936441f3938
Reviewed-Content-Hash: docs/architecture/adr-0012-overworld-exploration-encounters.md e42ac6d42af454490a6b7300a7d0f0b2d5c0571e
Reviewed-Content-Hash: docs/architecture/adr-0013-localization.md fd9303a69831b908c1715e14849dcb31f2a06f3c
Reviewed-Content-Hash: design/gdd/content-data-definitions.md ff14473d0804712400b702666e07824f7d5a2126
Reviewed-Content-Hash: design/gdd/faction-rule-modifiers.md 1812a7f6bd58080ebc680ca89b34742f9258d55b
Reviewed-Content-Hash: design/gdd/game-concept.md ce9474efabc4e96a62cf7d8e9859316615a4189d
Reviewed-Content-Hash: design/gdd/game-state-scene-flow.md a84c1406aca840d445191a9194cca07e779c6a62
Reviewed-Content-Hash: design/gdd/input-system.md 59917d823d98ee03f0cd97d8fcc102f4782bbc52
Reviewed-Content-Hash: design/gdd/sprite-camera-presentation.md 1b8c310076c4fa6dcbceb63497c1174b95df0064
Reviewed-Content-Hash: design/gdd/stats-damage-resolution.md fe1a2b64b4dd493d7805f4c80713c07413b01a52
Reviewed-Content-Hash: design/gdd/systems-index.md 0ffcec918ff97d9e127b4dd7fd5619235198160f
Reviewed-Content-Hash: design/gdd/turn-battle-system.md 26c898f3094f4b9e6ba7e1b8177eb712fc9c3ed8
Reviewed-Content-Hash: docs/architecture/tr-registry.yaml 77e84c9fef4dec6e4fac517f0d95af199cd74f5e
Reviewed-Content-Hash: docs/architecture/architecture.md 0ba376839704232919dd30e09e999cad6e6e8e64
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
Total requirements: 64 (no new IDs, none reworded; `tr-registry.yaml` unchanged)
✅ Covered (Accepted ADR): 60
🟡 Covered (Proposed ADR): 0
⚠️ Partial: 4 (TR-content-007, 008, 010; TR-stats-005)
❌ Gaps: 0

Since review 22b: 48 → 60 covered. The 12 🟡 rows now rest on Accepted ADRs. Those rows are TR-content-012 (ADR-0013), TR-input-001/006/009 (ADR-0008, 0009), TR-turnbattle-001..004 (ADR-0010), TR-factionrules-001/002 (ADR-0011) and TR-presentation-012/022 (ADR-0008, 0009). Full matrix: `docs/architecture/requirements-traceability.md`.

Requirement extraction: all 9 GDDs are byte-identical to review 22b, and so is `tr-registry.yaml`. The 64-requirement baseline from that review was reused, not re-extracted.

Story linkage (Phase 3b): `production/epics/go-back-to-your-planet/` holds 6 stories. They are minimal-tier MVP stories, and none cites a TR-ID, so every requirement is NO STORY for RTM purposes. There is no test root (`tests/` does not exist).

### Coverage Gaps (no ADR exists)
None.

Partial coverage (unchanged from 22b):
- ⚠️ TR-content-007/008/010 (Foundation): immutability is protected by discipline only. The report entry shape and `ERROR_SCREEN_CAP` are not in any ADR, and there is no 500-record load benchmark. Fix with an ADR-0001 amendment or notes on the catalog story. Engine Risk: LOW.
- ⚠️ TR-stats-005 (Core): the `Enemy.reward` ranges wait for the enemy-record migration (ADR-0007 §7). Engine Risk: LOW.

Pending (no TR IDs yet): Flee needs a section in `turn-battle-system.md` (ADR-0010 §5). The Overworld GDD does not exist, which blocks ADR-0012.

### Cross-ADR Conflicts

> Known conflict-prone areas: `docs/consistency-failures.md` does not exist.

No 🔴 conflict. The 22b findings are all resolved:
- **ADR-0009 → ADR-0008** (MEDIUM in 22b): fixed. ADR-0008 is now in ADR-0009's Depends On (L47) and was removed from its Enables.
- **ADR-0013 undeclared** (LOW): fixed. ADR-0008 and ADR-0011 now list ADR-0013 under Depends On.
- **Amendment annotations** (LOW): fixed for every Accepted amender. The Status lines of ADR-0001 (0004, 0007, 0011), ADR-0002 (0008, 0009, 0010), ADR-0003 (0008, 0009), ADR-0004 (0013, 0011), ADR-0006 (0010) and ADR-0007 (0011) carry them. ADR-0012's amendments (0001, 0002, 0005) are rightly not annotated while it is Proposed.

No data-ownership, state-authority or performance-budget conflicts. Note: ADR-0013 (L71, L180, L265, L278, L325) says "640×360 UI". After ADR-0008's refit, 640×360 is the *minimum* logical size, which is the right worst case for overflow screenshots. This is consistent; no change is needed.

### ADR Dependency Order
From `adr-dep-graph.sh`: 13 ADRs and 40 edges. No `NO_DEPS_SECTION` or `UNFILLED_DEPS`. **Acyclic.**

```
Accepted:
  1. ADR-0001 Content Data storage format
  2. ADR-0002 Game State & Scene Flow (0001)
  3. ADR-0004 Content Boot Ordering (0001, 0002)
  4. ADR-0006 Battle Replay Ownership (0002)
  5. ADR-0003 Input System (0001, 0002, 0004)
  6. ADR-0005 Sprite & Camera Presentation (0001, 0002, 0004, 0006)
  7. ADR-0007 Stats & Damage Resolution (0001, 0004)
  8. ADR-0013 Localization (0001, 0004)
  9. ADR-0008 UI Framework (0002, 0003, 0005, 0006, 0013)
 10. ADR-0011 Faction Rule Modifiers (0001, 0004, 0007, 0013)
 11. ADR-0009 Save/Load & Settings (0001, 0002, 0003, 0005, 0006, 0008)
 12. ADR-0010 Turn Battle System (0001, 0002, 0006, 0007, 0011)
Proposed:
 13. ADR-0012 Overworld Exploration & Encounters (0001–0005): blocked on its GDD
```

(The script's ORDER line lists ADR-0012 before 0009 and 0010. Neither depends on it, so it is listed last here as the only Proposed ADR.) No Accepted ADR depends on a Proposed one.

### GDD Revision Flags
None. All GDD assumptions are consistent with verified engine behaviour. The HIGH finding E1 concerns ADR-0008's resize trigger. No GDD assumes a window-refit mechanism, a 640×360 fixed canvas, hidden focus or a translation mode. Grep over `design/gdd/*.md` and the art bible finds no `640×360` or `content_scale` reference. The systems index is unchanged.

### Engine Compatibility Issues
Engine: Godot 4.7.2. ADRs with an Engine Compatibility section: 13 / 13, and all target 4.7.2.
- Deprecated API references: none. A sweep of all ADRs against `deprecated-apis.md` hits only avoid or reference context (ADR-0003 `event.device == 0`, ADR-0006/0012 References Consulted). There are no `duplicate()` calls on nested resources.
- Stale version references: none new. ADR-0005 still says "revision 6" for the presentation GDD (label only, carried over from 22b).
- Post-cutoff API conflicts: none between ADRs.
- 22b engine findings: F1, F2, F3 and F4 are folded in and verified in text: ADR-0008 Verification items 8, 11 and 12, §5, §6, §9, Guidelines L407–410, Validation L544/L553–554, and ADR-0013 §1 L90, item 9. F5 is closed. F6–F9 (ADR-0009) remain advisory and are recorded in ADR-0009's history as owed before the first save story. The reference corrections (F10, the D3D12 line) are still not made.

#### Engine Specialist Findings (godot-specialist; scope was the delta only; windowed probes on 4.7.2, Vulkan, RTX 4080 SUPER)
| # | Sev | ADR | Finding | Basis | Blocks |
|---|---|---|---|---|---|
| E1 | **HIGH** | 0008 §9 | **The refit trigger misses resizes.** The root `size_changed` fires only when the *stretched* size changes. Going from 1366×768 (683×384 logical, f=2) to 1920×1080 keeps f=2 and the stretched size, so no signal fires and no refit runs. The window stays letterboxed at offset (277,156). `NOTIFICATION_WM_SIZE_CHANGED` did not reach a child either. This breaks "never letterboxed" on maximize. Fix: compare `get_window().size` with the last size each frame, or use another trigger proven to fire on every resize. Add a direct 1366×768 → 1920×1080 test. | PROBED (code-driven resize; dragging the window by hand not probed) | **yes** (before the first UI story) |
| E2 | MEDIUM | 0008 §9 | "Never below 640×360" does not hold: a 600×300 window gives f=1 and 600×300 logical. Fix: set `get_window().min_size = Vector2i(640, 360)` at startup, and test it. | PROBED | no |
| E3 | LOW | 0008 §9 | Setting `content_scale_size` inside the handler re-fires `size_changed` once, so it runs twice with no loop. Other listeners see the logical size before the refit on the first call. ADR-0005's camera handler must read pixel size and be idempotent. No flicker. | PROBED / REASONED | no |
| E4 | LOW | 0008 §9 ↔ 0005 | `get_viewport().size` reports the full window (1365×767), not the "window less remainder" that §9 L247 describes. T = floor(H/360) is unaffected while f ≤ 6. ADR-0005 should name `get_viewport().size.y`. `get_tree().root` and `get_viewport()` are the same object. | PROBED / REASONED | no |
| E5 | LOW | 0008 §5 | `grab_focus(true)` hides focus as described. Injected `ui_down` from hidden focus moves focus and reveals it natively, so reveal-before-`nav_*` is redundant but harmless. | PROBED | no |
| E6 | LOW | 0013 §1 / 0008 §11 | `Node.AUTO_TRANSLATE_MODE_DISABLED` exists (value 2). INHERIT children under a DISABLED parent stop translating, and that includes fixed labels and `tooltip_text`. Rule: DISABLED goes on the leaf control only, or set fixed children to `ALWAYS`. A `.tscn` value overrides an `_init()` set. | PROBED / REASONED | no |
| E7 | LOW | 0008 Validation L546 | The "no black margins" screenshot check only lists sizes divisible by f. Note that an uneven size leaves an accepted strip narrower than f pixels. | REASONED | no |

Also confirmed: the 1280×720 first-launch window gives f=2 and 640×360 logical (PROBED).

Specialist gate per ADR: **0005** PASS (optional: E4 wording). **0008** CONCERNS, with E1 blocking implementation of §9. **0013** PASS (optional: E6 sentence).

### Architecture Document Coverage
`docs/architecture/architecture.md` (v3) has not changed since 22b. Every system in the systems index is still in the layer map, and there is no orphaned architecture. **It is stale against seven ADRs, six of them now Accepted (0007–0011, 0013), plus Proposed 0012.** The full list is in 22b § Architecture Document Coverage and is still accurate:
- Document Status / ADR Audit list only ADR-0001–0006.
- The module rows for Stats & Damage, Faction Rules, Turn Battle, Save/Load, UI Framework and Overworld predate their ADRs, and Localization has no row.
- The TR baseline still says "9 gaps".
- The data flow has no damage-resolution or settings-delivery flow.

Related: `control-manifest.md` (Manifest Version 2026-10-22) covers ADR-0001–0006 only. ADR-0007–0011 and ADR-0013 are Accepted but have no manifest rules, so stories against them would embed a manifest that lacks their constraints.

---

### Verdict: CONCERNS

- No requirement is uncovered, no requirement rests on a Proposed ADR, and there is no cross-ADR conflict or dependency cycle.
- Four requirements are partial (three Foundation, one Core). Each has partial coverage, not none, so none of them triggers FAIL.
- The engine specialist found one **HIGH** issue in Accepted ADR-0008 (E1, the refit trigger), plus a MEDIUM (E2). E1 must be amended before any UI story implements §9.
- `architecture.md` and the control manifest are stale against six Accepted ADRs.

Route to PASS:
1. Amend ADR-0008 §9: a refit trigger that fires on every resize (E1), `min_size` (E2), and the E3/E4/E7 wording. Optionally add the E6 sentence to ADR-0013 §1 and the E4 API name to ADR-0005.
2. Close the partials. TR-content-007/008/010 via an ADR-0001 amendment. TR-stats-005 lands with the enemy-record migration.
3. Bring `architecture.md` to v4 (`/create-architecture` sync), then `/create-control-manifest` to cover ADR-0007–0011 and 0013.
4. Write the Overworld GDD, then review and accept ADR-0012. Add the Flee section to `turn-battle-system.md`.

### Blocking Issues
None at verdict level (the verdict is not FAIL). E1 blocks implementation of ADR-0008 §9 only.

### Required ADRs
No new ADR is required for the designed systems. Future ADRs, none blocking (from `architecture.md`): Audio Manager, Quirk State / Combo System (blocked on QQ-02), Dialogue Banter & Quests, Squad Roster, Enemy AI.
