# Clinical review

A check of every clinical procedure in Booth Camp against published guidance: Days 1, 2, 3 and 6 to 11, the freestyle clinic, the shared engine and audiometer screen, and the Day 4 and Day 5 designs. Each finding was checked a second time against the code and against a source that was actually read, quoted word for word. Code references are to `main` at 99a8566 (Days 1 to 3, 6 to 11 and freestyle merged) unless a line says otherwise.

The short version: the engine follows ASHA (2005) and BSA (2018) on the things that matter most (start at 1 kHz, down 10 and up 5, threshold from ascending answers, the masking rules for air, the plateau, the overmasking limit). The problems are mostly in teaching text, in a few grading rules that are stricter than the guidelines, and in things a newcomer is never told.

## How to use this list

**Everything here is low priority** (Steve, 2026-10-19). Each item is fixed after its day is finished and merged into `main`. No day, and no fix for a playable bug, waits for an item on this list: finding the playable bugs early matters more.

Severity:
- **Wrong**: teaches or grades something the guidelines contradict.
- **Misleading**: a newcomer would come away with the wrong idea.
- **Missing**: an expected step or explanation is absent.
- **Choice**: guidelines differ; Steve's call (his answers are in the next section).
- **Kept**: a simplification that is fine for a game; noted only.

Owners and when: **Engine**, **Day 1** and **Day 2** items go to the integrator as small follow-up PRs once Days 4 and 5 are in; **Cases** items go to the cases thread after its current PR; **Freestyle** items to the freestyle thread; **Speech** items (Days 3 to 5) are already with the speech thread.

## Steve's decisions (2026-10-19)

| Topic | Decision | What changes |
|---|---|---|
| Better ear first for bone | Yes, everywhere | The cases still start unmasked bone on the poorer ear (C1). |
| Cross-hearing tip | Fix the misleading wording | E4 |
| Failed 1 kHz retest | Hoot explains why the retest matters | E3 |
| Masking dilemma | Explain it, and build a later, more advanced case that has one | E9, C9 |
| Masked air | Use it in a more advanced case | C10 |
| 1 kHz retest in the first ear only | Steve is reading ASHA and BSA on it; default below | E2, question 2 |
| Routine frequencies | 1.5, 3 and 6 kHz routine; 750 Hz only when 500 Hz and 1 kHz differ by 20 dB or more | E1 |
| Case with a 750 Hz jump | Needed | Day 9 Ginger already has one (500 to 1k: 25 dB right, 20 dB left), see C11 |
| Stimulus | Pulsed tones by default, and a bit louder for the player | E7 |
| Tinnitus | Hoot explains pulsed and warble tones during the tinnitus case | E8, C8 |
| 125 Hz | Not added: rare in practice and hearing aids barely use it | none |
| Short gaps between tones | Fine as a simplification, but a short gap should at least break the combo | E6 |
| Bone masking flag | Taken from the best unmasked bone threshold anywhere | Already on `main` (`ClinicRules.unmasked_bone`); the gap size is question 1 |
| Forehead bone | Worth a mention | D2-6 |
| Plateau | Keep 5 dB steps and a 15 dB plateau | none |

Where Steve has not answered, the default in the question list at the end applies until he says otherwise.

## Fix list

### Engine and audiometer screen (Engine)

**E1. Routine 1.5, 3 and 6 kHz; 750 Hz on the 20 dB rule.** [Choice: Steve decided]
Today 750, 1500, 3000 and 6000 Hz are added only when the neighbouring octaves differ by 20 dB or more (`autoload/clinic_rules.gd:18-20`, `INTEROCTAVES` and `TEST_ORDER`; `core/audiometry_session.gd:1106-1126`, `required_remaining`). So Gus, the Day 1 hearing-aid candidate with a high-frequency loss, never gets 3 or 6 kHz. New air order per ear: 1k, 1.5k, 2k, 3k, 4k, 6k, 8k, retest 1k, 500, 250, with 750 added only when 500 Hz and 1 kHz differ by 20 dB or more. Every patient file already holds values at all ten frequencies. Also update the order tips, Hoot's montages, par, the autoplay baselines and the docs that print the order. ASHA (2005) lists 3 and 6 kHz in the standard order; 1.5 kHz routine is a dispensing habit (fitting software uses it), which is fine.

**E2. 1 kHz retest in the first ear only.** [Wrong; default pending Steve's reading]
The retest is required, and missing it is graded as an error, in both ears (`core/audiometry_session.gd:493-494` raises `missed_retest`, `:1124` and `:1166` add it to the remaining list for every ear). ASHA (2005): "A retest at 1000 Hz is not necessary when testing the second ear." BSA (2018, section 6.4): "Then, for the first ear only, retest at 1000 Hz" and "The retest at 1000 Hz is normally not required in the second ear unless tests in the first ear revealed significant variation." Change: require it on the first air ear of the visit; on the second ear accept a voluntary retest without requiring it, unless the first ear's retest was off by more than 5 dB. Day 2's quick visit currently waives the retest on both ears (`story/level_bonnie.gd:351` and `:356`, `skip_hoot_retest`); keep the first ear's.

**E3. A failed retest gets an explanation.** [Missing: Steve decided]
A retest more than 5 dB off is a technique error with a one-line tip (`core/audiometry_session.gd:49`, `:497-498`), and nothing else happens. Add a short Hoot beat: why we retest (patients get better at the task in the first minutes, so a retest that comes out better says the first thresholds may be too high), re-instruct the patient, and recheck one earlier frequency. BSA (2018, 6.4): if the two values are within 5 dB keep the more sensitive one; if more than 5 dB apart, investigate.

**E4. Cross-hearing tip wording.** [Misleading: Steve decided]
The tip says "Bone has zero IA: that beep may have crossed to the OTHER cochlea" (`core/audiometry_session.gd:64`), but it also fires when an air tone crossed over. Split it by transducer. For air, something like "That loud beep leaked across the skull to the OTHER cochlea. Meet the Ghost! Time to mask." Air crosses once the level beats the interaural attenuation, about 40 dB with supra-aural phones and 55 with inserts (BSA 2018, 8.1).

**E5. Mask bone from a 10 dB gap.** [Choice: default 10 or more, question 1]
`bc_masking_needed` goes through `is_conductive_gap`, which is true only above 10 dB (`autoload/clinic_rules.gd:271`, `:350-351`, `:421-423`), so on the 5 dB grid masking starts at 15. ASHA (2005), bone conduction, Masking: "If the unmasked bone-conduction threshold is 10 dB better than the air-conduction threshold at that frequency in either ear, masking must be used." BSA (2018, 8.6.2, Rule 2): "Masking is needed at any frequency where the not-masked b-c threshold is better than the air-conduction threshold of either ear by 10 dB or more." Change: a separate `BC_MASK_GAP_DB := 10` compared with `>=` for the masking decision; keep `ABG_CONDUCTIVE_DB` (over 10) for naming the type of loss and drawing the gap bridge. Reword the audiogram legend ("blinking = air-bone gap over 10: mask it", `ui/audiogram/audiogram.gd:673`) and the Day 2 lines (D2-1). The unmasked bone already comes from either mastoid (`ClinicRules.unmasked_bone`, `autoload/clinic_rules.gd:537`), as Steve asked. No patient's true gap is exactly 10 dB, so this changes play only when a stamp is 5 dB off, plus Marina's left 4 kHz (C6).

**E6. A short gap breaks the combo.** [Kept, with Steve's change]
Gaps are penalised only when they fall into a regular rhythm (`core/audiometry_session.gd:1463-1478`). A gap shorter than a beep shows a one-time tip, and only when the patient guesses (`:1329-1331`); it never breaks the combo. Change: a gap shorter than the tone before it (or under about 1 s) breaks the combo with no other score change, the way the rhythm check does (`:1611-1629`), and shows the tip the first time.

**E7. Pulsed tones by default, a little louder for the player.** [Choice: Steve decided]
The screen starts on a steady tone (`ui/audiometer/audiometer_screen.gd:125`, `_stim := 0`; `core/tone_generator.gd:33`). Make pulsed the default. For loudness, `autoload/audio_safety.gd` is the only place that maps dB HL to playback (0 dB HL at about -75 dBFS, 0.6 dB per dB HL, `:7`, `:15-16`): raise the tone mapping a few dB there and keep every peak and bus ceiling (`:19-22`) as it is. ASHA (2005) allows continuous or pulsed tones; BSA (2018) advises against pulsed tones for calibration reasons, which matters less for a game.

**E8. Tinnitus changes the patient's answers.** [Missing]
`tinnitus_hz` is documented as "Near this frequency, steady tones are confused" (`core/patient_profile.gd:50-51`), but the patient simulator never reads it, and the stimulus never changes an answer. Change: within about half an octave of `tinnitus_hz`, steady tones give a few more misses and false alarms; pulsed or warble brings them back to normal. Rocco has `tinnitus_hz = 4000`, Marina 250. ASHA (2005): "Use a pulsed signal or a warble tone to help distinguish the test signal from the tinnitus." BSA (2018): "Subjects often find a warble tone easier to hear against their tinnitus than a pure-tone." Lentz et al. (2017): "the steady tone was rated as more difficult" "than the warble and pulsed tones." The lesson itself is C8.

**E9. Masking dilemma and an unreached plateau.** [Missing: Steve decided]
When one more 5 dB of noise would overmask, the player may store a masked threshold without a plateau (`core/audiometry_session.gd:602`, `window_full`; `ClinicRules.masking_dilemma`, `autoload/clinic_rules.gd:448`), but nothing explains it, and the chart has no "plateau not reached" mark. No current patient can reach it. Before the advanced case (C9) ships: a short explainer and Hoot line, the coach stops short of overmasking, and the stamp is recorded as "masked threshold not found" with a mark on the audiogram (BSA 2018, 8.8 step 5 and 8.9.4).

**E10. Mask lamp says "good" too early.** [Misleading]
The masking lamp shows "good" as soon as the noise is in the safe window, while the Ghost may still be answering. Call the green state "in range" and show "good" only once the plateau is found (BSA 2018, 8.8 step 6).

**E11. The straining face gives the threshold away.** [Misleading]
The "straining" face shows only when the dial is exactly at the true threshold, so a player can read thresholds off the face. Make it probabilistic across a few dB around threshold, or tie it to a slow press (ASHA 2005 asks testers not to give cues).

**E12. Audiogram proportions.** [Misleading]
The chart stretches to fill its card (`ui/audiogram/audiogram.gd:262-275`), so one octave is about 1.7 times as wide as 20 dB. ASHA (1990) symbols guideline: one octave should span the same distance as 20 dB. Letterbox the plot to that ratio on the audiometer screen and the reveal.

**E13. Masked air never differs from unmasked air.** [Missing: see C10]
Every patient uses the default real interaural attenuation of 60 dB (phones) and 75 dB (inserts) (`core/patient_profile.gd:28-30`), while the rules teach 40 and 55. So masked air always confirms unmasked air. The advanced case (C10) needs a lower real IA or a dead ear so a shadow curve appears and masked air drops.

**E14. Occlusion allowance source.** [Choice: default keep, question 4]
15 dB at 250 and 500 Hz and 10 dB at 750 and 1000 Hz with phones, and 0 with inserts (`autoload/clinic_rules.gd:257-260`), are Goldstein and Newman's values, within published ranges. The source comment (`:228`) credits Studebaker and Yacullo, whose values are larger; fix the comment.

**E15. Degree-of-loss scale.** [Choice: default keep, question 5]
The scale is normal up to 25 dB HL on the 500/1k/2k average, without ASHA's "slight" band, and the audiogram and reveal spell "moderately severe" differently. Keep one name everywhere and add a small footnote naming the scale.

**E16. Vibrotactile levels.** [Kept]
Set 250 Hz to 25 and add 1000 Hz at 70 in `VIBROTACTILE_DB` (`autoload/clinic_rules.gd:248`) when convenient, and optionally mark a felt tone with a small note on the chart.

### Day 1, Gus (Day 1)

**D1-1. Patient instructions.** [Missing] The right answer ("Press the button whenever you hear a beep, even if it's very faint.", `story/level_gus.gd:262`) leaves out "as soon as", "either ear" and "let go when it stops" (BSA 2018, 6.1). Lengthen it, and make the wrong options a similar length so length doesn't give the answer away.

**D1-2. Better ear first for air.** [Missing] Day 1 always tests right, then left, and never mentions the rule. One Hoot line: "Better ear first! Gus says they're the same, so either works." (ASHA 2005; BSA 2018, 6.4.)

**D1-3. What comes before a fitting.** [Missing] The fitting teaser follows an air-only test. One Hoot line before it: "Sneak peek only! Before real aids: bone conduction, speech tests and a red-flag check. Then we measure the fit in his ear." (AAA 2006, sections 2.1 and 3.3.)

**D1-4. Earphones on an older ear.** [Missing; question 6] The earphone step never mentions centring the cup over the canal or collapsing canals in a 78-year-old. One line and a caption (ASHA 2005; BSA 2018, 5.1 and 6.3).

**D1-5. Otoscopy medal.** [Kept, small change] Clicking the eardrum landmarks counts as a wrong click toward the medal. Make clicks on the drum and the cone of light free (BSA 2022 ear examination, 4.2).

**D1-6. "Dishes" heard as "fishes".** [Kept] The two words differ in voicing, which a high-frequency loss rarely causes. The gag can stay; if it is ever reworded, a pair that differs only in a soft high sound (sixty/fifty, sink/think) fits better (Wang, Reed and Bilger 1978).

**D1-7. Short case history, safety picks ungraded.** [Kept; question 7] Two history picks keep the pace; a greyed "a full history also covers" list on the case note would tell newcomers it is a shortcut.

### Day 2, Bonnie (Day 2)

**D2-1. Masking rule lines.** [Follows E5] "Any gap over 10? Mask the bone!" and "air more than 10 dB poorer than unmasked bone? Mask the bone!" (`story/level_bonnie.gd:484`, `:486`) become "a gap of 10 or more? Mask the bone!" if question 1 stays at the default. The red-flag line at `:642` ("A gap over 10 dB, bone near normal") is about the size of a real conductive component and can stay.

**D2-2. Air on the poorer ear first.** [Misleading] Day 2 tests air on Bonnie's poorer right ear first (`story/level_bonnie.gd:351-358`), although she says her left is perfect and the same day teaches better ear first for bone. Swap the two air tests: Hoot's montage does the left ear, then the player gets the coached right ear. (ASHA 2005; BSA 2018, 6.4.)

**D2-3. Noise headline.** [Misleading] The Daily Decibel C headline "NOISE MOSTLY IN THE RIGHT EAR, CONFIRMS OWL" (`story/daily_decibel.gd:41`) puts the noise in the test ear. "NOISE MOSTLY IN THE LEFT EAR" or "IN THE OTHER EAR" makes the joke teach the rule.

**D2-4. Hair and the open test ear.** [Missing] Never taught: hair out from under the oscillator, and the test ear left uncovered during masked bone. Add to the placement and masking lines (ASHA 2005; BSA 2018, 7.1 and 7.5).

**D2-5. Small wording fixes.** [Kept] "Bone marks are never joined" (`story/games/day2_board.gd:308`) becomes "usually aren't joined" (ASHA 1990). "Surgery to free it" (`story/level_bonnie.gd:682`) becomes a tiny-piston operation (modern stapes surgery replaces the stapes with a prosthesis; StatPearls, Otosclerosis). "Bone skips both, straight to the cochlea" (`:363`) becomes "mostly skips", since the same day teaches the Carhart notch. One Hoot line can mention that a full work-up adds tympanometry and reflexes.

**D2-6. Forehead bone.** [Steve's suggestion] The placement game already answers a forehead click with "Forehead placement exists, but today: the mastoid" and counts it as a slip (`story/games/bone_placement.gd:32`). Add a line on when clinics use the forehead (it sits more steadily and gives more repeatable results, but it needs more output, so the top of the range is lower), and consider not counting a forehead click as a slip.

### Cases, Days 6 to 11 (Cases)

**C1. Bone on the better ear first.** [Choice: Steve decided] Every one-sided case starts unmasked bone on the poorer ear, because the case checker requires bone on the reveal ear only (`story/case_data.gd:356-358`), and the masked-bone loop runs only over ears that had unmasked bone (`story/level_case.gd:615-660`). Change: unmasked bone on the better ear, masked bone on the case ear (the engine already compares every ear with the best unmasked bone), and rewrite the "bone buzzer on her left" lines (for example `story/cases/fluid.json:102`).

**C2. "Flat B means fluid".** [Misleading] Days 7 and 9 say "A flat B would mean fluid" (`story/cases/menieres.json:86`, `story/cases/cookie_bite.json:86`, the option "Yes: flat, type B. Fluid.") before canal volume is taught, and any day can be played first. Say "A flat B with a normal canal volume would point to fluid" (flat with a small volume points to wax or the probe; flat with a large volume to a hole).

**C3. Otoscopy and the drainage red flag.** [Misleading] "True: that clears wax, drainage and deformity." (`story/cases/noise_notch.json:138`, `story/cases/cookie_bite.json:158`). A clear canal today does not clear drainage in the last 90 days, which is the FDA red flag (21 CFR 801.422). Say "drainage today" and leave past drainage to the history question.

**C4. What counts as sudden.** [Missing] Dash's day never says what sudden means or how recent means "doctor today". One line: "Sudden means it came on over three days or less. Started in the last month? Doctor today." (NICE NG98, 1.1.2.)

**C5. Tympanometry into a packed canal.** [Choice; question 9] The probe seals on a canal "packed solid with wax" with no caveat (`story/cases/wax.json`). Keep the "flat and tiny volume means blocked" lesson, with Hoot saying many clinics skip the probe here and that it is a gentle seal at the entrance, never a push.

**C6. Marina's 4 kHz with the 10 dB rule.** [Follows E5] With masking from a 10 dB gap, Marina's left 4 kHz (air 25, unmasked bone 15) needs masked bone, and `_borrow_bone` (`story/level_case.gd:705-709`) should accept a borrowed gap of 5 dB or less, not 10.

**C7. Small wording fixes.** [Kept] "Wax out by a doctor" (`story/cases/wax.json:142`, `:168`) can become "by a doctor or a trained clinician" (question 8). "Bone skips the middle ear" (`story/cases/wax.json:106`, `story/cases/fluid.json:102`) becomes "mostly skips". The retest card "TWO DAYS LATER" (`story/cases/wax.json:183`) follows "softening drops for a few days": "A WEEK LATER" fits (BSA aural care guidance, 2025). The printed adult canal band of 0.9 to 2.0 mL (`core/cases/case_rules.gd:78`, printed at `story/games/case_tymp.gd:175`) is a male band; many women's canals are 0.7 to 0.9 mL (question 10).

**C8. The tinnitus lesson.** [Steve decided] On Rocco's day (and briefly on Marina's), Hoot explains why pulsed or warble tones help a patient with ringing ears: a pulsing or wobbling beep stands out from a steady ring. Works with E7 and E8.

**C9. New advanced case: a masking dilemma.** [Steve decided] A case near the end of the days with a large conductive loss in both ears, where the starting noise already risks overmasking. It needs E9 first.

**C10. New advanced case: masked air.** [Steve decided] A case where masked air really changes the chart: one very poor or dead ear with a lower real interaural attenuation, so unmasked air shows a shadow of the good ear and masking reveals the true threshold. It can be the same patient as C9 or a second one.

**C11. A 750 Hz case.** [Steve decided] Ginger (Day 9) already has the jump: 500 Hz to 1 kHz is 25 dB on the right and 20 on the left (`core/patients/ginger.tres`), so 750 Hz is required there today. Because stamps within 5 dB are accepted, her left ear triggers it only when the stamps are accurate; widening her left jump to 25 makes it reliable. Hoot should explain 750 the first time it is asked for.

**C12. Explainers.** [Missing] The cases have no explainer movies: red flags and the three stamps, audiogram shapes, and the tympanometer. Since any day can be played first, gate them the way the briefing is gated.

### Day 3 and Days 4 and 5 (Speech)

The speech thread is already folding these into its Day 4 and Day 5 work (`/mnt/project-files/boothcamp/speech_design/CLINICAL_AMENDMENTS.md`). Its own open questions for Steve (Dubno's 25-word limits, the rollover cut-off, critical differences, the word-test level, referral urgency) are in its Chapter 4 design.

- **S1. Sloping loss and the SRT.** [Wrong] Day 3 lists "a sloping loss" as a reason for an SRT worse than the PTA. A sloping loss tends to make the SRT better than the three-frequency average (ASHA 1988). Fix in progress (amendment A8).
- **S2. Praise for starting low.** [Misleading] "Starting low and coming up" praise fires on any low first word, with no ascent.
- **S3. Familiarisation by reading.** [Misleading] Mike reads the printed cards instead of hearing the words; ASHA (1988) familiarises by ear. A Hoot-led version is planned.
- **S4. ASHA-style SRT start.** [Choice; question 11] A first word 30 to 40 dB above the PTA (ASHA 1988) is scored as an error.
- **S5. SRT method.** [Choice; question 11] The game's down-10, up-5 routine is one common way, not ASHA 1988's descending method; Hoot can say so.
- **S6. Better ear first.** [Missing] The SRT ear order is fixed right then left.
- **S7. Day 3 explainer.** [Missing] Nothing explains the PTA, spondees, the SRT or agreement before the day.
- **S8. Word-test design (Day 4).** [Wrong and Misleading] The predicted-minimum table was 15 to 20 points stricter than Dubno (1995); rollover used a raw drop rather than the index; a fixed 20-point gap between ears ignores how much 25-word scores vary. All three replaced in amendments A1 to A3.
- **S9. Speech in noise lines (Day 5).** [Misleading] "Small" SNR loss for the normal band; "audiograms like his usually mean little noise trouble"; a booth result presented as proof of benefit in real rooms. Replaced in amendment A7.
- **S10. Kept.** The SRT ladder puts louder at the top, the opposite of the audiogram; its labels prevent misreading. Mike shows no tone-side signs of a non-organic loss.

### Still being checked

The freestyle clinic's eight patients, and twelve gaps a final completeness check raised (among them explainers when days are played out of order, a listening check and infection control, and how inserts are placed), are being checked a second time. They will be added here as a revision.

## Kept as simplifications

- Vibrotactile responses are a tickle emote only; the patient never presses for a felt tone (E16 is optional).
- Under masking noise the patient answers a little more steadily, and central masking is not modelled.
- Better ear first for bone is Steve's convention; BSA (2018, 7.1) starts on the poorer ear when it will need masking. Hoot can mention that some clinics do it the other way.
- The plateau uses 5 dB steps and a 15 dB plateau starting at the non-test ear's air plus 10 (Hood; Yacullo); BSA uses 10 dB steps. Steve keeps the 5 and 15.
- No 125 Hz (Steve: rare in practice, hearing aids barely use it).
- Insert IA printed as exactly 55 dB; "at least 55 dB, inserted deep" is more accurate if the shop text is touched.

## What the game already gets right

- Each ear starts at 1 kHz, about 40 dB HL, never above 70 (`autoload/clinic_rules.gd`, `START_DB`, `MAX_START_DB`).
- Heard means down 10, missed means up 5; before the first response, climb 10.
- Threshold is the lowest level with at least 2 ascending responses on at least half of the ascending trials; the climb before the first response is not counted.
- The retest agrees within 5 dB and the better value is plotted.
- Later frequencies start at the previous threshold plus 10 and descend; the first response at each frequency serves as familiarisation.
- Tones last 1 to 2 s (an error above 3 s), gaps vary, a regular rhythm is penalised, and false alarms are never credited to a tone.
- Air needs masking when the test ear's air minus IA reaches the non-test ear's bone (equality counts), with IA 40 dB for phones and 55 for inserts.
- Masked air: noise starts at the non-test ear's air plus 10; heard means noise up 5, missed means tone up 5; the plateau is the same answer through three 5 dB raises; no occlusion allowance for air.
- The overmasking limit is the test ear's bone plus the minimum IA of the masker earphone.
- The masker is a narrow band centred on the test frequency.
- Full accuracy credit within 5 dB of the true threshold.
- Unmasked bone is read from either mastoid when deciding where to mask.

## Starting at 30 or 40 dB at every new frequency

Steve asked whether presenting at 30 or 40 dB HL at each new air frequency is supported by research. In short: no guideline prescribes it and no study tested it. 30 dB HL (ASHA) and 40 dB HL (BSA and ISO, as an example) are the familiarisation levels at 1 kHz at the start of the test; for later frequencies BSA starts about 30 dB above the neighbouring threshold and ISO at "an estimated audible level". The habit costs time, not accuracy, as long as threshold is still approached from below: a fixed 30 dB HL start needs the fewest presentations for thresholds of 10 to 25 dB HL and about one more for every 10 dB above 50 (Marshall and Hanna 1986). The game accepts it without a penalty. The full answer, with sources, is the appendix below.

## Questions for Steve

Reply with a number only where you disagree; the default applies otherwise.

1. Mask bone from an air-bone gap of 10 dB or more (ASHA and BSA) instead of 15 as now. Default: switch to 10.
2. Retest 1 kHz in the first ear only, and in the second ear only when the first ear's retest was off by more than 5 dB (ASHA and BSA). Default: yes.
3. Bone frequencies: keep 500, 1k, 2k and 4k, with no 3 kHz bone and no bone retest. Default: keep.
4. Occlusion allowance: keep 15/15/10 dB with supra-aural phones (250/500/1k) and 0 with inserts. Default: keep.
5. Degree scale: keep the current one (normal up to 25 dB HL on the 500/1k/2k average) and name it in a footnote. Default: keep.
6. Older patients: add one Hoot line on collapsing canals (inserts fix it) and centring the cups; no new mechanic. Default: yes.
7. Day 1 safety picks (the paperclip, ignoring the seed): a wrong pick takes away the S grade for that visit, and Hoot's correction stays. Default: yes.
8. Barnaby's wax: "out by a doctor or a trained clinician, then we retest" instead of "out by a doctor". Default: yes.
9. A canal packed with wax: Hoot says many clinics skip the probe here and that it is a gentle seal at the entrance. Default: yes.
10. Adult canal volume on the tympanometer: print 0.6 to 2.0 mL (BSA's lower edge; women's canals are smaller) instead of 0.9 to 2.0. Default: yes.
11. Day 3 SRT: accept a first word 30 to 40 dB above the PTA (ASHA 1988) without a penalty, and keep the down-10, up-5 routine with Hoot calling it one common way. Default: yes.

## Sources

- ASHA (2005). Guidelines for Manual Pure-Tone Threshold Audiometry. https://www.asha.org/policy/gl2005-00014/
- British Society of Audiology (2018). Recommended Procedure: Pure-tone air-conduction and bone-conduction threshold audiometry with and without masking. https://www.thebsa.org.uk/wp-content/uploads/2024/01/Recommended-Procedure-Pure-Tone-Audiometry-2018.pdf
- ASHA (1990). Guidelines for Audiometric Symbols. https://www.asha.org/policy/gl1990-00006/
- ASHA (1988). Guidelines for Determining Threshold Level for Speech. https://www.asha.org/policy/gl1988-00008/
- ASHA. Degree of Hearing Loss (after Clark 1981). https://www.asha.org/public/hearing/degree-of-hearing-loss/
- CSHBC. Clinical Masking for Audiometric Testing in Adults (Hood 1960; Yacullo; Turner 2004). https://chcpbc.org/wp-content/uploads/2026/03/AUD-HIP-Clinical-Masking-for-Audiometric-Testing-in-Adults.pdf
- Novick M (2006). Insert Phones, Masking, and Occlusion Effect. AudiologyOnline. https://audiologyonline.com/ask-the-experts/insert-phones-masking-and-occlusion-450
- American Academy of Audiology (2006). Guidelines for the Audiologic Management of Adult Hearing Impairment. https://www.audiology.org/wp-content/uploads/2021/05/haguidelines.pdf_53994876e92e42.70908344.pdf
- 21 CFR 801.422, prescription hearing aid labeling (red flags for dispensers). https://www.law.cornell.edu/cfr/text/21/801.422
- BSA (2022). Recommended Procedure: Ear Examination. https://www.thebsa.org.uk/wp-content/uploads/2023/10/OD104-54-BSA-Recommended-Procedure-Ear-Examiniation-February-2022.pdf
- BSA (2026 revision). Recommended Procedure: Tympanometry and Acoustic Reflex Thresholds. https://www.thebsa.org.uk/wp-content/uploads/2026/03/BSA-Recommended-Procedure-Tympanometry-Acoustic-Reflex-Thresholds-March-2026-minor-revision.pdf
- BSA (2025). Practice Guidance: Aural Care (Ear Wax Removal). https://www.thebsa.org.uk/wp-content/uploads/2025/09/OD104-93-BSA-Aural-Care-Ear-Wax-Removal-July-2025.pdf
- Humes et al. (2023). Reference-interval approach to tympanometric norms, US data ages 6 to 80+. American Journal of Audiology 32(4). https://pubs.asha.org/doi/10.1044/2023_AJA-23-00092
- e3 Diagnostics. What Does a Flat Line in Tympanometry Mean? https://e3diagnostics.com/blog/FlatLineTympanometry
- NICE NG98 (2018). Hearing loss in adults: assessment and management. https://www.nice.org.uk/guidance/NG98/chapter/recommendations
- StatPearls. Otosclerosis. https://www.ncbi.nlm.nih.gov/sites/books/NBK560671/
- StatPearls. Nonorganic Functional Hearing Loss. https://www.statpearls.com/point-of-care/142869
- Emanuel DC (2005). Why does the Carhart notch appear at 2000 Hz? AudiologyOnline. https://www.audiologyonline.com/ask-the-experts/why-does-carhart-notch-appear-509
- Wang MD, Reed CM, Bilger RC (1978). A comparison of the effects of filtering and sensorineural hearing loss on patterns of consonant confusions. JASA 63(5).
- Lentz JJ et al. (2017). Am J Audiol 26:328-337 (steady, pulsed and warble tones in listeners with tinnitus).
- Yacullo WS (1999). Clinical Masking in Speech Audiometry: A Simplified Approach. Am J Audiol 8:106-116. https://pubs.asha.org/doi/10.1044/1059-0889(1999/019)
- Guthrie LA, Mackersie CL (2009). A Comparison of Presentation Levels to Maximize Word Recognition Scores. J Am Acad Audiol 20(6):381-390. https://pmc.ncbi.nlm.nih.gov/articles/PMC2948673
- Margolis RH (2005). Positive rollover. AudiologyOnline. https://audiologyonline.com/ask-the-experts/positive-rollover-515
- Mueller HG, Hornsby BWY. 20Q: Word Recognition Testing. AudiologyOnline. https://www.audiologyonline.com/articles/20q-word-recognition-testing-let-26478
- Sources for the starting-level question are listed in the appendix.

## Appendix: starting at 30 or 40 dB HL at every new air-conduction frequency


Steve's question (2026-10-18): "A common thing that we do is present at 30 dB or 40 dB for each new frequency in air conduction. Is that supported in any of the research?"

### Short answer

No guideline, standard or study recommends a fixed 30 or 40 dB HL first tone at every new frequency, and no study has tested it. Both numbers come from the **familiarisation tone at 1 kHz at the start of the test**: 30 dB HL is ASHA's, 40 dB HL is the BSA and ISO example for a listener with normal hearing. For the frequencies after that, the guidelines either give no separate rule (ASHA) or start at a level judged audible from the responses so far (BSA: about 30 dB above the neighbouring threshold; ISO: "an estimated audible level, as indicated by the previous responses").

The habit is harmless for accuracy as long as threshold is still approached from below (down 10, up 5, count the ascending yeses). Its cost is time: the one analysis that looked at a fixed 30 dB HL start found it takes the fewest presentations when thresholds are 10 to 25 dB HL, and about one extra presentation for every 10 dB above 50 dB HL (or below 10). A start set relative to the previous threshold avoids that. Automated audiometers use both styles.

### What the guidance says

| Source | First frequency (familiarisation) | Each later frequency |
|---|---|---|
| **ASHA 2005**, Guidelines for Manual Pure-Tone Threshold Audiometry | "Present a 1000-Hz tone at a 30 dB hearing level (HL). If a clear response occurs, begin threshold measurement. If no response occurs, present the tone at 50 dB HL and at successive additional increments of 10 dB until a response is obtained." (Or ascend a continuous tone from silence.) | No separate rule. "The procedure is the same regardless of frequency, output transducer, or ear under test." The search itself starts low: "The level of the first presentation of the test tone shall be well below the expected threshold." The page never mentions 40 dB HL. |
| **BSA 2018**, Recommended Procedure: pure-tone air- and bone-conduction audiometry (section 6.6, 6.7) | "present a tone of 1000 Hz that is clearly audible (e.g. at 40 dB HL for a normally hearing subject or approximately 30 dB above the estimated threshold for a subject with a hearing impairment, but never more than 80 dB HL)." Then "reduce the level of the tone in 10-dB steps until no further response occurs" and bracket up 5, down 10. | "Proceed to the next frequency, starting at a clearly audible level (e.g. 30 dB above the adjacent threshold, but see notes on familiarisation in Section 6.6)". Relative to the neighbouring threshold, not a fixed dB HL. |
| **ISO 8253-1:2010** (clause 6.2, read in the free EN ISO sample and checked against the Russian adoption GOST R ISO 8253-1-2012) | Given as an example, not a requirement: "present a tone of 1 000 Hz at a hearing level which is clearly audible, e.g. 40 dB for a normal hearing test subject", then down in 20 dB steps until no response and up in 10 dB steps until it returns. "Present the first test tone at a level which is 10 dB below the lowest level of the response of the test subject during the familiarization session." | "Proceed to the next test frequency at an estimated audible level, as indicated by the previous responses". Then a note: "For any frequency, the familiarization, or an abbreviated form of it, can be repeated." That note is the closest any standard comes to the 30/40 habit. |
| **ANSI S3.21-2004** (reaffirmed) | Paywalled. Its contents list has "Level of first presentation" and "Levels of succeeding presentations"; ASHA 2005 follows it. | Not readable. |

Textbooks repeat the same two numbers as familiarisation levels tied to the patient's expected hearing: Martin, Gelfand, Roeser and the Katz Handbook give ASHA's 30 dB HL ("unless prior knowledge of the examinee's hearing suggests otherwise", Katz); Stach gives 40 dB HL when normal or near-normal hearing is expected and about 60 dB when a mild loss is expected. Explicit later-frequency rules found in teaching material are relative: BSA and the Interacoustics Academy (30 dB above the adjacent threshold), the Open Access Guide to Audiology (start at the previous threshold, since neighbours rarely differ much), a VA contractor job aid (20 dB above the previous threshold). The Grason-Stadler training guide repeats familiarisation at every frequency, which is the closest thing to the habit as a written rule (see below).

### What the research says

- **No study tests a fixed start at every frequency against another rule** for accuracy, reliability or test time. Searches covered the classic method papers, method comparisons and automated-audiometry studies.
- **Marshall and Hanna (1986)**, a US Navy computer simulation (NSMRL Report 1081), modelled an ASHA-style start at a fixed 30 dB HL ("Each threshold determination began with the familiarization procedure"), which is the habit in simulated form. It needed the fewest trials when the true threshold was 10 to 25 dB HL: "A 1 trial increase per 10 dB in threshold value occurs for thresholds above 50 dB and below 10 dB. These results are due to the 30 dB starting level". They wrote that Carhart and Jerger's 30 dB SL start "would be more efficient than 30 dB HL" and that 20 dB SL would be more efficient still; for automated tests they proposed starting each frequency relative to the threshold just found.
- **Tyler and Wood (1980)** compared the whole BSA and ASHA manual methods at 1 kHz: "No significant differences among the three methods were found in their threshold estimates, standard deviations, number of false-positive responses, or subject preferences. The ASHA method took longer and required more tone presentations to establish a threshold."
- **Harris (1979)** and **Marshall and Hanna (1989)**: the stopping rule matters for time (2 responses is faster than 3, with about the same thresholds); neither looked at the starting level.
- **Carhart and Jerger (1959)**, the "modified Hughson-Westlake" paper, chose the ascending approach "to insure uniformity" after finding little difference between methods. Secondary accounts of its familiarisation level differ (about 30 dB HL if hearing seems normal, or 30 dB above threshold); the original could not be read.

### Where fixed starts are written down

Some automated systems and one manufacturer's training guide use a fixed first tone at every frequency, with no evidence offered for the choice:
- AMTAS (Margolis patent): the default "Level of the first stimulus presentation in a threshold determination" is 40 dB HL, and the method "is repeated for each E-selected stimulus".
- KUDUwave: "The initial intensity of each frequency was 30 dB HL" (Liu et al. 2022, Frontiers in Neuroscience).
- The Grason-Stadler training guide tells the tester to "Repeat the sections on Patient Familiarization and Threshold Determination for each tone setting", with familiarisation demonstrated "at 40 dB HL (or at a level estimated to evoke a prompt and clear response)" and the first threshold tone 10 dB below the response.

The NHANES III technician manual (1991) is sometimes quoted for this, but its 40 dB introduction is for "the first ear to be tested" only.

Other automated systems and apps start each later frequency a set amount above the previous threshold instead.

### What this means for Booth Camp

The game already allows the habit. It presets 1 kHz at 40 dB HL, recommends the previous threshold + 10 dB for each later frequency, and counts any first tone up to 70 dB HL as a clean start (`autoload/clinic_rules.gd` START_DB, MAX_START_DB; `core/audiometry_session.gd` recommended_start). Golf par is computed from the recommended start, so starting at 30 on an ear that needs 65 costs strokes, which matches the research: it is the slow route for a bigger loss, not a wrong one.

### Sources

- ASHA (2005). Guidelines for Manual Pure-Tone Threshold Audiometry. https://www.asha.org/policy/gl2005-00014/
- British Society of Audiology (2018). Recommended Procedure: Pure-tone air-conduction and bone-conduction threshold audiometry with and without masking. https://www.thebsa.org.uk/wp-content/uploads/2024/01/Recommended-Procedure-Pure-Tone-Audiometry-2018.pdf
- ISO 8253-1:2010, clause 6.2, from the EN ISO 8253-1:2010 sample at https://standards.iteh.ai/catalog/standards/cen/b5d6089a-99c2-4a78-9086-be7da495e999/en-iso-8253-1-2010 and the Russian adoption GOST R ISO 8253-1-2012 at https://files.stroyinf.ru/Data/540/54077.pdf
- ANSI/ASA S3.21-2004 preview (contents only). https://webstore.ansi.org/preview-pages/ASA/preview_ANSI+S3.21-2004.pdf
- Marshall L, Hanna TE (1986). NSMRL Report 1081. https://apps.dtic.mil/sti/tr/pdf/ADA173829.pdf
- Marshall L, Hanna TE (1989). Evaluation of stopping rules for audiological ascending test procedures using computer simulations. J Speech Hear Res 32(2):265. https://doi.org/10.1044/jshr.3202.265
- Tyler RS, Wood EJ (1980). A comparison of manual methods for measuring hearing levels. Audiology 19(4). https://doi.org/10.3109/00206098009072672
- Liu H, Du B, Liu B, Fu X, Wang Y (2022). Clinical comparison of two automated audiometry procedures. Front Neurosci 16:1011016. https://www.frontiersin.org/journals/neuroscience/articles/10.3389/fnins.2022.1011016/full
- Margolis RH. US Patent 6,496,585 (AMTAS). https://patents.google.com/patent/US6496585
- NHANES III Audiometry and Tympanometry Health Technicians' Manual (1991), section 3.3.1. https://stacks.cdc.gov/view/cdc/49885/cdc_49885_DS1.pdf
- Grason-Stadler, Pure Tone Audiometry guide. https://www.grason-stadler.com/guides/pure-tone-audiometry
- Interacoustics Academy, Pure-tone audiometry introduction. https://interacoustics.com/academy/audiometry-training/pure-tone-audiometry/pure-tone-audiometry-introduction
- Textbooks: Katz (ed.) Handbook of Clinical Audiology 6th/7th ed., ch. 3; Stach, Clinical Audiology 2nd ed., ch. 6; Martin, Introduction to Audiology; Roeser et al., Audiology: Diagnosis 2nd ed.; Gelfand, Essentials of Audiology.
