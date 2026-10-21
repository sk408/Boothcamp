# Booth Camp: The Tune-Up (Day 15, the follow-up visit)

Two weeks after his fitting, Gus comes back for his first follow-up. Day 14 ended with "Come back in a week or two
so we can fine-tune" and the paper's tip "Real fittings: measure in the ear, then fine-tune over the first few
weeks". This is that visit: the common complaints a newcomer meets at a first follow-up, and the adjustment (or the
talk) that fixes each one. Steve asked for "a follow up day with common adjustments and complaints" (2026-10-21).
Steve reviews every clinical line.

| | |
|---|---|
| Teaches | open questions at a follow-up ("where do you have trouble?"); the aid's datalog (hours worn a day); the common first complaints and their fixes: sharp loud sounds (soften the loud highs, not the whole aid), whistling at a hug or a cap (the feedback test before a tighter dome), a noisy hall (a noisy-places program with forward-focused mics, plus where to sit, with honest expectations), part-time wear (a talk, not a knob); a fix that causes a new problem |
| Length | target 6-7 minutes |
| Opens | from the chapter select like every day (`requires: "gus_fit"` only picks UP NEXT) |
| Level scene | `res://story/level_tuneup.tscn` (`story/level_tuneup.gd`) |
| Patient | `core/patients/gus_tune.tres`: Gus's thresholds again (a copy of `gus_fit.tres`). Its own id, as every chapter id is its patient id and `Game.chapter_for_patient` returns the first match. |
| Mini-game | `story/games/tune_desk.gd` (`TuneDesk`): the tune-up desk, one complaint ticket at a time and a tray of seven tools |
| Paper | `story/papers/paper_tuneup.gd`: SPORTS: THE TUNE-UP TICKETS (the summary's `sports_script`) |

The game never names a product or a manufacturer's feature. "The feedback test" and "a noisy-places program" are the
generic names.

---------------------------------------------------------------------------------------------

## 1. Beat by beat

PR 1 builds beats 1 to 5 and the wrap line. PR 2 adds Hoot's movie before the day, the listening check with a
clogged wax guard, and the next-visit plan (section 5).

| # | Beat | What happens | Medal |
|---|---|---|---|
| 1 | Two weeks later | The calendar card (TWO WEEKS LATER). Gus walks in: "The finches are back. So is every fridge, newspaper and teaspoon in town." Doris follows with her list. Hoot: follow-ups are where a fitting gets good. | - |
| 2 | Ask | Pick the opening question (§2). Then Gus and Doris tell three stories, and each goes on the notes board as a ticket: sharp paper and spoons, a whistle at hugs and his cap, bingo numbers lost in the crowd. | ask: gold first pick, silver second, bronze third |
| 3 | The datalog | Hoot plugs the aids into the computer: the aids keep a diary of the hours they are worn. 3.5 hours a day, and none on bingo night. A fourth ticket. | - |
| 4 | Tune | The tune-up desk (§3): each ticket in turn, pick the tool that fixes it. A wrong tool gets its own funny result and Hoot's reason; a ticket ends on the right tool. | tune: gold with no wrong tool, silver with one or two, bronze with more |
| 5 | Bingo night | Saturday at Bev's hall (Day 13's bingo caller): the noisy-places program on, Gus sitting facing Bev. "Two little ducks: twenty-two!" BINGO. Then Doris: it's his turn to wash up. The dishes, one more time. | - |
| 6 | Wrap | Hoot's line, then the Daily Decibel. | - |

---------------------------------------------------------------------------------------------

## 2. The opening question

"How should we start?" Three options, one right; a wrong pick is explained and greyed.

| Option | Right? | What happens |
|---|---|---|
| Where do you have trouble with them? | yes | Gus: "Where DON'T I?" The stories follow. Hoot: an open question opens the stories. |
| Are they perfect? | no | Gus: "Perfect!" Doris clears her throat and holds up her list. Hoot: a yes-or-no question gets a polite yes. |
| Have you been wearing them? | no | Gus: "Oh, yes. Mostly." Hoot: true, but it tells us little; the aid's diary will answer that one anyway. |

---------------------------------------------------------------------------------------------

## 3. The tune-up desk (`story/games/tune_desk.gd`)

A panel left of the fitting shot (like the target match). The current ticket sits on top, the four tickets show as
chips with a tick once fixed, and the tool tray fills the bottom: Left / Right picks a tool, Enter uses it; with the
mouse, a click on a tool uses it. A right tool stamps the ticket FIXED and the next one slides in.

**The seven tools:** SOFTEN LOUD HIGHS, WHOLE AID DOWN, FEEDBACK TEST, TIGHTER DOME, NOISY-PLACES PROGRAM, WHOLE AID
UP, TALK IT THROUGH.

| Ticket | Right tool | Why (Hoot) |
|---|---|---|
| Paper and spoons sound sharp | SOFTEN LOUD HIGHS | Ease the boost for loud high sounds only; soft voices keep theirs. The rest settles as his brain gets used to sound. |
| Whistles at hugs and his cap | FEEDBACK TEST | The aid plays a test sound, learns its own whistle path and cancels it. A tighter dome would stop it too, but blocks his good lows. |
| Bingo numbers lost in the crowd | NOISY-PLACES PROGRAM | The mics focus forward on Bev and calm the chatter behind; he sits facing Bev, back to the crowd. It won't erase the crowd, but it tips the balance. |
| Worn 3.5 hours a day | TALK IT THROUGH | No knob fixes wear time. With the spoons fixed: all day, every day, so his brain gets the practice. |

The wrong tools have their own results. Some of them:

- WHOLE AID DOWN on the sharp sounds: Doris goes muffled again ("Your _ea'_ ready, dear!", Day 14's strip), and
  Hoot says down-for-everything loses soft speech too.
- TIGHTER DOME on the whistle: the whistle stops, and Gus sounds like he's in a barrel (the occlusion effect from Day
  14).
- WHOLE AID UP anywhere: too loud for Gus ("The spoon! It's a GONG!", or a whistle). The first time costs a comfort
  point.
- A knob on the wear-time ticket: "No knob fixes wear time. Some tickets need a talk, not a tweak."

---------------------------------------------------------------------------------------------

## 4. Scoring

The visit stores `Game.set_audiometry_results(res)` with the usual three parts:

| Part | From |
|---|---|
| accuracy | the desk: per ticket 1.0 on the first tool, 0.5 on the second, 0.2 after; the mean of the four |
| technique | 0.5 × the opening question (1.0 first pick, 0.5 second, 0.2 third) + 0.5 × safe (1.0 with no WHOLE AID UP, 0.5 with one, 0 with more) |
| efficiency | 1.0 at par (one tool per ticket: 4); 0.12 less per extra tool, never below 0.3 |
| care | comfort, as on every day (the first WHOLE AID UP costs a point) |

`res.tuneup` keeps the details for the paper and the bot: `{tickets: [{id, fix, tries, wrong: [tool ids]}],
tools_used, par, ask_tries, ups}`.

---------------------------------------------------------------------------------------------

## 5. PR 2 (built)

- **Hoot's movie before the day** ("The Tune-Up"), with Hoot's lead-in as on every movie day: why the first weeks
  feel loud (the brain re-learning sound), the aid's diary, a whistle as the aid hearing itself, and forward mics in
  a crowd.
- **The listening check** (after the ask, `story/games/wax_guard.gd`). The right aid "went quiet on Tuesday". The
  player listens through a listening tube, checks a part (battery, mic cover, wax guard: a wrong one is explained
  and greyed), finds the plugged wax guard and clicks in a new one. Medal `check`.
- **The next visit** (after the desk). "When should Gus come back?": a check in a few months and a hearing test every
  year, sooner if anything changes (right); only when they break, or every week (wrong). Medal `plan`. Both picks
  show on the paper; the three scores are unchanged.

---------------------------------------------------------------------------------------------

## 6. Open questions for Steve (defaults stand unless you object; answer by number)

1. **Gus again.** Default yes: the follow-up closes his story. The alternative is a new patient with a new fitting.
2. **Two weeks after the fitting.** Default two weeks (Day 14 said "a week or two").
3. **The four tickets.** Default: sharp loud sounds, a whistle at hugs and his cap, a noisy bingo hall, 3.5 hours a
   day. Swap or add any (his own voice sounds boomy, an aid keeps falling out, the TV, the phone)?
4. **The fixes.** Default: soften the loud highs (not the whole aid) and reassure; the feedback test before a
   tighter dome; a noisy-places program (directional mics and noise reduction) plus seating, with honest
   expectations; a talk for wear time. Right for a newcomer?
5. **The datalog.** Default: Hoot reads it for the player (3.5 hours a day; none on bingo night), and the target is
   "all waking hours". Should the player read it themselves?
6. **One right tool per ticket.** Default yes, to keep it a clear puzzle. In real life a talk goes with every fix;
   Hoot says so in the right-tool lines.
7. **PR 2** (section 5): the movie, the wax guard listening check and the next-visit plan. Anything else a newcomer
   meets at a first follow-up that you'd add (cleaning, charging, putting the aids in)?
