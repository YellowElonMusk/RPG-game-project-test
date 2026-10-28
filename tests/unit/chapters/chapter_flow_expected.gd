## Expected tables for the ChapterFlow characterization tests (Story 032;
## ADR-0002 Migration Step 0). Every value here is a literal copy read once
## from today's shipped ChapterFlow/BureaucratiaRule/MegaCorpRule code --
## never a win-rate or balance number (Control Manifest: "Forbidden:
## asserting win rates or balance outcomes in a characterization test").
class_name ChapterFlowExpected
extends RefCounted

## Seeds the shared RNG injected into ChapterFlow -- test input, not an
## assertion.
const SEED: int = 12345

## Fight order + per-faction roster (checks 1, 2): fights 0-2 regular, fight
## 3 the boss, one enemy per fight (ChapterFlow._build_regular_enemies() /
## _build_boss_enemies(), read 2026-10-28).
const CHAPTER_EXPECTED: Dictionary = {
	"bureaucratia": [
		{"index": 0, "is_boss": false, "enemy_names": ["Clerk"]},
		{"index": 1, "is_boss": false, "enemy_names": ["Clerk"]},
		{"index": 2, "is_boss": false, "enemy_names": ["Clerk"]},
		{"index": 3, "is_boss": true, "enemy_names": ["Supervisor"]},
	],
	"megacorp": [
		{"index": 0, "is_boss": false, "enemy_names": ["Security Drone"]},
		{"index": 1, "is_boss": false, "enemy_names": ["Middle Manager"]},
		{"index": 2, "is_boss": false, "enemy_names": ["Security Drone"]},
		{"index": 3, "is_boss": true, "enemy_names": ["CEO"]},
	],
}


## A small fixture squad shared by every ChapterFlow characterization test.
## The stat block is arbitrary test input, not a pin -- only carryover and
## retry *behavior* are pinned here, never a specific stat value.
static func make_squad() -> Array[Combatant]:
	return [
		Combatant.new("Hero", 30, 10, 12, 8, 10, false),
		Combatant.new("Sidekick", 24, 8, 10, 6, 9, false),
	]
