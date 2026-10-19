# Arcade mode: Chart Chute

The arcade is the quick-play corner of Booth Camp: short runs, a clock, a streak and a high-score table. Steve picked
two cabinets from the shortlist (2026-10-19): **Chart Chute** first, then **Ears, Please!**. This file covers Chart
Chute. It opens from the title's **Arcade** button (beside Freestyle).

Arcade is not Freestyle. Freestyle is a whole visit at your own pace. Chart Chute drills one skill in a minute:
**reading the shape of an audiogram at a glance**.

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
   back to the title.

## 2. The ramp inside the run

| Run time | What changes |
|---|---|
| 0 s | SLOPE and NOTCH, right ear only (red O) |
| 10 s | the COOKIE BITE chute opens ("NEW CHUTE!", and the NEXT card is its first chart) |
| 25 s | the RISING chute opens |
| 30 s | left-ear charts join (blue X): same shapes |
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
  - `arcade_results` {options, best, mouse: {text: "Back to the title"}}. The solver goes back to the title.
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
  - `title_arcade` (from the check bot's `--via-title` keys run)

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
    - `keys`: real 1-4 keys, with KEY as the initials, then T back to the title.
    - `mouse`: real clicks only, with BAA as the initials, then Back to the title.
    - `guess`: a random open chute every time.
    - `help`: HOOT HELP every time.
    - `slip`: real keys, but each two-ear card first goes down the other ear's chute (a JAM with the "Other ear!"
      cue, and the `chute_jam_tell` shot), then the right one when it comes back.
  - `--via-title` starts from the title's Arcade button.
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
