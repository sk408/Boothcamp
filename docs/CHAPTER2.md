# Booth Camp, Chapter 2 (Day 2): Bonnie Bunsworth, "Bone conduction + masking"

Design for the second playable day. Day 1 (Grandpa Gus, air conduction) is finished and must not change.
Contract changes for this chapter are marked **(v3)** in `CONTRACTS.md`. Every clinical number below lives in
`autoload/clinic_rules.gd` (section "v3") or `core/patients/bonnie.tres`; change it there, not in a copy.
Steve reviews every number.

**(v4) Steve's feedback, applied** (contract changes marked **(v4)** in `CONTRACTS.md`):
1. **Bone on the better ear first.** The oscillator goes on Bonnie's LEFT mastoid and unmasked bone is measured there
   first (coached, `>` marks). Hoot states the rule: *unmasked bone tells you about the better cochlea, wherever the
   oscillator sits.* Then the **Ghost demo**: the oscillator moves to her right mastoid and ONE unmasked tone plays;
   the left cochlea answers; BOO. Then masking: noise in the LEFT ear, oscillator on the RIGHT mastoid, masked
   right bone with the plateau, then masked right air. Results, reveal and golf card show left `>` and right `[`.
2. **Hoot's masking movie**: a 92-second skippable, replayable cartoon at the start of the day (§16).

| | |
|---|---|
| Teaches | bone conduction, the air-bone gap, cross-hearing, clinical masking (plateau), overmasking, conductive loss = ENT referral |
| Length | 12-15 minutes: **(v4)** about 14:30 with the movie and "quick visit" on (the default), about 13 if the movie is skipped |
| Opens | from the start, in any order (polish: every day is open; Day 1 is the suggested first day) |
| New controls | B bone, A air, M masking on/off, PgUp / PgDn (or Shift+Up / Shift+Down) masking level, all with on-screen buttons |
| Level scene | `res://story/level_bonnie.tscn` (`story/level_bonnie.gd`) |

---------------------------------------------------------------------------------------------

## 1. The patient

**Bonnie Bunsworth**, 34, owns Bunsworth's Bakery. Chestnut bun with a wooden spoon stuck through it,
mustard top, flour-dusted apron. Cheerful, talks in bread. Brings croissants for the waiting room.

> "My right ear has gone all underwater. Like listening through a loaf of sourdough."

What she says when asked (case history, two rounds of three choices, 2 / 1 / 0 points):

| Question | Points | Answer | Case note |
|---|---|---|---|
| Which ear, and since when? | 2 | Just the right, crept up over a year or two. Left is perfect. | RIGHT ear only, slowly over 1-2 years |
| Is your favourite bread sourdough? | 0 | Rye. Don't tell the sourdough. | (joke) |
| Anyone in the family with hearing trouble? | 2 | Mum and Gran both went "underwater" in their thirties. | Family: Mum and Gran, same in their 30s |
| Any ear pain, drainage, dizziness, or sudden change? | 2 | No pain, no drips, no spinning. Just slowly muffled. | No red-flag symptoms |
| Does your own voice sound different? | 1 | My voice booms in that ear, and chewing crusts is LOUD. | Own voice + chewing loud on the right |
| Have you tried a gluten-free ear? | 0 | Gluten is my love language. | (joke) |

The picture a clinician should form: young adult, one ear, slowly progressive, family history, normal
eardrums, own voice loud (occlusion-like). That points to a conductive problem behind a normal eardrum
(otosclerosis). The game never diagnoses: Hoot says "a doctor may suspect otosclerosis".

## 2. Truth tables (`core/patients/bonnie.tres`)

True thresholds, dB HL. Bone is the cochlear threshold, never poorer than air.

| Hz | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| Right air (O) | 55 | 55 | 50 | 50 | 50 | 50 | 40 | 35 | 35 | 40 |
| Left air (X) | 10 | 5 | 5 | 5 | 5 | 5 | 10 | 10 | 15 | 15 |
| Right bone | 10 | 10 | 10 | 10 | 15 | **25** | 15 | 10 | | |
| Left bone | 5 | 5 | 5 | 0 | 5 | 5 | 10 | 5 | | |

The 2 kHz bone dip on the right (25, against 10 at 1k and 4k) is the **Carhart notch**.

Her head (`PatientProfile` v3 fields): real interaural attenuation phones 60, inserts 75, bone 0;
occlusion scale 1.0; slope 1.7, attention 0.97, fatigue 0.0006, false alarms 0.4 / min, reaction 0.35-0.8 s.
The masking RULES use the conservative textbook IA (phones 40, inserts 55, bone 0), so the rules ask for
masked air even though her real head would not cross over. The masked air then confirms the unmasked air.

What the player sees, derived from those numbers (all checked in `tests/test_masking_session.gd`):

| | 250 | 500 | 1k | 2k | 4k | note |
|---|---|---|---|---|---|---|
| Unmasked right bone reads | 5 | 5 | 0 | 5 | 5 | the LEFT cochlea answers: the Cross-Hearing Ghost |
| Air-bone gap (unmasked) | | 50 | 50 | 45 | 30 | > 10 everywhere: mask the bone |
| Initial masking, right bone (dB EM, left ear) | | 30 | 25 | 15 | 20 | left air + 10 + occlusion (500 +15, 1k +10) |
| Masked right bone (the plateau) | | 10 | 10 | 25 | 10 | 2k: the "shadow chase", 15 rises to 25 as noise climbs |
| Overmasking starts at (bone) | | 50 | 50 | 65 | 50 | tone + 40 |
| Masked air needed (rule) | yes | yes | yes | yes | no | right air - 40 >= left bone estimate |
| Initial masking, right air | 20 | 15 | 15 | 15 | | left air + 10 (no occlusion for air) |
| Overmasking starts at (air) | 50 | 50 | 50 | 65 | | test-ear masked bone + 40 (250 borrows the 500 bone) |
| Masked right air | 55 | 55 | 50 | 50 | | same as unmasked: her real head did not cross over |

Result the reveal shows: right ear **conductive** (gaps 45 / 40 / 25 / 25 at 500-4k, bone average 14),
referral red flag (gap 15+ at 500, 1k and 2k), Carhart notch; left ear normal. ~~Bone is tested on the right
only: the left air is normal, so the left can't have an air-bone gap.~~ **(v4)** Bone is tested on the LEFT
(better) ear first, unmasked (`>`: 5 / 0 / 5 / 5 at 500-4k). Unmasked bone is the better cochlea's answer
wherever the oscillator sits, so these marks are the bone baseline for BOTH ears; the right ear's air (50) sits
far below it, so the right cochlea is unknown until it is masked. The unmasked-right-bone row above is what the
Ghost demo shows with one tone (at 1 kHz, 5 dB above the measured left bone); it is never stored.

## 3. Beat by beat (v4: about 14:30 with the movie)

Times are for a first-time player with "quick visit" on. "Hoot runs" = Hoot's turn at x8 speed (input
locked, his stamps marked "hoot", not scored for golf). Every blocking beat emits `Events.awaiting_input`.
**(v4)** New or changed rows are bold. The v3 table (bone on the right first) is replaced.

| # | Phase (`phase_changed`) | What happens | Beat(s) | Time |
|---|---|---|---|---|
| **0** | **`explainer`** {movie, source, seen} | **Hoot's masking movie (§16), before Bonnie knocks. Until it is seen (reached its plateau scene) it just plays (Space = next caption / scene like dialogue, Esc = skip). Seen before: "Hoot's masking movie again? Popcorn's on me!" Roll the film / Skip it. (polish) After a skip: "Skipped! Rewatch it any time: pause menu, "Watch Hoot's masking movie"."** | **explainer** (or choice) | **1:35** |
| 1 | `intro` | Bonnie bursts in with croissants. Hoot: "Day 2, trainee! Today we test through the bone, not just the air." | dialogue | 0:35 |
| 2 | `history` | Two rounds of questions (table above). Red-flag card: "One ear only: YES = see a doctor." Medal `history`. | choice | 1:10 |
| 3 | `otoscopy` | A quick look: canals clear, eardrums normal. | dialogue | 0:15 |
| 4 | `instructions` | "Press for every beep, even faint ones. Ignore the shhh noise." | choice | 0:30 |
| 5 | `earphones` | Day 1's drag game, with "HER RIGHT" labels. Medal `earphones`. | earphones_place | 0:30 |
| 6 | `audiometry` {right, ac} | Player stamps 1 kHz (coached), Hoot runs the rest. | (AudiOtron) | 1:10 |
| 6b | `audiometry` {left, ac} | The left-ear montage. "Right ear needs about 50 dB, left is normal. But WHERE is it stuck?" | (AudiOtron) | 0:15 |
| **7** | **`bc_placement` {ear: left}** | **Earphones off. "Meet the bone buzzer! Better ear first: unmasked bone hears with the better cochlea anyway." "So: her LEFT." The placement game on her LEFT profile (§6). The 3D oscillator goes on her left mastoid.** | **bc_placement** (`mastoid_target_left`) | **0:45** |
| **8** | **`audiometry` {left, bc}** | **Unmasked bone on the LEFT, coached: press B, stamp 1k; Hoot does 2k, 4k, 500 (`>` marks). (polish) Plan `masking_deck: false`: the AIR / BONE route buttons but no MASKING group yet. Optional 250 Hz bonus hole (the tickle, also without the masking group). Then: "Left bone 0, left air 5: side by side." and THE RULE: "unmasked bone tells you about the BETTER cochlea, wherever the buzzer sits."** | (AudiOtron), choice | **1:40** |
| **9** | **`ghost_demo` {ear: right}** | **"Her right air needs 50. Is her RIGHT cochlea fine too? Unmasked bone can't tell us." "Watch what happens if we try anyway: swap the buzzer to her RIGHT mastoid." A quick second placement ("Swap sides!") on her RIGHT mastoid. ONE unmasked tone at 1 kHz, 5 dB above her measured left bone (every control but TONE locked; TONE wiggles "Hold Space!" if you wait, Hoot presses it after twice that). Her LEFT cochlea answers: the Ghost flies, "Bone 10, air 50? BOO!" (the level she really answered at). Nothing is stored. "Was that her right cochlea, or the LEFT one? Can't tell!" Then the rule with her numbers: "Right air 50, unmasked bone 5: a gap over 10 dB. Any gap over 10? Mask the bone!"** | **bc_placement** (quick), (AudiOtron `demo_tone`) | **0:50** |
| 10 | `masking` | "Which ear gets the shhh noise?" (left!). Medal `masking`. A single blue earphone goes on her left ear; the oscillator stays on her right mastoid. **(polish) Then the recap card "Masking, the short version" (about 12 s, Esc skips): shhh in the OTHER ear; start at its air + 10 (+ occlusion); heard? shhh up 5, missed? beep up 5; flat for 15 dB = the truth.** | choice, **explainer** (recap) | **0:45** |
| 10b | `audiometry` {right, bc_masked} | Masked bone, coached: noise in the LEFT ear, find the **flat line** at 1k and 2k; Hoot does 4k and 500. Starts at the unmasked (left) bone. | (AudiOtron) | 2:00 |
| 10c | `audiometry` {right, ac_masked} | Earphones back on. **(polish) "Air leaks too! 50 minus 40: up to 10 dB crosses. Her left BONE hears 5."** Hoot runs masked air (none with inserts: "At least 55 dB lost crossing her head: 55 minus 55 is below her left bone."). | (AudiOtron) | 0:20 |
| 11 | `reveal` | Audiogram stamps in: O X, **left `>` (unmasked bone), right `[` (masked bone)**. "The > marks: left bone, unmasked. The [ marks: right bone, masked." The toll bridge. | dialogue | 0:45 |
| 12 | `evidence` | Type of loss (conductive). Carhart notch line. Medal `evidence`. | choice | 0:35 |
| 13 | `referral` | Refer to ENT, the stamp. Medal `referral`. | choice, referral_stamp | 0:40 |
| 14 | `results` | The Daily Decibel. **Golf card rows: R O, L X, L `>`, R `[`, R O+.** | results_continue | 0:35 |

Total about 14:55 with the whole movie and the recap; about 13:10 if the movie is skipped. Medal `bc_placement`
counts the slips of both placements (0 gold, 1 silver, 2+ bronze). The demo never soft-locks: **(polish)** the wait
clock starts once Hoot's tip has typed out; after 6 s TONE wiggles ("Hold Space!"), after 12 s Hoot presses it;
a miss raises the tone 5 dB (at most 3 tones). If her left cochlea misses all three (a rare lapse),
Hoot says the no-Ghost line (§4) and the day goes on.

**Why this order (Steve).** Clinically you put the oscillator on the better ear first: unmasked bone there is
both ears' bone baseline (bone crosses the skull for free, IA about 0). The poorer ear's air is then compared
with that baseline: any gap over 10 dB means its bone must be masked. An unmasked tone on the poorer side only
re-measures the better cochlea, which the demo shows with one tone instead of a whole unscored test.

## 4. Teaching moments (Hoot, 18 words or fewer)

Lines in the order they appear (level dialogue and AudiOtron tips). Counted by `Hoot.MAX_WORDS`.

| Moment | Line |
|---|---|
| Purpose | "One muffled ear. Let's find out WHERE the sound gets stuck. Questions first!" |
| Own voice | "Own voice booming? A classic sign that sound is blocked before the inner ear." |
| One-sided = flag | "One-sided hearing loss is a red flag by itself. A doctor should see her." |
| Normal eardrum | "Not a crumb. A healthy-looking eardrum can still hide a stiff middle ear." |
| Instructions | "She'd press for the noise all day! Beeps only. Try again." |
| Air vs bone | "Air goes through the ear canal and middle ear. Bone skips both, straight to the cochlea." |
| Placement | **(polish)** "Snug on the mastoid, off the ear. Bone goes 250 to 4000 Hz: we need 500 and up." |
| ~~The Ghost~~ | ~~"Bone has almost zero interaural attenuation. Her LEFT cochlea may have answered!"~~ (v4: replaced by the demo lines below) |
| Tip `cross_hearing` | "Bone has zero IA: that beep may have crossed to the OTHER cochlea. Meet the Ghost!" |
| Why mask | "To hear the right cochlea alone, keep the left one busy with noise. Masking!" **(v4)** ends "Masking, like the movie!" when the movie played to the end |
| Wrong ear | "Noise in the test ear just hides the beep. Busy the OTHER ear." |
| Starting level | "Start noise: her left air threshold plus 10, plus extra for occlusion on low tones." |
| The dance | "Heard? Noise up 5. Missed? Tone up 5. Three noise steps, same answer: plateau!" |
| Tip `undermasked` | "The Ghost answered! Not enough noise yet: heard means noise up 5." |
| Tip `plateau_found` | "Flat line! Same answer through 15 dB more noise: that's the true threshold. Store it!" |
| Tip `overmasked` | "Too much noise! It leaks back and drowns the test ear too. That's overmasking." |
| Tip `vibrotactile` | "Loud low bone tones get FELT, not heard. A tickle is not a threshold!" |
| AC masking rule | **(polish)** "Air leaks too! 50 minus 40: up to 10 dB crosses. Her left BONE hears 5." (40 = the safe minimum IA, compared with the other ear's BONE) |
| Toll bridge | "That gap is the toll bridge: air pays a toll at the middle ear. Bone drives past." |
| Type of loss | "Conductive loss! Gap over 10 dB with normal bone. Gaps of 15 or more are a referral flag." |
| Carhart | **(polish)** "See the bone dip at 2k? A Carhart notch: a stiff middle ear fakes a small bone dip. Her cochlea is fine!" |
| Dilemma (mention only) | "If BOTH ears had big gaps, even masking could overmask. The masking dilemma. Another day!" |
| Takeaway | "Conductive loss with normal bone: refer to ENT. Often very treatable! Stamp it!" |

Masked-technique error tips (`AudiometrySession.TIPS`): `mask_wrong_step`, `mask_too_low`, `mask_start`,
`store_no_plateau`, `overmasked` (section 7).

**(v4) New and changed lines** (all 18 words or fewer; `%d` = the player's own numbers):

| Moment | Speaker | Line |
|---|---|---|
| Movie offer (seen before) | choice | "Hoot's masking movie again? Popcorn's on me!" / "Roll the film! (about 90 s)" / "Skip it: I know my masking." |
| Placement, left | Hoot | **(polish)** "Meet the bone buzzer! Better ear first: unmasked bone hears with the better cochlea anyway." / "So: her LEFT. It sits behind the ear, on the bony mastoid." |
| Placement caption, quick | card | "Swap sides! Her RIGHT mastoid: the same bony bump, behind the right ear." |
| Unicorn slip | Hoot | "A majestic unicorn! Forehead placement exists, but today: the mastoid, behind her {left / right} ear." |
| Top of head, glasses already found | Hoot | "Top of her head? Glasses gone, so: behind the ear, on the bony mastoid." ("Bonk!") |
| Left bone intro | AudiOtron tip | "Bone time, left ear! B = bone. Same dance: down 10, up 5. Start at 1k." |
| After left bone | Hoot | "Left bone %d, left air %d: side by side. Her left ear works fine all the way in." |
| | Bonnie | "A gold star for my left ear! I'll bake it a little one." |
| **The rule** | Hoot | "The rule: unmasked bone tells you about the BETTER cochlea, wherever the buzzer sits." |
| Demo setup | Hoot | "Her right air needs %d. Is her RIGHT cochlea fine too? Unmasked bone can't tell us." |
| Swap | Hoot | **(polish)** "Watch what happens if we try anyway: swap the buzzer to her RIGHT mastoid." |
| Demo tip | AudiOtron tip | "ONE beep, buzzer on her right, %d dB: just above her LEFT bone. Hold Space!" |
| Demo miss | AudiOtron tip | "No hand? Up 5, one more beep: hold Space." |
| Demo wait | AudiOtron chip | **(polish)** "Hold Space!" (TONE wiggles after 6 s; Hoot presses after 12 s) |
| Ghost callout | AudiOtron | "Bone %d, air %d? BOO!" (**polish:** %d = the level she really answered at) / "the LEFT cochlea may have heard it" |
| After the demo | Hoot | "BOO! Same answer as her left bone. Was that her right cochlea, or the LEFT one? Can't tell!" **(polish)** If she answered a step or two higher: "Heard at %d, near her left bone. Her right cochlea, or the LEFT one? Can't tell!" |
| | Bonnie | "A ghost in my skull?! I KNEW that oven was haunted." (kept) |
| **The criterion** (polish) | Hoot | "Right air %d, unmasked bone %d: a gap over 10 dB. Any gap over 10? Mask the bone!" (`ClinicRules.bc_masking_needed`; fallback: "The rule: air more than 10 dB poorer than unmasked bone? Mask the bone!") |
| | Hoot | "That's the Ghost's trick. Only masking the left ear can tell us the right cochlea's truth." |
| No Ghost (missed 3 times) | Hoot | "She missed it? Even the Ghost naps. But it CAN answer, so we mask anyway." |
| Why mask | Hoot | "To hear the right cochlea alone, keep the left one busy with noise. Masking, like the movie!" |
| Recap (polish) | card + Hoot | "Short version: shhh in the other ear, up 5 at a time, until the answer stays flat." |
| Masked bone intro | AudiOtron tip | "Noise in her LEFT ear, bone on her right. Find the flat line!" (kept) |
| Masked air (polish) | Hoot | "Air leaks too! %d minus %d: up to %d dB crosses. Her left BONE hears %d." / "It could reach her left cochlea. Clinics often mask air first; today the Ghost couldn't wait!" |
| Inserts (polish) | Hoot | "Inserts! At least %d dB lost crossing her head: %d minus %d is below her left bone." / "It can't reach her left cochlea: no masked air today. That's what the upgrade buys you!" |
| Masked = unmasked air (polish) | Hoot | "Masked air matches unmasked: her head loses more than %d. We assume %d to play safe." |
| Movie skipped (polish) | Hoot | "Skipped! Rewatch it any time: pause menu, "Watch Hoot's masking movie"." |
| Reveal | Hoot | "The > marks: left bone, unmasked. The [ marks: right bone, masked. Right air down near %d." |

## 5. Fun moments

- **The Cross-Hearing Ghost.** ~~The first time an unmasked bone tone is answered by the LEFT cochlea, the
  booth window shows a big "BOO!" callout.~~ **(v4)** The Ghost demo: one tone on the right mastoid, the LEFT
  cochlea answers, the Ghost flies from the right chart to the left one with "Bone 5, air 50? BOO!" (**(polish)** the level she really
  answered at: "Bone 10" after a missed first beep), the 3D Ghost
  slips round the back of her skull and taps her button hand. Bonnie: "A ghost in my skull?! I KNEW that oven was
  haunted."
- **(v4) Hoot's masking movie** (§16): Righty and Lefty, the snail cochleas; the skull wall; the jelly-head bone
  buzzer; the bedsheet Ghost; Lefty in sunglasses dancing in the "shhh" cloud; the plateau graph.
- **Flat line.** The LCD trail turns into a PLATEAU graph (masker steps along x, tone level up the y axis).
  Three noise raises with the same answer draw a flat green line and pop "FLAT LINE!" with a "PLATEAU!" chip.
- **The toll bridge.** On the reveal, an orange bridge deck runs along the masked bone marks with dashed posts
  down to the air marks, a "40 dB" sign on each post, and a little toll booth with a bobbing barrier arm.
- **Oscillator placement mini-game** (section 6), with a unicorn horn.
- **The tickle.** A loud low bone tone (250 Hz at 30+, 500 Hz at 55+) is felt, not heard: "hee hee! it
  tickles" chip, once per visit a Hoot tip. It teaches the vibrotactile trap without any loud sound.
- **TOO MUCH NOISE!** Overmasking shakes the screen and pops a coral callout ("it leaks back into the test
  ear"). Visual only: the masker itself stays quiet and capped (section 9).
- **Noise squiggles.** Whenever the masker is on, the booth window draws purple squiggles labelled NOISE on
  the masked side, and the LCD's NOISE box lights up. Nothing depends on hearing the noise.
- **The stamp.** A big red REFERRED TO ENT stamp slams onto the audiogram with a screen shake.
- **Bonnie herself:** croissants, "gluten is my love language", "like ignoring the mixer and listening for
  the oven timer", "Was I a unicorn for a second there? I felt majestic."

## 6. Oscillator placement mini-game (`story/games/bone_placement.gd`)

**(v4) Two placements.** First her LEFT side (`setup("left")`: the profile faces LEFT so her left ear is the one you
see, the tray sits bottom-left, target `mastoid_target_left`, Left/Right walk the highlight towards the back of her
head the other way round). Then, for the Ghost demo, a quick RIGHT one (`setup("right", true)`: caption "Swap sides!
Her RIGHT mastoid: the same bony bump, behind the right ear."; if her glasses were found the first time, they are
gone from the card and "top" is a plain slip). One medal for both. The text below describes the right side.

Bonnie in profile on a cream card, facing RIGHT, so the visible ear is her RIGHT (a profile facing left would
show her left ear; fixed at integration). The grey "bone buzzer" sits in a tray. Drag it onto a spot, or click a
spot; keyboard Left/Right (or the frequency keys) moves a highlight (Left walks from her nose towards the back
of her head), Enter/Space places. Beat `bc_placement` (solver = place on the mastoid). Anchors `oscillator`,
`mastoid_target_right`.

| Spot | Result | Gag | Hoot |
|---|---|---|---|
| **Mastoid** (behind the ear, on bone) | correct | buzz rings, "Bone on bone!" | "Perfect: on the mastoid bone, behind the ear, not touching it." |
| Ear flap (pinna) | slip | a drawn feedback squeal (no loud sound), "SQUEEEE!" | "Off the ear flap! Touching the pinna leaks buzz into the canal. Behind it, on bone." |
| Forehead | slip | a golden **unicorn horn** sprouts, "UNICORN!" | "A majestic unicorn! Forehead placement exists, but today: the mastoid, behind her right ear." |
| Nose | slip | the nose flashes, "BOOP!" | "Boop! A nose is cartilage, not bone. Find the bony bump behind her ear." |
| Top of head | slip | her lost reading glasses, "My glasses!" (the running gag) | "Her lost glasses! Mystery solved. The buzzer needs skin over bone, behind the ear." |
| Jaw | slip | chattering teeth lines | "She'd hear her teeth chatter! Higher and further back: the mastoid." |
| Bun | slip | flour puff | "That's a bun, not a bone! Lovely bun though. Try behind her ear." |

A wrong spot shows its gag for 1.1 s, then the buzzer bounces back and the spot gets a coral cross.
Medal: gold with 0 slips, silver 1, bronze 2+. Visit flag `bc_placement_slips`.

## 7. Clinical rules (exact numbers, `ClinicRules` v3)

| Rule | Value | Constant / function |
|---|---|---|
| Bone frequencies | 250-4000 Hz; required 1000, 2000, 4000, 500 (250 optional) | `BC_FREQS`, `BC_REQUIRED` |
| Bone maximum output | 250: 45, 500: 60, 750: 65, 1k-3k: 70, 4k: 65 dB HL | `BC_MAX_DB` |
| Felt, not heard | 250 Hz at 30+, 500 Hz at 55+ | `VIBROTACTILE_DB` |
| Oscillator position | mastoid, not touching the pinna | mini-game |
| Symbols (ASHA) | right: O air, < unmasked bone, [ masked bone, triangle masked air; left: X, >, ], square. Bone is never joined by lines; masked air replaces the unmasked O/X line point | `UiDraw.audiogram_symbol` |
| Interaural attenuation (rules) | phones 40, inserts 55, bone 0 | `IA_RULE_DB` |
| Air-bone gap | conductive when AC - BC > 10 | `ABG_CONDUCTIVE_DB`, `is_conductive_gap` |
| Referral red flag | AC - BC >= 15 at 500, 1000 AND 2000 Hz | `ABG_RED_FLAG_DB`, `abg_red_flag` |
| Bone masking needed | test-ear AC - unmasked BC > 10 | `bc_masking_needed` |
| Air masking needed | test AC - 40 (phones) >= non-test BC (best estimate) | `ac_masking_needed`, `nontest_bone_estimate` |
| Initial masking | non-test AC + 10, + occlusion effect for bone at 250 +15, 500 +15, 750 +10, 1k +10, 2k and up 0 (phones; inserts 0); no occlusion if the non-test ear has its own gap > 10 | `initial_masking`, `OCCLUSION_DB` |
| Plateau dance | heard: noise +5; missed: tone +5 | `next_mask_step` |
| Plateau | the same tone level heard through 3 noise raises of 5 dB (15 dB), starting at or above the initial level | `PLATEAU_STEPS`, `plateau_run` |
| Overmasking | masker - 40 >= test-ear bone (bone: masker >= tone + 40; air: masker >= the test ear's best bone + 40, the nearest measured bone frequency standing in where none was measured, e.g. 500 for 250) | `overmask_limit`, `is_overmasked`, session `overmask_limit_db` |
| Full window | heard with the noise at or above the initial level and one more step would overmask: store the held level (a narrow window, no plateau error) | session `window_full` |
| Masking dilemma | initial masking already at the overmasking limit (mention only) | `masking_dilemma` |
| Type of loss | normal (air <= 25); conductive (gap > 10 at 2+ of 500-4k, bone average <= 25); mixed (same gaps, poorer bone); sensorineural (no real gap) | `hearing_type` |
| Carhart notch | **(polish)** bone at 2k at least 10 poorer than the better of 500 and 4k (1k stands in when 500 is missing), at least 5 poorer than 4k (a notch, not a slope) and no better than 1k (the bottom of the dip) | `has_carhart_notch` |
| Masker range | 0-100 dB EM, 5 dB steps, starts at 10 when switched on | `MASK_MIN_DB`, `MASK_MAX_DB`, `MASK_STEP_DB` |

The simulator (`ClinicRules.response_threshold`, `PatientSim.condition_for`) models all of it: a tone is
heard when EITHER cochlea hears it. Unmasked bone reaches the other cochlea with 0 dB loss; air crosses with
the real IA; the masker raises the non-test cochlea (minus its own gap); masker noise crossing back
(masker - real IA) raises the test cochlea (overmasking); the covered non-test ear gains the occlusion effect
during bone tests. Gus (no bone data, no masking) gets exactly his air thresholds, so Day 1 is unchanged.

## 8. Scoring additions

- Results get one sheet per test (`ac`, `bc`, `bc_masked`, `ac_masked`). Accuracy, technique and efficiency
  average over every scored stamp on every sheet; Hoot's stamps are not scored.
- **Par** for a masked measurement = the presentations of the deterministic textbook dance from its start
  (initial noise, tone at the unmasked threshold) + `MASK_PAR_SLACK` 2. Unmasked bone uses the normal par.
  Fair golf as Day 1.
- **Masked technique errors** (break the combo, lower technique): `mask_too_low` (first masked tone with the
  noise below the initial level), `mask_start` (first masked tone more than 10 dB from the unmasked threshold),
  `mask_wrong_step` (anything but noise +5 after heard / tone +5 after missed), `store_no_plateau` (stored
  before 3 noise raises held, unless the safe window is full), `overmasked` (noise at or past the limit; once per measurement, not a check).
  Observations: `cross_hearing`, `undermasked`, `plateau_step` {steps, needed, db, mask_db, found},
  `plateau_found`, `vibrotactile`.
- **Medals (Day 2 paper row):** Chat (`history`), Bone (`bc_placement`), Mask (`masking`), Case (`evidence`),
  Refer (`referral`). Gold 10 / silver 6 / bronze 3 coins as before.
- Golf card: rows R O, L X, plus R [ (masked bone) and R O+ (masked air) when present. **(v4)** plus L > (left
  unmasked bone) before them. The Day 2 board legend lists "Left bone" too.

## 9. Audio safety for the masker

Masking noise is synthesized narrow-band noise (white noise through a 1/3-octave band-pass at the test
frequency) in the OTHER ear. Its level comes from `AudioSafety.masker_to_rms(db_em)`: the tone mapping
minus 6 dB, hard-capped at **-24 dBFS RMS**; every sample goes through `AudioSafety.clamp_masker_sample()`
(the masker ceiling, then the global -12 dBFS clamp) with 50 ms ramps. Overmasking and "too loud" are
visual gags only. Every masker lights the NOISE box on the LCD and the squiggles in the booth window, and
`Events.masker_changed` fires, so the chapter is playable without hearing.

## 10. The ending

- The referral choice, then the player stamps **REFERRED TO ENT** (beat `referral_stamp`).
- Bonnie: "A doctor for my ear, then back to my buns. Deal! Croissant for the road?"
- **The Daily Decibel, Vol. 2.** Day 2 headlines by grade, for example S "GHOST BUSTED: TRAINEE MASKS LIKE A
  PRO", A "BAKER'S EAR SENT TO ENT; OWL SUSPECTS A STIFF LITTLE BONE". Shop: **insert earphones**, 60 coins
  (55 dB rule IA, so fewer ghosts in later days). Day 2 never needs it: without coins the paper just shows the
  ad. Buttons: "Play Bonnie again", "Next: ..." (when another day is open) and "Back to the title".

## 11. Chapter select and progression (polish: every day open)

- `Game.CHAPTERS`: `gus` (Day 1: Grandpa Gus, `level_gus.tscn`) and `bonnie` (Day 2: Bonnie Bunsworth,
  `level_bonnie.tscn`, requires `gus`).
- **Every day is open from the start, in any order** (Steve's rule: it helps testing, and players may pick any
  day). `requires` only picks the suggested day (`Game.suggested_chapter_id()`), which wears an "UP NEXT"
  badge. There is no "Unlock all days (demo)" setting any more; old saves that carry it load fine.
- Title: **Play** starts `Game.next_chapter_id()` (the suggested day, else the last played) and says which
  ("Play: Day 2") once there is progress. **Days** opens the day picker (phase and beat `chapter_select`): a
  scrolling grid with one card per day (portrait, DAY chip, name, what it teaches, best grade, plays), sized
  for the screen; arrows + Enter, Esc = Back, mouse click and wheel.
- Finishing a day adds it to `progress.chapters_done` and emits `Events.chapter_completed`. The first clear
  of Day 1 stamps "UP NEXT! Day 2: Bonnie" on the paper and makes "Next: Day 2 [Space]" the big button; a replay
  still offers "Next: Day 2 [N]". When a later day is played while an earlier suggested day is still to do,
  or after the last day in order, Next goes to the suggested day instead (Day 2 played first: "UP NEXT! Day 1:
  Gus"). Old saves where Gus was played count as Day 1 done. Progress is saved in
  `user://save.json`.

## 12. Controls (keys and mouse)

| Action | Keys (default style) | Mouse |
|---|---|---|
| bone / air | B (or 8) / A (or 6) | **(polish)** the AIR \| BONE switch (two segments; AIR reads INSERT with inserts) |
| masking on / off | M | **(polish)** the NOISE button (ON / OFF with a lamp) |
| masking level | PgUp / PgDn, Shift+Up / Shift+Down | NOISE up / down buttons |
| tone, level, frequency, store, no response | as Day 1 | as Day 1 |

The swapped key style also swaps the masker pair (PgUp = less noise). The masking and route buttons are
hidden on Day 1. Key chips follow `Game.key_label()`.

## 13. Where it lives (for the builders)

| Part | File | State |
|---|---|---|
| Rules, constants | `autoload/clinic_rules.gd` (v3) | final, Steve to review |
| Bonnie | `core/patients/bonnie.tres` | final |
| Simulator, session | `core/patient_sim.gd`, `core/audiometry_session.gd` | complete; builder A owns tuning |
| Masker audio | `core/tone_generator.gd`, `autoload/audio_safety.gd` | complete |
| AudiOtron | `ui/audiometer/*` (plan keys, masking deck, LCD noise box, plateau graph, gags) | working; builder A may polish |
| Audiogram | `ui/audiogram/audiogram.gd` (bone + masked layers) | working |
| Level | `story/level_bonnie.gd`, `story/games/bone_placement.gd`, `story/games/day2_board.gd` | first playable; builder B owns polish |
| Bean, clinic | `world/characters/bean.gd` (BONNIE spec, bun, apron), `world/clinic.gd` (patient_id, oscillator, masking phone) | first playable |
| Bot | `tools/autoplay_bot.gd` (bone search, plateau dance, Day 2 sanity checks) | `tools/autoplay_check.sh --day=2` |

## 14. Open questions for Steve

1. Occlusion values (250/500 +15, 1k +10) and the overmask rule with the conservative 40 dB IA.
2. Should Day 2 also ask for left bone, or is "left air normal, so no gap possible" the right lesson?
   **(v4: answered by Steve)** Yes: left bone IS tested now, unmasked, and FIRST (the better ear; `>` marks). It is
   the bone baseline for both ears, because unmasked bone tells you about the better cochlea wherever the
   oscillator sits. The right ear then gets one unmasked demo tone (the Ghost) and masked bone.
3. The plateau needs 3 raises with a response at the same tone level; a single lapse restarts it, so the
   stored masked threshold is often 5 dB above the truth (rarely 15: two unlucky lapses in a row, e.g.
   autoplay seed 4 at 250 Hz). Keep (realistic) or make the sim steadier near threshold?
   **(polish: answered)** steadier under masking (§15): masked stamps now land on the truth most of the time.
4. Insert earphones as a Day 2 shop item (55 dB rule IA): good hook for later days?

## 15. Polish pass (after the fun, audiology and bug reviews)

- **Pacing.** Right air: Hoot coaches one beep, then runs the rest with no 1 kHz retest
  (`skip_hoot_retest`). Left air: a few-second stamp montage (`montage`, quick visit only). With Quick
  visit off the player tests everything. The bone and masking sheets are always the player's.
- **Masked air after masked bone.** Clinics often mask air first; the level says so in one line. With the
  insert earphones (55 dB rule IA) Bonnie's right air cannot reach her left cochlea, so the level skips
  masked air with two Hoot lines, and the AudiOtron finishes an empty goal sheet at once (no soft-lock).
  `tools/autoplay_check.sh --day=2 --upgrades=insert_earphones` checks that path.
- **Scoring.** `MASKED_GRACE_DB` is 0. The simulator is calibrated instead (`MASKED_BIAS_DB` 4, slope x0.7, no
  lapses under masking), so a by-the-book plateau search writes down the profile value about 70-80 % of the
  time and masked air agrees with unmasked air (answers open question 3). This is a gameplay calibration,
  not a claim about central masking. The unmasked air truth is the shadow curve (whichever cochlea hears).
- **Ghost timing.** The big "Bone 10, air 50? BOO!" Ghost waits until a bone mark sits next to an air mark;
  the first unmasked bone beep gets a small "boo?". The overmasking callout says the noise "could leak into
  the test ear". A one-time tip names the shadow chase, and the plateau tip then says why pros trust it.
- **Otosclerosis.** After the referral stamp: extra bone grows around the stapes so it cannot vibrate freely;
  the ENT confirms; surgery or hearing aids, both can work well. The Carhart line says the cochlea is fine.
- **Board.** The bridge is drawn per frequency: planks under the bone marks, pillars down to the air marks
  labelled "toll N dB", the river only between gaps, the bone car hopping plank to plank.

## 16. Hoot's masking movie (v4)

"Hoot's Movie Matinee: The Cross-Hearing Ghost". A cartoon short that plays at the start of Day 2, before Bonnie
knocks, so the player meets every masking idea once before using it. Data: `story/explainers/movies/masking.gd`
(scene list); player: `story/explainers/explainer_player.tscn`; stage (the drawings): `story/explainers/explainer_stage.gd`.
API and entry points: `CONTRACTS.md` §3.4. How to make another one: `docs/ADDING_A_CHAPTER.md`, "Hoot's movies".

**Format.** A cinema: velvet curtains, a cream screen (the stage, 880 x 440), Hoot's portrait and caption bar
under it (typewriter, his gibberish voice), the title top-left and one dot per scene top-right; **(builders)** each
scene's title chip (the scene key `title`: a sunny number disc and the title in capitals, e.g. "3 THE SKULL WALL") in the screen's top-left corner. Each scene teaches
ONE idea in one or two captions (18 words or fewer each). Quiet stings only (Sfx at -6 dB or softer): "too loud"
and "too much noise" are drawn, never played. **(polish)** Space / Enter / a click advance like the dialogue box
(finish the caption, then the scene's second caption, then the next scene), Esc = skip the movie, P = pause; the
buttons "Next" ("Start the day" on the last scene, "Done" for replays), "Skip movie" and "II" (pause). It counts as
seen once it reaches the plateau scene (`seen_at`), so an early Esc plays it again next visit, and Hoot says where
to rewatch it. Replay: pause menu "Watch Hoot's masking movie" during Day 2, and the title's Options and its
"Hoot's Movies" button (a vertical list once there are several movies). The music is ducked while it plays.

**The cast.** Righty (red snail-shell cochlea, the test ear today) and Lefty (blue, the better ear), drawn inside a
big round cartoon head seen from the front, so her RIGHT is on the screen's LEFT, like the patient facing you.
A brick skull wall between them with a dB sign; a red on-ear cup; a beige bone buzzer; the Ghost (Lefty under a
bedsheet); the purple "shhh" cloud; a noise dial.

| # | Scene (`set`) | Visuals (the stage brief) | Caption(s), Hoot | s | The one idea |
|---|---|---|---|---|---|
| 1 | `meet` | Curtains swish open; title card HOOT'S MOVIE MATINEE / THE CROSS-HEARING GHOST holds 8 s while Hoot says what the movie is about, with two question chips under it ("Why can the OTHER ear answer?", "How does masking stop it?"). Then the big head with a see-through window; red Righty (screen left) and blue Lefty (screen right) pop in with name tags and wave. | "Hoot's Movie Matinee! Today's mystery: how do you test ONE ear when the other can hear?" / "The answer is called MASKING. Let's see why we need it, and how it works." / "Meet Righty and Lefty: two cochleas, one on each side of one head." | 14 | (Steve, 2026-10-19: the movie said nothing about what it would explain) What the movie answers; then: each ear has its own cochlea, both in one skull. |
| 2 | `air` | A red on-ear cup pops onto her right side. Music-note beeps hop down the canal to Righty, who rings a tiny bell. Lefty sleeps (zzz). | "An earphone sends a beep to ONE ear. Righty hears it. Lefty snoozes." | 8 | Air conduction tests one ear at a time. |
| 3 | `wall` | A brick skull wall grows between them, sign "-40 dB / on-ear phones: at least" (a tag "inserts: -55 dB or more"); a chip under Lefty: "Lefty hears from 5 dB". **(polish)** The meter on the cup climbs **30, 35, 70** (params `levels`, `lefty_hears` 5): the notes get BIGGER (drawn; the sound stays soft). Each beep goes into Righty's ear AND shakes the skull: a skull-shake note with a dotted trail runs from the ear canal over Righty (never out of Righty) to the wall. The soft ones bonk and "30 - 40: fizzle!"; at 70 one squeezes through UNDER the sign with a 24 px countdown chip (70 -> 30), taps Lefty, who wakes and raises a hand, and a "70 - 40 = 30" chip holds beside him ("30 is above his 5!"). | "Crossing the skull costs at least 40 dB with on-ear headphones. Insert earphones: at least 55." / "So a LOUD beep can leak across to Lefty. That's cross-hearing!" | 11 | Interaural attenuation: at least 40 dB on-ear (at least 55 inserts); loud air tones can cross. |
| 4 | `bone` | The cup pops off; a bone buzzer clicks onto the bump behind Righty's ear. bzz lines; the whole head jiggles like jelly; both snails vibrate the same. The wall sign flips "-40 dB" -> **"BONE: 0 dB lost (really 0-10)"** and the bricks turn see-through. | "A bone buzzer shakes the WHOLE skull, not just one side." / "Both cochleas feel it almost equally: 0 to 10 dB lost. Call it zero!" | 10 | Bone reaches both cochleas (IA 0-10 dB, treat as 0). |
| 5 | `ghost` | Righty (the poorer ear today) wears a nightcap and snores through a soft buzz. Lefty throws a bedsheet over itself (blue under the sheet, two eye holes), floats over to Righty's side and waves an "I HEARD IT!" flag. A big "BOO!" bubble; Hoot gasps. | "Testing Righty? Lefty hears the buzz too, and if Lefty hears better, Lefty answers first." / "That's the Cross-Hearing Ghost: the better cochlea answering for the poorer ear." | 10 | The Ghost = the better cochlea answering for the poorer ear. |
| 6 | `mask` | A blue cup pops onto Lefty's side; a purple squiggly cloud full of "shhh" letters fills Lefty's corner. Lefty puts on tiny sunglasses and dances, busy. **(polish)** A "buzz turned UP to Righty's level" chip, then the buzz comes: the bedsheet slides off; Righty raises its own hand. | "Masking: a steady 'shhh' in the OTHER ear keeps it too busy to answer." / "The shhh goes in the non-test ear. The beep still goes to the test ear." | 10 | Masking = noise in the non-test ear (today the better one). |
| 7 | `under` | The cloud shrinks to a patchy puff with holes; the Ghost peeks through one ("boo!"). The noise dial shows a "+5" arrow, then **"enough!"** in the green. | "Too little shhh? The Ghost still sneaks through the gaps. Add more!" | 7 | Undermasking: too little noise and the Ghost still answers. |
| 8 | `over` | The dial swings into the red. The cloud balloons, spills over the wall (its tag shrinks by 40 as it crosses) and smothers Righty, whose hand drops. A coral "TOO MUCH NOISE!" sign wobbles. Nothing loud plays. | "Too much shhh? It leaks back across the skull and drowns Righty too. Overmasking!" | 9 | Overmasking: noise minus IA reaches the test ear's cochlea. |
| 9 | `plateau` | **(polish)** A chunky graph the AudiOtron (and audiogram) way up: "more shhh in the other ear (dB EM)" along the bottom in 5 dB steps from a dashed "start 15" tick (the other ear's air + 10), "the answer (dB HL)" down the side, LOUDER LOWER ("louder" arrow). Hoot hops: the first answers sink with the noise (GHOST: "the answer chases the noise": 15/15, 20/20, 25/25), then three hops stay level (30/25, 35/25, 40/25): a green FLAT LINE, a "15 dB" brace, "PLATEAU!". After a "..." gap the line sinks again ("TOO MUCH: overmasking": 70/30, 75/35), held to the scene's end (about 3 s). A soft blip per hop. | "Raise the shhh 5 dB at a time. If the answer chases the noise, the Ghost was answering." / "Answer holds steady through 15 dB more shhh? Plateau! That's Righty's true threshold." | 14 | The plateau: the same answer through about 15 dB more noise (three 5 dB steps) is the true threshold. |
| 10 | `outro` | Righty, Lefty and Hoot bow; a "THE END?" card; the curtains close. Two soft knocks on the cinema door: the next patient is here. | "Busy the other ear, find the flat line. Ooh, a knock! Places, trainee!" | 6 | Recap: mask the non-test ear, trust the plateau. |

Total 93 s planned (each scene lasts at least its time and long enough to read its last caption, so about 96 s
at normal text speed).

**(polish) The recap**, `story/explainers/movies/masking_recap.gd` ("The short version", `short`: never listed for
replay): one `card` scene, 12 s, played when the masking phase opens (about 8 minutes after the movie, right before
the masked bone test). Lines: "Shhh goes in the OTHER ear" / "Start: its air + 10 (+ occlusion)" / "Heard? Shhh up 5.
Missed? Beep up 5" / "Flat for 15 dB of shhh = the truth"; the shhh cloud bobs beside them. Caption: "Short version:
shhh in the other ear, up 5 at a time, until the answer stays flat." Esc skips it. `tests/test_contracts_v4.gd` checks the scene ids, the caption lengths, 60-100 s, the
quiet cues, and the facts against `ClinicRules` (IA 40 / 55 / 0, three 5 dB steps, the "too much" scene really
overmasking).

**The facts behind it (Steve).** Supra-aural (on-ear) interaural attenuation **at least** 40 dB is the safe
textbook minimum (real heads lose about 40-80 dB; Bonnie's is 60), inserts at least 55; bone IA is 0-10 dB,
treated as 0. The wall's 30 and 35 dB beeps arrive below Lefty's 5 dB threshold (30 - 40 and 35 - 40 are below
5), the 70 dB beep arrives at 30, well above it. Masker levels are dB EM (effective
masking). Plateau = the same threshold through about 15 dB of masker increase (three 5 dB steps). Overmasking
starts when the masker minus the IA reaches the test ear's bone (cochlea). Undermasking: the non-test cochlea
still hears the tone. The movie never claims a number the game does not use.

**Sounds per scene** (all `Sfx`, at -8 to -16 dB; retimed by the builders to land on the drawings): fanfare and two
pops (meet), pop / note / ding (air), a thunk (the wall lands), two boings, a whoosh and a chirp (wall), thunk / soft
squeak / stamp (bone), squeak / whoosh / boing / pop (ghost), pop / soft whoosh / ding (mask), boing and two clicks (the
dial, under), whoosh / soft sad trombone (over), six blips, a sparkle and a ding, then two lower blips (plateau),
a soft fanfare and two door knocks (outro).

## 17. (v4) Builder checklist (done; integrated)

| Who | What | Where | State |
|---|---|---|---|
| builder B (story) | Animate the ten sets of §16 on the stage. Keep `SETS` and `show_scene()`; captions and cues stay in the data. Cartoon, readable at 1280x720, no vendor art. Check with `dev_explainer.tscn` | `story/explainers/explainer_stage.gd` | **done**: every set animated as a pure function of `t` (no placeholder left); plus the generic data-only `card` set and the card fallback for unknown sets (`docs/ADDING_A_CHAPTER.md`), the scene title chip, the title's "Hoot's Movies" button. **(polish)** The wall's meter is 30 / 35 / 70 against Lefty's 5 dB tag (§16 row 3), the plateau is drawn the audiogram way up, and a movie may bring its own sets script (`MOVIE.stage`, `story/explainers/explainer_sets.gd`, `CONTRACTS.md` §3.4) so later chapters never edit the stage |
| builder B | Polish the left placement art if needed (it is the unmirrored drawing; tray bottom-left), the quick right placement, and the left 3D oscillator shot (`ear_left`) | `story/games/bone_placement.gd`, `world/clinic.gd` | the designer's v4 versions are in; checked in the rendered run (`bc_placement_left`, `day2_bone_placement_right`) |
| builder B | Day 2 board: the left `>` marks next to the right `[` on the reveal; the bridge stays on the right ear | `story/games/day2_board.gd` | the designer's v4 version is in; checked on `day2_reveal` / `day2_bridge` and the golf card. `dev_day2.tscn --part=board` now builds v4 results (left `>`, right `[`) |
| builder A | The `demo_tone` plan's look: TONE glowing as the only live control, the other controls dimmed, the Ghost's "Bone 5, air 50? BOO!" (the heard level) | `ui/audiometer/audiometer_screen.gd` | **done** (`CONTRACTS.md` §4.2 v4: banner, locks with "just TONE!", GHOST TEST badge, quest note, "?" bone ranges, the Ghost lands on her left `>`; integrator: no booth punch-in during the demo, it hid the callout) |
| builder A | The coach on the LEFT bone sheet (the first bone test is now the left ear): the route lesson (B), no masking talk (no gap on the left) | `ui/audiometer/*` | **done** (`ui/tests/test_audiotron_v4.gd`); masked right bone's coach names the unmasked (left) bone as its start |
| integrator | Steve review of §3, §4 (v4 lines) and §16; `tools/movie_check.sh --day=2` (the movie's stings stay quiet) | | movie_check run at integration and again at the polish pass; Steve's review of the polish lines pending |
| polisher | The audiology and fun + bugs reviews of Steve's feedback build: "other ear", "at least 40 / 55", the criterion with her numbers, masked air vs the left BONE, Space like dialogue, `seen_at`, the skip line, the pause button, the ref-counted music duck, the demo's idle clock, `masking_deck: false`, the recap card, the movie list | everywhere above | **done** (`tests/test_contracts_v4.gd` covers each) |

Known small points: the 1 kHz level cursor can overlap the 1 kHz "?" range a little during the demo; the optional
250 Hz left bone bonus hole makes masked right bone ask for 250 Hz too (the rules see a gap there: one more plateau);
**(polish)** the 12-second recap card plays at every visit's masking phase (a refresher, never listed; Esc skips it),
and the full movie plays again on a later visit until it has been watched to the plateau scene (`seen_at`).
