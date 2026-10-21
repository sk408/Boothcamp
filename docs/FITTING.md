# Booth Camp: The Fitting (Day 14, the finale)

Gus comes back for his hearing aids. Day 1 ended on a teaser (one big switch, the world in colour, "did you just
say DISHES?") and Hoot's promise: "Real fittings take fine-tuning and a few weeks of getting used to. That's a
later level!" This is that level. Steve reviews every clinical number and line.

| | |
|---|---|
| Teaches | why the workup comes first; picking a style (open fit for good lows, the occlusion effect); a prescription target; measuring in the real ear and matching the target band by band; too much gain (too loud, and feedback with an open dome); the first weeks with aids |
| Length | target 6-7 minutes |
| Opens | from the chapter select like every day (`requires: "bev"` only picks UP NEXT) |
| Level scene | `res://story/level_fitting.tscn` (`story/level_fitting.gd`) |
| Patient | `core/patients/gus_fit.tres`: Gus's own thresholds (a copy of `gus.tres`), bone = air. Its own id because `Game.chapter_for_patient` returns the first match, so `gus` would score as Day 1 (like `barnaby_after`). The clinic draws Gus by default. |
| Mini-game | `story/games/target_match.gd` (`TargetMatch`): the real-ear graph, three band handles, the "what Gus hears" strip |
| Paper | `story/papers/paper_fitting.gd`: SPORTS: THE FITTING CARD (the summary's `sports_script`) |

The game never names a commercial fitting formula or product. In play the target is "his prescription".

---------------------------------------------------------------------------------------------

## 1. Beat by beat

PR 1 (this design's first PR) builds beats 1, 2, 4, 6 and 7. PR 2 adds 3, 5 and the counselling choice in 6.

| # | Beat | What happens | Medal |
|---|---|---|---|
| 1 | Back again | Gus walks in ("Plain bagel today. No seeds. Doris checked."). Hoot opens the file: red flags none (Day 1), bone matched air (an inner-ear loss), words clear when loud enough, some trouble in noise: a **FIT**. The four lines go on the notes board. | - |
| 2 | Pick a style | Three options, one right: a **tiny speaker in the canal with an open dome** (his lows are nearly normal, so leave the ear open). Wrong: a **behind-the-ear aid with a sealed custom earmold** ("Why do I sound like I'm talking in a barrel?": the occlusion effect) and a **custom shell that fills the canal** ("Why does my bagel sound like a marching band?"). A wrong pick is explained and greyed; pick again. | style: gold first pick, silver second, bronze third |
| 3 | The probe tube (PR 2) | Slide the thin tube in to within about 5 mm of the eardrum. Too shallow and the high pitches read low; too deep and Gus says OW. PR 1: Hoot places it while explaining it. | probe |
| 4 | Match the target | The aids go on with the software's first guess. Doris comes in and says "Gus, the finches are back! Shall I put the kettle on?", which Gus hears with the high sounds missing ("_u_, _e _in__e_ are ba_!"). The player raises three bands (1k, 2k, 4k) until each sits inside the green zone (target ±5 dB). Every matched band brings back its sounds in the strip and a wave of colour; all three bring the birdsong. Then Hoot does the left ear at Hoot speed. | match: gold at par with every band within 2 dB, silver within par + 2, bronze otherwise |
| 5 | The loud-sound check (PR 2) | Doris drops a pan. Loud sounds must be loud but never painful: the output limit. | loud |
| 6 | The first weeks | PR 1: one Hoot line (the brain needs a few weeks; wear them all day; a follow-up to fine-tune). PR 2: a choice of what to tell Gus. | (PR 2) counsel |
| 7 | Payoff | Full colour. The dishes callback, with a twist: Gus pretends the new aids can't hear "dishes"; Hoot just measured them, they're perfect; Doris has a list. The Daily Decibel, then Hoot's finale line. | - |

---------------------------------------------------------------------------------------------

## 2. The target match (`story/games/target_match.gd`)

A real-ear graph: frequency across (250 Hz to 8 kHz), **boost** up (insertion gain, 0 to 40 dB). The dashed line is
his prescription target with a green zone of ±5 dB around it; the solid line is what the probe mic measures with the
aid on. Three handles: **MIDS** (1 kHz), **HIGHS** (2 kHz), **TOPS** (4 kHz). Below 1 kHz the line fades toward 0:
with an open dome the low sounds come in naturally, and Gus's lows are nearly normal anyway. Above 4 kHz it holds
flat to 6 kHz.

Controls: Left / Right picks a band, Up / Down boosts it by 2 dB (held keys repeat), Enter is Done; with the mouse,
each band has ▲ and ▼ buttons and a click on a column picks it. Done unlocks once all three bands are in the green.

**The target.** A public, textbook formula (NAL-R, Byrne and Dillon 1986) stands in for the fitting software's
prescription, because it can be shown in a few lines: insertion gain at f = 0.31 × threshold(f) + 0.05 × (threshold
at 500 + 1k + 2k) + k(f), with k = 250 −17, 500 −8, 750 −3, 1k +1, 1.5k +1, 2k −1, 3k −2, 4k −2, 6k −2 (dB), and
never below 0. For Gus's right ear that is about 13 dB at 1k, 16 at 2k and 19 at 4k (left: 13, 17, 21). Real
clinics use newer prescriptions built into the fitting software (question 2).

**The first guess.** The aid starts 6, 10 and 14 dB under target at 1k, 2k and 4k. That is the point of measuring:
the software's first guess is an average ear, and in a real ear it usually comes out short in the highs.

**What Gus hears.** Doris's line in the strip loses the sounds of the bands that are not matched yet, roughly where
the familiar-sounds chart puts them: MIDS "ch", "sh"; HIGHS "k", "g", "p", "t" ("ck" counts as one k); TOPS "f",
"s", "th". Unmatched: "_u_, _e _in__e_ are ba_! _all I _u_ _e _e__le on?"; all three: the whole line (question 3).

**Too much.** A band 6 dB or more over target is an overshoot: Gus winces ("Whoa! The fridge sounds like a jet
engine!"), or at TOPS the aid whistles ("Wheeee!": feedback, which an open dome gets first). The first overshoot
of each kind costs one comfort point and the clean-fit part of technique.

**Moves and par.** A move is a run of presses on one band in one direction; picking another band or reversing
starts a new move (an overshoot fixed costs a stroke). Par is the number of bands that start outside the green: 3.

**Hoot speed.** After the right ear, Hoot matches the left (the same three bands, animated, unscored).

---------------------------------------------------------------------------------------------

## 3. Scoring

The visit stores `Game.set_audiometry_results(res)` with the usual three parts, so the grade, coins and paper
work as on every day:

| Part | From |
|---|---|
| accuracy | the right ear's match: per band 1.0 within 2 dB, then 0.05 less per dB up to the zone's edge (0.85 at 5 dB); the mean of the three |
| technique | 0.6 × style (1.0 first pick, 0.5 second, 0.2 third) + 0.4 × clean (1.0 with no overshoot, 0.5 with one kind, 0 with both) |
| efficiency | 1.0 at or under par; 0.12 less per extra move, never below 0.3 |
| care | comfort, as on every day (an overshoot costs a point) |

`res.fitting` keeps the details for the paper and the bot: `{ear, bands: [{freq, target, start, final, err}], moves,
par, style, style_tries, overshoots, left_by_hoot}`.

---------------------------------------------------------------------------------------------

## 4. Open questions for Steve (defaults stand unless you object; answer by number)

1. **Gus as the finale patient.** Default yes: his story closes the loop from Day 1. The alternative is a new patient.
2. **The target formula.** Default NAL-R (public, 1986) shown as "his prescription", never by name in play. Real
   fittings use the software's NAL-NL2 or DSL v5 targets, which the game can't reproduce. Is NAL-R close enough for
   a mild-to-moderate sloping loss?
3. **The sounds in the strip.** Default MIDS ch/sh, HIGHS k/g/p/t, TOPS f/s/th, after the familiar-sounds chart.
   Swap any?
4. **Style choice.** Default: the open receiver-in-canal is the only right answer for Gus, and both wrong answers
   are wrong for occlusion. A custom aid with a big vent could work in real life; we keep it simple.
5. **The zone.** Default ±5 dB at 1k, 2k and 4k, matched in 2 dB steps. Some clinics allow more at 4k.
6. **The first guess.** Default 6, 10 and 14 dB under target at 1k, 2k, 4k.
7. **The overshoot lines.** Default: 6 dB over at 1k or 2k is "too loud", 6 dB over at 4k whistles. Real feedback
   depends on the vent and the ear; this is a teaching shortcut.
8. **The left ear at Hoot speed.** Default yes, to keep the day short.
9. **PR 2.** Default: the probe-tube placement, the loud-sound check and a counselling choice (acclimatisation over
   a few weeks, wear them all day, follow-up in one to two weeks). Anything to add or drop?
