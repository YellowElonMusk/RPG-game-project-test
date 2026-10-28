# Story 007: Both faction rules' banner text, tooltip text, combatant note and colours are pinned for every round state

> **Epic**: Content Migration
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-28

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: None (Step 0 characterization)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: Faction Rule Modifiers (§1 presentation group; §5 "texts", "colors"). Also ADR-0001: Content Data Definitions Storage & Loading Format (Migration Step 0).
**ADR Decision Summary**: ADR-0011 moves rule text and colours into `faction_rule` and `faction` records. Nothing else pins them, so this story pins them before they move, giving story 027 an "unchanged" to prove.
**ADR Version**: ADR-0011 2026-10-22 · ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API. `TranslationServer.set_locale()` is long-standing.

**Control Manifest Rules (this layer)**:
- Required: "Characterization tests are written against today's hardcoded factories before migration and rerun unchanged after it."
- Required (ADR-0013): "Every string-typed record export is listed in exactly one of the record script's `LOC_FIELDS` or `NON_LOC_FIELDS`" (why these strings must be pinned before they become record text).
- Guardrail: none (test code).

---

## Acceptance Criteria

*Migration criterion from ADR-0011 §1/§5 and ADR-0001 Migration Step 0, scoped to this story:*

- [ ] GIVEN both rules under the `en` locale, with combatant states arranged through `seam.arrange_vitals`, THEN `get_banner_text(r)` and `get_tooltip_text(r)` for r = 1, 2, 3, 4 (Bureaucratia: "3 rounds", "2 rounds", "1 round", granted; MegaCorp: constant), `get_combatant_tooltip_note()` for a suspended, a non-suspended, a knocked-out and an enemy combatant, `get_identity_color()` and `get_banner_color(r)` equal the pinned strings (byte-exact, including the em dashes) and colours.

---

## Implementation Notes

*Derived from ADR-0011 §1/§5 and the QA gate (RC-1):*

- The singular "1 round" (round 3) is the case that forces the two-key template in story 017 (`banner_locked_one`/`banner_locked_other`, Q6). Pin it explicitly.
- Colours are compared as `Color` values with `is_equal_approx`, and also as `to_html(false)` strings, so `#b07a12` vs `#B07A12` can't matter but a channel change can.
- **Locale.** The test sets `TranslationServer.set_locale("en")` in `before_test` and restores the previous locale in `after_test` (the seam provides the helper). Once ADR-0013 lands, a non-English locale would change the strings.
- Suspended (MP 0) and knocked-out cases are arranged with `seam.arrange_vitals` (RC-1).
- The neutral fallback rule's identity colour (`#4a5a8a`) is pinned as the control case. ADR-0011 §1 later changes that default; that is out of scope for this epic (see 027).
- Epic-wide rules: strings and colours are copied from running today's code into `CharacterizationExpected`, never read from the rules' constants; **watch it fail** (change one character of a banner locally, see the byte compare fail, revert, record it).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: the rules' decisions.
- Story 017: the `texts`/`colors` record contents and template-fill check.
- Story 027: presentation read from records.

---

## Files

- `tests/unit/battle/battle_faction_rule_presentation_characterization_test.gd` — created (7 test functions: banner/tooltip text by round for both rules, combatant tooltip note for both rules, colours by round for both rules, neutral control case)
- `tests/unit/battle/fixtures/characterization_expected.gd` — modified (presentation block: banner/tooltip text, colours, suspended note)

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revisions applied: arrangement through `seam.arrange_vitals`; locale set in `before_test` and restored in `after_test`). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Presentation equals the pins.
  - **Test: banner and tooltip by round.**
    - Given: r = 1..4 for both rules.
    - Then: the strings equal the fixture byte for byte (compare with `==`, and also as `to_utf8_buffer()` so the em dash is checked as bytes).
    - Edge cases: r = 3 is "1 round" (singular); r = 4 is the granted text.
  - **Test: combatant note.**
    - Then: MegaCorp: suspended (mp 0), non-suspended, KO and enemy give the pins. Bureaucratia gives `""` for all four, pinned.
  - **Test: colours.**
    - Then: `get_identity_color()` and `get_banner_color(r)` for r = 1..4 match by `is_equal_approx` and by `to_html(false)`.
    - Edge cases: Bureaucratia r = 4 is `b07a12`. The neutral fallback is `4a5a8a`, the control case.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_faction_rule_presentation_characterization_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-001-characterization-seam.md`
- Unlocks: `production/epics/content-migration/story-009-characterization-regression-gate.md`, `story-017-author-faction-rule-records.md`, `story-027-faction-rule-presentation-from-records.md`

---

## Completion Notes
**Completed**: 2026-10-28
**Criteria**: 1/1 passing
**Deviations**: None
**Watch it fail**: MegaCorp's banner was temporarily changed ("billing" → "Billing") in `src/battle/factions/megacorp.gd`; 8 assertions failed across the round-by-round checks. Reverted; `git status` confirmed `src/` was clean again.
**Test Evidence**: `tests/unit/battle/battle_faction_rule_presentation_characterization_test.gd` — 7/7 passing; full test tree 268/268, 0 errors/failures/orphans
**Reviewed by**: `/code-review` (APPROVED WITH SUGGESTIONS — an overclaiming doc comment reworded and re-verified before close)
