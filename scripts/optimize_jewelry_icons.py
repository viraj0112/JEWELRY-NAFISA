"""
One-off asset optimizer: the files in "Jewellery icon" are large (~197KB,
1350px) base64-PNG-embedded-in-SVG files. This extracts the embedded PNG from
each and downscales it to a small transparent PNG suitable for a chip icon.

Run once:  python scripts/optimize_jewelry_icons.py
Output:    assets/jewelry_icons/*.png  (small, ~64px)
"""
import base64
import io
import re
import pathlib

from PIL import Image

SRC_DIR = pathlib.Path("Jewellery icon")
OUT_DIR = pathlib.Path("assets/jewelry_icons")
TARGET = 64  # px, retina-friendly for an 18-24px display size
GOLD = (197, 148, 62)  # icon tint; source art is white strokes on black

OUT_DIR.mkdir(parents=True, exist_ok=True)

# Only the product-type icons the UI actually uses (skip the composite sheet).
WANTED = {
    "Ring", "Bangle", "Bracelet", "Earrings", "Necklace set", "Pendant",
    "Accessories", "Chain", "Anklet", "Armlet", "Nose Ring", "Toe Ring",
    "Waist Band", "Watch", "Pendant set", "Full set", "Bracelet & Ring",
}

data_uri = re.compile(r"data:image/(png|jpeg|jpg);base64,([A-Za-z0-9+/=]+)")

count = 0
for svg in sorted(SRC_DIR.glob("*.svg")):
    stem = svg.stem
    if stem not in WANTED:
        continue
    text = svg.read_text(encoding="utf-8", errors="ignore")
    m = data_uri.search(text)
    if not m:
        print(f"  SKIP {stem}: no embedded raster found")
        continue
    raw = base64.b64decode(m.group(2))
    img = Image.open(io.BytesIO(raw)).convert("RGBA")
    # Downscale preserving aspect ratio into a TARGET x TARGET box.
    img.thumbnail((TARGET, TARGET), Image.LANCZOS)
    # The source art is white strokes on an opaque black background. Use each
    # pixel's brightness as alpha and paint the strokes gold, yielding a
    # transparent-background icon that works on any chip color.
    lum = img.convert("L")
    img = Image.new("RGBA", img.size, GOLD + (0,))
    img.putalpha(lum)
    out = OUT_DIR / f"{stem}.png"
    img.save(out, "PNG", optimize=True)
    print(f"  {stem}.png  {out.stat().st_size // 1024}KB  {img.size}")
    count += 1

print(f"Done: {count} icons written to {OUT_DIR}")
