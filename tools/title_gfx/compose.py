"""PNG -> VRAM bytes composer for the LM3 title screen.

Layout: 32 columns x 28 rows = 896 tiles of 8x8 pixels = 256x224 indexed PNG.
Tile id = row*32 + col (linear). Tile 0 = top-left.

Usage:
  from compose import png_to_vram
  vram = png_to_vram('/path/to/title_256x224_indexed.png')  # 57344 B

Input PNG must be 256x224 in palette (mode='P') form, or an RGB/RGBA image that
exactly matches the live palette (mapped via cgram_live.bin).
"""
from __future__ import annotations
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
from tile_codec import encode_indexed_to_vram


WIDTH_TILES = 32
HEIGHT_TILES = 28
TILE_COUNT = WIDTH_TILES * HEIGHT_TILES  # 896


def _cgram_to_rgb555(cgram: bytes) -> list[tuple[int, int, int]]:
    """Convert 512 B CGRAM (BGR555) -> 256 RGB888 tuples."""
    colors = []
    for i in range(256):
        w = cgram[i * 2] | (cgram[i * 2 + 1] << 8)
        r = (w & 0x1F) << 3
        g = ((w >> 5) & 0x1F) << 3
        b = ((w >> 10) & 0x1F) << 3
        colors.append((r, g, b))
    return colors


def png_to_indexed_grid(png_path: str, cgram_path: str | None = None) -> list[list[list[int]]]:
    """Load a 256x224 image and return a list of 896 tile grids (8x8 palette indices).

    If the image is already indexed (mode='P'), uses its raw palette indices.
    Otherwise (RGB/RGBA), maps each pixel to the nearest color in cgram_live.bin.
    """
    img = Image.open(png_path)
    if img.size != (WIDTH_TILES * 8, HEIGHT_TILES * 8):
        raise ValueError(
            f'{png_path}: expected {WIDTH_TILES*8}x{HEIGHT_TILES*8}, got {img.size}'
        )

    if img.mode == 'P':
        px = img.load()
        pixels = [[px[x, y] for x in range(img.width)] for y in range(img.height)]
    else:
        if cgram_path is None:
            raise ValueError(f'{png_path}: non-indexed image requires cgram_path for color mapping')
        cgram = open(cgram_path, 'rb').read()[:512]
        palette = _cgram_to_rgb555(cgram)
        img_rgb = img.convert('RGB')
        px = img_rgb.load()
        lut: dict[tuple[int, int, int], int] = {}
        pixels = [[0] * img_rgb.width for _ in range(img_rgb.height)]
        for y in range(img_rgb.height):
            for x in range(img_rgb.width):
                rgb = px[x, y]
                if rgb in lut:
                    pixels[y][x] = lut[rgb]
                else:
                    best_i, best_d = 0, 1 << 30
                    for i, c in enumerate(palette):
                        d = (rgb[0] - c[0]) ** 2 + (rgb[1] - c[1]) ** 2 + (rgb[2] - c[2]) ** 2
                        if d < best_d:
                            best_d, best_i = d, i
                    lut[rgb] = best_i
                    pixels[y][x] = best_i

    tiles = []
    for ty in range(HEIGHT_TILES):
        for tx in range(WIDTH_TILES):
            grid = [
                [pixels[ty * 8 + y][tx * 8 + x] for x in range(8)]
                for y in range(8)
            ]
            tiles.append(grid)
    return tiles


def png_to_vram(png_path: str, cgram_path: str | None = None) -> bytes:
    """Top-level: PNG -> 57344 B VRAM."""
    tiles = png_to_indexed_grid(png_path, cgram_path)
    return encode_indexed_to_vram(tiles)


def vram_to_png(vram: bytes, png_path: str, cgram_path: str) -> None:
    """Debug inverse: VRAM -> indexed PNG with CGRAM palette embedded."""
    from tile_codec import decode_vram_to_indexed
    tiles = decode_vram_to_indexed(vram, TILE_COUNT)
    img = Image.new('P', (WIDTH_TILES * 8, HEIGHT_TILES * 8))
    cgram = open(cgram_path, 'rb').read()[:512]
    palette = _cgram_to_rgb555(cgram)
    flat = []
    for rgb in palette:
        flat += list(rgb)
    img.putpalette(flat)
    px = img.load()
    for ti, t in enumerate(tiles):
        tx = ti % WIDTH_TILES
        ty = ti // WIDTH_TILES
        for y in range(8):
            for x in range(8):
                px[tx * 8 + x, ty * 8 + y] = t[y][x]
    img.save(png_path)


if __name__ == '__main__':
    vram_path = '/mnt/crucial/projects/sfc-lm3-eng/en_data/gfx/raw/title/vram_live.bin'
    cgram_path = '/mnt/crucial/projects/sfc-lm3-eng/en_data/gfx/raw/title/cgram_live.bin'
    out_png = '/tmp/title_roundtrip.png'
    out_bin = '/tmp/title_roundtrip.bin'

    live_vram = open(vram_path, 'rb').read()[: 7 * 8192]
    vram_to_png(live_vram, out_png, cgram_path)
    print(f'wrote {out_png}')

    re_vram = png_to_vram(out_png)
    open(out_bin, 'wb').write(re_vram)
    matches = sum(1 for a, b in zip(re_vram, live_vram) if a == b)
    print(f'png -> vram re-encode: {matches}/{len(live_vram)} = {100*matches/len(live_vram):.2f}%')
    assert re_vram == live_vram, 'compose round-trip broken'
    print('✓ compose round-trip OK')
