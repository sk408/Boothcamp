extends Node
## Events: the global signal bus (autoload "Events").
##
## Every signal that crosses a module boundary (core/ui <-> world/story <-> autoload/tools)
## is declared HERE and only here. Modules emit and connect; nobody stores state on this node.
## See res://CONTRACTS.md for who emits what. Rules:
##  - Emit with ALL arguments (GDScript signals have no optional args). Use "" / {} / -1 for "none".
##  - Ears are always the Strings "right" or "left". Frequencies are int Hz. Levels are int dB HL.
##  - Signals here are fire-and-forget. If you need to await an answer, await the signal itself.
##  - Module-internal signals stay in the module; do not add them here.

# ---------------------------------------------------------------- flow (main / story)

## Ask main.gd to swap the top-level scene (fade out, free old, instance new, fade in).
## Emitter: story (title -> level -> title). Listener: main.gd.
signal goto_scene(path: String)
## main.gd emits after a new top-level scene is in the tree.
signal scene_changed(path: String, node: Node)
## Story emits whenever the level moves to a new beat. Listeners: autoplay bot (screenshots),
## world (camera), Hoot (clears low-priority tips). Phases: see Game.PHASES / CONTRACTS.md §3.
## info examples: {"ear": "right"} for &"audiometry".
signal phase_changed(phase: StringName, info: Dictionary)
## Story emits when a patient visit starts / when the results screen is reached.
signal level_started(patient_id: String)
## summary = Game.finish_visit() return value (CONTRACTS.md §5.3).
signal level_finished(summary: Dictionary)
## Emitted whenever the game blocks waiting for the player OUTSIDE the audiometer
## (dialogue line, choice, I-spy, drag, evidence, fitting button, results "continue").
## solver: a no-argument Callable that completes the beat the "good" way through the same
## code path a click would use. The autoplay bot calls it. Required for every blocking beat.
## beat ids: see CONTRACTS.md §3.2.
signal awaiting_input(beat: StringName, info: Dictionary, solver: Callable)
## Optional: emitted when a blocking beat is completed (by the player or the solver).
signal input_resolved(beat: StringName)
## Anyone may ask for a screenshot at a key moment; only acts when --shots=DIR was given.
signal screenshot_requested(shot_name: String)
## Pause menu (story) emits when it opens/closes.
signal pause_toggled(paused: bool)
## Ask to quit the app (used by the bot and the title "Quit" button). main.gd handles it.
signal quit_requested(exit_code: int)

# ---------------------------------------------------------------- settings / save (Game)

## Game emits after any settings value changed (already applied and saved).
signal settings_changed(key: String, value: Variant)
## Game emits after the key style changed: "otosuite" (Up = louder) or "affinity" (Up = softer).
signal key_style_changed(style: String)
## Game emits when comfort hearts change during a visit (0..3). reason: short id, e.g. "too_loud".
signal comfort_changed(hearts: int, reason: String)
## Game emits when the coin total changes.
signal coins_changed(total: int, delta: int)
## (v3) Game emits from finish_visit() when a chapter (day) is completed for the first time or again.
## newly_unlocked: chapter ids that this completion unlocked (Array of String, often empty).
signal chapter_completed(chapter_id: String, newly_unlocked: Array)

# ---------------------------------------------------------------- dialogue (story)

## Story emits each time a line of dialogue is shown (captions log, bot log, Hoot voice blips).
## speaker: "Gus", "Hoot", "Doris", "" for narration.
signal dialogue_line(speaker: String, text: String)

# ---------------------------------------------------------------- Professor Hoot (tips)

## Request a tip. Anyone emits. The Hoot autoload owns the queue (priority, de-dupe, timeouts).
## priority: Hoot.LOW / NORMAL / HIGH / URGENT (0..3). URGENT interrupts the current tip.
## ghost_hand_target: an anchor id registered with Hoot.register_anchor(), or "" for none.
## Text: 18 words max (Hoot warns in debug). Prefer Hoot.say_once(key, ...) for gag lessons.
signal hoot_say(text: String, priority: int, ghost_hand_target: String)
## Hoot autoload emits when a tip should appear. tip = {id, text, priority, target, key, duration}.
## Listener: the bubble view (res://story/hoot_bubble.tscn).
signal hoot_tip_shown(tip: Dictionary)
## Hoot autoload emits when a tip is gone (clicked, timed out, replaced or cleared).
signal hoot_tip_dismissed(tip_id: int)
## Hoot autoload emits when Hoot praises mastery (a skill reached 3 clean uses). View may show a wing-thumbs-up.
signal hoot_mastered(skill: StringName)

# ---------------------------------------------------------------- audiometry (core/ui emit)

## The audiometer screen emits when start_test() begins a test of one ear.
signal audiometry_started(patient_id: String, ear: String, coached: bool)
## A tone began / ended. duration_s is the presented duration (game-time seconds).
signal tone_started(ear: String, freq: int, db: int)
signal tone_stopped(ear: String, freq: int, db: int, duration_s: float)
## The patient pressed the response button (always simulated, never the player's ears).
## tone_related: true when the press came during a tone or inside the response window after
## it (what a clinician would count as a response); false = an obvious false alarm in silence.
signal patient_responded(ear: String, freq: int, db: int, tone_related: bool)
## Any change of the audiometer controls or progress. state shape: CONTRACTS.md §4.3.
signal audiometer_state_changed(state: Dictionary)
## A threshold (or no-response) was stored. info shape: CONTRACTS.md §4.4.
signal threshold_stored(ear: String, freq: int, db: int, info: Dictionary)
## Technique checker verdicts, for Hoot tips, gags and callouts. kinds: CONTRACTS.md §4.5.
signal technique_event(kind: StringName, data: Dictionary)
## Textbook combo changed. n = consecutive rule-correct actions, multiplier = 1, 2, 3 or 5.
signal combo_changed(n: int, multiplier: int)
## All required measurements of one ear are stored. ear_results = results.ears[ear].
signal ear_completed(ear: String, ear_results: Dictionary)
## Mirror of AudiometerScreen.test_finished for global listeners. results: CONTRACTS.md §5.1.
signal audiometry_finished(results: Dictionary)
## (v3) The masking noise changed: turned on/off, or its level (dB EM) or frequency moved.
## ear = the MASKED (non-test) ear. Every masker lights an on-screen indicator (CONTRACTS.md §1.3).
## Emitter: the AudiOtron. Listeners: world (noise squiggles on that cup), bot logs.
signal masker_changed(ear: String, freq: int, db: int, on: bool)
## (v3) The AudiOtron's active transducer changed (start_test or a switch): &"phones",
## &"inserts" or &"bone". ear = the test ear.
signal transducer_changed(transducer: StringName, ear: String)

# ---------------------------------------------------------------- world (story/ui emit, world listens)

## Ask the visible patient to react. kinds: CONTRACTS.md §6.2 (Clinic.REACTIONS).
## data may carry {"ear": "right", "intensity": 0..1, "db": 90}.
signal patient_reaction(kind: StringName, data: Dictionary)
## Small screen shake request (0..1). Listeners respect Game.settings.reduced_motion.
signal screen_shake(strength: float, duration_s: float)
