# Booth Camp: Freestyle (the walk-in clinic)

Practice mode outside the story. The player runs their own clinic: a waiting room of walk-in patients, any test
in any order, then the call. No script and no coaching during the visit; Hoot only debriefs at the end.
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
   difficulty stars (1 to 3) and the best grade so far. **Surprise me** picks one at random. **Back** to the title.
2. **Walk-in.** The patient walks to the desk and says why they came (`hello`). The first visit ever opens with
   Hoot's one-line briefing.
3. **The tool tray.** The player picks the next tool, any order, as often as they like:
   - **Ask questions**: the standard ten-question deck (section 4.1). Up to five questions per visit (the waiting
     room is full), so ask what matters. Each answer can add a note to the clipboard.
   - **Look in the ears**: the otoscope, right then left, with the canal size (it picks the tymp tip).
   - **Tympanometer**: pick the tip that seals, sweep both ears, name the type of each.
   - **Air tones**: pick which ear goes first, then air conduction on both ears.
   - **Bone conduction**: pick the mastoid, then unmasked bone (1k, 2k, 4k, 500).
   - **Masking**: pick a masked test (masked bone or masked air, right or left ear), or "No masking needed".
   - **Make the call**: ends the workup.
   The clipboard (left side) shows every note and every chart result so far; the chart card above the tray
   shows the audiogram once there is one. Done tools get a tick but can be run again. Every clinic choice (the
   tip, the tymp type, which ear first, the mastoid, the masked test, the chart type, the stamp) is a row of
   big buttons in the tray, so the chart stays in view.
4. **The chart.** "What type of hearing is in the RIGHT ear?" then the LEFT: normal, sensorineural, conductive,
   mixed. Wrong picks get Hoot's hint and another go.
5. **The call.** Four rubber stamps: **FIT**, **REFER**, **DOCTOR TODAY**, **NO AIDS NEEDED**. A wrong stamp gets
   the case's own line for that stamp, then another go. Then "Why?": pick a reason (some cases have more than
   one right reason).
6. **Debrief.** Hoot's lines from the case, then the **workup card**: what a pro would have run, in order, ticked
   or crossed against what the player did, with one line for each slip (section 4.5).
7. **Goodbye** (the case's lines; a FIT puts the hearing aids on) and the **Daily Decibel** with the
   freestyle medals: Chat, Workup, Chart, Call. Its buttons go back to the waiting room or play the same patient
   again.

Audiometry uses the normal AudiOtron, never coached. With **Quick visit** on (the default) the player stamps the
first three tones of each air ear and Hoot finishes at x8; bone and masked tests run as Hoot's montage. With
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
| Masked bone, per ear | that ear's air sits more than 10 dB above the unmasked bone (`ClinicRules.bc_masking_needed`) | unmasked bone reads the better cochlea, from either side |
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
types the ear differently (a few wandering stamps), the type their chart shows also counts, and the debrief
says what the truth was.

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
- tympanometer or air tones before looking in the ears;
- the poorer ear first for air or bone when the ears differ by more than 5 dB.

Extra tests are never slips (tymp on a normal ear is routine, "NOTHING TO MASK!" answers an unneeded masking
run), but the debrief says when one was not needed and why.

## 5. Medals and score

| Medal | Gold | Silver | Bronze |
|---|---|---|---|
| Chat | every key question asked | one missed | more (or the red flags missed) |
| Workup | no slips | one | more |
| Chart | both ears right first time | one wrong pick | more |
| Call | right stamp and a right reason first time | one wrong pick | more |

Score on the paper: 60 % medals (gold 100, silver 70, bronze 40) and 40 % the visit's audiometry score
(`Game.finish_visit`: accuracy, technique, efficiency, care). Coins as usual. The best freestyle grade per
walk-in is kept in the save (`progress.patients[<id>].fs_best_grade`) for the waiting-room card.

## 6. Hooks into shared code (all additive)

- `story/title_screen.gd`: a **Freestyle** button on the title menu, between Days and Options (six buttons with
  New player, so they are 42 px tall instead of 48).
- `story/case_portraits.gd`: `CasePortraits.register(who, look)` so walk-ins get portraits.
- `autoload/game.gd`: `PHASES` gains `freestyle_room`, `freestyle_tray`, `freestyle_chart`, `freestyle_debrief`.
- `story/daily_decibel.gd`: an optional summary `continue_text` (the main button's label).
- `tools/autoplay_bot.gd`: after the paper, `--mouse` clicks the summary's `continue_text` and waits for its
  `continue_scene`; `--via-freestyle` starts from the title's Freestyle button; the report gains `freestyle`.
- The waiting room hands its pick to the runner in the Engine meta `freestyle_next_case`; `--freestyle=<id>`
  wins (and is the bot's pick in the waiting room).

Not used: `Game.CHAPTERS`, the Days grid, `chapters_done`. The visit summary has `freestyle_case`,
`visit_score` (the audiometry score before the medal blend), `headlines`, `subheads`, `medal_beats`,
`continue_text`, `continue_scene`; visit flags `freestyle_case`, `freestyle_asked`, `freestyle_tip_tries`,
`freestyle_types`, `freestyle_slips`, `decision_first`, `decision`, `decision_tries`.

Speech tests: the tray has a **Speech tests** tool reserved (`FsRules.SPEECH_SCREEN`); it stays hidden until
word scores land (Day 4), so no walk-in needs speech yet.

### 6.1 Commands

    # one walk-in, keys or mouse only, from the waiting room
    tools/autoplay_check.sh --scene=res://story/freestyle/waiting_room.tscn --freestyle=fs_penny [--mouse]
    # from the title's Freestyle button, like a player
    tools/autoplay_check.sh --via-freestyle --freestyle=fs_penny --mouse
    # Quick visit off (the player runs every tone): add --full

## 7. The walk-ins

| # | Case id | Patient | Stars | Condition (never named as a diagnosis in play) | The call |
|---|---|---|---|---|---|
| 1 | `fs_penny` | Penny Natter, 41, podcaster | 1 | normal hearing both ears; "never listens" | **NO AIDS NEEDED** |

(Filled in as each case lands; truth tables are in each `core/patients/fs_*.tres`.)

## 8. Steve's checklist

(Filled in once all eight cases are written.)
