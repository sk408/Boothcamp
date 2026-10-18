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

## Speech (Day 3: Mike)

- **Level:** `story/level_mike.tscn` (`level_mike.gd`), chapter `mike`. Phases: `intro`, `history`,
  `otoscopy`, `instructions`, `audiometry` {right, ac} / {left, ac}, `familiarize`, `speech`
  {ear, test: "srt"} (right coached, then left), `evidence`, `referral`, `results`. Medals: `history`,
  `otoscopy` (always gold, not on the paper), `instructions`, `familiarize`, `evidence`, `referral`.
- **Tones:** Hoot runs both ears on the AudiOtron (`hoot_turn_after` 0, coached false). The AudiOtron
  only starts Hoot's turn at once with quick visit on, so the level sets the screen's public
  `quick_visit = true` right after `add_child` (see the request below).
- **SPEECH screen:** one instance for both ears (`start_test(patient, ear, coached, plan)`, then
  `await test_finished`); plan `{test: "srt", tones, list: "spondee_a", words: the 12 familiarised ids,
  exclude: ["windmill"] once dropped, transducer, intro}`, plus `hoot_turn_after: 4` on the left ear
  with quick visit on. Mike's response button is put away first (`hold_response_button(false)`).
  Hoot's "the tell" tip ("He's repeating words N dB below his beeps. Hmm!") fires once on the first
  correct word 30+ dB below that ear's PTA (`Events.speech_response`). If the SPEECH scene is missing,
  Hoot runs the words himself through `SpeechSession` (`LevelMike.hoot_runs_ear`, not scored).
- **Board** (`story/games/mike_board.gd`, story-internal): `run_cards(items, title)`,
  `read_along(from, to, s)`, `stumble(id)`, `run_drop(id)` (beat `familiarize_cards`, info
  `{targets: ["word_card_windmill"], mouse: {click: "word_card_windmill"}}`, solver drops it; other cards
  are slips with a kind tip), `show_objection(claim, clues)`, `run_objection()` (beat `objection_present`,
  info `{targets: ["objection_claim"], mouse: {drag: ["clue_srt_pta", "objection_claim"]}}`, solver
  presents the strongest clue; a weaker one gets a Hoot nudge and a retry; drag, click-then-claim, or
  1-3 + Enter), `set_referral_mode(on)`, `run_stamp()` (beat `referral_stamp`, RECHECK + OBJECTIVE TESTS).
  OBJECTION! slams in with `Events.screen_shake` and settles into a corner sticker; reduced motion
  keeps it still. Anchors: `word_card_<id>`, `objection_claim`, `clue_srt_pta`, `clue_coffee`,
  `clue_canals`, `referral_stamp`.
- **Daily Decibel:** headlines, subheads and the medal row (Chat, Explain, Words, Case, Next) for
  `mike`; with `audiometry.speech.srt` present, column 2 is the word golf card (per ear stored SRT,
  PTA, agreement chip with the gap, words vs par, golf) with half-words and Hoot's words in the facts
  line. Tone-only results keep the beep golf card.
- **Shared story bits:** Mike's portrait (`portraits.gd`), display name "Mike \"Totally Deaf\"
  Lenders", a gruff voice (f0 105 Hz), Days cards that shrink to fit up to six days in one row
  (`_card_size(n)`), faces and tints for `mike`, `nora`, `marco`. The HUD tracker, the Hoot notes
  and the pause corner hide in the `speech` phase like in `audiometry`.
- **Note:** CHAPTER3.md names Mike's favourite forklift with what reads like a real product name;
  the level uses "Old Rumbles, bay six" instead (originality rule).
- **Screenshots (Day 3):** `day3_familiarize`, `day3_objection`, `day3_stamp`, `day3_goodbye`,
  `day3_glazed`.
- **Tests:** `story/tests/test_level_mike.gd` (board beats, keyboard paths and solvers, the plans and
  objection cards with real numbers, Hoot's textbook fallback, the Day 3 paper, a smoke run to the
  instructions).

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
