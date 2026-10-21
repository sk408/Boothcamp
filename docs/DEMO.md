# The career-fair demo

The plan's item 4 asks for "a short demo version for career fairs", and research/design-notes.md §7 calls Gus "the
seed of a 10-minute career fair demo". This is that version: one visit with Grandpa Gus, from "HELLO? Is this the
beep place?" to "Doris... did you just say DISHES?", in about seven minutes, ending with "Like puzzles AND people?
Hearing care could be your job. Ask at this booth!"

## 1. Starting it

| Where | How |
|---|---|
| Windows | `BoothCamp.exe -- --demo`, or double-click `BoothCamp-Demo.cmd` next to the exe (`tools/booth/BoothCamp-Demo.cmd` in the repo) |
| The web page | add `?demo` to the address: `https://<the Pages address>/?demo` |
| Testing | `tools/autoplay_check.sh --demo` (add `--mouse --seed=3` for clicks only); `tools/shots.sh /abs/dir --demo` |

In demo mode (`Game.is_demo()`):

- The demo has its own save (`user://demo_save.json`), so a booth never touches a player's progress. Its settings
  (volume, key style, full screen) stay between visitors; everything else is wiped for each one.
- The title is the logo, one **Play** button and the line "Find out what Gus can't hear, then help him hear it. About
  7 minutes." No Days, Freestyle, Arcade, Options, New player or Quit, and no stats. Esc still opens the options
  (volume) for the staff.
- The safety notice ("This is a game, not a hearing test.") greets every visitor, not once per session.
- Quick visit is always on: Hoot finishes the beeps after the visitor's stamps.
- The web build only reads `demo` from the address; nothing else in it can change the game.
- **The attract loop.** After 30 seconds with nobody at the title (`--attract-after=N` for another delay), Hoot and
  Gus fill the screen over the clinic: Hoot waves and talks through the visit one teaser at a time, round and
  round, with "Press a key or click to play" pulsing and the tagline under it. Any key, click or real mouse
  movement ends it and the safety notice greets the visitor. It is silent, keeps the safety footer on screen, and
  never runs under autoplay.

## 2. The visit (`story/level_demo.gd`)

Six steps on the HUD: Chat, Peek, Phones, Beeps, Chart, Fit. It reuses Day 1's mini-games and Day 14's target match
as they are; the patient is `gus`, so the paper scores it like Day 1.

1. **Chat.** Gus walks in with his sesame bagel. Hoot: "Welcome to Booth Camp! Hearing care pros solve puzzles like
   Gus every day. Let's try one!" One question from Day 1's first round (noisy places, the turbo walker, the hardest
   sounds). Whatever the pick, Gus's "dishes / fishes" line comes out (Hoot asks it himself after a joke or the
   noise question), because the payoff needs it; the medal is the visitor's. Hoot names the red flags (pain,
   drainage, dizziness, sudden or one-sided change); Gus has none.
2. **Peek.** Day 1's otoscopy: find the sesame seed, choose not to poke, the sneeze. "Cartoon physics! Real ears
   can't sneeze things out."
3. **Phones.** Glasses off, the red and blue earphone cups. Hoot gives Gus the instructions himself (Day 1 lets the
   player pick them): "Gus: press whenever you hear a beep, even a faint one. Let go when it stops."
4. **Beeps.** Better ear first (both the same, so right). The right ear is coached at 1 kHz, the visitor does one
   more stamp alone, then Hoot fills in the rest of the ear in a montage; the left ear is Hoot's montage too. The
   audiometer's new plan key `montage_after` does this (§5).
5. **Chart.** The audiogram reveal while Gus walks to the desk: "A sloping high-frequency loss: the classic!" and
   "Soft sounds like s, sh, f and th live up high, right where Gus slopes down." Gus: "So THAT'S why 'dishes'
   sounds like 'fishes'!"
6. **Fit.** The world goes grey. Doris: "\_u\_, honey, can you \_lea\_e do \_e di\_e\_?" Hoot is honest about the
   shortcut: "Skipping ahead! Real aids come after more tests, like bone and speech. The full game has them." The
   aids go in and the visitor matches the right ear on Day 14's real-ear graph (MIDS, HIGHS, TOPS into the green;
   the world colours in as each band lands; an overshoot costs a heart); Hoot matches the left ear. Then the
   birds, "Can you PLEASE do the DISHES?", "Forty years, Gus. FORTY. YEARS.", "Real fittings take fine-tuning and a
   few weeks of getting used to.", "That's the job: every beep you measured made that moment." and the booth line.

**The paper.** The Daily Decibel with the demo's own headlines ("LOCAL GRANDPA HEARS 'DISHES' FOR FIRST TIME IN
YEARS" for an A), weather ("sunny, with a chance of careers"), four medals (Chat, Peek, Phones, Fit), the beep golf
card, no next day, and the button **Next visitor** (back to the title, which wipes the visitor). "Play Gus again"
replays the demo. No Decibucks and no shop: the WANTED ad ("Hearing care professionals do this every day. Ask at
this booth!") sits in their place, next to the buttons.

**Left alone.** A visitor who walks off mid-visit: after 120 seconds with no key, click or mouse movement (real
time, also while paused or during Hoot's montage) the demo goes back to the title. The paper goes back by itself
after 90 seconds, and the title starts the attract loop after 30 seconds. Never under autoplay.

## 3. What it leaves out, and why

Day 1's evidence board, the instructions choice and the second history round; bone conduction, masking, speech
tests, the style pick, the probe tube, the loud-sound check and the counselling. Each is a full day in the game; the
demo says so out loud in the fitting step. The clinical lines it keeps are Day 1's and Day 14's as reviewed
(D1-1 to D1-7, FITTING.md), shortened where a line was over 18 words.

## 4. Steve's questions (the defaults stand unless he says otherwise)

1. Seven minutes: one chat question, two stamps of his own before Hoot takes over. More stamps (3) or fewer?
2. The title's line says "About 7 minutes". Keep it?
3. The idle reset after 120 seconds. Shorter for a busy booth?
4. ~~The paper keeps the Decibucks and the comfy-chair ad. Hide them in the demo?~~ Steve: yes (2026-10-21). Done:
   the WANTED ad takes their place.
5. ~~Should the booth also have an attract loop when nobody is playing?~~ Steve: yes (2026-10-21). Done (§1). Its six
   teaser lines are in `story/demo_attract.gd`; the delay is 30 seconds.

## 5. Engine notes

- `Game.is_demo()`, `Game.reset_demo_visitor()` (progress back to `DEFAULT_PROGRESS`, settings kept),
  `Game.DEMO_SAVE_PATH`, `Game.WEB_FLAGS` (`["demo"]`), `Game._parse_web_query(search)`; demo mode sets
  `Game.cli["quick"]` unless `--full`.
- Title: `TitleScreen.DEMO_SCENE` (`res://story/level_demo.tscn`), `DEMO_TAGLINE`, `_on_demo_start()` (the
  `title_start` beat's solver in demo mode).
- Audiometer plan key `montage_after: bool`: on a quick visit, when the player's stamps run out
  (`hoot_turn_after`), Hoot fills in the rest of the ear in a montage (no x8 turn), saying `hoot_turn_text`.
- `LevelDemo.apply_summary(summary)`: `demo: true`, headlines, subheads, medal_beats, weather,
  `next_chapter_id: ""`, `continue_text: "Next visitor"`. The paper's results also carry `fitting` (the right
  ear's target match).
- The bot's `_check_demo`: the four medals, every band within 5 dB, no next day, "Next visitor"; the ears are
  checked like any visit's.
- The paper: a summary with `demo: true` hides the Decibucks and the shop (B buys nothing) and moves the WANTED ad
  to the bottom row.
- The attract loop: `story/demo_attract.gd` (`start()`, `stop()`, `is_running()`, `LINES`, `PROMPT`, signal
  `dismissed`), added by the title in demo mode; `TitleScreen.ATTRACT_S` (30) and `attract_after()`
  (`--attract-after=N`). To look at it:
  `tools/scene_shot.sh res://story/title_screen.tscn /abs/out/dir "3,8" -- --demo --attract-after=1`.
- Tests: `story/tests/test_demo.gd`.
