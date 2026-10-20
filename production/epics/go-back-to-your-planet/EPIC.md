# Epic: Go back to your planet!

> **Status**: In Progress
> **Tier**: minimal (no ADRs, no control manifest, no TR registry at this tier)

## Goal

Earth's military has fallen to a satirical alien alliance, and you lead humanity's
most unlikely heroes into turn-based battles, cracking each planet's absurd rule to
send the invaders home.

## Scope

From `design/game-brief.md` MVP:
1. Battle core: turn-based combat with Attack, Defend, specials, MP, win/lose and retry.
2. The squad: Karen, Michelin Chef, Florida Man, Baguette Thrower, with their specials.
3. Bureaucratia: 3-round permit ban on specials for both sides, hunker-down AI, Supervisor boss.
4. MegaCorp (cyberpunk planet): subscription billing, suspension, CEO boss.
5. A linear chapter per planet: 3 fights, then the boss.
6. Battle HUD: HP/MP bars, rule banner, floating numbers, tooltips.

Out of scope: see `design/game-brief.md` — Out of scope.

## Order

From the brief's Build order:
1. Battle core and Bureaucratia (rebuild what `prototypes/battle-concept/` proved).
2. The four squad specials.
3. MegaCorp's billing rule and enemies.
4. The battle HUD and rule tooltips.
5. Chapter flow: the fight chain and the boss, for both planets.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Battle core | Logic | Ready | N/A (minimal) |
| 002 | Bureaucratia — permit, hunker-down, Supervisor boss | Logic | Ready | N/A (minimal) |
| 003 | Squad specials — Karen, Chef, Florida Man, Baguette Thrower | Logic | Ready | N/A (minimal) |
| 004 | MegaCorp — subscription billing, drones, CEO boss | Logic | Ready | N/A (minimal) |
| 005 | Battle HUD — bars, rule banner, floating numbers, tooltips | UI | Ready | N/A (minimal) |
| 006 | Chapter flow — fight chain and boss, both planets | Integration | Ready | N/A (minimal) |
