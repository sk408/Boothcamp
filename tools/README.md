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
| **(Speech)** Day 3 (Mike: SRT on the SPEECH screen, the OBJECTION! board, the recheck stamp), keys or mouse only | `tools/autoplay_check.sh --day=3` / `tools/autoplay_check.sh --day=3 --mouse` | ~15 s |
| **(Day 4)** Day 4 (Nora: Hoot's tones and SRTs, then word recognition in the SPEECH screen's WORD mode: Word list 1 right, Word list 2 left with the noise decision, the louder list, then the Red-Flag Roll Call and the referral stamp), keys or mouse only; Quick visit off (the player's SRTs and all 25 words of every list): add `--full` | `tools/autoplay_check.sh --day=4` / add `--mouse` / add `--full` | ~20 s each |
| **(Day 4)** Day 4 picked from the Days grid by mouse (a fresh save, so the Letter Choir plays first) | `tools/autoplay_check.sh --save=/abs/s.json --via-days --mouse --pick=nora` | ~20 s |
| **(cases)** Days 6 to 12, the case files (history, otoscopy, tymp, audiometry, the call; Day 10 also the retest; Day 12 the shadow curve), keys or mouse only | `tools/autoplay_check.sh --day=6` (or 7 to 12) / add `--mouse`; Quick visit off: add `--full`; Day 10 with inserts owned (the wax keeps headphones): add `--upgrades=insert_earphones` | ~30 s each (Day 10 ~45 s) |
| **(cases)** A case picked from the Days grid by mouse | `tools/autoplay_check.sh --save=/abs/s.json --via-days --mouse --pick=marina` (or rocco, dash, ginger, barnaby, skye) | ~30 s |
| **(cases)** `docs/CASE_SCRIPTS.md` matches the case JSON (regenerate it: drop `--check`; `tools/run_tests.sh` runs the check too) | `python3 tools/case_scripts.py --check` | ~1 s |
| **(freestyle)** One walk-in from the waiting room, keys or mouse only (any `fs_` id from `FsData.CASE_IDS`); Quick visit off: add `--full` | `tools/autoplay_check.sh --scene=res://story/freestyle/waiting_room.tscn --freestyle=fs_penny` / add `--mouse` | ~60 s |
| **(freestyle)** From the title's Freestyle button, like a player | `tools/autoplay_check.sh --via-freestyle --freestyle=fs_penny --mouse` | ~60 s |
| **(arcade)** One Chart Chute run with a test bot; prints `ARCADE_RESULT`, exit 0 = every check passed (policies `careful`, `keys`, `mouse`, `guess`, `help`, `slip`; add `--via-title` to start from the title's Arcade button and pick cabinet 1 in the hall; `--days-done` lets story charts ride the belt; add `--shots=/abs/dir` under xvfb for its named shots) | `timeout 300 godot --headless --path . --fixed-fps 30 -- --scene=res://story/tests/arcade_chute_check.tscn --fresh --policy=careful --speed=4 --seed=1` | ~25 s |
| **(arcade)** One Ears, Please! shift with a test bot; prints `ARCADE_RESULT`, exit 0 = every check passed (policies `careful`, `keys`, `mouse`, `fit_everything`, `refer_everything`, `guess`, `help`; `--shift=N` plays shift N; `--via-title` starts from the title and picks the cabinet in the arcade hall; add `--shots=/abs/dir` under xvfb for its named shots) | `timeout 300 godot --headless --path . --fixed-fps 30 -- --scene=res://story/tests/arcade_desk_check.tscn --fresh --policy=careful --speed=4 --seed=1 --shift=1` | ~60 s |
| Rendered autoplay with screenshots at every phase | `tools/shots.sh /abs/out/dir` (Day 2: add `--day=2`) | ~5 min (Day 2 ~13 min) |
| Button-mashing stress test of the AudiOtron (both ears, Hoot's x8 turn, pause menu); prints `MONKEY_RESULT` | `timeout 900 godot --headless --path . --fixed-fps 30 -- --scene=res://tools/monkey.tscn --speed=3 --seed=1` (Day 2's tests and the masking keys: add `--day=2`; a case day's tests, its masking and any retest: `--day=6` to `--day=11`; **(v4)** first Hoot's masking movie three ways (as the level plays it with Space / Enter / clicks / P but no Esc: it must reach the end and freeze under the pause menu; the same plus Esc and Skip movie; the pause menu's "Watch" replay by a real click), `movie_runs` in the result; then six tests: right and left air, LEFT bone, the right Ghost demo, masked right bone and air) | ~10 s (Day 2 ~20 s) |
| **(Speech)** The same stress test on Day 3: the SPEECH screen (coached right ear, Hoot's recheck at x8, the left ear with Hoot's x8 turn; PRESENT, CORRECT / MISSED, the level, STORE, MASK by key and click, wrong scores, double STOREs), then the Day 3 board (cards, say-along, drop, OBJECTION!, stamp) under random keys, clicks and drags. Checks the dial range, the speech noise (only with MASK on, other ear, at the mask level, never in Hoot's turn, none left after an ear), no stuck TALK lamp, Hoot's recheck bracketed, and every board step done right. Any day the monkey doesn't play (Days 4 and 5, a day with no chapter) is refused with a message and exit 2 | `timeout 900 godot --headless --path . --fixed-fps 30 -- --scene=res://tools/monkey.tscn --speed=3 --seed=1 --day=3` | ~15 s |
| **(v3)** Day 2 set pieces without playing (bone placement with a wrong spot, the oscillator on Bonnie, the board's reveal, bridge and stamp on made-up results) | `tools/scene_shot.sh res://story/dev_day2.tscn /abs/out/dir "60" 30` (the scene takes its own shots) | ~2 min |
| **(polish)** The title with progress and the paper's Next (fresh Days card, Day 2 UP NEXT after Day 1, the menu after Day 1 and with both days done, the paper after Day 2 played first) | `timeout 300 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 30 -- --scene=res://story/dev_day2.tscn --shots=/abs/out/dir --part=title --quit-at=25` (`--part=placement` / `board` / `world` shoot one part; the default runs world, placement and board) | ~30 s |
| Play the full visit without Hoot's quick-visit turn (or force it with `--quick`) | add `--full` after `--` | |
| **(polish)** Own shop items for the run (Day 2 with insert earphones: no masked air needed, the level skips it) | `tools/autoplay_check.sh --day=2 --upgrades=insert_earphones` | ~25 s |
| Boot one scene and take timed screenshots (anything after a `--` goes to the scene) | `tools/scene_shot.sh res://world/clinic.tscn /abs/out/dir "1,3.5"` | ~20 s |
| **(v4)** Hoot's movie, one shot per scene (`explainer_<id>_<NN>_<scene>`), prints `EXPLAINER_RESULT` and quits | `timeout 400 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 30 -- --scene=res://story/explainers/dev_explainer.tscn --shots=/abs/out/dir --speed=2` (`--movie=<id>`; `--at=0.65` = the moment of each scene as a share of it, several with `--at=0.2,0.6,0.95` (extra shots `..._t<seconds>`); `--times=1.5,4` = seconds into every scene instead; `--from=<scene id or number>` start there, `--only` stop after that scene; `--menu` = then the Day 2 pause menu: really clicks "Watch Hoot's masking movie", checks the replay runs under the paused game, Space advances (like dialogue) to the next scene, Esc = skip, the menu comes back, prints `EXPLAINER_MENU {button, started, played_paused, space_next, skipped, menu_back}`; `--title` = only the title's "Hoot's Movies" button, the same way, prints `EXPLAINER_TITLE {button, started, playing, skipped, title_back}`; `--card-demo` = the generic `card` set with each icon and the unknown-set fallback (`explainer_card_*`); `--reduced-motion` = that setting on, its own save; **(polish)** `--extra-movie=res://path/movie.gd[,...]` = register more movie files for this run (e.g. `res://tests/fixtures/fake_movie.gd`, whose own sets script draws through the stage hook; then `--movie=fake_hook`); `--list` = only the pause menu's "Hoot's Movies" list with five made-up movies on two days (in the Day 2 menu it lists Day 2's: masking and three fakes): clicks the list button, shoots it (`explainer_movie_list_menu`, `explainer_movie_list`), Down x4 (`explainer_movie_list_down`), Enter plays the last row, Esc skips it, the list is back (`explainer_movie_list_back`), Esc returns to the menu; prints `EXPLAINER_LIST {rows, button, fits, down_hl, played, back, menu_back}`) | ~40 s |
| **(v4)** Day 2's two bone placements (left, slips, placed, the 3D oscillator on her left mastoid, the quick right one), then the v3 right-side shots | `timeout 300 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 30 -- --scene=res://story/dev_day2.tscn --shots=/abs/out/dir --part=placement --quit-at=40` | ~40 s |
| Windows build: `build/BoothCamp.exe` with the PCK embedded, plus `build/BoothCamp-win64.zip` (exe, README, font licence) | `tools/export_win.sh` (add `--xz` for an .xz too) | ~1 min |
| Audio-safety movie: record both ears (Movie Maker AVI) and check routing, levels and the -12 dBFS ceiling per tone | `tools/movie_check.sh /abs/out/dir` | ~5 min |
| **(Speech)** Day 3 set pieces without playing (Mike in the clinic, the word cards and the dropped word, OBJECTION!, the stamp, the paper, the Days grid) | `tools/scene_shot.sh res://story/dev_day3.tscn /abs/out/dir "1" 40` (one part: add `-- --part=board`; parts `world`, `board`, `paper`, `title`) | ~1 min |
| **(Day 4)** Nora's level from one beat, with Hoot's textbook results for everything before it (`--from=` movie, intro, history, otoscopy, instructions, tones, srt, words_r, words_l, louder, flags, call, payoff); `--from=paper` shoots four Daily Decibels instead (S, A with a redone list, C, Do-over: `dev_day4_paper_*`); `--from=words_l --boo` (no `--autoplay`) presses PRESENT unmasked on List 2, then MASK, for `day4_boo` / `day4_ghostbuster`, and quits | `tools/autoplay_check.sh --scene=res://story/dev_nora.tscn --from=words_l` (rendered, with the level's `day4_*` shots: `tools/shots.sh /abs/out/dir --scene=res://story/dev_nora.tscn --from=flags`); papers: `tools/scene_shot.sh res://story/dev_nora.tscn /abs/out/dir "1" 16 -- --from=paper`; the BOO: `tools/scene_shot.sh res://story/dev_nora.tscn /abs/out/dir "1" 120 -- --from=words_l --boo` | ~1-6 min |
| **(Speech)** The SPEECH screen alone: a coached right-ear SRT of Mike | `tools/scene_shot.sh res://ui/speech/speech_screen.tscn /abs/out/dir "2,6,12,20" 24` (extras after a `--`, e.g. `... 24 -- --demo-play --demo-ear=left`; also `--demo-uncoached`, `--demo-hoot=N`) | ~1 min |
| **(v3)** Day 2 audio-safety movie: Bonnie's air, bone, masked bone and masked air with UI sounds muted (**(v4)** in the v4 order: both airs, unmasked bone on her LEFT mastoid, the one-tone Ghost demo on the right, masked right bone with the noise in the left ear, masked right air); `tools/analyze_movie_bc.py` checks tone channel and level, the bone cross-feed (-10 dB) and the masker (other ear only, level, -24 dBFS cap); prints `AUDIO_CHECK PASS` | `tools/movie_check.sh /abs/out/dir --day=2` | ~20 min |
| **(Speech)** Day 3 audio-safety movie: Mike's SRT, both ears, played by the bot at `--speed=1` (each word's murmur plays in real time; a faster clock would cut words off), MASK on after the 3rd scored word of each ear and off after the 7th (words 4-7 carry the speech noise), UI sounds muted; `tools/analyze_movie_audio.py --speech` checks every word (test ear only, played in full, RMS vs `AudioSafety.speech_to_rms`), the speech noise (other ear only, RMS vs `masker_to_rms` at each level, -24 dBFS cap), that nothing else sounds, and the whole visit (`MOVIE_DONE`, no `AUTOPLAY_FAILED`, both ears tested and measured, each with words under the noise); a recording that exits non-zero (a stall, a timeout) fails before the analysis; prints `AUDIO_CHECK PASS`. `movie_check.sh` (and `movie_ac.tscn`) refuse any day other than 1, 2 or 3, and any `--chapter`, with a message and exit 2, recording nothing | `tools/movie_check.sh /abs/out/dir --day=3` | ~8 min (~480 MB AVI) |
| **(v3)** AudiOtron Day 2 teaching states (bone route, Ghost, masking deck, plateau, overmasking, finished audiogram) | `timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 30 -- --scene=res://ui/dev/dev_audiotron_day2.tscn --shots=/abs/dir --fresh` (add `--resolution 1920x1080` before `--` and a 1920x1080 xvfb screen for full HD) | ~3 min |
| **(Day 4)** The SPEECH screen's WORD mode on Nora, through the screen's own controls: Word list 1 coached (the denial, the level set, the first word, lens_try, NORA-VISION and the Banana Board, Call it, Hoot's x8 turn, the list stored), Word list 2 solo (the tea demo, the level chip, BOO!, GHOST BUSTED!, Call it, AUDIBLE, BUT MISSED, the ear compare), the coached redo (the lurking Ghost) and the louder list (the loud bubble, the slide, the verdicts) | `timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 30 -- --scene=res://ui/dev/dev_speech_word.tscn --shots=/abs/dir` (full HD: `--resolution 1920x1080` before `--` and a 1920x1080 xvfb screen; extras `--reduced-motion`, `--only=w1,w2,redo,louder`) | ~3 min |
| **(v3)** Chapter select by real input (polish: every day open, any order): Day 2 straight from a fresh save, then Day 1 by mouse on the same save (Day 1 still UP NEXT). `--expect-days` days must be on the grid in that order; other days may sit between or after them | `tools/autoplay_check.sh --save=/abs/s.json --via-days --expect-days=gus,bonnie --expect-suggested=gus --pick=bonnie` then `tools/autoplay_check.sh --save=/abs/s.json --keep-save --via-days --mouse --expect-suggested=gus --pick=gus` | ~30 s |
| **(polish)** The Days grid with 11 made-up days (never shipped): 1280x720 and 1920x1080 shots, keyboard scrolling to the last card | `tools/scene_shot.sh res://story/dev_days.tscn /abs/out/dir "30" 30` (add a 1920x1080 run: see the scene's header) | ~30 s |

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
| 4 | results sanity check failed: an ear is incomplete, a threshold is more than 10 dB off, or `level_finished` never fired. **(v3)** Day 2 also: every sheet (`ac`, `bc`, `bc_masked`, `ac_masked`) within 10 dB of the truth, Bonnie's right ear conductive with the red flag, masked bone at 500-4k, and masked air at every frequency the rules ask for with this air transducer (none with inserts; a masked air stamp where none was needed is a problem too). **(v4)** Day 2 also: LEFT unmasked bone at 500-4k, no unmasked RIGHT bone stamp (the Ghost demo stores nothing), the `explainer` and `ghost_demo` phases, the movie started on a fresh save, and at least one demo tone | **(Speech)** Every stored speech sheet within 10 dB of the truth; on Day 3 both SRTs stored and a poor PTA/SRT agreement. **(Days 4-5)** Every counted word list the player scored within 8 points of its deal, equal to the truth when nothing was misscored, started at a fair level and masked exactly when needed; on Day 4 the better ear first, the lists in play order, the right ear 88% or more (excellent or good), the left comfortable list 64% or less with its best final, below predicted, asymmetric and rolled over, the louder list's noise by the formula (65-75 dB), a referral (and the visit's decision `refer`), and `letter_choir` started on a fresh save
| 5 | script errors (or, since the polish pass, engine errors and `push_error()`) were logged during the run |
| 6 | `--mouse` only: a mouse target was not found on screen |

Screenshots are named `NN_<name>.png`:
- one per phase: `disclaimer`, `title`, `intro`, `history`, `otoscopy`, `instructions`, `earphones`, `audiometry_right`, `audiometry_left`, `reveal`, `evidence`, `fitting`, `results`;
- `audiometry_<ear>_first_tone`, `audiometry_<ear>_first_store`, `audiometry_<ear>_complete`;
- `results_final`.
- **(v3)** Day 2 adds `bc_placement`, `masking`, `referral`, `day2_reveal`, `day2_bridge`, `day2_stamp`; audiometry
  shots carry the test when it is not plain air: `audiometry_right_bc`, `audiometry_right_bc_masked_first_store`,
  `audiometry_right_ac_masked_hoot_turn`, and `audiometry_right_plateau` (the first plateau found).
- **(v4)** Day 2 adds `explainer` and `explainer_scene_2` (Hoot's movie, before the bot skips it), `explainer_masking_recap`
  (the recap card, all four lines in, as the masking phase opens), `bc_placement_left`,
  `audiometry_left_bc`, `ghost_demo_right`, `day2_bone_placement_right`, `audiometry_right_bc` (the demo) and
  `audiometry_right_ghost_demo` (its first tone).

**(Speech)** Speech shots: `speech_<ear>_srt_first_word`, `speech_<ear>_srt_descent` (the first word at 40 dB or
softer), `speech_<ear>_srt_stored`; Day 3 adds `day3_familiarize`, `day3_objection`, `day3_stamp`, `day3_goodbye`,
`day3_glazed`. **(Days 4-5)** Word and party lists name their slot and list: `speech_<slot>_<test>_<list_id>_first_word`
and `_stored` (for example `speech_left_wrs_words_2_first_word`); the descent shot is the SRT's only. Day 4 adds
`day4_intro`, `day4_tuning_fork`, `day4_lens_right`, `day4_call_it`, `day4_tea_demo`, `day4_boo` and
`day4_ghostbuster` (only when the noise was forgotten), `day4_audible_miss`, `day4_flags`, `day4_flags_done`,
`day4_stamp`, `day4_letter` and `day4_a_flat`.

Day 2 results add `sheets` (`<ear>_<test>`: `[stored, true]` per frequency), `right_abg`, `right_type` and
`plateaus_found`; **(v4)** `movies` (movies that started) and `ghost_demo_tones`. **(Speech)** Speech days add `speech` (`<test>_<ear>`: `[stored, true, agreement, words, par]`) and `speech_scores`. **(Days 4-5)** Days with word lists add `wrs_lists`; Day 4 adds `movies` (a fresh save must start `letter_choir`).

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
| `--day=N` / `--chapter=id` | **(v3)** start that chapter (`--day=2` = Bonnie, `--day=3` = Mike, `--day=4` = Nora) and treat it as unlocked for this run; with `--autoplay` the bot plays it |
| `--unlock-all` | **(v3)** accepted and ignored since the polish pass: every day is always open |
| `--keep-save` | **(v3)** with `--autoplay`: keep the save instead of resetting it (chain Day 1 then Day 2 on one `--save=`) |
| `--via-days` | **(v3)** with `--autoplay`: start from the title's Days card (`--pick=`, `--expect-days=`, `--expect-suggested=`; with `--mouse` the bot scrolls the grid with the wheel; see CONTRACTS.md §7.1) |
| `--freestyle=<id>` | **(freestyle)** the walk-in to play (the waiting room's pick and the runner's case; CONTRACTS.md §12) |
| `--via-freestyle` | **(freestyle)** with `--autoplay`: start from the title's Freestyle button |

Scenes with a `demo_start()` for `--scene`:
- `res://ui/audiometer/audiometer_screen.tscn`: a coached right-ear test of Gus;
- `res://world/clinic.tscn`: a walk-in showcase.
- `res://story/dev_day2.tscn` **(v3)**: Day 2's set pieces (see above). A dev tool: never reachable from the game.
- `res://story/explainers/dev_explainer.tscn` **(v4)**: plays one of Hoot's movies and shoots every scene (see above).
- `res://ui/dev/dev_speech_word.tscn` **(Day 4)**: the SPEECH screen's WORD mode on Nora (see above). A dev tool, excluded from the export (`ui/dev/*`).
- `res://story/dev_day3.tscn` **(Speech)**: Day 3's set pieces (see above). Also a dev tool, excluded from the export.
- `res://story/dev_nora.tscn` **(Day 4)**: Nora's level from a beat (`--from=`), or her papers (see above). A dev tool, excluded from the export. It starts by itself (no `demo_start()`).
- `res://ui/speech/speech_screen.tscn` **(Speech)**: a coached right-ear SRT of Mike (see above).
- `res://story/freestyle/waiting_room.tscn` **(freestyle)**: the walk-in clinic's waiting room (add `--freestyle=<id>`).
- `res://story/arcade/arcade_hall.tscn` **(arcade)**: the arcade hall (pick a cabinet).
- `res://story/arcade/chart_chute.tscn` **(arcade)**: a Chart Chute run (play it yourself; `--seed=N` repeats a belt).
- `res://story/arcade/ears_please.tscn` **(arcade)**: an Ears, Please! shift (`--seed=N` repeats a line of patients).
- `res://tools/monkey.tscn`: the stress test (`--day=2` for Day 2, `--day=3` for Day 3, `--day=6` to `--day=12` for the cases; any other day is refused).

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
