# Story 001: Every shipped enemy, move and rule is built by its future record ID through one test seam, using today's code

> **Epic**: Content Migration
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: None (Step 0 enabler; it pins today's behaviour and is the evidence that the content TRs changed no outcome)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Migration Step 0; Decision: "Characterization tests do not use the catalog"). Also ADR-0011: Faction Rule Modifiers (Migration Step 1) and ADR-0010: Turn Battle System (§3, the ID set).
**ADR Decision Summary**: Before any factory changes, characterization tests under `tests/unit/battle/` pin today's behaviour, and they must pass unchanged after every later migration step. This story builds the single seam those tests go through, so that later API changes edit one helper file instead of the tests.
**ADR Version**: ADR-0001 2026-10-23 · ADR-0011 2026-10-22 · ADR-0010 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API. The 4.7 typed-return override rule doesn't apply, because the seam overrides nothing except in `scripted_rule()`'s test double, and there every non-void override must `return` on every path.

**Control Manifest Rules (this layer)**:
- Required: "Characterization tests are written against today's hardcoded factories before migration and rerun unchanged after it."
- Required: "Enemy AI keys behaviour off the record `id`, never `display_name`" (the seam is keyed by ID from day one).
- Required (*Core*): "`Combatant.hp` is a read-only property" (written against the future API: tests change state only through the seam or `BattleCore`).
- Forbidden: none specific.
- Guardrail: none (test code).

---

## Acceptance Criteria

*Migration criterion from ADR-0001 Migration Step 0 (this epic has no GDD acceptance criteria of its own), scoped to this story:*

- [ ] GIVEN `BattleContentSeam`, WHEN asked for each ID in `CharacterizationExpected.ENEMY_IDS` (5), `MOVE_IDS` (14: 9 named attacks, 5 specials) and `RULE_IDS` (2), THEN it returns a non-null new instance: enemies and specials from today's factories, named attacks from `Move.new(...)` with the fixture's name and power, and rules from `.new()`. `enemy_turn(rule, enemy, squad, round, rng)` returns an `Array` of `{move_name: String, power: int, target: Combatant}`. `arrange_vitals(c, hp, mp)` leaves `c.hp == hp` and `c.mp == mp`. `scripted_rule(script)` returns a `FactionRule` whose enemy turns follow the script. An unknown ID fails the calling test (verified with gdUnit4 `assert_failure`).

---

## Implementation Notes

*Derived from ADR-0001 Migration Step 0, ADR-0011 Migration Step 1, the draft's Q2 resolution and the QA gate (RC-1, RC-2):*

- **Why one seam (Q2).** Three later changes would break any test that calls today's API directly: ADR-0011 §5/Step 4 deletes the `make_*()` factories and `is_manager()`; ADR-0011 Step 2 changes `choose_enemy_action()` from an `Array` of `{"move","target"}` dictionaries to `Array[EnemyAction]`; ADR-0007 Steps 2–3 delete the heal helpers and `DamageCalculator` and make `Combatant.hp` read-only. Characterization tests therefore build every shipped enemy, move and rule **by its future record ID** only through the seam, read enemy turns only through `seam.enemy_turn()`, and observe effects only through `BattleCore` (`outcome_log`, `action_resolved`, live `hp`/`mp` reads). When a later story changes the API it edits **the seam and nothing else**; stories 023–029 and 034 each name their seam edit. Story 009's gate excludes the seam on purpose.
- **Static API** (`class_name BattleContentSeam`): `enemy(id: String) -> Combatant`, `move(id: String) -> Move`, `rule(id: String) -> FactionRule`, `enemy_turn(rule, enemy, squad, round, rng) -> Array`, `arrange_vitals(c: Combatant, hp: int, mp: int) -> void`, `scripted_rule(script: Array) -> FactionRule`.
- **Named attacks have no factory today**; they are built inside each rule's `_named_attack()`. At Step 0 the seam builds them with `Move.new(name, Move.Category.ATTACK, 0, power, Move.TargetType.SINGLE_ENEMY)` from the pinned name and power. This is the one place Step 0 constructs a move by hand; story 023 replaces it with the catalog adapter, and story 005 asserts the rule's own emitted moves equal `seam.move(id)` so the copy can't drift.
- **`enemy_turn`** reads today's `{"move","target"}` dictionaries and returns `{move_name, power, target}`. Non-damage actions (the pre-permit Defend) are **included with `power 0`** so story 006 sees the hunker. After ADR-0011 Step 2 it reads `EnemyAction.move`/`.target` instead: one function, one edit.
- **`arrange_vitals(c, hp, mp)` (RC-1).** The seam owns state arrangement. At Step 0 it reaches the target with `take_damage`/`heal`/`spend_mp`; after ADR-0007 Step 3 it calls `restore_vitals(hp, mp)` (a one-file seam edit). Characterization tests change state only through this helper or through `BattleCore`, never by writing `hp`. `hp > max_hp` fails the test. **Coordination owed:** ADR-0007 §2's `lint_hp_writes.sh` allowlist needs a line for `tests/unit/battle/helpers/battle_content_seam.gd`. That line needs technical-director approval (an ADR reference in review); record the request in the Completion Notes.
- **`scripted_rule(script)` (RC-2).** A `FactionRule` test double injected through `BattleCore._init(..., p_faction_rule)`. It allows every move in every round (`specials_allowed` and `move_allowed` return true), and its `choose_enemy_action` returns the next scripted `{move_id, target_index}`, built through `seam.move(move_id)` and the living squad, in whatever return shape is current, so the seam owns the shape. An empty script means no enemy actions. It pins the damage and effect pipeline; the shipped rules' decisions stay pinned by 006 and 008.
- An unknown ID calls `push_error` and `fail()`; it never returns null quietly.
- The fixture skeleton `CharacterizationExpected` holds the three ID lists and the seed constants (`SEED_A`, …). Later Step 0 stories add their blocks. Expected values are pinned by running today's code once and copying the output, **never derived from the factories' `const`s** (a test that reads `BureaucratiaRule.CLERK_MAX_HP` would pass vacuously and break when 030 deletes it).
- Later additions to the seam, named so nobody is surprised: `resolved_log(battle)` (story 008), `ensure_catalog()` (story 024, or 023 if it lands first).
- The seam lives under `tests/`, so it is not shipped and is not covered by the content lint (035).
- Epic-wide test rules: gdUnit4, `extends GdUnitTestSuite`, `test_<scenario>_<expected>`, arrange/act/assert, `auto_free()` every Node (an orphan is exit 101); every `RandomNumberGenerator` seeded from a fixture constant; nothing time-dependent. Content is moved as-is and never retuned.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Stories 002–008: the characterization pins themselves.
- Story 008: `seam.resolved_log()`.
- Story 009: the regression gate.
- Story 023/024: the seam's catalog-backed builders and `ensure_catalog()`.

---

## Files

- `tests/unit/battle/helpers/battle_content_seam.gd` (`class_name BattleContentSeam`)
- `tests/unit/battle/fixtures/characterization_expected.gd` (skeleton: ID lists and seeds)
- `tests/unit/battle/battle_content_seam_test.gd`

---

## QA Test Cases

*Written by qa-lead at story creation (QL-STORY-READY, 2026-10-23; verdict GAPS, revisions applied: `arrange_vitals`, `scripted_rule`, unknown-ID failure in the criterion). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: The seam builds every ID, normalises enemy turns, arranges vitals and scripts enemy turns.
  - **Test: seam builds every ID.**
    - Given: the three ID lists in `CharacterizationExpected`.
    - When: each kind is requested.
    - Then: the result is non-null, of the right class, and `display_name` equals the fixture.
    - Edge cases: two calls for the same ID return different objects (`is_not_same`).
  - **Test: enemy_turn normalises.**
    - Given: `seam.rule("rule_bureaucratia_permit")`, a Clerk, the 4-member fixture squad, round 1, `rng.seed = SEED_A`.
    - When: `enemy_turn` runs.
    - Then: the result holds `{"Pen Jab", 5, <target>}`.
    - Edge cases: the Defend is included with `power 0` (pinned), so 006 sees the hunker.
  - **Test: arrange_vitals.**
    - Given: a fresh Karen fixture combatant.
    - When: `arrange_vitals(k, 17, 0)`.
    - Then: `hp == 17` and `mp == 0`.
    - Edge cases: `arrange_vitals(k, 0, 0)` gives `is_knocked_out()`; `hp` above `max_hp` is rejected (the test fails).
  - **Test: scripted_rule follows its script.**
    - Given: `scripted_rule([{move_id = "move_late_fee", target_index = 1}])` injected into a `BattleCore`.
    - When: the enemy phase runs.
    - Then: one action, Late Fee on squad member 1; an empty script yields no enemy action.
    - Edge cases: `specials_allowed(1)` is true under the double.
  - **Test: unknown ID fails.**
    - `assert_failure(func(): BattleContentSeam.enemy("enemy_nope")).is_failed()`.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/battle/battle_content_seam_test.gd` — must exist and pass. Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-001-install-gdunit4.md`
- Unlocks: `production/epics/content-migration/story-002-characterize-squad-specials.md`, `story-003-characterize-bureaucratia-roster.md`, `story-004-characterize-megacorp-roster.md`, `story-005-characterize-moves-damage.md`, `story-006-characterize-faction-rule-decisions.md`, `story-007-characterize-faction-rule-presentation.md`, `story-008-characterize-scripted-fights.md` (all in `production/epics/content-migration/`)
