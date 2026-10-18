# Booth Camp: Case Files (Days 6 onward)

Design for the patient cases. Each case is one patient with one condition, played as its own day from the
chapter select. The player gathers clues (history, otoscopy, a tympanogram, the audiogram) and makes the
call: **FIT** hearing aids, **REFER** to a doctor first, or **DOCTOR TODAY** (same-day urgent referral).
Contract additions are in `CONTRACTS.md` §11 (cases). Steve reviews every clinical number and line.

| | |
|---|---|
| Teaches | reading clues; red flags; audiogram shapes; tympanogram types; comparing with old charts; the fit / refer / doctor-today decision |
| Length | target 8-9 minutes per case with "quick visit" on (the default); see the budget in section 4 |
| Opens | from the chapter select, any order, every day open from the start (`requires` is only a "suggested next" badge; until the main thread removes chapter 2's day locks, "Unlock all days" opens them). The first case a player opens starts with Hoot's one-line Case Files briefing. |
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
| 10 | `wax` (batch 2) | to come after chapter 2 merges | Wax impaction: conductive, retest after removal | refer for removal, retest |
| 11 | `fluid` (batch 2) | to come | conductive (Bonnie already teaches otosclerosis on Day 2) | REFER |

Day numbers start at 6 because the speech chapters take Days 3-5. Chapter ids are the patient ids, like `gus` and
`bonnie`: `rocco`, `marina`, `dash`, `ginger`. No acoustic-neuroma case: the speech chapters' Day 4 patient (Nora)
already teaches "one-sided loss with poor words: refer before fitting".

**Day picker text** names the person or the joke, never the pattern, condition or call (28 characters or fewer):
rocco "Case file: ringing ears", marina "Case file: the ferry captain", dash "Case file: the pizza rush", ginger
"Case file: the ventriloquist".

**Each case has a beat only it has:** Rocco picks the drummer's earplugs (cotton wool / foam / musicians'); Marina
compares today with her spring test and her referral letter folds into a paper boat that sails to a lighthouse
marked EAR DOCTOR; Dash's hours clock counts up in the corner the whole visit and Hoot phones the ear doctor;
Ginger's puppet Chip heckles (her lips don't move), her nine-year-old chart proves the loss is stable, and her
family history is the tempting wrong clue.

## 2. Truth tables (dB HL; bone = air: these are all sensorineural)

Frequencies 250, 500, 750, 1k, 1.5k, 2k, 3k, 4k, 6k, 8k. All four use the default real interaural attenuation
(phones 60, inserts 75, bone 0), so no unmasked AIR reading is ever a cross-heard shadow, but every unmasked BONE
reading on a poorer ear is the better cochlea answering (the Ghost from Day 2), so the runner adds masked bone
wherever the rules ask. Every shape below survives any single 5 dB wobble (`story/tests/test_cases.gd`).

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
  side and no masking is needed. The runner types the left ear from this reading too (`_borrow_bone`).
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
- Unmasked bone on the left reads her RIGHT cochlea (about 10 / 5 / 10 / 15 at 500 / 1k / 2k / 4k): false gaps at
  500, 1k and 2k, so masked bone runs there and lands on the air values (no real gap).
- Masked air: the rule (left air - 40 >= the right cochlea's bone estimate) asks for it at 250 and 1k, each exactly
  on the line, so a 5 dB wobble can drop one; the runner follows the stamped values. It confirms 50 / 45.
- Last spell ten days ago; steady today; no sudden drop in the last three days. Tinnitus: left, a low roar, louder
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
- Unmasked right bone reads the LEFT cochlea; masked bone lands on the air values (45 / 55 / 55 / 55 at 500-4k,
  10 dB under the oscillator's limit at 4k and under the 500 Hz "felt" line).
- Masked air by the rule from 1k up (not at 250 or 500: 40 - 40 and 45 - 40 are below the left ear's 10). It
  confirms the unmasked values: his real phones IA is 60.
- A bit wobbly yesterday, fine now (dizziness: a red flag too). No face droop, numbness, slurred speech or double
  vision. Tympanograms: A both (tip medium). Otoscopy: clear, no wax (he was sure it was wax).

### 2.4 Ginger (cookie bite, symmetric)

| Hz | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| Right air (O) | 15 | 20 | 30 | 45 | 50 | 50 | 40 | 25 | 20 | 15 |
| Left air (X) | 15 | 25 | 35 | 45 | 50 | 55 | 45 | 30 | 25 | 20 |
| Right air, nine years ago (on file) | 15 | 20 | | 40 | | 50 | | 25 | | 15 |

- Shape `cookie_bite` both ears: the middle (1k-2k) 25-27.5 dB poorer than 500 Hz and 20-22.5 dB poorer than 4-8k.
- Ears within 5 dB: symmetric. Bone: Hoot, right mastoid, unmasked: it matches BOTH ears' air (it is the better
  cochlea, so the left gap can only be smaller), so no masking, and both ears read sensorineural.
- Her dad and his mum (Grandma Snapp) have the same pattern: one family line, three generations. School hearing
  tests found it; the chart from nine years ago is within 5 dB of today: stable.
- PTA: right 38.3, left 41.7. Tympanograms: A both (tip small, a narrow canal).

## 3. Beat by beat (one runner for every case)

Every choice (history questions, the tymp question, the shape question, the earplugs, the clue cards) is
shuffled with `Game.rng` (seeded by `--seed`, so autoplay stays reproducible); the solver's `best` follows the
shuffle. The stamp tray keeps its fixed order FIT / REFER / DOCTOR TODAY.

| # | Phase | What happens | Beat(s) |
|---|---|---|---|
| 1 | `intro` | First case ever: Hoot's briefing ("Case Files! Gather clues, then stamp it: FIT, REFER, or DOCTOR TODAY."). The patient's entrance gag and complaint (joke + real clue), Hoot's personal opener. The "always" clues go on the notes. | dialogue |
| 2 | `history` | Two rounds of three questions (2 / 1 / 0 points). The red-flag sweep always happens: if the player skipped it, Hoot asks it. Red-flag card, plus any extra cards the sweep reveals. Medal `history` (4 points gold, 2 silver). | choice |
| 3 | `otoscopy` | A quick look (`Otoscopy.show_clear`); the caption names the canal size (roomy / average-sized / narrow). Clue card. | dialogue |
| 4 | `tymp` | **The tympanometer gadget** (section 5): pick the tip for the canal the otoscope showed, both curves draw, then the patient's own question ("Her ear feels full. Is it fluid?"). Medal `tymp`. | choice |
| 5 | `instructions` | One line: the player tells the patient "press for every beep, even faint ones" (with the patient's joke), and the earphones go on. No mini-game in cases. | dialogue |
| 6 | `audiometry` | The case's test plan (section 4), then bone and the masked tests the rules ask for (Hoot; with Quick visit off the player runs them and Hoot's lines say so). The case's after-test line plays only when the measured bone ear agrees with the case; otherwise Hoot says a neutral line. | the AudiOtron's tone beats |
| 7 | `reveal` | The case board: the audiogram stamps in. Hoot: "What shape do you see?" | dialogue |
| 8 | `evidence` | The shape question (for Dash, the type of loss). Only after the right answer does the shape come alive with its title (section 6), with any chart on file joining it, dashed. Then the type badge (the patient's true type, like every line around it) and the chart's cards join the case file. Medal `evidence`. | choice |
| 9 | `decision` | Three rubber stamps: FIT / REFER / DOCTOR TODAY. A wrong stamp gets Hoot's reason and another try. Then "present the clue that proves it" from up to nine shuffled cards; each wrong card can have its own reply. Medal `decision`. | choice (stamp tray), choice (clue cards) |
| 10 | (payoff) | FIT: hearing aids pop on + counselling (Rocco also picks his earplugs). REFER: the letter folds into a paper boat. TODAY: Hoot phones the ear doctor and books this afternoon. The patient waves goodbye. | dialogue, choice |
| 11 | `results` | The Daily Decibel with the case's own headlines and medal row (Chat, Tymp, Pattern, Call). | results_continue |

The stamp tray and the clue cards emit the standard `choice` beat (same info as `DialogueBox.choose`), and their
buttons' text starts with the option text, so the autoplay bot plays them by keys and by mouse with no new route.

## 4. The test plan

Per case, `audiometry` in the JSON is a list of tests; the runner adds the masked follow-ups itself:

1. Air. One-sided cases (Marina, Dash): Hoot runs the better ear at x8 ("better ear first, like the pros"), then
   the player tests the poorer ear. Symmetric cases (Rocco, Ginger): the player tests the right ear first and Hoot
   runs the left at x8.
2. The player's ear: the player stamps the first N measurements, then Hoot finishes. The screen goes to the next
   required frequency after each store, and a half-octave joins as soon as its neighbours differ by 20 dB, so N
   counts those too. Rocco: right ear, N = 6 (1k, 2k, 4k, 3k, 8k, 6k: the 8k recovery stays the player's even if
   1.5k is also needed). Marina: left ear, N = 8 (the whole ear: 1k, 2k, 1.5k, 4k, 8k, retest, 500, 250). Dash:
   right ear, N = 3 (he's in a hurry). Ginger: right ear, N = 7 (1k, 2k, 4k, 3k, 8k, retest, 500: the bite's low
   edge is the player's).
3. Bone on the player's ear (Hoot). Rocco's and Ginger's unmasked bone sits within 10 dB of the air in both ears
   (no air-bone gap), so no bone masking is needed.
4. Masked bone where `ClinicRules.masked_freqs_needed(results, ear, &"bc_masked")` is not empty (Hoot).
5. Masked air where `masked_freqs_needed(results, ear, &"ac_masked")` is not empty (Hoot).

With "quick visit" off (`--full`), the player runs everything. Masking was taught on Day 2, so Hoot narrates it in
one line.

**Time budget** (target, quick visit): intro 0:30, history 1:15, otoscopy 0:15, tymp 0:40, instructions 0:10,
audiometry 2:30, reveal + evidence 1:15, call + clue 0:50, payoff 0:30, results 0:40 = 8:35. Autoplay runs
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
| B | flat, no peak (under 0.1 mL) | none | none | normal canal volume (0.9-2.0 mL): fluid behind the eardrum; small (under 0.9): wax or the probe against the canal wall; large (over 2.0): a hole in the eardrum or an open ear tube. Compare with the other ear. (`CaseRules.tymp_b_reading`) |
| C | a mountain moved left | below -100 daPa | normal | negative pressure (Eustachian tube) |

The shaded box is the normal range (-100 to +50 daPa, 0.3 to 1.7 mL, compensated). Ear canal volume is printed
beside the curve (adults about 0.9-2.0 mL).

1. Pick the ear tip for the canal the otoscope showed (narrow = small, average-sized = medium, roomy = large).
   Too small: "hisss, LEAK!"; too big: "it won't go in"; the right one seals with a "pop".
2. Right then left curve draw themselves (red, blue).
3. The question. Rocco: "What type are both of Rocco's tympanograms?" (A / B / C, shuffled). The others ask the patient's own worry: Marina
   "Her ear feels full. Is it fluid behind the eardrum?"; Dash "Dash says it's wax. Does the tymp agree?";
   Ginger "Is her middle ear the problem?".
4. Medal `tymp`: gold = the right tip and the right answer first time; silver = one slip (tip or answer); bronze =
   more.

Every case in this batch is type A both ears: the eardrums move normally, so no fluid and no blockage. A stiff
middle ear can still hide behind a type A, so the bone test decides (Hoot: "Type A both sides: no fluid, no
blockage. The bone test will tell us if it's deeper."). The conductive batch brings B (wax: small volume) and As.

## 6. The shape comes alive (after the player names it)

| Case | On the chart | Hoot |
|---|---|---|
| Rocco | a crash cymbal drops into the 4k dip with a "TSSSH!", an arrow shows the 8k recovery | "Dip at 4k, back up at 8k: a noise notch. It points to years of loud sound." |
| Marina | a wave rolls over the low pitches; her spring test is dashed above today's with the drops marked | "Low pitches about 25 dB worse than spring, and she has good days: hearing that comes and goes." |
| Dash | an alarm clock rings next to his right-ear line, the ring coming out of one side only (he woke up to it in one ear); the corner hours clock rings too | "Right ear needs 40 to 60 dB, left ear normal. One ear, overnight." |
| Ginger | a giant cookie takes a CHOMP out of the middle pitches; the chart from nine years ago is dashed behind | Chip: "Hey, that's MY look!" Hoot: "Worse in the middle, better at both ends: a cookie bite! These often run in families." |

Before the answer, Hoot only asks: "Here's the chart. What shape do you see?" (Dash: "One ear down overnight.
Now: where did the masked bone land?"). No title, line or card names the answer before the player does.

## 7. Decisions and clues (the full lines are in `docs/CASE_SCRIPTS.md`)

The rule (`CaseRules.DECISIONS`): **fit** = no red flag and no asymmetry, and a loss hearing aids can help (+
counselling, hearing protection). **refer** = any red flag or asymmetry that is not an emergency: a doctor
promptly, before any fitting (not same-day). **today** = sudden hearing loss (came on over 72 hours or less, within
the last 30 days) not explained by wax or the middle ear; it overrides refer. A sudden loss longer ago than that is
an urgent refer.

| Case | Proof cards (any one) | Tempting wrong cards, with their own replies |
|---|---|---|
| Rocco: why is it safe to fit? | No pain, drainage, dizziness or sudden change; Both ears match; Both ears, about the same | the noise years, "lost in noisy pubs" (why he wants aids, not why it's safe), the notch, the exam cards |
| Marina: why a doctor first? | Room-spinning spells; Left ear only; Hearing comes and goes; Low pitches 25 dB worse than spring; her full roaring left ear; the roar | "Last spell 10 days ago; no sudden drop in 3 days" (that's why it's not TODAY), the normal exam cards, no cold |
| Dash: why TODAY? | Right ear went overnight; Pop, then whooshing 30 hours ago; First time ever; Right ear down, bone too; Wobbly yesterday (its own line: dizzy with a sudden loss is another red flag) | no wax, type A (they rule out a plug, not the rush), the cotton bud, no pain, his good left ear |
| Ginger: her dad and grandma have it too; why is it still safe to fit? | No pain, drainage, dizziness or sudden change; Both ears match; Both ears, about the same; Found at school, the same ever since; Same bite as nine years ago | the family card ("That's family history, not a red flag"), the exam cards, the complaint and the shape |

Counselling that ships: Rocco, aids often make ringing less noticeable; the damage so far is permanent, more is
preventable; earplugs at every gig and rehearsal; musicians' earplugs; on stage aids out, earplugs in; a yearly
test. Marina, the safety net ("Hearing suddenly worse? Doctor that day. Weakness, numbness, double vision or
slurred speech? Emergency!"); aids may help between spells once a doctor has looked; her first mate takes the wheel
until a doctor clears her. Dash, same day to an ENT, audiogram sent ahead ("No ear doctor free today? Then the
emergency department. Same day, either way."); face droop, numbness, slurred speech or double vision mean the ER now; "Sooner is better. Doctors still treat after three days, but today beats tomorrow." Ginger,
aids tuned for the middle pitches; offer a routine genetic counselling referral alongside (not before) the fitting;
a yearly test, since some family patterns slowly change.

## 8. Clinical rules (`CaseRules`, teaching defaults for Steve to check)

| Rule | Value |
|---|---|
| Decisions | see section 7 |
| Red flags (US FDA prescription hearing aid labeling, 21 CFR 801.422, since October 2022: advise a doctor, preferably an ear specialist, before fitting) | a visible deformity of the ear, from birth or injury; fluid, pus or blood from the ear in the last 6 months; ear pain or discomfort; a lot of wax, or something in the canal; dizziness, recent or long-standing; sudden, quickly worsening or fluctuating hearing loss in the last 6 months; hearing loss or ringing in only one ear, or a clear difference between the ears; an air-bone gap of 15 dB or more at 500, 1000 and 2000 Hz. The 2022 OTC rule removed the old requirement that adults get a medical evaluation or sign a waiver before buying; the red flags remain dispenser guidance and good practice. Under-18s still see a doctor first, and some states still require referral. |
| Asymmetry (the measurable "difference between the ears") | 15 dB or more between the ears at two or more neighbouring test frequencies (`is_asymmetric`) |
| Sudden loss | 30 dB or more at 3+ neighbouring frequencies, coming on over 72 hours or less (`SUDDEN_ONSET_MAX_H`: the definition, not a deadline). Same-day referral: an ENT, or the emergency department if no ENT can see them today, with the audiogram. Treatment works best when it starts early, but doctors still treat for weeks, so a late patient still goes TODAY. |
| The hours clock | "SINCE IT STARTED 30 h 05 min", counting up in real (unscaled, unpaused) minutes, captioned "Sooner is better". No 72 h mark, no bar, no "too late". |
| Tympanogram normal box | peak pressure -100 to +50 daPa, compensated peak 0.3 to 1.7 mL; adult canal volume about 0.9 to 2.0 mL |
| Tympanogram curve (drawing only) | compliance(p) = peak / (1 + ((p - peak pressure) / half-width)^2), compensated (canal volume removed, as tympanometers display); half-widths A 37.5 daPa (tympanometric width 75), C 45, As 40, Ad 30; B is flat near 0 |

## 9. Scoring

- Audiometry scores as on Day 2 (every scored stamp on every sheet; Hoot's stamps are not scored).
- Medals: `history` (Chat), `tymp` (Tymp), `evidence` (Pattern), `decision` (Call). Gold 10 / silver 6 / bronze 3
  coins. `decision`: gold = right stamp and right clue first time; silver = one slip; bronze = more.
- Visit flags: `case_id`, `decision_first` (the first stamp), `decision` (the right call), `decision_tries`,
  `clue_tries`, `tymp_tip_tries`, `asked_red_flags`.

## 10. Open questions for Steve

1. Rocco: a 4k notch to 65-70 dB, 2k at 40-45, PTA 26.7 / 30 but a 2-4k average of 53.3 / 58.3, and trouble
   following talk in a noisy pub: a clear "fit", or "fit or monitor"? (The game says fit, plus earplugs.)
2. Marina: REFER (soon) rather than DOCTOR TODAY, since her last spell was ten days ago, she is steady today and
   she reports no sudden drop in the last three days? Is "fluctuating loss" being a red flag (2022 list) the right
   framing for players?
3. Dash: "same day: an ENT, or the emergency department if no ENT can see him today; send the audiogram"?
4. Ginger: FIT today for a known, stable, symmetric hereditary cookie bite in an adult, with a routine
   genetic-counselling referral offered alongside the fitting and a yearly audiogram? And the asymmetry rule (15 dB
   at two neighbouring frequencies), or another you prefer?
5. The red-flag wording above (2022 labeling), and "see a doctor first" as the game's phrase.
6. Tympanometer: should cases also show acoustic reflexes?
