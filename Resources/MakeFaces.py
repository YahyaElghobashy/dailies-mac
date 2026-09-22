"""Builds the 4 mascot states from the pixel-art VR face.

    python3 MakeFaces.py Art/face-src.png Faces/

idle   – untouched (transparent bg)
half   – left lens burning (⌊goal/2⌋ games done)
goal   – both lenses burning (daily goal reached)
crazed – everything on fire (every enabled game done in one day)
"""
import sys, random
from collections import deque
from PIL import Image, ImageDraw, ImageFilter

src, out = sys.argv[1], sys.argv[2].rstrip("/")
im = Image.open(src).convert("RGBA")
W, H = im.size
px = im.load()

# ── 1. isolate the visor: flood fill of pure black from the centre ────────────
def is_black(p): return p[3] > 250 and p[0] == 0 and p[1] == 0 and p[2] == 0
seen, q, visor = set(), deque([(W // 2, int(H * 0.45))]), set()
while q:
    x, y = q.popleft()
    if (x, y) in seen or not (0 <= x < W and 0 <= y < H): continue
    seen.add((x, y))
    if not is_black(px[x, y]): continue
    visor.add((x, y))
    q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
xs = [p[0] for p in visor]; ys = [p[1] for p in visor]
vx0, vx1, vy0, vy1 = min(xs), max(xs), min(ys), max(ys)
mid = (vx0 + vx1) // 2
print(f"visor {vx0}-{vx1} x {vy0}-{vy1}, {len(visor)} px, mid {mid}")
lens = {
    "L": [p for p in visor if p[0] < mid],
    "R": [p for p in visor if p[0] >= mid],
}
def bbox(pts):
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    return min(xs), min(ys), max(xs), max(ys)

visor_mask = Image.new("L", (W, H), 0)
vm = visor_mask.load()
for x, y in visor: vm[x, y] = 255

# ── 2. pixel flame glyph ──────────────────────────────────────────────────────
FLAME = [
    "....r....",
    "....r....",
    "...rr....",
    "...rrr...",
    "..rrrrr..",
    "..rooor..",
    ".rooooor.",
    ".roooyor.",
    "rooyyyoor",
    "rooywyoor",
    "roooyooor",
    ".rooooor.",
    "..rrrrr..",
]
PAL = {"r": (255, 74, 31, 255), "o": (255, 138, 30, 255), "y": (255, 210, 63, 255), "w": (255, 246, 200, 255)}

def stamp_flame(img, cx, bottom_y, cell, mask=None, alpha=255):
    """Draw the flame with its bottom edge at bottom_y, centred on cx."""
    d = ImageDraw.Draw(img)
    rows, cols = len(FLAME), len(FLAME[0])
    x0 = cx - (cols * cell) // 2
    y0 = bottom_y - rows * cell
    for r, row in enumerate(FLAME):
        for c, ch in enumerate(row):
            if ch == ".": continue
            col = PAL[ch][:3] + (alpha,)
            rect = [x0 + c * cell, y0 + r * cell, x0 + (c + 1) * cell - 1, y0 + (r + 1) * cell - 1]
            if mask is not None:
                # keep only the part inside the mask
                cxm = min(max((rect[0] + rect[2]) // 2, 0), W - 1); cym = min(max((rect[1] + rect[3]) // 2, 0), H - 1)
                if mask.getpixel((cxm, cym)) == 0: continue
            d.rectangle(rect, fill=col)

def ember_fill(img, pts, color):
    p = img.load()
    for x, y in pts: p[x, y] = color

def glow(img, center, radius, color, mask=None, blur=40):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse([center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius], fill=color)
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    if mask is not None:
        a = layer.split()[3]
        a = Image.composite(a, Image.new("L", (W, H), 0), mask)
        layer.putalpha(a)
    return Image.alpha_composite(img, layer)

def light_lens(img, key, cell=14, intensity=1.0):
    pts = lens[key]
    x0, y0, x1, y1 = bbox(pts)
    ember_fill(img, pts, (58, 12, 6, 255))
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    img = glow(img, (cx, cy), int((x1 - x0) * 0.45), (255, 110, 30, int(170 * intensity)), mask=visor_mask, blur=36)
    stamp_flame(img, cx, y1 - int((y1 - y0) * 0.12), cell)
    return img

def pixelate_edges(img):
    return img

# ── 3. states ─────────────────────────────────────────────────────────────────
idle = im.copy()
idle.save(f"{out}/face-idle.png")

half = im.copy()
half = light_lens(half, "L")
half.save(f"{out}/face-half.png")

goal = im.copy()
goal = light_lens(goal, "L")
goal = light_lens(goal, "R")
goal.save(f"{out}/face-goal.png")

# crazed: molten lenses, flames bursting past the hairline, red-hot rim, sparks, hair licks
crazed = im.copy()
for key in ("L", "R"):
    pts = lens[key]
    x0, y0, x1, y1 = bbox(pts)
    ember_fill(crazed, pts, (255, 122, 26, 255))
    crazed = glow(crazed, ((x0 + x1) // 2, (y0 + y1) // 2), int((x1 - x0) * 0.5), (255, 245, 180, 230), mask=visor_mask, blur=30)
# rim: visor pixels adjacent to non-visor → red hot
rim = set()
for x, y in visor:
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        if (x + dx, y + dy) not in visor: rim.add((x, y)); break
rim_thick = set(rim)
for x, y in list(rim):
    for dx in range(-8, 9):
        for dy in range(-8, 9):
            if (x + dx, y + dy) in visor: rim_thick.add((x + dx, y + dy))
ember_fill(crazed, rim_thick, (255, 61, 46, 255))
# big flames bursting upward out of each lens (unmasked, over the hair)
rng = random.Random(7)
for key in ("L", "R"):
    x0, y0, x1, y1 = bbox(lens[key])
    cx = (x0 + x1) // 2
    stamp_flame(crazed, cx, y1 - 10, 20)
    stamp_flame(crazed, cx - 60, y0 + 40, 12)
    stamp_flame(crazed, cx + 62, y0 + 70, 11)
# hair licks: little flames along the top silhouette
def top_of(x):
    for y in range(H):
        if px[x, y][3] > 40: return y
    return None
for x in (330, 400, 470, 540, 610, 680):
    ty = top_of(x)
    if ty is not None:
        stamp_flame(crazed, x + rng.randint(-8, 8), ty + 26, 9 + rng.randint(0, 3))
# sparks
d = ImageDraw.Draw(crazed)
for i in range(46):
    ang = rng.uniform(0, 6.283); rad = rng.uniform(280, 395)
    sx = int(W / 2 + rad * __import__("math").cos(ang)); sy = int(H * 0.42 + rad * 0.85 * __import__("math").sin(ang))
    s = rng.choice((8, 10, 12, 14))
    col = rng.choice([(255, 210, 63, 255), (255, 246, 200, 255), (255, 122, 26, 255)])
    d.rectangle([sx, sy, sx + s, sy + s], fill=col)
# warm vignette glow behind the head
crazed = glow(crazed, (W // 2, int(H * 0.5)), 330, (255, 90, 20, 90), blur=90)
crazed.save(f"{out}/face-crazed-pixel.png")
print("wrote idle/half/goal/crazed")

# ── 4. crop every state to the same square (so the face never changes size) and export @640 ──
from PIL import Image as _I
bb = _I.open(f"{out}/face-idle.png").convert("RGBA").getbbox()  # the face itself, effects may clip
cxc, cyc = (bb[0] + bb[2]) // 2, (bb[1] + bb[3]) // 2
half_side = max(bb[2] - bb[0], bb[3] - bb[1]) // 2 + 44
box = (cxc - half_side, cyc - half_side, cxc + half_side, cyc + half_side)
print("crop box", box)
for n in ("idle", "half", "goal", "crazed-pixel"):
    img = _I.open(f"{out}/face-{n}.png").convert("RGBA")
    canvas = _I.new("RGBA", (W + 2 * half_side, H + 2 * half_side), (0, 0, 0, 0))
    canvas.alpha_composite(img, (half_side, half_side))
    cropped = canvas.crop((box[0] + half_side, box[1] + half_side, box[2] + half_side, box[3] + half_side))
    cropped = cropped.resize((640, 640), _I.LANCZOS)
    cropped.save(f"{out}/face-{n}.png", optimize=True)
print("cropped + resized to 640")
