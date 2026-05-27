#!/usr/bin/env python3
import argparse
import json
import time

import mesen_ipc

LOG_PATH = "/mnt/crucial/projects/sfc-lm3-eng/.cursor/debug-7ef0da.log"
SESSION_ID = "7ef0da"
WRAM_7F_BASE = 0x10000


def _u8(buf, off):
    return buf[off]


def _u16(buf, off):
    return buf[off] | (buf[off + 1] << 8)


def _emit(run_id, hypothesis_id, message, data):
    payload = {
        "sessionId": SESSION_ID,
        "runId": run_id,
        "hypothesisId": hypothesis_id,
        "location": "tools/debug_vwf_probe.py",
        "message": message,
        "data": data,
        "timestamp": int(time.time() * 1000),
    }
    # #region agent log
    with open(LOG_PATH, "a", encoding="utf-8") as f:
        f.write(json.dumps(payload, separators=(",", ":")) + "\n")
    # #endregion


def capture(run_id="run1", seconds=15.0, poll_ms=600):
    sock = mesen_ipc.connect()
    last = None
    start = time.time()
    while time.time() - start < seconds:
        base = 0x5D60
        raw = mesen_ipc.read_wram(sock, WRAM_7F_BASE + base, 0x12) or ([0] * 0x12)
        snap = {
            "pre_row": _u16(raw, 0x00),
            "pre_col": _u16(raw, 0x02),
            "scene70": _u8(raw, 0x04),
            "nmi_path": _u8(raw, 0x05),
            "a1e": _u16(raw, 0x06),
            "dirty": _u8(raw, 0x08),
            "invert": _u8(raw, 0x09),
            "dma_lo": _u16(raw, 0x0A),
            "dma_hi": _u16(raw, 0x0C),
            "bmp_count": _u16(raw, 0x0E),
            "bmp_last": _u8(raw, 0x10),
            "nmi_stage": _u8(raw, 0x11),
        }
        if snap != last:
            hyp = "H2" if snap["nmi_path"] == 1 else "H3" if snap["nmi_path"] == 2 else "H1"
            _emit(run_id, hyp, "vwf_probe_snapshot", snap)
            last = snap
        time.sleep(poll_ms / 1000.0)
    _emit(run_id, "H0", "vwf_probe_complete", {"seconds": seconds})


if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Low-impact VWF debug probe")
    p.add_argument("--run-id", default="run1")
    p.add_argument("--seconds", type=float, default=15.0)
    p.add_argument("--poll-ms", type=int, default=600)
    args = p.parse_args()
    capture(run_id=args.run_id, seconds=args.seconds, poll_ms=args.poll_ms)
