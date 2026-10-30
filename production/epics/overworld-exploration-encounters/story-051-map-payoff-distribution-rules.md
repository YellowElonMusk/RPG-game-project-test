# Story 051: Every map's payoff distribution follows the facet, cap and tell rules

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: `tools/ci/validate_maps.gd` asserts every [D] criterion of the Overworld GDD, including the payoff-distribution rules of rule 7a (facets, `open`/`clue` minimums, `none` caps, tell placement, reference resolution).
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW-MEDIUM
**Engine Notes**: Pure data validation over loaded, baked map scenes; no runtime engine risk beyond the already-probed headless load/bake path `validate_maps.gd` shares with other [D] checks.

**Control Manifest Rules (this layer)**:
- Required: `validate_maps.gd` asserts payoff tells within `R_vis`, clue facet uniqueness, and the `open`/`clue` minimums — ADR-0012 §3
- Forbidden: Never let a map ship with two `clue` payoffs sharing a facet, or a `none` payoff on a Static or critical-path-first symbol
- Guardrail: n/a

---

## Acceptance Criteria

- [x] **AC-21c [D] (R7a)** On each non-Town, non-boss map: at least one symbol carries an `open` payoff that leads to an optional pocket or (on the dungeon) the dungeon shortcut; at least half of the non-story symbols carry `clue` or `open`; no two `clue` payoffs in the region share a facet, and none repeats the first-encounter poster's facet; each payoff's tell (gate, envelope prop or rolled poster) lies within `R_vis` of a vertex of its symbol's patrol; every payoff reference resolves; and no `item` payoff meets a critical-path requirement. At most ⌊N_sym/3⌋ symbols per map carry `none`, never a Static symbol and never the first symbol along the critical path; every optional pocket holds a `change` gag plus a recruit remark or a clue facet.

---

## Implementation Notes

*Derived from ADR-0012 §3 (`validate_maps.gd`) and GDD rule 7a ("Rules for payoffs"):*

This is a [D] data-validation story: one fixture-driven unit test exercising
`validate_maps.gd`'s payoff checks, run at boot and in CI per the evidence-tag
table, not a runtime behaviour test.

- **Per-map minimums**: at least one `open` payoff on every non-Town, non-boss map; at least half of non-story symbols carry `clue` or `open`. Write a passing fixture and a failing fixture for each, asserting CI names the offending record.
- **Facet uniqueness**: no two `clue` payoffs in a region share a facet, and none repeats the first-encounter poster's facet (Paris: "what approves a target" is taken, so Paris `clue`s draw from the other two facets).
- **Tells**: each payoff's tell (gate / envelope / rolled poster) lies within `R_vis` of a vertex of its symbol's patrol (`chase_visibility`'s radius) — fixture a tell placed just outside `R_vis` and assert CI rejects it.
- **References**: every payoff reference (checkpoint ID, item ID, Codex facet ID) resolves; an `item` payoff never meets a critical-path checkpoint requirement.
- **`none` caps**: at most ⌊N_sym/3⌋ `none` payoffs per map, never on a Static symbol, never on the first critical-path symbol.
- **Optional pockets**: each pocket behind an `open` payoff holds a `change` gag plus either a `recruit_remark` or a clue facet — fixture a pocket missing one and assert rejection.

---

## Out of Scope

- `story-050-first-victory-grants-payoff.md`: the runtime granting mechanism.
- Map-exit, bypass-lane and pressure-floor CI checks: separate stories elsewhere in this epic (outside this story's rule-7a scope).

---

## Files

- `tools/ci/validate_maps.gd`
- `src/data/records/encounter_data.gd`
- `data/encounters/`
- `tests/unit/overworld/payoff_rules_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic (Config/Data criterion, BLOCKING per the GDD evidence-tag table)
**Required evidence**:
- `tests/unit/overworld/payoff_rules_test.gd` — must exist and pass (BLOCKING)

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `story-050-first-victory-grants-payoff.md`, `story-017-zone-rate-zero-on-every-mvp-map.md` / `story-019-faction-patrol-archetype-id-resolves.md` (AC-8/AC-8b, the `validate_maps.gd` data-validation pattern this story follows)
- Unlocks: None

## Completion Notes (2026-10-30)

- `PayoffRules.check()` runs in `validate_maps` over each banded map, with facets checked region-wide. Test: `tests/unit/overworld/payoff_rules_test.gd`, one broken fixture per rule.
- Pocket versus shortcut: a gate is a pocket when opening it adds cells the map's entries could not reach. Otherwise it is a shortcut, which counts only on a story-encounter map and only if it shortens a camp's walk to an exit.
- Payoffs are per record (GDD rule 7a), so the dungeon Clerks got their own records: `enc_paris_clerks_first_room`, `_hall`, `_shortcut`, `_pocket`, `_keen`.
- **Segment:**
  - West: clue, "permit takes three rounds", with a rolled-poster tell.
  - East: `open` to the archive courtyard. That is a new 3 × 3 pocket in the south-east corner, walled with a gate at (20, 11) and holding a `change` gag plus a recruit remark. The walls were added by the new `tools/maps/build_segment_pocket.gd`.
- **Dungeon:**
  - First room: clue, "binds both sides".
  - Hall gap: clue, "Clerks wait", the third facet.
  - Hall north: `open` to the back stairs, a shortcut through the hall wall at x 15–16 that shortens the camp's walk to the boss exit.
  - South far-west: `open` to the stamp cupboard, a new pocket in the hall's south-west corner.
  - South-west and north-west: `none` (2 ≤ ⌊6/3⌋). The first-room Clerk, first along the critical path, is not `none`.
  - Rolled-poster tells for both clue Clerks.
- No `item` payoffs ship. The rule is checked against fixtures.
- **Owed narrative sign-off (AC-51):** three gate lines, two pocket gag lines, the rolled-poster text and the new clue stub. The recruit remarks are IDs only, until Squad Roster exists.
- Story 087 recaptured afterwards: 46 approaches, 0 failures.
- Tests updated: the battle content-warning fixture lists the new records, story 092's test gives its East Clerk a clue copy, and the dungeon's W is now 666.
