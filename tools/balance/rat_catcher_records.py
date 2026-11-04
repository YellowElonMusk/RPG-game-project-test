"""Writes the Rat Catchers' enemy and encounter records (narrative bible 6.5).

One table per chapter tier, so balance is tuned here and re-run:

    py tools/balance/rat_catcher_records.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# tier -> role -> (hp, atk, def, spd, xp, money)
TIERS = {
    "paris":   {"trapper": (40, 14, 9, 9, 10, 8),   "scout": (34, 15, 8, 12, 10, 8),  "captain": (100, 14, 10, 10, 40, 30)},
    "london":  {"trapper": (50, 17, 11, 10, 13, 10), "scout": (44, 18, 10, 13, 13, 10), "captain": (130, 16, 12, 11, 50, 36)},
    "sydney":  {"trapper": (62, 19, 13, 10, 17, 12), "scout": (54, 20, 12, 13, 17, 12), "captain": (165, 18, 14, 11, 60, 42)},
    "newyork": {"trapper": (76, 22, 15, 11, 20, 14), "scout": (66, 23, 14, 14, 20, 14), "captain": (200, 20, 16, 12, 72, 50)},
}
NAMES = {"trapper": "Rat Trapper", "scout": "Tunnel Scout", "captain": "Rat Catcher Captain"}
MOVES = {
    "trapper": ["move_net_throw", "move_rat_trap"],
    "scout": ["move_headlamp_glare", "move_tunnel_rush"],
    "captain": ["move_wanted_poster", "move_citizens_arrest"],
}
SPRITES = {"trapper": "sprite_rat_trapper", "scout": "sprite_tunnel_scout", "captain": "sprite_rat_captain"}
# Enemy records carry no faction_id: an Enemy's faction must be alien (content
# GDD); the Encounter names faction_rat_catchers, which picks the rule.
# Ambush: who jumps out on the segment (a mild tax). Captain: once per chapter.
AMBUSH = ["trapper", "trapper", "scout"]
CAPTAIN = ["captain", "trapper", "scout"]
POST_AMBUSH = "The Rat Catchers sit down on the kerb, nets tangled. \"Fine. You're not rats. Probably. We'll be watching.\""
POST_CAPTAIN = "The Captain rolls up the Wanted poster. \"Rats fight dirty. You didn't. Doesn't mean I like you.\" The Rat Catchers slip back into the tunnels."


def enemy(tier: str, role: str) -> str:
    hp, atk, dfn, spd, xp, money = TIERS[tier][role]
    moves = ", ".join('"%s"' % m for m in MOVES[role])
    boss = "is_boss = true\n" if role == "captain" else ""
    return f'''[gd_resource type="Resource" script_class="EnemyData" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/data/records/enemy_data.gd" id="1_a"]

[resource]
script = ExtResource("1_a")
id = "enemy_rat_{role}_{tier}"
display_name = "{NAMES[role]}"
{boss}max_hp = {hp}
attack = {atk}
defense = {dfn}
speed = {spd}
reward_xp = {xp}
reward_money = {money}
move_ids = PackedStringArray({moves})
sprite_set_id = "{SPRITES[role]}"
'''


def encounter(tier: str, kind: str) -> str:
    roles = CAPTAIN if kind == "captain" else AMBUSH
    ids = ", ".join('"enemy_rat_%s_%s"' % (r, tier) for r in roles)
    boss = "true" if kind == "captain" else "false"
    line = POST_CAPTAIN if kind == "captain" else POST_AMBUSH
    line = line.replace('"', '\\"')
    return f'''[gd_resource type="Resource" script_class="EncounterData" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/data/records/encounter_data.gd" id="1_a"]

[resource]
script = ExtResource("1_a")
id = "enc_rat_{kind}_{tier}"
enemy_ids = PackedStringArray({ids})
battle_stage_id = "stage_chapter_interim"
faction_id = "faction_rat_catchers"
is_boss = {boss}
can_flee = {"false" if kind == "captain" else "true"}
retreat_allowed = true
respawn = false
post_battle_line = "{line}"
'''


def main() -> None:
    for tier in TIERS:
        for role in TIERS[tier]:
            (ROOT / "data/enemies" / f"enemy_rat_{role}_{tier}.tres").write_text(enemy(tier, role), newline="\n")
        kinds = ["captain"] if tier == "paris" else ["ambush", "captain"]
        for kind in kinds:
            (ROOT / "data/encounters" / f"enc_rat_{kind}_{tier}.tres").write_text(encounter(tier, kind), newline="\n")
    print("rat catcher records written")


if __name__ == "__main__":
    main()
