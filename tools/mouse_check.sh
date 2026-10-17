#!/usr/bin/env bash
# Headless mouse-only playthrough: the bot plays the whole level with real mouse clicks and drags
# (no keys, no solvers), then clicks "Back to the title". Exit 6 = a mouse target was missing.
# Usage: tools/mouse_check.sh [--seed=N]
set -uo pipefail
cd "$(dirname "$0")/.."
godot --headless --path . --import >/dev/null 2>&1
timeout 600 godot --headless --path . --fixed-fps 30 -- --autoplay --speed=6 --mouse "$@" 2>&1 | grep -E "BOT phase|AUTOPLAY_|SCRIPT ERROR|Parse Error"
exit "${PIPESTATUS[0]}"
