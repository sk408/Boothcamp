# Booth Camp, Chapter 5 (Day 5): Marco Polenta, "The Party Noise Test"

This is the design of the fifth playable day, as built. It covers speech in noise: SNR and SNR loss, the Party Noise
Test (six sentences of five key words, the party louder every sentence), scoring key words exactly, the bill's
arithmetic, why the audiogram isn't the whole story, aided testing in the sound field, a blind test of directional
microphones, and restaurant tactics. Marco hears fine in quiet and gets lost at a busy table. The shared speech rules
and numbers live in `docs/SPEECH.md` §5 (`SpeechRules` in `core/speech/speech_rules.gd`). The API is `CONTRACTS.md`
§9.10-§9.24; where this doc and the contract differ, the contract wins, and the decisions D1-D30 there are the ones
this doc follows. Day 5 builds on Day 4's WORD mode (Hoot runs Marco's words in quiet with it, off-screen). Days 1-4,
6-13 and the walk-ins do not change. Steve checks every number and every clinical line (§15).

**Clinical review (2026-10-19).** The project's clinical review (`docs/CLINICAL_REVIEW.md`, item S9) changed a band
name and two Day 5 lines before the day shipped. They are folded in below as amendment **A7** (A1-A6 are Day 4's, A8
is Day 3's):
- the 0-3 dB band is **"Near-normal"**, never "Small" (`SIN_BAND_NAMES[&"normal"]`): the band ruler, the receipt, the
  movie's typical diner and the paper print "NEAR-NORMAL";
- the plates' line is "His audiogram can't tell us how he copes in noise. Measured: {avg} dB." (§5.7);
- after the FOCUS result, and on the paper: "The booth is kinder than a real restaurant. We'll check how the aids do at
  your table." The booth benefit is never presented as proof of benefit at a real table, and the 4.0 dB directional
  benefit stays (Q3).

| | |
|---|---|
| Teaches | SNR (how much louder the voice is than the noise) and SNR loss; the Party Noise Test (6 sentences of 5 key words, the party louder every sentence: SNR 25 down to 0 dB in 5 dB steps); scoring key words exactly; the arithmetic (SNR loss = 25.5 - key words right, each missed word about 1 dB, two lists averaged); the four bands and the technology each one points to; why the audiogram isn't the whole story; both ears together vs each ear; aided testing in the sound field at a chatting level; directional microphones, tested blind, and when a difference is real; restaurant tactics; when a remote microphone comes in |
| Length | about 12 minutes on a first visit with quick visit on (the default), including the 71 s movie; about 11 on replays (the movie is offered, and skipping is the default). About 14 minutes with quick visit off. The bot's keyboard run takes about 13 game-minutes. |
| Opens | always, from the Days grid. `requires` = `nora` only picks the "UP NEXT" hint. |
| New controls | The SPEECH screen's new PARTY mode. **Space** presents a sentence. **Up / Down** set the talker before the first sentence (unaided lists only: Hoot sets the aided level). **Right** (or + / =) = he got the highlighted key word; **Left** (or -) = he missed it. **1-5** flip one key word (the new actions `party_word_1` to `party_word_5`); **G** = ALL GOT (`party_all_got`); **S** or **Enter** = LOCK IN (`store`). There is no MASK (M only says why). The bill's band ruler: Left / Right and Space / Enter, or a click. The plates: keys 1-4, a drag, or a click then a click. The switch: Space / Enter or a click. The seats: the choice keys or a click. Every control is also a button. The swap-arrows style swaps only the level keys, exactly as on the SRT screen. The movie uses the shared player's controls (Space, Enter or a click: next, like the dialogue box; Esc: skip the movie; P or the "II" button: pause). |
| Level scene | `res://story/level_marco.tscn` (`story/level_marco.gd`). Movie data: `res://story/explainers/movies/party_noise.gd`, drawn by its own sets script `res://story/explainers/stages/party_noise_sets.gd` (`MOVIE.stage`), played by the shared `explainer_player.tscn` |

If Day 4's WORD mode were missing, Hoot would say one line instead of the words in quiet (§9, "No WRS mode") and the
day would still play; without the SPEECH screen Hoot runs every list by the textbook (`run_by_textbook`, C23).

---------------------------------------------------------------------------------------------

## 1. The patient

**Marco Polenta**, 54, restaurant critic (the "Table Talk" column in The Daily Decibel). Round and dapper: a mustard
waistcoat, a tomato-red cravat, a cream shirt, aubergine trousers, silver hair swept back, a grand curled moustache,
half-moon reading glasses on a chain, a little black critic's notebook, a fork in his breast pocket, and a white
napkin tucked into his collar at all times (yes, in the booth too).

Personality: theatrical, generous, warm, proud of his palate. He describes everything as food. Under the show he is
worried: his job is listening to chefs and dinner guests, and lately he books the empty 5:30 table and reviews quiet
rooms. His friends call him the Early Bird. Not a buffoon: he is sharp, and once he understands SNR he loves the
metaphor. No accent jokes; the comedy is food and drama.

> "My ears are perfect, in quiet. At a busy table, every word turns to soup."

The stakes, said early in the intro: "My daughter Rosa wants dinner at Trattoria Clatter on Saturday. The loudest
room in town. She has news." The payoff (§7.3) is that Saturday.

**Entrance gag: the review.** He steps in, sniffs, opens his notebook and reviews the clinic out loud: "(sniffs, opens
his notebook) Ambience: beige. Coffee: burnt, two stars. Service: an owl. Intriguing." Hoot: "...Welcome to Booth
Camp."

**As built.** His bean spec (`world/characters/bean.gd`, `MARCO`, in Day 5's marker region): the swept silver hair,
the curled moustache, the cravat, the napkin, the notebook and the fork, and the half-moon glasses (`"glasses":
&"halfmoon"`) on his nose, with their chain. Because they are `parts["glasses"]`, the clinic's head gear takes them
off for the earphones, the bone oscillator and the masking phone, and puts them back once he stands with his head
clear (main's add343c); the level does nothing about glasses itself. His portrait (`Portraits` "Marco") and Rosa's
are in the same region; the dialogue box names them "Marco Polenta" and "Rosa Polenta"; their voices are registered
at run time (`Voice.register("Marco", {f0: 118, wobble: 0.07, roll: 0.85})`, Rosa f0 215).

**Case history** (two rounds of three choices; prompts "Ask Marco a question:" then "Next question:"; the first 18
characters of every option are unique, for the mouse bot):

| Round | Question | Points | Answer | Case note |
|---|---|---|---|---|
| 1 | Where is it hardest to follow talk? | 2 | "Busy restaurants. Parties. Weddings. One-to-one in a quiet room? Perfect. Like a library." | Lost in noise; fine one-to-one in quiet |
| 1 | Any pain, dizziness, ringing or drips? | 2 | "No pain, no spinning, no drips. A faint hiss after very loud nights, both ears. Gone by breakfast." | No red flags; a brief hiss in both ears after loud nights |
| 1 | What's the best meal you ever had? | 0 | "A mushroom risotto in a hill town. I wept. The chef wept. The waiter asked for a tissue." | (joke) |
| 2 | Did it come on slowly, or suddenly? | 2 | "Slowly, over a few years. Like a sauce reducing. Both ears the same." | Gradual over years; both ears alike |
| 2 | How do you manage busy dinners now? | 1 | "I book the 5:30 table. Empty room, perfect hearing. My friends call me the Early Bird." | Books early tables to dodge the noise |
| 2 | Have you tried shushing the whole restaurant? | 0 | "Once. A wedding party of ninety shushed me back. In harmony." | (joke) |

- **Hoot's reply to each answer**: "Fine one-to-one, lost in a crowd. That's exactly what today measures." (hardest),
  "Slowly, both ears alike: noted. Sudden would have been a red flag." (onset), "The early table is a clue too. People
  quietly avoid what's hard." (coping), and "Delicious, but not a clue. Ask about his hearing!" for a joke.
- **The red-flag sweep always happens.** If the player skipped the pain question, Hoot asks it ("Always check red
  flags too: pain, dizziness, drips, one-sided ringing or loss, sudden changes."). If the player skipped the onset
  question, Hoot asks that too ("Sudden changes are red flags too. Slowly, or suddenly?"). Marco's answers and case
  notes are the same.
- **The hiss.** After his hiss answer (asked or swept), Hoot: "Hiss in both ears after loud nights isn't a red flag.
  It's a noise warning." Then: "Earplugs for loud nights: filtered ones keep the music clear."
- After the history Hoot sums up: "Fine in quiet, lost at busy tables, both ears alike. No red flags. Let's measure!"
  The notes get a green "No red flags" card (the HUD's new `"ok"` clue kind, headed ALL CLEAR).
- **Medal `history` (Chat).** Gold = 4 points. Silver = 2 or 3. Bronze = 0 or 1.

## 2. Truth tables (`core/patients/marco.tres`)

**Air thresholds** (dB HL). Bone = air (sensorineural, no gap; no bone data in the profile):

| Hz | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| right (O) | 10 | 15 | 15 | 20 | 25 | 30 | 35 | 40 | 40 | 35 |
| left (X) | 10 | 15 | 15 | 25 | 25 | 30 | 35 | 40 | 45 | 40 |

- PTA (500/1k/2k): right 21.7, left 23.3. The three spread 15 dB (under `STEEP_RANGE_DB` 20), so both use the
  three-frequency average. Degree: normal on the PTA (`DEGREE_BANDS` 25), with a mild high-pitch loss (3-8k at
  35-45). `ClinicRules.classify_shape`: `sloping` in both ears.
- The ears are within 5 dB at every frequency: symmetric. Better ear: right (`SpeechRules.better_ear(21.7, 23.3)`), so
  Hoot tests the right ear first.

**Speech** (the `speech` field; every key already exists in `PatientProfile.SPEECH_KEYS`):

| Key | Value | Why |
|---|---|---|
| `wrs_max` | right 96, left 92 | Excellent words in quiet. `predicted_wrs_max` of his true thresholds would give only 86 for the right ear at 55 dB (s, f, th, z, v and t sit under threshold there), too pessimistic for this mild slope, so the profile states it |
| `snr_loss` | 9.0 | Moderate. Much bigger than an audiogram like his suggests |
| `directional_benefit` | 4.0 | What FOCUS wins back with the talker in front and the party behind, for a fitting on **vented domes** (open enough for comfort with his good low pitches, closed enough for some focus). It equals the shared default and is stated so the fitting is explicit |
| (`srt`, `rollover`, `neural`) | not given | Honest ears: SRT follows the PTA (right 20, left 25), no rollover, no smearing |

His head (tones): slope 2.5, attention 0.95, fatigue 0.0005, false alarms 0.3 / min, reaction 0.7-1.3 s, rhythm
sensitivity 0.5, no tinnitus pitch, default interaural attenuation (phones 60, inserts 75). Tags `speech`,
`speech_in_noise`, `chapter_5`. Pronoun he, nickname "Marco".


### 2.1 Hoot's montage: what the player sees before the party

Every number comes from `SpeechRules` as written plus the contract's helpers (D17). Hoot runs all of it, whatever
quick visit says (§3.1), on one AudiOtron screen for the tones (so the visit's air-ear order is right, E2) and the
SPEECH screen's `run_hidden` for the speech.

| | right | left |
|---|---|---|
| Air (Hoot, 8x, montage) | as the table, in main's order (E1: 1k, 1.5k, 2k, 3k, 4k, 6k, 8k, the 1 kHz retest, 500, 250); the right is the visit's first air ear, so its montage owes the 1 kHz retest (E2) | the same order, no retest owed; 750 Hz only when the measured 500 Hz and 1 kHz differ by 20 dB or more |
| Bone, unmasked (Hoot, 8x, right mastoid), `ClinicRules.BC_REQUIRED` 1k / 2k / 4k / 500 | 20 / 30 / 40 / 15: no air-bone gap over 5 in either ear | (the same oscillator; the better cochlea answers) |
| Masked bone | only at a frequency `ClinicRules.masked_freqs_needed` names (a gap over 10 dB from Hoot's 5 dB wobble; about 3% of runs): the oscillator moves to that ear and the masking phone goes on the other ("A gap? Masked bone settles it: the shhh goes in the left ear.") | |
| PTA | about 22 | about 23 |
| SRT (Hoot, hidden) | 20, good agreement | 25, good agreement |
| WRS level (`wrs_level`) | 55 (60 if the tones wobble up) | 60 |
| Speech noise (`nontest_best_bone`, IA 40) | needed with phones, exactly on the line: 55 - 40 = 15 reaches the left's best (15 at 500 Hz); noise 35 (`wrs_mask_level`), plus the other ear's largest measured air-bone gap (A4: a 5 dB wobble of Hoot's stamps adds 5) | needed: 60 - 40 = 20 >= 15; noise 40 (45 with a 5 dB measured gap on the right, as in the bot's seed) |
| WRS (Hoot, hidden, 25 words; Word list 1 right, Word list 2 left) | 96% (92-100), excellent | 92% (88-96), excellent (88 reads "good") |
| Tones predict at least (`wrs_predicted_min_interp`, A1) | about 79 (PTA 21.7) | about 77 (PTA 23.3) |
| Below predicted, ear difference | no; 4 points: no | no |
| `wrs_summary.referral` | `&""` (no referral) | |

- Hoot's line after the bone: "Bone matches air: no gap. Sensorineural, both ears." when both ears measure
  sensorineural, else "Bone's in. Now his words, in quiet first."
- Before the words: "Now words in quiet, my turn. The rule says noise in the other ear." (or "No noise needed this
  time." when `words_need_noise` finds no ear that needs it). The summary: "Mild high-pitch loss, PTA about {pta}.
  Words in quiet: {r} and {l} percent. {verdict}!", with {verdict} the poorer ear's WRS band title (an 88% list says
  "Good").
- The air-bone check matters before any fitting: with no gap there is no air-bone-gap red flag
  (`CaseRules.RED_FLAGS`), and the loss is sensorineural.

### 2.2 The Party Noise Test

Both ears together unaided, then aided in the sound field (§5.1). Sentence n plays at `SIN_SNRS[n - 1]`.

| | Unaided (phones, both ears) | Programme A: OMNI (speakers) | Programme B: FOCUS (speakers) |
|---|---|---|---|
| Talker level | 70 dB HL (`sin_level(21.7)`), set by the player | **50 dB HL** (`SIN_AIDED_DB`, about 65 dB SPL in the sound field), set by Hoot | 50 dB HL, set by Hoot |
| Party levels, sentences 1-6 | 45, 50, 55, 60, 65, 70 | 25, 30, 35, 40, 45, 50 | 25, 30, 35, 40, 45, 50 |
| Effective SNR loss in the model | 9.0 | 9.0 (omni wins nothing in this much noise) | 9.0 - 4.0 = 5.0 |
| Expected key words per sentence (`sin_expected_words`) | 4.99, 4.92, 4.30, 1.94, 0.31, 0.03 | the same | 5.00, 4.99, 4.87, 3.98, 1.44, 0.20 |
| Expected total / SNR loss | 16.49 / 9.0 dB | 16.49 / 9.0 dB | 20.47 / 5.0 dB |
| A typical list (`snr_loss(total)`) | 16 (46% of lists): 9.5 dB; 17 (38%): 8.5 dB | the same | 20 (45%): 5.5 dB; 21 (40%): 4.5 dB |
| Two lists averaged | 9.0; within 8.0-10.0 in 98.2% of runs | 9.0 | 5.0 |
| Band (unaided only, D21) | **moderate** (99.95%) | none: "aided, sound field" | none: "aided, sound field" |
| Directional benefit (A average - B average) | | | about 4.0 dB; above 2.7 (`SIN_CRIT_DIFF_DB[2]`, two lists each) in 95.0% of runs (exact, from the count distributions) |

- **Where 25.5 comes from** (Spearman-Kärber over the six steps): SNR-50 = 25 (the top step) + 5 / 2 (half a step) -
  total (one key word = 5 dB / 5 words = 1 dB), so 27.5 - total. SNR loss = SNR-50 - `SIN_NORMAL_SNR50_DB` 2 = 25.5 -
  total. Equivalently, SNR loss = key words missed - 4.5: each missed key word adds 1 dB, and a typical listener
  misses about four or five anyway.
- **The level does not change the numbers**: the model's SNR loss does not depend on the talker level, so the aided
  level (D21) only makes the test realistic. The aided bands are not printed because the bands are unaided earphone
  norms; the aided sheets are only compared, A against B.
- **The audiogram's own estimate** (`estimated_snr_loss`: 2.8 right, 3.1 left) is stored on the sheet
  (`estimated_loss`) for tests only. No line or card prints it: it is the game's rough formula, not a real prediction
  (clinical 19).
- **The game's lists are steadier than real ones.** A simulated list's SNR loss has an SD of about 0.77 dB; real
  recorded lists wobble about twice as much, which is where 2.7 / 3.9 dB come from. The lines say "One list is a rough
  guess. Two make it solid." (§15 Q8.)
- **The honest path.** In the 5% of runs where the benefit lands at 2.7 dB or less, Hoot says so (§9), the visit flag
  `benefit_unsure` is set, and the bot accepts it with a positive benefit (contract §9.22).
- Every line and card uses the measured numbers (the player's own marks), never these expectations.


## 3. Beat by beat (about 12 minutes)

Every blocking beat emits `Events.awaiting_input`. "Hoot runs" = Hoot's turn at x8 (not scored). Phases go through
`Events.phase_changed`.

| # | Phase | What happens | Beat(s) | Time |
|---|---|---|---|---|
| 0 | `explainer` {movie, source: "day_start", seen} | **Hoot's party movie: "The Party Problem"** (§4). Before the first play only, Hoot announces it: "New trick today: WORDS IN NOISE. A quick cartoon first, then our next patient!" It plays until it has been seen to its last scene; after that Hoot offers it instead ("Hoot's party movie again? Popcorn's on me!"; the best answer is to skip). A skip gets the "Rewatch it any time" line. | the player's own `explainer` beat; `choice` on replays | 1:15 |
| 1 | `intro` | Marco strolls in, napkin tucked in, and reviews the clinic out loud. The complaint and the stakes (Rosa's dinner on Saturday). Hoot: "Day 5, trainee: speech in noise! Today the party talks back." | dialogue | 0:35 |
| 2 | `history` | Two rounds (§1), Hoot's replies, the red-flag sweep, the hiss lines, the green "No red flags" card. Medal `history`. | `choice` x2 | 1:00 |
| 3 | `otoscopy` | A quick look (`Otoscopy.show_clear`; the card: "Fresh speculum. Marco's RIGHT ear: clear canal, healthy eardrum.", the review's all-days A1): clear canals, healthy eardrums. The napkin gag. Medal `otoscopy` (gold, not a beat). | dialogue | 0:15 |
| 4 | `instructions` | "Party test! Tell Marco what to do:" (§9). A wrong answer is removed and the prompt comes back. Medal `instructions`. | `choice` | 0:30 |
| 5 | `audiometry` (each tone test), then `speech` {ear, srt / wrs} | **Hoot's montage** (§2.1): "Cosy. Like a pantry. Four stars."; Hoot's routine line (`HOOT["routine"]`, the case days' words, the review's all-days A1); tones both ears at 8x, right first, in main's order with the right's 1 kHz retest; unmasked bone at 500-4k; masked bone only where a gap shows; then, off-screen (`run_hidden`), SRTs and words in quiet, right first. One summary line with his own numbers. While the masking movie is unseen, the visit's first masked test (masked bone where a gap shows, else the words in quiet when they need noise) opens with the 12-second recap card and `HOOT["masking_hint"]`, once (the review's all-days A2, as on the case days); the level then joins `MASKING_LEVEL_GROUP`, so the pause menu lists the masking movie. | (AudiOtron, Hoot; `run_hidden`) | 0:50 |
| 6 | `speech` {both, sin, Party list 1, unaided} | PARTY mode, coached. The player sets the talker to 70 dB HL (the dial starts at 50). Hoot plays and scores the practice sentence (the amuse-bouche). The player scores all six sentences. The dining room fills course by course; at Dessert (0 dB) the noise wins. Marco: "The starter was delicious. The main was muddy. Dessert? I tasted only noise." | `speech` | 1:40 |
| 7 | `evidence` {board: bill} | **The bill** (§5.7): the receipt prints the six counts and the formula; "What's the bill?" (numbers only); then the band pointer on the menu's band ruler. PAID. Medal `bill`. | `choice`, `band_pick` | 0:30 |
| 8 | `speech` {both, sin, Party list 2, unaided} | "One list is a rough guess. Two make it solid. Second list!" The player sets the talker unprompted; Hoot then pours courses 1-3 at x8 (quick visit); the player scores 4-6. The receipt reprints both lists and the average: about 9.0 dB, MODERATE. | `speech` | 0:40 |
| 9 | `evidence` {board: plates} | **Two plates** (§5.7): serve a clue to each of Marco's two claims. BOTH TRUE!, then the banner THE AUDIOGRAM ISN'T THE WHOLE STORY. Medal `evidence`. | `plates_serve` x2 | 0:35 |
| 10 | `fitting` | Earphones off, hearing aids on (sparkle), two booth speakers roll in (`clinic.show_soundfield(true)`): TALKER in front, PARTY behind. "Blind tasting! Marco won't know which programme is on, so he can't guess." | dialogue | 0:20 |
| 11 | `speech` {both, sin, Party lists 3-4, omni} | Programme A: Hoot pours courses 1-3 of list 3 (quick visit); the player scores Main, Cheese and Dessert. Marco's aside on the player's first answer: "It's louder. But louder soup is still soup." List 4 is Hoot's at x8. | `speech` | 0:45 |
| 12 | `fitting` {board: pizza} | **The pizza** (omni hears the whole pizza; directional favours the front half and turns the back down). Then the **switch**: "Marco, eyes closed! Trainee, flip the switch to programme B." Then "Compare like with like: same speakers, same level, only the microphones changed." | dialogue, `focus_switch` | 0:25 |
| 13 | `speech` {both, sin, Party lists 5-6, directional} | Programme B, the same split: Hoot pours 1-3 of list 5, the player scores the noisy end (Main comes back about 4 of 5 this time), list 6 is Hoot's. Marco: "Now the voice is the main course, and the noise is just... garnish." | `speech` | 0:45 |
| 14 | `fitting` {board: reveal} | **The reveal card**: Marco guesses ("B! B was the main course."), then the card: A 9.0 dB, B 5.0 dB, "4.0 dB better", "2 lists each: 2.7 dB needed. REAL." Why blind, and (A7) the booth is kinder than a real restaurant. | dialogue | 0:20 |
| 15 | `counselling` {board: seats} | **Seat Marco**: the Trattoria floor plan, four seats; then "Face your guest...", the remote-mic note and the salt shaker. Medal `help`. | `choice` (seats), dialogue | 0:25 |
| 16 | `counselling` {board: dinner} | **Dinner at Trattoria Clatter** (§7.3): Rosa's news over a roaring room; the tray crash behind; "Tiramisu for the whole room!" Marco writes his review. | dialogue | 0:45 |
| 17 | `results` | The Daily Decibel, Day 5: the party golf card, with Marco's review as the subhead (§8.4). | `results_continue` | 0:40 |

Time budget: about 12:00 with the movie, about 11:00 on replays. With quick visit off the player also scores sentences
1-3 of lists 2, 3 and 5 (about +1:40); Hoot still runs the montage and lists 4 and 6 (`hoot_only`).

### 3.1 Who does what

| Task | Who | Why |
|---|---|---|
| Tones, both ears, right first | Hoot, x8 | taught on Days 1-2 |
| Unmasked bone, 500-4k (masked only where a gap appears) | Hoot, x8 | no air-bone gap before any fitting; taught on Day 2 |
| SRT and words in quiet (WRS), both ears, right first | Hoot, off-screen (`run_hidden`) | taught on Days 3-4; today they only prove "fine in quiet" and "his beeps are trustworthy" |
| Setting the talker to 70 dB HL (unaided) | player | the one level skill of the party test (`sin_level`) |
| The practice sentence | Hoot, normal speed | shows the chips and LOCK IN once |
| Party list 1, all six sentences | player, coached | the core skill, start to finish |
| Party list 2: the talker, then sentences 4-6 (1-3 by Hoot with quick visit on) | player | the set-up unprompted (the day's birdie) and the noisy end |
| The bill and the band | player | the arithmetic, once |
| Programme A, list 3: Main, Cheese, Dessert (1-3 by Hoot with quick visit on) | player | the player feels where OMNI fails |
| Programme A, list 4 | Hoot, x8 (`hoot_only`) | the second list for the average |
| Programme B, list 5 (as list 3) and list 6 (Hoot) | player / Hoot | the same split, so A and B are compared like with like |
| Plates, switch, seat | player | the day's thinking |

Quick visit on: the player scores 15 sentences (75 key words). Off: 24 (120). Aided talker levels are always Hoot's
(`level_by_hoot`), and lists 4 and 6 are always Hoot's.

### 3.2 State and flow

- **The HUD steps** ("MARCO POLENTA'S VISIT"): Chat, Peek, Explain, Beeps, Party 1, Bill, Party 2, Plates, A (sunny),
  B (mint), Seat.
- **Visit flags** (`Game.visit`): `movie_watched` (set by `_movie()`, §4.4), `asked_red_flags`, `asked_onset`,
  `instructed`, `instructed_first_try`, `masked_bone`, `bill_tries`, `band_tries`, `plates_slips`, `marco_guess`
  ("B" or "unsure"), `benefit_unsure` and `seat_tries`.
- **Medals**: `history` (Chat), `otoscopy` (gold, not on the paper), `instructions` (Explain: gold first try, silver
  second, bronze more), `bill` (Bill), `evidence` (Case), `help` (Help).
- **Flow functions** in `story/level_marco.gd`, in order: `_movie`, `_intro`, `_history`, `_otoscopy`,
  `_instructions`, `_montage` (tones and bone in the `level_case.gd` pattern, then `_hidden_speech`: the SPEECH screen
  is made there and kept for every party list, one session), `_party_1`, `_bill`, `_party_2`, `_plates`, `_fitting`,
  `_programme(&"A")`, `_pizza_and_switch`, `_programme(&"B")`, `_reveal`, `_close_speech`, `_seat`, `_dinner`,
  `_results`. Off-screen work and the fallback without a SPEECH screen use `session.run_by_textbook` (C23);
  `level_mike.hoot_runs_ear` is not copied.
- **The plans** are `party_plan(n, quick)`, exactly contract §9.21 (Day 5). Data constants: `MARCO_LOST` (Appendix B's
  noise-wins lines), `HOOT` (every Hoot line), `SEATS`, `HEADLINES`, `SUBHEADS`, `MEDAL_BEATS`, `WEATHER`.
- The babble loop is built in `_ready()` (`SpeechBabble.loop()`), before the movie, so the first PRESENT never hitches
  (contract §9.16).

## 4. Hoot's explainer movie: "The Party Problem"

### 4.1 What it teaches, and what it leaves for the day

SNR is as new to players as masking was, so it gets its own movie before the day. Eight scenes, **71 s**, one idea
each. It opens with what the movie answers (Steve's rule, 2026-10-19: every movie first says what it will explain):
why someone who does fine in quiet gets lost at a busy table, and that the answer is SNR loss, which quiet beeps
can't show. Then: one voice in quiet is easy (quiet); a crowd makes the same voice hard (crowd); SNR is the gap
(scale); turning everything up keeps the gap (knob); some ears need a bigger gap, and the extra is SNR loss (gap); the
test's six courses (menu); each missed key word costs about 1 dB, shown for a typical diner (receipt: 25 right,
0.5 dB, NEAR-NORMAL, A7); and why we test the party at all (tonight). The movie never shows Marco's numbers, never
names a band beyond the typical diner's, and never shows the formula's constant, so the bill stays the player's to
work out.

### 4.2 The movie, scene by scene

"Hoot's Movie Matinee: The Party Problem" (`MOVIE.title` "Hoot's party movie", `subtitle` "The Party Problem"). The
lead-in is in rows 0 and 1: the announcement in the clinic, then the marquee that holds while Hoot asks the movie's
question and names its answer.

| # | Scene (`set`) | Visuals (the stage brief) | Caption(s), Hoot | s | The one idea |
|---|---|---|---|---|---|
| 0 | (the clinic, first play only) | The door camera, before the movie starts. A replay instead gets the offer (§4.4), never this line. | Dialogue box: "New trick today: WORDS IN NOISE. A quick cartoon first, then our next patient!" | ~4 | (Steve) What today is for, before the cartoon. |
| 1 | `quiet` | Curtains swish open (0.1-1.2 s) on the marquee HOOT'S MOVIE MATINEE / The Party Problem, "starring a voice and a crowd", a little cafe table with a candle and two speech bubbles beside the title. **The marquee holds 8 s** (`params.card_hold`) while Hoot asks the question and names the answer, with **two question chips** under it ("Why is a busy table so hard?", "How do we test words in noise?", `params.questions`, popping in at 2.0 and 4.6 s). Then the card flips away on a quiet cafe: a window with the moon, a lamp over a small table, two beans with tiramisu. Her big crisp bubble: "Shall we share the tiramisu?" His bubble: a happy tick; a chip: "One voice, no crowd: easy!". | "Hoot's Movie Matinee! Today's mystery: why can someone fine in quiet get lost at a busy table?" / "The answer is SNR LOSS. Quiet beeps can't show it, so we test words in noise." / "In a quiet room, one voice is easy to follow." (at 0.3, 4.4 and 8.4 s) | 14 | (Steve, 2026-10-19: the movie must say what it will explain) What the movie answers; then: in quiet, one talker is easy to follow. |
| 2 | `crowd` | The same cafe fills: six tables pop in, two at a time, each with two grey diners and their grey chatter bubbles (twelve chatter strings of our own: "haha", "clink!", "more bread?", ...), then a waiter weaves across the front with a tray. Her bubble is the same size and says the same thing, but chatter bubbles crowd over it; his face goes puzzled. Chips: "Her voice: the SAME" and "The noise: MORE". The chatter is drawn only, never played. | "Add a crowd. Her voice didn't change. The noise did." | 8 | Background talk (babble) makes the same voice harder to follow. |
| 3 | `scale` | A big kitchen balance. Left pan: one plate, VOICE 70. Right pan: a stack of grey plates, PARTY 45; the beam tips to the voice (the heavier pan sinks), and a gold bracket between the pans reads SNR 25 dB. More plates land on the party side at 1.0, 3.6 and 6.0 s (`scale.at`): 55 (SNR 15), then 65 (SNR 5); the beam levels and the bracket shrinks each time. Then: "Smaller gap: harder to follow". | **Reworded (needs Steve's OK, Q19):** "SNR: how much louder the voice is than the noise. A bigger gap is easier." | 9 | SNR (signal-to-noise ratio) is the gap in dB between the voice and the noise. |
| 4 | `knob` | Hoot cranks a giant volume knob. Beside it, two bars like the SPEECH screen's SNR-O-METER: VOICE (mint) and PARTY (grey), the gold SNR bracket between their tops. Both bars grow 10 dB (voice 70 to 80, party 65 to 75) with drawn loud-lines; the bracket rides up and stays SNR 5 dB: "STILL 5 dB!". Drawn only: nothing gets louder. | "Turn everything up? Both get louder. The gap stays the same." | 8 | Turning everything up keeps the SNR the same. |
| 5 | `gap` | Split screen, the same noisy table on both sides. Left: a diner with typical ears gets half the words at a 2 dB gap (two of his four word tiles, "Try the lemon cake!", crisp, two crumbs). Right: the other diner's tiles all crumble into breadcrumbs at 2 dB; his gap widens to 10 dB and now half are crisp. Between them, a ruler from 2 to 10 marks the extra 8 dB: SNR LOSS. | "Most ears need a small gap. Some need a bigger one. That extra gap is SNR loss." | 9 | SNR loss: how much bigger a gap a listener needs than typical ears, to follow half the words. |
| 6 | `menu` | A restaurant menu unfolds: THE PARTY NOISE TEST, six courses: Starter 25, Soup 20, Fish 15, Main 10, Cheese 5, Dessert 0 (SNR, dB), each with five green peas for its key words. Tiny diners crowd the margins more with every course, and an arrow down the side reads "the party grows". | "The Party Noise Test: six sentences, five key words each. The party grows every time." | 8 | The Party Noise Test: six sentences of five key words, the babble one step louder each time (SNR 25 down to 0). |
| 7 | `receipt` | A till receipt prints for a diner with typical hearing: Starter 5, Soup 5, Fish 5, Main 5, Cheese 4, Dessert 1; KEY WORDS RIGHT 25; the bottom line reads SNR LOSS 0.5 dB, then a stamp: NEAR-NORMAL (A7). Beside it, his plates: the missed peas roll off the Cheese and Dessert plates, each into a little "+1 dB" tag, and a chip: "Most ears miss 4 or 5 anyway" (so five missed words and 0.5 dB agree). | "Every key word missed costs about 1 dB. The receipt adds up the SNR loss." | 8 | Each missed key word adds 1 dB to the SNR loss (a typical listener misses about four or five). |
| 8 | `tonight` | An audiogram card (beeps in a silent booth: "shh") beside the noisy table; a question mark hops between them. Two knocks on a door at the back; it swings open on a silhouette with a tucked-in napkin and a raised fork: TONIGHT. The curtains close: "Places, trainee: a guest!". | "Beeps are tested in silence. Dinner isn't silent. So we test the party too!" | 7 | Tone audiograms are measured in quiet; speech-in-noise testing measures the real complaint. |

Scene totals: 14 + 8 + 9 + 8 + 9 + 8 + 8 + 7 = **71 s** (the design's 65 s plus Steve's 6 s lead-in on scene 1; the
player stretches a scene only if its caption needs longer to type: 42 characters/s plus 1.6 s to read). The longest
caption is 17 words.

**Reduced motion** (the player's setting): cuts and crossfades only. The marquee does not sway and things fade in;
the tables fade in and the crowd's waiter is left out (a frozen waiter hid a table's chatter); the plates and the
beam change in cuts; the word tiles change without crumbling; the menu's rows appear without the unfold; the receipt
prints at once and the peas do not roll; the question mark does not hop and the door cuts open.

**Sounds per scene** (all `Sfx`, at -8 to -16 dB, seconds from the scene start; changed from the design where the
pictures moved):

| Scene | Cues |
|---|---|
| quiet | fanfare 0.2 (-14), whoosh 0.5 (-12), pop 2.0 and pop 4.6 (-10: the two question chips), pop 8.8 (-10: her bubble), chirp 10.2 (-14: his tick) |
| crowd | pops 0.8, 1.5, 2.2 (-12: the tables), whoosh 2.9 (-14: the waiter) |
| scale | dings 1.0, 3.6, 6.0 (-12: each stack of plates) |
| knob | clicks 1.0 and 1.6 (-10), boing 4.2 (-14: "STILL 5 dB!") |
| gap | pop 1.2 (-12), squeak 2.6 (-16: the crumbs), boing 4.4 (-14), ding 5.8 (-12: half crisp at 10 dB) |
| menu | whoosh 0.6 (-12), blips 2.0 and 4.6 (-14) |
| receipt | pen 1.0 (-14), kaching 4.0 (-12), stamp 4.8 (-12: NEAR-NORMAL) |
| tonight | pop 0.4 (-12), two knocks (thunk) 2.6 and 2.9 (-8), door 3.3 (-12), fanfare 5.4 (-16) |

The crowd, the babble and the loud knob are drawn, never played; no babble, murmur, whirr or music plays.

### 4.3 The movie data (`res://story/explainers/movies/party_noise.gd`)

The file replaced S0a's stub and is data only; the shared player plays it (`CONTRACTS.md` §3.4). Its art comes through
the per-movie sets hook: `MOVIE.stage` names `res://story/explainers/stages/party_noise_sets.gd`, which `extends
"res://story/explainers/explainer_sets.gd"` and declares `const SETS: Array[StringName] = [&"quiet", &"crowd",
&"scale", &"knob", &"gap", &"menu", &"receipt", &"tonight"]` with one `_set_<id>()` each. It shipped in two steps
(contract §9.20): the data without the `"stage"` line first, so every scene played as its card, then the sets script
and the `"stage"` line.
- **Card fallback.** Every scene carries card params at the top of `params` (`heading`, `lines`, `icon`, `tint`), so it
  always plays, as a card, whenever its set is not drawn.
- **Set data.** Each set's own data sits under a key named after the set (`params.quiet`, `params.receipt`, ...), never
  under a card key. Beyond the design's keys the sets read `quiet.title` / `starring` / `line`, `crowd.chatter` /
  `line`, `scale.at`, `gap.words` / `crisp`, `menu.title` / `key_words`, `receipt.courses` / `key_words` /
  `band_name`, and `tonight.sign` / `chip`.
- **The lead-in.** `params.card_hold` (8.0) and `params.questions` (the two chips) sit beside the card keys. The stage
  treats a scene with `card_hold` like Day 2's `meet` (no iris; its scene chip waits until the card has gone), and
  `_set_quiet()` draws the marquee and the chips, then runs the cafe on the stage's clock shifted by `card_hold` - 2 s
  (the shape of main's `_set_meet`; no shared file changes).
- `seen_at` is left at its default, the last scene (`tonight` carries the "why test the party" idea).
- A header comment names the facts Steve reviews and says every line, chatter word and course was written fresh for
  the game, never taken from a published speech-in-noise test.

**Art rules** (contract §9.20):
- Each `_set_<id>()` is a pure function of `t` and the scene's params (no tweens, nodes or RNG). It draws through `s`,
  the stage (`s._hoot()`, `s._text()`, `s._panel()`, `s._chip()`, `s._curtains()`, `s.draw_*()`), with the palette as
  `Stage2D.<COLOR>`; `_k()`, `_pop()` and `_ring()` are on the base.
- **The marquee** (scene 1): `s._curtains()` opens on a marquee drawn by `_set_quiet()` from `params.quiet.title`
  ("The Party Problem") under "HOOT'S MOVIE MATINEE". The stage's `_title_card()` (the masking movie's) is not used.
- The facts are the rules' facts, pinned by the movie test: the voice is `SIN_LEVEL_DB` (70) and the scale's gaps are
  `SIN_SNRS`; the menu is `SIN_COURSES` at `SIN_SNRS`; typical ears follow half the words at `SIN_NORMAL_SNR50_DB` (2);
  the typical diner's plates are what `sin_expected_words` gives at a loss of 0.5, 25 key words right, `snr_loss(25)`
  = 0.5, band `sin_band(0.5)` = `&"normal"`, printed as `SIN_BAND_NAMES`: "Near-normal".
- **Checking the art**: the shared dev scene shoots every scene, `dev_explainer.tscn --movie=party_noise
  --at=0.2,0.6,0.95` (and once with `--reduced-motion`), so no preview script of our own is needed (§13).

### 4.4 How the level plays it

`level_marco._movie()` is `level_nora._movie()` with the id `"party_noise"` (contract §9.20):
- **Until it is seen** (`Game.is_movie_seen("party_noise")` is false: it never reached its last scene):
  `_phase(&"explainer", {movie, source: "day_start", seen: false})`, Hoot's announcement (row 0 of §4.2), then the
  movie.
- **Once seen**: Hoot offers it: "Hoot's party movie again? Popcorn's on me!" with ["Roll the film! (about 70 s)",
  "Skip it: I know my SNR."], best answer 1 (skip). The "70" is `Movies.total_s` (71) rounded to 10. There is no
  announcement on a replay.
- **After a skip** at day start: "Skipped! Rewatch it any time: pause menu, "Watch Hoot's party movie"."
- `Game.set_visit_flag("movie_watched", ...)` takes the result's `watched`.
- **Replays.** Day 5's pause menu offers "Watch Hoot's party movie" (its chapter's movie). The title's Options and its
  "Hoot's Movies" list offer every movie, and the case days and walk-ins (`Movies.MASKING_LEVEL_GROUP`) offer every
  replay movie, the Party Problem among them, now that `marco` is in `Game.CHAPTERS`.
- If `Movies.has("party_noise")` is false (a broken registry), the day starts at the intro.

## 5. The Party Noise Test on the SPEECH screen (PARTY mode)

`SpeechScreen.start_test(patient, "both", coached, plan)` with `plan.test = "sin"` loads PARTY mode
(`core/speech/modes/sin_test.gd`, `ui/speech/modes/sp_mode_party.gd`, D1). SRT and WORD modes are untouched (each
test change unregisters the old mode's anchors, H26).

### 5.1 Both ears together, then the sound field (and why)

- **Unaided: both ears together, under earphones**, the talker and the party mixed into both ears (slot `"both"`). A
  party test can be run per ear or with both ears. Per ear (better ear first) is the choice when the ears differ: to
  see each ear's ability, to plan which ear to fit, to catch an asymmetry (Day 4's lesson). Marco's ears match within
  5 dB at every pitch, his words in quiet match within 4 points, and he says both ears are the same. Dinner is a
  two-ear job, so one both-ears score answers his real question, and it needs half the lists (each list can be used
  only once with a patient, or he learns the sentences). With the same mix in both ears there is nothing to cross
  over, so no masking. Better ear first still rules the tones and the word scores.
- **Aided: in the sound field, at a chatting level.** Earphones would cover the hearing aids' microphones, so aided
  tests use speakers. The talker speaker sits in front of Marco and the party speaker behind him: directional
  microphones only show their benefit when the voice and the noise come from different directions. The talker plays
  at 50 dB HL (`SIN_AIDED_DB`, about 65 dB SPL), set by Hoot: a raised 70 would push the aids into compression and
  output limiting. Same speakers, same level and fresh lists of the same kind for both programmes: compare like with
  like. The model ignores any small spatial benefit (§15 Q2).
- **Blind.** Marco is not told which programme is on. Patients who know tend to try harder on the "better" one.


### 5.2 The screen

```
+--------------+--------------------------------------+--------------+
| BOOTH WINDOW | LCD: [BOTH] [PARTY] [PHONES] [UNAIDED]| status       |
| Marco, napkin|  TALKER 70 dB HL   PARTY 55   SNR 15  | combo  II    |
|              |  Party list 1 . sentence 3 of 6 . Fish|              |
+--------------+---------------------------+----------+--------------+
| HIS ANSWER   | THE SIX COURSES            | SNR-O-   | Hoot's perch |
| "A loud      |  dining room strip: diners | METER    |              |
|  trumpet...  |  arrive course by course   | TALKER   |              |
|  woke the... |  (o)(o)(o)( )( )( ) plates | PARTY    |              |
|  bowl...     |  25  20  15  10  5   0     | [gap 15] |              |
|  sheet?"     |  running total 10          |          +--------------+
|              |                            |          | TICK WHAT HE |
+--------------+---------------------------+----------+ SAID . LITTLE|
| SENTENCE CARD: A [1 LOUD] [2 TRUMPET] [3 WOKE] the   | WORDS . LOCK |
|  [4 WHOLE] [5 STREET].   -> got it . <- missed . 3 / 5 so far     |
+---------------------------------------------------------------------+
| LEVEL + SENTENCE        | KEY WORDS                 | BILL         |
| [SOFTER][PRESENT][LOUDER]| [MISSED <-][GOT IT ->][ALL GOT G] | [LOCK IN] |
+---------------------------------------------------------------------+
```

- **LCD** (`SpLcd` view keys, contract §9.18.1): the ear chip BOTH (ink, never an ear colour), the test chip PARTY,
  the transducer chip (PHONES, INSERTS with the Day 2 upgrade, or SPEAKERS), the condition chip (UNAIDED; on aided
  lists "PROGRAMME A" / "PROGRAMME B" while the tasting is blind; "A: OMNI" / "B: FOCUS" only with the plan key
  `revealed`, which the level never sets because the reveal comes after the last list), the TALKER level in big digits
  (the big caption is always "TALKER"; "set by Hoot" sits on the start chip instead, "AIDED: 50 dB, set by Hoot", so
  it never collides with the TALK knob), the PARTY level and the SNR, and the info line "Party list 1 . sentence 3 of
  6 . Fish". Where the NOISE box was, a dim note reads "NO MASKING / same mix in / both ears" ("speakers reach / both
  ears" in the sound field): the LCD's new optional view key `noise_note`.
- **The six courses** (`SpCourses`): six plates labelled with their SNR and course (Starter 25, Soup 20, Fish 15, Main
  10, Cheese 5, Dessert 0). A plate fills with five peas as its sentence is locked in (green = ticked, grey = missed;
  Hoot's dimmer, with his H). Above the plates, a dining-room strip fills with diners as the SNR falls (2, 4, 7, 11,
  16 and 24 diners) with clatter words ("clink", "haha", "more bread?"). A running total sits under the plates. The
  SNR-loss line stays blank on list 1 ("SNR loss: ____", `hide_loss`) until the bill. Aided lists show their loss and
  "aided, sound field", never a band.
- **The SNR-O-METER** (`SpSnrMeter`, in the agreement meter's slot): a fixed mint TALKER bar and a grey PARTY bar that
  rises one step per sentence, and a bracket between them: "SNR 25 dB" down to "0 dB!". At 0 the bars meet.
- **The sentence card** (`SpSentenceCard`): the sentence the next PRESENT will say, with its five key words as chunky
  chips numbered 1-5 (at least 96 x 56 px), the little words in plain small text between them. As built it spans the
  bottom of the left and middle columns (not only the word card's slot), sized from the list's longest sentence, at
  most two rows of chips; the answer bubble grows down the left column, and the courses and the meter share the
  middle above it. A test checks that no PARTY widget overlaps another at 1280x720 and 1920x1080.
- **The answer bubble** (`SpBubble`): what Marco said, up to two lines. An ellipsis shows a dropped word. Before the
  first answer it reads "(waiting for a sentence)" (the bubble's new `idle_text`; the SRT's "(waiting for a word)"
  comes back with the SRT). The mock-up's "bowl" is a sound-alike miss for "whole"; homophones never appear as misses.
- **The dance card**: TICK WHAT HE SAID / LITTLE WORDS: no score / LOCK IN, then next.
- **Deck**: LEVEL + SENTENCE (SOFTER, PRESENT, LOUDER), KEY WORDS (MISSED, GOT IT, ALL GOT), BILL (LOCK IN). The
  ladder, the agreement meter, the word card, the LCD's THIS LEVEL line, MASK and STORE hide. The keys pill, the
  key-style pill and the pause "II" stay.
- **Aided booth window** (`SpPartyBooth`): the two speakers, voice in front and party behind. With FOCUS (only once
  `revealed`), the front half of the room is drawn bright and the back half dimmed, never removed.
- During a Hoot turn on a party list the perch reads "Hoot is testing: watch the plates!".

### 5.3 The key-word scoring interaction (the core skill)

One sentence, start to finish (contract §9.18.2):

1. **PRESENT** (Space, or click). The card glows NOW SAYING; the party starts, then the talker `BABBLE_LEAD_S` (0.6 s)
   later (both quiet, both capped); the PARTY bar is already at this sentence's level. Level keys lock after the
   first presentation ("The talker stays at one level for the whole list."), and from the start on aided lists
   ("Aided tests go at a chatting level: 50. The aids add their own boost.").
2. Thinking dots, then **Marco's answer** pops into the bubble. Only now do the chips wake up; chip 1 wears a sunny
   ring (the focus) with its key hints "-> got it / <- missed". A mark before the answer is refused.
3. **Score each key word** against what he SAID:
   - The walk: **Right** (or + / =) = he got the focus word: the chip turns mint with a tick and the focus moves on.
     **Left** (or -) = he missed it: coral outline, a cross, the word struck through; the focus moves on (to the next
     blank chip, wrapping). Same keys as Days 3 and 4.
   - The jump: **1-5** flip that chip (blank or missed -> got, got -> missed) and move the focus there, to fix a slip.
   - **G** or **ALL GOT** ticks all five (for the easy courses).
   - Mouse: **click a chip** to flip it (blank -> got -> missed -> got); right-click marks it missed.
   - The tally under the card counts as you go: "3 / 5 so far".
4. **LOCK IN** ({key:store}, or click). Blank chips count as missed (the paper way: circle what he got) and flip to
   crosses, so the player sees exactly what was billed. The count drops onto that course's plate; the missed words
   ride off on a passing waiter's tray ("sent back to the kitchen"; reduced motion: they just grey out). Nothing is
   scored before LOCK IN, and nothing can be changed after it. `Events.party_sentence_locked` follows.
5. Space again plays the next sentence. Before LOCK IN it is refused, once a list, with the tip "Lock in that sentence
   first: {key:store}. Then play the next one." and a wiggle of LOCK IN.

After sentence 6, `Events.party_list_done` fires, the total lands on the courses ("List done: {total} key words. SNR
loss {loss} dB.", or "List done: {total} key words." while the loss is hidden), then the list completes.

**Scoring rules** (what counts as "he got it"): the key word itself, said as written. A different word, a rhyme, a
plural or a tense change ("streets" for "street", "drop" for "dropped") is a miss, and so is any other changed ending
("smell" for "smelly", "loud" for "loudly": `SpeechRules.is_trap`). A missing key word is a miss. The little words
never count either way: "A loud trumpet woke up the whole street" scores 5. Upper / lower case and punctuation never
matter.

**Feedback.** At LOCK IN every chip is checked against what Marco said. Each key word judged right is a clean check
(`speech_textbook`, combo +1), and all five right adds `sin_lock_ok`; each one judged wrong is a `misscored` error:
its chip flashes, and Hoot names the first wrong chip of that LOCK IN (`MISSCORED_SIN`, §9; the others flash only). A
slip's line replaces an on-screen little-words or zero-gap tip. A list (or the player's part of one) with no slips
earns a **Chef's kiss** callout; a whole programme with no slips earns Marco's three forks on the golf card.

**Hoot's turn** (x8): the same controls through `recommended_action()`; his chips tick themselves in a quick ripple,
he locks in, the plate fills dim. `SpModeParty` keeps the murmur and the babble silent during his x8 turns (an eighth
of a sentence would only be a click); his practice at speed 1 plays them. The lamps still light.

**Asides and moments inside a list** (D28). None of them blocks the beat loop. Each is a `bubble.aside` line (Marco)
or a non-blocking coach tip (Hoot), and each shows once per visit:

| Trigger | Who | Line |
|---|---|---|
| the practice sentence is locked (`practice_done`) | Marco, aside | "An amuse-bouche! A little taste before the meal." |
| the first answer that swaps a little word (`little_words`) | Hoot, tip | "Little words don't count, either way. Only the five key words." |
| the idle point before sentence 4 of Party list 1 (the Main course) | Hoot, coach | "Ten dB gap. Most people still get everything here. Watch Marco." (`{name}`) |
| the first sentence at SNR 0 (`noise_won`) | Hoot, tip | "Zero gap: the party is as loud as the talker. Score what he said." |
| a count-0 answer under 0.25 expected (half the time) | Marco, the answer itself | one of `MARCO_LOST` (Appendix B), in the bubble, not an aside |
| the player's first answer on a programme A list (`party_aside`) | Marco, aside | "It's louder. But louder soup is still soup." |
| Party list 1 (the coached list) just after its intro, or MASK pressed (refused); once per visit (`sin_no_mask`) | Hoot, tip | "Both ears hear the same mix, so there's nothing to mask." |

Everything else Marco says (the review, the booth's "Cosy. Like a pantry. Four stars.", the bill, "Now the voice is
the main course..." after programme B, the guess) is story dialogue between lists, never inside one.

### 5.4 Coaching on Party list 1 (sticky tips with ghost hands)

1. The screen's opening line (the plan's `intro`): "Party time! Both ears together, like a real dinner. His ears
   match." The LCD's NO MASKING note shows, and just after the intro Hoot adds "Both ears hear the same mix, so
   there's nothing to mask." (`sin_no_mask`, once per visit; later only MASK would ask, and it is already said).
2. "Set the talker to 70 dB HL: {key:louder}. The party follows by itself." (a ghost hand on LOUDER; the dial starts
   at 50). The coach sets the level BEFORE the practice, so Hoot plays the practice at the player's level.
3. "A practice sentence first: {key:present_tone}. I'll score it; you watch the chips." Hoot plays it at normal speed,
   ticks the chips one by one, locks in. Marco: "An amuse-bouche! A little taste before the meal." Not scored, not on
   a plate.
4. "Your turn. {key:present_tone} plays the first sentence." (PRESENT)
5. While the answer comes: "Listen... what does he say back?" (Day 3's line); then on the first answer: "Tick the key
   words he got. Little words like 'the' never count." (chip 1)
6. "{key:speech_correct} if he got it, {key:speech_incorrect} if he missed it. Or click the chips." (the hand follows
   the focus). When the last input was a mouse click, instead: "Click each key word he got, then LOCK IN. Unticked
   words count as missed."
7. After five marks: "Happy with the ticks? Lock it in: {key:store}." (LOCK IN). A chip that disagrees with what he
   said gets "Check chip 3 against what he SAID: {key:party_word_3} flips it."
8. From sentence 2 on, only error tips and two moments: the Main course ("Ten dB gap. Most people still get
   everything here. Watch Marco.") and Dessert (the `noise_won` tip).

A coached list never earns the tee bonus. `SinTest` also takes `act(&"prompt")` for a set-up hint shown before
sentence 1 (it clears `unprompted`), but Day 5's screen never calls it: list 2's intro below names no level, so it
does not count as a hint. On list 2 (solo) the screen says only "Set the talker, then I'll pour the easy courses. You take the noisy
end." (quick visit) and starts Hoot's turn at the player's first PRESENT (`level_first`).

### 5.5 Material: Party lists 1-6 and the practice sentence

`core/speech/material/party_practice.json` ("Practice sentence") and `party_1.json` to `party_6.json` ("Party list 1"
to "Party list 6"), contract §9.11.2: kind `sentence`, `original: true`, six sentences each, in a fixed order
(sentence n plays at `SIN_SNRS[n - 1]`; never shuffled). Every sentence, key word and mishear was **written fresh for
Booth Camp** (Appendix A):
- everyday, low-context sentences of 6-9 words with exactly five key words, no key word repeated within a list, mostly
  not about food (so the restaurant theme doesn't help him guess);
- **no two key words of a sentence form an idiom, a compound or a fixed phrase** ("pass the salt", "picnic basket",
  "birthday presents", "caught the ball"), and no sentence is a stock phrase. Borderline pairings are listed for Steve
  (§15 Q18);
- no mishear equals its key word or is a homophone of it ("hole" is never a miss for "whole"; "meat" is never one for
  "meet").

```json
{"id": "p1_3", "text": "A loud trumpet woke the whole street.", "key_words": ["loud", "trumpet", "woke", "whole", "street"],
 "mishears": [["cloud"], ["crumpet"], ["spoke", "walk"], ["bowl", "goal"], ["sheet", "streets"]]}
```

Use: unaided lists 1-2, programme A lists 3-4, programme B lists 5-6; each list once per visit (a reused list is
refused, `sin_list_reused`). Recordings, when they exist: `assets/speech/party_<n>/<item_id>.wav`; the babble at
`assets/speech/babble/babble.wav` (`docs/SPEECH.md` §7).

**Originality.** None of the lists copies or paraphrases a published sentence test: no sentence, list, order, key-word
set or recording comes from HINT, BKB, IEEE/Harvard, QuickSIN, WIN, BKB-SIN, SPIN or AzBio. Every list's `note` says
so and names those tests. The repo never holds a published test's sentences to compare with, so the originality
guard (`core/tests/test_speech_sin.gd`, `test_party_material_is_our_own` and `test_party_notes_say_written_fresh`)
checks only our own material:
- every list's note says "written fresh for Booth Camp" and names the eight tests it must not copy;
- no sentence repeats within or across the lists (37 different sentences), and no two sentences share more than two
  key words;
- no key word appears twice in a list; nothing is its own mishear, a mishear appears once in its group, and each
  mishear is one word;
- our own homophone table: no mishear is a homophone of its key word, and no list holds a homophone of one of its key
  words anywhere;
- our own banned words (a diagnosis, anything scary or violent, rude words, alcohol) appear in no sentence and no
  mishear;
- at most one sentence per list has a food key word;
- no sentence holds one of §5.5's own example phrases ("pass the salt", "picnic basket", ...).
`test_party_lists_teach_traps` adds that every list offers at least 10 plural or tense traps and 25 sound-alikes. The
draft's "The kitchen clock..." was replaced because it might echo a published opening (Appendix A).

### 5.6 How Marco answers (`SinModel`, contract §9.12.2)

- `condition` (set by the session): `&"unaided"`, `&"omni"` or `&"directional"`. Effective SNR loss = `snr_loss`
  (9.0), minus `directional_benefit` (4.0) under `&"directional"`, never below 0. OMNI wins nothing.
- **How many**: `expected = SpeechRules.sin_expected_words(snr, loss)`, then `count = sin_count(expected, randf())`
  (dithered rounding: never more than one from the expected number, and exactly right on average).
- **Which ones**: misses are drawn by weight, so the words his loss steals go first: weight = 1 + the number of the
  word's key sounds (s, f, th, t, k, sh, ch, z, v, p, from its letters, or the item's `key_sounds`) whose cue sits
  within 15 dB of his true threshold at the talker level, capped at 3 more. "Six" and "socks" go before "moon". For
  the both-ears slot the thresholds are the better ear's at each frequency.
- **What he says**: the sentence frame with each heard key word as written; each missed one becomes a mishear from the
  item (55%, the trap 1 time in 5 when the group has one), a filler ("something", "mm") (30%), or is dropped with an
  ellipsis (15%). One answer in five swaps a little word ("the" for "a") to teach that little words don't count. "a" /
  "an" agree with a changed next word ("An angry bear..."); fillers are lowercase except at the start of a sentence.
- **When the noise wins**: count 0 with `expected` under 0.25 gives one of `MARCO_LOST` half the time (kind `&"lost"`,
  all five missed), never the same line twice in a row.
- The answer also carries `said_kinds` (heard / mishear / trap / filler / drop per key word), which picks the
  `misscored` line. What depends only on the sentence is cached by the item's hash, so 2000 seeded visits run in the
  tests in seconds.

### 5.7 The bill and the two plates (`story/games/marco_board.gd`)

**The bill** (after list 1). A till receipt prints on the board with a ka-ching (at once with reduced motion). The
numbers are the player's own locked-in counts, and the formula is printed but not filled in. The receipt is drawn,
never a Label, so the bill's choice is the only "<n> dB" text the mouse bot can match:

```
       TRATTORIA BOOTH CAMP
      TABLE 5 . PARTY LIST 1
Starter (25 dB) ......... 5
Soup (20 dB) ............ 5
Fish (15 dB) ............ 4
Main (10 dB) ............ 2
Cheese (5 dB) ........... 0
Dessert (0 dB) .......... 0
- - - - - - - - - - - - - - -
KEY WORDS RIGHT ........ 16
 SNR LOSS = 25.5 - KEY WORDS RIGHT
```

Beside it, the menu's **band ruler**: four band buttons, each with its name, its span and its remedy, in our own words
(`SIN_BAND_NAMES`, `SIN_REMEDIES`, D22):

```
NEAR-NORMAL        MILD                      MODERATE              SEVERE
0-3 dB             3-7 dB                    7-15 dB               over 15 dB
good habits        if aids: standard settings + directional mics  + a remote mic
```

1. **"What's the bill?"** (a stock `choice`, numbers only; the three answers rotate by the total, so the right one
   moves): "{loss} dB" (25.5 - total), "{total} dB" (the key words), "{added} dB" (25.5 + total). For a typical list:
   9.5 dB / 16 dB / 41.5 dB.
   - right: "Every key word he missed adds 1 dB. Most ears miss about four or five anyway."
   - the total: "That's the key words, not the loss. Subtract them from 25.5."
   - added: "Subtract, don't add! Fewer words right means a bigger SNR loss."
   When the band is moderate or severe, Marco then: "{loss} dB! For a critic, that's a terrible review."
2. **The band** (`band_pick`): "{loss} dB of SNR loss. Point to its band on the ruler." A pointer on the ruler: Left /
   Right move it and Space / Enter confirm, or the player clicks a band. Info `{loss, bands: [normal, mild, moderate,
   severe], pointer, best, mouse: {click: "band_<best>"}}`; the solver moves the pointer and confirms. A wrong band
   greys out (the pointer skips it) with the board caption "Find {loss} on the ruler. Which band holds it?" The bands' upper bounds are
   inclusive (`sin_band`: 7.0 is mild, 7.5 moderate).
3. The receipt prints "{BAND} SNR LOSS" and PAID stamps it. Then the band's line (the menu now makes a prediction the
   fitting will test):
   - moderate: "Moderate: the menu says directional mics. Let's prove it in the booth."
   - near-normal: "Near-normal: good habits first. Let's still see what the aids do." (A7)
   - mild: "Mild: if aids, standard settings. Let's still see what the mics do."
   - severe: "Severe: the menu says a remote mic. Let's first see what the mics do."
   Marco: "So my ears need the voice served... a little hotter than everyone else's."
4. After list 2 the receipt reprints both lists (key words right and SNR loss each) and "AVERAGE OF 2 LISTS 9.0 dB",
   with no question. Hoot: "Average of two lists: {avg} dB. {band} SNR loss." Then: "Real clinics use normed tests
   built like this. Our lists are for practice."
- The ruler's remedies say which technology an SNR loss points to; whether someone needs hearing aids at all is the
  audiogram's and the complaint's question, not the SNR loss's.
- **Medal `bill`**: gold = the bill and the band both first try; silver = one slip; bronze = more.

**The two plates.** "Marco says two things. Serve each clue to the claim it proves." His two claims sit on two empty
plates: "In quiet, I hear perfectly." and "At a busy table, words turn to soup." Four clue cards, all the same colour
until hovered (colour must not give the answer away), each headed by where it comes from, with this visit's numbers.
The replies are board captions:

| Card | Goes on | Reply |
|---|---|---|
| WORD LISTS: "Words in quiet: {r}% and {l}%" | the quiet plate (best) | "{band} words in quiet. Claim one: true!" (the WRS band title of his poorer ear) |
| AUDIOGRAM: "PTA about {pta}: near-normal beeps" | the quiet plate (accepted, silver) | "True, near-normal beeps. Words in quiet prove it even better." |
| PARTY TEST: "Party test: SNR loss {avg} dB" | the noisy plate | "{band} SNR loss. Claim two: also true!" |
| OTOSCOPE: "Canals clear, eardrums healthy" | neither | "True, but it doesn't prove either claim. Try another card." |
| a fitting card on the other plate | | "True, but that card proves the other claim. Try the other plate." (a slip) |

- Beat `plates_serve`, emitted once per plate (quiet, then noisy): info `{plate, cards, best, mouse: {drag:
  [clue_<best>, plate_<plate>]}}`. Keys **1-4** serve that card onto the glowing plate; or drag a card onto a plate,
  or click a card then the plate. The solver serves the best card.
- When both plates are full, BOTH TRUE! stamps across them (a screen shake unless reduced motion), then the banner THE
  AUDIOGRAM ISN'T THE WHOLE STORY. Hoot (A7): "His audiogram can't tell us how he copes in noise. Measured: {avg}
  dB." Then: "His SRTs agree with his beeps. This noise trouble is real, and very common."
- **Medal `evidence` (Case)**: gold = the two best cards with no slips; silver = one slip or the PTA card; bronze =
  more.
- Anchors `plate_quiet`, `plate_noisy`, `clue_words_quiet`, `clue_pta`, `clue_snr_loss`, `clue_canals`, and the
  ruler's `band_normal`, `band_mild`, `band_moderate`, `band_severe`.

## 6. The fitting: a blind tasting

1. Hoot: "Hearing aids on. We test them with speakers: voice in front, party behind." Earphones off,
   `clinic.put_on_hearing_aids()` (the sparkle from Day 1), `clinic.show_soundfield(true)` (two booth speakers on
   stands roll in: TALKER in front of him, a little to the side so the booth window still shows his face, PARTY
   behind). The aids are fitted on vented domes.
2. "Blind tasting! Marco won't know which programme is on, so he can't guess." Marco: "A blind tasting. My favourite
   kind." The LCD condition chip reads PROGRAMME A.
3. **Programme A** (OMNI, list 3, plan `condition: "omni", programme: "A"`): the screen's opening line "Programme A,
   in the sound field. Hoot sets the talker at a chatting level." The start chip reads "AIDED: 50 dB, set by Hoot";
   a level key gets "Aided tests go at a chatting level: 50. The aids add their own boost." (`sin_aided_level`).
   With quick visit on, Hoot pours courses 1-3 at x8 ("I'll pour the easy courses. You take the noisy end."); the
   player scores Main, Cheese and Dessert (Main comes back about 2 of 5). List 4 is Hoot's at x8 (`hoot_only`, "My
   list, at top speed: two lists make it solid."). On the player's first answer of list 3, Marco's aside (§5.3):
   "It's louder. But louder soup is still soup."
4. **The pizza** (board, the next dialogue click moves on): a top-down Marco between the speakers. A whole round pizza
   appears around his head. Hoot: "Omni hears the whole pizza. Directional favours the front half and turns the back
   down." The front half is drawn bright and the back half dimmed, never removed (labelled FRONT and BACK). Marco:
   "The front half, facing my guest. The back half... a little less." Reduced motion: two still frames.
5. **The switch** (`focus_switch`): "Marco, eyes closed! Trainee, flip the switch to programme B." A chunky two-way
   switch on a cartoon aid remote, A / B. Info `{mouse: {click: "party_focus_switch"}}`; Space / Enter or a click;
   the solver flips it. Marco closes his eyes (and, of course, keeps the napkin). Then: "Compare like with like: same
   speakers, same level, only the microphones changed."
6. **Programme B** (FOCUS, list 5, `condition: "directional", programme: "B", compare_to: "aided_omni"`): "Programme
   B, same speakers, same level. Only the microphones change." The same split as list 3; the player scores the noisy
   end (Main about 4 of 5 now, with their own hands). List 6 is Hoot's. Marco: "Now the voice is the main course, and
   the noise is just... garnish."
7. **The reveal card** (board). First Marco guesses:
   - benefit real: "B! B was the main course."
   - benefit too small to call: "A... or B? Both tasted rather similar."
   Then the card, THE REVEAL: two columns, PROGRAMME A and PROGRAMME B, which a moment later are named "A: OMNI" and
   "B: FOCUS", each with its two list totals (a star on a list Hoot
   scored any of) and the average SNR loss ("aided, sound field"; no band); a big arrow between them, "4.0 dB better";
   under it, "2 lists each: 2.7 dB needed. REAL." (or "Could be luck."). Hoot: "Programme B was FOCUS: {benefit} dB
   better, two lists each. Real, not luck." Or, when 2.7 dB or less: "Programme B was FOCUS: {benefit} dB better.
   Under {crit}, that could be luck." plus "In clinic, run another list each before you promise anything." Then:
   "Patients who know try harder on the 'better' one. Blind keeps it fair." and (A7) "The booth is kinder than a real
   restaurant. We'll check how the aids do at your table."
- The SPEECH screen's own `sin_benefit` tip says the same result at the end of list 6, with a third line for a benefit
  of 0 or less: "Programme B was FOCUS: no better this time. Run another list each."

## 7. The counselling finale

### 7.1 Seat Marco

A cream floor plan of Trattoria Clatter: the bar, the kitchen's swing doors, a music speaker on the wall, tables, and
Marco's guest (a heart-shaped "guest" marker). Four seats glow; each is a flat Button whose Label starts with the
option text, so the stock `choice` beat and the mouse bot handle it (`story/games/marco_seats.gd`; the choice keys or
a click). Fixed order (it is a map). Prompt: "Where should Marco sit? His mics favour the front."

| Seat | What happens | Hoot |
|---|---|---|
| Next to the kitchen doors | The doors swing and a tray crashes beside him: CLANG. | "Kitchen doors swing and clatter right beside him. Try a quieter spot." |
| Right under the music speaker | The speaker thumps "UNTZ UNTZ" over his head. | "Right under the music. The mics can't escape that. Try again." |
| Corner booth, facing the room | His front half points at the whole room; his guest is beside the noise. | "Noise in front is what the mics listen to! Turn him around." |
| **Corner booth, back to the room** | His front half points at his guest; the room is behind him. | "Back to the room, facing his guest, light on her face. Perfect!" |

The two corner booths are the lesson: the same seat, turned around. **Medal `help`**: gold = the right seat first
try; silver = second; bronze = more.

### 7.2 The honest notes

Two lines in the room, the rest on the paper (§8.4):
- "Face your guest. Good light on faces. Quieter times. Tell the host."
- "If noise ever beats the aids, a remote mic on his guest can help." Marco: "A little microphone for my guest? Like a
  salt shaker for words!"
- On the paper: "Booths and corners beat the middle of the room. Ask when you book.", "Real fittings are checked with
  a tiny mic in the ear, then fine-tuned over weeks." and "Loud nights? Filtered earplugs keep the music and spare the
  ears."

### 7.3 The payoff: dinner at Trattoria Clatter (`story/games/marco_dinner.gd`)

A 2D diorama, drawn in code, captioned "Saturday, 9 pm": the full dining room, the SNR-O-Meter pinned at "loud",
Marco in the corner booth with his back to the room and his daughter **Rosa** (28, curly dark hair, a denim jacket, a
new sparkly ring) across from him, the bright front half of his pizza on her. Grey chatter bubbles everywhere; hers
stays crisp.

1. Rosa: "Papa, I have news. Luca proposed. We're getting married!"
2. Marco: "Married? MARRIED! I heard every word!" The room applauds; confetti (reduced motion: none).
3. A waiter drops a tray behind him: CRASH. Marco, smiling: "And THAT I heard behind me. Just a little. Perfect."
4. Hoot (to the player): "Directional mics turn noise behind him down, not off. Honest expectations matter."
5. Marco: "Tiramisu for the whole room! ...Put it on the owl's bill." Hoot: "...I'll allow it."
6. Marco writes in his notebook; the page reads "BOOTH CAMP. Service: precise. Owl: wise, slightly smug." It turns
   into his review on the Daily Decibel. Marco: "Booth Camp. Read my review tomorrow. I'm booking the nine o'clock
   table." Hoot: "That's the job: measure the party, then fix the party. Lovely work, trainee!"


## 8. Scoring, par, golf and the Daily Decibel

### 8.1 Results

`speech.sin` (contract §9.15.2) holds one sheet per slot: `"both"` (unaided), `"aided_omni"` and
`"aided_directional"`, each with its two lists. Hoot's montage adds `speech.srt.right` / `.left` and `speech.wrs.right`
/ `.left`, all `by_hoot` (units 0). `speech.sin_summary` holds the unaided loss, band, band name and remedy, both
aided losses, the benefit, the critical difference, `real_change`, `benefit_unsure` and the lists used in play order.

- The SNR loss on a sheet is computed from the marks the player locked in (Hoot's sentences use his truthful marks):
  the clinic writes down what the clinician scored. `heard` and `true_count` are truth, for checks and the reveal
  only; `state()` never shows them.
- Aided sheets carry `band: &""`, `band_name: ""`, `remedy: ""` and the label "aided, sound field" (D21).
- The FOCUS sheet gets `benefit_db`, `compared_to`, `compared_lists`, `crit_diff_db` and `real_change` as soon as the
  OMNI sheet has a list (with the one-list critical difference until both have two); the `sin_benefit` line waits for
  two lists each.
- The audiogram's own estimate (`estimated_loss`, about 2.8) is stored for the tests only; no line or card prints it.

### 8.2 Accuracy, technique, efficiency, units

- **Accuracy**: the share of the player's key-word marks that match what Marco said.
- **Technique**: every judged key word is a check; the talker level is a check on player-set lists, judged at the
  player's FIRST SCORED sentence (Hoot may have played the practice, or the first courses, at the level the player
  set): `sin_good_level` at the target, `sin_level` off it; a clean LOCK IN adds `sin_lock_ok`. Errors break the
  combo. The level still locks at the first presentation, practice included.
- **Efficiency**: 1.0 on fixed lists (sheet `strokes` = `par` = the player's sentences, D3).
- **Units**: `units` = the lists with player sentences on the slot (Hoot-only lists 0); each unit weighs
  `SHEET_WEIGHT` 3 in `merge_results`.
- **Points**: `speech_textbook` 10 per key word (times the combo multiplier), `sin_good_level` 10, `sin_lock_ok` 20,
  Chef's kiss 100 per clean list (or clean player part of a list, even when Hoot locks its last sentence), golf par
  50. An all-Hoot list pays nothing.

### 8.3 Party golf (one rule on both speech days, D19)

Each player list is a hole. `golf_par` = the player's sentences; every misscored key word is a slip ("into the
soup"); the **tee bonus** (2) needs a solo list whose talker the player set unprompted, at the textbook level, on a list
that is not coached (`act(&"prompt")` would also clear it; Day 5's screen never calls it); `golf_strokes = golf_par + slips - tee_bonus`, through `fair_golf`.
- **Party list 2 is the day's birdie** (the player sets 70 alone, then scores cleanly).
- **List 1 is coached, and lists 3 and 5 have the level set by Hoot, so they top out at par.** One slip is still par;
  two or three are a bogey; four or five a double bogey. There are no eagles.
- **Marco's forks** per programme (`sin_forks`): three forks = no slips, two = one slip, one = two or three, "sent
  back" = four or more; "Hoot's" when he scored it all.

### 8.4 The Daily Decibel, Day 5

`story/daily_decibel.gd` is not edited for Day 5 (D8). `level_marco.gd` always sets `headlines`, `subheads`,
`medal_beats`, `weather` and `sports_script` in the summary. Marco's review is the subhead (no extra box, so the
WANTED panel still fits at 720p; a test checks the paper fits the window).

| Grade | Headline | Subhead (Marco's review) |
|---|---|---|
| S | TRAINEE SERVES A FIVE-STAR PARTY TEST; CRITIC LICKS PLATE | Five forks. "Precise, kind, and the owl knows his soup." M. Polenta, Table Talk. |
| A | FOOD CRITIC HEARS "MARRIED" OVER A FULL DINING ROOM | Four forks. "Every key word plated with care. The coffee: still two stars." M. Polenta |
| B | PARTY TEST SERVED WARM; A FEW KEY WORDS UNDERCOOKED | Three forks. "Solid service, a few key words undercooked. I will return." M. Polenta |
| C | SOME KEY WORDS SENT BACK TO THE KITCHEN, CONFIRMS OWL | Two forks. "Some words came back to the wrong table. Promising." M. Polenta |
| Do-over | MARCO BOOKS A TABLE FOR TOMORROW; BRING YOUR SCORING FORK | One fork, but a hopeful one. "The owl was charming. Book me again." M. Polenta |

- **Weather**: "Weather: rising babble, clearing with directional mics".
- **Medal row**: Chat (`history`), Explain (`instructions`), Bill (`bill`), Case (`evidence`), Help (`help`).
- **Column 2: SPORTS: THE PARTY GOLF CARD** (`sports_script = "res://story/papers/paper_party_golf.gd"`). Five
  columns (Condition, Lists, SNR loss, Band, Golf · forks), one row per condition tested, then the lines:

```
Condition            Lists     SNR loss   Band        Golf · forks
UNAIDED, phones      15  16*   10.0 dB    MODERATE    par · birdie · 3 forks
A: OMNI, speakers    17* 16*   9.0 dB     (aided)     par · 3 forks
B: FOCUS, speakers   19* 21*   5.5 dB     (aided)     par · 3 forks
SNR loss = 25.5 - key words right, two lists averaged.  * Hoot scored some or all of that list.
Directional benefit 3.5 dB (2.7 needed: real).
The booth is kinder than a real restaurant. We'll check how the aids do at your table.
Booths and corners beat the middle of the room. Ask when you book.
Real fittings are checked with a tiny mic in the ear, then fine-tuned over weeks.
Loud nights? Filtered earplugs keep the music and spare the ears.
Your key words: 75 · Scored as said: 75 · Best combo: n
HOOT SAYS: The audiogram tells you about quiet. The party test tells you about life.
```

- Every number is filled from the visit; the example has the totals of the bot's keyboard run, scored cleanly (quick visit on: Hoot pours the first
  courses of lists 2, 3 and 5, so they are starred, and lists 4 and 6 are his). When the benefit is not real, the line
  reads "Directional benefit {b} dB (2.7 needed: run another list each)." The UNAIDED row names the transducer
  (phones or inserts).
- No "beeps" or "spondees" text appears on Day 5's paper (a test, and the bot reads the paper's words on `marco`).


## 9. The lines (every Hoot line is 18 words or fewer, tokens at their longest)

`{tokens}` are the measured numbers; `{key:<action>}` is `_k()` (D10). Day 5 story lines say "he" for Marco
directly; screen tips use the `{he}` tokens. As built, the level's lines live in `level_marco.gd` `HOOT`, the boards'
in `marco_board.gd` `LINES`, the screen's in `SinTest.TIPS`, `MISSCORED_SIN`, `BENEFIT_LINES`, `COACH_LINES` and
`sp_mode_party.gd`'s `COACH_*` constants; the tests check every one at 18 words or fewer with its tokens at their
longest, keys named only through `{key:...}`, and no diagnosis.

| Moment | Line |
|---|---|
| Movie announcement (first play only) | "New trick today: WORDS IN NOISE. A quick cartoon first, then our next patient!" |
| Movie replay offer (once seen) | "Hoot's party movie again? Popcorn's on me!" ["Roll the film! (about 70 s)", "Skip it: I know my SNR."] |
| Movie skipped at day start | "Skipped! Rewatch it any time: pause menu, "Watch Hoot's party movie"." |
| Movie captions | §4.2 (ten captions, owned by the movie data) |
| Purpose | "Day 5, trainee: speech in noise! Today the party talks back." |
| Review gag | "...Welcome to Booth Camp." |
| History: hardest | "Fine one-to-one, lost in a crowd. That's exactly what today measures." |
| History: onset | "Slowly, both ears alike: noted. Sudden would have been a red flag." |
| Coping clue | "The early table is a clue too. People quietly avoid what's hard." |
| Joke answer | "Delicious, but not a clue. Ask about his hearing!" |
| Red-flag sweep | "Always check red flags too: pain, dizziness, drips, one-sided ringing or loss, sudden changes." |
| Onset sweep | "Sudden changes are red flags too. Slowly, or suddenly?" |
| Hiss | "Hiss in both ears after loud nights isn't a red flag. It's a noise warning." |
| Earplugs | "Earplugs for loud nights: filtered ones keep the music clear." |
| After history | "Fine in quiet, lost at busy tables, both ears alike. No red flags. Let's measure!" |
| Otoscopy | "Canals clear, eardrums healthy. Nothing in the way." |
| Napkin | "...You can take the napkin off." (Marco: "Never. Life is a buffet.") |
| Instructions prompt | "Party test! Tell Marco what to do:" |
| Instructions, best ("Repeat the main voice, even single words. Guess if unsure.") | "Repeat the main voice, even single words. Guess if unsure. The party gets louder." (Marco: "The main voice. Like listening to the chef over the clatter.") |
| Instructions, strict ("Only repeat sentences you hear perfectly.") | Marco: "Perfectly? Then you'll hear nothing from me after the soup." Hoot: "Too strict! Every key word counts, even one. Guessing is welcome." |
| Instructions, party ("Repeat everything you hear, party and all.") | Marco: "Clink! Ha-ha! Happy birthday! More bread!" Hoot: "Just the main voice! The party is the noise we measure against." |
| Montage: routine (A1) | "This morning's listening check: every beep clean, the button works. Dials stay out of view." |
| Montage: tones | "I'll run the beeps at top speed. Better ear first: the right." (the AudiOtron's intros: "Better ear first: the right. Watch the stamps fly in!", "Left ear, Hoot speed!", "Bone at 500 to 4k, at Hoot speed: is there any gap?") |
| Masking recap (A2) | after the card, masking movie unseen: "The full masking movie is under Hoot's Movies, in the pause menu or on the title screen." |
| Montage: bone | "Bone matches air: no gap. Sensorineural, both ears." (else "Bone's in. Now his words, in quiet first.") |
| Montage: words (noise needed) | "Now words in quiet, my turn. The rule says noise in the other ear." |
| Montage: words (no noise needed) | "Now words in quiet, my turn. No noise needed this time." |
| Montage: summary | "Mild high-pitch loss, PTA about {pta}. Words in quiet: {r} and {l} percent. {verdict}!" ({verdict} = the poorer ear's WRS band title) |
| Both ears (Party list 1's intro) | "Party time! Both ears together, like a real dinner. His ears match." |
| Level (coach) | "Set the talker to {target} dB HL: {key:louder}. The party follows by itself." |
| Practice (coach) | "A practice sentence first: {key:present_tone}. I'll score it; you watch the chips." |
| Present (coach) | "Your turn. {key:present_tone} plays the first sentence." |
| Waiting for the answer (coach, Day 3's line) | "Listen... what does {he} say back?" |
| Key words (coach) | "Tick the key words {he} got. Little words like 'the' never count." |
| Walk (keys) | "{key:speech_correct} if {he} got it, {key:speech_incorrect} if {he} missed it. Or click the chips." |
| Walk (mouse) | "Click each key word {he} got, then LOCK IN. Unticked words count as missed." |
| Fix a chip (coach) | "Check chip {n} against what {he} SAID: {key:party_word_<n>} flips it." |
| Lock in | "Happy with the ticks? Lock it in: {key:store}." |
| Main course | "Ten dB gap. Most people still get everything here. Watch {name}." |
| List done | "Six sentences done. Time for the bill!" |
| The bill | "{total} key words. Check the receipt's formula. What's the bill?" |
| Bill: right | "Every key word he missed adds 1 dB. Most ears miss about four or five anyway." |
| Bill: the total | "That's the key words, not the loss. Subtract them from 25.5." |
| Bill: added | "Subtract, don't add! Fewer words right means a bigger SNR loss." |
| Band prompt | "{loss} dB of SNR loss. Point to its band on the ruler." |
| Band: wrong (board caption) | "Find {loss} on the ruler. Which band holds it?" |
| Band: moderate | "Moderate: the menu says directional mics. Let's prove it in the booth." |
| Band: near-normal (A7) | "Near-normal: good habits first. Let's still see what the aids do." |
| Band: mild | "Mild: if aids, standard settings. Let's still see what the mics do." |
| Band: severe | "Severe: the menu says a remote mic. Let's first see what the mics do." |
| Second list | "One list is a rough guess. Two make it solid. Second list!" |
| Hoot first (Party list 2's intro, quick visit) | "Set the talker, then I'll pour the easy courses. You take the noisy end." |
| Hoot pours (the turn banner) | "I'll pour the easy courses. You take the noisy end." |
| Hoot's list (lists 4 and 6) | "My list, at top speed: two lists make it solid." |
| Average | "Average of two lists: {avg} dB. {band} SNR loss." |
| Normed tests | "Real clinics use normed tests built like this. Our lists are for practice." |
| Plates | "Marco says two things. Serve each clue to the claim it proves." |
| Quiet plate (board caption) | "{band} words in quiet. Claim one: true!" |
| Quiet plate, PTA (board caption) | "True, near-normal beeps. Words in quiet prove it even better." |
| Noisy plate (board caption) | "{band} SNR loss. Claim two: also true!" |
| Distractor (board caption) | "True, but it doesn't prove either claim. Try another card." |
| The other plate (board caption) | "True, but that card proves the other claim. Try the other plate." |
| The whole story (A7) | "His audiogram can't tell us how he copes in noise. Measured: {avg} dB." |
| Real trouble | "His SRTs agree with his beeps. This noise trouble is real, and very common." |
| Sound field | "Hearing aids on. We test them with speakers: voice in front, party behind." |
| Blind | "Blind tasting! Marco won't know which programme is on, so he can't guess." |
| Programme A (list 3's intro) | "Programme A, in the sound field. Hoot sets the talker at a chatting level." |
| Programme B (list 5's intro) | "Programme B, same speakers, same level. Only the microphones change." |
| Pizza | "Omni hears the whole pizza. Directional favours the front half and turns the back down." |
| Switch | "Marco, eyes closed! Trainee, flip the switch to programme B." |
| Like with like | "Compare like with like: same speakers, same level, only the microphones changed." |
| Benefit, real | "Programme B was FOCUS: {benefit} dB better, two lists each. Real, not luck." |
| Benefit, small | "Programme B was FOCUS: {benefit} dB better. Under {crit}, that could be luck." |
| Benefit, small, then | "In clinic, run another list each before you promise anything." |
| Why blind | "Patients who know try harder on the 'better' one. Blind keeps it fair." |
| The booth is kinder (A7) | "The booth is kinder than a real restaurant. We'll check how the aids do at your table." |
| Seat prompt | "Where should Marco sit? His mics favour the front." |
| Seat: kitchen | "Kitchen doors swing and clatter right beside him. Try a quieter spot." |
| Seat: speaker | "Right under the music. The mics can't escape that. Try again." |
| Seat: facing the room | "Noise in front is what the mics listen to! Turn him around." |
| Seat: back to the room | "Back to the room, facing his guest, light on her face. Perfect!" |
| Tips | "Face your guest. Good light on faces. Quieter times. Tell the host." |
| Remote mic | "If noise ever beats the aids, a remote mic on his guest can help." |
| Expectations | "Directional mics turn noise behind him down, not off. Honest expectations matter." |
| The bill (payoff) | "...I'll allow it." |
| Goodbye | "That's the job: measure the party, then fix the party. Lovely work, trainee!" |
| No WRS mode (fallback) | "Word lists are still at the printer. His beeps say words in quiet should be fine." |

**SPEECH screen tips** (`SinTest` TIPS, contract §9.14.5; `{he}` tokens):

| kind | Line |
|---|---|
| `sin_level` | "Party test: talker at {target} dB HL. The party levels follow by themselves." |
| `sin_good_level` | "Talker at {target}: just right. The party steps up by itself." |
| `sin_aided_level` | "Aided tests go at a chatting level: {aided}. The aids add their own boost." ({aided} = `SIN_AIDED_DB`, 50) |
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
| `sin_done_hidden` (`hide_loss`) | "List done: {total} key words." |
| `misscored` (generic) | "Score what {he} SAID: only the exact key words count." |
| `misscored`: a mishear, ticked | "{He} said '{said}'. Close isn't correct!" |
| `misscored`: a trap, ticked | "'{said}' isn't '{word}'. Word endings must match, plurals and tenses too." |
| `misscored`: a filler or nothing, ticked | "{He} didn't say '{word}'. Untick it: only exact words count." |
| `misscored`: the word, missed | "{He} did say '{word}'! Tick it." |
| `sin_benefit`: real / small | as "Benefit, real" and "Benefit, small" above |
| `sin_benefit`: none (0 dB or less) | "Programme B was FOCUS: no better this time. Run another list each." |

Hoot never names a cause or a condition today: no "hidden" anything, no processing disorder, no age label. The lines
say what was measured and what helps. Marco's results are not a referral: no red flags, no air-bone gap, a symmetric
gradual loss, and SRTs and words that agree with his beeps (`wrs_summary.referral` is empty; §15 Q9).

## 10. Fun moments and set-piece gags

- **The review.** Marco reviews the clinic on arrival: beige ambience, two-star coffee, "Service: an owl.
  Intriguing." Later, inside the booth: "Cosy. Like a pantry. Four stars."
- **The napkin.** Tucked in all day, even under the earphones. "...You can take the napkin off." "Never. Life is a
  buffet."
- **The party instructions gag.** Told to repeat everything, he repeats the party: "Clink! Ha-ha! Happy birthday!
  More bread!"
- **Six courses.** Each sentence is a course; the dining-room strip fills as the SNR drops, from two quiet diners at
  the Starter to a packed Saturday at Dessert: a birthday cake with candles, a conga line, a wobbling tray.
- **The noise wins.** At Dessert (0 dB) the party bar meets the talker bar, grey clatter words ("HAHA", "clink",
  "BIRTHDAY!", "more wine?") crowd his bubble, and Marco answers with one of his lines: "Words? Gone. Like the last
  breadstick." (Appendix B). Reduced motion: a still, busy picture.
- **Sent back to the kitchen.** At LOCK IN, the missed key words slide onto a passing waiter's tray and ride away.
- **Ka-ching.** The bill prints like a till receipt; PAID stamps it after the band.
- **BOTH TRUE!** The two plates, two true claims, one stamp: the audiogram isn't the whole story.
- **Louder soup.** Programme A: "It's louder. But louder soup is still soup."
- **The blind tasting.** Eyes closed, napkin on, the trainee flips the switch; Marco guesses the course ("B! B was the
  main course.").
- **The pizza.** The whole pizza around his head; then the front half glows and the back half dims.
- **Seat Marco.** The kitchen doors CLANG, the speaker goes UNTZ UNTZ, and the corner booth turned the wrong way puts
  the whole room in front of his mics.
- **The salt shaker.** "A little microphone for my guest? Like a salt shaker for words!"
- **Rosa's news and the tiramisu.** He hears "married" across a roaring room; the tray crash behind him is "just a
  little"; "Put it on the owl's bill." "...I'll allow it."
- **The review.** His review of Booth Camp runs as the paper's subhead, forks by grade.

## 11. Accessibility

- **Text first, audio optional.** Every sentence is on the card, every answer in the bubble, every level and SNR on
  the LCD and the meter, the party's growth in the diners and the plates. The murmur, the babble and the movie's cues
  are quiet extras through `AudioSafety` (speech at most -27 dBFS RMS, babble capped at the -24 dBFS masker ceiling).
  The movie's captions carry every meaning, and its crowd is drawn, never played. No line says "hear the gap".
- **Keys** (the game's default key style, hints on the buttons, H toggles them): Space present; Up / Down the talker
  (the key-style toggle swaps them; Left / Right stay got / missed); Right / + / = got it; Left / - missed; 1-5 flip;
  G all got; {key:store} lock in (S or Enter); the band pointer Left / Right and Space / Enter; the plates 1-4; the
  switch Space / Enter; M (no MASK on a party list: Hoot says why); the movie Space / Enter (advance like the
  dialogue box: finish the caption, then the next scene), Esc (skip the movie), P (pause).
- **Mouse only.** Every action is a button: PRESENT, the level chevrons and wheel, the chips (click flips,
  right-click misses), ALL GOT, LOCK IN, the pause "II", the keys and key-style pills, the movie player's "Next"
  ("Start the day" on its last scene), "Skip movie" and "II", the bands on the ruler, the plates (drag, or click a
  card then a plate), the seats, the switch. Chips are at least 96 x 56 px. Every blocking beat sets `info.mouse`,
  and `--mouse` plays the whole day with clicks and drags only.
- **No time pressure.** Scoring waits for the player; LOCK IN is never automatic; the movie can be stepped, paused
  and skipped.
- **Reduced motion** (`Game.settings.reduced_motion`): no screen shake, no conga line, no flying clatter words, no
  waiter ride (the missed chips just grey out), the receipt prints at once, the pizza is two stills, the movie uses
  cuts and crossfades (the crowd scene leaves its waiter out). No flashing faster than 3 per second anywhere
  (candles and confetti included).
- **Colour is never the only cue.** Got = mint + tick + bold; missed = coral outline + cross + strike-through; the
  BOTH chip is ink, never an ear colour; band chips carry their names; the pizza's halves are also labelled FRONT and
  BACK.
- **Reading.** Sentences in the card font at 26 px or more; the bubble wraps at two lines; plain short words in every
  line.


## 12. Files

**New files**

| File | What |
|---|---|
| `core/patients/marco.tres` | the truth (§2) |
| `core/speech/material/party_practice.json`, `party_1.json` to `party_6.json` | the practice sentence and Party lists 1-6 (§5.5, Appendix A) |
| `core/speech/models/sin_model.gd`, `core/speech/modes/sin_test.gd` | the party model and the session mode (§5.6, contract §9.12.2, §9.14) |
| `core/speech/speech_babble.gd` | the babble loop: four murmuring talkers from `SpeechVoice`'s cached syllables, seed 7, unit RMS, peaks capped (contract §9.16) |
| `ui/speech/modes/sp_mode_party.gd` | PARTY mode (§5) |
| `ui/speech/sp_sentence_card.gd`, `sp_courses.gd`, `sp_snr_meter.gd`, `sp_party_booth.gd` | PARTY-mode widgets (§5.2) |
| `story/level_marco.gd`, `story/level_marco.tscn` | the day (§3) |
| `story/games/marco_board.gd` | the bill receipt and the band ruler, the plates, the pizza, the switch and the reveal card (§5.7, §6) |
| `story/games/marco_seats.gd`, `story/games/marco_dinner.gd` | Trattoria Clatter's floor plan and the payoff (§7) |
| `story/explainers/movies/party_noise.gd` | the movie data (§4.3), replacing S0a's stub |
| `story/explainers/stages/party_noise_sets.gd` | the movie's own sets: `extends "res://story/explainers/explainer_sets.gd"`, `const SETS` of the eight set ids, one `_set_<id>()` each |
| `story/papers/paper_party_golf.gd` | the party golf card (§8.4) |
| `story/dev_marco.gd`, `story/dev_marco.tscn` | dev gallery: the PARTY mode on Marco through the screen's own controls, then the boards, the seats, the dinner, the papers and Marco in the clinic (`--part=screen`, `board`, `seats`, `dinner`, `paper`, `clinic` or `all`); excluded from the export |
| `core/tests/test_speech_sin.gd`, `test_speech_sin_model.gd`, `test_speech_sin_session.gd`, `test_speech_voice_babble.gd`, `ui/tests/test_speech_screen_party.gd`, `story/tests/test_level_marco.gd`, `story/tests/test_movie_party_noise.gd` | tests (§14) |

**Shared files.** Every shared-file change went through the contract's S0a and S0b steps (§9.10.7) or is additive and
guarded; Days 1-4, 6-13 and the walk-ins behave exactly as before. Day 5's own additions to shared files are only
these:

| File | Change | Why the other days are safe |
|---|---|---|
| `core/speech/speech_rules.gd` | the "party lists (Day 5)" block after S0a's lists block: `SIN_LISTS`, `SIN_PRACTICE_LIST`, `SIN_PRACTICE_SNR`, `SIN_CONDITIONS` and titles, `SIN_SLOTS`, `SIN_COURSES`, `SIN_AIDED_DB`, `SIN_BAND_NAMES`, `SIN_REMEDIES`, the miss weights, `SIN_MISS_SHARES`, the little words, `SIN_KEY_SOUNDS`, `SIN_IRREGULAR_FORMS`, `sin_slot`, `sin_babble_level`, `sin_snr_for`, `sin_count`, `key_word_sounds`, `key_word_miss_weight`, `is_trap`, `sin_average`, `sin_crit_diff`, `sin_real_change`, `sin_par`, `sin_forks` | new names only; `SIN_BAND_TITLES` and `SIN_HELP` stay as they are, and no Day 5 file reads them (a test) |
| `core/speech/speech_voice.gd` | the babble (`start_babble`, `set_babble`, `stop_babble`, `is_babbling`, `babble_ready`, `babble_rms`, cut on pause and exit) and the "both" channel branch | "right" and "left" are unchanged, and Day 3 never passes "both" (a test) |
| `ui/speech/sp_lcd.gd`, `ui/speech/sp_bubble.gd` | the LCD's optional view key `noise_note` (in `OPTIONAL_KEYS`); the bubble's `idle_text` | both off by default; going back to the SRT restores them (tests) |
| `ui/speech/speech_screen.gd` | with a mode only: Hoot's opening lines say "Both ears" and count sentences on a party list, and the perch says "Hoot is testing: watch the plates!" | `_mode == null` on Day 3 keeps the old lines |
| `autoload/game.gd` | the `marco` line in its `CHAPTERS` marker, after Day 4's: day 5, `requires` `nora`, tint `#ffe1b8` | a new entry; Days 3-5 stay before Days 6-13. After Day 4, "UP NEXT" points to Day 5 |
| `world/clinic.gd` | `show_soundfield(on)`: two booth speakers on stands, TALKER in front and PARTY behind; `put_on_hearing_aids()` reused | a new function only Day 5 calls |
| `world/characters/bean.gd` | the `MARCO` spec and its drawing extras (napkin, cravat, notebook, fork, the half-moon glasses) in Day 5's marker region | a new spec; the extras default off |
| `story/portraits.gd` | "Marco" (BG `#ffe1b8`, name `#b5652a`) and "Rosa" (BG `#e3ecff`, name `#3e5fa8`) | new keys |
| `story/dialogue_box.gd` | the display names "Marco Polenta" and "Rosa Polenta" | new keys |
| `story/hud.gd` | the clue kind `"ok"` (a green ALL CLEAR card) | a new kind nobody else passes |
| `story/voice.gd` | none: the level calls `Voice.register("Marco", ...)` and `Voice.register("Rosa", ...)` at run time | |
| `story/explainers/movies.gd` | the `party_noise` registry line (S0a) | a movie is listed for replay only once its chapter exists |
| `tools/autoplay_bot.gd` | the Day 5 checks of contract §9.22 (`_check_sin_lists`, `_check_marco`, the paper's words, `movies`) in blocks marked `# (Days 4-5)` (`tools/INTEGRATION_NOTES.md`, "Already in the bot") | each block needs a party sheet or the `marco` chapter |
| `core/tests/test_speech_seams.gd` | the movie-stub check skips a movie whose day exists; a stand-in party sheet adds no party summary | tests |
| `export_presets.cfg` | `story/dev_marco.*` in every preset's `exclude_filter` (the party lists ride the existing `core/speech/material/*.json` include) | dev files only |
| `docs/SPEECH.md`, `CONTRACTS.md`, `README.md`, `tools/README.md`, `docs/ADDING_A_CHAPTER.md` | SPEECH.md §5 and the SIN kinds; the contract's SIN parts corrected to the build; the Day 5 commands and overview | docs |

Not edited for Day 5: `story/daily_decibel.gd` (S0b's hook, D8), `autoload/events.gd` and the input map (S0a added the
party signals, `party_word_1` to `party_word_5` and `party_all_got`), and the main thread's `explainer_stage.gd`,
`explainer_sets.gd` and `explainer_player.gd` (the sets hook means Day 5 never touches them).

**Story beats** (each with a solver and a mouse route): `band_pick`, `plates_serve`, `focus_switch`; the bill, the
instructions, the history and the seats are stock `choice` beats.

## 13. Screenshots

The bot's own `speech_<slot>_sin_<list_id>_first_word` and `_stored` shots come for free (D26:
`speech_both_sin_party_1_*`, `speech_both_sin_party_2_*`, `speech_aided_omni_sin_party_3_*`,
`speech_aided_directional_sin_party_5_*`, ...). Plus:

| Name | Shows | Taken by |
|---|---|---|
| `explainer_party_noise_<NN>_<scene>` (8, at 0.2 / 0.6 / 0.95 of each scene) | every movie scene as the player shows it; once more with `--reduced-motion` | `dev_explainer.tscn --movie=party_noise --at=0.2,0.6,0.95` |
| `day5_review`, `day5_history_clue`, `day5_montage` | the entrance review; the green "No red flags" card; the word strips stamped in | the level (`--shots`) |
| `day5_bill`, `day5_band_pointer`, `day5_average` | the receipt with the formula and the band ruler; PAID; both lists and the average | the level |
| `day5_plates`, `day5_both_true` | the plates, then the stamp and the banner | the level |
| `day5_soundfield`, `day5_pizza`, `day5_switch`, `day5_reveal` | the booth speakers in the clinic; front half bright, back half dimmed; the A / B switch; A against B | the level |
| `day5_seats`, `day5_seat_facing` | the floor plan; the wrong-way booth | the level |
| `day5_dinner`, `day5_married`, `day5_tray_crash` | the payoff | the level |
| `day5_party_level`, `day5_practice`, `day5_scoring`, `day5_lock_tray`, `day5_noise_wins`, `day5_list_done`, `day5_soundfield`, `day5_focus_revealed`, `day5_hoot_turn` | the coached talker and ghost hand; Hoot's practice; chips half marked; the waiter's tray; Dessert at 0 dB; the total; programme A in the sound field; FOCUS's bright front half; Hoot's x8 courses | `dev_marco.tscn --part=screen` |
| `dev_day5_bill` ... `dev_day5_reveal_luck`, `dev_day5_seats`, `dev_day5_seat_<id>`, `dev_day5_dinner` ... `dev_day5_review`, `dev_day5_paper_<grade>` (S, A, C, Do-over), `dev_day5_marco_*` | every board state by its solver, each seat, the dinner, four papers, Marco in the clinic (glasses on, off for the phones, back on standing) | `dev_marco.tscn --part=board / seats / dinner / paper / clinic` |
| `results_final` | the paper, with the review subhead | the bot |

Rendered at 1280x720 and 1920x1080, reduced motion on and off.

## 14. Tests

- `core/tests/test_speech_sin.gd` (the rules and the material)
  - The rules as written: `snr_loss(16)` 9.5, `snr_loss(20)` 5.5; `snr_loss(t) == (30 - t) - 4.5` for every t;
    `sin_band` 3.0 normal, 3.5 mild, 7.0 mild, 7.5 moderate, 15.0 moderate, 15.5 severe; `sin_level(21.7)` 70;
    `SIN_AIDED_DB` 50; slots, levels and SNRs; the dithered count; key sounds and miss weights; traps (with the
    irregular pasts); averages, `real_change`, par and forks.
  - A7: `SIN_BAND_NAMES[&"normal"]` is "Near-normal"; no Day 5 file reads `SIN_BAND_TITLES` or `SIN_HELP`.
  - Material: `party_practice`, `party_1` to `party_6` validate, six sentences each, five key words in order; every
    note says "written fresh for Booth Camp" and names the tests it must not copy; the own-material guard (§5.5); every
    list teaches traps and sound-alikes; the `key_sounds` overrides.
- `core/tests/test_speech_sin_model.gd` (the model): Marco's numbers (PTA 21.7 / 23.3, better ear right,
  `directional_benefit` 4.0, `snr_loss` 9.0); the loss sources; `sin_expected_words` at each SNR (to 0.01) for losses
  9.0 and 5.0; 4000 dithered lists average 16.49 +- 0.1, never more than one from the expected count; two lists land
  within 1.5 dB of 9.0 in at least 99% of 2000 seeded runs, the unaided band is moderate in at least 99.5%, FOCUS within
  1.5 dB of 5.0 in at least 99%, and the 2-vs-2 benefit is above 2.7 in at least 93% (and at most 98%, so the honest
  path still happens); heavier key words go first (ratio at least 1.5 at SNR 15); answers keep what he heard; lost
  lines only with count 0; the same seed replays a visit; per ear and both; the model holds its sim weakly.
- `core/tests/test_speech_sin_session.gd` (the session mode): it loads by path; nothing to mask; `state()` is never
  truth; the present / mark / flip / all-got / lock flow; blanks lock as missed; the walk wraps; per-chip checks and
  lines; the coach fixes wrong marks; the player's level is checked at the first scored sentence; the practice; Hoot
  first and level first; `level_by_hoot` on aided lists; the unaided sheet and units; Hoot's lists count no units;
  party golf (list 2 can birdie; lists 1, 3 and 5 top out at par); the FOCUS benefit; `run_by_textbook` reaches a
  sheet for every Day 5 plan; a whole Day 5 visit on one session; a list is used once; moments once per visit; the
  hidden loss; the per-ear summary; the lines fit and name keys; the mode is freed with its session.
- `core/tests/test_speech_voice_babble.gd`: the loop builds in under 150 ms headless; unit RMS and capped peaks; the
  party keeps going; the same seed replays; the recording path and helpers; the babble level on the masker mapping;
  babble and mix peaks capped; "both" writes both channels and one ear one; the babble stops on stop, exit and pause.
- `ui/tests/test_speech_screen_party.gd` (the screen): a party list by keys; layout and anchors on screen, clear of
  Hoot and of each other at 1280x720 and 1920x1080; the walk, flips, all-got and lock keys; the level set by Hoot from
  the start; the swapped key style swaps only the level; a list by mouse at 1920; chip clicks and the mouse buttons;
  marks refused before the answer; beat info, solvers and a stale solver; `hoot_first` three courses then hands back;
  `level_first` then `hoot_first`; the practice by Hoot at x1; `hoot_only`; `hoot_turn_after`; the walk hand follows
  the focus; a slip line replaces the little-words tip; a second list on "both" gets its own Hoot turn; no takeover
  without quick visit; reduced motion is still; SRT -> PARTY -> SRT restores the layout; a WORD probe then PARTY drops
  its anchors; Day 3's SRT never reaches the PARTY mode; the lines fit and name no diagnosis.
- `story/tests/test_level_marco.gd` (the level): the movie is announced only when unseen; the party plans (unaided
  lists 1-2 with phones or inserts, A lists 3-4 and B lists 5-6 in the sound field at 50 by Hoot, `hide_loss` on list
  1 only, `hoot_only` on lists 4 and 6, quick visit on and off); a textbook visit's sheets; the bill options and the
  medals; the band ruler's keys and a wrong band; the plates by keys, drag, click-then-click and solver; the pizza,
  the switch and the reveal; the reveal's guess follows the benefit; the seats by keys and buttons; the dinner plays
  through; the party golf card's rows and lines; the paper fits the window; every Hoot line fits and names no
  diagnosis (with A7's three lines pinned); choice prefixes are unique; the level's constants; a smoke run to the
  tones.
- `story/tests/test_movie_party_noise.gd` (the movie): `Movies.validate("party_noise", Stage2D.SETS)` is empty with
  its own sets, 45-110 s (71); the house rules on every scene (captions 18 words or fewer, card params: heading 30
  characters or fewer, at most 4 lines of 36 or fewer, icon in `CARD_ICONS`, the set's data under its own key); our
  own words only (no published test named); **the lead-in**: scene 1 has `card_hold` >= 6, two `questions` of 30
  characters or fewer, and its first caption ends with "?"; the cards-only fallback; every scene draws; the sets are
  pure in `t` (a source scan for `randf`, `randi`, `RandomNumberGenerator`, `Time.`, `create_tween`, `add_child`,
  `get_tree`); the facts of the scale, the knob, the gap, the menu and the receipt (`SIN_SNRS`, `SIN_COURSES`,
  `SIN_NORMAL_SNR50_DB`, `snr_loss(25)`, `sin_band(0.5)` drawn as "NEAR-NORMAL").
- The bot (contract §9.22, applied in `tools/autoplay_bot.gd`): `tools/autoplay_check.sh --day=5`, keys and
  `--mouse`, `--via-days --pick=marco`, and `--full` once; each grade S with no problems.

## 15. Open questions for Steve

1. Both ears together under earphones for a symmetric loss like Marco's, or each ear on its own (better ear first)
   even when the ears match? What does your clinic do day to day?
2. Aided in the sound field at 50 dB HL (which we take as about 65 dB SPL; please check against your calibration),
   talker in front and party behind, set by Hoot. Right level and set-up? The model gives no spatial benefit for the
   speakers on their own: OK to keep it that simple?
3. OMNI wins nothing over unaided in this much noise, and FOCUS wins 4 dB for a fitting on vented domes. Fair numbers
   for a fresh fitting in a booth? Would you pick a different dome for Marco? (A7 keeps the 4.0 dB and adds "The
   booth is kinder than a real restaurant. We'll check how the aids do at your table.")
4. Scoring strictness: a plural or tense change is a miss, little words never count, extra little words are fine.
   As built, any changed ending is a miss too ("smell" for "smelly", "loud" for "loudly"), with the line "Word endings
   must match, plurals and tenses too." Is that how you score?
5. The arithmetic: SNR loss = 25.5 - key words right per list (derived in §2.2), two lists averaged; bands at 3 / 7 /
   15 dB named Near-normal / Mild / Moderate / Severe (A7); a typical SNR-50 of 2 dB. Right to teach?
6. **How close is too close.** The Party Noise Test keeps a familiar structure: 6 sentences of 5 key words, SNR 25 to
   0 in 5 dB steps, four-voice babble, 25.5 - total, bands at 3 / 7 / 15 and 2.7 / 3.9 dB critical differences. The
   sentences, babble, band names and remedies are our own, and Hoot says real clinics use normed tests. Are you
   comfortable with that, or should the structure move further away?
7. The remedies on the band ruler: "good habits", "if aids: standard settings", "+ directional mics", "+ a remote mic".
   They say which technology an SNR loss points to, not whether someone needs aids. Would you say it that way?
8. Comparing conditions: 2.7 dB for two lists against two, 3.9 for one against one. The game's lists wobble about half
   as much as real ones, so Hoot says "One list is a rough guess. Two make it solid." Is that honest enough, or should
   the game show the spread?
9. No referral for Marco: symmetric, gradual, no red flags, no air-bone gap, SRTs and words that agree with his beeps.
   Would you refer anyone for a big speech-in-noise difficulty with a near-normal audiogram (for example for further
   auditory tests), or is counselling plus aids the right call here?
10. The banner line, now A7's: "His audiogram can't tell us how he copes in noise. Measured: {avg} dB." Right, now that
    the game's own estimate is never shown?
11. His hiss after very loud nights (both ears, gone by morning): "isn't a red flag, it's a noise warning", plus
    filtered earplugs. Right advice, and enough?
12. The counselling content: face your guest, good light, quieter times, tell the host, booths and corners, back to
    the room with directional mics, a remote mic if noise wins, and "real fittings are checked with a tiny mic in the
    ear, then fine-tuned over weeks". Anything missing or wrong?
13. Hoot's montage: tones (in the new routine order, with the right's 1 kHz retest), unmasked bone at 500-4k, SRTs and
    words in quiet, all by Hoot (the SRTs and words off-screen). The speech-noise rule fires exactly on the line for
    his right ear at 55. Fine on a speech-in-noise day?
14. The practice sentence before list 1 (unscored), each list used once per visit, and the lists treated as equally
    hard (they are not normed). OK?
15. The payoff (Rosa's engagement over a roaring room) and "down, not off" as the honest expectation line: right tone
    for career-fair players?
16. The bill's framing: "Every key word he missed adds 1 dB. Most ears miss about four or five anyway." (Exactly:
    25.5 - right = missed - 4.5.) A fair way to teach it? The movie's receipt adds the chip "Most ears miss 4 or 5
    anyway", so its typical diner (five missed, 0.5 dB) agrees with the rule.
17. The patient-blind A/B ("Blind tasting!"): Marco is not told which programme is on, and Hoot explains why. Is that
    how you would run it, and is "Patients who know try harder on the 'better' one" fair?
18. The replacement sentences (Appendix A: p1_4 "A PURPLE KITE LANDED on the BAKERY ROOF." and the others rewritten
    under the no-phrase rule) and these borderline pairings: goat chewed, paper crown, woke the whole street, rainy
    Monday, rusty wagon, hungry bear, shiny shoes, stripy hat, broken radio, wet leaf, sang loudly, bus home, loud
    sneeze, glass table, old city library. Too predictable, or fine?
19. **The movie captions** (§4.2), especially two changed since the design:
    - **The scale caption was reworded and needs your OK**: "SNR: how much louder the voice is than the noise. A
      bigger gap is easier." The design's "how far the voice sits above the noise" contradicted the picture once the
      balance was drawn the physical way (the heavier, louder voice pan sinks, so it sits lower).
    - Steve's lead-in on scene 1: "Hoot's Movie Matinee! Today's mystery: why can someone fine in quiet get lost at a
      busy table?" and "The answer is SNR LOSS. Quiet beeps can't show it, so we test words in noise." (chips "Why is a
      busy table so hard?" and "How do we test words in noise?"). And: "Every key word missed costs about 1 dB. The
      receipt adds up the SNR loss."
20. **The talker level check** is judged at the player's first scored sentence (Hoot plays the practice, and on list 2
    the first courses, at the player's level). Only coaching costs the tee bonus: list 2's "Set the talker, then I'll
    pour the easy courses." names no level, so it is not a hint. Should any other hint cost the bonus?
21. **Only the first wrong chip of a LOCK IN gets Hoot's line**; the other wrong chips flash. Enough feedback for a
    newcomer, or should Hoot name each one?
22. **The aided level** is announced by the screen ("Programme A, in the sound field. Hoot sets the talker at a
    chatting level.") and the start chip "AIDED: 50 dB, set by Hoot"; the longer "Aided tests go at a chatting level:
    50. The aids add their own boost." shows only if the player tries the level keys. Should Hoot always say it?
23. **Marco's bill line** ("{loss} dB! For a critic, that's a terrible review.") plays only for a moderate or severe
    loss, so a near-normal or mild bill is never called terrible. Right?


---------------------------------------------------------------------------------------------

## Appendix A. The sentences (all written for Booth Camp)

Every sentence, key word and mishear below was **written fresh for Booth Camp**. None copies or paraphrases a
published sentence test (HINT, BKB, IEEE/Harvard, QuickSIN, WIN, BKB-SIN, SPIN, AzBio): no sentence, list, order,
key-word set or recording is taken from them (§5.5). As built, the data is `core/speech/material/party_practice.json`
and `party_1.json` to `party_6.json`, word for word as below, each with `original: true` and a `note` that says so.
The SNR column is the course: Starter 25, Soup 20, Fish 15, Main 10, Cheese 5, Dessert 0 (`SIN_COURSES`).

Key words in CAPITALS; mishears in brackets after each sentence, one group per key word, in order (a "/" separates
two mishears of the same key word). The first mishear of each word is a sound-alike; a second one is often a plural or
tense trap. No mishear is a homophone of its key word.

**Practice sentence** (`party_practice`)

| id | Sentence | Mishears |
|---|---|---|
| pp_1 | A GREEDY CAT STOLE THREE SAUSAGES. | needy; hat; stove / steal; tree; sausage |

**Party list 1** (`party_1`, unaided)

| id | SNR | Sentence | Mishears |
|---|---|---|---|
| p1_1 | 25 | The SLEEPY GOAT CHEWED a PAPER CROWN. | leafy; coat / goats; shoed / chews; pepper; clown / crowns |
| p1_2 | 20 | My UNCLE KEEPS RED SOCKS in the FREEZER. | ankle / uncles; keep / leaps; bed; sock / box; feeder / freezers |
| p1_3 | 15 | A LOUD TRUMPET WOKE the WHOLE STREET. | cloud; crumpet; spoke / walk; bowl / goal; sheet / streets |
| p1_4 | 10 | A PURPLE KITE LANDED on the BAKERY ROOF. | turtle; white / kites; handed / lands; battery; proof / roofs |
| p1_5 | 5 | The TRAIN LEFT EARLY on a RAINY MONDAY. | rain / trains; lift; curly; brainy; Sunday |
| p1_6 | 0 | TWO PUPPIES CARRIED a TURNIP past the FENCE. | few; puppy; married / carries; parsnip / turnips; tents / fences |

**Party list 2** (`party_2`, unaided)

| id | SNR | Sentence | Mishears |
|---|---|---|---|
| p2_1 | 25 | Our TEACHER DREW a GOLDEN CASTLE on the CEILING. | preacher / teachers; grew / draw; holding; tassel / castles; feeling |
| p2_2 | 20 | The TINY BABY GIGGLED at the SPOTTED PONY. | shiny; maybe / babies; wiggled / giggles; potted; bony / ponies |
| p2_3 | 15 | DAD KEPT his PENCILS inside a SMELLY BOOT. | bad; slept / keeps; pencil; jelly / smell; suit / boots |
| p2_4 | 10 | A SHY DONKEY PUSHED the RUSTY WAGON. | pie / sky; monkey; brushed / push; dusty; dragon / wagons |
| p2_5 | 5 | She HID SIX TOMATOES behind the TALL PIANO. | kid / hit; sticks / fix; tomato; ball / doll; pianos |
| p2_6 | 0 | A HUNGRY BEAR OPENED the GREEN SUITCASE. | angry; chair / bears; open; cream / screen; bookcase |

**Party list 3** (`party_3`, programme A)

| id | SNR | Sentence | Mishears |
|---|---|---|---|
| p3_1 | 25 | My NEPHEW FOLDED a PINK TICKET into a STAR. | nephews; rolled / fold; ink / sink; picket / tickets; car / stars |
| p3_2 | 20 | My COUSIN SELLS SHINY SHOES from a CANOE. | dozen / cousins; smells / sell; tiny; juice / shoe; Peru / canoes |
| p3_3 | 15 | We WATCHED an ORANGE BALLOON DRIFT over the HILLS. | washed; arrange; saloon / balloons; drip / drifts; pills / hill |
| p3_4 | 10 | The DOCTOR WORE a STRIPY HAT to WORK. | rocker; four; slippy; cat / hats; fork |
| p3_5 | 5 | GRANDPA HUGGED the BROKEN RADIO all EVENING. | grandma; tugged / hugs; open; ratio / radios; evenings |
| p3_6 | 0 | A DUCK SNORED LOUDLY behind the YELLOW TRACTOR. | truck / ducks; snowed / snores; proudly / loud; mellow; actor / tractors |

**Party list 4** (`party_4`, programme A)

| id | SNR | Sentence | Mishears |
|---|---|---|---|
| p4_1 | 25 | The NEW POSTMAN SLIPPED on a WET LEAF. | blue; snowman; sipped / slips; red; beef / leaves |
| p4_2 | 20 | Her BROTHER CARVED a CANDLE SHAPED like a SHIP. | mother; starved / carves; handle / candles; shaken / shapes; chip / ships |
| p4_3 | 15 | The CHILDREN SANG LOUDLY on the BUS HOME. | chicken; sank / sing; proudly; bun; phone |
| p4_4 | 10 | I LOST my SPOTTY GLOVE inside the EMPTY THEATRE. | cost; dotty; love / gloves; twenty; heater / theatres |
| p4_5 | 5 | The FARMER LENT his TWELVE CHAIRS to the SCHOOL. | former; tent / lend; shelves; chair; stool / schools |
| p4_6 | 0 | A LITTLE ROBOT TICKLED the SLEEPY GIRAFFE. | brittle; rabbit / robots; pickled / tickles; creepy; carafe / giraffes |

**Party list 5** (`party_5`, programme B)

| id | SNR | Sentence | Mishears |
|---|---|---|---|
| p5_1 | 25 | The QUEEN DROPPED her GOLDEN SPOON in the POND. | keen; stopped / drop; holding; moon / spoons; bond / ponds |
| p5_2 | 20 | Our NEIGHBOUR POLISHES his GREEN HELMET every THURSDAY. | labour / neighbours; punishes / polished; cream; pelmet / helmets; Tuesday |
| p5_3 | 15 | Two PINK BIRDS SAT on the POSTBOX all MORNING. | ink / sink; words / bird; cat / sit; toolbox / postboxes; warning / mornings |
| p5_4 | 10 | My SISTER PAINTED the TALL DOOR SILVER. | blister / sisters; planted / paints; ball; floor / doors; sliver / slipper |
| p5_5 | 5 | The FROG SLEPT QUIETLY beside the ORANGE BUCKET. | dog / fog; swept / sleeps; quickly / quiet; arrange; pocket / buckets |
| p5_6 | 0 | TOMORROW we MEET at the OLD CITY LIBRARY. | borrow; eat; gold; pretty; liberty |

**Party list 6** (`party_6`, programme B)

| id | SNR | Sentence | Mishears |
|---|---|---|---|
| p6_1 | 25 | Our GOALKEEPER BORROWED a SHORT LADDER from GRANNY. | shopkeeper; borrows; sort / shirt; letter / ladders; nanny |
| p6_2 | 20 | MUM LEFT a WOODEN TROPHY under the STAIRS. | gum; lift; woollen; toffee / trophies; chairs / stair |
| p6_3 | 15 | A LOUD SNEEZE SHOOK the GLASS TABLE. | cloud; squeeze / sneezes; cook / shake; class / glasses; cable / tables |
| p6_4 | 10 | The SMILING PILOT WAVED from the RED BICYCLE. | filing; pirate / pilots; saved / waves; bed; icicle / bicycles |
| p6_5 | 5 | We HEARD TINY TRUMPETS behind the GREEN BARN. | hard / hear; shiny; crumpets / trumpet; cream; yarn / barns |
| p6_6 | 0 | The NOISY PARROT HID every SILVER BUTTON. | nosy; carrot / parrots; kid / hit; sliver; mutton / buttons |

What changed from the draft, and why: p1_4 (was "PLEASE PASS the SALT and the WARM BREAD": a stock phrase, and
Day 4's movie used to show "Pass the salt"); p4_5 (counted twelve sheep before bed); p2_6 (picnic basket); p6_2
(birthday presents); p2_4 (cold wind blew); p6_1 (caught the ball); p3_1 (the kitchen clock: a possible published
opening). Also rewritten for the same rule: p1_6 (dug a tunnel), p2_1 (purple castle on the board), p2_3 (found his
keys), p2_5 (by the garden gate), p3_2 (shoes at the market), p3_3 (orange moon rise), p3_5 (fixed with tape), p3_6
(swam across the muddy pond), p4_2 (baked a cake), p4_4 (woolly glove in the deep snow), p4_6 (cleaned the dusty
attic), p5_1 (spoon in the soup), p5_2 (washes his car every Sunday), p5_3 (birds built a nest), p5_4 (bright yellow),
p5_5 (jumped over the stone wall), p6_3 (sudden storm, apple trees), p6_5 (cold pizza on the beach) and p6_6
(repeated every secret word). Mishears that were homophones or too easy were replaced ("sheeps", "meat", "green" for
"queen").

## Appendix B. Marco's lines

**When the noise wins** (`MARCO_LOST`; Dessert, count 0; one is picked, never twice in a row):

- "Words? Gone. Like the last breadstick."
- "Nothing. Only clatter. Like a kitchen at closing time."
- "I heard... a birthday? Somebody always has a birthday."
- "Sorry. The party ate the whole sentence."
- "Something about... soup? It's always soup."
- "I'm nodding and smiling. My famous dinner-party trick."
- "Was that 'tiramisu'? I want it to be 'tiramisu'."
- "Clink, clink, ha-ha. That's all I've got."

**Around the tests**

- After the practice sentence: "An amuse-bouche! A little taste before the meal."
- After unaided list 1: "The starter was delicious. The main was muddy. Dessert? I tasted only noise."
- After the bill: "{loss} dB! For a critic, that's a terrible review."
- On SNR loss: "So my ears need the voice served... a little hotter than everyone else's."
- The blind tasting: "A blind tasting. My favourite kind."
- During programme A: "It's louder. But louder soup is still soup."
- After the pizza: "The front half, facing my guest. The back half... a little less."
- After programme B: "Now the voice is the main course, and the noise is just... garnish."
- The guess: "B! B was the main course." (or "A... or B? Both tasted rather similar.")
- On the remote mic: "A little microphone for my guest? Like a salt shaker for words!"
- Goodbye: "Booth Camp. Read my review tomorrow. I'm booking the nine o'clock table."


---------------------------------------------------------------------------------------------

## Design notes (critique points not taken, or taken differently)

1. **Fun 12's "the player sets the talker in the sound field on list 5".** Not taken: clinical 4 sets every aided
   list at `SIN_AIDED_DB`, by Hoot, so A and B are compared at one known level. The player's level skill stays on the
   unaided earphone test, so Day 5's birdie is on list 2 only (the same one-rule golf as Day 4).
2. **Clinical 9's "tulip domes".** Not used: it is a product-line term, and the vendor-free rule bans those. The
   fitting says "vented domes", and the benefit is 4.0 dB (the critique's second option), with the honest "another
   list each" path for the 5% of runs at 2.7 dB or less.
3. **Clinical 17's seat line for the middle table** is moot: fun 22 replaced the middle table with "Corner booth,
   facing the room". The pizza line and the front-half / back-half picture are applied as asked.
4. **Clinical 10's help-line rewordings** ("Usually copes in noise...", "A moderate SNR loss needs technology too.",
   "That fits a {band} SNR loss. His is {measured}.") are moot: fun 10 deleted the "What helps" beat. Their substance
   is kept: the mild remedy reads "if aids: standard settings", the ruler says which technology a band points to (not
   candidacy), aided sheets print no band, and a wrong band gets "Find {loss} on the ruler. Which band holds it?".
5. **Clinical 22's movie split into 9 shots and about 73 s.** The movie is 8 scenes: fun 17 folded the title into
   scene 1, and the receipt is its own 8 s scene, so each caption still gets its own scene of at least 8 s. As built
   it runs 71 s (the design's 65 s plus Steve's lead-in: scene 1 holds the marquee for its question and answer, so it
   is 14 s; §4.2).
6. **Engineering 1's "shot 7a/7b becomes one scene with two captions".** Superseded by clinical 22 (two captions in
   8 s read too fast): they are two scenes, `menu` and `receipt`.
7. **Fun 17's receipt caption "Every key word missed costs about 1 dB..." and its 59 s, 7 shots.** The caption and the
   typical diner (25 right, 0.5 dB) are as asked; the scene count is 8 (point 5).
8. **Clinical 5, taken partly.** The 25.5 is derived in §2.2, the band names and remedies are ours, and the Hoot aside
   and an open question (Q6) are added. The structure itself is kept, because it is the shared rule set in
   `docs/SPEECH.md` and `speech_rules.gd` (a general Spearman-Kärber design), and `SIN_BAND_TITLES` / `SIN_HELP` are
   left in place (additive-only) with a test keeping new code off them.
9. **Clinical 3's alternative wording** ("His word scores fit his beeps...") is not needed: the full fix was taken
   (unmasked bone and quick SRTs in Hoot's montage), so the plates line is "His SRTs agree with his beeps. This noise
   trouble is real, and very common."
10. **Fun 2's montage line** ("Mild high-pitch loss, PTA about 22. Words in quiet: 96 and 92. Excellent!") is written
    with tokens, and its verdict comes from the poorer ear's band, so an 88% list says "Good" (clinical 22).
11. **Clinical 16 named seven sentences.** More were rewritten under the new no-phrase rule (Appendix A lists them),
    and the remaining borderline pairings go to Steve (Q18) rather than being rewritten again.
12. **Fun 11's split ("Hoot pours 1-3, the player scores Main / Cheese / Dessert")** applies with quick visit on. With
    it off, the player scores lists 3 and 5 whole; lists 4 and 6 stay Hoot's either way (`hoot_only`), because the
    second lists of each programme add no new skill.
13. **Fun 10's ruler wording "3-7 mild: hearing aids"** reads "if aids, standard settings", following clinical 10:
    the SNR loss picks the technology, not whether someone needs aids.
14. **Engineering 8's `hoot_only` for Day 5's two WRS lists.** The key and the gate are in the contract, but Day 5's
    SRT and WRS now run off-screen through `run_hidden` (fun 2), which never depends on quick visit; `hoot_only` is
    used for lists 4 and 6.
15. **(Applied as written.) Engineering 2's `story/explainers/stages/party_noise_stage.gd` (a subclass of `explainer_stage.gd` with
    `MOVIE_SETS`), its dev preview script, and fun 4's "paste into SETS later".** Superseded: the per-movie sets hook
    has landed on `chapter-2-feedback` (461f723; the `movie_ref` copies predate it). The sets live in
    `story/explainers/stages/party_noise_sets.gd`, which extends `explainer_sets.gd` and must call its list `SETS`
    (the base declares none, so nothing is shadowed), and `MOVIE.stage` points at it. The shared dev scene shoots the
    real sets, so no preview script is needed, and nothing is ever pasted into the shared stage.
16. **(Applied as written.) Fun 4's "Next scene" / "Skip movie" controls.** The shared player has moved on: Space / Enter / a click advance
    like the dialogue box, and its buttons are "Next" ("Start the day" on the last scene), "Skip movie" and "II". This
    doc follows the player, so Day 5's movie works exactly like Day 2's.
17. **Engineering 19's "name each in-list trigger in CHAPTER5 §5.3".** Taken: §5.3 now has the table. Two lines moved
    to keep lists unblocked: "louder soup" became an aside on the first player answer of programme A, and "Now the
    voice is the main course..." stays as story dialogue after programme B.
18. **The 94.9% benefit figure** (from the earlier draft) is now 95.0%, computed exactly from the dithered count
    distributions (clinical's own check said 95.1% by simulation).

### As built (what changed while building Day 5)

19. **The level comes before the practice.** `recommended_action` asks for the talker level first and the practice
    sentence second, and the level locks at the first presentation (practice included), so the practice plays at the
    level the list will use. On screen Hoot never moves a level the player owns (`level_first`, `practice`).
20. **The level check moved to the first scored sentence** (§8.2): Hoot may play the practice, or the first courses
    with quick visit on, at the level the player set, so the check waits for the player's own first scored sentence.
21. **Trap wording.** The trap line reads "'{said}' isn't '{word}'. Word endings must match, plurals and tenses too."
    `is_trap` counts any changed ending of the key word (one word starting with the other, a regular plural or tense
    ending, a doubled consonant, `SIN_IRREGULAR_FORMS`), so "smell" for "smelly" is a trap too (§15 Q4). A generic `misscored` line ("Score what
    {he} SAID: only the exact key words count.") covers a slip with no single word to name.
22. **The LCD caption.** The big caption always reads "TALKER"; "set by Hoot" moved onto the start chip ("TALKER: 70
    dB, set by Hoot" when Hoot set it, "AIDED: 50 dB, set by Hoot" on the aided lists), so the caption never overlaps the TALK knob.
23. **Programme chips stay blind.** The condition chip reads PROGRAMME A / PROGRAMME B until the plan's `revealed` is
    set (after the reveal); only then "A: OMNI" / "B: FOCUS", and only then does the booth draw FOCUS's front cone.
24. **Layout.** The sentence card spans the bottom of the left and middle columns (§5.2). The masking panel shows a `noise_note` ("NO MASKING", "same mix in" / "speakers reach", "both ears") in place of a
    level, and the reply bubble's `idle_text` reads "(waiting for a sentence)".
25. **The movie's scale scene** draws the balance the physical way (the louder, heavier voice pan sinks), so its
    caption was reworded to "SNR: how much louder the voice is than the noise. A bigger gap is easier." (§15 Q19,
    needs Steve's OK). The receipt scene adds the chip "Most ears miss 4 or 5 anyway", and the cue times follow the
    71 s cut (§4.2).
26. **Lines that play only sometimes.** `sin_no_mask` shows once per visit: just after Party list 1's intro (or on M
    if the player reaches for masking first); the longer `sin_aided_level` line only when the player presses a level
    key on an aided list (the start chip and the list's intro say it otherwise, §15 Q22); Marco's "terrible review"
    line only for a moderate or severe bill (§15 Q23); the `sin_benefit` "none" line when FOCUS is no better.
27. **Feedback at LOCK IN.** Only the first wrong chip gets Hoot's line; the other wrong chips flash (§15 Q21). A
    slip's line replaces the sticky tips while it shows.
28. **The benefit fields** land on the FOCUS sheet as soon as the OMNI sheet has one list (§8.1), so the screen can
    show a provisional difference; the `sin_benefit` line still waits for two lists each.
29. **Chef's kiss** is paid on a clean player part of a list, even when Hoot locks the last sentence; an all-Hoot list
    pays nothing (§8.2).
