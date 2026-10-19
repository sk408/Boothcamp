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
| **(cases)** `story/cases/**`, `story/level_case.*`, `story/case_*.gd`, `story/games/case_*.gd`, `core/cases/**` | cases thread | Days 6-9: the case files and their runner (§11) |

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
    and the peak never goes above **-12 dBFS**.
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
| `rng: RandomNumberGenerator` | Seeded (`--seed`, default 1234 in autoplay). Use it for anything that should replay the same way. |
| `clock: float` | Game seconds. Pauses with the tree and follows `Engine.time_scale`. |
| `PHASES` | Phase ids (§3.1). **(v4)** adds `explainer` and `ghost_demo`; **(Speech)** `familiarize`, `speech` (§9.8); **(cases)** `tymp`, `decision` (§11) |
| **(v4)** `is_movie_seen(id) -> bool`, `mark_movie_seen(id)` | `progress.movies_seen`; `mark_movie_seen` adds the id once and saves. The explainer player calls it when a movie ends after reaching its `seen_at` scene (§3.4) |
| **(v3)** `CHAPTERS` | `[{id, day, title, patient_id, teaches, scene, requires}]`: `gus` (Day 1: Grandpa Gus, `res://story/level_gus.tscn`) and `bonnie` (Day 2: Bonnie Bunsworth, `res://story/level_bonnie.tscn`, requires `gus`); **(Speech)** `mike` (Day 3, `res://story/level_mike.tscn`, §9.8); **(cases)** `rocco`, `marina`, `dash`, `ginger` (Days 6-9, `res://story/level_case.tscn` with the extra key `case`, §11). **(polish)** `requires` is only a hint: the chapter best played first, which picks the suggested ("UP NEXT") day; it never locks anything. Optional `face` (a `Portraits` speaker id) and `tint` (a `Color` or `"#rrggbb"`) style the title's day card when its `DAY_FACES` / `DAY_TINTS` tables have no entry for the id |
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
  - `AC_FREQS`, `OCTAVE_FREQS`, `INTEROCTAVES`, `TEST_ORDER`.
  - Hughson-Westlake steps: `START_DB` 40, down 10, up 5, `ASCENDING_HITS_NEEDED` 2.
  - `MAX_DB` per frequency, tone-timing limits, `RESPONSE_WINDOW_S`, `TOO_LOUD_SL_DB`.
  - `PAR_PER_MEASUREMENT` 7 (**v2**: only a fallback; the session computes par per measurement, §5.2), `MARATHON_FACTOR` 3.0, `SCORE_WEIGHTS`, `GRADE_BANDS`, `DEGREE_BANDS`, `SHAPES`, `SHAPE_TITLES`.
  - Functions: `clamp_db`, `accuracy_for_error`, `golf_name`, `grade_for_score`, `combo_multiplier`, `degree_name`, `pta`, `required_interoctaves`, `classify_shape`.
  - `accuracy_for_error`: 0 dB -> 1.0, 5 -> 0.8, 10 -> 0.3, more than 10 -> 0 (engine-and-fun.md scoring table).
  - `golf_name(strokes, par)` **(v2)** uses run-sized bands, because one extra ascending run costs 2-3 presentations:
    d = strokes - par: -6 or less albatross, -5..-4 eagle, -3..-2 birdie, -1..+1 par, +2..+3 bogey, +4..+5 double bogey, +6 or more triple bogey.

  **(v3) Bone conduction and masking** (all numbers in `docs/CHAPTER2.md` §7):
  - `TESTS`, `TRANSDUCERS`, `BC_FREQS` (250-4k), `BC_REQUIRED` [1000, 2000, 4000, 500], `BC_MAX_DB` (250: 45, 500: 60, 750: 65, 1k-3k: 70, 4k: 65), `VIBROTACTILE_DB` (250: 30, 500: 55).
  - `IA_RULE_DB` (phones 40, inserts 55, bone 0), `MASK_SAFETY_DB` 10, `OCCLUSION_DB` (phones: 250 +15, 500 +15, 750 +10, 1k +10; inserts 0), `OCCLUSION_MAX_GAP_DB` 10, `MASK_STEP_DB` 5, `PLATEAU_STEPS` 3, `MASK_MIN_DB` 0, `MASK_MAX_DB` 100.
  - `ABG_CONDUCTIVE_DB` 10 (gap > 10 = conductive), `ABG_RED_FLAG_DB` 15 at `ABG_RED_FLAG_FREQS` [500, 1000, 2000], `CARHART_FREQ` 2000, `CARHART_MIN_DIP_DB` 10, `HEARING_TYPES`, `HEARING_TYPE_TITLES`, `MASK_STATUSES` (off, needed, under, ok, over, impossible).
  - Functions: `test_id`, `test_is_bone`, `test_is_masked`, `unmasked_test`, `test_freqs`, `max_db_for(freq, transducer)`, `clamp_db_for`, `clamp_mask_db`, `ia_rule`, `occlusion_effect`, `air_bone_gap`, `is_conductive_gap`, `abg_red_flag`, `hearing_type`, `has_carhart_notch`, `ac_masking_needed` (test AC - IA >= non-test BC), `bc_masking_needed` (gap >= `BC_MASK_GAP_DB`, 10: clinical review E5; `is_conductive_gap` stays > 10 for naming the loss), `initial_masking` (non-test AC + 10 + occlusion), `overmask_limit` / `is_overmasked` (masker - IA >= test cochlea), `masking_dilemma`, `mask_status`, `next_mask_step` (heard: noise +5; missed: tone +5), `plateau_run`, `sheet_thresholds`, `best_thresholds`, `nontest_bone_estimate`, `masked_freqs_needed`, `response_threshold` (the cross-hearing model: either cochlea answers).
  - **(v4)** `unmasked_bone(results, freq) -> Variant`: the lower of BOTH ears' unmasked bone stamps at `freq`
    (`null` when neither has one). Bone crosses the skull for free, so an unmasked bone answer belongs to the
    better cochlea, wherever the oscillator sat. `masked_freqs_needed(results, ear, &"bc_masked")` now compares the
    test ear's air with `unmasked_bone()` (Day 2 measures unmasked bone on the LEFT mastoid only), and the session
    starts a masked bone measurement there too (`mask_start` check, par, recommended start).

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

New beats are fine if they follow the same rule. Add them to this table through `story/INTEGRATION_NOTES.md`.

### §3.3 Story helpers (story-internal, listed for reference)

- `DialogueBox` (CanvasLayer 30):
  - `await say(speaker, text)`.
  - `await choose(prompt, options: Array[String], best) -> int`. The keys 1-9 pick an option.
  - It emits `Events.dialogue_line`.
- `DailyDecibel`: `await show_summary(summary) -> String`: "title", "again" or **(v3)** "next" (the "Next: Day N"
  button / key N, shown when the next chapter is open; the level then calls `Game.start_chapter(summary.next_chapter_id)`).
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
| Registry | `story/explainers/movies.gd` (`preload`, story-internal) | `MOVIES {id: path}`; static `ids()`, `has(id)`, `movie(id)` (deep copy), `for_chapter(chapter_id, include_short := false)` (the chapter's replayable movies), `replay_ids()` (every movie but the recaps), `is_short(id)`, `day_label(id)` ("Day 2"), `title(id)`, `total_s(id)`, `own_sets(id)` (the movie's own set ids), `word_count(text)`, `validate(id, known_sets) -> PackedStringArray`. `CARD_MAX_LINES` 4 and `CARD_MAX_CHARS` 36: `validate()` reports a `card` scene with more or longer lines. **(polish)** `static var extra := {}` (id -> a movie file path or a MOVIE Dictionary): **tests and dev tools only**, more movies at run time (`dev_explainer --extra-movie=`, `--list`); the game never sets it |
| Movie data | `story/explainers/movies/<id>.gd` (or your chapter's folder) | `const MOVIE := {id, title, subtitle, chapter (a Game.CHAPTERS id), narrator ("Hoot"), scenes: [...]}` plus the optional keys **(polish)** `seen_at` (a scene id: reaching it counts as seen, default the last scene; masking: `"plateau"`), `short` (true = a recap of 5-30 s: played by its level, never in a replay list) and `stage` (the movie's own sets script, below) |
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
  chapter's in a level (none on Day 1, nor on Days 3 and 6-9), every movie on the title's Options, never the recaps
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
| `skip_hoot_retest` **(polish)** | Hoot's turn / montage waives the 1 kHz retest of that ear (`session.retest_waived`); the player's own runs still need it |
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

Required measurements per ear, in the recommended order:
1. 1000, 2000, 4000 and 8000 Hz;
2. a 1000 Hz retest;
3. 500 and 250 Hz;
4. the inter-octaves (750, 1500, 3000, 6000) wherever the neighbouring octaves differ by 20 dB or more.

After a store, the screen moves to the next remaining frequency (the rule is in `required_remaining`).

### §4.3 `get_state()` / `audiometer_state_changed` keys

```
{
  "patient_id": "gus", "ear": "right", "freq": 1000, "db": 40, "tone_on": false,
  "accepting_input": true, "coached": true,
  "freqs_available": [250, 500, 750, 1000, 1500, 2000, 3000, 4000, 6000, 8000],
  "min_db": -10, "max_db": 120,                       # for the current freq
  "stored": {"right": {1000: 25, ...}, "left": {}},   # freq -> stored dB (no-response = max_db)
  "remaining": [2000, 4000, ...],                     # required, not yet stored, current ear
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
| `missed_retest` | 500 or 250 Hz stored before the 1 kHz retest | db |
| `retest_mismatch` | the 1 kHz retest differs by more than 5 dB | db |
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
| `interoctave_needed` | freq = the half-octave that is now required |
| `not_instructed` **(v2)** | db (the patient guesses because nobody told him what to do) |
| `phones_swapped` **(v2)** | db (he points at the other ear: the phones are on the wrong ears) |

**(v3) Masking errors** (masked sheets only):

| kind | when | data |
|---|---|---|
| `mask_too_low` | the first masked tone of a measurement with the noise below the initial level | mask_db, initial_db |
| `mask_start` | the first masked tone more than 10 dB from the unmasked threshold | db, start_db |
| `mask_wrong_step` | not the plateau dance: heard = noise +5 (same tone), missed = tone +5 (same noise) | expected, expected_mask, got, got_mask, prev_db, prev_heard |
| `store_no_plateau` | stored before 3 noise raises held (not when `window_full`: one more step would overmask) | db |
| `overmasked` | the noise reached the overmasking limit (once per measurement; not a check) | mask_db, limit_db |

On non-`ac` sheets `start_not_1k`, `missed_retest` and the inter-octave rule do not apply.

**(v3) Observations:** `cross_hearing` (unmasked: the other cochlea answered), `undermasked` (masked: it still
did), `plateau_step` {steps, needed, db, mask_db, found, auto} after every masked verdict, `plateau_found`
{db, start_mask, end_mask}, `vibrotactile` {db} (a felt low bone tone).

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
- **(polish)** `AudiometrySession`: `MASKED_GRACE_DB` 0 (a masked stamp is scored like any other: the simulator is
  calibrated instead); `retest_waived: Dictionary` (ear -> true: no 1 kHz retest needed); `instant_measure(ear, freq)
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
      "order": [1000, 2000, 4000, 8000, 1000, 500, 250, 3000],  # store order (1000 twice = retest)
      "strokes": 41, "par": 56,            # tone presentations vs par, incl. retest
      "accuracy": 0.95,                    # mean of the freq accuracies
      "shape": &"sloping",                 # ClinicRules.classify_shape
      "pta": 28.3,                         # 500/1k/2k average (NAN if missing)
      "coached": true
    },
    "left": {...}                          # present once the left ear was started
  },
  "technique_errors": [{"kind": "wrong_step", "ear": "right", "freq": 2000, "db": 35, "message": "..."}],
  "presentations": 96, "false_alarms": 1, "max_combo": 23,
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
  (initial noise, tone at the unmasked stamp) + 2. Masking errors (§4.5) lower technique like any other.

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
SRT: the speech recognition threshold, ASHA's preferred term), later `CHAPTER4.md` (WRS) and `CHAPTER5.md` (speech in
noise). Additions are marked **(Speech)** where they touch earlier sections. Days 1, 2 and 6-9 behave exactly as before.

| Path | Owner | Contents |
|---|---|---|
| `core/speech/**` | speech thread | `SpeechRules`, `SpeechMaterial`, `SpeechSim`, `SpeechSession`, `SpeechVoice`, `material/*.json` |
| `ui/speech/**` | speech thread | `SpeechScreen` (`speech_screen.tscn`) and its widgets |
| `story/level_mike.*`, `story/games/mike_board.gd` | speech thread | the Day 3 level and its board |

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
  the speech sanity checks), `world/tests/test_clinic.gd`, and the new `tests/test_contracts_speech.gd`.
- Changed in place, other days unchanged: `story/daily_decibel.gd` (column 2 and the weather line branch on the
  speech results), `world/characters/bean.gd` (the shirt block moves inside a `vest` branch for Mike),
  `world/characters/face_rig.gd` (Mike's face; one comment reworded), `story/portraits.gd` and
  `tests/test_chapters.gd` (their tables gain Mike; the header comment changes), `story/pause_menu.gd` and
  `story/hud.gd` (the speech phase hides the pause corner and the tracker, like the audiometry phase), `story/dialogue_box.gd` (Mike's display name "Mike
  Lenders"), `story/tests/test_story.gd` (Mike in the voice-bank check; a new Day 3 card test), `export_presets.cfg` (the material JSON in,
  `story/dev_day3.*` out), `tools/scene_shot.sh` (positional parsing, so `--` and options can come anywhere),
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
  (`SRT_LOW_START_BELOW_PTA_DB`) is the clean `srt_low_start` instead of an `srt_start` error (an ascending start;
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
| `srt_start` | error | the first word is outside PTA + 10..25; a first word at least 10 dB below the PTA is clean with `low_start_ok` (data: expected, pta) |
| `srt_wrong_step` | error | not "got it: down 10 (5 tolerated); missed: up 5", nor another word at the same level (up to 4 there) (expected, got, prev_db, prev_correct, words_here) |
| `misscored` | error | the score differs from what the patient said (said, said_kind, scored) |
| `srt_store_no_bracket` | error | stored before a level scored 2+ right and half or more with the level 5 below under half |
| `srt_store_wrong_level` | error | stored a level other than that one (candidate) |
| `speech_marathon` | error | more than 3x par words in one measurement (once) |
| `speech_textbook`, `srt_good_start`, `srt_store_ok` | clean | combo +1, points |
| `srt_low_start` | clean | a first word at least 10 dB below the PTA with plan `low_start_ok`: combo +1, 10 points, Hoot's line in `message` ("Starting low and coming up: smart when answers look exaggerated.") |
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
  "technique_errors": [{kind, ear, freq: -1, test, db, message}],
  "accuracy": 0.9, "technique": 0.98, "efficiency": 0.92, "score": 93.1, "grade": "A"
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
`compress/mode` 0: a **project-wide** default, so every WAV in the project imports uncompressed. RMS from
`AudioSafety.speech_to_rms(hl)` (`SPEECH_OFFSET_DB` -9, RMS ceiling `SPEECH_CEILING_DBFS` -27), every sample through
`clamp_sample()`. Speech noise: speech-shaped noise in the other ear through `masker_to_rms()` and
`clamp_masker_sample()`. Every word lights the TALK lamp; nothing depends on hearing it.

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
quick visit on; 0 = Hoot runs it all; missing = never), `intro`, `hoot_turn_text`, `show_agreement` (default true),
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
  level as the SRT. MASK (`toggle_mask`) is speech noise in the other ear at level - 20.
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
`hoot_turn_after` 0), `familiarize` (go through the words; a word Mike doesn't know is dropped), `speech` {ear, test:
"srt"} for right (coached) and left, `evidence` (OBJECTION!), `referral`, `results`. New blocking beats:
`familiarize_cards` (info {mouse}), `objection_present` (info {targets, mouse: {drag: [clue, target]}}; solver
presents the strongest clue), `referral_stamp` (reused). Every SRT plan sets `low_start_ok` once Hoot's coffee
whisper has been on screen. After the right ear, when the player's SRT can't show the mismatch (not poor, not
better than the PTA, or not stored at its bracket), Hoot reruns that ear by the book on a fresh session
(`fresh_session`, `hoot_turn_after` 0); the board (`board_sheet()`) uses his recheck, the results keep the player's
sheet for the grade. The SRT-vs-PTA measurement is always the strongest clue. Chapter: `Game.CHAPTERS` id `mike`, day 3, requires `bonnie`
(the suggested order only: any chapter can be picked). Medals: `history`, `instructions`, `familiarize`, `evidence`,
`referral`. Anchors: `word_card_<item id>` (familiarize), `objection_claim`, `clue_srt_pta`, `clue_coffee`,
`clue_canals` (evidence), `referral_stamp`. Without the SPEECH scene the level lets Hoot say the words (unscored), so
the visit still ends.

### §9.9 Autoplay (Speech)

- The bot treats `speech` beats like every other beat (waits, then calls the solver); with `--mouse` any beat whose
  info carries `mouse` is played by its route: `{click: anchor}`, `{drag: [from_anchor, to_anchor]}` or
  `{text: "visible text prefix"}`.
- Progress also comes from the `speech_*` signals. Sanity (exit 4): every stored SRT within 10 dB of the truth, both
  ears stored on a speech day, and on Day 3 a poor PTA/SRT agreement.
- Screenshots: `speech_<ear>_srt_first_word`, `speech_<ear>_srt_descent`, `speech_<ear>_srt_stored`,
  `day3_familiarize`, `day3_objection`, `day3_stamp`, `day3_goodbye`, `day3_glazed`.

---------------------------------------------------------------------------------------------

## §11 Cases (patient case files, Days 6 onward)

Design: `docs/CASES.md`. Full scripts: `docs/CASE_SCRIPTS.md` (generated from the JSON by `tools/case_scripts.py`).
(§9 is speech, Days 3-5; §10 is left free for a chapter in flight, so section numbers don't collide when branches merge.)

**Files.**

| What | Where | Owner |
|---|---|---|
| Case data, one per case | `story/cases/<case_id>.json` (the source of truth for every line) | cases |
| Patient truth tables | `core/patients/<patient_id>.tres` (sensorineural cases: no bone data, bone = air; conductive cases carry `bc_right` / `bc_left`). A retest profile `<id>_after.tres` (the ear after treatment) is loaded by the runner and never registered as a chapter | cases |
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
`retest`.

**Optional case keys (batch 2; all default to the Days 6-9 behaviour).** `otoscopy.view` `clear` / `wax` / `fluid`
(a wax view keeps the first visit's air on headphones); `otoscopy.kind` and `findings[].kind` `clue` / `flag`;
`tymp.<ear>.ecv_ml` (required: a B ear sits outside 0.6-0.9 mL, any other type inside 0.9-2.0); `findings[].when`
`symmetric` / `asymmetric` / `conductive` / `abg_flag`; `reveal.pattern` `gap` with `reveal.plug` `wax` / `fluid`;
`audiometry[].montage` (Hoot's alone: `hoot_turn_after` 0) and `skip_hoot_retest`, passed to the AudiOtron's plan;
`do` `wax_jar` / `plane`; `paper.wrong_first` `{fit / refer / today: {headline, subhead?}}` for each wrong first
stamp; `retest` `{patient_id, card?, intro?, otoscopy?, tymp?, before?, instructions?, audiometry (air only),
reveal {ear, label?, title?, lines?}, payoff?}`. When `reveal.ear` is right or left, unmasked bone goes on the better ear only; the runner then masks bone on each ear
whose air sits over it (`CaseData.masked_bone_ears`, as on Day 2).
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
`merge_retest`, the runner's own lines, headphones with wax, and the new gadgets draw. `tools/run_tests.sh` also
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
The waiting room hands its pick to the runner in the Engine meta `freestyle_next_case`; `--freestyle=<id>` wins.
The best result per walk-in is stored inside the save's patient record: `progress.patients[<id>].fs_best_grade`
and `fs_best_score`.

**Reused, not copied.** The AudiOtron (`start_test` plans, never coached), the clinic, `CaseRules` (tymp types, red
flags, asymmetry, decisions), `ClinicRules` (types of loss, masking rules, PTA), the story tympanometer gadget
`story/games/case_tymp.gd` (the tray hides the Tympanometer when that file is missing) and the Daily Decibel.

**Phases** (`Events.phase_changed`): `freestyle_room`, `intro`, `freestyle_tray`, `history`, `otoscopy`, `tymp`,
`audiometry` (info `{ear, test}`), `freestyle_chart`, `decision`, `freestyle_debrief`, `results`. `Game.PHASES`
gained `freestyle_room`, `freestyle_tray`, `freestyle_chart`, `freestyle_debrief`.

**Beats.** No new beat kinds: everything is `dialogue`, `choice` and the AudiOtron's own beats. The waiting room's
pick, the tool tray, the question board and every clinic choice (tip, tymp type, ear first, mastoid, masked test,
chart type, the stamp) are `choice` beats whose `best` is the pro's pick (`FsRules.best_tool`). Buttons start
with their option text, so the mouse bot clicks them by their first 18 characters (tests keep them unique).

**Visit and medals.** Medals `fs_chat` (Chat), `fs_workup` (Workup), `fs_chart` (Chart), `fs_call` (Call). The
paper's score is 60 % medals (gold 100, silver 70, bronze 40) and 40 % the visit's own score. Summary keys:
`freestyle_case`, `visit_score`, `headlines`, `subheads`, `medal_beats`, `continue_text` ("Waiting room"),
`continue_scene` (the waiting room), `next_chapter_id` "" and `first_clear` false. Visit flags:
`freestyle_case`, `freestyle_asked`, `freestyle_tip_tries`, `freestyle_types`, `freestyle_tymp_misreads`,
`freestyle_slips`, `decision_first`, `decision`, `decision_tries`.

**The AudiOtron between tests.** One screen per visit. Between tests it stays in the tree (its Hoot anchors are
registered once) but is hidden and `PROCESS_MODE_DISABLED`, unregistered from `Stage.audiometer`, with the booth
view off and the music back; the next test re-registers it. It is freed when the patient walks to the desk.

**Hooks in other modules (all additive).**
- `story/title_screen.gd`: the **Freestyle** button (`FREESTYLE_SCENE`) after Days; Options and Quit share the last
  row (Up/Down and Left/Right walk the buttons in order) so six buttons still clear the safety footer.
- `story/case_portraits.gd`: `CasePortraits.register(who, look)` (walk-ins aren't chapters, so they register).
- `story/daily_decibel.gd`: the summary's optional `continue_text` labels the main button (default "Back to the title";
  keep it short, the paper must fit 1280 px).
- `tools/autoplay_bot.gd`: `--mouse` clicks `continue_text` and counts `continue_scene` as being back;
  `--via-freestyle` presses the title's Freestyle button; the report gains `freestyle` {case, medals, visit_score}.

**Anchors.** `freestyle_chart` (the chart card).

**Tests.** `story/tests/test_freestyle.gd`: every walk-in is listed and validates, the call and the types of loss
agree with the truth table (and survive any 5 dB wobble), "no aids needed" only for normal hearing, the tymp tip
matches the canal, speakers are unique game-wide, button prefixes are unique, every tray row and teaser fits the
screen, an unmasked gap is never an accepted chart type, and the title's menu ends above the footer.
