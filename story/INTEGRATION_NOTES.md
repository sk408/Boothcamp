# story/ integration notes (builder B)

No new Events signals and no new beats. Every blocking moment emits a §3.2 beat with a solver:
`disclaimer_ok`, `title_start`, `dialogue`, `choice`, `otoscopy_find`, `earphones_place`,
`evidence_present`, `fitting_switch_on`, `results_continue`.

## For other modules

- **ui/ (AudiOtron):** the pause menu's corner "II" button hides during the `audiometry` phase, because it
  covered the combo card. Esc / P still open the menu. If you want a pause button on the AudiOtron, call
  `get_tree().get_first_node_in_group("pause_menu").call("open")`.
- **Voice bus:** `story/voice.gd` plays the dialogue babble on `AudioSafety.VOICE_BUS` (Master if that bus is
  missing) and sets that bus's volume from `Game.settings.sfx_volume`. Syllable peaks are -24 dBFS and
  go through `AudioSafety.clamp_sample`. In the grey fitting world it plays a muffled bank (high
  harmonics rolled off, 8 dB quieter), reading the clinic's `get_muffle()` by name through `Stage.clinic`.
- **Hoot bubble:** the evidence board calls `Hoot.set_bubble_hint()` so tips sit below the case file, and
  clears it in `_exit_tree`. Without a hint the bubble sits top-right at y = 176, clear of the HUD.
- **CanvasLayers:** HUD tracker and micro-games 10, dialogue 30, Daily Decibel 40, Hoot bubble 80,
  pause 90. The HUD hides its tracker during audiometry and results.
- **Screenshots:** with `--shots` the level also asks for `story_door_burst`, `story_history_clue`,
  `story_seed_found`, `story_sneeze`, `story_earphones_game`, `story_earphones_on`,
  `story_reveal_title`, `story_evidence_board`, `story_evidence_solved`, `story_fitting_grey`,
  `story_fitting_colour`, `story_fitting_dishes`. Without `--shots` these calls do nothing.

## v3 (Day 2)

- **Beats:** Day 2 adds `bc_placement` (solver: oscillator on the mastoid), `referral_stamp` (solver:
  stamp) and the title's `chapter_select` (solver: start `Game.next_chapter_id()`); the rest are
  `dialogue` / `choice` as on Day 1. The payoff (croissant, glasses, walk out) is dialogue only.
- **Placement mini-game** (`story/games/bone_placement.gd`): spots nose (BOOP!), forehead (a unicorn
  horn), jaw, `top` = her reading glasses perched on her head ("My glasses!"), pinna (a drawn
  feedback squeal, never a loud sound), bun, and the mastoid. Note: CHAPTER2.md section 6 puts the
  unicorn on the top of the head; it moved to the forehead so the top could be the glasses gag.
- **Board** (`story/games/day2_board.gd`, story-internal): `run_reveal(results)`, `show_gap()` (the
  toll bridge, polish: one plank per frequency just under each masked bone mark, stone pillars down to
  the air marks labelled "toll N dB", the river only between gaps (per-segment quads, no self-crossing
  polygon), the left ear faded to 25 %, a toll booth with a bobbing barrier, and a little dog-bone car
  hopping plank to plank),
  `set_compact(on)` (shrinks the chart to the top so dialogue choices fit below), `show_type(text)`,
  `show_carhart()` (ring on the 2 kHz bone mark + label), `run_stamp()`. Anchors `reveal_audiogram`,
  `abg_bridge`, `referral_stamp`.
- **Otoscopy:** `Otoscopy.show_clear(ear, caption)` is an input-free look at a healthy ear (Day 2).
- **Title:** Days shows one illustrated card per day (portrait, title, what it teaches, best grade
  badge, plays, padlock + "Finish Day 1 to open" when locked), the "Unlock all days (demo)" toggle
  and Back. Up/Down or Left/Right + Enter, Esc = Back, or click. The card's title is a child Label, so
  the mouse bot's `_click_text("Day 1: Grand")` still lands on the card. Day 1's flow is unchanged.
- **Screenshots (Day 2):** `day2_bone_placement`, `day2_reveal`, `day2_bridge`, `day2_type`,
  `day2_carhart`, `day2_stamp`, `day2_croissant`, `day2_goodbye`.

## Dev tool

`story/dev_gallery.tscn` shows each story screen with made-up results and requests `gallery_*` shots:

    xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
      --audio-driver Dummy --fixed-fps 30 -- --scene=res://story/dev_gallery.tscn --shots=/abs/dir --speed=2

It is not part of the game flow. `story/dev_day2.tscn` does the same for Day 2 (`--part=world`,
`placement`, `board`, `title`, default all but title).

## Tests

`story/tests/test_story.gd` covers dialogue keys and solvers, the mini-game solvers and keyboard paths,
the Hoot bubble, the pause menu and its key-style label, the results continue beat, the title beats, and
the voice ceiling.

## Cases (Days 6 to 9, cases branch; CONTRACTS.md §11, docs/CASES.md)

The case files run in their own runner (`story/level_case.gd`) and touch other story files only additively.
Requests for the integrator and the title owner:

- **Day picker (agreed with the main thread, which owns `title_screen.gd`).** Each case chapter in
  `Game.CHAPTERS` carries `face` (the portrait speaker, e.g. `"Rocco"`) and `tint` (the card colour). The chapter
  select rework falls back to those keys when `DAY_FACES` / `DAY_TINTS` has no entry, and lays out any number of
  chapters in a scrolling grid. Until it lands, Days 6 to 9 show the default cream card with no portrait.
  `Portraits` already draws every case speaker (it falls back to `CasePortraits`).
- **Merge order.** The speech chapters (Days 3 to 5) and the cases (Days 6 to 9) both append to `Game.CHAPTERS`
  and `Game.PHASES` (speech: `familiarize`, `speech`; cases: `tymp`, `decision`). Keep both blocks, speech first.
- **No locks.** `requires` on the case chapters is a "suggested next" badge only; every day stays open.
- **Daily Decibel golf rows.** `GOLF_EXTRA_ROWS` lists right-ear masked rows only. Marina's masked tests are
  on her LEFT ear, so her masked holes are not scored. Please add `["bc_masked", "L  ]", "left"]` and
  `["ac_masked", "L  X+", "left"]` (or whatever symbols you prefer).
- **Daily Decibel summary keys.** A case summary may carry `headlines` and `subheads` (grade -> text, incl.
  `"Do-over"`) and `medal_beats`; when present they win over the per-chapter tables. Already wired, listed
  here so it isn't undone at merge.
- **Voice.** `Voice.register(speaker, spec)` adds a babble voice for a case speaker (built-in speakers can't
  be overwritten). Case speakers with no voice fall back to Gus's.
- **Portraits.** Unknown speakers fall back to `story/case_portraits.gd`. Chip (Ginger's puppet) has a cookie
  portrait.
- **Screenshots:** `case_<id>_intro`, `_otoscopy`, `_tymp_sweep`, `_tymp_curves`, `_reveal`, `_pattern`,
  `_case_file`, `_stamp`, `_exhibit`, `_hearing_aids` / `_letter` / `_boat`, `_goodbye`.
- **Tests:** `story/tests/test_cases.gd` (12 tests). `python3 tools/case_scripts.py --check` fails if
  `docs/CASE_SCRIPTS.md` is out of date with the case JSON.
