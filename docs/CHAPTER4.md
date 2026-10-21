# Booth Camp, Chapter 4 (Day 4): Nora Nightingale, "Word recognition (WRS)"

This is the design of the fourth playable day, as built. It covers the word recognition score (WRS) at a level loud
enough for every sound, whole-word scoring, the speech banana seen through the patient's own ears, masking speech,
ear differences beyond chance, rollover (a louder list scores worse), "her best is worse than her tones predict",
and a referral for a doctor's check, with imaging requested, before any fitting. The shared speech rules and numbers
live in `docs/SPEECH.md` §4. The API is `CONTRACTS.md` §9.10-§9.24; where this doc and the contract differ, the
contract wins, and the decisions D1-D30 there are the ones this doc follows. Days 1-3, 6-13 and the walk-ins do not
change. Steve checks every number and every clinical line (§17).

**Clinical review (2026-10-19).** The project's clinical review changed four Day 4 grading rules and three lines
before the day shipped (`docs/CLINICAL_REVIEW.md`). They are folded in below, marked with their ids:
- **A1** the predicted minimum ("her tones predict at least") is a new 25-word table, interpolated;
- **A2** rollover is the rollover index, with the poorer score taken from a louder level;
- **A3** two ears differ when their scores are too far apart for chance on lists that long (the 25-word critical
  difference), not at a fixed 20 points;
- **A4** word-list noise adds the other ear's air-bone gap (Nora has none);
- **A5** Hoot says real clinics use recorded lists; the "slowly" card says "Slow still counts when one ear lags";
  the level is "loud enough for every sound, never uncomfortable", never "comfortably loud" as the goal;
- **A6** five new open questions (§17, Q27-Q31).

| | |
|---|---|
| Teaches | WRS at a level loud enough for every sound, never uncomfortable (the game's rule: PTA + 35, never below 55); one-syllable words scored whole (25 words, 4% each); the speech banana and which sounds a high-pitch loss steals (Nora-vision); speech noise in the better ear when loud words could cross (explained in the movie first); ears too far apart for chance; rollover (a louder list scores worse); a best score worse than the tones predict; red flags, and a referral for a doctor's check before any fitting |
| Length | about 11 minutes on a first visit with quick visit on (the default), including the 70 s movie; about 10 on replays (the movie is offered, and skipping is the default). About 17 minutes with quick visit off. If Day 2 was never played, the masking movie (about 90 s) is offered first. The bot's keyboard run takes about 10 game-minutes. |
| Opens | always, from the Days grid. `requires` = `mike` only picks the "UP NEXT" hint. |
| New controls | The SPEECH screen's new WORD mode. **Space** presents a word. **Up / Down** set the level (hold to repeat), before the first word only. **Right** (or + / =) means she repeated the whole word; **Left** (or -) means she missed it. **M** turns speech noise on or off. **V** turns NORA-VISION on or off (the new action `toggle_lens`). There is no STORE: a list ends itself after 25 words. "Call it" and the Red-Flag Roll Call use the same **Right / Left** keys, or their buttons. Every control is also a button. The swap-arrows style swaps only the level keys, exactly as on the SRT screen. The movie uses the shared player's controls (Space, Enter or a click: next, like the dialogue box; Esc: skip the movie; P or the "II" button: pause). |
| Level scene | `res://story/level_nora.tscn` (`story/level_nora.gd`). Movie data: `res://story/explainers/movies/letter_choir.gd`, drawn by its own sets script `res://story/explainers/stages/letter_choir_sets.gd` (`MOVIE.stage`), played by the shared `explainer_player.tscn` |

---------------------------------------------------------------------------------------------

## 1. The patient

**Nora Nightingale**, 58, choir director of the Nightingale Singers (forty voices, rehearsals every Thursday). She
has a silver bob held up by a small tuning fork used as a hair pin ("Middle C. For emergencies."). She wears a navy
scarf printed with cream music notes and a forest-green cardigan. Pearl opera glasses hang on a chain, and a baton
pokes out of her breast pocket. She is warm and theatrical, says "darling" now and then (three lines a visit at
most), and hums when she is nervous. Her favourite note is A flat. She is worried but brave, and never tragic.

> "My left ear has gone like a radio between stations. I hear the voices. I just can't make out the WORDS."

She comes in humming a scale and stops on a note ("(hums up a scale) Do, re, mi, fa, so... (stops on a note) Mmm.").
Nora: "Your hoot is a touch sharp, Professor. Try an A flat. My favourite. Terribly misunderstood." Hoot: "I've been
called sharp before. Questions first, then beeps, then words." That setup is always heard, so the A-flat payoff at the
door (§12) always lands. Her pronoun is she and her short name is Nora. Her bean spec (`world/characters/bean.gd`,
`NORA`): a silver bob, a tuning-fork pin, the notes scarf, and the opera glasses on a chain. The glasses hang on her
torso, so the clinic's head gear (which takes `parts["glasses"]` off) leaves them alone. Her portrait (`Portraits`
"Nora") is BG `#d8f0e4` with the name colour `#2f7d5b`; the dialogue box names her "Nora Nightingale"; her voice is
registered at run time (`Voice.register("Nora", {f0: 230, wobble: 0.09})`).

**Case history** (two rounds of three choices. Prompts: "Ask Nora a question:" then "Next question:"):

| Round | Question | Points | Answer | Case note |
|---|---|---|---|---|
| 1 | Any ringing, or dizziness? | 2 | "A hiss in the LEFT, like a kettle that never boils. And I wobble on stairs sometimes. No pain, no drips." | Hiss in the left ear only; some unsteadiness on stairs; no pain or discharge |
| 1 | Any loud noise over the years? | 1 | "Forty sopranos every Thursday. But they stand on my RIGHT." | Choir noise, reaches both ears |
| 1 | Do you hum to test your ears? | 0 | "Doesn't everyone?" | (joke) |
| 2 | Which ear? Did it come on suddenly or slowly? | 2 | "The left. It crept up slowly, over about a year. Nothing sudden. The right is still lovely." | LEFT ear, gradual over about a year, nothing sudden |
| 2 | Where is it hardest to follow words? | 1 | "Rehearsals. The altos stand on my left, and it's all mush. I hear them. I can't make out the words." | Left: hears voices but not words |
| 2 | Could you sing me your symptoms? | 0 | "(sings) Oh, left ear, why so fuzzy... That's the whole aria, darling." | (joke) |

- **The onset question is worth 2.** The REFER-or-DOCTOR-TODAY call (§7) rests on "slowly, not suddenly", as on
  Days 3 and 5.
- **Nothing important is lost by a pick.** Her opening line names the left ear. If the player skips the onset
  question, Nora adds after round 2: "Oh, and it crept up slowly, over about a year. Nothing sudden." There are no
  points for that, and `asked_onset` stays false.
- **The red-flag sweep.** If the player never asks "Any ringing, or dizziness?", Hoot asks it after round 2 (H-HIS-5)
  and Nora gives the same answer. `asked_red_flags` stays false, and the case note is still written.
- **Medal `history` (Chat).** Gold = 4 points (the 2-point question in both rounds). Silver = 2 or 3. Bronze = 0 or 1.
- After the history, Hoot says: "One-sided hiss, one-sided mush, wobbly stairs. We measure carefully, then decide
  who she sees." The case notes gain "One-sided hiss and wobbly stairs: sort the red flags after the tests." That
  sets the stakes: measure carefully and refer wisely. Nobody guesses a diagnosis.

## 2. Truth tables (`core/patients/nora.tres`)

**Tone thresholds** (dB HL). There is no `bc` data, so bone equals air: a sensorineural loss in both ears.

| Hz | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| right (O) | 10 | 10 | 10 | 15 | 15 | 20 | 25 | 30 | 35 | 40 |
| left (X) | 30 | 35 | 35 | 40 | 45 | 45 | 50 | 55 | 55 | 60 |
| left minus right | 20 | 25 | 25 | 25 | 30 | 25 | 25 | 25 | 20 | 20 |

- **PTA** (500/1k/2k): right 15.0, left 40.0. The three values spread only 10 dB, so the 3-frequency average is
  used in both ears. The ears differ by 25.
- **Asymmetry.** The left is 20 to 30 dB worse at every frequency (`CaseRules.is_asymmetric`: 15 dB at two or more
  neighbouring frequencies).
- **The chart.** 1.5k, 3k and 6k are routine on every ear (`ClinicRules.ROUTINE_FREQS`, E1), so Hoot charts nine
  frequencies. Neighbouring octaves never differ by 20 dB or more, so 750 Hz is never needed; the lens and the
  predicted score read it by interpolating between 500 and 1k (`interp_threshold`).

**Interaural attenuation:** phones **50** (instead of the default 60), inserts 75. With 50, unmasked speech at 75 dB
reaches her right cochlea at about 25 dB HL, 10 dB above her right SRT, so the Ghost really does steal words. The
clinic's masking rule still uses 40 for phones (`SpeechRules.SPEECH_IA_DB`).

**Her head:** false alarms 0.3 per minute; reaction 0.7-1.2 s; slope 2.5; attention 0.95; fatigue 0.0005; rhythm
sensitivity 0.6. `tinnitus_hz` is 0: the hiss is a history fact only, so Hoot's tones stay clean. Tags `speech`,
`chapter_4`.

**Speech** (the `speech` field):

```
speech = {
  "srt":      {"right": 15, "left": 40},
  "wrs_max":  {"right": 96, "left": 52},
  "rollover": {"left": {"after": 75, "drop_per_10db": 20}},
  "neural":   {"left": true}
}
```

`neural` left means her left ear's misses are spread at random. They do not follow the banana, so she can miss a word
whose every sound reached her (the "audible, but missed" moment, §5.3).

### 2.1 What a textbook player sees

All numbers come from the `SpeechRules` functions and the WRS helpers (contract §9.11-§9.15, with A1-A4). They are
pinned in `core/tests/test_speech_wrs.gd` (§16).

| | right | left |
|---|---|---|
| Air (Hoot's montage), 250 / 500 / 1k / 1.5k / 2k / 3k / 4k / 6k / 8k | 10 / 10 / 15 / 15 / 20 / 25 / 30 / 35 / 40 | 30 / 35 / 40 / 45 / 45 / 50 / 55 / 55 / 60 |
| Bone, unmasked (Hoot, on her right mastoid), 1k / 4k | 15 / 30: on her air lines (her better ear) | not run |
| Bone, masked (Hoot, noise in the right), 1k / 4k | not run | 40 / 55, the same as air: sensorineural |
| Best bone per frequency (`ear_best_bone`), 500 / 1k / 2k / 4k | 10 (air) / 15 / 20 (air) / 30 | 35 (air) / 40 / 45 (air) / 55 |
| PTA (3-frequency) | 15.0 | 40.0 |
| SRT start (`srt_start`) | 30 | 55, with noise on (55 - 40 = 15 >= right air 10; noise 35) |
| SRT and agreement | 15, good (0 dB apart) | 40, good (0 dB apart) |
| WRS level (`wrs_level`) and window (`wrs_window`) | **55** (15 + 35 = 50, but never below 55); 50-60 | **75** (40 + 35); 70-80 |
| Speech noise needed? (`nontest_best_bone`, IA 40) | **no**: 55 - 40 = 15 is below her left ear's best bone (35) | **yes**: 75 - 40 = 35 >= the right ear's best (10). Noise **55** (`wrs_mask_level`: 75 - 20 + no gap, inside [35, 70]) |
| (A1) Tones predict at least (`wrs_predicted_min_interp`, the sheet's `predicted_min`) | **82%** | **60%** |
| `predicted_wrs_max` (her measured chart; information only, her `wrs_max` wins) | 95% | 91% |
| Audibility at the WRS level (`wrs_audibility`) | 0.996 | 0.990 |
| Comfortable list, expected score | Word list 1: p 0.956, 24 words = **96%** (92-100%), excellent | Word list 2, masked: p 0.515, 13 words = **52%** (48-56%), very poor (56 reads "poor") |
| Louder list (20 dB up, noise locked on) | not run | Word list 3 at **95**, noise **70** (95 - 20 = 75, clamped to her left best bone 35 + 40 - 5): p 0.120, 3 words = **12%** (8-16%) |
| (A2) Rollover (`wrs_rollover`) | | PBmax 52 at 75, PBmin 12 at 95 (a louder level): index (52 - 12) / 52 = **0.77**, at least 0.45, so rollover. The worst deal (48 then 16) gives 0.67. |
| Her best (`pb_max`) against the prediction | 96 >= 82: best final at once | 52 < 60: **below predicted**, said only once the louder list is done (D13) |
| (A3) The ears (`wrs_differ` on the bests, 25 words each) | chance alone gives 80-100 (`wrs_same_range`) | chance alone gives 28-76: the ranges do not overlap, so 96 vs 52 is **too far apart for chance** (the worst deal, 92 vs 56, too) |

"p" is the chance she repeats a word: `wrs_max x A(L) - rollover_drop(L)`. A is the audibility curve. The rollover
term is `max(0, L - 75) / 10 x 20%`. The count is `round(p x 25)` plus -1, 0, 0 or +1 (one draw per list; contract
§9.12.1).

**Noise checks.** List 2's noise 55 reaches her left cochlea at 55 - 50 = 5 dB (the real IA). The louder list's 70 is
the clinic's maximum (left best bone 35 + IA 40 - 5) and reaches her left cochlea at 70 - 50 = 20 dB, under her left
bone (35 and up). The minimum, 95 - 40 = 55, is below it, so the clamp always has room. Hoot names the cap with the
`wrs_mask_capped` tip ("Noise 70, not 75: any louder and it could reach her test ear too."). (A4) The noise adds the
other ear's air-bone gap (`nontest_largest_abg`); Nora's right ear has none, so her numbers do not change.

### 2.2 Robustness (Hoot's wobble and the deal)

Hoot's tone run wobbles a little: each stamp lands within 5 dB, about 2 times in 3 exactly. That moves the measured
left PTA, the comfortable level and the predicted minimum, which is interpolated between the rows of A1's table (so
a PTA of 41.7 gives 58).

| measured left PTA | chance | comfortable level (noise) | (A1) predicted min | comfortable list | louder list (noise) | (A2) rollover index, worst deal |
|---|---|---|---|---|---|---|
| 35.0 | 0.5% | 70 (50) | 66 | 52% (48-56) | 90 (70): 20% (16-24) | 0.62, worst 0.50 |
| 36.7 | 5.6% | 70 (50) | 64 | 52% (48-56) | 90 (70): 20% (16-24) | 0.62, worst 0.50 |
| 38.3 | 23.6% | 75 (55) | 62 | 52% (48-56) | 95 (70): 12% (8-16) | 0.77, worst 0.67 |
| 40.0 | 40.7% | 75 (55) | 60 | 52% (48-56) | 95 (70): 12% (8-16) | 0.77, worst 0.67 |
| 41.7 | 23.6% | 75 (55) | 58 | 52% (48-56) | 95 (70): 12% (8-16) | 0.77, worst 0.67 |
| 43.3 | 5.6% | 80 (60) | 56 | 40% (36-44) | 100 (70): 0% (0-4) | 1.00, worst 0.89 |
| 45.0 | 0.5% | 80 (60) | 54 | 40% (36-44) | 100 (70): 0% (0-4) | 1.00, worst 0.89 |

- The comfortable level is 75 in 88% of runs, 70 in 6% and 80 in 6%. The right ear's level is always 55, and its
  predicted minimum stays at about 82 (80-84 across the wobble), below its worst score (92).
- **Every row raises every flag** with one rule each: her best (always the comfortable list) is below the prediction
  (56 or less against 58 or more), the ears are too far apart for chance (92 or more against 56 or less), and the
  rollover index is 0.50 or more (the cut-off is 0.45). `test_nora_rows` and `test_predicted_min_interp` pin this.
- **The noise ceiling wobbles too.** Her left best bone reads 30-40, so the louder list's noise is 65-75 (70 on a
  textbook run). At most 75 - 50 = 25 dB reaches her left cochlea, under her bone, so no score changes.
- The lines never hard-code 60 or 82: they take `{min}` from the sheet.
- A right list scored below its prediction (only possible by scoring several real hits as misses) leaves the right
  ear's best open, so the ear verdict is held and the "apart" Roll Call card turns FINE. The other flags still refer.

### 2.3 What-ifs (wrong set-ups)

| Set-up | Result | What the game does |
|---|---|---|
| Left at 75, **no noise**, phones (real IA 50) | p_test 0.515, p_cross 0.385, so 0.702 combined: **72%** (68-76) | The BOO chip first (§5.4). If the player presses PRESENT again, she scores 3 words, Hoot finishes at top speed ("That set-up can't count, so I'll finish this list at top speed!"), and the reveal says "72%? The Ghost helped, so this list can't count. Noise on, fresh list." The coached redo on the next list follows. |
| Left at 75, no noise, inserts (real IA 75) | 52%: nothing crosses | The rule still asks for noise (75 - 55 = 20 >= 10), so the BOO chip still shows, and a confirmed list still does not count. |
| Left at 60 (outside 70-80), confirmed | 0.52 x A(60) = 0.52 x 0.832 = 0.43: 11 words, 44% | The level chip first. If confirmed: 3 player words, Hoot finishes, "44%, but at the wrong level, so this list can't count. Fresh list, right level.", and the coached redo. |
| The louder list without noise | cannot happen | its noise is locked on (`lock_noise`) |

### 2.4 Nora-vision numbers (what reaches her ear)

For each sound the margin is `SpeechRules.sound_margin(sound, dial, measured thresholds)`: the sound's level (dial
plus its `SOUND_CUES` offset) minus her threshold there. Below 0 the sound is lost (faded, dotted outline). From 0 to
3 dB it is "only just" (full ink, dotted underline). From 3 dB up it is clear (D18). These use her **measured**
thresholds (Hoot's nine frequencies, with 750 interpolated), so the lens never shows anything the player could not
know.

| Ear, dial | Lost (margin, dB) | Only just | Clear |
|---|---|---|---|
| Right 50 | s -5, f -12, th -15 | z 0, t 0, v +2 | the rest |
| Right 55 (List 1) | f -7, th -10 | s 0 | the rest (z and t +5) |
| Right 65 | none | th 0 | the rest (f +3) |
| Right 70 and up | none | none | everything |
| Left 40 (where the redo's dial starts) | everything, even the vowels (-2.9) | | |
| Left 50 (**chat level**, the tea demo) | s, f, th, z, v, sh, ch, j, t, k, p, h, b, d, g (-10 to -40); ng -3, r -2, y -5 | m 0, n 0, l +0.1 | w +3, vowels +7.1 |
| Left 65 | s -15, f -22, th -25, z -10, v -8, t -10, k -2, p -5, h -10 | ch +2, j, d and g 0 | the rest |
| Left 70 | s -10, f -17, th -20, z -5, v -3, t -5, h -5 | p 0 | the rest (k +3) |
| Left 75 (List 2) | s -5, f -12, th -15 | z, t and h 0, v +2 | the rest |
| Left 80 | f -7, th -10 | s 0 | the rest |
| Left 95 (the louder list) | none | none | everything (th +5). Yet she scores 12%. |

- `SpeechRules.CHAT_DB := 50` is the "chatting level" mark on the dial.
- Words built only from sounds that clear 8 dB at 70 on her left (sh, b, m, n, ng, l, r, w, y and vowels; "moon",
  "ring", "shell") stay fully audible at 70, 75 and 80 whatever Hoot's wobble does. Word lists 2 and 3 put at least
  two of them in places 2-6 (§6), so "Call it" #2 and the stamp always have a word to land on.

## 3. Beat by beat

### 3.1 Who does what, and in what order

- **Better ear first.** The right ear (PTA 15) goes first in every test. Hoot says so out loud.
- **Hoot runs every tone test, unscored, whatever quick visit says** (his montage: the stamps fly in, as on Day 3,
  where Hoot runs Mike's tones). Right air (the visit's first air ear, so its montage owes the 1 kHz retest, E2),
  left air, then unmasked bone on her right mastoid at 1k and 4k, then masked bone on her left at 1k and 4k (noise in
  the right). The AudiOtron asks for masked bone only where an unmasked bone stamp shows a gap, so the unmasked right
  run comes first: the cases' one-sided pattern. That is about 1:00. Bone and masking were taught on Day 2; today's
  lesson is words.
- **The SRT in both ears**, right first.
  - Quick visit on: Hoot's SRTs run off-screen (`screen.run_hidden`, D23). The agreement meter swings to GOOD twice,
    and Hoot says one line. About 0:10.
  - Quick visit off: the player runs them, solo when `mike` is in `chapters_done`, else with Day 3's coach (D30).
- **The word lists are always the player's.** Word lists are handed out in play order (D25, `next_list()`):
  - **Word list 1**: right ear at 55, coached.
  - **Word list 2**: left ear, solo. Hoot first parks the dial at chat level for the tea demo. Then the player sets
    the level (75) and decides about noise.
  - **The redo** (only when List 2 cannot count: unmasked, or outside the window): left, coached, the next list
    (`words_3`). The Ghost lurks on it.
  - **The louder list**: left, 20 dB above the counted comfortable list, coached, the next list (`words_3`, or
    `words_4` after a redo). The noise is locked on.
- **Quick visit trims the lists**: `QUICK_WORDS := {&"right": 8, &"left": 8, &"redo": 5, &"louder": 5}`. Then Hoot
  finishes the list at top speed (List 1: "Lovely scoring! I'll score the rest at top speed."; the others: "I'll
  score the rest at top speed!"). The score covers all 25 words; accuracy and golf count only the player's words.
  With quick visit off, the player scores all 25.
- **A confirmed wrong set-up** on List 2: the player scores 3 words, then Hoot finishes at top speed whatever quick
  visit says (`confirmed_wrong_hoot_after` 3), so the reveal comes fast. The redo then gives the player 5 words (25
  with quick visit off).
- **No familiarisation for word lists.** Hoot says why: "No practice run: word lists test her first try." (§17 Q13.)
- **(A5) Recorded lists.** Before List 1 Hoot says: "Real clinics play recorded word lists, so every patient hears
  the very same voice." (§17 Q14.)

### 3.2 The beats

Every blocking beat emits `Events.awaiting_input(beat, info, solver)`. "Hoot runs" means Hoot's turn at top speed (not
scored).

| # | Phase (`phase_changed`) | What happens | Beat(s) | Time |
|---|---|---|---|---|
| 0 | `explainer` | If the masking movie is unseen and `bonnie` is not done, Hoot offers it once (§4.4). Then "The Letter Choir" (§4): until it has been seen (reached its `count` scene) Hoot announces it ("New trick today: WORD SCORES. A quick cartoon first, then our next patient!") and it plays; after that Hoot offers it ("Hoot's word movie again? Popcorn's on me!"; the best answer is to skip). A skip gets H-MOV-3. | the player's own `explainer` beat; `choice` on replays | 1:15 |
| 1 | `intro` | Nora hums in. The tuning gag with the A-flat setup (§1), her "radio between stations" line. Hoot: "Day 4, trainee: word scores! Loud enough is easy. CLEAR enough is the question." | dialogue | 0:40 |
| 2 | `history` | Two rounds (§1). Nora's onset aside or Hoot's red-flag sweep fills any gap. Medal `history`. | `choice` x2 | 1:00 |
| 3 | `otoscopy` | Clear canals, healthy eardrums (the card opens with a fresh speculum, clinical review A1). The tuning-fork-in-her-hair gag. | dialogue | 0:20 |
| 4 | `instructions` | Pick the right instruction. Wrong picks are removed one by one (the Day 3 loop). Medal `instructions`. | `choice` | 0:30 |
| 5 | `audiometry` {right, ac}, {left, ac}, {right, bc}, {left, bc_masked} | Hoot's routine line first (clinical review A1, H-TON-0). Hoot runs right and left air, unmasked bone on her right at 1k and 4k, then masked bone on her left there. While the masking movie is unseen, the 12-second recap card and H-TON-R come before the masked run (clinical review A2, as on the case days). "Masked bone sits right on her air lines: sensorineural. Left 20 to 30 dB worse." When `bonnie` is not done, the Ghost gets its own line before the masked run (§11). | (AudiOtron, Hoot) | 1:00 |
| 6 | `speech` {right, srt}, {left, srt} | "Now the words. First her SRT in both ears: the softest level for words." Quick visit on: the hidden run and one line. Quick visit off: the player's SRTs. | (speech beats when the player runs them) | 0:15 |
| 7 | `speech` {right, wrs} | The recorded-list line (A5). **Word list 1, coached.** WORD mode opens with the card, the score strip, the level chip and the NOISE box. Hold to 55; no noise this ear. After word 2, Nora's opera glasses (`lens_try`), and the Banana Board slides in. "Call it" #1 on the first faint-letter word. Hoot finishes: **96%, excellent**, about what her tones predict. | `speech`, `lens_try`, `call_it` | 1:15 |
| 8 | `speech` {left, wrs} | **Word list 2, solo.** The tea demo at 50, then the player sets the level and decides about noise. The BOO chip if unmasked. One self-correction, chatty answers, the "Mike?" aside. "Call it" #2 and the AUDIBLE, BUT MISSED stamp. **52%**: "Is that her best?" The ear compare appears. If the list cannot count: the coached redo. | `speech`, `call_it` | 1:30 |
| 9 | `speech` {left, wrs, louder} | "Left ear: 52%. What next?" The best pick is a new list 20 dB louder. The comfort check. **The louder list, coached**, in the loud bubble: **12%**. The rollover slide. On its done screen the verdicts land: her best is below the prediction, and the ears are too far apart for chance. | `choice`, `speech` | 1:00 |
| 10 | `evidence` | **Red-Flag Roll Call** (§7): nine cards, one at a time; sort each one. Medal `evidence`. | `flag_pick` x9 | 0:30 |
| 11 | `referral` | The stamp tray: FIT / **REFER** / DOCTOR TODAY. The letter is a sheet of music; Nora signs it with a baton flourish and it slides into an envelope for the EAR DOCTOR. The safety-net line. Medal `referral`. | `choice` (`choose_stamp`) | 0:45 |
| 12 | `referral` | The payoff: Nora's worry, Hoot's honest answer, the altos tactic, the thank-you trill, the A-flat door gag. | dialogue | 0:45 |
| 13 | `results` | The Daily Decibel, Day 4 (§10). | `results_continue` | 0:40 |

That is about 11:00 with quick visit on and the movie watched; about 10:00 on replays. A confirmed wrong set-up adds
about 0:40 (3 words, Hoot's fast finish, the redo's 5 words). With quick visit off (the player's SRTs and all 25
words of each list) it is about 17 minutes. The redo's phase info adds `redo: true`.

### 3.3 State and flow

- **The HUD steps**: Chat, Peek, Explain, Beeps, SRT, Words R, Words L, Louder, Flags, Call (the title "NORA
  NIGHTINGALE'S VISIT"; Words R in the right ear's red, Words L and Louder in the left ear's blue).
- **Visit flags** (`Game.visit`): `movie_watched`, `asked_red_flags`, `asked_onset`, `instructed`,
  `instructed_first_try`, `masked_first_try`, `wrs_redo` ("" / "unmasked" / "level"), `lens_used`, `boo_seen`,
  `ghost_words` (the words the other ear answered), `call_it` (the guesses, in play order: {moment, word, guess,
  outcome}), `flag_slips`, `decision_first`, `decision` and `decision_tries`.
- **The flow functions** in `story/level_nora.gd` follow `level_mike.gd`: `_masking_offer` and `_movie` (§4.4),
  `_intro`, `_history`, `_otoscopy`, `_instructions`, `_tones` (the `level_case.gd` pattern: `put_on_bone_oscillator`
  and `put_on_masking_phone`), `_speech` (`_srt`, `_list_right`, `_list_left`, `_redo_if_needed`, `_louder`),
  `_evidence`, `_referral`, `_payoff` and `_results`. Helpers: `next_list()` (play order, D25), `list_plan(kind,
  list_id, quick, n)`, `roll_call_cards(results)`, `letter_text(results)`, `subheads(results)`, `tone_gap()` and
  `gap_words()`, `history_medal()`, `masking_medal()`, `ghost_words()` and `call_its()`. Hoot's off-screen work and
  the fallback for a missing SPEECH scene use `SpeechSession.run_by_textbook(ear)` (C23); `level_mike.hoot_runs_ear`
  is not copied. `_shot("...")` calls name the `day4_*` screenshots of §15.
- **The plans** for each list are exactly contract §9.21 (Day 4). The level's data constants:
  - `NORA_CHATTER := ["Like a good downbeat.", "Lovely and clear, that {word}.", "I'd know it anywhere.", "Next!"]`.
    The word model writes the word first ("Seal! Like a good downbeat."), and the line keeps to 6 words or fewer
    around it (contract §9.12.1);
  - `NORA_SILENCES := ["Sorry?", "Mm?", "(hums uncertainly)"]`;
  - `TEA_DEMO` (§5.6).

## 4. The explainer movie: "The Letter Choir"

### 4.1 What it teaches, and what it leaves for the day

Eight scenes, 70 s, one idea each. It opens with what the movie answers (Steve's rule, 2026-10-19: every movie first
says what it will explain): why loud-enough words can still come out mushy, and that a word score counts clear words.
Then: speech sounds differ (choir); the speech banana (banana); a high-pitch loss hides the soft high sounds
(curtain); so speech is heard but not understood (mush); loud enough for every sound, never uncomfortable, brings most
sounds back (louder, which says "most", because the lens will still show faint letters at 55 and 75); loud words can
cross to the good ear, and speech noise there keeps them out (crossing: the masking idea before the player needs it
on List 2); 25 whole words at 4% each (count); and a teaser (tease). The movie shows none of Nora's numbers, no red
flags and no EAR DOCTOR door: "audible, but missed", rollover and the referral are the day's own discoveries (the
stamp, the slide and the Roll Call).

### 4.2 The movie, scene by scene

"Hoot's Movie Matinee: The Letter Choir" (`MOVIE.title` "Hoot's word movie", `subtitle` "The Letter Choir"). The
lead-in is in rows 0 and 1: the announcement in the clinic, then the marquee that holds while Hoot asks the movie's
question and names its answer.

| # | Scene (`set`) | Visuals (the stage brief) | Caption(s), Hoot | s | The one idea |
|---|---|---|---|---|---|
| 0 | (the clinic, first play only) | The door camera, before the movie starts. A replay instead gets the offer (§4.4), never this line. | Dialogue box: "New trick today: WORD SCORES. A quick cartoon first, then our next patient!" | ~4 | (Steve) What today is for, before the cartoon. |
| 1 | `choir` | Curtains swish open (0-1.2 s) on the marquee HOOT'S MOVIE MATINEE / The Letter Choir, "starring the speech sounds", two little singers beside the title. **The marquee holds 8 s** (`params.card_hold`) while Hoot asks the question and names the answer, with **two question chips** under it ("Loud enough, so why mushy?", "How do we score clear words?", `params.questions`). Then the card flips away and the word SOFT steps forward as four singers on choir risers: a big round "o" sings with an open mouth; "s", "f" and "t" are small and whisper. They sing in turn, each lighting its letter of SOFT and putting its note on a staff (the vowel's big and low, the consonants' tiny and high), then all together; Hoot conducts. | "Hoot's Movie Matinee! Today's mystery: why can loud-enough words still come out mushy?" / "The answer is a WORD SCORE: it counts clear words, because beeps can't measure clarity." / "Every word is a tiny choir: vowels sing low and loud, consonants whisper high." (at 0.3, 4.4 and 8.4 s) | 15 | (Steve, 2026-10-19: the movie must say what it will explain) What the movie answers; then: vowels are low-pitched and loud, consonants such as s, f and th high-pitched and soft. |
| 2 | `banana` | An audiogram stage: pitch from low (left) to high (right), soft at the TOP and loud at the bottom, as on a real chart. The letter singers hop up to their spots in three groups (the `SOUND_CUES` positions for a chatting voice, dial 50, copied as data) and a yellow banana outline draws itself around them. Vowels sit low-left and loud; s, f and th high-right and soft, near the top. | "Line up every speech sound by pitch and loudness, and you get a banana. The speech banana!" | 8 | Plotted by pitch and level, everyday speech sounds form the speech banana. |
| 3 | `curtain` | A sloping threshold line draws itself across the banana (a made-up sloping loss, not Nora's chart). A velvet curtain drops from the TOP of the chart down to the line. The singers above the line duck behind it, only their tiny feet showing under the hem; the vowels below the line keep singing. | "A high-pitch hearing loss drops a curtain over the soft, high singers: s, f, th." | 8 | A sloping high-pitch loss hides the soft high consonants first. |
| 4 | `mush` | Two beans at a little cafe table. His bubble says "Let's meet at six!". A copy flies to her ear, dropping its consonants on the way, and arrives as "Le__ mee_ a_ _i_!" (dotted gaps). Her bubble: "Lettuce... meat...?" A question mark bounces beside her guess; a chip over the table: "voices, not words". | "Vowels still get through, so she knows you're talking. She just can't tell which word." | 8 | With the consonants lost, speech is heard but not understood: voices, not words. |
| 5 | `louder` | Hoot turns a big volume knob (drawn; nothing gets louder). The whole banana slides DOWN the chart by 35 dB (50 to 85), out from under the curtain; most singers step out and bow. Two (f and th) stay behind it: "most", not all. A "too loud" strip at the bottom of the chart stays empty. Card heading: "Loud enough, never too loud". | (A5) "Turn the words up: loud enough for every sound, never uncomfortable. Most singers step out." | 8 | A level loud enough for every sound, never uncomfortable, makes most speech sounds audible, so the word score tests clarity, not loudness. |
| 6 | `crossing` | The masking movie's front-view head with Righty (her right, the screen's LEFT) and Lefty. A chunky word bubble ("banana!", tagged 80 dB) goes into Lefty's side (the poorer ear today); a smaller copy squeezes through the skull wall under its "-40 dB" toll sign to Righty, who throws on the Ghost's bedsheet: "I HEARD IT!" Then a phone on her right ear fills Righty's corner with a purple cloud labelled SPEECH NOISE, the next crossing word bonks off it, and the sheet slides off. Visual only: no noise plays. | "Loud words can cross the head to the good ear. Speech noise there keeps it out." | 8 | Loud speech can cross the skull to the better cochlea, so the better (non-test) ear gets speech noise. |
| 7 | `count` | A 5 x 5 board of tiles flips one by one (mint tick or coral cross, each with its symbol). "sock" comes back as "lock": a callout card shows both and stamps coral with "A RHYME IS A MISS". The ticks add up on a scoreboard: 22 of 25, 88%. Watching up to here counts as seen (`seen_at`). | "Then we count: twenty-five words, 4% each. A rhyme is a miss. The score measures CLEAR." | 8 | The word recognition score: 25 whole words at 4% each; a rhyme or near-miss scores as a miss. |
| 8 | `tease` | The volume knob turns again and a big question mark pops on it. The stage door opens a crack; little music notes float in on a staff (a hum, drawn); Hoot perks up. The curtains close. | "But what if louder DOESN'T make it clearer? Ooh, someone's humming at the door!" | 7 | Teaser: sometimes louder is not clearer (the day will show why). |

Scene totals: 15 + 8 + 8 + 8 + 8 + 8 + 8 + 7 = **70 s** (the player stretches a scene only if its caption needs longer
to type: 42 characters/s plus 1.6 s to read). The longest caption is 18 words.

**Reduced motion** (the player's setting): cuts and crossfades only; the singers fade in at their spots, the curtain
fades in, the banana crossfades down, and the count tiles change without flipping.

**Sounds per scene** (all `Sfx`, at -8 to -16 dB): a fanfare, a whoosh and six pops (choir: two for the question
chips, four for the singers), three pops and a sparkle (banana), a whoosh and a thunk (curtain), a pop and a soft
boing (mush), three clicks and a sparkle (louder), a whoosh, a boing, a pop and a thunk (crossing), a blip, a stamp
and a ding (count), a click, a door and three rising notes (tease). The loud knob, the loud word and the speech noise
are drawn, never played; no babble, hum or music plays.

### 4.3 The movie data (`res://story/explainers/movies/letter_choir.gd`)

The file is data only; the shared player plays it (`CONTRACTS.md` §3.4). Its art comes through the per-movie sets
hook: `MOVIE.stage` names `res://story/explainers/stages/letter_choir_sets.gd`, a script that `extends
"res://story/explainers/explainer_sets.gd"` and declares `const SETS: Array[StringName] = [&"choir", &"banana",
&"curtain", &"mush", &"louder", &"crossing", &"count", &"tease"]` with one `_set_<id>()` each. The stage draws its
built-in sets itself and hands these to the script; a set nobody draws falls back to a card.
- **Card fallback.** Every scene carries card params at the top of `params` (`heading`, `lines`, `icon`, `tint`), so it
  always plays, as a card, whenever its set is not drawn.
- **Set data.** Each set's own data sits under a key named after the set (`params.choir`, `params.banana`, ...), never
  under a card key. Scene 1's lead-in keys (`card_hold`, `questions`) sit beside the card keys; its set reads them.
- **The lead-in.** `params.card_hold` (8.0) makes scene 1 an opening that holds a title card: the stage's scene chip
  waits until the card has gone, and the set draws the marquee with the two `questions` chips under it, then runs the
  choir on the stage's clock shifted by `card_hold` - 2 s (the same contract as Day 2's `meet`).
- `seen_at` is `"count"`: a player who skips only the teaser has still seen the movie.
- Captions are 18 words or fewer. Cues are `Sfx` names at -8 to -16 dB.
- A header comment names the facts Steve reviews (the singers' spots are `SOUND_CUES` at `CHAT_DB`; the curtain's
  chart is made up; the louder slide is `WRS_ABOVE_PTA_DB`; 25 words at 4%; on-ear phones lose at least 40 dB) and
  says the example words and sentences were written fresh for the game, never taken from a published word list or
  rhyme test.

**Art rules** (contract §9.20):
- Each `_set_<id>()` is a pure function of `t` and the scene's params: no tweens, nodes or RNG, so pause freezes it
  and a skipped scene leaves nothing behind. It draws through `s`, the stage (`s._hoot()`, `s._text()`, `s._panel()`,
  `s._chip()`, `s._note()`, `s._curtains()`, `s._head_open()`, `s._snail()`, `s._cloud()`, `s.draw_*()`), with the
  palette as `Stage2D.<COLOR>`; `_k()`, `_pop()` and `_ring()` are on the base.
- **The marquee** (scene 1): `s._curtains()` opens over the marquee drawn by `_set_choir()` from `params.choir.title`
  and `starring`, with "HOOT'S MOVIE MATINEE" above it. The stage's `_title_card()` names the masking movie, so it is
  not used, and no shared file changes.
- The banana and curtain maths are copied in as data (the `SOUND_CUES` positions); the sets never call `SpBanana` or
  any Day 4 UI code.
- **The crossing scene** reuses the masking movie's props through the stage's helpers (the front-view head, Righty and
  Lefty, the skull wall, the bedsheet Ghost, the purple cloud), so the Ghost looks the same as on Day 2.
- **The metaphor is the same everywhere.** The curtain hangs from the top of the chart (soft sounds) down to the
  threshold line. Louder words move the banana DOWN the chart, out from under the curtain. The Banana Board (§5.2)
  draws the same picture.
- **Checking the art**: the shared dev scene shoots every scene, `dev_explainer.tscn --movie=letter_choir
  --at=0.2,0.6,0.95` (add `--reduced-motion` for the still versions), so no preview script of our own is needed (§15).

### 4.4 How the level plays it

`level_nora._movie()` is `level_bonnie._movie()` with the id `"letter_choir"`:
- **Until it is seen** (`Game.is_movie_seen("letter_choir")` is false): `_phase(&"explainer", {movie, source:
  "day_start", seen: false})`, Hoot's announcement (row 0 of §4.2), then the movie. "Seen" means it reached its
  `seen_at` scene (`count`, `Game.mark_movie_seen`); an earlier Esc plays it again on the next visit.
- **Once seen**: Hoot offers it: "Hoot's word movie again? Popcorn's on me!" with ["Roll the film! (about 70 s)",
  "Skip it: I know my banana."], best answer 1 (skip). The "70" comes from `Movies.total_s` rounded to 10. There is no
  announcement on a replay.
- **After a skip** at day start, Hoot says where it lives (H-MOV-3): "Skipped! Rewatch it any time: pause menu,
  "Watch Hoot's word movie"."
- **The masking movie first, when needed** (`_masking_offer`): if `Movies.has("masking")`, the masking movie is not
  seen and `bonnie` is not in `chapters_done`, Hoot first offers: "New to the Cross-Hearing Ghost? My masking movie
  explains it first." with ["Show me the Ghost movie! (about 90 s)", "Skip it: on with words."], best 1. It plays the
  same way.
- `Game.set_visit_flag("movie_watched", ...)` takes the result's `watched` (it reached `seen_at`).
- **Replays.** On Day 4 the pause menu offers "Watch Hoot's word movie" (the movies whose `chapter` is `nora`; the
  masking movie belongs to `bonnie`). The title's Options and its "Hoot's Movies" list offer every movie, and the case
  days and walk-ins (which can mask, E19) offer them all too, so the Letter Choir is listed there as well.
- **The masking recap** (clinical review A2): the day-start offer stays. When the masking movie is still unseen at
  Hoot's masked bone (the offer declined or skipped, or Day 2 played without it), the one-card `masking_recap` plays
  first, once a visit (the `explainer` beat), then H-TON-R. From then on the level is in `MASKING_LEVEL_GROUP`, so its
  pause menu lists every replay movie (E19), the masking movie among them. A watched masking movie changes nothing.
- If `Movies.has("letter_choir")` is false (a broken registry), the day starts at the intro.

## 5. The SPEECH screen in WORD mode

`SpeechScreen.start_test(patient, ear, coached, plan)` with `plan.test = "wrs"` loads the WORD mode by path
(`core/speech/modes/wrs_test.gd` and `ui/speech/modes/sp_mode_word.gd`, D1). SRT mode is untouched: Day 3 runs with
`mode == null` (contract §9.10.2).

### 5.1 Layout (what appears when)

Widgets appear as they become useful (their reveal state lives in `screen.memory`):

| Area | From List 1's first word | Added later |
|---|---|---|
| LCD | test chip **WORDS**; "Word list 1 · word 9 of 25 · 96% so far"; the **level chip** by the dial, "PTA 15 + 40 = 55 · min 55" (it follows the dial); the NOISE box and its sum (below) | the louder list: "LOUDER = COMFY 75 + 20 = 95" |
| Card | "LIST SAYS:" and the word, crisp at full size, always | with the lens on: a second row "REACHES HER (55 dB):" (§5.3), which turns into "SHE SAID:" on a miss |
| Middle | the **score strip** (`SpScoreStrip`) | the **Banana Board** slides in at the first lens press; the **band ruler** after a list ends |
| Meter slot | (empty: the SRT ladder, meter, tally and STORE are hidden) | the **ear compare** (`SpEarCompare`) once both ears have a counted list; its chance bands and verdict once both bests are final |
| Deck | LEVEL + WORD (SOFTER, PRESENT, LOUDER) · SCORE THE WHOLE WORD (MISSED, REPEATED) · NORA-VISION · NOISE. No STORE. | |
| Dance card | [EACH WORD 25 x 4%] [WHOLE WORD ONLY] [COMFY PTA + 35] | the louder list: [LOUDER COMFY + 20] |

- **The NOISE sum.** On a coached list it shows the sum and the answer: "55 - 40 = 15 < 35:" with "NO NOISE" (or
  "75 - 40 = 35 >= 10:" with "NOISE!", then "NOISE ON"). On the solo List 2 it shows the rule and the other ear's
  number, never the answer: "NOISE? LEVEL - 40 vs RIGHT BEST:" with "10".
- **The score strip.** 5 x 5 tiles fill in as words are scored. A tick tile is mint and a cross tile is coral, each
  with its symbol as well as the colour. A miss tile shows what she said in small type. Hoot's tiles are brown, as on
  Day 3's golf card. The running line reads "13 right x 4% = 52%". There is no live pace marker. After the list the
  band chip lands (EXCELLENT / GOOD / FAIR / POOR / VERY POOR, from `WRS_BAND_TITLES`).
- **No STORE.** After the 25th score the list ends itself: the strip flashes, the band chip lands, then the sheet is
  stored (celebrate at 1.2 s, finish at 4.0 s). Hoot's perch line during his turn: "Hoot is testing: watch the
  tiles!".
- **One level per list.** After a list's first word, Up / Down and NOISE lock. A press shows the chip "One level per
  list" (or "Same noise, every word") and the tip ("One level per list. A word score belongs to a single level."). The
  louder list keeps its noise locked from the start ("The noise stays as it is for the whole list. Same set-up, every
  word.").
- **The two-press confirm** (solo lists only; contract §9.17.4). The first PRESENT with a wrong set-up does not
  present; a chip explains, and a second PRESENT within 4 s tests anyway:
  - level: "Loud enough for every sound: PTA + 35 = 75." / "{key:present_tone} again: test at 60 anyway." (a louder
    list: "The louder list goes 20 above the comfy one: 95.");
  - unmasked: the BOO chip (§5.4).
  - Coached lists have no "anyway": PRESENT is denied for 4 s and the coach repeats the step.

### 5.2 The Banana Board (`ui/speech/sp_banana.gd`)

A mini audiogram (250-8k across, -10 to 100 dB down, soft at the top). Before the first lens press its placeholder
reads "NORA-VISION [V]"; at the press it slides in and draws:
- **Her measured thresholds** for the test ear: O or X in the ear colour, joined by a line.
- **The curtain**: a velvet fill from the top of the chart down to that line.
- **The banana**: the speech-sound letters (`SOUND_CUES`), each at (cue frequency, dial + cue offset). They move down
  with the dial. Letters above her line sit behind the curtain, faded by `lens_alpha`.
- A **CHAT 50** tick on the level scale.
- **Once the ear's best is final**: a bar "tones predict at least {min}%" next to a bar for her best. If the best is
  lower, the bars get a red-flag pin.
- **After the louder list**: her score per level drawn as a playground slide (§12), with a music note as the dot.

### 5.3 NORA-VISION (the lens; V, or the button `speech_lens_button`)

The "hear through the patient's ears" lens. Nora lends Hoot her pearl opera glasses (an aside the first time: "Borrow
my opera glasses, Professor. They're tuned to me.").
- **The word is never hidden.** The card's top row always shows "LIST SAYS:" and the word, crisp at full size. The
  lens adds a second row, "REACHES HER (dB):", where each spelling chunk of the next word is drawn at `alpha =
  lens_alpha(margin) = lerp(1.0, 0.15, clamp(-margin / 15, 0, 1))`, with a dotted outline when the margin is below 0
  and a dotted underline from 0 to 3 dB ("only just"). Silent letters are plain ink. The margin uses her measured
  thresholds, the same arithmetic as `predicted_wrs_max`, so the lens and the prediction always agree.
- **Examples.** "thorn" on her right ear at 55: a ghostly "th", then a solid "orn". "sock" on her left ear at 50: a
  dotted "s", a solid "o" and a dotted "ck".
- **Her answer through the lens.** On a miss, the REACHES HER row's letters scramble into what she said (0.6 s; a
  crossfade with reduced motion), and its label turns into "SHE SAID:".
- **"Call it" (beat `call_it`, D29).** Twice, the lens feeds a guess before a word is presented. It is unscored and
  never changes the deal. Right = "She'll get it", Left = "She'll miss it", or the two buttons. The card: "Call it!
  {key:speech_correct}: she'll get it. {key:speech_incorrect}: she'll miss it."
  - List 1, on the first player word with a lost chunk that is dealt a hit (on Nora's right that is "fox", place 4):
    "Nora-vision shows a faint 'f'. Will she get 'fox'?" After her answer: "She got it! One faint letter, and her
    brain filled the gap."
  - List 2, on the deal's `audible_target` (places 2-6): "Every sound of 'moon' reaches her. Will she get it?" She
    misses it, and the stamp lands.
  - The player builds a picture on the right ear ("faint letters can still work") and watches the left ear break it.
- **"AUDIBLE, BUT MISSED."** With plan `audible_stamp` (List 2 and the redo only, D18), when a word whose every chunk
  had 3 dB or more is missed, a stamp lands on the card with the `audible_miss` tip ("Nora-vision says every sound
  arrived. Yet the word came out wrong."). Once per list. That is the neural ear: the sounds arrived, but the word
  did not. It never shows on List 1 (her right ear is cochlear and nearly perfect).
- **Coaching.** The lens is introduced on List 1 after word 2 (`lens_try`: one coached press, "Nora-vision! Press
  {key:toggle_lens} to see each word as her ear gets it."). It then stays as the player left it for the visit
  (`screen.memory`). It is never needed to progress.
- **Generic.** The label comes from the patient's short name ("NORA-VISION"; `{Lens}` = "Nora-vision" in lines), so
  later days can reuse it.

### 5.4 The Ghost on the SPEECH screen (`ui/speech/sp_ghost.gd`)

- **Solo lists: no lurking.** The noise decision on List 2 is the player's. The Ghost appears only if the player
  presses PRESENT with noise needed and off: it pops out of the booth window ("BOO!") with the confirm chip:
  - "BOO! At 75, words can cross to her other ear."
  - "{key:toggle_mask}: noise on. {key:present_tone} again: test without it."
  - Pressing M then blows it away ("GHOST BUSTED!", `fx.ghost`), and Hoot says "Ghost busted! Now only her left ear
    can answer." Pressing PRESENT again confirms the unmasked list (§2.3).
- **Coached lists (the redo): it lurks** while masking is needed and off, at `ghost_alpha = clamp(0.2 + (level - 40 -
  nontest_best_bone) / 25, 0.2, 1)`. On her left it shows faintly from 50 (the first level that needs noise) and is
  bold by 70. The `ghost_lurk` tip says it once per list: "The Ghost is lurking! At this level the other ear can hear
  these words."
- **Ghost words.** If an unmasked word is answered by the right cochlea (`heard_by == "cross"`), her answer gets the
  ghost bubble style, the `ghost_word` tip, and the existing `cross_heard_speech` technique event fires. The clinic's
  3D Ghost already reacts to its cross-heard cue.
- **First appearance when Day 2 was skipped.** If `bonnie` is not done, Hoot adds before the masked bone run: "Loud
  sounds can cross the skull to the other ear. That's the Cross-Hearing Ghost!"
- **Nora's aside** on the first M of a list that needs noise: "Is that the sopranos warming up?"

### 5.5 The loud bubble

On the louder list (plan `loud_bubble`) her answers are drawn 1.4 times bigger in plain capitals ("HOPE? NO...
ROPE?"). No shake, with or without reduced motion. Her first loud answer adds the aside "Ooh, that's LOUD."

### 5.6 Plan keys, beats, anchors and asides

- **Plan keys**: contract §9.13.2. `coached` is the `start_test` argument, never a plan key. Day 4 uses `test`,
  `tones`, `list`, `transducer`, `level`, `mask_on`, `lock_noise`, `louder_than`, `redo_of`, `ensure_audible_miss_by`,
  `audible_stamp`, `aside_by`, `self_correct`, `chatter`, `silences`, `call_it`, `chat_demo`,
  `confirmed_wrong_hoot_after`, `hoot_turn_after`, `hoot_turn_text`, `intro`, `lens_try_after` and `loud_bubble`
  (contract §9.21 has the four plans).
- **`TEA_DEMO`** (List 2's `chat_demo`): `{text: "Fancy a cup of tea?", level: 50, chunks: [["F", "f"], ["a",
  "vowel"], ["n", "n"], ["c", "s"], ["y", "vowel"], [" ", ""], ["a", "vowel"], [" ", ""], ["c", "k"], ["u", "vowel"],
  ["p", "p"], [" ", ""], ["o", "vowel"], ["f", "v"], [" ", ""], ["t", "t"], ["ea", "vowel"], ["?", ""]], lines: [...]
  (§11, the tea demo)}`. At 50 on her left the REACHES HER row reads "_an_y a _u_ o_ _ea?", with the "n" only just
  (dotted underline). It is a Hoot turn before the first word: nothing is presented, dealt or locked.
- **Beats on the SPEECH screen**: `speech` (every idle point), `lens_try` (once, List 1), `call_it` (§5.3). The info is
  `{ear, slot, test: "wrs", action, target_db, list, list_n, word_n, louder_than, mouse: {click: anchor}}`.
- **Actions**: `present`, `score_correct`, `score_missed`, `louder`, `softer`, `mask_toggle`, `lens_toggle`,
  `call_it` (contract §9.19.1 has the inputs and mouse routes).
- **Anchors**: `speech_present_button`, `speech_louder_button`, `speech_softer_button`, `speech_correct_button`,
  `speech_incorrect_button`, `speech_mask_button`, `speech_lens_button`, `speech_word_card`, `speech_response`,
  `speech_score_strip`, `speech_banana`, `speech_ghost`, `speech_ear_compare`, `call_it_yes_button`,
  `call_it_no_button`.
- **Coach text** comes from `SpModeWord.coach_text(rec)` (its `LINES`). Every key is `{key:<action>}`, filled by
  `_k()`, so the swapped arrow style reads correctly, and pronouns come through `say()`.
- **Asides** (D28) are non-blocking `bubble.aside` lines (the `aside` bubble style, set a little in from the badge),
  each once per visit through `session.observe_once(key, &"aside", ...)`. Day 4's triggers (`DEFAULT_ASIDES`, or the
  item's `asides`):
  - an answer that is a foil with an `asides` entry: "bike" heard as "Mike?" ("Mike? He's in the break room. With
    donuts.") and "hook" heard as "Hoot?" ("Present!");
  - the first lens press: Nora, "Borrow my opera glasses, Professor. They're tuned to me.";
  - the first M on a list that needs noise: Nora, "Is that the sopranos warming up?";
  - the first answer on a louder list: Nora, "Ooh, that's LOUD."
  None of them stops the beat loop.

## 6. The word lists ("Word list 1" to "Word list 4")

New material files, `res://core/speech/material/words_1.json` to `words_4.json` (contract §9.11.1): `kind:
"monosyllable"`, `original: true`, 25 items each, played in file order (D11) and handed out in play order (D25).
Each list's `note` says it was written fresh for Booth Camp and names the published tests it must not copy (§17 Q21).
Each item is `{id, text, key_sound, foils: [3], plural, chunks}`, plus `asides` on two items.
- `key_sound` is a `SOUND_CUES` id: the sound that tells the word apart from its foils.
- `foils` are rhymes that change only the key sound: her believable mishears.
- `plural` is the inflected form the `plural_trap` answer uses ("Socks?"); "—" means the item has none.
- `chunks` are spelling pieces mapped to sound ids, with "" for silent letters (for example `[["s","s"],["o","vowel"],
  ["ck","k"]]`). They are optional in `validate`, so `spondee_a` still validates, and required by the tests for
  `words_*`.

**Word list 1** (written for this game; `test_word_list_1_is_the_design` pins the targets in this order):

| # | Word | Key | Foils | Plural |
|---|---|---|---|---|
| 1 | sock | s | lock, rock, dock | socks |
| 2 | sand | s | hand, band, land | sands |
| 3 | price | s | pride, prize, prime | prices |
| 4 | fox | f | box, rocks, locks | foxes |
| 5 | leaf | f | leak, leash, leap | leaves |
| 6 | thorn | th | corn, horn, born | thorns |
| 7 | booth | th | boom, boot, boos | booths |
| 8 | tub | t | cub, rub, sub | tubs |
| 9 | night | t | nine, knife, Nile | nights |
| 10 | cork | k | fork, pork, York | corks |
| 11 | hike | k | hide, hive, height | hikes |
| 12 | shore | sh | core, four, roar | shores |
| 13 | chess | ch | guess, less, Bess | — |
| 14 | zone | z | bone, cone, loan | zones |
| 15 | van | v | fan, tan, ran | vans |
| 16 | pear | p | bear, fair, wear | pears |
| 17 | bunch | b | lunch, munch, punch | bunches |
| 18 | dice | d | mice, rice, nice | — |
| 19 | gate | g | mate, rate, bait | gates |
| 20 | mug | m | bug, hug, tug | mugs |
| 21 | nose | n | hose, doze, pose | noses |
| 22 | lamb | l | ham, ram, dam | lambs |
| 23 | rope | r | hope, cope, mope | ropes |
| 24 | wave | w | cave, pave, rave | waves |
| 25 | hut | h | nut, cut, shut | huts |

- **The key-sound mix** (`WRS_KEY_MIX`, the same in every list): s 3, f 2, th 2, t 2, k 2, and one each of sh, ch, z,
  v, p, b, d, g, m, n, l, r, w and h.
- **List 1 only** puts the high, soft key sounds early, so the player's 8 coached words on the right ear meet the faint
  "f" and "th" (and "fox", place 4, is Call it #1).
- **The recipe for every list** (the tests check it):
  - the same key-sound mix; one syllable; familiar to a 10-year-old;
  - no scary, medical, rude or alcohol words (a banned-word list in the test covers targets, foils and plurals);
  - foils change only the key sound; `plural` differs from the word and every foil;
  - no target repeated within or across the four lists (100 different targets);
  - **the audible-word rule**: `words_2` and `words_3` each have at least 2 words in places 2-6 that are
    `word_fully_audible` (every chunk 3 dB or more) on Nora's left at 70, 75 and 80 dB, at least 2 of them clearing 8
    dB at 70. Build them only from sounds that clear 8 dB at 70 (sh, b, m, n, ng, l, r, w, y and vowels), for example
    "moon", "ring", "shell". Place 1 never counts.
- **Originality** (`test_originality_guard`, contract §9.11.1). The repo never holds a published test's words, so the
  guard checks only our own material:
  - every list's `note` begins "Written fresh for Booth Camp" and names the published tests it must not copy (NU-6,
    W-22, CID W-1, PB-50, AB / Boothroyd, NU-CHIPS, WIPI and the Modified Rhyme Test);
  - no target is its own foil or a foil of a target in its own list, every foil is one word, and an item's foils are
    distinct;
  - no two of the 100 items share more than two words of their rhyme sets (the target plus its foils), so no set is
    reused with a word swapped.
- **Two in-jokes, landed by `aside_by`** (they do not depend on the deal):
  - List 2 has "bike" in places 1-8, with the foil "Mike": "Mike? He's in the break room. With donuts."
  - List 3 has "hook" in places 1-5, with exactly the foils "Hoot", "hoof" and "hood": its last sound changes, never
    its first (the rhymes that change the first sound of "hook" are a published rhyme set, so none is used). When she
    says "Hoot?", Hoot answers "Present!"
  - Both answers are side bubbles. The scoring is still a miss.
- **As built**, a few foils differ from the first draft of List 1 (sub, tan, ran, wear, tug, nice), and List 4's
  "moose" takes mood, move, moon and "rhyme" takes chime, dime, time. Every change kept the rules above.

## 7. The Red-Flag Roll Call (`story/games/nora_board.gd`, new)

**Decision: a new board.** It does not reuse `story/games/case_board.gd` (single-pick beats bound to the case JSON and
its reveal patterns) or `mike_board.gd` (a single OBJECTION drag).

**What it reuses:** `CaseRules.RED_FLAGS` ids and wording, `CaseRules.DECISIONS` and `DECISION_STAMPS`, the stamp
colours (a const reference to `case_board.gd`'s `STAMP_COLORS`, never a copy), the stamp-tray look with its fixed
order (FIT, REFER, DOCTOR TODAY) and the stock choice beat for the stamp. No shared file changes.

**The board** ("RED-FLAG ROLL CALL"). Nine cards wait in the wings in a fixed shuffled order (`ROLL_CALL_ORDER`: hiss,
canals, tones, agree, apart, slowly, predicted, wobbly, louder). One at a time, a card steps onto a podium between two
choir risers: the RED FLAG riser (right) and the FINE riser (left). Each card carries its source tag (SHE SAID,
AUDIOGRAM, WORD LISTS, OTOSCOPE, SRT VS PTA) and uses the player's own numbers from this visit.
- **Right** (`speech_correct`, the key the player just used to score) or the big **RED FLAG** button sends the card to
  the flag riser.
- **Left** (`speech_incorrect`) or the **FINE** button sends it to the fine riser.
- A right sort plays the next note of a rising scale (drawn as a note climbing a staff), and Hoot's short line for
  that card shows as the board's caption (non-blocking, not a dialogue bubble).
- A wrong sort bounces the card back onto the podium with a cracked-note clunk (drawn as a cracked note), Hoot's line
  for that card, and, the first time, Nora's wince: "Ooh. A sour one." The player sorts it again.
- Every card is a decision: 9 sorts, about 0:30. Nothing completes itself, and there is no "how many are left" count.

| Card | Sort | Comes from | Text (tokens from this visit; a textbook run in brackets) |
|---|---|---|---|
| hiss | RED FLAG (`one_sided`) | history | "Hiss in the LEFT ear only" |
| wobbly | RED FLAG (`dizziness`) | history | "Wobbly on stairs sometimes" |
| tones | RED FLAG (asymmetry) | `CaseRules.is_asymmetric` on her tone results | "Left tones {lo}-{hi} dB worse than right" (20-30) |
| apart | RED FLAG | the sheets' `asymmetric` (A3, bests final) | "Best words: right {r}%, left {l}%" (96, 52) |
| predicted | RED FLAG | the left sheet's `below_predicted` (A1) | "Left best {l}%; tones predict {min}% or more" (52, 60) |
| louder | RED FLAG | the left sheet's `rollover` (A2) | "Louder list: {l}% fell to {b}%" (52, 12) |
| canals | FINE | otoscopy | "Ear canals clear" |
| agree | FINE | SRT vs PTA | "SRT agrees with PTA in both ears" |
| slowly | FINE | history | "Came on slowly, over about a year" |

- **Computed, not hard-wired** (`level_nora.roll_call_cards`). A card is a flag only if its rule fires on the visit's
  results. With Nora's truth all six always fire (§2.2). If the player's own misscoring hides one, that card becomes a
  FINE card with its "no flag" line (§11), and the referral still follows from the others. A louder score that did
  not fall reads "{l}% went to {b}%".
- **(A5) "Slowly" teaches the urgency.** Its line: "Slow still counts when one ear lags. Sudden would mean a doctor
  today."
- **The beat** is `flag_pick`. Info: `{card, remaining, mouse: {click: "flag_yes_button" | "flag_no_button"}}` (the
  button for the right sort). The solver sends `speech_correct` or `speech_incorrect`.
- **Prompt**: "Red-flag roll call! Each clue steps up: red flag, or fine?"
- **Medal `evidence` (Flags)**: gold 0 wrong sorts, silver 1, bronze 2 or more.
- **Then the stamp tray** (a choice beat, `choose_stamp`, prompt "Your call for Nora:"): FIT / REFER / DOCTOR TODAY.
  REFER is right (`wrs_summary.referral == &"refer"`, D27). Wrong picks bounce off, greyed, and the player picks
  again. Medal `referral` (Call): first try, second, third.
- **The letter.** REFER fills a short letter (§11, P-LETTER) printed on a sheet of manuscript paper. Nora signs it with
  a baton flourish (a treble-clef squiggle), and it slides into an envelope addressed EAR DOCTOR. With reduced motion
  it fades across.
- **Anchors**: `flag_yes_button`, `flag_no_button`, `flag_podium`, `case_stamps`, `referral_letter`.

## 8. Simulation, session and rules

The exact API is the contract's; this section says what Day 4 needs from it.

### 8.1 The word model (`core/speech/models/wrs_model.gd`, contract §9.12.1)

- **Chance of a word**: `p_test = wrs_max x wrs_audibility(L, srt_eff) - rollover_drop(L)`, with `srt_eff = max(SRT,
  noise - real IA)` (the second term only matters for overmasking). The other cochlea's chance `p_cross` is the same
  formula at `L - real IA` against its own SRT; it is 0 once the noise reaches the crossed level (masked out).
  `p_wrs = 1 - (1 - p_test) x (1 - p_cross)`.
- **The deal** (one per list, at its first PRESENT, D4): `k_test = round(p_test x 25) + j` and `k_total = round(p_wrs x
  25) + j`, with `j` from [-1, 0, 0, +1]. A cochlear ear's misses lean to the sounds below threshold (`wrs_miss_weight`
  on the TRUE thresholds), so her right ear mostly loses f and th words; her neural left loses words at random.
- `ensure_audible_miss_by` 6 (List 2 and the redo) puts one dealt miss on a fully audible word in places 2-6 (on the
  measured thresholds the lens uses), and names it `audible_target` (Call it #2). `aside_by` makes the aside word a
  miss within the player's words; it is never the audible target. Neither changes the count.
- **Answers**: a cochlear miss is a foil (80%) or silence (20%); a neural miss is a foil (60%), silence (25%) or another
  list word (15%); a word that is too soft gets more silences. Silences come from `NORA_SILENCES`.
- **Answer styles, the player's words only** (D20; surface text, never the score):
  - `chatty_hit`, about 1 hit in 3 (never on a Call it word): the word, then a short line ("Sock! Like a good
    downbeat.");
  - `plural_trap`, once per list, on the first dealt miss whose word has a plural (never the audible target): the
    plural as a question ("Socks?"): a miss;
  - `self_correct`, once on List 2, on the player's second dealt hit: "Lock... no, SOCK!": the final answer counts, a
    hit (§17 Q24);
  - the aside word always takes its aside foil, in the `aside` style.
  So scoring takes judgement: the player must read what she said, not match two strings.

### 8.2 The session (`core/speech/modes/wrs_test.gd`, contract §9.13 and §9.15)

- **One list per `start_test`**; one sheet per ear (`speech.wrs.right` / `.left`) holding every list on that ear.
  Level and noise lock at the first word; the list ends itself after word 25.
- **Counting**: a list counts when it started inside the window, with noise exactly when the rule needs it (a louder
  list also 15-25 dB above the comfortable one), and no later list redoes it (`redone_by`). A list id is used once a
  visit; a reused list is refused. Only counted lists set `pct`, `pb_max`, `louder_pct` and the flags.
- **Verdicts wait for the best** (D13): `below_predicted` and `asymmetric` use `pb_max` and are said only once the
  ear's best is final (its louder list is done, or the comfortable score already reaches the prediction). So List 2
  ends with "Is that her best?", and the verdicts land on the louder list's done screen. The ear verdict needs both
  ears final; finishing a list recomputes the other ear's sheet too.
- **(A2) Rollover** is `wrs_rollover` over the ear's counted lists: PBmax is the best score, PBmin the lowest score at
  a level above PBmax's, and rollover is an index of 0.45 or more. A lower louder score under the cut-off gets
  "{pct}%: lower, but under the rollover cut-off. Not a flag on its own."
- **(A3) The ears** differ when `wrs_differ` says the two bests are too far apart for chance on lists that long.
- **The noise level** is `wrs_mask_level` (D16, A4): level - 20 plus the other ear's air-bone gap, clamped to [level -
  IA, test-ear best bone + IA - 5].
- **Speech masking** uses the per-frequency best bone (D17): masked bone, else unmasked bone, else air, at each of
  500-4k. That keeps an unmasked bone value from standing in for an ear it was never measuring (the Ghost), and it
  gives the noise ceiling its test-ear bone. SRT keeps `nontest_best_threshold` (D12), so Day 3 is unchanged.
- **The referral** (D27): `wrs_summary.referral` is `&"refer"` when the bests differ beyond chance, or rollover is
  found, or one ear only is below its prediction. It is never "doctor today" from word scores alone.
- **Technique kinds**: contract §9.13.6 and `docs/SPEECH.md` §8 (errors `wrs_level`, `rollover_level`,
  `wrs_unmasked`, `misscored`; clean `wrs_good_start`, `wrs_mask_ok`, `speech_textbook`; and the observations).

### 8.3 `SpeechRules` (the WRS section)

Constants: `WRS_LISTS`, `WRS_KEY_MIX`, `WRS_DEAL_JITTER`, `WRS_MISS_SCALE_DB` 4, `WRS_MISS_FLOOR` 0.05,
`WRS_MISS_COCHLEAR`, `WRS_MISS_NEURAL`, `WRS_LOUDER_DB` 20, `WRS_LOUDER_TOLERANCE_DB` 5, `WRS_AUDIBLE_MARGIN_DB` 3.0,
`WRS_CHATTY_SHARE` 0.33, `WRS_CHATTY_MAX_WORDS` 6, `WRS_SELF_CORRECT_COUNTS` true, `CHAT_DB` 50, `LENS_FADE_DB` 15,
`LENS_MIN_ALPHA` 0.15, `GHOST_ALPHA_FLOOR` 0.2, `GHOST_ALPHA_SPAN_DB` 25; (A1) `WRS_PREDICTED_MIN_25`; (A2)
`ROLLOVER_INDEX_CUTOFF` 0.45; (A3) `WRS_CRIT_Z` 1.96; and, in the lists block, `LIST_TEE_BONUS` 2 and
`LIST_CONFIRM_SLIP` 3. Functions: `wrs_predicted_min_interp`, `wrs_window`, `ear_best_bone`, `nontest_best_bone`,
`wrs_mask_level`, `wrs_mask_capped`, `wrs_louder_level`, `wrs_louder_ok`, `rollover_drop`, `rollover_index_of`,
`wrs_rollover`, `wrs_differ`, `wrs_same_range`, `wrs_pct`, `wrs_deal_count`, `wrs_miss_weight`, `lens_alpha`,
`ghost_alpha`, `chunk_sounds`, `word_min_margin`, `word_fully_audible`, `wrs_referral`. Day 3's older WRS helpers
(`WRS_PREDICTED_MIN` and `wrs_predicted_min`, `WRS_ASYMMETRY_PCT` and `wrs_asymmetric`, `ROLLOVER_DROP_PCT`,
`is_rollover`, `rollover_index`, `wrs_below_predicted`) are untouched and commented "Day 3 tests only": no day grades
with them. `speech_mask_level` and `nontest_best_threshold` are untouched.

## 9. Scoring, par and golf

- **Results**: Hoot's tone sheets (unscored); Hoot's SRTs (unscored), or the player's; `speech.wrs.right` and
  `speech.wrs.left` (contract §9.15.1); `speech.wrs_summary`.
- **Accuracy**, per list: matches over the player's words (how often the player scored what she really said). Set-up
  errors go to technique, not accuracy. Hoot's words are out of accuracy.
- **Units**: `units` = the counted player lists on the slot (a redone list and a Hoot-only list count 0); each unit
  weighs `SHEET_WEIGHT` 3 in `merge_results`, as an SRT sheet does.
- **Technique**: every set-up step and every score is a check (§8.2).
- **Efficiency**: 1.0 on fixed lists (sheet `strokes` = `par` = the player's words, D3).
- **WRS golf, one rule on both speech days (D19).** Each player list is a hole.
  - `golf_par` = the player's words (8 or 5 with quick visit on; 25 with it off).
  - `slips` = misscored words, plus 3 for a confirmed wrong set-up (`LIST_CONFIRM_SLIP`).
  - The **tee bonus** (2, `LIST_TEE_BONUS`) needs a solo list, the textbook level, noise exactly when needed at the
    first PRESENT, and an unprompted set-up (no confirm chip, no BOO, no level coach).
  - `golf_strokes = golf_par + slips - tee_bonus`, through `fair_golf` (a clean list is never worse than par; a list
    with slips is never better than par).
  - So **List 2 is the day's birdie** (-2) when the player sets 75 and noise alone. **List 1, the louder list and the
    redo are coached, so they top out at par.** WRS has no eagles.
  - A redone list keeps its golf on the card, but `counts` is false, so only the redo goes into the ear's pct.
- **Points** (`WrsTest.POINTS`): textbook score 10, `wrs_good_start` 10, `wrs_mask_ok` 20, list done 50 (player
  lists), times the combo multipliers (3 gives x2, 6 gives x3, 10 gives x5), plus the golf points.
- **Medals** (the Day 4 paper row):

| Medal | Beat | Gold | Silver | Bronze |
|---|---|---|---|---|
| Chat | `history` | 4 points | 2-3 | 0-1 |
| Explain | `instructions` | first try | second | third |
| Noise | `masking` | noise on before List 2's first PRESENT, no BOO | noise on after the BOO | tested unmasked, then redid |
| Flags | `evidence` | no wrong sorts | 1 | 2 or more |
| Call | `referral` | REFER first try | second | third |

`otoscopy` records gold (a look, no choice).

## 10. The Daily Decibel, Day 4

`story/daily_decibel.gd` is not edited for Day 4 (D8). Its one S0b change reads the day's subheads, weather and
sports column from the summary and makes `_is_speech` true for any speech sheet. `level_nora._results()` always sets
`headlines`, `subheads` (with this visit's `{r}`, `{l}` and `{b}`), `medal_beats`, `weather`, `sports_script` and
`roll_call` ({cards, slips}) in the summary.

**Headlines and subheads**:

| Grade | Headline | Subhead |
|---|---|---|
| S | "TRAINEE HITS EVERY NOTE: WORDS SCORED, FLAGS RAISED, EAR DOCTOR NEXT" | "Better ear first, noise in the good ear, rollover caught. A doctor's check before any fitting." |
| A | "CHOIR DIRECTOR'S WORDS SCORED, FLAGGED AND REFERRED, ALL IN KEY" | "Right {r}%, left {l}%, louder {b}%: red flags raised. A doctor's check before any fitting." |
| B | "WORD SCORES SUNG; A FEW NOTES FLAT, SAYS OWL" | "The flags flew. A few words were scored in the wrong key. Whole words only, says Hoot." |
| C | "SOME WORDS WENT OFF-KEY, CONFIRMS OWL" | (A5) "Remember: loud enough for every sound, 4% a word, and noise in the good ear." |
| Do-over | "NORA BACK TOMORROW FOR AN ENCORE; GHOST STILL HUMMING" | "Word scores are a whole new song. Everyone sings a wrong note once." |

- **Medal row** (`medal_beats`): `[["history", "Chat"], ["instructions", "Explain"], ["masking", "Noise"],
  ["evidence", "Flags"], ["referral", "Call"]]`.
- **Weather**: "Weather: scattered consonants, fog over the left".
- **Sports: THE WORD GOLF CARD** (`sports_script = "res://story/papers/paper_word_golf.gd"`, which builds column 2,
  header "SPORTS: THE WORD GOLF CARD"). Four columns, one row per list, in play order (`seq`); with more than three
  rows (a redo) the rows go compact (21 px):

| Ear · List · Level | Noise | Score + band | Golf |
|---|---|---|---|
| R · Word list 1 · 55 dB | none | 96% EXCELLENT | par |
| L · Word list 2 · 75 dB | 55 | 52% VERY POOR | birdie |
| L · Word list 3 · 95 dB | 70 | 12% VERY POOR | par |

  Under the table (tokens from the visit; a textbook run in brackets; a line with nothing to say is left out):
  - "Tones predict at least: right {min_r}%, left {min_l}%." (82, 60)
  - "Louder: {l}% fell to {b}% (rollover)." (52, 12), or "Louder: {l}%, then {b}%: no rollover."
  - "SRT by Hoot: right {srt_r} ({agree_r}), left {srt_l} ({agree_l})." (15 good, 40 good; "Your SRT: ..." when the
    player ran them, with a sheet Hoot ran tagged "Hoot's")
  - "Red flags sorted: {sorted} of 9 (wrong sorts: {slips})."
  - "Your words: {mine} (Hoot: {hoots}). Best combo: {combo}." (21 and 54 with quick visit on)
  - grades S and A: "HOOT SAYS: Whole words, both ears, louder once, flags raised. Lovely, careful work, trainee.";
    grades B, C and Do-over: "HOOT SAYS: Whole words, both ears, louder once, flags raised. We'll tune the rest
    together."
  - "ARTS: Nightingale Singers' altos now stand on the director's right."
  - A redone list shows its row struck through, with "(redone)"; a list Hoot scored alone shows "Hoot's" in the golf
    column.
- Every number is filled from the visit; the examples are a textbook run, and the real rows vary with Hoot's stamps
  (§2.2).

## 11. The lines (every Hoot line is 18 words or fewer, tokens at their longest)

The ids are for the script and the tests. `{tokens}` are filled from the visit; `{key:<action>}` is `_k()` (D10);
`{he}`, `{his}`, `{him}` and `{Lens}` are `say()` tokens. Nora's lines are marked "Nora:". Lines from the contract's
tables (`WrsTest.TIPS`, `MISSCORED_WRS`, `VERDICTS`, `SpModeWord.LINES`) are quoted here and owned there.

**Intro, history, otoscopy, instructions**

| id | When | Line |
|---|---|---|
| N-IN-0 | she hums in | Nora: "(hums up a scale) Do, re, mi, fa, so... (stops on a note) Mmm." |
| N-IN-1 | then | Nora: "Your hoot is a touch sharp, Professor. Try an A flat. My favourite. Terribly misunderstood." |
| H-IN-2 | reply | "I've been called sharp before. Questions first, then beeps, then words." |
| N-IN-3 | her complaint | Nora: "My left ear has gone like a radio between stations. I hear the voices. I just can't make out the WORDS." |
| H-IN-1 | then | "Day 4, trainee: word scores! Loud enough is easy. CLEAR enough is the question." |
| H-HIS-1 | after a joke answer | "Fun, but not a clue. Ask about her hearing!" |
| H-HIS-2 | after the noise answer | "Good to know: noise reaches both ears. Her trouble is one-sided, though." |
| H-HIS-3 | after the hiss answer | "One-sided hiss, and wobbles. Those go on the red-flag list." |
| H-HIS-4 | after the hardest-place answer | "Hears voices but not words. That's clarity, not loudness. Today's test!" |
| H-HIS-7 | after the onset answer | "Slowly, over a year: noted. Sudden would have meant a doctor today." |
| N-HIS-8 | onset not asked (after round 2) | Nora: "Oh, and it crept up slowly, over about a year. Nothing sudden." |
| H-HIS-5 | the sweep (red flags not asked) | "Always ask about red flags: one-sided ringing, dizziness, pain, discharge, sudden change." |
| H-HIS-6 | after the history | "One-sided hiss, one-sided mush, wobbly stairs. We measure carefully, then decide who she sees." |
| H-OTO-1 | otoscopy | "Look before you test! Clear canals, healthy eardrums. Nothing blocking the left." (the otoscope card: "Fresh speculum. Nora's LEFT ear: clear canal, healthy eardrum.", clinical review A1) |
| H-OTO-2 | otoscopy gag | "...You have a tuning fork in your hair." Nora: "Middle C. For emergencies." |
| H-INS-0 | the prompt | "What do we tell Nora before the words?" |
| H-INS-1 | best: "Repeat each word you hear. Guess if you're not sure." | "Perfect. Guesses count: a word list should catch everything she can make out." |
| H-INS-2 | wrong: "Sing each word back to me." | Nora: "Ro-o-o-ope! ...With vibrato?" Hoot: "Gorgeous. But just SAY them, so we score words, not notes." |
| H-INS-3 | wrong: "Only answer when you're certain." | Nora: "Certain? Then you'll hear very little from me." Hoot: "Too strict! Guesses count. A careful patient hides what she really hears." |
| H-INS-4 | after | "Repeat each word, and guess if unsure. No practice run: word lists test her first try." Nora: "Guess? I've been guessing the altos' words for a year." |

**Movies** (§4.4)

| id | When | Line |
|---|---|---|
| H-MOV-1 | masking offer (Day 2 not played, masking movie unseen) | "New to the Cross-Hearing Ghost? My masking movie explains it first." ["Show me the Ghost movie! (about 90 s)", "Skip it: on with words."] |
| H-MOV-0 | the first play (Steve's lead-in) | "New trick today: WORD SCORES. A quick cartoon first, then our next patient!" |
| H-MOV-2 | replay offer | "Hoot's word movie again? Popcorn's on me!" ["Roll the film! (about 70 s)", "Skip it: I know my banana."] |
| H-MOV-3 | the movie was skipped at day start | "Skipped! Rewatch it any time: pause menu, "Watch Hoot's word movie"." |
| (captions) | the movie itself | §4.2 (ten captions, owned by the movie data) |

**Tones and SRT (Hoot runs)**

| id | When | Line |
|---|---|---|
| H-TON-0 | seated, before the first tone test (clinical review A1) | "This morning's listening check: every beep clean, the button works. Dials stay out of view." (`LevelMike.ROUTINE_LINE`, the case days' words) |
| H-TON-1 | earphones on | "Earphones on! I'll run the beeps at top speed. Better ear first: right." |
| (banners) | Hoot's montages (no time added) | right air: "Better ear first: the right. Watch the stamps fly in!" / "My montage! Right ear at top speed."; left air: "Left ear, Hoot speed!" / "Left ear at top speed. Same dance, other ear!"; right bone: "Bone on her better ear first: 1k and 4k, at Hoot speed." |
| H-TON-2 | masked bone on the left (the banner) | "Now masked bone on her left, at 1k and 4k. Noise in the right keeps the Ghost out." |
| H-TON-R | after the masking recap card (masking movie unseen, clinical review A2) | "The full masking movie is under Hoot's Movies, in the pause menu or on the title screen." |
| H-TON-G | before the masked bone, `bonnie` not done | "Loud sounds can cross the skull to the other ear. That's the Cross-Hearing Ghost!" |
| H-TON-3 | bone done | "Masked bone sits right on her air lines: sensorineural. Left {gap} dB worse." ({gap} = "20 to 30" from her chart, `tone_gap`; a chart that does not read sensorineural: "Bone's in. Left {gap} dB worse than right in the air.") |
| N-TON-4 | reply | Nora: "{gap} worse? Sounds like a modern opera." |
| H-SRT-0 | the SPEECH screen opens | "Now the words. First her SRT in both ears: the softest level for words." |
| H-SRT-1 | quick visit: the hidden SRTs | "My quick SRTs: {r} and {l}. Both agree with her beeps: trustworthy!" (not both good: "My quick SRTs: {r} and {l}. Close enough to her beeps to go on.") |
| H-SRT-2 | quick visit off, `mike` done | "Your turn: SRT both ears, right first. You know the dance from Mike." |
| H-SRT-2b | quick visit off, `mike` not done | "Your turn: SRT both ears, right first. I'll coach every step." |
| H-SRT-3 | the player's SRTs agree | "Good agreement both ears: her beeps are trustworthy." (else: "SRTs stored. Now the main event: word scores!") |

**Word list 1, right ear, coached**

| id | When | Line |
|---|---|---|
| H-W-0 | (A5) before List 1 | "Real clinics play recorded word lists, so every patient hears the very same voice." |
| H-W-1 | WORD mode opens (the plan's `intro`) | "Word scores! One-syllable words, loud enough for every sound. Twenty-five of them, 4% each." |
| H-R-1 | level (the LCD chip follows the dial) | "PTA {pta}, plus 35 is {sum}. But never below 55! Hold {key:louder} to 55." |
| H-R-2 | noise check (with "55 - 40 = 15 < 35: NO NOISE") | "Too soft to cross {his} skull, so no noise for this ear. {key:present_tone}: first word!" |
| H-R-5 | first hit | "{He} said the whole word! Score it: {key:speech_correct}." |
| H-R-6 | first miss or silence (either list) | "Not the exact word, or no answer? That's a miss: {key:speech_incorrect}." |
| (coach) | a chatty hit / a self-correction / a plural / a rhyme | "The word is inside {his} sentence. That's a hit: {key:speech_correct}." / "{His} final answer is the word. That's a hit: {key:speech_correct}." / "One sound extra makes a different word. That's a miss: {key:speech_incorrect}." / "A rhyme is a different word. That's a miss: {key:speech_incorrect}." |
| H-W-2 | `lens_try`, after word 2 | Nora (aside): "Borrow my opera glasses, Professor. They're tuned to me." Hoot: "{Lens}! Press {key:toggle_lens} to see each word as {his} ear gets it." |
| CALL-1 | Call it #1 (contract §9.17.5) | "{Lens} shows a faint '{chunk}'. Will {he} get '{word}'?" Then: "{He} got it! One faint letter, and {his} brain filled the gap." |
| H-R-10 | Hoot's turn | "Lovely scoring! I'll score the rest at top speed." |
| (verdict) | list done (best final at once) | "{pct} percent: {band}. About what {his} tones predict." Then `best_ok`: "{His} best was {best} percent: about what {his} tones predict." Nora: "Clear as a bell. Well, a small bell." |

**Word list 2, left ear, solo**

| id | When | Line |
|---|---|---|
| H-L-1 | the tea demo: the dial parks at 50 | "This is chatting level, 50. Watch what reaches her left ear." |
| (card) | the demo card | LIST SAYS "Fancy a cup of tea?"; REACHES HER "_an_y a _u_ o_ _ea?" |
| N-L-2 | her reply | Nora: "Candy... a canoe? At my age?" |
| H-L-3 | then | "That's her complaint: voices, but not words!" |
| H-L-4 | hand-back (A5) | "Your turn: set a level loud enough for every sound, and decide about noise." |
| (level chip) | a wrong level, first PRESENT | "Loud enough for every sound: PTA + 35 = {target}." / "{key:present_tone} again: test at {db} anyway." |
| (BOO chip) | unmasked first PRESENT (contract §9.17.4) | "BOO! At {db}, words can cross to {his} other ear." / "{key:toggle_mask}: noise on. {key:present_tone} again: test without it." |
| H-L-6 | M after a BOO | "Ghost busted! Now only {his} {ear} ear can answer." |
| (tip) | textbook start (`wrs_good_start`) | "{db}: textbook! Loud enough for {him}, never uncomfortable, and noise in the good ear when needed." |
| (tip) | noise on first (`wrs_mask_ok`) | "Noise in the other ear first. No ghost steals these words!" |
| N-L-5 | first M on a list that needs noise (aside) | Nora: "Is that the sopranos warming up?" |
| (aside) | "bike" heard as "Mike?" | "Mike? He's in the break room. With donuts." |
| CALL-2 | Call it #2 | "Every sound of '{word}' reaches {him}. Will {he} get it?" Then the stamp and the `audible_miss` tip: "{Lens} says every sound arrived. Yet the word came out wrong." |
| (verdict) | list done, best not final | "{pct} percent: {band}. Is that {his} best?" |
| H-L-11 | redo: unmasked (`redo_unmasked`) | "{pct}%? The Ghost helped, so this list can't count. Noise on, fresh list." |
| H-L-12 | redo: wrong level (`redo_level`) | "{pct}%, but at the wrong level, so this list can't count. Fresh list, right level." |
| H-L-10 | a confirmed wrong set-up: Hoot takes over | "That set-up can't count, so I'll finish this list at top speed!" |
| H-L-13 | redo coach | "Word list {n}, coached: {key:louder} to {target}, noise on, then {key:present_tone}." |
| (tip) | a ghost word scored right | "Right score: {he} did say it. But the Ghost helped. Noise next time!" |

**The rollover choice and the louder list**

| id | When | Line |
|---|---|---|
| H-RO-0 | the prompt | "Left ear: {pct}%. What next?" |
| H-RO-1 | best: "Try a new list 20 dB louder." | "Is {pct} her best? A list 20 louder tells us. Worse instead is rollover." |
| H-RO-2 | wrong: "Stop here: {pct}% is her score." | "Not yet! A poor score earns one more check: a new list, 20 louder." |
| H-RO-3 | wrong: "Crank it to 100 and call it fixed." | Nora: "Louder never fixed my altos." Hoot: "Max volume isn't a test. Twenty louder, and we compare." |
| H-RO-4 | comfort check | "{target} dB is loud. Tell me if it's too loud, Nora." Nora: "Loud, but bearable. Like the tenors." |
| H-RO-5 | level coach (the dial starts at the comfortable level) | "Rollover check: 20 louder. Tap {key:louder} up to {target}. Noise stays on." |
| (tip) | the noise was capped (`wrs_mask_capped`) | "Noise {mask}, not {naive}: any louder and it could reach {his} test ear too." |
| N-RO-9 | her first loud answer (aside) | Nora: "Ooh, that's LOUD." |
| (verdict) | list done, rollover (over the slide) | "{pct}%! Louder, and {he} got WORSE. That's rollover." |
| H-RO-8 | then (`rollover_found`) | "Most ears do better, or the same, when louder. Worse is a reason to look further." |
| (verdict) | louder, no rollover | "Louder didn't make it worse. No rollover here." / (A2) "{pct}%: lower, but under the rollover cut-off. Not a flag on its own." |
| (verdict) | the left best is now final | "{His} best was {best} percent. {His} tones predict at least {min}. A red flag." |
| (verdict) | (A3) both bests final, too far apart | "Right {r}, left {l}: too far apart for chance. 25-word lists wobble, but not this much." |

**Misscoring tips** (`MISSCORED_WRS`, contract §9.13.5)

| she said | scored | line |
|---|---|---|
| a foil (a rhyme) | hit | "A rhyme is a miss. Only the exact word counts." |
| another list word | hit | "A different word is a miss. Score it as missed." |
| nothing | hit | "No answer is a miss. Score only what {he} said." |
| a plural trap | hit | "'{said}' isn't '{word}'. Whole word, exactly: that's a miss." |
| the word | miss | "{He} said it exactly! Score it as repeated." |
| a chatty hit | miss | "{He} said '{word}' inside a sentence. The word is there: that's a hit." |
| a self-correction | miss | "{He} settled on '{word}'. The final answer counts: a hit." |
| a ghost word | (scored right) | "Right score: {he} did say it. But the Ghost helped. Noise next time!" |

**Set-up tips** (`WrsTest.TIPS`): `wrs_level` "Word lists go loud enough for every sound: {his} PTA plus 35, never below
55."; `wrs_unmasked` "This loud, words can cross to the other ear. Noise on before the list!"; `rollover_level` "The
louder list goes 20 dB above the comfy one, and never past 100."; `wrs_no_store` "No store needed: the list scores
itself after word 25."; `wrs_list_reused` "A fresh list every time, or {he} starts learning the words."; `ghost_word`
"The other ear answered that one. It can't count for this ear."

**Red-Flag Roll Call** (`level_nora.roll_call_cards`; each pair is the right sort / the wrong sort)

| id | When | Line |
|---|---|---|
| H-FL-0 | board opens | "Red-flag roll call! Each clue steps up: red flag, or fine?" |
| H-FL-1 | hiss | "One-sided ringing: a red flag." / "Ringing in just one ear is a red flag. Try again!" |
| H-FL-2 | wobbly | "Unsteady, plus a one-sided loss: the doctor should know." / "Dizziness with a one-sided loss is a red flag. Try again!" |
| H-FL-3 | tones | "Left {gap} dB worse than right: an asymmetry." / "One ear {gap} dB worse than the other: an asymmetry, a red flag." |
| H-FL-4 | apart (A3) | "Right {r}, left {l}: too far apart for chance. Ears this different need a doctor's look." / "Scores too far apart for chance are a red flag. Try again!" |
| H-FL-5 | predicted (A1) | "Tones predict at least {min}%. Her best was {l}. Worse than predicted." / "Her best is worse than her tones predict: a red flag." |
| H-FL-6 | louder (A2) | "Louder made it worse. Rollover: a classic reason to check further." / "Louder made it worse: rollover. That's a red flag." |
| H-FL-7 | canals | "Clear canals: nothing blocking. The problem is deeper." / "Clear canals are good news. Nothing blocking: the problem is deeper." |
| H-FL-8 | agree | "Agreement means her tones are trustworthy. That makes the flags MORE believable." / "Agreement means her tones are trustworthy. That's good news, not a flag." |
| H-FL-9 | slowly (A5, both sorts) | "Slow still counts when one ear lags. Sudden would mean a doctor today." |
| H-FL-11 | a flag card that did not fire (FINE, both sorts) | tones: "The ears' tones are close: no asymmetry flag there." apart: "Close enough to be chance: not a red flag on its own." predicted: "Her best reached her tones' prediction: no flag there." louder: "Louder didn't make it worse: no rollover, no flag." |
| N-FL-12 | first wrong sort | Nora: "Ooh. A sour one." |
| H-FL-10 | board done | "Words worse than her tones, one ear far worse, plus rollover: the doctor should look further." |

**Referral**

| id | When | Line |
|---|---|---|
| H-REF-0 | stamp prompt | "Your call for Nora:" |
| H-REF-1 | FIT | "Not yet! Aids can wait. First a doctor checks what's behind those flags." |
| H-REF-2 | DOCTOR TODAY | "Close! But it crept in over a year. Soon, not today: days to two weeks." |
| H-REF-3 | REFER | "Refer: an ear doctor soon. The doctor decides on scans. No fitting until then." |
| H-REF-4 | the letter | "The letter says what we found, not what it is. The doctor decides." |
| H-REF-5 | the safety net | "Sudden drop, or worse wobbles before then? Call a doctor that same day." |
| P-LETTER | the letter on paper (not a Hoot line, so no word limit; each clause from the visit) | "REFERRAL to ear doctor (ENT), soon. Asymmetric sensorineural hearing loss, left (masked bone), gradual over about a year; one-sided tinnitus (left); some unsteadiness. SRT agrees with PTA both ears. Word recognition poorer than the audiogram predicts, with rollover: left {l}% at {lv} dB HL (masked), {b}% at {bv}; right {r}% at {rv}. Please assess, including imaging (e.g. MRI), before any hearing aid fitting." |

**The payoff**

| id | When | Line |
|---|---|---|
| N-PAY-0 | after the letter | Nora: "A doctor first? Should I be worried, darling?" |
| H-PAY-1 | reply | "I can't tell you what it is. The doctor can, and that's why we check." |
| H-PAY-2 | then | "Most checks like this come back clear. Checking is how we stay safe." (§17 Q16) |
| N-PAY-3 | then | Nora: "And my hearing aid?" |
| H-PAY-3 | reply | "Once the doctor says go, we'll talk aids." |
| H-PAY-4 | the tactic | "Until then, stand the altos on your right, your clearer side." |
| N-PAY-4 | reply | Nora: "Altos to the right, darling! That's a revolution." |
| N-PAY-5 | the thank-you trill | Nora: "(sings up an arpeggio) Thank you, Pro-fes-sor!" |
| H-PAY-6 | the door gag | Nora: "Professor, your hoot is an A flat now." Hoot: "...Is that good?" Nora: "It's misunderstood." |

The takeaway line ("Whole words, both ears, louder once, flags raised...") is on the paper (§10), not in the payoff.

**Banned words.** No string may name a diagnosis: no "tumour", "tumor", "neuroma", "schwannoma", "cancer", "growth",
"stroke" or "Meniere". Tests enforce it (§16). "darling" appears in at most three of Nora's lines.

## 12. Set-piece gags

- **The tuning gag.** Nora hums in and tunes Hoot ("Try an A flat. My favourite. Terribly misunderstood."). It comes
  back at the door: "Professor, your hoot is an A flat now." "...Is that good?" "It's misunderstood."
- **Middle C, for emergencies.** At otoscopy Hoot spots the tuning fork in her hair.
- **The vibrato instruction.** "Sing each word back to me" gets "Ro-o-o-ope! ...With vibrato?" as a wrong pick.
- **The cup of tea** (List 2's demo, before the player touches the dial). Hoot parks the dial at chat level, and the
  card shows "Fancy a cup of tea?" reaching her left ear as "_an_y a _u_ o_ _ea?". Nora: "Candy... a canoe? At my
  age?" It is her complaint in one line, worked out from the §2.4 margins.
- **"Is that the sopranos warming up?"** Her aside when the speech noise first comes on.
- **BOO! / GHOST BUSTED!** The Day 2 Ghost pops out of the booth window on an unmasked solo PRESENT, and M blows it
  away. On the coached redo it lurks and grows bolder with the level.
- **Chatty Nora.** Now and then a right answer comes with a line ("Rope! Lovely and clear, that rope."), and once she
  corrects herself ("Lock... no, SOCK!").
- **The comfort check.** "Loud, but bearable. Like the tenors." (the day's one tenors joke)
- **The loud list.** Her answers swell into big plain capitals: "HOPE? NO... ROPE?"
- **The rollover slide.** The Banana Board turns her scores into a playground slide. A music note climbs to 52% at
  75, then whooshes over the top and down to 12% at 95, while Hoot's rollover line plays. With reduced motion the
  note moves in two steps.
- **The roll call scale.** Each right sort plays the next note up the scale, drawn on a staff. A wrong sort is a
  cracked-note clunk, and Nora winces: "Ooh. A sour one." (The A flat is kept for the door.)
- **The signed score.** The referral letter is a sheet of music. Nora signs it with a baton flourish, and it slides
  into an envelope for the EAR DOCTOR. (Day 7's paper boat stays Marina's.)
- **Altos to the right.** Hoot's practical tip becomes her small victory: "That's a revolution." The paper follows it
  up in the arts column.
- **The thank-you trill.** Nora sings "Thank you, Pro-fes-sor!" up an arpeggio.

## 13. Accessibility

- **Text first.** Every word is on the card as text before any sound plays, and her answer is always a text bubble.
  Nothing depends on hearing: the scale and the cracked note are drawn on a staff, the noise shows in the NOISE box
  and the booth window, and the movie's hum is drawn as notes. `SpeechVoice` is optional.
- **The word is always readable.** The lens never fades the only copy of the word (§5.3), so low-vision players can
  always read what they are scoring.
- **Reduced motion.**
  - The movie: the player's cuts and crossfades (§4.2).
  - The banana slides in steps, and the curtain does not sway.
  - The Ghost fades in and out instead of floating.
  - The loud bubble never shakes.
  - The tiles flip without bouncing; the lens letters crossfade instead of scrambling.
  - The Roll Call cards slide without bouncing; the letter fades into its envelope.
  - No screen shake on stamps.
- **Mouse.** Every key has a button: PRESENT, LOUDER, SOFTER, REPEATED, MISSED, NOISE, NORA-VISION, the Call it
  buttons, RED FLAG and FINE, the stamps, the choices, and the movie player's "Next" (on the last scene "Start the
  day"), "Skip movie" and "II". Every blocking beat sets `info.mouse`, so the bot plays the day by mouse too.
- **Keys.**
  - Space: present. Up / Down: level, before the first word (hold to repeat).
  - Right, + or =: repeated / "She'll get it" / RED FLAG. Left or -: missed / "She'll miss it" / FINE.
  - M: noise. V: NORA-VISION. H: key hints. Esc or P: pause.
  - The movie: Space, Enter or a click advance like the dialogue box (finish the caption, then the next caption, then
    the next scene); Esc skips the movie; P pauses.
  - The number keys are not used today (6 and 8 stay the transducer keys).
  - The swap-arrows style swaps the level keys, exactly as on Day 3. Every line names keys through `{key:...}`.
- **Colour.** Ticks and crosses use shapes as well as colours. The lens uses opacity, dotted outlines and dotted
  underlines. The ears use O and X as well as their colours. The risers are labelled RED FLAG and FINE. The ear
  compare's verdict is written out ("Too far apart for chance" / "Within chance: no flag").
- **Reading time.** Movie captions are 18 words or fewer, and the player stretches a scene until its caption has been
  up for 1.6 s after typing. Hoot's lines follow the existing dialogue pacing; asides never block.

## 14. Files

**New files**

| File | What |
|---|---|
| `core/patients/nora.tres` | the truth (§2) |
| `core/speech/material/words_1.json` to `words_4.json` | the word lists (§6) |
| `core/speech/models/wrs_model.gd`, `core/speech/modes/wrs_test.gd` | the word model and the session mode (§8) |
| `ui/speech/modes/sp_mode_word.gd` | WORD mode (§5) |
| `ui/speech/sp_score_strip.gd`, `sp_banana.gd`, `sp_ghost.gd`, `sp_ear_compare.gd` | WORD-mode widgets (§5) |
| `story/level_nora.gd`, `story/level_nora.tscn` | the day (§3) |
| `story/games/nora_board.gd` | the Red-Flag Roll Call, the stamp tray and the letter (§7) |
| `story/explainers/movies/letter_choir.gd` | the movie data (§4.3) |
| `story/explainers/stages/letter_choir_sets.gd` | the movie's own sets: `extends "res://story/explainers/explainer_sets.gd"`, `const SETS` of the eight set ids, one `_set_<id>()` each |
| `story/papers/paper_word_golf.gd` | the word golf card (§10) |
| `story/dev_nora.gd`, `story/dev_nora.tscn` | dev scene: the level from one beat (`--from=`), the papers (`--from=paper`), the BOO (`--from=words_l --boo`); excluded from the export |
| `ui/dev/dev_speech_word.gd`, `ui/dev/dev_speech_word.tscn` | dev gallery: WORD mode on Nora through the screen's own controls (`--only=w1,w2,redo,louder`); excluded from the export (`ui/dev/*`) |
| `core/tests/test_speech_wrs.gd`, `ui/tests/test_speech_screen_wrs.gd`, `story/tests/test_level_nora.gd`, `story/tests/test_movie_letter_choir.gd` | tests (§16) |

**Shared files.** Every shared-file change went through the contract's S0a and S0b steps (§9.10.7) and is additive;
Days 1-3, 6-13 and the walk-ins behave exactly as before. Day 4's own additions to shared files are only these:

| File | Change | Why the other days are safe |
|---|---|---|
| `core/speech/speech_rules.gd` | §8.3, in the WRS section and the lists block | the old functions and constants are untouched |
| `autoload/game.gd` | the `nora` line in its `CHAPTERS` marker: day 4, `requires` `mike`, tint `#d8f0e4` | a new entry. The one intended visible change: after Day 3, "UP NEXT" and the paper's "Next" point to Day 4. |
| `world/characters/bean.gd` | the `NORA` spec in its marker region (bob, tuning-fork pin, notes scarf, opera glasses) | a new spec |
| `story/portraits.gd` | "Nora" in its marker region: BG `#d8f0e4`, name colour `#2f7d5b` | a new key |
| `story/dialogue_box.gd` | the display name "Nora Nightingale" | a new key |
| `story/explainers/movies.gd` | the `letter_choir` registry line (S0a) | a new id; a movie is listed for replay only once its chapter exists |
| `story/voice.gd` | none: the level calls `Voice.register("Nora", ...)` at run time | |
| `tools/autoplay_bot.gd` | the Day 4 checks of contract §9.22, in blocks marked `# (Days 4-5)` (`tools/INTEGRATION_NOTES.md`, "Already in the bot") | each block needs a word sheet or the `nora` chapter |
| `export_presets.cfg` | `story/dev_nora.*` in both presets' `exclude_filter` (the word lists ride the existing `core/speech/material/*.json` include) | dev files only |
| `docs/SPEECH.md`, `CONTRACTS.md`, `README.md`, `tools/README.md`, `docs/ADDING_A_CHAPTER.md` | W6: SPEECH.md §4 and the WRS kinds; the contract as §9.10-§9.24; the Day 4 commands and overview; the movie lead-in rule | docs |

Not edited for Day 4: `story/daily_decibel.gd` (S0b's hook covers it, D8), `explainer_stage.gd`, `explainer_sets.gd`
and `explainer_player.gd` (the main thread owns them; the sets hook means Day 4 never needs to touch them).

## 15. Screenshots

Taken by `_shot()` in the bot run (`tools/shots.sh`), by the dev scenes, and by the shared dev scene for the movie.

| Name | Shows | Taken by |
|---|---|---|
| `explainer_letter_choir_<NN>_<scene>` (8, at 0.2 / 0.6 / 0.95 of each scene) | every movie scene as the player shows it; once more with `--reduced-motion` | `dev_explainer.tscn --movie=letter_choir --at=0.2,0.6,0.95` |
| `day4_intro` | Nora humming in, the tuning gag | the level |
| `day4_tuning_fork` | otoscopy with the fork in her hair | the level |
| `speech_right_wrs_words_1_first_word` | WORD mode, List 1, first word: card, strip, level chip, NOISE sum | the bot |
| `day4_lens_right` | NORA-VISION on: LIST SAYS "fox", REACHES HER with a faint "f" | the level |
| `day4_call_it` | Call it #1 on the card | the level |
| `speech_right_wrs_words_1_stored` | List 1 done: 96%, EXCELLENT, the band ruler | the bot |
| `day4_tea_demo` | the dial at 50: "_an_y a _u_ o_ _ea?" | the level |
| `day4_boo` | the BOO chip and the Ghost in the booth window | `dev_nora --from=words_l --boo` (the bot always masks first) |
| `day4_ghostbuster` | GHOST BUSTED! | `dev_nora --from=words_l --boo` |
| `speech_left_wrs_words_2_first_word` | List 2's first word, set up by the player | the bot |
| `day4_audible_miss` | the AUDIBLE, BUT MISSED stamp | the level |
| `speech_left_wrs_words_2_stored` | List 2 done: 52%, "Is that her best?", the ear compare | the bot |
| `speech_left_wrs_words_3_stored` | the louder list done: 12%, the slide, the predicted-min bar with its red pin | the bot |
| `day4_flags` / `day4_flags_done` | the Roll Call mid-way and complete | the level |
| `day4_stamp` | the REFER stamp | the level |
| `day4_letter` | the signed score sliding into its envelope | the level |
| `day4_a_flat` | the door gag | the level |
| `results_final` | the Daily Decibel, Day 4 | the bot |
| `dev_day4_paper_<grade>` | four Daily Decibels: S, A with a redone list, C, Do-over | `dev_nora --from=paper` |

The commands are in `tools/README.md` (Day 4 rows).

## 16. Tests

**`core/tests/test_speech_wrs.gd`** (contract §9.24; where an amendment changed a pinned number, the test says so)

- **Rules**: `wrs_level(15) == 55`, `wrs_level(40) == 75`; windows 50-60 and 70-80 (`wrs_window`); `wrs_band(52) ==
  very_poor`, `wrs_band(56) == poor`; (A1) `wrs_predicted_min_interp` 15 -> 82, 35 -> 66, 40 -> 60, 41.67 -> 58, 45 ->
  54, 50 -> 48, clamped outside 0-80, 0 without a PTA, and Nora's left best below it on every §2.2 row; the old
  `wrs_predicted_min` unchanged; (A2) `wrs_rollover` pins (52 at 75, 12 at 95: 0.77; the worst deal 0.67; 52 then 40:
  0.23, no rollover; a lower score at a softer level and a single list: no PBmin); (A3) `wrs_differ` on the eight
  published 25- and 50-word range ends, `wrs_same_range(44, 25) == (20, 68)`, Nora's 96 vs 52 and 92 vs 56 different,
  96 vs 88 and 52 vs 40 the same; `ear_best_bone` and `nontest_best_bone` on Nora's Hoot sheets (right 35, left 10);
  `wrs_mask_level(75, 35, phones) == 55` and `(95, 35, phones) == 70`, (A4) the other ear's gap adds, `wrs_mask_capped`;
  `lens_alpha` and `ghost_alpha` end points; `word_fully_audible` needs 3 dB ("sock" on her right at 55 is not audible:
  s is 0); `wrs_referral` on its cases.
- **The material**: four lists of 25, 100 different targets, `chunks` join to the text, `WRS_KEY_MIX` per list, Word
  list 1 in §6's order, the audible-word rule, the two asides (hook keeps its first sound), the content rules, and the
  own-material originality guard (§6).
- **Nora's chances** (truth, IA 50): right 55 0.956; left 75 masked 0.515; left 95 with noise 70 0.120; left 75
  unmasked 0.70; masked out when the noise reaches the crossed level; and the §2.2 rows (`test_nora_rows`).
- **The deal**: counts within 1 of round(p x 25), exact half the time, over 4000 seeds per case; s / f / th words
  missed far more often on her cochlear right; no banana on her neural left; masked lists never cross; a seed replays
  the deal; `ensure_audible_miss_by` 6 lands an audible miss in places 2-6 every time on `words_2` and `words_3` at 70,
  75 and 80; `aside_by` lands the aside as a miss.
- **Answer styles**: on player words only; a chatty hit carries the word as a whole token with 6 words or fewer of
  chatter; at most one plural trap per list; one self-correction on List 2; the counts never change.
- **The session**: the mode loads by path; lists end after 25; level and noise lock; two lists on one ear do not
  collide; `redo_of`; the first-word checks; misscoring by what she said; verdicts held until the louder list on her
  left, and the no-rollover lines; every sheet field; golf (a clean solo List 2 with an unprompted set-up is a birdie;
  coached lists top out at par; a BOO removes the tee bonus); Hoot's words out of accuracy and units;
  `run_by_textbook` reaches a sheet for every Day 4 plan; Call it; `state().wrs`; every line fits 18 words.

**`ui/tests/test_speech_screen_wrs.gd`**

- The layout and every anchor at 1280x720 and 1920x1080, clear of Hoot's perch; a list by keys ends itself; a list by
  mouse; beats, info, solvers and a stale solver; Hoot's turn at top speed, restored and keyed per list.
- The swap-arrows style swaps only the level keys, and the coach follows it; no STORE and one level per list.
- The two-press confirm (the level chip and the BOO) on a solo list; a second press tests anyway and Hoot finishes;
  a coached list denies instead, and the Ghost lurks there.
- The lens: V and the button, its alpha on the MEASURED thresholds; its row turns into her answer only on a miss.
- Call it with both keys and both buttons; the tea demo neither presents nor locks; asides never block; the ear
  compare waits for both ears.
- Reduced motion and the widgets; Day 3's SRT never reaches the WORD mode; every line fits and names no diagnosis.

**`story/tests/test_level_nora.gd`**

- The movie is announced only when unseen; the masking-movie offer appears only when that movie is unseen and `bonnie`
  is not done.
- The word-list plans and the quick counts (8 / 8 / 5 / 5); the SRTs are coached until Day 3 is done.
- The Roll Call cards from a textbook visit (9 cards, 6 flags); the board by keys and buttons, and a wrong sort
  bounces back; the stamp tray and the letter (REFER, "imaging", "before any hearing aid fitting").
- The word golf card's rows and lines; the Day 4 paper fits the window.
- Every Hoot line in `level_nora.gd` and `nora_board.gd` is 18 words or fewer with tokens at their longest and names
  keys only through `{key:...}`; no banned diagnosis word; "darling" in at most three of Nora's lines.
- The level's constants; a smoke run of the level up to the tones.

**`story/tests/test_movie_letter_choir.gd`** (contract §9.20)

- `Movies.validate("letter_choir", Stage2D.SETS)` is empty with its own sets; `Movies.own_sets("letter_choir")` is
  exactly the eight set ids, none of them built in.
- The house rules: 45-110 s (70), every caption 18 words or fewer, `seen_at` is a scene, every cue in `Sfx.SOUNDS` at
  -8 dB or softer; every scene has card params (a heading of 30 characters or fewer, at most 4 lines of 36 or fewer,
  an icon in `CARD_ICONS`) and its set's data under its own key.
- The lead-in: scene 1 holds its card (`card_hold` 8) with two question chips, and its captions name the question
  and the answer.
- Cards only: with the `stage` line removed every scene still plays as its card; with it, every scene is drawn.
- Pure in `t`: the sets script contains no `randf`, `randi`, `RandomNumberGenerator`, `Time.`, `create_tween`,
  `add_child` or `get_tree` (a source scan).
- Facts: the banana is `SOUND_CUES` at `CHAT_DB`; the louder scene is loud enough, never too loud (35 dB,
  `WRS_ABOVE_PTA_DB`); the choir and the mush; the crossing's `ia` is `SPEECH_IA_DB[&"phones"]` and the count board's
  25 tiles are `WRS_WORDS`.

**The bot** (Day 4 checks in `tools/autoplay_bot.gd`, contract §9.22): both ears present, right first; list ids in play
order; right best 88 or more; left comfortable 64 or less; left `best_final`, `below_predicted` and `asymmetric`; a
louder list with `rollover` and its capped noise; `referral == &"refer"` and the visit's `decision`; a fresh save must
start `letter_choir` (the result prints `movies` and `wrs_lists`).

**Regression**: every Day 1-3 and 6-13 test passes unchanged, the Day 3 golden snapshots match (A8 changed one Day 3
tip line, said in its test), and the Day 1-3, 6-13 and walk-in autoplay results match their baselines.

## 17. Open questions for Steve

1. **The WRS level**: PTA + 35, rounded to 5, never below 55, with an accepted window of PTA + 30 to 40 (at least
   50). Or would you rather use SRT + 35-40, or the patient's most comfortable level? (Q30 asks the same with the
   clinical review's options.)
2. **Whole words or phonemes?** 25 words at 4% each with 90 / 78 / 66 / 54 bands is a US convention; many UK and
   Australian clinics score 10-word lists by phoneme (30 phonemes). Which do you use? If phonemes, should Word lists 1-4
   switch to 10 words x 3 phonemes?
3. **The bands**: 90 / 78 / 66 / 54 for excellent, good, fair, poor, and very poor below. Do the labels match your
   clinic?
4. **The predicted minimum** (A1). The game uses `WRS_PREDICTED_MIN_25` (PTA 0 -> 88, 20 -> 80, 30 -> 72, 40 -> 60,
   50 -> 48, 60 -> 36, 70 -> 24, 80 -> 12), a game approximation of Dubno et al. (1995)'s lower limits anchored on
   their 50-word value at a PTA of 50, interpolated between rows: Nora's right (PTA 15) gets 82, her left (PTA 40) 60,
   and a measured 41.7 gives 58. Is interpolating fair? (The rows themselves: Q27.) Lines and the paper never credit
   a number to Dubno; they say "her tones predict at least {min}%".
5. **Ear differences for word scores** (A3): two bests differ when they are too far apart for chance on lists that
   long (the 25-word critical difference: arcsine-transformed, z 1.96, which reproduces Thornton & Raffin's 95%
   ranges). 96 vs 52 and 92 vs 56 differ; 96 vs 88 and 52 vs 40 do not. (Q29 asks whether newcomers should get a
   simpler fixed cut-off.)
6. **Rollover** (A2): one extra list 20 dB louder; the rollover index (PBmax - PBmin) / PBmax, with PBmin taken only
   from a level above PBmax's, flagged at 0.45 or more (the cut-off: Q28). Nora rolls over from 75 at 20 points per 10
   dB, so 52% at 75 falls to 12% at 95 (index 0.77). Is it right to check only the poorer ear, and only after a poor
   score?
7. **Speech masking**: noise at the speech level minus 20 (plus the other ear's air-bone gap, A4); IA 40 for phones
   and 55 for inserts; noise needed when the level minus IA reaches the other ear's best bone (500-4k). The game takes
   the best bone per frequency (masked, else unmasked, else air). Is that right? Should SRT switch to it too?
8. **The louder list's noise**: 95 - 20 = 75 is clamped to the maximum, her left best bone 35 + 40 - 5 = 70 (the
   minimum is 95 - 40 = 55). Hoot says "Noise 70, not 75: any louder and it could reach her test ear too." Is that
   the clamp you would teach?
9. **Nora's numbers**: the thresholds, PTA 15 and 40, SRT 15 and 40, word scores 96 / 52 / 12, rollover after 75 at
   20 points per 10 dB, and a phones IA of 50 (lower than average, so the Ghost matters). Believable for a one-sided
   loss that needs a doctor's look?
10. **The six flags and three fine cards.** Is "wobbly on stairs sometimes" fair as a red flag for a young player? Is
    "came on slowly, over about a year" right as a FINE card, with (A5) "Slow still counts when one ear lags. Sudden
    would mean a doctor today."?
11. **The referral wording**: REFER soon (days to about 2 weeks) to an ear doctor, imaging requested in the letter,
    "the doctor decides on scans", and a same-day safety net for a sudden drop or worse dizziness.
12. **Urgency in your service**: is a gradual asymmetric loss with poor word scores a "soon" referral, or routine?
    (Q31 asks the same with the NICE guidance in mind.)
13. **No familiarisation for word lists**, and no carrier phrase ("Say the word..."). Should a carrier come in with
    recordings later?
14. **Recorded or live voice.** The words are text plus an optional synthesized murmur; (A5) Hoot now says "Real
    clinics play recorded word lists, so every patient hears the very same voice." before List 1. Enough, or should the
    movie or the paper say it too?
15. **Bone at 1k and 4k only** (Hoot, at top speed, to save time for words): unmasked on her right mastoid, then masked
    on her left with noise in the right. Enough to call it sensorineural before the words, or should Hoot run all four
    frequencies?
16. **The reassurance line**: "Most checks like this come back clear." True enough to say? If not, an alternative is
    "Checking first is the careful way. Finding out helps, whatever it is."
17. **The quick-visit split**: the player scores 8 / 8 / 5 words (5 on a redo, and 3 before Hoot takes over a confirmed
    wrong set-up). Enough practice?
18. **The lens and the 3 dB rule.** The lens uses the game's simplified sound map (`SOUND_CUES`), the measured
    thresholds interpolated, "audible" at 3 dB or more, "only just" from 0 to 3, and CHAT level 50. Close enough to the
    real speech banana to teach with?
19. **The movie captions** (§4.2), especially the lead-in ("Today's mystery: why can loud-enough words still come out
    mushy?" and "The answer is a WORD SCORE: it counts clear words, because beeps can't measure clarity."), (A5) "Turn
    the words up: loud enough for every sound, never uncomfortable. Most singers step out." and "Loud words can cross
    the head to the good ear. Speech noise there keeps it out."
20. **Golf, one rule on both speech days**: a clean list is a birdie only when the player made its set-up unprompted
    on a solo list (Day 4: List 2); coached lists top out at par. Fun and fair?
21. **Originality**: every list was written fresh for the game, and its note names the published tests it must not
    copy (NU-6, W-22, CID W-1, PB-50, AB / Boothroyd, NU-CHIPS, WIPI, the Modified Rhyme Test). The repo holds no
    published list, so the test checks only our own material (§6). Please flag any item or rhyme set you recognise.
22. **The order**: tones, then SRT, then WRS right, left, then the louder left list.
23. **The "UP NEXT" change**: after Day 3 the paper now suggests Day 4 instead of Day 6. Intended; OK?
24. **Self-corrections and chatty answers.** "Lock... no, SOCK!" is scored as a hit (the final answer counts), and
    "Sock! Like a good downbeat." is a hit (the word is there). A plural ("Socks?") is a miss. Your clinic's rules?
25. **The altos tactic**: "stand the altos on your right, your clearer side" (the director's right, which is stage
    left). A sensible practical tip, or would you rather Hoot say something else?
26. **How much to coach List 2's noise.** The movie explains it, List 1 shows the sum, and List 2 shows only the rule
    ("NOISE? LEVEL - 40 vs RIGHT BEST: 10") plus the BOO chip if the player forgets. Enough, or should the first noise
    decision be fully coached?
27. **(A6) Dubno's 25-word lower limits** at PTA 0, 20, 30, 40, 50, 60, 70 and 80. The game's approximation is A1's
    table (Q4); please give the published values so the rows can be replaced.
28. **(A6) The rollover-index cut-off** for your recorded list: 0.45 (the game's default, the classic cut-off), 0.25,
    or "any clear drop at a louder level"?
29. **(A6) Critical differences** (A3, the game's default) or a simple fixed cut-off for newcomers, and which value?
30. **(A6) The WRS level rule**: PTA + 35 (the game's default), the 2 kHz sensation-level rule (2 kHz under 50 add 25,
    50-55 add 20, 60-65 add 15, 70-75 add 10), or LDL - 5?
31. **(A6) Urgency**: is a gradual one-sided loss with poor words a routine or a two-week referral in your service
    (NICE NG98 treats it as routine)? The game keeps the cases days' "refer = soon" until you answer.

---------------------------------------------------------------------------------------------

## Design notes (critique points not taken, or taken differently)

1. **Clinical 7 ("coach List 2's noise step the first time")**, taken partly. The movie's crossing scene explains
   speech noise before the day, List 1's coached noise check shows the sum, and List 2 shows the rule and the other
   ear's number, plus the BOO coaching on a mistake. List 2's noise step is not fully coached, because fun 8 makes it
   the day's one solo decision (and its only birdie). Open question 26 asks Steve.
2. **Fun 3's seven scenes in 56 s** became eight scenes: clinical 7's Ghost scene ("crossing") was added rather than
   merged, because it is a separate idea from counting words. Steve's lead-in (2026-10-19) then grew scene 1 from 9 s
   to 15 s (the 8 s marquee hold and two more captions), so the movie is 70 s.
3. **Fun 4's self-contained shell scene with `start()` / `finished(skipped)` and a `seen_explainers` shim.** Not built:
   the shared player already plays MOVIE data with exactly those controls, and `movies_seen` records it (engineering
   1, contract design note 1).
4. **Fun 15's "altos stage right".** Corrected: Nora faces the choir, so stage right (the singers' right) is her left,
   her poorer side. The paper says "now stand on the director's right" (stage left).
5. **Fun 15's S headline "...DOCTOR'S CHECK BOOKED"** and clinical 14's "...SENT TO THE EAR DOCTOR IN PERFECT TIME".
   Merged as "TRAINEE HITS EVERY NOTE: WORDS SCORED, FLAGS RAISED, EAR DOCTOR NEXT": the clinic refers but does not
   book the doctor's check, and the pun on timing is dropped.
6. **Fun 27 (the paper nightingale repeats Day 7's paper boat).** Taken as the choir version (a score signed with a
   baton flourish). Declaring a series motif would mean editing `docs/CASES.md`, which Day 4 does not touch.
7. **Clinical 6's "the 80 row gives 100 dB -> 4%".** By the rules it is 0% (0-4): p = 0.0199, x 25 = 0.50, which
   rounds to 0. The row is still rollover (index 1.00, worst 0.89).
8. **Clinical 14's letter and fun 13's "52% fell to 20%"** now say 12% at 95: clinical 6's rollover (20 points per
   10 dB) moved the louder score. Both edits are otherwise as asked.
9. **Fun 6's "Call it" as a stock `choice` beat.** Made a SPEECH-screen beat (`call_it`, D29) instead, so the screen
   does not hand over to the dialogue box mid-list. It is still unscored, with keys and mouse.
10. **Clinical 1's "move beat 8b after beat 9"** and fun 1's "fold 8b into the List 2 done screen" pull in different
    directions. The verdicts are held (clinical 1) and land on the louder list's done screen, so there is no separate
    beat (fun 1's time saving). List 2's done screen asks "Is that her best?".
11. **Fun 8's BOO text** ("BOO! At 75, words can cross her skull. Press [M] for noise in her right.") is written with
    tokens, and as two lines, because a confirm chip must also say what the second PRESENT does.
12. **Clinical 22's Ghost alpha "+5 offset"** is done with engineering 16's floor instead (0.2 from the first level that
    needs noise); both fix the same "invisible at 50" bug. It applies to coached lists only, since solo lists no
    longer lurk (fun 8).
13. **Fun 13's LCD counter "PTA +0 ... +35 | min 55"** reads "PTA 15 + 40 = 55 · min 55": it follows the dial with the
    real sum, so the player sees why 55 and not 50.
14. **The "booth" foil "booze"** (not raised by a critique) was replaced by "boos": the content rules ban alcohol words.
15. **Fun 1's "about 11:00 first visit"** lands there after all: the Roll Call (fun 9) and the hidden SRTs saved time,
    and the lead-in, the unmasked right bone and the recorded-list line (A5) spent it again.
16. **Engineering 2's `letter_choir_stage.gd` (a subclass of `explainer_stage.gd`) and fun 4's "paste into SETS
    later".** Superseded by the per-movie sets hook: the sets live in `story/explainers/stages/letter_choir_sets.gd`,
    which extends `explainer_sets.gd` and names its list `SETS` (the base declares none, so nothing is shadowed), and
    `MOVIE.stage` points at it. Nothing is ever pasted into the shared stage. The preview script is dropped too:
    `dev_explainer --movie=letter_choir --at=...` shoots the real sets.
17. **Engineering 2's "unique across movies" set-id test.** Dropped: the stage asks only the playing movie's own sets
    script, so ids only need to avoid the built-in `SETS` (which would win). The ids happen to be unique anyway.
18. **Fun 4's "Next scene" / "Skip movie" controls.** The shared player has moved on: Space / Enter / a click advance
    like the dialogue box, and the buttons are "Next" ("Start the day" on the last scene), "Skip movie" and "II". This
    doc follows the player, so the controls match Day 2 exactly.
19. **Fun 1's "merge H-TON-2/3/4 into one line".** H-TON-3 is the one spoken result line. H-TON-2 is the banner over
    Hoot's run (it costs no time), and Nora's reply N-TON-4 stays as the tones gag (about 3 s).
20. **Engineering 13's "Tap {key:louder} {taps} times".** H-RO-5 says "Tap {key:louder} up to {target}": Up repeats
    when held (fun 13), so a tap count would be busywork.
21. **(As built) Unmasked right bone before the masked left bone.** The design had masked bone only. The AudiOtron
    asks for masked bone only where an unmasked stamp shows a gap, so Hoot runs unmasked bone on her better ear first
    (the cases' one-sided pattern, about 15 s more).
22. **(As built) The Roll Call's lines are the board's caption**, not dialogue bubbles, so a sort never waits on the
    dialogue box.
23. **(As built) The originality guard checks only our own material** (§6): the repo holds no published test, so there
    is nothing to compare against; every list's note names the tests it must not copy instead.
