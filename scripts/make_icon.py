#!/usr/bin/env python3
"""Generate the application icon.

A dark monitor showing a remote desktop: a screen with a small grid of
windows and a cursor, drawn in the muted blue/grey palette the app uses.
Rendered at every size macOS asks for and packed into an .icns.
"""

import struct
import sys
import pathlib

from PIL import Image, ImageDraw

SIZES = [16, 32, 64, 128, 256, 512, 1024]

BG_TOP = (38, 48, 66)
BG_BOTTOM = (20, 26, 38)
SCREEN = (58, 138, 190)
SCREEN_DARK = (40, 96, 134)
WINDOW = (226, 232, 240)
ACCENT = (255, 196, 92)
BORDER = (14, 18, 26)


def rounded(draw, box, radius, fill):
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def render(size):
    """Draw the icon at the given pixel size."""
    s = size
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Rounded background with a vertical gradient.
    grad = Image.new("RGBA", (s, s))
    gd = ImageDraw.Draw(grad)
    for y in range(s):
        t = y / max(s - 1, 1)
        col = tuple(int(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t) for i in range(3))
        gd.line([(0, y), (s, y)], fill=col + (255,))
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 0.22), fill=255)
    img.paste(grad, (0, 0), mask)
    d = ImageDraw.Draw(img)

    # Monitor body.
    m = int(s * 0.13)
    screen_box = [m, int(s * 0.18), s - m, int(s * 0.68)]
    rounded(d, screen_box, radius=int(s * 0.06), fill=BORDER)
    inner = [screen_box[0] + int(s * 0.025), screen_box[1] + int(s * 0.025),
             screen_box[2] - int(s * 0.025), screen_box[3] - int(s * 0.025)]
    rounded(d, inner, radius=int(s * 0.04), fill=SCREEN)

    # Remote desktop: a title bar and two windows with their own title bars.
    ix0, iy0, ix1, iy1 = inner
    iw, ih = ix1 - ix0, iy1 - iy0
    bar = int(ih * 0.16)
    d.rectangle([ix0, iy0, ix1, iy0 + bar], fill=SCREEN_DARK)
    # Window controls on the desktop's own menu bar.
    ctrl = int(bar * 0.34)
    cy = iy0 + (bar - ctrl) // 2
    for i, col in enumerate(((228, 96, 92), (226, 178, 84), (108, 192, 112))):
        cx = ix0 + int(iw * 0.04) + i * int(ctrl * 1.5)
        d.ellipse([cx, cy, cx + ctrl, cy + ctrl], fill=col)

    wy0 = iy0 + bar + int(ih * 0.10)
    gap = int(iw * 0.06)
    win_h = int((iy1 - wy0) * 0.62)

    # Left window.
    lx0 = ix0 + int(iw * 0.06)
    lx1 = lx0 + int(iw * 0.40)
    d.rectangle([lx0, wy0, lx1, wy0 + win_h], fill=WINDOW)
    d.rectangle([lx0, wy0, lx1, wy0 + int(win_h * 0.20)], fill=(86, 106, 138))

    # Right window, offset down, clearly a different shade.
    rx0 = lx1 + gap
    rx1 = rx0 + int(iw * 0.30)
    ry0 = wy0 + int(win_h * 0.22)
    d.rectangle([rx0, ry0, rx1, ry0 + win_h], fill=(168, 216, 240))
    d.rectangle([rx0, ry0, rx1, ry0 + int(win_h * 0.20)], fill=(48, 100, 140))

    # Cursor arrow.
    cx = rx0 + int(iw * 0.04)
    cy = ry0 + int(win_h * 0.72)
    cw = max(int(s * 0.085), 2)
    d.polygon([(cx, cy), (cx, cy + cw), (cx + cw * 0.42, cy + cw * 0.72),
               (cx + cw * 0.30, cy + cw * 1.45), (cx + cw * 0.55, cy + cw * 1.6),
               (cx + cw * 0.68, cy + cw * 0.88), (cx + cw * 1.05, cy + cw * 0.88)],
              fill=ACCENT, outline=BORDER)

    # Stand: lighter than the background so it does not disappear.
    neck = int(s * 0.045)
    d.rectangle([s // 2 - neck, screen_box[3] - int(s * 0.02),
                 s // 2 + neck, int(s * 0.82)], fill=(84, 100, 126))
    rounded(d, [s // 2 - int(s * 0.16), int(s * 0.81), s // 2 + int(s * 0.16), int(s * 0.87)],
            radius=int(s * 0.02), fill=(84, 100, 126))

    return img


def build_icns(images, path):
    """Pack PNG images into an .icns container."""
    types = {16: b"icp4", 32: b"icp5", 64: b"icp6", 128: b"ic07",
             256: b"ic08", 512: b"ic09", 1024: b"ic10"}

    entries = []
    for size, data in images:
        t = types[size]
        entries.append(t + struct.pack(">I", len(data)) + data)

    header = b"icns" + struct.pack(">I", 8 + sum(len(e) for e in entries))
    with open(path, "wb") as fh:
        fh.write(header)
        for e in entries:
            fh.write(e)


def main():
    out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "icon.icns")
    rendered = []
    for size in SIZES:
        img = render(size)
        rendered.append((size, img))
        # Keep a PNG copy for inspection.
        img.save("/tmp/icon_%d.png" % size)

    import io
    packed = []
    for size, img in rendered:
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        packed.append((size, buf.getvalue()))

    build_icns(packed, out)
    print("wrote %s (%d bytes, %d sizes)" % (out, out.stat().st_size, len(SIZES)))


if __name__ == "__main__":
    main()
