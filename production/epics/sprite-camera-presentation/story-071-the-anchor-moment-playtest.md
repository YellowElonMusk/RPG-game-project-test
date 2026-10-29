# Story 071: The anchor moment reads clearly to first-time players

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-005` *(best-matching; no TR directly addresses a playtest outcome — TR-presentation-005 covers the boss takeover's dusk flood and sky, which this playtest's third threshold tests the player-facing legibility of. The first two thresholds, about reading "my side" vs. "the enemies" and reacting to the first hit, span the sprite/camera/lighting system as a whole rather than one TR-ID; flagging here as instructed.)*
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: §3's `SkyCard`/faction dusk flood and §4's `PresentationDirector` blend are what the third threshold ("the boss reads") measures for legibility; the first two thresholds measure the whole battle stage's framing and the first hit-reaction animation, both already decided by §1–§6.
**ADR Version**: 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: This story runs against a built, playable vertical slice (title → first battle → first boss fight) rather than probing any new engine API; its risk sits with the GDD's Player Fantasy claim, not with 4.7.2 rendering behaviour.

**Control Manifest Rules (this layer)**:
- Required: One lighting signature per state, already applied before the transition reveals the mode (ADR-0005 §4) — the reveal is what the first threshold measures
- Required: Boss takeover: faction dusk flood on a sky card, driven by the takeover clock (ADR-0005 §3, ADR-0006 §5) — what the third threshold measures

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-66 [PT]** (P-16) (the anchor moment, Player Fantasy) Five first-time players play from the title into their first battle and their first boss fight, with no explanation.
  - **The first frame reads:** within 5 s of the first battle wipe opening, at least 4 of 5 can point to "my side" and "the enemies" and say they're in a fight.
  - **The first reaction lands:** at least 3 of 5 visibly react (a smile, a laugh, a comment) to the first reaction frame of their first hit.
  - **The boss reads:** at least 4 of 5 say, unprompted or when asked "what changed?", that the fight escalated or that the enemy's side took over the place.

  **It gates the first-playable milestone.** A missed threshold blocks that gate until this GDD's Player Fantasy, staging or lighting is revised and a rerun with five new players passes. It is logged as a design problem, not a bug.

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines:*

This is a moderated playtest, not an automated test: five first-time players, no explanation, observed from the title screen through their first battle into their first boss fight, scored against the three thresholds verbatim from the AC.
- Each threshold has its own pass bar (4/5, 3/5, 4/5) and must be scored independently — a strong result on one does not excuse a miss on another.
- A missed threshold is recorded as a design problem against this GDD's Player Fantasy, staging or lighting (not a code bug), and blocks the first-playable milestone until the design is revised and a rerun with five *new* players passes.
- The playtest record captures each player's verbatim reaction/response for all three thresholds, not just the pass/fail tally, so a revision can target the specific staging or lighting cue that failed to read.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Any code or data change the playtest's findings might call for — this story only runs and records the playtest
- `story-069-nothing-compiles-in-play.md` and other performance gates — this is a legibility/Player Fantasy gate, not a performance one

---

## Files

- `production/qa/playtests/anchor-moment-2026-10-29.md`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- A playtest record in `production/qa/playtests/anchor-moment-2026-10-29.md`, scored against all three thresholds — must exist; the first-playable milestone is gated on it passing

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: the boss stages (no epic yet); a playable vertical slice from Title through a first battle and first boss fight
- Unlocks: the first-playable milestone gate
