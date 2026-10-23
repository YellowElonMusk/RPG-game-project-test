# Story 030: In an exported Windows build, `ResourceLoader.list_directory()` finds every record

> **Epic**: Content Catalog
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: Not started (set by /dev-story)

## Context

**GDD**: `design/gdd/content-data-definitions.md`
**Requirement**: `TR-content-001`, `TR-content-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Content Data Definitions Storage & Loading Format (Decision "File discovery"; Engine Compatibility "Verification Required"; Validation Criteria)
**ADR Decision Summary**: Discovery uses `ResourceLoader.list_directory()` because it belongs to Godot's resource virtual filesystem and should work the same in the editor and in an exported build. There, `.tres` files may be converted to binary with `.remap` companions that a raw `DirAccess` listing would expose. ADR-0001 requires this behaviour to be re-confirmed against an **exported** build before the first real content migration ships.
**ADR Version**: ADR-0001 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `list_directory()` is a 4.4 API, after the LLM cutoff, verified so far only from the raw project directory. Unknowns to observe: whether listed names in an export are the original `<id>.tres` names or `.remap`/`.res` names (story 002's filename = `id` check depends on it); whether the "convert text resources to binary on export" option changes the result; whether the raw-text unknown-field scan (story 015, `FileAccess` on the `.tres`) can still read source text in an export where the file was converted. Record every observation.

**Control Manifest Rules (this layer)**:
- Required: "Discover files with `ResourceLoader.list_directory(path)`, recursed per subdirectory under `data/`."
- Forbidden: "Never enumerate content files with `DirAccess`."
- Guardrail: none specific.

---

## Acceptance Criteria

*From ADR-0001 Engine Compatibility "Verification Required" (no GDD AC; added at story creation 2026-10-23 because no other story owned it):*

- [ ] In an exported Windows build of the project, the catalog loaded from the exported `data/` reaches the same terminal state, with the same `id` list per type, as the same data loaded in the editor, and no listed name is a `.remap` or `.res` artefact. The observation is recorded in a manual evidence log.

---

## Implementation Notes

*Derived from ADR-0001 Engine Compatibility and Validation Criteria:*

- **Prerequisites the user may need to provide.**
  - An **export preset**: there is no `export_presets.cfg`, and `project.yaml` `commands.build` is `[TO BE CONFIGURED]` ("no export presets yet — create one in the editor, then set via /settings"). Create a Windows Desktop preset in the editor. This is an editor UI step and may need the user. Then set `commands.build` with `/settings`.
  - **Export templates** for 4.7.2.stable, installed through the editor's template manager.
  - The preset's resource filter must include `data/*` (and `tools/ci/*` if the probe below uses the validate script).
- **Probe.** Prefer running story 027's `res://tools/ci/validate-content.gd` inside the exported executable (`<game>.exe --headless -s res://tools/ci/validate-content.gd`) if the export template accepts `-s`; confirm that on 4.7.2 and record it. If it does not, add a small debug-only probe: a command-line user argument (`-- --content-discovery-report`) handled by a throwaway main scene in a dedicated "discovery probe" preset, which prints `state`, the per-type `id` lists and the raw `list_directory()` output for each type directory, then quits. Do not ship the probe in the game's release preset.
- **Data set.** Use a copy of `tests/unit/content_data/fixtures/valid_one_of_each/` placed at `res://data/` in a throwaway branch, or the real `res://data/` once migration has content. The editor-side baseline is the same probe run with `godot --headless` from the project directory.
- **Escalation.** If the exported listing differs (for example `.remap` names appear, or the raw-text scan cannot read converted files), stop and escalate to technical-director: ADR-0001's discovery decision or story 015's mechanism needs amending before content migration ships.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Release packaging, signing and store builds: the release epic (`/release-checklist`).
- Linux / Steam Deck export: a later verification once that preset exists.

---

## Files

- `export_presets.cfg` (Windows Desktop preset; created in the editor)
- `project.yaml` (`commands.build`, via `/settings`)
- `tools/ci/content-discovery-probe.gd` (only if `-s` is unavailable in exports)
- `production/qa/evidence/content-catalog-030-exported-discovery-[date].md`

---

## QA Test Cases

*Written at story creation (2026-10-23) from the QL-STORY-READY coverage finding ("ADR-0001's Verification requires `list_directory()` to be re-verified in an exported Windows build. No story owns that"). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: Exported discovery matches the editor.
  - Setup: a Windows Desktop export preset that includes `data/*`; 4.7.2 export templates; the probe chosen above; the same data set for both runs.
  - Verify:
    1. Run the probe from the project directory (`godot --headless`) and save its output as the baseline.
    2. Export a Windows build and run the probe in the exported executable, headless.
    3. Repeat step 2 with "convert text resources to binary" toggled the other way, if the preset exposes it.
  - Pass condition: in every exported run, `state` equals the baseline's (`READY` for a valid set); each type's `id` list equals the baseline's; the raw `list_directory()` output contains no `.remap` or `.res` names (or, if it does, the catalog still maps them to the same IDs and the log says so); and the evidence log records the engine version, the preset settings, the exact commands, both outputs and the date. Any difference is a fail and an escalation, not a pass with notes.

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration: a documented manual evidence log at `production/qa/evidence/content-catalog-030-exported-discovery-[date].md` (the "playtest doc" form of Integration evidence; an exported build cannot run under gdUnit4). Gate level: BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content-catalog/story-002-load-one-of-each-type.md`; a Windows export preset and 4.7.2 export templates (not yet present; `commands.build` is unset). Optionally `production/epics/content-catalog/story-027-headless-validate-content.md`, if the probe reuses its script.
- Unlocks: None in this epic. ADR-0001 requires it before the first real content migration ships (`production/epics/content-migration/`).
