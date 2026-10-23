# Story 027: Both rules' banner text, tooltip text, combatant note and colours come from their faction and `faction_rule` records, and the Step 0 suite passes unchanged

> **Epic**: Content Migration
> **Status**: Blocked — BLOCKED: needs story 026; reading `texts` through `LocText.of_key()` needs ADR-0013's `LocText` (no epic yet). Recommended unblock: read `texts` directly until `LocText` exists, behind a `# TODO(ADR-0013)` line. English output is identical.
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-005` (colours and text by record, not code)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: Faction Rule Modifiers (§1 presentation group defaults; §5 "Text formatting"). Also ADR-0013: Localization (§4).
**ADR Decision Summary**: Rule presentation (banner, tooltip, combatant note, banner colour) is filled from the `faction_rule` record's `texts`/`colors`, and the identity colour comes from the faction record.
**ADR Version**: ADR-0011 2026-10-22 · ADR-0013 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `String.format()` with a Dictionary is a long-standing API. `Color(hex)` parsing accepts `#rrggbb`.

**Control Manifest Rules (this layer)**:
- Required (Feature, ADR-0011): "Rule tuning, rosters, named attacks, colours and player-visible text must be data."
- Required (ADR-0013): "Every string-typed record export is listed in exactly one of … `LOC_FIELDS` or `NON_LOC_FIELDS`."
- Guardrail: presentation strings are built on demand by the HUD; no per-frame formatting budget concern at this scale.

---

## Acceptance Criteria

*Migration criterion from ADR-0011 §1/§5, scoped to this story:*

- [ ] GIVEN configured rules, WHEN the presentation methods run for rounds 1–4 and each combatant case, THEN every string is the record's template filled with `String.format()` (Bureaucratia choosing `banner_locked_one`/`_other` by `rounds_left`), `get_identity_color()` returns the faction record's `signature_color`, Bureaucratia's granted banner colour comes from `colors.banner_unlocked`, and story 009's gate passes (007 green, unchanged); AND a fixture rule whose `banner_locked_other` is `"X{rounds_left}"`, with a faction whose `signature_color` is `#010203`, makes `get_banner_text(1) == "X3"` and `get_identity_color()` equal to `#010203`.

---

## Implementation Notes

*Derived from ADR-0011 §1/§5 and the QA gate (RC-8):*

- **Data vs leftover constant (RC-8).** Story 007 passes whether the strings come from the record or a leftover literal. The non-default fixture (`"X{rounds_left}"`, `#010203`) in the criterion is what proves they come from data.
- The pin in story 007 is English and byte-exact, and story 017's template-fill check already proved the templates reproduce it. This story wires the rule to the record.
- `rounds_left = permit_rounds - round_number + 1`; `rounds_left == 1` picks `banner_locked_one`, otherwise `banner_locked_other` (Q6).
- **Leave the fallback as shipped.** The record-less fallback (`FactionRule.new()`) keeps its in-code `tr()` sentences and today's `#4a5a8a` identity colour. ADR-0011 §1 changes that default to `Color(0, 0, 0, 0)`; that is a presentation change, not part of this migration. Flag it for the UI/HUD story that substitutes the theme token (ADR-0008). Otherwise story 006/007's control case would change.
- Until ADR-0013's `LocText` exists, read `texts` directly behind a `# TODO(ADR-0013)` line (the recommended unblock).
- **Closing condition:** story 009's gate passes, the Step 0 suite green and its files' hashes unchanged; editing a characterization test or the frozen fixture is never the fix. Re-run in a fresh process.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 026: rule decisions from records.
- Stories 030/031: deleting the colour and text constants.
- The ADR-0011 §1 fallback-colour change: UI/HUD (ADR-0008).

---

## Files

- `src/battle/factions/bureaucratia.gd`, `src/battle/factions/megacorp.gd` (presentation methods read configured texts and colours)
- `tests/unit/battle/fixtures/rule_configure/…` (the `"X{rounds_left}"` / `#010203` fixtures)
- `tests/unit/battle/battle_faction_rule_configure_test.gd` (presentation cases)

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revision applied: the different-texts fixture is in the criterion (RC-8)). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Presentation from records.
  - **Test: strings from data.**
    - Given: the fixture rule (`banner_locked_other = "X{rounds_left}"`) and faction (`signature_color #010203`).
    - Then: `get_banner_text(1) == "X3"`; `get_identity_color()` equals `#010203`; the `_one`/`_other` choice switches at `rounds_left` 1 vs 2.
  - **Test: 009 gate.**
    - Then: 007 green, hashes unchanged.
    - Edge cases: the fallback rule keeps `#4a5a8a` (the ADR-0011 change is deferred).

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_faction_rule_configure_test.gd` (presentation cases) — must exist and pass, and story 009's gate passes. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-migration/story-009-characterization-regression-gate.md`, `story-013-author-faction-records.md`, `story-017-author-faction-rule-records.md`, `story-026-faction-rule-decisions-from-records.md`
- Unlocks: `production/epics/content-migration/story-030-delete-bureaucratia-constants.md`, `story-031-delete-megacorp-constants.md`
