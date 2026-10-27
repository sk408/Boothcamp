# Booth Camp: the Masking Trainer (Training room, first lesson)

Steve asked (2026-10-27) for "a masking trainer which helps new players understand masking, when to use and how to
use it, helps them understand and memorize the occlusion effect, and is approachable for someone with little
previous knowledge. Either a separate day or maybe time to introduce an extra training tab."

This page is the design. It is built in small PRs after this one (section 9). **Built so far:** the Training
button, the Training room and Station 1 (PR 2); Stations 2 and 3 (PR 3); Station 4 (PR 4); Station 5 and Hoot's movie "The Plugged Ear" (PR 5); Station 6 (the exam), the print view and the AudiOtron's OE chip (PR 6): the whole trainer. **Steve: section 10 is your question
list. Reply by number only where you disagree; every default stands otherwise.**

| | |
|---|---|
| Teaches | why we mask (cross-hearing, the skull wall), when to mask (air and bone rules), how much (start level, plateau walk, overmasking), the occlusion effect (what it is, when it counts, the numbers) |
| For | someone who has never masked: no prior knowledge, one idea per card |
| Length | about 2-4 minutes a station, 20-25 minutes for all six |
| Home | a new **Training** button on the title, opening the **Training room**; the Masking Trainer is its first lesson (question 1) |
| Opens | every station open from the start, any order (Steve's rule for days) |
| Rules | every number comes from `ClinicRules` (no copies); fun first; colourful cards, one purpose each; playable with sound off; never tests the player's own hearing; no reward for speed |

------------------------------------------------------------------------------------------------------------------

## 1. Where it lives

**The title gets a Training button.** The menu card keeps its rows: Days and Training share one row, as Freestyle
and Arcade do (`Play` / `Days | Training` / `Freestyle | Arcade` / `Options | Quit`). Training opens
`story/training/training_room.tscn`.

**The Training room** is a cork board in Hoot's office: one big lesson card per trainer. Today it holds one card,
**MASKING SCHOOL** (navy, with the masquerade mask), and a dimmed "More lessons soon" card, so the room already
looks like a place that will grow (tymps, speech, fitting could follow). Each lesson card shows its stations as
coloured chips with a star each, and the cheat-sheet cards the player has earned pinned beside it.

**Self-contained.** The trainer is one scene (`story/training/masking/masking_school.tscn`) that takes the station to
open and returns where it came from. So it can also be registered as a Day later (one `Game.CHAPTERS` entry, a
`level_masking_school.gd` that runs the stations in order) if Steve prefers that (question 1).

## 2. The shape of a station

Every station is the same loop, so a new player learns the trainer once:

1. **Hoot's card** (one screen): what this station is for, in one line, with a picture. "Why mask? Because ears
   cheat."
2. **Try it** (2-3 guided cards): Hoot does the first one with the player, step by step; nothing can go wrong.
3. **Your round** (6 holes): one card at a time, instant feedback after each answer: a green stamp and one line
   on why, or a friendly red "Not quite" with the rule drawn on the card. A wrong answer never ends the round.
4. **The scorecard**: golf, as everywhere in the game (section 7), and the station's star.

Cards are the game's style: chunky ink outlines, Fredoka, one colour per purpose, and the same colour means the same
thing in every station:

| Colour | Means | Example |
|---|---|---|
| red / blue | right ear / left ear (the audiogram's colours) | the test ear's chip |
| navy | the skull wall (interaural attenuation) | "40" brick wall |
| grey cloud | the masking noise ("shhh") | the noise dial |
| gold | a rule to remember | "AIR - 40 vs other BONE" |
| green | safe / just right | the masking window |
| purple | dilemma, no safe level | the purple ? |
| orange | the occlusion effect | the plugged-ear hum |

Tap or click a card part to open its "why" in place (Steve's push-to-navigate taste); keys 1-4 answer, Enter goes on,
H shows Hoot's hint (costs a stroke), Esc pauses.

## 3. The stations

Six stations, in the suggested order (all open). Each reuses what the game already has.

### 3.1 Station 1: "Why mask?" (the Cross-Hearing Ghost)

- **Lead-in:** the first time, Hoot's masking movie ("The Cross-Hearing Ghost", 92 s, already on main) plays; after
  that it is offered as a replay chip, never forced (the movie rule).
- **Try it:** the movie's cartoon head, with Righty (the test ear, red) and Lefty (blue) and each one's hearing on a
  chip ("Lefty hears from 10 dB"). The player raises the beep in the right earphone 5 dB at a time (the louder key,
  or the button); the board does the sum through the navy wall ("50 - 40 = 10") and at the first level Lefty can
  hear, the Ghost floats out: BOO! Then the same with inserts (the wall is 55: BOO at 65), then the bone buzzer (no
  wall at all: BOO at just 10).
- **Your round, "Who heard it?":** six cards. Each shows one beep (earphone, level) on Righty and both cochleas'
  hearing. The player picks **THE TEST EAR**, **THE OTHER EAR (GHOST!)** or **COULD BE EITHER** (keys 1-3). The
  answer is drawn: who wakes up, the sum through the wall, the Ghost when only Lefty heard it, and two "why" lines
  under the stage. Every answer comes up at least once a round; headphones, inserts and bone are mixed 3:2:1.
- **Earns:** the **Skull Wall card**: "Headphones 40. Inserts 55. Bone 0."
- **Rules used:** `ClinicRules.IA_RULE_DB`.

### 3.2 Station 2: "When to mask?" (spot the risk)

- **Try it:** Hoot walks three charts, one "Check it" press per check. Bone first: "a gap of 10 or more on this ear?
  Mask." Air second: "this ear's air, minus the wall, reaches the bone? Mask." The second chart is the first one again
  with inserts on: the thicker wall saves the air test. The third has no gap at all.
- **Your round, "Mask it?":** a one-frequency audiogram (O Righty's air, < the unmasked bone, X Lefty's air; Righty is
  the test ear) beside the numbers and the earphone. Answer **NO MASKING**, **MASK BONE ONLY** or **MASK BONE AND
  AIR**. The reveal draws both checks on the chart (the gap bracket; the air arrow dropping by the wall to the bone
  line) and writes the sums: "Air: 70 - 40 = 30 vs bone 30: MASK AIR".
- **Why three answers, not four (question 4, corrected in PR 3):** before masking, the only bone we have is the
  unmasked bone, which reads the better cochlea, so it is also the best the other ear can be. Air crossing then means
  air minus the wall reaches that bone, which is a gap of at least the wall (40 or 55), and bone needs masking too. So
  "mask air only" cannot happen on these charts (a test checks every pair). Inserts still matter: a 45 dB gap is
  "mask both" under headphones and "bone only" under inserts. Headphones and inserts are dealt 2:1.
- **Earns:** the **When-to-Mask card**: "BONE: gap 10 or more. AIR: test air - wall reaches other bone."
- **Rules used:** `ac_masking_needed`, `bc_masking_needed`, `ia_rule`.

### 3.3 Station 3: "How much to start?" (the noise dial)

- **Try it:** Hoot names three sums and the player turns the dial to each: an air test ("Lefty's air is 15. Add 10:
  25"), bone at 500 Hz under a headphone ("15 + 10 + 15 = 40"), and the same with an insert masker (25, no boom).
- **Your round, "Set the dial":** the player turns the grey noise dial with Up/Down (or the buttons) in 5 dB steps,
  starting at Lefty's air, and presses Enter (Set it). Each round deals one air test, two low bone tests under a
  headphone (the boom), one bone test at 2k or up, one low bone test with a blocked covered ear (its own gap 20 or
  more) and one with an insert masker. The reveal paints the sum on the dial: Lefty's air (blue), +10 (mint), the
  occlusion boom (orange), with a gold tick on the start level.
- **Par:** the right level, with no hint. A dial 5 dB off counts as a bogey (the answer is close, the habit is not);
  further off is a double bogey. One setting per hole.
- **Earns:** the **Start Level card**: "Other ear's AIR + 10. Bone, low pitches: + occlusion."
- **Rules used:** `initial_masking`, `MASK_SAFETY_DB`, `occlusion_effect`, `OCCLUSION_MAX_GAP_DB`.

### 3.4 Station 4: "The plateau walk"

- **Try it:** a practice patient (a cartoon, never the player) in the booth. Hoot plays the masked bone test one
  "Next step" press at a time and names each move: "Heard, so shhh up 5." The **plateau board** draws each
  presentation as a dot (shhh across, beep up; filled = heard, hollow = no answer): the beep chases the shhh, then
  holds flat for three raises. The gold bar is the plateau = Righty's real bone.
- **Your round, "Walk it":** three practice patients, one of each kind, shuffled: the beep shifts up before it
  plateaus (Lefty was answering), the first answer was the truth (flat from the start), and a dilemma. Every
  presentation shows the answer as a "YES! (hand up)" bubble, so it plays with sound off. Each step the player picks
  **SHHH UP 5**, **BEEP UP 5**, **STORE IT** (three raises held) or **NO SAFE LEVEL**.
- **The window** under the board: too little shhh (yellow, under the start level), just right (mint), too much (coral,
  from the overmasking limit for the current beep). The dilemma patient has no mint at all (purple "?"): store
  nothing, reach for inserts.
- **The patients (PR 4):** a small rule-based model in `MaskDeck.walk_hears`, built from ClinicRules (the covered ear
  hears a bone tone with its occlusion boost unless the shhh covers it; the test ear hears unless shhh crosses back
  over the wall). It answers the same way every time, so the textbook walk always finds the true threshold. That
  changes question 10's default: wobbly `PatientSim` patients are saved for the exam (PR 6), where a drift is a fair
  surprise.
- **Par:** the textbook walk (`next_mask_step` from the start level until `plateau_run` holds for three raises), with
  each wrong move or a hint +1. Hoot names the right move after a wrong one.
- **Earns:** the **Plateau card**: "Heard: shhh +5. Missed: beep +5. Flat for 15 = the truth."
- **Rules used:** `next_mask_step`, `plateau_run`, `PLATEAU_STEPS`, `overmask_limit`, `masking_dilemma`,
  `mask_status`. Steve's 5/15 plateau stays.

### 3.5 Station 5: "The occlusion effect" (the plugged-ear hum)

The station Steve asked for by name: understand it, then memorize it.

- **Lead-in: a new Hoot movie, "The Plugged Ear"** (about 60-75 s, the movie pattern of `CONTRACTS.md` 3.4, lead-in
  chips "Why does a covered ear hear bone LOUDER?" and "How much do we add?"). Scenes:
  1. *Hum with your ears open* (the lead-in): Hoot hums; low sound leaks out of the open canal.
  2. *Plug it*: a cup goes over the ear; the low hum bounces back in; the cochlea's meter jumps. "Covering a
     normal ear makes LOW bone tones louder in it."
  3. *Only the lows*: a low tone's slow wave fills the canal; a high tone's quick wave doesn't care. 250 and 500 get
     the most, 1k a bit, 2k and up nothing.
  4. *Why the masker cares*: the masking earphone covers the other ear, so that ear hears the bone tone better, so
     the noise needs more to keep it busy: the add-on.
  5. *Deep inserts nearly cancel it*: a foam insert deep in the canal leaves almost no air to boom (the game uses 0).
  6. *A blocked ear has none to add*: an ear with its own conductive loss already "hears through a plug": no extra.
  7. *You've felt it*: fingers in your ears while you talk, or a sealed hearing aid ("talking in a barrel": Gus's
     fitting, Day 14). Hoot never asks the player to try it with a tone.
  8. Wrap: "Lows, covered, normal ear, bone only. Add it." The movie is drawn, quiet, and skippable.
- **Try it, "Plug lab":** a cut-away ear on a bench. The player toggles **OPEN / HEADPHONE / DEEP INSERT** and taps a
  frequency chip; an orange bar shows how much louder the bone tone gets in the covered ear. No sound plays.
- **Your round, part A, "Does it count?":** a card names a test and a covered ear. **ADD IT** or **NOT THIS TIME**:
  air test (never), bone at 2k (no), the covered ear has its own gap (no), inserts (no, in this game), headphones
  on a normal ear at 500 (yes).
- **Your round, part B, "Fill the pocket card" (the memory drill):** an empty pocket card with columns 250, 500, 750,
  1k, 2k, 4k and a row each for headphones and inserts. Number tiles (+0, +10, +15) drop in from the side; the player
  places each one. A right tile clicks in gold; a wrong one bounces back with the reason. Spaced repetition: each
  later visit shows fewer filled cells to start with, and the station's star needs the card filled from blank with
  no slips.
- **As built (PR 5):** the movie runs 83 s in eight scenes (listed as "Training" in the title's Hoot's Movies and in the masking levels' menus, never as Day 2's own movie: `"training": true`);
  it plays on the first visit and is offered as a replay after. The plug lab is three moves (headphone at 500,
  headphone at 2k, deep insert at 500); keys 1-3 pick the cover and Left/Right the pitch. Part A is six "Does it
  count?" cards (one per Station 3 card kind, so the add-on is judged on the same patients); part B is hole 7, one
  beat per blank cell. The card starts with 8 cells filled on the first play, 4 on the second, none after; the star
  needs par on a blank card (12 cells), so a first-visit par shows "A blank card earns the star".
- **Earns:** the **Occlusion Pocket Card** (headphones 250 +15, 500 +15, 750 +10, 1k +10, 2k+ 0; inserts 0; "only
  bone, only a covered NORMAL ear"). It is pinned in the Training room, and once earned it appears as a small
  orange chip on the AudiOtron's masking deck on the story days ("OE +15") that opens the card (question 7).
- **Rules used:** `OCCLUSION_DB`, `occlusion_effect`, `OCCLUSION_MAX_GAP_DB`, `test_is_bone`.

### 3.6 Station 6: "The masking exam" (the whole job)

- Nine holes, mixed: who heard it, mask it?, set the dial, one plateau walk, one occlusion call, and one dilemma.
  No hints for the first try of a hole; the scorecard is golf with a grade (S to C), saved as the trainer's best.
- **Earns:** a **Masking School diploma** stamp on the lesson card (Hoot in a mortarboard), and the title's stats
  line counts it.
- **As built (PR 6):** two "Who heard it?" (different answers), two "Mask it?" (different calls), two dials (one
  with the occlusion boom), one plateau walk, one "Does it count?" and one masking dilemma walk, shuffled. Each hole
  plays by its own station's rules and screen; the top bar names the kind ("Hole 3/9: set the dial"). No Try it and
  no movie. Hoot's hint is locked on a first try ("Hint: after a miss") and opens after a wrong answer, still +1.
  Grade from strokes over par: S at even par (and the star), A up to +2, B up to +5, C beyond. Finishing the exam
  at any grade earns the diploma; its stamp (and the title's "Masking diploma: A") shows the best grade.
  The exam's walks use the same rule-based patients as Station 4 (see question 10).

## 4. The cheat-sheet cards

Each station earns one card (five, plus the diploma). They are the trainer's "notes": short, coloured, one rule
each, and always worded the same way the stations say it. Earned cards are pinned in the Training room; tapping one
opens it big. A player who has every card sees a "Print view" with all five on one page (question 8). **As built (PR 6):**
the "More lessons soon" slot on the pin board becomes a PRINT VIEW tile (or press P); the page shows the five cards
and the diploma stamp, and "Save picture" writes it as a PNG (Documents/BoothCamp/masking-cheat-sheets.png on a PC,
a download on the web) for printing. Pinned cards shrink a long line to fit instead of cutting it.

| Card | Colour | Text |
|---|---|---|
| Skull Wall | navy | Headphones 40. Inserts 55. Bone 0. |
| When to Mask | gold | BONE: gap 10 or more. AIR: test air - wall reaches other bone. |
| Start Level | grey | Other ear's AIR + 10. Bone, low pitches: + occlusion. |
| Plateau | green | Heard: shhh +5. Missed: beep +5. Flat for 15 = the truth. |
| Occlusion Pocket Card | orange | 250 +15, 500 +15, 750 +10, 1k +10, 2k up 0. Inserts 0. Only bone, only a covered normal ear. |

## 5. The cards are honest

- Every level is a real 5 dB step inside the audiometer's range (`ClinicRules.clamp_db_for`, `clamp_mask_db`).
- Generated cards stay 5 dB clear of every rule edge (as the arcade's decks do), so no answer hangs on wobble, except
  in the "Try it" cards where Hoot points at an edge on purpose ("exactly 40: that counts").
- Frequencies are ones the test uses: bone 250-4k (250 only in the occlusion station, where it matters most),
  air 250-8k.
- The trainer never plays a tone at the player's ears to test them. Beeps, when sound is on, are the game's soft UI
  chirps; the noise is drawn as a cloud, never played loud.

## 6. Points, stars and save

- **Golf, per hole:** par is one clean answer (or the textbook walk for the plateau station). A wrong first answer:
  +1. Hoot's hint: +1. The dial 5 off: +1. Birdies come only from the plateau walk (fewer steps than the textbook,
  which happens when the player stores a plateau that the board shows the moment it is there).
- **A station's star:** the round at par or better (any number of tries; the best round counts).
- **Save:** `Game` progress gets a `training` key (`{"masking": {"stations": {id: {best, star}}, "cards": [...],
  "exam": {best, grade}}}`), an additive change; "New player" wipes it like the rest. As built, the exam is the
  station `exam` like any other (`{best, star, plays}`); its grade is `MaskDeck.exam_grade(best)`, not stored.

## 7. Hoot's lines (short, 18 words or fewer)

| Moment | Line |
|---|---|
| Room, first visit | "Welcome to my Training room! Short lessons, big ideas. Start with masking?" |
| Station 1 card | "Ears cheat. A loud beep in one ear can sneak across to the other." |
| Ghost caught | "BOO! The other ear answered. That's cross-hearing." |
| Station 2 card | "Before every masked test, ask: could the other ear be answering?" |
| Station 3 card | "Start the shhh at the other ear's air plus 10." |
| Occlusion hint | "Low bone tone, covered normal ear? It booms. Add a bit more shhh." |
| Station 4 card | "Heard it? Shhh up. Missed it? Beep up. Flat for 15? That's the truth." |
| Overmasked | "Too much shhh! It crossed back and hushed the test ear too." |
| Dilemma | "No safe level fits. Inserts, or store nothing. That's honest." |
| Station 5 card | "Plug a normal ear and low bone sounds get louder. Let's learn how much." |
| Pocket card full | "Pocket card complete! Fifteen, fifteen, ten, ten, then nothing. You've got it." |
| Exam passed | "Masking School diploma! Go mask with confidence, trainee." |

## 8. Files (all new unless marked)

| What | Path |
|---|---|
| Design (this page) | `docs/training/MASKING_TRAINER.md` |
| Training room | `story/training/training_room.tscn` + `.gd` |
| The trainer and its stations | `story/training/masking/masking_school.tscn` + `.gd`, `story/training/masking/station_*.gd` |
| Card generators (pure, tested) | `story/training/masking/mask_deck.gd` (uses `ClinicRules` only) |
| The new movie | `story/explainers/movies/plugged_ear.gd` + its sets script; one registry line in `movies.gd` (additive) |
| Title button (additive) | `story/title_screen.gd`: the Training button and `_on_training()` |
| Occlusion chip on the AudiOtron (additive, later PR) | `ui/audiometer/audiometer_screen.gd` |
| Tests | `story/tests/test_training_*.gd` |
| Bot | `story/tests/training_check.tscn` (`--station=why|when|start|plateau|occlusion|exam`, `--policy=careful|keys|mouse|guess|hint`, `--via-title`, `--shots`), listed in `tools/README.md` |

No new data files outside code are planned (cards are generated), so the Web preset's `include_filter` does not
change; if one is added, it goes on the filter in the same PR.

## 9. Build order (small PRs into main)

1. This design doc.
2. The Training button, the Training room, the trainer's frame (station loop, scorecard, save) and **Station 1**,
   with tests and the bot.
3. **Stations 2 and 3** (mask it?, set the dial).
4. **Station 4** (the plateau walk).
5. **Station 5**: the "Plugged Ear" movie, the plug lab, the pocket-card drill and the cards.
6. **Station 6** (the exam), the cheat-sheet print view and the AudiOtron's occlusion chip.

## 10. For Steve: questions (reply by number only where you disagree)

1. **Home:** a Training button on the title (sharing a row with Days) opening a Training room, Masking School its
   first lesson. Not a Day 16. The trainer can still be added as a Day later.
2. **Six stations**, all open, in the order of section 3; the exam last.
3. **Station 1** reuses the Cross-Hearing Ghost movie as its lead-in (first time only, then a replay chip); only
   Station 5 gets a new movie.
4. **Station 2** (corrected in PR 3): three answers, NO MASKING, MASK BONE ONLY, MASK BONE AND AIR. With the unmasked
   bone as the other ear's bone, "mask air only" cannot happen (section 3.2 says why). Inserts are dealt on a third of
   the charts, so the player sees a thicker wall save the air test.
5. **Interaural attenuation:** 40 headphones, 55 inserts, 0 bone, flat across frequencies (the story's numbers).
6. **Occlusion numbers taught:** headphones 250 +15, 500 +15, 750 +10, 1k +10, 2k and up 0; inserts 0 ("deep
   insertion"), with a line in the movie that shallow inserts leave some. Only for bone, only when the covered ear
   is normal (its own gap 10 or less).
7. **The AudiOtron chip:** once the Pocket Card is earned, a small orange "OE" chip on the masking deck in the story
   days opens it. It is a reminder, not an answer: the start level is still the player's to set. As built (PR 6):
   the chip sits at the right end of the MASKING label on the AudiOtron's deck, shown only with the MASKING group;
   a click opens the card above the deck and another closes it. It never reads the live test.
8. **Print view** of all five cards on one page, for a player who wants a paper copy.
9. **Scoring:** golf per hole, par = a clean answer; a hint or a wrong first answer +1; no reward for speed.
10. **The plateau patients** (changed in PR 4): Station 4's practice patients answer by the rules every time, so the
    walk always lands on the truth. Changed again in PR 6: the exam's walks use the same rule-based patients, so
    every hole has one right move and the closing lines stay true; the simulator's drift and misses stay on the
    story days.
11. **The "you've felt it" line** (fingers in your ears while you talk) stays, with no tone ever played to test the
    player.
12. **The name:** "Masking School" for the lesson, "Training" for the title button, "The Plugged Ear" for the movie.
