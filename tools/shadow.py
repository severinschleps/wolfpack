# Writes Media/Shadow/s1..s20.tga: white, opaque in the middle, fading out over n pixels at the
# edges (round at the corners). Drawn 9-sliced with margins n, tinted by the shadow's color.
import math, struct, sys
out = sys.argv[1] if len(sys.argv) > 1 else "WolfpackAddon/Media/Shadow"
for n in range(1, 21):
    t = 4
    while t < 2 * n + 2: t *= 2
    px = bytearray()
    for y in range(t):
        for x in range(t):
            dx = max(n - (x + 0.5), (x + 0.5) - (t - n), 0)
            dy = max(n - (y + 0.5), (y + 0.5) - (t - n), 0)
            a = max(0.0, 1 - math.hypot(dx, dy) / n)
            px += bytes((255, 255, 255, round(255 * a * a * (3 - 2 * a))))
    with open(f"{out}/s{n}.tga", "wb") as f:
        f.write(struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, t, t, 32, 40) + px)

# Media/Dot.tga: a white disc, its edge smoothed over a pixel; the trail's round caps.
t, px = 64, bytearray()
for y in range(t):
    for x in range(t):
        a = max(0.0, min(1.0, t / 2 - math.hypot(x + 0.5 - t / 2, y + 0.5 - t / 2)))
        px += bytes((255, 255, 255, round(255 * a)))
with open(f"{out}/../Dot.tga", "wb") as f:
    f.write(struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, t, t, 32, 40) + px)
