#!/usr/bin/env bash
# Boot ONE scene directly (its demo_start() runs if it has one) and take timed screenshots.
# Usage: tools/scene_shot.sh res://world/clinic.tscn /abs/out/dir "1,3.5" [quit_at_seconds] [-- extra user args]
set -uo pipefail
SCENE="${1:?scene}"; OUT="${2:?out dir}"; AT="${3:-1}"; QUIT="${4:-}"
shift $(( $# < 4 ? $# : 4 )); [[ "${1:-}" == "--" ]] && shift   # the rest goes to the scene
cd "$(dirname "$0")/.."
mkdir -p "$OUT"
[[ -z "$QUIT" ]] && QUIT=$(echo "$AT" | tr ',' '\n' | sort -g | tail -1 | awk '{print $1 + 0.5}')
godot --headless --path . --import >/dev/null 2>&1
timeout 300 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
  --audio-driver Dummy --fixed-fps 30 -- --scene="$SCENE" --shots="$OUT" --shot-at="$AT" --quit-at="$QUIT" "$@" 2>&1 \
  | grep -E "SHOT|SCRIPT ERROR|Parse Error"
