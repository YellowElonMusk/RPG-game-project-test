# Story 135: Build the level-review tool that lists approaches and junction nodes and drives walk-in captures

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: — (not yet implemented)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-016`, `TR-overworld-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time. TR-016 covers the junction-data validation this tool consumes; TR-017 covers the presentation capture it drives.)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: ADR-0012's load-time validation already computes and checks junction coverage (TR-016); this tool is the GDD's "Tooling owed" item that turns that data into placed walk-in captures, driving the ADR-0005 capture tool.
**ADR Version**: ADR-0012 2026-10-23; ADR-0005 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Reads the baked `WalkGrid` and `AStarGrid2D` (already probed) to place the leader and frozen symbols; no new engine surface beyond driving the existing capture tool.

**Control Manifest Rules (this layer)**:
- Required: "`tools/ci/validate_maps.gd` runs after `validate-content.gd`... and asserts every [D] criterion of the Overworld GDD" (ADR-0012 §3) — this tool consumes the same junction/approach data `validate_maps.gd` validates, read, not re-derived independently.
- Required: "A* origins... Every search starts from the symbol-legal cell nearest the symbol's centre" (ADR-0012 §5, GDD rule 5) — placements for AC-32's symbol approaches must respect this when freezing a symbol at its patrol point.

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story (tooling story per the story map; delivers the GDD's level-review Tooling-owed item, test plan OW-T03):*

- [ ] Delivers: a tool that lists each symbol's approaches (per stage, deduplicated by 45° sector), each leg's junction nodes, and the AC-30i edge point; places the leader and a frozen symbol per the O-07 procedure; drives the capture tool; and writes the O-07 measurement rows. Unblocks AC-30i, AC-32 and AC-45e.

---

## Implementation Notes

*Derived from the test plan's O-07 procedure and Tooling stories table (OW-T03):*

- **List** (per shipped map, per reachable stage):
  - **AC-32** (outside this writer's range): for each active symbol, its approaches — walk-grid entries into its `see_m` disc, deduplicated by 45° sector.
  - **AC-45e** (story 109): for each leg, its junction nodes, as defined by AC-45f / story 110's validator.
  - **AC-30i** (outside this writer's range): the one point where the walk-grid path from the pre-dungeon CampSpot to the Permit Counter crosses the safe-zone edge.
- **Place**: AC-32 freezes the symbol at its patrol point nearest the approach, the leader at `see_m + 0.1 m` from it on the approach line, facing it. AC-45e places the leader at the junction node, facing along the leg. AC-30i places the leader at the edge point, facing the Counter. In every case, followers snap behind and the camera settles (the follow camera run to rest) before any capture.
- **Measure**: render the ID pass twice — normally, and with set geometry hidden (via story 134's "set hidden" pass) — and compute visible fraction = target mask pixels (normal) ÷ target mask pixels (unoccluded). A target whose unoccluded mask is empty (off screen) has visible fraction 0.
- **Pass threshold**: visible fraction ≥ 0.5 for AC-32 and AC-45e (as the GDD states); the same ≥ 0.5 threshold is this test plan's chosen tolerance for AC-30i, since the GDD only says "on screen" there.
- **Retain**: every placement's screenshot, both ID passes and the measurement row, under `production/qa/evidence/captures/walkin-[map]-[stage]/`, listed on the art-director sheet (O-10).
- This tool reads junction data from `validate_maps.gd` (story 110's AC-45f check) rather than re-deriving it, so the two never disagree about what counts as a junction.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 110 (`story-110-beacon-junction-coverage-validation.md`): defining and validating junction coverage — this tool only *consumes* that data.
- Story 134 (`story-134-capture-id-tags-for-overworld-cues.md`): the capture-ID tags and the hidden-geometry ID pass mechanism this tool drives.
- Story 109 (`story-109-beacon-chain-walkin-capture.md`): running this tool against shipped maps and retaining the AC-45e evidence with sign-off.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `tools/leveldesign/level_review_tool.gd` (approach/junction/edge-point listing, placement, capture driving, O-07 row writer)
- `tests/integration/overworld/level_review_tool_test.gd`
- `production/qa/evidence/captures/walkin-[map]-[stage]/` (output location)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/overworld/level_review_tool_test.gd` OR a documented validation that the tool's listings, placements and measurements match the O-07 procedure — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/overworld-exploration-encounters/story-134-capture-id-tags-for-overworld-cues.md`, `production/epics/overworld-exploration-encounters/story-110-beacon-junction-coverage-validation.md`
- Unlocks: `production/epics/overworld-exploration-encounters/story-109-beacon-chain-walkin-capture.md`, `story-076-permit-counter-telegraph-screenshot.md` (AC-30i), `story-087-patrol-visibility-before-the-notice-radius.md` (AC-32)
