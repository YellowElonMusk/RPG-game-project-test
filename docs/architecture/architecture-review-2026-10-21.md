## Architecture Review Report
Date: 2026-10-21
Mode: full
Workflow: full
Engine: Godot 4.7.2
GDDs Reviewed: 6 (content-data-definitions, game-state-scene-flow, input-system, stats-damage-resolution, turn-battle-system, faction-rule-modifiers)
ADRs Reviewed: 1 (ADR-0001, Accepted)

Reviewed-Content-Hash: docs/architecture/adr-0001-content-data-storage-format.md b968532303456bf5f20943c64c909dbb06b4aa9d
Reviewed-Content-Hash: design/gdd/content-data-definitions.md a49084f2b558d15e2f6d5846e6bae8356984f16e
Reviewed-Content-Hash: design/gdd/faction-rule-modifiers.md db710305b56cd2971696d709497f1671afe24173
Reviewed-Content-Hash: design/gdd/game-concept.md ce9474efabc4e96a62cf7d8e9859316615a4189d
Reviewed-Content-Hash: design/gdd/game-state-scene-flow.md 461d22da7b41887fb0f58644b8db008b22f6c0b5
Reviewed-Content-Hash: design/gdd/input-system.md 1120fa798a0cb1a16ea89c89286c570cd7f0bf0e
Reviewed-Content-Hash: design/gdd/stats-damage-resolution.md fe1a2b64b4dd493d7805f4c80713c07413b01a52
Reviewed-Content-Hash: design/gdd/systems-index.md 281f2fd42fc3753cbb38ae862152ab7844ce9540
Reviewed-Content-Hash: design/gdd/turn-battle-system.md 29afa993d907cb2f91868f6ea19e42fed4552679
Reviewed-Content-Hash: docs/architecture/tr-registry.yaml 5ed42c79dfb0e53224ba588a6bdd080bc9003809
Reviewed-Content-Hash: docs/architecture/architecture.md 49292bf3f3e1e7524ce16ad16ceb8d4b0c0c27ec
Reviewed-Content-Hash: docs/engine-reference/godot/VERSION.md ddeee991a78c7e94b4e1b0d0e3605dcebd9d5fa7
Reviewed-Content-Hash: docs/engine-reference/godot/breaking-changes.md 4bc55e16796664ff88c7582c9f08e3530f7c94d4
Reviewed-Content-Hash: docs/engine-reference/godot/current-best-practices.md a45cd2c39a8ec53eaa3e924f39f93594e62085fd
Reviewed-Content-Hash: docs/engine-reference/godot/deprecated-apis.md 6a1353983e1db0d7bc0cc41a568b039495b5413c
Reviewed-Content-Hash: docs/engine-reference/godot/modules/animation.md ee51f50a46f8c63b771f62fe438947d4d84c59e3
Reviewed-Content-Hash: docs/engine-reference/godot/modules/audio.md c72af247505908a04f84a1dd3e765939efe700bd
Reviewed-Content-Hash: docs/engine-reference/godot/modules/input.md 3406b1b813858898696e510ea0accfcc7df98af8
Reviewed-Content-Hash: docs/engine-reference/godot/modules/navigation.md 7ae18ffbd2c3230cb19d610373225bfba187a472
Reviewed-Content-Hash: docs/engine-reference/godot/modules/networking.md 6606880462a2241014f77feb9610c5611e659ec6
Reviewed-Content-Hash: docs/engine-reference/godot/modules/physics.md 3b6ac8947f3f3e8c9ac9e6e0ff6cac06fdb8d805
Reviewed-Content-Hash: docs/engine-reference/godot/modules/rendering.md 2a303185bb57eed31dd1151a036784820747b211
Reviewed-Content-Hash: docs/engine-reference/godot/modules/ui.md 30ad166ab8c4e92c15aa37ed3464483b92b7845b
Reviewed-Content-Hash: project.yaml dd24b70e820bed481810a3ec6c0afe6341cb9bfa
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
Total requirements: 35 (first registered baseline: 17 from architecture.md's provisional list, kept under their IDs, plus 18 new)
✅ Covered: 6
⚠️ Partial: 10
❌ Gaps: 19

Full matrix: `docs/architecture/requirements-traceability.md`. Registry: `docs/architecture/tr-registry.yaml`.

### Coverage Gaps (no ADR exists)
  ❌ TR-gamestate-001..004, 006: Game State & Scene Flow (mode/overlay machine, transition locking, freeze/restore, retry/retreat, data-driven timing)
     Suggested ADR: "/architecture-decision game-state-scene-flow". Domain: Core. Engine Risk: MEDIUM
  ❌ TR-input-002..006: Input System (deadzone, device identity, device/focus broadcasts, active device, no Game State dependency)
     Suggested ADR: "/architecture-decision input-system". Domain: Input. Engine Risk: HIGH
  ❌ TR-stats-001..004: Stats & Damage (pipeline, injected RNG, modifier/override registration, outcome records)
     Suggested ADR: "/architecture-decision retrofit" for Stats & Damage. Domain: Core. Engine Risk: LOW
  ❌ TR-turnbattle-001..003: Turn Battle (state machine, gates, Game State outcome handshake)
     Suggested ADR: "/architecture-decision retrofit" for Turn Battle. Domain: Core. Engine Risk: LOW
  ❌ TR-factionrules-001: FactionRule contract. Suggested ADR: retroactive Faction Rule Modifiers ADR (before ADR-0001's migration). Engine Risk: LOW
  ❌ TR-content-012: localization extraction. Deferred to before Alpha (GDD Open Question 2). Engine Risk: LOW

### Cross-ADR Conflicts
None. Only one ADR exists.

### ADR Dependency Order
`adr-dep-graph.sh`: ADRS 1, EDGES none, ORDER adr-0001. ADR-0001 declares "Depends On: None" explicitly, so this is a real empty set, not an unfilled one.
Foundation (no dependencies):
  1. ADR-0001: Content Data Storage Format

### GDD Revision Flags
None from engine findings. All GDD assumptions are consistent with verified engine behaviour (Input Rule 11 already follows the 4.7 `DEVICE_ID_*` change, and Input Rule 3 already follows 4.6 dual focus).

**GDD-to-GDD and GDD-to-code conflicts.** These are not engine flags. Run `/consistency-check` or `/propagate-design-change` on them:
1. Stats & Damage Rule 9 step 5 has faction rules act through priority overrides, but the FactionRule 9-method contract has no modifier or override hook, and Bureaucratia works through `specials_allowed()`.
2. Stats & Damage Rule 11 expects `unaffordable` / `no_target` outcome records, but Turn Battle returns `null` for a rejected submit.
3. Game State Rule 7 expects Victory / Fled / Defeat plus results-done, but Turn Battle has no flee and only a won/lost bool.

### Engine Compatibility Issues
Engine: Godot 4.7.2. ADRs with an Engine Compatibility section: 1 / 1.
Deprecated API references: none. Stale version references: none.
Post-cutoff API: `ResourceLoader.list_directory()` (4.4+) verified in the editor only. **Exported-build verification is still pending** (MEDIUM). Also check that the returned names end in `.tres`, that the export filter includes `data/**`, and that `get_global_class_list()` works in an export.

### Engine Specialist Findings (godot-specialist)
- **HIGH: autoload ordering (confirms TD-MANIFEST).** Turn Battle System is not an autoload, so it cannot register effect types before `ContentCatalog._ready()` calls `load_all()`. Fix: `ContentCatalog._ready()` does not load. A `Boot` autoload listed after it (later the Game State bootstrap) registers the vocabularies and then calls `load_all()`.
- **HIGH: the raw-text unknown-field check breaks in exported builds.** Exports convert `.tres` to binary (`editor/export/convert_text_resources_to_binary`), so `FileAccess` on the `.tres` path fails. Fix: unknown-field detection runs only in editor and CI (`OS.has_feature("editor")` or the validator script). Exports run ID, range and reference checks only. Worth testing: whether 4.x keeps unknown properties as `_missing_resource_properties` metadata, which would be an export-agnostic alternative. [unverified]
- **HIGH: the headless validator conflicts with the autoload.** `-s` script mode cannot resolve autoload identifiers, and a second `load_all()` is forbidden. Fix: put load and validation in a plain `class_name ContentLoader` (RefCounted) that both the autoload and `validate-content.gd` create. This is also unit-testable, in line with the DI standard.
- **MEDIUM: the line scan of `[resource]` is fragile.** Multi-line arrays and strings (`effects`) span lines. Count only top-level `key = value` lines, and allow-list `script`, `resource_name`, `resource_local_to_scene` and `metadata/*`. Filter `get_property_list()` by `PROPERTY_USAGE_STORAGE`.
- **MEDIUM: cached instances alias.** With `CACHE_MODE_REUSE`, `effects` arrays and dictionaries are shared. Adapters must copy or `.duplicate(true)` them, and a test should mutate a built `Move` and check the record is unchanged (TR-content-007 / AC-5).
- **MEDIUM:** a `.tres` whose script fails to parse may load as a bare `Resource`, not `null`. Also check `record is <RecordClass>`.
- **LOW:** `Array[Dictionary]` is awkward to edit in the Inspector (already accepted in the ADR).

### Architecture Document Coverage
- Every systems-index system appears in architecture.md's layer map.
- Missing from Data Flow / API Boundaries: the Stats modifier/override registration (Quirk, Faction, Items); Stats outcome records and the KO event to UI and Codex; the Battle ↔ Game State outcome handshake and Encounter descriptor; Input's `active_device_changed` `pad_style` argument; the Input ↔ UI pointer and focus-sync contract; Stats F9 reward totals to Leveling and Items (Vertical Slice).
- Inaccuracy: architecture.md says SquadSpecials has 4 specials, but `src/battle/squad/specials.gd` has 5 (`make_viral_stunt`).
- Orphans: **SquadSpecials** has no owning system in systems-index; **ChapterFlow** overlaps TR-gamestate-004 and TR-turnbattle-003 (QQ-01).

---

### Verdict: FAIL

Foundation-layer requirements are uncovered (Game State & Scene Flow and Input System have no ADR), and ADR-0001 carries three HIGH engine findings that make TR-content-003 and TR-content-006 impossible to implement as written.

### Blocking Issues (must resolve before PASS)
1. **Amend ADR-0001**: the Boot-autoload registration order, `ContentLoader` extracted for the headless validator, unknown-field detection limited to editor and CI, aliasing protection for cached records. This blocks the Content Data Definitions implementation.
2. **Write and accept the Game State & Scene Flow ADR** (TR-gamestate-*), including the `ChapterFlow` overlap.
3. **Write and accept the Input System ADR** (TR-input-*).

### Required ADRs
1. ADR-0001 amendment (Foundation, HIGH): needed before any catalog code
2. Game State & Scene Flow (Foundation, MEDIUM)
3. Input System (Foundation, HIGH)
4. Sprite & Camera Presentation (Core): before Overworld (architecture.md)
5. Retroactive Faction Rule Modifiers ADR: before ADR-0001's migration touches it
6. Retroactive Stats & Damage and Turn Battle ADRs: also settle the three GDD conflicts above
