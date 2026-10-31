# Story 049: the boss takeover starts on reveal, runs on one clock, and holds the battle

> **Epic**: Sprite & Camera Presentation
> **Status**: Done (2026-10-31) -- `tests/integration/battle/boss_takeover_clock_test.gd` 8/8; full suite 1898/1898 exit 0; windowed takeover shots in `production/qa/evidence/story-049-boss-takeover-runs-on-one-clock/`
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/sprite-camera-presentation.md`
**Requirement**: `TR-presentation-005`, `TR-presentation-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Battle Replay Ownership; ADR-0005: Sprite & Camera Presentation
**ADR Decision Summary**: The takeover's `HOLD` entry (`TAKEOVER_FULL` or `TAKEOVER_SETTLE`) is gated behind the reveal exactly like any other queue entry, so no beat starts and no command menu opens before it ends; its own clock (`get_hold_time()`) drives both the stage's takeover blend and the boss's `intro` frame, so presentation never derives either from a separate timer.
**ADR Version**: ADR-0006 2026-10-22; ADR-0005 2026-10-22

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: The controller's own clock mechanism (ADR-0006) is LOW risk, but this story's assertions include that the stage's takeover blend equals `smoothstep(clamp(t_hold / blend_boss, 0, 1))` — a `LightingProfile`/shader-consumed value under ADR-0005's HIGH-risk rendering domain. Highest among the story's ADRs applies.

**Control Manifest Rules (this layer)**:
- Required: "**A blend requested with a `clock` runs from that clock, never a tween** (the takeover blend)" (Stages and lighting, ADR-0005 §3–§5).
- Required: "**Who requests the boss light.** The Battle mode, never the Director: first encounter: on the controller's `hold_started(TAKEOVER_FULL)` it calls `stage.request_profile(&\"boss_<faction>\", blend_boss, clock)`" (Stages and lighting, ADR-0005 §3–§5).
- Forbidden: "No `Timer`, `Tween`, `SceneTree` or `Time` access may be added to the controller" (ADR-0006 Implementation Guidelines) — the takeover's blend and `intro` frame must derive only from `get_hold_time()`, never a parallel timer.

---

## Acceptance Criteria

*From GDD `design/gdd/sprite-camera-presentation.md`, scoped to this story:*

- [ ] **AC-45 [I]** (P-01, P-04) (boss takeover, rule 6) GIVEN a boss fight with a real, seeded `BattleCore`, the controller and a stub Game State: **Starts on reveal:** the takeover blend is at `p = 0` on every frame before the reveal, and has started on the first frame after it. **First encounter, protected:** with "Speed up boss entrances" Off, the takeover lasts `blend_boss + boss_hold` within one frame per event, with Faster battle animations On and with the replay latched. With it On, it lasts `(blend_boss + boss_hold) / battle_speed_mult` with Faster battle animations On and no press, and `/ ff_mult` latched. **One clock:** on every frame, the stage's takeover blend equals `smoothstep(clamp(t_hold / blend_boss, 0, 1))` within 1e-4, and the boss's `intro` frame follows `t_hold − blend_boss`, where `t_hold` is the takeover's clock. **Holds the battle:** no beat starts and no command menu opens before the takeover ends. **Retry settles:** the settle lasts `boss_retry_hold` at 1×, `/ battle_speed_mult` with Faster battle animations On, and `/ ff_mult` latched, each within one frame per event.

---

## Implementation Notes

*Derived from ADR-0006 Decision §2 (the `HOLD` entry), §5 (first-entry call order, step 6/11) and §6 (Speeds table):*

- The takeover `HOLD` entry is enqueued via `controller.enqueue_takeover(boss_combatant, HoldKind.TAKEOVER_FULL)` **after** the reveal gate and **before** `start_battle(false)` on first entry (ADR-0006 §5 step 6) — "starts on reveal" is therefore a direct consequence of queue order: the `HOLD` cannot start until `open_reveal_gate()` releases the gate ahead of it.
- Per the Speeds table (§6): a plain beat and `TAKEOVER_SETTLE` always scale by `plain = max(latched ? ff_mult : 1, battle_speed_on ? battle_speed_mult : 1)`; `TAKEOVER_FULL` is the **one protected entry** — it scales by `plain` only if `speed_up_boss` is On, otherwise always 1 (even latched, even with Faster battle animations On) — this story's "protected" test case is exactly this asymmetry, and must explicitly test the Off case stays at 1× despite both other speed-ups being active.
- **One clock**: `stage.request_profile(&"boss_<faction>", blend_boss, func(): return controller.get_hold_time())` (ADR-0005 §3, called by the Battle mode, never the Director) means the stage evaluates `smoothstep(clamp(t_hold / blend_boss, 0, 1))` from that same `get_hold_time()` call every frame, running no tween of its own — this story's test asserts the stage's blend and the boss's `intro` frame both derive from the *identical* `t_hold` value on any given frame, never two independently-advancing clocks that could drift.
- "Holds the battle" reuses `story-033`'s gating assertion, specialized to the boss case: no `beat_started` and no `turn_started_after_replay` before `hold_finished(TAKEOVER_FULL)`.
- **Retry settles** at `boss_retry_hold`, following the same speed rules as a plain beat (not protected like `TAKEOVER_FULL`) — this is the `TAKEOVER_SETTLE` kind, distinct from the first-encounter `TAKEOVER_FULL`, and `story-030` covers the *lighting* side of this same Retry path; this story covers only the duration/clock side.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `story-030-retry-and-cancel-in-a-boss-fight.md`: the lighting values the takeover blends toward (this story only needs the blend's timing formula, not its visual correctness).
- `story-033-command-menu-and-outcomes-wait-for-the-replay.md`: the general (non-boss) gating order.
- `story-042-replay-indicator-and-latch-input.md`: the indicator's passive/active state during the takeover (cross-referenced, not re-tested).

---

## Files

- `src/battle/battle_replay_controller.gd`
- `src/presentation/diorama_stage.gd`
- `tests/integration/battle/boss_takeover_clock_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/battle/boss_takeover_clock_test.gd` OR playtest doc

**Status**: [x] `tests/integration/battle/boss_takeover_clock_test.gd` created and passing (8/8, 2026-10-31); live observation: `production/qa/evidence/story-049-boss-takeover-runs-on-one-clock/` (t_hold 0.45 mid-blend p 0.508 on intro frame 0; 1.0, 1.4, 1.75 s through the intro)

---

## Dependencies

- Depends on: `BattleReplayController` (ADR-0006, no epic yet); `story-001-windowed-engine-spike.md` (settles `blend_boss`, `boss_hold`, `boss_retry_hold`); boss stages (content, not yet authored)
- Unlocks: None
