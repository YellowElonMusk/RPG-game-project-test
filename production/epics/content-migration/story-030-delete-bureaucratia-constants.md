# Story 030: `BureaucratiaRule` declares no stat, power, tuning, colour or display-string constant, and the Step 0 suite passes unchanged

> **Epic**: Content Migration
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-005` (data, not code)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: Faction Rule Modifiers (Migration Step 4: "delete the `const` tuning, colour and text constants"; Implementation Guidelines: "Rule scripts must not declare numeric tuning `const`s, colour constants or display strings")
**ADR Decision Summary**: Once the rule reads everything from its records, the hardcoded constants are deleted so the data is the only source.
**ADR Version**: ADR-0011 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: A missing const is a parse error, so the parse check finds stale references; it is not a run (see the HUD-demo note).

**Control Manifest Rules (this layer)**:
- Required (Feature, ADR-0011): "Rule tuning, rosters, named attacks, colours and player-visible text must be data. Rule scripts must not declare numeric tuning `const`s, colour constants or display strings."
- Forbidden: hardcoded content constants in `src/battle/factions/`.
- Guardrail: none.

---

## Acceptance Criteria

*Migration criterion from ADR-0011 Migration Step 4, scoped to this story:*

- [ ] GIVEN `src/battle/factions/bureaucratia.gd`, THEN the file contains no `const` declaration; no `Color(` call with a string or numeric literal; and none of the strings in `CharacterizationExpected` for Bureaucratia (the display names "Clerk" and "Supervisor", the named-attack names "Pen Jab", "Red Tape", "Late Fee", "Mass Audit", "Final Notice", and the banner and tooltip strings) as a literal; a grep of `src/` for each deleted const name (`PERMIT_ROUNDS`, `LOW_HP_THRESHOLD`, `HUNKER_JAB_POWER`, `FOCUS_ATTACK_POWER`, `LATE_FEE_POWER`, `MASS_AUDIT_POWER`, `FINAL_NOTICE_POWER`, `CLERK_*`, `SUPERVISOR_*`) finds nothing; and story 009's gate passes.

---

## Implementation Notes

*Derived from ADR-0011 Migration Step 4 and the QA gate (RC-7):*

- **The forbidden set is pinned data (RC-7).** "Player-visible string literal" means the fixture's strings, not every quote: `&"bureaucratia_permit"` StringNames and `push_error` messages are permitted. The test reads the forbidden strings from `CharacterizationExpected`, so the list can't drift from what was pinned.
- **The HUD demo is the one non-obvious caller:** `src/battle/ui/battle_hud_demo.gd` line 83 uses `BureaucratiaRule.PERMIT_ROUNDS + 1`. Replace it with the round read from the rule record's `permit_rounds` (or a rule query method). A parse check alone finds it, but **a parse check is not a run**: open the HUD demo and capture a screenshot of the Bureaucratia granted state to `production/qa/evidence/content-migration-030-hud-granted.png` as supporting evidence. The story type stays Logic.
- The `_named_attack()` helper is gone after story 023. If it still exists, it goes here too.
- Content was moved as-is; nothing is retuned on deletion.
- **Closing condition:** story 009's gate passes, the Step 0 suite green and its files' hashes unchanged; editing a characterization test or the frozen fixture is never the fix.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 031: the MegaCorp constants.
- Story 033: `is_manager()`.
- Story 034: the `make_*()` factories.
- Story 035: the CI lint.

---

## Files

- `src/battle/factions/bureaucratia.gd`
- `src/battle/ui/battle_hud_demo.gd` (line 83)
- `tests/unit/battle/battle_no_hardcoded_content_test.gd` (Bureaucratia case)
- `production/qa/evidence/content-migration-030-hud-granted.png` (supporting)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revision applied: forbidden set pinned as fixture strings plus explicit rules (RC-7)). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: No constants in `BureaucratiaRule`.
  - Given: `bureaucratia.gd` read as text.
  - Then: no `const` line (regex `^\s*const\s`); no `Color\(\s*["0-9]`; none of the Bureaucratia strings from `CharacterizationExpected` as a quoted literal; a grep of `src/` for each deleted const name finds nothing.
  - Edge cases: `&"bureaucratia_permit"` StringNames and `push_error` messages are permitted. Story 009's gate passes.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_no_hardcoded_content_test.gd` (Bureaucratia case) — must exist and pass, and story 009's gate passes. Gate level: BLOCKING.
- Supporting: `production/qa/evidence/content-migration-030-hud-granted.png`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-009-characterization-regression-gate.md`, `story-024-bureaucratia-roster-adapter.md`, `story-026-faction-rule-decisions-from-records.md`, `story-027-faction-rule-presentation-from-records.md`
- Unlocks: `production/epics/content-migration/story-035-no-hardcoded-battle-content-lint.md`
