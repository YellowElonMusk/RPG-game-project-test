# Story 079: Shipped scenes contain no physics nodes and no live collision on GridMap or TileMapLayer

> **Epic**: Overworld Exploration & Encounters
> **Status**: Complete (2026-10-30)
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-10-23
> **Last Updated**: 2026-10-29

## Context

**GDD**: `design/gdd/overworld-exploration-encounters.md`
**Requirement**: `TR-overworld-016`, `TR-overworld-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Overworld Exploration & Encounters — Ground-Plane Movement on a Baked Walk Grid, Data-Defined Encounters, No Physics Engine
**ADR Decision Summary**: `validate_maps.gd` fails any shipped map containing a physics node by class, any `CSGShape3D` at all, a `GridMap` with non-zero collision or item shapes, or a `TileMapLayer` with collision enabled — the Overworld uses no physics engine, full stop.
**ADR Version**: 2026-10-23

**Engine**: Godot 4.7.2 | **Risk**: LOW–MEDIUM
**Engine Notes**: Probed on 4.7.2: `GridMap.collision_layer` defaults to **1** and `CSGShape3D.use_collision` defaults to **false**; `SoftBody3D`, `RayCast3D` and `ShapeCast3D` are **not** `CollisionObject3D`s, so the ban lists them by class rather than by base type; `CSGShape3D.bake_static_mesh()` returns null before tree entry and a valid mesh only one frame later.

**Control Manifest Rules (this layer)**:
- Required: `tools/ci/validate_maps.gd` asserts no physics nodes by class, no shipped `CSGShape3D`, zeroed `GridMap`/`TileMapLayer` collision — source: ADR-0012 §2, §3
- Forbidden: Never use a physics body, area, cast or collision shape in the Overworld, 2D or 3D (`CollisionObject2D/3D`, `SoftBody3D`, `RayCast*`, `ShapeCast*`, `SpringArm3D`, joints, `PhysicalBoneSimulator3D`, the deprecated `TileMap`, any shipped `CSGShape3D`) — source: ADR-0012 §2, §3 (Alternatives 1 and 3)
- Guardrail: Overworld memory: ~1 byte per walk cell plus a 4-byte component label; no physics world allocated — source: ADR-0012 Performance

---

## Acceptance Criteria

*From GDD `design/gdd/overworld-exploration-encounters.md`, scoped to this story:*

- [x] **AC-30e [D] (ADR-0012)** The scene contains no node of these classes: `CollisionObject3D` or `CollisionObject2D` (bodies and areas), `SoftBody3D`, `RayCast3D`, `ShapeCast3D`, `RayCast2D`, `ShapeCast2D`, `SpringArm3D`, any `Joint3D`/`Joint2D`, `PhysicalBoneSimulator3D`. Shipped maps contain no `CSGShape3D` at all (CSG is baked to `MeshInstance3D` in the editor, or with `bake_static_mesh()` one frame after tree entry). Every `GridMap` has `collision_layer` = `collision_mask` = 0, and `mesh_library.get_item_shapes(id)` is empty for every used item (`GridMap.collision_layer` defaults to 1 on 4.7.2, so the authoring default must be changed). Every `TileMapLayer` has `collision_enabled` off (it defaults to on, so this authoring default must also be changed).

---

## Implementation Notes

*Derived from ADR-0012 §3's `validate_maps.gd` class list and Engine Compatibility (probed items):*

- Walk every shipped map scene and fail on any node of the listed physics classes, naming the node's path and class.
- Fail on any `CSGShape3D` at all in a shipped map — CSG is an authoring tool, baked to `MeshInstance3D` before ship (or via `bake_static_mesh()`, which returns null before tree entry and a valid mesh only one frame later — probed).
- Every `GridMap`: `collision_layer == 0 and collision_mask == 0`, and every used item's `mesh_library.get_item_shapes(id)` is empty. Because `GridMap.collision_layer` defaults to **1**, this check also catches an author who never touched the property.
- Every `TileMapLayer`: `collision_enabled == false`, catching the same "never touched it" default (collision defaults **on**).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- story-078-overworld-reference-integrity-check: reference resolution, unrelated to node classes (AC-30d)

---

## Files

- `tools/ci/validate_maps.gd`
- `scenes/maps/**/*.tscn` (checked, not authored here)
- `tests/unit/overworld/no_physics_nodes_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic (Data validation)
**Required evidence**:
- `tests/unit/overworld/no_physics_nodes_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: None
- Unlocks: `production/epics/overworld-exploration-encounters/story-080-entry-point-exit-clearance.md`

## Completion Notes (2026-10-30)

- `MapValidator.check_no_physics()` runs from `validate_maps` for every map. It reports banned node classes (and subclasses, via `is_class`), any GridMap collision layer or mask, any GridMap item shapes, and any TileMapLayer with `collision_enabled` on.
- It caught all four shipped WalkLayers with collision on (the 4.7.2 default). They are now off in the scenes and in `build_paris_dungeon_maps.gd`.
- Mutation checked: dropping `Joint3D` from the ban list fails a test here.
