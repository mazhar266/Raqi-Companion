"""Generate the app icons from icon/icon.png.

Uses Pillow rather than adding flutter_launcher_icons, keeping the dependency
list as short as it already is. Re-run after replacing the source icon.

Three shapes are produced:
  * Legacy Android mipmaps and the plain web icons — the artwork full-bleed,
    keeping its own rounded corners and transparency.
  * The Android adaptive foreground — the artwork inset so its content stays
    inside the 66% safe zone that every launcher mask is guaranteed to show,
    over a solid background of the artwork's own green.
  * The web maskable icons — the same idea against the 80% maskable safe zone.
"""
import os
from PIL import Image

SRC = 'icon/icon.png'

# Sampled from the flat area of the artwork's background, so the adaptive
# background and the artwork's own field are the same colour and the seam
# between them is invisible.
BG = (10, 52, 43, 255)
BG_HEX = '#0A342B'

# The artwork carries a faint light rim along its rounded edge; trimming a
# little before insetting keeps that rim from reading as an outline.
TRIM = 0.03

# The artwork's field is a soft gradient, so no single background colour
# matches it everywhere. Fading the inset artwork's outer edge into the
# background hides the join completely.
FEATHER = 0.10

# Fractions of the canvas the artwork is scaled to. 0.72 keeps the wordmark
# inside a circular launcher mask; maskable's safe zone is more generous.
ADAPTIVE_SCALE = 0.74
MASKABLE_SCALE = 0.78

MIPMAPS = {
    'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192,
}
# 108dp adaptive canvas at each density.
ADAPTIVE = {
    'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432,
}

src = Image.open(SRC).convert('RGBA')
w, h = src.size
trimmed = src.crop((int(w * TRIM), int(h * TRIM),
                    int(w * (1 - TRIM)), int(h * (1 - TRIM))))


def write(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, 'PNG', optimize=True)
    print(f'  {path}  {img.size[0]}x{img.size[1]}')


def full_bleed(size):
    return src.resize((size, size), Image.LANCZOS)


def feathered(img):
    """Fade the outer FEATHER fraction of the image out to transparent."""
    n = img.size[0]
    edge = max(1, round(n * FEATHER))
    mask = Image.new('L', (n, n), 255)
    px = mask.load()
    for i in range(edge):
        # smoothstep, so the falloff has no visible banding
        t = (i + 0.5) / edge
        v = round(255 * t * t * (3 - 2 * t))
        for j in range(i, n - i):
            px[i, j] = px[n - 1 - i, j] = px[j, i] = px[j, n - 1 - i] = v
    out = img.copy()
    alpha = out.getchannel('A').point(lambda a: a)
    out.putalpha(Image.composite(alpha, Image.new('L', (n, n), 0), mask))
    return out


def inset(size, scale, background):
    """The artwork centred at `scale` of a `size` canvas, edges feathered."""
    canvas = Image.new('RGBA', (size, size), background)
    art = feathered(trimmed.resize((round(size * scale),) * 2, Image.LANCZOS))
    offset = (size - art.size[0]) // 2
    canvas.alpha_composite(art, (offset, offset))
    return canvas


print('Android legacy mipmaps:')
for density, size in MIPMAPS.items():
    write(full_bleed(size), f'android/app/src/main/res/mipmap-{density}/ic_launcher.png')

print('Android adaptive foreground (background is a colour resource):')
for density, size in ADAPTIVE.items():
    write(inset(size, ADAPTIVE_SCALE, (0, 0, 0, 0)),
          f'android/app/src/main/res/mipmap-{density}/ic_launcher_foreground.png')

print('In-app (About screen):')
write(full_bleed(256), 'assets/icon/app_icon.png')

print('Web:')
write(full_bleed(32), 'web/favicon.png')
write(full_bleed(192), 'web/icons/Icon-192.png')
write(full_bleed(512), 'web/icons/Icon-512.png')
write(inset(192, MASKABLE_SCALE, BG), 'web/icons/Icon-maskable-192.png')
write(inset(512, MASKABLE_SCALE, BG), 'web/icons/Icon-maskable-512.png')

print(f'\nadaptive/maskable background colour: {BG_HEX}')
