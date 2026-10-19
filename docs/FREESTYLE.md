# Booth Camp: Freestyle (the walk-in clinic)

Practice mode outside the story. The player runs their own clinic: a waiting room of walk-in patients, any test
in any order, then the call. No script and no coaching of the tests: Hoot only gives a one-line hint after a wrong
tympanogram or chart type, and debriefs at the end.
Steve checks every clinical call (section 8 is his checklist).

| | |
|---|---|
| Teaches | choosing the workup yourself: which history questions matter, look before you insert, when bone is needed, when masking is needed, reading the chart (type of loss per ear) and the call |
| Opens | the title's **Freestyle** button. Every walk-in is open; play any, any order, as often as you like, or press **Surprise me** |
| Scenes | `res://story/freestyle/waiting_room.tscn` (the hub), `res://story/freestyle/level_freestyle.tscn` (one runner for every walk-in) |
| Case data | `story/freestyle/cases/<id>.json` (the source of truth for every line that ships), patient truth in `core/patients/<id>.tres` |
| Rules | `story/freestyle/fs_rules.gd` (`FsRules`): the question deck, the workup, masking needs, the solver's pick, medals. Clinical numbers come from `ClinicRules` and `CaseRules` |
| Not chapters | freestyle patients are never in `Game.CHAPTERS`, never on the Days grid, and their ids start with `fs_` |

The game never diagnoses. Hoot says what a pattern "points to" and that a doctor decides.

---------------------------------------------------------------------------------------------

## 1. A visit, beat by beat

1. **Waiting room.** Cards for every walk-in: portrait, name and age, a one-line teaser in their own words,
   difficulty stars (1 to 3) and the best grade so far. **Surprise me** picks one at random. **Back** (or Esc) to
   the title; left alone for 90 s the room goes back to the title too (a booth display).
2. **Walk-in.** The patient walks to the desk and says why they came (`hello`). The first visit ever opens with
   Hoot's one-line briefing.
3. **The tool tray.** The player picks the next tool, any order, as often as they like:
   - **Ask questions**: the standard ten-question deck (section 4.1). Up to five questions per visit (the waiting
     room is full), so ask what matters. Each answer can add a note to the clipboard.
   - **Look in the ears**: the otoscope, right then left, with the canal size (it picks the tymp tip).
   - **Tympanometer**: pick the tip that seals, sweep both ears, name the type of each.
   - **Air tones**: pick which ear goes first, then air conduction on both ears.
   - **Bone conduction**: pick the mastoid, then unmasked bone (1k, 2k, 4k, 500).
   - **Masking**: pick a masked test (masked bone or masked air, right or left ear), or "No masking". Masking
     works from the air chart, so before air tones the player only gets "Air tones first!".
   - **Make the call**: ends the workup.
   The clipboard (left side) shows every note and every chart result so far; the chart card above the tray
   shows the audiogram once there is one. Done tools get a tick but can be run again. Every clinic choice (the
   tip, the tymp type, which ear first, the mastoid, the masked test, the chart type, the stamp) is a row of
   big buttons in the tray. Which ear, which mastoid and which masked test are asked at the desk before the
   booth, so the chart and the clipboard stay in view (the tympanometer's own choices sit under its screen).
4. **The chart.** "What type of hearing is in the RIGHT ear?" then the LEFT: normal, sensorineural, conductive,
   mixed. Wrong picks get Hoot's hint and another go (section 4.3).
5. **The call.** Four rubber stamps: **FIT**, **REFER**, **DOCTOR TODAY**, **NO AIDS NEEDED**. A wrong stamp gets
   the case's own line for that stamp, then another go. Then "Why?": pick a reason (some cases have more than
   one right reason).
6. **Debrief.** The **workup card**: what a pro would have run, in order, ticked or crossed against what the
   player did, with Hoot's line for each slip (section 4.5, up to four lines). Then Hoot's lines from the case.
7. **Goodbye** (the case's lines; a FIT puts the hearing aids on) and the **Daily Decibel** with the
   freestyle medals: Chat, Workup, Chart, Call. Its buttons go back to the waiting room (**Waiting room**) or
   play the same patient again.

Audiometry uses the normal AudiOtron, never coached. With **Quick visit** on (the default) the player stamps the
first three tones of each air ear and Hoot finishes at x8; bone runs as Hoot's montage and masked tests as Hoot's
x8 turn. With
Quick visit off the player runs everything.

## 2. Files

| File | What |
|---|---|
| `story/freestyle/fs_rules.gd` | rules: decisions, deck, tools, workup, masking needs, solver's pick, medals |
| `story/freestyle/fs_data.gd` | case loader and validator (`FsData.CASE_IDS` lists every walk-in, in waiting-room order) |
| `story/freestyle/waiting_room.gd/.tscn` | the hub |
| `story/freestyle/level_freestyle.gd/.tscn` | the visit runner |
| `story/freestyle/fs_tray.gd` | the tool tray, and the row of big buttons for every clinic choice |
| `story/freestyle/fs_questions.gd` | the question board |
| `story/freestyle/fs_clipboard.gd` | notes and results so far |
| `story/freestyle/fs_chart.gd` | the audiogram card above the tray, and the call's rubber stamp |
| `story/freestyle/fs_debrief.gd` | the workup card |
| `story/freestyle/cases/*.json` | the walk-ins |
| `core/patients/fs_*.tres` | their truth tables |
| `story/tests/test_freestyle.gd` | every case validates; the clinical calls hold against the truth, with 5 dB of wobble |

## 3. The case file

```jsonc
{
  "id": "fs_penny",                  // = the file name, starts with fs_
  "patient_id": "fs_penny",          // core/patients/<patient_id>.tres
  "speaker": "Penny",                // dialogue name, unique across the whole game
  "stars": 1,                        // difficulty on the waiting-room card, 1 to 3
  "teaser": "Her husband says she never listens. She says he mumbles.",   // 64 characters max
  "look": { ... },                   // same keys as a story case's look (portrait + clinic bean, docs/CASES.md)
  "voice": {"f0": 230.0, "wobble": 0.06, "roll": 0.64, "vowels": ["e", "i", "a"]},
  "hello": [["Penny", "..."]],       // walk-in lines: the complaint in their own words
  "answers": {                       // a reply to EVERY deck question (section 4.1)
    "which_ear": {"say": "Both the same, I think.", "note": "Both ears seem the same"},
    ...                              // say: a line or a list of lines; note: the clipboard note (48 chars max, "" = none)
                                     // optional "flag": true writes the note in red (a red flag the patient has)
  },
  "key_questions": ["red_flags", "onset", "noise", "hardest"],   // what a pro asks this patient (red_flags always, 5 max)
  "otoscopy": {
    "canal": "average-sized",        // narrow | average-sized | roomy -> small | medium | large tip
    "right": {"view": "clear", "caption": "Penny's RIGHT ear: ..."},
    "left": {"view": "clear", "caption": "..."},
    "note": "Canals clear, eardrums normal"
  },
  "tymp": {                          // what the tympanometer shows if the player runs it (always present)
    "right": {"type": "A", "peak_daPa": -10, "peak_ml": 0.8, "ecv_ml": 1.3},
    "left": {"type": "A", "peak_daPa": -5, "peak_ml": 0.9, "ecv_ml": 1.3},
    "note": "Tymp: type A both ears"
  },
  "needs_tymp": false,               // optional: overrides the workup's tymp rule (section 4.2)
  "decision": "clear",               // fit | refer | today | clear
  "decision_lines": {"fit": "...", "refer": "...", "today": "...", "clear": "..."},   // Hoot, when that stamp lands
  "why": {"prompt": "Why does Penny need no hearing aids?",
          "options": [["Every tone was 25 dB or better in both ears.", true, "Right! ..."], ...]},   // 3+, 1+ right
  "debrief": [["Hoot", "..."]],      // the teaching moment after the call
  "goodbye": [["Penny", "..."], {"react": "cheer"}],   // lines and actions ({"do": "hearing_aids"} for a FIT)
  "paper": {"headlines": {"S": "...", "A": "...", "B": "...", "C": "...", "Do-over": "..."},
            "subheads": {"S": "...", ...}}
}
```

House rules (checked by `FsData.validate` and `story/tests/test_freestyle.gd`): Hoot's lines 18 words max; every
deck question answered; tymp numbers read as the type they claim (`CaseRules.tymp_type_of`); why-options and
notes never start like a button (the mouse bot clicks by the first 18 characters); "no aids needed" exactly when
both ears are normal; each ear's type of loss survives every threshold moving 5 dB; no vendor names, logos or
word lists anywhere. Otoscope views on main: `clear` only (earwax and fluid views come with the conductive days).

Truth tables follow docs/CASES.md section 2 conventions, plus two freestyle limits so every tone is measurable:
air at least 10 dB under the audiometer's maximum, and bone at the required bone frequencies at least 5 dB under
the bone oscillator's maximum (`ClinicRules.BC_MAX_DB`: 500 Hz 60, 1k to 2k 70, 4k 65). No masking dilemmas
(no large conductive loss in both ears).

## 4. The workup a pro runs (`FsRules.workup`)

The debrief compares the player's visit with this list, built from the patient's truth (masking: from the
measured chart once it exists, so the list never asks for masking the player's own chart does not need).

| Step | Needed when | Why |
|---|---|---|
| Ask questions | always: the case's `key_questions`, red flags always | history first; red flags decide referrals |
| Look in the ears | always, before the tympanometer or any earphone | never put anything in an ear you have not looked in |
| Tympanometer | either ear conductive or mixed, or either tympanogram not type A (or the case's `needs_tymp`) | it tells a stiff, floppy or fluid-filled middle ear apart |
| Air tones | always | the chart |
| Bone conduction | any air threshold poorer than 25 dB HL | normal air rules out a conductive part; anything poorer needs bone to type it |
| Masked bone, per ear | that ear's air sits 10 dB or more above the unmasked bone (`ClinicRules.bc_masking_needed`) | unmasked bone reads the better cochlea, from either side |
| Masked air, per ear | air minus 40 dB (phones; 55 inserts) reaches the other ear's bone (`ClinicRules.ac_masking_needed`) | loud air tones cross the head |

### 4.1 The question deck (every walk-in answers all ten)

| id | Button |
|---|---|
| `which_ear` | Is one ear better than the other? |
| `onset` | When did it start: slowly, or all of a sudden? |
| `ringing` | Any ringing or buzzing in your ears? |
| `red_flags` | Any ear pain, drainage or dizziness? |
| `noise` | Any loud noise: work, music, hobbies? |
| `ear_history` | Any ear infections, surgery or injuries? |
| `family` | Does hearing loss run in your family? |
| `health` | Any medicines or health problems? |
| `aids` | Have you worn hearing aids before? |
| `hardest` | Where is hearing hardest for you? |

Five questions per visit (`FsRules.CHAT_BUDGET`); **Done asking** leaves early.

### 4.2 Which ear first

Air: the better ear first (by the patient's report; the debrief uses the true pure-tone average, and ears within
5 dB count as the same, so either is fine). Bone: on the better ear, the same rule (Steve's convention).

### 4.3 The chart question

Each ear's type is graded against the patient's truth (`ClinicRules.hearing_type`). When the player's own chart
types the ear differently (a few wandering stamps), the type their chart shows also counts, and Hoot says right
away what the ear really is ("Underneath, the left ear is a mixed loss: a few stamps wandered.").

One exception: a gap the chart asked to mask and nobody masked. When an ear's air sits 10 dB or more above
the unmasked bone and that ear has no masked bone, its reading does not count (the gap may be the other cochlea
answering). Picking it costs a Chart slip, and Hoot explains and names the true type. The workup card also
flags the missing masked bone.

### 4.4 The call

| Stamp | Means |
|---|---|
| **FIT** | hearing aids, no red flags |
| **REFER** | see a doctor before (or instead of) hearing aids: a red flag (`CaseRules.RED_FLAGS`), an air-bone gap, an asymmetry |
| **DOCTOR TODAY** | a sudden loss (`CaseRules` sudden definition) within the last 30 days: same-day referral |
| **NO AIDS NEEDED** | normal hearing in both ears and no red flag: counsel, baseline on file |

### 4.5 Slips (the workup medal and the debrief)

- a needed step not run (each one);
- a needed key question not asked (the chat medal; red flags count double);
- anything in an ear before looking in the ears: the tympanometer's probe, air tones' earphones or a masked
  test (bone conduction sits on the mastoid, so it does not count);
- the poorer ear first for air or bone when the ears differ by more than 5 dB.

Extra tests are never slips (tymp on a normal ear is routine, "NOTHING TO MASK!" answers an unneeded masking
run), but the debrief says when one was not needed and why.

## 5. Medals and score

| Medal | Gold | Silver | Bronze |
|---|---|---|---|
| Chat | every key question asked | one missed | more (or the red flags missed) |
| Workup | no slips | one | more |
| Chart | both ears right first time | one wrong pick | more (tympanogram types are not counted here: Hoot explains a wrong one on the spot) |
| Call | right stamp and a right reason first time | one wrong pick | more |

Score on the paper: 60 % medals (gold 100, silver 70, bronze 40) and 40 % the visit's audiometry score
(`Game.finish_visit`: accuracy, technique, efficiency, care). Coins as usual. The best freestyle grade per
walk-in is kept in the save (`progress.patients[<id>].fs_best_grade`) for the waiting-room card.

## 6. Hooks into shared code (all additive)

- `story/title_screen.gd`: a **Freestyle** button on the title menu, after Days. Options and Quit now share the
  last row (Up/Down and Left/Right walk the buttons in order), so a returning player's six buttons and stats
  still end above the safety footer.
- `story/case_portraits.gd`: `CasePortraits.register(who, look)` so walk-ins get portraits.
- `autoload/game.gd`: `PHASES` gains `freestyle_room`, `freestyle_tray`, `freestyle_chart`, `freestyle_debrief`.
- `story/daily_decibel.gd`: an optional summary `continue_text` (the main button's label; keep it short, the
  paper is 1280 px wide: freestyle uses "Waiting room").
- `tools/autoplay_bot.gd`: after the paper, `--mouse` clicks the summary's `continue_text` and waits for its
  `continue_scene`; `--via-freestyle` starts from the title's Freestyle button; the report gains `freestyle`.
- The waiting room hands its pick to the runner in the Engine meta `freestyle_next_case`; `--freestyle=<id>`
  wins (and is the bot's pick in the waiting room).

Not used: `Game.CHAPTERS`, the Days grid, `chapters_done`. The visit summary has `freestyle_case`,
`visit_score` (the audiometry score before the medal blend), `headlines`, `subheads`, `medal_beats`,
`continue_text`, `continue_scene`; visit flags `freestyle_case`, `freestyle_asked`, `freestyle_tip_tries`,
`freestyle_types`, `freestyle_tymp_misreads`, `freestyle_slips`, `decision_first`, `decision`, `decision_tries`.

Speech tests: the tray has a **Speech tests** tool reserved (`FsRules.SPEECH_SCREEN`); it stays hidden until
word scores land (Day 4), so no walk-in needs speech yet.

### 6.1 Commands

    # one walk-in, keys or mouse only, from the waiting room
    tools/autoplay_check.sh --scene=res://story/freestyle/waiting_room.tscn --freestyle=fs_penny [--mouse]
    # from the title's Freestyle button, like a player
    tools/autoplay_check.sh --via-freestyle --freestyle=fs_penny --mouse
    # Quick visit off (the player runs every tone): add --full

## 7. The walk-ins

Eight walk-ins, from easy to hard. Every call was checked against current guidance by a researcher and then by a
second, adversarial reviewer (sources under each case). Truth tables live in `core/patients/fs_*.tres`; what each
patient says is in `story/freestyle/cases/fs_*.json`.

| # | Walk-in | Stars | What it teaches | The call |
|---|---|---|---|---|
| 1 | Penny Natter, 41, podcaster | ★ | normal hearing: "never listens" is not always the ears; no bone needed | **NO AIDS NEEDED** |
| 2 | Mabel Shush, 74, retired librarian | ★ | the classic first fitting: slow, matching, sloping loss | **FIT** |
| 3 | Sid Sprocket, 45, bike mechanic | ★ | a lifelong, stable loss still gets the full workup | **FIT** |
| 4 | Dame Viola Vibrato, 68, retired soprano | ★★ | a bigger loss is not a red flag; old aids wear out; narrow canals | **FIT** |
| 5 | Buck Shotwell, 58, duck hunter | ★★ | an asymmetry is a red flag even with a good excuse; masked bone on the worse ear | **REFER** |
| 6 | Melody Belle, 36, music teacher | ★★ | a sudden loss in one ear is urgent with no pain; mask bone and air | **DOCTOR TODAY** |
| 7 | Skyler Kickflip, 19, skateboarder | ★★★ | a big air-bone gap and a floppy tymp after a knock | **REFER** |
| 8 | Hector Ticktock, 63, clockmaker | ★★★ | a mixed loss with a stiff tymp: masking shows the two parts | **REFER** |

### 7.1 Penny Natter, 41 (★☆☆): **NO AIDS NEEDED**

Waiting-room card: "Her husband says she never listens. She says he mumbles." Case `fs_penny`.

| dB HL | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| Right air | 10 | 10 | 5 | 5 | 5 | 10 | 10 | 15 | 15 | 10 |
| Left air | 10 | 5 | 5 | 10 | 10 | 5 | 10 | 10 | 20 | 15 |

Bone = air in both ears (no bone rows in the file).

- **Chart:** right normal (PTA 8, normal), left normal (PTA 7, normal). Asymmetric: no.
- **Look and tymp:** Canals clear, eardrums normal; average-sized canals (medium tip). Tymp right A (-10 daPa, 0.8 mL, canal 1.3 mL), left A (-5 daPa, 0.9 mL, canal 1.3 mL).
- **Key questions:** red_flags, onset, noise, hardest.
- **The workup a pro runs:** questions, then look in the ears, then air (either ear first).
- **The call:** NO AIDS NEEDED. Hoot: "Normal hearing in both ears! No aids needed. Her trouble is distance, not her ears." Right reason: "Every tone was 25 dB or better in both ears."
- **Hoot's debrief:** "Normal hearing is good news, not a wasted visit. Now there's a baseline for later." "Talking from another room fails for everyone. Face each other, get attention first." "And those loud earbuds: keep them at half volume, with breaks. Damaged hearing doesn't grow back."
- **Checked against:** [WHO grades of hearing loss (2021)](https://pmc.ncbi.nlm.nih.gov/articles/PMC11266198); [21 CFR 801.422, prescription hearing aid labeling (red flags)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-H/part-801/subpart-H/section-801.422).

### 7.2 Mabel Shush, 74 (★☆☆): **FIT**

Waiting-room card: "Forty years of shushing. Now the whole world whispers back." Case `fs_mabel`.

| dB HL | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| Right air | 25 | 30 | 30 | 35 | 40 | 45 | 50 | 55 | 60 | 65 |
| Left air | 25 | 30 | 35 | 35 | 40 | 45 | 55 | 55 | 65 | 70 |

Bone = air in both ears (no bone rows in the file).

- **Chart:** right sensorineural (PTA 37, mild), left sensorineural (PTA 37, mild). Asymmetric: no.
- **Look and tymp:** Canals clear, eardrums normal; average-sized canals (medium tip). Tymp right A (-15 daPa, 0.6 mL, canal 1.4 mL), left A (-10 daPa, 0.7 mL, canal 1.3 mL).
- **Key questions:** red_flags, onset, which_ear, hardest.
- **The workup a pro runs:** questions, then look in the ears, then air (either ear first), then bone (either mastoid).
- **The call:** FIT. Hoot: "Fit! Slow, matching ears, no red flags, and she's missing the consonants. A classic first fitting." Right reason: "A slow, matching loss in both ears, and no red flags."
- **Hoot's debrief:** "A textbook first fitting: slow, matching, sloping down to the high pitches. No red flags, so fit." "Vowels are low and loud. Consonants like s, f and th are high and soft. She misses those." "Family tips: face her, get her attention first, pick a quiet table, and turn on TV subtitles."
- **Checked against:** [AAO-HNSF Clinical Practice Guideline: Age-Related Hearing Loss (2024), summary guide](https://www.entnet.org/wp-content/uploads/2024/05/CPG_HearingLoss_SummaryGuideFINAL.pdf); [BAA/BSA Onward Referral Guidance for Adult Audiology Service Users (Sept 2023)](https://www.baaudiology.org/app/uploads/2023/04/Onward-Referral-Guidance-for-Adult-Audiology-Service-Users-Sept-23.pdf); [AAA Guidelines for the Audiologic Management of Adult Hearing Impairment](https://www.audiology.org/wp-content/uploads/2021/05/haguidelines.pdf_53994876e92e42.70908344.pdf); [21 CFR 801.422 (prescription hearing aid labeling, red flags)](https://www.law.cornell.edu/cfr/text/21/801.422); [Federal Register 87 FR 50698 (Aug 17 2022), OTC hearing aid final rule, comment on bilateral tinnitus](https://www.govinfo.gov/content/pkg/FR-2022-08-17/html/2022-17230.htm).

### 7.3 Sid Sprocket, 45 (★☆☆): **FIT**

Waiting-room card: "His hearing aid just died. He's worn them since he was six." Case `fs_sid`.

| dB HL | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| Right air | 40 | 45 | 45 | 50 | 50 | 55 | 55 | 55 | 60 | 60 |
| Left air | 45 | 45 | 50 | 50 | 55 | 55 | 55 | 55 | 60 | 65 |

Bone = air in both ears (no bone rows in the file).

- **Chart:** right sensorineural (PTA 50, moderate), left sensorineural (PTA 50, moderate). Asymmetric: no.
- **Look and tymp:** Roomy canals clear, eardrums normal; roomy canals (large tip). Tymp right A (-5 daPa, 0.9 mL, canal 1.7 mL), left A (-15 daPa, 1.0 mL, canal 1.8 mL).
- **Key questions:** red_flags, onset, which_ear, aids.
- **The workup a pro runs:** questions, then look in the ears, then air (either ear first), then bone (either mastoid).
- **The call:** FIT. Hoot: "Fit! Lifelong, steady, matching ears, no red flags. New aids, and his wheels keep turning." Right reason: "The same steady loss in both ears, no gap, no red flags."
- **Hoot's debrief:** "Years of aids don't mean skipping the checks. Look, ask and test, every visit." "Bone sat right on air, no gap: that's what shows it's sensorineural. Air alone can't tell." "A new sudden drop: a doctor today. One ear slipping behind: a doctor first. Sid has neither."
- **Checked against:** [21 CFR 801.422, prescription hearing aid labeling, red flag conditions for dispensers](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-H/part-801/subpart-H/section-801.422); [FDA letter to state officials on the OTC hearing aid final rule (Oct 13, 2022): prescription hearing aids do not require a physician's involvement or medical evaluation](https://fda.gov/media/163084/download); [British Academy of Audiology, Onward Referral Guidance for Adult Audiology Service Users (2023 update page; 15 dB AC asymmetry; bilateral-worsening referral criterion removed)](https://baaudiology.org/?p=11189); [Benson EA, Messersmith JJ. Audiologic Assessment. Seminars in Hearing 2022;43(2):58-65 (red flags -> medical referral before amplification)](https://pmc.ncbi.nlm.nih.gov/articles/PMC9325090); [American Academy of Audiology, Guidelines for the Audiologic Management of Adult Hearing Impairment (2006), sec. 2.1: case history, otoscopic inspection, cerumen management, hearing assessment and needs assessment come before fitting](https://www.audiology.org/wp-content/uploads/2021/05/haguidelines.pdf_53994876e92e42.70908344.pdf).

### 7.4 Dame Viola Vibrato, 68 (★★☆): **FIT**

Waiting-room card: "Her old aids whistle a top C, and still the world mumbles." Case `fs_viola`.

| dB HL | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| Right air | 30 | 50 | 55 | 60 | 60 | 65 | 60 | 60 | 70 | 75 |
| Left air | 35 | 55 | 55 | 60 | 60 | 60 | 60 | 60 | 75 | 80 |

Bone = air in both ears (no bone rows in the file).

- **Chart:** right sensorineural (PTA 58, moderately severe), left sensorineural (PTA 58, moderately severe). Asymmetric: no.
- **Look and tymp:** Narrow canals, clear; eardrums normal; narrow canals (small tip). Tymp right A (-10 daPa, 0.5 mL, canal 0.9 mL), left A (-15 daPa, 0.6 mL, canal 1.0 mL).
- **Key questions:** red_flags, onset, which_ear, aids.
- **The workup a pro runs:** questions, then look in the ears, then air (either ear first), then bone (either mastoid).
- **The call:** FIT. Hoot: "Fit! Slow, matching, no red flags. A bigger loss just needs stronger aids, fitted and checked properly." Right reason: "Slow and even in both ears, no gap, no red flags."
- **Hoot's debrief:** "A bigger loss isn't a red flag. Slow, matching, no gap, no red flags: that's a fit." "Eight-year-old aids wear out, and hearing drifts. New ones get checked in her ear with a tiny mic." "Honest goals: words get clearer, noise stays tricky. If good aids fall short, ask about an implant check."
- **Checked against:** [WHO grades of hearing loss (2021), German consensus version, PMC11266198](https://pmc.ncbi.nlm.nih.gov/articles/PMC11266198); [BAA/BSA Onward Referral Guidance for Adult Audiology Service Users (Sept 2023)](https://www.baaudiology.org/app/uploads/2023/04/Onward-Referral-Guidance-for-Adult-Audiology-Service-Users-Sept-23.pdf); [21 CFR 801.422, prescription hearing aid labeling with red-flag conditions for dispensers](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-H/part-801/subpart-H/section-801.422); [FDA OTC hearing aid final rule, 87 FR 50698 (Aug 2022), comment responses on tinnitus in one ear](https://www.govinfo.gov/content/pkg/FR-2022-08-17/html/2022-17230.htm); [BSA Practice Guidance: Verification of hearing devices using probe microphone measurements (2018)](https://www.baaudiology.org/app/uploads/2020/11/REMS-2018.pdf).

### 7.5 Buck Shotwell, 58 (★★☆): **REFER**

Waiting-room card: "Forty years of duck hunting. Now the ducks sneak up on him." Case `fs_buck`.

| dB HL | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| Right air | 15 | 15 | 15 | 15 | 20 | 20 | 30 | 35 | 40 | 30 |
| Left air | 15 | 20 | 20 | 25 | 30 | 45 | 55 | 60 | 65 | 55 |

Bone = air in both ears (no bone rows in the file).

- **Chart:** right sensorineural (PTA 17: the loss is in the high pitches), left sensorineural (PTA 30, mild). Asymmetric: yes.
- **Look and tymp:** Canals clear, eardrums normal; average-sized canals (medium tip). Tymp right A (-10 daPa, 0.7 mL, canal 1.4 mL), left A (-5 daPa, 0.8 mL, canal 1.5 mL).
- **Key questions:** red_flags, which_ear, onset, noise. Red-flag answers: which_ear.
- **The workup a pro runs:** questions, then look in the ears, then air (right ear first), then bone (right mastoid), then masked bone left (2k, 4k).
- **The call:** REFER. Hoot: "Refer! The shotgun likely did it, but ears this lopsided need a doctor's all-clear first." Right reason: "His left ear is much worse than his right."
- **Hoot's debrief:** "His pattern points to the shotgun: the ear nearer the muzzle takes the blast. For right-handers, the left." "But a lopsided loss is a red flag until a doctor clears it. Even with a good excuse." "Earplugs AND earmuffs, every shot from now on. The damage so far stays; more is preventable."
- **Checked against:** [NICE NG98 Hearing loss in adults, rec 1.3.2](https://www.nice.org.uk/guidance/NG98/chapter/recommendations); [BAA Onward Referral Guidance for Adult Audiology Service Users (Sept 2023)](https://www.baaudiology.org/app/uploads/2023/04/Onward-Referral-Guidance-for-Adult-Audiology-Service-Users-Sept-23.pdf); [Schiff et al., Practice Patterns in Asymmetric SNHL: Survey Data, Laryngoscope 2024](https://einstein.elsevierpure.com/en/publications/practice-patterns-in-asymmetric-sensorineural-hearing-loss-survey/); [ENTtoday TRIO Best Practice, What defines asymmetric SNHL? (2019)](https://www.enttoday.org/article/what-defines-asymmetric-sensorineural-hearing-loss/); [Ahsan et al., Clinical Predictors of Abnormal MRI Findings in ASNHL, JAMA Otolaryngol 2015](https://jamanetwork.com/journals/jamaotolaryngology/fullarticle/2167110).

### 7.6 Melody Belle, 36 (★★☆): **DOCTOR TODAY**

Waiting-room card: "Her right ear woke up muffled. She's waiting for it to pop." Case `fs_melody`.

| dB HL | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| Right air | 45 | 45 | 55 | 60 | 60 | 60 | 60 | 60 | 65 | 65 |
| Left air | 10 | 10 | 5 | 5 | 10 | 10 | 10 | 15 | 15 | 10 |

Bone = air in both ears (no bone rows in the file).

- **Chart:** right sensorineural (PTA 55, moderate), left normal (PTA 8, normal). Asymmetric: yes.
- **Look and tymp:** Canals clear, eardrums normal; narrow canals (small tip). Tymp right A (-5 daPa, 0.7 mL, canal 1.0 mL), left A (0 daPa, 0.8 mL, canal 1.0 mL).
- **Key questions:** red_flags, onset, which_ear, ringing. Red-flag answers: which_ear, onset, ringing.
- **The workup a pro runs:** questions, then look in the ears, then tympanometer, then air (left ear first), then bone (left mastoid), then masked bone right (500, 1k, 2k, 4k), then masked air right (750, 1k, 1.5k, 2k, 3k, 4k, 6k, 8k).
- **The call:** DOCTOR TODAY. Hoot: "Doctor TODAY! A sudden loss in one ear is urgent, pain or no pain. Early treatment works best." Right reason: "It came on overnight, and her bone is down too."
- **Hoot's debrief:** "A sudden loss in one ear is an emergency, even with no pain. Treatment works best early." "A full, blocked feeling is often the first sign. Her normal tymp said it wasn't fluid." "One ear much worse? Mask its bone and air: the good ear may be answering for it."
- **Checked against:** [Chandrasekhar SS et al. Clinical Practice Guideline: Sudden Hearing Loss (Update). Otolaryngol Head Neck Surg 2019;161(1S):S1-S45.](https://pubmed.ncbi.nlm.nih.gov/31369359/); [AAO-HNSF, Sudden Hearing Loss guideline talking points for physicians](https://www.entnet.org/sites/default/files/SHL-talking-points-physicians.pdf); [NICE QS185 Quality statement 2: Sudden onset of hearing loss](https://www.nice.org.uk/guidance/qs185/chapter/Quality-statement-2-Sudden-onset-of-hearing-loss); [BAA Onward Referral Guidance for Adult Audiology Service Users (Sept 2023)](https://www.baaudiology.org/app/uploads/2023/04/Onward-Referral-Guidance-for-Adult-Audiology-Service-Users-Sept-23.pdf); [21 CFR 801.422 prescription hearing aid labeling (red-flag conditions addressed to dispensers)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-H/part-801/subpart-H/section-801.422).

### 7.7 Skyler Kickflip, 19 (★★★): **REFER**

Waiting-room card: "Lost a fight with a handrail. Now one ear wears a beanie." Case `fs_skyler`.

| dB HL | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| Right air | 10 | 5 | 5 | 5 | 10 | 5 | 10 | 10 | 15 | 10 |
| Left air | 50 | 50 | 50 | 45 | 45 | 50 | 50 | 55 | 55 | 50 |
| Left bone | 5 | 0 | 5 | 5 | 5 | 10 | 10 | 5 |  |  |

Right bone = air.

- **Chart:** right normal (PTA 5, normal), left conductive (PTA 48, moderate). Asymmetric: yes.
- **Look and tymp:** Canals clear; left eardrum healed and closed; average-sized canals (medium tip). Tymp right A (-10 daPa, 0.8 mL, canal 1.3 mL), left Ad (-5 daPa, 2.8 mL, canal 1.4 mL).
- **Key questions:** red_flags, which_ear, onset, ear_history. Red-flag answers: which_ear, onset, red_flags, ear_history.
- **The workup a pro runs:** questions, then look in the ears, then tympanometer, then air (right ear first), then bone (right mastoid), then masked bone left (500, 1k, 2k, 4k), then masked air left (250, 500, 750, 1k, 2k, 3k, 4k, 6k, 8k).
- **The call:** REFER. Hoot: "Refer! A big gap after a knock points to the hearing chain. A doctor decides; often it's fixable." Right reason: "A big air-bone gap in the left ear since the fall."
- **Hoot's debrief:** "Healed eardrum, floppy peak, big gap after a knock: that points to the hearing chain behind it." "The hearing chain: three tiny bones behind the eardrum. Masked bone was normal, so the inner ear's fine." "Often fixable, but the doctor decides. Red flags: blood, sudden change, one ear worse, that gap."
- **Checked against:** [21 CFR 801.422 (eCFR; the list itself appears there only as an image)](https://www.ecfr.gov/current/title-21/chapter-I/subchapter-H/part-801/subpart-H/section-801.422); [BAA, Onward Referral Guidance for Adult Audiology Service Users (Sept 2023)](https://www.baaudiology.org/app/uploads/2023/04/Onward-Referral-Guidance-for-Adult-Audiology-Service-Users-Sept-23.pdf); [NICE NG98 Hearing loss in adults, recommendations 1.1.2 and 1.1.6](https://www.nice.org.uk/guidance/NG98/chapter/recommendations); [StatPearls, Ossicular-Chain Dislocation](https://www.statpearls.com/point-of-care/26366); [FPnotebook, Tympanometry (type Ad causes)](https://fpnotebook.com/ENT/Exam/Tympnmtry.htm).

### 7.8 Hector Ticktock, 63 (★★★): **REFER**

Waiting-room card: "His left ear runs slow. Odder still, noise seems to help." Case `fs_hector`.

| dB HL | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| Right air | 10 | 10 | 10 | 15 | 15 | 20 | 25 | 35 | 40 | 45 |
| Left air | 65 | 65 | 60 | 60 | 55 | 60 | 60 | 60 | 65 | 65 |
| Left bone | 30 | 30 | 30 | 30 | 35 | 40 | 35 | 35 |  |  |

Right bone = air.

- **Chart:** right sensorineural (PTA 15: the loss is in the high pitches), left mixed (PTA 62, moderately severe). Asymmetric: yes.
- **Look and tymp:** Canals clear, eardrums look normal; average-sized canals (medium tip). Tymp right A (-10 daPa, 0.7 mL, canal 1.4 mL), left As (-5 daPa, 0.2 mL, canal 1.4 mL).
- **Key questions:** red_flags, which_ear, onset, family. Red-flag answers: which_ear, ringing.
- **The workup a pro runs:** questions, then look in the ears, then tympanometer, then air (right ear first), then bone (right mastoid), then masked bone left (500, 1k, 2k, 4k), then masked air left (250, 500, 750, 1k, 1.5k, 2k).
- **The call:** REFER. Hoot: "Refer! A big gap plus a stiff, shallow tymp points to the middle ear. A doctor decides." Right reason: "A big air-bone gap and a stiff, shallow tymp on the left."
- **Hoot's debrief:** "A mixed loss has two parts: bone shows the inner ear's share, the gap shows the middle ear's." "Unmasked bone heard his good right cochlea. Only masked bone showed the left ear's own part." "Gap plus stiff tymp points to the middle ear. Doctor first; aids can come later, or alongside."
- **Checked against:** [Merck Manual Professional, Otosclerosis (T. A. Jan, reviewed June 2026)](https://www.merckmanuals.com/professional/ear,-nose,-and-throat-disorders/middle-ear-and-tympanic-membrane-disorders/otosclerosis); [Ahmed S., Otosclerosis, UCLA Head & Neck Surgery chapter 143 (2011)](https://www.uclahealth.org/sites/default/files/documents/2_23_11_Ahmed_Otosclerosis_ch143_0.pdf); [Sargent E. W., Otosclerosis: A Review for Audiologists, AudiologyOnline (2001)](https://audiologyonline.com/articles/otosclerosis-a-review-for-audiologists-1226); [Laurent C., Tympanometry, Open Access Guide to Audiology and Hearing Aids for Otolaryngologists](https://open.umich.edu/sites/default/files/downloads/tympanometry.pdf); [US FDA hearing-aid red flags (former 21 CFR 801.420; now 'red flag' conditions in 801.422 labeling), as listed in 'Hearing Referral Eight Red Flags', Hearing Health Matters (2018)](https://hearinghealthmatters.org/waynesworld/2018/hearing-referral-eight-red-flags/).

## 8. Steve's checklist

Steve, every call above is how the game grades the player today. Each question below has a default (what the game
does now); answer only where you disagree, by number. The first seven change the rules for every walk-in.

1. Teach 25 dB HL as the adult normal cut-off, as the rest of the game does? (yes = keep 25; no = use 20, as WHO 2021 does)
2. Five questions per visit ("the waiting room is full"), so the player has to choose. Right number? (a number; 5 now)
3. The tympanometer is required only when there is an air-bone gap, an odd tymp or a full feeling (Melody); running it otherwise is fine but not required. Make it required before every FIT? (yes/no; no now)
4. REFER for an asymmetry or a gap means the aids wait for the doctor's all-clear (FDA red-flag wording). Or would you fit while the referral is pending, as BAA 2023 allows? (yes = wait, as now; no = fit while pending; affects Buck and Hector)
5. Ringing in both ears is not a red flag; only ringing in one ear is. Buck's both-ear ringing that is louder on the left counts as not a flag. Keep? (yes/no)
6. When word scores join freestyle (after Day 4), should every FIT walk-in need a word test before the call (AAO-HNSF sends poor word recognition to a doctor)? (yes/no)
7. Bone conduction is required whenever any air tone is poorer than 25 dB, even for a long-known loss like Sid's. Keep? (yes/no)
8. Penny: for a "never listens" complaint with a normal chart, should Hoot suggest a speech-in-noise test if the trouble continues? (yes/no; no now)
9. Mabel: leave "ringing" as an optional question for her faint hiss in both ears? (yes/no; yes now)
10. Sid: an adult with a lifelong loss who has never seen an ear doctor, refer once before fitting? Sid was checked as a child, so his call stays FIT either way. (yes/no)
11. Sid: is his own word that his hearing is stable enough, or should the case put an old audiogram on file? (yes = his word is enough, as now)
12. Viola: keep Hoot's hedge "If good aids fall short, ask about an implant check" for a PTA 58 loss? (yes/no; yes now)
13. Viola: how many weeks after the fitting should Hoot book her tune-up? (a number; 2 now)
14. Buck: keep REFER for a shooter-shaped asymmetry (left 25 dB worse from 2k to 8k, right-handed shooter, no other flags)? (yes = keep; no = FIT and monitor)
15. Melody: her 4th key question is "ringing" (one-sided, a red flag). Swap it for "ear infections, surgery or injuries" ("has this happened before")? (yes = swap; no = keep)
16. Melody: keep her free of dizziness, so "sudden" alone carries the call? (yes/no; yes now)
17. Melody: her right 500 Hz is 45 dB so masked bone there stays clear of the vibrotactile zone (about 50 to 60 dB HL). OK? (yes/no)
18. Melody is close to Dash (Day 8): right ear, overnight, DOCTOR TODAY. Move her loss to the left ear so the two feel different? (yes/no; no now)
19. Skyler: REFER (a doctor within about 2 weeks) rather than DOCTOR TODAY, for a loss that began with a knock 3 months ago and has been steady since, with no dizziness or facial weakness? (yes/no; yes now)
20. Skyler: is a left type Ad peak of 2.8 mL (at -5 daPa, canal 1.4 mL) believable? (yes, or the peak in mL you would use)
21. Skyler: keep the left bone flat and normal (0 to 10 dB), with no small inner-ear dip at 4k from the knock? (yes/no; yes now)
22. Hector: his right ear (normal to 3k; 4k 35, 6k 40, 8k 45) is graded sensorineural. Keep? (yes = keep; no = make it normal)
23. Hector: Hoot explains "hears better in the noisy workshop" as people speaking up over the clocks, while his wife murmurs on his poorer side. Right for beginners? (yes/no)
24. Hector: a loss starting at 53 is late for a stiff middle ear. Change his story to "about twenty years slow"? (yes/no; no now)
