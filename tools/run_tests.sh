#!/usr/bin/env bash
# Import (if needed) and run every unit test headless, then check that docs/CASE_SCRIPTS.md matches
# the case JSON. Exit code = 0 only when both pass.
# Usage: tools/run_tests.sh [--filter=word] [--verbose]
set -uo pipefail
cd "$(dirname "$0")/.."
godot --headless --path . --import >/dev/null 2>&1
args=()
[[ $# -gt 0 ]] && args=(-- "$@")
timeout 600 godot --headless --path . -s res://tests/run_tests.gd "${args[@]}"
status=$?
python3 tools/case_scripts.py --check || status=1
exit $status
