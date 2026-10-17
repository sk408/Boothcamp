#!/usr/bin/env bash
# Import (if needed) and run every unit test headless. Exit code = test result.
# Usage: tools/run_tests.sh [--filter=word] [--verbose]
set -uo pipefail
cd "$(dirname "$0")/.."
godot --headless --path . --import >/dev/null 2>&1
args=()
[[ $# -gt 0 ]] && args=(-- "$@")
timeout 600 godot --headless --path . -s res://tests/run_tests.gd "${args[@]}"
