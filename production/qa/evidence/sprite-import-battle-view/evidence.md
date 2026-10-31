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

Known gaps (flagged, not fixed here): no blob shadows yet (story 020); no hit
punch or VFX wired; MegaCorp backdrop not captured (no shipped MegaCorp
encounter) -- its road starts ~y 555, so enemies may sit at the curb.
