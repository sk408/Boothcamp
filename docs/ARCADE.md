# Arcade mode: the hall, Chart Chute and Ears, Please!

The arcade is the quick-play corner of Booth Camp: short runs, a clock, a streak and a high-score table. Steve picked
two cabinets from the shortlist (2026-10-19): **Chart Chute** first, then **Ears, Please!**. Part 1 of this file
covers Chart Chute; part 2 covers Ears, Please!.

Arcade is not Freestyle. Freestyle is a whole visit at your own pace. Each cabinet drills one skill in a minute or
two: Chart Chute is **reading the shape of an audiogram at a glance**; Ears, Please! is **spotting the red flags
before you fit**.

## The hall

The title's **Arcade** button (beside Freestyle) opens the arcade hall (`story/arcade/arcade_hall.tscn`): two
cabinets side by side, each with its name, a little picture, its pitch, the top of its high-score board and your best
recent score ("NEW!" until you have played it).

- Keys **1** and **2** open a cabinet; **Left/Right** and **Enter** (or Space) do too; the mouse hovers and clicks.
- **T** or "Back to the title" goes home; **Esc** pauses, as everywhere.
- Every cabinet's results card has "Back to the arcade [T]", which comes back here with that cabinet selected.
- Beat `arcade_hall` {options, best, mouse: {click: "arcade_cabinet_ears_please"}}; the solver opens Ears, Please!.
  Anchors `arcade_cabinet_chart_chute` and `arcade_cabinet_ears_please`.

# Part 1: Chart Chute

## 1. A run

1. **Warm-up (no clock).** Three charts. Only SLOPE and NOTCH are open. On the first two, Hoot points at the
   right chute and the chute glows. A wrong drop just bounces back so you can try again.
2. **3, 2, 1, GO!**
3. **60 seconds.** The next chart arrives the moment you sort one. A small NEXT card up the belt shows what's coming.
   - Drop each chart down the chute whose shape it has: **1 SLOPE**, **2 NOTCH**, **3 COOKIE BITE**, **4 RISING**.
     Use keys 1 to 4 (the digit row by position on any layout, or the keypad) or click a chute. A key pressed while
     the chart is still landing counts once it lands (up to 0.35 s early); a key pressed while the last chart was
     still dropping or jammed does not carry over. A chute that is not open yet just shakes.
   - **Right:** the chart drops, the chute plays its gag (the skier zips down, the cymbal crashes, the cookie gets
     chomped, the wave rolls), and the patient says a line about what that loss is like.
   - **Wrong (JAM!):** the belt stops for 1.2 s, the right chute glows and the tell glows on the chart (for a
     notch: "NOTCH: Dips at 3-6k, comes back up at 8k", with an arrow at 8k). On a two-ear card sorted by the other
     ear's shape, the ear tag flashes and says "Other ear! Sort the RED O" (or BLUE X). The streak resets and the
     chart comes back three cards later.
   - **HOOT HELP** (H or the button) shows the tell for 1.5 s and sorts the chart for you. No points, no slip, and
     the streak is kept.
4. **TIME!** The results card shows your rank, right and oops a minute, accuracy, best streak, score, story charts
   found, a speed chart of your last runs, and the high-score board. A run 90% accurate or better that makes the
   top ten asks for three initials (type them, or click the arrows). **Enter** or **Space** plays again, **T** goes
   back to the arcade hall.

## 2. The ramp inside the run

| Run time | What changes |
|---|---|
| 0 s | SLOPE and NOTCH, right ear only (red O) |
| 10 s | the COOKIE BITE chute opens ("NEW CHUTE!", and the NEXT card is its first chart) |
| 25 s | the RISING chute opens |
| 30 s | left-ear charts join (blue X): same shapes |
| 35 s | the REVERSE BITE chute opens, key 5 (section 16) |
| 40 s | two-ear charts ("SORT THE RED O" / "SORT THE BLUE X": the other ear has a different shape and is dimmed) and lookalikes (the same shape with a trap in it) |
| 50 s | one story patient's own chart, worth x3 (gold card, "STORY CHART x3") |

No shape comes three times running, sent-back charts and story charts included.

## 3. Every chart is honest

- Each chart's label comes from `ClinicRules.classify_shape`, the same rule the story's reveals use.
- Each chart is also kept away from that rule's edges: the shape still holds with any single frequency 5 dB
  better or worse, the worst point is past 35 dB HL, and a notch bottoms out at 40 dB HL or worse. A right answer
  is never a coin toss (`ChartDeck.stable`).
- Inter-octaves (750, 1500) are plotted wherever `ClinicRules.required_interoctaves` asks for them.
- **Lookalikes:** a slope with a dip at 4k that never comes back up is still a SLOPE. A slope never recovers 10 dB at
  6k either, so none of them reads as a 4k notch to a clinician. A notch sitting on a sloping loss, with 8k
  recovering by 10 dB or more, is still a NOTCH. A shallow cookie bite and a gentle rising loss round out the set.
- **Story charts** are the real patients' thresholds from `core/patients`:
  - Gus (Day 1): sloping, both ears.
  - Rocco (Day 6): notch, both ears.
  - Ginger (Day 9): cookie bite, both ears.
  - Marina (Day 7): rising, **left ear only**, because her right ear is normal.

  Each one passes the same margin check. A story chart only rides the belt once you have finished that patient's
  Day, so the arcade never shows a Day's pattern (or Marina's clue) before you play it
  (`ChartDeck.golden_pool`). At most one is dealt per run, the unfound ones first (`found` in the save); once all
  the open ones are found they come round again. The results say which Days add the rest.
- Flat losses and normal charts never ride the belt (there is no chute for them).

## 4. Points, ranks and the board

- A right drop scores 100 x the streak multiplier (`ClinicRules.combo_multiplier`: x2 from 3 in a row, x3 from 6,
  x5 from 10). A story chart scores x3 on top of that.
- **FLUENT** means 25 right a minute with at most 1 slip (precision-teaching style). This is a starting aim to tune
  in playtests.
- **Ranks:**
  - Chart Whisperer: fluent.
  - Sharp Eye: 90% accurate and 15 or more a minute.
  - Steady Sorter: 80% accurate.
  - Jam Master: under 80% accurate (slips only counts too).
  - Belt Watcher: nothing sorted and nothing slipped. Accuracy then shows "–".
- **High-score board:** only runs 90% accurate or better go on it. Guessing scores about a third of what reading
  does and never reaches the board (`test_guessing_scores_far_below_reading`, and the `guess` bot). The board starts
  with HOO 6,000, GUS 3,000 and BON 1,500, so a first-timer has someone to beat.
- **Footer:** "Practice, not a qualification. Hearing care professionals read charts like these every day."

## 5. Save

`Game.progress["arcade"]["chart_chute"]` (`DEFAULT_PROGRESS` gained `"arcade": {}`) holds:

- `table`: the top ten as `[{initials, score, accuracy}]`.
- `runs`: the last 12 as `{right, oops, score}`, for the speed chart.
- `found`: the shapes whose story chart you've sorted.
- `initials`: the last initials entered.

Reads are defensive, because JSON brings numbers back as floats (`story/arcade/arcade_scores.gd`).

## 6. Contract notes

- **Beats** (CONTRACTS.md §3.2, listed in `story/INTEGRATION_NOTES.md`):
  - `chute_sort` {shape, options (the open chutes' words), best, mouse: {click: "chute_<shape>"}}. The solver sorts
    into the right chute.
  - `arcade_initials` {mouse: {click: "arcade_initials_ok"}}. The solver enters BOT.
  - `arcade_results` {options, best, mouse: {text: "Back to the arcade"}}. The solver goes back to the hall.
  - A run is never a visit: no `begin_visit`, `finish_visit`, medals or coins.
- **Anchors:** `chute_sloping`, `chute_notch`, `chute_cookie_bite`, `chute_rising`, `chute_help`,
  `arcade_initials_ok`.
- **Time:** pausable game time only (timers with `process_always` off, node tweens, `Game.clock`). The pause
  menu's Quit to title works mid-run. The initials read keys ahead of the pause menu, so a typed P is a letter
  (Esc still pauses).
- **Window shape:** the 1280x720 playfield stays centred in a wider or taller window; the wall, floor, top band and
  belt fill the rest.
- **Reduced motion:** the chart glides in without overshoot, the belt rollers and the streak flame stand still,
  and the glows are steady.
- **Screenshots** (with `--shots`):
  - `chute_warmup`
  - `chute_jam_tell`
  - `chute_unlock_cookie_bite`, `chute_unlock_rising`
  - `chute_both_ears`
  - `chute_golden` (needs `--days-done`)
  - `chute_results`
  - `chute_board`
  - `title_arcade` and `arcade_hall` (from the check bot's `--via-title` keys run)

## 7. Files and commands

- `story/arcade/chart_chute.gd` / `.tscn`: the scene.
- `chart_deck.gd`: the seeded charts and story charts.
- `chute_rules.gd`: the clock, ramp and scoring.
- `arcade_scores.gd`: the board and run history, shared with the next cabinet.
- `arcade_art.gd`: the chute pictures and gags.
- Tests: `story/tests/test_arcade_chute.gd`, run with `tools/run_tests.sh --filter=arcade`.
- End to end, one run with a test bot. It prints `ARCADE_RESULT {json}` and exits 0 when every check passed:

  ```
  timeout 300 godot --headless --path . --fixed-fps 30 -- \
    --scene=res://story/tests/arcade_chute_check.tscn --fresh --policy=careful --speed=4 --seed=1
  ```

  - Policies:
    - `careful`: the solver.
    - `keys`: real 1-5 keys, with KEY as the initials, then T back to the arcade hall.
    - `mouse`: real clicks only, with BAA as the initials, then Back to the arcade.
    - `guess`: a random open chute every time.
    - `help`: HOOT HELP every time.
    - `slip`: real keys, but each two-ear card first goes down the other ear's chute (a JAM with the "Other ear!"
      cue, and the `chute_jam_tell` shot), then the right one when it comes back.
  - `--via-title` starts from the title's Arcade button and picks cabinet 1 in the hall.
  - `--days-done` marks every Day finished first, so a story chart can come (the `careful` bot must then sort one).
    Without it, no story chart may appear.

## 8. For Steve: clinical check

Reply with a number only where you disagree. Each item says what the game does now.

1. The chute names are **SLOPE, NOTCH, COOKIE BITE, RISING**. RISING is the reverse slope, worse in the low pitches.
2. A **notch** is called when the worst of 3k, 4k and 6k is at least 15 dB worse than 2k and at least 10 dB worse
   than 8k (`ClinicRules.classify_shape`). The belt only shows notches that bottom out at 40 dB HL or worse.
3. **Lookalikes:** a 4k dip that does not come back up (not at 6k, not at 8k) is labelled SLOPE. A notch on top of
   a sloping loss is labelled NOTCH when 8k recovers by 10 dB or more.
4. **The tells:**
   - SLOPE: "Worse and worse toward the high pitches".
   - NOTCH: "Dips at 3-6k, comes back up at 8k".
   - COOKIE BITE: "Worst in the middle, better at both ends".
   - RISING: "The low pitches are the worst".
5. **The patient lines** (all 14):
   - SLOPE: "Everyone mumbles these days!", "I hear talking, not words.", "Birds? What birds?", "S and F sound the
     same."
   - NOTCH: "Thirty years of loud gigs...", "My workshop is LOUD.", "Jet engines, every day.", "I never wore
     earplugs."
   - COOKIE BITE: "Mum's chart looks like this too!", "Middle voices just vanish.", "Grandad had the same bite."
   - RISING: "The fridge hum is gone!", "Deep voices are hard.", "Low notes went missing."
6. Marina's story chart shows her left ear only (rising). Gus, Rocco and Ginger show both ears and you sort the
   right ear.
7. Flat losses and normal hearing never appear. A FLAT chute could come later if you want one.
8. FLUENT is 25 right a minute with 1 slip or fewer.

# Part 2: Ears, Please!

You're on the front desk of a hearing clinic. Patient files slide onto the desk; read each one and stamp it **FIT**
(hearing aids can help), **REFER** (a red flag: a doctor first) or, from shift 3, **DOCTOR TODAY** (a sudden loss that
can't wait), then **prove it** by pointing at what made you send them. Two minutes a shift. The wall shows the rules as picture cards, so a newcomer can play it cold; the lesson is
the dispenser's first habit: **catch the red flags before you fit**.

## 9. A shift

1. **Pick a shift** (only once a second shift is open): 1 Trainee, 2 Dispenser or 3 Clinic Lead, each opened by the
   one before it.
2. **Warm-up (no clock).** Three files with Hoot pointing at the right stamp, then at the proof. A wrong stamp or a
   wrong proof is just tried again. Once you have warmed up on a shift, **S** or the **Skip**
   button at the end of the top bar skips it, whatever the file in hand is waiting for.
   - Shift 1: a clear FIT, a ONE EAR WORSE, a ticked "Dizzy spells".
   - Shift 2: a two-ear air-bone gap (it looks like a FIT on air alone), a FIT whose masked bone [ ] sits on air
     ("the gap is the distance, not the bracket"), and a ticked "Lots of wax" (the new LOOKED boxes).
   - Shift 3: a sudden loss that started days ago (DOCTOR TODAY, proved by the alarm clock), a sudden loss that
     started months ago (REFER) and a loss that comes and goes (REFER).
3. **3, 2, 1, DESK OPEN!** 120 seconds; the wall clock runs 9:00 to 11:00.
   - **Stamp:** keys **1** FIT, **2** REFER, **3** DOCTOR TODAY (digit row by position on any layout, or the
     keypad), or click a stamp. A locked stamp shakes and says when it opens.
   - **The alarm clock** (shift 3): a card across the top of the chart says how the loss **CAME ON** ("Suddenly,
     overnight", "Suddenly, in a day", "Suddenly, in 2 days", "Comes and goes", "Slowly, over years"), when it
     **STARTED** ("Yesterday", "5 days ago", "3 months ago", "6 years ago") and the **EAR** it hit (RIGHT in red, LEFT
     in blue, or a dash). Every shift 3 file has the same clock, so only reading it tells the call.
   - **PROVE IT** (after REFER or DOCTOR TODAY): the pointer starts on the first intake box; the **arrows** move it
     over every intake box, the alarm clock (shift 3) and every chart column, **Enter** points; or click it. Every
     box and every column can be pointed at on every file, so the list never hints at the answer.
   - **Clean** (right stamp, right proof): points, the combo grows. FIT gives the patient their aids in the window
     with a sparkle and a "GOAL" sticker (what the fitting aims at: "the phone", "book club"). REFER sends the
     letter out of the window and lights the rule card that proved it; DOCTOR TODAY phones the doctor ("SEEN
     TODAY!"). The first clean file of each kind in a run
     opens a short NICE! note with its rule.
   - **Slip:** a note names what went wrong and shows the proof (it glows; a gap shows the bone-to-air lines with
     their dB). The clock is held while a note is up (at least 1 s, at most 6 s; Enter or a click closes it).
     - CITATION: FIT on a file with a red flag.
     - EXTRA REFERRAL: REFER (or DOCTOR TODAY) on a file that could be fitted.
     - RIGHT STAMP, WRONG PROOF: REFER or DOCTOR TODAY, but the pointer was on something that doesn't prove it.
     - TOO URGENT (shift 3): DOCTOR TODAY on a file that needs a usual referral.
     - INCIDENT (shift 3): FIT or REFER on a same-day file. Hoot warns after the first; the second closes the desk
       early ("DESK CLOSED!").
   - **HOOT HELP** (H or the button): Hoot shows the proof, then stamps and points for you. No points, and the file
     counts as not clean; the combo is kept for the first two helps of a shift.
   - **The VIP** ("Very Insistent Patient") comes with 25 seconds left, worth x2, and begs for the wrong stamp: on
     shift 1 Wendy Bliss ("My daughter's wedding is Saturday! Just fit me, dear!", ear leaking); on shift 2 Gary Rush
     ("Quick, I've a plane to catch!", an air-bone gap in both ears); on shift 3 Walter Wick ("It's only wax, dear.
     Just pop the aids in!": the otoscope shows no wax, and the alarm clock says sudden, under a month ago). The FIT stamp
     wobbles while a VIP is at the desk ("PICK ME?" with reduced motion).
4. **CLOSING TIME!** (or **TWO WENT HOME!** after an early close) The results card shows the rank and its line; files, clean (and %), red
   flags missed, same-day patients missed (shift 3), extra referrals, best combo, score; the promotion line; "WHAT YOU MISSED" ("EVERY FILE" on a clean shift), a row per kind of file with a mark per file
   (tick: clean, ~: right stamp but wrong proof, +: extra referral, cross: missed, ?: helped) and the row with the most trouble tinted, with its tip; and the
   shift's own high-score board. **Enter** plays the same shift again, **S** opens the shift picker, **T** goes back
   to the arcade hall.

## 10. Every file is honest

Each file is a real air and bone table, charted the way a clinician records it (masked where `ClinicRules` says
masking is needed), then decided by `DeskRules.decide()`, which uses only `CaseRules` and `ClinicRules`. The deck
(`DeskDeck`) rebuilds any file that sits near a rule's edge, so no call is a coin toss:

- Between the ears, every shared frequency differs by 5 dB or less, or by 20 or more.
- Every air-bone gap on the chart is 5 dB or less, or 20 or more.
- A FIT file's ears both have a pure-tone average of 30 to 65 dB HL: a loss aids can help. Shapes: slope, steep,
  flat, gentle, cookie bite.
- Outside the gap files, both ears are sensorineural: no conductive part a doctor should see.
- One-ear files sit on a fittable loss 60% of the time, so "one line near the top" is never the tell; the split is.
- A two-ear gap file has air like a FIT and bone 20 dB above it at 500, 1k and 2k (at 25 dB, masking either ear's
  bone could hit the masking dilemma).
- Every masked point on the chart could really be measured: a file where `ClinicRules.masking_dilemma` would hold
  for any masked air or bone point is rebuilt.
- Every patient is an adult aged 50 to 88, whatever the call (age never gives the stamp away), nobody shows an
  emergency sign (no stamp covers those), and no patient's line names a
  cause for their loss: the wall's "ONE EAR WORSE: no known cause" is never undercut by the file.
- Shift 3: a same-day file's loss started 1 to 14 days ago and came on within 2 days (never sooner than it took to
  come on, so no "Yesterday" beside "in 2 days"), with that ear 30 dB or more worse at 3 or more neighbouring
  frequencies; an older sudden loss started 2 to 4 months ago; a loss that comes and goes started 7 to 20 days ago
  on a FIT-like chart. Nothing started between 15 and 59 days ago, so "under a month" is never a coin toss. Every
  other file's clock says "Slowly, over years".
- The chart: 250 to 8k with 1.5k, 3k and 6k routine, 750 Hz where `ClinicRules.required_interoctaves` asks for it;
  bone at 500, 1k, 2k and 4k. Symbols as on Day 2 (O X, < >, [ ], △), with a legend under the chart.

**The rules on the wall** (what each card sends where):

| Card | What it means | From |
|---|---|---|
| A TICKED BOX | any YES on the intake: ear leaking, ear pain, dizzy spells, ringing in ONE ear (asked); lots of wax, odd ear shape (looked, otoscope) | shift 1 (looked boxes from shift 2) |
| ONE EAR WORSE | 15 dB or more between the ears at two neighbouring frequencies (`CaseRules.is_asymmetric`), no known cause | shift 1 |
| AIR-BONE GAP | bone 15 dB or more better than air at 500, 1k and 2k in one ear (`ClinicRules.abg_red_flag`) | shift 2 |
| SUDDEN LOSS ("In 3 days or less", under a pink THE ALARM CLOCK header), with two lines (`DeskRules.SUDDEN_ROWS`): "Under a month ago" DOCTOR TODAY, "Older, or comes & goes" REFER (the clock's own words) | came on within 3 days (`CaseRules.SUDDEN_ONSET_MAX_H`) and started under a month ago (`SUDDEN_REFER_TODAY_DAYS`, 30 days), with that ear 30 dB or more worse at 3 or more neighbouring frequencies (`SUDDEN_MIN_DB`, `SUDDEN_MIN_FREQS`) and no middle-ear cause: DOCTOR TODAY. A sudden loss that started months ago, or one that comes and goes, is still a red flag (`CaseRules.RED_FLAGS`: in the last 6 months): REFER | shift 3 |

When the alarm clock proves a call, the card lights the line for that call (a tick beside its stamp on a clean
file). Hoot also teaches both lines in the warm-up and the lessons.

**PROVE IT accepts** the ticked box itself; for ONE EAR WORSE, any column in a run of the asymmetric frequencies;
for a gap, any bone column of that ear where the gap is 15 dB or more (either ear when both have one); the alarm
clock for an older or comes-and-goes loss. A DOCTOR TODAY is proved only by the alarm clock. When a file has more than
one proof, Hoot points at a ticked box first, then the alarm clock, then the gap (a gap explains a split), then the
split.

## 11. Points, ranks, promotion and the boards

- **Points** are lopsided on purpose, because a missed red flag can hurt a patient and an extra referral costs one
  visit:
  - clean: 300 x the combo multiplier (`ClinicRules.combo_multiplier`: x2 from 3 in a row, x3 from 6, x5 from 10);
  - right stamp, wrong proof: +100;
  - extra referral, or DOCTOR TODAY on a usual referral: -100;
  - missed red flag: -600 (two clean calls);
  - a same-day patient sent home: -900, and a second one closes the desk;
  - the VIP doubles points won. The shown score never drops below 0.

  Stamping FIT on everything ends below zero and REFER on everything barely scores (`test_against_the_clock_...`
  and the `fit_everything` and `refer_everything` bots; on shift 3 both send same-day patients home, so the desk
  closes on the second instead).
- **Clean %** counts HOOT HELP as not clean. A shift is **safe** when no red flag was missed, no same-day patient
  was sent home, and 3 in 4 calls were clean (on shift 3 the results line says so when a run is not safe).
- **Promotion:** a safe shift of 8 files or more opens the next shift (the results say what is still missing).
- **Ranks:** Desk Legend (safe, 90% clean, 10+ files), Red Flag Radar (safe), Learning the Ropes (no flag
  missed, but mostly HOOT HELP), Better Safe Than Sorry (no flag missed, but extra referrals), Show Your Working (no
  flag missed, but wrong proofs), One Got Away (one red flag missed),
  Red Flags Got Through, Incident Report (a same-day patient sent home), Desk Closed (two), Coffee Break (nothing
  stamped).
- **Boards:** one per shift, safe shifts only. Shift 1 starts with HOO 24,000, GUS 12,000, BON 6,000; shift 2 with
  HOO, SID, VIO; shift 3 with HOO, MEL, DAS. A careful human reads about 15 to 20 files a shift (around 20,000); the bots read 35 to 55.
- **Footer:** "Practice, not a qualification. Real clinics follow their own referral rules, and a doctor makes the
  diagnosis."

## 12. Save

`Game.progress["arcade"]["ears_please"]`: `table` (shift 1's board), `table_2` and `table_3` (shifts 2 and 3), `runs` (last 12 as
{right, oops, score, shift, files, missed_flag, over, helps}), `unlocked` (highest open shift), `warmed` (shifts
whose warm-up was played), `initials`. Reads are defensive (`arcade_scores.gd`).

## 13. Contract notes

- **Beats:**
  - `desk_shift` {options, open, best, mouse: {click: "desk_shift_<n>"}}: the solver picks the newest open shift.
  - `desk_stamp` {file, options, best, decision, kind, boss, warmup, mouse: {click: "desk_stamp_<stamp>"}}: the
    solver stamps the right call.
  - `desk_prove` {file, stamp, target, anchor, count, mouse: {click: <anchor>}}: the solver points at the best proof
    (target {kind: intake, id} | {kind: chart, freq} | {kind: sudden}).
  - `desk_note` {title, mouse: {click: "desk_note_ok"}}: the solver closes the note.
  - `arcade_initials`, `arcade_results` as in part 1 ("Back to the arcade").
  - Never a visit: no `begin_visit`, `finish_visit`, medals or coins.
- **Anchors:** `desk_stamp_fit`, `desk_stamp_refer`, `desk_stamp_today`, `desk_help`, `desk_note_ok`,
  `desk_intake_<id>`, `desk_chart_<freq>`, `desk_sudden` (the alarm clock), `desk_shift_<n>`, `arcade_initials_ok`.
- **Time, window, motion:** as in part 1 (pausable game time, centred 1280x720 playfield, reduced motion keeps
  everything still and steady).
- **Sound off:** every stamp, slip and note is words and pictures; nothing needs sound and nothing tests the player's
  hearing. Speed is rewarded only on reading (the clock); there are no beeps to answer.
- **Screenshots** (with `--shots`): `desk_picker`, `desk_warmup`, `desk_stamp_fit`, `desk_stamp_refer`, `desk_stamp_today`,
  `desk_fit_goal`, `desk_prove`, `desk_letter`, `desk_vip`, `desk_<slip outcome>`, `desk_results`, `desk_board`.

## 14. Files and commands

- `story/arcade/ears_please.gd` / `.tscn`: the scene. `desk_rules.gd`: the rules and scoring (pure).
  `desk_deck.gd`: the seeded files. `desk_run.gd`: the warm-up, targets, arrow steps and every word the desk says.
  `desk_art.gd`: the pictures. `arcade_hall.gd` / `.tscn`: the hall.
- Tests: `story/tests/test_arcade_desk.gd` (rules and deck) and `test_arcade_desk_run.gd` (shift parts and the
  hall); `tools/run_tests.sh --filter=arcade`.
- End to end, one shift with a test bot (prints `ARCADE_RESULT {json}`, exit 0 when every check passed):

  ```
  timeout 300 godot --headless --path . --fixed-fps 30 -- \
    --scene=res://story/tests/arcade_desk_check.tscn --fresh --policy=careful --speed=4 --seed=1 --shift=1
  ```

  Policies: `careful`, `keys` (arrows walk the pointer), `mouse`, `fit_everything`, `refer_everything`,
  `today_everything` (shift 3), `guess`, `help`. `--shift=N` plays shift N; `--via-title` starts from the title and picks the cabinet in the hall;
  `--picker` picks shift N (2 or 3; shift 1 has no picker) in the shift picker (by key, or a click with `mouse`) instead of going straight to it.

## 15. For Steve: clinical check (Ears, Please!)

Reply with a number only where you disagree. Each item says what the game does now.

1. **FIT** means nothing ticked, the ears alike, no air-bone gap red flag, and both ears with a pure-tone average of
   30 to 65 dB HL. Milder, more severe or flat-normal files never appear.
2. **ONE EAR WORSE** is 15 dB or more at two neighbouring frequencies (`CaseRules.is_asymmetric`, the rule the cases
   use). No file gives a cause, so every one of them refers.
3. **The intake boxes:** ear leaking, ear pain, dizzy spells, ringing in ONE ear (asked); lots of wax, odd ear shape
   (looked, from shift 2). Any YES refers. Wax says "a doctor or nurse clears it first, then test again": many
   dispensers remove wax themselves, but the game keeps it a referral (as Barnaby's Day does).
4. **AIR-BONE GAP** is masked bone 15 dB or more better than air at 500, 1k **and** 2k in one ear
   (`ClinicRules.abg_red_flag`). The deck never shows a smaller gap, or a gap at only some of those three, so the
   question "does a conductive part short of the flag refer?" never comes up in the game. Tell me if it should.
5. **Two-ear gaps** (shift 2, and its VIP): air like a FIT, masked bone 20 dB better on both sides at 500, 1k
   and 2k. Kept at 20 so masking either ear's bone has a safe window (at 25 it could be a masking dilemma); any file
   with a masking dilemma anywhere is rebuilt. The lesson: "the ears match on air,
   but bone sits way above air: a gap. REFER!"
6. **Masked bone on air** (the shift 2 warm-up): brackets with no gap are a FIT ("the gap is the distance, not the
   bracket").
7. **The proofs:** for a split, any column in the run; for a gap, any bone column of that ear with the 15 dB gap;
   on shift 3, the alarm clock for a sudden or comes-and-goes loss, and only the alarm clock proves DOCTOR TODAY. When
   there is more than one, Hoot shows a ticked box first, then the alarm clock, then the gap (it explains a split),
   then the split.
8. **Points:** a missed red flag costs -600, an extra referral -100, a clean call +300 with the combo. On shift 3 a
   same-day patient sent home costs -900 (the second closes the desk) and DOCTOR TODAY on a usual referral -100.
   Promotion needs no red flag missed, 3 in 4 clean and 8 files.
9. **Shift 3 (DOCTOR TODAY)** is playable, built on this rule while you check it: a loss that came on within 3
   days and started under a month ago (30 days), with that ear 30 dB or more worse than the other at 3 or more neighbouring
   frequencies (the chart's stand-in for "dropped since last time", since the desk has no earlier chart) and no
   middle-ear cause, is DOCTOR TODAY. A loss that comes and goes, or a sudden one that started months ago, is a red
   flag and refers as usual. The deck keeps clear of the line: same-day files started 1 to 14 days ago, older sudden
   ones 2 to 4 months ago (past the 6-week window for treatment). Hoot's lesson: "A sudden loss that started under
   a month ago: a doctor TODAY. Treatment works best started early." Tell me if same-day should end sooner (two weeks,
   say) or the drop should be different.
10. The footer says "Practice, not a qualification. Real clinics follow their own referral rules, and a doctor makes
    the diagnosis."

# Part 3: Chart Chute's new belts (Steve's note, 2026-10-21)

Steve asked for more Chart Chute modes: one where **bone conduction** is on the chart and the player calls the loss
**sensorineural, conductive or mixed**, and the **reverse cookie bite**, which he sees often enough to include. The
first is its own cabinet; the second is a fifth chute on the shapes belt. Same engine, same rules as part 1 (warm-up,
60 seconds, JAM and tell, HOOT HELP, streak, board at 90%), so only what differs is below.

## 16. REVERSE BITE: a fifth chute on the shapes belt

- The fifth chute is **5 REVERSE BITE** (key 5), with a rainbow picture (the arch the line makes) that shines when a
  chart lands. It opens at **35 s** ("NEW CHUTE!", like the others); the five chutes sit a little narrower.
- **The rule** (Chart Chute's own, on top of `ClinicRules.classify_shape`, which has no reverse bite and calls these
  flat): the low pitches (average of 250 and 500) and the high pitches (average of 4k and 8k) are each **15 dB or
  more worse** than the middle (average of 1k and 2k), and it is not a notch or a cookie bite. Like every chute, each
  dealt chart still holds its shape with any one frequency 5 dB either way.
- **The tell:** "Better in the middle, worse at both ends". **The lines:** "Mid voices are fine, the rest fades.",
  "Low hum AND birdsong are gone.", "I hear you best in the middle."
- No story patient has a reverse bite, so it has no gold card.

## 17. AIR & BONE: a third cabinet

The hall gets a third cabinet, **AIR & BONE** ("Air or bone? Find where the loss lives."). Every chart shows one
ear's air line **and its bone line**, and the three chutes are where the loss lives:

| Key | Chute (picture) | Rule (`ClinicRules.hearing_type`, the engine's own) | Tell |
|---|---|---|---|
| 1 | **SENSORINEURAL** (a snail shell: the cochlea) | no real gap: bone sits with air | "Bone sits on air: the inner ear" |
| 2 | **CONDUCTIVE** (a cork in a tube) | a gap of more than 10 dB at two or more of 500, 1k, 2k, 4k, with bone normal (average 25 or better) | "Bone is normal, air is down: the middle ear" |
| 3 | **MIXED** (the cork and the snail) | the same gap, but bone is down too | "Bone is down too, AND a gap: both" |

- **The ramp:** warm-up with SENSORINEURAL and CONDUCTIVE; MIXED opens at 15 s; left ears (blue X, bone >) at
  30 s; lookalikes at 40 s (a sensorineural chart with one 5 dB air-bone split, a conductive chart with bone at
  20, a mixed chart whose bone is only just down). No two-ear cards and no story charts on this belt.
- **Honest charts:** bone at 500, 1k, 2k and 4k, never poorer than air and never past the bone limits
  (`ClinicRules.BC_MAX_DB`). Each chart keeps its type with any one air or bone point 5 dB either way: gaps are 20
  dB or more, or 5 or less; conductive bone averages 15 or better, mixed bone 35 or worse. Bone is drawn **masked
  [ ]** where it sits 10 dB or more better than air (where a clinician would mask, `ClinicRules.BC_MASK_GAP_DB`),
  and unmasked < where it doesn't. Air: sloping or flat for sensorineural, flat or rising for conductive, sloping
  or flat for mixed.
- **Lines:** sensorineural "Loud enough, just not clear.", "Everyone mumbles!", "It's the S sounds."; conductive
  "Like my head's under water.", "My own voice booms!", "It feels blocked."; mixed "Blocked AND fuzzy.", "Ear
  trouble since I was a lad, and now this.", "Louder helps, but not enough."
- Its own board (save key `chart_chute_types`), FLUENT and ranks as in part 1.

## 18. For Steve: clinical check (the new belts)

Reply with a number only where you disagree. Each item says what the game will do.

1. **REVERSE BITE** is low (250/500) and high (4k/8k) each 15 dB or more worse than the middle (1k/2k).
2. The chute is called **REVERSE BITE** (the full name is in the tell and the NEW CHUTE line).
3. **AIR & BONE** uses the engine's type rule: a gap is more than 10 dB, conductive or mixed needs a gap at two or
   more of 500, 1k, 2k, 4k, and bone averaging 25 or better is "normal bone" (conductive), poorer is mixed.
4. Each card shows **one ear**. Bone is drawn masked where there is a 10 dB or bigger gap, unmasked where not (the
   other ear is not on the card, so the game doesn't show the masking decision itself).
5. There is **no NORMAL chute**: every chart has a loss. A fourth NORMAL chute could come later.
6. Conductive charts are flat or rising (stiffness-type), sensorineural sloping or flat, mixed sloping or flat.
   Tell me if you want rising mixed losses or sloping conductive ones too.
7. The lines in sections 16 and 17.

## 19. TYMP TOSS: a fourth cabinet (part 4)

The hall gets a fourth cabinet, **TYMP TOSS** ("Read the eardrum's peak. Which type?"). The same belt game as
Chart Chute, on a third belt: each card is one ear's **tympanogram** instead of an audiogram, drawn like the Day 10-11
tympanometer screen (pressure -400 to +200 daPa across, admittance in mL up, the shaded **normal box** from -100 to
+50 daPa and 0.3 to 1.7 mL, and the canal volume printed under the curve). Five chutes, named with the words the
tympanometer already uses (`CaseRules.TYMP_SHAPES`), sorted by the engine's own `CaseRules.tymp_type`:

| Key | Chute (picture) | Rule | Tell |
|---|---|---|---|
| 1 | **A** (a mountain) | peak inside the box | "Peak inside the box: the eardrum moves fine" |
| 2 | **B** (a pancake) | no peak (under 0.1 mL) | "No peak at all: flat as a pancake" |
| 3 | **As** (a low hill) | peak at normal pressure, under 0.3 mL | "Peak too low: a stiff eardrum" |
| 4 | **C** (a mountain with a left arrow) | peak below -100 daPa | "Peak moved left: negative pressure" |
| 5 | **Ad** (a skyscraper) | peak over 1.7 mL | "Peak sky-high: a floppy eardrum" |

- **The ramp:** warm-up with A and B; As opens at 10 s, C at 20 s, Ad at 30 s; left ears (blue) at 30 s;
  lookalikes at 40 s (an A near the box's edges, a C only 50 daPa past the line, an As at 0.25 mL, and a B with a
  tiny or large canal volume, whose patient line hints at wax or an old hole; it still goes down B).
- **Honest cards:** each peak sits at least 40 daPa and 0.05 mL from every line it could cross (a C's peak at -150
  daPa or lower; an A's between -60 and +25 daPa and 0.4 to 1.5 mL). Canal volume is normal (0.8 to 1.6 mL) except
  on those lookalike B cards.
- **Lines:** A "Just here for a check-up.", "My ears feel fine, honest!", "The wife sent me."; B "My ear feels full
  of water.", "Had a stinking cold for weeks.", "Everything's muffled on this side."; As "My hearing faded slowly.",
  "Mum had stiff ears too.", "Quieter every year, no pain."; C "My ears won't pop since the flight.", "Bit of a
  cold lately.", "Like I'm still on the plane."; Ad "I took a knock to that ear once.", "Old scar on my eardrum.",
  "A big bang, years ago."; the lookalike B lines "Never cleaned my ears. Ever." (tiny volume) and "I had grommets
  as a kid." (large volume).
- No story charts on this belt, no two-ear cards; its own board (save key `chart_chute_tymps`), FLUENT and ranks
  as in part 1. The hall's four cabinets sit a little smaller.

## 20. For Steve: clinical check (TYMP TOSS)

Reply with a number only where you disagree. Each item says what the game will do.

1. The five Jerger types use the game's tympanometer rules: normal box -100 to +50 daPa and 0.3 to 1.7 mL, flat
   under 0.1 mL.
2. The chutes are named by type letter with the tympanometer's pictures (mountain, pancake, low hill, mountain
   moved left, skyscraper).
3. A type B with a tiny or large canal volume still goes down **B**; only its line and the printed volume hint at
   wax or a hole. Sorting B into fluid / blocked / hole could be a later belt.
4. No story charts on this belt (Skye's and Barnaby's flat tymps could come later as gold cards).
5. Type C here is any peak below -100 daPa (no C1/C2 split).
6. The lines in section 19.

## 21. DEGREE DROP: a fifth cabinet (part 5)

The hall gets a fifth cabinet, **DEGREE DROP** ("How much loss? Drop it by degree."). The belt game again, on a
fourth belt: each card is one ear's audiogram, and the five chutes are the degree of loss by the **pure-tone
average of 500, 1k and 2k** (`ClinicRules.pta`), named with the scale the game's audiogram already prints
(`ClinicRules.degree_name`, Goodman 1965):

| Key | Chute (picture: the quietest everyday sound still heard) | Average of 500, 1k, 2k |
|---|---|---|
| 1 | **MILD** (a ticking clock) | 26 to 40 dB HL |
| 2 | **MODERATE** (talking) | 41 to 55 |
| 3 | **MOD-SEVERE** (a shout) | 56 to 70 |
| 4 | **SEVERE** (a drum) | 71 to 90 |
| 5 | **PROFOUND** (a jet) | over 90 |

- **The tell** glows over 500 to 2k and gives the band, e.g. "MODERATE: 500-2k average 41 to 55".
- **The ramp:** warm-up with MILD and MODERATE; MOD-SEVERE opens at 10 s, SEVERE at 20 s, PROFOUND at 30 s; left
  ears at 30 s; lookalikes at 40 s (a steep slope whose 4k and 8k are far worse than its average, or a rising chart
  whose 250 is: the average is what counts).
- **Honest charts:** shapes from Chart Chute's slopes, flats and rising charts, lifted to a band. The average sits
  at least 5 dB inside its band and stays in it with any one point 5 dB off; every point stays inside the
  audiometer's range (no "no response" marks).
- **Lines:** mild "I miss the odd word.", "Fine one-to-one, not in a crowd."; moderate "I live on 'pardon?'.", "The TV
  is too loud, says my wife."; mod-severe "I only catch people who face me.", "Phone calls are hopeless."; severe "I
  hear voices, not words.", "Shouting is all I get."; profound "I feel the bass more than hear it.", "I lip-read
  everything."
- No story charts, no two-ear cards; its own board (save key `chart_chute_degrees`). With five cabinets the hall
  draws each one a little smaller still.

## 22. For Steve: clinical check (DEGREE DROP)

Reply with a number only where you disagree. Each item says what the game will do.

1. Degree is the **three-frequency average (500, 1k, 2k)**, the one the game's speech days use, not a four-frequency
   average with 4k.
2. The bands are the ones the audiogram already prints (Goodman): mild 26-40, moderate 41-55, moderately severe
   56-70, severe 71-90, profound over 90.
3. The chute says **MOD-SEVERE** to fit; the tell and the NEW CHUTE line say "moderately severe".
4. The pictures are the quietest everyday sound still heard (clock, talking, a shout, a drum, a jet), a loose
   "familiar sounds" idea, not exact levels.
5. No "normal" chute (every chart has a loss) and no profound charts with "no response" arrows.
6. The lines in section 21.

## 23. FLAT OUT: a sixth cabinet (part 6)

The hall gets a sixth cabinet, **FLAT OUT** ("Flat tymp? Read the canal volume."). It follows on from TYMP TOSS:
a flat (type B) tympanogram is not one finding but three, and the **canal volume** says which
(`CaseRules.tymp_b_reading`, the same rule Day 10 and Day 11 use). Each card is one ear's tympanogram with a
**volume gauge** across its top: TINY under 0.6 mL, NORMAL 0.6 to 2.0, BIG over 2.0, a pointer on the reading.

| Key | Chute (picture) | The card |
|---|---|---|
| 1 | **FLUID** (a water drop) | flat, canal volume normal (0.8 to 1.6 mL): fluid behind the eardrum |
| 2 | **WAX** (a bath plug) | flat, canal volume tiny (0.3 to 0.45 mL): wax, or the probe against the canal wall |
| 3 | **HOLE** (a doughnut) | flat, canal volume big (2.6 to 3.2 mL): a hole in the eardrum, or an open grommet |
| 4 | **PEAK** (a mountain) | not flat at all: a type A, As or C peak, normal volume |

- **The tell** glows over the gauge for the three flat chutes ("WAX: Canal under 0.6 mL: blocked") and over the
  curve for PEAK ("PEAK: A peak, so it isn't flat").
- **The ramp:** warm-up with FLUID and WAX; HOLE opens at 10 s, PEAK at 25 s; left ears at 30 s; lookalikes at
  40 s. A lookalike tells the wrong story: a flat card whose patient says something that fits another chute ("Never
  cleaned my ears. Ever." over a normal volume), or a shallow As peak whose patient says "My ear feels full of
  water." The numbers win.
- **Honest cards:** every reading stays on its side of the line with the volume 0.1 mL either way, and a flat
  card's peak stays under the flat line with 0.04 mL to spare; PEAK cards keep TYMP TOSS's margins and leave out Ad,
  so the gauge never covers a peak.
- **Lines:** fluid "My ear feels full of water.", "Had a stinking cold for weeks.", "Everything's muffled on this
  side."; wax "Never cleaned my ears. Ever.", "I use cotton buds every day.", "It went dull after a swim."; hole "I
  had grommets as a kid.", "It popped on a dive.", "My ear runs now and then."; peak "Just here for a check-up.", "My
  ears feel fine, honest!", "Ears pop on planes, that's all."
- No story charts, no two-ear cards; its own board (save key `chart_chute_flats`). With six cabinets the hall draws
  each one narrower and fits long names to their marquee. The NEW! starburst sits on each cabinet's top edge.

## 24. For Steve: clinical check (FLAT OUT)

Reply with a number only where you disagree. Each item says what the game will do.

1. The volume lines are the game's own adult ones (`CaseRules`): under 0.6 mL tiny, over 2.0 mL big. No child
   volumes.
2. A tiny volume reads **WAX** on the chute; the tell adds "or the probe against the canal wall". That is what a
   newcomer should check first: look in the ear, re-seat the probe.
3. A big volume reads **HOLE**, and the tell says "or an open grommet", so a big volume in a child with tubes is
   good news, not a fault.
4. FLUID is the name for a flat tymp with a normal volume (no "otitis media" on the chute).
5. PEAK is the "not flat" chute: A, As and C peaks only (no Ad), normal volume.
6. The pictures (drop, plug, doughnut, mountain) and the lines in section 23.
