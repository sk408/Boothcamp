# Booth Camp: Case Files (Days 6 onward)

Design for the patient cases. Each case is one patient with one condition, played as its own day from the
chapter select. The player gathers clues (history, otoscopy, a tympanogram, the audiogram) and makes the
call: **FIT** hearing aids, **REFER** to a doctor first, or **DOCTOR TODAY** (same-day urgent referral).
Contract additions are in `CONTRACTS.md` §11 (cases). Steve reviews every clinical number and line.

| | |
|---|---|
| Teaches | reading clues; red flags; audiogram shapes; tympanogram types and canal volume; where a loss sits (canal, middle ear, inner ear); comparing with old charts; retesting after treatment; the fit / refer / doctor-today decision |
| Length | target 8-9 minutes per case with "quick visit" on (the default); see the budget in section 4 |
| Opens | from the chapter select, any order, every day open from the start (`requires` only picks the suggested "UP NEXT" day). The first case a player opens starts with Hoot's one-line Case Files briefing, and Hoot's three case movies play just before their steps (section 3.1). |
| Level scene | `res://story/level_case.tscn` (`story/level_case.gd`), one runner for every case |
| Case data | `story/cases/<case_id>.json`: **the source of truth for every line that ships**. `docs/CASE_SCRIPTS.md` is generated from it (`python3 tools/case_scripts.py`) so the full scripts can be read and signed off. Patient truth in `core/patients/<id>.tres`. |
| Rules | `core/cases/case_rules.gd` (`CaseRules`): decisions, red flags, asymmetry, the sudden-loss definition, tympanogram types and curve |

The game never diagnoses. Hoot says what the pattern "points to" and that a doctor decides. Clinicians in the
game spot patterns and refer; doctors diagnose.

---------------------------------------------------------------------------------------------

## 1. The cases

| Day | Case id | Patient | Condition (never named as a diagnosis in play) | The call |
|---|---|---|---|---|
| 6 | `noise_notch` | Rocco Rimshot, 52, drummer of The Decibelles | Noise-induced hearing loss, both ears | **FIT** (+ musicians' earplugs, tinnitus counselling, yearly test) |
| 7 | `menieres` | Captain Marina Gale, 46, island ferry captain | Ménière's-like: spinning spells, fluctuating low-pitch loss and roaring, left | **REFER** (+ safety net, not at the wheel until cleared) |
| 8 | `sudden` | Dash Delgado, 29, owner, chef and only driver of Speedy Slice | Sudden sensorineural hearing loss, right, yesterday morning | **DOCTOR TODAY** |
| 9 | `cookie_bite` | Ginger Snapp, 41, ventriloquist (and Chip, her cookie puppet) | Hereditary mid-frequency ("cookie-bite") sensorineural loss, both ears, stable for years | **FIT** (+ offer a genetic counselling referral, yearly test) |
| 10 | `wax` | Barnaby Bumble, 61, beekeeper (forty thousand bees, all called Gerald) | Wax impaction, right: conductive, bone normal | **REFER** (a doctor or trained clinician clears the wax), then a live **retest** a week later: normal |
| 11 | `fluid` | Skye Tailwind, 33, long-haul cabin crew | Middle-ear fluid after a cold and a flight, left: conductive, bone normal | **REFER** (a doctor this week, before her Friday flight) |
| 12 | `dead_ear` | Morgan Gale, 58, keeper of the Gullrock light (Captain Marina's sibling) | A deaf right ear since mumps at seven, checked by an ear doctor, unchanged: its unmasked air is the left ear's shadow; masked, no response | **FIT** (a CROS: the right side's sound sent to the left ear; guard the left ear, a yearly test) |
| 13 | `bilateral_conductive` | Bev Bingham, 46, caller at the town hall bingo | Otosclerosis-like: big air-bone gaps in both ears with Carhart's notch, As tymps, her mum had the same; masking runs out of room (the masking dilemma) | **REFER** (an ear doctor first; aids often work well, some choose an operation) |

Day numbers start at 6 because the speech chapters take Days 3-5. Chapter ids are the patient ids, like `gus` and
`bonnie`: `rocco`, `marina`, `dash`, `ginger`. No acoustic-neuroma case: the speech chapters' Day 4 patient (Nora)
already teaches "one-sided loss with poor words: refer before fitting". Batch 2 keeps bone flat and teaches canal
against middle ear plus the retest (Bonnie, Day 2, teaches one stiff middle ear). Batch 2's chapter ids: `barnaby`,
`skye`. The advanced cases (clinical review C10, C9; `/mnt/project-files/boothcamp/cases/ADVANCED_CASES.md`): Day 12
`morgan`, Day 13 `bev`, whose stiff middle ears are in BOTH ears, which is what makes masking run out of room.

**Day picker text** names the person or the joke, never the pattern, condition or call (28 characters or fewer):
rocco "Case file: ringing ears", marina "Case file: the ferry captain", dash "Case file: the pizza rush", ginger
"Case file: the ventriloquist", barnaby "Case file: the beekeeper", skye "Case file: the cabin crew", morgan
"Case file: the lighthouse", bev "Case file: the bingo caller".

**Each case has a beat only it has:** Rocco picks the drummer's earplugs (cotton wool / foam / musicians'); Marina
compares today with her spring test and her referral letter folds into a paper boat that sails to a lighthouse
marked EAR DOCTOR; Dash's hours clock counts up in the corner the whole visit and Hoot phones the ear doctor;
Ginger's puppet Chip heckles (her lips don't move), her nine-year-old chart proves the loss is stable, and her
family history is the tempting wrong clue. Barnaby brings his wallet ("hearing aid time!"), the otoscope finds a
wall of wax, and a week later he walks back in with the plug in a jar ("EXHIBIT A") for a retest whose chart flies
up over the waxy one; his bee Gerald waits outside during the tests. Skye talks in in-flight announcements, tries to
pop her ear ("Hnnnngh!"), and her referral folds into a paper plane that lands on an EAR DOCTOR runway. Morgan
brings the ear doctor's letter, and their deaf right ear "answers" at 55-70 dB (75-90 with inserts) until the noise goes in: the shadow
curve, with a ghost on the chart. Bev calls bingo numbers at everyone, hears BETTER in the noisy hall, and runs
Hoot out of masking room: he lends his insert earphones, her chart fills with purple ?s ("FULL HOUSE!"), and a
padlocked stirrup bone drops into the gap.

**The four "where is it stuck" days** (Hoot's framing for the conductive cases):

| | Wax (Barnaby, Day 10) | Fluid (Skye, Day 11) | Stiff middle ear (Bonnie, Day 2) | Inner ear (Dash, Day 8) |
|---|---|---|---|---|
| Otoscope | a plug; the eardrum can't be seen | clear canal; dull amber drum, bubbles | clear canal, normal drum | clear canal, normal drum |
| Tymp | B, **tiny** canal volume (the probe meets the plug) | B, **normal** canal volume (the drum can't move) | not measured on Day 2 | A |
| Bone | normal | normal | normal (Carhart dip at 2k) | **down with the air** |
| Air-bone gap | 25-30 dB | about 25 dB | 25-45 dB | none |
| Onset | muffly for months, then all at once in the shower | crept in after a cold and a flight | slow, years | overnight |
| Call | REFER: wax out, then retest | REFER: a doctor this week | REFER | DOCTOR TODAY |

## 2. Truth tables (dB HL; sensorineural, Days 6-9 and 12: bone = air; conductive, Days 10-11 and 13: their own bone data)

Frequencies 250, 500, 750, 1k, 1.5k, 2k, 3k, 4k, 6k, 8k. Days 6-11 use the default real interaural attenuation
(phones 60, inserts 75, bone 0; Days 12-13 use 50 / 70), so no unmasked AIR reading is ever a cross-heard shadow (Day 12's is, on purpose), but every unmasked BONE
reading is the better cochlea answering, wherever the buzzer sits (the Ghost from Day 2). So one-sided cases put
unmasked bone on the better ear only (Steve's convention, as on Day 2), compare the poorer ear's air with it, and the
runner adds masked bone on the poorer ear wherever the rules ask. Every shape below survives any single 5 dB wobble
(`story/tests/test_cases.gd`).

### 2.1 Rocco (noise notch, symmetric)

| Hz | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| Right air (O) | 15 | 15 | 20 | 25 | 30 | 40 | 55 | 65 | 55 | 40 |
| Left air (X) | 15 | 20 | 20 | 25 | 35 | 45 | 60 | 70 | 60 | 45 |

- Shape `notch` both ears: the 3-6k floor is 25 dB below 2k and recovers 25 dB at 8k.
- Ears within 5 dB everywhere: symmetric (5 dB is test-retest wobble; the card says "Left and right ears match", since
  the measured chart can wobble a little more). Flavour only: he says the left, his hi-hat
  side, might be worse; no line claims the chart shows it.
- Bone: Hoot, right mastoid, unmasked (= right air; the right is the better cochlea, so no Ghost). Unmasked bone
  is the better cochlea, so it stands for both ears: left air minus it is 0-5 dB, so no gap is possible on either
  side and no masking is needed. The runner types the left ear from this reading too (`_borrow_bone`, within 10 dB everywhere, the
  no-real-gap line; a 10 dB gap gets masked bone first, clinical review E5 and C6).
- PTA (500/1k/2k): right 26.7, left 30. 2k/3k/4k average: right 53.3, left 58.3. Tinnitus: both ears, high, constant.
- Tympanograms: A both (tip large, a roomy canal). Last loud gig four days ago (no temporary shift).

### 2.2 Marina (Ménière's-like, left, low pitches)

| Hz | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| Right air (O) | 10 | 10 | 10 | 5 | 10 | 10 | 10 | 15 | 15 | 15 |
| Left air (X) today | 50 | 45 | 45 | 45 | 35 | 25 | 25 | 25 | 30 | 30 |
| Left air, spring sea medical (on file) | 25 | 20 | | 20 | | 15 | | 20 | | 30 |

- Left shape `rising` (low average 46.7, high average 26.7). Right normal. Asymmetric.
- The spring test shows the low pitches 25 dB better. On its own that only proves a change; her report of good and
  bad days (in her opening lines, always heard) is what makes it fluctuating. The spring test was not itself
  asymmetric: 250, 1k and 8k each differ from her right ear by 15, but never two neighbouring frequencies.
- Unmasked bone on her better (right) ear reads her right cochlea (about 10 / 5 / 10 / 15 at 500 / 1k / 2k / 4k).
  Against her left air that is a gap at 500, 1k and 2k, and at 4k (25 against 15: exactly the 10 dB bone-masking
  gap of clinical review E5, so a 5 dB wobble can drop it), so masked bone runs on the left there and lands on the
  air values (no real gap).
- Masked air: the rule (left air - 40 >= the right cochlea's bone estimate) asks for it at 250 and 1k, each exactly
  on the line, so a 5 dB wobble can drop one; the runner follows the stamped values. It confirms 50 / 45.
- Last spell ten days ago, good days since, and no new drop: her hearing dips with spells and comes back, and today's
  low-pitch loss (25 dB worse than spring) is under the 30 dB sudden-loss bar. The pattern, not a clock, keeps her off
  DOCTOR TODAY. Tinnitus: left, a low roar, louder
  before a spell. Fullness: left. No cold. Tympanograms: A both (tip medium).

### 2.3 Dash (sudden sensorineural loss, right)

| Hz | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| Right air (O) | 40 | 45 | 50 | 55 | 55 | 55 | 55 | 55 | 60 | 60 |
| Left air (X) | 10 | 10 | 10 | 5 | 10 | 10 | 15 | 15 | 15 | 20 |

- Right shape `flat` (PTA 51.7, moderate), left normal.
- Meets the sudden SNHL definition: 30 dB or more poorer at 3+ neighbouring frequencies (here 30-50 dB poorer than
  the left ear at all ten; with no old audiogram the other ear is the baseline), coming on within 72 hours
  (overnight, about 30 hours before the visit).
- Unmasked bone on his better (left) ear matches his left air: far under his right air, so masked bone runs on the
  right and lands on the air values (45 / 55 / 55 / 55 at 500-4k,
  10 dB under the oscillator's limit at 4k and under the 500 Hz "felt" line).
- Masked air by the rule from 1k up (not at 250 or 500: 40 - 40 and 45 - 40 are below the left ear's 10). It
  confirms the unmasked values: his real phones IA is 60.
- A bit wobbly yesterday, fine now (dizziness: a red flag too). No face droop, numbness, slurred speech or double
  vision. Tympanograms: A both (tip medium). Otoscopy: clear, no wax (he was sure it was wax).

### 2.4 Ginger (cookie bite, symmetric)

| Hz | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| Right air (O) | 15 | 20 | 30 | 45 | 50 | 50 | 40 | 25 | 20 | 15 |
| Left air (X) | 15 | 20 | 35 | 45 | 50 | 55 | 45 | 30 | 25 | 20 |
| Right air, nine years ago (on file) | 15 | 20 | | 40 | | 50 | | 25 | | 15 |

- Shape `cookie_bite` both ears: the middle (1k-2k) 27.5-30 dB poorer than 500 Hz and 20-22.5 dB poorer than 4-8k.
- The 500-to-1k jump is 25 dB in both ears (clinical review C11), so 750 Hz is tested in both, even with a 5 dB wobble.
- Ears within 5 dB: symmetric. Bone: Hoot, right mastoid, unmasked: it matches BOTH ears' air (it is the better
  cochlea, so the left gap can only be smaller), so no masking, and both ears read sensorineural.
- Her dad and his mum (Grandma Snapp) have the same pattern: one family line, three generations. School hearing
  tests found it; the right-ear chart from nine years ago is within 5 dB of today: stable.
- PTA: right 38.3, left 40. Tympanograms: A both (tip small, a narrow canal).

### 2.5 Barnaby (wax, right: conductive)

| Hz | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| Right air (O) | 35 | 35 | 35 | 35 | 35 | 35 | 40 | 40 | 40 | 40 |
| Right bone (`bc_right`) | 10 | 10 | 10 | 10 | 10 | 10 | 10 | 10 | | |
| Left air (X) | 5 | 5 | 5 | 5 | 5 | 5 | 10 | 10 | 10 | 15 |
| Right air after the wax is out (`barnaby_after.tres`, the retest) | 10 | 10 | 10 | 10 | 10 | 10 | 15 | 15 | 15 | 20 |

- Right shape `flat` (PTA 35), left normal, asymmetric. Right type **conductive**: gaps of 25 / 25 / 25 / 30 at
  500 / 1k / 2k / 4k with bone averaging 10, so `abg_red_flag` is true (10 dB of margin). No single 5 dB wobble to
  any air or bone value at 500-4k changes the shape, the type or the flag (`story/tests/test_cases.gd`).
- **Phones, not inserts:** with the canal full of wax the runner forces supra-aural phones for the first visit
  ("inserts go deep, and could push the wax further"); the retest may use inserts again.
- Unmasked bone on his better (left) ear (Hoot's montage) reads about 5; against his right air that is a gap, so
  masked bone runs on the right at 1k, 2k, 4k and 500 (full
  plateaus, no dilemma: initial noise sits 20 dB or more under the overmasking limit). **No masked air**: right air
  minus 40 never reaches the left bone estimate (10 dB of margin), and Hoot says so from the stamps ("At these levels,
  air tones can't cross the head. Only bone needed masking today!").
- Retest: right air only, on a fresh AudiOtron and session with the treated ear's truth. Air lands on the unchanged
  bone (0 dB apart at 250-2k, 5 at 3-4k), about 25 dB better: normal, symmetric. `barnaby_after` is never a
  chapter's patient and `begin_visit` never sees it; the first visit's results stay the scored set.
- Tympanograms: right B, ECV 0.4 mL (blocked); left A, 1.5 mL (tip large, a roomy canal). After removal: right A
  with a 1.6 mL canal.

### 2.6 Skye (middle-ear fluid, left: conductive)

| Hz | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| Right air (O) | 10 | 5 | 5 | 5 | 5 | 5 | 10 | 10 | 15 | 15 |
| Left air (X) | 40 | 35 | 35 | 35 | 30 | 35 | 30 | 35 | 35 | 35 |
| Left bone (`bc_left`) | 10 | 10 | 10 | 10 | 10 | 10 | 10 | 10 | | |

- Left shape `flat` (PTA 35), right normal, asymmetric. Left type **conductive** (gaps of 25 at 500 / 1k / 2k / 4k),
  `abg_red_flag` true; neither changes under any single 5 dB wobble. The slight low-pitch tilt (40 at 250) suits
  fluid's stiffness-plus-mass effect without becoming a `rising` shape. Bone is flat: no Carhart dip (Bonnie's lesson).
- Unmasked bone on her better (right) ear (Hoot's montage), then masked bone on the left at 1k, 2k, 4k and 500
  (left oscillator, noise in the right ear); no masked air with phones or inserts.
- Tympanograms: right A (-15 daPa, 0.7 mL, canal 1.2 mL), left B with a normal 1.1 mL canal (fluid) (tip medium).

### 2.7 Morgan (a deaf right ear: the shadow curve; clinical review C10)

| Hz | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| Right air (O), true | 110 | 130 | 135 | 140 | 140 | 140 | 140 | 140 | 130 | 120 |
| Left air (X) | 10 | 10 | 10 | 5 | 5 | 10 | 10 | 15 | 15 | 20 |

- No bone data: bone = air in both ears. The right ear sits 20 dB past the dial everywhere (`ClinicRules.max_db` + 20;
  `PatientProfile.validate` now allows up to + 30, as it already did for bone), so its own cochlea never answers.
- Real interaural attenuation phones 50, inserts 70, bone 0 (ADVANCED_CASES question 2): below the defaults and above
  the masking rules' 40 / 55, so unmasked right air is the left ear's bone plus 50 (about 55-70 dB; 75-90 with
  inserts): the left ear's shape, just louder. That is the shadow, and the rules always ask for masked air.
- Unmasked bone on the left (Hoot's montage), so it never fakes a conductive gap on the right. Masked bone on the right
  at 500, 1k, 2k, 4k: each noise step pushes the answer up 5 dB, no plateau, then no response at the bone limit (60 /
  70 / 70 / 65). Then masked air at every routine frequency (250 to 8k with 1.5k, 3k and 6k; clinical review E1):
  the same climb, then no response at the dial's limit (90 at 250, 110 at 500 and 6k, 120 from 1k to 4k, 100 at
  8k). Masked bone must come first (the runner's order): its no-response stamps lift
  the overmasking limit, so masked air never fills its window (no purple ?) and E9's dilemma never trips
  (`test_dead_ear_plan_masks_both_ways`, with phones and inserts).
- Right shape `flat`, left normal, asymmetric: a FIT anyway, for a known cause (section 7). The raw chart would type the
  right ear "mixed" (the best-thresholds code ignores no-response flags), so the case types it with
  `CaseData.measured_type`: no-response bone drops out, and with no bone left and the air abnormal the ear reads
  sensorineural, as the truth does. Tympanograms A both ears (tip large).

### 2.8 Bev (gaps in both ears: the masking dilemma; clinical review C9)

| Hz | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| Air, both ears | 65 | 55 | 55 | 55 | 50 | 45 | 40 | 35 | 40 | 40 |
| Bone, both ears | 20 | 10 | 10 | 10 | 15 | 25 | 20 | 15 | | |

- Otosclerosis-like in both ears: gaps 45 / 45 / 20 / 20 at 500, 1k, 2k, 4k (the air-bone-gap red flag), Carhart's
  notch on bone at 2k, tympanograms As both ears (shallow, stiff), shape `rising` in both (low pitches 58, high 40:
  it stays rising under any single 5 dB wobble). Real interaural attenuation phones 50, inserts 70, slope 1.5.
- These numbers differ from ADVANCED_CASES.md's first draft (500 60, 1k 50, 4k 40, 8k 45; bone 250 15, 4k 10): with
  those, inserts still left no room at 4k, the shape sat exactly on the rising/flat line, and 250 Hz air was heard
  across the head with nothing in the rules to mask it.
- Masked bone windows (initial masking = the other ear's air + 10; overmasking limit = the bone + the rule's 40 / 55):
  through headphones, 1k and 500 open in a masking dilemma (initial 65, limit 50) and 2k and 4k fit one noise raise:
  a purple ? on all four. Through inserts, 1k and 500 are still dilemmas (initial 65 = limit 65, a purple ?), while
  2k (55 to 80) and 4k (45 to 70) have room for a full plateau. Pinned for every single 5 dB wobble
  (`test_dilemma_case_windows`).
- The loan (`lend_inserts`): before the first masked bone test, the runner reads the windows from the stamps
  (`CaseData.dilemma_freqs`, which mirrors the session). When it opens in a dilemma, or with no room for a
  plateau (a player who owns inserts and gets a bone stamp of 15 at 500 Hz and 1 kHz), Hoot says the case's
  `on_dilemma` lines (once; also for a player who owns inserts), then, if the player owns none, lends his inserts
  for the rest of the visit (`LEND_INSERTS`; never the save's upgrades, never into wax).
- Hoot's dilemma movie (`dilemma_movie`, question 26): right after those lines and before the loan, while it is
  unwatched, **Hoot:** "Both ears blocked: a real puzzle! A quick cartoon on why, then back to work." and "The
  Masking Dilemma" (79 s; Esc skips it, and it comes back on the next visit until watched to its purple ? scene).
  Two corks in the head: air needs 55 at 1k, bone shows 10; the noise must reach the other ear's air + 10 = 65, and
  65 - 40 = 25 crosses back over Righty's 10 (hushed); the window chart: enough from 65, hushed from 50, no room;
  inserts thicken the wall to 55 and open 55 to 75 at 2k (room for a plateau); Bev's chart gets the purple ? at 500
  and 1k ("the test's limit, not her ears'"). Every number is the game's own rule on Bev's truth
  (`test_dilemma_movie_numbers_match_the_rules`). Replays: Day 13's pause menu and the title, as "Day 13".
- Masked air: the air was measured through headphones before the loan, and each air stamp is judged by its own
  earphone's rule (`ClinicRules.masked_freqs_needed`), so 500 Hz and 1 kHz need masked air (55 - 40 >= 10). Run
  through the lent inserts, those are dilemmas too (initial 65, limit 65): a purple ? at the air level. A player who
  owns inserts measured the air through them: no masked air (55 - 55 < 10), and Hoot says so.
- After the masked tests, when Hoot stored a purple ? (`NO_ROOM`): "Purple ? marks: no safe noise level was left for
  a plateau. True thresholds may be poorer." The simulator answers the true bone inside every safe window, so the
  stamps still land on the truth.

## 3. Beat by beat (one runner for every case)

Every choice (history questions, the tymp question, the shape question, the earplugs, the clue cards) is
shuffled with `Game.rng` (seeded by `--seed`, so autoplay stays reproducible); the solver's `best` follows the
shuffle. The stamp tray keeps its fixed order FIT / REFER / DOCTOR TODAY.

| # | Phase | What happens | Beat(s) |
|---|---|---|---|
| 1 | `intro` | First case ever: Hoot's briefing ("Case Files! Gather clues, then stamp it: FIT, REFER, or DOCTOR TODAY."). The patient's entrance gag and complaint (joke + real clue), Hoot's personal opener. The "always" clues go on the notes. | dialogue |
| 2 | `history` | Two rounds of three questions (2 / 1 / 0 points). The red-flag sweep always happens: if the player skipped it, Hoot asks it. Red-flag card, plus any extra cards the sweep reveals. Medal `history` (4 points gold, 2 silver). | choice |
| 3 | `otoscopy` | A quick look at the other ear ("Fresh speculum. <name>'s <OTHER EAR> ear first: a clear canal, a healthy eardrum.": both ears are looked at before any probe or insert goes in), then the case's ear (`CaseOtoscopy.show_view`: the healthy drum, a wax plug, or fluid behind the drum); its caption names the canal size (roomy / average-sized / narrow). Clue card (red for wax: "a lot of wax" is a red flag). A wax view keeps the air tests on headphones. | dialogue |
| 4 | `tymp` | **The tympanometer gadget** (section 5): pick the tip for the canal the otoscope showed, both curves draw, then the patient's own question ("Her ear feels full. Is it fluid?"). Medal `tymp`. | choice |
| 5 | `instructions` | Hoot's routine line first, every case ("This morning's listening check: every beep clean, the button works. Dials stay out of view.", clinical review A1), then one line: the player tells the patient "press for every beep, even faint ones" (with the patient's joke), and the earphones go on. No mini-game in cases. Rocco's ringing gets Hoot's tinnitus lesson here (clinical review C8): a steady beep near his ring's pitch hides in it; "Which beep stands out from Rocco's ringing?" (PULSED and WARBLE both right, TONE hides; repeats until right); the audiometer starts on PULSED and the chip switches to WARBLE or TONE; some clinics prefer warble. Marina keeps a one-line tip. | dialogue, choice (Rocco) |
| 6 | `audiometry` | The case's test plan (section 4), then masked bone and masked air on each ear wherever the rules ask (Hoot; with Quick visit off the player runs them and Hoot's lines say so). The case's after-test line plays only when every ear with bone agrees with the case; otherwise Hoot says a neutral line. Before the visit's first masked test, while Day 2's masking movie is unseen, the 12-second masking recap card plays, then Hoot says where the full movie lives (clinical review A2, as Freestyle does). When every masked air stamp on an ear is no response (Morgan), Hoot says: "No plateau, just a climb, then nothing at the limit." (It names no ear: the evidence question asks who answered.) | the AudiOtron's tone beats, explainer (recap) |
| 6b | `speech` | Only a case with a `speech_check` (the FIT cases Rocco and Ginger; clinical review C13 and A4). The HUD's Words pill. "Words next: a word score in each ear, then the Party Noise Test. Hoot speed!" Hoot runs the SRT and a word score on each ear, then one unaided Party Noise Test list, off-screen with the SPEECH screen's montage (Day 5's `run_hidden`), unscored. From his sheets: "SRTs match the beeps. Words in quiet: right 92%, left 88%. Excellent!" and "Party Noise Test: 4.5 dB SNR loss. Mild trouble in noise." (no line hints at the call); cards "Words in quiet" and "Party Noise Test" join the case file (the first to leave a full board); then the case's `after` line. | the SPEECH screen's montage |
| 7 | `reveal` | The case board: the audiogram stamps in. Hoot: "What shape do you see?" | dialogue |
| 8 | `evidence` | The shape question (for Dash and Barnaby, the type of loss; for Skye, where the sound is stuck; for Morgan, who answered the right ear's unmasked beeps; for Bev, the type of loss). Only after the right answer does the shape come alive with its title (section 6), with any chart on file joining it, dashed. Then the type badge (the patient's true type, like every line around it) and the chart's cards join the case file: a card with a `when` shows only when the measured chart says so (symmetric, asymmetric, conductive, the air-bone-gap flag, the shadow, or no response), and if any of them read differently on the truth tables Hoot says once: "Some stamps wandered, so the chart and the story disagree. In clinic, recheck first!" Medal `evidence`. | choice |
| 9 | `decision` | Three rubber stamps: FIT / REFER / DOCTOR TODAY. A wrong stamp gets Hoot's reason and another try. Then "present the clue that proves it" from up to nine shuffled cards; each wrong card can have its own reply. Medal `decision`. | choice (stamp tray), choice (clue cards) |
| 10 | (payoff) | FIT: hearing aids pop on + counselling (Rocco also picks his earplugs). REFER: the letter flies off (Marina's folds into a paper boat, Skye's into a paper plane). TODAY: Hoot phones the ear doctor and books this afternoon. The patient waves goodbye. | dialogue, choice |
| 11 | `retest` | Only a case with a `retest` block (Barnaby). The HUD's Retest pill. "A WEEK LATER" flips over the empty door; he walks back in with the wax in a jar; a clear look, a tymp recheck (the tip seals, both curves draw, no question), a prediction ("Where will his right-ear air land now?", repeats until right), then right air on a fresh AudiOtron. The new chart flies up over the first visit's air, dashed and labelled WITH WAX, with "+25" arrows and the title UNPLUGGED!; the patient's lines play only when the measured ear types as the story says (else a neutral recheck line). No medal; the first visit's results stay the scored set. Visit flags `retested`, `retest_type`. | dialogue, choice, the AudiOtron's tone beats |
| 12 | `results` | The Daily Decibel with the case's own headlines and medal row (Chat, Tymp, Pattern, Call). A wrong first stamp swaps every graded headline (S to C) for the case's `paper.wrong_first` one (or a generic "FIRST STAMP SAID ..."); Do-over keeps its own. | results_continue |

The stamp tray and the clue cards emit the standard `choice` beat (same info as `DialogueBox.choose`), and their
buttons' text starts with the option text, so the autoplay bot plays them by keys and by mouse with no new route.

### 3.1 Hoot's case movies (clinical review C12)

Three in-engine cartoons (CONTRACTS.md §3.4), each played just before the step it explains, so any day can be
played first. Gated like the briefing: on the player's first case (`LevelCase.first_case()`) each plays after its
lead-in line; on a later case Hoot offers one that was never watched to its `seen_at` scene ("Roll the film!" /
"Not now"); once watched, it is never forced again and lives in the pause menu (Hoot's Movies, on every case day
through `also_chapters`) and the title's list, labelled "Days 6-13". Esc skips one ("Skipped! Rewatch it any time:
pause menu, "Hoot's Movies"."). The lines are `LevelCase.CASE_MOVIES`; `docs/CASE_SCRIPTS.md` prints them.

| Movie | Plays | Teaches |
|---|---|---|
| Hoot's case files movie (`case_files`): "Three Stamps and the Red Flags" | before the patient knocks (phase `explainer`, then `intro`) | a dispenser spots patterns and refers, doctors diagnose; FIT / REFER (soon) / DOCTOR TODAY (same day); the red flags; the proof card |
| Hoot's tympanometer movie (`tymp`): "The Eardrum Trampoline" | before the tympanometer step | look first, a gentle seal; the 226 Hz probe and the pressure sweep; types A, As, Ad, C, B read with the canal volume |
| Hoot's audiogram movie (`shapes`): "Slopes, Notches & Cookie Bites" | before the reveal | reading the chart (O right, X left, 25 dB or better is normal); sloping, rising, flat, the noise notch, the cookie bite; what bone adds (sensorineural, conductive, mixed) and the 15 dB gap red flag. Every chart it draws classifies as its scene says (test_cases.gd) |

The data is `story/explainers/movies/<id>.gd`, the drawing `story/case_movies/<id>_sets.gd` (the movie's own sets).

## 4. The test plan

Per case, `audiometry` in the JSON is a list of tests; the runner adds the masked follow-ups itself:

1. Air. One-sided cases (Marina, Dash, Barnaby, Skye, Morgan): Hoot runs the better ear first ("better ear first, like the
   pros"; at x8, or as Hoot's montage for Barnaby, Skye and Morgan: `"montage": true` with `hoot_turn_after` 0 fills the ear
   in a few seconds), then the player tests the poorer ear. Symmetric cases (Rocco, Ginger): the player tests the right ear first and Hoot
   runs the left at x8.
2. The player's ear: the player stamps the first N measurements, then Hoot finishes. The screen goes to the next
   required frequency after each store (clinical review E1: 1k, 1.5k, 2k, 3k, 4k, 6k, 8k, the retest on the first
   ear, 500, 250), and 750 joins as soon as 500 Hz and 1 kHz differ by 20 dB, so N counts it too. Rocco: right ear,
   N = 7 (1k up to the 8k recovery). Marina: left ear, N = 10 (the whole ear, with room for a retest). Dash:
   right ear, N = 3 (he's in a hurry). Ginger: right ear, N = 10 (1k to 8k, retest, 500, 750: the bite's
   low edge is the player's, and once 750 is on her chart Hoot says why it was tested). Barnaby: right ear, N = 2 (1k and 1.5k); on the retest, N = 1 (1k, where he was 35 a week
   ago). Skye: left ear, N = 2. Morgan: right ear, N = 4 (1k to 3k: the shadow is in the player's own stamps).
   Bev: right ear, N = 4, then her left at x8.
3. Unmasked bone (Hoot). One-sided cases: on the better ear only (Steve's convention, as on Day 2; x8 for Marina
   and Dash, a montage for Barnaby, Skye and Morgan), since it answers for the better cochlea wherever it sits;
   `CaseData.validate` checks it. Symmetric cases (Rocco, Ginger, Bev): the right ear only; Rocco's and Ginger's
   unmasked bone sits within 5 dB of the air in both ears (under the 10 dB bone-masking gap), so no bone masking is
   needed; Bev's sits far under the air in both, so both ears get masked bone (section 2.8).
4. Masked bone on each ear (`CaseData.masked_bone_ears`: the plan's bone ears, then the other air-tested ears)
   where `ClinicRules.masked_freqs_needed(results, ear, &"bc_masked")` is not empty: the ear's air against the best
   unmasked bone from either mastoid (Hoot; the oscillator moves to that ear). Only the poorer ear of a one-sided
   case ever needs it in the shipped cases (pinned by a test).
5. Masked air on each air-tested ear where `masked_freqs_needed(results, ear, &"ac_masked")` is not empty (Hoot).
   Checking every ear changes nothing for the shipped cases: the better ear never needs it (pinned by a test).
   When masked bone ran and no ear needed masked air (Barnaby, Skye), Hoot says why. Morgan's right ear needs masked
   air at every routine frequency, phones or inserts, after masked bone (section 2.7); Bev's ears need it at 500 Hz
   and 1 kHz when the air was measured through headphones (section 2.8).

The air transducer is the inserts once that upgrade is owned, except while the canal is full of wax (Barnaby's first
visit): headphones then, and the masking rules read the same transducer.

With "quick visit" off (`--full`), the player runs everything. Masking was taught on Day 2, so Hoot narrates it in
one line.

**Time budget** (target, quick visit): intro 0:30, history 1:15, otoscopy 0:15, tymp 0:40, instructions 0:10,
audiometry 2:30, reveal + evidence 1:15, call + clue 0:50, payoff 0:30, results 0:40 = 8:35. Barnaby is "two
visits in one" (about 11 minutes; the retest adds about 2:45) and Skye about 9:20. Trims for Barnaby, in order: his
first right ear from 2 player stamps to 1; drop the retest tymp; a shorter retest payoff; the retest air as Hoot's
montage (cut last: it loses the player's 1k moment). Autoplay runs
take about as much game time as Day 2. Two AudiOtron changes would shorten the cases and are requested in
`ui/INTEGRATION_NOTES.md`: hand over to Hoot once a named frequency is stored (instead of a stamp count), and let
masked air that only confirms the unmasked values stamp in as one sweep.

## 5. The tympanometer gadget (`story/games/case_tymp.gd`)

A chunky handheld "Tymp-O-Matic". It seals the canal, sweeps the air pressure from +200 to -400 daPa and draws how
easily the eardrum moves (a peak where it moves best). Teaching numbers (`CaseRules`):

| Type | Shape (game words) | Peak pressure | Peak (mL) | Means |
|---|---|---|---|---|
| A | a normal mountain | -100 to +50 daPa | 0.3-1.7 | the eardrum moves normally (no fluid, no blockage) |
| As | a shallow hill | normal | under 0.3 | stiff (otosclerosis-like) |
| Ad | a skyscraper | normal | over 1.7 | very floppy |
| B | flat, no peak (under 0.1 mL) | none | none | read with the canal volume: tiny (under 0.6 mL, `TYMP_BLOCKED_ECV`): wax or the probe against the canal wall ("blocked"); normal (0.6-2.0 mL, the adult band): fluid behind the eardrum; large (over 2.0): a hole in the eardrum or an open ear tube. Compare with the other ear. (`CaseRules.tymp_b_reading`, `ecv_band`) |
| C | a mountain moved left | below -100 daPa | normal | negative pressure (Eustachian tube) |

The shaded box is the normal range (-100 to +50 daPa, 0.3 to 1.7 mL, compensated). Ear canal volume is printed
beside the curve with a chip (TINY / NORMAL / LARGE), the caption "Adult canal: about 0.6-2.0 mL" (BSA's lower edge: many women's canals are 0.7-0.9 mL) and "226 Hz probe tone" by the name. After
the question, a flat ear gets a ribbon: "FLAT + TINY CANAL = BLOCKED", "FLAT + NORMAL CANAL = FLUID?" or "FLAT + BIG
CANAL = HOLE?" (only after the answer, so it never gives it away).

1. Pick the ear tip for the canal the otoscope showed (narrow = small, average-sized = medium, roomy = large).
   Too small: "hisss, LEAK!"; too big: "it won't go in"; the right one seals with a "pop".
2. Right then left curve draw themselves (red, blue).
3. The question. Rocco: "What type are both of Rocco's tympanograms?" (A / B / C, shuffled). The others ask the patient's own worry: Marina
   "Her ear feels full. Is it fluid behind the eardrum?"; Dash "Dash says it's wax. Does the tymp agree?";
   Ginger "Is her middle ear the problem?"; Barnaby "His right is flat. What does the canal volume say?" (blocked /
   fluid / a hole); Skye "Skye says it just needs a good pop. What does the tymp say?" (fluid / a peak moved left,
   type C / a wax plug). Across the two days the player meets every reading of a flat tymp, from both sides.
4. Medal `tymp`: gold = the right tip and the right answer first time; silver = one slip (tip or answer); bronze =
   more.

Days 6-9 are type A both ears: the eardrums move normally, so no fluid and no blockage. A stiff middle ear can
still hide behind a type A, so the bone test decides (Hoot: "Type A both sides: no fluid, no blockage. The bone test
will tell us if it's deeper."). Barnaby's right is B with a tiny canal (0.4 mL: blocked) and Skye's left is B with a
normal canal (1.1 mL: fluid). The retest rechecks Barnaby's tymp: right A, and the canal volume jumps to 1.6 mL.

## 6. The shape comes alive (after the player names it)

| Case | On the chart | Hoot |
|---|---|---|
| Rocco | a crash cymbal drops into the 4k dip with a "TSSSH!", an arrow shows the 8k recovery | "Dip at 4k, back up at 8k: a noise notch. It points to years of loud sound." |
| Marina | a wave rolls over the low pitches; her spring test is dashed above today's with the drops marked | "Low pitches about 25 dB worse than spring, and she has good days: hearing that comes and goes." |
| Dash | an alarm clock rings next to his right-ear line, the ring coming out of one side only (he woke up to it in one ear); the corner hours clock rings too | "Right ear needs 40 to 60 dB, left ear normal. One ear, overnight." |
| Ginger | a giant cookie takes a CHOMP out of the middle pitches; the chart from nine years ago is dashed behind | Chip: "Hey, that's MY look!" Hoot: "Worse in the middle, better at both ends: a cookie bite! These often run in families." |
| Barnaby | the gap pattern: bridge posts from bone up to air with the gap in dB, the left ear fades, the gap shades in, red dots on the 15+ posts at 500 / 1k / 2k, and a lumpy waxy cork with a wick slams into the gap (THUNK) with a "PLUGGED! ~25 dB" sticker (the measured average gap) | "Bone near normal, air about 25 dB worse: an air-bone gap. Sound is stuck at the door." |
| Barnaby's retest | the new chart flies up; the first visit's right air is dashed behind it ("WITH WAX") with mint "+25" arrows; title UNPLUGGED! | Barnaby: "The BEES! I can hear the bees again!" |
| Skye | the gap pattern filled with water: bubbles rise, a rubber duck bobs at the waterline, "BLUB! ~25 dB" | "Bone near normal, air about 25 dB worse: an air-bone gap, full of bubbles." |
| Morgan | the shadow: the right ear's unmasked answers come back as a dashed line of open circles (the chart hides them under the masked marks), the left ear's shape just louder, above the no-response arrows; the Ghost floats up beside it with a "SHADOW" sticker | "Dashed: the shadow. The left ear heard those beeps across the head." |
| Bev | the gap pattern on both ears (neither fades): the gaps shade in, red dots on the 15+ posts, and the stirrup, the tiniest bone, drops into the gap; a padlock snaps onto its footplate, "STUCK! ~35 dB" | "Bone near normal, air far worse: an air-bone gap in BOTH ears." |

Before the answer, Hoot only asks: "Here's the chart. What shape do you see?" (Dash: "One ear down overnight.
Now: where did the masked bone land?"; Morgan: "Masked, the right ear shows only arrows. Yet unmasked, it answered you!"). Morgan's
audiometry lines stay a suspicion ("Is that really the right ear hearing? Masking will tell."); the engine's own
Ghost tip (E4's `cross_hearing_air`, once per visit) does hint at the answer during the test, so the evidence question
is partly a recap there. No title, line or card names the answer before the player does.

## 7. Decisions and clues (the full lines are in `docs/CASE_SCRIPTS.md`)

The rule (`CaseRules.DECISIONS`): **fit** = no red flag and no asymmetry, and a loss hearing aids can help (+
counselling, hearing protection); an asymmetry with a known cause, already checked by an ear doctor and unchanged, is
a fit too (Steve's rule; Morgan, `decision.asymmetry_known_cause`). **refer** = any red flag or asymmetry with no known cause that is not an emergency: a doctor
soon (days to about two weeks), before any fitting (not same-day). **today** = sudden hearing loss (came on over 72 hours or less, within
the last 30 days) not explained by wax or the middle ear; it overrides refer. A sudden loss longer ago than that is
an urgent refer.

| Case | Proof cards (any one) | Tempting wrong cards, with their own replies |
|---|---|---|
| Rocco: why is it safe to fit? | No pain, drainage, dizziness or sudden change; Both ears match; Both ears, about the same | the noise years, "lost in noisy pubs" (why he wants aids, not why it's safe), the notch, the exam and chart cards (credited: they clear wax, drainage today, deformity and an air-bone gap; past drainage, pain, dizziness and sudden change need the red-flag check) |
| Marina: why a doctor first? | Room-spinning spells; Left ear only; Hearing comes and goes; Low pitches 25 dB worse than spring; her full roaring left ear; the roar | "Last spell 10 days ago; good days since" (that's why it's not TODAY), the normal exam cards, no cold |
| Dash: why TODAY? | Right ear went overnight; Pop, then whooshing 30 hours ago; First time ever; Right ear down, bone too; Wobbly yesterday (its own line: dizzy with a sudden loss is another red flag) | no wax, type A (they rule out a plug, not the rush), the cotton bud, no pain, his good left ear |
| Ginger: her dad and grandma have it too; why is it still safe to fit? | No pain, drainage, dizziness or sudden change; Both ears match; Both ears, about the same; Found at school, the same ever since; Right ear matches nine years ago | the family card ("That's family history, not a red flag"), the exam and chart cards (credited, as for Rocco), the complaint and the shape |
| Barnaby: what shows something is blocking the sound? | the wax plug; flat tymp, tiny canal volume; the gap card ("bone normal, air down"); the gap of 15+ at 500, 1k and 2k | his wallet (why he WANTS aids), the cotton buds (how it got packed in), "sudden" (the wax explains it), "one ear only" (a reason for a doctor, not what shows the sound is blocked) |
| Skye: what shows the trouble is in the middle ear? (her normal bone is why it's this week, not today, and Hoot's lines say so) | flat tymp, normal canal volume; the dull amber drum; the gap card ("bone normal") | her Friday flight (her deadline, not an emergency), "after a cold" (a cold can come before an inner-ear loss too), the 15+ gap card (mixed losses have gaps too), one ear only |
| Morgan: why can Morgan be fitted without a referral? | the ear doctor's letter (mumps, checked, no change); no change in the right ear since childhood | the deaf right ear (the problem, not the reason), where the trouble is (what the aid helps), the shadow and no-response cards (how it was found), "right ear only" (usually a REFER), the red-flag sweep, the exam cards, the earmuffs |
| Bev: what sends Bev to an ear doctor first? | the gap card ("both ears: bone near normal, air down"); the gap of 15+ at 500, 1k and 2k | her mum's operation (helps the doctor think), better in noise (a clue to what, not the red flag), the purple ? card ("the test's limits, not her ears'"), the As tymps, matching ears, the clear red-flag check |

Counselling that ships: Rocco's payoff opens with why he is a FIT and not a "not yet" ("We fit because his hearing
trips him up at the pub." "Same chart, no trouble yet? Counsel, earplugs, and a recheck in a year.", clinical review
C14). Every FIT checks words before the call (beat 6b), and the payoff points at the fitting's own check: Rocco
"At the fitting, a tiny mic in his ear checks the aids hit their target.", Ginger "At the fitting we measure in her
ear, then score words again with the aids on." Marina's referral says why a one-sided loss sees a doctor: "Now and
then the hearing nerve is to blame. A doctor checks, sometimes with a scan." (C13). Rocco, aids help though noisy pubs stay tricky; aids often make ringing less
noticeable; the damage so far is permanent, more is
preventable; earplugs at every gig and rehearsal; filtered musicians' earplugs (a filter turns pitches down more
evenly than foam); on stage aids out, earplugs in; a yearly test; and Hoot's tinnitus lesson in the instructions (pulsed or warble
beeps stand out from a ringing ear, a steady tone hides; clinical review C8), with a short tip for Marina's roar. Marina, an ear doctor appointment this week, not someday; the safety net ("Hearing drops and doesn't come
back? Doctor that day. Weakness, numbness, double vision or slurred speech? Emergency!"); aids may help between spells once a doctor has looked; her first mate takes the wheel
until a doctor clears her. Dash, same day to an ENT, audiogram sent ahead ("No ear doctor free today? Then the
emergency department. Same day, either way."); face droop, numbness, slurred speech or double vision mean the ER now; "Sooner is better. Doctors still treat after three days, but today beats tomorrow." Ginger,
aids tuned for the middle pitches; offer a routine genetic counselling referral alongside (not before) the fitting;
a yearly test, since some family patterns slowly change. Barnaby, a note for the doctor (wax plug, right ear, bone
normal); softening drops for a few days, then a gentle rinse or suction; no cotton buds, hairpins or ear candles
("they don't clean anything, and they can burn"); pain, drips or dizziness before then mean a doctor that day; after
the retest, "if it hadn't come back with the wax out, the doctor would look deeper" and "some ears just make lots of
wax". Skye, an ear doctor this week; in grown-ups, one-sided fluid gets a doctor's look, back of the nose too; it
often clears by itself, or the doctor can drain it; ask the doctor before flying; pain, fever, drips, dizziness or
worse hearing mean a doctor that day; once it clears, a retest, and back to the doctor first if it's still down.
Morgan, a CROS: a microphone on the right sends that side's sound to the left ear; it helps at dinners but can't tell
where the foghorn is ("Direction takes two hearing ears"); guard the left ear (earmuffs, a yearly test), and if the
left ear ever changes, come straight back. Bev, a letter to the ear doctor (gaps in both ears, stiff eardrums, her
mum's history); the doctor checks the tiny bones that carry sound; hearing aids often work very well for this, and
some people choose an operation; Carhart's notch named; doctor first, then back here to choose.

## 8. Clinical rules (`CaseRules`, teaching defaults for Steve to check)

| Rule | Value |
|---|---|
| Decisions | see section 7; refer = soon, days to about two weeks; today = the same day; an asymmetry with a known, doctor-checked, unchanged cause is a fit (`decision.asymmetry_known_cause`; a test keeps every other FIT symmetric) |
| Red flags (US FDA prescription hearing aid labeling, 21 CFR 801.422, since October 2022: advise a doctor, preferably an ear specialist, before fitting) | a visible deformity of the ear, from birth or injury; fluid, pus or blood from the ear in the last 6 months; ear pain or discomfort; a lot of wax, or something in the canal; dizziness, recent or long-standing; sudden, quickly worsening or fluctuating hearing loss in the last 6 months; hearing loss or ringing in only one ear, or a clear difference between the ears; an air-bone gap of 15 dB or more at 500, 1000 and 2000 Hz. The 2022 OTC rule removed the old requirement that adults get a medical evaluation or sign a waiver before buying; the red flags remain dispenser guidance and good practice. Under-18s still see a doctor first, and some states still require referral. |
| Asymmetry (the measurable "difference between the ears") | 15 dB or more between the ears at two or more neighbouring test frequencies (`is_asymmetric`) |
| Sudden loss | 30 dB or more at 3+ neighbouring frequencies, coming on over 72 hours or less (`SUDDEN_ONSET_MAX_H`: the definition, not a deadline). Same-day referral: an ENT, or the emergency department if no ENT can see them today, with the audiogram. Treatment works best when it starts early, but doctors still treat for weeks, so a late patient still goes TODAY. Hoot says the definition on Dash's day: "Sudden means over three days or less. Within a month, no wax or fluid to blame? Doctor today." (NICE NG98, 1.1.2: a sudden loss not explained by an outer or middle ear cause). |
| The hours clock | "SINCE IT STARTED 30 h 05 min", counting up in real (unscaled, unpaused) minutes, captioned "Sooner is better". No 72 h mark, no bar, no "too late". |
| Tympanogram normal box | peak pressure -100 to +50 daPa, compensated peak 0.3 to 1.7 mL; adult canal volume about 0.6 to 2.0 mL (BSA's lower edge) |
| Canal volume with a flat tymp | under 0.6 mL reads "blocked" (`TYMP_BLOCKED_ECV`); 0.6-2.0 "fluid"; over 2.0 "a hole". Every other type sits inside the adult band (`CaseData.validate`) |
| Bone order | one-sided cases: unmasked bone on the better ear only, then masked bone on the poorer ear wherever its air sits over that bone (Steve's convention, as on Day 2; `CaseData.validate` checks it) |
| Wax and the earphones | while the canal is full of wax, air goes through headphones, never a foam insert |
| No response (Day 12) | an ear past the dial: masked runs climb 5 dB with every noise step, never plateau, and store no response at the limit; a no-response stamp scores when the truth lies past the limit. The finding `shadow` shows when most of the ear's masked air stamps are no response where its unmasked air answered (on the truth tables: a dead ear whose other-ear bone plus the patient's phones attenuation is within the dial); `no_response` when every masked air stamp, and every masked bone stamp if run, is no response |
| Retest | a case's `retest` patient (`<id>_after.tres`) is the ear after treatment: the same bone, air back to bone. It belongs to no chapter and never starts a visit; the retest is unscored |
| Tympanogram curve (drawing only) | compliance(p) = peak / (1 + ((p - peak pressure) / half-width)^2), compensated (canal volume removed, as tympanometers display); half-widths A 37.5 daPa (tympanometric width 75), C 45, As 40, Ad 30; B is flat near 0 |

## 9. Scoring

- Audiometry scores as on Day 2 (every scored stamp on every sheet; Hoot's stamps are not scored).
- Medals: `history` (Chat), `tymp` (Tymp), `evidence` (Pattern), `decision` (Call). Gold 10 / silver 6 / bronze 3
  coins. `decision`: gold = right stamp and right clue first time; silver = one slip; bronze = more.
- Visit flags: `case_id`, `decision_first` (the first stamp), `decision` (the right call), `decision_tries`,
  `clue_tries`, `tymp_tip_tries`, `asked_red_flags`; with a retest, `retested` and `retest_type` (the measured type).
- The retest is a victory lap: no medal, its stamps unscored. `finish_visit` runs before it, so a player who quits
  during the retest keeps the day; afterwards the first visit's results come back, and any comfort heart lost during
  the retest is given back. Its chart keeps the first visit's bone on
  the retested ear, so air can be seen climbing back to it.

## 10. Open questions for Steve

1. Rocco: a 4k notch to 65-70 dB, 2k at 40-45, PTA 26.7 / 30 but a 2-4k average of 53.3 / 58.3, and trouble
   following talk in a noisy pub: a clear "fit", or "fit or monitor"? (The game says fit, plus earplugs.)
2. Marina: REFER (soon: an ear doctor this week) rather than DOCTOR TODAY, since her hearing dips with spells and
   comes back, her last spell was ten days ago, she is steady today and she has no new drop that has stayed down?
   Is "fluctuating loss" being a red flag (2022 list) the right framing for players?
3. Dash: "same day: an ENT, or the emergency department if no ENT can see him today; send the audiogram"?
4. Ginger: FIT today for a known, stable, symmetric hereditary cookie bite in an adult, with a routine
   genetic-counselling referral offered alongside the fitting and a yearly audiogram? And the asymmetry rule (15 dB
   at two neighbouring frequencies), or another you prefer?
5. The red-flag wording above (2022 labeling), and "see a doctor first" as the game's phrase.
6. Tympanometer: should cases also show acoustic reflexes?

**Batch 2 (Days 10 and 11):**

7. Barnaby, testing through wax: Hoot says "Usually wax comes out before testing. Today we'll measure first, to see
   its toll," runs a full masked audiogram and a tymp before removal, and retests afterwards. Is "chart it, then
   compare" acceptable teaching, or should the case refer first and test only after removal?
8. A type B with a 0.4 mL canal volume on an occluded canal: the right teaching picture? Many clinicians skip the
   probe with a complete impaction.
9. Phones, not inserts, while wax is in the canal ("they go deep, and could push the wax further"): agree?
10. Who removes wax: "out by a doctor or trained clinician" (the clinical review's default), with "softening drops
    for a few days, then a gentle rinse or suction". Scope varies by state and some dispensers and audiologists remove
    wax. Is REFER the right single answer under the FDA "a lot of wax" flag, and is "or trained clinician" enough said
    about scope?
11. Sudden plus wax: muffly for months, then all at once in the shower; a visible plug; normal masked bone. Is "The wax
    explains the sudden block, and his bone is normal. Soon, not today." safe wording?
12. The retest: "a week later" (drops for a few days first, per the clinical review) and a full return to normal at 61 (air within 5 dB of bone), or should
    a residual show? And is a flat 35-40 dB conductive loss (a 25-30 dB gap) from a complete plug plausible?
13. Barnaby's counselling ("Nothing smaller than your elbow goes in your ear!", the ear-candle line, "Some ears just
    make lots of wax", "If it hadn't come back with the wax out, the doctor would look deeper"), the prediction rule
    ("take away the plug and air climbs to bone") and the clue pick (the plug, the tiny-volume tymp, the gap cards
    prove it; "one ear only" and "sudden" don't).
14. Skye: REFER, "a doctor this week, before Friday's flight", with "In grown-ups, fluid on one side gets a doctor's
    look, back of the nose too"? Does "Bone's normal: middle ear, not inner ear. Soon, not today."
    rightly rule out inner-ear barotrauma, and does "an ache with the cold, gone now" count as the FDA "pain" flag?
15. Skye's picture: a flat 30-40 dB conductive loss, a B with a 1.1 mL canal, a dull amber drum with bubbles and a
    fluid line, no cone of light. Consistent, or would a resolving effusion more often be type C? And the quiz option
    "Just pressure: a peak moved left" (type C) as the answer to "it just needs a pop"?
16. Skye's flight and safety net ("Ask the doctor before you fly", "Pain, fever, drips, dizziness, or hearing getting
    worse? See a doctor that day"; fever is not on the FDA list), "It often clears by itself. If not, the doctor has
    ways to drain it", and the outer / middle / inner question with the decoy "a cold can come before an inner-ear
    loss too".
17. The canal-volume band: 0.6-2.0 mL printed as the adult band (the clinical review's default, question 10 there),
    and a flat tymp below 0.6 read as "blocked"?
18. Masking: unmasked bone on the better ear only, then masked bone on the case ear at 500-4k with full plateaus
    and no masked air (phones; inserts for Skye). Red cards: the 15+ gap card and "one ear only" in both cases, and wax at otoscopy: worth it,
    or too many red cards?
19. Follow-up wording for Days 6-9: Hoot's tinnitus lesson for Rocco and Marina's tip (pulsed or warble, never a
    steady tone near the ring; some clinics prefer warble; section 3, row 5), "Filtered musicians' earplugs" with "A filter turns pitches down more evenly
    than foam", and the wrong-first-stamp headlines for all six cases (`docs/CASE_SCRIPTS.md`, The Daily Decibel).

**Advanced cases (Day 12; ADVANCED_CASES.md questions 1-2, defaults stand):**

20. Morgan: FIT with a CROS for an old, explained, doctor-checked dead ear (the "one ear only" card reads as a clue,
    not a red flag, because the letter explains it), or REFER anyway? And the CROS counselling: helps at dinners, no
    direction, guard the left ear, a yearly test, come straight back if the left ear changes.
21. Morgan's real interaural attenuation, phones 50 / inserts 70, so the shadow sits around 55-70 with phones (75-90
    with inserts); and masked bone before masked air, both climbing to no response at the limit.

**Day 13 (ADVANCED_CASES.md questions 3-6; defaults stand):**

22. Bev's numbers (section 2.8): otosclerosis-like, Carhart's notch at 2k, As tymps, gaps 45 / 45 / 20 / 20, changed
    from the first draft so inserts make room at 2k and 4k. REFER, with "aids often work very well; some choose an
    operation; the doctor first", and Hoot names Carhart's notch in the payoff: keep or cut?
23. Hoot's inserts lent for the visit when the dilemma first shows and none are owned (the default), or should the
    day need the upgrade?
24. The purple ? stays at 500 Hz and 1 kHz with inserts, bone and (after headphone air) masked air: none of those
    ends fully masked. Masked air through the lent inserts on headphone-measured air: fine, or should Hoot re-measure
    unmasked air through the inserts instead?
25. The proof card: the gaps (and the 15+ gap red flag). The design accepted "plateau not reached" as support; it is
    a wrong pick here ("Those ? marks show the test's limits, not her ears'"). Agree?
26. ~~A short dilemma movie stays a later follow-up.~~ Done: Hoot's "The Masking Dilemma" plays on Day 13 before
    the loan (section 2.8). Its captions and numbers (headphones 40, inserts 55, 65 vs 50 at 1k, 55 to 75 at 2k):
    keep or change?

**Words before a FIT (clinical review C13 and A4; defaults stand):**

27. Hoot's words check (SRT and a word score in each ear, then one Party Noise Test list, at Hoot speed, before the
    call) runs on the two FIT cases only, Rocco and Ginger (the default). Should every case day run it ("speech in
    noise on every test"), or the REFER days skip it as they do now? Dash's same-day doctor and Barnaby's wax would
    skip it in clinic too.
28. Morgan (FIT with a CROS) has no words check yet: a word score on the hearing left ear only (a CROS needs a strong
    one) plus the Party Noise Test, which through headphones may read near-normal (a dead ear's trouble in noise
    is about where the talker sits). Add it, or leave Morgan's day as it is (the default)?
