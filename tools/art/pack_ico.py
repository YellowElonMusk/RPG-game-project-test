"""Packs assets/icon/icon_<size>.png (from make_icon.gd) into
assets/icon/icon.ico, the Windows exe icon (export preset
`application/icon`). PNG-compressed entries, valid on Windows Vista+.

    py tools/art/pack_ico.py
"""
import struct

SIZES = [16, 32, 48, 64, 128, 256]
DIR = "assets/icon"


def main():
    blobs = []
    for s in SIZES:
        with open("%s/icon_%d.png" % (DIR, s), "rb") as f:
            blobs.append(f.read())
    out = struct.pack("<HHH", 0, 1, len(SIZES))
    offset = 6 + 16 * len(SIZES)
    for s, blob in zip(SIZES, blobs):
        dim = 0 if s >= 256 else s  # 0 means 256 in an ICONDIRENTRY
        out += struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(blob), offset)
        offset += len(blob)
    out += b"".join(blobs)
    with open("%s/icon.ico" % DIR, "wb") as f:
        f.write(out)
    print("wrote %s/icon.ico (%d bytes)" % (DIR, len(out)))


if __name__ == "__main__":
    main()
