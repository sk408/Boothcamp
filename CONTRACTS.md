# Booth Camp: module contracts

This is the API that lets four people build in parallel without editing each other's files.
If code and this file disagree, the integrator decides which one is right and then fixes the other.
Section numbers (§) are referenced from code comments. Keep them stable.

Engine: Godot 4.7.2, statically typed GDScript, Compatibility (OpenGL) renderer, 1280x720 base,
`canvas_items` / `expand` stretch, resizable window. Main scene `res://main.tscn`.

---------------------------------------------------------------------------------------------

## §1 Rules for parallel work

### §1.1 Ownership

| Path | Owner | Contents |
|---|---|---|
| `core/**` | builder A | `PatientProfile`, patient data, patient simulator, tone generator, audiometry logic and technique checker |
| `ui/**` | builder A | AudiOtron 3000 screen (`ui/audiometer/`), Audiogram widget (`ui/audiogram/`) |
| `world/**` | builder B | 3D clinic, Gus, Hoot body, cameras, reactions, shaders |
| `story/**` | builder B | title, level director, dialogue, micro-games, Hoot bubble view, pause menu, results paper |
| `autoload/**`, `main.tscn`, `main.gd`, `tests/**`, `tools/**`, `project.godot`, `export_presets.cfg`, `assets/**`, `CONTRACTS.md` | foundation, then integrator | shared services, harness, contracts |
| **(Speech)** `core/speech/**`, `ui/speech/**`, `story/level_mike.*`, `story/games/mike_board.gd` | speech thread | Day 3: the SPEECH screen and its logic (§9) |
| **(cases)** `story/cases/**`, `story/level_case.*`, `story/case_*.gd`, `story/games/case_*.gd`, `core/cases/**` | cases thread | Days 6-13: the case files and their runner (§11) |
| **(Days 4-5)** `story/level_nora.*`, `story/games/nora_board.gd`, `story/papers/paper_word_golf.gd`, `story/explainers/movies/letter_choir.gd`, `story/explainers/stages/letter_choir_sets.gd`, `core/patients/nora.tres` (Day 5's files come with its PR) | speech thread | Days 4-5: word lists and the Party Noise Test on the SPEECH screen (§9.10-§9.24; every owner in §9.23.1) |

**Export presets.** `export_presets.cfg` has two presets, "Windows Desktop" and "Web" (Steve's, 2026-10-19; `.github/workflows/pages.yml` deploys the web build to GitHub Pages on every push to main). A run-time data file that is not a Godot resource (patient and case JSON, word lists) must be in BOTH presets' `include_filter`, or the exported game runs without it.

The foundation stubs in `core/`, `ui/`, `world/` and `story/` have been replaced by the builders' real modules
(integrated 2026-10-17). Owners may keep changing their internals, but must keep the public API in this file.
Contract changes from that integration are marked **(v2)**.

**(v3) Chapter 2** (Day 2, Bonnie Bunsworth: bone conduction + masking; design in `docs/CHAPTER2.md`) adds
chapters (every day open, polish), bone and masked tests, the masker, and the Day 2 level. Every v3 change is marked
**(v3)**. Day 1 behaves exactly as before: every v3 parameter has a default that reproduces v2.
Additions from the Chapter 2 builders, merged at integration, are marked **(v3, builders)**.

**(v4) Day 2 feedback** (Steve's review; design in `docs/CHAPTER2.md` §3, §16) changes only Day 2 and adds one
shared feature. Every v4 change is marked **(v4)**:
- **Bone on the better ear first.** Unmasked bone is tested on Bonnie's LEFT mastoid (`>` marks), then a
  one-tone **Ghost demo** on the right mastoid (plan key `demo_tone`, nothing stored), then masked right bone and
  masked right air as before. Placement game: `bc_placement` names its target (`mastoid_target_left` / `_right`).
- **Hoot's movies** (`story/explainers/`, §3.4): short, skippable, replayable in-engine cartoons. Day 2 opens with
  "Hoot's masking movie"; the pause menu replays it. New phase `explainer`, beat `explainer`, three `Events`
  signals, `Game.progress.movies_seen`.

Day 1 is unchanged (no movie, its pause menu shows no movie button). `tests/test_contracts_v4.gd` checks the v4 API.

**Merged with main** (the speech chapter, Day 3, §9, marked **(Speech)**; the patient cases, Days 6-9, §11, marked
**(cases)**): those days have no movie either and play exactly as on main. The v4 bone rules (`unmasked_bone()`,
the either-mastoid masked bone start) give the same answers there, since each case measures unmasked bone on one ear only.
**(cases follow-up)** One-sided cases now rely on that rule, as Day 2 does: unmasked bone on the better ear only, then
masked bone on the case ear (§11).

### §1.2 How modules may touch each other

- **Across modules, use only:**
  - the autoloads (`Events`, `Game`, `Hoot`, `Stage`, `Sfx`);
  - the shared static classes (`ClinicRules`, `AudioSafety`, `Palette`, `UiDraw`, `Juice`);
  - the contract types `PatientProfile` and `Audiogram`;
  - scenes loaded **by string path**, whose methods are called by name (`node.call("start_test", ...)`, `await node.test_finished`).

  Do not reference another module's other `class_name`s, preload its scripts, or reach into its child nodes.
- **Don't edit another owner's folder.** If you need a change in someone else's API, write it in
  `res://<their module>/INTEGRATION_NOTES.md`, for example `res://ui/INTEGRATION_NOTES.md`. Say what you need and why.
  Work around it on your side until the change lands.
- **Global signals live only in `autoload/events.gd`.** Signals internal to a module stay in that module.
- **Every module-owned test** goes in `res://<module>/tests/test_*.gd` and extends `TestCase`. The
  runner finds it automatically (§7.4).
- **Use scaled game time** (`delta`, `get_tree().create_timer()`, tweens, `Game.clock`), never
  `Time.get_ticks_msec()`, for gameplay. The bot runs at `--speed=6` and the tests use fixed fps.
- **No blocking dialogue while the audiometer accepts input.** Use Hoot tips (§8) during audiometry.
  `DialogueBox` and the micro-games would steal Space and Enter.
- **Buttons must not take keyboard focus** (`focus_mode = FOCUS_NONE`). Otherwise Space, which presents the
  tone, would click them. Every control must also work with the mouse.
- **Static typing everywhere.** In 4.7, `var x := f()` where `f` returns `Variant` is a compile error.
  Write `var x: Variant = f()`.
- **Inputs are always these types:**
  - ears: the Strings `"right"` and `"left"`;
  - frequencies: `int` Hz from `ClinicRules.AC_FREQS` (bone: `ClinicRules.BC_FREQS`, 250-4000);
  - levels: `int` dB HL on the 5 dB grid; **(v3)** masker levels: `int` dB EM on the 5 dB grid, 0-100;
  - kinds and phases: `StringName`; **(v3)** tests `&"ac"`, `&"ac_masked"`, `&"bc"`, `&"bc_masked"` and
    transducers `&"phones"`, `&"inserts"`, `&"bone"` are `StringName` too.

### §1.3 Safety and originality (hard rules)

- **No vendor material anywhere players can see it:** names, logos, icons, screenshots, sounds, fonts (no
  Tahoma). `tests/test_vendor_free.gd` fails on vendor names inside string literals. The fictional audiometer is the
  **AudiOtron 3000**. The internal setting ids `"otosuite"` and `"affinity"` are allowed. Labels say
  "Up = LOUDER (default)" and "Up = SOFTER (swapped)".
- **Clinical conventions are fine:** red O for the right ear, blue X for the left ear, ASHA symbols, Hughson-Westlake.
- **Tone level:**
  - Every tone is synthesized.
  - Displayed dB HL is **simulated**.
  - All tone levels go through `AudioSafety.hl_to_peak()` and `AudioSafety.clamp_sample()`. The mapping is about -75 dBFS at 0 dB HL, plus 0.6 dB per dB HL,
    and the peak never goes above **-12 dBFS**. Tones get `TONE_BOOST_DB` (4 dB) on top, about -71 dBFS at 0 dB HL (clinical
    review E7); masking noise and words keep the base mapping.
  - (E7) The audiometer screen starts on **pulsed** tones; the stimulus key cycles pulsed, warble and steady.
  - Bus limiters back this up: Tones -12 dB, Master -6 dB (`default_bus_layout.tres`).
  - Sfx are normalized to a -18 dBFS peak.
- **(v3) Masking noise:** synthesized narrow-band noise (white noise through a 1/3-octave band-pass at the
  test frequency) in the non-test ear only. Its level comes from `AudioSafety.masker_to_rms(db_em)` (the tone
  mapping minus 6 dB, RMS capped at **-24 dBFS**), every sample goes through `AudioSafety.clamp_masker_sample()`,
  with 50 ms ramps. Overmasking is a visual gag.
- **(v3, builders) Bone tones** play in the test ear's channel and, `ToneGenerator.BONE_CROSS_DB` (-10 dB) softer, in
  the other channel too ("bone has no interaural attenuation"), through the same `hl_to_peak()` mapping and
  `clamp_sample()`. Air tones stay one-channel. `tools/movie_check.sh --day=2` measures both (§7.1).
- **"Too loud" gags are visual only:** shake, hair blast, Hoot. Never play a loud sound.
- **Every tone lights an on-screen indicator** (the TONE lamp) and every patient press lights the PRESS
  lamp. **(v3)** Every masker lights the NOISE box on the LCD and the squiggles in the booth window, and fires
  `Events.masker_changed`. Nothing depends on the player hearing the tone or the noise.
- **The patient's answers come from the simulator** (`core/`), never from the player's ears.
- **The start of the game shows the notice "This is a game, not a hearing test."** (title screen, phase `disclaimer`).
- **(Speech) Speech audiometry** (Days 3-5) follows the same rules: original material only, every word lights the
  TALK lamp, levels go through `AudioSafety.speech_to_rms()` and noise through the masker mapping (§9.6).

---------------------------------------------------------------------------------------------

## §2 Autoloads and shared classes

Autoloads, in order: `Events`, `Game`, `Sfx`, `Hoot`, `Stage` (`project.godot`).
Static classes (`class_name`, no node) in `autoload/`: `ClinicRules`, `AudioSafety`, `Palette`, `UiDraw`, `Juice`.

### §2.1 Events (`autoload/events.gd`)

The global signal bus. Each signal's emitter and payload is documented in the file. Summary:

| Group | Signals |
|---|---|
| flow | `goto_scene(path)`, `scene_changed(path, node)`, `phase_changed(phase, info)`, `level_started(patient_id)`, `level_finished(summary §5.3)`, `awaiting_input(beat, info, solver)`, `input_resolved(beat)`, `screenshot_requested(shot_name)`, `pause_toggled(paused)`, `quit_requested(exit_code)` |
| settings | `settings_changed(key, value)`, `key_style_changed(style)`, `comfort_changed(hearts, reason)`, `coins_changed(total, delta)` |
| dialogue | `dialogue_line(speaker, text)` |
| Hoot | `hoot_say(text, priority, ghost_hand_target)`, `hoot_tip_shown(tip)`, `hoot_tip_dismissed(tip_id)`, `hoot_mastered(skill)` |
| audiometry | `audiometry_started(patient_id, ear, coached)`, `tone_started(ear, freq, db)`, `tone_stopped(ear, freq, db, duration_s)`, `patient_responded(ear, freq, db, tone_related)`, `audiometer_state_changed(state §4.3)`, `threshold_stored(ear, freq, db, info §4.4)`, `technique_event(kind §4.5, data)`, `combo_changed(n, multiplier)`, `ear_completed(ear, ear_results §5.1)`, `audiometry_finished(results §5.1)` |
| world | `patient_reaction(kind §6.2, data)`, `screen_shake(strength, duration_s)` |
| **(v3)** chapters | `chapter_completed(chapter_id, newly_unlocked: Array)` (Game, from `finish_visit`; **(polish)** `newly_unlocked` is always `[]`: every day is open) |
| **(v3)** masking | `masker_changed(ear, freq, db, on)` (ear = the MASKED ear), `transducer_changed(transducer, ear)` (AudiOtron) |
| **(Speech)** speech | `speech_started(patient_id, ear, test, coached)`, `speech_presented(ear, test, db, item)`, `speech_response(ear, test, db, answer)`, `speech_scored(ear, test, db, correct, right)`, `speech_stored(ear, test, sheet §9.5)`, `speech_state_changed(state §9.4)`, `speech_finished(results §9.5)`; all from the SPEECH screen (§9.7) |
| **(v4)** movies | `explainer_started(movie_id, source)` (source `"day_start"`, `"pause"`, `"title"`, `"dev"`, `"test"`), `explainer_scene(movie_id, index, scene_id)` (every scene), `explainer_finished(movie_id, skipped)`; all from the explainer player (§3.4) |

Emit every signal with all its arguments. Use `""`, `{}` or `-1` for "none".
`tests/test_contracts.gd` checks that every signal exists.

### §2.2 Game (`autoload/game.gd`)

| Member | Meaning |
|---|---|
| `settings: Dictionary` | `DEFAULT_SETTINGS`: `key_style` ("otosuite" / "affinity"), `master_volume`, `tone_volume`, `sfx_volume`, `music_volume` (0..1), `show_key_hints`, `reduced_motion`, `no_startle`, `fullscreen`, `text_speed`, `quick_visit`. **(polish)** `unlock_all_days` is gone (every day is open); an old save that still has it loads fine, the key is ignored |
| `set_setting(key, value)` | apply, save, emit `settings_changed` (and `key_style_changed`) |
| `set_key_style(style)`, `get_key_style()` | Swaps the events of `louder` and `softer` (§4.7) |
| `key_label(action) -> String`, `key_labels(action)` | Current key names for on-screen hints. Always use these; never hard-code "Up". |
| `progress: Dictionary` | `coins`, `upgrades: Array`, `patients: {id: {best_score, best_grade, last_grade, plays}}`, `seen_disclaimer`, `hoot_mastery`, `plays`, **(v3)** `chapters_done: Array` (chapter ids finished at least once), `last_chapter`, **(v4)** `movies_seen: Array` (movie ids watched at least up to their `seen_at` scene, §3.4; **(polish)** an early skip does not count; an old save without it loads fine) |
| `save_game()`, `load_game()`, `reset_save()` | JSON at `user://save.json` (`user://save_autoplay.json` under `--autoplay`, `user://save_scene.json` under `--scene=`). A corrupt file is copied to `.bak`. **(v3)** An old save where Gus was played counts as Day 1 done. |
| `load_patient(id) -> Resource` | `res://core/patients/<id>.tres` (a `PatientProfile`) |
| `current_patient_id`, `visit` | §2.3 |
| `begin_visit(id)` | Resets the visit state. Story calls it first. |
| `lose_comfort(reason, amount=1)`, `gain_comfort(...)`, `get_comfort()` | 0..3 hearts; emits `comfort_changed` |
| `set_visit_flag(key, v)`, `get_visit_flag(key, default)` | Free-form per-visit flags |
| `record_medal(beat, "gold" / "silver" / "bronze")` | One medal per micro-game |
| `set_audiometry_results(results §5.1)` | Story calls it after the last `test_finished`. |
| `finish_visit() -> Dictionary` | Scores the visit, awards coins, saves, and returns the summary (§5.3). Called once, on results (**(cases)** a case with a retest calls it just before the retest, §11). |
| `add_coins(n)`, `has_upgrade(id)`, `buy_upgrade(id, cost) -> bool` | Shop |
| `cli: Dictionary`, `cli_flag(name)`, `cli_value(name, default)`, `is_autoplay()` | User args after `--` (§7.1) |
| **(demo)** `is_demo()`, `reset_demo_visitor()`, `DEMO_SAVE_PATH`, `WEB_FLAGS` | The career-fair demo (§14): `--demo`, or `?demo` in the web page's address (only the names in `WEB_FLAGS` are read from it). Its own save `user://demo_save.json` (after `--autoplay` and `--scene=`; `--save=` wins); quick visit forced unless `--full`. `reset_demo_visitor()` puts `progress` back to `DEFAULT_PROGRESS` and keeps `settings` |
| `rng: RandomNumberGenerator` | Seeded (`--seed`, default 1234 in autoplay). Use it for anything that should replay the same way. |
| `clock: float` | Game seconds. Pauses with the tree and follows `Engine.time_scale`. |
| `PHASES` | Phase ids (§3.1). **(v4)** adds `explainer` and `ghost_demo`; **(Speech)** `familiarize`, `speech` (§9.8); **(cases)** `tymp`, `decision` (§11) |
| **(v4)** `is_movie_seen(id) -> bool`, `mark_movie_seen(id)` | `progress.movies_seen`; `mark_movie_seen` adds the id once and saves. The explainer player calls it when a movie ends after reaching its `seen_at` scene (§3.4) |
| **(v3)** `CHAPTERS` | `[{id, day, title, patient_id, teaches, scene, requires}]`: `gus` (Day 1: Grandpa Gus, `res://story/level_gus.tscn`) and `bonnie` (Day 2: Bonnie Bunsworth, `res://story/level_bonnie.tscn`, requires `gus`); **(Speech)** `mike` (Day 3, `res://story/level_mike.tscn`, §9.8); **(cases)** `rocco`, `marina`, `dash`, `ginger`, `barnaby`, `skye`, `morgan`, `bev` (Days 6-13, `res://story/level_case.tscn` with the extra key `case`, §11). **(polish)** `requires` is only a hint: the chapter best played first, which picks the suggested ("UP NEXT") day; it never locks anything. Optional `face` (a `Portraits` speaker id) and `tint` (a `Color` or `"#rrggbb"`) style the title's day card when its `DAY_FACES` / `DAY_TINTS` tables have no entry for the id |
| **(v3)** `chapters()`, `chapter(id)`, `chapter_for_patient(id)`, `chapter_for_day(day)`, `chapter_scene(id)` | Registry lookups (`{}` / `""` when unknown) |
| **(v3)** `is_chapter_done(id)`, `is_chapter_unlocked(id)`, `unlocked_chapter_ids()` | **(polish)** Every chapter is open from the start, in any order (Steve's rule): `is_chapter_unlocked()` is always true and `unlocked_chapter_ids()` lists every chapter. Kept so callers need not change |
| **(polish)** `suggested_chapter_id()`, `static suggested_from(list, done)` | The suggested day (the title's "UP NEXT" badge): the first chapter in day order not done whose `requires` is done, empty or unknown; else the first not done; `""` when every day is done |
| **(v3)** `next_chapter_id()`, `cli_chapter_id()` | What the title's Play starts: the CLI chapter, else the suggested day, else `last_chapter`, else Day 1 |
| **(v3)** `start_chapter(id) -> bool` | Remembers `last_chapter`, saves, emits `goto_scene(scene)`. False only if the chapter is unknown or its scene is missing |
| **(v3)** `current_chapter_id` | Set by `begin_visit` from the patient |
| **(v3)** `SHOP_ITEMS` | `{id: {cost, day, title, blurb}}`: `comfy_chair` (40, day 1), `insert_earphones` (60, day 2). Never needed to play |

### §2.3 Visit shape (`Game.visit`)

```
{
  "patient_id": "gus",
  "comfort": 3,                       # hearts 0..3 (ClinicRules.MAX_COMFORT)
  "comfort_log": [{"reason": "too_loud", "delta": -1}, ...],
  "medals": {"history": "gold", "otoscopy": "silver", "earphones": "gold", "evidence": "gold"},
  "flags": {"instructed": true, "earphones_swapped": false, ...},
  "audiometry": {...results §5.1...},
  "started_at": 12.3,                 # Game.clock
  "summary": {...§5.3...}             # after finish_visit()
}
```
Comfort reasons used so far: `too_loud`, `marathon`, `no_instructions`.
**(v3)** Day 2 medals: `history`, `otoscopy`, `earphones`, `bc_placement`, `masking`, `evidence`, `referral`.
Day 2 flags: `bc_placement_slips` / `bc_placement_mistakes` (int), `asked_red_flags`, `instructed_first_try`.
**(v4)** `bc_placement_mistakes` and the `bc_placement` medal now count the slips of BOTH placements (left, then the
quick right one); `movie_watched` (the day-start movie played to the end), `ghost_demo_seen` (the demo tone was
answered by the left cochlea, `cross_heard`).

### §2.4 Hoot, Stage, Sfx

- **Hoot**: the tip queue. See §8.
- **Stage**: lets `ui/` and `world/` find each other without importing each other.
  - `clinic` and `audiometer` vars.
  - `register_clinic` / `unregister_clinic(node)`, `register_audiometer` / `unregister_audiometer(node)`, `has_clinic()`.
  - `get_booth_texture() -> Texture2D`: the clinic's booth camera, or a gradient placeholder.
  - `set_booth_view_active(bool)`.
  - `react(kind, data)`: a shortcut for `Events.patient_reaction`.
- **Sfx**: friendly synthesized UI sounds, quiet and cached, on the Sfx bus.
  - `play(name, pitch=1, vol_db=0)`. Names: `click blip thunk stamp ding boing pop whoosh kaching sad_trombone squeak fanfare chirp pen door note sparkle error`.
  - `play_note(hz, vol_db)`.
  - `Sfx.audiogram_note_hz(freq)`: 250 Hz maps to C4 and 8 kHz to C6, for the "audiogram melody".
  - `stop_all()` **(v2)**: stops every voice and drops the cache. `main.gd` calls it on quit.
  - Music: `music_start()`, `music_stop()`, `is_music_playing()`, and **(polish)** `music_duck(on, owner := "")`:
    reference-counted by owner key (the AudiOtron uses `"audiotron:<instance id>"`, a movie `"explainer:<instance id>"`, **(Speech)** the SPEECH screen `"speech:<instance id>"`);
    the music stays ducked to silence while ANY owner holds it, so one owner ending never brings the marimba back
    under another's beeps. `is_music_ducked()`, `music_duck_owners()` (tests). Every owner undoes its duck in
    `_exit_tree()`.

### §2.5 Shared static classes

- **`ClinicRules`**: every clinical and scoring number, and the pure functions over them.
  - `AC_FREQS`, `OCTAVE_FREQS`, `INTEROCTAVES`, `TEST_ORDER`; **E1** `ROUTINE_FREQS` (the octaves plus 1500, 3000 and 6000: tested on every ear) and `is_routine(freq)`.
  - Hughson-Westlake steps: `START_DB` 40, down 10, up 5, `ASCENDING_HITS_NEEDED` 2.
  - `MAX_DB` per frequency, tone-timing limits, `RESPONSE_WINDOW_S`, `TOO_LOUD_SL_DB`.
  - `PAR_PER_MEASUREMENT` 7 (**v2**: only a fallback; the session computes par per measurement, §5.2), `MARATHON_FACTOR` 3.0, `SCORE_WEIGHTS`, `GRADE_BANDS`, `DEGREE_BANDS` (Goodman 1965; **E15** `DEGREE_SCALE_NOTE` "degrees: Goodman (1965)", printed under the audiogram's band names, which match), `SHAPES`, `SHAPE_TITLES`.
  - Functions: `clamp_db`, `accuracy_for_error`, `golf_name`, `grade_for_score`, `combo_multiplier`, `degree_name`, `pta`, `required_interoctaves`, `classify_shape`.
  - `accuracy_for_error`: 0 dB -> 1.0, 5 -> 0.8, 10 -> 0.3, more than 10 -> 0 (engine-and-fun.md scoring table).
  - `golf_name(strokes, par)` **(v2)** uses run-sized bands, because one extra ascending run costs 2-3 presentations:
    d = strokes - par: -6 or less albatross, -5..-4 eagle, -3..-2 birdie, -1..+1 par, +2..+3 bogey, +4..+5 double bogey, +6 or more triple bogey.

  **(v3) Bone conduction and masking** (all numbers in `docs/CHAPTER2.md` §7):
  - `TESTS`, `TRANSDUCERS`, `BC_FREQS` (250-4k), `BC_REQUIRED` [1000, 2000, 4000, 500], `BC_MAX_DB` (250: 45, 500: 60, 750: 65, 1k-3k: 70, 4k: 65), `VIBROTACTILE_DB` (250: 25, 500: 55, 1000: 70: **E16**).
  - `IA_RULE_DB` (phones 40, inserts 55, bone 0), `MASK_SAFETY_DB` 10, `OCCLUSION_DB` (phones: 250 +15, 500 +15, 750 +10, 1k +10; inserts 0), `OCCLUSION_MAX_GAP_DB` 10, `MASK_STEP_DB` 5, `PLATEAU_STEPS` 3, `MASK_MIN_DB` 0, `MASK_MAX_DB` 100.
  - `ABG_CONDUCTIVE_DB` 10 (gap > 10 = conductive), `ABG_RED_FLAG_DB` 15 at `ABG_RED_FLAG_FREQS` [500, 1000, 2000], `CARHART_FREQ` 2000, `CARHART_MIN_DIP_DB` 10, `HEARING_TYPES`, `HEARING_TYPE_TITLES`, `MASK_STATUSES` (off, needed, under, ok, over, impossible).
  - Functions: `test_id`, `test_is_bone`, `test_is_masked`, `unmasked_test`, `test_freqs`, `max_db_for(freq, transducer)`, `clamp_db_for`, `clamp_mask_db`, `ia_rule`, `occlusion_effect`, `air_bone_gap`, `is_conductive_gap`, `abg_red_flag`, `hearing_type`, `has_carhart_notch`, `ac_masking_needed` (test AC - IA >= non-test BC), `bc_masking_needed` (gap >= `BC_MASK_GAP_DB`, 10: clinical review E5; `is_conductive_gap` stays > 10 for naming the loss), `initial_masking` (non-test AC + 10 + occlusion), `overmask_limit` / `is_overmasked` (masker - IA >= test cochlea), `masking_dilemma`, `mask_status`, `next_mask_step` (heard: noise +5; missed: tone +5), `plateau_run`, `sheet_thresholds`, `best_thresholds`, `nontest_bone_estimate`, `masked_freqs_needed`, `response_threshold` (the cross-hearing model: either cochlea answers).
  - **(v4)** `unmasked_bone(results, freq) -> Variant`: the lower of BOTH ears' unmasked bone stamps at `freq`
    (`null` when neither has one). Bone crosses the skull for free, so an unmasked bone answer belongs to the
    better cochlea, wherever the oscillator sat. `masked_freqs_needed(results, ear, &"bc_masked")` now compares the
    test ear's air with `unmasked_bone()` (Day 2 measures unmasked bone on the LEFT mastoid only), and the session
    starts a masked bone measurement there too (`mask_start` check, par, recommended start).
  - **(cases, Day 13)** `masked_freqs_needed(results, ear, &"ac_masked", phones)` judges each air stamp with the
    transducer the stamp records (`info.transducer`, "phones" / "inserts"); `phones` is only the fallback for
    stamps without one. Nothing changes while a visit keeps one transducer; when Hoot lends inserts mid-visit
    (Day 13), the air measured through headphones still needs masking by the headphones' rule.

  The numbers are teaching defaults that the clinical reviewer (Steve) checks. Change them here, not in a copy.
- **`AudioSafety`**: `hl_to_dbfs`, `hl_to_peak`, `peak_ceiling`, `clamp_sample`, and the bus names `Tones`, `Sfx`, `Music`, `Voice` (§1.3).
  **(v3)** `MASKER_OFFSET_DB` -6, `MASKER_CEILING_DBFS` -24, `masker_to_rms(db_em)`, `masker_ceiling()`, `clamp_masker_sample(v)`.
- **`Palette`**: warm palette constants (`INK`, `PAPER`, `SUNNY`, `CORAL`, `MINT`, `SKY`, `WALL`, ...), plus
  `ear_color(ear)` (right = red, left = blue), `ear_tint(ear)` and `grade_color(grade)`.
- **`UiDraw`**: `_draw()` helpers: `arrow`, `triangle`, `heart`, `star`, `check`, `cross`,
  `ear_symbol(ci, center, ear, size, width, no_response)` (O / X and the no-response arrow), `rounded_rect`.
  **(v3)** `audiogram_symbol(ci, center, ear, test, size, width, no_response, color)`: every ASHA symbol (right / left:
  ac O / X, ac_masked triangle / square, bc < / >, bc_masked [ / ]); `symbol_offset(ear, test, size)`: bone symbols
  sit beside the frequency line (right ear to the left, left ear to the right).
- **`Juice`**: `pop`, `bounce_in`, `squash`, `shake`, `bob` and `float_text(parent, text, at, color, size)`. Each respects
  `reduced_motion`.

Theme: `res://assets/theme/main_theme.tres` is the project default.
- Button variations: `AccentButton`, `GhostButton`.
- Label variations: `TitleLabel`, `HeaderLabel`, `CaptionLabel`.
- Fonts: Fredoka 400 / 500 / 600 / 700 in `res://assets/fonts/` (OFL).

---------------------------------------------------------------------------------------------

## §3 Flow

### §3.1 Scenes, phases, canvas layers

`main.gd` boots `res://story/title_screen.tscn`. Any boot argument like `--scene=res://...` boots a different scene and calls its `demo_start()`.
To change scenes, emit `Events.goto_scene(path)`. Main fades out, frees the old scene, adds the new one,
emits `scene_changed`, then fades in. Main also hosts the overlays `story/hoot_bubble.tscn` and `story/pause_menu.tscn`.

Story emits `Events.phase_changed(phase, info)` at each beat, in this order. Ids are in `Game.PHASES`.

| phase | where | info |
|---|---|---|
| `disclaimer` | title screen: "This is a game, not a hearing test." | {} |
| `explainer` **(v4)** | a chapter's day-start movie (Day 2: before `intro`), or Hoot's offer to replay it | {movie, source: "day_start", seen: bool} |
| `title` | title menu (Play / Days / Options / Quit) | {} |
| `chapter_select` **(v3)** | the title's day picker ("Days") | {unlocked: [every chapter id], suggested: chapter id} |
| `intro` | Gus bursts in | {} |
| `history` | case-history choices | {} |
| `otoscopy` | I-spy in the ear canal | {} |
| `instructions` | tell Gus what to do | {} |
| `earphones` | drag red to right, blue to left | {} |
| `audiometry` | AudiOtron, right ear coached | {"ear": "right"} |
| `audiometry` | AudiOtron, left ear solo | {"ear": "left"} |
| `reveal` | audiogram reveal + shape | {} |
| `evidence` | "present the evidence" drag | {} |
| `fitting` | teaser fitting, world regains colour | {} |
| `results` | Daily Decibel newspaper | {} |

**(v3) Day 2** (`level_bonnie`): `intro`, `history`, `otoscopy`, `instructions`, `earphones`, then
`audiometry` {ear, test} for {right, ac} and {left, ac}, then `bc_placement` (the
oscillator mini-game), {right, bc}, `masking` (which ear gets the noise), {right, bc_masked}, {right, ac_masked};
then `reveal`, `evidence` (type of loss), `referral` (ENT stamp), `results`. Every `audiometry` phase info
now carries `"test"` (Day 1 sends `{"ear": ...}` only, which means `"ac"`).

**(v4) Day 2 order** (bone on the better ear first; `docs/CHAPTER2.md` §3):

| # | phase | info | beats |
|---|---|---|---|
| 0 | `explainer` | {movie: "masking", source: "day_start", seen} | first visit: `explainer` (the movie); seen before: a `choice` "Roll the film!" / "Skip it" (best = skip) |
| 1-5 | `intro`, `history`, `otoscopy`, `instructions`, `earphones` | as v3 | as v3 |
| 6 | `audiometry` | {ear: "right", test: "ac"}, then {ear: "left", test: "ac"} | AudiOtron |
| 7 | `bc_placement` | {ear: "left"} | `bc_placement` (target `mastoid_target_left`) |
| 8 | `audiometry` | {ear: "left", test: "bc"} (coached; then the optional 250 Hz bonus hole, {left, bc} again) | AudiOtron, `choice` |
| 9 | `ghost_demo` | {ear: "right"} | `bc_placement` (quick: `mastoid_target_right`), then `audiometry` {ear: "right", test: "bc"} with plan `demo_tone` (§4.2) |
| 10 | `masking` | {} | `choice`, then `audiometry` {right, bc_masked} and {right, ac_masked} (none with inserts) |
| 11-14 | `reveal`, `evidence`, `referral`, `results` | as v3 | as v3 |

No unmasked RIGHT bone is ever stored on Day 2 (the demo stores nothing): the reveal shows left `>` and right `[`.

**(Speech)** Day 3's order (`familiarize`, `speech`): §9.8. **(cases)** Days 6-9 (`tymp`, `decision`): §11.

Every `phase_changed` clears all Hoot tips (§8).

Canvas layers:

| Layer | Used by |
|---|---|
| 10 | story HUD and micro-games |
| 20 | AudiOtron screen; **(Speech)** SPEECH screen (§9.7; a level shows one of the two at a time) |
| 30 | DialogueBox |
| 40 | results paper |
| 80 | Hoot bubble |
| 85 | **(v4)** explainer player (Hoot's movies) |
| 90 | pause menu |
| 120 | main fade |

### §3.2 Blocking beats: `Events.awaiting_input(beat, info, solver)`

Every wait for the player **outside the audiometer** must emit `awaiting_input` before it waits.
- `solver` is a no-argument `Callable` that completes the beat in the best way, through the same code path a
  click uses.
- The autoplay bot calls it (§7). Emitting `Events.input_resolved(beat)` afterwards is optional.

| beat | emitted by | info |
|---|---|---|
| `disclaimer_ok` | title screen | {} |
| `title_start` | title screen | {} |
| `dialogue` | DialogueBox.say | {speaker, text} |
| `choice` | DialogueBox.choose | {prompt, options, best} |
| `otoscopy_find` | level | {target: "otoscope_seed"} |
| `earphones_place` | level | {targets: ["ear_target_right", "ear_target_left"]} |
| `evidence_present` | level | {target: "evidence_target"} |
| `fitting_switch_on` | level | {} |
| `results_continue` | results paper | {summary} |
| `chapter_select` **(v3)** | title screen (Days card) | {chapters: every chapter id, next: chapter id, suggested: chapter id}; solver starts `next` |
| `bc_placement` **(v3)** | level_bonnie (oscillator game) | {targets: ["mastoid_target_right"], mistakes}; solver places it on the mastoid. **(v4)** {targets: ["mastoid_target_<ear>"], ear, quick, mistakes}: Day 2 plays it twice, `left` first, then `right` with `quick` true |
| `explainer` **(v4)** | explainer player (§3.4) | {movie, title, scenes (count), source}; solver = `skip_all()` (the movie ends at once, skipped) |
| `referral_stamp` **(v3)** | level_bonnie (Day 2 board) | {targets: ["referral_stamp"]}; solver stamps. **(Speech)** level_mike reuses it |
| `speech` **(Speech)** | SPEECH screen (§9.7) | {ear, test, action, mouse: {click: anchor}}; solver sends the recommended action |
| `familiarize_cards`, `objection_present` **(Speech)** | level_mike (§9.8) | {mouse}; {targets, mouse: {drag: [clue, target]}} |
| `fitting_target` **(Day 14)** | level_fitting (target match, §13) | {}; solver raises each band straight to its target (one move each) and presses Done |
| `probe_tube` **(Day 14)** | level_fitting (probe tube, §13) | {}; solver slides the tube straight into the zone (within 5 mm of the eardrum) and locks it |
| `loud_check` **(Day 14)** | level_fitting (loud-sound check, §13) | {}; solver turns the loud limit straight to the right notch and drops the pan once |

New beats are fine if they follow the same rule. Add them to this table through `story/INTEGRATION_NOTES.md`.

### §3.3 Story helpers (story-internal, listed for reference)

- `DialogueBox` (CanvasLayer 30):
  - `await say(speaker, text)`.
  - `await choose(prompt, options: Array[String], best) -> int`. The keys 1-9 pick an option.
  - It emits `Events.dialogue_line`.
- `DailyDecibel`: `await show_summary(summary) -> String`: "title", "again" or **(v3)** "next" (the "Next: Day N"
  button / key N, shown when the next chapter is open; the level then calls `Game.start_chapter(summary.next_chapter_id)`).
  The paper settles at `fit_scale(size, window)`: exactly 1 when its tilted box fits the window's height, else
  scaled down to fit with `FIT_MARGIN` (16 px) to spare.
- **(v3)** HUD: `set_steps(steps, labels, title, colors)` replaces Day 1's step tracker.
- **(v3)** Earphones game: `setup(clinic, pronoun := "his")`.
- **(v3, builders)** Day 2 board (`story/games/day2_board.gd`): `run_reveal(results)`, `show_gap()` (the toll
  bridge), `set_compact(on)`, `show_type(text)`, `show_carhart()`, `run_stamp()`. `Otoscopy.show_clear(ear, caption)`
  is an input-free look at a healthy ear. The title's Days card keeps `_day_buttons` (every day card, then
  Back; metas `label`, `chapter`, `ch`, `suggested`, `best`, `hl`), `_day_cards`, `_pick_day`, `_days_back`, `_days_scroll`
  and `_days_cols` for the tests and the bot. **(polish)** It is a scrolling grid for any number of days: columns and
  visible rows follow the screen (`grid_geometry(vp, n, k)`), the rest scrolls (wheel, scroll bar, or the arrow keys,
  which keep the highlighted card in view: Left / Right step through every button, Up / Down move a row, past the
  last row to Back). Esc = Back. `chapters_override` (dev scenes and tests only) shows another chapter list.
- Pause menu: group `pause_menu`, with `open()` / `close()` / `is_open()` and the key-style toggle. The `pause` action toggles it.
  **(v4)** `movie_ids_here() -> Array[String]` (the movies its "Watch ..." buttons offer now) and `await play_movie(id)`
  (the replay, §3.4).
- **(v4)** Bone placement game: `setup(ear := "right", quick := false)` before `add_child` (ear `"left"` draws her left
  profile, facing left; `quick` = the short "Swap sides!" caption), `glasses_on` (false once she found her glasses:
  no glasses on the card, "top" is a plain slip), then `await run()`; `mistakes`, `wrong_spots`, `placed`.
- **(v4)** Day 2 board legend lists "Left bone" (`>`) when the left ear has a `bc` sheet; the paper's golf card has an
  `L  >` row (`GOLF_EXTRA_ROWS`) before `R  [` and `R  O+`.

### §3.4 Hoot's movies (v4): `story/explainers/`

Short in-engine cartoons that explain one idea before a day (about 60-100 s), skippable and replayable. Day 2
plays "Hoot's masking movie" (storyboard in `docs/CHAPTER2.md` §16) and, when the masking phase opens, its one-card
recap "The short version". How to add one: `docs/ADDING_A_CHAPTER.md`, "Hoot's movies".

| Part | File | What it is |
|---|---|---|
| Registry | `story/explainers/movies.gd` (`preload`, story-internal) | `MOVIES {id: path}`; static `ids()`, `has(id)`, `movie(id)` (deep copy), `for_chapter(chapter_id, include_short := false)` (the chapter's replayable movies; **(cases)** a movie's `also_chapters` count too), `chapters_of(movie) -> Array[String]` (**(cases)** its `chapter`, then its `also_chapters`), `replay_ids()` (every movie but the recaps and, **(Days 4-5)**, any movie whose `chapter` is not in `Game.CHAPTERS` yet, such as a stub registered before its day), **(E19)** `for_level(chapter_id, masks)` (the chapter's own, or every replay movie when the level can mask: **(cases)** even when it has movies of its own, so the case days list the masking movie beside their three) and `MASKING_LEVEL_GROUP` (`masking_level`: the case runner and Freestyle join it, so their pause menus offer the masking movie; **(clinical review A2, all days)** Days 4 and 5 join it when their masking recap card plays), `is_short(id)`, `day_label(id)` ("Day 2"; "Days 6-13" for a movie shared by several days), `title(id)`, `total_s(id)`, `own_sets(id)` (the movie's own set ids), `word_count(text)`, `validate(id, known_sets) -> PackedStringArray`. `CARD_MAX_LINES` 4 and `CARD_MAX_CHARS` 36: `validate()` reports a `card` scene with more or longer lines. **(polish)** `static var extra := {}` (id -> a movie file path or a MOVIE Dictionary): **tests and dev tools only**, more movies at run time (`dev_explainer --extra-movie=`, `--list`); the game never sets it |
| Movie data | `story/explainers/movies/<id>.gd` (or your chapter's folder) | `const MOVIE := {id, title, subtitle, chapter (a Game.CHAPTERS id), narrator ("Hoot"), scenes: [...]}` plus the optional keys **(polish)** `seen_at` (a scene id: reaching it counts as seen, default the last scene; masking: `"plateau"`), `short` (true = a recap of 5-30 s: played by its level, never in a replay list), `stage` (the movie's own sets script, below) and **(cases)** `also_chapters` (more Game.CHAPTERS ids whose pause menu lists it: the case movies belong to `rocco` and also to Days 7 to 13, labelled "Days 6-13") |
| Scene | (in the movie data) | `{id, set, duration (s), captions: [Hoot lines, 18 words or fewer], teaches (the one idea)}` plus the optional keys `title` (the scene chip top-left on the stage: a number disc and the title in capitals), `caption_at: [s]` (default spread), `board` (the animation brief, never shown), `params` (for the set), `cues: [{t, sfx, pitch, vol_db}]` |
| Stage | `story/explainers/explainer_stage.gd` (Control, 880 x 440) | Fully animated: `SETS` (the built-in set ids: the ten masking sets of `docs/CHAPTER2.md` §16 and `card`), `use_movie(movie)` (the player calls it: loads `MOVIE.stage`), `show_scene(scene)`, and it animates by the `t` the player sets each frame: every drawing is a pure function of `t` (no tweens, nodes or RNG), so a paused movie freezes, a screenshot repeats and a skipped scene leaves nothing behind. `scene_no` (set by the player) and `scene_title` (the scene's `title`) label the corner chip. The generic set **`card`** needs no code: params `{heading (default: the scene's title), lines (at most 4, 36 characters each), line_at: [s] (default spread over the first 60 %), icon (one of `CARD_ICONS`: "", "snails", "ghost", "cloud", "note", "dial", "hoot"), hoot (a waving Hoot, default true), tint ("#rrggbb")}`. **Fallback:** a `set` nobody knows (neither the stage nor the movie's sets script) draws a card with the scene's title (never an error, never a blank screen) |
| **(polish) Sets hook** | `story/explainers/explainer_sets.gd` (RefCounted base) | A movie may bring its OWN sets, so a later chapter never edits the stage: `MOVIE.stage = "res://<your folder>/<id>_sets.gd"`, a script that `extends "res://story/explainers/explainer_sets.gd"`, declares `const SETS: Array[StringName]` and one `func _set_<id>() -> void` per set. The stage draws its built-in sets itself and hands any other set to that script (`draw_set(stage, id)`), so it draws in the stage's `_draw()` with the same inputs, refreshed per frame: `t`, `duration`, `params`, `scene_id`, `scene_title`; `s` is the stage (every helper: `s._snail()`, `s._chip()`, `s._text()`, `s._cloud()`, `s._head_open()`, `s.draw_*()`...), `Stage2D.<COLOR>` its palette, and `_k()`, `_pop()`, `_ring()` are on the base. Same rules: a pure function of `t`, sounds only in the cues. `Movies.validate(id, Stage2D.SETS)` accepts a set from either list and reports a missing script, one that is not an explainer_sets.gd with SETS, or a SETS id without its `_set_<id>()`. Working example: `tests/fixtures/fake_movie.gd` + `fake_movie_sets.gd` (test `test_movie_sets_hook`) |
| Player | `res://story/explainers/explainer_player.tscn` (CanvasLayer 85) | see below |
| Dev scene | `res://story/explainers/dev_explainer.tscn` | plays `--movie=<id>` (default masking) and shoots every scene (`explainer_<id>_<NN>_<scene>`); `--at=a,b` (shares of each scene), `--times=s,s` (seconds), `--from=<id or number>`, `--only`, `--menu`, `--title`, `--card-demo`, `--reduced-motion`, **(polish)** `--extra-movie=res://...gd` (register more movie files, e.g. the hook fixture), `--list` (the "Hoot's Movies" list with five made-up movies) (`tools/README.md`) |

Player API (load by path, call by name):
```
signal finished(result: Dictionary)
func play(id: String, source := "menu") -> Dictionary   # coroutine; {movie, skipped, scenes_seen, source, watched}
func advance() -> void          # (polish) Space / Enter / a click / "Next": finish the caption, else the next caption, else the next scene
func skip_scene() -> void       # next scene now (dev tools and tests)
func skip_all() -> void         # end the movie now (Esc / "Skip movie" / the beat's solver)
func is_playing() -> bool
var movie_id, movie, scene_index, skipped
var start_scene := 0            # dev scenes only (dev_explainer --from=): the first scene to play
```
- **Beat and events.** `play()` emits `explainer_started`, then `awaiting_input(&"explainer", {movie, title, scenes,
  source}, skip_all)`, `explainer_scene` per scene, and at the end `explainer_finished(id, skipped)` and
  `input_resolved(&"explainer")`. **(polish) Seen:** `Game.mark_movie_seen(id)` only when the movie reached its
  `seen_at` scene (`watched` in the result), so an early Esc plays it again on the next visit. While it plays it is in
  group `explainer_player`; freed mid-play (P, then Quit to title) it undoes its music duck and leaves the group.
- **Captions.** Hoot's lines type out at 42 characters/s x `text_speed` (each emits `dialogue_line`) with Hoot's
  gibberish voice (`story/voice.gd` syllables on its own players, its own RNG, never `Game.rng`). A scene lasts
  `max(duration, last caption start + typing time + 1.6 s)`.
- **Keys** (in `_input`, so they win over the pause menu's Esc), after a 0.3 s grace: **(polish)** Space / Enter
  (`advance_dialogue`, `ui_accept`) and a click on the screen advance like the dialogue box: finish the typing, else
  jump to the scene's next caption (the drawing jumps with it to that caption's time; the cues in between are
  skipped, never played in a burst), else the next scene. Esc (`ui_cancel`) = skip the movie. P pauses (a level's
  movie freezes with the game). Buttons (`FOCUS_NONE`): "Next" (the last scene: "Start the day" at day start,
  "Done" for replays), "Skip movie", and "II" (opens the pause menu; hidden while the game is already paused). Hint
  row: Space "or click: next", Esc "skip the movie", P "pause".
- **Music.** Ducked while it plays through `Sfx.music_duck(on, owner)`, reference-counted by owner (§2.4): a replay
  over the AudiOtron never brings the marimba back.
- **Sounds** (§1.3): only `Sfx.play` cues, capped at -6 dB on top of the Sfx -18 dBFS normalisation, plus the
  quiet voice. "Too loud", masking noise and overmasking are drawn, never played.
- **Process mode.** INHERIT: under a level it pauses with the game; under the pause menu (ALWAYS) it plays while the
  game stays paused.
- **Entry points.** (1) A chapter's level plays its movie at day start (`level_bonnie._movie()`: phase `explainer`;
  until it is seen it just plays; once `Game.is_movie_seen(id)`, Hoot offers it with a choice, best = skip). **(polish)**
  After a day-start skip Hoot says where it lives: "Skipped! Rewatch it any time: pause menu, "Watch <title>"."
  (2) A level may play a `short` recap mid-day (`level_bonnie._recap()`, source `"recap"`, the same beat; Day 2: the
  masking card right before the masked bone test). (3) The pause menu offers the movies "here": the current
  chapter's in a level (none on Day 1; **(clinical review S7)** Day 3's is "Hoot's spondee movie"), every movie on the title's Options, never the recaps
  (`movie_ids_here()`). One movie: a "Watch <title>" button; two or more: **(polish)** a "Hoot's Movies..." button
  that opens a small vertical list (`open_movie_list(standalone := false)`, `is_movie_list_open()`,
  `close_movie_list()`, `movie_list_rows()`): one row per movie (the day chip, title and subtitle, the length, "Watch"),
  Up / Down + Enter or the mouse, it scrolls past about five rows, Esc / P / Back return to the menu.
  `movie_button()` returns the visible one of the two buttons. The menu (or the list) hides, plays the movie (source
  `"pause"` / `"title"`) and comes back. No `phase_changed` is emitted for replays. The buttons hide while a movie is
  already playing. (4) The title menu's small **"Hoot's Movies"** button (node `MoviesButton`, bottom right,
  `FOCUS_NONE`, shown only in the menu state; a mouse shortcut, keyboard players use Options): with one movie it
  opens the pause menu and runs its `play_movie(id)` (source `"title"`, the title waits paused, Esc skips) and closes
  the menu after; with several it opens the list on its own (`open_movie_list(true)`: Back closes it to the title).

---------------------------------------------------------------------------------------------

## §4 Audiometry (builder A)

### §4.1 PatientProfile (`core/patient_profile.gd`, Resource)

```
id: String                     display_name: String       age: int        complaint: String
thresholds_right: Dictionary[int, int]   # freq -> true AC threshold dB HL, every AC_FREQS entry
thresholds_left:  Dictionary[int, int]
false_alarms_per_minute: float (0.5)     reaction_time_min_s / max_s: float (0.6 / 1.4)
psychometric_slope_db: float (2.5)       attention: float 0..1 (1.0)
fatigue_per_tone: float (0.0)            min_tone_s: float (0.5)
rhythm_sensitivity: float 0..1 (0.5)     tinnitus_hz: int (0 = none)     tags: PackedStringArray
get_threshold(ear, freq) -> int          # log-frequency interpolation for missing freqs
get_thresholds(ear) -> Dictionary[int, int]
validate() -> PackedStringArray          # empty = valid
# (v3) bone conduction and the head
bc_right / bc_left: Dictionary[int, int] # freq -> true bone (cochlear) threshold; {} = same as air (no gap)
ia_phones_db: int (60)  ia_inserts_db: int (75)  ia_bone_db: int (0)   # this head's REAL interaural attenuation
occlusion_scale: float (1.0)             # x ClinicRules.OCCLUSION_DB
get_bc_threshold(ear, freq) -> int       # never poorer than air
get_bc_thresholds(ear), has_bone_data(), get_ia(transducer) -> int
# (v3, builders) pronouns for every text about the patient
pronoun: String ("he" / "she" / "they")  nickname: String ("" = first word of display_name)
short_name() -> String                   # "Gus", "Bonnie"
say(text) -> String                      # fills {he} {He} {his} {His} {him} and {name}
static pronouns(text, which) -> String   # the same without a patient
```

The defaults in brackets are intentionally neutral. Each patient's file stores its own values.
Patients load with `Game.load_patient(id)` from `res://core/patients/<id>.tres`.

**`core/patients/gus.tres`**: Grandpa Gus, age 78. Mild-to-moderate bilateral sloping presbycusis, roughly symmetric.

| Hz | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| right | 15 | 20 | 20 | 25 | 30 | 40 | 50 | 55 | 60 | 65 |
| left | 15 | 20 | 25 | 25 | 35 | 45 | 50 | 60 | 65 | 65 |

His response settings (**v2**, builder A):
- false alarms 0.3 per minute;
- reaction time 0.4-0.9 s;
- slope 1.7;
- attention 0.95;
- fatigue 0.001;
- minimum tone 0.6 s;
- rhythm sensitivity 0.4;
- tags: presbycusis, tutorial, chapter_0.

Tests require `validate()` to pass, a `sloping` shape in both ears, and left-right differences of 10 dB or less.
Gus has no bone data, so his bone equals his air and no test of his ever needs masking.

**(v3) `core/patients/bonnie.tres`**: Bonnie Bunsworth, age 34, baker. Unilateral RIGHT conductive loss
(otosclerosis, Carhart notch). Truth table, simulator settings and every derived value: `docs/CHAPTER2.md` §2.

| Hz | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| right air | 55 | 55 | 50 | 50 | 50 | 50 | 40 | 35 | 35 | 40 |
| left air | 10 | 5 | 5 | 5 | 5 | 5 | 10 | 10 | 15 | 15 |
| right bone | 10 | 10 | 10 | 10 | 15 | 25 | 15 | 10 | | |
| left bone | 5 | 5 | 5 | 0 | 5 | 5 | 10 | 5 | | |

### §4.2 AudiOtron screen: `res://ui/audiometer/audiometer_screen.tscn`

The root is a `CanvasLayer` (layer 20) with this API. The story adds it as a child, calls `start_test()` once per
ear and awaits `test_finished`. Between ears the screen stays in the tree. It keeps its session and its
audiogram for the same patient.

```
signal test_finished(results: Dictionary)          # §5.1, every ear tested so far this visit
func start_test(patient: PatientProfile, ear: String, coached: bool, plan := {}) -> void   # (v3) plan
func get_state() -> Dictionary                      # §4.3
func get_results() -> Dictionary                    # §5.1 (also usable mid-test)
func demo_start() -> void                           # standalone: begins a coached right-ear test of Gus
```

How the screen behaves:
- **Lifecycle.** It registers with `Stage` while it is in the tree, and turns on the booth view.
- **Input.** It reads the input actions (§4.7) in `_unhandled_input` only while `accepting_input` is true. Every control also has a
  clickable button with a key chip: hold TONE to present, right-click TONE = no response.
- **Coaching.** When `coached`, Hoot walks the player through the first ear with sticky tips pointing at anchors (§8).
  When `coached` is false it stays quiet unless the player makes an error.
- **Finishing an ear.** When every required measurement of the requested ear is stored, input stops, `ear_completed` fires, an
  audiogram melody plays, then `Events.audiometry_finished(results)` and `test_finished(results)` follow.
- **On exit.** It clears its Hoot bubble hint and its tips.
- **Ear lock (v2).** The ear buttons are locked to the ear `start_test` asked for (a locked button wiggles).
- **Level lock (v2).** Level changes are ignored while a tone plays; both the TONE lamp and the level stay lit.
- **Key hints (v2).** `H` (`toggle_key_hints`) and the "Keys" pill flip `Game.settings.show_key_hints`.
- **Pause button (v2, integrator).** A small "II" button in the score card's corner opens the pause menu
  (`get_first_node_in_group("pause_menu").open()`), releasing any held tone first. It is a pill (no keycap
  strip). The pause menu hides its own corner button whenever `Stage.audiometer` is registered (story and
  standalone demo alike), so there is exactly one pause button and it is the mouse-only route mid-test.
- **Visit flags it reads (v2).** `instructed` (false = more false alarms) and `earphones_swapped` (true = the
  phones really sit on the wrong ears, so the patient answers with the other ear). The earphone mini-game
  never leaves the cups swapped; it records wrong drops as the flag `earphone_slips` (an int) instead.

**(v3) The test plan** (`start_test`'s 4th argument; `{}` = Day 1 behaviour). Keys, all optional:

| key | meaning |
|---|---|
| `test` | the goal sheet: `"ac"` (default), `"bc"`, `"bc_masked"`, `"ac_masked"`. The transducer follows (bone for bone tests) |
| `bc_freqs` | required unmasked bone frequencies (default `ClinicRules.BC_REQUIRED`) |
| `air_transducer` | `"phones"` (default) or `"inserts"` |
| `mask_on`, `mask_db` | start with the masker on / at this level (default off: the player presses M) |
| `masking_controls` | show the MASKING (noise down, NOISE on/off, noise up) and ROUTE (AIR \| BONE) buttons; default true for any test but `ac` |
| `masking_deck` **(polish)** | default true; with `masking_controls`, false keeps only the ROUTE (AIR \| BONE) buttons: no MASKING group on the deck, no noise LCD, and M / PgUp / PgDn do nothing (an unmasked bone sheet before masking is taught: Day 2's left bone and the bonus hole). `get_state().masking_deck` |
| `hoot_turn_after` | stamps before Hoot takes over at x8 (default 3); 0 = Hoot runs the whole test (quick visit) |
| `intro`, `hoot_turn_text`, `done_title` | Hoot's opening tip, his take-over line, the quest panel's done title |
| `intro_full` **(polish)** | the opening tip used instead of `intro` when quick visit is off (no "I'll run the rest") |
| `montage` **(polish)** | with quick visit and `hoot_turn_after` 0: Hoot fills the ear as a stamp montage (`AudiometrySession.instant_measure`, no tones played, input locked, scoring off) instead of the x8 turn |
| `montage_after` **(demo)** | with quick visit: when the player's `hoot_turn_after` stamps run out, Hoot fills in the rest of the ear as a montage (as `montage` does) instead of the x8 turn, saying `hoot_turn_text` (default "Nice work! I'll fill in the rest in a flash."). Plans without it are unchanged (§14) |
| `skip_hoot_retest` **(polish)** | Hoot's turn / montage waives the 1 kHz retest of that ear (`session.retest_waived`); the player's own runs still need it. (E2) Only the first air ear of a visit owes the retest anyway. (FS-07) The waiver lasts for that ear for the rest of the session: a later air run on it, whoever runs it, owes no retest, so a non-air plan never sets it |
| `nothing_title` **(polish)** | the done title when the goal sheet needs nothing (default "NOTHING TO MASK!") |
| `start_db` **(polish)** | the first level of a non-air plan instead of the textbook start (Day 2's optional 250 Hz bone "bonus hole" starts at 40, so the vibrotactile tickle lands) |
| `demo_tone` **(v4)** | `{freq, db, title, max_tones := 3, idle_s := 6.0}`: the one-tone **Ghost demo**. The screen sits at `freq` / `db` with the masking deck hidden, scoring off and every control but TONE locked (keys and buttons); a sticky Hoot tip (`intro`) points at TONE. A heard tone (or the last try) ends it; a miss raises the tone 5 dB and asks again. **(polish)** The wait clock starts once Hoot's tip has typed out (plus 1 s); after `idle_s` TONE wiggles with a "Hold Space!" chip, after twice that Hoot presses TONE himself. A cross-heard answer flies the Ghost with `title` ("Bone 5, air 50? BOO!"); **(polish)** when she answered higher than `db` (a missed first beep), the shout names the level she really answered at and her air there ("Bone 10, air 50? BOO!"). Nothing is stored, no `ear_completed`; its open measurement is dropped (`AudiometrySession.discard_open(ear, freq)`, core-internal) so it never starts a bone search; after 2.4 s it emits `audiometry_finished` and `test_finished`. **(v4, builders) The look:** a lavender "GHOST DEMO: ONE BEEP" banner; TONE beckons, every other deck button and Ask Hoot is dimmed, and a locked key or click wiggles it with a quiet error blip and a "just TONE!" chip; the test ear's card says "GHOST TEST" with no pips; the quest panel shows one token, no bar, and a note ("ONE beep, buzzer on her RIGHT. Nothing gets stored.", then "Heard at N dB... but by WHICH cochlea?"); no par, dance card, combo flame or booth punch-in (integrator: the punch-in hid the Ghost's callout); Hoot's own press shows a "Hoot's wing!" chip, a too-short press "A blip! Hold ..."; the Ghost flies onto the better ear's `>` mark and lingers 3 s. The locks and labels come back when it ends |

**(v4)** Masked BONE measurements start at `ClinicRules.unmasked_bone()` (either mastoid), not only the test ear's
own unmasked bone sheet. A `bc_masked` plan opens on the unmasked bone sheet (noise off, the player presses M); when
that ear has no unmasked bone stamps of its own, its opening level is that same `unmasked_bone()` value too.
**(v4, builders)** The masking light (`masking_needed_here`) compares with that same either-mastoid bone, so it is on
for her right ear once only her left bone is measured, and off on the left. The coach names the start: "First masked
beep at %d dB, the unmasked bone. Noise %d. Hold [key]." / "Start at the unmasked bone, %d dB: the better cochlea's.
Tap [key] N." While the poorer ear's bone is unknown (the demo, and its `bc` / `bc_masked` plans with the deck), its
chart shows dashed amber **"?" ranges** from the unmasked bone up to that ear's air (`Audiogram.bone_range`) wherever
masked bone is needed and not yet stamped, with the legend "? = bone hiding here: mask to find it". The coached
LEFT bone sheet (the route lesson, B) never mentions noise or masking and shows no blinking or "?".
UI internals added for this (builder A, `ui/audiometer/`): `AoButton.denied` (signal: a locked button was clicked,
after its wiggle and error blip), `AoEarCard.badge` ("TESTING" / "GHOST TEST"; no pips when `progress_total <= 0`),
`AoQuestPanel.note` (multi-line; no bar when `total_count == 0`), `FxLayer.ghost(..., life := 2.0)`.

The required measurements are those of the goal sheet: `ac` as below; `bc` = `bc_freqs`; masked sheets =
`ClinicRules.masked_freqs_needed()` from what is stored so far (bone: gap > 10; air: AC - 40 >= the other
ear's bone estimate). The player can switch sheets with the controls (transducer x masking on/off picks the
sheet: `test_for(transducer, mask_on)`), but the test finishes when the goal sheet is complete. Masked
measurements start at the unmasked stamp; after a masked store the noise dial moves to the next frequency's
initial level. The masker plays in the non-test ear whenever masking is on (§1.3).
**(polish)** If the goal sheet is not `ac` and is already complete when `start_test` runs (insert earphones: no
masked air is needed), the test finishes at once with `nothing_title`; nothing waits for input. While the masking
deck shows, STORE on the wrong sheet (an unmasked stamp during a masked test) is refused with a tip naming the key
to press. Unmasked bone heard by the other cochlea flies the Ghost only once a bone mark sits next to the air mark
("Bone 10, air 50? BOO!"); before that a small "boo?" chip. Hoot's coach explains the covered-ear (occlusion) bonus
once, and a one-time tip names a "shadow chase" (heard, then missed at the same tone after one noise raise).
**(v3, builders)** The route lesson: a COACHED `bc` plan with the masking deck starts on AIR while the ear has no
bone stamps yet, so the player presses B (uncoached bone plans start on bone). With `hoot_turn_after` 0 Hoot runs
the whole test ("My turn!"); when his turn starts right after the coached stamp, the coach's "now you lead" line
is skipped (integrator).

Events it emits:
- `audiometry_started`;
- **(v3)** `masker_changed`, `transducer_changed`;
- `tone_started` / `tone_stopped`;
- `patient_responded`;
- `audiometer_state_changed` (on every change);
- `threshold_stored`;
- `technique_event`;
- `combo_changed`;
- `ear_completed`;
- `audiometry_finished`, once per `start_test`;
- `patient_reaction` (forwarded from the session);
- `screen_shake` (the too-loud gag).

Required measurements per ear, in the recommended order (**E1**, `ClinicRules.TEST_ORDER`):
1. 1000, 1500, 2000, 3000, 4000, 6000 and 8000 Hz (`ROUTINE_FREQS`);
2. a 1000 Hz retest (**E2**: the first air ear of the visit only);
3. 500 and 250 Hz;
4. 750 Hz when 500 Hz and 1 kHz differ by 20 dB or more (`required_interoctaves` still flags any half-octave
   whose octaves differ that much, but the others are routine).

After a store, the screen moves to the next remaining frequency (the rule is in `required_remaining`).

### §4.3 `get_state()` / `audiometer_state_changed` keys

```
{
  "patient_id": "gus", "ear": "right", "freq": 1000, "db": 40, "tone_on": false,
  "accepting_input": true, "coached": true,
  "freqs_available": [250, 500, 750, 1000, 1500, 2000, 3000, 4000, 6000, 8000],
  "min_db": -10, "max_db": 120,                       # for the current freq
  "stored": {"right": {1000: 25, ...}, "left": {}},   # freq -> stored dB (no-response = max_db)
  "remaining": [1500, 2000, 3000, ...],               # required, not yet stored, current ear
  "ear_complete": false, "combo": 0, "presentations": 0,
  # v2 extras (builder A):
  "points": 1200, "multiplier": 3,                    # arcade points and combo multiplier
  "trail": [...],                                      # this measurement's presentations (db, heard), for the LCD
  "strokes": 4, "par": 9,                              # presentations so far vs this measurement's par
  "candidate_db": 25,                                  # level that would be stored now, -1 if none yet
  "stimulus": "pure",                                  # "pure", "pulsed" or "warble"
  "hoot_turn": false,                                  # quick visit: Hoot is finishing the ear at x8 (input locked,
                                                       #   accepting_input false, his stamps carry "by_hoot": true, golf &"hoot")
  "quick_visit": true,                                 # setting "quick_visit" (or --quick / --full)
  # v3 (Chapter 2). "stored" is the CURRENT sheet; "remaining" / "ear_complete" are the GOAL sheet;
  # "freqs_available" and "max_db" follow the transducer (bone: 250-4k, BC_MAX_DB).
  "test": &"bc_masked",                                # sheet the controls point at (transducer x masking)
  "goal_test": &"bc_masked",                           # the plan's test
  "transducer": &"bone", "air_transducer": &"phones",
  "masking_controls": true,                            # the MASKING / ROUTE buttons are shown
  "masking_deck": true,                                # (polish) the MASKING group is on the deck (plan masking_deck)
  "mask_on": true, "mask_db": 25, "mask_ear": "left",  # masker dial (dB EM) and the ear it plays in
  "mask_status": &"ok",                                # ClinicRules.MASK_STATUSES (the NOISE box light)
  "initial_mask_db": 25,                               # the helper's starting level here (0 without masking UI)
  "start_mask_db": 25,                                 # (E9) where the coach starts the noise: initial_mask_db, or one
                                                       #   step under overmasking in a masking dilemma
  "overmask_limit_db": 50,                             # noise at or above this overmasks (bone: tone + 40; air: test-ear bone + 40)
  "plateau": {"db": 10, "steps": 2, "needed": 3, "found": false, "start_mask": 25, "initial": 25, "points": [...]},  # masked sheets only, else {}
  "stored_tests": {"ac": {"right": {...}, "left": {...}}, "bc": {...}, "bc_masked": {...}, "ac_masked": {...}},
  # v4
  "demo": false                                        # the one-tone Ghost demo is on (plan demo_tone): only TONE works;
                                                       #   "par" is 0 while it is on
}
```

Before the first `start_test`, `accepting_input` is false and `stored` is empty.

### §4.4 Threshold info (`threshold_stored` and `results.ears[ear].freqs[freq]`)

```
{
  "ear": "right", "freq": 1000, "stored_db": 25, "true_db": 25, "error_db": 0.0,
  "no_response": false, "strokes": 6, "par": 7, "golf": &"birdie",   # golf_name(strokes, par)
  "accuracy": 1.0,                       # ClinicRules.accuracy_for_error
  "errors": [&"store_wrong_level"],      # technique kinds found at this store
  "technique_ok": true, "retest": false, "masked": false, "order_index": 0,
  # v2 extras: "redo" (a repeat of an already stored freq), "candidate_db", "responses", "points"
  # v3: "test" ("ac" / "bc" / "bc_masked" / "ac_masked"), "transducer", "mask_db" (-1 = off),
  #     "plateau" (masked sheets: plateau_info at the store), "start_db", "by_hoot", "clean", "golf_raw";
  #     masked "responses" are [db, heard, mask_db]
  # clinical review E9: "plateau_not_reached" (true = a masked stamp stored because the safe window was
  #     full, or in a masking dilemma, before a plateau: the true threshold may be poorer; the audiogram
  #     draws a purple "?" badge; a stamp at or better than true_db scores full accuracy)
}
```
**(v3)** `true_db` is the response threshold for that sheet: unmasked bone = whichever cochlea answers first
(the better one), masked bone = the bone threshold, masked air = the air threshold. A masked
store is the plateau level when a plateau was found, else the ascending threshold.
**(v3, builders; polish)** `AudiometrySession.MASKED_GRACE_DB` is now 0: masked stamps are scored like any other.
The plateau's upward drift is removed at the source instead (the simulator's masked calibration, §4.8).
**(polish)** Unmasked air `true_db` is the shadow curve too: the better of the test ear and the other cochlea
through the air IA (unchanged for Gus and Bonnie, whose real IA keeps the shadow out of reach).
**(v2)** `par` is dynamic: the median presentations of a textbook search from the level this measurement
started at (typically 7-13), not the constant 7.

`true_db` is the patient's truth, for scoring and the reveal only. Gameplay code and the bot must never use
it during the test.

### §4.5 Technique kinds (`Events.technique_event(kind, data)`)

`data` always has `ear` and `freq`. Error kinds also carry `message`: a Hoot line of 18 words or fewer, from `AudiometrySession.TIPS`.
**(v3, builders)** `TIPS` hold pronoun tokens (`{he}`, `{his}`, ...): read them with `session.tip_text(kind)`. The
`message` in the signal data is already filled in for the patient.

**Errors.** Each one breaks the combo and lowers the technique score.

| kind | when | data |
|---|---|---|
| `wrong_step` | the next level breaks the stepping rule: heard means down 10; missed means up 5, or before any response at this frequency, up 10 (up 5 is tolerated) | expected, got, prev_db, prev_heard |
| `start_too_high` | the first tone of a measurement is above `MAX_START_DB` (70) | db |
| `store_without_bracket` | stored with no level heard twice on ascending runs | db |
| `store_wrong_level` | stored a level that is not the lowest one heard twice ascending | db |
| `start_not_1k` | the first store of an ear isn't 1000 Hz | db |
| `missed_retest` | **(E2) no longer raised**: the lows may come before the retest (BSA 2018 retests after 250 Hz); the retest stays required on the ear that owes it | db |
| `retest_mismatch` | the 1 kHz retest differs by more than 5 dB (**E3**: a `retest_why` observation follows) | db |
| `nr_too_early` | "no response" stored without a miss at the maximum level | db |
| `tone_too_short` / `tone_too_long` | tone under 0.5 s / over 3 s | duration_s |
| `rhythmic` | the last 4 gaps between tones vary by less than 0.3 s | spread_s |
| `too_loud` | a tone 45 dB or more above the true threshold (visual gag, −1 comfort) | db, sl |
| `marathon` | more than 3x par tones at one frequency (−1 comfort) | strokes |
| `store_far_off` **(v2)** | the stored level is far from the patient's real threshold (bracket more carefully) | db |

(v2) `too_loud` data also has `comfort_loss`: 1 for the first too-loud tone of a measurement, else 0.

**Positive and neutral observations:**

| kind | data |
|---|---|
| `textbook_step` | db, combo |
| `good_start` | db, combo |
| `store_ok` | db, combo |
| `retest_ok` | diff |
| `birdie` / `eagle` / `albatross` | (no extra fields) |
| `missed` | db |
| `false_alarm` | (no extra fields) |
| `interoctave_needed` | freq = the half-octave that is now required (**E1**: only 750; 1.5k, 3k and 6k are routine) |
| `not_instructed` **(v2)** | db (the patient guesses because nobody told him what to do) |
| `phones_swapped` **(v2)** | db (he points at the other ear: the phones are on the wrong ears) |
| `retest_why` **(E3)** | diff, better, lines (right after `retest_mismatch`, scored only: Hoot's lines from `retest_beat(ear)`; the screen says them the first time a visit has one, then the short tip) |
| `short_gap` **(E6)** | gap_s (a gap shorter than the beep before it and under `ClinicRules.SHORT_GAP_S` 1.0 s, or a guess after a short gap; the tip once per visit). The rushed gap breaks the combo with no error and no technique cost |

**(v3) Masking errors** (masked sheets only):

| kind | when | data |
|---|---|---|
| `mask_too_low` | the first masked tone of a measurement with the noise below the initial level (**E9**: in a masking dilemma, below the safe maximum `safe_mask_max_db`) | mask_db, initial_db |
| `mask_start` | the first masked tone more than 10 dB from the unmasked threshold | db, start_db |
| `mask_wrong_step` | not the plateau dance: heard = noise +5 (same tone), missed = tone +5 (same noise) | expected, expected_mask, got, got_mask, prev_db, prev_heard |
| `store_no_plateau` | stored before 3 noise raises held (not when `window_full`: one more step would overmask) | db |
| `overmasked` | the noise reached the overmasking limit (once per measurement; not a check) | mask_db, limit_db |

On non-`ac` sheets `start_not_1k`, `missed_retest` and the inter-octave rule do not apply.

**(v3) Observations:** `cross_hearing` (unmasked bone: the other cochlea answered; **E4** `cross_hearing_air` for an
unmasked air tone, "Time to mask."), `undermasked` (masked: it still did), `plateau_step` {steps, needed, db, mask_db, found, window_full, auto} after every masked verdict, `plateau_found`
{db, start_mask, end_mask}, `vibrotactile` {db} (a felt low bone tone). **(E9)** `masking_dilemma` {initial_db,
limit_db} (the first scored masked tone where the initial masking already overmasks) and `plateau_not_reached`
{db, mask_db, limit_db} (the safe window filled before a plateau), each once per visit. **(E8)** `tinnitus_steady`
{tinnitus_hz} (the first scored steady tone near the patient's tinnitus pitch; once per visit).

Combo multiplier (`combo_changed`): x1, x2 at 3, x3 at 6, x5 at 10 consecutive clean checks.

### §4.6 Audiogram widget: `res://ui/audiogram/audiogram.tscn` (`class_name Audiogram`, Control)

```
@export var ear: String = "right"            # "right", "left" or "both"
@export var show_title: bool = false
signal draw_finished                         # after show_results(..., animate) finishes
func set_point(ear, freq, db, no_response := false, animate := true) -> void
func clear_points() -> void
func show_results(results: Dictionary, animate := false) -> void     # §5.1
func set_cursor(freq: int, db: int, visible: bool) -> void
func freq_to_x(freq: int) -> float          # local coordinates
func db_to_y(db: float) -> float
func get_point_global_position(ear, freq) -> Vector2
func get_region_global_rect(freq_lo, freq_hi, db_lo := -10, db_hi := 120) -> Rect2
# v2 (builder A):
signal freq_clicked(freq: int)               # the player clicked a frequency column
func play_melody(ear, step_s := 0.2) -> float   # plays the "audiogram melody", returns its length
func point_count(ear) -> int
func freq_at(local_x: float) -> int          # nearest test frequency, -1 outside the plot
# v3:
func set_point(ear, freq, db, no_response := false, animate := true, test := &"ac") -> void
# clinical review E9: set_point(..., test, no_plateau := false) draws the purple "?" badge (plateau not
#   reached) beside a masked symbol; show_results() reads it from "plateau_not_reached" (§4.4)
func point_count(ear, test := &"ac") -> int
func get_point_global_position(ear, freq, test := &"ac") -> Vector2   # includes the bone symbol offset
var layers: Dictionary                        # test -> ear -> freq -> point (the non-ac sheets)
var cursor_test: StringName = &"ac"           # the cursor ghost's symbol
var max_output_transducer: StringName = &"phones"   # &"bone" shades the bone maximum output
# show_results() also loads "ac_masked", "bc" and "bc_masked" (§5.1 v3)
# (v3, builders) optional layers, all off by default (Day 1 never sets them):
var attention: Dictionary                     # test -> ear -> freq -> true: the masking assistant's blinking symbols
var show_gap: bool                            # the air-bone gap bridge (dashed "45?" posts on unmasked bone, solid on masked)
var masker_view: Dictionary                   # the masker on this chart: {freq, db, ...} draws the noise curtain
var dim: Dictionary                           # (polish) ear -> alpha (1 = normal): fades one ear's symbols, lines and layers
var bone_range: Dictionary                    # (v4, builder A) ear -> freq -> [lo_db, hi_db]: a dashed amber "?" capsule
                                              #   beside the air mark (unknown bone) + the legend "? = bone hiding here: mask to find it"
```

What it draws:
- a log-frequency axis (250 Hz to 8 kHz) and a dB axis from -10 at the top down to 120;
- a normal-hearing band;
- the ASHA symbols: right = red O, left = blue X, no response = a symbol with a down-pointing arrow;
- **(v3)** bone and masked symbols (`UiDraw.audiogram_symbol`): masked air (triangle / square) replaces O / X at
  its frequency and the air line runs through it; masked bone ([ / ]) replaces unmasked bone (< / >); bone
  symbols sit beside the frequency line and are never joined by lines.

Story uses it for the reveal and the evidence beat.

### §4.7 Input actions and key style

The actions live in `project.godot` (generated by `tools/setup_input_map.gd`, `device = -1`).
Default key style `"otosuite"`:

| action | default keys | meaning |
|---|---|---|
| `present_tone` | Space (hold) | tone on while held |
| `louder` | Up | +5 dB |
| `softer` | Down | −5 dB |
| `freq_up` / `freq_down` | Right / Left | next or previous frequency |
| `store` | S, Enter, Keypad Enter | store threshold |
| `no_response` | N | store no response |
| `ear_right` / `ear_left` | R / L | select ear |
| `toggle_mask` | M | **(v3)** masking noise on / off (Day 2 deck) |
| `mask_louder` / `mask_softer` **(v3)** | PgUp / PgDn, and Shift+Up / Shift+Down | masker +5 / -5 dB EM |
| `transducer_bone` / `transducer_air` **(v3)** | B (and 8) / A (and 6) | route the tone to the bone oscillator / back to the earphones |
| `toggle_key_hints` **(v2)** | H | show / hide the key chips |
| `advance_dialogue` | Space, Enter, Keypad Enter | next dialogue line |
| `pause` | Esc, P | pause menu |

The `"affinity"` style swaps the events of `louder` and `softer`, so Up = softer. **(v3)** It also swaps
`mask_louder` and `mask_softer`. Shift+Up also matches plain `louder` (Godot's modifier matching), so the
AudiOtron checks the `mask_*` actions before `louder` / `softer`.
- Switch it with `Game.set_key_style()`, the pause-menu toggle, or `--affinity`.
- Code must listen for the action names, never keycodes, and show key hints with `Game.key_label(action)`.
  Refresh the hints on `Events.key_style_changed`.

The key chips are on by default (`settings.show_key_hints`). First-time players get the coached right ear.

### §4.8 core internals (builder A may change freely)

- `AudiometrySession` (RefCounted): pure logic with `advance(delta)`. Methods:
  - controls: `set_ear`, `step_freq`, `set_freq`, `step_level`, `tone_down`, `tone_up`;
  - storing: `store`, `store_no_response`;
  - queries: `ascending_threshold`, `required_remaining`, `is_ear_complete`, `stored_thresholds`, `build_results`.
  - **(polish)** `ascending_threshold` also answers `MIN_DB` (-10) when the open measurement was heard twice at -10 dB HL:
    nothing softer to bracket from, so a store there is by the book (`textbook_presentations` and the bot agree).
- `PatientSim`: logistic psychometric model with attention, fatigue, false alarms, reaction time and groove.
  - `THRESHOLD_BIAS_DB` 2: the curve's 50 % point sits 2 dB below the profile threshold, so a by-the-book 2-of-3
    ascending search writes down the profile value about 80 % of the time (and 5 dB either side otherwise).
    With 0 it is a coin flip between T and T+5, and a perfect player would lose accuracy points (integrator, v2).
- **(v3)** `AudiometrySession`: `configure(plan)`, `test`, `goal_test`, `transducer`, `air_transducer`, `mask_on`,
  `mask_db`, `set_transducer`, `set_mask`, `toggle_mask`, `step_mask`, `set_mask_level`, `masker_ear`, `test_for`,
  `initial_mask_db`, `overmask_limit_db` (bone: tone + IA; air: the test ear's best bone, or the nearest measured
  bone frequency's, + IA), `masking_needed_here` (**(v4)** bone: the ear's air vs `ClinicRules.unmasked_bone()`, else
  `nontest_bone_estimate`), **(v4)** `discard_open(e, f)` (drops the open measurement, closes its tone record and
  cancels any patient press or anticipation still on its way: the Ghost demo), `mask_status`, `plateau_info`, `store_candidate` (the plateau
  level, or the held level once `window_full(e, f)`), `window_full`, `results_view`; per-test sheets; `MASK_PAR_SLACK` 2 (masked par = textbook dance + 2).
  **(Clinical review E9)** `safe_mask_max_db(e, f, tone_db)` (one step under the overmasking limit), `start_mask_db`
  (the initial masking, or the safe maximum in a dilemma: where the coach starts the noise), `in_dilemma`.
- **(polish)** `AudiometrySession`: `MASKED_GRACE_DB` 0 (a masked stamp is scored like any other: the simulator is
  calibrated instead); `retest_waived: Dictionary` (ear -> true: no 1 kHz retest needed); **(E2)** `retest_required(ear)`
  (only the first air ear of the visit, `air_ear_order[0]`, owes the 1 kHz retest, or the second too when the first ear's
  retest was off by more than 5 dB; a waived ear never; a voluntary retest on another ear is still graded) and
  `air_ear_order: Array[String]`; **(E3)** `retest_beat(ear) -> Array[String]` (after a retest more than 5 dB off: why we
  retest, from `RETEST_WHY_BETTER` or `RETEST_WHY_WORSE`, re-instruct and recheck, plus `RETEST_OTHER_EAR` on the first
  air ear; [] when it agreed); **(E6)** `last_tone_dur` (the last beep's length); `instant_measure(ear, freq)
  -> Dictionary` runs one whole textbook measurement at once through the public controls with simulated time (Hoot's
  montage; returns {} while a tone is on or while scoring is on). The unmasked air truth (`response_truth(&"ac")`) is
  the shadow curve: the better of the test ear and the other cochlea through the air IA, so an unmasked stamp that
  the other ear heard is scored as correct for an unmasked sheet.
- **(polish)** `PatientSim`: `MASKED_BIAS_DB` 4, `MASKED_SLOPE_SCALE` 0.7, `MASKED_LAPSE_SCALE` 0 under masking (the
  noise makes answers steadier, not looser), so a by-the-book plateau search lands on the profile value about 70-80 %
  of the time and masked air agrees with unmasked air. This is a gameplay calibration, not a model of central masking.
- **(polish)** `ToneGenerator.render()`: the masker keeps playing when a tone ramps out (it never drops with the tone).
- **(v3)** `PatientSim`: `transducer`, `masker_db`, `masker_transducer`, `condition()`, `condition_for(ear, freq, tr,
  mask, mask_tr)` (via `ClinicRules.response_threshold`), `last_heard_by` (&"test" / &"cross", reactions only).
- **(E8)** `PatientSim.steady_tone` (false = pulsed or warble, the E7 default) and `tinnitus_confuses(freq)`: within
  `TINNITUS_OCTAVES` (0.6: the half-octave pitches either side) of `profile.tinnitus_hz` a steady tone near threshold is missed `TINNITUS_MISS_P` (35 %) more
  often, and `false_alarm_tick(delta)` presses `TINNITUS_FA_FACTOR` (3) times as often while `dialled_freq` is in range. The
  session sets it (`set_steady_tone(on)`, `steady_tone`); the AudiOtron passes its stimulus before every tone.
- `ToneGenerator` (Node): `AudioStreamGenerator` at 44.1 kHz on the Tones bus.
  - **(v3)** masker: `start_masker(ear, freq, db_em)`, `set_masker(freq, db_em)`, `stop_masker()`, through `AudioSafety` (§1.3).
  - **(v3, builders)** `bone: bool` (set by the AudiOtron when the route is bone) and `BONE_CROSS_DB` -10: a bone tone also
    plays in the other channel, 10 dB softer (§1.3).
  - 25 ms raised-cosine ramps.
  - The right ear plays on the R channel.
  - `start_tone(ear, freq, hl)`, `stop_tone()`, `set_level(hl)`, `is_on()`, `current_peak()`.

Only §4.2–§4.7 and §5.1 are contracts.

---------------------------------------------------------------------------------------------

## §5 Results and scoring

### §5.1 Results (`test_finished`, `audiometry_finished`, `get_results()`)

```
{
  "patient_id": "gus", "patient_name": "Grandpa Gus",
  "ears": {
    "right": {
      "freqs": {1000: {...§4.4...}, 2000: {...}, ...},   # one entry per stored freq (retest not here)
      "complete": true,
      "retest_1k": {"stored_db": 25, "diff": 0, "strokes": 5},   # {} if not done
      "order": [1000, 1500, 2000, 3000, 4000, 6000, 8000, 1000, 500, 250],  # store order (1000 twice = retest)
      "strokes": 66, "par": 70,            # tone presentations vs par, incl. retest
      "accuracy": 0.95,                    # mean of the freq accuracies
      "shape": &"sloping",                 # ClinicRules.classify_shape
      "pta": 28.3,                         # 500/1k/2k average (NAN if missing)
      "coached": true
    },
    "left": {...}                          # present once the left ear was started
  },
  "technique_errors": [{"kind": "wrong_step", "ear": "right", "freq": 2000, "db": 35, "message": "..."}],
  "presentations": 150, "false_alarms": 1, "max_combo": 23,
  "accuracy": 0.93,        # 0..1, mean over every stored freq of both ears
  "technique": 0.98,       # 0..1, clean checks / checks
  "efficiency": 0.71,      # 0..1, min(1, total par / total strokes)
  "score": 89.4,           # 0..100 from accuracy/technique/efficiency only (care added in §5.3)
  "grade": "A",
  "duration_s": 210.5,     # session game-seconds
  # v2 extras: "points" (arcade points), "false_hits", and per ear "golf" (fair golf: strokes minus par summed over the player's holes, a clean hole never above par and a slipped one never below; "golf_raw" is the plain sum; Hoot's quick-visit holes are excluded and counted in "hoot_holes")
}
```

**(v3)** Per ear also:
```
"bc": {500: {...§4.4...}, ...}, "bc_masked": {...}, "ac_masked": {...},   # the other sheets, like "freqs"
"complete_tests": [&"ac", &"bc", ...],    # sheets whose required set is stored ("complete" still means AC)
"best_ac": {500: 55, ...}, "best_bc": {500: 10, ...},   # masked where measured
"abg": {500: 45, ...},                   # best AC - best BC
"hearing_type": &"conductive",           # ClinicRules.hearing_type (normal / conductive / sensorineural / mixed / unknown)
"abg_red_flag": true,                    # gap >= 15 at 500, 1k and 2k
"carhart_notch": true                    # from masked bone
```
and at the top level `"tests"` (sheets with any stamps) and `"air_transducer"`. Accuracy, technique, efficiency
and the totals cover every sheet.

The freq keys are `int`. The stub doesn't include the full per-presentation trails. Builder A may add keys,
but must not rename or remove these.

### §5.2 Scoring

- **Visit score:** `100 x (0.40·accuracy + 0.30·technique + 0.15·efficiency + 0.15·comfort/3)`.
- **Grades:** S at 95 or more, A at 85, B at 70, C at 55, and "Do-over" below that.
- **Coins:** `round(score/2)` plus the medal bonus (gold 10, silver 6, bronze 3).
- **Par (v2):** per measurement, the median presentations of a textbook search from that measurement's start
  level (typically 7-13). Golf names use run-sized bands (§2.5). Teaching defaults that need playtesting.
- **(v3) Masked par:** the presentations of the deterministic textbook plateau dance from the measurement's start
  (initial noise, tone at the unmasked stamp; **E9:** the safe maximum in a dilemma, ending once the window is full) + 2. Masking errors (§4.5) lower technique like any other.

### §5.3 Visit summary (`Game.finish_visit()`, `Events.level_finished`)

```
{
  "patient_id": "gus", "score": 91.2, "grade": "A",
  "accuracy": 0.93, "technique": 0.98, "efficiency": 0.71, "care": 1.0, "comfort": 3,
  "medals": {"history": "gold", ...}, "coins_earned": 76, "coins_total": 76,
  "duration_s": 402.0, "audiometry": {...§5.1...},
  # v3
  "patient_name": "Grandpa Gus", "chapter_id": "gus", "day": 1,
  "newly_unlocked": [],                # (polish) always empty: every day is open
  "next_chapter_id": "bonnie",         # the suggested day when it comes earlier in order than this one (a later day played first); else the day after this one in order; after the last chapter the suggested day (polish), "" when all are done
  # polish
  "patient_short": "Gus",              # PatientProfile.short_name()
  "first_clear": true,                 # this visit finished the chapter for the first time
  "suggested_next": "bonnie"           # Game.suggested_chapter_id() after this visit ("" = every day done)
}
```

---------------------------------------------------------------------------------------------

## §6 Clinic (builder B): `res://world/clinic.tscn`

### §6.1 API (root `Node3D`, `class_name Clinic` in the stub)

The root registers with `Stage` in `_enter_tree` and unregisters itself in `_exit_tree`. It listens to
`Events.patient_reaction` and `Events.screen_shake`. Story calls these methods by name, and awaits the ones marked coroutine.

```
const REACTIONS: Array[StringName]             # §6.2
const SHOTS: Array[StringName] = [&"wide", &"door", &"desk", &"booth", &"ear_right", &"ear_left", &"face", &"otoscope", &"title", &"fitting"]  # v2: + title, fitting
const SPOTS: Dictionary[StringName, Vector3]   # &"door", &"desk", &"booth"
func walk_in() -> void                         # coroutine: door bursts open, Gus to the desk
func walk_to(spot: StringName, duration := 2.2) -> void   # coroutine
func sit() -> void                             # coroutine: to the booth chair
func stand() -> void                           # coroutine
func focus_camera(shot: StringName, duration := 0.8) -> void   # coroutine; 0 = cut
func put_on_earphones(red_on_right := true) -> void
func take_off_earphones() -> void
func play_patient_reaction(kind: StringName, data := {}) -> void   # unknown kinds ignored
func set_world_saturation(amount: float) -> void   # 0 grey and muffled .. 1 full colour (fitting)
func get_booth_texture() -> Texture2D          # live view for the AudiOtron (ViewportTexture)
func set_booth_view_active(active: bool) -> void
func get_ear_screen_position(ear: String) -> Vector2   # via the main camera (for drag targets)
func get_patient() -> Node3D
func get_main_camera() -> Camera3D
func hoot_emote(kind: StringName) -> void      # &"wing_up", &"facepalm", &"nod", &"hop"
func demo_start() -> void                      # standalone showcase (--scene)
# v2 story extras (called by name; see world/INTEGRATION_NOTES.md):
# doris_enter() (coroutine), doris_react(kind), gus_look(target), set_title_mode(on), play_birdsong(),
# get_head_screen_position(), take_off_glasses(), put_on_glasses(), put_on_hearing_aids(), get_muffle() -> float
# (D2-8) head gear takes glasses off first; those come back when the patient stands (world/INTEGRATION_NOTES.md)
# v3 (Chapter 2):
var patient_id := ""                           # set BEFORE add_child: "bonnie" builds Bonnie (the node is still `gus`)
func put_on_bone_oscillator(ear := "right") -> void   # headband + vibrator on the mastoid (takes the earphones off)
func put_on_masking_phone(ear := "left") -> void      # one earphone for the noise during bone tests
func take_off_bone_oscillator() -> void               # removes both
# (v3, builders) story extras, called by name:
func put_down_basket() -> void                        # Bonnie's croissant basket onto the desk (sit() calls it too)
func give_croissant() -> void                         # coroutine: a croissant hops to Hoot
func walk_out() -> void                               # coroutine: stand, wave, out through the door
func patient_name() -> String                         # "Gus", "Bonnie" (lip-sync follows this speaker)
# (v3, builders) the clinic also listens to Events.masker_changed (the first masker-on of a test busts a peeking
# Ghost: "SHOO!"), technique_event(&"plateau_found") ("BUSTED!"), transducer_changed and the tone events (the
# oscillator buzzes with rings and "bzz" while a bone tone plays). All visual only.
```
**(v2)** `set_world_saturation` muffles at the sound sources (quieter, lower), never with bus effects. Nobody adds
or removes bus effects at runtime: it can deadlock the audio thread (world/INTEGRATION_NOTES.md).

During audiometry the story turns the main camera off (`current = false`). The AudiOtron covers the
screen and only the booth SubViewport renders.

In the cartoon world, Gus's right ear is world −X. The red cup goes on it.

### §6.2 Reaction kinds (`Events.patient_reaction(kind, data)`)

`heard`, `missed`, `false_alarm`, `too_loud_blast`, `startle`, `grooving`, `bored`, `straining`,
`squint`, `yawn`, `cheer`, `confused`, `point_wrong_way`, `nod`, `wince`.

**(v3)** The session also emits `cross_heard` {ear, via, db, masked} (the Ghost), `tickle` {ear, db} (a felt low
bone tone) and `overmasked` {ear, masker_ear, mask_db}. **(v3, builders)** `Clinic.REACTIONS` lists them, plus `wave`
(the story's hello and goodbye), and the clinic plays them: the 3D Cross-Hearing Ghost (`world/characters/ghost.gd`)
flies from the test ear to the other ear, Bonnie giggles at a tickle, and overmasking gives her spiral eyes.
The AudiOtron shows its own gags too (the BOO! on the chart). Unknown kinds are still ignored.

`data` may include `ear`, `intensity` (0..1) and `db`. Reactions are visual and must be safe to fire every
tone. `too_loud_blast` is a hair-blast or wobble, and with `no_startle` it becomes a small wobble.
New kinds go through `world/INTEGRATION_NOTES.md`.

---------------------------------------------------------------------------------------------

## §7 Autoplay, screenshots and test contract

### §7.1 Command line (user args after `--`, parsed into `Game.cli`)

| arg | effect |
|---|---|
| `--autoplay` | adds `tools/autoplay_bot.gd`. Fresh separate save, seed 1234, the game quits itself. |
| `--shots=/abs/dir` | adds `tools/screenshot_service.gd`, which saves PNGs (rendered runs only) |
| `--shot-at=1.5,4` / `--quit-at=6` | timed shots and quit, in game seconds |
| `--scene=res://path.tscn` | boot that scene instead of the title and call its `demo_start()` |
| `--seed=N` | `Game.rng` seed |
| `--speed=N` | `Engine.time_scale` |
| `--affinity` | key style "affinity" for this run |
| `--fresh` | reset the save |
| `--save=user://x.json` | use another save file |
| `--mouse` **(v2)** | with `--autoplay`: the bot plays the whole level with real mouse events only (exit 6 if a target is missing) |
| `--day=N` / `--chapter=id` **(v3)** | Play (and the bot) starts that chapter |
| `--unlock-all` **(v3)** | **(polish)** accepted and ignored: every chapter is always open |
| `--keep-save` **(v3, integrator)** | with `--autoplay`: keep the save instead of resetting it (chain Day 1 then Day 2 with the same `--save=`) |
| `--upgrades=a,b` **(polish)** | own these shop items for this run (e.g. `insert_earphones`), after the save reset |
| `--demo` **(demo)** | the career-fair demo (§14, docs/DEMO.md); on the web, `?demo` in the page's address |
| `--attract-after=N` **(demo)** | with `--demo`: the title's attract loop starts after N seconds with nobody there (default 30) |
| `--via-days` **(v3, integrator)** | with `--autoplay`: start from the title's Days card with real input (clicks with `--mouse`, else ui_* keys) instead of Play. Options: `--pick=<chapter id>` (default `next`; any day on any save, nothing is locked), `--expect-days=gus,bonnie` (the listed days must be on the grid, in that order; other days may sit between or after them), **(polish)** `--expect-suggested=<id>` (the card with the UP NEXT badge). With `--mouse` the bot rolls the wheel over the grid until the card is in view. The result gets a `days` report; a failed expectation is a problem (exit 4) |

### §7.2 What the bot relies on (must keep working)

The bot (`tools/autoplay_bot.gd`) plays the whole level **only through public contracts**:

1. **Outside the audiometer:** each `Events.awaiting_input`. It waits 0.6 game seconds, takes the phase screenshot,
   then calls `solver`.
2. **Audiometry.** On `Events.audiometry_started` it plays real `InputEventAction`s through `Input.parse_input_event`:
   - the actions `present_tone`, `louder`, `softer`, `freq_up`, `freq_down`, `store`, `no_response`, `ear_right` and `ear_left`;
   - it reads only `Stage.audiometer.get_state()` and `Events.patient_responded`;
   - it runs a real Hughson-Westlake search: down 10 / up 5, 2 of 3 ascending, the 1 kHz retest and the inter-octaves;
   - it varies the tone lengths and the gaps between tones;
   - it never reads true thresholds.
   - **(v3)** On other goal sheets (`get_state().goal_test`): it routes the controls (`transducer_bone` /
     `transducer_air`, `toggle_mask`), runs the same search on bone (max output from `max_db`), and on masked
     sheets the plateau dance with `mask_louder` / `mask_softer`: noise to `initial_mask_db`, tone to its own
     unmasked stamp, heard -> noise +5, missed -> tone +5, store after 3 held raises (or before
     `overmask_limit_db`). **(v4)** For masked bone the start is its own unmasked bone stamp at that frequency
     from EITHER mastoid (the lower), else the level the screen suggests (`db`).
   - **(v4)** When `get_state().demo` is true it only holds TONE (up to 3 tones, stopping at the first heard) and
     waits; it treats `Events.audiometry_finished` as the end of any test (the demo emits no `ear_completed`).
   - **(v4)** The `explainer` beat with keys: **(polish)** `advance_dialogue` (it advances like dialogue) until
     scene 2 shows (at most 4 taps), a shot (`explainer_scene_2`; a recap: `explainer_<id>`), then `ui_cancel`
     (skip); the solver only if the movie still plays. With `--mouse`: real clicks on "Next" the same way, then
     "Skip movie". The masking recap card is the same beat: a one-scene movie gets no tap (it would end it), and
     its shot waits until all four lines are in.
3. **Ending.** On `Events.level_finished` it records the summary. On `results_continue` it prints
   `AUTOPLAY_RESULT {json}` and emits `Events.quit_requested(code)`.

**Exit codes:**

| Code | Meaning |
|---|---|
| 0 | ok |
| 2 | stalled for 120 game seconds |
| 3 | overall timeout |
| 4 | results sanity check failed: an ear is incomplete, a threshold is off by more than 10 dB (any sheet, v3), or there was no `level_finished`; **(v3)** on Day 2 also: Bonnie's right ear not conductive, no red flag, masked bone missing at 500-4k, or no masked air; **(v4)** left unmasked bone missing at 500-4k, any unmasked RIGHT bone stamp, no `explainer` or `ghost_demo` phase, no movie on a fresh save, or no demo tone. The Day 2 result adds `movies` and `ghost_demo_tones` |
| 5 | script errors were logged |
| 6 | (`--mouse`) a mouse target could not be found on screen |

**Mouse-only mode (v2, `--mouse`).** Beats are solved by clicking or dragging what a player sees: the Hoot anchors
(`otoscope_seed`, `earphone_red` -> `ear_target_right`, `evidence_slope` -> `evidence_target`, **(v3)** `oscillator` ->
`mastoid_target_right` (**v4**: the beat's `targets[0]`, so `mastoid_target_left` first), `referral_stamp`, **(v4)** the movie's
"Next" / "Skip movie" buttons, **(Speech)** any beat whose info carries `mouse` (§9.9), the day card by its title, the AudiOtron buttons incl. the masking deck;
TONE is a held left button), visible buttons and choice rows by their text, and the dialogue box. On the results
paper it clicks "Back to the title" and checks that the title scene returns. Mouse events are sent in window
coordinates (`get_viewport().get_final_transform()`), because the headless window is only 64x64.

So, every module must:
- **Story:** emit `awaiting_input` with a working solver for every blocking beat. Emit `phase_changed` per beat.
  Call `Game.set_audiometry_results` and `finish_visit`, and emit `level_finished`.
- **The audiometer:** react to the actions in `_unhandled_input`. Respond to a held `present_tone` (pressed, then
  released about 1-2 s later). Keep `get_state()` keys (§4.3). Register with `Stage`. Emit `audiometry_started`,
  `patient_responded` and `test_finished`.
- **Every scene** must keep working at `--speed=6` and `--fixed-fps 30`.

### §7.3 Screenshots

Anyone may `Events.screenshot_requested.emit("name")`. It only does something with `--shots`.
The bot saves:
- one shot per phase, named like `05_audiometry_right.png` (**v3**: `_<test>` is appended for non-`ac` tests, e.g. `audiometry_right_bc_masked`);
- **(v3)** `audiometry_<ear>_<test>_first_store`, `audiometry_<ear>_<test>_hoot_turn`, `audiometry_<ear>_plateau`;
- **(v3)** the story's own: `day2_bone_placement`, `day2_reveal`, `day2_bridge`, `day2_type`, `day2_carhart`, `day2_stamp`,
  `day2_croissant`, `day2_goodbye`;
- **(v4)** `explainer` (phase), `explainer_scene_2` (the bot's peek), `explainer_masking_recap` (the recap card), `bc_placement_left`, `ghost_demo_right`,
  `audiometry_right_ghost_demo` (the demo's first tone), `day2_bone_placement_right` (the quick placement); the dev
  scenes add `explainer_<id>_<NN>_<scene>` (`dev_explainer.tscn`; **(v4, builders)** extra moments of a scene
  `explainer_<id>_<NN>_<scene>_t<seconds>`, `--menu`: `explainer_pause_menu`, `explainer_pause_replay`,
  `explainer_pause_back`; `--title`: `explainer_title_*`; `--card-demo`: `explainer_card_*`) and `dev_day2_placement_left`,
  `dev_day2_slip_left_*`, `dev_day2_placed_left`, `dev_day2_oscillator_3d_left`, `dev_day2_placement_right_quick`
  (`dev_day2.tscn --part=placement`);
- `audiometry_<ear>_first_tone`, `audiometry_<ear>_first_store`, `audiometry_<ear>_complete`;
- `results_final`.

### §7.4 Unit tests

- Files: `res://tests/test_*.gd` (foundation) and `res://<module>/tests/test_*.gd` (owners).
- Base: `extends TestCase` (`tests/base_test_case.gd`).
- Each `test_*` method runs on a fresh instance and may `await`.
- Helpers:
  - asserts: `assert_true`, `assert_false`, `assert_eq`, `assert_ne`, `assert_near`, `assert_between`, `assert_has`, `assert_has_method`, `assert_has_signal`;
  - `add_node(n)`, which is freed after the test;
  - `wait_frames(n)`, `wait_seconds(s)`;
  - `send_action(action, pressed)` and `tap_action(action)`, which send real `InputEventAction`s just like the bot;
  - `allow_errors()`.
- Any script or engine error logged during a test fails it.
- `tests/test_contracts.gd` checks this file's APIs. Update it together with this file. **(v3)** `tests/test_contracts_v3.gd`
  checks the v3 additions (signals, plan and state keys, masking / route actions incl. Shift+Up, audiogram layers,
  clinic oscillator, the `bc_placement` / `referral_stamp` beats, `Hud.set_steps`). **(v4)** `tests/test_contracts_v4.gd`
  checks the v4 additions: the movie signals, `PHASES`, `movies_seen`, the movie registry and data (`validate`, the
  storyboard ids, 60-100 s, the IA / plateau / overmasking facts, quiet cues), the player's beat, solver, keys and
  buttons, the pause-menu replay, both placements, `unmasked_bone`, the `demo_tone` plan, the Day 2 order and the
  golf-card `L  >` row. **(polish)** Also: Space advances like dialogue (the second caption is never thrown away),
  `seen_at` and the last button ("Start the day" / "Done"), the music duck owners (a replay over the AudiOtron, a
  movie freed mid-play), `masking_deck: false`, the movie list with six movies (one column, fits 720p, scrolls, keys),
  the sets hook (`tests/fixtures/fake_movie.gd` + `fake_movie_sets.gd`: own sets drawn with the same `t` / `duration`
  / `params`, validate, the card fallback) and the masking recap. Test fixtures live in `tests/fixtures/` (no
  `test_` prefix, never run as tests; `tests/*` is never exported).
- **(Speech)** `tests/test_contracts_speech.gd` checks §9; **(cases)** `story/tests/test_cases.gd` checks §11.
- **(v3)** Stress test: `tools/monkey.tscn` mashes Day 1, or with `--day=2` Bonnie's five tests and the masking /
  route keys (invariants: noise dial 0-100, no masker while MASK is off or after a test). **(v4)** Day 2 runs six:
  right and left air, LEFT bone, the right Ghost demo (`demo_tone`), masked right bone, masked right air.
  **(v4, integrator)** Before them it mashes Hoot's masking movie three ways (level-style without Esc: one scene at a
  time to the end, frozen under the pause menu; with Esc / Skip: an accepted Esc ends it at once; the pause menu's
  "Watch" replay: the menu comes back) and reports `movie_runs`.
  **(Speech)** With `--day=3` it mashes Mike's SPEECH screen and the Day 3 board (invariants: the dial in range, the
  speech noise only with MASK on, other ear, mask level, never in Hoot's turn; the board's steps all end right).
  **(cases)** With `--day=6` and up it plays that case's tests, its masking and any retest, with Day 2's invariants.
  Any other day (Days 4 and 5, a day with no chapter) is refused (exit 2), never played as Day 1;
  `tools/movie_check.sh` (and `tools/movie_ac.tscn`) refuse the same way any day other than 1-3, and any `--chapter`
  (they take `--day` only).
- Runner: `godot --headless --path . -s res://tests/run_tests.gd [-- --filter=word --verbose]`.
  Exit codes: 0 = green, 1 = failures, 2 = no tests.

---------------------------------------------------------------------------------------------

## §8 Professor Hoot: tips and anchors

**Who owns what.**
- The **Hoot autoload owns the tip queue** (`autoload/hoot.gd`): priority, de-dupe, timeouts, mastery.
- The **bubble view** (`story/hoot_bubble.tscn`, builder B) only displays. It listens to `hoot_tip_shown` and
  `hoot_tip_dismissed`, and calls `Hoot.dismiss(id)` when the player clicks it.
- The world's Hoot body (`Clinic.hoot_emote`) is cosmetic.

**Requesting a tip.** Either way works:
- `Events.hoot_say.emit(text, priority, target)`;
- `Hoot.say(text, priority, target, key, duration_s, skill) -> id`. It returns -1 if the tip was suppressed.

Related calls:
- `Hoot.say_once(key, text, priority, target)`: once per visit.
- `dismiss(id)`, `dismiss_current()`, `clear_queue()`, `clear()`.
- **(polish)** `dismiss_target(target)`: drops every queued tip pointing at that anchor, and the current one (the
  AudiOtron calls it with `store_button` once the player stamps, so "Store it!" never outlives the stamp).
- `current_tip()`, `is_showing()`, `queued_count()`.
- `note_clean_use(skill)` and `is_mastered(skill)`. Mastery comes after 3 clean uses and is saved in `progress.hoot_mastery`. It emits `hoot_mastered`.

**Rules:**
- Tips are 18 words or fewer.
- Priorities: `Hoot.LOW` 0, `NORMAL` 1, `HIGH` 2, `URGENT` 3. URGENT, or anything more than one level above the
  current tip, replaces it. Otherwise the tip queues (at most 4).
- `duration_s` < 0 picks a time automatically, 3-8 s by word count. 0 makes the tip **sticky**: the caller must dismiss it, or a
  phase change clears it.
- **Every `phase_changed` and every `level_started` clears all tips.**
- The audiometer clears its tips on exit.
- Tip shape: `{id, text, priority, target, key, duration}`.

**Ghost-hand anchors.** `Hoot.register_anchor(id, node)` works with a Control, a Node2D or a Node3D (projected through the active
camera). Related calls: `unregister_anchor`, `has_anchor`, `anchor_screen_rect(id) -> Rect2`. The ids used so far:

| Where | Anchor ids |
|---|---|
| AudiOtron | `tone_button`, `louder_button`, `softer_button`, `freq_up_button`, `freq_down_button`, `store_button`, `no_response_button`, `ear_right_button`, `ear_left_button`, `audiogram_right`, `audiogram_left` |
| story | `otoscope_seed`, `ear_target_right`, `ear_target_left`, `earphone_red`, `earphone_blue`, `reveal_audiogram`, `evidence_target`, `evidence_slope` |
| AudiOtron **(v3)** | `mask_softer_button`, `mask_toggle_button`, `mask_louder_button`, `transducer_air_button`, `transducer_bone_button` **(polish: the old single `transducer_button` became the two-segment AIR \| BONE switch)** (hidden unless the plan shows the masking deck) |
| story **(v3)** | `oscillator`, `mastoid_target_right`, `abg_bridge`, `referral_stamp`; **(v4)** `mastoid_target_left` (the placement game registers `mastoid_target_<ear>` for its ear only) |

**Bubble placement.**
- A screen can reserve a spot with `Hoot.set_bubble_hint(rect)` in viewport coordinates, and `clear_bubble_hint()` on exit.
- The AudiOtron reserves its right-hand column.
- With no hint, the bubble sits top-right below the HUD (y ≈ 176). Screens that need that area should set a hint.

---------------------------------------------------------------------------------------------

## §9 Speech audiometry (Days 3-5)

The speech chapters add a second test screen, the **SPEECH** screen, next to the AudiOtron. Rules and numbers:
`docs/SPEECH.md` (`SpeechRules` in `core/speech/speech_rules.gd`); chapter designs: `docs/CHAPTER3.md` (Day 3, Mike,
SRT: the speech recognition threshold, ASHA's preferred term), `docs/CHAPTER4.md` (Day 4, Nora, WRS) and, with Day 5's
PR, `CHAPTER5.md` (speech in noise). Additions are marked **(Speech)** where they touch earlier sections. Days 1, 2
and 6-9 behave exactly as before. **Days 4 and 5** are §9.10-§9.24 (the test modes, the word recognition score, the
Party Noise Test and their stories); §9.10.0 lists what they change in §9.1-§9.9.

| Path | Owner | Contents |
|---|---|---|
| `core/speech/**` | speech thread | `SpeechRules`, `SpeechMaterial`, `SpeechSim`, `SpeechSession`, `SpeechVoice`, `material/*.json` |
| `ui/speech/**` | speech thread | `SpeechScreen` (`speech_screen.tscn`) and its widgets |
| `story/level_mike.*`, `story/games/mike_board.gd` | speech thread | the Day 3 level and its board |
| `core/patients/mike.tres` | speech thread | Mike Lenders (new file): his claimed audiogram, `speech` (SRT 30 both ears), tags |
| `core/INTEGRATION_NOTES.md` | speech thread | notes for the integrator (new file) |

**Shared-file changes (Speech).** Mostly additions. The lines that change in place are Mike or speech branches that
leave every other day as it was, plus one removed rule:
- `CONTRACTS.md` §1.3: the line **"Speech audiometry is not in this slice."** was removed and replaced by the
  **(Speech) Speech audiometry** rule (original material, TALK lamp, `AudioSafety.speech_to_rms()`); plus this §9.
- Added only: `autoload/game.gd` (the `mike` chapter: Day 3, `requires: bonnie` as the suggested order only, `face`,
  `tint`, teaches "Speech recognition threshold"; the `familiarize` / `speech` phases), `autoload/events.gd` (the
  `speech_*` signals, at the end under `# --- mike / speech ---`), `autoload/audio_safety.gd` (`SPEECH_OFFSET_DB`,
  `SPEECH_CEILING_DBFS`, `speech_to_rms()`, `speech_ceiling()`), `core/patient_profile.gd` (`speech`, default `{}`
  so every existing patient behaves as before; `SPEECH_KEYS`, `speech_value()` and its validation),
  `project.godot` / `tools/setup_input_map.gd` (`speech_correct`, `speech_incorrect`, the project-wide WAV import
  default, §9.6), `story/voice.gd`, `world/clinic.gd` (Mike), `tools/autoplay_bot.gd` (the generic mouse route and
  the speech sanity checks), `world/tests/test_clinic.gd`, `story/INTEGRATION_NOTES.md`, `ui/INTEGRATION_NOTES.md`
  and `world/INTEGRATION_NOTES.md` (speech sections appended), `tools/analyze_movie_audio.py` (the `--speech`
  mode), and the new `tests/test_contracts_speech.gd`.
- Changed in place, other days unchanged: `story/daily_decibel.gd` (column 2, the weather line and the C subhead
  branch on the speech results: `speech_c_subhead()` names the slip on a speech day's C; other days keep their
  subhead tables; `fit_scale()` scales down only a paper too tall for the window, on any day), `world/characters/bean.gd` (the shirt block moves inside a `vest` branch for Mike),
  `world/characters/face_rig.gd` (Mike's face; one comment reworded), `story/portraits.gd` and
  `tests/test_chapters.gd` (their tables gain Mike; the header comment changes), `story/pause_menu.gd` and
  `story/hud.gd` (the speech phase hides the pause corner and the tracker, like the audiometry phase), `story/dialogue_box.gd` (Mike's display name "Mike
  Lenders"), `story/tests/test_story.gd` (Mike in the voice-bank check; a new Day 3 card test), `export_presets.cfg` (the material JSON in,
  `story/dev_day3.*` out), `tools/scene_shot.sh` (positional parsing, so `--` and options can come anywhere),
  `tools/monkey.gd` and `tools/movie_check.sh` / `tools/movie_ac.gd` (a `--day=3` mode each; a day they don't
  play is refused with a message and exit 2 instead of running Day 1; Days 1 and 2 run exactly as before),
  `tools/README.md` (Day 3 in the commands and exit codes), `README.md` (Day 3 and speech in the overview; the
  "not in this slice" speech-in-noise bullet goes) and `docs/ADDING_A_CHAPTER.md` (recordings are WAV only).

### §9.1 PatientProfile.speech

`@export var speech: Dictionary = {}` (all keys optional; anything missing comes from the audiogram):
`srt` {ear: dB HL}, `srt_offset` {ear: dB}, `half_words` (0..1, share of SRT misses given as half a word, default
0.15), `wrs_max` {ear: %}, `rollover` {ear: {after, drop_per_10db}}, `neural` {ear: bool}, `snr_loss` (dB),
`directional_benefit` (dB). `speech_value(key, ear := "", default)` reads one; `SPEECH_KEYS` lists them and
`validate()` rejects unknown keys. Day 3: `core/patients/mike.tres` (voluntary tones about 70 dB, `srt` 30 / 30,
`half_words` 0.6, tags `non_organic`, `speech`, `chapter_3`).

### §9.2 Material (`SpeechMaterial`, static)

`res://core/speech/material/<list_id>.json`: `{id, title, kind: "spondee" | "monosyllable" | "sentence", original: true,
items: [...]}`. Spondee items `{id, text, parts: [a, b], mishears: [...]}`. Every list is written for the game: no
list, order or recording is copied; every word is checked against ASHA (1988) Appendices A-C and CID W-1
(`core/tests/test_speech_core.gd` holds those lists whole and rejects any match, ignoring case, spaces and hyphens). Functions: `load_list(id)`, `items(id)`, `item(list, item)`,
`title(id)`, `kind(id)`, `list_ids()`, `validate(list)`, `recording_path(list, item)` (`""` = none),
`half_word(item, first_part)`. Day 3 uses `spondee_a` (16 words).

### §9.3 SpeechSim (RefCounted, `core/speech/speech_sim.gd`)

`SpeechSim.new(profile, seed)`. `true_srt(ear)`, `cochlear_srt(ear)`, `half_word_share()`, `p_srt(ear, level)`,
`respond_srt(ear, level, item, others) -> {text, correct, kind, heard_by, delay_s, p}` (`kind`: `&"correct"`,
`&"half"`, `&"wrong"`, `&"silence"`). Condition vars set by the session: `transducer`, `mask_db` (speech noise in the
other ear, -1 = off). Unmasked speech also reaches the other cochlea (real IA softer).

### §9.4 SpeechSession (RefCounted, `core/speech/speech_session.gd`)

Pure logic for every speech test of one visit (both ears); the screen owns all timing.
- Setup: `SpeechSession.new(profile, seed)`, `configure(plan)` (keys below: `test`, `list`, `words`, `exclude`,
  `tones`, `transducer`, `level`, `low_start_ok`), `begin(ear, coached)` (the dial goes to the PTA rounded to 5 dB,
  or `level`). `low_start_ok` (bool, default false): a first SRT word at least 10 dB below the PTA
  (`SRT_LOW_START_BELOW_PTA_DB`) is a clean start instead of an `srt_start` error, and the first step after it, when it
  goes up, the clean `srt_low_start` (clinical review S2; an ascending start;
  the dial's default at the PTA does not count); the level sets it once suspicion of a
  non-organic loss is on screen, never from the hidden `non_organic` tag. A start above the window stays an error.
- Controls: `step_level(dir)`, `set_level(db)`, `set_mask(on)`, `toggle_mask()`, `present() -> trial` (`{}` when
  refused: a word still needs its score, the ear is done, or no words), `score(correct) -> trial`, `store() -> sheet`.
- Queries: `next_item()`, `candidate()` (`SpeechRules.NO_SRT` -1 = not bracketed), `pta_for(ear)`,
  `recommended_start()`, `masking_needed_here()`, `mask_level()`, `is_done()`, `trials_for()`,
  `recommended_action() -> {action, target_db}` (`&"score_correct"`, `&"score_missed"`, `&"louder"`, `&"softer"`,
  `&"mask_toggle"`, `&"present"`, `&"store"`, `&"none"`; it uses only what the player can see), `textbook_target()`.
- `scoring` (false during Hoot's turn: his words and store are not scored), `tip_text(kind)`,
  `agreement_tip(agreement, diff) -> String` (Hoot's line after a store: `AGREEMENT_TIPS` keys `good`, `fair_better`,
  `fair_worse`, `poor_better`, `poor_worse`; `diff` = SRT - PTA, below zero = the SRT is better).
- Speech masking (`masking_needed_here()`, `mask_level()`): needed when the level minus the speech IA (40 phones,
  55 inserts) reaches the other ear's lowest bone over 500-4000 Hz, masked or unmasked; the noise is
  `SpeechRules.speech_mask_level(level, nontest_abg)` = level - 20 + the other ear's largest air-bone gap at
  500-4000 Hz (`nontest_largest_abg(tones, ear)`, masked bone where measured; `speech_mask_level(level)` alone still
  means no gap). Without bone results both rules use air only (best air for the bone, no gap): a temporary stand-in.
  Day 3 has no bone, so its numbers are unchanged.
- The step rule (`SpeechRules.srt_step_verdict(db, correct, next_db, words_here)`): down 10 (5 tolerated) after a
  correct word, up 5 after a miss, and another word at the same level is `&"tolerated"` (after a hit or a miss)
  while fewer than `SpeechRules.SRT_MAX_WORDS_PER_LEVEL` (4) words were given at that level in this ear; the 5th is
  `&"wrong"`. `_check_step` counts the words.
- Signals: `technique(kind, data)`, `combo_changed(n, multiplier)`, `reaction(kind, data)`, `stored(ear, test, sheet)`.
- `get_state()`: `test, ear, db, min_db, max_db, list_id, list_title, next_word, words_left, pta, pta_right,
  pta_left, recommended_start, candidate_db, trail [{db, scored, kind, by_hoot}], strokes, awaiting_score,
  current {word, said, db, scored}, mask_on, mask_db, mask_ear, masking_needed, transducer, done, stored_db,
  agreement, diff, combo, multiplier, points, presentations, scoring`.
- Statics: `merge_results(tones, speech)`, `scored_tone_stamps(tones)`, `tone_results_from(profile)` (demo / test
  tone results, every stamp by Hoot).

**Speech technique kinds** (`Events.technique_event`, data `{ear, freq: -1, test, db, ...}`; errors carry `message`):

| kind | type | when |
|---|---|---|
| `srt_start` | error | the first word is outside PTA + 10..40 (clinical review S4); a first word at least 10 dB below the PTA is clean with `low_start_ok` (data: expected, pta) |
| `srt_wrong_step` | error | not "got it: down 10 (5 tolerated); missed: up 5", nor another word at the same level (up to 4 there) (expected, got, prev_db, prev_correct, words_here) |
| `misscored` | error | the score differs from what the patient said (said, said_kind, scored) |
| `srt_store_no_bracket` | error | stored before a level scored 2+ right and half or more with the level 5 below under half |
| `srt_store_wrong_level` | error | stored a level other than that one (candidate) |
| `speech_marathon` | error | more than 3x par words in one measurement (once) |
| `speech_textbook`, `srt_good_start`, `srt_store_ok` | clean | combo +1, points |
| `srt_low_start` | clean | the first step after a first word at least 10 dB below the PTA with plan `low_start_ok`, when it goes up, in place of that step's `speech_textbook` (the low first word itself is `srt_good_start`): combo +1, 10 points, Hoot's line in `message` ("Starting below his beeps and coming up: smart when answers look exaggerated.") |
| `birdie` / `eagle` / `albatross` | observation | the SRT hole's golf |
| `srt_stored`, `srt_agreement` | observation | after a store (agreement, diff, pta); `srt_agreement` carries Hoot's verdict line |
| `half_word`, `cross_heard_speech`, `speech_mask_needed`, `score_first` | observation | lessons (once each) |

### §9.5 Results

The SPEECH screen's `test_finished(results)` and `get_results()` give the **merged** visit results: the tone results
(§5.1) handed in as `plan.tones`, plus `"speech"`, with `accuracy`, `technique`, `efficiency`, `score`, `grade`
recomputed over the scored tone stamps and the scored speech sheets (an SRT weighs as 3 stamps; Hoot's work counts
for neither). The tone-only numbers stay under `"tone_scores"`. Story passes it to `Game.set_audiometry_results()`.

```
"speech": {
  "srt": {"right": {...sheet...}, "left": {...}}, "wrs": {}, "sin": {},
  "pta": {"right": 71.7, "left": 73.3}, "tests": ["srt"], "scored_sheets": 2,
  "presentations": 24, "hoot_presentations": 6, "max_combo": 18, "points": 900, "checks": 50, "clean_checks": 49,
  "technique_errors": [{kind, ear, freq: -1, test, db, message}],   # a misscored entry adds scored, said_kind
  "accuracy": 0.9, "technique": 0.98, "efficiency": 0.92, "score": 93.1, "grade": "A",
  "recheck": {"srt": {"right": {...Hoot's sheet...}}}   # Day 3 only, when Hoot reran the right ear (never graded)
}
sheet (SRT) = {ear, test: "srt", list_id, stored_db, true_db, error_db, accuracy, candidate_db,
  bracketed (candidate_db != NO_SRT and stored_db == candidate_db: the UI and story praise only these), pta, pta_method,
  agreement (&"good" / &"fair" / &"poor"), diff (SRT - PTA), start_db, recommended_start, strokes (player words),
  words (all), par, golf (fair golf, &"hoot" for Hoot's), golf_raw, clean, errors, trials [{n, db, item_id, word,
  said, kind, correct, scored, mask_db, by_hoot, delay_s, heard_by}], masked, mask_db, transducer, by_hoot, coached,
  half_words (count)}
```
`true_db` and `trials[].correct` / `kind` are truth: scoring and the reveal only.

### §9.6 SpeechVoice (Node, `core/speech/speech_voice.gd`) and safety

`play_item(ear, list_id, item, hl) -> seconds`, `stop()`, `is_playing()`, `set_level(hl)`, `start_noise(ear, db_em)`,
`set_noise(db_em)`, `stop_noise()`, `render(frames)` (pure DSP). Words: a synthesized murmur (one voiced syllable per
part), or a recording at `res://assets/speech/<list_id>/<item_id>.wav` (WAV only, imported uncompressed), in the test ear
only, levelled over its speech. The uncompressed import is `project.godot`'s `[importer_defaults]` wav
`compress/mode` 0: a **global** (project-wide) default, so every WAV anywhere in the project imports uncompressed,
not only speech recordings (fine today: no other WAVs; a later WAV that should be compressed needs its own import
setting). RMS from `AudioSafety.speech_to_rms(hl)` (`SPEECH_OFFSET_DB` -9, RMS ceiling `SPEECH_CEILING_DBFS` -27), every sample through
`clamp_sample()`. Speech noise: speech-shaped noise in the other ear through `masker_to_rms()` and
`clamp_masker_sample()`. Every word lights the TALK lamp; nothing depends on hearing it. `tools/movie_check.sh --day=3`
records Mike's SRT with speech noise and `tools/analyze_movie_audio.py --speech` measures both (word and noise
channel, level, ceiling; tools/README.md).

### §9.7 SPEECH screen: `res://ui/speech/speech_screen.tscn` (`class_name SpeechScreen`)

A `CanvasLayer` (layer 20), built in code in the AudiOtron's visual language. The story adds it as a child, calls
`start_test()` once per ear and awaits `test_finished`. It keeps its session between ears.

```
signal test_finished(results: Dictionary)          # §9.5 merged results
func start_test(patient: PatientProfile, ear: String, coached: bool, plan := {}) -> void
func get_state() -> Dictionary                      # §9.4 keys + accepting_input, talking, answer_shown, hoot_turn, coached, patient_id, quick_visit
func get_results() -> Dictionary                    # §9.5
func demo_start() -> void                           # standalone: Mike, tones from his profile, coached right-ear SRT
```

**Plan keys:** `test` ("srt"), `tones` (§5.1 results; required for the PTA), `list`, `words`, `exclude`, `level`,
`transducer`, `low_start_ok` (§9.4), `hoot_turn_after` (words the player scores before Hoot finishes the ear at x8 with
quick visit on; 0 = Hoot runs it all; missing = never), `hoot_turn_after_up` (with `hoot_turn_after`: Hoot also takes
over once the player has scored the word stepped up after a miss, the bracket's first "missed: up 5"; the count
stays the cap), `intro`, `hoot_turn_text`, `show_agreement` (default true),
`done_title`, `fresh_session` (this ear on a new session, for Hoot's recheck: the player's session, with its sheets
and points, comes back on the next `start_test` without it).

**Statics:** `SpeechScreen.is_bracketed(sheet) -> bool` (the sheet's `bracketed`, else worked out from `candidate_db`
and `stored_db`), `SpeechScreen.golf_text(sheet) -> [callout, small line]` ("Oops!" / "check Hoot's tip" after a slip
or an unbracketed store; "Clean!" for a clean run over par, never "Par!").

**Behaviour.**
- It is **not** the AudiOtron: never `Stage.register_audiometer`, never `audiometry_started`. It joins the group
  `speech_screen` and turns the booth view on while in the tree.
- One word: PRESENT (`present_tone`, Space, or the button) plays the word (TALK lamp, `SpeechVoice`), then after the
  patient's delay his answer appears in a speech bubble (`Events.dialogue_line(patient short name, said)` for lip
  sync, except silence). The player scores it: CORRECT (`speech_correct`) or MISSED (`speech_incorrect`). Level
  (`louder` / `softer`, so the key style applies) is locked while a word plays. STORE (`store`) stores the dial
  level as the SRT. MASK (`toggle_mask`) is speech noise in the other ear at `session.mask_level()` (level - 20, plus that ear's
  largest air-bone gap when bone was measured, §9.4).
- It shows the word card (next word), the answer bubble, the level trail ("SRT ladder") with a PTA line, the per-level
  tally and, for SRT, the **agreement meter** (a needle over good / fair / poor that clunks into place on store).
- Coaching (`coached`): sticky Hoot tips with ghost-hand anchors walk the first ear (start at PTA + 15, present,
  score what he said, down 10 / up 5, store). Errors, and clean kinds that carry one (`srt_low_start`), show the
  `message` tip. On the coached ear STORE before a bracket only warns: it never stores off the bracket.
- Feedback after a store: the word card's line, the golf callout and the fanfare praise only a bracketed (or
  Hoot's) store. "The tell": once per visit, the first word rightly scored as repeated 30 dB (`TELL_GAP_DB`) or more
  below the ear's PTA gets Hoot's note, his hand on `agreement_meter` (never on the answer being judged); on the
  coached ear the coach's tip comes back after it.
- Hoot's turn (`hoot_turn_after`): banner, `Engine.time_scale` x8 restored after, `session.scoring = false`, he
  follows `recommended_action()` through the screen's own controls.
- Finishing an ear: input stops, then `Events.speech_finished(results)` and `test_finished(results)`.
- **Blocking beat** (§3.2): whenever it waits for the player (not during Hoot's turn) it emits
  `Events.awaiting_input(&"speech", info, solver)`, info `{ear, test, action, mouse: {click: <anchor id>}}`. The solver
  sends the recommended action as a real `InputEventAction` (pressed, then released); a stale solver does nothing.
- On exit it clears its tips and bubble hint. Pause: a small "II" pill opens the pause menu; the pause menu hides its
  own corner button while a `speech_screen` node is in the tree.

**Anchors** (`Hoot.register_anchor`): `speech_present_button`, `speech_correct_button`, `speech_incorrect_button`,
`speech_louder_button`, `speech_softer_button`, `speech_store_button`, `speech_mask_button`, `speech_word_card`,
`speech_response`, `speech_ladder`, `agreement_meter`.

**Events it emits:** `speech_started`, `speech_presented`, `speech_response`, `speech_scored`, `speech_stored`,
`speech_state_changed` (every change), `speech_finished`; plus `technique_event` (forwarded from the session),
`combo_changed`, `patient_reaction` (`nod` correct, `confused` silence, `squint` half word, `cross_heard`).

**Input actions (Speech):** `speech_correct` (Right, Keypad +, =), `speech_incorrect` (Left, Keypad -, -); reused:
`present_tone`, `louder`, `softer`, `store`, `toggle_mask`, `toggle_key_hints` (§4.7).

### §9.8 Story and flow (Day 3, `story/level_mike.gd`)

Phases: `intro`, `history`, `otoscopy`, `instructions`, `audiometry` {right, ac} / {left, ac} (Hoot runs the tones:
`hoot_turn_after` 0; after the right ear he retests 1 kHz, `LevelMike.retest_1k(tones)`: his first 1 kHz minus
`RETEST_BETTER_DB` 15, past `ClinicRules.RETEST_TOLERANCE_DB`, said by Hoot and kept as the right ear's `retest_1k`
with `by_hoot`; the PTA keeps the first stamp, and the shared tone code is unchanged. **(E2)** The right is the visit's
first air ear, the only one that owes the retest; both montages keep `skip_hoot_retest`, so the AudiOtron's test plan
shows no `1k R` and the left gets no retest), `familiarize` (Hoot says each word and Mike says it back by ear, the cards facing Hoot; a
word Mike doesn't know is dropped; then his SRT instructions: the test words come from this list), `speech` {ear, test:
"srt"} for right (coached) and left, `evidence` (OBJECTION!), `referral`, `results`. New blocking beats:
`familiarize_cards` (info {mouse}), `objection_present` (info {targets, mouse: {drag: [clue, target]}}; solver
presents the strongest clue), `referral_stamp` (reused). Every SRT plan sets `low_start_ok` once Hoot's coffee
whisper has been on screen. After the right ear, when the player's SRT can't show the mismatch (not poor, not
better than the PTA, or not stored at its bracket), Hoot reruns that ear by the book on a fresh session
(`fresh_session`, `hoot_turn_after` 0); the board (`board_sheet()`) uses his recheck, the results keep the player's
sheet for the grade. The SRT-vs-PTA measurement is always the strongest clue. Chapter: `Game.CHAPTERS` id `mike`, day 3, requires `bonnie`
(the suggested order only: any chapter can be picked). Medals: `history`, `instructions`, `familiarize`, `evidence`,
`referral`. Anchors: `word_card_<item id>`, `familiarize_cue` (familiarize), `objection_claim`, `clue_srt_pta`, `clue_coffee`,
`clue_canals` (evidence), `referral_stamp`. Without the SPEECH scene the level lets Hoot say the words (unscored), so
the visit still ends. The Daily Decibel's column 2 is the word golf card: per ear the stored SRT, PTA, agreement chip,
words vs par and golf ("no bracket" for an unbracketed player store, "N slips" / "no golf" for a bracketed one with
errors), then Hoot's recheck note (`recheck_note()`, from `speech.recheck.srt.right`, never graded) and the agreement
legend with the direction (`agreement_legend()`). A speech C's subhead names the slip (`speech_c_subhead()`); a
misscored C says which way (`misscore_way()`, `SPEECH_C_MISSCORED`).

### §9.9 Autoplay (Speech)

- The bot treats `speech` beats like every other beat (waits, then calls the solver); with `--mouse` any beat whose
  info carries `mouse` is played by its route: `{click: anchor}`, `{drag: [from_anchor, to_anchor]}` or
  `{text: "visible text prefix"}`.
- Progress also comes from the `speech_*` signals. Sanity (exit 4): every stored SRT within 10 dB of the truth, both
  ears stored on a speech day, and on Day 3 a poor PTA/SRT agreement.
- Screenshots: `speech_<ear>_srt_first_word`, `speech_<ear>_srt_descent`, `speech_<ear>_srt_stored`,
  `day3_familiarize`, `day3_objection`, `day3_stamp`, `day3_goodbye`, `day3_glazed`.

### §9.10 Days 4-5: test modes and the S0 seams

**(Days 4-5)** §9.10-§9.24 take the speech code from the SRT only (Day 3) to the word recognition score (Day 4, Nora,
`docs/CHAPTER4.md`) and the Party Noise Test (Day 5, Marco, `docs/CHAPTER5.md`). Where a chapter doc and this contract
differ, **this contract wins**; §9.10.1 lists every decision so the three stay in line.

**The clinical review (2026-10-19).** Its speech amendments A1-A8 (`docs/CLINICAL_REVIEW.md` items S1 and S8 name
them; they are not that file's own A items) are written into the rules they changed, and every number they moved is
recomputed here:
- A1, the predicted minimum ("her tones predict at least"): D14, §9.15.1, §9.24.
- A2, rollover is the rollover index, with PBmin above PBmax: D15, §9.15.1, §9.24.
- A3, ear differences use the 25-word critical difference, not a fixed 20 points: D27, §9.15, §9.17.1, §9.24.
- A4, word-list noise adds the other ear's air-bone gap: D16, §9.13.3.
- A5, Day 4's lines ("loud enough for every sound, never uncomfortable"; recorded lists): §9.13.5, §9.20, §9.21.
- A6, new open questions for Steve: `docs/CHAPTER4.md` §17, Q27-Q31.
- A7, Day 5's "Near-normal" band and two Day 5 lines: D22, §9.21, §9.23.1.
- A8, Day 3: a sloping loss is no reason for an SRT worse than the PTA: §9.10.0.

**Status.** Day 4 is built as this contract says: the S0 seams, `WrsTest` and `WrsModel`, `SpModeWord` and its
widgets, Nora's level and the Red-Flag Roll Call, the word golf column, the Letter Choir and the bot's Day 4 checks.
**Day 5 is built too**, and the SIN parts of §9.11-§9.24 now say what was built (A7 folded in): `SinTest` and
`SinModel`, the party babble, `SpModeParty` and its widgets, Marco's level with the bill, the plates, the blind
tasting, the seats and the dinner, the party golf column, the Party Problem movie (Steve's lead-in, 71 s) and the
bot's Day 5 checks. The design as built is `docs/CHAPTER5.md`. Without Day 5's files a `sin` plan would take the
missing-mode path (§9.10.2), as before.

**Ground rules kept from §1, §3.4 and §9.**
- Days 1-3, 6-13 and the walk-ins behave exactly as before. Shared files take additive changes only, each one guarded
  so that a Day 3 SRT session never reaches the new code (`session.mode == null`, `screen._mode == null`). The one
  allowed visible Day 3 change is the "UP NEXT" hint, which now points to Day 4 (§9.21).
- Original material only. No published test list, sentence, recording, order or rhyme set is copied or closely
  paraphrased (NU-6, W-22, CID W-1/W-22, AB/Boothroyd, PB-50, NU-CHIPS, WIPI, the Modified Rhyme Test family, HINT,
  BKB, IEEE/Harvard, QuickSIN, WIN, BKB-SIN, SPIN, AzBio). No vendor names, logos or UI copy. In-game names: "Word
  list 1" to "Word list 4", "Party list 1" to "Party list 6", "Practice sentence", "Party Noise Test".
- Better ear first. Hoot never names a diagnosis. WRS red flags lead to REFER (soon: days to about 2 weeks) for a
  doctor's check, with imaging requested in the letter, before any fitting; never to DOCTOR TODAY from word scores
  alone. A sudden change stays a DOCTOR TODAY matter, as in the cases days.
- Every Hoot line and movie caption is 18 words or fewer, after `{tokens}` are filled with their longest values.
  Every key named in a line is a `{key:<input action>}` placeholder filled by the screen's `_k()`, so the
  swap-arrows style reads correctly (D10).
- Text first: every word and sentence is on screen before any sound, every answer is a text bubble, and nothing
  depends on hearing audio. `SpeechVoice` is optional. No line may say "hear the gap" or ask the player to listen.
- Movies follow §3.4: data for the shared player, `Sfx` cues only at -6 dB or softer (these movies
  use -8 to -16), and babble, noise and "too loud" are drawn, never played.

#### §9.10.0 What Days 4-5 change in §9.1-§9.9

**§9 intro (Day 4) (Day 5).** The ownership table gains the rows of §9.23. Chapter designs: `docs/CHAPTER4.md` (Day 4,
Nora, WRS) and `docs/CHAPTER5.md` (Day 5, Marco, Party Noise Test).

**§9.1 PatientProfile.speech (Day 4) (Day 5).** No new keys. Meanings made exact:
- `wrs_max` {ear: %} is the ceiling of the word score in quiet at a fully audible level. Missing: `predicted_wrs_max`
  of the ear's TRUE thresholds.
- `rollover` {ear: {after, drop_per_10db}}: above `after` dB HL the score loses `drop_per_10db` percentage points per
  10 dB (linear).
- `neural` {ear: bool}: misses are spread at random over the list instead of following the banana.
- `snr_loss` (dB, or {ear: dB}): the unaided SNR loss. A number applies to both ears; "both" uses the lower ear value.
  Missing: `estimated_snr_loss` of the better ear's true thresholds.
- `directional_benefit` (dB): what FOCUS (directional microphones) wins back. Missing: `SIN_DIRECTIONAL_BENEFIT_DB`.
- New profiles:
  - `core/patients/nora.tres` (CHAPTER4 §2): phones IA 50, `wrs_max` 96 / 52, `rollover.left` **{after 75,
    drop_per_10db 20}**, `neural.left`, tags `speech`, `chapter_4`.
  - `core/patients/marco.tres` (CHAPTER5 §2): `wrs_max` 96 / 92, `snr_loss` 9.0, `directional_benefit` **4.0** (vented
    domes; stated explicitly although it equals the default), tags `speech`, `speech_in_noise`, `chapter_5`.

**§9.2 Material (Day 4) (Day 5).** See §9.11. `SpeechMaterial.validate` gains the optional monosyllable `chunks`,
`asides` and `plural` checks and the sentence checks (S0a). A list without the new optional fields validates as
before.

**§9.3 SpeechSim (Day 4) (Day 5).** See §9.12. S0a adds `condition`, public `ia()`, `air(ear)` and `delay_for(p)`
(thin wrappers of the private `_ia`, `_air` and `_delay`), and the WRS and SIN facade methods, each returning a safe
default until its model file exists. `respond_srt` and every SRT number are unchanged.

**§9.4 SpeechSession (Day 4) (Day 5).** See §9.10.4 (the seams), §9.13 (WRS) and §9.14 (SIN). New vars: `mode`,
`mode_missing`, `slot`, `seq`, `used_lists`. `begin(ear)` also takes `"both"` when the plan's test is `sin`.
`get_state()` gains `slot`, `mode` and one sub-dictionary named after the test (`wrs` or `sin`). New
`run_by_textbook(ear)` (C23) runs a whole list with no screen, and `mask_level()` takes the mode's rule (C24). The
action set of `recommended_action()` grows (§9.13.4, §9.14.4). New technique kinds: §9.13.6 and §9.14.6.

**§9.5 Results (Day 4) (Day 5).** See §9.15. `speech.wrs` and `speech.sin` are filled. One sheet per **slot**: WRS
slots are ears; SIN slots are `"both"`, `"aided_omni"` and `"aided_directional"` (or an ear for a per-ear unaided
test). Each WRS or SIN sheet holds a `lists` array. Every sheet carries `stored_db` and `true_db`, so the bot's generic
"within 10 dB" check keeps working. **`units`** = the counted player lists on the slot (a redone list and a Hoot-only
list count 0); each unit weighs `SHEET_WEIGHT` 3 in `merge_results`, as an SRT sheet does. New top-level keys:
`wrs_summary`, `sin_summary`.

**§9.6 SpeechVoice (Day 5).** See §9.16: `play_item("both", ...)` now writes both channels (a deliberate change; Day 3
never passes "both"), the party babble (`start_babble`, `set_babble`, `stop_babble`) on the masker's safety path,
and the SNR mixed into the test ear or ears.

**§9.7 SPEECH screen (Day 4) (Day 5).** See §9.17-§9.19. Plan key `test` takes `"wrs"` (WORD mode) and `"sin"` (PARTY
mode). `get_state()` gains `mode`, `slot` and the mode's `extra_state()` (`lens_on`, `confirm_pending`, `practice`),
and takes `words_left` and `recommended_start` from the mode. New public `complete_list(sheet)` and `run_hidden(...)`
(H27, H28). New anchors, inputs and beats are listed in §9.19. The SRT layout, keys, coaching and anchors are
unchanged.

**§9.8 Story and flow (Day 4) (Day 5).** See §9.20 (movies) and §9.21 (the Day 4 and Day 5 plans). Movies follow §3.4:
the phase `&"explainer"`, `Game.is_movie_seen` / `mark_movie_seen`, the explainer signals and the per-movie sets hook
(`MOVIE.stage`, `explainer_sets.gd`) already exist. One new phase: `&"counselling"`. New chapters `nora` (day 4,
requires `mike`) and `marco` (day 5, requires `nora`); `requires` is the suggested order only.

**§9.9 Autoplay (Day 4) (Day 5).** See §9.22. The main thread owns `tools/autoplay_bot.gd`, and the patch request is
`tools/INTEGRATION_NOTES.md`. Day 4's part (applied by W5a) and Day 5's (applied by P5a) are in the bot in blocks
marked `# (Days 4-5)`, none of which runs on Days 1-3 or 6-13.

**Events, speech block (Day 5).** The doc comments of `speech_presented`, `speech_scored` and `speech_stored` change
from "ear: right / left" to "ear: right / left, or "both" for a party test". The `item`, `trial` and `sheet`
dictionaries they carry gain `slot` (and `list_id` for WRS and SIN). Signatures are unchanged.

**Day 3 text (A8; owned by W1).** "A sloping loss" is no reason for an SRT worse than the PTA: a sloping loss tends to
make the SRT better than the three-frequency average, which is why the PTA uses the best two when they spread. It is
gone from every "worse" list: `SpeechSession.AGREEMENT_TIPS` (`fair_worse`, `poor_worse`), the Daily Decibel's
`agreement_legend()`, `docs/SPEECH.md` and `docs/CHAPTER3.md`. The two docs add the note in the "better" direction (a
steep slope can make words a little better than the three-tone average, so the PTA then uses the best two). Day 3's
autoplay results are unchanged: the text is not in `AUTOPLAY_RESULT`.

#### §9.10.1 Decisions

| # | Decision | Where it shows |
|---|---|---|
| D1 | WRS and SIN logic live in **test-mode objects in their own files**, not in `if test == &"wrs"` branches inside `speech_session.gd` and `speech_screen.gd`. Two builders can work in parallel, and Day 3 stays byte-for-byte on its old path. | CHAPTER4 §5, §8; CHAPTER5 §5, §12 |
| D2 | **One sheet per slot, each with `lists`.** WRS: `speech.wrs.right` / `.left`, holding every list on that ear (comfortable, redo, louder). SIN: one sheet per condition with its two lists. | CHAPTER4 §8; CHAPTER5 §8.1 |
| D3 | Sheet `strokes` / `par` are the **efficiency pair** (both = the player's presentations, so efficiency is 1.0 on fixed lists). Golf uses `golf_strokes` / `golf_par` / `golf`. | CHAPTER4 §9; CHAPTER5 §8 |
| D4 | The WRS **deal includes cross-hearing**: the counts of test-ear hits and of all hits are both controlled to round(p x N) +- 1, so an unmasked list is as repeatable as a masked one. | CHAPTER4 §8 |
| D5 | **Movies follow §3.4.** Each is data (`story/explainers/movies/<id>.gd`), registered in `movies.gd`, played by the shared `explainer_player.tscn` exactly as `level_bonnie._movie()` does, replayed from the pause menu. Its art is its own sets script behind the landed hook (`MOVIE.stage`, a script extending `explainer_sets.gd` with `const SETS`), so no shared movie file changes. No movie class, scene, beat, anchor, progress key, visit flag or command-line switch of our own (§9.20). (Steve, 2026-10-19) Scene 1 holds its title card (`params.card_hold` 8 s, two `params.questions` chips) while its first captions say what the movie will explain, and the level announces the day in one Hoot line before the first play. | CHAPTER4 §4; CHAPTER5 §4 |
| D6 | ALL GOT gets a key: **G** (`party_all_got`). | CHAPTER5 §5.3 |
| D7 | The lens action is `toggle_lens` (V) with the button `speech_lens_button`. It is a WORD-mode feature; PARTY mode supports it only when its plan sets `lens` (off on Day 5). | CHAPTER4 §5.3 |
| D8 | The Daily Decibel takes a day's sports column, weather line and subheads **from the summary** (`sports_script`, `weather`, `subheads`), and `_is_speech` is true for any speech sheet, so `daily_decibel.gd` changes once (S0b) and never again for Days 4-5. | CHAPTER4 §10; CHAPTER5 §8.4 |
| D9 | The bot's generic "within 10 dB of the truth" check stays for all three tests; WRS and SIN sheets carry `stored_db` / `true_db` for it. | CHAPTER4 §16; CHAPTER5 §14 |
| D10 | Every line that names a key uses `{key:<input action>}` (for example `{key:louder}`, `{key:toggle_mask}`, `{key:store}`), filled by `_k()` in coach lines, tips and technique messages alike. | both chapters' line tables |
| D11 | WRS lists and party lists always play **in file order** (never shuffled). | CHAPTER4 §6; CHAPTER5 §5.5 |
| D12 | WRS uses `SpeechRules.nontest_best_bone` for "is noise needed"; SRT keeps `nontest_best_threshold`. | CHAPTER4 §8 |
| D13 | **Verdicts wait for the ear's best.** `below_predicted` and `asymmetric` are computed from `pb_max` (the best counted list on the ear) and are held until that best is final: the louder list is done, or the comfortable score already reaches the predicted minimum. Lines and boards never call "worse than predicted" earlier. | CHAPTER4 §3, §7, §11 |
| D14 | **Predicted minimum, interpolated (A1).** `SpeechRules.wrs_predicted_min_interp(pta)` interpolates linearly between the rows of `WRS_PREDICTED_MIN_25` (`[[0, 88], [20, 80], [30, 72], [40, 60], [50, 48], [60, 36], [70, 24], [80, 12]]`: the lowest 25-word best score that still fits the tones, a game approximation of Dubno et al. (1995)'s 95% lower limits anchored on their 50-word value of 48% at a PTA of 50) and clamps outside them (88 below 0, 12 above 80; 0 without a PTA). A PTA of 41.7 gives 58. Days 4 and later use it; the old `WRS_PREDICTED_MIN` table and `wrs_predicted_min` stay for Day 3's tests only (no day uses them). Every line takes the number as `{min}` from the sheet, and no line or paper credits it to Dubno: "{his} tones predict at least {min}%". Steve replaces the rows (CHAPTER4 Q27). | CHAPTER4 §2, §7, §10, §11 |
| D15 | **Rollover is the rollover index (A2).** `SpeechRules.wrs_rollover(lists)` over an ear's counted lists (`{level_db, pct}`): PBmax = the best score, PBmin = the lowest score at a level ABOVE the PBmax list's (none: no PBmin, no rollover), `index = rollover_index_of(pb_max, pb_min)` = (PBmax - PBmin) / PBmax (0 when PBmax is 0), and `rollover = index >= ROLLOVER_INDEX_CUTOFF` (0.45, the classic cut-off; CHAPTER4 Q28). Returns `{pb_max, pb_min (-1 none), index, rollover}`. The raw drop (`rollover_drop`) is information only; Day 3's `is_rollover` and `rollover_index(scores)` stay for their old tests (not used by Days 4-5). | CHAPTER4 §2.2, §7 |
| D16 | **WRS noise level** = `wrs_mask_level(level, bc_te_best, transducer, nontest_abg := 0)` = `level - 20 + nontest_abg`, clamped to `[level - IA, bc_te_best + IA - 5]` (IA from `SPEECH_IA_DB`; when the two cross, the ceiling wins; no bone, no ceiling). (A4) `nontest_abg` is the other ear's largest air-bone gap (`nontest_largest_abg`), as Day 3's speech masking adds it; Nora has none. `wrs_mask_capped(...)` says when the ceiling bit (the `wrs_mask_capped` tip). SRT keeps `speech_mask_level`. | CHAPTER4 §2.1, §11 |
| D17 | **Best bone per frequency.** `ear_best_bone(tones, ear)` takes, at each of 500-4000 Hz, masked bone, else unmasked bone, else air. `nontest_best_bone(tones, e) = min(ear_best_bone(tones, other))`; the noise ceiling uses `min(ear_best_bone(tones, e))`. | CHAPTER4 §8; CHAPTER5 §2 |
| D18 | **An audible chunk has a margin of 3 dB or more** (`WRS_AUDIBLE_MARGIN_DB`). The lens draws 0 to 3 dB as "only just" (full ink, dotted underline). The "AUDIBLE, BUT MISSED" stamp needs plan `audible_stamp` (List 2 and the redo only). | CHAPTER4 §2.4, §5.3 |
| D19 | **One golf rule on both days.** Each player list is a hole. A clean list is a **birdie** only when it was a solo list whose set-up the player made unprompted (`tee_bonus`); coached lists, and lists whose level Hoot set, top out at par. The sheet's `golf` is its newest player list's; `holes` keeps every list's. | CHAPTER4 §9; CHAPTER5 §8.3 |
| D20 | **WRS answer styles are surface only.** On the player's words, a hit may come back chatty and a miss may come back as a plural trap; List 2 has one self-correction. The deal, the counts and the score are unchanged. | CHAPTER4 §8 |
| D21 | **Aided party tests run at `SIN_AIDED_DB` 50 dB HL** (about 65 dB SPL in the sound field), set by Hoot. Aided sheets carry no band and no remedy: they are labelled "aided, sound field" and only compared, OMNI against FOCUS. | CHAPTER5 §2, §6, §8 |
| D22 | **Party band names and remedies in our own words**: new `SIN_BAND_NAMES` (Near-normal / Mild / Moderate / Severe; A7: 0-3 dB is normal or near-normal, never "Small") and `SIN_REMEDIES`. `SIN_BAND_TITLES` and `SIN_HELP` stay as they are and no new file reads them (a test). Lines print "{Band} SNR loss"; the receipt prints "{BAND} SNR LOSS". | CHAPTER5 §5.7, §9 |
| D23 | **Hoot's off-screen work** goes through `SpeechSession.run_by_textbook(ear)` (C23) with mode actions through `SpeechTestMode.do(action, rec)`, and the screen's `run_hidden(...)` (H28) shows it as a short montage. It replaces the levels' `hoot_runs_ear` fallback for WRS and SIN. | CHAPTER4 §3; CHAPTER5 §3 |
| D24 | **`hoot_only`** plan key: the list is Hoot's whatever quick visit says. The screen's Hoot-turn gate becomes `hoot_only or quick_visit` for both `hoot_turn_after` and `hoot_first`. | CHAPTER4 §3; CHAPTER5 §3 |
| D25 | **Word lists are assigned in play order**: right `words_1`, left `words_2`, then the next left list (redo or louder) takes `words_3`, and the one after that `words_4`. | CHAPTER4 §3, §6, §10 |
| D26 | **Slots everywhere.** Events, beats and `errors[]` carry `slot`; screenshot names are `speech_<slot>_<test>_<list_id>_first_word` / `_stored` for WRS and SIN (SRT keeps Day 3's names). | CHAPTER4 §15; CHAPTER5 §13 |
| D27 | **When word scores refer** (`wrs_referral`): asymmetric (A3: `wrs_differ` on the two final bests, the 25-word critical difference), or rollover (A2), or below predicted (A1) in exactly one ear. Below predicted in both ears alone gives no referral and the flag `below_predicted_both` (open question 8). | CHAPTER4 §7 |
| D28 | **In-list gags never block.** They are `bubble.aside` lines raised by the mode from `refresh()` / `on_answer()`, each gated by `session.observe_once(key, ...)`. The tea demo is a Hoot turn before List 2's first word, not a list item. | CHAPTER4 §5.6, §12; CHAPTER5 §5.3, §10 |
| D29 | **"Call it"** is a WORD-mode beat (`call_it`) on the SPEECH screen, not a dialogue choice: Right = "{He}'ll get it", Left = "{He}'ll miss it", unscored. | CHAPTER4 §5.3 |
| D30 | **The Day 3 coach is reused** when a speech day runs a solo SRT before `mike` is done: the SRT plan is coached instead. | CHAPTER4 §3.1 |

#### §9.10.2 The pattern

```
SpeechSession (RefCounted) --strong--> mode: SpeechTestMode (RefCounted) --WeakRef--> session
SpeechSim     (RefCounted) --strong--> _wrs: WrsModel / _sin: SinModel   --WeakRef--> sim
SpeechScreen  (CanvasLayer) --child--> _mode: SpMode (Node)          (Node refs: no cycle)
```

- **Loaded by path.** Shared files never name a Day 4 or Day 5 class. `SpeechTestMode.make()`, `SpMode.make()` and
  `SpeechSim.wrs_model()` / `sin_model()` use `ResourceLoader.exists(path)` then `load(path).new(...)`. That way S0
  compiles and passes every test before W and P add a single file, and either builder can merge first.
- **No reference cycles.** A mode or model holds its owner through `weakref()`; accessors return the owner or null.
  A fresh mode is made on every `configure()`, and the old one is dropped. Tests check that a freed session frees its
  mode and that a re-configured session frees the old mode (`is_instance_valid` on a `WeakRef`).
- **Null mode = Day 3.** `test == &"srt"` gives `mode == null`, and every seam starts with `if mode != null`. The
  screen's seams start with `if _mode != null`.
- **Missing mode script.** For `test` `wrs` or `sin` with its script absent, `configure()` sets `mode_missing = true`.
  `present()` is then refused, and the screen ends the test at once with `test_finished(results)`. The results hold
  no sheet for that test, and `push_warning("speech mode <test> missing")` is printed. `run_by_textbook` returns `{}`.
  Levels then say the result in one Hoot line from the chart (CHAPTER5 §12) and carry on.
- **Tests only:** `SpeechTestMode.path_override` and `SpMode.path_override` point a test id at another script (the
  seam probes) or at nowhere (the missing-mode path), and `SpeechSim.wrs_model_path` / `sin_model_path` do the same
  for the models. The game never sets them.
- **Static typing.** A loaded mode is typed as its base (`SpeechTestMode`, `SpMode`). Model calls go through
  `Object.call()` on a `RefCounted` member, so the facade compiles without the model class. Variant returns are
  typed explicitly (`var r: Dictionary = m.call("deal", ...)`).

#### §9.10.3 `SpeechTestMode` (core, S0b): `res://core/speech/modes/speech_test_mode.gd`

```gdscript
class_name SpeechTestMode
extends RefCounted
const PATHS: Dictionary[StringName, String] = {
	&"wrs": "res://core/speech/modes/wrs_test.gd", &"sin": "res://core/speech/modes/sin_test.gd"}

static func make(s: SpeechSession, t: StringName) -> SpeechTestMode   # null for srt or a missing script
static func script_path(t: StringName) -> String     # path_override (tests only), else PATHS
func _init(s: SpeechSession) -> void                 # stores weakref(s)
func session() -> SpeechSession                      # null once the session is gone

# identity and lifecycle
func test_id() -> StringName                         # &"wrs" / &"sin"
func configure(plan: Dictionary) -> void             # after the session's common configure()
func slot_for(ear: String) -> String                 # default: ear
func begin(ear: String, coached: bool) -> void       # after the session's common begin(); picks the first item
func start_level() -> int                            # the dial at begin (plan.level, else the mode's default)
func measure_key() -> String                         # default "<test>:<slot>"; per list for wrs / sin

# queries (all use only what the player can see, except where marked truth)
func next_item() -> Dictionary
func current_trials() -> Array                       # this list's trials
func is_done() -> bool                               # this list is finished
func words_left() -> int                             # items still to present in this list
func can_set_level() -> bool                         # false once the list has started
func can_mask() -> bool
func masking_needed(level: int) -> bool
func mask_level(level: int) -> int                   # C24: the noise (dB EM) at this dial while it is on
func recommended_start() -> int
func recommended_action() -> Dictionary              # {action, target_db, ...}; truth only for scoring actions
func textbook_target() -> int
func candidate() -> int                              # SpeechRules.NO_SRT

# controls
func present() -> Dictionary                         # {} = refused
func score(correct: bool) -> Dictionary
func store() -> Dictionary                           # {} = refused
func act(action: StringName, args: Dictionary = {}) -> Dictionary   # mode-only controls; {} = refused
func do(action: StringName, rec: Dictionary) -> Dictionary          # run_by_textbook: one mode-only action of
                                                                     # recommended_action(); {} = refused

# views and words
func state() -> Dictionary                           # get_state()[test]
func tip(kind: StringName) -> String                 # "" = use SpeechSession.TIPS
func points(kind: StringName) -> int                 # -1 = use SpeechSession.POINTS
func on_level_refused() -> void                      # once-per-list tip
func on_mask_refused() -> void
func summarize(speech: Dictionary) -> void           # adds wrs_summary / sin_summary to build_results()
```

All base methods are safe no-ops (`{}`, `[]`, `false`, `-1`, `""`), except that the level and the noise stay free
(`can_set_level` and `can_mask` return true) and `mask_level` follows the SRT rule until a mode says otherwise. Modes
report through the session's public helpers (C22), so combo, points, checks and `technique` work exactly as for SRT.

#### §9.10.4 Session seams (S0b), `core/speech/speech_session.gd`

Each seam is a guarded line or two. Day 3 code paths are unchanged when `mode == null`.

| # | Where | Change |
|---|---|---|
| C1 | vars | `var mode: SpeechTestMode = null`, `var mode_missing := false`, `var slot := "right"`, `var seq := 0`, `var used_lists: Array[String] = []` |
| C2 | `configure()` end | `mode = SpeechTestMode.make(self, test)` (a fresh one every call; the old one is dropped); `mode_missing = test != &"srt" and mode == null`; `if mode != null: mode.configure(plan)` |
| C3 | `begin()` | `slot = mode.slot_for(e) if mode != null else e`; `ensure_slot(slot)`; the dial is `mode.start_level()` when a mode exists; `_pick_next()` only without a mode; then `mode.begin(e, coach)`. `coached` gets the key `slot` too. |
| C4 | new | `ensure_slot(s)`: adds `trials[t][s] = []` for every test when missing (Day 3's "right" / "left" exist already) |
| C5 | new | `measure_key() -> String`: `mode.measure_key()` or `"%s:%s" % [test, ear]` (the old `_mkey()`, which now calls it) |
| C6 | `trials_for(e, t)` | with a mode and no arguments: `mode.current_trials()` |
| C7 | `is_done(e, t)` | with a mode and no arguments: `mode.is_done()` |
| C8 | `next_item()` | `mode.next_item()` |
| C9 | `present()` top | `if mode_missing: return {}`; `if mode != null: return mode.present()`. Modes put `slot` and `list_id` in the item they emit with `speech_presented`. |
| C10 | `score()` top | `if mode != null: return mode.score(correct)` |
| C11 | `store()` top | `if mode != null: return mode.store()`. Modes put `slot` in every sheet they emit with `speech_stored`. |
| C12 | `candidate()` | `mode.candidate()` |
| C13 | `recommended_action()`, `textbook_target()`, `recommended_start()` | delegate |
| C14 | `masking_needed_here(level)` | `mode.masking_needed(lv)` |
| C15 | `set_level()` top | `if mode != null and not mode.can_set_level(): mode.on_level_refused(); return false` |
| C16 | `set_mask()` top | `if mode != null and not mode.can_mask(): mode.on_mask_refused(); return false` |
| C17 | `pta_for(e)` | `"both"` returns the lower (better) of the two ears' PTAs (NAN when both are missing) |
| C18 | new | `measured_thresholds(e) -> Dictionary` (public `_tone_thresholds`; for `"both"`, the per-frequency minimum of the two ears), `nontest_best_bone(e) -> float` and `test_best_bone(e) -> float` (D17) |
| C19 | `get_state()` | adds `"slot": slot`, `"mode": String(test) if mode != null else ""`, `out[String(test)] = mode.state()`; with a mode, `words_left` is `mode.words_left()` and `recommended_start` is `mode.recommended_start()` |
| C20 | `build_results()` | per sheet, `units := int(sh.get("units", 0 if by_hoot else 1))`: `n += units`, `acc += accuracy x units`; strokes and par as now. After the loop, for each of `wrs` and `sin` with sheets, `SpeechTestMode.make(self, t).summarize(out)` (a fresh, throwaway instance). |
| C21 | `tip_text(kind)` and `_clean()` points | `mode.tip(kind)` first (when not ""), and `mode.points(kind)` first (when not -1) |
| C22 | new public helpers | `clean(kind, data := {})`, `fail(kind, data, message := "")` (wraps `_error(..., false, message)`), `observe(kind, data)`, `observe_once(key, kind, data)`, `emit_kind(kind, data, message)`, `data(extra) -> Dictionary` (wraps `_data`; adds `slot`), `next_seq() -> int` (`seq += 1`), `say(t) -> String` (wraps `_say`), `slips() -> Array` (this measurement's error kinds so far). Every error and observation carries `slot`. |
| C23 | new | `run_by_textbook(e: String, max_steps := 4000) -> Dictionary`: with `scoring = false`, `begin(e, false)`, then loop `recommended_action()` until `&"none"` or a stored sheet: `louder` / `softer` / `mask_toggle` / `present` / `score_correct` / `score_missed` / `store` through the session's own methods, anything else through `mode.do(action, rec)` (a refusal ends the loop with a `push_warning`). Returns the stored sheet, or `{}`. Emits the usual signals. It is Hoot's work: `by_hoot` and `units` 0. |
| C24 | `mask_level()` | with a mode: `mode.mask_level(db)` while the noise is on, else -1 (WRS: `wrs_mask_level`, D16 with A4; the base mode keeps the SRT rule) |

`merge_results` is unchanged: it already uses `scored_sheets` (now the sum of `units`) times `SHEET_WEIGHT`.

#### §9.10.5 `SpMode` (ui, S0b): `res://ui/speech/modes/sp_mode.gd`

```gdscript
class_name SpMode
extends Node                                         # a child of the SpeechScreen, freed with it
const PATHS: Dictionary[StringName, String] = {
	&"wrs": "res://ui/speech/modes/sp_mode_word.gd", &"sin": "res://ui/speech/modes/sp_mode_party.gd"}
## Base actions every mode MUST claim in act(), so the SRT handlers never run on a WRS or SIN list (a test).
const MUST_CLAIM: Array[StringName] = [&"store", &"score_correct", &"score_missed"]
static var path_override: Dictionary = {}            # tests only: a test id -> another script (or nowhere)
var screen: SpeechScreen

static func make(t: StringName) -> SpMode            # null for srt or a missing script
func setup(s: SpeechScreen) -> void                  # once: build widgets under s.ui_root()
func enter(plan: Dictionary) -> void                 # every start_test of this test
func exit() -> void                                  # stop sounds, clear overlays (screen exit or test change)
func hidden_base_widgets() -> Array[StringName]      # of &"ladder", &"meter", &"card", &"tally", &"mask_button", &"store_button"
func layout(rects: Dictionary) -> void               # {bubble, card, mid, meter, perch, dance, deck, booth}
func deck_groups() -> Array[Dictionary]              # [{title, buttons: [{action, id, width}]}], left to right
func make_buttons() -> Dictionary                    # action -> SpButton (mode-only buttons)
func input_for(action: StringName, args: Dictionary = {}) -> StringName   # &"" = base mapping
func mouse_for(action: StringName, args: Dictionary = {}) -> String       # anchor id; "" = base mapping
func handle_input(event: InputEvent) -> bool         # true = consumed (runs BEFORE the base handler)
func act(action: StringName, args: Dictionary = {}) -> bool               # true = handled; MUST_CLAIM always true
func on_present(trial: Dictionary) -> float          # shows the item AND calls screen.voice.play_item(...)
                                                     # (or the babble + talker); returns the seconds until the
                                                     # answer may show; < 0 = base card path and base voice call
func on_answer(trial: Dictionary) -> bool            # true = the mode shows the answer
func on_scored(trial: Dictionary) -> void
func on_stored(sheet: Dictionary) -> bool            # true = the mode runs its own end-of-list show, and then
                                                     # MUST call screen.complete_list(sheet)
func on_technique(kind: StringName, data: Dictionary) -> bool             # true = claimed
func kind_class(kind: StringName) -> StringName      # &"error" / &"hold" / &"repeat" / &"" (base lists)
func target_for(kind: StringName, data: Dictionary) -> String             # anchor; "" = base
func coach_text(rec: Dictionary) -> Array            # [text, anchor, key] or [] = base
func beat_id(rec: Dictionary) -> StringName          # default &"speech"; &"call_it" / &"lens_try" for mode beats
func beat_action(rec: Dictionary) -> Dictionary      # may replace the session's action (lens_try, call_it)
func beat_info(info: Dictionary) -> Dictionary       # adds mode keys to the beat's info
func beat_key(rec: Dictionary) -> String             # dedupe key for _emit_beat
func hoot_step() -> float                            # -1 base step, -2 hand back to the player, >= 0 seconds to wait
func hoot_turn_text() -> String                      # "" = plan / base text
func lcd_view(view: Dictionary) -> Dictionary        # adds §9.10.7 SpLcd keys
func dance_specs() -> Array[Dictionary]              # [{title, sub}] x 3
func refresh(state: Dictionary) -> void              # may raise asides (D28)
func celebrate(sheet: Dictionary) -> bool            # true = handled
func callout_point() -> Vector2
func mastery_skill(kind: StringName) -> StringName   # &"" = none
func anchors() -> Dictionary                         # anchor id -> Control
func restore_base() -> void                          # put back every base label, glyph and visibility it changed
func extra_state() -> Dictionary                     # get_state() extras: lens_on, confirm_pending, practice, ...
func montage(sheet: Dictionary) -> float             # run_hidden's show of a sheet Hoot ran off-screen (< 0 = none)
```

#### §9.10.6 Screen seams (S0b), `ui/speech/speech_screen.gd`

| # | Where | Change |
|---|---|---|
| H1 | vars | `var _mode: SpMode = null`, `var _modes: Dictionary = {}` (test -> SpMode, built once and reused), `var memory: Dictionary = {}` (survives `start_test` for one visit and is cleared on exit; the lens state and the widget reveals live here) |
| H2 | `start_test()` | after the session is configured: `_set_mode(session.test)`. That unregisters the old mode's anchors (H26), calls its `exit()` and `restore_base()`, then `SpMode.make()` plus `setup()` on first use, `enter(plan)`, hides `hidden_base_widgets()`, merges `make_buttons()` into the button map and calls `_layout()`. `test == srt` restores the base widgets, labels and glyphs. With `session.mode_missing`, it ends the test at once (§9.10.2). |
| H3 | `_unhandled_input()` first line | `if _mode != null and _mode.handle_input(event): get_viewport().set_input_as_handled(); return` |
| H4 | `_act()` first line | `if _mode != null and _mode.act(action, args): return` (`_act` gains `args := {}`). A mode that leaves a `MUST_CLAIM` action unclaimed is a bug (the seam test asserts it). |
| H5 | `_present()` | after `session.present()`: `var wait := _mode.on_present(trial) if _mode != null else -1.0`; with `wait < 0` the card path and `voice.play_item` as now; else the answer timer uses `wait`. The mode owns the voice call and its duration (the babble lead on Day 5). |
| H6 | `_on_answer()` | `if _mode == null or not _mode.on_answer(trial):` the bubble path as now |
| H7 | `_score()` | after scoring: `_mode.on_scored(trial)`. `_maybe_tell()` only when `_mode == null`. The `hoot_turn_after` check moves into `_check_hoot_after()`, which counts `_player_units()` (mode: the player's scored words or locked sentences in this list). |
| H8 | `_on_stored()` | `if _mode != null and _mode.on_stored(sheet): return` (the mode then calls `complete_list(sheet)` itself) |
| H9 | `_handle_technique()` top | `if _mode != null and _mode.on_technique(kind, data): return`; `_is_error` / `_is_hold` / `_is_repeat` consult `_mode.kind_class(kind)` first; `{key:...}` placeholders in `data.message` are filled with `_k()` here too |
| H10 | `_target_for()` | `_mode.target_for(kind, data)` first |
| H11 | `_celebrate()` | `_mode.celebrate(sheet)` first; the base path names `sheet.slot`, not `_ear` |
| H12 | `_golf_callout()` | position from `_mode.callout_point()` when not `Vector2.ZERO` |
| H13 | mastery | the Hoot mastery skill from `_mode.mastery_skill(kind)` when not `&""` |
| H14 | `_start_hoot_turn()` | banner text `_mode.hoot_turn_text()` first; `_hoot_speed()` reads `plan.hoot_speed` (default `HOOT_SPEED` 8) |
| H15 | `_hoot_step()` | `var w := _mode.hoot_step() if _mode != null else -1.0`: -1 runs the base step (`recommended_action()` through `_do`), -2 calls `_end_hoot_turn()` and hands back, >= 0 waits that long |
| H16 | the Hoot-turn gate | `var hoot_ok := bool(plan.get("hoot_only", false)) or quick_visit` (D24), for `hoot_turn_after` and for `hoot_first`. `plan.hoot_first > 0` starts Hoot's turn at once, or at the player's first PRESENT when `plan.level_first` (the mode hands back with -2). |
| H17 | `_hoot_done_ears` | keyed by `session.measure_key()` instead of the ear, so a second list on one ear gets its own Hoot turn |
| H18 | `_beat_action()` | `_mode.beat_action(rec)` when not empty |
| H19 | `_emit_beat()` | beat id `_mode.beat_id(rec)`; info passed through `_mode.beat_info(info)` (it adds `slot`); dedupe key `_mode.beat_key(rec)`; the mouse anchor from `_mode.mouse_for(action, args)`, else `button(action)`'s anchor, never an inline `ACTION_BUTTONS[action]` lookup |
| H20 | `_solve()` | input from `_mode.input_for(action, args)` when not `&""` |
| H21 | mouse route | `info.mouse.click` from `_mode.mouse_for(action, args)` when not "" |
| H22 | `_coach_text()` | `_mode.coach_text(rec)` first. `{key:<action>}` placeholders are filled with `_k(action)` for every coach line and tip (D10; H9 does the same for technique messages). |
| H23 | `_refresh()` | the LCD view goes through `_mode.lcd_view(view)`; then `_mode.refresh(st)` |
| H24 | `_refresh_buttons()`, `_update_dance()` | mode buttons follow `can_*`; `SpDance.set_specs(_mode.dance_specs())` |
| H25 | `_layout()`, `_layout_deck()` | `_layout()` hands the rect dictionary to `_mode.layout(rects)`. `_layout_deck` builds the groups from `_mode.deck_groups()` (button ids and widths come from the entries, not the base's hard-coded table) and hides any button not placed, except the utility pills (keys, key style, pause). |
| H26 | `_register_anchors()` | also registers `_mode.anchors()`; `_set_mode()` unregisters the old mode's anchors on a test change (Day 5 goes SRT to WRS to SIN in one visit), and exit unregisters them all |
| H27 | public helpers | `player_ok()`, `idle()`, `busy()`, `refresh()`, `after(s, cb)`, `make_button(...)`, `button(action)`, `say(t)`, `tip(kind, msg, anchor)`, `deny(button, msg)`, `k(action)`, `do_action(action, args := {})`, `hoot_running()`, `answer_shown()`, `clock()`, `ui_root()`, **`complete_list(sheet)`** (runs `_complete_ear()`'s celebrate-and-finish and emits `Events.speech_stored`; modes that claim `on_stored` must call it), plus the read-only members `session`, `fx`, `voice`, `booth`, `lcd`, `card`, `bubble`, `dance`. `get_state()` adds `mode`, `slot` and the mode's `extra_state()` (`lens_on`, `confirm_pending`, `practice`, and WORD mode's view keys). `demo_start()` reads `--demo-test=wrs|sin`. |
| H28 | new | `run_hidden(patient, ear: String, plan: Dictionary, show := true) -> Dictionary`: configures the screen's own session for `plan` (so the sheet joins this visit's results), calls `session.run_by_textbook(ear)`, and with `show` plays a 2-3 s montage (SRT: the agreement meter swings to its result; a mode: `_mode.montage(sheet)`, WRS: the strip stamps in finished, the band chip lands and a chip names Hoot's score). No beats, no Hoot turn, whatever quick visit says. Returns the sheet. |

#### §9.10.7 Other S0 additions to shared files (all additive)

**S0a** (it unblocked P0):

| File | Addition |
|---|---|
| `core/speech/speech_sim.gd` | `var condition: StringName = &"unaided"`; public `ia()`, `air(ear)`, `delay_for(p)` (thin wrappers of `_ia`, `_air`, `_delay`); lazy `wrs_model()` / `sin_model()` by path; the facade methods of §9.12, each returning a safe default while its model is missing |
| `core/speech/speech_material.gd` | `tokens(text) -> PackedStringArray` (lowercase, punctuation stripped); `validate()`: optional monosyllable `chunks`, `asides` and `plural` checks; sentence `key_words`, `mishears` and optional `key_sounds` checks (§9.11.3) |
| `core/speech/speech_rules.gd` | a new block "lists (Days 4-5)" at the end of the file: `LIST_TEE_BONUS := 2`, `LIST_CONFIRM_SLIP := 3` (D19; both modes read them) |
| `autoload/events.gd` | the block below, after the speech signals; the doc-comment amendment of the speech signals ("both", `slot`) |
| `tools/setup_input_map.gd`, `project.godot` | `toggle_lens` = V; `party_word_1` to `party_word_5` = 1-5 and keypad 1-5; `party_all_got` = G. Nothing is rebound; 6 and 8 stay the transducers. The swap-arrows style swaps only `louder` / `softer` (and the `mask_*` pair), as now. |
| `autoload/game.gd` | `PHASES` += `&"counselling"` (`&"explainer"` exists already); two marker comments in `CHAPTERS` after `mike`, with one untouched separator line between them (W and P each replace their own marker; §9.23) |
| `story/explainers/movies.gd` | two `MOVIES` lines after `"masking"`: `"letter_choir": "res://story/explainers/movies/letter_choir.gd"` and `"party_noise": "res://story/explainers/movies/party_noise.gd"` |
| `story/explainers/movies/letter_choir.gd`, `party_noise.gd` | valid stubs (`chapter` "nora" / "marco"): three `card` scenes of 16 s each (48 s, at least `MIN_TOTAL_S` 45), so `Movies.validate` passes on day one. W and P each own and replace their own file in W5a / P5a (the data, cards only) and W5b / P5b (the `stage` line), §9.20. Day 4's is the full Letter Choir; Day 5's stays the stub until its PR. |

**S0b** (the seams, reviewed by P):

| File | Addition |
|---|---|
| `core/speech/modes/speech_test_mode.gd`, `ui/speech/modes/sp_mode.gd` | the two base classes (§9.10.3, §9.10.5) |
| `core/speech/speech_session.gd`, `ui/speech/speech_screen.gd` | C1-C23, H1-H28 |
| `ui/speech/sp_lcd.gd` | optional view keys: `test_chip` (String), `ear_chip` (String; "BOTH" draws in ink, never an ear colour), `chips` (Array of String), `info_line` (String), `big_caption` (String, replaces "LEVEL"), `aux` (Array of {label, value}), `start_chip` (String: the level chip by the dial, which follows it). A view without them draws exactly as now. |
| `ui/speech/sp_dance.gd` | `set_specs(specs: Array[Dictionary])`; the Day 3 specs stay the default |
| `ui/speech/sp_button.gd` | glyphs `EYE` (lens), `LOCK` (lock in), `ALL` (all got) |
| `ui/speech/sp_word_card.gd` | `var word_drawer: Callable` (when valid, it draws a second row under the word; the word itself is always drawn crisp); `var carrier := ""` (a small line above the word); `var hide_word := false` (sentence mode only) |
| `ui/speech/sp_bubble.gd` | `var style: StringName = &"normal"`: `&"loud"` draws 1.4x plain capitals (no shake); `&"ghost"` draws a ghost-shaped tail. `var aside := ""`: a small side bubble that never blocks. `var text_inset := 0.0`: keeps the answer clear of the score badge (WORD mode). |
| `story/daily_decibel.gd` | weather `String(s.get("weather", <today's expression>))`; subheads from `s.subheads` when present (the cases' mechanism, also for the C-grade line); column 2: when `s.has("sports_script")`, `(load(path) as GDScript).new().call("build", c2, aud, s)`, else today's code; `_is_speech(aud)` is true when any of `speech.srt` / `speech.wrs` / `speech.sin` is not empty (Day 3 unchanged) |
| `docs/SPEECH.md` §6 | rewritten once for all three tests: golf per list (D19), efficiency 1.0 on fixed lists, `units` |
| `tools/INTEGRATION_NOTES.md` | the bot patch of §9.22, with what is already applied |
| `core/tests/test_speech_seams.gd` | §9.24 |

```gdscript
# ---------------------------------------------------------------- speech, Days 4-5 (CONTRACTS.md §9.10-§9.24)
## The WORD-mode lens ("NORA-VISION") was turned on or off. ear: the test ear.
signal speech_lens_toggled(ear: String, on: bool)
## A party sentence was locked in. condition: "unaided" / "omni" / "directional"; count: key words billed.
signal party_sentence_locked(condition: String, n: int, snr: int, count: int)
## A party list finished (6 sentences). snr_loss = SIN_CONSTANT - total.
signal party_list_done(condition: String, list_id: String, total: int, snr_loss: float)
```

The explainer signals (`explainer_started(movie_id, source)`, `explainer_finished(movie_id, skipped)`,
`explainer_scene`) already exist (§2.1); declaring them again would be a duplicate-member parse error.

### §9.11 Material

#### §9.11.1 Word lists (W): `res://core/speech/material/words_1.json` to `words_4.json`

```json
{"id": "words_1", "title": "Word list 1", "kind": "monosyllable", "original": true,
 "note": "Written fresh for Booth Camp: ... Nothing is copied or closely paraphrased from a published word test (...)",
 "items": [
  {"id": "w1_01", "text": "sock", "key_sound": "s", "foils": ["lock", "rock", "dock"], "plural": "socks",
   "chunks": [["s", "s"], ["o", "vowel"], ["ck", "k"]]},
  {"id": "w2_07", "text": "bike", "key_sound": "b", "foils": ["Mike", "hike", "like"], "plural": "bikes",
   "chunks": [["b", "b"], ["i", "vowel"], ["k", "k"], ["e", ""]],
   "asides": {"mike": "Mike? He's in the break room. With donuts."}}
 ]}
```

- **Ids**: list ids `words_1` to `words_4` (`SpeechRules.WRS_LISTS`); item ids `w<list>_<nn>` (01-25), unique across the
  four lists.
- `note`: the list's originality statement (the guard below reads it).
- **Counts**: exactly 25 items per list (`WRS_WORDS`), 100 different target words.
- `key_sound`: a `SOUND_CUES` id: the sound that tells the word apart from its foils.
- `foils`: 3 or more rhyme words that differ from the target only in the key sound. They must not equal the target,
  must be distinct, and must not be a target in the same list. They are the believable mishears.
- `chunks` (optional in `validate`, **required by the tests for `words_*`**): spelling pieces with sound ids. "" marks
  silent letters. The pieces join exactly to `text`, every id is in `SOUND_CUES` (or ""), and at least one piece
  carries `key_sound`. The lens, `word_fully_audible` and the "audible, but missed" stamp read these.
- `plural` (optional): the plural or other inflected form used by the `plural_trap` answer style (§9.12.1). It must
  differ from `text` and from every foil.
- `asides` (optional): {foil in lowercase: Hoot's side line}. It is shown when that foil is her answer. Never
  blocking, once per visit. Each line is 18 words or fewer.
- **The key-sound mix** (`SpeechRules.WRS_KEY_MIX`, the same in every list): s 3, f 2, th 2, t 2, k 2, and one each
  of sh, ch, z, v, p, b, d, g, m, n, l, r, w, h (25).
- **Content rules** (CHAPTER4 §6): one syllable, familiar to a 10-year-old, no scary, medical, rude or alcohol words,
  no item repeated across lists. Word list 1 is CHAPTER4 §6's table, with the high, soft key sounds early (List 1 is
  the right ear, where the faint "f" and "th" teach the lens). Lists 2-4 follow the recipe.
- **The audible-word rule** (tests): `words_2` and `words_3` each have at least 2 words in places 2-6 that are
  `word_fully_audible` (every chunk 3 dB or more) on Nora's left at 70, 75 and 80 dB, at least 2 of them clearing 8 dB
  at 70. Build them only from sounds that clear 8 dB at 70 (sh, b, m, n, ng, l, r, w, y and vowels; for example
  "moon", "ring", "shell"), so a 5 dB wobble in Hoot's tones keeps them audible. Place 1 never counts: its PRESENT comes
  before the deal can be read.
- **The asides**: List 2 has "bike" (foil "Mike") in places 1-8, and List 3 has "hook" with the foils "Hoot", "hoof"
  and "hood" (its last sound changes, never its first: the rhymes that change its first sound are a published
  rhyme set, so none is used) in places 1-5, with the aside "Present!"
  on "hoot".
- **Originality guard** (`test_originality_guard`, tests only; amended 2026-10-19). The repo never holds a published
  test's words, so nothing compares with one and the guard checks only our own material:
  - every list's `note` begins "Written fresh for Booth Camp" and names the published tests it must not copy (NU-6,
    W-22, CID W-1, PB-50, AB / Boothroyd, NU-CHIPS, WIPI and the Modified Rhyme Test);
  - no target is its own foil or a foil of a target in its own list, every foil is one word, and an item's foils are
    distinct;
  - no target repeats within or across the four lists (100 different targets);
  - no two of the 100 items share more than two words of their rhyme sets (the target plus its foils), so no set is
    reused with a word swapped.
  Everyday words such as "night" and "nose" are fine on their own. Steve is asked to flag any item or rhyme set he
  recognises (CHAPTER4 Q21).
- Recordings (later): `res://assets/speech/words_<n>/<item_id>.wav` (`docs/SPEECH.md` §7). There is no carrier phrase
  (open question 15).

#### §9.11.2 Party lists (P): `party_practice.json`, `party_1.json` to `party_6.json`

```json
{"id": "party_1", "title": "Party list 1", "kind": "sentence", "original": true,
 "items": [
  {"id": "p1_3", "text": "A loud trumpet woke the whole street.",
   "key_words": ["loud", "trumpet", "woke", "whole", "street"],
   "mishears": [["cloud"], ["crumpet"], ["spoke", "walk"], ["bowl", "goal"], ["sheet", "streets"]]}
 ]}
```

- **Ids**: `party_practice` ("Practice sentence", 1 item, `pp_1`) and `party_1` to `party_6` ("Party list 1" to
  "Party list 6", `SpeechRules.SIN_LISTS`). Item ids `p<list>_<n>` (n = 1-6).
- **Counts**: 6 sentences per list (one per `SIN_SNRS` step), 5 key words each (`SIN_KEY_WORDS`), so 30 key words per
  list and 180 over the six lists, plus 1 practice sentence.
- **Order**: fixed (D11). Sentence n plays at `SIN_SNRS[n - 1]`.
- `key_words` (5): every one appears in `SpeechMaterial.tokens(text)` in this order. Their token positions are
  derived and never stored. A key word is never repeated within a list.
- `mishears` (5 groups, each 1 or more words): plausible wrong answers per key word. No mishear equals its key word,
  and none is a homophone of it. A mishear that shares the key word's stem is a **trap**, and it is still a miss.
  `SpeechRules.is_trap(said, key_word)` (as built): one word starts with the other ("street"/"streets",
  "smelly"/"smell"), or they share a base after a regular ending is cut (-ies/-ied to -y, -ves to -f/-fe, -es, -s,
  -ed, -ing, with or without a final e; a doubled consonant before -ed/-ing: "slipped" -> "slip"; bases of 3 letters
  or more) or through `SIN_IRREGULAR_FORMS` ("sang"/"sing", "left"/"leave"). So any changed ending is a trap, and
  its line names endings (§9.14.5).
- `key_sounds` (optional, 5 groups of `SOUND_CUES` ids): overrides the letter-based guess (`key_word_sounds`) where
  spelling misleads ("phone" -> f).
- **Content** (CHAPTER5 §5.5 and Appendix A): everyday, low-context, 6-9 words, mostly not about food, no homophone
  of a key word in its own list. **No two key words of a sentence form an idiom, a compound or a fixed phrase**
  ("pass the salt", "picnic basket", "birthday presents", "caught the ball"), and no sentence is a stock phrase.
  Borderline pairings are listed for Steve (CHAPTER5 §15).
- **Originality guard** (tests only; amended 2026-10-19, as for the word lists). The repo never holds a published
  test's sentences, so the guard checks only our own material (`core/tests/test_speech_sin.gd`, as built):
  - `test_party_notes_say_written_fresh`: every list's `note` says "written fresh for Booth Camp" and names the
    published sentence tests it must not copy (HINT, BKB, IEEE/Harvard, QuickSIN, WIN, BKB-SIN, SPIN, AzBio);
  - `test_party_material_is_our_own`: no sentence repeats within or across the lists (37 different sentences with
    the practice), no two sentences share more than two key words, no key word appears twice in a list; nothing is
    its own mishear, a mishear appears once in its group and is one word; our own homophone table (no mishear is a
    homophone of its key word, and no list holds a homophone of one of its key words); our own banned words (a
    diagnosis, anything scary or violent, rude words, alcohol) in no sentence and no mishear; at most one food
    sentence per list; and no sentence holds one of the fixed phrases named above;
  - `test_party_lists_teach_traps`: every list offers at least 10 plural or tense traps and 25 sound-alikes.
- Babble recording (optional): `res://assets/speech/babble/babble.wav`.

#### §9.11.3 `SpeechMaterial.validate` additions (S0a)

- **Monosyllable**: as now, plus: when `chunks` exists, the pieces join to `text`, the ids are valid, and one piece
  carries `key_sound`. When `asides` exists, every key is a foil in lowercase and every value is a String. When
  `plural` exists, it is a String different from `text` and the foils.
- **Sentence**: `key_words` has 5 entries found in order among `tokens(text)`. `mishears` (when present) has 5 groups
  and no entry equals its key word. `key_sounds` (when present) has 5 groups of valid ids.
- `spondee_a` and every existing list still validate unchanged (a regression test).

### §9.12 SpeechSim: the facade and the two models

The facade lives in `speech_sim.gd` (S0a). The models are new files: `core/speech/models/wrs_model.gd` (W, `WrsModel`)
and `core/speech/models/sin_model.gd` (P, `SinModel`). Each model gets `_init(sim)` and keeps a `WeakRef`. Models use
only `sim.profile`, `sim.rng`, `sim.transducer`, `sim.mask_db`, `sim.condition`, `sim.true_srt()`,
`sim.cochlear_srt()`, `sim.ia()`, `sim.air()`, `sim.delay_for()` and `SpeechSim.as_question()`. Every random draw
uses `sim.rng`, so a seed replays a visit exactly.

#### §9.12.1 WRS facade (S0a) and `WrsModel` (W)

```gdscript
func true_wrs_max(ear: String) -> float                        # 0..100
func p_wrs_test(ear: String, level: int) -> float              # the test ear's own chance, 0..1
func p_wrs_cross(ear: String, level: int) -> float             # the other cochlea's chance (0 when masked out)
func p_wrs(ear: String, level: int) -> float                   # 1 - (1 - test) x (1 - cross)
func deal_wrs_list(ear: String, level: int, items: Array, opts: Dictionary = {}) -> Dictionary
func respond_wrs(ear: String, level: int, item: Dictionary, outcome: StringName, list_items: Array = [],
		silences: PackedStringArray = PackedStringArray(), style: StringName = &"",
		chatter: PackedStringArray = PackedStringArray()) -> Dictionary
```

**Chance of a word** (`docs/SPEECH.md` §4, CHAPTER4 §8):
- `srt_eff = max(true_srt(ear), mask_db - ia())` when the noise is on (`mask_db` >= 0), else `true_srt(ear)`. The
  second term matters only when the noise crosses back to the test ear (overmasking).
- `rollover_drop(ear, L) = max(0, L - after) / 10 x drop_per_10db / 100` (`SpeechRules.rollover_drop`; 0 without a
  `rollover` entry).
- `p_test = clamp(true_wrs_max(ear) / 100 x SpeechRules.wrs_audibility(L, srt_eff) - rollover_drop(ear, L), 0, 1)`.
- `p_cross`: the other ear (`o`) at `Lx = L - ia()`, against `srt_x = max(cochlear_srt(o), mask_db)` when masked
  (the noise is in that ear), else `cochlear_srt(o)`:
  `clamp(true_wrs_max(o) / 100 x wrs_audibility(Lx, srt_x) - rollover_drop(o, Lx), 0, 1)`. Noise at or above the
  crossed level masks the word out (`mask_db >= Lx` gives 0): X dB EM covers speech at X dB HL, so a list masked by
  the rule never has a word stolen.
- `p_wrs = 1 - (1 - p_test) x (1 - p_cross)`.

**The deal** (one call per list, at its first PRESENT; level and noise are locked from then on):
- `n = items.size()` (25). `j = WRS_DEAL_JITTER[rng.randi_range(0, 3)]` from [-1, 0, 0, +1]: one draw per list.
- `k_test = clampi(roundi(p_test x n) + j, 0, n)` and `k_total = clampi(roundi(p_wrs x n) + j, k_test, n)`. So the
  list count is round(p x N) +- 1, with chances 1/4, 1/2 and 1/4 (D4). Real 25-word lists wobble about twice as
  much (open question 1).
- **Which words the test ear misses** (`n - k_test` of them, drawn by weight without replacement):
  - cochlear ear: `w = SpeechRules.wrs_miss_weight(m) = 1 / (1 + exp(m / 4)) + 0.05`, where
    `m = sound_margin(key_sound, L, TRUE thresholds of the ear)`. A sloping loss mostly loses s, f and th words;
  - `neural` ear: `w = 1` (the smear: misses ignore the banana).
- `opts.ensure_audible_miss_by = a` (with `opts.audible_thresholds` = the MEASURED thresholds the lens uses; the true
  ones when missing): if no dealt miss among places 2..a (indices `[1, a)`) is `word_fully_audible` there, the first
  audible hit in that window (never the aside word) swaps its outcome with the last dealt miss outside the window
  (else the last one inside it). `k_test` is unchanged; nothing happens when the window holds no audible word. The
  result names the word as `audible_target` (the Call it word).
- `opts.aside_by = b`: the first item in places 1..b that has `asides` is made a miss: if it was dealt a test hit, it
  swaps outcomes with the last dealt miss after place b that is not the `audible_target` (else the last other miss).
  `k_test` is unchanged. Its answer is the aside foil (`aside_target`, style `&"aside"`).
- **Cross hits**: `k_total - k_test` of the test-ear misses (at most as many as there are), drawn uniformly (never the
  `audible_target` or the `aside_target`), become `&"cross"`; the result's `k_total` counts the ones placed.
- Returns `{outcomes: Array[StringName] (&"test" / &"cross" / &"miss", one per item index), n, k_test, k_total,
  jitter: j, p_test, p_cross, p_total, level: L, mask_db, neural: bool, audible_target: int (-1 none),
  aside_target: int (-1 none)}`.

**One answer** (`respond_wrs`):
- `&"test"` / `&"cross"`: `{text: <the word, first letter up, then "!" when p > 0.9, else ".">, correct: true, kind:
  &"correct", heard_by: outcome}`.
- `&"miss"`: the miss shares are cochlear {foil 0.80, silence 0.20} or neural {foil 0.60, silence 0.25, other 0.15}
  (`WRS_MISS_COCHLEAR`, `WRS_MISS_NEURAL`). When the word is too soft (`A = wrs_audibility(L, srt_eff) < 0.5`), the
  silence share becomes `max(share, 1 - A)` and the others shrink in proportion.
  - foil: a uniform pick from `foils`, as `as_question(foil)`, kind `&"wrong"`, `rhyme: true`, with `aside` when
    the foil has one;
  - other: another target of the list (not this item and not one of its foils), kind `&"wrong"`, `rhyme: false`;
  - silence: a pick from `silences` (the plan's), else `SpeechSim.SILENCES`, kind `&"silence"`.
- **Answer styles** (D20; the mode passes `style` for the player's words only, except `&"aside"`):
  - `&"chatty_hit"` (a hit): "<Word>! <line>", the line from `chatter` (6 words or fewer, `{word}` filled; without a
    plan list, `WrsModel.CHATTER`: "That one came through.", "Easy one!", "Clear as day."), for example "Sock! Like a
    good downbeat." Kind `&"correct"`, `style` recorded. The mode picks it for about 1 hit in 3 (`WRS_CHATTY_SHARE`
    0.33, by `sim.rng`), never on the Call it word.
  - `&"plural_trap"` (a miss): `plural`, first letter up ("Socks?"). Kind `&"wrong"`, `trap: true`. Once per list, on
    the first dealt miss among the player's words whose item has `plural` (never the `audible_target`).
  - `&"self_correct"` (a hit): "<Foil>... no, <WORD>!" Kind `&"correct"`. Once per list when the plan sets
    `self_correct` (List 2), on the player's second dealt hit. The final answer counts (`WRS_SELF_CORRECT_COUNTS :=
    true`; open question 4).
  - `&"aside"` (a miss, Hoot's words too): the deal's `aside_target` always answers with its aside foil
    (`as_question(foil)`, kind `&"wrong"`, `rhyme: true`, `aside` = its line), so the in-joke always lands.
- Always: `delay_s = delay_for(p_total)`, `p = p_total`, `key_sound`, `margin_db` (true), `style`, `trap`, and
  `aside` (from `item.asides` when the foil has one, else "").
- Returns `{text, correct, kind, heard_by, delay_s, p, rhyme, trap, style, key_sound, margin_db, aside}`. `correct`,
  `kind`, `heard_by` and `margin_db` are truth.

#### §9.12.2 SIN facade (S0a) and `SinModel` (P)

```gdscript
var condition: StringName = &"unaided"                         # &"unaided" / &"omni" / &"directional"
func true_snr_loss(ear: String = "both") -> float              # unaided
func effective_snr_loss(ear: String = "both") -> float         # minus the directional benefit under &"directional"
func p_key_word(snr: float, ear: String = "both") -> float     # sin_expected_words(snr, loss) / 5
func respond_sin(snr: int, item: Dictionary, level: int = SpeechRules.SIN_LEVEL_DB,
		ear: String = "both", opts: Dictionary = {}) -> Dictionary
```

- `true_snr_loss(ear)`: `speech.snr_loss` (a number, or {ear: dB}; "both" = the lower ear), else
  `estimated_snr_loss` of the better ear's (or that ear's) true thresholds. `&"omni"` wins nothing (CHAPTER5 §2).
- `effective_snr_loss = true_snr_loss - directional_benefit` under `&"directional"`, never below 0. The loss does not
  depend on the talker level, so the aided level (D21) changes no number.
- **How many**: `expected = SpeechRules.sin_expected_words(snr, loss_eff)`, then
  `count = SpeechRules.sin_count(expected, rng.randf()) = clampi(floori(expected + u), 0, 5)`. This dithered rounding
  is never more than 1 away from `expected` and averages exactly to it. A simulated list's SNR loss has an SD of about
  0.77 dB, about half of what real recorded lists show (open question 1).
- **Which**: `count` of the 5 key words are drawn as heard, the rest as missed. Misses are drawn by weight without
  replacement: `w = SpeechRules.key_word_miss_weight(word, sounds, thresholds, level) = 1 + min(SIN_PICK_CAP 3, the
  number of its key sounds whose cue margin at the talker level is under SIN_PICK_WINDOW_DB 15)`. `thresholds` are
  the true thresholds (ear "both": the per-frequency minimum). Sounds come from `key_sounds[i]`, else
  `key_word_sounds(word)` (from letters: s, f, th, t, k, sh, ch, z, v, p).
- **What he says**: the sentence frame with each heard key word as written, and each missed one becomes:
  - a mishear from its group (0.55; when the group has both a trap and a sound-alike, the trap 1 time in 5
    (`SinModel.TRAP_SHARE`), and a group of traps only always gives a trap),
  - a filler ("something", "mm", "whatsit"; `SinModel.FILLERS`) (0.30; an item without mishears gives a filler),
  - or nothing, with an ellipsis (0.15) (`SIN_MISS_SHARES`).
  One answer in 5 swaps a little word ("the" for "a"; `SIN_LITTLE_SWAP_SHARE`) to show that little words don't count.
  As built, "a" / "an" follow a changed next word ("an angry bear", "a whatsit balloon"), and an answer with a miss
  ends as a question.
- **When the noise wins**: count 0 and `expected < 0.25` give, half the time, one of the plan's `lost_lines`
  (Marco's, CHAPTER5 Appendix B) as the whole answer, never the same line twice in a row. That is kind `&"lost"`,
  with all 5 missed (`said_kinds` all `&"drop"`).
- `delay_s = delay_for(expected / 5)`.
- Returns `{text, heard: Array[bool] (5), said_words: Array[String] (5, "" when dropped), said_kinds:
  Array[StringName] (5: &"heard" / &"mishear" / &"trap" / &"filler" / &"drop"), count, expected, kind (&"all" /
  &"partial" / &"none" / &"lost"), delay_s, snr, loss_eff, little_swap: bool, traps: Array[bool] (5)}`. `heard`,
  `count`, `expected` and `loss_eff` are truth. `said_kinds` picks the `misscored` line (§9.14.5).
- **As built**: `SpeechSim.sin_model()` loads `core/speech/models/sin_model.gd` by path on first use and the facade
  forwards to it, so no shared file names the class; the model holds the sim through a `WeakRef` and draws only from
  `sim.rng`, so a seed replays a visit. What only the item decides is worked out once per sentence (shared by every
  model), and the miss weights once per sentence, talker level and ear (truth is fixed for a visit). Truth helpers
  for the tests and the reveal: `better_ear()` (the lower true speech PTA, "right" on a tie), `thresholds_for(ear)`
  (an ear's true thresholds; "both" = the better of the two ears at each frequency) and `miss_weights(item, level,
  ear)`.
- **Per ear** (an unaided test of one ear, plan `ear`): the same model with that ear's loss. Cross-hearing is ignored
  (open question 12).

### §9.13 SpeechSession mode "wrs" (`core/speech/modes/wrs_test.gd`, W)

#### §9.13.1 One list per `start_test`

A list is one `start_test(patient, ear, coached, plan)` with `plan.test = "wrs"` (`coached` is the `start_test`
argument, never a plan key). The session is kept between lists and ears, so a second list on the same ear lands in the
same ear sheet as `lists[1]`. Lists play in file order (D11) and are assigned in play order (D25). `measure_key()` =
`"wrs:<ear>:<list_id>"`, and `list_n` is the list's place in the visit's play order (1-4). A list id already in
`session.used_lists` is refused for a new list: the mode observes `wrs_list_reused` and `present()` returns `{}` (the
story never does this; the guard is for tests). `louder_than` and `redo_of` read the earlier lists from
`session.sheets` across `start_test` calls (a test).

#### §9.13.2 Plan keys (all optional except `test` and `tones`)

| Key | Type / default | Meaning |
|---|---|---|
| `test` | "wrs" | WORD mode |
| `tones` | §5.1 results | required: the measured PTA, the bone for masking, and the lens |
| `list` | `words_1` | the list id |
| `level` | snap5(PTA); with `louder_than`, the comfortable list's `level_db` | where the dial starts |
| `mask_on` | false | the noise at begin |
| `lock_noise` | false | the noise cannot be turned off (the louder list) |
| `louder_than` | 0 | n of the comfortable list on this ear this list is 20 dB louder than (0 = a comfortable list) |
| `redo_of` | 0 | n of the list this one replaces (the earlier one gets `counts: false`) |
| `transducer` | "phones" | "phones" / "inserts" |
| `ensure_audible_miss_by` | 0 | §9.12.1 (places 2..a) |
| `audible_stamp` | false | the "AUDIBLE, BUT MISSED" stamp and its observation (D18) |
| `aside_by` | 0 | §9.12.1 (the aside word lands as a miss within places 1..b) |
| `styles` | true | the answer styles on the player's words (D20) |
| `self_correct` | false | one self-correction among the player's words |
| `chatter` | [] | the patient's chatty-hit lines (`{word}` token, 6 words or fewer after the word) |
| `silences` | [] | her "no answer" lines |
| `call_it` | [] | the Call it moments: `&"faint_hit"` and / or `&"audible_miss"` (§9.17.5) |
| `chat_demo` | {} | the tea demo before the first word: `{text, chunks: [[piece, sound]...], level, lines: [[who, text]...]}` (§9.17.6) |
| `hoot_only` | false | Hoot runs the whole list whatever quick visit says (D24) |
| `hoot_turn_after` | missing | player words before Hoot finishes the list at x8; the gate is `hoot_only or quick_visit`; 0 = Hoot runs it all |
| `confirmed_wrong_hoot_after` | 0 | after a confirmed wrong set-up, Hoot takes over after this many player words, whatever quick visit says (the list cannot count) |
| `hoot_speed` | 8 | Hoot's time scale |
| `hoot_turn_text` | "I'll score the rest at top speed!" | banner |
| `lens` | memory, else false | the lens state at the first list (it then persists in `screen.memory`) |
| `lens_try_after` | 0 | after this many player words, the `lens_try` beat (0 = never) |
| `loud_bubble` | false | answers in the loud bubble (plain capitals) |
| `ghost_lurk` | the `coached` argument | the lurking Ghost when noise is needed and off (coached lists only; solo lists get the BOO chip instead) |
| `confirm_wrong_setup` | true unless coached | the two-press confirm (§9.17.4); coached lists deny instead |
| `asides` | `SpModeWord.DEFAULT_ASIDES` | the patient's trigger asides `{noise, loud, lens}` (§9.17.6); item asides come from the material |
| `intro`, `done_title` | "" | screen texts |

#### §9.13.3 State and controls

- **Controls**: `present()`, `score(correct)`, `step_level` / `set_level` (before the first word only), `set_mask` /
  `toggle_mask` (before the first word only, and never off with `lock_noise`). `store()` is refused (the list ends
  itself) and observes `wrs_no_store` once. The noise level is always `wrs_mask_level(db, test_best_bone(ear),
  transducer, nontest_largest_abg)` (D16 with A4, through C24).
- `act()` (mode-only controls; the screen calls them):
  - `&"toggle_lens"` {on?}: flips the lens and returns `{lens_on}`. The screen owns the value (in `memory`) and the
    mode mirrors it for `state()`.
  - `&"call_it"` {guess}: records a Call it answer (unscored) and returns `{word, guess, outcome, moment}`.
  - `&"confirm_chip"` {why}: the screen showed the two-press confirm chip (`why` `&"level"` / `&"unmasked"`). The
    set-up was prompted (no tee bonus), and the BOO observes `boo`.
  - `&"prompted"`: any other chip or coach line before the first word: the set-up was prompted.
  - `&"ghost_lurk"`: the lurking Ghost is showing (coached lists): the lesson, once per list.
- **First PRESENT** of a list: the technique checks (§9.13.6, only when `scoring`), then `deal_wrs_list(ear, db,
  items, {ensure_audible_miss_by, aside_by, audible_thresholds: measured_thresholds(ear)})`. Level and noise lock. The
  list id joins `used_lists`. A wrong set-up the player confirmed on a solo list sets `confirmed_wrong` (§9.17.4).
- **Every PRESENT**: `respond_wrs(ear, db, item, outcomes[i], items, plan.silences, style, plan.chatter)` makes the
  trial `{n, list_n, list_id, slot, db, item_id, word, said, kind, rhyme, trap, style, aside, correct, scored: null,
  mask_db, by_hoot, delay_s, heard_by, audible, call_it}`. `audible` = `word_fully_audible(item, db,
  measured_thresholds(ear))` (every chunk 3 dB or more); `call_it` is the Call it moment on that word (`&""` none). It
  is appended to `trials.wrs[ear]` and to this list.
  - A `heard_by == &"cross"` answer emits `reaction(&"cross_heard", ...)` and observes `ghost_word` (once per list) and
    `cross_heard_speech` (once per ear).
- **score(correct)**: `misscored` or `speech_textbook` (§9.13.6). After the 25th score (player's or Hoot's), the mode
  finishes the list (§9.15.1), emits `stored(ear, &"wrs", sheet)` and the observations, and returns the trial with
  `list_done: true`. With `audible_stamp`, a missed word with `audible` true observes `audible_miss` (once per list).
- **The ear's best** is final when the ear has a counted louder list, or its counted comfortable `pct` is at least
  `predicted_min`. Only then are `below_predicted`, `asymmetric` and their verdict lines produced (D13).
- `state()` (`get_state().wrs`): `{list_id, list_title, list_n, word_n (presented), words: 25, scored, right_so_far
  (by the player's marks), pct_so_far (right_so_far x 4), level_locked, noise_locked, comfy_db (the comfortable
  level: the textbook target, or a louder list's comfortable list), window: [lo, hi] (the accepted levels),
  louder_than, louder_target (-1 on a comfortable list), predicted_min, best_final, lens_on, masking_needed,
  nontest_best_bone, mask_level, ghost_alpha, ghost_lurk, lists_done (this ear), confirm_needed (&"" / &"level" /
  &"unmasked"), confirm_wrong_setup, call_it_pending (&"" or the moment), call_it_word, call_it_chunk (the faint
  piece), started, done, coached, unprompted, confirmed_wrong, audible_stamp, loud_bubble, hoot_turn_text}`. Nothing
  in it is truth.

#### §9.13.4 `recommended_action()`

1. List done, or its list was already used this visit: `{action: &"none"}`.
2. A Call it is pending (the screen shows it): `{action: &"call_it", guess: <truth>, moment, word}`.
3. A word awaits its score: `&"score_correct"` / `&"score_missed"` from the truth.
4. The list has not started: when `db != textbook_target()`, `&"louder"` / `&"softer"` with `target_db`; then, if
   `masking_needed(db)` and the noise is off, `&"mask_toggle"`; then `&"present"`.
5. Otherwise `&"present"`.

`textbook_target()`: a louder list gives `SpeechRules.wrs_louder_level(comfy_db)` = `min(MAX_DB, comfy_db + 20)`,
where `comfy_db` is the level of the counted comfortable list named by `louder_than`. Otherwise it is
`SpeechRules.wrs_level(pta_for(ear))`. `recommended_start()` = `textbook_target()`.
`masking_needed(level)` = `speech_masking_needed(level, nontest_best_bone(ear), transducer)`. The UI-only
`lens_toggle` comes from `SpModeWord.beat_action()` (§9.19). `do()` handles `&"call_it"`.

#### §9.13.5 Hoot's TIPS (WRS)

`WrsTest.TIPS`, `MISSCORED_WRS` and `VERDICTS`, as built. Each line is 18 words or fewer with its `{tokens}` filled
at their longest. `{he}` and friends are `PatientProfile.say()` tokens; the mode fills `{db}` (the dial), `{mask}` /
`{naive}` (the capped noise and the uncapped rule) and `{Lens}` ("Nora-vision"); `{key:x}` is `_k()` (D10). (A5) The
level lines say "loud enough for every sound, never uncomfortable", not "comfortably loud".

| kind | line |
|---|---|
| `wrs_level` | "Word lists go loud enough for every sound: {his} PTA plus 35, never below 55." |
| `wrs_unmasked` | "This loud, words can cross to the other ear. Noise on before the list!" |
| `rollover_level` | "The louder list goes 20 dB above the comfy one, and never past 100." |
| `wrs_good_start` | "{db}: textbook! Loud enough for {him}, never uncomfortable, and noise in the good ear when needed." |
| `wrs_mask_ok` | "Noise in the other ear first. No ghost steals these words!" |
| `wrs_mask_capped` | "Noise {mask}, not {naive}: any louder and it could reach {his} test ear too." |
| `wrs_level_locked` | "One level per list. A word score belongs to a single level." |
| `wrs_noise_locked` | "The noise stays as it is for the whole list. Same set-up, every word." |
| `wrs_no_store` | "No store needed: the list scores itself after word 25." |
| `wrs_list_reused` | "A fresh list every time, or {he} starts learning the words." |
| `ghost_lurk` | "The Ghost is lurking! At this level the other ear can hear these words." |
| `ghost_word` | "The other ear answered that one. It can't count for this ear." |
| `audible_miss` | "{Lens} says every sound arrived. Yet the word came out wrong." |
| `boo` | "BOO! At {db}, words can cross to {his} other ear." |

`misscored` messages, by what she said (`MISSCORED_WRS`, keyed by her answer's kind or style; CHAPTER4 §11 quotes
this table):

| key | said | scored | line |
|---|---|---|---|
| `rhyme` | a foil | hit | "A rhyme is a miss. Only the exact word counts." |
| `other` | another list word | hit | "A different word is a miss. Score it as missed." |
| `silence` | silence | hit | "No answer is a miss. Score only what {he} said." |
| `trap` | a plural trap | hit | "'{said}' isn't '{word}'. Whole word, exactly: that's a miss." |
| `correct` | the word | miss | "{He} said it exactly! Score it as repeated." |
| `chatty_hit` | a chatty hit | miss | "{He} said '{word}' inside a sentence. The word is there: that's a hit." |
| `self_correct` | a self-correction | miss | "{He} settled on '{word}'. The final answer counts: a hit." |
| `ghost_word` | a ghost word | (no misscore: the line of a clean `speech_textbook`, scored right) | "Right score: {he} did say it. But the Ghost helped. Noise next time!" |

Verdict lines (`VERDICTS`: the message of `wrs_done`, `wrs_verdict` and the flag observations; held per D13). Rollover
is A2's index and the ear compare A3's critical difference, so "a little lower" and "points apart" never flag on
their own.

| key | when | line |
|---|---|---|
| `not_final` | a counted comfortable list, best not final yet | "{pct} percent: {band}. Is that {his} best?" |
| `as_predicted` | a counted comfortable list at or above the predicted minimum | "{pct} percent: {band}. About what {his} tones predict." |
| `rollover` | a counted louder list, rollover found | "{pct}%! Louder, and {he} got WORSE. That's rollover." |
| `louder_lower` | a counted louder list, lower but under the cut-off | "{pct}%: lower, but under the rollover cut-off. Not a flag on its own." |
| `louder_same` | a counted louder list, the same or better | "Louder didn't make it worse. No rollover here." |
| `redo_unmasked` | a comfortable list at the right level that does not count: the noise was needed and off | "{pct}%? The Ghost helped, so this list can't count. Noise on, fresh list." |
| `redo_level` | a comfortable list that does not count: the level was outside the window (`start_ok` false) | "{pct}%, but at the wrong level, so this list can't count. Fresh list, right level." |
| `redo_louder` | a louder list that does not count (not 15-25 above the comfy one, or unmasked) | "{pct}%, but not 20 dB louder, so this list can't count." |
| `best_ok` | `wrs_verdict`: the best just became final, at or above the minimum | "{His} best was {best} percent: about what {his} tones predict." |
| `below_predicted` | `wrs_verdict` and `wrs_below_predicted`: the best just became final, below the minimum | "{His} best was {best} percent. {His} tones predict at least {min}. A red flag." |
| `asymmetric` | `wrs_asymmetry` (and the verdict's second line): both bests final and `wrs_differ` | "Right {r}, left {l}: too far apart for chance. 25-word lists wobble, but not this much." |
| `rollover_found` | `rollover_found`: this list made the ear's rollover | "Most ears do better, or the same, when louder. Worse is a reason to look further." |

#### §9.13.6 Technique kinds (WRS)

Data always includes `{ear, slot, freq: -1, test: "wrs", db, list_id, list_n}`. Errors carry `message`.

| kind | type | when |
|---|---|---|
| `wrs_level` | error | first word of a comfortable list outside `wrs_level_ok` (expected, got, pta) |
| `rollover_level` | error | first word of a louder list outside `wrs_louder_ok` (expected, got, comfy_db) |
| `wrs_unmasked` | error | first word with noise needed and off (nontest_best, level) |
| `misscored` | error | a score differs from what she said (said, said_kind, rhyme, trap, style, scored) |
| `wrs_good_start` | clean | first word inside the window (a louder list: inside 15-25 dB above) |
| `wrs_mask_ok` | clean | first word with noise needed and on |
| `speech_textbook` | clean | a score that matches what she said |
| `wrs_done` | observation | list finished (pct, band, counts, right, words, points) with its verdict line (§9.13.5) |
| `wrs_verdict` | observation | the ear's best became final (best, predicted_min, below_predicted, asymmetric, diff) with its lines |
| `wrs_below_predicted`, `wrs_asymmetry`, `rollover_found` | observation | when the flag fires on a final best (with the numbers) |
| `wrs_mask_capped` | observation | the noise level was clamped by D16 (mask, naive; once per list) |
| `ghost_lurk`, `ghost_word`, `audible_miss`, `cross_heard_speech`, `boo` | observation | lessons (once per list; `cross_heard_speech` once per ear) |
| `wrs_level_locked`, `wrs_noise_locked`, `wrs_no_store`, `wrs_list_reused`, `score_first` | observation | refused actions (once per list) |
| `call_it` | observation | a Call it answer (word, guess, outcome, moment; unscored) |
| `aside` | observation | a patient's trigger aside was shown (text, why; once per visit, raised by `SpModeWord`, D28) |
| `birdie`, `par`, `bogey`, ... | observation | the list's golf (player lists only) |

Points (`WrsTest.POINTS`): `speech_textbook` 10, `wrs_good_start` 10, `wrs_mask_ok` 20, `wrs_done` 50 (player lists
only), times the combo multiplier. Golf points as `GOLF_POINTS`.

### §9.14 SpeechSession mode "sin" (`core/speech/modes/sin_test.gd`, P)

#### §9.14.1 One list per `start_test`; conditions and slots

`start_test(patient, "both", coached, plan)` with `plan.test = "sin"` (or an ear, for a per-ear unaided test).
- `plan.condition`: `"unaided"` (default), `"omni"` or `"directional"`. `sim.condition` follows it.
- **Slot** = `SpeechRules.sin_slot(condition, ear)`: unaided "both" gives `"both"`, an unaided ear gives that ear, omni
  gives `"aided_omni"`, and directional gives `"aided_directional"`.
- `transducer`: "phones" or "inserts" unaided, "soundfield" aided (the default for omni and directional).
- **Aided level** (D21): omni and directional default to `level = SIN_AIDED_DB` (50) with `level_by_hoot = true`.
- `measure_key()` = `"sin:<slot>:<list_id>"`. A list in `used_lists` is refused (`sin_list_reused`).
- **The practice sentence** (`plan.practice = "party_practice"`): before sentence 1, Hoot plays it at `hoot_speed` 1
  at `SIN_PRACTICE_SNR` 25, ticks the chips and locks in. It is never scored or stored and never fills a plate. It
  then hands back. The level locks at the practice (it plays at the list's talker level). As built the coach asks
  for the talker level first and the practice second (§9.14.4), so the practice plays at the level the player set.

#### §9.14.2 Plan keys

| Key | Type / default | Meaning |
|---|---|---|
| `test` | "sin" | PARTY mode |
| `tones` | §5.1 results | required (the better ear's PTA gives the talker level) |
| `list` | `party_1` | the list id |
| `condition` | "unaided" | §9.14.1 |
| `transducer` | by condition | §9.14.1 |
| `level` | unaided: snap5(PTA of "both"); aided: `SIN_AIDED_DB` | where the talker dial starts |
| `level_by_hoot` | aided: true | the dial is set by Hoot and locked from the start; no `sin_level` check and no tee bonus; as built the start chip reads "AIDED: 50 dB, set by Hoot" (unaided: "TALKER: {n} dB, set by Hoot") and the big caption stays "TALKER" |
| `programme` | "" | "A" / "B": the blind-tasting label on the LCD condition chip ("PROGRAMME A" until the screen's `revealed`, then "A: OMNI") and the plates |
| `practice` | "" | the practice list id (§9.14.1) |
| `hoot_only` | false | Hoot runs the whole list whatever quick visit says (D24) |
| `hoot_first` | 0 | Hoot runs sentences 1..n at x8, then hands back; gate `hoot_only or quick_visit` |
| `level_first` | false | with `hoot_first`: Hoot's turn starts at the player's first PRESENT, so the player sets the talker first |
| `hoot_turn_after` | missing | player sentences before Hoot finishes the list; 0 = Hoot runs it all; same gate |
| `hoot_speed` | 8 | Hoot's time scale |
| `hide_loss` | false | the SNR loss stays blank on screen until the story's bill beat reveals it |
| `compare_to` | "" | the slot this condition is compared with (`"aided_omni"` for FOCUS) |
| `benefit_lines` | {} | (as built) `{real, small, none}` lines that replace `BENEFIT_LINES` for another compare |
| `lost_lines` | [] | his noise-wins lines |
| `lens` | false | the lens on the key-word chips (D7) |
| `intro`, `hoot_turn_text`, `done_title` | "" | screen texts |
| `revealed` | false | (as built; the screen's) the blind tasting is over: the condition chip names the programme ("B: FOCUS") and the booth draws FOCUS's bright front half |

#### §9.14.3 State and controls

- `present()`: refused while a sentence waits for LOCK IN (observes `lock_first`) or when the list is done. The first
  presentation (practice included) locks the level. As built, the level check (§9.14.6) waits for the player's
  first scored sentence on a list whose level is the player's (`level_mine`: not `level_by_hoot`, not an off-screen
  run), because Hoot may play the practice, or the first courses (`hoot_first` with `level_first`), at the level the
  player set; the check judges the level the list locked at.
  Sentence n plays at `snr = SIN_SNRS[n - 1]` with `babble_db = sin_babble_level(db, snr) = db - snr`. Then
  `respond_sin(snr, item, db, ear, {lost_lines})` gives the trial `{n, list_n, list_id, slot, item_id, text,
  key_words, snr, babble_db, said, said_words, heard[5], traps[5], marks: [null x 5], count, expected, kind,
  little_swap, by_hoot, delay_s, practice, locked: false}`, and `focus_key` = 0. As built the trial also carries
  `condition`, `db`, `word` (the sentence text, for the shared seams) and `said_kinds[5]`.
- **Marks** (the chips; `marks[i]` is null = blank, true = got, false = missed):
  - `score(correct)` (the walk: Right / Left) sets `marks[focus] = correct`. Focus then moves to the next blank chip
    after it (wrapping), or -1 when none is blank.
  - `act(&"flip_key", {key: i})` (keys 1-5, a chip click): blank or missed becomes got, and got becomes missed. Focus
    moves to `i`.
  - `act(&"mark_key", {key: i, got})` (a right-click is `got: false`): sets that chip; focus moves on as for the walk.
  - `act(&"all_got")`: all 5 become got; focus -1.
  - `act(&"focus_key", {key: i})`: moves the highlight without marking.
  - `act(&"prompt")` (as built): a set-up hint was shown before the first sentence, so the list earns no tee bonus
    (returns `{unprompted: false}`, or {} once the level is locked). Day 5's screen never calls it: a coached list
    never earns the bonus anyway.
  - `store()` = `act(&"lock")`: blanks become missed (false). Then each chip is checked against `heard`: a match is
    `speech_textbook`, a mismatch is `misscored`, and all 5 right adds `sin_lock_ok`. Hoot's marks are the truth and
    are not scored. Sentence 6 locked finishes the list (§9.15.2). The return is the locked trial plus `{count_billed,
    list_done}`.
  - Marks cannot change after LOCK IN.
- `do(action, rec)` runs `key_got`, `key_missed`, `key_fix`, `all_got` and `lock` for `run_by_textbook`.
- `state()` (`get_state().sin`, CHAPTER5 §12): `{condition, condition_title, programme, slot, list_id, list_title,
  list_n, sentence_n, snr, babble_db, talker_db, level_by_hoot, course, courses: [{n, snr, course, count (billed),
  by_hoot}], key_words, marks, focus_key, total_so_far, lists: [{list_id, total, snr_loss}], avg_loss (-1 or
  hidden), band (or &"" when hidden or aided), level_locked, practice_pending, awaiting_lock}`. `heard` is never in
  it. As built it adds `sentences` (6), `target_db` (`textbook_target()`), `text` (the card's sentence), `loss_hidden`,
  `practice` (the card holds the practice), `done`, `reused`, `aided`, `label`, `transducer`, `compare_to`, `lens`
  and `slips`; a course also has `locked`. `level_locked` is `not can_set_level()` (true from the start with
  `level_by_hoot`).

#### §9.14.4 `recommended_action()`

1. List done (or a reused list): `&"none"`.
2. A sentence awaits LOCK IN (once its answer is shown):
   - a marked chip that differs from the truth: `{action: &"key_fix", key: k}` (k = 1..5, the first one);
   - else, when `focus_key >= 0`: `&"key_got"` / `&"key_missed"` from `heard[focus]`;
   - else `&"lock"`.
3. (As built, the level comes before the practice.) The list has not started, the level can be set, and `db !=
   textbook_target()` (= `sin_level(pta_for("both"))`, or the ear's PTA per ear; aided `SIN_AIDED_DB`):
   `&"louder"` / `&"softer"` with `target_db`. On the screen Hoot never moves a level the player owns: during his
   own turn with `level_first` or a pending practice he skips this step; off-screen he sets his own.
4. `&"present"` (with the practice pending, the screen starts Hoot's practice turn).

Inputs: `key_got` -> `speech_correct`, `key_missed` -> `speech_incorrect`, `key_fix` -> `party_word_<k>`, `lock` ->
`store`, `present` -> `present_tone`, `louder` / `softer` as now. `masking_needed()` is false (the same mix goes to
both ears, or speakers); `can_mask()` is false, `mask_level()` is -1 and the MASK button hides. A refused M
(`on_mask_refused`) observes `sin_no_mask`; a refused level key (`on_level_refused`) observes `sin_aided_level` on
an aided list Hoot set, else `sin_level_locked`.

#### §9.14.5 Hoot's TIPS (SIN)

| kind | line |
|---|---|
| `sin_level` | "Party test: talker at {target} dB HL. The party levels follow by themselves." |
| `sin_good_level` | "Talker at {target}: just right. The party steps up by itself." |
| `sin_aided_level` | "Aided tests go at a chatting level: {aided}. The aids add their own boost." ({aided} = `SIN_AIDED_DB`) |
| `sin_level_locked` | "The talker stays at one level for the whole list." |
| `sin_no_mask` | "Both ears hear the same mix, so there's nothing to mask." |
| `lock_first` | "Lock in that sentence first: {key:store}. Then play the next one." |
| `blanks` | "Unticked key words count as missed when you lock in." |
| `little_words` | "Little words don't count, either way. Only the five key words." |
| `noise_won` | "Zero gap: the party is as loud as the talker. Score what {he} said." |
| `chef_kiss` | "Every key word scored as {he} said it. Chef's kiss!" |
| `sin_list_reused` | "Fresh lists every time, or {he} learns the sentences." |
| `practice` | "A practice sentence first. I'll score it; you watch the chips." |
| `sin_done` | "List done: {total} key words. SNR loss {loss} dB." |
| `sin_done_hidden` (with `hide_loss`) | "List done: {total} key words." |
| `misscored` (generic) | "Score what {he} SAID: only the exact key words count." |
| `sin_benefit` (real) | "Programme B was FOCUS: {benefit} dB better, two lists each. Real, not luck." |
| `sin_benefit` (small) | "Programme B was FOCUS: {benefit} dB better. Under {crit}, that could be luck." |
| `sin_benefit` (none: 0 dB or less) | "Programme B was FOCUS: no better this time. Run another list each." |
| coach: lock (keys) | "Happy with the ticks? Lock it in: {key:store}." |
| coach: lock (mouse) | "Click each key word {he} got, then LOCK IN. Unticked words count as missed." |
| coach: walk | "{key:speech_correct} if {he} got it, {key:speech_incorrect} if {he} missed it. Or click the chips." |

The coach picks the mouse line when the player's last input was a mouse click (`screen.clock()` keeps the last
device). `sin_benefit` lines are written for a FOCUS-vs-OMNI compare (`SinTest.BENEFIT_LINES`); a plan with another
`compare_to` passes its own `benefit_lines`. The coach lines are `SinTest.COACH_LINES`. As built, the rest of the
coach (the level, the practice, the first sentence, "Tick the key words...", the key fix, the Main course and Day 3's
waiting line) lives in `sp_mode_party.gd`'s `COACH_*` constants (CHAPTER5 §5.4 and §9).

`misscored` messages, one per wrong chip (`MISSCORED_SIN`):

| what he said for that key word | line |
|---|---|
| a mishear, ticked | "{He} said '{said}'. Close isn't correct!" |
| a trap, ticked | "'{said}' isn't '{word}'. Word endings must match, plurals and tenses too." (as built: a trap is any changed ending, §9.11.2) |
| a filler or nothing, ticked | "{He} didn't say '{word}'. Untick it: only exact words count." |
| the word, missed | "{He} did say '{word}'! Tick it." |

#### §9.14.6 Technique kinds (SIN)

Data always includes `{ear: slot, slot, freq: -1, test: "sin", db, condition, list_id, list_n, sentence_n}`.

| kind | type | when |
|---|---|---|
| `sin_level` | error | the player's first scored sentence of a list whose level is theirs plays off the target (target, got, pta); never with `level_by_hoot` |
| `misscored` | error | one per wrong chip at LOCK IN (key, word, said, said_kind, marked) |
| `sin_good_level` | clean | that sentence at the target |
| `speech_textbook` | clean | one per right chip at LOCK IN |
| `sin_lock_ok` | clean | all 5 chips right at LOCK IN |
| `lock_first`, `sin_level_locked`, `sin_list_reused` | observation | refused actions (once per list) |
| `sin_aided_level` | observation | (as built) a level key on an aided list Hoot set (once per list) |
| `sin_no_mask` | observation | (as built) a refused M, or the screen just after the coached unaided list's intro (once per visit) |
| `blanks` | observation | the first LOCK IN with a blank chip (once per visit) |
| `little_words` | observation | the first answer with a little-word swap (once per visit) |
| `noise_won` | observation | the first sentence at SNR 0 (once per visit) |
| `practice_done` | observation | the practice sentence is locked |
| `sin_done` | observation | list finished (total, snr_loss; band hidden when `hide_loss` or aided) |
| `chef_kiss` | observation | a list (or the player's part of it) with no slips; only with player sentences |
| `birdie` | observation | (as built) a player list's golf is a birdie; other golf names are points only (the screen's callout names them) |
| `sin_benefit` | observation | the `compare_to` condition finished its second list (benefit, crit, real, compared_to; the real / small / none line) |
| `party_aside` | observation | (as built; the screen's) Marco's aside on the first player answer of programme A (`line`; once per visit) |

Points (`SinTest.POINTS`): `speech_textbook` 10, `sin_good_level` 10, `sin_lock_ok` 20, `chef_kiss` 100, golf par 50.

### §9.15 Results, sheets and scoring (§9.5 extended)

#### §9.15.1 WRS sheet: `speech.wrs.<ear>`

As built (`WrsTest._sheet` and `_list_record`). The ear's sheet gathers every list on that ear (comfortable, redo,
louder), and both ears' sheets are recomputed after each list, because the compare reads both.

```
sheet (WRS) = {ear, slot: ear, test: "wrs", list_id (the newest list's),
  pct (the counted comfortable list; -1 none), level_db (that list's; else the newest comfortable list's; a louder
  list never sets it), band, pta, pta_method, recommended_level (wrs_level of the measured PTA),
  pb_max (best counted list, -1 none), pb_min (A2: wrs_rollover's, -1 none), best_final,
  predicted_min (A1: roundi(wrs_predicted_min_interp(pta))), below_predicted (pb_max < predicted_min, once best_final),
  predicted_max (predicted_wrs_max on the measured octaves),
  louder_pct, louder_level_db, rollover_drop (comfy pct - louder pct; information only),
  rollover_index (A2), rollover (A2: index >= 0.45, once best_final),
  other_pct (the other ear's pb_max), diff_pct (-1 until both), asymmetric (A3: wrs_differ on the two bests, both final),
  stored_db (= level_db), true_db (= wrs_level of the TRUE PTA), error_db (= stored_db - true_db),
  units (counted player lists), strokes, par (both = the player's words, D3),
  golf_strokes, golf_par, golf (of the newest player list), holes [{list_id, golf}], accuracy (all player words),
  misscored, clean, errors [kinds], coached (the newest list's), by_hoot (units == 0), seq (the first list's),
  masked, mask_db (the newest list's), transducer, words (every word presented on this ear),
  lists: [list...]}
list = {n (its place in the visit's play order), list_id, list_title, seq, level_db, mask_db, mask_capped, masked,
  masking_needed, start_ok, textbook_start, unprompted (no confirm chip, no BOO, no coach line before the first word),
  louder_than, louder_ok, comfy_db (a louder list's comfortable level; -1 otherwise), counts, confirmed_wrong,
  redone_by (only on a list a later redo replaced: that list's n), words: 25,
  right (the marks: the player's for the player's words, the truth for Hoot's), pct, band,
  true_right, true_pct, expected_pct (roundi(p_total x 100)), deal {k_test, k_total, jitter, p_test, p_cross},
  player_words, hoot_words, matches, misscored, accuracy, slips, tee_bonus, golf_strokes, golf_par, golf,
  ghost_words, audible_misses, call_its [{word, guess, outcome, moment}], by_hoot, coached, errors [kinds],
  trials [{n, item_id, word, said, kind, rhyme, trap, style, correct, scored, heard_by, audible, by_hoot, delay_s}]}
```

- `counts` = `start_ok and (masked or not masking_needed) and louder_ok` (`start_ok` is `wrs_level_ok` on a
  comfortable list, `louder_ok` on a louder one), and false once a later list names it in `redo_of` (that list
  then carries `redone_by`; the redo may name a list on either ear). Only counted lists set `pct`, `pb_max`,
  `louder_pct` and the flags.
- `pct = SpeechRules.wrs_pct(right, 25)` (`roundi(right x 4)`). The pct is what the player scored, as a clinic writes
  down what the clinician scored. `true_pct` and `trials[].correct` / `kind` / `heard_by` are truth, for the reveal and
  for checks only.
- **Best final** (D13): the ear has a counted louder list, or its counted comfortable list is at or above the
  predicted minimum. The verdicts, `below_predicted`, `rollover` and the compare wait for it.
- (A1) `predicted_min` reads `WRS_PREDICTED_MIN_25` (D14): Nora's measured left PTA of 40 gives 60, so her 52 is
  below it; a PTA of 41.7 gives 58.
- (A2) `rollover` is the rollover index of D15 over the counted lists: PBmin is the lowest score at a level above the
  PBmax list's, so a softer list never makes rollover, and one list never does.
- (A3) `asymmetric` uses `wrs_differ` with each best's word count (25 here): a difference counts only when it is
  outside what chance alone gives (the critical difference at z 1.96). `diff_pct` is the plain difference, for the
  lines.
- **Golf** (D19; each player list is a hole, CHAPTER4 §9): `golf_par = player_words`;
  `slips = misscored + (LIST_CONFIRM_SLIP 3 if confirmed_wrong)`; `tee_bonus = LIST_TEE_BONUS 2` only when the list
  is solo (not coached), `textbook_start`, `masked == masking_needed` at the first PRESENT, `unprompted`, and not
  `confirmed_wrong`; `golf_strokes = golf_par + slips - tee_bonus`; `golf = ClinicRules.fair_golf(golf_strokes,
  golf_par, slips == 0)`. A perfect solo list is a birdie, a clean coached list is par, and WRS has no eagles. A list
  with no player words has `golf: &"hoot"`.
- **Accuracy** = `matches / player_words` (set-up errors go to technique). **Efficiency** = 1.0 (D3).
- **Flags** (D13-D15): `below_predicted`, `asymmetric` and `rollover` as above; each is false until the best is final.
- `units` = counted lists with player words on this ear (a redone list and a Hoot-only list count 0).

#### §9.15.2 SIN sheet: `speech.sin.<slot>` (CHAPTER5 §8.1, made exact)

```
sheet (SIN) = {ear: "both" (or the ear), slot, test: "sin", condition, condition_title, programme, transducer,
  level_db, aided (bool), label ("unaided, phones" / "aided, sound field"),
  lists: [{n, list_id, list_title, seq, condition, programme, level_db, total, snr_loss, true_total,
           player_sentences, hoot_sentences, key_words, matches, slips, accuracy, by_hoot, coached,
           level_by_hoot, level_mine, start_ok, unprompted, tee_bonus, golf_strokes, golf_par, golf, errors,
           sentences: [{n, item_id, snr, babble_db, said, said_words, heard[5], marks[5], count (billed),
                        true_count, expected, kind, little_swap, by_hoot, delay_s}]}],
  lists_done, snr_loss (sin_average of the lists' losses; -1 before one list),
  band, band_name, remedy                                       # unaided only; &"" / "" on aided sheets (D21)
  true_loss (sim.effective_snr_loss), true_band, estimated_loss (estimated_snr_loss, better ear, measured),
  stored_db = roundi(snr_loss), true_db = roundi(true_loss), error_db = |snr_loss - true_loss|,
  key_words (player-judged), misscored, accuracy, units (lists with player sentences),
  strokes, par (both = the player's sentences, D3), golf_strokes, golf_par, golf (newest player list),
  holes [{list_id, golf}], forks, clean, errors, by_hoot, coached, seq,
  benefit_db, compared_to, compared_lists, crit_diff_db, real_change
                       # as built: when plan.compare_to is set and that slot has one list or more}
```

- `total` = the sum of the billed marks (the player's for the player's sentences, the truth for Hoot's), and
  `snr_loss = SIN_CONSTANT - total`. The constant comes from the Spearman-Kärber estimate over the six steps:
  SNR-50 = 25 (the top step) + 5 / 2 (half a step) - total (one key word = 5 dB / 5 words = 1 dB) = 27.5 - total; SNR
  loss = SNR-50 - `SIN_NORMAL_SNR50_DB` 2 = 25.5 - total. Equivalently, SNR loss = key words missed - 4.5.
- **Golf** (D19): each player list is a hole; `golf_par` = the player's sentences; `slips` = misscored chips;
  `tee_bonus = LIST_TEE_BONUS` only on a solo list (not coached) whose level the player set (`level_mine`, never
  with `level_by_hoot`), at the textbook level (`start_ok`), unprompted (no `act(&"prompt")`);
  `golf_strokes = golf_par + slips - tee_bonus`; `golf = fair_golf(golf_strokes, golf_par, slips == 0)`. One slip is
  still par, 2-3 are a bogey, 4-5 a double bogey. `forks = sin_forks(condition slips)`: 3 with no slips, 2 for one,
  1 for 2-3, 0 for 4 or more. With no player sentences: `golf: &"hoot"`, `forks: -1`.
- `band = sin_band(snr_loss)`, `band_name = SIN_BAND_NAMES[band]`, `remedy = SIN_REMEDIES[band]` on unaided sheets
  only. Aided sheets keep `band: &""`, `band_name: ""` and `remedy: ""`: the bands are unaided earphone norms (D21).
- `benefit_db = <compare_to>.snr_loss - snr_loss`; `compared_lists = min(lists_done)`; `crit_diff_db =
  sin_crit_diff(compared_lists)` (3.9 for 1, 2.7 for 2 lists); `real_change = sin_real_change(benefit_db,
  compared_lists)`. As built these land as soon as the compared slot has one list (a provisional difference); the
  `sin_benefit` line waits for `compared_lists >= SIN_LISTS_PER_CONDITION` (2).
- A list's `accuracy` = `matches / key_words` (the player's chips); `true_total` and a sentence's `true_count`,
  `heard` and `expected` are truth (checks and the reveal only). `errors` are the session's slips so far.

#### §9.15.3 Visit results

- `speech.tests` lists every test with a sheet, in `SpeechRules.TESTS` order. `scored_sheets` = the sum of `units`.
- `speech.wrs_summary` (`WrsTest.summarize`): `{best: {right, left} (-1 none), final: {right, left}, diff (-1 until
  both), asymmetric (A3), below_predicted: {right, left}, rollover: {ear, comfy_pct, louder_pct, drop, index, flag},
  flags: Array[StringName] (&"asymmetric", &"below_predicted", &"below_predicted_both", &"rollover"), referral}`.
  `referral = SpeechRules.wrs_referral(asymmetric, below_r, below_l, rollover)`: `&"refer"` when asymmetric, or
  rollover, or below predicted in exactly one ear; else `&""` (both ears below alone adds `&"below_predicted_both"`;
  open question 8). It is never `&"today"`: word scores alone never send a patient to a doctor today
  (`CaseRules.DECISIONS`).
- `speech.sin_summary` (`SinTest.summarize`): `{unaided: {slot, snr_loss, lists, label, band, band_name, remedy},
  ears: {right, left} (as built: per-ear unaided sheets, same brief), omni: {slot, snr_loss, lists, label},
  directional: {slot, snr_loss, lists, label}, benefit_db, crit_diff_db, real_change, benefit_unsure (compared, not
  real), estimated_loss, lists_used: [list ids in play order]}`. Missing conditions are left out. As built it reads
  whole party sheets only (a stand-in sheet from another test is skipped, so it adds no summary), and with per-ear
  sheets only, the better (lower) ear stands for `unaided`.
- `merge_results` is unchanged (a unit weighs `SHEET_WEIGHT` 3 tone stamps).

### §9.16 SpeechVoice: party babble and SNR (P, `core/speech/speech_voice.gd`, additive)

```gdscript
const BABBLE_TRIM_DB := -5.0          # dial dB: puts babble on the words' RMS mapping (below)
const BABBLE_LEAD_S := 0.6            # the party starts this long before the talker
const BABBLE_TAIL_S := 0.3
func play_item(ear: String, list_id: String, it: Dictionary, hl: float) -> float # ear "both" = both channels (signature unchanged)
func start_babble(ear: String, babble_db: int) -> void    # "right" / "left" / "both"
func set_babble(babble_db: int) -> void
func stop_babble() -> void
func is_babbling() -> bool
func babble_ready() -> bool
static func babble_rms(babble_db: int) -> float
```

- **The sound, cheaply.** `SpeechBabble.loop()` (`core/speech/speech_babble.gd`, P) builds an 8 s loop from
  `SpeechVoice`'s cached murmur syllables: four talkers made by resampling them at 4 pitch ratios (`TALKER_F0_HZ`
  105, 130, 190 and 225 Hz relative to the murmur f0; `SOURCE_SYLLABLES` 3), each with its own seeded start,
  syllable order, pauses and loudness (seed 7), summed, wrapped so the loop has no seam, and normalised to unit RMS
  with peaks capped near `CREST` 4.0 times the RMS (about 12 dB). No sine synthesis per sample. As built the loop is
  built synchronously and cached: `level_marco.gd` calls `SpeechBabble.loop()` in `_ready` (before the movie), so
  the first PRESENT never hitches; no `WorkerThreadPool` was needed. `babble_ready()` says whether it is built. A
  test builds it in under 400 ms headless.
  When `res://assets/speech/babble/babble.wav` exists, it is used instead (through `wav_to_mono`, normalised the same
  way).
- **Level**: `babble_rms(db) = AudioSafety.masker_to_rms(db + BABBLE_TRIM_DB)`. Words use `speech_to_rms(hl)`, and
  `masker_to_rms(x)` equals it at `x = hl - 5` ((-9 - -6) / 0.6), so a 0 dB SNR plays the party at the talker's RMS.
  Both stay under their ceilings (`MASKER_CEILING_DBFS` -24, `SPEECH_CEILING_DBFS` -27). Note: the shared 0.6 dB per
  dial dB mapping makes a 25 dB dial SNR about a 15 dB audible gap. That is fine because nothing depends on audio;
  no line may say "hear the gap".
- **Same safety path as the masker**: every babble sample goes through `clamp_masker_sample()`, and every output
  sample (babble plus the word) through `clamp_sample()`. Nothing can pass the -12 dBFS peak.
- **"both" is a deliberate change.** Today `play_item` sets `var right_w := ear == "right"`, so "both" would play the
  left channel only. The new branch writes both channels for "both" (and the sound field); "right" and "left" are
  unchanged, and Day 3 never passes "both". A test covers all three.
- **Mixing** in `render(frames)`: for each channel in the test ear(s), `out = clamp_sample(clamp_masker_sample(babble)
  + word)`. The speech-noise masker (WRS) keeps its own channel as now; the two never play together (PARTY mode has
  no MASK).
- **Timing** is the PARTY mode's job (H5): `start_babble(ears, babble_db)` at PRESENT, the talker after
  `BABBLE_LEAD_S`, and `stop_babble()` `BABBLE_TAIL_S` after the sentence ends, at LOCK IN, on stored, on exit and on
  pause. As built the babble fades in and out over `NOISE_RAMP_S` (0.05 s), and `SpeechVoice` itself cuts it at once,
  with no fade, on `NOTIFICATION_PAUSED` and when it leaves the tree. During Hoot's x8 turns `SpModeParty` keeps both
  the murmur and the babble silent (it knows `screen.hoot_running()`); his practice turn, at speed 1, is audible. The
  lamps still light. `SpeechVoice` never reads `Engine.time_scale`.

### §9.17 SPEECH screen: WORD mode (`ui/speech/modes/sp_mode_word.gd`, W)

#### §9.17.1 Layout and widgets

Widgets appear as they become useful (CHAPTER4 §5.1). Their reveal state lives in `screen.memory`.

| Area | WORD mode |
|---|---|
| LCD (`lcd_view`) | `test_chip` "WORDS"; `info_line` "Word list 2 · word 9 of 25 · 52% so far"; `start_chip`, the level chip by the dial (it follows the dial): "PTA 40 + 35 = 75 · min 55", on a louder list "LOUDER = COMFY 75 + 20 = 95"; `aux`, the NOISE sum: on a coached list "75 - 40 = 35 >= 10:" with "NOISE!" (then "NOISE ON"; "NO NOISE" when none is needed), on a solo list only the rule and the other ear's number, "NOISE? LEVEL - 40 vs RIGHT BEST:" with "10", never the answer; the NOISE box as now, with the capped level |
| Middle (`mid`) | `SpScoreStrip` (left) from the first list; `SpBanana` (right) slides in at the first lens press |
| Card | `SpWordCard`: "LIST SAYS:" and the word, crisp at full size, always; with the lens on, a second row "REACHES HER (55 dB):" drawn by `word_drawer`, which turns into "SHE SAID:" on a miss |
| Meter slot | the SRT ladder, meter, tally and STORE are hidden (`hidden_base_widgets`); `SpEarCompare` once both ears have a counted list: R/L bars, each with the band of scores chance alone could give (`wrs_same_range`, A3), and the verdict once both bests are final |
| Deck | LEVEL + WORD (SOFTER, PRESENT, LOUDER) . SCORE THE WHOLE WORD (MISSED, REPEATED) . "<NAME>-VISION" (LENS) . NOISE (MASK). No STORE. |
| Dance | [EACH WORD 25 x 4%] [WHOLE WORD ONLY] [COMFY PTA + 35]; a louder list: [LOUDER COMFY + 20] |
| Booth window | `SpGhost` over `booth.glass_rect()` (lurk on coached lists; BOO on solo lists) |
| Overlay | the Call it card (§9.17.5) |

- **`SpScoreStrip`** (`ui/speech/sp_score_strip.gd`): 5 x 5 tiles in list order. Ticks are mint with a tick symbol,
  crosses are coral with a cross symbol, and Hoot's tiles are brown. A miss tile shows what she said in small type.
  - The running line: "13 right x 4% = 52%".
  - **The band ruler** (ticks at 90 / 78 / 66 / 54 with `WRS_BAND_TITLES`, and a sunny tick at `predicted_min` once
    the best is final) appears after the first list is done. There is no live pace marker.
  - At the end of a list the band chip lands. The louder list's slide (CHAPTER4 §12) appears when its data exists.
- **`SpBanana`** (`ui/speech/sp_banana.gd`, CHAPTER4 §5.2): the MEASURED thresholds of the test ear, the curtain, and
  the `SOUND_CUES` letters at (cue frequency, dial + offset), faded behind the curtain by `lens_alpha`. There is a
  CHAT 50 tick. Once the best is final: the "tones predict at least {min}" bar; after the louder list: the slide.
- **`SpGhost`** (`ui/speech/sp_ghost.gd`): on coached lists with `ghost_lurk`, alpha `SpeechRules.ghost_alpha(level,
  transducer, nontest_best_bone) = clamp(0.2 + (level - SPEECH_IA_DB[transducer] - nontest_best_bone) / 25, 0.2, 1)`
  while masking is needed and off, else 0; so it shows faintly from the first level that needs noise (50 on Nora's
  left) and is bold by 70. On solo lists it does not lurk: it pops ("BOO!") with the confirm chip on an unmasked
  PRESENT (§9.17.4). M blows it away with "GHOST BUSTED!" (`fx.ghost`). A `ghost_word` answer gets the ghost bubble
  style.

#### §9.17.2 The lens ("<SHORT NAME>-VISION"): V or `speech_lens_button`

- The label is `PatientProfile.short_name` in capitals plus "-VISION" (NORA-VISION); lines use it as `{Lens}`
  ("Nora-vision"). The glyph is EYE.
- **Input**: `toggle_lens` (V) or the button. It is allowed at any time except during a movie or the pause menu
  (including Hoot's turn: it is only a view). It writes `screen.memory["lens_on"]`, emits
  `Events.speech_lens_toggled(ear, on)` and refreshes. The first press also slides in the Banana Board.
- **What it draws** (`word_drawer`, the second row only; the word above is never faded): each `chunk` of the next
  word at `alpha = SpeechRules.lens_alpha(margin)` = `lerp(1.0, LENS_MIN_ALPHA 0.15, clamp(-margin / LENS_FADE_DB 15,
  0, 1))`, with a dotted outline when `margin < 0` and a dotted underline when `0 <= margin < 3` ("only just").
  Silent chunks are drawn in plain ink. `margin = SpeechRules.sound_margin(sound, dial,
  session.measured_thresholds(ear))`, which uses `SOUND_CUES` and `interp_threshold`, so the lens matches
  `predicted_wrs_max`.
  - It never reads the true thresholds: a test swaps the profile's truth and keeps the tone results, and the lens must
    not change.
  - A word without `chunks` falls back to `SpeechRules.chunk_sounds(item)` (a letter guess).
- On a miss, the lens row's letters scramble into what she said (0.6 s; a crossfade with reduced motion), and its
  label turns into "SHE SAID:".
- **"AUDIBLE, BUT MISSED."** With `audible_stamp`, when a trial with `audible` true is missed (by the truth, shown after
  it is scored), a stamp lands on the card. It shows once per list, with the `audible_miss` tip.
- PARTY mode with `plan.lens`: the same alpha on each key-word chip, at the talker level, against the per-frequency
  minimum of the two ears. It is off on Day 5.

#### §9.17.3 One word, start to finish

PRESENT (Space / button) plays the word: the card glows NOW SAYING, then thinking dots, then her answer in the bubble
(the loud style on a louder list; the aside, if any, as a Hoot side bubble). REPEATED (`speech_correct`, Right / + /
=) or MISSED (`speech_incorrect`, Left / -) scores it, and the tile flips. After word 25 the list ends itself: the
strip flashes, the band chip lands, then `celebrate` at 1.2 s and the finish at 4.0 s (`complete_list`). Level and
NOISE lock after the first word; a press shows the chip "One level per list" (`wrs_level_locked`) or "Same noise,
every word" (`wrs_noise_locked`).

#### §9.17.4 The two-press confirm (solo lists only)

The first PRESENT of a list with `confirm_wrong_setup` and a wrong set-up (`state().confirm_needed` is `&"level"` or
`&"unmasked"`) does not present. It shows a chip for `SpModeWord.CONFIRM_S` (4 s) and tells the mode
(`act(&"confirm_chip", {why})`):
- level: "Loud enough for every sound: PTA + 35 = {target}." with the second line "{key:present_tone} again: test at
  {db} anyway." (a louder list: "The louder list goes 20 above the comfy one: {target}.") (A5)
- unmasked: the Ghost pops out of the booth window, and the chip reads "BOO! At {db}, words can cross to {his} other
  ear." with the second line "{key:toggle_mask}: noise on. {key:present_tone} again: test without it." The `boo`
  observation fires.

A second PRESENT within 4 s presents. The list then records `confirmed_wrong`, and the session's errors fire as usual;
with `confirmed_wrong_hoot_after`, Hoot takes over after that many player words. Coached lists have no "anyway":
PRESENT is denied (`deny`) with the matching tip for `DENY_S` (4 s), and the coach repeats the step. `get_state().
confirm_pending` is true while the chip is up. Any other chip or coach line before the first word clears `unprompted`
(`act(&"prompted")`).

#### §9.17.5 Call it (`call_it`)

An overlay card on the SPEECH screen at the idle point before a chosen word's PRESENT (the deal is known by then;
place 1 is never chosen). Unscored; it never changes the deal.
- `&"faint_hit"`: the first player word, with the lens on, whose lens row has a chunk below 0 dB and that is dealt a
  test hit. Prompt: "{Lens} shows a faint '{chunk}'. Will {he} get '{word}'?" After the answer: "{He} got it! One
  faint letter, and {his} brain filled the gap."
- `&"audible_miss"`: the deal's `audible_target`. Prompt: "Every sound of '{word}' reaches {him}. Will {he} get it?"
  After the answer: the stamp and the `audible_miss` tip.
- Options: "{He}'ll get it" (`speech_correct`, Right; button `call_it_yes_button`) and "{He}'ll miss it"
  (`speech_incorrect`, Left; `call_it_no_button`). The beat `call_it` carries `{word, prompt, options ([{id, label,
  input, guess}] x 2), best, mouse: {click: <the best button>}}`; its solver sends the best input. The answer goes to
  the list's `call_its`.

#### §9.17.6 The chat demo and the asides (D28)

- **`chat_demo`** (List 2): at `enter`, before any beat, the mode runs a Hoot turn at speed 1. The dial parks at the
  demo's `level` (`CHAT_DB` 50), the card shows the demo `text` with its REACHES HER row from the given `chunks` (the
  lens is shown for the demo even if off), and the `lines` play as non-blocking coach bubbles (2.5 s each, or a click).
  Nothing is presented, dealt or locked; the dial stays at 50 for the player. Then it hands back (-2).
- **Asides** are `bubble.aside` lines raised by `refresh()` / `on_answer()`, each once per visit through
  `session.observe_once(key, &"aside", {...})`. They never block the beat loop. The Day 4 triggers are listed in
  CHAPTER4 §5.6: an `asides` foil answer, the first M on a list that needs noise, and the first answer on a louder
  list.

### §9.18 SPEECH screen: PARTY mode (`ui/speech/modes/sp_mode_party.gd`, P)

#### §9.18.1 Layout and widgets (CHAPTER5 §5.2)

| Area | PARTY mode |
|---|---|
| LCD | `ear_chip` "BOTH" (ink) or the ear; `test_chip` "PARTY"; `chips` [PHONES / INSERTS / SPEAKERS, UNAIDED / "PROGRAMME A" / "PROGRAMME B" (blind; "A: OMNI" / "B: FOCUS" only with the plan's `revealed`)]; `big_caption` always "TALKER"; `start_chip` "TALKER = 70 dB" (or the PTA sum when it applies), "TALKER: {n} dB, set by Hoot" or "AIDED: 50 dB, set by Hoot" (as built: "set by Hoot" lives on the start chip, clear of the TALK knob); `aux` [{PARTY, 55}, {SNR, 15}]; `info_line` "Party list 1 . sentence 3 of 6 . Fish" ("Party list 1 . practice sentence"); `noise_note` ["NO MASKING", "same mix in" / "speakers reach", "both ears"] where the NOISE box was |
| Card | `SpSentenceCard` (replaces the word card; as built it spans the bottom of the left and middle columns, sized from the list's longest sentence, at most two rows of chips) |
| Middle | `SpCourses` (six plates and the dining-room strip) |
| Meter slot | `SpSnrMeter` (the TALKER and PARTY bars and the gap bracket) |
| Bubble | `SpBubble` (two lines, as now; it grows down the left column; `idle_text` "(waiting for a sentence)") |
| Deck | LEVEL + SENTENCE (SOFTER, PRESENT, LOUDER) . KEY WORDS (MISSED, GOT IT, ALL GOT) . BILL (LOCK IN). MASK, STORE, the ladder, the agreement meter, the word card and the LCD's THIS LEVEL line hide. |
| Dance | as built: [TICK WHAT / HE SAID] [LITTLE WORDS / no score] [LOCK IN / then next] |
| Perch | during a Hoot turn on a party list: "Hoot is testing: watch the plates!" |
| Booth window | `SpPartyBooth` overlay: the two speakers in the sound field; with FOCUS, the front half of the room drawn bright and the back half dimmed (never removed) |

- **`SpSentenceCard`** (`ui/speech/sp_sentence_card.gd`): the sentence the next PRESENT will say, with its 5 key words
  as chips (at least 96 x 56 px, numbered 1-5, wrapping to 2 rows when needed). The little words are plain small text
  between them.
  - The chips wake only after the answer shows. The focus chip wears the sunny ring with its key hints.
  - Left click flips (blank -> got -> missed -> got); right click marks missed.
  - The tally reads "3 / 5 so far". At LOCK IN, blanks turn to crosses.
  - Each chip is a child `Control` registered as anchor `party_key_<n>`, so ghost hands and the bot can click it.
  - Truth is never drawn before LOCK IN.
- **`SpCourses`** (`ui/speech/sp_courses.gd`): six plates labelled with SNR and course (`SIN_COURSES`: Starter 25,
  Soup 20, Fish 15, Main 10, Cheese 5, Dessert 0). Peas fill at LOCK IN (green ticked, grey missed; Hoot's dimmer).
  The diners strip and the running total sit under them. The SNR loss line stays blank with `hide_loss`; aided lists
  show the loss and "aided, sound field", never a band.
- **`SpSnrMeter`** (`ui/speech/sp_snr_meter.gd`): a fixed mint TALKER bar and a grey PARTY bar that rises one step per
  sentence, with the bracket "SNR 25 dB" down to "0 dB!".
- **`SpBubble`**: the answer, up to two lines (the existing wrap and shrink). An ellipsis shows a dropped word.
- **Shared-file seams Day 5 added** (all optional, off for Day 3): `SpBubble.idle_text` (the line before anything is
  said; the SRT's stays "(waiting for a word)"), the LCD view key `noise_note` (in `SpLcd.OPTIONAL_KEYS`, so going
  back to the SRT drops it), and in `speech_screen.gd`, with a mode only: Hoot's opening lines say "Both ears" for
  the both-ears channel and count sentences on a party list, and the perch line above. A test checks that no PARTY
  widget overlaps another at 1280x720 and 1920x1080.

#### §9.18.2 One sentence (CHAPTER5 §5.3) and its keys

1. PRESENT: the babble starts, then the talker; the PARTY bar is already at this sentence's level. Level keys lock
   after the first sentence (`sin_level_locked`), or from the start with `level_by_hoot`.
2. The answer pops into the bubble, and the chips wake with focus on chip 1.
3. Scoring:
   - Right / + / = (`speech_correct`): got, and the focus moves on.
   - Left / - (`speech_incorrect`): missed, and the focus moves on.
   - 1-5 (`party_word_n`): flip that chip.
   - G (`party_all_got`) or ALL GOT: all five got.
   - Chip clicks: as above.
4. LOCK IN: `{key:store}` (S / Enter) or the button. `Events.party_sentence_locked` follows, and the plate fills.
   As built, Hoot's line names only the first wrong chip of a LOCK IN (the other wrong chips flash), and while that
   slip's line shows it replaces the sticky tips.
5. Space before LOCK IN is refused with `lock_first` and a wiggle of LOCK IN.

After sentence 6, `Events.party_list_done` fires, the course total lands, then `celebrate` and `complete_list`.

### §9.19 Beats, solvers, mouse routes, keys, key style and quick visit (both modes)

#### §9.19.1 Blocking beats

- **One blocking `Events.awaiting_input(beat, info, solver)` per idle point**: whenever the screen waits for the player
  (not during Hoot's turn, a movie, the pause menu or a confirm chip). It is deduped by `beat_key`:
  - WRS: `"wrs|<measure_key>|<word_n>|<action>|<db>|<mask_on>|<lens_on>"`;
  - SIN: `"sin|<measure_key>|<sentence_n>|<action>|<key>|<marks as 0/1/->|<db>"`.
- **info**: `{ear, slot, test, action, target_db, mouse: {click: <anchor>}}`, plus:
  - WRS: `list, list_n, word_n, louder_than`;
  - SIN: `condition, list, list_n, sentence_n, key (1-5 or 0), focus_key`.
- **The solver** sends the recommended action as a real `InputEventAction` (pressed, then released): the input below,
  with `party_word_<k>` for `key_fix`. A stale solver (the beat key changed since it was emitted) does nothing.
- **Beat ids** on the SPEECH screen:
  - `speech`: every WORD and PARTY idle point.
  - `lens_try`: WRS, when `plan.lens_try_after` is reached and the lens is off. Action `lens_toggle`, input
    `toggle_lens`, mouse `speech_lens_button`. Emitted once.
  - `call_it`: WRS (§9.17.5).
- **Story beats** (each with a solver and a mouse route; owned by the chapter boards): `flag_pick` (CHAPTER4 §7),
  `band_pick`, `plates_serve`, `focus_switch` (CHAPTER5 §5.7, §6), and stock `choice` / dialogue beats.
- **Movies**: the shared player emits its own `awaiting_input(&"explainer", {movie, title, scenes, source},
  skip_all)`, which the bot already handles. We add no movie beat.

| action | input | mouse (`info.mouse.click`) |
|---|---|---|
| `present` | `present_tone` | `speech_present_button` |
| `louder` / `softer` | `louder` / `softer` | `speech_louder_button` / `speech_softer_button` |
| `mask_toggle` (WRS) | `toggle_mask` | `speech_mask_button` |
| `score_correct` / `score_missed` (WRS) | `speech_correct` / `speech_incorrect` | `speech_correct_button` / `speech_incorrect_button` |
| `lens_toggle` (WRS) | `toggle_lens` | `speech_lens_button` |
| `call_it` {guess} (WRS) | `speech_correct` (get it) / `speech_incorrect` (miss it) | `call_it_yes_button` / `call_it_no_button` |
| `key_got` / `key_missed` (SIN) | `speech_correct` / `speech_incorrect` | `speech_correct_button` (GOT IT) / `speech_incorrect_button` (MISSED) |
| `key_fix` {key} (SIN) | `party_word_<key>` | `party_key_<key>` (a click flips it, which fixes it) |
| `lock` (SIN) | `store` | `party_lock_button` |

Every beat has a mouse route, so `--mouse` plays both days without a key.

#### §9.19.2 Anchors

- **WORD**: `speech_present_button`, `speech_louder_button`, `speech_softer_button`, `speech_correct_button`,
  `speech_incorrect_button`, `speech_mask_button`, `speech_lens_button`, `speech_word_card`, `speech_response`,
  `speech_score_strip`, `speech_banana`, `speech_ghost`, `speech_ear_compare`, `call_it_yes_button`,
  `call_it_no_button`.
- **PARTY**: `speech_present_button`, `speech_louder_button`, `speech_softer_button`, `speech_correct_button`,
  `speech_incorrect_button`, `speech_response`, `party_key_1` to `party_key_5`, `party_all_got_button`,
  `party_lock_button`, `party_sentence_card`, `party_courses`, `party_snr_meter`.
- The old mode's anchors are unregistered when the test changes (H26).
- Every anchor is on screen and clear of Hoot's perch at 1280x720 and 1920x1080 (a test).

#### §9.19.3 Key hints, the key style and buttons

- **Key hints** (H, `toggle_key_hints`) on every button. WORD: PRESENT [Space], LOUDER / SOFTER [Up] / [Down] (or
  swapped), REPEATED [Right], MISSED [Left], NOISE [M], LENS [V]; Call it: [Right] / [Left]. PARTY: chips [1]-[5],
  GOT IT [Right], MISSED [Left], ALL GOT [G], LOCK IN [S]. The focus chip shows "-> got it / <- missed".
- **The swap-arrows style** changes only `louder` / `softer` (and `mask_*`), exactly as on Day 3. No new action is
  swapped. Every coach line, tip and technique message that names a key uses `{key:<action>}` (D10), and a test
  renders every line in both styles.
- **Mouse-only**: every key has a button, every chip and card is clickable, and the movie player has its own "Next"
  ("Start the day" on the last scene), "Skip movie" and "II" buttons.

#### §9.19.4 Hoot's quick-visit takeover

- **The gate** (H16, D24): `hoot_only or quick_visit`. Quick visit is read exactly as `level_mike.quick_visit()` does
  (`--quick` / `--full` win over the setting).
- **`hoot_turn_after` N**: after the player scores N words (WRS) or locks N sentences (SIN) of this list, the banner
  shows `hoot_turn_text`. Hoot then finishes the list at `hoot_speed` (default x8): `session.scoring = false`, and
  `Engine.time_scale` is set and restored exactly. With 0, Hoot runs it all. The Hoot-done key is `measure_key()`
  (H17).
- **`confirmed_wrong_hoot_after` N** (WRS): the same takeover after a confirmed wrong set-up, outside the gate.
- **`hoot_first` N** (SIN): Hoot's turn starts at once (or at the player's first PRESENT with `level_first`).
  `SpModeParty.hoot_step()` returns -2 once sentence N is locked, and the player takes over at sentence N + 1.
- **The practice** (SIN): a Hoot turn at speed 1 that `hoot_step()` ends (-2) after the practice LOCK IN.
- Hoot plays through the real controls: chips ripple, LOCK IN is pressed, and plates fill dim. His words and sentences
  are not scored (`by_hoot`), and they are billed by the truth.
- **`run_hidden`** (H28) is never a Hoot turn: it runs off-screen whatever quick visit says.
- **Quick visit off**: the levels leave out `hoot_turn_after` and `hoot_first` for player lists (§9.21); `hoot_only`
  lists stay Hoot's.

### §9.20 Movies (§3.4; S0a stubs, then W and P each write one)

**A movie is data.** `res://story/explainers/movies/letter_choir.gd` (W, CHAPTER4 §4) and
`res://story/explainers/movies/party_noise.gd` (P, CHAPTER5 §4). Each is `extends RefCounted` with
`const MOVIE := {id, title, subtitle, chapter: "nora" | "marco", narrator: "Hoot", scenes}` plus the optional movie
keys `seen_at` and `stage`. Each scene has `id, set, duration, captions[], teaches`, plus the optional `title,
caption_at, params, cues, board`; both movies fill every one of them (CHAPTER4 §4.2, CHAPTER5 §4.2 print the data).

| Movie | id | title / subtitle | Scenes (set ids) | `seen_at` | Total | Day |
|---|---|---|---|---|---|---|
| The Letter Choir | `letter_choir` | "Hoot's word movie" / "The Letter Choir" | choir, banana, curtain, mush, louder, crossing, count, tease | `count` | 70 s, 8 scenes (15 + 6 x 8 + 7) | 4 (`nora`) |
| The Party Problem | `party_noise` | "Hoot's party movie" / "The Party Problem" | quiet, crowd, scale, knob, gap, menu, receipt, tonight | (default: the last, `tonight`) | 71 s, 8 scenes (14 + 8 + 9 + 8 + 9 + 8 + 8 + 7; as built, with Steve's lead-in on `quiet`) | 5 (`marco`) |

**Files and stage sets.** The per-movie sets hook (§3.4, "Sets hook") lets each movie bring its own sets script, so no
shared movie file changes beyond S0a's registry lines.

| File | Owner | Step | What |
|---|---|---|---|
| `story/explainers/movies.gd` | S0a | S0a | the two `MOVIES` lines (§9.10.7); nothing else |
| `story/explainers/movies/letter_choir.gd`, `party_noise.gd` | S0a stub, then W / P | S0a; W5a / P5a; W5b / P5b | S0a: a valid stub (three `card` scenes of 16 s). W5a / P5a: the full data **without** the `"stage"` line, so every scene plays as its card. W5b / P5b: add `"stage": "res://story/explainers/stages/<id>_sets.gd"` |
| `story/explainers/stages/letter_choir_sets.gd` | W | W5b | `extends "res://story/explainers/explainer_sets.gd"`; `const SETS: Array[StringName] = [&"choir", &"banana", &"curtain", &"mush", &"louder", &"crossing", &"count", &"tease"]`; one `func _set_<id>() -> void` per set |
| `story/explainers/stages/party_noise_sets.gd` | P | P5b | the same shape with `[&"quiet", &"crowd", &"scale", &"knob", &"gap", &"menu", &"receipt", &"tonight"]` |
| `story/tests/test_movie_letter_choir.gd`, `test_movie_party_noise.gd` | W / P | W5a / P5a | the tests below |

Neither builder edits `explainer_stage.gd`, `explainer_sets.gd`, `explainer_player.gd` or `dev_explainer.gd` (the
main thread owns them), and no preview script is needed: `dev_explainer.tscn --movie=<id> --at=0.2,0.6,0.95` shoots
the real sets (`--reduced-motion` for the still versions).

- **The hook.** The player calls `stage.use_movie(movie)`, which loads `MOVIE.stage`. The stage draws its built-in
  sets itself and hands any other set to that script's `draw_set(stage, id)` inside its own `_draw()`; a set neither
  knows draws `_set_card()` from the scene's params. `Movies.validate(id, Stage2D.SETS)` accepts the script's `SETS`
  and reports a missing script, a script that is not an `explainer_sets.gd`, or a `SETS` id with no `_set_<id>()`.
  `Movies.own_sets(id)` lists the script's ids.
- **Set rules.** The list is `const SETS`: the base `explainer_sets.gd` extends `RefCounted` and declares none, so
  nothing is shadowed. Each `_set_<id>()` reads only `t`, `duration`, `params`, `scene_id` and `scene_title`: no
  tweens, nodes or RNG, so a paused movie freezes and a skipped scene leaves nothing behind. It draws through `s`,
  the stage (`s._hoot()`, `s._text()`, `s._panel()`, `s._chip()`, `s._note()`, `s._curtains()`, `s._head_open()`,
  `s._snail()`, `s._cloud()`, `s.draw_*()`), with the palette as `Stage2D.<COLOR>`; `_k()`, `_pop()` and `_ring()`
  are on the base. Banana or audiogram maths is copied in from `SpeechRules` values as data (`SOUND_CUES`
  positions), never a call into `SpBanana` or other Day 4 UI code.
- **Set ids** never collide with `explainer_stage.gd`'s built-in `SETS` (meet, air, wall, bone, ghost, mask, under,
  over, plateau, outro, card): a built-in would win. They need not be unique across movies (the stage asks only the
  playing movie's script), though these sixteen are.
- **Card fallback, every scene.** Every scene, of any set, carries top-level card params: `heading` (30 characters or
  fewer), `lines` (at most 4, 36 characters or fewer each), `icon` (one of `CARD_ICONS`: "", "snails", "ghost",
  "cloud", "note", "dial", "hoot") and `tint`. So the movie plays as cards at W5a / P5a, and a set ever missing from
  the script still shows its card, never a blank screen. The set's own data nests under a key named after the set
  (`params.banana = {...}`) and never reuses `heading`, `lines`, `line_at`, `icon`, `hoot` or `tint`.
  `Movies.validate` checks the card limits only when `set == "card"`, so our tests check them on every scene.
  Scene 1's lead-in keys (`card_hold`, `questions`) sit beside the card keys; its set reads them.
- **Brand.** One brand for every movie: the Matinee curtain opens inside scene 1 (as the masking movie opens), on a
  marquee "HOOT'S MOVIE MATINEE" over the movie's subtitle. Our scene-1 sets (`choir`, `quiet`) draw it with
  `s._curtains()` and a marquee from their own params (`params.choir.title`, `params.quiet.title`). The stage's
  `_title_card()` names the masking movie and is not used; no shared file changes.
- **The lead-in** (Steve, 2026-10-19: every movie opens the way Day 2's does). Scene 1 holds its title card for
  `params.card_hold` seconds (8.0) with the two `params.questions` chips under it (popping in at 2.0 and 4.6 s), while
  its first captions say what the movie will explain and name the answer; the set's own picture then runs on the
  stage's clock shifted by `card_hold - 2` s. The stage treats a scene as a card scene when `set_id == &"meet"` or
  its params have `card_hold` (`_card_scene()`: no iris, and the scene title waits for the card to go); a sets script
  that draws scene 1 reads both keys, as the built-in `_set_meet` does. Day 4's scene 1 (`choir`, 15 s) has the
  chips "Loud enough, so why mushy?" and "How do we score clear words?" and captions at 0.3, 4.4 and 8.4 s: the
  question, the answer (a WORD SCORE counts clear words, because beeps can't measure clarity), then the choir. Day
  5's scene 1 (`quiet`, 14 s; as built) has the chips "Why is a busy table so hard?" and "How do we test words in
  noise?" and captions at 0.3, 4.4 and 8.4 s: the question (why someone fine in quiet gets lost at a busy table),
  the answer (SNR LOSS: quiet beeps can't show it, so we test words in noise), then the quiet cafe. As built its
  scale caption reads "SNR: how much louder the voice is than the noise. A bigger gap is easier." (the balance is
  drawn the physical way, the louder voice pan sinking; it needs Steve's OK, CHAPTER5 §15 Q19), and its receipt
  scene adds the chip "Most ears miss 4 or 5 anyway". Beyond the design's keys its sets read `quiet.title` /
  `starring` / `line`, `crowd.chatter` / `line`, `scale.at`, `gap.words` / `crisp`, `menu.title` / `key_words`,
  `receipt.courses` / `key_words` / `band_name` and `tonight.sign` / `chip`; the cue times are CHAPTER5 §4.2's. The
  masking movie and the case movies (`tymp`, `shapes`, `case_files`) carry the same keys. Before the first play
  the level announces the day in one Hoot line (below). The chapter doc's movie table prints the lead-in
  (CHAPTER4 §4.2).
- **Cues** come only from `Sfx.SOUNDS` (click, blip, thunk, stamp, ding, boing, pop, whoosh, kaching, sad_trombone,
  squeak, fanfare, chirp, pen, door, note, sparkle, error), each with `vol_db` from -8 to -16 (the player caps at -6
  anyway). The crowd, babble, the loud knob and "too loud" are drawn, never played; no cue is louder than the
  others.
- **Controls** are the player's (§3.4), the same as Day 2's movie: after a 0.3 s
  grace, Space / Enter / a click advance like the dialogue box (finish the caption, else the scene's next caption,
  else the next scene); Esc skips the movie; P pauses. Buttons: "Next" ("Start the day" on the last scene at day
  start, "Done" on replays), "Skip movie" and "II". Captions type at 42 characters/s; a scene lasts `max(duration,
  last caption start + typing + 1.6 s)`. The music is ducked while it plays.
- **Seen** means the movie reached its `seen_at` scene (`watched` in the result); only then does the player call
  `Game.mark_movie_seen(id)`. An Esc before that plays it again on the next visit.

**How the level plays it** (as built in `level_nora.gd`: `level_bonnie._movie()` plus the one-line announcement;
Day 5 changes the id, the lines and the offer):

```gdscript
const Movies := preload("res://story/explainers/movies.gd")
const EXPLAINER_SCENE := "res://story/explainers/explainer_player.tscn"
const MOVIE_ID := "letter_choir"          # "party_noise" in level_marco.gd
const MASKING_MOVIE := "masking"
var _movie_watched := false               # the movie reached its seen_at scene this visit (lines may refer to it)

func _run() -> void:
	await _masking_offer()
	await _movie()
	await _intro()
	...

## Day 4 only, called before _movie(): the masking movie for a player who skipped Day 2.
func _masking_offer() -> void:
	if not Movies.has(MASKING_MOVIE) or Game.is_movie_seen(MASKING_MOVIE) or Game.is_chapter_done("bonnie"):
		return
	clinic.call("focus_camera", &"door", 0.0)
	var opts: Array[String] = ["Show me the Ghost movie! (about %d s)" % int(roundf(Movies.total_s(MASKING_MOVIE) / 10.0) * 10.0),
		"Skip it: on with words."]
	var c: int = await dialogue.choose("New to the Cross-Hearing Ghost? My masking movie explains it first.", opts, 1)
	if c == 0:
		await _play_movie(MASKING_MOVIE)

func _movie() -> void:
	if not Movies.has(MOVIE_ID):
		return
	var seen := Game.is_movie_seen(MOVIE_ID)
	_phase(&"explainer", {"movie": MOVIE_ID, "source": "day_start", "seen": seen})
	clinic.call("focus_camera", &"door", 0.0)
	if seen:
		var opts: Array[String] = ["Roll the film! (about %d s)" % int(roundf(Movies.total_s(MOVIE_ID) / 10.0) * 10.0),
			"Skip it: I know my banana."]                 # Day 5: "Skip it: I know my SNR."
		var c: int = await dialogue.choose("Hoot's word movie again? Popcorn's on me!", opts, 1)   # Day 5: "Hoot's party movie again? ..."
		if c != 0:
			return
	else:
		await _say("Hoot", "New trick today: WORD SCORES. A quick cartoon first, then our next patient!")
	var r := await _play_movie(MOVIE_ID)
	_movie_watched = bool(r.get("watched", not bool(r.get("skipped", false))))
	Game.set_visit_flag("movie_watched", _movie_watched)
	if bool(r.get("skipped", false)):
		await _say("Hoot", "Skipped! Rewatch it any time: pause menu, \"Watch %s\"." % Movies.title(MOVIE_ID))

func _play_movie(id: String) -> Dictionary:
	var player: Node = (load(EXPLAINER_SCENE) as PackedScene).instantiate()
	add_child(player)
	var r: Dictionary = await player.call("play", id, "day_start")
	player.queue_free()
	return r
```

- **The announcement** (Steve's lead-in): before the first play only, one Hoot line names the day's new trick
  (Day 4: "New trick today: WORD SCORES. A quick cartoon first, then our next patient!"; Day 5: "New trick today:
  WORDS IN NOISE. A quick cartoon first, then our next patient!"). On a replay visit the offer stands in for it.
- Until a movie is seen it just plays; once seen, Hoot offers it with a choice whose best answer is "skip". The offers
  read their length from `Movies.total_s`, rounded to 10 s: "Roll the film! (about 70 s)" on Day 4 and on Day 5
  (71 s; "Hoot's party movie again? Popcorn's on me!", skip: "Skip it: I know my SNR."), and "about 90 s" for the
  masking offer.
- After a day-start skip Hoot says where the movie lives (the same line as Day 2's, 11 words).
- Replays: the pause menu asks `Movies.for_level(Game.current_chapter_id, masks)`. Day 4's level is not in
  `MASKING_LEVEL_GROUP`, so it offers its own chapter's movie only ("Watch Hoot's word movie"); the case days and the
  walk-ins (in the group) offer every replay movie, the Letter Choir among them. The masking movie belongs to `bonnie`,
  so Day 4's pause menu does not list it (the title's "Hoot's Movies" does). Day 5's works the same way ("Watch
  Hoot's party movie"). `Movies.replay_ids()` leaves out a movie whose chapter is not in `Game.CHAPTERS` yet; both
  days exist now, so both movies are listed.
- **(Clinical review A2, all days)** While the masking movie is unseen, the visit's first masked test (Day 4: Hoot's masked
  bone; Day 5: his masked bone, where a gap shows) plays the one-card
  `masking_recap` first (the `explainer` beat, source `recap`), once a visit, then Hoot: "The full masking movie is
  under Hoot's Movies, in the pause menu or on the title screen." The level joins `MASKING_LEVEL_GROUP` right there,
  so from then on its pause menu offers every replay movie, as on the case days. Day 4's day-start masking offer
  stays. A watched masking movie changes nothing; Day 3 masks nothing and has no recap.
- No `seen_explainers`, `explainer_skipped`, `movie_skipped`, skip anchors, hold-to-skip or `--explainer`: the player
  and `movies_seen` cover them. No `tools/INTEGRATION_NOTES.md` stage note is needed either.

**Tests** (each builder's own file: `story/tests/test_movie_letter_choir.gd` (W), `test_movie_party_noise.gd` (P)):
- `Movies.validate(id, Stage2D.SETS)` is empty (Stage2D = `explainer_stage.gd`; the hook adds the sets script's
  `SETS`); 45-110 s; every caption 18 words or fewer; `seen_at`, when given, is a scene.
- `Movies.own_sets(id)` is exactly the movie's set ids (W5b / P5b), and none is in `Stage2D.SETS`.
- For every scene, whatever its set: at most 4 lines of 36 characters or fewer, `icon in CARD_ICONS`, a heading of 30
  characters or fewer, and the set's data under its own key, never under a card key.
- The cards-only step: the same data with `stage` removed (registered through `Movies.extra` in the test) validates
  with no known sets, and every scene falls back to its card.
- The lead-in: scene 1 holds its card (`card_hold` 8) with two `questions` chips, and its captions name the
  question and the answer (Day 4: `test_letter_choir_lead_in`; Day 5: `test_party_noise_lead_in`).
- Every cue name is in `Sfx.SOUNDS` with `vol_db <= -8`.
- Facts match the rules: the count board's 25 tiles = `WRS_WORDS`; the crossing's `ia` = `SPEECH_IA_DB[&"phones"]`;
  the louder slide = `WRS_ABOVE_PTA_DB`; the menu's SNRs = `SIN_SNRS`; the receipt's loss = `snr_loss(25)` (0.5) and
  its band `sin_band(0.5)`; the gap's typical value = `SIN_NORMAL_SNR50_DB`.
- Pure in `t`: the sets script contains no `randf`, `randi`, `RandomNumberGenerator`, `Time.`, `create_tween`,
  `add_child` or `get_tree` (a source scan); the dev scene's shots at the same `t` are identical.

### §9.21 Story wiring for Days 4 and 5 (the plans)

`quick` = the quick-visit setting (read as `level_mike.quick_visit()`). `t` = the visit's merged tone results. Every
list is one `start_test`, except `run_hidden` work. The plans are pseudo-code: `key = v if quick` means the key is
present only with quick visit on. `next_list()` hands out word lists in play order (D25).

**Day 4, `story/level_nora.gd`** (CHAPTER4 §3, as built; `QUICK_WORDS := {&"right": 8, &"left": 8, &"redo": 5,
&"louder": 5}`; `list_plan(kind, list_id, quick, n)` builds every word list's plan):

```gdscript
# Tones (Hoot, x8, montage, level_case.gd pattern), in this order:
#   right ac (the visit's first air ear, so its montage owes the 1 kHz retest, E2), left ac,
#   right bc unmasked at BONE_FREQS [1000, 4000] (her better mastoid: the AudiOtron asks for masked bone
#   only where an unmasked bone stamp shows a gap), then left bc_masked at 1000 and 4000 with
#   put_on_masking_phone("right"). (E1) Air charts its nine frequencies; 750 Hz only on the 20 dB rule.
# SRTs: quick -> screen.run_hidden(nora, ear, {test = "srt", tones = t, transducer}), right then left
#       quick off -> start_test(nora, ear, not Game.is_chapter_done("mike"), {test = "srt", tones = t, transducer})   # D30
# Every word list: {test = "wrs", tones = t, list = next_list(), transducer} plus its kind's keys, and
# hoot_turn_after = QUICK_WORDS[kind] if quick.
# List 1 (right, coached), after Hoot's A5 line "Real clinics play recorded word lists, so every patient
# hears the very same voice."
{lens_try_after = 2, call_it = [&"faint_hit"], chatter = NORA_CHATTER,
 intro = "Word scores! One-syllable words, loud enough for every sound. Twenty-five of them, 4% each.",
 hoot_turn_text = "Lovely scoring! I'll score the rest at top speed."}
# List 2 (left, solo); the tea demo parks the dial at CHAT_DB
{level = SpeechRules.CHAT_DB, chat_demo = TEA_DEMO, ensure_audible_miss_by = 6, audible_stamp = true,
 call_it = [&"audible_miss"], aside_by = 8, self_correct = true, chatter = NORA_CHATTER, silences = NORA_SILENCES,
 confirmed_wrong_hoot_after = 3}
# Redo (only when List 2's counts == false): left, coached
{redo_of = n, ensure_audible_miss_by = 6, audible_stamp = true, aside_by = 5, chatter = NORA_CHATTER,
 silences = NORA_SILENCES}
# Louder: left, coached, 20 dB above the counted comfortable list n, after the "What next?" choice
{louder_than = n, mask_on = true, lock_noise = true, loud_bubble = true, aside_by = 5, chatter = NORA_CHATTER,
 silences = NORA_SILENCES}
```
- **Phases**: `explainer` (the movie), `intro`, `history`, `otoscopy`, `instructions`, `audiometry` (each tone test),
  `speech` (each SRT and list, with `{ear, test}` and `redo` / `louder` on those lists), `evidence`, `referral`,
  `results`. Without the SPEECH screen, Hoot runs every measurement by the textbook (`run_by_textbook`, C23) and
  the day carries on.
- **The decision** comes from the Red-Flag Roll Call (nine cards in `ROLL_CALL_ORDER`: hiss, canals, tones, agree,
  apart, slowly, predicted, wobbly, louder; a card is a red flag only when its rule fires on the visit's results)
  and the stamp tray (CHAPTER4 §7). `wrs_summary.referral` is `&"refer"` (a missing summary also means refer), and
  the story checks the player's stamp against it. The letter fills in the visit's numbers and asks for an
  assessment, including imaging, before any fitting; it says what was found, never what it is.
- **Visit flags**: `movie_watched`, `asked_red_flags`, `asked_onset`, `instructed`, `instructed_first_try`,
  `masked_first_try`, `wrs_redo` ("", "unmasked" or "level"), `lens_used`, `boo_seen`, `ghost_words`, `call_it`,
  `flag_slips`, `decision_first`, `decision` (`refer`) and `decision_tries`.
- **Medals** (`MEDAL_BEATS`): history "Chat", instructions "Explain", masking "Noise" (gold: noise on before List
  2's first word, unprompted; silver: on after the BOO; bronze: tested unmasked), evidence "Flags" (by Roll Call
  slips) and referral "Call" (by stamp tries). Otoscopy records gold and is not a beat.
- `Game.CHAPTERS` entry (W5a): `{"id": "nora", "day": 4, "title": "Day 4: Nora Nightingale", "patient_id": "nora",
  "teaches": "Word recognition (WRS)", "scene": "res://story/level_nora.tscn", "requires": "mike", "face": "Nora",
  "tint": Color("#d8f0e4")}`. This changes Day 3's "UP NEXT" (and the paper's "Next") to Day 4: the one allowed
  visible Day 3 change. Day 5's entry replaces the marker line after it.
- The summary for the paper always sets `headlines`, `subheads` (with the visit's {r}, {l} and {b}), `medal_beats`,
  `weather` ("Weather: scattered consonants, fog over the left"), `sports_script =
  "res://story/papers/paper_word_golf.gd"` and `roll_call` ({cards, slips}).

**Day 5, `story/level_marco.gd`** (CHAPTER5 §3, as built; `party_plan(n, quick)` builds the plans):

```gdscript
# Hoot's montage (whatever quick visit says), all with hoot_turn_after = 0 and montage = true:
#   air, right then left, in the routine order (E1: 1k, 1.5k, 2k, 3k, 4k, 6k, 8k, the 1 kHz retest, 500, 250;
#   750 on the 20 dB rule); the right is the visit's first air ear, so it owes the 1 kHz retest (E2);
#   unmasked bone on the right mastoid at ClinicRules.BC_REQUIRED (1k, 2k, 4k, 500), masking_controls on;
#   masked bone only on an ear where ClinicRules.masked_freqs_needed(results, ear, &"bc_masked") is not empty;
# then, off-screen and right first, on the SPEECH screen kept for the whole visit (tr = the air transducer):
screen.run_hidden(marco, "right", {test = "srt", tones = t, transducer = tr}); then "left"
screen.run_hidden(marco, "right", {test = "wrs", tones = t, list = "words_1", transducer = tr})
screen.run_hidden(marco, "left", {test = "wrs", tones = t, list = "words_2", transducer = tr})
# Every party plan: {test = "sin", tones = t, list = SIN_LISTS[n - 1], lost_lines = MARCO_LOST}; lists 1-2 add
# transducer = tr. Unaided list 1: "both", coached, with the practice; the dial starts at 50
{condition = "unaided", level = 50, practice = "party_practice", hide_loss = true, intro = "intro_party1"}
# Unaided list 2: solo; the player sets the talker (the dial at snap5(PTA)), then Hoot pours 1-3 when quick
{condition = "unaided", level_first = true}  # + quick: hoot_first = 3, intro = "intro_party2", hoot_turn_text = "pours"
# Programme A (OMNI), sound field at SIN_AIDED_DB, set by Hoot
{condition = "omni", programme = "A", intro = "intro_aided_a"}  # + quick: hoot_first = 3, hoot_turn_text = "pours"
{condition = "omni", programme = "A", hoot_only = true, hoot_turn_after = 0, hoot_turn_text = "hoot_list"}  # no lost_lines
# Programme B (FOCUS)
{condition = "directional", programme = "B", compare_to = "aided_omni", intro = "intro_aided_b"}  # + quick as list 3
{condition = "directional", programme = "B", compare_to = "aided_omni", hoot_only = true, hoot_turn_after = 0,
 hoot_turn_text = "hoot_list"}  # no lost_lines
```
(The quoted `intro` / `hoot_turn_text` names are `level_marco.gd` `HOOT` keys; the plan carries their lines.)
- As built, Hoot's lists 4 and 6 carry no `lost_lines` (`party_plan` erases them), and the coached list 1 is the
  only one with the practice.
- Visit flags (as built): `movie_watched`, `asked_red_flags`, `asked_onset`, `instructed`, `instructed_first_try`,
  `masked_bone`, `bill_tries`, `band_tries`, `plates_slips`, `marco_guess` ("B" when the benefit is real, else
  "unsure"), `benefit_unsure` and `seat_tries`.
- Aided lists take `level = SIN_AIDED_DB` and `level_by_hoot = true` by default (§9.14.1).
- When `aided_directional.real_change` is false, the level sets the visit flag `benefit_unsure` and Hoot says so
  (CHAPTER5 §9).
- `Game.CHAPTERS` entry (P5a, merged after W5a): `{"id": "marco", "day": 5, "title": "Day 5: Marco Polenta",
  "patient_id": "marco", "teaches": "Speech in noise (SNR loss)", "scene": "res://story/level_marco.tscn", "requires":
  "nora", "face": "Marco", "tint": Color("#ffe1b8")}`.
- The summary for the paper always sets `headlines`, `subheads` (Marco's review, CHAPTER5 §8.4), `medal_beats`,
  `weather` ("Weather: rising babble, clearing with directional mics") and `sports_script =
  "res://story/papers/paper_party_golf.gd"`.
- (A7) Hoot's lines say "His audiogram can't tell us how he copes in noise. Measured: {avg} dB.", and after the
  FOCUS result (and on the paper): "The booth is kinder than a real restaurant. We'll check how the aids do at your
  table." The booth benefit is never presented as proof of real-world benefit, and the 4.0 dB directional benefit
  stays (open question 17). The unaided band reads "Near-normal" for 0-3 dB (the receipt prints "NEAR-NORMAL").
- `world/clinic.gd` gains `show_soundfield(on)` (P, additive; nobody else touches it).

**Both levels**:
- Hoot's off-screen work and the fallback for a missing SPEECH scene go through `session.run_by_textbook(ear)` (C23);
  `level_mike.hoot_runs_ear` is not copied.
- They play their movie as §9.20 shows and skip it when `Movies.has(id)` is false.
- Portraits, bean specs and voices follow CHAPTER4 §14 and CHAPTER5 §12. `Voice.register(...)` is called at runtime.
  Each builder edits only its own marker region in `world/characters/bean.gd` and `story/portraits.gd` (§9.23).
  `story/voice.gd` is not edited: each level calls `Voice.register(...)` at runtime.

### §9.22 Autoplay (§9.9 extended; `tools/INTEGRATION_NOTES.md`)

The main thread owns `tools/autoplay_bot.gd`. The Days 4-5 builders wrote this section as a patch request in
`tools/INTEGRATION_NOTES.md`; W5a then applied Day 4's part and P5a Day 5's, in blocks marked `# (Days 4-5)` that
run only with a `wrs` / `sin` test, a word or party sheet or the `nora` / `marco` chapter, so Days 1-3 and 6-13 print
byte-identical `AUTOPLAY_RESULT` lines. The notes list what is applied ("Already in the bot"): all of it now. The notes number the patch's parts 1-8 (speech days, beats, word lists,
party lists, Day 4, Day 5, screenshots, runs), and the bot's comments cite them as §9.22.1-§9.22.8. Any problem below
fails the run with exit 4.

- `speech_day := chapter in ["mike", "nora", "marco"]`. The generic loop (every sheet in srt / wrs / sin within 10 dB
  of `true_db`) stays (D9).
- Beats need no new bot code: `lens_try`, `call_it`, `flag_pick`, `band_pick`, `plates_serve` and `focus_switch` all
  carry a solver and a `mouse` route; `explainer` is the player's own.
- **`_check_wrs_lists(sp, report, problems)`** (any day with `speech.wrs`; applied). It adds `report.wrs_lists`, one
  row per list (`ear:list_id:level:mask:pct`, with `:void` on a list that does not count), and for every counted
  list with player words:
  - `|pct - expected_pct| <= 8`;
  - `pct == true_pct` when nothing was misscored (`matches == player_words`);
  - `start_ok`, and `masked == masking_needed`.
- **`_check_sin_lists(sp, report, problems)`** (any day with `speech.sin`; applied). It adds `report.sin_lists`, one
  row per list (`slot:list_id:level:total`, with `:hoot` on a list with no player sentences), and checks:
  - every list has 6 sentences, and `total` equals the sum of the sentences' billed counts;
  - `|snr_loss - true_loss| <= 3` for every sheet with 2 lists;
  - no practice sentence is stored.
- **Day 4 (`nora`)** (`_check_nora`, applied):
  - `wrs.right` and `wrs.left` exist; the right sheet's `seq` is below every left list's (better ear first);
  - the list ids follow play order (one right list, `words_1`; then `words_2`, `words_3`, `words_4` on the left);
  - right `pb_max >= 88` and band excellent or good; the left counted comfortable list's `pct <= 64`;
  - left `best_final`, `below_predicted`, `asymmetric` and `rollover` (A1-A3);
  - a counted left list with `louder_than > 0`, whose `mask_db` equals `wrs_mask_level(level_db, test_best_bone,
    transducer, nontest_largest_abg)` (A4; `test_best_bone` is the lowest of `ear_best_bone(tones, "left")`) and lies
    in 60-80 (70 on a textbook run, as Hoot's bone stamps wobble up to 10 dB, CHAPTER4 §2.2);
  - `wrs_summary.referral == &"refer"`; and the visit flag `decision` is `refer` when the visit records one;
  - the movies: the result adds `movies` (the movies that started, as Day 2 and the cases print it), and a fresh save
    (no `--keep-save`) must start `letter_choir`.
- **Day 5 (`marco`)** (`_check_marco`, applied):
  - `srt.right`, `srt.left`, `wrs.right` and `wrs.left` exist, all by Hoot, right first, even with `--full`;
  - WRS bands excellent or good;
  - `sin.both`, `sin.aided_omni` and `sin.aided_directional` each with `lists_done == 2`, and the 6 list ids distinct;
  - unaided band `&"moderate"`; aided sheets at `level_db == SIN_AIDED_DB` with `band == &""`;
  - `aided_directional.real_change == true`, or the visit flag `benefit_unsure` with `benefit_db > 0`;
  - the paper text contains no "beeps" and no "spondees": the bot reads every visible Label's and Button's text
    (`_visible_texts`) at `results_continue` on `marco`, and a paper it never read is a problem too;
  - the movies: the result adds `movies`, and a fresh save (no `--keep-save`) must start `party_noise`.
- **Screenshots** (D26):
  - WORD: `speech_<ear>_wrs_<list_id>_first_word`, `speech_<ear>_wrs_<list_id>_stored`;
  - PARTY: `speech_<slot>_sin_<list_id>_first_word`, `speech_<slot>_sin_<list_id>_stored` (slots `both`, `aided_omni`,
    `aided_directional`);
  - SRT keeps `speech_<ear>_srt_first_word` / `_stored`;
  - plus the chapter lists in CHAPTER4 §15 and CHAPTER5 §13.
- **Runs**: `tools/autoplay_check.sh --day=4` and `--day=5`, each with keys, with `--mouse`, with `--via-days
  --pick=nora` / `--pick=marco` (and `--save=<abs path>`), and once with `--full` (quick visit off; on Day 5 Hoot's SRT
  and WRS stay his). Each prints one `AUTOPLAY_RESULT` line; grade S with no problems is the bar. As built, Day 5's
  keyboard run takes about 760 game-seconds and prints `sin_lists` such as `both:party_1:70:15`,
  `aided_omni:party_4:50:16:hoot` and `aided_directional:party_5:50:19`.

### §9.23 File ownership and the build plan

#### §9.23.1 Owners

| Path | Owner | Notes |
|---|---|---|
| S0a and S0b additions to the shared files of §9.10.7, the two mode base classes | **W**, as steps S0a and S0b | P reviews S0b before it merges |
| `core/speech/material/words_*.json`, `models/wrs_model.gd`, `modes/wrs_test.gd` | W | |
| `ui/speech/modes/sp_mode_word.gd`, `sp_score_strip.gd`, `sp_banana.gd`, `sp_ghost.gd`, `sp_ear_compare.gd` | W | |
| `core/patients/nora.tres`, `story/level_nora.*`, `story/games/nora_board.gd`, `story/explainers/movies/letter_choir.gd` (after the S0a stub), `story/explainers/stages/letter_choir_sets.gd`, `story/papers/paper_word_golf.gd`, `story/dev_nora.*` | W | |
| `core/speech/material/party_*.json`, `models/sin_model.gd`, `modes/sin_test.gd`, `speech_babble.gd` | P | |
| `core/speech/speech_voice.gd` (babble, "both") | P | W never edits it |
| `ui/speech/modes/sp_mode_party.gd`, `sp_sentence_card.gd`, `sp_courses.gd`, `sp_snr_meter.gd`, `sp_party_booth.gd` | P | |
| `core/patients/marco.tres`, `story/level_marco.*`, `story/games/marco_*.gd`, `story/explainers/movies/party_noise.gd` (after the S0a stub), `story/explainers/stages/party_noise_sets.gd`, `story/papers/paper_party_golf.gd`, `story/dev_marco.*`, `world/clinic.gd` (`show_soundfield`) | P | |
| `core/speech/speech_rules.gd` | S0a: the "lists" block. W: append at the end of the WRS section. P: append after the S0a block at the end of the file. | never the same lines |
| `autoload/game.gd` `CHAPTERS`, `world/characters/bean.gd` specs, `story/portraits.gd` entries | W and P | S0a puts two marker comments with one unchanged separator line between them; each builder replaces only its own marker; W5a's CHAPTERS line merges before P5a's |
| `story/explainers/movies.gd` | S0a only | W and P never touch it |
| `story/explainers/explainer_stage.gd`, `explainer_sets.gd`, `explainer_player.gd`, `dev_explainer.gd` | main thread | never edited for Days 4-5: the sets hook (§9.20) carries our art |
| `tools/autoplay_bot.gd` | main thread | Day 4's checks in `# (Days 4-5)` blocks (W5a, §9.22); Day 5's go in the same way |
| `docs/SPEECH.md` | S0b rewrites §6 for all three tests. W6: §4 and the WRS kinds. P6: §5 and the SIN kinds. | separate sections |
| `CONTRACTS.md` | W6 pastes this contract | P6 adds only corrections, in its own commits |

**SpeechRules appends.**
- **S0a** ("lists (Days 4-5)", end of file): `LIST_TEE_BONUS` 2, `LIST_CONFIRM_SLIP` 3.
- **W** (WRS section): `WRS_LISTS`, `WRS_KEY_MIX`, `WRS_DEAL_JITTER`, `WRS_MISS_SCALE_DB` 4, `WRS_MISS_FLOOR` 0.05,
  `WRS_MISS_COCHLEAR`, `WRS_MISS_NEURAL`, `WRS_LOUDER_DB` 20, `WRS_LOUDER_TOLERANCE_DB` 5, `WRS_AUDIBLE_MARGIN_DB`
  3.0, `WRS_CHATTY_SHARE` 0.33, `WRS_CHATTY_MAX_WORDS` 6, `WRS_SELF_CORRECT_COUNTS` true, `CHAT_DB` 50, `LENS_FADE_DB`
  15, `LENS_MIN_ALPHA` 0.15, `GHOST_ALPHA_FLOOR` 0.2, `GHOST_ALPHA_SPAN_DB` 25, and (A1-A3) `WRS_PREDICTED_MIN_25`,
  `ROLLOVER_INDEX_CUTOFF` 0.45, `WRS_CRIT_Z` 1.96. Functions: `wrs_predicted_min_interp`, `ear_best_bone`,
  `nontest_best_bone`, `wrs_mask_level`, `wrs_louder_level`, `wrs_louder_ok`, `rollover_drop`, `wrs_pct`,
  `wrs_deal_count`, `wrs_miss_weight`, `lens_alpha`, `ghost_alpha`, `chunk_sounds`, `word_min_margin`,
  `word_fully_audible`, `wrs_referral`, `wrs_window`, `wrs_mask_capped`, and (A2, A3) `rollover_index_of`,
  `wrs_rollover`, `wrs_differ`, `wrs_same_range`.
- **P** (after the S0a block): `SIN_LISTS`, `SIN_PRACTICE_LIST`, `SIN_PRACTICE_SNR` 25, `SIN_LISTS_PER_CONDITION` 2,
  `SIN_CONDITIONS`, `SIN_CONDITION_TITLES`, `SIN_SLOTS`, `SIN_COURSES`, `SIN_AIDED_DB` 50, `SIN_BAND_NAMES`,
  `SIN_REMEDIES`, `SIN_PICK_WINDOW_DB` 15, `SIN_PICK_CAP` 3, `SIN_MISS_SHARES`, `SIN_LITTLE_SWAP_SHARE` 0.2,
  `SIN_LOST_EXPECTED` 0.25, `SIN_LOST_SHARE` 0.5, `SIN_LITTLE_WORDS`. Functions: `sin_slot`, `sin_babble_level`,
  `sin_snr_for`, `sin_count`, `key_word_sounds`, `key_word_miss_weight`, `is_trap`, `sin_average`, `sin_crit_diff`,
  `sin_real_change`, `sin_par`, `sin_forks`.

```gdscript
const SIN_AIDED_DB := 50     ## aided party tests in the sound field: about 65 dB SPL (check your calibration)
const SIN_BAND_NAMES: Dictionary[StringName, String] = {
	&"normal": "Near-normal", &"mild": "Mild", &"moderate": "Moderate", &"severe": "Severe"}
const SIN_REMEDIES: Dictionary[StringName, String] = {
	&"normal": "good habits", &"mild": "if aids: standard settings",
	&"moderate": "+ directional mics", &"severe": "+ a remote mic"}
```

#### §9.23.2 Build order (two parallel builders)

| Step | Who | What | Done when |
|---|---|---|---|
| S0a | W | §9.10.7 S0a: SpeechSim public helpers and `condition`, the empty facades, `SpeechMaterial.tokens()` and the validate additions, the "lists" rules block, the inputs, the Events block, `PHASES += counselling`, the CHAPTERS markers, the two `MOVIES` lines and stub movies | rebased on main; every existing test green; `test_all_scripts_compile` green; `Movies.validate` empty for both stubs; Day 3 autoplay identical (keys and `--mouse`) |
| P0 | P, after S0a | pure work in new files only: `party_*.json`, `SinModel` (against S0a's SpeechSim), `SpeechBabble`, the SpeechRules appends on a local branch, `test_speech_sin_model.gd` | the model's statistics tests pass (§9.24) |
| S0b | W, reviewed by P | §9.10.7 S0b: the base classes, C1-C23, H1-H28, the shared-widget hooks, `run_by_textbook`, `run_hidden`, the Daily Decibel hook, the `SPEECH.md` §6 rewrite, the INTEGRATION_NOTES patch | rebased on main; all of S0a's checks; `test_speech_seams.gd` green, including probe WRS and SIN SpModes that exercise every C-hook and H-hook; the Day 3 golden snapshot byte-identical with the probe modes loaded |
| W1 / P1 | each | rules appends and material, with their tests; W1 also applies amendments A1-A4 to the rules and A8 (the Day 3 sloping-loss text) | |
| W2 / P2 | each | the model behind the S0a facade | |
| W3 / P3 | each | the session mode (`WrsTest` / `SinTest`), sheets, summaries | session tests green; `run_by_textbook` reaches a sheet for every plan of §9.21; Day 3 untouched |
| W4 / P4 | each | the UI mode and widgets (P also `SpeechVoice`) | screen tests green at 1280x720 and 1920x1080 |
| W5a / P5a | each | the movie data without its `stage` line (every scene plays as its card) and its test; the level, boards, paper column, patient, CHAPTERS line (W5a first) | the movie test (cards step) and the level test green; autoplay `--day=4` / `--day=5` (keys and `--mouse`) green |
| W5b / P5b | each | the movie's sets script and the `stage` line | `Movies.validate(id, Stage2D.SETS)` empty; the dev scene's shots of every scene looked at (normal and `--reduced-motion`) |
| W6 / P6 | each | docs (their own `SPEECH.md` sections; W6 pastes this contract into `CONTRACTS.md`) | |

**Merge order**: S0a, then S0b, then whichever of W and P is ready first, then the other, with one exception: the
CHAPTERS lines merge W5a before P5a (marco `requires` nora, so P's line waits even if P is ready first). W5b and P5b
(the sets scripts) touch only their own files and merge in any order. After S0b, the
only shared lines are the marker regions, which are built to merge without conflict. Neither builder edits the
other's files or the S0 seams. A seam that turns out to be missing goes back through a small S0 follow-up PR that both
rebase on.

**As built (Day 4).** S0a, S0b, W1-W5b and W6 are done on the Days 4-5 branch, with main merged in twice (E1-E16, then
Day 12) and the Letter Choir from its movie step; the fallback for a late S0b was not needed.

**As built (Day 5).** P0-P6 are done on Day 5's own branch, which builds on Day 4's (with main merged in) and merges
with its PR: the party model and session mode, the babble, PARTY mode, the Party Problem movie with its own sets,
Marco's level, boards and paper, the bot's Day 5 checks, and the docs (`docs/CHAPTER5.md`, `docs/SPEECH.md` §5).

### §9.24 Test plan

Every random test uses fixed seeds (`SpeechSim.new(profile, seed)` for `seed in range(N)`), so a failure replays.

**`core/tests/test_speech_seams.gd` (S0b)**
- `test = srt`: `mode == null`, and `get_state()` keys are a superset of today's. A Day 3 scripted session gives the
  same trials, sheets and results as before S0 (a golden snapshot), also with the probe modes loaded.
- Probe `SpeechTestMode` and `SpMode` subclasses (in the test folder) for `wrs` and `sin` exercise every C-hook and
  H-hook once: `complete_list` runs `_complete_ear` and emits `speech_stored`; the probes claim every `MUST_CLAIM`
  action and an unclaimed one fails the test; `on_present` owns the voice call and its wait; `_emit_beat` routes a
  mode action through `mouse_for`; `_celebrate` names the slot; `words_left` and `recommended_start` come from the
  mode; returning to SRT restores base labels and glyphs; a WRS-to-SIN change unregisters the WRS anchors; deck groups
  place buttons by their ids and widths; `{key:...}` is filled in coach lines, tips and technique messages.
- A missing mode script (paths patched to nowhere): `mode_missing`, `present() == {}`, `run_by_textbook == {}`, and the
  screen emits `test_finished` with no sheet.
- `ensure_slot("both")`; `pta_for("both")` = the lower PTA; `build_results` units arithmetic with fake sheets.
- `slot` is present in `speech_presented`, `speech_stored`, the beats and `errors[]`.
- Freeing a session frees its mode; re-configuring frees the old mode; freeing a sim frees its models (`WeakRef`).
- The gate: `hoot_only` starts Hoot's turn with quick visit off and with `--full`; `hoot_first` uses the same gate.
- `validate()`: `spondee_a` unchanged; good and bad `chunks`, `asides`, `plural` and sentence items.
- The Daily Decibel: `_is_speech` true for a wrs-only and a sin-only result; a summary with `weather`, `subheads` and
  `sports_script` uses them; Day 3's paper is unchanged.

**`core/tests/test_speech_wrs.gd` (W)**
- **Rules** (CHAPTER4 §16; recomputed with A1-A4):
  - `wrs_level(15) == 55`, `wrs_level(40) == 75`; windows 50-60 and 70-80; `wrs_band(52) == &"very_poor"`,
    `wrs_band(56) == &"poor"`; the key-sound mix fills a list;
  - (A1) `wrs_predicted_min_interp`: 15 -> 82, 35 -> 66, 40 -> 60, 41.67 -> 58 (+- 0.01), 45 -> 54, 50 -> 48, 0 ->
    88, 80 -> 12; clamped below 0 and above 80; no PTA (NaN) -> 0; Nora's left best stays below it on every row of
    CHAPTER4 §2.2; and `wrs_predicted_min` unchanged (40 -> 76, 41.7 -> 64);
  - (A2) `wrs_rollover`: 52 then 12 louder -> index 0.77, rollover; 48 / 16 -> 0.67, rollover; 52 / 40 -> 0.23, none;
    a lower score at a SOFTER level, or a single list, gives no PBmin; `ROLLOVER_INDEX_CUTOFF == 0.45`; Day 3's
    `is_rollover` and `rollover_index` unchanged;
  - (A3) `wrs_differ` and `wrs_same_range`: 44% on 25 words -> 20-68, on 50 words -> 26-62 (the edges are the
    same, one step past them differs); 96 vs 52 and 92 vs 56 differ, 96 vs 88 and 52 vs 40 do not; Nora's 96 and 52
    bands do not overlap; no list, no verdict; `wrs_asymmetric` unchanged for Day 3's tests;
  - `ear_best_bone` on Nora's Hoot sheets (right ac, left ac, left bc_masked at 1k and 4k): left {500: 35 (air),
    1000: 40, 2000: 45 (air), 4000: 55}; `nontest_best_bone(right)` = 35, `nontest_best_bone(left)` = 10;
    `nontest_best_threshold` unchanged;
  - (D16, A4) `wrs_mask_level(75, 35, phones) == 55`, `(95, 35) == 70`, `(90, 35) == 70`, `(100, 35) == 70`,
    `(75, 35, phones, 10) == 65` (the other ear's gap adds), `(95, 35, phones, 10) == 70` (still capped),
    `(95, NAN) == 75` (no bone, no ceiling), `(100, 10) == 45` (the ceiling wins); `wrs_mask_capped`;
    `speech_mask_level` unchanged;
  - `lens_alpha(0) == 1.0`, `lens_alpha(-15) == 0.15`; `ghost_alpha(50, phones, 10) == 0.2`, `ghost_alpha(75, phones,
    10) == 1.0`;
  - `word_fully_audible` needs every chunk at 3 dB or more ("sock" on Nora's right at 55 is not: s is 0);
  - `wrs_referral`: asymmetric -> refer; rollover -> refer; below in one ear -> refer; below in both, nothing else ->
    "" with the flag.
- **Nora's chances** (truth, IA 50): `p_wrs_test(right, 55)` = 0.956 +- 0.005; left 75 masked 0.515 +- 0.005; left 95
  with noise 70 = 0.120 +- 0.005; left 75 unmasked `p_wrs` 0.70 +- 0.02;
  a crossed word is masked out once the noise reaches its level; and CHAPTER4 §2.2's rows (`test_nora_rows`).
- **List control**, 4000 seeds each for p in {0.956, 0.515, 0.120, 0.70}:
  - `|k - round(p x 25)| <= 1` always;
  - the share with `k == round(p x 25)` is 0.50 +- 0.03;
  - the mean k is within 0.08 of `round(p x 25)`.
- **Banana**: 2000 deals on Nora's right at 55 (cochlear): the per-word miss rate of s / f / th words is at least 4
  times that of m / n / l / r words. 2000 deals on her neural left: the high/low miss-rate ratio is 1.25 or below.
- **Cross-hearing**: masked lists never give `&"cross"`; unmasked, `k_total - k_test` matches the formula; a cross
  answer emits the reaction.
- **`ensure_audible_miss_by` 6** on `words_2` and `words_3` at 70, 75 and 80: k is unchanged; an audible miss lands in
  places 2-6 in 100% of 1000 seeds; it is the deal's `audible_target`.
- **`aside_by`**: k unchanged; the aside word is a miss within places 1..b with its aside foil as the answer.
- **Answers**: rhymes come from the item's foils; "other" is never the item or its foils; the silence share rises when
  A < 0.5; asides only on their foil; styles only on player words; chatty hits contain the word as a whole token and
  6 words or fewer of chatter; one plural trap per list at most; one self-correction on a `self_correct` list.
- **Session**:
  - a list ends itself after 25 scores; level and noise lock after word 1 (refusals observed once);
  - two lists on one ear don't collide; `is_done` per list; a reused list is refused; `louder_than` and `redo_of`
    read earlier lists across `start_test` calls; a louder list's dial starts at the comfortable list's level;
  - first-word errors and clean kinds as in §9.13.6; misscored messages by kind, including chatty, plural and
    self-correct;
  - verdicts are held: no `below_predicted` or `asymmetric` before the louder list on Nora's left;
  - sheet fields as in §9.15.1; `counts` and `redo_of`;
  - golf: a clean solo list with an unprompted textbook set-up is a birdie; a clean coached list is par; a BOO before
    M removes the tee bonus; a list with slips is never better than par;
  - Hoot's words are out of accuracy and units; `wrs_summary.referral` is `&"refer"` for Nora's truth and `&""` for
    Marco's;
  - `run_by_textbook` reaches a stored sheet for every Day 4 and Day 5 WRS plan with no screen.
- **Material**: 4 lists of 25; ids unique; `chunks` join; `WRS_KEY_MIX` holds per list; no repeats; Word list 1 in
  CHAPTER4 §6's order; the audible-word rule; "bike" has the foil "Mike", and "hook" takes exactly "Hoot", "hoof" and
  "hood" (its last sound changes, never its first); the content rules; the own-material originality guard (§9.11.1).

**Day 5's core tests, as built** (CHAPTER5 §14 lists them in full):
- **`core/tests/test_speech_sin.gd` (rules and material)**: `snr_loss(16)` 9.5, `snr_loss(20)` 5.5 and `snr_loss(t)
  == (30 - t) - 4.5` for every t (the "missed minus 4.5" identity the bill line teaches); `sin_band` at 3.0 / 3.5 /
  7.0 / 7.5 / 15.0 / 15.5; `sin_level(21.7)` 70; `SIN_AIDED_DB` 50; slots, levels and SNRs; the dithered count; key
  sounds and miss weights; `is_trap` with the irregular forms (`test_traps`); averages, `real_change`, par and forks;
  (A7) `SIN_BAND_NAMES[&"normal"]` is "Near-normal", and no Day 5 file reads `SIN_BAND_TITLES` or `SIN_HELP` (a grep
  test); the material's shape (`test_party_lists_shape`), the `key_sounds` overrides and the originality guard of
  §9.11.2 (`test_party_notes_say_written_fresh`, `test_party_material_is_our_own`, `test_party_lists_teach_traps`).
- **`core/tests/test_speech_sin_model.gd` (the model)**: Marco's numbers (PTA 21.7 / 23.3, better ear right,
  `directional_benefit` 4.0, `snr_loss` 9.0) and the loss sources; `sin_expected_words` at each SNR (to 0.01) for
  losses 9.0 and 5.0; 4000 dithered lists average 16.49 +- 0.1, never more than 1 from the expected count; two lists
  land within 1.5 dB of 9.0 in at least 99% of 2000 seeds, the unaided band is moderate in at least 99.5%, FOCUS within
  1.5 dB of 5.0 in at least 99%, and the 2-vs-2 benefit is above 2.7 in at least 93% and at most 98% (exactly 95.0%
  from the dithered count distributions; the honest "another list each" path still happens); heavier key words go
  first (ratio at least 1.5 at SNR 15); answers keep what he heard, traps are misses, lost lines come only with count
  0; the same seed replays a visit; per ear and both; the model holds its sim weakly.
- **`core/tests/test_speech_sin_session.gd` (the session mode)**: it loads by path; nothing to mask; `state()` is
  never truth; the present / mark / flip / all-got / lock flow, present refused before LOCK IN, blanks lock as missed,
  the walk wraps; per-chip checks and lines; `recommended_action` with a wrong mark gives `key_fix`; the player's level
  is checked at the first scored sentence; the practice is never stored; `hoot_first` unscored and `level_first`
  starting Hoot's turn at the player's first PRESENT; `level_by_hoot` locks the dial and skips `sin_level` and the tee
  bonus; aided sheets at 50 with no band, no remedy and the label "aided, sound field"; units and Hoot's lists at 0;
  party golf (list 2 can birdie; lists 1, 3 and 5 top out at par); `act(&"prompt")`; the FOCUS benefit and
  `real_change`; `run_by_textbook` reaches a stored sheet for every Day 5 plan with no screen; a whole Day 5 visit on
  one session; a list is used once; moments once per visit; the hidden loss; the per-ear summary; the lines fit and
  name keys; the mode is freed with its session.

**`core/tests/test_speech_voice_babble.gd` (P)**, as built: the loop builds in under 400 ms headless; unit RMS and
capped peaks (`CREST`); the party keeps going over the loop; the same seed replays; the recording path and helpers;
the babble RMS on the masker mapping (`masker_to_rms(db - 5)`, the word RMS at SNR 0); babble under
`MASKER_CEILING_DBFS` and the mix never above -12 dBFS (talker 90, SNR 0); "both" writes both channels and "right" /
"left" only theirs; the babble stops on stop, exit and pause.

**`ui/tests/test_speech_screen_wrs.gd` (W)** and **`ui/tests/test_speech_screen_party.gd` (P)**
- The mode's layout: anchors on screen and clear of Hoot at both resolutions; hidden base widgets; deck groups.
- Keys and the mouse each finish a list: the solver path, the `--mouse` route of every beat, and a stale solver as a
  no-op.
- Hoot's turn: x8 set and restored exactly; hand-back at `hoot_first`; the Hoot-done key per list; PARTY keeps the
  murmur and the babble silent during Hoot's turn (`hoot_running()`).
- Swap-arrows: only level swaps, and every coach line renders the right key in both styles.
- WORD: no STORE; the two-press confirm with the BOO chip (solo) and denial (coached); no lurk on solo lists; V and
  the button toggle the lens; the word is always drawn crisp and the lens row is a second row; the lens alpha equals
  `lens_alpha(sound_margin(...))` on MEASURED thresholds and ignores truth; the Banana Board slides in at the first
  lens press; no band ruler before a list ends; the Call it card at the right word with both inputs and both buttons;
  the tea demo neither presents nor locks; asides never emit a blocking beat.
- PARTY: chip click cycle, right-click misses, 1-5 flips, G all-got, S / Enter lock; MASK hidden; level locked
  mid-list and from the start with `level_by_hoot`; the mouse coach line after a click. As built
  (`test_speech_screen_party.gd`): a party list by keys and one by mouse at 1920; no PARTY widget overlaps another at
  1280x720 or 1920x1080; marks refused before the answer; beat info, solvers and a stale solver; `hoot_first` three
  courses then hands back, `level_first` then `hoot_first`, the practice by Hoot at x1, `hoot_only`,
  `hoot_turn_after`; a slip line replaces the little-words tip; a second list on "both" gets its own Hoot turn; no
  takeover without quick visit; SRT -> PARTY -> SRT restores the layout; a WORD probe then PARTY drops its anchors.
- Reduced motion: no shake, scramble or waiter ride.
- **Day 3 regression**: `_mode == null` with an SRT plan, and the Day 3 deck layout snapshot and anchor list are
  unchanged.

**Story and content tests (W and P)**
- `story/tests/test_level_nora.gd` and `test_level_marco.gd` (CHAPTER4 §16 and CHAPTER5 §14). As built, Marco's
  covers the movie announced only when unseen, `party_plan` (lists 1-2 unaided with phones or inserts, A and B in the
  sound field at 50 by Hoot, `hide_loss` on list 1 only, `hoot_only` on lists 4 and 6, quick visit on and off), a
  textbook visit's sheets, the bill, the band ruler, the plates (keys, drag, click-then-click, solver), the pizza,
  the switch and the reveal, the seats, the dinner, the party golf card, the paper fitting the window, and every line
  (A7's three pinned).
- The movie tests of §9.20.
- **Lines**: every Hoot line in the new TIPS tables, levels, boards and movies is 18 words or fewer with tokens at
  their longest; every key named in a line is a `{key:...}` placeholder.
- **No diagnosis**: no string in the new files contains "tumour", "tumor", "neuroma", "schwannoma", "cancer",
  "growth", "stroke" or "Meniere".
- Day 5's paper contains no "beeps" and no "spondees".
- `test_vendor_free.gd` covers the new files (no product-line or product names); `test_contracts_speech.gd` gains the
  new state keys (assert-has style).
- Autoplay: §9.22 runs, including Day 5 with `--full` (Hoot's SRT and WRS stay Hoot's).

#### §9.24.1 Worked numbers the tests pin (recomputed with A1-A4)

| Case | Number | Source |
|---|---|---|
| Nora right, 55 dB, no noise | p_test 0.956, 24 words (96%, 92-100), excellent; (A1) predicted at least 82 | CHAPTER4 §2.1 |
| Nora left, 75 dB, noise 55 | p_test 0.515, 13 words (52%, 48-56), very poor; (A1) predicted at least 60 | CHAPTER4 §2.1 |
| Nora left, 95 dB, noise 70 (clamped from 75) | p_test 0.120 (rollover drop 0.40), 3 words (12%, 8-16); (A2) rollover index (52 - 12) / 52 = 0.77 (worst deal 48 / 16: 0.67) | CHAPTER4 §2.1 |
| Nora left, 75 dB, unmasked (IA 50) | p_test 0.515, p_cross 0.385, p_wrs 0.702, 18 words (72%, 68-76): the Ghost helped, so the list does not count | CHAPTER4 §2.3 |
| Nora rows by measured left PTA | 70 dB: 52% then 20% at 90 (index 0.62, worst 0.50); 75 dB: 52% then 12% at 95 (0.77, worst 0.67); 80 dB: 40% then 0% at 100 (1.00, worst 0.89) | CHAPTER4 §2.2 |
| Nora predicted minimum (A1, interpolated) | right 82; left 60 at PTA 40, 58 at 41.7, 54 at 45, 66 at 35 | CHAPTER4 §2.2 |
| Nora flags | left best 52 < 60 (below predicted); (A3) asymmetric: 96's chance range 80-100 and 52's 28-76 do not overlap (the worst deal, 92 vs 56, too); (A2) rollover, index 0.77 >= 0.45: REFER | CHAPTER4 §7 |
| Nora noise | List 2: 75 - 40 = 35 >= 10 (the right ear's best), noise 55 ((A4) her right ear has no air-bone gap to add); louder: 70, clamped by 35 + 40 - 5 | CHAPTER4 §2.1 |
| Marco WRS (Hoot) | right 96% (92-100); left 92% (88-96; 88 reads "good"); masking on the line at 55 (noise 35) and needed at 60 (noise 40) | CHAPTER5 §2 |
| Marco unaided, 70 dB HL | expected 4.99 / 4.92 / 4.30 / 1.94 / 0.31 / 0.03 = 16.49, SNR loss 9.0, moderate (99.95%) | CHAPTER5 §2 |
| Marco FOCUS (benefit 4.0), 50 dB HL | loss 5.0: expected 5.00 / 4.99 / 4.87 / 3.98 / 1.44 / 0.20 = 20.47; lists 20 (45%) or 21 (40%); benefit > 2.7 in 95.0% (exact) | CHAPTER5 §2 |
| The 25.5 | SNR-50 = 25 + 5 / 2 - total; SNR loss = SNR-50 - 2 = 25.5 - total = missed - 4.5 | §9.15.2 |
| Typical diner (loss 0) | about 25 right: 0.5 dB, Near-normal (A7) | CHAPTER5 §4 |
| Babble at SNR 0 | the party's RMS equals the talker's (trim -5 dial dB) | §9.16 |

Day 3's numbers do not move: the old `WRS_PREDICTED_MIN` / `wrs_predicted_min`, `is_rollover`, `rollover_index` and
`wrs_asymmetric` keep their pins for Day 3's tests, and no day reads them.

#### §9.24.2 Open questions for Steve (the contract's)

"Open question N" in §9.10-§9.24 means this list. The Day 4 ones are also in `docs/CHAPTER4.md` §17 (its number in
brackets), and the clinical review's A6 added CHAPTER4 Q27-Q31: Dubno's 25-word lower limits (to replace A1's rows),
the rollover-index cut-off, critical differences or a fixed cut-off, the WRS level rule, and the referral's urgency.

1. **List control.** The game deals each word list to round(p x 25) +- 1 words, and a party list's SNR loss wobbles
   with an SD of about 0.77 dB. Real lists wobble about twice as much (25-word binomial scores; about 1.4 dB for a
   party list, which is where the 2.7 / 3.9 dB critical differences come from). The lines say "One list is a rough
   guess. Two make it solid." The ear compare now draws each best's chance range (A3); should a single score show
   its spread too?
2. **25 words or 10 x 3 phonemes** (CHAPTER4 Q2). Lists are 25 words scored whole at 4% each, with 90 / 78 / 66 / 54
   bands: a US convention. Many UK and Australian clinics use 10-word lists scored by phoneme (30 phonemes). Which do
   you use? If phonemes, should Word lists 1-4 switch to 10 words x 3 phonemes?
3. **The key-sound mix.** Every list has the same mix of key sounds (s 3, f 2, th 2, t 2, k 2, and one each of the
   rest). Is that a fair way to make the four lists equally hard?
4. **Scoring rules** (CHAPTER4 Q24). For a word: a rhyme or a plural is a miss; the word inside a chatty sentence is
   a hit; a self-correction counts its final answer (a hit). For a sentence: a plural or tense change on a key word is
   a miss, and little words never count. Do these match your clinic?
5. **One level per list.** Level and noise lock after the first word, and a wrong set-up means a new list instead of
   a fix in the middle. Is that right?
6. **The louder list and its noise** (CHAPTER4 Q8). It is a fresh list 20 dB above the comfortable one (15-25
   accepted), with the noise kept on at level - 20 (plus the other ear's air-bone gap, A4) but clamped to [level - IA,
   test-ear best bone + IA - 5]: 70 instead of 75 at 95 dB for Nora. Is that the check and the clamp you would teach?
7. **The lens and the 3 dB rule** (CHAPTER4 Q18). The lens uses the measured audiogram and the game's simplified
   sound map (`SOUND_CUES`). A sound counts as audible at 3 dB or more above threshold; 0-3 dB is drawn as "only
   just"; the fade covers 15 dB below. Honest enough to teach with?
8. **Bilateral below-predicted.** A score below the predicted minimum in both ears, with nothing else, gives no
   referral in the game (it is common with cochlear loss in older adults). One ear below, an asymmetry or rollover
   refers. Is that your line?
9. **The predicted minimum** (A1; CHAPTER4 Q4 and Q27). The game interpolates between the rows of
   `WRS_PREDICTED_MIN_25` (PTA 0 -> 88, 20 -> 80, 30 -> 72, 40 -> 60, 50 -> 48, 60 -> 36, 70 -> 24, 80 -> 12), a game
   approximation of Dubno et al. (1995)'s lower limits, so Nora's PTA of 40 gives 60 and a measured 41.7 gives 58.
   Please give the published 25-word values so the rows can be replaced, and say whether interpolating is fair.
10. **Red flags to REFER only** (CHAPTER4 Q11, Q12 and Q31). Word-score flags lead to "refer soon", with imaging
    requested in the letter before any fitting, never to "doctor today" from word scores alone. Is that the right
    line, and is "soon" right for your service?
11. **Which key words go first.** In noise, the words with soft high sounds are missed first (weight 1 + up to 3 such
    sounds). Is that a reasonable simplification?
12. **Per-ear party tests** ignore cross-hearing. Is that acceptable for the game, or should a per-ear party test ask
    for noise in the other ear?
13. **The babble level.** The party is on the same level scale as the talker, so 0 dB SNR means equal loudness. Any
    concern about how that sounds through home headphones?
14. **Golf, one rule** (CHAPTER4 Q20). On both days a clean list is a birdie only when the player made its set-up
    unprompted on a solo list; coached lists and lists whose level Hoot set top out at par. Fun and fair?
15. **A carrier phrase** (CHAPTER4 Q13). Neither test uses one ("Say it back" is the instruction, not part of each
    item). Should a carrier come in with recordings later?
16. **"Right noise decision".** The tee bonus needs noise exactly when the rule says. Should noise when it isn't
    needed (harmless here) also earn the bonus?
17. **Aided level.** Aided party tests run at 50 dB HL in the sound field, which we take as about 65 dB SPL, set by
    Hoot: talker in front, party behind, the same for OMNI and FOCUS. Is that level and set-up what you would teach?
    (A7) The 4.0 dB directional benefit stays, and Hoot says the booth is kinder than a real restaurant.
18. **How close is too close.** The Party Noise Test keeps a familiar structure: 6 sentences of 5 key words, SNR 25 to
    0 dB in 5 dB steps, four-voice babble, 25.5 - total, bands at 3 / 7 / 15 dB and 2.7 / 3.9 dB critical
    differences. Our sentences, babble, band names and remedies are our own, and Hoot says real clinics use normed
    tests. Are you comfortable with that, or should the structure move further away?

#### §9.24.3 Design notes (critique points not taken, or taken differently)

1. **A self-contained movie shell scene with `start()` / `finished(skipped)`, and a `seen_explainers` shim** (fun 4,
   engineering 1). Not built: the shared player already plays MOVIE data with those controls, and `movies_seen` /
   `Game.is_movie_seen` already record it. A second shell would be a third control scheme to keep in step.
2. **CHAPTER5's shot 7a/7b as one scene with two captions** (engineering 1). Split instead into two scenes (`menu`,
   `receipt`), so each caption gets its own 8 s scene (clinical 22) while the title shot is folded into scene 1 (fun
   17). The contract's movie is 8 scenes and 65 s, not the 9 shots and 73 s that clinical 22 estimated. As built it is 8
   scenes and 71 s, with Steve's lead-in on scene 1 (§9.20).
3. **The suggested cues for the topple and the EAR DOCTOR door** (engineering 3). Moot: those scenes were cut (fun 3).
   The rule itself is applied to every remaining cue.
4. **`hoot_only` for Day 5's two WRS lists** (engineering 8). The key and the gate are added, but Day 5's WRS (and
   SRT) run off-screen through `run_hidden` (fun 2), which never depends on quick visit. `hoot_only` is used for
   Day 5's lists 4 and 6.
5. **Rewording `SIN_BAND_TITLES` and `SIN_HELP` in place** (clinical 5 and 10). Shared files take additive changes
   only, so new constants (`SIN_BAND_NAMES`, `SIN_REMEDIES`) carry our wording and a test keeps new code off the old
   ones.
6. **Moving the Party Noise Test's structure away from the published design** (clinical 5, implied). Kept: the 25-to-0
   dB steps, the 6 x 5 key words, the 25.5 and the 3 / 7 / 15 bands are already the shared rules in
   `docs/SPEECH.md` and `speech_rules.gd`, and the structure is a general Spearman-Kärber design. Everything that is
   material (sentences, babble, names, remedies) is ours; the derivation, a Hoot aside and open question 18 go to
   Steve.
7. **"The 80 row gives 100 dB -> 4%"** (clinical 6). By the rules it is 0% (0-4): p = 0.0199, 0.0199 x 25 = 0.50, which
   rounds to 0. The row is still rollover (index 1.00, worst 0.89).
8. **A product-line dome name** (clinical 9). Not used: the fitting says "vented domes", and the benefit is 4.0 dB
   with the honest "another list each" path for the 5% of runs under 2.7 dB.
9. **The player setting the sound-field level on list 5** (fun 12). Not taken: Hoot sets every aided list at
   `SIN_AIDED_DB` (clinical 4), and the player's level skill stays on the unaided earphone test. Day 5's birdie is on
   list 2 only.
10. **Bilateral below-predicted as a referral** (clinical 20). Taken as asked: no referral on its own, a flag, and open
    question 8.
11. **The bot patch inside `tools/autoplay_bot.gd`.** Not applied by the W and P feature steps (engineering 4): it
    went to `tools/INTEGRATION_NOTES.md`. Day 4's part was then applied in `# (Days 4-5)` blocks so `--day=4` could
    run (§9.22), and the notes list it.
12. **Engineering 2's stage files** (`story/explainers/stages/<id>_stage.gd` extending `explainer_stage.gd`, a
    `MOVIE_SETS` constant, dev preview subclasses, and a hook note asking the main thread to route our sets). Not
    needed: the per-movie sets hook (§3.4) does it. A movie names its sets script in `MOVIE.stage`; the script extends
    `explainer_sets.gd` (a `RefCounted` with no `SETS` of its own), so the list must be called `SETS` and nothing is
    shadowed. The files are `stages/letter_choir_sets.gd` and `stages/party_noise_sets.gd`, the shared
    `dev_explainer` shoots them (no preview scripts), and no hook note is needed. Card params stay on every scene, as
    asked: they were the W5a / P5a cards and are the fallback for any set the script does not draw.
13. **Engineering 2's "set ids unique across movies" test.** Dropped: the stage asks only the playing movie's sets
    script, so only a clash with the built-in `SETS` matters (a built-in would win). The sixteen ids are unique anyway.
14. **Fun 4 and engineering 1's player controls** ("Space / Enter / click = next scene", buttons "Next scene" and
    "Skip movie"). The shared player has dialogue-style advance and the "Next" / "Skip movie" / "II" buttons; §9.20
    follows the player, so Days 2, 4 and 5 keep one control scheme.
15. **Fun 4's "self-contained shell scene, playable with `start()` and `finished`"** from the task brief is not built
    for the same reason as note 1: the shared player is the shell, and `play()` / `finished(result)` are its API.

---------------------------------------------------------------------------------------------

## §11 Cases (patient case files, Days 6 onward)

Design: `docs/CASES.md`. Full scripts: `docs/CASE_SCRIPTS.md` (generated from the JSON by `tools/case_scripts.py`).
(§9 is speech, Days 3-5; §10 is left free for a chapter in flight, so section numbers don't collide when branches merge.)

**Files.**

| What | Where | Owner |
|---|---|---|
| Case data, one per case | `story/cases/<case_id>.json` (the source of truth for every line) | cases |
| Patient truth tables | `core/patients/<patient_id>.tres` (sensorineural cases: no bone data, bone = air; conductive cases carry `bc_right` / `bc_left`, both for gaps in both ears (Day 13); a deaf ear (Day 12) puts its air past the dial, up to `ClinicRules.max_db(f) + 30`, so masked tests store no response). A retest profile `<id>_after.tres` (the ear after treatment) is loaded by the runner and never registered as a chapter | cases |
| Runner (one for every case) | `story/level_case.gd` + `.tscn` | cases |
| Loader and checks | `story/case_data.gd` (`CaseData`, preload by path) | cases |
| Rules | `core/cases/case_rules.gd` (`class_name CaseRules`): decisions, red flags (2022 labeling), asymmetry, the sudden-loss definition, tympanogram types and curve | cases |
| Case board, tymp gadget, hours clock, payoff props | `story/games/case_board.gd`, `case_tymp.gd`, `case_clock.gd`, `case_props.gd` | cases |
| The look in the ear (healthy drum, wax plug, fluid) | `story/games/case_otoscopy.gd` (extends builder B's `otoscopy.gd`, overrides `_draw_canal`) | cases |
| Portraits from a case's look | `story/case_portraits.gd` | cases |
| 3D costume bits | `world/characters/case_extras.gd` (`CaseExtras.attach(bean, spec)`) | cases |

**Registering a case.** One `Game.CHAPTERS` entry per case, scene `res://story/level_case.tscn`, with the extra keys
`case` (the JSON id), `face` (the portrait speaker for the day picker) and `tint` (the card colour). `requires` only picks
the suggested ("UP NEXT") day; every day is open. `LevelCase.pick_case_id()`: the chapter's `case`, else `--case=<id>`,
else the first registered case.

**Phases** (`Events.phase_changed`): `intro`, `history`, `otoscopy`, `tymp`, `instructions`, `audiometry` (one per
test, info `{ear, test}`), `reveal`, `evidence`, `decision`, then `retest` for a case with a retest block, and
`results`. Inside the retest, `otoscopy`, `tymp`, `instructions`, `audiometry` and `reveal` repeat with
`info.retest = true` (the bot suffixes those phase shots `_retest`). `Game.PHASES` gained `tymp`, `decision` and
`retest`. **(Clinical review C12)** An `explainer` phase `{movie, source: "case", first_case}` comes before
`intro`, `tymp` and `reveal` when Hoot's case movie for that step (`LevelCase.CASE_MOVIES`: `case_files`, `tymp`,
`shapes`) has not been watched yet: on the first case it plays after Hoot's lead-in; on a later case Hoot offers it
(a `choice` beat, best = watch). The movie itself is the standard `explainer` beat (§3.4); the retest has none.
Visit flags `movie_<id>` (watched to its `seen_at` scene).

**Optional case keys (batch 2; all default to the Days 6-9 behaviour).** `otoscopy.view` `clear` / `wax` / `fluid`
(a wax view keeps the first visit's air on headphones); `otoscopy.kind` and `findings[].kind` `clue` / `flag`;
`tymp.<ear>.ecv_ml` (required: any type but B inside the adult band 0.6-2.0 mL; a B reads with it); `findings[].when`
`symmetric` / `asymmetric` / `conductive` / `abg_flag`; `reveal.pattern` `gap` with `reveal.plug` `wax` / `fluid`;
`audiometry[].montage` (Hoot's alone: `hoot_turn_after` 0) and `skip_hoot_retest`, passed to the AudiOtron's plan;
`audiometry[].if_tested` `{"750": script}` on a first-visit air step (750 only: E1 made 1.5k, 3k and 6k routine), said after that step once the
ear's stamps asked for that frequency and it is on the chart (Ginger's 750 Hz);
`do` `wax_jar` / `plane`; `paper.wrong_first` `{fit / refer / today: {headline, subhead?}}` for each wrong first
stamp; `retest` `{patient_id, card?, intro?, otoscopy?, tymp?, before?, instructions?, audiometry (air only),
reveal {ear, label?, title?, lines?}, payoff?}`. When `reveal.ear` is right or left, unmasked bone goes on the better ear only; the runner then masks bone on each ear
whose air sits over it (`CaseData.masked_bone_ears`, as on Day 2).
**(Day 12, clinical review C10)** `findings[].when` `shadow` (most of the case ear's masked air stamps are no response
where its unmasked air answered; `CaseData.shadow_shows`) and `no_response` (every masked air stamp, and every masked
bone stamp if run; `CaseData.no_response_shows`); `reveal.pattern` `shadow` (the board redraws the unmasked answers
as a dashed line with the Ghost); `decision.asymmetry_known_cause` (bool: a FIT with one ear worse, for a known,
doctor-checked, unchanged cause; a test allows an asymmetric FIT only with it). `CaseData.measured_type(res, ear)`
types an ear with no-response bone dropped (the chart's `hearing_type` reads a deaf ear as mixed); the runner and
`finding_shows` use it. After masked air, when every masked air stamp on an ear is no response, Hoot says
`LevelCase.NO_PLATEAU`.
**(Day 13, clinical review C9)** `on_dilemma` (a script) and `lend_inserts` (bool; needs `on_dilemma`, never with a
wax view): before each masked bone test the runner reads the noise window from the stamps
(`CaseData.bone_mask_window(res, ear, f, masker)` -> `{initial, limit, raises, dilemma}`, mirroring the session;
`CaseData.dilemma_freqs`); the first time one opens in a masking dilemma or with fewer than `PLATEAU_STEPS` safe
raises (so before any purple ? can show) it plays `on_dilemma`, then, with
`lend_inserts` and no inserts owned, lends Hoot's for the rest of the visit (`CaseData.air_transducer(blocked, lent)`,
`LevelCase.LEND_INSERTS`; never `progress.upgrades`). Visit flags `dilemma_told`, `lent_inserts`.
`findings[].when` `no_plateau` (a masked stamp on either ear carries `plateau_not_reached`; on the truth, an inserts
window with fewer than `PLATEAU_STEPS` safe raises; `CaseData.no_plateau_shows`); `reveal.plug` `stiff` (the board
drops a padlocked stirrup into the gap, "STUCK!"); a `gap` reveal with `ear` `both` dims neither ear. After the masked
tests, when Hoot stored a purple ?, he says `LevelCase.NO_ROOM`.
**(Clinical review C13, A4)** `speech_check` (`{ears: ["right", "left"] (one or both, default both), after: script}`):
after the tones and before the reveal, the HUD's Words step: Hoot's SRT and word score (`SpeechRules.WRS_LISTS` in order) on
each ear, then one unaided Party Noise Test list in both ears, run off-screen (`SpeechScreen.run_hidden`, unscored);
`LevelCase.speech_lines` / `speech_clues` turn the sheets into Hoot's two lines (`SPEECH_WORDS` or `SPEECH_WORD`,
`SPEECH_NOISE`) and the cards `words` and `sin`. Used before a FIT call only (Rocco, Ginger).
`CaseData.validate` type-checks every key before reading it (a broken file returns problems, never a script error),
checks every script's speakers, Hoot emotes and props (`story/tests/test_cases.gd` checks reaction names against
the clinic's `REACTIONS`), and the runner goes back to the title on any problem.

**Beats.** No new beat kinds. Everything is `dialogue`, `choice` (history, tip, tymp question, shape, earplugs,
the stamp tray, the clue cards), the AudiOtron's own beats, and `results_continue`. The stamp tray
(FIT / REFER / DOCTOR TODAY) and the tip sizes (Small / Medium / Large) keep a fixed order; every other choice is
shuffled with `Game.rng` and `info.best` follows the shuffle. Stamp and card buttons are flat Buttons whose Label children start with
the option text, so the mouse bot clicks them by their first 18 characters (tests keep those prefixes unique).

**Hooks in other modules (all additive).**
- `world/clinic.gd`: `var patient_spec: Dictionary` (a full bean spec from `CaseData.bean_spec`); when set, the
  patient is built from it and `CaseExtras.attach(patient, patient_spec)` adds the costume bits.
- `story/portraits.gd`: unknown speakers fall back to `CasePortraits` (name colour, frame background, drawing),
  so a new case needs no portrait code. A case's extra speakers (`voices`, e.g. Chip) can use `"portrait": "cookie"`.
- `story/voice.gd`: `Voice.register(speaker, {f0, wobble, roll, vowels})` gives case speakers a babble voice.
- `story/daily_decibel.gd`: the summary may carry `headlines`, `subheads` and `medal_beats`; they win over the
  per-chapter tables.

**Visit and medals.** Medals `history` (Chat), `tymp` (Tymp), `evidence` (Pattern), `decision` (Call). Visit flags:
`case_id`, `asked_red_flags`, `tymp_tip_tries`, `decision_first`, `decision`, `decision_tries`, `clue_tries`, and with a
retest `retested`, `retest_type`. The retest has no medal and is unscored: a case with a retest calls `finish_visit`
before it (so quitting during the retest keeps the day), and afterwards the first visit's results are restored
(`Game.set_audiometry_results`) and any heart lost during it is given back (`Game.gain_comfort`). The summary gains `case_id`, `headlines`, `subheads`,
`medal_beats` (a wrong first stamp swaps the S to C headlines, `LevelCase.paper_for`).

**Anchors.** `reveal_audiogram` (the board's chart), `case_stamps`, `case_clues`.

**Screenshots** (with `--shots`): `case_<id>_intro`, `_otoscopy`, `_tymp_sweep`, `_tymp_curves`, `_reveal`,
`_pattern`, `_case_file`, `_stamp`, `_exhibit`, `_hearing_aids` / `_letter` / `_boat` / `_wax_jar` / `_plane`,
`_goodbye`; a retest adds `_retest_later`, `_retest_otoscopy`, `_retest_tymp`, `_retest_chart`, `_retest_goodbye`.

**Tests.** `story/tests/test_cases.gd`: every registered case validates (`CaseData.validate`), Hoot lines are 18 words
or fewer, choice prefixes are unique, each truth table shows its shape even with any single 5 dB wobble, asymmetry
and the call match, Dash meets the sudden definition, the charts on file, tymp curve widths, the red-flag list,
picker teasers give nothing away; batch 2: the 0.6 mL blocked floor and canal-volume bands, the conductive truths
survive a wobble and mask bone but not air, no shipped case gains a masked test, script names (reactions, emotes,
props, speakers), patients match their chapters and validate, flat tymps read their canal volume, every new
validate rule and broken file is reported, the retest profile, finding conditions, wrong-first headlines,
`merge_retest`, the runner's own lines, headphones with wax, and the new gadgets draw; Day 12: the shadow and
no-response findings, masked bone then masked air to no response with phones and inserts, and the known-cause FIT;
Day 13: the dilemma windows under any single wobble, masked air by each stamp's transducer, the loan, and Bev's
findings on the truth and on a clean run. `tools/run_tests.sh` also
fails when `docs/CASE_SCRIPTS.md` is stale.

---------------------------------------------------------------------------------------------

## §12 Freestyle (the walk-in clinic)

Design and Steve's checklist: `docs/FREESTYLE.md`. Practice outside the story: the title's **Freestyle** button opens a
waiting room of walk-in patients; the player picks the tools in any order, then charts and makes the call.

**Files.** Everything lives in `story/freestyle/` (owner: freestyle): `fs_rules.gd` (`FsRules`, preload by path: the
question deck, the workup a pro runs, masking needs, medals), `fs_data.gd` (`FsData`: loader and validator,
`CASE_IDS` in waiting-room order), `waiting_room.gd/.tscn` (the hub), `level_freestyle.gd/.tscn` (one runner for
every walk-in), `fs_tray.gd`, `fs_questions.gd`, `fs_clipboard.gd`, `fs_chart.gd`, `fs_debrief.gd`, and
`cases/<id>.json`. Truth tables: `core/patients/fs_<id>.tres` (same conventions as §11). Ids start with `fs_`.

**Not chapters.** Walk-ins are never in `Game.CHAPTERS`, never on the Days grid and never in `chapters_done`.
The waiting room and the runner set `Game.current_chapter_id` to `FsData.NOT_A_DAY` (`"freestyle"`), so the pause
menu (E19, `Movies.for_level`) offers the replay movies, the masking movie among them, never a leftover day's own.
The waiting room hands its pick to the runner in the Engine meta `freestyle_next_case`; `--freestyle=<id>` wins.
The best result per walk-in is stored inside the save's patient record: `progress.patients[<id>].fs_best_grade`
and `fs_best_score`.

**Reused, not copied.** The AudiOtron (`start_test` plans, never coached), the clinic, `CaseRules` (tymp types, red
flags, asymmetry, decisions), `ClinicRules` (types of loss, masking rules, PTA), the story tympanometer gadget
`story/games/case_tymp.gd` (the tray hides the Tympanometer when that file is missing) and the Daily Decibel.

**Phases** (`Events.phase_changed`): `freestyle_room`, `intro`, `freestyle_tray`, `history`, `otoscopy`, `tymp`,
`audiometry` (info `{ear, test}`), `freestyle_chart`, `decision`, `freestyle_debrief`, `results`. `Game.PHASES`
gained `freestyle_room`, `freestyle_tray`, `freestyle_chart`, `freestyle_debrief`.

**Beats.** No new beat kinds: everything is `dialogue`, `choice`, the AudiOtron's own beats and, for the masking
recap, `explainer`. The waiting room's
pick, the tool tray, the question board and every clinic choice (tip, tymp type, ear first, mastoid, masked test,
chart type, the stamp) are `choice` beats whose `best` is the pro's pick (`FsRules.best_tool`). Buttons start
with their option text, so the mouse bot clicks them by their first 18 characters (tests keep them unique). While
Day 2's masking movie is unseen, the visit's first masked test plays the one-card `masking_recap` first (the
`explainer` beat, as on Day 2; clinical review A2).

**Visit and medals.** Medals `fs_chat` (Chat), `fs_workup` (Workup), `fs_chart` (Chart), `fs_call` (Call). The
paper's score is 60 % medals (gold 100, silver 70, bronze 40) and 40 % the visit's own score. Summary keys:
`freestyle_case`, `visit_score`, `headlines`, `subheads`, `medal_beats`, `continue_text` ("Waiting room"),
`continue_scene` (the waiting room), `next_chapter_id` "" and `first_clear` false. Visit flags:
`freestyle_case`, `freestyle_asked`, `freestyle_tip_tries`, `freestyle_types`, `freestyle_tymp_misreads`,
`freestyle_slips`, `decision_first`, `decision`, `decision_tries`.

**The AudiOtron between tests.** One screen per visit. Between tests it stays in the tree (its Hoot anchors are
registered once) but is hidden and `PROCESS_MODE_DISABLED`, unregistered from `Stage.audiometer`, with the booth
view off and the music back; the next test re-registers it. It is freed when the patient walks to the desk.
So one `AudiometrySession` covers the whole workup, and (E2) only the visit's first air ear owes the 1 kHz retest
(the second too after a first-ear mismatch over 5 dB). `LevelFreestyle.air_plan()` and `bone_plan()` never set
`skip_hoot_retest`: the screen waives the retest per ear, not per test, so a bone run before air would cost that
ear its air retest (FS-07).

**Hooks in other modules (all additive).**
- `story/title_screen.gd`: the **Freestyle** button (`FREESTYLE_SCENE`) after Days; Options and Quit share the last
  row (Up/Down and Left/Right walk the buttons in order) so six buttons still clear the safety footer.
- `story/case_portraits.gd`: `CasePortraits.register(who, look)` (walk-ins aren't chapters, so they register).
- `story/daily_decibel.gd`: the summary's optional `continue_text` labels the main button (default "Back to the title";
  keep it short, the paper must fit 1280 px).
- `tools/autoplay_bot.gd`: `--mouse` clicks `continue_text` and counts `continue_scene` as being back;
  `--via-freestyle` presses the title's Freestyle button; the report gains `freestyle` {case, medals, visit_score}.

**Anchors.** `freestyle_chart` (the chart card).

**Rules.** The calls follow `CaseRules` (red flags, including a clear difference between the ears); Steve,
2026-10-19: refer for red flags or an asymmetry with no known cause, and a likely cause (Buck's shooting) still
sees a doctor first (docs/FREESTYLE.md 4.4). Every walk-in asks where the patient has trouble hearing (`FsRules.TROUBLE_QUESTION`).
Masked bone starts from unmasked bone stamped on either mastoid; with none yet the runner sends the player to bone
first (no unmasked pre-run on the poorer side). Any test begun before the otoscope looked, bone included, is the
"look first" slip. After the case's debrief, `debrief_extras()` adds Hoot's Carhart line (an ear with a
middle-ear part whose truth has the notch, shown by the chart's masked bone) and, on every FIT, that a full fitting also checks words in quiet and in noise.
(The case days' FITs now run the words check themselves, `speech_check` in section 11; freestyle's FS-13 can follow
the same pattern: see story/INTEGRATION_NOTES.md.)

**Tests.** `story/tests/test_freestyle.gd`: every walk-in is listed and validates, the call and the types of loss
agree with the truth table (and survive any 5 dB wobble), "no aids needed" only for normal hearing, every walk-in
asks where they have trouble hearing (and a FIT's debrief turns those places into goals), the tymp tip
matches the canal, speakers are unique game-wide, button prefixes are unique, every tray row and teaser fits the
screen, an unmasked gap is never an accepted chart type, the title's menu ends above the footer, every masked
frequency leaves 20 dB between the starting noise and the overmasking line on headphones, no true bone reaches
55 dB at 500 Hz, the debrief's extra lines go where they belong, a visit's pause menu offers the masking movie
after a day with its own movie, and Hoot's bone montage before air leaves the first air ear its 1 kHz retest.

## §13 The fitting (Day 14, the finale; docs/FITTING.md)

Gus comes back for his hearing aids. `story/level_fitting.gd` (scene `res://story/level_fitting.tscn`) plays the
chapter `gus_fit` with the patient `gus_fit` (`core/patients/gus_fit.tres`: Gus's own thresholds, bone = air). It
has its own patient id because `Game.chapter_for_patient` returns the first match, so `gus` would score as Day 1;
the chapter id is the patient id, as on every day (tests begin a visit by chapter id).
The clinic draws Gus by default (no `patient_id` set).

**Phases.** `intro`, `aid_style` (new), `probe_tube` (new), `real_ear` (new), `loud_check` (new), `fitting` (the
payoff), `counselling` (what to tell Gus; Days 4-5's phase), `results`.

**The probe tube** (`story/games/probe_tube.gd`, `ProbeTube`): the beat `probe_tube` (§3.2), before the aids go
in. The tip starts 17 mm from the eardrum and moves 3 mm a step; it locks within 5 mm (`zone_of(mm)`: "shallow",
"zone", "touch"). Statics `dip_hz(mm)` (a quarter wavelength from the drum) and `reading_error(mm, freq)` draw
what the probe mic reads. `result()` = {ear, depth, mistakes, shallow, touched}. Signals `touched` (the first
touch only; the level takes a comfort point) and `mistake(kind)`. For the mouse bot: `presses_needed()`,
`in_button()`, `lock_button()`.

**The loud-sound check** (`story/games/loud_check.gd`, `LoudCheck`): the beat `loud_check` (§3.2), after the
match. A five-notch loud limit; the first drop plays by itself at notch 4 and stings; notch 3 is right
(`verdict(n)`: "squashed", "right", "ouch"). The clang always plays at the same quiet level (AudioSafety: the
loudness is only drawn). `result()` = {notch, drops, squashed, ouch}. Signals `ouch` (the first drop at notch 5
only; the level takes a comfort point) and `dropped(notch)`. For the mouse bot: `presses_needed()`,
`turn_button(up)`, `drop_button()`.

**The counselling** (`LevelFitting.COUNSEL`): a choice loop that ends when the three right tips of five are found
(all-day wear, a few weeks to get used to sound, a follow-up to fine-tune); a wrong pick gets Gus's line and
Hoot's correction and leaves the list.

**The target match** (`story/games/target_match.gd`, `TargetMatch`): the beat `fitting_target` (§3.2). Statics, all
tested: `target_gain(thresholds, freq)` (a public textbook formula standing in for the fitting software's
prescription; play never names it), `targets(thresholds)` (1k, 2k, 4k, whole dB), `heard(line, matched)` (the
sounds of unmatched bands become "_"), `band_accuracy(err)`, `efficiency(moves, par)`, `curve_at(f, gains)`.
`result()` = {ear, bands: [{freq, target, start, final, err}], moves, par, overshoots ("loud" / "whistle"),
accuracy, efficiency}. Signals `matched_changed(count)` (the level sets `set_world_saturation`) and
`overshoot(kind)` (the first of each kind; the level takes a comfort point). For the mouse bot:
`presses_needed(i)`, `arrow_button(i, up)`, `done_button()`.

**Results.** `Game.set_audiometry_results(LevelFitting.results_for(right, picks, left))`, stored after the match
and again after the loud check and the counselling. picks = {style_tries, probe_mistakes, loud_drops,
counsel_slips}. Accuracy, technique (`TECHNIQUE_WEIGHTS`: 0.25 style + 0.2 probe + 0.2 loud + 0.15 counsel + 0.2
clean; each slip part is 1.0 right first time, 0.5 after one slip, 0.2 after more), efficiency, and `fitting` (the
right ear's result plus style, style_tries, probe_mistakes, loud_drops, counsel_slips, left_by_hoot, left). No
`ears`: the bot checks the fitting instead (`_check_fitting`: every band within 5 dB, the open style, Hoot's left
ear, and a probe, loud and counsel medal). The summary carries its own headlines, subheads, medal_beats (style,
probe, match, loud, counsel), weather and `sports_script` (`story/papers/paper_fitting.gd`, THE FITTING CARD).

**Tests.** `story/tests/test_fitting.gd`: the chapter and its patient, the prescription for Gus, what Gus hears,
the band and move scores, the first guess and par, the Done gate, the bot's solver at par, overshoots once per
kind, the keys, the visit's results and paper, the style options (unique bot prefixes, similar lengths) and
Hoot's lines at 18 words or fewer; the probe tube's zone, mic dip, solver, mistakes and keys; the loud check's
verdicts, solver and slips; the technique weights and parts; the counselling options and lines.

## §14 The career-fair demo (docs/DEMO.md)

`--demo` (or `?demo` in the web page's address) turns on `Game.is_demo()`. The title (`story/title_screen.gd`) then
shows one Play button (`_on_demo_start()`, the `title_start` solver) that goes to `TitleScreen.DEMO_SCENE`
(`res://story/level_demo.tscn`), with `DEMO_TAGLINE` under it; no Days, modes, Options, New player, Quit, movies
button or stats. The safety notice shows for every visitor, and each title calls `Game.reset_demo_visitor()`.

`story/level_demo.gd` (`LevelDemo`) plays patient `gus` (chapter `gus` in the demo's own save) in six HUD steps
(chat, peek, phones, beeps, chart, fit) with existing phases and beats only: Day 1's first history round
(`LevelGus.HISTORY[0]`), otoscopy, earphones and reveal; the right ear coached with `RIGHT_PLAN`
(`hoot_turn_after` 2, `montage_after`), the left with `LEFT_PLAN` (`hoot_turn_after` 0, `montage`); Day 14's
TargetMatch on the right ear (`real_ear` phase, beat `fitting_target`) and Hoot's left ear. Medals: history,
otoscopy, earphones, match. The results are the audiometry results plus `fitting` (the right ear's match).
`LevelDemo.apply_summary(summary)` adds `demo: true`, headlines, subheads, medal_beats, weather,
`next_chapter_id: ""` and `continue_text: "Next visitor"`. The paper's "again" replays the demo; anything else goes
to the title. An inner `Watchdog` (PROCESS_MODE_ALWAYS, real time) sends the demo to the title after
`IDLE_RESET_S` (120 s) without input; never under autoplay.

**The paper** (`story/daily_decibel.gd`, additive): a summary with `demo: true` hides the Decibucks and the shop
(B buys nothing) and moves the WANTED ad into their place on the bottom row, next to the buttons.

**The attract loop** (`story/demo_attract.gd`, `DemoAttract`, a Control the title adds in demo mode, never under
autoplay): after `TitleScreen.attract_after()` seconds (`ATTRACT_S` = 30, or `--attract-after=N`) with nobody at the
title (menu or notice state, not paused), `start()` fades in over the clinic, hiding the menu and the notice: Hoot
(waving) and Gus, Hoot's `LINES` one every `LINE_S` (4.5 s) round and round, `PROMPT` ("Press a key or click to
play") pulsing, and the tagline; the safety footer stays uncovered. Any key, click or mouse movement of
`MOTION_MIN_PX` (6 screen px) or more ends it (the event is consumed) and emits `dismissed`; the title then shows the
safety notice. Silent; reduced motion calms the bob, wave and pulse.

**Bot.** `_check_demo` (when the summary has `demo: true`): the four medals, each band within 5 dB, no next day,
"Next visitor"; the ears are checked as usual. **Tests.** `story/tests/test_demo.gd`: the flag and the web address
(only `WEB_FLAGS`), the visitor reset keeping settings, the Play-only title, the scene and plans, the paper, Hoot's
lines at 18 words or fewer, and `montage_after` (a montage after two stamps, no x8, every hole stamped);
**(demo polish)** the paper without Decibucks or shop, the attract loop (starts with nobody there, a mouse nudge
leaves it, a key ends it with the notice) and no attract loop outside demo mode or under autoplay.
