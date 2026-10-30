# Story 030: `BureaucratiaRule` declares no stat, power, tuning, colour or display-string constant, and the Step 0 suite passes unchanged (merged with story 031) (merged with story 032)

> **Epic**: Content Migration
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
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

*Merged from story 031, 2026-10-24:*

*Migration criterion from ADR-0011 Migration Step 4 / §5, scoped to this story:*

- [ ] GIVEN `src/battle/factions/megacorp.gd`, THEN the file contains no `const` declaration; no `Color(` call with a string or numeric literal; none of the strings in `CharacterizationExpected` for MegaCorp (the display names "Security Drone", "Middle Manager", "CEO", the named-attack names "Laser Scan", "Upsell", "Layoffs", "Hostile Takeover", and the banner, tooltip and note strings) as a literal; no match for `display_name\s*==`; a grep of `src/` for each deleted const name (`BILL_MP`, `SECURITY_DRONE_*`, `MIDDLE_MANAGER_*`, `CEO_*`, `LASER_SCAN_POWER`, `UPSELL_POWER`, `LAYOFFS_POWER`, `HOSTILE_TAKEOVER_POWER`) finds nothing; and story 009's gate passes.

*Merged from story 032, 2026-10-24:*

*Migration criterion from ADR-0001 Migration Step 4, scoped to this story:*

- [x] GIVEN `src/battle/squad/specials.gd`, THEN it contains none of `SPEAK_TO_MANAGER_MP_COST`, `APPETIZER_MP_COST`, `APPETIZER_POWER`, `FAMILY_MEAL_MP_COST`, `FAMILY_MEAL_POWER`, `VIRAL_STUNT_MP_COST`, `VIRAL_STUNT_ROUNDS`, `HOME_RUN_MP_COST`, `HOME_RUN_POWER`, and none of the five shipped special names from `CharacterizationExpected` ("Speak to the Manager", "Family Meal", "Appetizer", "Viral Stunt", "Home Run") as a literal; a grep of `src/` for each deleted const name finds nothing; and story 009's gate passes. *(Done 2026-10-30 as story 032, see that file. The Bureaucratia and MegaCorp criteria are still blocked by stories 026 and 027.)*

---

## Implementation Notes

*Derived from ADR-0011 Migration Step 4 and the QA gate (RC-7):*

- **The forbidden set is pinned data (RC-7).** "Player-visible string literal" means the fixture's strings, not every quote: `&"bureaucratia_permit"` StringNames and `push_error` messages are permitted. The test reads the forbidden strings from `CharacterizationExpected`, so the list can't drift from what was pinned.
- **The HUD demo is the one non-obvious caller:** `src/battle/ui/battle_hud_demo.gd` line 83 uses `BureaucratiaRule.PERMIT_ROUNDS + 1`. Replace it with the round read from the rule record's `permit_rounds` (or a rule query method). A parse check alone finds it, but **a parse check is not a run**: open the HUD demo and capture a screenshot of the Bureaucratia granted state to `production/qa/evidence/content-migration-030-hud-granted.png` as supporting evidence. The story type stays Logic.
- The `_named_attack()` helper is gone after story 023. If it still exists, it goes here too.
- Content was moved as-is; nothing is retuned on deletion.
- **Closing condition:** story 009's gate passes, the Step 0 suite green and its files' hashes unchanged; editing a characterization test or the frozen fixture is never the fix.

*Merged from story 031, 2026-10-24:*

*Derived from ADR-0011 Migration Step 4 and the QA gate (RC-7):*

- **The forbidden set is pinned data (RC-7)**, read from `CharacterizationExpected`; StringNames and `push_error` messages are permitted.
- The `display_name ==` check is the guard story 026 earned. It's asserted here because this is where the old branch's last trace (`MIDDLE_MANAGER_DISPLAY_NAME`) is deleted.
- Content was moved as-is; nothing is retuned on deletion.
- **Closing condition:** story 009's gate passes, the Step 0 suite green and its files' hashes unchanged; editing a characterization test or the frozen fixture is never the fix.

*Merged from story 032, 2026-10-24:*

*Derived from ADR-0001 Migration Step 4 and the QA gate (RC-7):*

- **The forbidden set is pinned data (RC-7):** the nine const names and the five display names read from `CharacterizationExpected`.
- **`HEAL_ATTACK_SCALE` is not deleted here.** It's a Stats formula constant (F4) that moves to `StatsConfig.heal_attack_scale` with ADR-0007 Migration Step 2, together with `calculate_heal()`. Deleting it here would be a Core change made from a Foundation story. Story 035's lint allowlists it until the Stats epic removes it, naming the Stats story that does.
- `DamageCalculator`'s constants: same reasoning (ADR-0007 deletes the class).
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

*Merged from story 031, 2026-10-24:*

- `src/battle/factions/megacorp.gd`
- `tests/unit/battle/battle_no_hardcoded_content_test.gd` (MegaCorp case)

*Merged from story 032, 2026-10-24:*

- `src/battle/squad/specials.gd`
- `tests/unit/battle/battle_no_hardcoded_content_test.gd` (specials case)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revision applied: forbidden set pinned as fixture strings plus explicit rules (RC-7)). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: No constants in `BureaucratiaRule`.
  - Given: `bureaucratia.gd` read as text.
  - Then: no `const` line (regex `^\s*const\s`); no `Color\(\s*["0-9]`; none of the Bureaucratia strings from `CharacterizationExpected` as a quoted literal; a grep of `src/` for each deleted const name finds nothing.
  - Edge cases: `&"bureaucratia_permit"` StringNames and `push_error` messages are permitted. Story 009's gate passes.

*Merged from story 031, 2026-10-24:*

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revision applied: same fix as 030 plus the `display_name\s*==` regex (RC-7)). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: No constants in `MegaCorpRule`.
  - Given: `megacorp.gd` read as text.
  - Then: as story 030, for the MegaCorp names and strings; and no match for `display_name\s*==`.
  - Edge cases: StringNames and `push_error` messages are permitted. Story 009's gate passes.

*Merged from story 032, 2026-10-24:*

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
- Logic: `tests/unit/battle/battle_no_hardcoded_content_test.gd` (Bureaucratia case) — must exist and pass, and story 009's gate passes. Gate level: BLOCKING.
- Supporting: `production/qa/evidence/content-migration-030-hud-granted.png`.

**Status**: [ ] Not yet created

*Merged from story 031, 2026-10-24:*

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_no_hardcoded_content_test.gd` (MegaCorp case) — must exist and pass, and story 009's gate passes. Gate level: BLOCKING.

**Status**: [ ] Not yet created

*Merged from story 032, 2026-10-24:*

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_no_hardcoded_content_test.gd` (specials case) — must exist and pass, and story 009's gate passes. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-009-characterization-regression-gate.md`, `story-024-bureaucratia-roster-adapter.md`, `story-026-faction-rule-decisions-from-records.md`, `story-027-faction-rule-presentation-from-records.md`, `story-028-squad-specials-adapter.md`
- Unlocks: `production/epics/content-migration/story-035-no-hardcoded-battle-content-lint.md`
