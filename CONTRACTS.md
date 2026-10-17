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
  - frequencies: `int` Hz from `ClinicRules.AC_FREQS`;
  - levels: `int` dB HL on the 5 dB grid;
  - kinds and phases: `StringName`.

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
- **"Too loud" gags are visual only:** shake, hair blast, Hoot. Never play a loud sound.
- **Every tone lights an on-screen indicator** (the TONE lamp) and every patient press lights the PRESS
  lamp. Nothing depends on the player hearing the tone.
- **The patient's answers come from the simulator** (`core/`), never from the player's ears.
- **The start of the game shows the notice "This is a game, not a hearing test."** (title screen, phase `disclaimer`).
- **Speech audiometry is not in this slice.**

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

Emit every signal with all its arguments. Use `""`, `{}` or `-1` for "none".
`tests/test_contracts.gd` checks that every signal exists.

### §2.2 Game (`autoload/game.gd`)

| Member | Meaning |
|---|---|
| `settings: Dictionary` | `DEFAULT_SETTINGS`: `key_style` ("otosuite" / "affinity"), `master_volume`, `tone_volume`, `sfx_volume`, `music_volume` (0..1), `show_key_hints`, `reduced_motion`, `no_startle`, `fullscreen`, `text_speed` |
| `set_setting(key, value)` | apply, save, emit `settings_changed` (and `key_style_changed`) |
| `set_key_style(style)`, `get_key_style()` | Swaps the events of `louder` and `softer` (§4.7) |
| `key_label(action) -> String`, `key_labels(action)` | Current key names for on-screen hints. Always use these; never hard-code "Up". |
| `progress: Dictionary` | `coins`, `upgrades: Array`, `patients: {id: {best_score, best_grade, last_grade, plays}}`, `seen_disclaimer`, `hoot_mastery`, `plays` |
| `save_game()`, `load_game()`, `reset_save()` | JSON at `user://save.json` (`user://save_autoplay.json` under `--autoplay`, `user://save_scene.json` under `--scene=`). A corrupt file is copied to `.bak`. |
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

  The numbers are teaching defaults that the clinical reviewer (Steve) checks. Change them here, not in a copy.
- **`AudioSafety`**: `hl_to_dbfs`, `hl_to_peak`, `peak_ceiling`, `clamp_sample`, and the bus names `Tones`, `Sfx`, `Music`, `Voice` (§1.3).
- **`Palette`**: warm palette constants (`INK`, `PAPER`, `SUNNY`, `CORAL`, `MINT`, `SKY`, `WALL`, ...), plus
  `ear_color(ear)` (right = red, left = blue), `ear_tint(ear)` and `grade_color(grade)`.
- **`UiDraw`**: `_draw()` helpers: `arrow`, `triangle`, `heart`, `star`, `check`, `cross`,
  `ear_symbol(ci, center, ear, size, width, no_response)` (O / X and the no-response arrow), `rounded_rect`.
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
| `title` | title menu (Start / Options / Quit) | {} |
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

New beats are fine if they follow the same rule. Add them to this table through `story/INTEGRATION_NOTES.md`.

### §3.3 Story helpers (story-internal, listed for reference)

- `DialogueBox` (CanvasLayer 30):
  - `await say(speaker, text)`.
  - `await choose(prompt, options: Array[String], best) -> int`. The keys 1-9 pick an option.
  - It emits `Events.dialogue_line`.
- `DailyDecibel`: `await show_summary(summary)`.
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

### §4.2 AudiOtron screen: `res://ui/audiometer/audiometer_screen.tscn`

The root is a `CanvasLayer` (layer 20) with this API. The story adds it as a child, calls `start_test()` once per
ear and awaits `test_finished`. Between ears the screen stays in the tree. It keeps its session and its
audiogram for the same patient.

```
signal test_finished(results: Dictionary)          # §5.1, every ear tested so far this visit
func start_test(patient: PatientProfile, ear: String, coached: bool) -> void
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

Events it emits:
- `audiometry_started`;
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
  "quick_visit": true                                  # setting "quick_visit" (or --quick / --full)
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
}
```
**(v2)** `par` is dynamic: the median presentations of a textbook search from the level this measurement
started at (typically 7-13), not the constant 7.

`true_db` is the patient's truth, for scoring and the reveal only. Gameplay code and the bot must never use
it during the test.

### §4.5 Technique kinds (`Events.technique_event(kind, data)`)

`data` always has `ear` and `freq`. Error kinds also carry `message`: a Hoot line of 18 words or fewer, from `AudiometrySession.TIPS`.

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
```

What it draws:
- a log-frequency axis (250 Hz to 8 kHz) and a dB axis from -10 at the top down to 120;
- a normal-hearing band;
- the ASHA symbols: right = red O, left = blue X, no response = a symbol with a down-pointing arrow.

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
| `toggle_mask` | M | reserved (masking is not in this slice) |
| `toggle_key_hints` **(v2)** | H | show / hide the key chips |
| `advance_dialogue` | Space, Enter, Keypad Enter | next dialogue line |
| `pause` | Esc, P | pause menu |

The `"affinity"` style swaps the events of `louder` and `softer`, so Up = softer.
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
- `ToneGenerator` (Node): `AudioStreamGenerator` at 44.1 kHz on the Tones bus.
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

The freq keys are `int`. The stub doesn't include the full per-presentation trails. Builder A may add keys,
but must not rename or remove these.

### §5.2 Scoring

- **Visit score:** `100 x (0.40·accuracy + 0.30·technique + 0.15·efficiency + 0.15·comfort/3)`.
- **Grades:** S at 95 or more, A at 85, B at 70, C at 55, and "Do-over" below that.
- **Coins:** `round(score/2)` plus the medal bonus (gold 10, silver 6, bronze 3).
- **Par (v2):** per measurement, the median presentations of a textbook search from that measurement's start
  level (typically 7-13). Golf names use run-sized bands (§2.5). Teaching defaults that need playtesting.

### §5.3 Visit summary (`Game.finish_visit()`, `Events.level_finished`)

```
{
  "patient_id": "gus", "score": 91.2, "grade": "A",
  "accuracy": 0.93, "technique": 0.98, "efficiency": 0.71, "care": 1.0, "comfort": 3,
  "medals": {"history": "gold", ...}, "coins_earned": 76, "coins_total": 76,
  "duration_s": 402.0, "audiometry": {...§5.1...}
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
```
**(v2)** `set_world_saturation` muffles at the sound sources (quieter, lower), never with bus effects. Nobody adds
or removes bus effects at runtime: it can deadlock the audio thread (world/INTEGRATION_NOTES.md).

During audiometry the story turns the main camera off (`current = false`). The AudiOtron covers the
screen and only the booth SubViewport renders.

In the cartoon world, Gus's right ear is world −X. The red cup goes on it.

### §6.2 Reaction kinds (`Events.patient_reaction(kind, data)`)

`heard`, `missed`, `false_alarm`, `too_loud_blast`, `startle`, `grooving`, `bored`, `straining`,
`squint`, `yawn`, `cheer`, `confused`, `point_wrong_way`, `nod`, `wince`.

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
3. **Ending.** On `Events.level_finished` it records the summary. On `results_continue` it prints
   `AUTOPLAY_RESULT {json}` and emits `Events.quit_requested(code)`.

**Exit codes:**

| Code | Meaning |
|---|---|
| 0 | ok |
| 2 | stalled for 120 game seconds |
| 3 | overall timeout |
| 4 | results sanity check failed: an ear is incomplete, a threshold is off by more than 10 dB, or there was no `level_finished` |
| 5 | script errors were logged |
| 6 | (`--mouse`) a mouse target could not be found on screen |

**Mouse-only mode (v2, `--mouse`).** Beats are solved by clicking or dragging what a player sees: the Hoot anchors
(`otoscope_seed`, `earphone_red` -> `ear_target_right`, `evidence_slope` -> `evidence_target`, the AudiOtron buttons;
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
- one shot per phase, named like `05_audiometry_right.png`;
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
- `tests/test_contracts.gd` checks this file's APIs. Update it together with this file.
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

**Bubble placement.**
- A screen can reserve a spot with `Hoot.set_bubble_hint(rect)` in viewport coordinates, and `clear_bubble_hint()` on exit.
- The AudiOtron reserves its right-hand column.
- With no hint, the bubble sits top-right below the HUD (y ≈ 176). Screens that need that area should set a hint.
