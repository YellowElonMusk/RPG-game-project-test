"""Writes the Rat Catchers' sprite-set records (placeholder strips from
`rat_catcher_placeholder_sprites.gd`). Frame counts follow the starters'
strips the placeholders are made from.

    py tools/art/rat_catcher_sprite_sets.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def anim(i: int, aid: str, fps: str, frames: int, strip_id: str, extra: str = "") -> str:
    fd = ", ".join(["1"] * frames)
    return (f'[sub_resource type="Resource" id="anim_{i}"]\n'
            f'script = ExtResource("2_anim")\n'
            f'animation_id = &"{aid}"\n'
            f'facing = &"front"\n'
            f'{extra}fps = {fps}\n'
            f'frame_durations = PackedFloat32Array({fd})\n'
            f'strip = ExtResource("{strip_id}")\n')


def write(set_id: str, folder: str, boss: bool) -> None:
    clips = ["idle", "attack", "hurt", "ko"] + (["special"] if boss else [])
    ids = {c: f"{3 + i}_{c}" for i, c in enumerate(clips)}
    subs = [
        anim(0, "idle", "4.0", 4, ids["idle"]),
        anim(1, "attack", "10.0", 4, ids["attack"], "impact_frame = 1\n"),
        anim(2, "defend", "6.0", 4, ids["idle"], "impact_frame = 0\n"),
        anim(3, "hit", "8.0", 2, ids["hurt"]),
        anim(4, "knockout", "8.0", 3, ids["ko"], "land_frame = 2\n"),
    ]
    if boss:
        for mv in ["Wanted Poster", "Citizen's Arrest"]:
            subs.append(anim(len(subs), "move", "10.0", 6, ids["special"],
                             f'move_name = "{mv}"\nimpact_frame = 2\n'))
        subs.append(anim(len(subs), "intro", "10.0", 6, ids["special"]))
    head = (f'[gd_resource type="Resource" script_class="SpriteSetData" '
            f'load_steps={3 + len(clips) + len(subs)} format=3]\n\n'
            '[ext_resource type="Script" path="res://src/presentation/sprite_set_data.gd" id="1_set"]\n'
            '[ext_resource type="Script" path="res://src/presentation/sprite_animation_data.gd" id="2_anim"]\n')
    for c in clips:
        head += (f'[ext_resource type="Texture2D" '
                 f'path="res://assets/sprites/enemies/{folder}/{folder}_{c}.png" id="{ids[c]}"]\n')
    refs = ", ".join(f'SubResource("anim_{i}")' for i in range(len(subs)))
    res = ('[resource]\nscript = ExtResource("1_set")\n'
           f'set_id = &"{set_id}"\nis_placeholder = true\nis_squad = false\n'
           'facings_used = Array[StringName]([&"front"])\n'
           f'animations = Array[ExtResource("2_anim")]([{refs}])\n')
    (ROOT / f"data/presentation/sprite_sets/{set_id}.tres").write_text(
        head + "\n" + "\n".join(subs) + "\n" + res, newline="\n")


if __name__ == "__main__":
    write("sprite_rat_trapper", "rat_trapper", False)
    write("sprite_tunnel_scout", "tunnel_scout", False)
    write("sprite_rat_captain", "rat_captain", True)
    print("rat catcher sprite sets written")
