# Test Infrastructure

**Engine**: Godot 4.7.2
**Test Framework**: GdUnit4
**CI**: `.github/workflows/tests.yml`
**Setup date**: 2026-10-22

## Directory Layout

```
tests/
  unit/           # Isolated unit tests (formulas, state machines, logic)
  integration/    # Cross-system and save/load tests
  smoke/          # Critical path test list for /smoke-check gate
```

```
production/qa/
  evidence/       # Screenshot logs and manual test sign-off records
```

> **Manual evidence lives under `production/qa/evidence/`, not `tests/`** — that
> is where every consumer reads it.

Planned suites named by the Accepted ADRs (create each when its story starts):
- `tests/unit/battle/`: the characterization suite (ADR-0001 Migration Step 0), which runs first and stays green through every migration step (ADR-0010)
- `tests/unit/ui/`: `MenuGuard`, focus stack, held-direction mirror, pointer counter, `UiNavigator` (ADR-0008)
- `tests/unit/save/`: uses the in-memory `SaveFileSystem` and never touches `user://` (ADR-0009)

## Installing GdUnit4

```
1. Open Godot → Asset Store (AssetLib before Godot 4.7) → search "GdUnit4" → install it
2. Enable the plugin: Project → Project Settings → Plugins → GdUnit4 ✓
3. Restart the editor
4. Verify: res://addons/gdUnit4/bin/GdUnitCmdTool.gd exists (capital U)
```

Commit `addons/gdUnit4/`. CI runs the committed copy (`version: installed`).

**Installed version**: gdUnit4 **6.2.2** (Story 001, 2026-10-23), pulled from the
project's GitHub release archive (Asset Store listing lagged 4.7.2) and enabled
via `project.godot`'s `[editor_plugins]` section. The project's upstream README
compatibility table lists `v6.2.x` as compatible through Godot v4.7.1; v4.7.2 is
a patch release of 4.7.1 and is not separately listed. Confirmed working by the
actual headless test run (Story 001's acceptance criterion), not by the editor
UI — re-verify in the editor if anything looks off after an engine upgrade.

## Running Tests

```bash
godot --headless --path . --import
godot --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
```

Run the import first. On a fresh clone there is no `.godot/` class cache, so
without it the run exits **1** (`Failed to load script`) and no test runs. A
cache that predates a new `class_name` makes valid code fail with exit 105.

Exit codes:

| Code | Meaning |
|---|---|
| 0 | Every test passed. `No test cases found` also exits 0, and that is **not** a pass |
| 100 | At least one test failed |
| 101 | Every test passed, but a test leaked nodes. A warning, except for Game State, where ADR-0002 counts it as a failure |
| 103, 104 | GdUnit4 could not run |
| 105 | A test script does not parse |

`--ignoreHeadlessMode` and `--remote-debug tcp://127.0.0.1:0` are both required.
The second one makes every run print two expected `ERROR:` lines about the
remote port.

## Test Naming

Names follow the engine's language (`.claude/rules/test-standards.md`):
- **Godot**: file `[system]_[feature]_test.gd`, function `test_[scenario]_[expected]`
  — `combat_damage_test.gd` → `test_base_attack_returns_expected_damage()`

## Story Type → Test Evidence

| Story Type | Required Evidence | Location |
|---|---|---|
| Logic | Automated unit test — must pass | `tests/unit/[system]/` |
| Integration | Integration test OR playtest doc | `tests/integration/[system]/` |
| Visual/Feel | Screenshot + lead sign-off | `production/qa/evidence/` |
| UI | Retained screenshot of each screen touched | `production/qa/evidence/` |
| Config/Data | Smoke check pass | `production/qa/smoke-*.md` |

## CI

Tests run automatically on every push to `main` and on every pull request.
A failed test suite blocks merging.
