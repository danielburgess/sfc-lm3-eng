"""Phase 2b: corruption-probe. Copy a source ROM, XOR a byte window with a
distinctive pattern, write to a probe ROM. Boot in Mesen, screenshot, diff
against baseline to identify which screen element uses the corrupted bytes.

Usage:
    python3 tools/title_gfx/probe_corrupt.py <file_offset> <length> [--pattern 0xAA]
                                              [--src lm3.sfc] [--out out/lm3_probe.sfc]
                                              [--mark]  # write an obvious stripe instead of XOR

Default source: lm3.sfc (2MB base). Works on 4MB built ROM too if you pass --src.
XOR pattern default 0xAA (alternating bits = max visible change).
"""
import sys, argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent


def corrupt(src_path, out_path, offset, length, pattern, mark):
    data = bytearray(Path(src_path).read_bytes())
    if offset < 0 or offset + length > len(data):
        sys.exit(f"window {offset:#x}+{length:#x} out of ROM size {len(data):#x}")
    orig = bytes(data[offset:offset + length])
    if mark:
        # Obvious stripe: 0x00, 0xFF, 0x00, 0xFF... — forces visible change
        for i in range(length):
            data[offset + i] = 0xFF if (i & 1) else 0x00
    else:
        for i in range(length):
            data[offset + i] ^= pattern
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    Path(out_path).write_bytes(data)
    print(f"Corrupted {length} bytes @ file {offset:#08x} ({'mark' if mark else f'XOR {pattern:#04x}'})")
    print(f"  Original:  {' '.join(f'{b:02X}' for b in orig[:16])}{'...' if length > 16 else ''}")
    print(f"  Corrupted: {' '.join(f'{b:02X}' for b in data[offset:offset+min(16,length)])}{'...' if length > 16 else ''}")
    print(f"  Written:   {out_path}")
    # SNES addr reminder
    bank = offset // 0x8000
    addr = 0x8000 + (offset % 0x8000)
    if bank < 0x80:
        print(f"  SNES LoROM: ${bank:02X}:{addr:04X}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("offset", type=lambda x: int(x, 0), help="File offset (hex or decimal)")
    ap.add_argument("length", type=lambda x: int(x, 0), help="Number of bytes to corrupt")
    ap.add_argument("--pattern", type=lambda x: int(x, 0), default=0xAA, help="XOR pattern (default 0xAA)")
    ap.add_argument("--src", default=str(ROOT / "lm3.sfc"), help="Source ROM path")
    ap.add_argument("--out", default=str(ROOT / "out/lm3_probe.sfc"), help="Output probe ROM path")
    ap.add_argument("--mark", action="store_true", help="Write alternating 0x00/0xFF stripes instead of XOR")
    args = ap.parse_args()
    corrupt(args.src, args.out, args.offset, args.length, args.pattern, args.mark)


if __name__ == "__main__":
    main()
