# Architecture Traceability Index
Last Updated: 2026-10-23 (ADR-0012 Accepted after the architecture review)
Engine: Godot 4.7.2

## Coverage Summary
- Total requirements: 83 (19 new: TR-overworld-001..019; TR-gamestate-001 and -004 reworded)
- Covered (Accepted ADR): 78 (94%)
- Covered (Proposed ADR): 0
- Partial: 5 (TR-content-007, 008, 010; TR-stats-005; TR-overworld-017)
- Gaps: 0

Only **Accepted** ADRs count as covered. All 13 ADRs (ADR-0001 to ADR-0013) are Accepted. ADR-0012 was Accepted 2026-10-23, and ADR-0002 §11 (in-mode fade, `register_camp`) is in effect with it.

## Full Matrix

| Requirement ID | GDD | System | Requirement | ADR Coverage | Status |
|---|---|---|---|---|---|
| TR-content-001 | content-data-definitions.md | Content Data | 8 record types (incl. `bindings_`), permanent prefixed IDs, aliases | ADR-0001; ADR-0003 adds `bindings_` (ADR-0012, Proposed, would add `map_`/`enc_`) | ✅ |
| TR-content-002 | content-data-definitions.md | Content Data | Unloaded → Loading → Validating → Ready \| Failed, terminal | ADR-0001 | ✅ |
| TR-content-003 | content-data-definitions.md | Content Data | Full-set validation, two severities, headless check | ADR-0001 + ADR-0004 | ✅ |
| TR-content-004 | content-data-definitions.md | Content Data | `get_record` / `has_record` / `all_records` / `resolve_alias` | ADR-0001 | ✅ |
| TR-content-005 | content-data-definitions.md | Content Data | ID-only references; asset IDs, never paths | ADR-0001 | ✅ |
| TR-content-006 | content-data-definitions.md | Content Data | Data-only records; vocabulary registered before validation | ADR-0001 + ADR-0004 | ✅ |
| TR-content-007 | content-data-definitions.md | Content Data | Immutable after Ready; caller mutation never leaks | ADR-0001 | ⚠️ Partial: shared cached Resources, protected by discipline only |
| TR-content-008 | content-data-definitions.md | Content Data | Structured entries, deterministic order, error screen, log | ADR-0001 | ⚠️ Partial: entry shape, sort key, `ERROR_SCREEN_CAP` and log not in any ADR |
| TR-content-009 | content-data-definitions.md | Content Data | Boot waits for Ready; Failed never reaches gameplay | ADR-0001 + ADR-0002 + ADR-0004 | ✅ |
| TR-content-010 | content-data-definitions.md | Content Data | 500 records, median < 1.0 s | ADR-0001 (ADR-0004 cites `LOAD_TIME_BUDGET` as a mitigation only) | ⚠️ Partial: no benchmark in any ADR's Validation Criteria |
| TR-content-011 | content-data-definitions.md | Content Data | Ranges read from the owner's constants | ADR-0001; ADR-0007 §7 for Stats | ✅ |
| TR-content-012 | content-data-definitions.md | Content Data | Player-visible strings extractable for localization | ADR-0013 §1–§4; ADR-0008 §11 | ✅ |
| TR-gamestate-001 | game-state-scene-flow.md | Game State | Mode + overlay stack, 6 ordered signals | ADR-0002 | ✅ |
| TR-gamestate-002 | game-state-scene-flow.md | Game State | One transition at a time, input lock, rollback | ADR-0002 | ✅ |
| TR-gamestate-003 | game-state-scene-flow.md | Game State | Overworld freeze/restore; Encounter descriptor | ADR-0002 (ADR-0012 adds the Overworld side, Proposed) | ✅ |
| TR-gamestate-004 | game-state-scene-flow.md | Game State | Retry vs Retreat | ADR-0002 | ✅ |
| TR-gamestate-005 | game-state-scene-flow.md | Game State | Boot waits on catalog; Content Error mode | ADR-0002 + ADR-0004 | ✅ |
| TR-gamestate-006 | game-state-scene-flow.md | Game State | Data-driven timings, injectable clock/loader, Menu stops mode time | ADR-0002 | ✅ |
| TR-gamestate-007 | game-state-scene-flow.md | Game State | Transition flashes go through the flash gate; capped variant, timing unchanged | ADR-0002 §7 + ADR-0005 §12 (UI side: ADR-0008 §8) | ✅ |
| TR-input-001 | input-system.md | Input | 8 actions; bindings record; overrides persist via Save/Load | ADR-0003; persistence ADR-0009 §7 | ✅ |
| TR-input-002 | input-system.md | Input | Radial deadzone, menu repeat, injectable clock | ADR-0003 | ✅ |
| TR-input-003 | input-system.md | Input | `DEVICE_ID_*` (4.7), never device 0 | ADR-0003 | ✅ |
| TR-input-004 | input-system.md | Input | Device lost/restored, focus broadcasts | ADR-0003 | ✅ |
| TR-input-005 | input-system.md | Input | `active_device_changed(kind, pad_style)` | ADR-0003 (consumer: ADR-0008 §4) | ✅ |
| TR-input-006 | input-system.md | Input | No Game State dependency; pointer to UI; 4.6 dual focus sync | ADR-0003; dual focus ADR-0008 §5–§6 | ✅ |
| TR-input-007 | input-system.md | Input | One `pressed` per physical press; no key-repeat echoes | ADR-0003 | ✅ |
| TR-input-008 | input-system.md | Input | Derived `nav_*` actions | ADR-0003 | ✅ |
| TR-input-009 | input-system.md | Input | Hover moves focus only after `pointer_switch_px` | ADR-0003 (knob); ADR-0008 §6 (behaviour) | ✅ |
| TR-stats-001 | stats-damage-resolution.md | Stats & Damage | F2–F8 pipeline, injected constants, < 50 µs | ADR-0007 §1, §4 | ✅ |
| TR-stats-002 | stats-damage-resolution.md | Stats & Damage | RNG injected, never global | ADR-0007 §1 | ✅ |
| TR-stats-003 | stats-damage-resolution.md | Stats & Damage | Modifier/override registration by priority | ADR-0007 §3 | ✅ |
| TR-stats-004 | stats-damage-resolution.md | Stats & Damage | Apply-only HP writes; one outcome record per resolution | ADR-0007 §2, §5 | ✅ |
| TR-stats-005 | stats-damage-resolution.md | Stats & Damage | Ranges validated by catalog; no max_hp/max_mp modifiers | ADR-0007 §7 | ⚠️ Partial: `Enemy.reward` ranges wait for the enemy-record migration (ADR-0007's own note) |
| TR-turnbattle-001 | turn-battle-system.md | Turn Battle | RefCounted state machine, signal-only presentation | ADR-0010 §1; ADR-0006 | ✅ |
| TR-turnbattle-002 | turn-battle-system.md | Turn Battle | Ordered gates; rejected submit returns null | ADR-0010 §2 | ✅ |
| TR-turnbattle-003 | turn-battle-system.md | Turn Battle | Encounter in; Victory / Fled / Defeat + results-done out | ADR-0010 §3, §5; ADR-0002 §7 | ✅ (Flee also needs a GDD section; see Known Gaps) |
| TR-turnbattle-004 | turn-battle-system.md | Turn Battle | Factories replaced by records via the adapter | ADR-0010 §3, §8; ADR-0001 Migration Step 3 | ✅ |
| TR-turnbattle-005 | turn-battle-system.md | Turn Battle | Outcomes reach presentation only via `BattleReplayController` | ADR-0006 | ✅ |
| TR-factionrules-001 | faction-rule-modifiers.md | Faction Rules | Stateless 10-method FactionRule contract (reworded 2026-10-22) | ADR-0011 §1–§2 | ✅ |
| TR-factionrules-002 | faction-rule-modifiers.md | Faction Rules | `rule_id` → class registry owned by Faction Rules | ADR-0011 §4 | ✅ |
| TR-presentation-001 | sprite-camera-presentation.md | Presentation | One texel scale `T`, screen-facing pixel-snapped quads, no rotate/scale | ADR-0005 §1–§2 | ✅ |
| TR-presentation-002 | sprite-camera-presentation.md | Presentation | Upright-card occlusion; level shift-lens battle camera | ADR-0005 §2, §6 | ✅ |
| TR-presentation-003 | sprite-camera-presentation.md | Presentation | Actor-only lights, rim ring, local read_order contrast | ADR-0005 §2–§3 | ✅ |
| TR-presentation-004 | sprite-camera-presentation.md | Presentation | One signature per state, hidden switch; blends never pop | ADR-0005 §3–§4 | ✅ |
| TR-presentation-005 | sprite-camera-presentation.md | Presentation | Boss dusk flood on the sky card, on the takeover clock | ADR-0005 §3, §5; ADR-0006 §2, §5 | ✅ |
| TR-presentation-006 | sprite-camera-presentation.md | Presentation | Fixed cameras; follow camera; aspect rules | ADR-0005 §6 | ✅ |
| TR-presentation-007 | sprite-camera-presentation.md | Presentation | Whole-pixel hit-punch, HUD still, comfort settings | ADR-0005 §6 | ✅ |
| TR-presentation-008 | sprite-camera-presentation.md | Presentation | Menu freezes the world; everything on mode time; no `TIME` | ADR-0005 §4, §7; ADR-0002 | ✅ |
| TR-presentation-009 | sprite-camera-presentation.md | Presentation | Beat-by-beat replay; `beat_min`; no skipped beat; end holds | ADR-0006 §2–§5 | ✅ |
| TR-presentation-010 | sprite-camera-presentation.md | Presentation | One beat clock for frames, punch and sound | ADR-0006 §4; ADR-0005 §1 | ✅ |
| TR-presentation-011 | sprite-camera-presentation.md | Presentation | One-level latch, speed settings, refusal, indicator, no buffering | ADR-0006 §6 | ✅ |
| TR-presentation-012 | sprite-camera-presentation.md | Presentation | Menu input guard, safe default focus, refusal feedback | ADR-0008 §5–§7 | ✅ |
| TR-presentation-013 | sprite-camera-presentation.md | Presentation | HUD reads the replay's displayed state; cancel and resync | ADR-0006 §2, §8 | ✅ |
| TR-presentation-014 | sprite-camera-presentation.md | Presentation | Boot validation of sprite sets, animations, presets, knobs | ADR-0005 §9 via ADR-0004 | ✅ |
| TR-presentation-015 | sprite-camera-presentation.md | Presentation | One global flash gate, four classes, landing-time booking | ADR-0005 §12 | ✅ |
| TR-presentation-016 | sprite-camera-presentation.md | Presentation | No pipeline compiles in play (measured) | ADR-0005 §11 (UI materials: ADR-0008 §8) | ✅ |
| TR-presentation-017 | sprite-camera-presentation.md | Presentation | Native scale, SDR, no SSAA, Vulkan pinned, native Linux Deck | ADR-0005 §7, §10 | ✅ |
| TR-presentation-018 | sprite-camera-presentation.md | Presentation | ≤ 300 3D + 100 canvas draw calls; p99 ≤ 16.6 ms, worst ≤ 33 ms | ADR-0005 Performance | ✅ |
| TR-presentation-019 | sprite-camera-presentation.md | Presentation | Blob shadows only; only the set light casts | ADR-0005 §2–§3 | ✅ |
| TR-presentation-020 | sprite-camera-presentation.md | Presentation | Two facings, per-animation `no_mirror`, safe fallbacks | ADR-0005 §1, §9 | ✅ |
| TR-presentation-021 | sprite-camera-presentation.md | Presentation | Knobs and presets in data; chained-range validation | ADR-0005 §5, §9; ADR-0006 §9 | ✅ |
| TR-presentation-022 | sprite-camera-presentation.md | Presentation | Six comfort settings from the settings service | ADR-0005 (consumers); ADR-0009 §7–§8 (service); ADR-0008 §7–§8 (UI) | ✅ |
| TR-presentation-023 | sprite-camera-presentation.md | Presentation | Deterministic capture tool for [C] ACs | ADR-0005 §13 | ✅ |
| TR-presentation-024 | sprite-camera-presentation.md | Presentation | Faction colour only in boss takeover | ADR-0005 §2, §3, §5 | ✅ |
| TR-overworld-001 | overworld-exploration-encounters.md | Overworld | Continuous ground-plane movement, no physics, one clock `ow_dt` | ADR-0012 §2 | ✅ |
| TR-overworld-002 | overworld-exploration-encounters.md | Overworld | Walk grid bake, SAFE tags, batched `set_blocked`, 4-connected components | ADR-0012 §2 | ✅ |
| TR-overworld-003 | overworld-exploration-encounters.md | Overworld | Visible symbols only; `zone_rate` 0; faction patrol archetype | ADR-0012 §3, §5 | ✅ |
| TR-overworld-004 | overworld-exploration-encounters.md | Overworld | Symbol sub-state machine, notice, `path_dist` give-up, Static `start_on` | ADR-0012 §5 `SymbolBrain` | ✅ |
| TR-overworld-005 | overworld-exploration-encounters.md | Overworld | Deterministic pinned A*, bounded notice search, round-robin budget, 2 ms p99 | ADR-0012 §2, §5, Performance | ✅ |
| TR-overworld-006 | overworld-exploration-encounters.md | Overworld | Swept contact, fixed per-frame order | ADR-0012 §5 | ✅ |
| TR-overworld-007 | overworld-exploration-encounters.md | Overworld | `enc_` pipeline; two-step thaw | ADR-0012 §5; ADR-0002 §4 | ✅ |
| TR-overworld-008 | overworld-exploration-encounters.md | Overworld | First-Victory payoffs, payoff card | ADR-0012 §3, §5 | ✅ |
| TR-overworld-009 | overworld-exploration-encounters.md | Overworld | Occupation stages, scheduled raises, faction × stage records, marker activation | ADR-0012 §3, §4 | ✅ |
| TR-overworld-010 | overworld-exploration-encounters.md | Overworld | Local and region liberation | ADR-0012 §4, §5, §7 | ✅ |
| TR-overworld-011 | overworld-exploration-encounters.md | Overworld | Checkpoints, fight-free sources, same-instance redirect | ADR-0012 §3, §6; ADR-0002 §11 (in effect) | ✅ |
| TR-overworld-012 | overworld-exploration-encounters.md | Overworld | `map_` records, legs and steps, fresh-instance map change, exits | ADR-0012 §3, §4 | ✅ |
| TR-overworld-013 | overworld-exploration-encounters.md | Overworld | Camp registration through Game State; chapter-end prompt | ADR-0012 §4; ADR-0002 §11 (in effect) | ✅ |
| TR-overworld-014 | overworld-exploration-encounters.md | Overworld | `WorldState` single owner; save moments; Continue | ADR-0012 §4; ADR-0009 §3 | ✅ |
| TR-overworld-015 | overworld-exploration-encounters.md | Overworld | `probe()`, prompt, lockouts, pointer ignored | ADR-0012 §6; ADR-0003 | ✅ |
| TR-overworld-016 | overworld-exploration-encounters.md | Overworld | Invariants I1–I18; `validate_maps.gd` | ADR-0012 §3, §9 | ✅ |
| TR-overworld-017 | overworld-exploration-encounters.md | Overworld | Profile per map × faction × stage, `chase_visibility`, followers, sprite clock | ADR-0012 §2, §7; ADR-0005 annotations owed | ⚠️ |
| TR-overworld-018 | overworld-exploration-encounters.md | Overworld | Overworld text as `LocText`; timed text holds | ADR-0013 §1–§3; ADR-0008 | ✅ |
| TR-overworld-019 | overworld-exploration-encounters.md | Overworld | Interim flag registry; no `Engine.time_scale` | ADR-0012 §4, Guidelines | ✅ |

## Known Gaps

No requirement is without an ADR. Remaining work:

| Item | Action | Layer | Engine Risk |
|---|---|---|---|
| TR-content-007/008/010 (partial) | ADR-0001 amendment or catalog story notes: immutability guard, report entry format and `ERROR_SCREEN_CAP`, the 500-record load benchmark | Foundation | LOW |
| TR-stats-005 (partial) | `Enemy.reward` range validator lands with the enemy-record migration (ADR-0001 Step 3 / ADR-0010 §3) | Core | LOW |
| Flee | `turn-battle-system.md` has no Flee section; ADR-0010 §5 blocks Flee-shipping stories on one plus a new TR | Feature | LOW |
| TR-overworld-017 (partial) | ADR-0005 annotation text owed: profiles per faction × stage, liberated profile, `sky_card`, interior light, blur bounds, capture-ID tags (incl. `SKY`) | Core | MEDIUM |

## Superseded Requirements

None. Rewordings (same intent):
- TR-content-001 (2026-10-22): the InputBindings record type made it 8 record types.
- TR-factionrules-001 (2026-10-22): ADR-0007 added `register_resolution_hooks`, so the contract has 10 methods.
- TR-gamestate-001 (2026-10-23): ADR-0002 §11 adds the Overworld-only in-mode fade, a fourth entry point with a two-signal exception.
- TR-gamestate-004 (2026-10-23): Retreat goes to the last camp **registered** (entered, or passed in the Overworld).
