"""SNES 8BPP plane-pair tile codec.

8BPP tile = 64 bytes = 4 plane-pairs * 16 bytes. Each plane-pair = 8 rows * 2 bytes:
  byte[0] = plane-N bits (MSB = leftmost pixel)
  byte[1] = plane-(N+1) bits

Pixel value p (0..255) for (x,y) in tile:
  pp0 = pair 0 (planes 0-1), pp1 = pair 1 (planes 2-3), pp2 = pair 2 (4-5), pp3 = pair 3 (6-7)
  p = ((bit(pp3[y*2+1], 7-x) << 7) | (bit(pp3[y*2+0], 7-x) << 6) |
       (bit(pp2[y*2+1], 7-x) << 5) | (bit(pp2[y*2+0], 7-x) << 4) |
       (bit(pp1[y*2+1], 7-x) << 3) | (bit(pp1[y*2+0], 7-x) << 2) |
       (bit(pp0[y*2+1], 7-x) << 1) | (bit(pp0[y*2+0], 7-x) << 0))
"""
from __future__ import annotations


def decode_tile_8bpp(tile64: bytes) -> list[list[int]]:
    """Return 8x8 pixel grid [y][x] = palette index (0..255)."""
    assert len(tile64) == 64
    grid = [[0] * 8 for _ in range(8)]
    for y in range(8):
        b0 = tile64[y * 2 + 0]
        b1 = tile64[y * 2 + 1]
        b2 = tile64[16 + y * 2 + 0]
        b3 = tile64[16 + y * 2 + 1]
        b4 = tile64[32 + y * 2 + 0]
        b5 = tile64[32 + y * 2 + 1]
        b6 = tile64[48 + y * 2 + 0]
        b7 = tile64[48 + y * 2 + 1]
        for x in range(8):
            m = 1 << (7 - x)
            p = (
                ((b0 & m) != 0) << 0
                | ((b1 & m) != 0) << 1
                | ((b2 & m) != 0) << 2
                | ((b3 & m) != 0) << 3
                | ((b4 & m) != 0) << 4
                | ((b5 & m) != 0) << 5
                | ((b6 & m) != 0) << 6
                | ((b7 & m) != 0) << 7
            )
            grid[y][x] = p
    return grid


def encode_tile_8bpp(grid: list[list[int]]) -> bytes:
    """Inverse of decode_tile_8bpp. grid[y][x] in 0..255."""
    out = bytearray(64)
    for y in range(8):
        b = [0] * 8
        for x in range(8):
            p = grid[y][x] & 0xFF
            m = 1 << (7 - x)
            for plane in range(8):
                if p & (1 << plane):
                    b[plane] |= m
        out[y * 2 + 0] = b[0]
        out[y * 2 + 1] = b[1]
        out[16 + y * 2 + 0] = b[2]
        out[16 + y * 2 + 1] = b[3]
        out[32 + y * 2 + 0] = b[4]
        out[32 + y * 2 + 1] = b[5]
        out[48 + y * 2 + 0] = b[6]
        out[48 + y * 2 + 1] = b[7]
    return bytes(out)


def decode_vram_to_indexed(vram: bytes, tile_count: int | None = None) -> list[list[list[int]]]:
    """Decode N 8BPP tiles from VRAM. Returns list of 8x8 grids."""
    if tile_count is None:
        tile_count = len(vram) // 64
    return [decode_tile_8bpp(vram[i * 64 : (i + 1) * 64]) for i in range(tile_count)]


def encode_indexed_to_vram(tiles: list[list[list[int]]]) -> bytes:
    """Inverse: pack N 8x8 grids into 64N VRAM bytes."""
    out = bytearray()
    for t in tiles:
        out += encode_tile_8bpp(t)
    return bytes(out)


if __name__ == '__main__':
    vram = open('/mnt/crucial/projects/sfc-lm3-eng/en_data/gfx/raw/title/vram_live.bin', 'rb').read()[: 7 * 8192]
    tiles = decode_vram_to_indexed(vram)
    re_encoded = encode_indexed_to_vram(tiles)
    matches = sum(1 for a, b in zip(re_encoded, vram) if a == b)
    print(f'Tiles: {len(tiles)}')
    print(f'VRAM:  {len(vram)} B')
    print(f'Match: {matches}/{len(vram)} = {100*matches/len(vram):.2f}%')
    assert re_encoded == vram, 'tile codec round-trip broken'
    print('✓ tile codec round-trip OK')
