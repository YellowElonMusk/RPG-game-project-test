# Go back to your planet!

Earth's military has fallen to a satirical alien alliance, and you lead humanity's
most unlikely heroes into turn-based battles, cracking each planet's absurd rule to
send the invaders home.

A turn-based, Dragon Quest-style party RPG built in **Godot 4.7.2** (GDScript).

## The squad

| Recruit | Special |
|---|---|
| **Karen** | *Speak to the Manager*: stuns one enemy (bosses don't take complaints) |
| **Michelin Chef** | *Appetizer* heals one ally; *Family Meal* heals the whole squad over time |
| **Florida Man** | *Viral Stunt*: the target takes 50% more damage for 2 rounds |
| **Baguette Thrower** | *Baguette Home Run*: swings a day-old baguette like a baseball bat |

## The planets (MVP)

- **Bureaucratia:** no special moves for either side until the government permit
  arrives (3 rounds). The officials hunker down and prey on anyone at half HP.
- **MegaCorp (cyberpunk):** subscription billing charges every squad member MP each
  round. At 0 MP you're suspended to basic attacks.

More planets (Influencia, Super Patriot, Oratio, Only Male Alpha) come after the MVP.

## Status

Early development. What exists:

- **Battle prototype** with both planets: `prototypes/battle-concept/`
- **Battle core** (turn order, Attack/Defend, MP, win/loss/retry): `src/battle/`
- Design: `design/game-brief.md` (the MVP brief), `design/gdd/` (system designs),
  `design/art/art-bible.md`
- Production plan: `production/epics/go-back-to-your-planet/` (6 MVP stories)

## Running it

1. Install [Godot 4.7.2](https://godotengine.org/) and make it callable as `godot`
   from a terminal. The project's commands and `play.bat` assume that. On Windows,
   put the Godot folder on your PATH and add a `godot.cmd` next to the exe containing
   `@"%~dp0Godot_v4.7.2-stable_win64_console.exe" %*`. For Git Bash, also add a `godot`
   script containing `exec "/c/<your Godot folder>/Godot_v4.7.2-stable_win64_console.exe" "$@"`.
2. Open this folder as a Godot project. On first open (or on the command line, run
   `godot --headless --path . --import` once) Godot builds its cache.
3. Play the prototype: open `prototypes/battle-concept/battle.tscn` and press **F6**
   (Run Current Scene), or double-click `prototypes/battle-concept/play.bat` on Windows.
4. Battle-core test screen: open `src/battle/battle_debug_harness.tscn` and press **F6**.

## Project layout

| Folder | Contents |
|---|---|
| `src/` | Game code |
| `prototypes/` | Throwaway prototypes (never imported by `src/`) |
| `design/` | Game brief, system designs, art bible, entity registry |
| `docs/` | Architecture and registries |
| `production/` | Stories, QA evidence, project stage |

Built with the help of [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios).
