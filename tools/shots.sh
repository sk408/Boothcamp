#!/usr/bin/env bash
# Rendered autoplay under Xvfb: plays the whole level and saves PNGs at key moments.
# Usage: tools/shots.sh /abs/out/dir [extra user args, e.g. --seed=7 --affinity]
# Takes ~5 minutes on llvmpipe (4 CPUs); Day 2 (--day=2) ~13 minutes. Never run two Godot instances on the same project dir.
set -uo pipefail
OUT="${1:?usage: tools/shots.sh /abs/out/dir [args]}"; shift || true
cd "$(dirname "$0")/.."
mkdir -p "$OUT"
godot --headless --path . --import >/dev/null 2>&1
timeout 1800 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
  --audio-driver Dummy --fixed-fps 30 -- --autoplay --speed=6 --shots="$OUT" "$@" > "$OUT/run.log" 2>&1
code=$?
grep -E "AUTOPLAY_|SCRIPT ERROR" "$OUT/run.log"
ls "$OUT"/*.png 2>/dev/null | wc -l | xargs echo "screenshots:"
exit $code
