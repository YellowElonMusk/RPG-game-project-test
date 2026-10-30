# Story 134: Tag every overworld cue with a capture-ID for the presentation capture tool

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (implemented, awaiting /story-done)
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-30 (implemented, awaiting /story-done)

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**ADR Governing Implementation**: ADR-0005: Sprite & Camera Presentation (§14 overworld profiles, Migration Step 1c amendment); ADR-0012: Overworld Exploration & Encounters
**ADR Decision Summary**: ADR-0012's Ordering Note amends ADR-0005 §7 to add "per-cue capture-ID tags in the §13 capture tool"; this story is that amendment's overworld-side delivery — the GDD's "Tooling owed" item behind AC-44a/b, AC-32, AC-45e and AC-54.
**ADR Version**: ADR-0005 2026-10-22; ADR-0012 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Adds node metadata and a "set hidden" mask-rendering pass to the existing capture tool; no new post-cutoff API beyond what the capture tool (sprite-camera-presentation epic) already uses.

**Control Manifest Rules (this layer)**:
- Required: "lighting profiles keyed by map × faction × stage plus a liberated profile; `sky_card`; the interior travelling light's constraints; tilt-shift blur bounds per the GDD's `chase_visibility`... per-cue capture-ID tags in the §13 capture tool" (control manifest / ADR-0012 Ordering Note, amending ADR-0005 §7).
- Guardrail: none (a tooling story, not a runtime budget).

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story (tooling story per the story map; delivers the GDD's capture-ID Tooling-owed item, test plan OW-T02):*

- [x] Delivers: per-cue `capture_id` node metadata and mask rendering per ADR-0005 §14, covering `SKY`, `notice_slip`, `chase_tag`, `stun_pose`, `checkpoint_open`, `checkpoint_closed`, `safe_paving`, `exit_beacon`, `camp_sign`, `interact_prompt`, `symbol`; and the "set hidden" ID pass used by the walk-in procedure (O-07). Unblocks AC-44a, AC-44b, AC-54, AC-32 and AC-45e (and AC-30i's measure).

---

## Implementation Notes

*Derived from ADR-0012's Ordering Note (amending ADR-0005 §7) and the test plan's Tooling stories table (OW-T02):*

- **Capture-ID tags**: attach `capture_id` node metadata to every node the GDD's cue list names: `SKY`, `notice_slip`, `chase_tag`, `stun_pose`, `checkpoint_open`, `checkpoint_closed`, `safe_paving`, `exit_beacon`, `camp_sign`, `interact_prompt`, `symbol`. Each tag must resolve to a stable mask the capture tool can render.
- **Mask rendering**: each tagged node's mask must be renderable as a grayscale relative-luminance image (WCAG, linear sRGB) per AC-44a/b's contrast measurement, and as a sky-region mask per AC-54's luminance measurement.
- **"Set hidden" ID pass**: for the O-07 walk-in procedure, the tool must support rendering the ID pass twice — normally, and with set geometry hidden — so visible fraction can be computed as (target mask pixels, normal) ÷ (target mask pixels, unoccluded).
- This story extends the sprite-camera-presentation epic's capture tool (story 002 there) with overworld-specific cue tags; it does not re-implement the capture tool itself.
- Bookkeeping note (test plan Findings item 8): the GDD's Tooling-owed list calls this "an ADR-0005 §13 amendment", but the accepted text sits in §14 (amending the §13 tool) — cite §14 in code comments and docs, not §13.
- Until this story ships, AC-44a, AC-44b, AC-54, AC-32 and AC-45e all report **NOT ASSESSED**, never a pass (test plan NOT ASSESSED rule).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 135 (`story-135-level-review-walkin-tool.md`): the tool that lists junction nodes/approaches and *drives* this capture tool for the walk-in procedure — that tool is a separate consumer of the tags this story delivers.
- The capture tool's own rendering pipeline (sprite-camera-presentation epic, story 002 there) — this story only adds overworld cue tags to it.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/overworld/capture_id_tags.gd` (new: tag constants, `tag_map`, `symbol_tag`, `checkpoint_tag`)
- `src/overworld/overworld_mode.gd` (tags the map on load; checkpoint retagged open)
- `src/overworld/overworld_view.gd` (symbol sprite tag by sub-state; interact prompt label tag)
- `tools/capture/presentation_capture.gd` (id_set_hidden pass, visible fractions, per-tag masks, WCAG luminance)
- `tools/capture/capture_main.gd` (`--fixture=cues`)
- `tests/integration/overworld/capture_id_tags_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/overworld/capture_id_tags_test.gd` OR a documented validation that each of the 11 cue tags renders a stable mask and the hidden-geometry ID pass works — must exist and pass.

**Status**: [x] Created and passing: `tests/integration/overworld/capture_id_tags_test.gd` 10/10 (2026-10-30). Windowed capture `capture_main.gd --fixture=cues` → `production/qa/evidence/story-134-capture-id-tags/`: all 11 tag masks non-empty; beacon behind a wall 47.5% visible (id vs id_set_hidden).

---

## Dependencies

- Depends on: `production/epics/sprite-camera-presentation/story-002-capture-tool.md` (the presentation capture tool, P-09, ADR-0005 Migration Step 1c)
- Unlocks: `production/epics/overworld-exploration-encounters/story-109-beacon-chain-walkin-capture.md`, `production/epics/overworld-exploration-encounters/story-127-exterior-stage-sky-luminance.md`, `production/epics/overworld-exploration-encounters/story-135-level-review-walkin-tool.md`, `story-106-event-cue-contrast-against-its-ring.md` (AC-44a), `story-107-interact-prompt-contrast-against-its-ring.md` (AC-44b), `story-087-patrol-visibility-before-the-notice-radius.md` (AC-32)

---

## Completion Notes

**Completed**: 2026-10-30
**Criteria**: 1/1 (tag set, masks and set-hidden pass delivered; headless tests + windowed capture)
**Deviations**:
- Tag `beacon`, not `exit_beacon`: ADR-0005 §14 folds the exit beacon into `beacon` and the capture tool already used it.
- `notice_slip` / `chase_tag` / `stun_pose` currently retag the whole symbol sprite by brain sub-state (no separate slip/tag nodes are drawn yet; TODO(sprite-camera-presentation)).
- `interact_prompt` is a 2D Label: tagged, but its mask comes from the `ui` pass (the ID pass culls canvas items).
- No overworld node draws `safe_paving` or a beacon banner yet, and `SKY` is tagged by the presentation layer; those masks render once their geometry exists (fixture proves the path).
