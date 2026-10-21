# ui/ integration notes

## Speech screen (Day 3, CONTRACTS.md §9.7)

`res://ui/speech/speech_screen.tscn`: a CanvasLayer on layer 20 with `class_name SpeechScreen`, built in code
in the AudiOtron's visual language. It reuses AoButton, AoDraw, AoFx, AoBoothWindow and AoStatus. Its own
widgets are `SpButton`, `SpLcd`, `SpLadder`, `SpAgreementMeter`, `SpWordCard`, `SpBubble` and `SpDance`.
Nothing under `ui/audiometer/` changed.

**API**

```
signal test_finished(results: Dictionary)
func start_test(patient: PatientProfile, ear: String, coached: bool, plan: Dictionary = {}) -> void
func get_state() -> Dictionary
func get_results() -> Dictionary
func demo_start() -> void
```

- `test_finished` carries the §9.5 merged results.
- `get_state()` returns the `SpeechSession.get_state()` keys plus `accepting_input`, `talking`,
  `answer_shown`, `hoot_turn`, `coached`, `patient_id` and `quick_visit`. It also adds three extras:
  `listening`, `finishing` and `hoot_turn_after`.
- `get_results()` returns `SpeechSession.merge_results(tones, speech)`, or `{}` before the first ear.
- `demo_start()` runs Mike with his tones from his profile, a coached right ear.

Lifecycle and ownership:
- The first `start_test` creates the session with `SpeechSession.new(patient, Game.rng.randi())`. The screen
  keeps it between ears and makes a new one when the patient changes.
- Every `start_test` calls `configure(plan)` and then `begin(ear, coached)`.
- The screen never calls `Stage.register_audiometer` and never emits `audiometry_started`.
- While it is in the tree it joins the group `speech_screen` and turns the booth view on.

**Plan keys:** `test` ("srt"), `tones` (required for the PTA), `list`, `words`, `exclude`, `level`,
`transducer`, `low_start_ok` (passed to the session), `hoot_turn_after`, `hoot_turn_after_up`, `intro`,
`hoot_turn_text`, `show_agreement` (default true), `done_title` (the big callout at the end of the ear) and
`fresh_session`.

**`fresh_session` (Hoot's recheck on Day 3):** this ear runs on a new session. The player's session is parked
(`_kept_session`) and comes back, with its sheets, on the next `start_test` without the key; the status card
keeps showing the player's points meanwhile.

**Feedback after a store (only a bracketed store is praised):** `SpeechScreen.is_bracketed(sheet)` reads the
sheet's `bracketed` (else `candidate_db` == `stored_db`). The word card's line reads "ear done: nice work!" only
for a clean bracketed store ("ear done: check Hoot's tips" after slips, "stored before a bracket", "the bracket
said N dB", "stored by Hoot, by the book"). `SpeechScreen.golf_text(sheet)` gives the golf callout: "Oops!" after
a slip or an unbracketed store, "Clean!" for a clean run over par (never "Par!" over "14 words, par 12"). The
fanfare and confetti only play for a bracketed or Hoot store. A clean store on an ear with earlier slips
(`session.slips()`) gets no combo callout, so no "Clean score!" appears under its "Oops!".

**Clean kinds with a message:** `srt_low_start` (the first step up after a first word at least 10 dB below the PTA with `low_start_ok`) takes the clean branch
(combo note, "+points") and shows its `message` as a once-per-visit Hoot tip pointing at `speech_ladder`.

**The tell:** once per visit, the first word rightly scored as repeated `TELL_GAP_DB` (30) dB or more below the
ear's PTA gets "He's repeating words N dB below his beeps. Hmm!", with the hand on `agreement_meter`
(`speech_ladder` when the meter is hidden), never on the answer bubble being judged. On the coached ear it
interrupts the coach's tip, which comes back after.

**`hoot_turn_after` (story builder):**
- **Only applies when quick visit is on.** Quick visit is the `quick_visit` setting, which `--quick` / `--full`
  override, or the screen's `quick_visit` var. With quick visit off, the player always runs the whole ear.
- **Missing:** Hoot never takes over.
- **0:** Hoot runs the whole ear, even when `coached` is true.
  - The plan's `intro` shows for 2 s.
  - On the next frame a banner appears and Hoot says `hoot_turn_text` (or a default line).
  - After 1.8 s `Engine.time_scale` is multiplied by 8 (base × 8, so x48 under the bot's `--speed=6`).
  - No player beat is emitted before or during his turn.
- **N > 0:** Hoot takes over once the player has presented N words on this ear and scored the last one.
- **With `hoot_turn_after_up`:** Hoot also takes over as soon as the player has scored a word stepped up after
  a miss (the bracket's first "missed: up 5"); N stays the cap. Day 3's solo left ear uses N = 12
  (`LevelMike.LEFT_SOLO_WORDS`).
- **During his turn:**
  - `session.scoring` is false, so his words never count, and the sheet has `by_hoot: true`.
  - He presses the screen's own buttons, following `recommended_action()`, on pausable timers.
  - The voice is muted during his turn. The TALK lamp and the answers still show.
- **Afterwards:** `Engine.time_scale` goes back to exactly the saved value, and `scoring` is true again.
  - This also happens if the screen leaves the tree mid-turn.
  - While the game is paused his turn drops to the base speed.

**Blocking beat (autoplay bot):** whenever the screen waits for the player, it emits
`Events.awaiting_input(&"speech", info, solver)` once per idle point.
- "Waiting" means: input is live, no word is playing, he is not answering, and it is not Hoot's turn.
- The shape of `info`:
  ```
  {"ear": "right", "test": "srt", "action": "louder", "target_db": 85, "mouse": {"click": "speech_louder_button"}}
  ```
- `action` is the `recommended_action()` name: `present`, `score_correct`, `score_missed`, `louder`,
  `softer`, `mask_toggle` or `store`.
- `mouse.click` is the Hoot anchor of the matching button. Its centre is a real click target, clear of
  Hoot's bubble.
- The solver sends the matching InputEventAction through `Input.parse_input_event`: a press, then a
  release 0.05 s later. The actions are `present_tone`, `speech_correct`, `speech_incorrect`, `louder`,
  `softer`, `toggle_mask` and `store`.
- A solver is stale once the state has moved on. A stale solver does nothing, and calling the same
  solver twice presses once.

**Anchors:** `speech_present_button`, `speech_correct_button`, `speech_incorrect_button`,
`speech_louder_button`, `speech_softer_button`, `speech_store_button`, `speech_mask_button`,
`speech_word_card`, `speech_response` (the answer bubble), `speech_ladder` and `agreement_meter`.
All of them are unregistered on exit.

**Events it emits:**
- `speech_started`, `speech_presented`, `speech_response`, `speech_scored` and `speech_stored`.
- `speech_state_changed` on every change.
- `speech_finished`, which fires about 4 s after the store and before `test_finished`.
- `technique_event` (every session kind, forwarded) and `combo_changed`.
- `dialogue_line(short_name, said)` for each answer, so the clinic can lip-sync. It is skipped for "...",
  "(shrugs)" and other non-spoken answers.
- `patient_reaction` through `Stage.react`: `nod` (correct or wrong word), `squint` (half word), `confused`
  (silence) and `cross_heard`.
- `screen_shake` when the agreement meter slams into POOR.

**Layout and other modules:**
- **Pause menu:** the screen has its own "II" pill (top right of the status card), which calls
  `get_first_node_in_group("pause_menu").open()`. The story's pause menu should hide its corner button
  while a `speech_screen` node is in the tree. `story/pause_menu.gd` already checks this group.
- **Hoot's bubble:** `Hoot.set_bubble_hint()` points at the screen's right column, under the status
  card (x = vp.x - 312, y ≈ 206, 300 wide, about 270 tall). Tips never cover the deck buttons. The hint
  is cleared on exit, together with `Hoot.clear()`.
- **Viewport:** the layout reads `get_viewport().get_visible_rect().size` and lays itself out again on
  `size_changed`. It was checked at 1280x720 and at a wider 1728x720.
- **Audio:** words and the masking noise go only through the screen's own SpeechVoice child. Sfx plays
  only UI blips. The music is ducked while the screen is up. Loudness gags are visual only.
- **Headless audio hang (fixed in core):** the suite used to hang at quit after the masking test. The cause
  was the engine mixing a freed generator stream (see `core/INTEGRATION_NOTES.md`); `SpeechVoice` now keeps
  its stream alive past its last mix, and the test plays the noise for real again.

**Deviations from §9.7 (small):**
1. **Meter reading while testing.** While testing, the agreement needle reads `max(0, PTA - provisional
   SRT)` and not `|provisional - PTA|`. The provisional SRT is the softest level the player has scored as
   repeated. With the plain formula a reliable patient starts in the red, since his first words are
   above the PTA. When the SRT is stored, the needle reads `|SRT - PTA|` as specified.
2. **STORE before a bracket.** The first press only warns: a tip, plus a chip saying "press again to store
   anyway". A second press within 4 s stores. On the coached ear it never stores: every press warns again
   ("not bracketed yet: keep going"). Hoot's turn and the beat solver handle this.
3. **Nod on a wrong word.** A confident wrong word also gets `nod`, alongside correct answers. Only half
   words and silence get the other reactions.
4. **Silent Hoot's turn.** The voice is muted during Hoot's x8 turn; the TALK lamp still lights.
5. **Extra state keys:** `listening`, `finishing` and `hoot_turn_after`.
6. **Style pill wording.** The pill reads "Up = LOUDER" with a "(default)" sub-line, or "Up = SOFTER" with
   "(swapped)".
7. **Coached-ear tips.** A technique error or an observation tip (for example `half_word`) briefly takes
   the sticky coach tip's place, at HIGH priority for 4 s. The coach's line then comes back.

## From the cases branch (Days 6 to 9; CONTRACTS.md §11)

The case runner uses the AudiOtron through its existing plan keys only (`test`, `ear`, `hoot_turn_after`,
`intro`, `bc_freqs`, `masking_controls`, `air_transducer`). Nothing in `ui/` was changed. Requests, all
optional and additive:

- **Hand over at a named frequency.** `hoot_turn_after` counts stamps, so Marina's "watch the low pitches"
  plan has to guess how many stamps reach 500 Hz (since E1: 8 on a second ear, 1k to 8k then 500; 9 when
  the ear owes the 1 kHz retest; Marina's case now uses 10, the whole ear). A plan key
  like `hoot_turn_at: 500` (Hoot takes over once that frequency is stored) would let a case hand the
  player exactly the frequencies it teaches.
- **"Masked air: confirmed" sweep.** When the rules ask for masked air and Hoot runs it at speed, a short
  banner or stamp ("MASKED AIR: CONFIRMED") would tell the player why the chart changed.
- **Skip the bone tickle lesson in Hoot's turns.** In a case, Hoot runs bone conduction at speed; the
  tickle tip still shows once per run. A plan key `tips: false` (or skipping the tip when the current
  turn is Hoot's) would keep the case moving.
- **(Day 12, done, small) No pen line through a masked no-response mark.** `audiogram.gd` `_refresh_segments`
  already skipped unmasked no-response points; where a frequency has a masked air mark, that mark now decides.
  Morgan's deaf ear answered unmasked (the shadow) but gave no response masked, and the line was joining the
  arrows. Only a masked no-response mark changes anything, so Days 1-11 and Freestyle draw as before. The shadow
  itself is drawn by the case board, not the audiogram (the audiogram still hides an unmasked O under a masked mark).
- **(C13, done, small) `SpeechScreen.run_hidden` names the patient.** Only `start_test` set the bubble's speaker, so a
  hidden run before any `start_test` (Day 5's montage, the cases' words check) labelled the bubble "Mike says".
  `run_hidden` now sets it from `patient.short_name()` too. Nothing else changes.
- **(Career-fair demo, done, small) Plan key `montage_after`.** On a quick visit, when the player's stamps run out
  (`hoot_turn_after`), Hoot fills in the rest of the ear in a montage instead of the x8 turn, saying the plan's
  `hoot_turn_text` (default "Nice work! I'll fill in the rest in a flash."). Both places that started Hoot's
  turn now call `_hoot_takes_over()`, which starts the x8 turn exactly as before unless the plan has the key, so
  every existing plan plays as it did. Used by `story/level_demo.gd`'s right ear (docs/DEMO.md).
