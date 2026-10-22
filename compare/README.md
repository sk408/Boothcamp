# Hearing Aid Compare

A separate Godot 4.7.2 project (not part of Booth Camp) that compares the hearing aids sold at Costco hearing aid
centres, for new users (Plain words) and engineers (Full specs). Design and Steve's questions:
[docs/compare/COMPARE.md](../docs/compare/COMPARE.md). Served at `<Pages address>/compare/`.

## Editing

| To change | Edit |
|---|---|
| A price | `data/prices.json` (`usd`, `checked`; `null` hides it) |
| A spec, its sources or its status | `data/aids.json` (`v`, `src`, `status`, `note`); then `meta.specs_as_of` |
| A source | `data/sources.json` (`read` = the date it was read) |
| A row, its plain words, a topic's colour, a need, Hoot's questions | `data/rows.json` |
| The drawings | `tools/make_art.py`, then run it (`python3 tools/make_art.py`) to rewrite `data/art.json`. A product drawing's outline comes from `tools/outlines.json`; re-trace one from a photo with `python3 tools/trace_photo.py <photo> <name>` (needs `opencv-python-headless`) and paste the result in. Photos are never committed. |

Statuses: `verified` = a maker's or Costco's own page says so (the tests insist on one such source);
`reported` = third-party sources only; `unverified` = nothing found (value left empty, shown as "Not verified").

## Checks (from this folder, Godot on PATH as `godot`)

| What | Command |
|---|---|
| Scripts compile and the data tests pass | `tools/check.sh` (add `--web=/abs/dir` for a web export) |
| Screenshots | `xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --rendering-driver opengl3 --resolution 1280x800 -s res://tools/shot.gd -- --out=/abs/dir` (extras: `--detail`, `--scroll=900`, `--needs=telecoil,iphone`, `--open=card:<aid id>`, `--open=viewer:<aid id>`, `--open=quiz:1`, `--open=results --answers=0,0,1,0,1`, `--text=2`, `--name=file`). For a phone: `--resolution 1170x2532` on a 1200x2600 screen with `--dpr=3` |

The game's test runners skip this folder because it holds its own `project.godot`.
