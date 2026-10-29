# Story 030: a Retry or a cancelled first-encounter takeover lands on the right light, never a pop

> **Epic**: Sprite & Camera Presentation
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-005`, `TR-presentation-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Battle Replay Ownership; ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: On Retry, the Battle mode (never the Director) requests the boss light through `stage.request_profile()`, learning from `GameStateMachine.is_transition_flash_capped()` whether to apply it hidden behind an uncapped flash (blend 0) or blended over `blend_defeat` when the flash plays capped; a first-encounter takeover cancelled mid-blend by an exit snaps every lighting parameter to the next mode's entry preset on the first revealed frame.
**ADR Version**: ADR-0006 2026-10-22; ADR-0005 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Carries ADR-0005's HIGH rendering risk because the light values under test are `LightingProfile` fields consumed by the (not-yet-built) shader pipeline. The replay/latch call order itself (ADR-0006) is LOW risk and needs no further engine verification; this story is a headless integration test of the two ADRs' call order, not a windowed render check.

**Control Manifest Rules (this layer)**:
- Required: "Every battle stage enters on profile `battle`... The boss light is requested explicitly by the owning mode, never the Director, via `stage.request_profile()`" (Stages and lighting, ADR-0005 §3–§5).
- Required: "`PresentationDirector` applies the entry profile at `blend_time = 0` on `mode_entered`... it skips the apply on a same-mode row (Retry) because the owning mode already set the light during SWAP" (Stages and lighting, ADR-0005 §3–§5).
- Forbidden: "Never let a mode scene light itself with no Director — there must be one always-processing owner of the global uniforms" (ADR-0005) — the Battle mode's direct `request_profile()` call on Retry is the one sanctioned exception to that rule, documented here so it is not mistaken for a violation.

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-26 [L]** (P-04) (Retry and cancel in a boss fight) GIVEN Retry in a boss fight with a full (uncapped) retry flash, with Faster battle animations and Speed up boss entrances both Off (AC-45 covers the other speeds), THEN: every lighting parameter equals the takeover's end-state preset within 1e-4 on every frame from the first frame the retry flash stops fully covering the screen; the boss shows the last frame of its `intro` for `boss_retry_hold` before the first command menu opens. GIVEN a capped retry flash, THEN the light moves from Defeat to the takeover end state as one blend over `blend_defeat` from the flash's start, with no frame-to-frame change larger than the blend's largest step. GIVEN a first-encounter takeover cancelled mid-blend by an exit, THEN every lighting parameter equals the next mode's entry preset on the first frame that mode is revealed.

---

## Implementation Notes

*Derived from ADR-0006 Decision §5 (Call order — Retry) and ADR-0005 Decision §3 (Profile requests):*

- **Retry's SWAP order** (ADR-0006 §5): `cancel_pending_replay()` (again, unconditionally) → restore HP/MP → **the Battle mode requests the light** → `enqueue_reveal_gate()` → `enqueue_takeover(TAKEOVER_SETTLE)` if a boss fight → `start_battle(false)` → `resync()`. The light request must come after HP/MP restore and before the gate, matching this exact order — a test asserting call order via a spy belongs here.
- **Which light, and how.** The Battle mode asks `GameStateMachine.is_transition_flash_capped()` (ADR-0002 amendment), which reports the `FlashGate` result for this transition's retry flash: uncapped → `request_profile(&"boss_<faction>", 0.0)`, hidden behind the flash; capped → `request_profile(&"boss_<faction>", blend_defeat)`, a visible blend from Defeat because a capped flash hides nothing.
- **`TAKEOVER_SETTLE` duration** is `boss_retry_hold` (ADR-0006 §6) — the takeover light is already in place behind the retry flash, and the boss holds the last frame of its `intro` for that duration before the gate opens and the first command menu can appear.
- **Same-mode skip.** `PresentationDirector.mode_entered(BATTLE)` on the Battle → Battle row does **not** re-apply the entry profile (ADR-0005 §4), because the Battle mode already set the Retry light during SWAP; this story's test must assert the Director's apply is skipped on this row, not merely that the light ends up correct by coincidence.
- **Cancelled first encounter.** An exit mid-blend (Retreat, Quit) does not need to finish the takeover blend — the next mode's `mode_entered` applies that mode's entry profile at `blend_time = 0`, hidden behind the wipe (ADR-0005 §4), so the lighting parameter snap is the Director's ordinary entry-profile apply, not a special case in this controller.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-027-replay-time-holds-every-case.md`: the general latch/speed formula (this story only needs `boss_retry_hold` at 1×, per AC-26's stated case; AC-45 covers the other speeds).
- `story-040-retry-and-exit-mid-replay-clear-the-display.md`: the HUD/sprite display reset on Retry (a separate signal, `display_resynced`).
- `story-038-boss-takeover-faction-parity.md`: the capture-measured swatch values this light blends toward.

---

## Files

- `src/battle/battle_replay_controller.gd`
- `src/presentation/diorama_stage.gd`
- `src/presentation/presentation_director.gd`
- `tests/integration/presentation/retry_boss_light_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/integration/presentation/retry_boss_light_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `BattleReplayController` (ADR-0006, no epic yet); `story-001-windowed-engine-spike.md` (the spike settles the boss profile fields and `blend_defeat`); boss stages (content, not yet authored)
- Unlocks: None
