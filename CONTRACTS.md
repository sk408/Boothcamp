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

The foundation stubs in `core/`, `ui/`, `world/` and `story/` have been replaced by the builders' real modules
(integrated 2026-10-17). Owners may keep changing their internals, but must keep the public API in this file.
Contract changes from that integration are marked **(v2)**.

**(v3) Chapter 2** (Day 2, Bonnie Bunsworth: bone conduction + masking; design in `docs/CHAPTER2.md`) adds
chapters and unlocks, bone and masked tests, the masker, and the Day 2 level. Every v3 change is marked
**(v3)**. Day 1 behaves exactly as before: every v3 parameter has a default that reproduces v2.
Additions from the Chapter 2 builders, merged at integration, are marked **(v3, builders)**.

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
| **(v3)** chapters | `chapter_completed(chapter_id, newly_unlocked: Array)` (Game, from `finish_visit`) |
| **(v3)** masking | `masker_changed(ear, freq, db, on)` (ear = the MASKED ear), `transducer_changed(transducer, ear)` (AudiOtron) |

Emit every signal with all its arguments. Use `""`, `{}` or `-1` for "none".
`tests/test_contracts.gd` checks that every signal exists.

### §2.2 Game (`autoload/game.gd`)

| Member | Meaning |
|---|---|
| `settings: Dictionary` | `DEFAULT_SETTINGS`: `key_style` ("otosuite" / "affinity"), `master_volume`, `tone_volume`, `sfx_volume`, `music_volume` (0..1), `show_key_hints`, `reduced_motion`, `no_startle`, `fullscreen`, `text_speed`, `quick_visit`, **(v3)** `unlock_all_days` (career-fair demo: every day open) |
| `set_setting(key, value)` | apply, save, emit `settings_changed` (and `key_style_changed`) |
| `set_key_style(style)`, `get_key_style()` | Swaps the events of `louder` and `softer` (§4.7) |
| `key_label(action) -> String`, `key_labels(action)` | Current key names for on-screen hints. Always use these; never hard-code "Up". |
| `progress: Dictionary` | `coins`, `upgrades: Array`, `patients: {id: {best_score, best_grade, last_grade, plays}}`, `seen_disclaimer`, `hoot_mastery`, `plays`, **(v3)** `chapters_done: Array` (chapter ids finished at least once), `last_chapter` |
| `save_game()`, `load_game()`, `reset_save()` | JSON at `user://save.json` (`user://save_autoplay.json` under `--autoplay`, `user://save_scene.json` under `--scene=`). A corrupt file is copied to `.bak`. **(v3)** An old save where Gus was played counts as Day 1 done. |
| `load_patient(id) -> Resource` | `res://core/patients/<id>.tres` (a `PatientProfile`) |
| `current_patient_id`, `visit` | §2.3 |
| `begin_visit(id)` | Resets the visit state. Story calls it first. |
| `lose_comfort(reason, amount=1)`, `gain_comfort(...)`, `get_comfort()` | 0..3 hearts; emits `comfort_changed` |
| `set_visit_flag(key, v)`, `get_visit_flag(key, default)` | Free-form per-visit flags |
| `record_medal(beat, "gold" / "silver" / "bronze")` | One medal per micro-game |
| `set_audiometry_results(results §5.1)` | Story calls it after the last `test_finished`. |
| `finish_visit() -> Dictionary` | Scores the visit, awards coins, saves, and returns the summary (§5.3). Called once, on results. |
| `add_coins(n)`, `has_upgrade(id)`, `buy_upgrade(id, cost) -> bool` | Shop |
| `cli: Dictionary`, `cli_flag(name)`, `cli_value(name, default)`, `is_autoplay()` | User args after `--` (§7.1) |
| `rng: RandomNumberGenerator` | Seeded (`--seed`, default 1234 in autoplay). Use it for anything that should replay the same way. |
| `clock: float` | Game seconds. Pauses with the tree and follows `Engine.time_scale`. |
| `PHASES` | Phase ids (§3.1) |
| **(v3)** `CHAPTERS` | `[{id, day, title, patient_id, teaches, scene, requires}]`: `gus` (Day 1: Grandpa Gus, `res://story/level_gus.tscn`) and `bonnie` (Day 2: Bonnie Bunsworth, `res://story/level_bonnie.tscn`, requires `gus`) |
| **(v3)** `chapters()`, `chapter(id)`, `chapter_for_patient(id)`, `chapter_for_day(day)`, `chapter_scene(id)` | Registry lookups (`{}` / `""` when unknown) |
| **(v3)** `is_chapter_done(id)`, `is_chapter_unlocked(id)`, `unlocked_chapter_ids()` | Unlocked = no `requires`, or `requires` done, or `unlock_all_days`, or `--unlock-all`, or the `--day` / `--chapter` chapter |
| **(v3)** `next_chapter_id()`, `cli_chapter_id()` | What the title's Play starts: the CLI chapter, else the first unlocked chapter not done, else `last_chapter`, else Day 1 |
| **(v3)** `start_chapter(id) -> bool` | Remembers `last_chapter`, saves, emits `goto_scene(scene)`. False if locked or missing |
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
  - Functions: `test_id`, `test_is_bone`, `test_is_masked`, `unmasked_test`, `test_freqs`, `max_db_for(freq, transducer)`, `clamp_db_for`, `clamp_mask_db`, `ia_rule`, `occlusion_effect`, `air_bone_gap`, `is_conductive_gap`, `abg_red_flag`, `hearing_type`, `has_carhart_notch`, `ac_masking_needed` (test AC - IA >= non-test BC), `bc_masking_needed` (gap > 10), `initial_masking` (non-test AC + 10 + occlusion), `overmask_limit` / `is_overmasked` (masker - IA >= test cochlea), `masking_dilemma`, `mask_status`, `next_mask_step` (heard: noise +5; missed: tone +5), `plateau_run`, `sheet_thresholds`, `best_thresholds`, `nontest_bone_estimate`, `masked_freqs_needed`, `response_threshold` (the cross-hearing model: either cochlea answers).

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
| `title` | title menu (Play / Days / Options / Quit) | {} |
| `chapter_select` **(v3)** | the title's day picker ("Days") | {unlocked: [chapter ids]} |
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

Every `phase_changed` clears all Hoot tips (§8).

Canvas layers:

| Layer | Used by |
|---|---|
| 10 | story HUD and micro-games |
| 20 | AudiOtron screen |
| 30 | DialogueBox |
| 40 | results paper |
| 80 | Hoot bubble |
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
| `chapter_select` **(v3)** | title screen (Days card) | {chapters: unlocked ids, next: chapter id}; solver starts `next` |
| `bc_placement` **(v3)** | level_bonnie (oscillator game) | {targets: ["mastoid_target_right"], mistakes}; solver places it on the mastoid |
| `referral_stamp` **(v3)** | level_bonnie (Day 2 board) | {targets: ["referral_stamp"]}; solver stamps |

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
  is an input-free look at a healthy ear. The title's Days card keeps `_day_buttons` (metas `label`, `chapter`,
  `toggle`, `locked`, `hl`), `_pick_day`, `_toggle_unlock_all` and `_days_back` for the tests and the bot.
- Pause menu: group `pause_menu`, with `open()` / `close()` / `is_open()` and the key-style toggle. The `pause` action toggles it.

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
| `masking_controls` | show the MASKING (noise down, MASK, noise up) and ROUTE (AIR / BONE) buttons; default true for any test but `ac` |
| `hoot_turn_after` | stamps before Hoot takes over at x8 (default 3); 0 = Hoot runs the whole test (quick visit) |
| `intro`, `hoot_turn_text`, `done_title` | Hoot's opening tip, his take-over line, the quest panel's done title |

The required measurements are those of the goal sheet: `ac` as below; `bc` = `bc_freqs`; masked sheets =
`ClinicRules.masked_freqs_needed()` from what is stored so far (bone: gap > 10; air: AC - 40 >= the other
ear's bone estimate). The player can switch sheets with the controls (transducer x masking on/off picks the
sheet: `test_for(transducer, mask_on)`), but the test finishes when the goal sheet is complete. Masked
measurements start at the unmasked stamp; after a masked store the noise dial moves to the next frequency's
initial level. The masker plays in the non-test ear whenever masking is on (§1.3).
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
  "mask_on": true, "mask_db": 25, "mask_ear": "left",  # masker dial (dB EM) and the ear it plays in
  "mask_status": &"ok",                                # ClinicRules.MASK_STATUSES (the NOISE box light)
  "initial_mask_db": 25,                               # the helper's starting level here (0 without masking UI)
  "overmask_limit_db": 50,                             # noise at or above this overmasks (bone: tone + 40; air: test-ear bone + 40)
  "plateau": {"db": 10, "steps": 2, "needed": 3, "found": false, "start_mask": 25, "initial": 25, "points": [...]},  # masked sheets only, else {}
  "stored_tests": {"ac": {"right": {...}, "left": {...}}, "bc": {...}, "bc_masked": {...}, "ac_masked": {...}}
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
(the better one), masked bone = the bone threshold, air (masked or not) = the air threshold. A masked
store is the plateau level when a plateau was found, else the ascending threshold.
**(v3, builders)** Masked accuracy grace: a masked stamp ABOVE the truth is scored as if it were
`AudiometrySession.MASKED_GRACE_DB` (5) dB closer (5 above = exact, 10 above = 0.8), because the plateau's
single presentations at a ~75 % threshold drift upwards. `true_db` and `error_db` are unchanged.
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
- `PatientSim`: logistic psychometric model with attention, fatigue, false alarms, reaction time and groove.
  - `THRESHOLD_BIAS_DB` 2: the curve's 50 % point sits 2 dB below the profile threshold, so a by-the-book 2-of-3
    ascending search writes down the profile value about 80 % of the time (and 5 dB either side otherwise).
    With 0 it is a coin flip between T and T+5, and a perfect player would lose accuracy points (integrator, v2).
- **(v3)** `AudiometrySession`: `configure(plan)`, `test`, `goal_test`, `transducer`, `air_transducer`, `mask_on`,
  `mask_db`, `set_transducer`, `set_mask`, `toggle_mask`, `step_mask`, `set_mask_level`, `masker_ear`, `test_for`,
  `initial_mask_db`, `overmask_limit_db` (bone: tone + IA; air: the test ear's best bone, or the nearest measured
  bone frequency's, + IA), `masking_needed_here`, `mask_status`, `plateau_info`, `store_candidate` (the plateau
  level, or the held level once `window_full(e, f)`), `window_full`, `results_view`; per-test sheets; `MASK_PAR_SLACK` 2 (masked par = textbook dance + 2).
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
  "newly_unlocked": ["bonnie"],        # chapters this visit opened (empty on a replay)
  "next_chapter_id": "bonnie"          # "" after the last chapter
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
| `--day=N` / `--chapter=id` **(v3)** | Play (and the bot) starts that chapter; it counts as unlocked |
| `--unlock-all` **(v3)** | every chapter unlocked for this run |
| `--keep-save` **(v3, integrator)** | with `--autoplay`: keep the save instead of resetting it (chain Day 1 then Day 2 with the same `--save=`) |
| `--via-days` **(v3, integrator)** | with `--autoplay`: start from the title's Days card with real input (clicks with `--mouse`, else ui_* keys) instead of Play. Options: `--pick=<chapter id>` (default `next`), `--try-locked=<id>` (press that card first and expect a refusal), `--toggle-unlock` (press "Unlock all days (demo)" first), `--expect-days=gus,bonnie` (the unlocked list). The result gets a `days` report; a failed expectation is a problem (exit 4) |

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
     `overmask_limit_db`).
3. **Ending.** On `Events.level_finished` it records the summary. On `results_continue` it prints
   `AUTOPLAY_RESULT {json}` and emits `Events.quit_requested(code)`.

**Exit codes:**

| Code | Meaning |
|---|---|
| 0 | ok |
| 2 | stalled for 120 game seconds |
| 3 | overall timeout |
| 4 | results sanity check failed: an ear is incomplete, a threshold is off by more than 10 dB (any sheet, v3), or there was no `level_finished`; **(v3)** on Day 2 also: Bonnie's right ear not conductive, no red flag, masked bone missing at 500-4k, or no masked air |
| 5 | script errors were logged |
| 6 | (`--mouse`) a mouse target could not be found on screen |

**Mouse-only mode (v2, `--mouse`).** Beats are solved by clicking or dragging what a player sees: the Hoot anchors
(`otoscope_seed`, `earphone_red` -> `ear_target_right`, `evidence_slope` -> `evidence_target`, **(v3)** `oscillator` ->
`mastoid_target_right`, `referral_stamp`, the day card by its title, the AudiOtron buttons incl. the masking deck;
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
  `day2_croissant`, `day2_goodbye`; with `--via-days`: `days_locked_refused`, `days_toggled`;
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
  clinic oscillator, the `bc_placement` / `referral_stamp` beats, `Hud.set_steps`).
- **(v3)** Stress test: `tools/monkey.tscn` mashes Day 1, or with `--day=2` Bonnie's five tests and the masking /
  route keys (invariants: noise dial 0-100, no masker while MASK is off or after a test).
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
| AudiOtron **(v3)** | `mask_softer_button`, `mask_toggle_button`, `mask_louder_button`, `transducer_button` (hidden unless the plan shows the masking deck) |
| story **(v3)** | `oscillator`, `mastoid_target_right`, `abg_bridge`, `referral_stamp` |

**Bubble placement.**
- A screen can reserve a spot with `Hoot.set_bubble_hint(rect)` in viewport coordinates, and `clear_bubble_hint()` on exit.
- The AudiOtron reserves its right-hand column.
- With no hint, the bubble sits top-right below the HUD (y ≈ 176). Screens that need that area should set a hint.

---------------------------------------------------------------------------------------------

## §9 Speech audiometry (Days 3-5)

The speech chapters add a second test screen, the **SPEECH** screen, next to the AudiOtron. Rules and numbers:
`docs/SPEECH.md` (`SpeechRules` in `core/speech/speech_rules.gd`); chapter designs: `docs/CHAPTER3.md` (Day 3, Mike,
SRT), later `CHAPTER4.md` (WRS) and `CHAPTER5.md` (speech in noise). Additions are marked **(Speech)** where they touch
earlier sections. Days 1 and 2 behave exactly as before.

| Path | Owner | Contents |
|---|---|---|
| `core/speech/**` | speech thread | `SpeechRules`, `SpeechMaterial`, `SpeechSim`, `SpeechSession`, `SpeechVoice`, `material/*.json` |
| `ui/speech/**` | speech thread | `SpeechScreen` (`speech_screen.tscn`) and its widgets |
| `story/level_mike.*`, `story/games/mike_board.gd` | speech thread | the Day 3 level and its board |

### §9.1 PatientProfile.speech

`@export var speech: Dictionary = {}` (all keys optional; anything missing comes from the audiogram):
`srt` {ear: dB HL}, `srt_offset` {ear: dB}, `half_words` (0..1, share of SRT misses given as half a word, default
0.15), `wrs_max` {ear: %}, `rollover` {ear: {after, drop_per_10db}}, `neural` {ear: bool}, `snr_loss` (dB),
`directional_benefit` (dB). `speech_value(key, ear := "", default)` reads one; `SPEECH_KEYS` lists them and
`validate()` rejects unknown keys. Day 3: `core/patients/mike.tres` (voluntary tones about 70 dB, `srt` 30 / 30,
`half_words` 0.6, tags `non_organic`, `speech`, `chapter_3`).

### §9.2 Material (`SpeechMaterial`, static)

`res://core/speech/material/<list_id>.json`: `{id, title, kind: "spondee" | "monosyllable" | "sentence", original: true,
items: [...]}`. Spondee items `{id, text, parts: [a, b], mishears: [...]}`. Every list is written for the game
(`tests` reject a sample of published words). Functions: `load_list(id)`, `items(id)`, `item(list, item)`,
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
  `tones`, `transducer`, `level`), `begin(ear, coached)` (the dial goes to the PTA rounded to 5 dB, or `level`).
- Controls: `step_level(dir)`, `set_level(db)`, `set_mask(on)`, `toggle_mask()`, `present() -> trial` (`{}` when
  refused: a word still needs its score, the ear is done, or no words), `score(correct) -> trial`, `store() -> sheet`.
- Queries: `next_item()`, `candidate()` (`SpeechRules.NO_SRT` -1 = not bracketed), `pta_for(ear)`,
  `recommended_start()`, `masking_needed_here()`, `mask_level()`, `is_done()`, `trials_for()`,
  `recommended_action() -> {action, target_db}` (`&"score_correct"`, `&"score_missed"`, `&"louder"`, `&"softer"`,
  `&"mask_toggle"`, `&"present"`, `&"store"`, `&"none"`; it uses only what the player can see), `textbook_target()`.
- `scoring` (false during Hoot's turn: his words and store are not scored), `tip_text(kind)`.
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
| `srt_start` | error | the first word is outside PTA + 10..25 (data: expected, pta) |
| `srt_wrong_step` | error | not "got it: down 10 (5 tolerated); missed: up 5" (expected, got, prev_db, prev_correct) |
| `misscored` | error | the score differs from what the patient said (said, said_kind, scored) |
| `srt_store_no_bracket` | error | stored before a level scored 2+ right and half or more with the level 5 below under half |
| `srt_store_wrong_level` | error | stored a level other than that one (candidate) |
| `speech_marathon` | error | more than 3x par words in one measurement (once) |
| `speech_textbook`, `srt_good_start`, `srt_store_ok` | clean | combo +1, points |
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
sheet (SRT) = {ear, test: "srt", list_id, stored_db, true_db, error_db, accuracy, candidate_db, pta, pta_method,
  agreement (&"good" / &"fair" / &"poor"), diff (SRT - PTA), start_db, recommended_start, strokes (player words),
  words (all), par, golf (fair golf, &"hoot" for Hoot's), golf_raw, clean, errors, trials [{n, db, item_id, word,
  said, kind, correct, scored, mask_db, by_hoot, delay_s, heard_by}], masked, mask_db, transducer, by_hoot, coached,
  half_words (count)}
```
`true_db` and `trials[].correct` / `kind` are truth: scoring and the reveal only.

### §9.6 SpeechVoice (Node, `core/speech/speech_voice.gd`) and safety

`play_item(ear, list_id, item, hl) -> seconds`, `stop()`, `is_playing()`, `set_level(hl)`, `start_noise(ear, db_em)`,
`set_noise(db_em)`, `stop_noise()`, `render(frames)` (pure DSP). Words: a synthesized murmur (one voiced syllable per
part), or a recording at `res://assets/speech/<list_id>/<item_id>.wav` (or `.ogg`), in the test ear only; RMS from
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
`transducer`, `hoot_turn_after` (words the player scores before Hoot finishes the ear at x8 with quick visit on; 0 =
Hoot runs it all; missing = never), `intro`, `hoot_turn_text`, `show_agreement` (default true).

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
  score what he said, down 10 / up 5, store). Errors show the `message` tip.
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
presents the strongest clue), `referral_stamp` (reused). Chapter: `Game.CHAPTERS` id `mike`, day 3, requires `bonnie`
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

