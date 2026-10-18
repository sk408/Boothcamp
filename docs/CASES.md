# Booth Camp: Case Files (Days 6 onward)

Design for the patient cases. Each case is one patient with one condition, played as its own day from the
chapter select. The player gathers clues (history, otoscopy, a tympanogram, the audiogram) and makes the
call: **FIT** hearing aids, **REFER** to a doctor first, or **DOCTOR TODAY** (same-day urgent referral).
Contract additions are in `CONTRACTS.md` §11 (cases). Steve reviews every clinical number and line.

| | |
|---|---|
| Teaches | reading clues; red flags; audiogram patterns (noise notch, rising, flat one-sided, cookie bite); tympanogram types; the fit / refer / doctor-today decision |
| Length | 7-9 minutes per case with "quick visit" on (the default) |
| Opens | from the chapter select, any order (every chapter is open from the start) |
| Level scene | `res://story/level_case.tscn` (`story/level_case.gd`), one runner for every case |
| Case data | `story/cases/<case_id>.json` (story, clues, tymp, test plan, decision); patient truth in `core/patients/<id>.tres` |
| Rules | `core/cases/case_rules.gd` (`CaseRules`): decisions, red flags, asymmetry, tympanogram types and curve |

The game never diagnoses. Hoot says what the pattern "points to" and that a doctor decides ("a doctor may
check for..."). Clinicians in the game spot patterns and refer; doctors diagnose.

---------------------------------------------------------------------------------------------

## 1. The cases

| Day | Case id | Patient | Condition (never named as a diagnosis in play) | The call |
|---|---|---|---|---|
| 6 | `noise_notch` | Rocco "Thunder" Rimshot, 52, pub-band drummer | Noise-induced hearing loss, both ears | **FIT** (+ hearing protection) |
| 7 | `menieres` | Captain Marina Gale, 46, ferry captain | Ménière's-like: episodic vertigo, fluctuating low-frequency loss, left | **REFER** |
| 8 | `sudden` | Dash Delgado, 29, pizza courier | Sudden sensorineural hearing loss, right, yesterday | **DOCTOR TODAY** |
| 9 | `cookie_bite` | Ginger Snapp, 34, owns a cookie shop | Hereditary mid-frequency ("cookie-bite") sensorineural loss, both ears, stable for years | **FIT** |
| 10 | `wax` (batch 2) | to come after chapter 2 merges | Wax impaction: conductive, retest after removal | refer for removal, retest |
| 11 | `otosclerosis` or `fluid` (batch 2) | to come | conductive (Bonnie already teaches otosclerosis on Day 2, so fluid may fit better) | REFER |

Day numbers start at 6 because the speech chapters take Days 3-5. Chapter ids are the patient ids, like `gus` and
`bonnie`: `rocco`, `marina`, `dash`, `ginger`. No acoustic-neuroma case: the speech chapters' Day 4 patient (Nora)
already teaches "one-sided loss with poor words: refer before fitting".

## 2. Truth tables (dB HL; bone = air unless listed: these are sensorineural)

Frequencies 250, 500, 750, 1k, 1.5k, 2k, 3k, 4k, 6k, 8k. All four use the default real interaural attenuation
(phones 60, inserts 75, bone 0), so no unmasked AIR reading is ever a cross-heard shadow (each test ear stays
within 60 dB of the other ear's bone), but every unmasked BONE reading on a poorer ear is the better cochlea
answering (the Ghost from Day 2), so the runner adds masked bone wherever the rules ask.

### 2.1 Rocco (noise notch, symmetric)

| Hz | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| Right air (O) | 15 | 15 | 20 | 25 | 30 | 40 | 55 | 60 | 55 | 40 |
| Left air (X) | 15 | 20 | 20 | 25 | 35 | 45 | 60 | 65 | 60 | 45 |

- Shape `notch` both ears (`ClinicRules.classify_shape`): 3-6k floor 20 dB below 2k, 20 dB recovery at 8k.
- Ears within 5 dB everywhere: symmetric. Left a touch worse (the hi-hat side for a right-handed drummer).
- Bone (right, unmasked) = air: no gap anywhere, no masking needed. Type: sensorineural.
- PTA (500/1k/2k): right 26.7, left 30. Tympanograms: A both. Tinnitus: both ears, high pitch.

### 2.2 Marina (Ménière's-like, left, low frequencies)

| Hz | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| Right air (O) | 10 | 10 | 10 | 5 | 10 | 10 | 10 | 15 | 15 | 15 |
| Left air (X) today | 50 | 50 | 45 | 45 | 35 | 30 | 25 | 25 | 30 | 35 |
| Left air, spring screening (on file) | 25 | 25 | 20 | 20 | 15 | 15 | 15 | 20 | 25 | 30 |

- Left shape `rising` (low average 48, high average 30). Right normal.
- The spring screening (a good day) shows the low pitches 25 dB better: hearing that comes and goes.
- Unmasked bone on the left reads her RIGHT cochlea (about 10 / 5 / 10 / 15 at 500 / 1k / 2k / 4k), a false gap of
  40 / 40 / 20 / 10, so masked bone runs at 500, 1k and 2k and lands on the air values (no real gap).
- Masked air: the rule (left air - 40 >= right bone) asks for it at 250, 500 and 1k (borderline); the runner adds it.
- Tympanograms: A both.

### 2.3 Dash (sudden sensorineural loss, right)

| Hz | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| Right air (O) | 45 | 50 | 55 | 55 | 60 | 60 | 60 | 60 | 65 | 65 |
| Left air (X) | 10 | 10 | 10 | 5 | 10 | 10 | 15 | 15 | 15 | 20 |

- Right shape `flat` (moderate to moderately severe), left normal. Started yesterday morning (about 30 hours ago).
- Every right frequency needs masked air by the rule; masked air confirms the unmasked values.
- Unmasked right bone reads the LEFT cochlea; masked bone lands on the air values (50 / 55 / 60 / 60 at 500-4k,
  all inside the oscillator's range). Type: sensorineural. That is what makes it urgent: not wax, not fluid.
- Tympanograms: A both. Otoscopy: clear, no wax (he was sure it was wax).

### 2.4 Ginger (cookie bite, symmetric)

| Hz | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| Right air (O) | 15 | 20 | 30 | 45 | 50 | 50 | 40 | 30 | 20 | 15 |
| Left air (X) | 15 | 25 | 35 | 45 | 50 | 55 | 45 | 30 | 25 | 20 |

- Shape `cookie_bite` both ears: the middle (1k-2k) 25-30 dB poorer than 500 Hz and 17-20 dB poorer than 4-8k.
- Ears within 5 dB: symmetric. Bone (right, unmasked) = air: no gap, no masking. Type: sensorineural.
- Dad and Grandma have the same pattern; her school hearing tests found it and it has been stable since.
- PTA: right 38.3, left 41.7. Tympanograms: A both.

## 3. Beat by beat (one runner for every case)

| # | Phase | What happens | Beat(s) |
|---|---|---|---|
| 1 | `intro` | The patient's entrance gag and complaint (joke + real clue). Hoot's opener. The "always" clues go on the notes. | dialogue |
| 2 | `history` | Two rounds of three questions (2 / 1 / 0 points). If the red-flag question was skipped, Hoot asks it anyway (the red-flag sweep always happens). Red-flag card. Medal `history`. | choice |
| 3 | `otoscopy` | A quick look at both ears (`Otoscopy.show_clear`). Clue card. | dialogue |
| 4 | `tymp` | **The tympanometer gadget** (section 5): pick the ear tip, both curves draw, name the type. Medal `tymp`. | choice |
| 5 | `instructions` | One line ("You know the drill") and the earphones go on. No mini-game in cases. | dialogue |
| 6 | `audiometry` | The case's test plan (section 4): better ear first (Hoot at x8), then the player's ear, then bone and the masked tests the rules ask for (Hoot). | the AudiOtron's tone beats |
| 7 | `reveal` | The case board: the audiogram stamps in, then the pattern comes alive (section 6). | dialogue |
| 8 | `evidence` | "What does the audiogram show?" (the pattern, or for Dash the type of loss from the measured bone). Medal `evidence`. | choice |
| 9 | `decision` | Three rubber stamps on the case file: FIT / REFER / DOCTOR TODAY. A wrong stamp gets Hoot's reason and another try. Then "present the clue that proves it" from the clue cards. Medal `decision`. | choice (stamp tray), choice (clue cards) |
| 10 | (payoff) | FIT: hearing aids pop on + the counselling line. REFER: the referral letter. TODAY: Hoot phones the ear doctor and books this afternoon. The patient waves goodbye. | dialogue |
| 11 | `results` | The Daily Decibel with the case's own headlines and medal row (Chat, Tymp, Pattern, Call). | results_continue |

The stamp tray and the clue cards emit the standard `choice` beat (same info as `DialogueBox.choose`), and their
buttons' text starts with the option text, so the autoplay bot plays them by keys and by mouse with no new route.

## 4. The test plan

Per case, `audiometry` in the JSON is a list of tests; the runner adds the masked follow-ups itself:

1. Air, better ear (`hoot_turn_after` 0: Hoot runs it at x8). "Better ear first, like the pros."
2. Air, the ear in question: the player stamps the first N measurements, then Hoot finishes.
   Rocco N = 4 (1k, 2k, 4k, 8k: the player sees the 4k dip and the 8k recovery), Marina 7 (the whole ear, so the
   player finds the low-pitch loss), Dash 3, Ginger 6 (1k, 2k, 4k, 8k, the 1k retest and 500: the bite appears).
3. Bone on the ear in question (Hoot). Rocco's and Ginger's ears match, so their unmasked bone needs no masking.
4. Masked bone where `ClinicRules.masked_freqs_needed(results, ear, &"bc_masked")` is not empty (Hoot).
5. Masked air where `masked_freqs_needed(results, ear, &"ac_masked")` is not empty (Hoot).

With "quick visit" off (`--full`), the player runs everything. Masking was taught on Day 2, so Hoot narrates it in
one line: "Bone buzzes both cochleas. I'll keep the good ear busy with noise."

## 5. The tympanometer gadget (`story/games/case_tymp.gd`)

A chunky handheld "Tymp-O-Matic". It seals the canal, sweeps the air pressure from +200 to -400 daPa and draws how
easily the eardrum moves (a peak where it moves best). Teaching numbers (`CaseRules`):

| Type | Shape (game words) | Peak pressure | Peak (mL) | Means |
|---|---|---|---|---|
| A | a normal mountain | -100 to +50 daPa | 0.3-1.7 | the middle ear moves normally |
| As | a shallow hill | normal | under 0.3 | stiff (otosclerosis-like) |
| Ad | a skyscraper | normal | over 1.7 | very floppy |
| B | flat, no peak | none | flat | fluid; with a tiny canal volume, wax or the probe against the wall; with a big volume, a hole in the drum |
| C | a mountain moved left | below -100 daPa | normal | negative pressure (Eustachian tube) |

The shaded box is the normal range (-100 to +50 daPa, 0.3 to 1.7 mL). Ear canal volume shows too (adults about
0.9-2.0 mL).

1. Pick the ear tip (small / medium / large). Too small: "hisss, LEAK!"; too big: "it won't go in"; the right one
   seals with a "pop". The right size is per patient.
2. Right then left curve draw themselves (red, blue).
3. "What type is it?" A / B / C (later: As too). Gold for right first time, with the tip on the first try.

Every case in this batch is type A both ears: the lesson is "the middle ear moves normally, so the problem is
deeper: the inner ear or the nerve". The conductive batch brings B (wax: small volume) and As.

## 6. Reveal patterns (the "shape comes alive" moment)

| Case | On the chart | Hoot |
|---|---|---|
| Rocco | a firework bursts out of the 4k dip, "KA-BOOM!", with an arrow at the 8k recovery | "Dip at 4k, better at 8k: the noise notch. Loud sound did that." |
| Marina | a wave crashes over the low pitches; the spring screening draws as a faded dashed line above today's | "Her low pitches dropped 25 dB since spring. Hearing that comes and goes." |
| Dash | an alarm clock rings next to his right-ear line; the 72-hour clock on the board ticks | "One ear down overnight, bone down too. Sensorineural and sudden: the clock is ticking." |
| Ginger | a giant cookie takes a CHOMP out of the middle pitches, crumbs fall | "Worse in the middle, fine at both ends: a cookie bite! It often runs in families." |

## 7. Decisions, clues and lines

Decision options and what Hoot says for each pick. 18 words or fewer per Hoot line.

### 7.1 Rocco: FIT (+ protection)

- FIT (correct): "Both ears match, no red flags: hearing aids help. And earplugs for every gig!"
- REFER: "No red flags here: both ears match, no dizziness, no pain, nothing sudden. He can be fitted."
- DOCTOR TODAY: "Nothing sudden here: thirty years of cymbals, slowly. Today isn't an emergency."
- Present the clue ("Why is it safe to fit Rocco today?"): **No pain, drainage, dizziness or sudden change** or
  **Both ears match**.
- Counselling: noise damage is permanent but preventable; musicians' earplugs keep the music clear.

### 7.2 Marina: REFER

- REFER (correct): "Spinning attacks, a full roaring ear, hearing that comes and goes: an ear doctor should see her."
- FIT: "Dizziness is a red flag. Doctor first; hearing aids may help later, between attacks."
- DOCTOR TODAY: "Her spells come and go over months, and she's steady today. Soon, not today."
- Clue: **Room-spinning attacks for hours** (dizziness red flag), **Left ear only** or **Hearing comes and goes**.

### 7.3 Dash: DOCTOR TODAY

- TODAY (correct): "Sudden sensorineural loss is an emergency. Treatment works best early. Doctor TODAY!"
- FIT: "A hearing aid on a brand-new sudden loss? Doctor first, and today: treatment works best early."
- REFER: "A routine referral could take weeks. Sudden hearing loss can't wait: TODAY."
- Clue: **Gone overnight, yesterday** (sudden) or **Bone down too: not wax, not fluid**.
- The 72-hour clock: "hours since it started" on the board, from 30 at the start of the visit, ticking with game time.

### 7.4 Ginger: FIT

- FIT (correct): "Both ears match, stable for years, no red flags: hearing aids tuned for the middle pitches."
- REFER: "No red flags: no pain, dizziness or sudden change, and both ears match. She can be fitted."
- DOCTOR TODAY: "She's had this since school. Nothing sudden, so no emergency."
- Clue: **Both ears match**, **No pain, drainage, dizziness or sudden change** or **The same since school**.
- Note: a family pattern is worth a chat with a doctor or genetic counsellor some time, but it is not a red flag.

## 8. Clinical rules (`CaseRules`, teaching defaults for Steve to check)

| Rule | Value |
|---|---|
| Decisions | `fit`, `refer`, `today` ("FIT hearing aids", "REFER to a doctor first", "DOCTOR TODAY") |
| Red flags (paraphrased from the long-standing US dispenser list; check the post-2022 wording) | visible deformity; drainage in the last 90 days; sudden or rapidly worsening loss in the last 90 days; acute or chronic dizziness; sudden or recent one-sided loss; air-bone gap of 15 dB or more at 500, 1000 and 2000 Hz; lots of wax or a foreign body; ear pain |
| Asymmetry | 15 dB or more between the ears at two or more neighbouring test frequencies (`is_asymmetric`) |
| Sudden loss urgency | same-day referral; treatment works best when it starts early (the game's clock shows 72 hours) |
| Tympanogram normal box | peak pressure -100 to +50 daPa, peak 0.3 to 1.7 mL; adult canal volume about 0.9 to 2.0 mL |
| Tympanogram curve (drawing only) | compliance(p) = canal volume + peak / (1 + ((p - peak pressure) / width)^2), width 70 daPa (A, C), 55 (As), 90 (Ad); B is flat |

## 9. Scoring

- Audiometry scores as on Day 2 (every scored stamp on every sheet; Hoot's stamps are not scored).
- Medals: `history` (Chat), `tymp` (Tymp), `evidence` (Pattern), `decision` (Call). Gold 10 / silver 6 / bronze 3 coins.
  `decision`: gold = right stamp and right clue first time; silver = one slip; bronze = more.
- Visit flags: `case_id`, `decision` (the final stamp), `decision_tries`, `clue_tries`, `tymp_tip_tries`.

## 10. Open questions for Steve

1. Rocco: is a 4k notch to 60-65 dB with 2k at 40-45 and restaurant trouble a clear "fit" in your practice, or "fit or
   monitor"? (The game says fit, plus earplugs.)
2. Marina: REFER (soon) rather than DOCTOR TODAY, since she is between attacks and the loss has fluctuated for months?
3. Dash: same-day referral wording ("doctor today": ENT or urgent care / ER if ENT can't see him today)?
4. Ginger: FIT for a known, stable, symmetric hereditary cookie bite in an adult, with a doctor or genetics chat as
   a side note rather than a red flag? And the asymmetry rule the cases use (15 dB at two neighbouring
   frequencies), or another one you prefer?
5. The red-flag list wording after the 2022 OTC rule, and whether the game should say "see a doctor first" or
   "medical evaluation recommended".
6. Tympanometer: should cases also show acoustic reflexes?
