"""Turns the Nano Banana Pro 'crazed' render into face-crazed.png, matched to the other states.

    python3 MakeCrazed.py Art/face-crazed-nanobanana-raw.png Faces/face-idle.png Faces/face-crazed.png
"""
import sys
from collections import deque
from PIL import Image

raw, idle_path, out = sys.argv[1], sys.argv[2], sys.argv[3]
im = Image.open(raw).convert("RGBA")
W, H = im.size
px = im.load()

# 1. white background → transparent (flood from the four corners so the teeth stay white)
def whiteish(p): return p[0] > 228 and p[1] > 228 and p[2] > 228
seen = set(); q = deque([(0, 0), (W - 1, 0), (0, H - 1), (W - 1, H - 1)])
while q:
    x, y = q.popleft()
    if (x, y) in seen or not (0 <= x < W and 0 <= y < H): continue
    seen.add((x, y))
    if not whiteish(px[x, y]): continue
    px[x, y] = (0, 0, 0, 0)
    q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
print("bg removed:", len(seen), "px")

# 2. find the head: widest opaque span (the jacket/shoulders), and its horizontal centre
rows = []
for y in range(H):
    xs = [x for x in range(0, W, 2) if px[x, y][3] > 0]
    if xs: rows.append((y, xs[0], xs[-1]))
bottom = max(r[0] for r in rows)
widest = max(rows, key=lambda r: r[2] - r[1])
head_w = widest[2] - widest[1]
cx = (widest[1] + widest[2]) // 2
print("head width", head_w, "centre x", cx, "bottom y", bottom)

# 3. match the idle face: its head width / centre / bottom in the 640 canvas
idle = Image.open(idle_path).convert("RGBA"); ip = idle.load(); IW, IH = idle.size
irows = []
for y in range(IH):
    xs = [x for x in range(IW) if ip[x, y][3] > 0]
    if xs: irows.append((y, xs[0], xs[-1]))
ibottom = max(r[0] for r in irows)
iwidest = max(irows, key=lambda r: r[2] - r[1])
target_w = iwidest[2] - iwidest[1]; target_cx = (iwidest[1] + iwidest[2]) // 2
scale = target_w / head_w
print("idle head width", target_w, "scale", round(scale, 3))
new = im.resize((int(W * scale), int(H * scale)), Image.LANCZOS)
canvas = Image.new("RGBA", (IW, IH), (0, 0, 0, 0))
ox = int(target_cx - cx * scale)
oy = int(ibottom - bottom * scale)
canvas.alpha_composite(new, (ox, oy)) if ox >= 0 and oy >= 0 else canvas.paste(new, (ox, oy), new)
canvas.save(out, optimize=True)
print("wrote", out, canvas.size)
