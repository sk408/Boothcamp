#!/usr/bin/env bash
# Headless end-to-end check: the bot plays the whole level (no rendering, ~2-5 s).
# Exit code: 0 ok, 2 stalled, 3 timeout, 4 bad results, 5 script errors (see autoplay_bot.gd).
# Usage: tools/autoplay_check.sh [--seed=N] [--speed=6] [--affinity] [--day=2] [--mouse]
set -uo pipefail
cd "$(dirname "$0")/.."
godot --headless --path . --import >/dev/null 2>&1
timeout 600 godot --headless --path . --fixed-fps 30 -- --autoplay --speed=6 "$@" 2>&1 | grep -E "BOT phase|AUTOPLAY_|SCRIPT ERROR|Parse Error"
exit "${PIPESTATUS[0]}"
