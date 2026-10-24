# Story 035: A CI lint finds no shipped battle content hardcoded under `src/battle/`, outside a reviewed allowlist

> **Epic**: Content Migration
> **Status**: Blocked — BLOCKED: after its dependencies; blocked through story 034 (and 033)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-005`, `TR-factionrules-002` (closing evidence for the epic's DoD)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: Faction Rule Modifiers (Validation Criteria: "CI grep"); EPIC.md DoD ("No battle content remains hardcoded in `src/battle/`")
**ADR Decision Summary**: A CI grep keeps rule-subclass references inside `src/battle/factions/` and keeps content constants out of the rule and squad code, so the migration can't silently regress.
**ADR Version**: ADR-0011 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: The lint is a bash script; the CI runner is Ubuntu, so bash on a Windows dev machine is not required. The gdUnit4 test runs it with `OS.execute`.

**Control Manifest Rules (this layer)**:
- Required (Feature, ADR-0011): the CI grep covers rule-subclass references outside `src/battle/factions/`.
- Required: "Attack and Defend stay code-side factories" (allowlisted on purpose).
- Guardrail: the lint runs in CI, not at runtime.

---

## Acceptance Criteria

*Migration criterion from ADR-0011 Validation Criteria and EPIC.md DoD, scoped to this story:*

- [ ] GIVEN `tools/ci/lint_battle_content.sh`, WHEN run on `src/`, THEN it exits 0. WHEN run on fixture files containing each forbidden pattern (a `BureaucratiaRule.`/`MegaCorpRule.` reference outside `src/battle/factions/`, a `display_name ==` comparison in a rule class, a numeric/`Color`/display-string `const` in `src/battle/factions/` or `src/battle/squad/`, and a `Combatant.new(` with literal stats outside the allowlist), THEN it exits 1 and names the file and line for each.

---

## Implementation Notes

*Derived from ADR-0011 Validation Criteria and the draft's Q8 resolution:*

- **Initial allowlist** (`tools/ci/lint_battle_content_allowlist.txt`), one line and reason each (Q8): `src/battle/ui/battle_hud_demo.gd` `SQUAD_*` (harness squad); `src/battle/battle_debug_harness.gd` (harness squad and `TEST_SPECIAL_MP_COST`); `src/chapters/chapter_flow_demo.gd` `SQUAD_*` (outside `src/battle/` but harness); `src/battle/squad/specials.gd` `HEAL_ATTACK_SCALE` and `src/battle/damage_calculator.gd` (Stats, until ADR-0007 Step 2, naming the Stats story that removes them); `src/battle/move.gd` `make_attack`/`make_defend` (code-side by ADR-0001). An allowlist line without a reason is itself an error.
- **Watch it fail:** the fixture run is the failing half. Also run it once on the pre-030 tree (a branch at 029) and confirm it flags the real constants; record that in the Completion Notes.
- It overlaps ADR-0007's own HP-write lint and `src/battle/stats/` layering grep, which are a separate script owned by Stats. Don't merge the two.
- Q1 (squad characters) decides whether the demo/harness squads later read `char_*` records; until then they stay allowlisted.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Stories 030–034: the deletions this lint guards.
- Story 022: the no-paths scan on records.
- ADR-0007's `lint_hp_writes.sh` (Stats).

---

## Files

- `tools/ci/lint_battle_content.sh`
- `tools/ci/lint_battle_content_allowlist.txt`
- `tests/unit/battle/fixtures/lint/…` (one bad file per pattern, one allowlisted file)
- `tests/unit/battle/battle_content_lint_test.gd`
- `.github/workflows/tests.yml` (lint step)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict ADEQUATE). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: The lint passes on `src/` and fails on each pattern.
  - **Test: lint passes on src/.**
    - Then: exit 0 on `src/`.
  - **Test: each fixture pattern fails.**
    - Given: each bad fixture.
    - Then: exit 1, and the output contains `<file>:<line>`.
    - Edge cases: an allowlisted file and symbol passes. An allowlist line without a reason is itself an error. Run once on the 029-era tree, record that it flags the real constants, and keep that in the Completion Notes.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_content_lint_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-022-migrated-records-no-paths.md`, `story-030-delete-bureaucratia-constants.md`, `story-033-delete-is-manager.md`, `story-034-delete-roster-factories.md`
- Unlocks: epic close (`/story-done` on the last story → EPIC DoD review)
