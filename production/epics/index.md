# Epics Index

Last Updated: 2026-10-29
Engine: Godot 4.7.2

| Epic | Layer | System | GDD | Stories | Status |
|------|-------|--------|-----|---------|--------|
| [Go back to your planet!](go-back-to-your-planet/EPIC.md) | MVP (minimal tier, pre-architecture) | Battle core, squad, Bureaucratia, MegaCorp, battle HUD, chapter flow | design/game-brief.md | 6 (done) | In Progress |
| [Content Catalog](content-catalog/EPIC.md) | Foundation | Content Data Definitions (+ Content Boot Ordering) | content-data-definitions.md | 30 stories | Ready |
| [Content Migration](content-migration/EPIC.md) | Foundation | Content Data Definitions (ADR-0001 Migration Plan) | content-data-definitions.md | 35 stories | Ready |
| [Input System](input-system/EPIC.md) | Foundation | Input System | input-system.md | 26 stories | Ready |
| [Game State & Scene Flow](game-state-scene-flow/EPIC.md) | Foundation | Game State & Scene Flow | game-state-scene-flow.md | 41 stories | Ready |
| [Sprite & Camera Presentation](sprite-camera-presentation/EPIC.md) | Core | Sprite & Camera Presentation | sprite-camera-presentation.md | 74 stories | Ready |

**Foundation build order** (producer PR-EPIC, 2026-10-23): test setup (story 1 of
Content Catalog) → Content Catalog, with Content Migration Step 0 alongside → Input
System ∥ Game State Step 1 → Game State Step 2 (GameRoot, Battle mode, ChapterFlow
hand-over) → finish Content Migration → Game State Step 3. Core-layer epics start once
Content Catalog and Game State Step 2 are done.
