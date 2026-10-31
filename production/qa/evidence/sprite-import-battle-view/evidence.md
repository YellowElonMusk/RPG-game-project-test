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

Known gaps (flagged, not fixed here): enemies at depth 20 stand slightly above
the painted road; squad legs sit behind the command menu while it is open; no
blob shadows yet (story 020); no hit punch or VFX wired.
