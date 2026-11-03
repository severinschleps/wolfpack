# Writes Media/Frame/Bronze/*.tga from the pieces in assets/: uncompressed, top-left first, each
# padded with clear pixels to a power of two (the older clients load nothing else). The art sits
# in the top-left corner; ns.ART in the addon holds each piece's own size and its padded one.
import struct, sys, os
src = sys.argv[1] if len(sys.argv) > 1 else "assets"
out = sys.argv[2] if len(sys.argv) > 2 else "WolfpackAddon/Media/Frame/Bronze"
PIECES = { "tl": "top_left_corner", "tr": "top_right_corner", "bl": "bottom_left_corner",
    "br": "bottom_right_corner", "top": "top_horizontal_bar", "bottom": "bottom_horizontal_bar",
    "side": "leftandright_vertial_bar" }

def read(path): # 32-bit TGA, RLE (type 10) or not (type 2), BGRA rows
    d = open(path, "rb").read()
    idl, _, kind, _, _, _, _, _, w, h, bpp, desc = struct.unpack("<BBBHHBHHHHBB", d[:18])
    assert bpp == 32 and kind in (2, 10), path
    p, px = 18 + idl, bytearray()
    if kind == 2: px = bytearray(d[p:p + w * h * 4])
    while len(px) < w * h * 4:
        c = d[p]; p += 1; n = (c & 127) + 1
        if c & 128: px += d[p:p + 4] * n; p += 4
        else: px += d[p:p + 4 * n]; p += 4 * n
    rows = [px[y * w * 4:(y + 1) * w * 4] for y in range(h)]
    if not desc & 32: rows.reverse() # bottom-up on disk
    return w, h, rows

def pot(n):
    t = 1
    while t < n: t *= 2
    return t

os.makedirs(out, exist_ok=True)
for name, file in PIECES.items():
    w, h, rows = read(f"{src}/{file}.tga")
    W, H = pot(w), pot(h)
    px = b"".join(bytes(r) + bytes(4 * (W - w)) for r in rows) + bytes(4 * W * (H - h))
    with open(f"{out}/{name}.tga", "wb") as f:
        f.write(struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, W, H, 32, 40) + px)
    print(f"{name} = {{ {w}, {h}, {W}, {H} }},")
