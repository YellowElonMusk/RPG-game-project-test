# Story 031: `MegaCorpRule` declares no stat, power, tuning, colour or display-string constant and compares no `display_name`, and the Step 0 suite passes unchanged

> **Epic**: Content Migration
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: Faction Rule Modifiers (Migration Step 4; Implementation Guidelines; §5: "MegaCorp also gets a role map … which replaces its display-name comparison")
**ADR Decision Summary**: Once MegaCorp reads everything from its records and keys on `record_id`, its hardcoded constants and display-name branch are deleted.
**ADR Version**: ADR-0011 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: A missing const is a parse error; the parse check finds stale references.

**Control Manifest Rules (this layer)**:
- Required (Feature, ADR-0011): "Rule tuning, rosters, named attacks, colours and player-visible text must be data. Rule scripts must not declare numeric tuning `const`s, colour constants or display strings."
- Required: "Enemy AI keys behaviour off the record `id`, never `display_name`."
- Guardrail: none.

---

## Acceptance Criteria

*Migration criterion from ADR-0011 Migration Step 4 / §5, scoped to this story:*

- [ ] GIVEN `src/battle/factions/megacorp.gd`, THEN the file contains no `const` declaration; no `Color(` call with a string or numeric literal; none of the strings in `CharacterizationExpected` for MegaCorp (the display names "Security Drone", "Middle Manager", "CEO", the named-attack names "Laser Scan", "Upsell", "Layoffs", "Hostile Takeover", and the banner, tooltip and note strings) as a literal; no match for `display_name\s*==`; a grep of `src/` for each deleted const name (`BILL_MP`, `SECURITY_DRONE_*`, `MIDDLE_MANAGER_*`, `CEO_*`, `LASER_SCAN_POWER`, `UPSELL_POWER`, `LAYOFFS_POWER`, `HOSTILE_TAKEOVER_POWER`) finds nothing; and story 009's gate passes.

---

## Implementation Notes

*Derived from ADR-0011 Migration Step 4 and the QA gate (RC-7):*

- **The forbidden set is pinned data (RC-7)**, read from `CharacterizationExpected`; StringNames and `push_error` messages are permitted.
- The `display_name ==` check is the guard story 026 earned. It's asserted here because this is where the old branch's last trace (`MIDDLE_MANAGER_DISPLAY_NAME`) is deleted.
- Content was moved as-is; nothing is retuned on deletion.
- **Closing condition:** story 009's gate passes, the Step 0 suite green and its files' hashes unchanged; editing a characterization test or the frozen fixture is never the fix.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 030: the Bureaucratia constants.
- Story 034: the `make_*()` factories.
- Story 035: the CI lint.

---

## Files

- `src/battle/factions/megacorp.gd`
- `tests/unit/battle/battle_no_hardcoded_content_test.gd` (MegaCorp case)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revision applied: same fix as 030 plus the `display_name\s*==` regex (RC-7)). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: No constants in `MegaCorpRule`.
  - Given: `megacorp.gd` read as text.
  - Then: as story 030, for the MegaCorp names and strings; and no match for `display_name\s*==`.
  - Edge cases: StringNames and `push_error` messages are permitted. Story 009's gate passes.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_no_hardcoded_content_test.gd` (MegaCorp case) — must exist and pass, and story 009's gate passes. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-009-characterization-regression-gate.md`, `story-025-megacorp-roster-adapter.md`, `story-026-faction-rule-decisions-from-records.md`, `story-027-faction-rule-presentation-from-records.md`
- Unlocks: `production/epics/content-migration/story-035-no-hardcoded-battle-content-lint.md`
