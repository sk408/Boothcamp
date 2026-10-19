# Booth Camp

A cartoon hearing-clinic game. You are a trainee in Professor Hoot's clinic, and your first
patient is Grandpa Gus, who has been hearing "fishes" every time Doris asks him to do the dishes.
You take his history, look in his ears, explain the test, put the earphones on, run a real-style
pure-tone air-conduction test on both ears with the AudiOtron 3000, read the audiogram, crack the
case, and get a sneak peek of his first hearing aids. One visit takes about 10 to 15 minutes.

**Day 2** brings Bonnie Bunsworth, a baker whose right ear has gone "all underwater". It opens with
**Hoot's masking movie** ("The Cross-Hearing Ghost"), a 95-second cartoon in ten scenes: two snail
cochleas in one head, the skull wall that eats at least 40 dB of an earphone beep, the bone buzzer
that shakes both sides, the Ghost (the better cochlea answering for the poorer ear), the "shhh" in
the other ear, too little and too much of it, and the plateau. Space, Enter or a click work like
the dialogue box (finish the caption, then the next caption, then the next scene), Esc skips it, P
pauses. **Replay it** any time from the pause menu ("Watch Hoot's masking movie", Day 2) or the
title's **Hoot's Movies** button (also under Options). It counts as watched once it reaches the
plateau scene; skip it earlier and it plays again next visit. A 12-second recap card plays when the
masking phase starts.

You test her right ear by air (Hoot coaches the first beep and runs the rest), watch Hoot's montage
of her normal left ear, then **bone, better ear first**: the oscillator goes on her LEFT mastoid
and you test her bone there, unmasked (`>` marks). Unmasked bone is heard by the better cochlea
wherever the buzzer sits, so this is both ears' bone baseline. Hoot then moves it to her right
mastoid for ONE unmasked tone, and her left cochlea answers for the right ear: the Cross-Hearing
Ghost. Her right air is 10 dB or more poorer than that unmasked bone, so the right bone must be
masked: noise in the left ear, the plateau dance for bone (`[` marks) and then for air, and the
referral stamp to the ear doctor (a conductive loss with normal bone). About 15 minutes. Every day is open from the start: pick one
on the title's **Days** card, in any order. The suggested day wears an **UP NEXT** ribbon, and after
Day 1 The Daily Decibel stamps UP NEXT! and **Next: Day 2** goes straight on. Progress is saved.

**Day 3** brings Mike Lenders, a forklift driver who says he can't hear a thing since a forklift
beeped at work (yet he hears Hoot's whispered offer of coffee). Hoot runs his beeps, then you find
his speech recognition threshold (SRT) on the new SPEECH screen: go through the two-part words
first, present them softer and softer, score what Mike actually says, and find the softest level
where he repeats half of them. His words come back far better than his beeps, so you present the
clues on the OBJECTION! board, never accuse him, and stamp a recheck with objective tests, with
his doctor told about the sudden loss.

> **This is a game, not a hearing test.** Every "dB" in it is simulated. The beeps are kept quiet
> on purpose (about -75 dBFS at 0 dB HL, never above -12 dBFS, with a limiter on top), and you
> never need to hear them: every beep lights up on screen and every answer from Gus does too.
> The "too loud" gags are visual only; the game never plays a loud sound.
> Worried about your own hearing? Please see a licensed hearing professional.

## Run it (Windows)

1. Copy `BoothCamp.exe` anywhere and double-click it. Nothing to install; the game is one file.
2. Windows SmartScreen may say "Windows protected your PC" because the file is not code-signed.
   Click **More info**, then **Run anyway**.
3. Needs 64-bit Windows 10 or 11 and a graphics driver with OpenGL 3.3 (any PC from the last
   ten years). Settings and progress are saved in `%APPDATA%\Godot\app_userdata\Booth Camp`.

F11 or Alt+Enter toggles fullscreen. Esc or P pauses (volume, key style, text speed, comfort
options). Closing the window saves and quits.

## How to play

### Keyboard (default layout)

| Key | AudiOtron 3000 |
|---|---|
| **Space** (hold 1 to 2 s) | Play the beep. The ring on the TONE pad turns green at 1 s. |
| **Up** / **Down** | Louder / softer, 5 dB per tap |
| **Left** / **Right** | Lower / higher pitch (frequency) |
| **S** or **Enter** | Store the threshold (stamp it on the audiogram) |
| **N** | No response (only after a miss at the loudest level) |
| **R** / **L** | Right / left ear |
| **H** | Show or hide the key hints next to every control |
| **B** / **A** (Day 2) | Route the tone to the BONE oscillator / back to AIR (earphones) |
| **M** (Day 2) | Masking NOISE on / off (it plays in the other ear; its lamp glows while on) |
| **PgUp** / **PgDn**, or **Shift+Up** / **Shift+Down** (Day 2) | Noise louder / softer, 5 dB per tap |
| **Esc** or **P** | Pause and options |

| Key | SPEECH screen (Day 3) |
|---|---|
| **Space** | Present the next word (the TALK lamp lights while it plays) |
| **Up** / **Down** | Louder / softer, 5 dB per tap |
| **Right**, **+** or **=** | He repeated it: CORRECT |
| **Left** or **-** | He missed it (silence, half the word, or the wrong word): MISSED |
| **S** or **Enter** | Store the SRT |
| **M** | Speech noise in the other ear on / off |
| **H** | Show or hide the key hints |

Prefer Up = softer? Click **Up = LOUDER** on the AudiOtron (or use the pause menu) to swap the
two arrows. Everywhere else: Space or Enter continues dialogue, Up / Down or 1 to 4 picks an
answer, and every screen says which keys it uses.

### Mouse only

Everything works with the mouse. Hold the big **TONE** pad to beep, right-click it for no
response, click **SOFTER**, **LOUDER**, the **Hz** arrows and **STORE**, or scroll over the dB
readout. Click the audiogram or a test-plan token to jump to that frequency. The **II** button
pauses. In the story, click to continue, click an answer, drag the earphone cups onto Gus's ears
and drag the evidence onto the case file. On Day 2, click the **AIR | BONE** switch and **NOISE**, the
noise arrows, drag the bone oscillator onto Bonnie's mastoid, and click the referral stamp. On
the title's **Days** card, click a day; the mouse wheel scrolls the grid when there are more days
than fit.
On Day 3, click a word card to drop it, click **PRESENT**, **CORRECT**, **MISSED**, **LOUDER**,
**SOFTER**, **STORE** and **MASK** on the SPEECH screen, and drag a clue onto Mike's claim.

### The AudiOtron in one breath

The **dance card** under the test plan always shows the rule: **heard = down 10, missed = up 5,
heard twice on the way up = STORE**. Hoot coaches you step by step on the first frequency of the
right ear, then you lead. Each threshold is a golf hole: par is the number of beeps a textbook
search usually needs, combos build while every step is by the book, and the scoring is fair:
when Gus wobbles it never costs you a bogey, and a slip never earns a birdie.

On the second ear you test a few frequencies on your own, then Hoot takes a turn and finishes
the ear at 8x speed so you can watch the whole routine (turn this off with **Quick visit (Hoot
runs the repeats)** in the pause menu to test every frequency yourself; Hoot's stamps never count
for or against you). On Day 2 the air test is a repeat of Day 1, so Hoot coaches one beep and
runs the rest, and her left ear plays as a quick stamp montage; the bone and masking sheets are
yours. With Quick visit off you test everything.

On Day 2 the AudiOtron grows a **MASKING** deck. The **AIR | BONE** switch shows where the tone
goes (AIR reads INSERT with the insert earphones from the shop). **NOISE** turns the masker on in
the other ear, with a lamp and a NOISE box that light whenever it plays. Hoot walks you through
the first masked bone threshold one press at a time: the starting noise (the other ear's air
+ 10, plus a few dB for a covered ear at low pitches), then "heard = noise up 5, missed = tone up
5" until the answer survives three noise raises in a row: the plateau, drawn as a flat line on
the chart. If one more noise step makes her answer vanish, the tone was crossing to the other
ear: that was the Ghost.

## What the level teaches

- **Case history:** ask open questions that find clues (which sounds are hard, how long, which
  ear), and always ask about **red flags** (pain, drainage, dizziness, sudden or one-sided change),
  any of which means a doctor checks the ears first.
- **Otoscopy:** look before you test. Gus has a sesame seed in his ear canal: never poke at it; a
  doctor or trained clinician removes it safely. (He sneezes it out, which is cartoon physics.)
- **Instructions:** "press whenever you hear a beep, even a very faint one" gives honest answers.
- **Earphones:** glasses off, red on the right ear, blue on the left (his right is your left).
- **Pure-tone audiometry (Hughson-Westlake, simplified):** start at 1000 Hz around 40 dB HL; climb
  10 dB until the first response; then down 10 after every "yes" and up 5 after every miss; the
  threshold is the lowest level heard on at least two ascending runs. Order: 1k, 2k, 4k, 8k,
  retest 1k (within 5 dB is clinic-grade; the better one counts), then 500 and 250 Hz, plus the
  half-octave in between whenever neighbours differ by 20 dB or more. Beeps 1 to 2 s, varied
  gaps (a steady rhythm makes patients guess), never start loud.
- **Reading the audiogram:** lower on the chart means a louder sound was needed. Gus has a gradual,
  sloping high-frequency loss in both ears: low pitches near normal, high pitches moderately
  severe. Soft consonants like s, sh, f and th live up in those high pitches, so "dishes" turns
  into a guess.
- **Fitting teaser:** hearing aids add a boost where his hearing slopes; real fittings take
  fine-tuning and a few weeks of getting used to.

At the end, The Daily Decibel scores accuracy, technique, efficiency and care, shows your golf
card and the 1 kHz retest, and pays Decibucks you can spend on a comfier booth chair (Day 2's
paper sells insert earphones).

### Day 2: what it teaches

- **Bone conduction:** the oscillator goes on the mastoid bone behind the ear, never touching the
  ear itself. Bone skips the ear canal and middle ear, so it measures the cochlea directly (tested
  at 500 to 4000 Hz; the bone oscillator tops out lower than earphones). An optional **bonus
  hole** tests bone at 250 Hz too: a loud low buzz there can be felt rather than heard, which is
  why many clinics skip it.
- **The air-bone gap:** air poorer than bone by more than 10 dB means a conductive loss. A gap of
  15 dB or more at 500, 1000 and 2000 Hz is a red flag for a referral.
- **Cross-hearing:** bone crosses the skull with about 0 dB of loss, so unmasked bone is heard by
  the better cochlea, wherever the oscillator sits: that is why bone goes on the better ear first.
  Air crosses too once the tone is at least 40 dB above the other ear's bone (on-ear phones; real
  heads lose 40 to 80 dB, so 40 is the safe rule).
- **When to mask bone:** the test ear's air 10 dB or more poorer than the unmasked bone (ASHA 2005,
  BSA 2018). Hoot says it with her numbers ("Right air 50, unmasked bone 5: a 45 dB gap"). A
  gap of exactly 10 is masked but still names no conductive loss: that needs more than 10.
- **Masking (simplified):** the noise goes in the OTHER (non-test) ear. Start it at that ear's air
  threshold + 10, plus the occlusion effect for bone at low pitches (a covered ear hears bone
  louder); heard = noise up 5, missed = tone up 5; the tone heard at the same level through three
  noise raises (15 dB) is the plateau. Too much noise crosses back (overmasking). Then masked air:
  on-ear phones lose at least 40 dB crossing the head, so her right air minus 40 could still reach
  her left cochlea (its BONE threshold), and air gets masked too. With the insert earphones (at
  least 55 dB lost) it cannot, and no masked air is needed. The masking dilemma is only mentioned.
- **The takeaway:** a conductive loss with normal bone means an ENT referral. Bonnie's pattern
  is the classic picture of otosclerosis: extra bone grows around the stapes (the stirrup bone),
  so it cannot vibrate freely. Her bone line has a small dip at 2 kHz, the **Carhart notch**: a
  stiff middle ear fakes a small bone loss there, and her cochlea is fine. The ENT confirms it;
  then surgery to free the stapes, or hearing aids, both of which can work well. The game never
  diagnoses.
- **The Day 2 board:** the air-bone gap drawn as a river, with the bone line as the bridge over
  it and a toll booth: the "toll" is the dB the middle ear charges before sound reaches the
  cochlea.

Symbols follow the usual audiogram conventions: O / X for air, < / > for unmasked bone,
[ / ] for masked bone, triangle / square for masked air; bone symbols are never joined by lines.
The masking noise is synthesized narrowband noise, quiet and capped like the beeps, and it
always lights the NOISE box and the booth squiggles, so Day 2 is playable without sound too.

### Day 3: what it teaches

- **Spondees:** two-part words said with equal stress on both parts (rainbow, doorbell), chosen
  because they are about equally easy to hear. Go through them first at a comfortable level, and
  drop any word the patient doesn't know.
- **The SRT (speech recognition threshold):** start about 15 dB above the pure-tone average
  (PTA: the average of the beeps at 500, 1000 and 2000 Hz); repeated = down 10, missed = up 5,
  and another word at the same level is fine; the SRT is the softest level where at least two
  words and half of them come back, with fewer than half right 5 dB below it. Score only what the
  patient said: half a word is a miss.
- **PTA/SRT agreement:** a reliable SRT lands within about 6 dB of the PTA (12 is fair). The
  direction matters: Mike's SRT is about 40 dB better than his beeps, a classic sign of a
  non-organic loss; an SRT worse than the PTA points to the instructions, language, word
  recognition or a sloping loss instead.
- **Never accuse:** most non-organic losses aren't fibs (stress, worry, even a real loss
  underneath). Gather the clues (the agreement, the whispered coffee, clear canals), stay kind,
  recheck, refer for objective tests, and tell his doctor about the sudden loss. The game never
  calls Mike a liar.

The words are an original list written for the game, shown on screen as you play: no list, order
or recording is copied, and every word is checked against ASHA (1988) Appendices A-C and CID W-1.
Each word plays as a quiet murmur through the same safety limits as the beeps; a recording can
replace it later, and nothing depends on hearing it.

## Build from source

Requires [Godot 4.7.2](https://godotengine.org) (standard build, GDScript only) and, for the
Windows build, the 4.7.2 export templates. All art, sound and music are made in code at runtime;
the only asset files are the Fredoka font (SIL Open Font License, `assets/fonts/OFL-Fredoka.txt`).

```bash
godot --headless --path . --import                  # first time, or after adding files
tools/run_tests.sh                                  # unit tests (exit 0 = green)
tools/autoplay_check.sh                             # a bot plays the whole level headless
tools/autoplay_check.sh --day=2                     # ...Day 2 (bone and masking)
tools/autoplay_check.sh --day=2 --upgrades=insert_earphones   # ...Day 2 with inserts
tools/autoplay_check.sh --via-days --pick=bonnie   # ...picking Day 2 on the Days card
tools/autoplay_check.sh --day=3                     # ...Day 3 (speech, SRT)
tools/mouse_check.sh                                # the same with mouse clicks only
godot --path .                                      # play it

mkdir -p build
godot --headless --path . --export-release "Windows Desktop" build/BoothCamp.exe
```

`tools/README.md` lists the other checks: rendered screenshots of a full playthrough
(`tools/shots.sh`), the audio-safety recording that measures every tone
(`tools/movie_check.sh`), and a button-mashing stress test of the AudiOtron
(`--scene=res://tools/monkey.tscn`). `CONTRACTS.md` describes how the modules talk to each other.

## What's next

- More patients, each teaching one new idea: a noise notch (a drummer), a child who needs play
  audiometry, the masking dilemma (both ears with big gaps), and a "something's not right, refer
  to a doctor" case. Day 2's design and rules are in `docs/CHAPTER2.md`.
- A real fitting level: choosing a target, adjusting gain by frequency, and the follow-up visit.
- More speech tests: word recognition (Day 4) and a party-noise test (Day 5). The speech rules
  are in `docs/SPEECH.md`, Day 3's design in `docs/CHAPTER3.md`.
- Counselling choices that change how the visit ends.
- More upgrades for the clinic, and a practice booth with random patients.
