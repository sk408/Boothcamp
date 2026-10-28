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
  (see the request below). After the right ear Hoot retests 1 kHz in the level (`retest_1k(tones)`: the
  measured 1 kHz minus `RETEST_BETTER_DB` 15, a test-retest mismatch; Hoot says the numbers, Mike blames the
  earphones) and it goes on the record as the right ear's `retest_1k` (`by_hoot`, PTA unchanged); not on the
  OBJECTION! board, where SRT vs PTA stays the clue. Hoot then names the degree from `ClinicRules.degree_name` and defines the PTA
  (`pta_line()`, best two when `SpeechRules.pta_method` says so).
- **SPEECH screen:** one instance for both ears (`start_test(patient, ear, coached, plan)`, then
  `await test_finished`); plan `{test: "srt", tones, list: "spondee_a", words: the 12 familiarised ids,
  exclude: ["windmill"] once dropped, transducer, intro, low_start_ok}`, plus `hoot_turn_after_up`
  with `hoot_turn_after: 12` (`LEFT_SOLO_WORDS`, the cap) on the second ear with quick visit on: the
  player scores down to his first miss below the SRT and the word stepped up 5 after it, then Hoot
  finishes the bracket. The ears go better first (`srt_ears()`: the lower tone PTA, right on a tie; clinical
  review S6) and the first is the coached one: for Mike the right, then the left. `low_start_ok` is true once Hoot's coffee whisper has been on screen (`_whisper_seen`, never
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
- **Board** (`story/games/mike_board.gd`, story-internal): `run_cards(items, title)` (the cards face the
  clinician: a "CLINICIAN'S SIDE: Mike can't see this" sign, anchor `familiarize_cue`), `say_along(from, to, s)`
  (Hoot says each card, Mike says it back by ear: the "now saying" line and a tick per card),
  `finish_say_along()`, `say_word(id, echo)`, `stumble(id)`, `run_drop(id)` (beat `familiarize_cards`, info
  `{targets: ["word_card_windmill"], mouse: {click: "word_card_windmill"}}`, solver drops it; other cards
  are slips with a kind tip), `show_objection(claim, clues)`, `run_objection()` (beat `objection_present`,
  info `{targets: ["objection_claim"], mouse: {drag: ["clue_srt_pta", "objection_claim"]}}`, solver
  presents the strongest clue; a weaker one gets a Hoot nudge and a retry; drag, click-then-claim, or
  1-3 + Enter), `set_referral_mode(on)`, `run_stamp()` (beat `referral_stamp`, RECHECK + OBJECTIVE TESTS
  + DOCTOR TODAY). `objection_cards()` builds the claim and clues from `board_sheet()`: the SRT-vs-PTA clue
  ("Hoot's recheck: SRT %d vs PTA %d" after a recheck) is always the best one, the coffee and canals
  captions stay neutral, and the verdict and `claim_note()` follow the direction.
  OBJECTION! slams in with `Events.screen_shake` and settles into a corner sticker; reduced motion
  keeps it still. Anchors: `word_card_<id>`, `familiarize_cue`, `objection_claim`, `clue_srt_pta`, `clue_coffee`,
  `clue_canals`, `referral_stamp`.
- **Daily Decibel:** headlines, subheads and the medal row (Chat, Explain, Words, Case, Next) for
  `mike`; with `audiometry.speech.srt` present, column 2 is the word golf card (per ear stored SRT,
  PTA, agreement chip with the gap, words vs par, golf) with half-words and Hoot's words in the facts line.
  - Golf cell: "no bracket" for an unbracketed player store, and "N slip(s)" / "no golf" for a bracketed
    player store with errors (`sheet.errors`, like the screen's "Oops!"). Hoot's rows and clean player
    stores keep the golf name.
  - C subhead: the most frequent slip (`SPEECH_C_SUBHEADS`, `speech_c_subhead()`). When misscoring tops
    it, `misscore_way()` (from the errors' `scored`) picks the `SPEECH_C_MISSCORED` line, generous or
    strict; a tie, or no direction on record, keeps the `SPEECH_C_SUBHEADS` line.
  - Under the card, `recheck_note(sp)` prints "Hoot's recheck: SRT N dB on the right, by the book (X
    agreement). Not graded." when `speech.recheck.srt.right` exists.
  - The legend (`agreement_legend()`, two lines) gives the bands and the direction: words better than
    beeps point to a non-organic loss; words worse, to instructions, language or word recognition.
  - Tone-only results keep the beep golf card.
- **Daily Decibel fit (any day):** `show_summary` settles the paper at `fit_scale(size, window)`: exactly
  1 when its tilted box fits the window's height, else scaled down to fit with 8 px to spare above and
  below. Papers that fit are unchanged; a tall one (masked golf rows plus three buttons, e.g. Days 2, 7
  and 8 in autoplay) no longer runs off the window.
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
- **(Clinical review A1 and A2, all days: Days 3 to 5.)** The cases' routine, in their words: `LevelMike.ROUTINE_LINE`
  (the morning listening check, the button, the dials out of view) once, seated, before the first tone test,
  and `LevelMike.SPECULUM_CAPTION` ("Fresh speculum. ...") on the otoscope card; Days 4 and 5 use both (Day 5
  as `HOOT["routine"]`). Ungraded, no new beat. Days 4 and 5 copy `level_case._recap` (the masking recap before
  the visit's first masked test while the movie is unseen, then Hoot's pointer; CONTRACTS.md §9.20); Day 3 masks
  nothing. These lines draw on `Game.rng` (Hoot's voice), so Days 3 to 5 replay with different seeded answers
  than before. Tests: each day's level test plays to the first tone test (Day 3) or the first masked test.

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

## Cases (Days 6 to 13, cases branch; CONTRACTS.md §11, docs/CASES.md)

The case files run in their own runner (`story/level_case.gd`) and touch other story files only additively.
Requests for the integrator and the title owner:

- **Day picker.** Each case chapter in `Game.CHAPTERS` carries `face` (the portrait speaker, e.g. `"Rocco"`) and
  `tint` (the card colour), which the Days grid uses. `Portraits` draws every case speaker (it falls back to
  `CasePortraits`).
- **Merge order.** The speech chapters (Days 3 to 5) and the cases (Days 6 to 13) both append to `Game.CHAPTERS`
  and `Game.PHASES` (speech: `familiarize`, `speech`; cases: `tymp`, `decision`, `retest`). Keep both blocks,
  speech first, and keep the exact `"case": "<id>"` spelling (`tools/case_scripts.py` finds the case order with a
  regex).
- **Daily Decibel golf rows.** `GOLF_EXTRA_ROWS` has left-ear masked rows too (Marina's and Skye's masked tests are
  on the LEFT ear). Its rows are now `[sheet key, ear]`: the old label column was never read (`_row_tag` draws the
  symbol) and its U+25A1 square is not in Fredoka, so it was dropped at the integrator's request.
  (cases follow-up) One-sided cases now put unmasked bone on the better ear only, as on Day 2, so Dash and
  Barnaby show the `L  >` row, and a new `["bc", "right"]` row (`R  <`, after `L  >`, hidden like it when that ear
  has masked bone) shows Marina's and Skye's right bone, and Rocco's and Ginger's.
- **Notice to builder B: `story/games/case_otoscopy.gd`** extends `otoscopy.gd` and overrides `_draw_canal` (it
  draws the wax plug or the fluid on top of your healthy drum), reading `view_center`, `ear` and `_canal`, and
  calls `show_clear`. It also copies your drum's geometry from `_draw_canal` (centre offset (-6, 6), radii 112 x 98,
  tilt -0.25, colour #c9c6cf, cone of light (8, 8) / (56, 74) / (26, 84)). Please keep those names, and tell us if
  the drum changes (or expose those numbers as constants and the cases will read them). The copies live in an inner
  class (`CaseLook`), so a constant you add to `otoscopy.gd` can never clash with them. The fluid bubbles also read
  your `_t` (the game-time clock `_process` keeps), so please keep that name too.
- **Retest and `Game.finish_visit`.** A case with a retest (Barnaby) calls `finish_visit` before the retest, so a
  player who quits during it keeps the day; `_results` reuses that summary (`tools/autoplay_bot.gd` checks it).
- **Tympanometer (shared with freestyle).** `story/games/case_tymp.gd` now prints "226 Hz probe tone" by its name
  and the adult canal band 0.6-2.0 mL (`CaseRules.TYMP_ADULT_ECV`, was 0.9-2.0); `CaseRules.ecv_band` no longer
  returns `&"low"` (the old 0.6-0.9 grey zone). Every freestyle canal volume is 0.9 mL or more (Viola's right ear is
  0.9, already NORMAL under the old `< 0.9` check), so no freestyle reading changes.
- **Otoscopy on both ears.** A case's first look shows the other ear first (`OTHER_EAR_CAPTION`), then the
  case's ear, so both ears are looked at before any probe or insert goes in (about two seconds longer).
- **Hoot's case movies (clinical review C12).** Three movies (`case_files`, `tymp`, `shapes`) for every case day.
  Additive changes to shared files: `story/explainers/movies.gd` registers them, gains an optional movie key
  `also_chapters` (`for_chapter` lists a movie on those chapters too; new `chapters_of(movie)`), and `day_label`
  reads "Days 6-13" for a movie on several days (one-day movies still read "Day 2"). `tools/autoplay_bot.gd` checks
  that a fresh save's case day starts all three (they play through the existing `explainer` beat, keys and mouse).
  Their sets live in `story/case_movies/`, so the stage is untouched. The title now has more than one movie, so
  its button opens the movie list (the existing `title_screen._on_movies` path): `tests/test_contracts_v4.gd`
  `test_title_movies_button` plays the list's first row when there are several (Days 4 and 5 hit the same thing).
  With E19, `Movies.for_level` now returns every replay movie whenever the level can mask (it used to only when the
  chapter had none of its own); otherwise the case days, which now have three of their own, would have lost the
  masking movie from their pause menu. `story/tests/test_freestyle.gd` `test_a_visit_pauses_to_the_masking_movie`
  asserted the old behaviour ("a day's own movie would win"); that line now checks the new one.
  `story/explainers/explainer_stage.gd` (two lines, via a new `_card_scene()`): a movie's own opening set with
  `params.card_hold` is entered like Day 2's "meet" (no iris over the curtains; the scene chip waits for the card).
  Only scenes with `card_hold` change, so the masking movie looks exactly as before.
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
- **Day 12, the shadow curve (clinical review C10).** Morgan's deaf right ear sits past the dial, so masked bone and
  masked air store no response; the unmasked air is the left ear's shadow. Shared-file changes, both small:
  `core/patient_profile.gd` validate allows air up to `max_db(f) + 30` (see `core/INTEGRATION_NOTES.md`), and
  `ui/audiogram/audiogram.gd` draws no pen line through a frequency whose masked air mark is no response (see
  `ui/INTEGRATION_NOTES.md`). `tools/autoplay_bot.gd` (additive): `_check_v3` accepts a no-response stamp when the
  truth lies past it, and `_check_dead_ear_case` reports `shadow` and `case_ear_type` and checks the masked sheets.
  The case movies list Morgan in `also_chapters`. Freestyle and Days 1-11 are unchanged: no other patient goes past
  the dial, and only a masked no-response mark changes a line.
- **Day 13, the masking dilemma (clinical review C9).** Bev has big air-bone gaps in both ears, so masked bone opens
  in a dilemma; before the first one the runner says the case's `on_dilemma` lines and, when the player owns none,
  lends Hoot's inserts for the visit (a runner flag and visit flags `dilemma_told` / `lent_inserts`; the save's
  upgrades never change). One shared-file change, small: `ClinicRules.masked_freqs_needed` judges each air stamp
  with the transducer it records (`info.transducer`), the param only as the fallback, so headphone-measured air
  still needs masking by the headphones' rule after the loan (see `core/INTEGRATION_NOTES.md`). A visit that keeps
  one transducer, which is every other day and Freestyle, gets the same answers as before. `tools/autoplay_bot.gd`
  (additive): `_check_dilemma_case` checks both ears conductive with the red flag, the purple ? at 500 Hz and 1 kHz
  (at 2k / 4k only after a missed beep), masked air where the rules ask, the dilemma lines and the loan.
  `tools/monkey.gd` mirrors the loan. The case movies list Bev. `story/games/case_props.gd`: a wax-jar sparkle under
  a pixel wide is skipped (its star polygon could fail to triangulate, an engine error that flaked
  `test_new_gadgets_draw_every_view`).
- **Day 13's dilemma movie (CASES.md question 26).** Hoot's "The Masking Dilemma"
  (`story/explainers/movies/dilemma.gd`, its own sets in `story/case_movies/dilemma_sets.gd`) plays after Bev's
  `on_dilemma` lines and before the loan, while unwatched. Shared files, additive: one line in `Movies.MOVIES`; a
  case key `dilemma_movie` (`CaseData.TOP_TYPES`, validated: needs `on_dilemma`, a registered movie; case_data.gd
  now preloads movies.gd); `LevelCase._movie(id, lead_in)` takes an optional lead-in (always played, never an
  offer) and `DILEMMA_MOVIE_LEAD_IN`; `tools/autoplay_bot.gd` `_check_dilemma_case` also checks the movie started
  on a fresh save. Its chapter is `bev`, so it is not one of the "Days 6-13" case movies (`CASE_MOVIES` keeps its
  three) and the masking-level pause menus list it with the others. No new data files: the Web preset needs nothing.
- **Words before a FIT (clinical review C13 and A4).** A case with `speech_check` (`{"ears": [...], "after": script}`;
  Rocco and Ginger) adds the HUD's Words step after the tones: Hoot runs the SRT and a word score on each ear, then
  one unaided Party Noise Test list (`SpeechRules.SIN_LISTS[0]`, slot `both`), with `SpeechScreen.run_hidden` (Day 5's
  montage; `SpeechSession.run_by_textbook` without the screen). Hoot's sheets are unscored (`units` 0), so
  `merge_results` keeps the tone grade. `LevelCase.speech_lines(res, ears)` and `speech_clues(res, ears)` are static
  and read only `res.speech`, so **freestyle's FS-13 can reuse them** after its own hidden runs: the lines never hint
  at the call. Marina's payoff gains the "hearing nerve" line. `ui/speech/speech_screen.gd`: `run_hidden` names
  the patient in the bubble (see `ui/INTEGRATION_NOTES.md`).
- **Tests:** `story/tests/test_cases.gd` (52 tests). `tools/run_tests.sh` runs `python3 tools/case_scripts.py
  --check` after the full suite, so a stale `docs/CASE_SCRIPTS.md` fails the run (skipped under `--filter`, and only
  a warning without python3).

## Merge: main (Days 3, 6-9) into the Day 2 feedback (v4)

- **Daily Decibel golf rows.** `GOLF_EXTRA_ROWS` is the union of both sides: v4's `["bc", "L  >", "left"]` first
  (Day 2's unmasked bone on the better, left ear), then `R  [`, `R  O+`, and the cases' `L  ]`, `L  □`. A row only
  shows when that sheet has stamps, so Day 1 and Day 3 show none, Day 2 shows `L  >`, `R  [`, `R  O+` as on the
  feedback branch, and Rocco, Dash and Ginger as on main. Marina (her bone is tested on her left ear) shows only
  her `L  ]` and `L  □` rows: the `L  >` row hides when that ear has a masked-bone sheet. (cases follow-up: her
  unmasked bone is now on the right, the new `R  <` row; see the golf rows note in the Cases section.) (cases, PR #3) The rows
  are now `[sheet key, ear]`; `_row_tag` draws the symbol.
- **Pause corner.** Hidden while the AudiOtron, the SPEECH screen (Speech) or one of Hoot's movies (v4) is up.
- **Hoot's movies** stay Day 2 only: Days 3 and 6-9 have no movie, and their pause menu shows no movie button
  (the title's Options and its "Hoot's Movies" button still offer the masking movie on any save). **(clinical
  review S7)** Day 3 now opens with Hoot's spondee movie (`level_mike._movie`, as Day 4's), and its pause menu
  offers "Watch Hoot's spondee movie".

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

## Arcade: Chart Chute (arcade branch; docs/ARCADE.md)

Everything is in `story/arcade/` plus its tests in `story/tests/`. Changes to shared files are additive:

- **Title menu.** An **Arcade** button after Freestyle, sharing its row (as Options and Quit share theirs), so a
  returning player's seven buttons still clear the safety footer. `test_title_menu_clears_the_footer` now expects
  seven buttons.
- **Game.DEFAULT_PROGRESS** gained `"arcade": {}` (mode -> {table, runs, found, initials}; `story/arcade/arcade_scores.gd`).
- **New beats (CONTRACTS.md §3.2 table):**
  - `chute_sort`: chart_chute. Info {shape, options, best, mouse: {click: "chute_<shape>"}}. The solver sorts into the right chute.
  - `arcade_initials`: chart_chute's results. Info {mouse: {click: "arcade_initials_ok"}}. The solver enters BOT.
  - `arcade_results`: chart_chute's results. Info {options, best, mouse: {text: "Back to the arcade"}}. The solver goes to the arcade hall (it went to the title before the hall existed).
- **Autoplay bot.** It is not used for the arcade, because its `_finish` expects a visit's `results_continue`. The
  arcade has its own harness, `story/tests/arcade_chute_check.tscn` (tools/README.md).
- **Reused:**
  - `ClinicRules.classify_shape`, `combo_multiplier`, `required_interoctaves` and `clamp_db`.
  - The Audiogram and `CasePortraits.register` (for the belt's made-up patients).
  - `Game.load_patient` for the story charts of Gus, Rocco, Ginger and Marina.
- **Audiogram `dim` fix (shared file, a bug fix).** `ui/audiogram/audiogram.gd` documents `dim` as fading an ear's
  marks, but it only faded the symbols: the pen lines and the stamp splats stayed full strength. Both now multiply by
  the same fade (two lines). `case_board.gd` and `day2_board.gd` use `dim` too; their dimmed ear now looks dimmed all
  the way through, which is what their comments already describe.
- **Story charts need their Day.** `ChartDeck.golden_pool()` reads `Game.is_chapter_done()`: Gus, Rocco, Ginger and
  Marina's own charts only ride the belt once Days 1, 6, 9 and 7 are finished, so the arcade never shows a Day's
  pattern (or Marina's clue) first.
- **Wide and tall windows.** The scene keeps its 1280x720 playfield centred with `get_viewport_rect()` and the
  `size_changed` signal (the desktop stretch aspect is `expand`); the wall, floor, top band and belt fill the rest.
  The web build's `keep` aspect needs nothing extra.
- **Engine gotcha.** A typed dictionary const such as `Dictionary[StringName, PackedStringArray]` keeps its array
  literals as plain Arrays. Indexing one through a `PackedStringArray` variable crashes Godot 4.7.2 (signal 11). For
  such tables, use an untyped `Dictionary` and read the values as `Array`. The same goes for a const
  `Array[PackedStringArray]` of literals (Ears, Please!'s patient lines are a plain `const LINES: Array`).

## Arcade: the hall and Ears, Please! (arcade branch; docs/ARCADE.md part 2)

Everything is in `story/arcade/` plus its tests in `story/tests/`. Shared files:

- **Title menu.** `title_screen.gd`'s `ARCADE_SCENE` now opens `story/arcade/arcade_hall.tscn` (was Chart Chute
  directly); the button and its row are unchanged.
- **Chart Chute** (arcade-owned) now ends on "Back to the arcade [T]", which opens the hall.
- **ArcadeScores** gained an optional `board` argument on `table`, `qualifies` and `add_score` (default `"table"`,
  so Chart Chute is unchanged) and `BOARD_SEEDS` for boards with their own starting rows. Ears, Please! keeps one
  board per shift (`table`, `table_2`) plus `unlocked` and `warmed` in `Game.progress["arcade"]["ears_please"]`.
- **New beats (CONTRACTS.md §3.2 table):**
  - `arcade_hall`: the hall. Info {options, best, mouse: {click: "arcade_cabinet_<id>"}}. The solver opens Ears, Please!.
  - `desk_shift`: the shift picker. Info {options, open, best, mouse: {click: "desk_shift_<n>"}}. The solver picks the newest open shift.
  - `desk_stamp`: a file waits for a stamp. Info {file, options, best, decision, kind, boss, warmup, mouse: {click: "desk_stamp_<stamp>"}}. The solver stamps the right call.
  - `desk_prove`: PROVE IT. Info {file, stamp, target, anchor, count, mouse: {click: <anchor>}}. The solver points at the best proof.
  - `desk_note`: a feedback note holds the clock. Info {title, mouse: {click: "desk_note_ok"}}. The solver closes it.
  - `arcade_initials` and `arcade_results` as for Chart Chute.
- **Harness.** `story/tests/arcade_desk_check.tscn` (tools/README.md); `arcade_chute_check` now also walks through
  the hall (`--via-title` picks cabinet 1, and the results' T must reach the hall).
- **Reused:** `CaseRules` (`RED_FLAGS` ids, `is_asymmetric`, `SUDDEN_*`, `DECISION_STAMPS`), `ClinicRules`
  (`abg_red_flag`, `ABG_RED_FLAG_DB`, `ac_masking_needed` and `bc_masking_needed` for charting, `combo_multiplier`, `required_interoctaves`),
  the Audiogram (`show_gap` for the gap tell), `CasePortraits.register` and `Portraits.draw`.
- **No new data files**, so the Web preset's include_filter needs nothing.
- **Shift 3 (DOCTOR TODAY), a later PR:** arcade-owned files only. The third stamp opens, every shift 3 file
  carries the alarm-clock card (anchor `desk_sudden`; `desk_prove` can now carry target {kind: "sudden"}), two
  missed same-day patients close the desk, and `ArcadeScores.BOARD_SEEDS` gains `ears_please:table_3`. No shared
  file changes and no new data files.

## The fitting (Day 14; cases branch; docs/FITTING.md, CONTRACTS.md §13)

- **Game.CHAPTERS** gains `gus_fit` (Day 14, patient `gus_fit`: chapter id = patient id, `requires: "bev"`, face Gus). **Game.PHASES** gains
  `aid_style` and `real_ear`. Both additive, after every existing entry.
- **New beat** `fitting_target` (CONTRACTS.md §3.2 table): info {}, the solver matches each band in one move and
  presses Done.
- **tools/autoplay_bot.gd** (additive): the mouse route for `fitting_target` (each band's + or - button, then
  Done), and on the `gus_fit` chapter `_check_fitting` replaces the per-ear check (the day tests no ears). The
  report gains `fitting` {errs, moves, par, style_tries, overshoots, medals}.
- **Clinic**, used as is: `put_on_hearing_aids`, `set_world_saturation` (0 to 1 as bands match; the last one
  crosses 0.6, which plays the birdsong), `doris_enter`, `doris_react`, `gus_look`, the `fitting` and
  `fitting_close` shots.
- **The Daily Decibel**, used as is: the summary's headlines, subheads, medal_beats, weather and
  `sports_script` (`story/papers/paper_fitting.gd`).
- **No new data files** (a .tres, .tscn and .gd only), so the Web preset's include_filter needs nothing.
- **PR 2** (the probe tube, the loud-sound check, the counselling): **Game.PHASES** gains `probe_tube` and
  `loud_check` (additive; the counselling uses Days 4-5's `counselling`). **New beats** `probe_tube` and
  `loud_check` (CONTRACTS.md §3.2), each with a mouse route in the bot (the In button then Lock; the dial's - or
  + then Drop). `_check_fitting` also wants a probe, loud and counsel medal; the report gains probe_mistakes,
  loud_drops and counsel_slips. `LevelFitting.results_for(right, picks, left)` now takes a picks dictionary.
  Still no new data files.


## The tune-up (Day 15; cases branch; docs/TUNEUP.md, CONTRACTS.md §15)

- **Game.CHAPTERS** gains `gus_tune` (Day 15, patient `gus_tune`: chapter id = patient id, `requires: "gus_fit"`,
  face Gus). **Game.PHASES** gains `datalog` and `tune_desk` (the opening question uses `history`). Both additive.
- **New beat** `tune_desk` (CONTRACTS.md §3.2): info {ticket}, the solver uses the ticket's right tool.
- **tools/autoplay_bot.gd** (additive): the mouse route for `tune_desk` (a click on the right tool), and on the
  `gus_tune` chapter `_check_tuneup` replaces the per-ear check like Day 14's. The report gains `tuneup`.
- **Clinic and CaseProps**, used as is: `walk_in`, `put_on_hearing_aids`, `doris_enter`, `doris_react`,
  `gus_look`, `hoot_emote`, the `fitting` shot, and CaseProps' `later` card ("TWO WEEKS LATER").
- **No new data files** (.tres, .tscn and .gd only), so the Web preset's include_filter needs nothing.
- **Part 2**: **Movies.MOVIES** gains `tuneup` (one line). **Game.PHASES** gains `listening_check` (additive).
  **New beat** `wax_guard` {step} with a mouse route in the bot; `_check_tuneup` also wants the `check` and `plan`
  medals. Still no new data files.

## The career-fair demo (cases branch; docs/DEMO.md, CONTRACTS.md §14)

- **Game** (additive): `is_demo()` (`--demo`, or `?demo` in the web page's address: `_parse_cli()` reads
  `window.location.search` on the web only, and only the names in `WEB_FLAGS`), `reset_demo_visitor()`
  (progress back to `DEFAULT_PROGRESS`, settings kept), `DEMO_SAVE_PATH` (`user://demo_save.json`, after autoplay
  and `--scene=` in the save-path order; `--save=` still wins). Demo mode sets `cli["quick"]` unless `--full`.
- **title_screen.gd** (additive): in demo mode the menu is one Play button (`_on_demo_start()`, the `title_start`
  solver, goes to `DEMO_SCENE` = `res://story/level_demo.tscn`), with `DEMO_TAGLINE` under it, no movies button
  and no stats; the safety notice shows for every visitor; `_ready()` calls `Game.reset_demo_visitor()`. Outside
  demo mode nothing changes.
- **New level** `story/level_demo.gd` (patient `gus`, so it scores as Day 1 in the demo's own save). Reuses
  `LevelGus.HISTORY[0]`, Day 1's otoscopy, earphones and reveal, and Day 14's TargetMatch and
  `LevelFitting.match_medal` / `SAT_BY_MATCHED`, unchanged. Phases: intro, history, otoscopy, earphones,
  audiometry, reveal, real_ear, results (all existing). No new beats.
- **Audiometer plan key** `montage_after` (ui/INTEGRATION_NOTES.md).
- **tools/autoplay_bot.gd** (additive): `_check_demo` when the summary has `demo: true` (the four medals, the
  right ear's bands within 5 dB, no next day, "Next visitor"); the report gains `demo` {medals, errs}.
- **tools/export_win.sh**: the delivery zip also carries `BoothCamp-Demo.cmd` (from `tools/booth/`). Steve's
  build folder needs it next to `BoothCamp.exe` to start the demo with a double-click.
- **No new data files** (.gd, .tscn and a .cmd outside the export), so the Web preset needs nothing.
- **(demo polish)** **daily_decibel.gd** (additive): a summary with `demo: true` hides the coins and the shop (B buys
  nothing) and moves the WANTED ad to the bottom row. **title_screen.gd** (additive): in demo mode (not under
  autoplay) the title adds `story/demo_attract.gd` and starts it after `attract_after()` seconds with nobody there
  (`ATTRACT_S` 30, `--attract-after=N`), hiding the menu and the notice; a key, click or mouse movement ends it and the
  notice shows. CONTRACTS.md §14.

## The Training room and Masking School (docs/training/MASKING_TRAINER.md)

- **title_screen.gd** (additive): a **Training** button shares a row with Days (`_on_training()` goes to
  `TRAINING_SCENE` = `res://story/training/training_room.tscn`); the menu keeps its rows, so a returning player's
  eight buttons still clear the footer. "New player" also wipes `training`.
- **Game** (additive): `DEFAULT_PROGRESS["training"]` = {} (lesson -> {stations: {id: {best, star, plays}}, cards}),
  read and written only through `story/training/training_progress.gd`.
- **New scenes**: `story/training/training_room.tscn` (the cork board: lesson card, station chips 1-6, pinned
  cheat-sheet cards), `story/training/masking/masking_school.tscn` (one station: Hoot's card, Try it, a six-hole
  round, the scorecard). The room sets `MaskingSchool.next_station`; `--scene=...masking_school.tscn --station=why`
  boots one station directly. The station draws on Hoot's movie stage through the sets hook
  (`story/training/masking/school_sets.gd`, sets `who_heard`, `when_card`, `start_dial`, `plateau_walk`, `pe_open`, `pe_ear`, `pe_masker`, `oe_count`, `pocket_card`), so no
  shared stage edit. Built: 1 why (who heard it?), 2 when (mask it?), 3 start (set the dial), 4 plateau (walk it), 5 occlusion (plug lab, does it count?, the pocket card), 6 exam (nine mixed holes, each card's `rules` key picks the station whose rules it plays by; no Try it; hint locked on a first try; grade `MaskDeck.exam_grade`); a new station is a `MaskDeck.STATIONS`
  entry with `built: true` plus its branches in `masking_school.gd` (`_tries`, `_deal`, `try_step`).
- **Rules** live in `story/training/masking/mask_deck.gd` and read `ClinicRules` only (`ia_rule`,
  `ac_masking_needed`, `bc_masking_needed`, `initial_masking`, `occlusion_effect`, `OCCLUSION_DB`, `next_mask_step`, `plateau_run`, `overmask_limit`,
  `masking_dilemma`, the plateau numbers).
- **Beats** `training_room`, `training_intro`, `training_try`, `training_card`, `training_next`,
  `training_scorecard` (CONTRACTS.md §3.2), and phases `training_room`, `training` (emitted, not in `Game.PHASES`'
  visit flow). A first visit to station 1 plays Hoot's masking movie (source `"training"`).
- **movies.gd** (additive): registry line `"plugged_ear"` (`story/explainers/movies/plugged_ear.gd`, chapter `bonnie`,
  stage `school_sets.gd`, `"training": true`), the lead-in of Station 5. `Movies.is_training`: a training movie is never a chapter's own (`for_chapter`), so Day 2 keeps its one movie; it shows on the title's list labelled "Training". `TrainingProgress.record_round(..., star_ok)`: a par round
  earns the star only when `star_ok` (Station 5: a blank pocket card).
- **New files (PR 6)**: `story/training/diploma.gd` (the diploma stamp, drawn on the exam's scorecard, the lesson
  card and the print view), `story/training/print_view.gd` (the room's print view; P or the PRINT VIEW tile once all
  five cards are earned; "Save picture" = a PNG in Documents/BoothCamp, user:// as a fallback, a download on the web),
  `story/training/oe_chip.gd` (the AudiOtron's OE chip). `cheat_card.gd` shrinks a long line to fit.
- **ui/audiometer/audiometer_screen.gd** (additive): `OeChip` preload and `_oe_chip`, built with the deck, shown with
  the MASKING group (`_mask_deck`) once `OeChip.earned()` (the save's `training.masking.cards` has `occlusion`, read
  without writing), placed at the right end of the MASKING label in `_layout_deck`. It takes no keys.
- **title_screen.gd** (additive): the stats line adds "Masking diploma: <grade>" once the exam is finished (read
  straight from the save, no writes).
- **Bot**: `story/tests/training_check.tscn` (tools/README.md); `story/tests/training_shots.tscn` shoots the room
- **(practical) The Practical**, the Training room's second lesson (docs/training/PRACTICAL_EXAM.md, research in
  docs/training/CA_PRACTICAL_EXAM.md). `training_room.gd` gets two lesson tabs under the sign (MASKING SCHOOL,
  THE PRACTICAL; Tab or a click switches; `TrainingRoom.lesson` remembers it for the session, Masking School first).
  The board, chips (eight, two columns of four, SOON under the number) and pins follow the tab; the print view stays
  Masking School's. New: `story/training/practical/practical_deck.gd` (stations, cards, generators; the bulletin's
  numbers named there: `CAL_MONTHS`, `SANITIZER_MAX_OZ`, the subject rules), `practical_art.gd` (the cards' drawings),
  `practical_school.tscn` + `.gd` (the station loop on its own drawn stage, beats `practical_*`), save lesson
  `"practical"` through `TrainingProgress`. Built: 1 kit ("Pack the bag": what stays home, the calibration sticker,
  the listening check, the subject). A new station is a `PracticalDeck.STATIONS` entry with `built: true` plus its
  `deal`/`tries` branches and its card kinds in `practical_art.gd`. Bot `story/tests/practical_check.tscn`. No new
  data files.
  with the diploma, the print view and its saved PNG, and the AudiOtron's chip. **No new data files**, so the Web preset needs nothing.
