"""Dayce app icon generator — outputs assets/icon/app_icon.png (1024x1024)"""
from PIL import Image, ImageDraw
import os, math

SIZE = 1024

def lerp_color(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))

def make_icon(size=SIZE):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # ── Gradient background ───────────────────────────────────────────────────
    top_col    = (124, 92, 252)   # #7C5CFC
    bottom_col = (74,  45, 196)   # #4A2DC4
    for y in range(size):
        t = y / (size - 1)
        col = lerp_color(top_col, bottom_col, t)
        draw.line([(0, y), (size - 1, y)], fill=col + (255,))

    # ── Rounded‑square mask (iOS squircle‑like corner) ────────────────────────
    corner_r = int(size * 0.225)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1],
                                           radius=corner_r, fill=255)
    img.putalpha(mask)

    # ── Calendar card (white) ─────────────────────────────────────────────────
    pad   = int(size * 0.16)
    cx1   = pad
    cy1   = int(pad * 1.1)
    cx2   = size - pad
    cy2   = size - int(pad * 0.85)
    cw    = cx2 - cx1
    ch    = cy2 - cy1
    cr    = int(cw * 0.11)

    draw.rounded_rectangle([cx1, cy1, cx2, cy2], radius=cr, fill=(255, 255, 255, 255))

    # ── Header bar (purple stripe at top of card) ─────────────────────────────
    hdr_h  = int(ch * 0.28)
    hdr_y2 = cy1 + hdr_h
    hdr_col = (32, 10, 96)   # deep dark purple — clearly distinct from background
    draw.rounded_rectangle([cx1, cy1, cx2, hdr_y2],
                            radius=cr, fill=hdr_col + (255,))
    draw.rectangle([cx1, cy1 + cr, cx2, hdr_y2],
                   fill=hdr_col + (255,))

    # ── Binding rings (two white donuts at top edge) ──────────────────────────
    ring_r   = int(size * 0.042)
    inner_r  = int(ring_r * 0.48)
    ring_y   = cy1
    for rx in [cx1 + cw // 3, cx1 + (cw * 2) // 3]:
        draw.ellipse([rx - ring_r,  ring_y - ring_r,
                      rx + ring_r,  ring_y + ring_r],
                     fill=(255, 255, 255, 255))
        draw.ellipse([rx - inner_r, ring_y - inner_r,
                      rx + inner_r, ring_y + inner_r],
                     fill=hdr_col + (255,))

    # ── Date dot grid (3 rows × 5 cols) ──────────────────────────────────────
    g_top   = hdr_y2 + int(ch * 0.10)
    g_bot   = cy2    - int(ch * 0.09)
    g_left  = cx1    + int(cw * 0.11)
    g_right = cx2    - int(cw * 0.11)

    rows, cols = 3, 5
    dot_r   = int(size * 0.020)

    for row in range(rows):
        for col in range(cols):
            tx = g_left  + (g_right - g_left)  * col / (cols - 1)
            ty = g_top   + (g_bot   - g_top)   * row / (rows - 1)
            x, y = int(tx), int(ty)

            # Highlighted "today" cell (row=1, col=2)
            if row == 1 and col == 2:
                hr = int(dot_r * 2.1)
                draw.ellipse([x - hr, y - hr, x + hr, y + hr],
                             fill=(245, 158, 11, 255))  # amber — stands out on both bg and card
                # white center
                wr = int(dot_r * 0.85)
                draw.ellipse([x - wr, y - wr, x + wr, y + wr],
                             fill=(255, 255, 255, 255))
            else:
                draw.ellipse([x - dot_r, y - dot_r, x + dot_r, y + dot_r],
                             fill=(200, 195, 235, 255))

    return img


if __name__ == "__main__":
    out_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")
    os.makedirs(out_dir, exist_ok=True)

    icon = make_icon()
    path = os.path.join(out_dir, "app_icon.png")
    icon.save(path, "PNG")
    print(f"Saved {path} ({SIZE}×{SIZE})")
