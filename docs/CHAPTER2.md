# Booth Camp, Chapter 2 (Day 2): Bonnie Bunsworth, "Bone conduction + masking"

Design for the second playable day. Day 1 (Grandpa Gus, air conduction) is finished and must not change.
Contract changes for this chapter are marked **(v3)** in `CONTRACTS.md`. Every clinical number below lives in
`autoload/clinic_rules.gd` (section "v3") or `core/patients/bonnie.tres`; change it there, not in a copy.
Steve reviews every number.

| | |
|---|---|
| Teaches | bone conduction, the air-bone gap, cross-hearing, clinical masking (plateau), overmasking, conductive loss = ENT referral |
| Length | 10-15 minutes (about 12 with "quick visit" on, the default) |
| Opens | after Day 1 is finished, or at once with "Unlock all days (demo)" (title Days card, pause menu) |
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
referral red flag (gap 15+ at 500, 1k and 2k), Carhart notch; left ear normal. Bone is tested on the right
only: the left air is normal, so the left can't have an air-bone gap.

## 3. Beat by beat (about 12 minutes)

Times are for a first-time player with "quick visit" on. "Hoot runs" = Hoot's turn at x8 speed (input
locked, his stamps marked "hoot", not scored for golf). Every blocking beat emits `Events.awaiting_input`.

| # | Phase (`phase_changed`) | What happens | Beat(s) | Time |
|---|---|---|---|---|
| 1 | `intro` | Bonnie bursts in with croissants. Hoot: "Day 2, trainee! Today we test through the bone, not just the air." | dialogue | 0:45 |
| 2 | `history` | Two rounds of questions (table above). Red-flag card: "One ear only: YES = see a doctor." Medal `history`. | choice | 1:30 |
| 3 | `otoscopy` | A quick look (no mini-game today): canals clear, eardrums normal. "A healthy-looking eardrum can still hide a stiff middle ear." Medal `otoscopy` gold. | dialogue | 0:20 |
| 4 | `instructions` | New wrinkle: "Press for every beep, even faint ones. Ignore the shhh noise." Wrong picks cost a retry (and comfort for "press for the noise too"). | choice | 0:40 |
| 5 | `earphones` | Day 1's drag game, with "HER RIGHT" labels. Medal `earphones`. | earphones_place | 0:40 |
| 6 | `audiometry` {ear right, test ac} | Player stamps 1 kHz (coached), Hoot runs the rest. | (AudiOtron) | 1:30 |
| 6b | `audiometry` {ear left, test ac} | Hoot runs the left ear at top speed. Hoot: right needs about 50 dB, left normal. "But WHERE is it stuck?" | (AudiOtron) | 0:45 |
| 7 | `bc_placement` | Earphones off. The **oscillator placement mini-game** (section 6). Then the 3D oscillator goes on the right mastoid. Medal `bc_placement`. | bc_placement | 1:00 |
| 8 | `audiometry` {ear right, test bc} | Unmasked bone, coached: switch to BONE, stamp 1k and 2k; Hoot does 4k and 500. The **BOO!** Ghost callout on the first cross-heard tone. Afterwards: "Bone at 0 dB, air at 50? Suspicious. Bone buzzes BOTH cochleas." | (AudiOtron) | 1:30 |
| 9 | `masking` | "Which ear gets the shhh noise?" (left!). Medal `masking`. A single blue earphone goes on her left ear. Hoot explains the starting level and the plateau dance. | choice | 0:40 |
| 9b | `audiometry` {ear right, test bc_masked} | Masked bone, coached: masking ON, noise to the starting level, find the **flat line** at 1k and 2k; Hoot does 4k and 500. | (AudiOtron) | 2:30 |
| 9c | `audiometry` {ear right, test ac_masked} | Earphones back on. "Air needs masking too: 50 minus 40 reaches her left bone. I'll run it!" Hoot runs masked air. | (AudiOtron) | 0:20 |
| 10 | `reveal` | Bonnie's audiogram stamps in (O X, < unmasked bone, [ masked bone). The **toll bridge** draws in between bone and air with the gap in dB. "AIR-BONE GAP: ~35 dB". | dialogue | 1:00 |
| 11 | `evidence` | "What type of loss is Bonnie's right ear?" Sensorineural / Conductive / Mixed (the answer is the type her measured results show). Carhart notch line, masking-dilemma mention. Medal `evidence`. | choice | 0:45 |
| 12 | `referral` | "What's next for Bonnie?" Hearing aids today / **Refer to an ENT doctor** / See you in five years. Then the player slams the **REFERRED TO ENT** stamp. Medal `referral`. | choice, referral_stamp | 0:45 |
| 13 | `results` | The Daily Decibel, Day 2 edition. | results_continue | 0:45 |

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
| Placement | "Snug on the mastoid, not touching the ear. Bone tones go 500 to 4000 Hz." |
| The Ghost | "Bone has almost zero interaural attenuation. Her LEFT cochlea may have answered!" |
| Tip `cross_hearing` | "Bone has zero IA: that beep may have crossed to the OTHER cochlea. Meet the Ghost!" |
| Why mask | "To hear the right cochlea alone, keep the left one busy with noise. Masking!" |
| Wrong ear | "Noise in the test ear just hides the beep. Busy the OTHER ear." |
| Starting level | "Start noise: her left air threshold plus 10, plus extra for occlusion on low tones." |
| The dance | "Heard? Noise up 5. Missed? Tone up 5. Three noise steps, same answer: plateau!" |
| Tip `undermasked` | "The Ghost answered! Not enough noise yet: heard means noise up 5." |
| Tip `plateau_found` | "Flat line! Same answer through 15 dB more noise: that's the true threshold. Store it!" |
| Tip `overmasked` | "Too much noise! It leaks back and drowns the test ear too. That's overmasking." |
| Tip `vibrotactile` | "Loud low bone tones get FELT, not heard. A tickle is not a threshold!" |
| AC masking rule | "Air needs masking too: 50 minus 40 reaches her left bone. I'll run it!" |
| Toll bridge | "That gap is the toll bridge: air pays a toll at the middle ear. Bone drives past." |
| Type of loss | "Conductive loss! Gap over 10 dB with normal bone. Gaps of 15 or more are a referral flag." |
| Carhart | "See bone dip at 2k? A Carhart notch: a classic clue for otosclerosis." |
| Dilemma (mention only) | "If BOTH ears had big gaps, even masking could overmask. The masking dilemma. Another day!" |
| Takeaway | "Conductive loss with normal bone: refer to ENT. Often very treatable! Stamp it!" |

Masked-technique error tips (`AudiometrySession.TIPS`): `mask_wrong_step`, `mask_too_low`, `mask_start`,
`store_no_plateau`, `overmasked` (section 7).

## 5. Fun moments

- **The Cross-Hearing Ghost.** The first time an unmasked bone tone is answered by the LEFT cochlea, the
  booth window shows a big "BOO!" callout ("the Ghost: the LEFT cochlea heard it") and the glyph says "boo".
  During Hoot's turn it is a small "boo!" chip. After the unmasked bone test Bonnie: "A ghost in my skull?!
  I KNEW that oven was haunted."
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

Bonnie in profile on a cream card, facing left, so the visible ear is her RIGHT. The grey "bone buzzer" sits
in a tray. Drag it onto a spot, or click a spot; keyboard Left/Right (or the frequency keys) moves a highlight,
Enter/Space places. Beat `bc_placement` (solver = place on the mastoid). Anchors `oscillator`,
`mastoid_target_right`.

| Spot | Result | Gag | Hoot |
|---|---|---|---|
| **Mastoid** (behind the ear, on bone) | correct | buzz rings, "Bone on bone!" | "Perfect: on the mastoid bone, behind the ear, not touching it." |
| Ear flap (pinna) | slip | buzz arcs around the ear, "Bzzz! Tickles!" | "Off the ear flap! Touching the pinna makes it buzz. Behind the ear, on bone." |
| Forehead | slip | "Hmm, not today" | "Foreheads work for some tests. Today: the mastoid, just behind her right ear." |
| Nose | slip | the nose flashes, "BOOP!" | "Boop! A nose is cartilage. Find the bony bump behind her ear." |
| Top of head | slip | a golden **unicorn horn** sprouts, "UNICORN!" | "A majestic unicorn! Sadly not a clinical position. Behind the ear, please." |
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
| Carhart notch | bone at 2k at least 10 poorer than both 1k and 4k | `has_carhart_notch` |
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
- Golf card: rows R O, L X, plus R [ (masked bone) and R O+ (masked air) when present.

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

## 11. Chapter select, progression, unlocks

- `Game.CHAPTERS`: `gus` (Day 1: Grandpa Gus, `level_gus.tscn`) and `bonnie` (Day 2: Bonnie Bunsworth,
  `level_bonnie.tscn`, requires `gus`).
- Title: **Play** starts `Game.next_chapter_id()` (the first open day not yet done, else the last played).
  **Days** opens the day picker (phase and beat `chapter_select`): one card per day with best grade and
  plays; a locked day says how to open it; the toggle "Unlock all days (demo): ON/OFF"; Back / Esc.
- Day 2 opens when Day 1 is finished (`Game.finish_visit()` adds the chapter to `progress.chapters_done`
  and emits `Events.chapter_completed`), or with `settings.unlock_all_days` (title Days card, pause menu),
  or `--day=2` / `--chapter=bonnie` / `--unlock-all` on the command line. Old saves where Gus was played
  count as Day 1 done. Progress is saved in `user://save.json`.
- After Day 1 the paper offers "Next: Day 2: Bonnie Bunsworth" (key N).

## 12. Controls (keys and mouse)

| Action | Keys (default style) | Mouse |
|---|---|---|
| bone / air | B (or 8) / A (or 6) | ROUTE button (toggles) |
| masking on / off | M | MASK button |
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
3. The plateau needs 3 raises with a response at the same tone level; a single lapse restarts it, so the
   stored masked threshold is often 5 dB above the truth (rarely 15: two unlucky lapses in a row, e.g.
   autoplay seed 4 at 250 Hz). Keep (realistic) or make the sim steadier near threshold?
4. Insert earphones as a Day 2 shop item (55 dB rule IA): good hook for later days?
