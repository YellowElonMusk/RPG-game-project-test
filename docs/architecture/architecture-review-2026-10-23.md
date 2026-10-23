## Architecture Review Report
Date: 2026-10-23
Mode: full
Workflow: full
Engine: Godot 4.7.2
GDDs Reviewed: 8 system GDDs (the 7 from 22c, reused baseline, plus overworld-exploration-encounters rev 4, extracted in full), with game-concept.md and systems-index.md for context
ADRs Reviewed: 13 (ADR-0001 to ADR-0011 and ADR-0013 Accepted; ADR-0012 Proposed, rev 3)

Freshness check against `architecture-review-2026-10-22c.md`: CHANGED ADR-0005, 0008, 0012, 0013, systems-index.md and architecture.md; NEW overworld-exploration-encounters.md. architecture.md changed, which reaches every phase, so a full re-run (autonomous, logged). No `UNRESOLVED` pattern.

Reviewed-Content-Hash: docs/architecture/adr-0001-content-data-storage-format.md ab67bef98298864964489d994cd55a06fe85b26e
Reviewed-Content-Hash: docs/architecture/adr-0002-game-state-scene-flow.md f819e37a3c5d1ebf25c21dd5882b2e64888e99d8
Reviewed-Content-Hash: docs/architecture/adr-0003-input-system.md 6da5598d989e3160995983e1d7c01c0886c1718f
Reviewed-Content-Hash: docs/architecture/adr-0004-content-boot-ordering.md 6958f6a1795c1e67c4d356c55fac4addb8cc2408
Reviewed-Content-Hash: docs/architecture/adr-0005-sprite-camera-presentation.md 86b202b313bafe1c388dca4bb7ff0b672f38cc7b
Reviewed-Content-Hash: docs/architecture/adr-0006-battle-replay-ownership.md e0850122343bf2036da37a113b75e78492f9f30a
Reviewed-Content-Hash: docs/architecture/adr-0007-stats-damage-resolution.md cec133dd8b12b93668a5c9fc8d9bf3ebb5c162d3
Reviewed-Content-Hash: docs/architecture/adr-0008-ui-framework.md 5f0be4e0ada3cb0ba6aa7293d55d591d83e61ca8
Reviewed-Content-Hash: docs/architecture/adr-0009-save-load-settings.md 7c50d04e4f03c4f99074ddc4a478c264a1267cbe
Reviewed-Content-Hash: docs/architecture/adr-0010-turn-battle-system.md dd7e58e6e387ec673a7f550dc09047c599366e7d
Reviewed-Content-Hash: docs/architecture/adr-0011-faction-rule-modifiers.md 64ed8bfdd58327022090c63324bb1936441f3938
Reviewed-Content-Hash: docs/architecture/adr-0012-overworld-exploration-encounters.md 0d298edec80d30b6f961d24ce45fdd8a451c0f51
Reviewed-Content-Hash: docs/architecture/adr-0013-localization.md b6bb09f85ed3aaa6a1fa57083c9378b83d3177c3
Reviewed-Content-Hash: design/gdd/content-data-definitions.md ff14473d0804712400b702666e07824f7d5a2126
Reviewed-Content-Hash: design/gdd/faction-rule-modifiers.md 1812a7f6bd58080ebc680ca89b34742f9258d55b
Reviewed-Content-Hash: design/gdd/game-concept.md ce9474efabc4e96a62cf7d8e9859316615a4189d
Reviewed-Content-Hash: design/gdd/game-state-scene-flow.md ddce44b92bec46e79c96b43f9afb5d5e440f7eb4
Reviewed-Content-Hash: design/gdd/input-system.md 59917d823d98ee03f0cd97d8fcc102f4782bbc52
Reviewed-Content-Hash: design/gdd/overworld-exploration-encounters.md 7ea2b70a2c311bcd42e437d719c8a4c54b6ed32f
Reviewed-Content-Hash: design/gdd/sprite-camera-presentation.md 1b8c310076c4fa6dcbceb63497c1174b95df0064
Reviewed-Content-Hash: design/gdd/stats-damage-resolution.md fe1a2b64b4dd493d7805f4c80713c07413b01a52
Reviewed-Content-Hash: design/gdd/systems-index.md bbd21c19df915445b7881a847fd10481468e26c3
Reviewed-Content-Hash: design/gdd/turn-battle-system.md 26c898f3094f4b9e6ba7e1b8177eb712fc9c3ed8
Reviewed-Content-Hash: docs/architecture/tr-registry.yaml 510aa5cb8a36690646a9809e31c5caf3694e4c8b
Reviewed-Content-Hash: docs/architecture/architecture.md 8a73ccaf343017c34512b2fa9c4e409fd232f218
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
Total requirements: 83 (19 new: TR-overworld-001..019; TR-gamestate-001 and -004 reworded; registry version 4)
✅ Covered (Accepted ADR): 61
🟡 Covered (Proposed ADR): 18 (TR-overworld rows on ADR-0012, Proposed)
⚠️ Partial: 4 (TR-content-007, 008, 010; TR-stats-005), plus TR-overworld-017 partly waiting on ADR-0005 annotation text
❌ Gaps: 0

Requirement extraction: the 7 system GDDs reviewed in 22c and `tr-registry.yaml` were unchanged, so their 64-requirement baseline was reused. The new `overworld-exploration-encounters.md` (rev 4, Approved) was extracted in full: 19 requirements. Full matrix: `docs/architecture/requirements-traceability.md`.

Story linkage (Phase 3b): the 6 MVP stories cite no TR-ID; every requirement is NO STORY. `tests/unit` and `tests/integration` exist (scaffold only).

### Coverage Gaps (no ADR exists)
None.

Partial coverage:
- ⚠️ TR-content-007/008/010 (Foundation), TR-stats-005 (Core): unchanged from 22c.
- ⚠️ TR-overworld-017 (Feature/Core): ADR-0012 §7 states the profile resolution, but ADR-0005's own text still lacks profiles keyed by faction × stage, the liberated profile, `sky_card`, the interior light constraints, the leader-relative blur bounds and per-cue capture-ID tags (incl. `SKY`). These are ADR-0005 annotations listed in ADR-0012's Ordering Note.

### Cross-ADR Conflicts

> Known conflict-prone areas: `docs/consistency-failures.md` does not exist.

No 🔴 conflict remains. Found and resolved in this review (by revising Proposed ADR-0012 and adding a pending revision to ADR-0002):
- **ADR-0012 vs ADR-0002 §1/§4 (integration contract)**: ADR-0012's "amendment (d)" added a fourth entry point and a partial signal sequence as an annotation, contradicting TR-gamestate-001 and ADR-0002's four-signal guideline. Resolved: written as ADR-0002 §11 (pending revision, effective with ADR-0012's acceptance), with legality, a zero-length SWAP, a two-signal exception in the guideline, and `is_in_mode_fade()`. Game State GDD rules 2, 4 and 9 synced.
- **ADR-0012 vs ADR-0002 (state ownership)**: `last_camp_id` (machine) and `WorldState.last_camp_return` stored one fact twice; ADR-0012 routed Retreat to OVERWORLD. Resolved: `camp_returns` map with the return derived from `machine.last_camp_id`; Retreat stays `choose_retreat()` → CAMP.
- **ADR-0012 vs ADR-0002 §8 (data ownership)**: ADR-0002 deleted ChapterFlow; ADR-0012 kept its step list with no holder. Resolved: `WorldState.chapter_step` (single writer `OverworldMode`), interim `ChapterSteps` data, ADR-0002 §8 note.
- **ADR-0012 vs ADR-0002 §2 ("exactly 0 or 1 live mode")**: map change added the new mode before freeing the old. Resolved: detach old → add new → free old on success.

No performance-budget conflict: the overworld's 2 ms p99 share sits inside `frame_budget_ms` 16.6, but is not yet a `project.yaml` key (OQ-19).

### ADR Dependency Order
From `adr-dep-graph.sh`: 13 ADRs, 41 edges, no `NO_DEPS_SECTION` or `UNFILLED_DEPS`. **Acyclic.**

```
Accepted:
  1. ADR-0001 Content Data storage format
  2. ADR-0002 Game State & Scene Flow (0001)  — §11 revision pending
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
 13. ADR-0012 Overworld Exploration & Encounters (0001–0005, 0013) — all dependencies Accepted
```
No Accepted ADR depends on a Proposed one.

### GDD Revision Flags
None from engine findings. The HIGH engine finding G1 (marker `global_position` out of tree) concerns ADR-0012's implementation; no GDD assumes a marker read mechanism. Design sync done during this review (not a flag): `game-state-scene-flow.md` rules 2, 4 and 9 for ADR-0002 §11; Overworld GDD OQ-18 marked resolved.

### Engine Compatibility Issues
Engine: Godot 4.7.2. ADRs with an Engine Compatibility section: 13 / 13, all targeting 4.7.2. No deprecated-API references (ADR-0012 now bans the deprecated `TileMap` in maps). No stale version references beyond the 22c label note. No post-cutoff API conflicts.

#### Engine Specialist Findings (godot-specialist; scope: delta since 22c; probes on 4.7.2)
| # | Sev | ADR | Finding | Basis | Status |
|---|---|---|---|---|---|
| — | — | 0008 §9 | 22c E1/E2 fixed (per-frame refit; `min_size` clamps 600×300 → 640×360) | PROBED | closed |
| — | — | 0005 / 0013 | E4 and E6 notes correct | SOURCED | closed |
| G1 | **HIGH** | 0012 §3/§4 | Markers read out of tree: `global_position` returns the origin | PROBED | fixed (map-root-relative local transforms) |
| G2 | MEDIUM | 0012 §4 | `WorldState` written in `_ready` survives a rolled-back map change | REASONED | fixed (commit on `mode_entered`) |
| G3 | MEDIUM | 0012 §4 ↔ 0002 §2 | Two live modes during map change | REASONED | fixed (detach first) |
| G4 | MEDIUM | 0012 (d) ↔ 0002 | Overlay order, SWAP phase, guideline for the in-mode fade | REASONED | fixed (ADR-0002 §11) |
| G5 | LOW | 0012 §5 | `transition_finished` has no type; payoff card after a redirect | REASONED | fixed (`pending_thaw`) |
| G6 | LOW | 0012 §2 | `GameRoot` priority unpinned | PROBED | fixed (−20) |
| G7 | LOW | 0012 §3 | Deprecated `TileMap` builds collision | SOURCED | fixed (in class list) |
| G8 | LOW | 0012 (e) | Two records of the last camp | REASONED | fixed (derived return) |

Gates: 0005 PASS, 0008 PASS, 0013 PASS, 0002 PASS with §11 wording, 0012 CONCERNS → all items fixed in text.

TD-ADR (technical-director) on ADR-0012 rev 3: CONCERNS, 4 blocking (ADR-0002 annotation scope, camp state twice, ChapterFlow ownership, stale references) → all fixed; advisories folded.

### Architecture Document Coverage
`docs/architecture/architecture.md` (v4) lists every system in the systems index; no orphaned architecture. **Stale against this review:** the ADR Audit row for ADR-0012 still says "no GDD, so no TR IDs", the build-order note still asks for the Overworld GDD, and the Overworld module row predates ADR-0012 rev 3 (`SymbolBrain`, `WorldState.camp_returns`/`chapter_step`, ADR-0002 §11). Sync with `/create-architecture` after ADR-0012 is accepted. `control-manifest.md` (2026-10-22) lacks ADR-0012's rules and the `Engine.time_scale` ban; regenerate on acceptance (a schema change: needs the user).

---

### Verdict: CONCERNS

- No requirement is uncovered and there is no remaining cross-ADR conflict or dependency cycle.
- 18 requirements rest on Proposed ADR-0012, which caps the verdict at CONCERNS. Route out: `/architecture-decision accept ADR-0012` (its ADR-0002 §11 revision takes effect with it).
- Five partials (four carried from 22c, plus TR-overworld-017 waiting on ADR-0005 annotation text).
- One HIGH engine finding (G1) was found and fixed in ADR-0012 during this review.
- `architecture.md` and the control manifest are stale against ADR-0012 rev 3.

Route to PASS:
1. Accept ADR-0012 (ADR-0002 §11, ADR-0001 record types and the ADR-0005 annotations take effect).
2. Write the ADR-0005 annotation text for TR-overworld-017.
3. Close the 22c partials (ADR-0001 amendment; enemy-record migration).
4. `/create-architecture` sync, then `/create-control-manifest`; add the OQ-19 budget to `project.yaml` if the user agrees.

### Blocking Issues
None at verdict level.

### Required ADRs
No new ADR is required. Future ADRs, none blocking: Audio Manager, Quirk State / Combo System, Dialogue Banter & Quests (replaces the interim flag registry and `ChapterSteps`), Squad Roster, Enemy AI.
