"""Phase 2a: scan ROM for 24-bit LE pointers into graphics banks ($22-$2E),
group by source region + dedupe, flag repeating-stride clusters as candidate
pointer tables. Output to JSON + text report for docs/ROM_MAP.md.

LoROM convention:
  SNES addr $BB:OOOO -> file = (BB & 0x7F)*0x8000 + (OOOO - 0x8000)
  24-bit LE pointer bytes: [OO_lo, OO_hi, BB]

Only scans banks $22..$2E, addresses within $8000..$FFFF (valid LoROM page).
"""
import sys, json, re
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).resolve().parent.parent.parent
ROM = ROOT / "lm3.sfc"
OUT = ROOT / "en_data/gfx/raw/title"
OUT.mkdir(parents=True, exist_ok=True)

BANK_MIN = 0x22
BANK_MAX = 0x2E


def lorom_to_file(bank, addr):
    if addr < 0x8000:
        return None
    return (bank & 0x7F) * 0x8000 + (addr - 0x8000)


def find_pointers(rom):
    """Scan every byte position for a valid 24-bit LE pointer into $22-$2E:$8000-$FFFF."""
    hits = []
    n = len(rom)
    for i in range(n - 3):
        bank = rom[i + 2]
        if bank < BANK_MIN or bank > BANK_MAX:
            continue
        addr = rom[i] | (rom[i + 1] << 8)
        if addr < 0x8000:
            continue
        target = lorom_to_file(bank, addr)
        if target is None or target >= n:
            continue
        hits.append({
            "src_file": i,
            "bank": bank,
            "addr": addr,
            "target_file": target,
        })
    return hits


def cluster_stride(hits, stride, min_len=3, tol=0):
    """Group hits that form arithmetic progressions with given stride.
    Returns list of dicts {start_file, stride, count, targets}."""
    src_set = {h["src_file"]: h for h in hits}
    clusters = []
    used = set()
    # Walk sources in order; for each start, greedily extend
    ordered = sorted(src_set)
    for i, s in enumerate(ordered):
        if s in used:
            continue
        chain = [s]
        while True:
            nxt = chain[-1] + stride
            if nxt in src_set:
                chain.append(nxt)
            else:
                break
        if len(chain) >= min_len:
            for c in chain:
                used.add(c)
            clusters.append({
                "start_file": chain[0],
                "stride": stride,
                "count": len(chain),
                "end_file": chain[-1] + 3,
                "targets": [src_set[c] for c in chain],
            })
    return clusters


def main():
    rom = ROM.read_bytes()
    print(f"ROM size: {len(rom):#x} ({len(rom)} bytes)")

    print("Scanning for 24-bit LE pointers to banks $22-$2E:$8000-$FFFF...")
    hits = find_pointers(rom)
    print(f"  {len(hits)} raw pointer hits")

    # Cluster by common strides. 3/4/6/8 are the typical pointer-table strides.
    # Stride 3 = pure 3-byte ptr table. 4/6/8 = compound records (id+size+ptr).
    all_clusters = []
    for stride in (3, 4, 6, 8):
        c = cluster_stride(hits, stride, min_len=3)
        for cl in c:
            cl["stride_label"] = f"stride={stride}"
        all_clusters.extend(c)

    # Sort clusters by start_file
    all_clusters.sort(key=lambda c: (c["start_file"], -c["count"]))

    # Drop sub-clusters fully contained in a larger one with smaller stride
    def contains(outer, inner):
        return (outer["start_file"] <= inner["start_file"]
                and outer["end_file"] >= inner["end_file"]
                and outer != inner)

    # Keep only largest-extent clusters when they overlap
    keep = []
    for c in all_clusters:
        # Drop if any prior kept cluster contains this one entirely
        if any(contains(k, c) for k in keep):
            continue
        # Remove any previously kept cluster that's contained in c
        keep = [k for k in keep if not contains(c, k)]
        keep.append(c)

    print(f"  {len(keep)} candidate pointer-table clusters (stride 3-8, len >= 3)")

    # Sniff-classify each cluster's targets (look at first 16 bytes)
    def sniff(target_file):
        """Rough content classification of a target region."""
        chunk = rom[target_file:target_file + 64]
        if not chunk:
            return "eof"
        if all(b == 0 for b in chunk):
            return "zero-padding"
        if all(b == 0xFF for b in chunk):
            return "ff-padding"
        # Bitplane-pair signature: rows alternate byte/byte with low entropy
        b0 = chunk[:16]
        if len(set(b0)) <= 4 and 0x00 in b0:
            # looks like a tile chunk
            return "tile.likely-Nbpp"
        # High-bit-flag stream (compression marker)
        if sum(1 for b in chunk[:32] if b & 0x80) >= 20:
            return "compressed.likely"
        # ASCII-ish
        printable = sum(1 for b in chunk if 0x20 <= b <= 0x7E)
        if printable >= 48:
            return "ascii-ish"
        # Else
        return "unknown"

    # Build report
    report = []
    for c in keep:
        first = c["targets"][0]
        last = c["targets"][-1]
        start_snes = f"${first['bank']:02X}:{first['addr']:04X}"
        c_out = {
            "table_src_file": c["start_file"],
            "stride": c["stride"],
            "count": c["count"],
            "table_end_file": c["end_file"],
            "first_target_file": first["target_file"],
            "first_target_snes": start_snes,
            "first_target_sniff": sniff(first["target_file"]),
            "last_target_file": last["target_file"],
            "slot_classifications": [sniff(t["target_file"]) for t in c["targets"]],
            "bank_distribution": {},
        }
        banks = defaultdict(int)
        for t in c["targets"]:
            banks[t["bank"]] += 1
        c_out["bank_distribution"] = {f"${b:02X}": n for b, n in sorted(banks.items())}
        report.append(c_out)

    # Write outputs
    (OUT / "pointer_scan.json").write_text(json.dumps(report, indent=2))
    print(f"\nWrote {OUT / 'pointer_scan.json'}")

    # Print top-level summary
    print("\n=== Candidate pointer-table clusters ===")
    for c in report[:30]:
        print(f"  file {c['table_src_file']:06X}  stride={c['stride']}  n={c['count']:3d}  "
              f"first->{c['first_target_snes']} ({c['first_target_sniff']})  "
              f"banks={list(c['bank_distribution'].keys())}")
    if len(report) > 30:
        print(f"  ... and {len(report) - 30} more")

    # Also dump raw pointer-hit histogram by target bank
    print("\n=== Raw pointer hits by target bank ===")
    bank_hist = defaultdict(int)
    for h in hits:
        bank_hist[h["bank"]] += 1
    for b in sorted(bank_hist):
        print(f"  ${b:02X}: {bank_hist[b]:5d} hits")


if __name__ == "__main__":
    main()
