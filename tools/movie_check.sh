#!/usr/bin/env bash
# Audio-safety movie check: records both ears of air conduction with Movie Maker (MJPEG AVI + PCM),
# then analyses the audio per tone: routing (test ear only), level vs AudioSafety, -12 dBFS ceiling.
# Usage: tools/movie_check.sh /abs/out/dir [--speed=6]     (~5 min on llvmpipe, ~500 MB AVI)
set -uo pipefail
OUT="${1:?usage: tools/movie_check.sh /abs/out/dir}"; shift || true
cd "$(dirname "$0")/.."
mkdir -p "$OUT"
godot --headless --path . --import >/dev/null 2>&1
timeout 1500 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
  --fixed-fps 30 --write-movie "$OUT/ac.avi" -- --scene=res://tools/movie_ac.tscn --autoplay --speed=6 "$@" \
  > "$OUT/run.log" 2>&1
ffmpeg -loglevel error -y -i "$OUT/ac.avi" -vn -c:a pcm_s16le "$OUT/ac.wav"
python3 -I tools/analyze_movie_audio.py "$OUT/ac.wav" "$OUT/run.log"
