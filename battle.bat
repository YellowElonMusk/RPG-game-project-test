@echo off
REM Double-click to jump straight into a fight (with battle music).
REM Starts a New Game, walks into the first patrol on the Paris street and
REM hands you the battle. Other cities: battle.bat map_london_segment_placeholder
REM (also map_sydney_segment_placeholder, map_newyork_segment_placeholder).
set MAP=%1
if "%MAP%"=="" set MAP=map_paris_segment_placeholder
if exist "C:\Godot\Godot_v4.7.2-stable_win64.exe" (
  start "" "C:\Godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." -s res://tools/play/quick_battle.gd -- --map=%MAP%
) else (
  start "" godot --path "%~dp0." -s res://tools/play/quick_battle.gd -- --map=%MAP%
)
