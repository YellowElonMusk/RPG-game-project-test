@echo off
REM Double-click to play the game (Godot 4.7.2, editor binary; no export preset yet).
REM Boots Title -> New Game -> the overworld. Needs Godot at C:\Godot (or `godot` on PATH).
if exist "C:\Godot\Godot_v4.7.2-stable_win64.exe" (
  start "" "C:\Godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0"
) else (
  start "" godot --path "%~dp0"
)
