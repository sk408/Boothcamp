#!/usr/bin/env bash
# Hearing Aid Compare checks: every script compiles, the data tests pass. Optional: --web=/abs/dir exports the web
# build there. Run from anywhere; Godot 4.7.2 on PATH as `godot` (or set GODOT).
set -euo pipefail
cd "$(dirname "$0")/.."
G="${GODOT:-godot}"
timeout 120 "$G" --headless --path . --import >/dev/null 2>&1 || true
for f in scripts/*.gd tools/shot.gd tests/*.gd; do
	out=$(timeout 60 "$G" --headless --path . --check-only -s "$f" 2>&1 || true)
	if echo "$out" | grep -q "ERROR"; then echo "$out"; echo "COMPILE FAIL $f"; exit 1; fi
done
timeout 60 "$G" --headless --path . -s res://tests/test_data.gd
for a in "$@"; do
	case "$a" in
		--web=*) d="${a#--web=}"; mkdir -p "$d"; timeout 300 "$G" --headless --path . --export-release "Web" "$d/index.html"; test -f "$d/index.pck" ;;
	esac
done
