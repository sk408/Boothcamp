# Booth Camp: The Fitting (Day 14, the finale)

Gus comes back for his hearing aids. Day 1 ended on a teaser (one big switch, the world in colour, "did you just
say DISHES?") and Hoot's promise: "Real fittings take fine-tuning and a few weeks of getting used to. That's a
later level!" This is that level. Steve reviews every clinical number and line.

| | |
|---|---|
| Teaches | why the workup comes first; picking a style (open fit for good lows, the occlusion effect); placing the probe tube near the eardrum; a prescription target; measuring in the real ear and matching the target band by band; too much gain (too loud, and feedback with an open dome); the output limit (loud but never painful); the first weeks with aids |
| Length | target 7-8 minutes |
| Opens | from the chapter select like every day (`requires: "bev"` only picks UP NEXT) |
| Level scene | `res://story/level_fitting.tscn` (`story/level_fitting.gd`) |
| Patient | `core/patients/gus_fit.tres`: Gus's own thresholds (a copy of `gus.tres`), bone = air. Its own id because `Game.chapter_for_patient` returns the first match, so `gus` would score as Day 1 (like `barnaby_after`). The chapter id is `gus_fit` too, as every chapter id is its patient id. The clinic draws Gus by default. |
| Mini-games | `story/games/probe_tube.gd` (`ProbeTube`): the canal and the probe tube; `story/games/target_match.gd` (`TargetMatch`): the real-ear graph, three band handles, the "what Gus hears" strip; `story/games/loud_check.gd` (`LoudCheck`): the loud limit dial and the pan |
| Paper | `story/papers/paper_fitting.gd`: SPORTS: THE FITTING CARD (the summary's `sports_script`) |

The game never names a commercial fitting formula or product. In play the target is "his prescription".

---------------------------------------------------------------------------------------------

## 1. Beat by beat

PR 1 built beats 1, 2, 4 and 6 (with one Hoot line for the first weeks). PR 2 added 3, 5 and the counselling choice in 7.

| # | Beat | What happens | Medal |
|---|---|---|---|
| 1 | Back again | Gus walks in ("Plain bagel today. No seeds. Doris checked."). Hoot opens the file: red flags none (Day 1), bone matched air (an inner-ear loss), words clear when loud enough, some trouble in noise: a **FIT**. The four lines go on the notes board. | - |
| 2 | Pick a style | Three options, one right: a **tiny speaker in the canal with an open dome** (his lows are nearly normal, so leave the ear open). Wrong: a **behind-the-ear aid with a sealed custom earmold** ("Why do I sound like I'm talking in a barrel?": the occlusion effect) and a **custom shell that fills the canal** ("Why does my bagel sound like a marching band?"). A wrong pick is explained and greyed; pick again. | style: gold first pick, silver second, bronze third |
| 3 | The probe tube | Before the aids go in, the player slides the thin tube in until its tip sits within 5 mm of the eardrum (§2b). Too shallow and the high pitches read low; too deep and Gus says OW. | probe: gold with no slip, silver with one, bronze with more |
| 4 | Match the target | The aids go on with the software's first guess. Doris comes in and says "Gus, the finches are back! Shall I put the kettle on?", which Gus hears with the high sounds missing ("_u_, _e _in_e_ are ba_!"). The player raises three bands (1k, 2k, 4k) until each sits inside the green zone (target ±5 dB). Every matched band brings back its sounds in the strip and a wave of colour; all three bring the birdsong. Then Hoot does the left ear at Hoot speed. | match: gold at par with every band within 2 dB, silver within par + 2, bronze otherwise |
| 5 | The loud-sound check | Doris drops a pan ("I always carry a pan. Forty years of marriage, Hoot."). Loud sounds must be loud but never painful: the player sets the aid's loud limit (§2c). | loud: gold on the first drop, silver within three, bronze after |
| 6 | Payoff | Full colour. The dishes callback, with a twist: Gus pretends the new aids can't hear "dishes"; Hoot just measured them, they're perfect; Doris has a list. | - |
| 7 | The first weeks | What to tell Gus: find the three right tips of five (§2d). Then Hoot's finale line and the Daily Decibel. | counsel: gold with no slip, silver with one, bronze with two |

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
"s", "th". Unmatched: "_u_, _e _in_e_ are ba_! _all I _u_ _e _e__le on?"; all three: the whole line (question 3).

**Too much.** A band 6 dB or more over target is an overshoot: Gus winces ("Whoa! The fridge sounds like a jet
engine!"), or at TOPS the aid whistles ("Wheeee!": feedback, which an open dome gets first). The first overshoot
of each kind costs one comfort point and the clean-fit part of technique.

**Moves and par.** A move is a run of presses on one band in one direction; picking another band or reversing
starts a new move (an overshoot fixed costs a stroke). Par is the number of bands that start outside the green: 3.

**Hoot speed.** After the right ear, Hoot matches the left (the same three bands, animated, unscored), tube and all.

---------------------------------------------------------------------------------------------

## 2b. The probe tube (`story/games/probe_tube.gd`)

A cross-section of the right ear canal: the opening at the left, the eardrum at the right, 25 mm apart (an
adult's canal). The tube's tip starts 17 mm from the eardrum and moves 3 mm a press: Right or Up slides it in,
Left or Down out, Enter locks it (the mouse has Out, In and Lock it buttons). The green zone is the last 5 mm
before the drum.

- **Lock short of the zone:** refused, and a slip. Hoot: "Too shallow! The high pitches would read low."
- **Touch the drum** (the step past 2 mm): a slip, Gus says "OW! That's my eardrum, not a doorbell!", the tube
  springs back to 8 mm, and the first touch costs one comfort point.
- **Lock in the zone** (5 or 2 mm): done.

The "what the probe mic reads" strip under the canal draws why: with the tip far from the drum, the mic sits in a
dip in the sound a quarter wavelength from the drum (343 m/s ÷ 4 × the distance: about 5 kHz at 17 mm), so the
highs read low; as the tube goes in the dip slides up and off the chart, and within 5 mm the line is flat to 8
kHz. It is a teaching picture, not a measurement (question 10).

## 2c. The loud-sound check (`story/games/loud_check.gd`)

The aid's loud limit (its output limit) is a dial from 1 to 5; a meter shows how Doris's pan lands for Gus:
SQUASHED, JUST RIGHT or OUCH. The first drop plays by itself on the software's first guess, notch 4, and stings
("Ooh! That one stings a bit."). Then the player turns the dial (Left / Right, or the - and + buttons) and drops
again (Enter, or Drop the pan) until a clang lands just right.

| Notch | The clang for Gus | Gus |
|---|---|---|
| 1 | squashed | "Was that a pan or a pillow?" |
| 2 | squashed | "Hmm. Sounds like a pan full of socks." |
| 3 | **just right** (done) | "CLANG! Loud... but fine. Now THAT's a pan." |
| 4 | ouch (the first guess) | "Ooh! That one stings a bit." |
| 5 | ouch, and the first drop here costs one comfort point | "YOWCH! My fillings rattled!" |

The clang always plays at the same quiet level: how loud it is for Gus is only drawn on the meter (the game never
plays a loud sound to make a joke). Real clinics set the output limit below the patient's discomfort level and
check it with loud sounds; the dial is a teaching shortcut (question 11).

## 2d. The first weeks (the counselling choice)

"What should Gus know about his first weeks? Find all three." Five tips, three right:

| Tip | Right? | What happens |
|---|---|---|
| Wear them all day, every day, right from the start. | yes | Hoot: all-day wear teaches his brain fastest; off for sleep, showers and swimming. |
| Save them for special days so they last longer. | no | Gus: "Like my good suit? I've worn it once since 1987." Hoot: aids only work when they're worn. |
| Give your brain a few weeks to get used to sound. | yes | Hoot: the fridge, his footsteps, paper rustling are loud at first; his brain settles in weeks. |
| Turn them all the way up whenever it gets noisy. | no | Gus: "Full blast at Bev's bingo? I'd hear the numbers from the next town!" Hoot: turning up boosts the noise too; face the talker and sit away from the racket. |
| Come back in a week or two so we can fine-tune. | yes | Hoot: the follow-up fine-tunes from his real life; a fitting is never one visit. |

A wrong pick is explained and leaves the list; the choice ends when all three right tips are found (question 12).

---------------------------------------------------------------------------------------------

## 3. Scoring

The visit stores `Game.set_audiometry_results(res)` with the usual three parts, so the grade, coins and paper
work as on every day:

| Part | From |
|---|---|
| accuracy | the right ear's match: per band 1.0 within 2 dB, then 0.05 less per dB up to the zone's edge (0.85 at 5 dB); the mean of the three |
| technique | 0.25 × style + 0.2 × probe + 0.2 × loud + 0.15 × counsel + 0.2 × clean. Style: 1.0 first pick, 0.5 second, 0.2 third. Probe and counsel: 1.0 with no slip, 0.5 with one, 0.2 with more. Loud: 1.0 on the first drop, 0.5 within three, 0.2 after. Clean: 1.0 with no overshoot, 0.5 with one kind, 0 with both |
| efficiency | 1.0 at or under par; 0.12 less per extra move, never below 0.3 |
| care | comfort, as on every day (the first overshoot of each kind, the first touch of the eardrum and the first drop at notch 5 each cost a point) |

`res.fitting` keeps the details for the paper and the bot: `{ear, bands: [{freq, target, start, final, err}], moves,
par, style, style_tries, probe_mistakes, loud_drops, counsel_slips, overshoots, left_by_hoot}`. The paper adds one
line for the rest: "Tube: first try. Loud limit: first drop. Talk: three of three, no slips."

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
   a few weeks, wear them all day, follow-up in one to two weeks). Built in PR 2; questions 10-12 cover the details.
10. **The probe tube.** Default: lock within 5 mm of the eardrum, 3 mm a step from 17 mm, a 25 mm canal, a touch
    springs the tube back. Many clinics mark the tube at a set length from the ear's notch instead; we keep the
    distance on screen. Is the dip drawing (a quarter wavelength from the drum) a fair picture for a newcomer?
11. **The loud-sound check.** Default: a five-notch dial, the first guess one notch too loud, one right notch, the
    loudness only drawn. Real output limits are set from the patient's discomfort levels, per band; is the single
    dial too simple, or is "loud but never painful" the right first lesson?
12. **The counselling tips.** Default: all-day wear (off for sleep, showers, swimming), a few weeks to get used to
    sound, a follow-up in one to two weeks; wrong: saving them for special days, turning them all the way up in
    noise. Swap or add any (cleaning, batteries or charging, realistic expectations in noise)?
