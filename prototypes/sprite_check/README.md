# Sprite check (prototype)

Plays every exported SpriteForge strip in-engine, one row per character,
plus the battle backdrops, to eyeball new art before it reaches a battle.
Not used by the game.

    godot --path . -s res://prototypes/sprite_check/sprite_check.gd
    # keys: 1 = squad, 2 = enemies, 3 = backdrops
    godot --path . -s res://prototypes/sprite_check/sprite_check.gd -- --shots=<dir>   # save screenshots and quit

Evidence it produced: `production/qa/evidence/sprite-import-battle-view/05-*.png`, `06-*.png`.
