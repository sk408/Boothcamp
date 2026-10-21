#!/usr/bin/env bash
# Export the Windows build: build/BoothCamp.exe (PCK embedded), plus a zip for delivery
# (exe + README + font licence + the career-fair demo launcher, docs/DEMO.md) and optionally an .xz of the exe.
# Usage: tools/export_win.sh [--xz]
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . --export-release "Windows Desktop" build/BoothCamp.exe
file build/BoothCamp.exe || true
ls -la build/BoothCamp.exe
# delivery zip: the game is the one exe; the README says how to get past SmartScreen
STAGE="$(mktemp -d)"
cp build/BoothCamp.exe "$STAGE/"
cp README.md "$STAGE/README.md"
cp assets/fonts/OFL-Fredoka.txt "$STAGE/OFL-Fredoka.txt"
cp tools/booth/BoothCamp-Demo.cmd "$STAGE/BoothCamp-Demo.cmd"
rm -f build/BoothCamp-win64.zip
(cd "$STAGE" && zip -q -9 "$OLDPWD/build/BoothCamp-win64.zip" BoothCamp.exe README.md OFL-Fredoka.txt BoothCamp-Demo.cmd)
rm -rf "$STAGE"
ls -la build/BoothCamp-win64.zip
if [[ "${1:-}" == "--xz" ]]; then
  xz -9e -T2 -k -f build/BoothCamp.exe
  ls -la build/BoothCamp.exe.xz
fi
