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
  badge, plays, UP NEXT on the suggested day) in a scrolling grid, and Back. Up/Down or Left/Right + Enter, Esc = Back, or click. The card's title is a child Label, so
  the mouse bot's `_click_text("Day 1: Grand")` still lands on the card. Day 1's flow is unchanged.
- **Screenshots (Day 2):** `day2_bone_placement`, `day2_reveal`, `day2_bridge`, `day2_type`,
  `day2_carhart`, `day2_stamp`, `day2_croissant`, `day2_goodbye`.

## Speech (Day 3: Mike)

- **Level:** `story/level_mike.tscn` (`level_mike.gd`), chapter `mike`. Phases: `intro`, `history`,
  `otoscopy`, `instructions`, `audiometry` {right, ac} / {left, ac}, `familiarize`, `speech`
  {ear, test: "srt"} (right coached, then left), `evidence`, `referral`, `results`. Medals: `history`,
  `otoscopy` (always gold, not on the paper), `instructions`, `familiarize`, `evidence`, `referral`.
- **Tones:** Hoot runs both ears on the AudiOtron (`hoot_turn_after` 0, coached false, `montage` and
  `skip_hoot_retest` as on Day 2: a few seconds per ear). The AudiOtron only starts Hoot's turn at once
  with quick visit on, so the level sets the screen's public `quick_visit = true` right after `add_child`
  (see the request below). Hoot then names the degree from `ClinicRules.degree_name` and defines the PTA
  (`pta_line()`, best two when `SpeechRules.pta_method` says so).
- **SPEECH screen:** one instance for both ears (`start_test(patient, ear, coached, plan)`, then
  `await test_finished`); plan `{test: "srt", tones, list: "spondee_a", words: the 12 familiarised ids,
  exclude: ["windmill"] once dropped, transducer, intro, low_start_ok}`, plus `hoot_turn_after: 8`
  (`LEFT_SOLO_WORDS`: enough to reach his first miss below the SRT) on the left ear with quick
  visit on. `low_start_ok` is true once Hoot's coffee whisper has been on screen (`_whisper_seen`, never
  the hidden `non_organic` tag). Mike's response button is put away first (`hold_response_button(false)`).
  Hoot defines the SRT before the words. "The tell" lives in the SPEECH screen only (§9.7; the level no
  longer listens to `speech_response`). If the SPEECH scene is missing, Hoot runs the words himself
  through `SpeechSession` (`LevelMike.hoot_runs_ear`, not scored).
- **Recheck:** after the right ear, `_srt_shows_mismatch(sheet)` is true only for poor agreement with the
  SRT better than the PTA and stored at its bracket (`SpeechScreen.is_bracketed`). Otherwise Hoot says why
  (`recheck_line(sheet)`) and reruns the right ear by the book (`rerun_right()`: plan `fresh_session`,
  `hoot_turn_after` 0, the screen's `quick_visit` on for it and restored after; without a screen a new
  `SpeechSession` + `hoot_runs_ear`). His sheet goes in `LevelMike.recheck`; `board_sheet()` returns it for
  the board and Hoot's verdict, while the results keep the player's sheet for the grade.
- **Board** (`story/games/mike_board.gd`, story-internal): `run_cards(items, title)`,
  `read_along(from, to, s)`, `stumble(id)`, `run_drop(id)` (beat `familiarize_cards`, info
  `{targets: ["word_card_windmill"], mouse: {click: "word_card_windmill"}}`, solver drops it; other cards
  are slips with a kind tip), `show_objection(claim, clues)`, `run_objection()` (beat `objection_present`,
  info `{targets: ["objection_claim"], mouse: {drag: ["clue_srt_pta", "objection_claim"]}}`, solver
  presents the strongest clue; a weaker one gets a Hoot nudge and a retry; drag, click-then-claim, or
  1-3 + Enter), `set_referral_mode(on)`, `run_stamp()` (beat `referral_stamp`, RECHECK + OBJECTIVE TESTS
  + DOCTOR TODAY). `objection_cards()` builds the claim and clues from `board_sheet()`: the SRT-vs-PTA clue
  ("Hoot's recheck: SRT %d vs PTA %d" after a recheck) is always the best one, the coffee and canals
  captions stay neutral, and the verdict and `claim_note()` follow the direction.
  OBJECTION! slams in with `Events.screen_shake` and settles into a corner sticker; reduced motion
  keeps it still. Anchors: `word_card_<id>`, `objection_claim`, `clue_srt_pta`, `clue_coffee`,
  `clue_canals`, `referral_stamp`.
- **Daily Decibel:** headlines, subheads and the medal row (Chat, Explain, Words, Case, Next) for
  `mike`; with `audiometry.speech.srt` present, column 2 is the word golf card (per ear stored SRT,
  PTA, agreement chip with the gap, words vs par, golf; "no bracket" instead of the golf for an
  unbracketed store) with half-words and Hoot's words in the facts line. A speech C grade's subhead
  names the most frequent slip (`SPEECH_C_SUBHEADS`, `speech_c_subhead()`). Tone-only results keep the
  beep golf card.
- **Shared story bits:** Mike's portrait (`portraits.gd`), display name "Mike Lenders" (no joke
  nickname), a gruff voice (f0 105 Hz). Mike's day card uses his chapter entry's own `"face": "Mike"`
  and `"tint"` keys (no `title_screen.gd` change). The HUD tracker, the Hoot notes and the pause
  corner hide in the `speech` phase like in `audiometry`.
- **Note:** CHAPTER3.md names Mike's favourite forklift with what reads like a real product name;
  the level uses "Old Rumbles, bay six" instead (originality rule).
- **Screenshots (Day 3):** `day3_familiarize`, `day3_objection`, `day3_stamp`, `day3_goodbye`,
  `day3_glazed`.
- **Tests:** `story/tests/test_level_mike.gd` (board beats, keyboard paths and solvers, the plans and
  objection cards with real numbers and by sheet, the recheck with and without the screen, every Hoot
  line 18 words or fewer, Hoot's textbook fallback, the Day 3 paper, a smoke run to the instructions).

## Dev tool

`story/dev_gallery.tscn` shows each story screen with made-up results and requests `gallery_*` shots:

    xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
      --audio-driver Dummy --fixed-fps 30 -- --scene=res://story/dev_gallery.tscn --shots=/abs/dir --speed=2

It is not part of the game flow. `story/dev_day2.tscn` does the same for Day 2 (`--part=world`,
`placement`, `board`, `title`, default all but title).
`story/dev_day3.tscn` does it for Day 3 (`--part=world`, `board`, `paper`, `title`, default all;
`dev_day3_*` shots). Both are in the export exclude filter.

## Tests

`story/tests/test_story.gd` covers dialogue keys and solvers, the mini-game solvers and keyboard paths,
the Hoot bubble, the pause menu and its key-style label, the results continue beat, the title beats, and
the voice ceiling.

## Cases (Days 6 to 11, cases branch; CONTRACTS.md §11, docs/CASES.md)

The case files run in their own runner (`story/level_case.gd`) and touch other story files only additively.
Requests for the integrator and the title owner:

- **Day picker.** Each case chapter in `Game.CHAPTERS` carries `face` (the portrait speaker, e.g. `"Rocco"`) and
  `tint` (the card colour), which the Days grid uses. `Portraits` draws every case speaker (it falls back to
  `CasePortraits`).
- **Merge order.** The speech chapters (Days 3 to 5) and the cases (Days 6 to 11) both append to `Game.CHAPTERS`
  and `Game.PHASES` (speech: `familiarize`, `speech`; cases: `tymp`, `decision`, `retest`). Keep both blocks,
  speech first, and keep the exact `"case": "<id>"` spelling (`tools/case_scripts.py` finds the case order with a
  regex).
- **Daily Decibel golf rows.** `GOLF_EXTRA_ROWS` has left-ear masked rows too (Marina's and Skye's masked tests are
  on the LEFT ear). Its rows are now `[sheet key, ear]`: the old label column was never read (`_row_tag` draws the
  symbol) and its U+25A1 square is not in Fredoka, so it was dropped at the integrator's request.
- **Notice to builder B: `story/games/case_otoscopy.gd`** extends `otoscopy.gd` and overrides `_draw_canal` (it
  draws the wax plug or the fluid on top of your healthy drum), reading `view_center`, `ear` and `_canal`, and
  calls `show_clear`. It also copies your drum's geometry from `_draw_canal` (centre offset (-6, 6), radii 112 x 98,
  tilt -0.25, colour #c9c6cf, cone of light (8, 8) / (56, 74) / (26, 84)). Please keep those names, and tell us if
  the drum changes (or expose those numbers as constants and the cases will read them).
- **Daily Decibel weather line.** In the Day 6 screenshots taken before the Days rework, the pause corner button
  covered the end of "Weather: 100% chance of beeps". Not rechecked since; worth a look.
- **Daily Decibel summary keys.** A case summary may carry `headlines` and `subheads` (grade -> text, incl.
  `"Do-over"`) and `medal_beats`; when present they win over the per-chapter tables. Already wired, listed
  here so it isn't undone at merge.
- **Voice.** `Voice.register(speaker, spec)` adds a babble voice for a case speaker (built-in speakers can't
  be overwritten). Case speakers with no registered voice are silent; missing keys in a case's voice spec take Gus's values.
- **Portraits.** Unknown speakers fall back to `story/case_portraits.gd`. Chip (Ginger's puppet) has a cookie
  portrait.
- **Screenshots:** `case_<id>_intro`, `_otoscopy`, `_tymp_sweep`, `_tymp_curves`, `_reveal`, `_pattern`,
  `_case_file`, `_stamp`, `_exhibit`, `_hearing_aids` / `_letter` / `_boat` / `_wax_jar` / `_plane`, `_goodbye`;
  Barnaby's retest adds `_retest_later`, `_retest_otoscopy`, `_retest_tymp`, `_retest_chart`, `_retest_goodbye`.
- **Tests:** `story/tests/test_cases.gd` (32 tests). `tools/run_tests.sh` runs `python3 tools/case_scripts.py
  --check` after the suite, so a stale `docs/CASE_SCRIPTS.md` fails the run.

## Merge: main (Days 3, 6-9) into the Day 2 feedback (v4)

- **Daily Decibel golf rows.** `GOLF_EXTRA_ROWS` is the union of both sides: v4's `["bc", "L  >", "left"]` first
  (Day 2's unmasked bone on the better, left ear), then `R  [`, `R  O+`, and the cases' `L  ]`, `L  □`. A row only
  shows when that sheet has stamps, so Day 1 and Day 3 show none, Day 2 shows `L  >`, `R  [`, `R  O+` as on the
  feedback branch, and Rocco, Dash and Ginger as on main. Marina (her bone is tested on her left ear) shows only
  her `L  ]` and `L  □` rows: the `L  >` row hides when that ear has a masked-bone sheet. (cases, PR #3) The rows
  are now `[sheet key, ear]`; `_row_tag` draws the symbol.
- **Pause corner.** Hidden while the AudiOtron, the SPEECH screen (Speech) or one of Hoot's movies (v4) is up.
- **Hoot's movies** stay Day 2 only: Days 3 and 6-9 have no movie, and their pause menu shows no movie button
  (the title's Options and its "Hoot's Movies" button still offer the masking movie on any save).

## Freestyle (the walk-in clinic; freestyle branch; CONTRACTS.md §12, docs/FREESTYLE.md)

Everything is in `story/freestyle/` plus `core/patients/fs_*.tres`. Changes to shared files are additive:

- **Title menu.** A **Freestyle** button after Days. With **New player** that makes six buttons, so Options and
  Quit now share the last row (Up/Down and Left/Right walk the buttons in order) and the card still clears the
  safety footer (`test_title_menu_clears_the_footer`). If another branch adds a menu button too (for example a
  movies button), keep both and run that test.
- **Game.PHASES** gained `freestyle_room`, `freestyle_tray`, `freestyle_chart`, `freestyle_debrief` (append after the
  speech and cases blocks).
- **CasePortraits.register(who, look)**: walk-ins aren't chapters, so the waiting room registers their looks.
- **Daily Decibel**: the summary's optional `continue_text` labels the main button ("Waiting room");
  default unchanged.
- **Autoplay bot**: with `--mouse` it clicks `continue_text` and treats the summary's `continue_scene` like the title;
  new `--via-freestyle` (title -> Freestyle); the report gains `freestyle`. `_open_days()` now calls the shared
  `_open_title_button(text)`.
- **Reused**: `story/games/case_tymp.gd` (the cases tympanometer), the AudiOtron's plans, `CaseRules`, `ClinicRules`.
  No second tympanometer.
- **Tests:** `story/tests/test_freestyle.gd`.
