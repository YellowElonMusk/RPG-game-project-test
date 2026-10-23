## Architecture Review Report
Date: 2026-10-22 (second run of the day)
Mode: full
Workflow: full
Engine: Godot 4.7.2
GDDs Reviewed: 7 system GDDs (content-data-definitions, game-state-scene-flow, input-system, sprite-camera-presentation rev 7, stats-damage-resolution, turn-battle-system, faction-rule-modifiers), plus game-concept.md and systems-index.md for context
ADRs Reviewed: 13 (ADR-0001 to ADR-0007 Accepted; ADR-0008 to ADR-0013 Proposed)

Freshness check against `architecture-review-2026-10-22.md`: 7 ADRs are new (0007–0013), 6 ADRs changed (acceptances and review fixes), 4 GDDs changed (faction-rule-modifiers, input-system, sprite-camera-presentation rev 7, turn-battle-system), and `architecture.md` changed. Full re-run. No `UNRESOLVED` pattern.

Reviewed-Content-Hash: docs/architecture/adr-0001-content-data-storage-format.md c469d0291707725b6b4a2709b3e877f7e63f69d5
Reviewed-Content-Hash: docs/architecture/adr-0002-game-state-scene-flow.md 7fba568ed44b7d46710a04917b24f248e3d47e8a
Reviewed-Content-Hash: docs/architecture/adr-0003-input-system.md bc627670eb247761fe5dcab30d7fc49312757e79
Reviewed-Content-Hash: docs/architecture/adr-0004-content-boot-ordering.md d0f7f164556d631698514801f4ad5594e43412c9
Reviewed-Content-Hash: docs/architecture/adr-0005-sprite-camera-presentation.md e7f5b9505c22de224e10fcb89b8167c94348c75b
Reviewed-Content-Hash: docs/architecture/adr-0006-battle-replay-ownership.md 5c2cd1792600fafe15ecafdcde583091f7ebe856
Reviewed-Content-Hash: docs/architecture/adr-0007-stats-damage-resolution.md 293e34d568885e4778d5604bafe8d7997d7c86e3
Reviewed-Content-Hash: docs/architecture/adr-0008-ui-framework.md 2e5cd161d48b74f95c7c7bb747f976e6daea4e78
Reviewed-Content-Hash: docs/architecture/adr-0009-save-load-settings.md 07049db9585da3cc5336f97c7b485db0f907bff7
Reviewed-Content-Hash: docs/architecture/adr-0010-turn-battle-system.md 95bbcc06c3d1bbb3b6705d154cab564c2a175a72
Reviewed-Content-Hash: docs/architecture/adr-0011-faction-rule-modifiers.md 7c5fc3cdebe7a3b67df9deb85e3200e1ad4cf2cc
Reviewed-Content-Hash: docs/architecture/adr-0012-overworld-exploration-encounters.md e42ac6d42af454490a6b7300a7d0f0b2d5c0571e
Reviewed-Content-Hash: docs/architecture/adr-0013-localization.md 6250df31e98bc553ffd7f54d723a66e54b37c4f8
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
Total requirements: 64 (no new IDs; TR-factionrules-001 reworded to the 10-method contract)
✅ Covered (Accepted ADR): 48
🟡 Covered (Proposed ADR): 12 (TR-content-012, TR-input-001/006/009, TR-turnbattle-001..004, TR-factionrules-001/002, TR-presentation-012/022)
⚠️ Partial: 4 (TR-content-007, 008, 010; TR-stats-005)
❌ Gaps: 0

Since this morning: 6 → 48 covered, 9 → 0 gaps. Full matrix: `docs/architecture/requirements-traceability.md`.

Changed GDDs checked for new requirements. None found:
- `sprite-camera-presentation.md` rev 7 adds re-booking on freeze or speed change, red-capped variants, stars and `horizon_band_frac`, the Victory curve from captured light, and odd-width quad edges. All of these are already in ADR-0005 rev 3 (§1 L93, §3 sky card, §12 `set_rate`) and ADR-0006 §5, under existing TR-presentation-005/004/015/001.
- `input-system.md`: the morning's flagged sentences ("Speed up all replay beats") are fixed.
- `turn-battle-system.md` and `faction-rule-modifiers.md`: ADR-0007 annotations only. The contract growing to ten methods triggered the TR-factionrules-001 rewording.

### Coverage Gaps (no ADR exists)
None.

Partial coverage:
- ⚠️ TR-content-007/008/010 (Foundation): immutability is protected by discipline only; the report entry shape and `ERROR_SCREEN_CAP` are in no ADR; there is no 500-record load benchmark. Suggested: an ADR-0001 amendment, or notes on the catalog story. Engine Risk: LOW.
- ⚠️ TR-stats-005 (Core): `Enemy.reward` ranges wait for the enemy-record migration (ADR-0007 §7's own note). Engine Risk: LOW.

Pending requirements:
- **Flee:** ADR-0010 §5 blocks every Flee-shipping story on a Flee section in `turn-battle-system.md` (it has none) plus a new TR.
- **Overworld:** ADR-0012 has no GDD, so it has no TR IDs, and it cannot be Accepted.

### Cross-ADR Conflicts

> Known conflict-prone areas: `docs/consistency-failures.md` does not exist, so there was no prior pattern to surface.

No 🔴 blocking conflict. `adr-dep-graph.sh` finds no cycle, and every ADR has a filled Depends On row. The morning's ADR-0005 ↔ ADR-0006 cycle is cut.

**MEDIUM: ADR-0009 vs ADR-0008 (Integration contract / undeclared dependency).**
- ADR-0009 claims: "Does **not** depend on ADR-0008" (Ordering Note, L50).
- But its §7 (L206) wires `PresentationSettings` into the Battle mode through "`GameRoot`'s `pre_setup` hook (ADR-0008 §2)". That hook is ADR-0008's additive amendment to ADR-0002. ADR-0012 (c) also calls `pre_setup` "introduced by ADR-0008 and ADR-0009".
- Impact: if ADR-0009 is implemented first, the hook it needs does not exist.
- Resolution options:
  1. **(Recommended)** Add ADR-0008 to ADR-0009's Depends On, and drop ADR-0008 from ADR-0009's Enables. The `UiSettings` adapter stays as written.
  2. Have ADR-0009 introduce `pre_setup` itself (shared with ADR-0008), and say so in both Ordering Notes.

**LOW: undeclared dependencies on ADR-0013.** ADR-0008 §11 is "per ADR-0013" and was rewritten by it, and ADR-0011 §5 lists `texts` in ADR-0013's `LOC_FIELDS`. ADR-0013 lists both under Enables, but neither lists ADR-0013 under Depends On. The script's order happens to be correct, but the declared graph is incomplete. Fix: add ADR-0013 to the Depends On rows of ADR-0008 and ADR-0011.

**LOW: amendments pending on Accepted ADRs.** These Proposed ADRs amend Accepted ones additively:
- ADR-0008 amends 0002 and 0003.
- ADR-0009 amends 0002 and 0003.
- ADR-0010 amends 0002 and 0006.
- ADR-0011 amends 0001, 0004 and 0007.
- ADR-0012 amends 0001, 0002 and 0005.
- ADR-0013 amends 0004.

None of the Accepted ADRs mention them yet. That matches the project's pattern (ADR-0007's amendment was annotated on acceptance). Each must be annotated when its ADR is Accepted.

No data-ownership, state-authority or performance-budget conflicts were found:
- Settings are owned by ADR-0009. ADR-0005 (`FlashSettings`) and ADR-0008 (`UiSettings`) consume them through interfaces.
- Overworld position is owned by ADR-0012 `WorldState`, and ADR-0009 §3 was revised to match.
- HP writes belong to ADR-0007 `_apply_hp` only.

### ADR Dependency Order
From `adr-dep-graph.sh` (acyclic):

```
Accepted:
  1. ADR-0001 Content Data storage format
  2. ADR-0002 Game State & Scene Flow (0001)
  3. ADR-0004 Content Boot Ordering (0001, 0002)
  4. ADR-0006 Battle Replay Ownership (0002)
  5. ADR-0003 Input System (0001, 0002, 0004)
  6. ADR-0005 Sprite & Camera Presentation (0001, 0002, 0004, 0006)
  7. ADR-0007 Stats & Damage Resolution (0001, 0004)
Proposed, in acceptance order:
  8. ADR-0013 Localization (0001, 0004)
  9. ADR-0008 UI Framework (0002, 0003, 0005, 0006) [+0013 undeclared]
 10. ADR-0009 Save/Load & Settings (0001, 0002, 0003, 0005, 0006) [+0008 undeclared]
 11. ADR-0011 Faction Rule Modifiers (0001, 0004, 0007) [+0013 undeclared]
 12. ADR-0010 Turn Battle System (0001, 0002, 0006, 0007, 0011)
 13. ADR-0012 Overworld Exploration & Encounters (0001–0005): blocked on its GDD
```

⚠️ ADR-0010 depends on ADR-0011, which is still Proposed. ADR-0010 cannot be safely implemented until ADR-0011 is Accepted. This is already stated in both ADRs.

### GDD Revision Flags
No GDD revision flags from engine findings. No GDD assumes full-bleed UI at non-multiple window sizes (F1), and none assumes a localization mechanism (F4). The systems index is unchanged.

Design drift found while extracting (not engine-driven; no systems-index status change):
- `turn-battle-system.md`: no Flee section, although TR-turnbattle-003, ADR-0010 §5 and `game-state-scene-flow.md` (AC-12/13) all have Fled.
- `content-data-definitions.md` Rule 1: needs `map_`/`enc_` record types when ADR-0012 is accepted. Open Question 2 is answered by ADR-0013 on acceptance.
- `turn-battle-system.md` L159/L254 and `faction-rule-modifiers.md` L272: the annotations say "ADR-0007, Proposed"; it is now Accepted.
- `design/gdd/overworld-exploration-encounters.md` does not exist (ADR-0012 is blocked on it).

### Engine Compatibility Issues
Engine: Godot 4.7.2. ADRs with an Engine Compatibility section: 13 / 13. All target 4.7.2.
- Deprecated API references: none. Mentions of `TileMap`, `yield()`, `connect("…")`, `accessibility_live` and `device == 0` are all in avoid or reference context. ADR-0008 L251 notes the 4.7 `AccessibilityServer.AccessibilityLiveMode` retype correctly.
- Stale version references: none. ADR-0005 still cites the presentation GDD "revision 6" (L27, L557); the GDD is now rev 7. The rev-7 mechanics are already in ADR-0005 rev 3, so this is a label only.
- Post-cutoff API conflicts: none between ADRs.
- Reference self-inconsistency (LOW):
  - `current-best-practices.md` L83 still says D3D12 is the Windows default.
  - `modules/ui.md` and `modules/input.md` describe `grab_focus()` as keyboard-only with separate mouse focus. 4.7.2 has one focus owner plus hidden focus (specialist F2/F10).
- Morning advisories still not folded in: E5, E6, E7, E8, E9, E10 (E4 is closed in ADR-0005 §10).

#### Engine Specialist Findings (godot-specialist, headless probes on 4.7.2)
| # | Sev | ADR | Finding | Probe | Blocks acceptance |
|---|---|---|---|---|---|
| F1 | MEDIUM | 0008 | Integer stretch leaves an inset border at window sizes that are not exact multiples: 1600×1200 → 2×, offset (160,120); 1366×768, 1600×900 and 1440×900 too. Full-rect curtain, backdrop and blockers cover only the inset, and the native 3D view shows in the margins. L38 says 2880×1800 is 5×, but the ADR's own `floor(min(W/640, H/360))` gives 4× (verified by this review). L237's "at 16:10 the UI factor equals T" is false there. | PROBED | yes |
| F2 | MEDIUM | 0008 | A mouse click gives **hidden** focus (`has_focus()` true, `has_focus(true)` false), so no focus stylebox is drawn. `PointerFocusSync`'s `grab_focus()` defaults to `hide_focus=false`. The "one indicator" rule is inconsistent, and `refuse()` can pulse an unfocused-looking control. State `hide_focus` per path. | PROBED | yes |
| F3 | MEDIUM | 0008 | A `Container` used as `screen_root` or overlay root lays out the full-rect `GuardBlocker`/`MenuBackdrop` (came out 200×0 in a `VBoxContainer`). Require plain `Control` roots. | PROBED | no |
| F4 | MEDIUM | 0013 / 0008 §11 | Text set from code is translated twice: a `Label` with default `auto_translate_mode` re-translates `tr()`/`LocText` output, and pseudolocalization doubles (`[[Ṕłáý]]`). This breaks §6's screenshot evidence. Require `auto_translate_mode = DISABLED` on code-set text. ADR-0013 L343 only notes the property exists (verified by this review). | PROBED | yes |
| F5 | LOW | 0013 | Open items settled: `tr(&"Open", &"menu.open")` works; `NOTIFICATION_TRANSLATION_CHANGED` arrives synchronously, once per `set_locale()`. `extract_scenes.gd` should read `PackedScene.get_state()` rather than instantiate. | PROBED / REASONED | no |
| F6 | MEDIUM | 0009 | No fsync, and main is renamed to `.bak` first, so tmp→main replaces nothing and ext4's replace-on-rename safeguard doesn't apply. A power loss on the Deck can leave an empty main file. `read_slot` should fall back to `.bak` on `CORRUPT`, not only when main is missing. Whether `flush()` fsyncs is NOT SOURCEABLE. | REASONED | no |
| F7 | LOW | 0009 / 0010 / 0012 | `JSON.stringify` writes 15 significant digits by default, so `party_pos` doesn't round-trip. A 64-bit `rng.state` loses precision as a float. Use `full_precision=true`, and store RNG state as a string. | PROBED | no |
| F8 | LOW | 0009 | `NOTIFICATION_APPLICATION_FOCUS_OUT` as the Deck suspend path is NOT SOURCEABLE (hardware probe owed). `use_custom_user_dir` applies to editor and test runs, so `user://` tests could overwrite real saves. | NOT SOURCEABLE / REASONED | no |
| F9 | LOW | 0008 × 0003 | `InputSystem._input` sees a click before the GUI, so a click on `GuardBlocker` still emits `pointer_confirm`, and `MenuGuard` (L188) doesn't list `pointer_*`. With a 640×360 base and no window size override, the first windowed launch opens 640×360. | REASONED | no |
| F10 | LOW | reference | Correct `ui.md`/`input.md` on focus, alongside the D3D12 line. | PROBED | no |

Also confirmed: `Control.translation_context` exists (introduction version NOT SOURCEABLE); the Linux rename is REASONED; load-time-only `TileMapLayer` + `AStarGrid2D` is sound; ADR-0008's `pre_setup` ordering, deferred `focus_default()` and re-injection fit ADR-0002/0003.

Specialist gate per ADR:

| ADR | Gate |
|---|---|
| 0007 | PASS |
| 0008 | CONCERNS. Fix F1 and F2 before acceptance. |
| 0009 | PASS WITH NOTES (F6–F8). Deck probes owed. |
| 0010 | PASS |
| 0011 | PASS |
| 0012 | PASS (F7 applies) |
| 0013 | CONCERNS. Add the F4 rule. |

### Architecture Document Coverage
`docs/architecture/architecture.md` (v3) exists. Every `systems-index.md` system appears in the layer map, and there is no orphaned architecture. v3 is synced only to ADR-0002–0006, though. **Stale against ADR-0007–0013:**
- Document Status: "ADRs Referenced: ADR-0001 to ADR-0006".
- Module Ownership rows:
  - Stats & Damage still exposes `DamageCalculator.calculate_damage()` with "No ADR yet". ADR-0007 has `DamageResolver`, `ResolutionHooks` and `StatsConfig`, and moves heals out of `SquadSpecials`.
  - Faction Rule Modifiers says "9-method" and "Retroactive ADR recommended". ADR-0011 has 10 methods plus `FactionRuleRegistry`.
  - Turn Battle lacks ADR-0010's `check_command`, `BattleFactory` and `battle_fled`.
  - Save/Load says "format is an open ADR". It is now ADR-0009 `SaveService`.
  - UI Framework says "— (leaf)". ADR-0008 defines `UiService`, `UiContext`, `MenuGuard` and `PromptFacade`.
  - Overworld does not mention ADR-0012's `WorldState` or its map and encounter records.
  - Content Boot Ordering's registrant list lacks the Stats validators, `FactionRuleRegistry` and `LocFieldsValidator`.
  - Localization (ADR-0013) has no row.
- ADR Audit table: lists only ADR-0001–0006. The dependency-order line is stale.
- Technical Requirements Baseline: still lists the morning's "9 gaps", which are now 0.
- Data Flow §5 says "Save/Load & Settings (not built)" with no ADR reference. There is no damage-resolution or settings-delivery flow.

---

### Verdict: CONCERNS

- No requirement is uncovered, and no 🔴 blocking cross-ADR conflict exists.
- 12 of 64 requirements rest on Proposed ADRs, which caps the verdict at CONCERNS.
- Four requirements are partial (three Foundation, one Core). Each is partially covered, not uncovered.
- The engine specialist found three MEDIUM issues that block acceptance: F1 and F2 (ADR-0008) and F4 (ADR-0013).
- `architecture.md` is stale against seven ADRs.

Route to PASS:
1. Fold F1 and F2 into ADR-0008 and F4 into ADR-0013. Fix the undeclared dependencies (0009 → 0008, 0008/0011 → 0013).
2. Accept ADR-0013 → ADR-0008 → ADR-0009 → ADR-0011 → ADR-0010. When each is accepted, annotate its amendments on the Accepted ADRs.
3. Close the partials: TR-content-007/008/010 through an ADR-0001 amendment; TR-stats-005 lands with the enemy-record migration.
4. Write the Overworld GDD, then review and accept ADR-0012.
5. Run `/create-architecture` (sync) or a manual v4 to bring `architecture.md` up to date.

### Blocking Issues
None. The verdict is not FAIL. The items above are the route from CONCERNS to PASS.

### Required ADRs
No new ADR is required for the 7 designed systems. Future ADRs, none blocking (from `architecture.md`): Audio Manager, Quirk State / Combo System (blocked on QQ-02), Dialogue Banter & Quests, Squad Roster, Enemy AI.
