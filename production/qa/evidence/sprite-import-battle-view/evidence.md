# Sprite import: battle view evidence (2026-10-31)

Captured windowed at 1280x720 with
`godot --path . -s res://tools/capture/battle_capture.gd -- --encounter=<id> --out=<dir>`,
which boots content for real (sprite-set validators included) before entering Battle.

| File | Shows |
|---|---|
| 01-clerk-fight-idle.png | `enc_paris_clerks_hall`: Bureaucratia backdrop, squad (back facing) on slots 0-3, Clerk idle |
| 02-clerk-fight-attack-beat.png | Same fight mid-beat: Baguette Thrower `attack`, Clerk `hit`; command menu hidden during replay |
| 03-boss-fight-idle.png | `enc_paris_supervisor`: boss backdrop, 128 px Supervisor centred, Clerk escort on the new side slot |
| 04-boss-fight-attack-beat.png | Boss fight mid-beat: Supervisor `hit` |
| 05/06-sprite-check-*.png | Every exported strip playing in-engine (`prototypes/sprite_check`) |

Grounding fix (same day): the command menu moved into the left column under
compact squad cards, freeing the painted ground band (y >= ~510 at 720p);
squad now stands at depth 8.7 (feet ~y 660), enemies at 12.8 (feet ~y 540).

Shadows, punch and impact VFX (same day): 02 and 04 are the impact frame --
impact_burst at the target's mid-body, target in its hit frame, damage number
beside the card; every actor has a blob shadow (story 020). The hit-punch
is too short (0.1 s, 2-5 px) to judge in a still; its wiring and the
backdrop following it are unit-tested.

FlashGate + MegaCorp (same day): GameRoot now owns the FlashGate service and
injects it into GameStateMachine (FlashGatePortAdapter) and BattleMode; every
impact burst asks it first and plays a muted capped variant on refusal
(unit-tested; Reduce Flashing has no settings UI yet, so it is Off in play).
07/08 are ad-hoc MegaCorp fights (`--faction --enemies --boss`): grounded on
the street, CEO burst on impact. The command panel now starts at y 464 so a
two-line faction banner no longer pushes the last squad card under it.

Drone hurt fix (same day): frame 1 of `security_drone_hurt.png` (a generated
in-between that grew legs) replaced by a copy of frame 0, the approved
legless recoil (candidate 004). 09 shows the drone through a hit.
