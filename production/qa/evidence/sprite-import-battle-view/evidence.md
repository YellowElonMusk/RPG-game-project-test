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

Known gaps: impact_burst is not routed through FlashGate yet (not wired in
GameRoot); no MegaCorp encounter to capture.
