#!/bin/bash
# Build wrapper: regenerate title gfx if PNG/script source changed, then
# invoke retrotool. Pass any extra args through to retrotool (e.g. --no-cache,
# -D version=scripted, -o /path).
#
# Usage:
#   ./build.sh                      # default vwf build to out/lm3_vwf.sfc
#   ./build.sh --no-cache           # force-rebuild encoders too
#   ./build.sh -D version=scripted  # alternate flavor
set -e
cd "$(dirname "$0")"

# Title gfx — script self-skips when outputs are newer than all inputs
python3 tools/title_gfx/build_title.py

# ROM build (default args, override-able via $@)
exec .venv314/bin/retrotool build project.toml \
  -D version=vwf -j 6 \
  -o out/lm3_vwf.sfc \
  "$@"
