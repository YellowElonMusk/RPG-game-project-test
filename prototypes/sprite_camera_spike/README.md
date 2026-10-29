# PROTOTYPE - NOT FOR PRODUCTION
# Sprite & Camera windowed engine spike (story-001)

**Hypothesis:** Godot 4.7.2 supports ADR-0005 verification items 12–16 (ambient-disabled, key-only actor lighting; manual AnimatedSprite3D frame stepping; shader flip; a glow-before-tonemap compositor hook; pipeline-compile counters), and the `frustum_offset` sign holds at 16:9 and 16:10.

**Run:** `timeout 170 Godot_v4.7.2-stable_win64_console.exe --path . --windowed --resolution 1280x720 -s res://prototypes/sprite_camera_spike/spike_main.gd < /dev/null` (never `-d`). It writes PNGs to `production/qa/evidence/story-001-windowed-engine-spike/` and prints the counter, sign and glow results.

**Status:** concluded (2026-10-29), apart from the owed items.

**Findings:** 12, 13 and 14 PASS. 15 FAIL (no compositor hook between glow and tonemap). 16 partial (warm cache; nothing registered). The sign is +y = image down at both aspects. See the story's Completion Notes and ADR-0005.
