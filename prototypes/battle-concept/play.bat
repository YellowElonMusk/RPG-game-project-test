@echo off
REM PROTOTYPE - NOT FOR PRODUCTION
REM Question (iteration 2): Does Bureaucratia's 3-round permit wait build tension that pays off when all-out war begins?
REM Date: 2026-10-20
REM Double-click to play. Launches the battle prototype directly in Godot 4.7.2.
REM Needs `godot` on PATH (see the project README, "Running it").
godot --path "%~dp0..\.." --windowed --resolution 1280x720 res://prototypes/battle-concept/battle.tscn
