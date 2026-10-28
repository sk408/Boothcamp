# Booth Camp: the Practical (Training room, second lesson)

Steve asked (2026-10-28) for "exhaustive research into the california hearing aid dispenser practical exam" and to
"create our own practical exam in the training section of the game." The research is
[CA_PRACTICAL_EXAM.md](CA_PRACTICAL_EXAM.md); this page is the game design, built in small PRs after this one
(section 9). **Built so far:** the lesson tabs in the Training room, the lesson frame and Station 1, Pack the bag
(PR 2); Station 2, Steady hands, and Hoot's movie "The Steady Hand" (PR 3); Station 4, Too loud? (PR 4); Station 3, Station A: the tones (PR 5). **Steve: section 10 is your question list. Reply by number only where you disagree; every default stands
otherwise.**

| | |
|---|---|
| Teaches | what the California practical asks a candidate to **do**: pack and check the kit, safe hands, look and refer, pure tones with masking, the threshold of discomfort, one ear impression, retube and deliver a RIC, troubleshoot, and keep it all hygienic and calm |
| For | trainees heading for the practical, and newcomers who want to see the whole job in one place |
| Length | about 3-5 minutes a station; the mock exam about 15-20 minutes |
| Home | the Training room's second lesson card, **THE PRACTICAL**, beside Masking School (question 1) |
| Opens | every station open from the start, any order |
| Rules | fun first; colourful cards, one purpose each; playable with sound off; never tests the player's own hearing; no reward for speed; clinical numbers from `ClinicRules` / `CaseRules` or this lesson's own named table, never copied |
| Honesty | **our own** practice exam, built from the board's public bulletin and outline. Not the board's score sheet, station cards or wording; not affiliated with the board; says so on the lesson's first card |

------------------------------------------------------------------------------------------------------------------

## 1. What the real exam is, in one picture

Two timed rooms on a live subject (CA_PRACTICAL_EXAM.md section 3):

- **Station A, 35 minutes:** look in the ear, prepare and listening-check the audiometer, pure-tone air and bone,
  masked by the plateau method, the threshold of discomfort (TD), record it.
- **Station B, 30 minutes:** look again, decide the ear is fit for an impression (or refer), dam, one impression,
  judge it; fit tubing and a RIC and orient the new user; retube an earmold; troubleshoot faulty aids.
- Over both: **Safe Support Technique** (an unsafe task is stopped), **hygiene**, scripted examiners, no notes.
- About **one first-time candidate in three fails** (64 % first-time pass in 2024-25).

The game turns each of those into a short, friendly station, then puts them back together as a mock exam day.

## 2. Where it lives

**The Training room** gets a second lesson card, **THE PRACTICAL** (teal, with a clipboard and a little otoscope),
next to MASKING SCHOOL. The "More lessons soon" card moves under them (or becomes the print tile, as now). The
lesson is one scene, `story/training/practical/practical_school.tscn`, taking the station to open, exactly like
`masking_school.tscn`, so the shared frame (Hoot's card, Try it, Your round, scorecard, cheat-sheet card) is reused.

The room needs room for eight station chips: the lesson card shows **two columns of four** (Masking School keeps its
two of three). The cork board grows a second column of pinned cards for this lesson's cheat sheets.

## 3. The stations

Eight stations in the real exam's order (all open). The station loop is Masking School's (Hoot's card, 2-3 Try it
cards, a round of holes, golf scorecard, a star and a cheat-sheet card).

Colours keep one meaning across the lesson: **teal** = the lesson and its examiner cards, **gold** = a rule to
remember, **green** = safe, **red** = STOP (unsafe) or refer, **red / blue** = right / left ear, **orange** = the
impression material, **purple** = a fault to find, **grey** = hygiene.

### 3.1 Station 1: "Pack the bag" (kit and room check)

*Real exam:* own equipment, no sharing, audiometer calibrated within 12 months, non-insert headphones, a clear
one-piece syringe or a non-electric gun, in-date material, dams in sizes, a listening device, sanitizer of 10 oz or
less, non-bleach wipes, a clear bag; the listening check; an approved subject.

- **Pack it:** a table of 16 items slides past; drag (or 1-4 and Enter) the right ones into a clear bag. Decoys are
  played for laughs: insert earphones, a syringe with a detachable tip, bleach wipes, a jumbo sanitizer, an
  impression kit stamped "EXP 2019", a watch, a phone, a cheat sheet ("You won't need me. You'll know it.").
- **Calibration stamp:** three audiometer stickers; pick the one still inside 12 months of the exam date.
- **The listening check:** the AudiOtron's cords drawn big; three faults hide in turn (a crackling cord, the red
  phone playing on the left, a dead bone oscillator). Tap the faulty part (all visual: the tone is a drawn wave).
- **Can they be your subject?** Three people with a one-line card ("My cousin. She's an audiologist." / "My
  neighbour, 70, clean ears last Tuesday." / "My friend. He sat for this exam in March."). Yes or no.
- **Earns:** the **Kit Bag** card (grey and gold).
- **As built (PR 2):** six holes, all pick-one cards with keys 1-4: two "Which one stays home?" trays (three kit
  items and one decoy each, two different decoys), one "Which audiometer can come?" (three calibration stickers
  against an exam in March 2027, one inside 12 months, none on the edge), one listening check (crackly cord, cups
  swapped, silent bone oscillator, or all clear) and two "Can they be your subject?" (one who qualifies, one who
  doesn't). Try it is two guided cards (the inserts tray, the swapped cups) where only the right answer is open.
  The room shows the lessons as two tabs under the sign (Tab switches), not two cards side by side: the board
  keeps its size, and the eight chips sit in two columns of four.

### 3.2 Station 2: "Steady hands" (Safe Support Technique and the look)

*Real exam:* the instrument moves with the head, not into the ear; one hand always on the head; an unsafe task is
stopped. Hygienic precautions. Otoscopy decides referral and whether an impression is safe.

- **Lead-in:** a short new Hoot movie, **"The Steady Hand"** (about 60 s): a wobbly owl with an otoscope, a sneezing
  patient, then the bridge hand and the braced instrument hand moving as one unit; "Hands, head and light: one unit."
- **Brace it:** a big profile head. Place the **bridge hand** (on the head above and behind the pinna), lift the pinna,
  then the **instrument hand** with a finger on the cheek, then slide the light in. Then the patient sneezes, nods or
  turns: braced, the light rides along (a green "moved with the head"); unbraced, the examiner card flips: **STOP.
  Unsafe.** (no gore, a cartoon wince and Hoot: "That's the one they stop you for."). Grips to learn: otoscope handle
  up, handle down, ear light for the dam, syringe tip.
- **Wash up:** before each look, the grey hygiene chip asks for sanitized hands and a fresh or wiped speculum; skip it
  and the card shows a germ stamp (+1).
- **Look and call:** six ears drawn by the arcade's otoscope art (clear, wax, fluid, hole, object, plus a deformed
  outer ear and a "draining in the last month" note on the intake card). Call **OK to test / OK for an impression /
  refer first**. The referral list is **California's eight** (B&P 2538.36: deformity, drainage in 90 days, sudden or
  rapid loss in 90 days, dizziness, one-sided sudden loss in 90 days, significant air-bone gap, significant wax or a
  foreign body, pain), on its own card in this lesson (question 5).
- **Earns:** the **Safe Support** card (green) and the **California Refer 8** card (red).
- **As built (PR 3):** Hoot's movie "The Steady Hand" (nine scenes, about 86 s: the pencil grip and its OW, the
  bridge hand, the braced light, the sneeze it rides, a floating hand, the four tools of the board's sheet, the STOP
  card, the Safe Support card) plays on the first visit; replay from the station card or the title's Hoot's Movies.
  Six holes, pick-one with keys 1-4: "Which grip is safe?" (four drawings of one tool: safe, a floating instrument
  hand, no bridge hand, held like a pencil), "Ready to go in?" (one grip to judge: go in, or STOP: brace first),
  "Keep it clean" (one of five hygiene moments, three answers) and three "Look, then call it" cards (the arcade's
  otoscope view plus an intake card; at least one to go ahead and one to refer; twelve looks cover all eight
  flags and three that are fine). The heads sneeze once a grip is judged: braced, everything rides along; unbraced,
  a cartoon OW. An unsafe pick is the lesson's STOP: +2, not +1. The calls are two (go ahead / refer first), not
  three: California's list says when to refer, not when an impression alone must wait. Try it: a grip line-up, a
  floating hand to stop, a wax-filled ear to refer.

### 3.3 Station 3: "Station A: the tones" (air, bone, masking, record)

*Real exam:* pure-tone air and bone thresholds, unmasked and masked by the plateau method, recorded on an audiogram
with the right symbols and colours.

- **Reuses the AudiOtron** (`ui/audiometer/audiometer_screen.tscn`, `start_test(patient, ear, coached, plan)`) with a
  practice subject who answers **by the rules** (as Masking School's walks do), on non-insert headphones (the exam's
  rule). One subject per round, three subjects in all (normal; a sloping loss with one masked bone; a one-sided loss
  that needs masked air).
- **Before the first beep:** red on right, blue on left (the story's earphone game), the bone oscillator on the
  mastoid (Day 2's placement game), and the instruction card.
- **The plateau** reuses Masking School's walk rules; the recording reuses the reveal chart, scored per symbol
  (right ear red O, left ear blue X, bone brackets, masked symbols).
- **The clock** (section 6): each step costs **exam minutes** on a drawn clock; running long never costs a point,
  Hoot just says "Real exam: 35 minutes for all of Station A."
- **Earns:** the **Station A Order** card (gold): check, look, air better ear first, bone, mask, TD, record.
- **As built (PR 5):** one subject a round, three in all, each one of Station 1's good subjects answering by the
  rules on over-ear headphones: Dev, 34 (near-normal, left a touch better: nothing to mask), Rosa, 70 (a sloping
  loss, the right better, a gap at 500 Hz on the left: masked bone) and Aunt May, 58 (a one-sided loss on the left:
  masked bone and masked air). Pick holes, keys 1-4: "Phones on" (which cup on this ear), "Which ear first?" (what
  the subject says), "Bone on" (four numbered spots on a drawn head), "Mask?" (the subject's own chart from the
  booth, with the bone and air rules drawn beside it) and "Record it" (four drawn symbols: the asked one, the other
  ear's twin, the same ear's masked or unmasked sibling, one more). **Booth holes** run the real AudiOtron with the
  3D clinic behind its window: air on the better ear, air on the other, unmasked bone on the better ear, then the
  masked sheets the chart needs on the poorer ear. The player stamps the first thresholds (two for air and bone,
  one for a masked sheet) and Hoot's montage fills the rest of the ear. A booth hole's par is a clean hole: one
  stroke per technique slip the AudiOtron already flags, or per stamp 10 dB off the subject's answer, at most +3.
  So 8 to 10 holes a round. Try it: the red cup, then the mastoid. **Deferred:** the exam clock (section 6) and
  the TD on this chart (Station 4 has it).

### 3.4 Station 4: "Too loud?" (the threshold of discomfort)

*Real exam:* a suggested TD routine: the face in view, the highest tested frequency first, start at 70, pairs of
short bursts, at most 5 up per pair, finger up for annoying, hand up to stop, watch for reflexes, record TD, an arrow
down at the 110 line when there is no response.

- **Seat them:** pick the chair where the subject's face is visible (two seats face the wall: wrong).
- **Walk it:** the drawn beep pairs climb on a ladder from 70 in 5s; the cartoon subject's face changes (a frown,
  a finger, then the hand, sometimes a blink before the hand). Press **Next pair** or **Record TD here**. Raise more
  than 5, or keep going after the hand, and the examiner card says so (+1). One subject reaches the audiometer's
  limit with no hand: record the **arrow at 110**.
- **Never loud:** no sound plays at any level; each pair is a soft UI tick and a drawn wave (question 7).
- **Earns:** the **TD Steps** card (gold).
- **As built (PR 4):** six holes, keys 1-4: "Where does the subject sit?" (the booth from above, four chairs: side-on
  to you, back to you, facing the wall, behind the window post), "Which pitch first?" (the chart's tested pitches;
  the highest TESTED one, with an untested higher pitch as a decoy), two quick rule cards (start level, step,
  finger, hand, the arrow, reflexes, pairs) and two ladder walks. A ladder asks once per rung: Next pair (up 5),
  Jump up 10 (always a miss), Record TD here, or No hand at 110: arrow. The face goes calm, a frown, a finger, the
  hand; some subjects blink hard on the finger rung, and about one in three walks reaches 110 with no hand. Each
  rung's pair is a soft tick and a drawn pair of bursts. A miss on a rung is +1 and stays on that rung; one hint a
  hole. Try it: the chair, then a short guided ladder to TD 80. **Station 3 moved to its own PR** (the next one):
  it runs the real AudiOtron, which is bigger work than this pick-one frame.

### 3.5 Station 5: "One good impression" (the ear impression)

*Real exam:* is the ear fit for one; tell the client what they'll feel; pick and place the dam, check it with the
otoscope; express the material to the tip; fill canal and concha; check the cure; break the seal; remove; re-inspect;
judge the impression. Only one impression.

- **Try it:** Hoot walks a full impression on a cartoon ear, one step at a time.
- **The order:** the eleven steps arrive as shuffled cards; lay them in order (a wrong card bounces back, +1).
- **The dam:** three canal sizes, three dam sizes; pick the snug one and slide it **past the second bend** with the
  ear light under safe support (Station 2's grip); the otoscope check shows it sitting or not.
- **The squeeze:** express material until it comes clean (an air bubble in the tip if you don't: "No air in the
  tip!"), then fill the canal **from the dam outwards**, tip buried, then the concha. Lifting the tip out early leaves
  a **void**.
- **The cure:** press the fingernail test: a dent means not yet; wait the drawn timer; no dent = cured.
- **Out:** break the seal (lift the pinna, ease the helix), roll it out, **look again** (a skipped re-look: +1).
- **Judge it:** a round of six cartoon impressions; tap the fault or OK: **void, too short (no second bend), dam
  missing, folded helix, blob, OK**.
- **Earns:** the **Impression Steps** card (orange).

### 3.6 Station 6: "Delivery day" (RIC fit, retube and counselling)

*Real exam:* fit tubing in earmolds, fit the RIC to the ear, orient a new user, delivery steps, realistic
expectations, care and maintenance; replace tubing on an earmold with #13 tubing.

- **Retube:** cut the old tube off, thread the new pre-bent #13 through the bore, the bend **the same way as the
  old one**, trim it to the old length; a wrong way round shows a tube pointing at the patient's eye.
- **Fit the RIC:** choose the receiver wire length (too short pulls, too long gapes) and the dome size from a
  drawn ear; then teach insert and remove (Day 14's lines).
- **Counsel:** Gus is back for his "first week" talk; pick the **true, kind** line from three for six questions
  (realistic expectations, wearing time, his own voice, batteries or charging, cleaning, the telecoil in church),
  reusing the fitting and tune-up days' voice. Communication tips (face the speaker, light on faces, a quieter table)
  get their own card.
- **Earns:** the **Delivery** card (teal).

### 3.7 Station 7: "The bench" (troubleshooting)

*Real exam:* physical inspection, listening check, test the instrument, correct the problem, know which
electroacoustic measure a fault changes.

- **Reuses Day 15's bench** (`tune_desk.gd`, `wax_guard.gd`): an aid arrives with a ticket ("dead", "weak",
  "whistles", "comes and goes", "sounds rough"); pick the tool from the station's tray (battery tester, listening
  tube, wax pick, brush, blower bulb, a new tube, a new dome, the test box).
- **The test box card:** after the fix, pick which measure was off (output too low, gain too low, distortion too
  high, battery current too high), drawn as one bar against a green band.
- **Feedback twist:** whistling in the hand but not in the ear vs in the ear too: external (fit, dome) or internal
  (send it in).
- **Repair, send away, or replace:** the last card of each aid.
- **Earns:** the **Bench Tree** card (purple): look, listen, test, fix, or send.

### 3.8 Station 8: "Exam day" (the mock exam)

- Two rooms, **Room A** (35 exam minutes) and **Room B** (30), each with an examiner at a desk who reads short prompt
  cards **written for the game** ("Please look in the subject's right ear.") and says nothing else, as the real
  examiners do. Hoot waits outside ("No owls in the exam room. You've got this.").
- **Room A:** the kit table, the look (with a referral twist on some seeds), air and bone with one masked threshold,
  TD, record.
- **Room B:** the look, the impression (one), retube, a RIC delivery with a counselling card, two bench aids.
- **The score sheet:** each task has steps worth 1-3 points (our own list, built from the bulletin's focus areas);
  hygiene and record-keeping steps count. **Unsafe = STOP:** a slip in Station 2's sense ends that task with its
  points lost; the room goes on, as in the real exam.
- **Grade:** points as a percentage, **S / A / B / C**, and **Practical pass** at B or better with no STOP (question
  9). Hoot's hints are off. Finishing earns the **Booth Camp Practical licence** stamp (a game licence, clearly not a
  board one) on the lesson card and a "Practical: A" line on the title.

## 4. The cheat-sheet cards

| Card | Colour | Text |
|---|---|---|
| Kit Bag | grey | Calibrated audiometer (12 months), non-insert phones, bone, otoscope, ear light, one-piece clear syringe or gun, in-date material, dams, listening tube, small sanitizer, non-bleach wipes. Clear bag. No sharing. |
| Safe Support | green | Bridge hand on the head. Instrument hand braced. Hands, head and light: one unit. |
| California Refer 8 | red | Deformity. Drainage (90 days). Sudden loss (90 days). Dizzy. One-sided sudden loss. Big air-bone gap. Wax or object. Pain. |
| Station A Order | gold | Check. Wash. Look. Air, better ear first. Bone. Mask: plateau. TD. Record. |
| TD Steps | gold | Face in view. Top pitch first. Start 70. Pairs. Up 5. Finger = annoying, hand = stop. No hand at max = arrow at 110. |
| Impression Steps | orange | Look. Tell. Dam past the 2nd bend. Check. Express to tip. Fill canal, then concha. Cure. Break seal. Out. Look again. Judge. |
| Delivery | teal | Retube: same bend, same length. RIC: wire and dome fit. Teach in and out. Expectations: real and kind. |
| Bench Tree | purple | Look. Listen. Test. Fix. Can't fix? Send it in. Can't send? Replace. |

A **print view** with all eight cards on one page (P in the room once all are earned), as Masking School has.

## 5. Honesty and safety

- **No board material reproduced:** prompts, score sheet and cards are ours; the research doc quotes the board only
  to cite it. The lesson's first card: "Our practice exam, built from the board's public outline. The real one may
  differ. Check the board's latest bulletin."
- **No vendor logos, art, word lists or recordings;** the aids, tools and ears are the game's own drawings.
- **Sound off works everywhere;** no tone is ever played to test the player; the TD station plays no loud sound.
- Every number has a name: TD start 70, step 5, the 110 line, the 12-month calibration and 10 oz rules, the 90 days,
  in this lesson's deck (`practical_deck.gd`) with the bulletin cited beside each; masking numbers from `ClinicRules`.

## 6. Points, stars, the clock and save

- **Golf per hole**, as in Masking School: par is a clean answer; a wrong first answer +1; a hint +1; a skipped hygiene
  or re-look step +1; an unsafe move +2 (and the STOP card).
- **A station's star:** a round at par or better.
- **The exam clock is game time, not real time:** each action has a fixed cost in exam minutes (a tone pair 10 s,
  a threshold about 1 minute, the impression's cure 5 minutes), shown as a drawn clock. Running over shows "time!"
  and Hoot's note; it never costs points and nothing hurries the player (question 8).
- **Save:** `TrainingProgress` with the lesson key `"practical"` (additive; "New player" wipes it).

## 7. Hoot's lines (18 words or fewer)

| Moment | Line |
|---|---|
| Lesson card | "The practical: two rooms, one live ear, no notes. Let's make your hands remember." |
| Station 1 | "Your own kit, checked and calibrated. No borrowing on the day." |
| Station 2 | "Hands, head and light: one unit. If they sneeze, you ride along." |
| STOP | "That's the one they stop you for. Brace first, then go in." |
| Station 3 | "Same tones as the story days. Now on the clock, and every symbol counts." |
| Station 4 | "Watch the face, not the dial. A finger is annoying; a hand means stop." |
| Station 5 | "One impression. Make it a good one: no air, no voids, past the second bend." |
| Station 6 | "Same bend, same length. Then tell them the truth, kindly." |
| Station 7 | "Look, listen, test. Most dead aids are a battery or a wax guard." |
| Exam passed | "Practical passed! Your hands know the job. Go get the real one." |

## 8. Files (all new unless marked)

| What | Path |
|---|---|
| Research | `docs/training/CA_PRACTICAL_EXAM.md` |
| Design (this page) | `docs/training/PRACTICAL_EXAM.md` |
| The lesson and its stations | `story/training/practical/practical_school.tscn` + `.gd`, `station_*.gd` as needed |
| Deck (pure, tested) | `story/training/practical/practical_deck.gd` (named numbers with sources; `ClinicRules`, `CaseRules` for the rest) |
| Art | `story/training/practical/practical_art.gd` (head in profile, hands, dams, impressions, tubes, tools) |
| New movie | `story/explainers/movies/steady_hand.gd`, one registry line in `movies.gd` with `"training": true` (additive) |
| Training room (additive) | `story/training/training_room.gd`: the second lesson card, eight chips, a second card column |
| Tests and bot | `story/tests/test_training_practical_*.gd`; `story/tests/practical_check.tscn` (`--station=kit|hands|tones|td|impression|delivery|bench|exam`, the same policies and `--via-title` as training_check), listed in `tools/README.md` |

No data files outside code are planned; if one is added, it goes on the Web preset's `include_filter` in the same PR.

## 9. Build order (small PRs into main)

1. This research and design (docs only).
2. The lesson card in the Training room, the lesson frame and **Station 1** (Pack the bag), tests and the bot.
3. **Station 2** (Steady hands, the look, the Refer 8) and the movie "The Steady Hand".
4. **Station 4** (TD). (Station 3, the tones on the AudiOtron, follows as its own PR.)
5. **Station 5** (the impression).
6. **Station 6** (delivery day) and **Station 7** (the bench).
7. **Station 8** (exam day), the licence stamp and the print view.

## 10. For Steve: questions (reply by number only where you disagree)

1. **Home:** a second lesson card, THE PRACTICAL, in the Training room. Not a Day.
2. **Eight stations** in the real exam's order (section 3), all open, the mock exam last.
3. **California first:** the lesson follows California's two-station exam. The national IHS practical (which adds
   audiogram interpretation and real-ear verification) is only mentioned on one card; Day 14 already teaches
   verification. If California adopts the IHS exam, a later PR adds those stations.
4. **Name:** "The Practical" for the lesson, "Exam day" for Station 8, "Booth Camp Practical licence" for the stamp.
5. **Refer list:** this lesson teaches **California's eight** from B&P 2538.36 (90 days, "significant" air-bone gap)
   on its own card; the story days keep the FDA list in `CaseRules` (6 months, 15 dB). A line on the card says the
   two lists differ.
6. **Safe Support** is the one STOP rule (an unsafe move ends the task, as the real examiners do); everything else is
   a +1.
7. **TD:** follows the bulletin's suggested routine (top pitch first, 70 start, pairs, 5 dB, finger and hand, the
   arrow at 110). Your clinic may differ; the card says "the board's suggested routine". No loud sound ever plays.
8. **The clock:** game minutes, drawn, never scored (the game's no-reward-for-speed rule); Hoot only notes "time!".
9. **Exam pass line:** B or better (75 % of the points) with no STOP. The board's pass mark is not published, so this
   is ours.
10. **Station 3's subjects** answer by the rules (no wobble), like Masking School's walks, so every threshold has one
    right answer.
11. **Headphones only** in Station 3 (the exam bans inserts); the story days keep inserts.
12. **Counselling:** folded into Station 6 with Gus as the patient, not its own station.
13. **The impression art:** cartoon impressions and ears, no photos; faults: void, short, no dam, folded helix, blob.
14. **New movie:** only "The Steady Hand"; the other stations open with a Try it walk-through, no movie.
15. **Disclaimer card** at the lesson's start (section 5).
16. **Your own exam:** anything you remember in general terms (what people failed, what the bench aids had wrong)
    would sharpen it; nothing confidential (CA_PRACTICAL_EXAM.md section 10). The TD positioning PDF is pictures only;
    a description from you would help Station 4.
