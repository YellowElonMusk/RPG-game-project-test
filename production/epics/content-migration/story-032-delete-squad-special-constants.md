# Story 032: `SquadSpecials` declares no MP-cost, power or rounds constant for any special, and the Step 0 suite passes unchanged

> **Epic**: Content Migration
> **Status**: Merged into story 030 (2026-10-24)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-006` (the specials are data, read by their owner)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Migration Step 4); EPIC.md Steps 4–5
**ADR Decision Summary**: Once the specials' factories read their records, the specials' hardcoded cost, power and rounds constants and display names are deleted.
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: A missing const is a parse error; the parse check finds stale references.

**Control Manifest Rules (this layer)**:
- Required: "Static factories become adapters…".
- Required (*Core*): "Every tuning number comes from `StatsConfig`" (why `HEAL_ATTACK_SCALE` waits for Stats).
- Guardrail: none.

---

## Acceptance Criteria

*Migration criterion from ADR-0001 Migration Step 4, scoped to this story:*

- [ ] GIVEN `src/battle/squad/specials.gd`, THEN it contains none of `SPEAK_TO_MANAGER_MP_COST`, `APPETIZER_MP_COST`, `APPETIZER_POWER`, `FAMILY_MEAL_MP_COST`, `FAMILY_MEAL_POWER`, `VIRAL_STUNT_MP_COST`, `VIRAL_STUNT_ROUNDS`, `HOME_RUN_MP_COST`, `HOME_RUN_POWER`, and none of the five shipped special names from `CharacterizationExpected` ("Speak to the Manager", "Family Meal", "Appetizer", "Viral Stunt", "Home Run") as a literal; a grep of `src/` for each deleted const name finds nothing; and story 009's gate passes.

---

## Implementation Notes

*Derived from ADR-0001 Migration Step 4 and the QA gate (RC-7):*

- **The forbidden set is pinned data (RC-7):** the nine const names and the five display names read from `CharacterizationExpected`.
- **`HEAL_ATTACK_SCALE` is not deleted here.** It's a Stats formula constant (F4) that moves to `StatsConfig.heal_attack_scale` with ADR-0007 Migration Step 2, together with `calculate_heal()`. Deleting it here would be a Core change made from a Foundation story. Story 035's lint allowlists it until the Stats epic removes it, naming the Stats story that does.
- `DamageCalculator`'s constants: same reasoning (ADR-0007 deletes the class).
- **Closing condition:** story 009's gate passes, the Step 0 suite green and its files' hashes unchanged; editing a characterization test or the frozen fixture is never the fix.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The Stats epic: `HEAL_ATTACK_SCALE`, the heal helpers, `DamageCalculator`.
- Story 033: `apply_stun()`'s `is_manager` call.
- Story 035: the CI lint.

---

## Files

- `src/battle/squad/specials.gd`
- `tests/unit/battle/battle_no_hardcoded_content_test.gd` (specials case)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revision applied: forbidden literals are the five shipped special names (RC-7)). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: No special constants.
  - Given: `specials.gd` read as text.
  - Then: it contains none of the 9 const names or the 5 names as literals; a grep of `src/` for the deleted names finds nothing.
  - Edge cases: `HEAL_ATTACK_SCALE` is present, as expected. Story 009's gate passes.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_no_hardcoded_content_test.gd` (specials case) — must exist and pass, and story 009's gate passes. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-009-characterization-regression-gate.md`, `story-028-squad-specials-adapter.md`
- Unlocks: `production/epics/content-migration/story-035-no-hardcoded-battle-content-lint.md`
