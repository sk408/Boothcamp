# Booth Camp tools and commands

Run every command from the project root (`/home/claude/boothcamp`). Godot 4.7.2 is assumed to be on PATH as `godot`.

**The machine is shared.**
- It has only 4 CPUs.
- Never run two Godot processes on this project directory at the same time. They fight over `.godot/`.
- Always use a timeout or a self-quitting mode. Every script below already does.

## Everyday commands

| What | Command | Time |
|---|---|---|
| Import assets (after adding or changing files) | `godot --headless --path . --import` | ~5 s |
| Unit tests (exit 0 = green, 1 = failures, 2 = none found) | `tools/run_tests.sh` | ~5 s |
| ...the same without the wrapper | `godot --headless --path . -s res://tests/run_tests.gd` | |
| ...only some tests | `tools/run_tests.sh --filter=hoot --verbose` | |
| Headless end-to-end autoplay (the bot plays the whole level) | `tools/autoplay_check.sh` | ~5 s |
| ...with another seed, or the swapped key style | `tools/autoplay_check.sh --seed=7 --affinity` | |
| Headless mouse-only playthrough (real clicks and drags only, ends back on the title) | `tools/mouse_check.sh` | ~10 s |
| **(v3)** Day 2 (Bonnie: bone, masking, referral), keys or mouse only | `tools/autoplay_check.sh --day=2` / `tools/autoplay_check.sh --day=2 --mouse` | ~25 s |
| Rendered autoplay with screenshots at every phase | `tools/shots.sh /abs/out/dir` (Day 2: add `--day=2`) | ~5 min (Day 2 ~13 min) |
| Button-mashing stress test of the AudiOtron (both ears, Hoot's x8 turn, pause menu); prints `MONKEY_RESULT` | `timeout 900 godot --headless --path . --fixed-fps 30 -- --scene=res://tools/monkey.tscn --speed=3 --seed=1` (Day 2's five tests and the masking keys: add `--day=2`) | ~10 s (Day 2 ~20 s) |
| **(v3)** Day 2 set pieces without playing (bone placement with a wrong spot, the oscillator on Bonnie, the board's reveal, bridge and stamp on made-up results) | `tools/scene_shot.sh res://story/dev_day2.tscn /abs/out/dir "60" 30` (the scene takes its own shots) | ~2 min |
| Play the full visit without Hoot's quick-visit turn (or force it with `--quick`) | add `--full` after `--` | |
| **(polish)** Own shop items for the run (Day 2 with insert earphones: no masked air needed, the level skips it) | `tools/autoplay_check.sh --day=2 --upgrades=insert_earphones` | ~25 s |
| Boot one scene and take timed screenshots | `tools/scene_shot.sh res://world/clinic.tscn /abs/out/dir "1,3.5"` | ~20 s |
| Windows build: `build/BoothCamp.exe` with the PCK embedded, plus `build/BoothCamp-win64.zip` (exe, README, font licence) | `tools/export_win.sh` (add `--xz` for an .xz too) | ~1 min |
| Audio-safety movie: record both ears (Movie Maker AVI) and check routing, levels and the -12 dBFS ceiling per tone | `tools/movie_check.sh /abs/out/dir` | ~5 min |
| **(v3)** Day 2 audio-safety movie: Bonnie's air, bone, masked bone and masked air with UI sounds muted; `tools/analyze_movie_bc.py` checks tone channel and level, the bone cross-feed (-10 dB) and the masker (other ear only, level, -24 dBFS cap); prints `AUDIO_CHECK PASS` | `tools/movie_check.sh /abs/out/dir --day=2` | ~20 min |
| **(v3)** AudiOtron Day 2 teaching states (bone route, Ghost, masking deck, plateau, overmasking, finished audiogram) | `timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 30 -- --scene=res://ui/dev/dev_audiotron_day2.tscn --shots=/abs/dir --fresh` (add `--resolution 1920x1080` before `--` and a 1920x1080 xvfb screen for full HD) | ~3 min |
| **(v3)** Chapter select by real input: fresh save (Day 2 locked and refused), then Day 2 after Day 1 on the same save | `tools/autoplay_check.sh --save=/abs/s.json --via-days --expect-days=gus --try-locked=bonnie` then `tools/autoplay_check.sh --save=/abs/s.json --keep-save --via-days --mouse --expect-days=gus,bonnie --pick=bonnie` (or `--toggle-unlock` on a fresh save) | ~30 s |

The scripts expand to the commands below, if you need to tweak them:

```bash
# headless autoplay (no rendering; screenshots are skipped)
timeout 600 godot --headless --path . --fixed-fps 30 -- --autoplay --speed=6

# rendered autoplay under a virtual display (llvmpipe)
timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
  --audio-driver Dummy --fixed-fps 30 -- --autoplay --speed=6 --shots=/abs/out/dir

# one scene, shots at 1.5 s and 4 s of game time, quit at 5 s
timeout 300 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
  --audio-driver Dummy --fixed-fps 30 -- --scene=res://ui/audiometer/audiometer_screen.tscn \
  --shots=/abs/out/dir --shot-at=1.5,4 --quit-at=5

# play it yourself (needs a display)
godot --path .
```

## Autoplay output

The bot prints `BOT phase ...` lines, then one line like this:

```
AUTOPLAY_RESULT {"grade":"A","score":91.2,"accuracy":0.92,"technique":1.0,"efficiency":0.62,
                 "presentations":180,"thresholds":{"right":{"1000":[25,25],...}},"technique_errors":[...],"problems":[]}
```

`thresholds` holds `[stored, true]` pairs. True values are used for checking only. The bot never reads them while testing.

Exit codes:

| Code | Meaning |
|---|---|
| 0 | ok |
| 2 | stalled: no progress for 120 game seconds; a `stuck_<phase>.png` shot is taken |
| 3 | overall timeout |
| 4 | results sanity check failed: an ear is incomplete, a threshold is more than 10 dB off, or `level_finished` never fired. **(v3)** Day 2 also: every sheet (`ac`, `bc`, `bc_masked`, `ac_masked`) within 10 dB of the truth, Bonnie's right ear conductive with the red flag, masked bone at 500-4k, and masked air at every frequency the rules ask for with this air transducer (none with inserts; a masked air stamp where none was needed is a problem too) |
| 5 | script errors (or, since the polish pass, engine errors and `push_error()`) were logged during the run |
| 6 | `--mouse` only: a mouse target was not found on screen |

Screenshots are named `NN_<name>.png`:
- one per phase: `disclaimer`, `title`, `intro`, `history`, `otoscopy`, `instructions`, `earphones`, `audiometry_right`, `audiometry_left`, `reveal`, `evidence`, `fitting`, `results`;
- `audiometry_<ear>_first_tone`, `audiometry_<ear>_first_store`, `audiometry_<ear>_complete`;
- `results_final`.
- **(v3)** Day 2 adds `bc_placement`, `masking`, `referral`, `day2_reveal`, `day2_bridge`, `day2_stamp`; audiometry
  shots carry the test when it is not plain air: `audiometry_right_bc`, `audiometry_right_bc_masked_first_store`,
  `audiometry_right_ac_masked_hoot_turn`, and `audiometry_right_plateau` (the first plateau found).

Day 2 results add `sheets` (`<ear>_<test>`: `[stored, true]` per frequency), `right_abg`, `right_type` and
`plateaus_found`.

`run.log` in the output directory holds the full log.

## Command-line flags (user args go after `--`)

| Flag | Effect |
|---|---|
| `--autoplay` | the bot plays. Uses a fresh save in `user://save_autoplay.json` and seed 1234 by default. Quits itself. |
| `--shots=/abs/dir` | enables the screenshot service (rendered runs only) |
| `--shot-at=1.5,4` | timed screenshots (game seconds) |
| `--quit-at=N` | quit after N game seconds |
| `--scene=res://x.tscn` | boot this scene instead of the title and call its `demo_start()` |
| `--seed=N` | RNG seed (`Game.rng`) |
| `--speed=N` | `Engine.time_scale` |
| `--affinity` | Up = softer for this run |
| `--fresh` | reset the save first |
| `--save=user://x.json` | use another save file (`--scene=` runs default to `user://save_scene.json`, never the player's save) |
| `--mouse` | with `--autoplay`: drive everything with real mouse events (the mouse-only path) |
| `--day=N` / `--chapter=id` | **(v3)** start that chapter (`--day=2` = Bonnie) and treat it as unlocked for this run; with `--autoplay` the bot plays it |
| `--unlock-all` | **(v3)** every day open for this run (the save's "Unlock all days (demo)" setting is not changed) |
| `--keep-save` | **(v3)** with `--autoplay`: keep the save instead of resetting it (chain Day 1 then Day 2 on one `--save=`) |
| `--via-days` | **(v3)** with `--autoplay`: start from the title's Days card (`--pick=`, `--try-locked=`, `--toggle-unlock`, `--expect-days=`; see CONTRACTS.md §7.1) |

Scenes with a `demo_start()` for `--scene`:
- `res://ui/audiometer/audiometer_screen.tscn`: a coached right-ear test of Gus;
- `res://world/clinic.tscn`: a walk-in showcase.
- `res://story/dev_day2.tscn` **(v3)**: Day 2's set pieces (see above). A dev tool: never reachable from the game.
- `res://tools/monkey.tscn`: the stress test (`--day=2` for Day 2).

## Generators (one-off, foundation-owned)

| Script | Writes |
|---|---|
| `godot --headless --path . -s res://tools/setup_input_map.gd` | the `[input]` section of `project.godot`: the default key bindings (CONTRACTS.md §4.7) |
| `godot --headless --path . -s res://tools/build_assets.gd` | `icon.png`, `assets/theme/main_theme.tres`, `default_bus_layout.tres` (limiters), `core/patients/gus.tres` |
| `... -s res://tools/build_assets.gd -- --only=icon,theme` | only those parts |

Run `--import` afterwards. `gus.tres` is owned by builder A once they have edited it. Don't regenerate it after that.

## Writing tests

Put `test_*.gd` files in `res://tests/` (foundation) or in `res://<module>/tests/` (module owners). Each one `extends TestCase`.

```gdscript
extends TestCase

func test_louder_adds_five() -> void:
	var screen: Node = add_node((load("res://ui/audiometer/audiometer_screen.tscn") as PackedScene).instantiate())
	await wait_frames(2)
	Game.begin_visit("gus")
	screen.call("start_test", Game.load_patient("gus"), "right", true)
	var db0: int = screen.call("get_state")["db"]
	await tap_action(&"louder")       # InputEventAction, exactly like the bot
	assert_eq(int(screen.call("get_state")["db"]), db0 + 5)
	Hoot.clear()
```

- Any script error during a test fails it. Call `allow_errors()` first if the test expects one.
- Nodes added with `add_node()` are freed after the test.
- See CONTRACTS.md §7.4.
