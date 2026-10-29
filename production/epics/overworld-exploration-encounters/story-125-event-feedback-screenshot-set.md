# Story 125: Retained screenshots of every overworld event cue

> **Epic**: Overworld Exploration & Encounters
> **Status**: Ready
> **Layer**: Feature
> **Type**: Visual/Feel
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: — (not yet implemented)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters; ADR-0005: Sprite & Camera Presentation; ADR-0002: Game State & Scene Flow
**ADR Decision Summary**: ADR-0012 defines the symbol/contact/checkpoint events these cues represent; ADR-0005 owns the sprites, cues and Reduce Motion stills being captured; ADR-0002 owns the contact→battle wipe transition this set includes.
**ADR Version**: ADR-0012 2026-10-23; ADR-0005 2026-10-22; ADR-0002 2026-10-21

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No new engine surface — captures existing cue rendering (notice slip, "!" tag, orbiting slips, DENIED stamp) through the shipped presentation pipeline.

**Control Manifest Rules (this layer)**:
- Required: none directly (a visual-evidence story, not a coded rule).
- Guardrail: none.

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [ ] **AC-52 [VF] (Visual/Audio, event feedback)** Retained screenshots, with the art-director sign-off, of each event cue: the notice slip, the chase pose and "!" tag, the stun, the contact hold, the checkpoint denial, an exit with and without the beacon, the camp sign, the ticket dispenser, and the safe-zone paving. Chase and stun are also captured under Reduce Motion, showing a still pose that still reads. One capture each of Paris stages 1 (Town), 2 (overworld segment) and 3 (dungeon), and one of the "FERMÉ POUR RESTRUCTURATION" tape.

---

## Implementation Notes

*Derived from GDD Visual/Audio Requirements § Event feedback:*

Each cue has a non-color backup and every sound has a visual twin ([A11Y], Visual/Audio Requirements preamble). This story captures each one in its readable state:

- **Notice slip**: cream paper-slip pop-up with ink "!" plus the notice pose (clipboard snaps up, head turns). Holds for `notice_delay_s`, then shrinks to a small "!" tag.
- **Chase pose + "!" tag**: hurried walk, clipboard forward, small paper trail, "!" tag. Capture both normal and **Reduce Motion** (stills the paper trail; the "!" tag stays).
- **Stun**: seated pose amid scattered papers, 2–3 orbiting form slips for `flee_grace_s`. Capture both normal and **Reduce Motion** (slips hold still; the seated pose and scattered papers still read).
- **Contact hold**: the Clerk's one-beat notice-pose hold before the battle wipe plays.
- **Checkpoint denial**: the "DENIED" stamp (square shape plus text), geometry-based open/closed state (boom down/up, tape across/gone), never color-only.
- **Map exit, with and without the beacon**: the diegetic street opening (lamp post/arch, chevrons) both as an optional exit (unlit) and as the critical-path exit carrying the lantern banner.
- **Camp sign**: the café/bakery door, cup/fire sign (used for every camp in every region).
- **Ticket dispenser**: the story-encounter booth prop (Permit Counter dressing).
- **Safe-zone paving**: the café-terrace cobbles paving change that marks `safe_radius_m` geometrically.
- Stage coverage: one capture each of Paris stage 1 (Town), stage 2 (overworld segment) and stage 3 (dungeon, interior profile).
- One capture of the "FERMÉ POUR RESTRUCTURATION" tape (a specific set-dressing prop named by the AC).
- Retain every screenshot in `production/qa/evidence/` with the art-director sign-off in `production/qa/evidence/signoff-overworld.md` (test plan O-10, which notes chase/stun are also captured with Reduce Motion on).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 126 (`story-126-overworld-sfx-visual-twin-coverage.md`): confirming every SFX event actually has its visual twin on the same frame — this story only captures the visual cues themselves.
- Story 127 (`story-127-exterior-stage-sky-luminance.md`): the measured sky-luminance capture, a different (capture-measured) AC.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- No new source files — captures existing cue rendering across the shipped Paris maps and stages.
- `production/qa/evidence/` (retained screenshots)
- `production/qa/evidence/signoff-overworld.md`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: retained screenshots in `production/qa/evidence/` plus sign-off in `production/qa/evidence/signoff-overworld.md`. BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `story-020-patrol-loop-and-pingpong-traversal.md`..`story-038-contact-starts-encounter-once.md` (symbol sub-state cues, R5), `story-043-victory-respawn-policy.md`..`story-048-timers-freeze-under-overlays.md` (checkpoint denial, R7), `production/epics/sprite-camera-presentation/story-023-follow-camera-matches-the-formula.md` (follow camera)
- Unlocks: None
