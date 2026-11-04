"""Rewrites the London, Sydney and New York placeholder map scenes with their
own walk layouts (data/maps/<city>_<map>_placeholder.tscn).

Each layout is ASCII: `#` is wall, `.` is floor, one character is one 1 m
cell, ground (x, y) is world (x, z). Markers keep their nodes and every
property the spec doesn't name; the spec moves them (`pos` = world x, z)
and overrides other properties with raw .tscn values.

Usage, from the project root (Python 3):

    py tools/maps/city_layouts.py            # all cities
    py tools/maps/city_layouts.py london     # one city

Then check with:

    godot --headless --path . -s res://tools/maps/validate_maps_cli.gd

Re-run after editing a layout; the scenes are rewritten in place.
"""
import base64
import re
import struct
import subprocess
import sys

from city_layout_specs import SPECS

MAP_DIR = "data/maps"
# The scenes are always rebuilt from this commit (every city on the shared
# Paris/London layout), so re-running is idempotent and `mirror_x` never
# applies twice.
BASE_COMMIT = "0ab6e17"


def encode_grid(rows):
    w = len(rows[0])
    for y, r in enumerate(rows):
        if len(r) != w:
            raise ValueError("row %d is %d wide, expected %d: %r" % (y, len(r), w, r))
    out = bytearray(b"\x00\x00")
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch not in "#.":
                raise ValueError("bad cell %r at (%d, %d)" % (ch, x, y))
            out += struct.pack("<hhHHHH", x, y, 0, 0 if ch == "." else 1, 0, 0)
    return base64.b64encode(bytes(out)).decode("ascii")


def _fmt(v):
    s = ("%.3f" % v).rstrip("0").rstrip(".")
    return s if s not in ("-0", "") else "0"


def node_block(text, name):
    m = re.search(r'\[node name="%s"[^\]]*\]\n' % re.escape(name), text)
    if m is None:
        raise KeyError("no node %s" % name)
    start = m.end()
    nxt = text.find("\n[", start)
    end = len(text) if nxt == -1 else nxt + 1
    return start, end


def set_prop(block, key, value):
    pat = re.compile(r"^%s = .*$" % re.escape(key), re.M)
    line = "%s = %s" % (key, value)
    if pat.search(block):
        return pat.sub(lambda _m: line, block, count=1)
    # Insert after the script line, else at the top.
    sm = re.search(r"^script = .*$", block, re.M)
    if sm:
        return block[: sm.end()] + "\n" + line + block[sm.end():]
    return line + "\n" + block


def set_pos(block, x, z):
    line = "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, 0, %s)" % (_fmt(x), _fmt(z))
    pat = re.compile(r"^transform = .*$", re.M)
    if pat.search(block):
        return pat.sub(lambda _m: line, block, count=1)
    return line + "\n" + block


def _mirror_block(block, w):
    """Mirrors every ground coordinate in one node block about x = w / 2."""
    def tr(m):
        # A marker on a cell boundary (x whole) belongs to the cell on its
        # right (`WalkGrid.cell_of` floors); its mirror is that cell's
        # mirror, so it lands on the mirrored cell's centre.
        x = float(m.group(1))
        mx = w - x - 0.5 if x == int(x) else w - x
        return "0, 0, 1, %s, 0, %s)" % (_fmt(mx), m.group(2))
    block = re.sub(r"0, 0, 1, ([-\d.]+), 0, ([-\d.]+)\)", tr, block)

    def rect(m):
        x, y, rw, rh = (float(v) for v in m.group(2).split(","))
        return "%s = Rect2(%s, %s, %s, %s)" % (m.group(1), _fmt(w - x - rw), _fmt(y), _fmt(rw), _fmt(rh))
    block = re.sub(r"^(\w+_rect) = Rect2\(([^)]*)\)", rect, block, flags=re.M)

    def point(m):
        x, y = (float(v) for v in m.group(2).split(","))
        return "%s = Vector2(%s, %s)" % (m.group(1), _fmt(w - x), _fmt(y))
    block = re.sub(r"^(return_marker) = Vector2\(([^)]*)\)", point, block, flags=re.M)

    def facing(m):
        x, y = (float(v) for v in m.group(2).split(","))
        return "%s = Vector2(%s, %s)" % (m.group(1), _fmt(-x), _fmt(y))
    block = re.sub(r"^(facing|return_facing) = Vector2\(([^)]*)\)", facing, block, flags=re.M)

    def path(m):
        vals = [float(v) for v in m.group(1).split(",")]
        out = []
        for i in range(0, len(vals), 2):
            out += [_fmt(w - vals[i]), _fmt(vals[i + 1])]
        return "patrol_path = PackedVector2Array(%s)" % ", ".join(out)
    block = re.sub(r"^patrol_path = PackedVector2Array\(([^)]*)\)", path, block, flags=re.M)
    return block


def mirror(text, w):
    parts = re.split(r'(\[node name="[^"]+" type="Marker3D"[^\]]*\]\n)', text)
    for i in range(2, len(parts), 2):
        nxt = parts[i].find("\n[")
        head, tail = (parts[i], "") if nxt == -1 else (parts[i][: nxt + 1], parts[i][nxt + 1:])
        parts[i] = _mirror_block(head, w) + tail
    return "".join(parts)


def apply(path, spec):
    text = subprocess.run(["git", "show", "%s:%s" % (BASE_COMMIT, path)], capture_output=True,
                          check=True).stdout.decode("utf-8")
    if spec.get("mirror_x"):
        text = mirror(text, spec["mirror_x"])
    text = re.sub(r'tile_map_data = PackedByteArray\("[^"]*"\)',
                  'tile_map_data = PackedByteArray("%s")' % encode_grid(spec["grid"]), text, count=1)
    sx, sy = spec["spawn"]
    text = re.sub(r"leader_spawn_cell = Vector2i\([^)]*\)",
                  "leader_spawn_cell = Vector2i(%d, %d)" % (sx, sy), text, count=1)
    for name, props in spec["nodes"].items():
        start, end = node_block(text, name)
        block = text[start:end]
        for key, value in props.items():
            if key == "pos":
                block = set_pos(block, value[0], value[1])
            else:
                block = set_prop(block, key, value)
        text = text[:start] + block + text[end:]
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)


def main(argv):
    cities = argv[1:] or sorted(SPECS)
    for city in cities:
        for map_name, spec in SPECS[city].items():
            path = "%s/%s_%s_placeholder.tscn" % (MAP_DIR, city, map_name)
            apply(path, spec)
            print("wrote", path)


if __name__ == "__main__":
    main(sys.argv)
