# Booth Camp: speech audiometry (Days 3-5)

The rules, numbers and data shapes shared by the three speech chapters:

| Day | Chapter id | Patient | Teaches | Design |
|---|---|---|---|---|
| 3 | `mike` | Mike Lenders | SRT (speech recognition threshold), PTA/SRT agreement, signs of a non-organic loss | `docs/CHAPTER3.md` |
| 4 | `nora` | Nora Nightingale | WRS, "hear through their ears", asymmetry, rollover, refer | `docs/CHAPTER4.md` |
| 5 | `marco` | Marco Polenta | the Party Noise Test (speech in babble), SNR loss, directional mics | `docs/CHAPTER5.md` |

Every clinical number below lives in `core/speech/speech_rules.gd` (`SpeechRules`). Change it there, not in a
copy. These are teaching defaults: Steve reviews every number before release. The API that the code follows is
`CONTRACTS.md` §9.

---------------------------------------------------------------------------------------------

## 1. Ground rules

- **Original material only.** Every list in `core/speech/material/*.json` was written for this game: no list,
  order or recording is copied; every word is checked against ASHA (1988) Appendices A-C and CID W-1. The guard
  in `core/tests/test_speech_core.gd` holds those four published spondee lists whole (ASHA Appendix A Table 1, B
  and C, and CID W-1) and fails on any match in any material list, ignoring case, spaces and hyphens. No CID W-22,
  NU-6, AB, BKB, HINT, IEEE or QuickSIN list, order or recording is used either. Word lists 1-4 (Day 4) were
  written fresh for the game: no word list, order or rhyme set comes from NU-6, W-22, CID W-1, PB-50, AB /
  Boothroyd, NU-CHIPS, WIPI or the Modified Rhyme Test, and their guard (`core/tests/test_speech_wrs.gd`) checks
  only our own lists (no repeats within or across lists, no reused rhyme set, the banned words, the structure of
  `CONTRACTS.md` §9.11). The repo never holds a published word list to compare with. The in-game test names are
  "Spondee list A", "Word list 1-4" and the "Party Noise Test"; real test names only appear in an educational
  "in real clinics" line, if ever.
- **Text first, audio later.** Every item plays as on-screen text: the clinician's word card shows the target,
  the patient's answer appears in a speech bubble, and the SPEECH lamp lights while it "plays". A quiet
  synthesized murmur stands in for the voice. Drop recordings in later (section 7) and they are used
  automatically.
- **Safety.** Speech and babble levels go through `AudioSafety` exactly like tones (about -75 dBFS at 0 dB HL,
  +0.6 dB per dB HL, never above -12 dBFS, babble RMS capped at the masker ceiling of -24 dBFS). Nothing is ever
  loud, and nothing depends on hearing it.
- **The patient's answers come from the simulator** (`SpeechSim`), never from the player's ears.

## 2. The pure-tone average (PTA)

- PTA = the mean of 500, 1000 and 2000 Hz (`SpeechRules.pta3`).
- When those three spread over 20 dB or more (`STEEP_RANGE_DB`), use the mean of the best two
  (`pta_best2`, the Fletcher average). `SpeechRules.pta_for_speech(thresholds)` picks the right one.
- Speech tests read the PTA from the tone test the clinic already ran (Hoot runs it at top speed on Days 3-5).

## 3. SRT: speech recognition threshold (Day 3)

ASHA's preferred term is *speech recognition threshold* (older texts say "speech reception threshold"). It is the
softest level at which the patient repeats **half** of a list of spondees: two-part words said with equal stress
on both parts ("rain-bow", "door-bell"), chosen because they are about equally easy to hear. It cross-checks the
tone audiogram.

| Rule | Value | Constant / function |
|---|---|---|
| Familiarise first | at a comfortable level, say each word for the patient to repeat (the list out of their sight: they learn the words by ear, not by reading); drop any word they don't know; then tell them every test word comes from this list | story beat |
| Better ear first | the ear with the lower PTA | `better_ear` |
| Start level | the PTA rounded to the nearest 5 dB, plus 15 | `SRT_START_ABOVE_PTA_DB` 15, `srt_start` |
| Acceptable first word | PTA + 10 to PTA + 25. A first word at least 10 dB below the PTA is an ascending start: clean (`srt_low_start`) when the plan sets `low_start_ok`. Anything else outside the window (including the dial's default at the PTA) is an `srt_start` error | `SRT_START_MIN_DB` 10, `SRT_START_MAX_DB` 25, `SRT_LOW_START_BELOW_PTA_DB` 10, `srt_start_ok`, `srt_start_low` |
| The dance | repeated it: **down 10** (down 5 is tolerated); missed it: **up 5** | `SRT_DOWN_DB` 10, `SRT_UP_DB` 5, `srt_next_level` |
| Same level again | another word at the same level is tolerated, after a hit or a miss, while fewer than 4 words were given at that level in this ear; the 5th word there is a wrong step | `SRT_MAX_WORDS_PER_LEVEL` 4, `srt_step_verdict(db, correct, next_db, words_here)` (`SpeechSession._check_step` counts the words) |
| SRT | the lowest level with **at least 2 words right and at least half right**, once the level **5 dB below** it was tried and scored under half | `SRT_MIN_CORRECT` 2, `srt_candidate` |
| Scoring | only the whole word counts: "Rain...?", "Train toe?" and silence are all wrong | `SpeechSession.score` |
| Agreement with PTA | difference 6 dB or less = **good** (a reliable SRT), 7-12 = **fair**, 13 or more = **poor** | `AGREE_GOOD_DB` 6, `AGREE_FAIR_DB` 12, `agreement` |
| Direction | SRT - PTA. An SRT much **better** than the PTA points to a non-organic loss: re-instruct and recheck. A **worse** one points to the instructions, language or word recognition (a sloping loss is not a reason: a steep slope can make words a little better than the three-tone average, so the PTA then uses the best two). Hoot's line after a store depends on both | `srt_pta_diff`, `SpeechSession.agreement_tip(agreement, diff)` (`AGREEMENT_TIPS` keys `good`, `fair_better`, `fair_worse`, `poor_better`, `poor_worse`) |
| Speech masking | needed when the level minus 40 (phones) reaches the other ear's lowest bone, masked or unmasked (or air, see below) | `speech_masking_needed` |
| Speech masking level | presentation level minus 20, plus the other ear's largest air-bone gap at 500-4000 Hz (0 when no bone was measured) | `SPEECH_MASK_BELOW_DB` 20, `speech_mask_level(level, nontest_abg)`, `nontest_largest_abg` |
| Par | the words a textbook dance takes from the first word's level on a perfectly steady patient, plus 1 (from 85 to an SRT of 30: 11 + 1) | `srt_textbook_words`, `SRT_PAR_SLACK` 1, `srt_par` |

Teaching line: **"Got it: down 10. Missed: up 5. Another word here is fine too!"** (the `srt_wrong_step` tip) and
**"SRT, speech recognition threshold: the softest level where he repeats at least two words, half or more."** It
is close to the dance of the tones on purpose ("got it twice at 30, missed at 25: SRT 30"). A second word at the
same level is how a level is confirmed (ASHA presents a second word at a level too), so the game allows up
to `SRT_MAX_WORDS_PER_LEVEL` words there before it calls the step wrong.

**Speech masking without bone.** Both masking rules read the other ear's bone from the tone results the
session already has, but not the same way. The need rule (`nontest_best_threshold`) takes the other ear's
lowest bone at 500-4000 Hz, masked or unmasked: a safe lower bound, like `ClinicRules.nontest_bone_estimate`.
The noise level (`nontest_largest_abg`) reads `best_thresholds`, so masked bone replaces unmasked bone where
measured when it works out the air-bone gap. Without bone results both rules use air only: the other
ear's best air stands in for its bone, and no air-bone gap is added to the speech noise. That is a temporary
stand-in (Hoot runs air only on Day 3, and Mike has no gap, so his numbers are the same either way); tone
results with bone sheets bring the gap in with no code change.

**Where the search starts.** ASHA (1988) starts 30-40 dB above the estimated SRT, and allows an ascending
start (from below, coming up) when an exaggerated loss (pseudohypacusis) is suspected. The game's
PTA + 15, with PTA + 10..25 accepted, is a shorter teaching default that Steve reviews (CHAPTER3.md §7 Q2;
`SRT_START_MAX_DB` stays until he answers). The plan key `low_start_ok` turns the ascending start on: Day 3 sets
it once Hoot's coffee whisper has been on screen (never from the hidden `non_organic` tag), and a first word
at least 10 dB below the PTA (`SRT_LOW_START_BELOW_PTA_DB`) then scores clean with Hoot's *"Starting below his
beeps: smart when answers look exaggerated."* (true for any such start: Mike may still repeat a first word at 60,
and then the next step is down, not up). The dial's default (the PTA itself) is not an ascending start, so
presenting straight away is still an `srt_start` error.

**On the SPEECH screen.** The sheet's `bracketed` key (stored at the bracketed SRT) decides the praise: "ear done:
nice work!", the golf callout (a clean run over par reads "Clean!", never "Par!") and the fanfare only follow a
bracketed store; an unbracketed one reads "stored before a bracket" or "the bracket said N dB" and "Oops!". On the
coached ear STORE before a bracket only warns (never "store anyway"), and the coach's bracket tip reads
*"Bracketed! N dB: the softest level with half or more right. Press S to STORE."* Plan `fresh_session` runs one
ear on a new session (Hoot's recheck on Day 3); the player's session and sheets come back on the next ear.

**The patient model.** Each word is repeated correctly with probability
`logistic((level - (SRT_true - SRT_BIAS_DB)) / SRT_SLOPE_DB)`, `SRT_SLOPE_DB` 2.0, `SRT_BIAS_DB` 3 (so a textbook
search stores the true SRT about two times in three and 5 dB either side otherwise, like
`PatientSim.THRESHOLD_BIAS_DB` for tones; checked over 4000 simulated searches). The true SRT of an ear is
`speech.srt[ear]` when the profile gives one, else the PTA of its true thresholds rounded to 5 dB plus
`speech.srt_offset[ear]` (0 when the words agree with the tones). A miss is one of: silence ("Huh?"), half the
word ("...bow?") or a wrong word (another spondee, or the word's own funny mishear, asked once: "Train toe?").
The share of half-word misses is `speech.half_words` (0.15 by default; a non-organic patient gives many more).

**Non-organic loss (Mike).** His voluntary tone thresholds sit around 70 dB, so his PTA is about 70, but he
repeats spondees at about 30. Hoot's 1 kHz retest also comes back 15 dB better than the first (a retest should
agree within 5 dB): poor test-retest reliability is another sign. An SRT 13 dB or more better than the PTA is
"poor agreement" in the direction of a non-organic loss: re-instruct, retest, and refer for objective tests that
don't need his answers (acoustic reflexes, OAEs, ABR / ASSR; a Stenger only for a one-sided claim, and Mike claims
both ears). An SRT of 30 is an upper bound on his hearing, not his real hearing. Never accuse: most non-organic
losses aren't fibs (stress, worry, even a real loss underneath), and the clinic's job is an accurate record. A
reported sudden loss still goes to a doctor before any hearing aid.

## 4. WRS: word recognition score (Day 4)

One-syllable words at a level **loud enough for every sound, never uncomfortable** (the game's rule: PTA + 35, at
least 55). The score is the percentage repeated correctly: when speech is loud enough, how clearly does it come
through? The design is `docs/CHAPTER4.md`; the API is `CONTRACTS.md` §9.10-§9.24. The clinical review's amendments
(A1-A4, `docs/CLINICAL_REVIEW.md`) are the rules below: the predicted minimum, the rollover index, the critical
difference and the noise's air-bone gap.

| Rule | Value | Constant / function |
|---|---|---|
| Level | PTA + 35 rounded to 5 dB, at least 55 dB HL (PTA 15: 55; PTA 40: 75) | `WRS_ABOVE_PTA_DB` 35, `WRS_MIN_DB` 55, `wrs_level` |
| Acceptable level | PTA + 30 to PTA + 40, at least 50, always holding the textbook level (PTA 15: 50-60; PTA 40: 70-80) | `WRS_WINDOW_DB` 5, `WRS_MIN_OK_DB` 50, `wrs_level_ok`, `wrs_window` |
| One level, one noise | the level and the noise lock at a list's first word; a word score belongs to a single level | `WrsTest.can_set_level`, `can_mask` |
| List | 25 words, each worth 4 %, played in file order; a list id is used once a visit, and each ear's lists come in play order (`words_1`, `words_2`, then `words_3`, `words_4`) | `WRS_WORDS` 25, `WRS_LISTS` |
| No STORE | the list ends itself after its 25th score | |
| Scoring | whole word only: a rhyme ("lock" for "sock"), a plural ("Socks?"), another word and silence are misses; the word inside a chatty line ("Sock! Like a good downbeat.") and a self-correction's final answer ("Lock... no, SOCK!") are hits | `WrsTest.score`, `WRS_SELF_CORRECT_COUNTS` |
| Bands | 90+ excellent, 78-89 good, 66-77 fair, 54-65 poor, below 54 very poor | `WRS_BANDS`, `wrs_band`, `WRS_BAND_TITLES` |
| Counting | a list counts when it started inside the window, with noise exactly when the rule needs it (a louder list: also 15-25 dB above its comfortable list), and no later list redoes it. Only counted lists give the ear's score and its flags | the list's `counts`, `redone_by` |
| (A1) Worse than the audiogram predicts | the ear's best score is below the minimum its PTA predicts, interpolated between the rows PTA 0: 88, 20: 80, 30: 72, 40: 60, 50: 48, 60: 36, 70: 24, 80: 12 and clamped outside them (a game approximation of the published 95 % lower limits for 25 words, anchored on 48 % at a PTA of 50; Steve checks it). Lines and the paper say "her tones predict at least {min}%" and never credit a number to a paper | `WRS_PREDICTED_MIN_25`, `wrs_predicted_min_interp` (15 -> 82, 40 -> 60, 41.7 -> 58) |
| (A2) Rollover | one extra list 20 dB louder on the poorer ear. PBmax is the ear's best counted score; PBmin the lowest counted score at a level ABOVE PBmax's (none: no rollover; a lower score at a softer level never counts); rollover when the index (PBmax - PBmin) / PBmax is 0.45 or more. A 20-point drop is NOT the rule: 52 then 40 is an index of 0.23, no rollover; 52 then 12 is 0.77 | `ROLLOVER_INDEX_CUTOFF` 0.45, `wrs_rollover(lists)`, `rollover_index_of` |
| The louder list | 20 dB above the counted comfortable list (15-25 accepted), never past 100; its noise stays on, locked | `WRS_LOUDER_DB` 20, `WRS_LOUDER_TOLERANCE_DB` 5, `wrs_louder_level`, `wrs_louder_ok` |
| (A3) Ear difference | the two ears' best scores are too far apart for chance on lists that long: with theta = 2 asin(sqrt(p)), they differ when the thetas are more than 1.96 x sqrt(1/n_a + 1/n_b) apart (the 95 % critical difference of Thornton & Raffin, 1978). On 25 words a 44 % score is the same as 20-68 % and differs from 16 and 72; 96 vs 52 differ, 96 vs 88 and 52 vs 40 do not | `WRS_CRIT_Z` 1.96, `wrs_differ`, `wrs_same_range` |
| The verdicts wait for the best | "below predicted" and the ear difference use the ear's best and are said only once it is final: its louder list is done, or the comfortable score already reaches the prediction. The ear difference needs both ears final | the sheet's `best_final` (D13) |
| Speech masking (need) | needed when the level - IA (40 phones, 55 inserts) reaches the other ear's best bone, taken per frequency over 500-4000 Hz: masked bone, else unmasked bone, else air (an unmasked bone value never stands in for an ear it was not measuring) | `SPEECH_IA_DB`, `ear_best_bone`, `nontest_best_bone`, `speech_masking_needed` |
| (A4) Speech masking (level) | level - 20 plus the other ear's largest air-bone gap at 500-4000 Hz, clamped to [level - IA, the test ear's best bone + IA - 5], so it covers the crossed words and never crosses back to the test ear. The ceiling wins when the two meet. Hoot names a capped noise ("Noise 70, not 75: ...") | `wrs_mask_level(level, test_best_bone, transducer, nontest_abg)`, `wrs_mask_capped`, `nontest_largest_abg` |
| The referral | refer (a doctor's check soon, before any fitting) when the ears differ beyond chance, rollover is found, or exactly one ear is below its prediction. Word scores alone never mean a doctor today | `wrs_referral` (D27), `speech.wrs_summary.referral` |
| Chat level | the dial's "chatting level" mark, where the tea demo plays | `CHAT_DB` 50 |

The SRT rules (section 3) keep their own masking need (`nontest_best_threshold`), so Day 3 is unchanged. Day 3's
older WRS helpers stay in `SpeechRules` for Day 3's tests only, and no day grades with them: `WRS_ASYMMETRY_PCT` and
`wrs_asymmetric` (a fixed 20 points), `WRS_PREDICTED_MIN` and `wrs_predicted_min` (the old step table),
`ROLLOVER_DROP_PCT`, `is_rollover` and `rollover_index` (a raw drop), and `wrs_below_predicted`.

**The patient model** (`core/speech/models/wrs_model.gd`, behind `SpeechSim`'s WRS facade). At level L an ear's
chance of repeating a word is

```
p_test  = wrs_max x A(L, srt_eff) - rollover_drop(L)        srt_eff = max(SRT, noise - real IA)
p_cross = the same for the other cochlea at L - real IA      0 once the noise reaches that crossed level
p       = 1 - (1 - p_test) x (1 - p_cross)
```

- `A(L, srt) = logistic((L - (srt + 12)) / 5)` is the whole word's audibility (`wrs_audibility`,
  `WRS_AUDIBLE_ABOVE_SRT_DB` 12, `WRS_AUDIBLE_SLOPE_DB` 5). `wrs_max` is `speech.wrs_max[ear]`, else predicted from the
  true audiogram (`predicted_wrs_max`). `rollover_drop` comes from `speech.rollover[ear] = {after, drop_per_10db}`:
  `max(0, L - after) / 10 x drop_per_10db %` (Nora: after 75, 20 per 10 dB, so 0.40 at 95).
- The noise term in `srt_eff` only matters for overmasking (noise loud enough to cross back to the test ear).
- **The deal.** A list is dealt whole at its first word (D4): `k = round(p x 25) + j`, one `j` from [-1, 0, 0, +1] per
  list (`WRS_DEAL_JITTER`, `wrs_deal_count`), for the test ear alone and for either ear. So a clean list lands on the
  patient's real score give or take one word, and a seed replays it exactly.
- **Which words are missed** follows the **speech banana**: each word's key sound (the one its rhymes differ in) has a
  frequency and a level below the overall speech level (`SOUND_CUES`). A cochlear ear misses first the words whose
  key sound sits lowest under its TRUE thresholds (`wrs_miss_weight`: `WRS_MISS_SCALE_DB` 4, floor `WRS_MISS_FLOOR`
  0.05), so a high-pitch loss loses s, f and th words first. A `speech.neural[ear]` ear misses at random, whatever the
  audiogram says: she can miss a word whose every sound reached her.
- **What she says on a miss.** A cochlear miss is a rhyme (a foil, 80 %) or silence (20 %); a neural miss is a foil
  (60 %), silence (25 %) or another word of the list (15 %) (`WRS_MISS_COCHLEAR`, `WRS_MISS_NEURAL`). A word that is
  too soft gets more silences.
- **Answer styles** (D20, the player's words only; they change what she says, never the deal or the score): a
  chatty hit, about 1 hit in 3 (`WRS_CHATTY_SHARE` 0.33): the word, then a short line of `WRS_CHATTY_MAX_WORDS` 6 or
  fewer; a plural trap once per list on the first dealt miss that has a plural ("Socks?": a miss); a self-correction
  once on a plan that asks for it ("Lock... no, SOCK!": a hit).
- **Plan helpers.** `ensure_audible_miss_by` puts one dealt miss on a fully audible word in the first places (on the
  measured thresholds the lens uses; `audible_target`), and `aside_by` lands an item's in-joke foil as a miss
  (`aside_target`, never the audible word). Neither changes the count.

**Hearing through the patient's ears (the lens).** "<NAME>-VISION" draws each spelling chunk of the next word at
`lens_alpha(margin) = lerp(1.0, 0.15, clamp(-margin / 15, 0, 1))` (`LENS_FADE_DB` 15, `LENS_MIN_ALPHA` 0.15), where the
margin is `sound_margin(sound, dial, measured thresholds)`: below 0 the sound is lost (dotted outline), 0 to 3 dB
"only just" (dotted underline), 3 dB or more clear (`WRS_AUDIBLE_MARGIN_DB` 3, `word_min_margin`,
`word_fully_audible`). It reads the MEASURED thresholds (interpolated, `interp_threshold`), never the truth, so it
shows only what the player could know, and it never hides the only copy of the word.

**The Ghost on the SPEECH screen.** On a coached list that needs noise with the noise off, the Ghost lurks at
`ghost_alpha = clamp(0.2 + (level - IA - other ear's best bone) / 25, 0.2, 1)` (`GHOST_ALPHA_FLOOR` 0.2,
`GHOST_ALPHA_SPAN_DB` 25): faint from the first level that needs noise, bold 20 dB above it (Nora's left: 50, then
70), and 0 where words cannot cross. On a solo list it never
lurks; it pops out ("BOO!") only when the player presents unmasked, with a two-press confirm.

**Golf and the sheets.** Each list the player runs is a golf hole (section 6): a clean solo list set up unprompted is
a birdie (`LIST_TEE_BONUS` 2), a clean coached list is par, a confirmed wrong set-up adds `LIST_CONFIRM_SLIP` 3. One
sheet per ear (`speech.wrs.<ear>`) holds every list on that ear (the comfortable list, a redo, the louder list), and
`speech.wrs_summary` holds the bests, the flags and the referral (`CONTRACTS.md` §9.15).

## 5. The Party Noise Test: speech in babble (Day 5)

Sentences from one talker in four-talker babble. Each list has **6 sentences with 5 key words**; the babble
rises one step per sentence from **25 dB SNR** (easy) to **0 dB** (as loud as the talker).

| Rule | Value | Constant / function |
|---|---|---|
| Level | 70 dB HL when PTA is 45 or less, else "loud but OK" (PTA + 25, at most 90) | `SIN_LEVEL_DB` 70, `sin_level` |
| SNRs | 25, 20, 15, 10, 5, 0 dB | `SIN_SNRS` |
| Score | key words right, 0-5 per sentence, 0-30 per list | |
| **SNR loss** | **25.5 - total key words right** (per list, then averaged) | `SIN_CONSTANT` 25.5, `snr_loss` |
| Bands | 0-3 normal / near normal; over 3-7 mild; over 7-15 moderate; over 15 severe | `SIN_BANDS`, `sin_band` |
| What helps | normal: nothing new; mild: hearing aids; moderate: directional microphones; severe: a remote microphone | `SIN_HELP` |
| Lists | average 2 or more: one list is a guess, two are evidence. Critical difference 3.9 dB (1 vs 1 list), 2.7 dB (2 vs 2) | `SIN_CRIT_DIFF_DB` |

**The patient model.** A key word at SNR s is right with probability `logistic((s - SNR50) / SIN_SLOPE_DB)`,
`SNR50 = SIN_NORMAL_SNR50_DB (2) + snr_loss`, `SIN_SLOPE_DB` 2.2. Each sentence's count is the expected number
give or take one, so two clean lists land within about 1 dB of the patient's SNR loss (`speech.snr_loss`,
otherwise estimated from the audiogram). Directional microphones (aided, Day 5's payoff) improve it by
`speech.directional_benefit` (4 dB by default).

## 6. Shared scoring

The same rules for all three tests (`CONTRACTS.md` §9.5 and §9.15).

- **Sheets and slots.** Every speech measurement is a **sheet** in the results: `speech.srt`, `speech.wrs` and
  `speech.sin`, one sheet per **slot**. SRT and word-list slots are the ears; party slots are `"both"`,
  `"aided_omni"` and `"aided_directional"` (or an ear, for a one-ear unaided test). A word-list or party sheet
  holds every list run on its slot in `lists` (the comfortable list, a redo and the louder list on one ear; the
  two lists of a party condition). Every sheet carries `stored_db` and `true_db`, so the "within 10 dB of the
  truth" check works for all three tests.
- **Units.** A sheet weighs its `units` in the visit: the counted lists the player ran on that slot (an SRT sheet
  is 1). A redone list, a list Hoot ran and a sheet Hoot ran off-screen count 0. `scored_sheets` is the sum of the
  units, and `merge_results` weighs each unit like `SHEET_WEIGHT` (3) tone stamps.
- **Accuracy**: SRT = `ClinicRules.accuracy_for_error(|stored - true|)`; word and party lists = the share of the
  player's items scored the way the patient actually answered (`matches / player items`). A wrong set-up costs
  technique and golf, not accuracy. A sheet's accuracy counts once per unit.
- **Technique**: every verdict is a check (a textbook step, a correct score, the right level, the noise when it
  is needed); slips break the combo (section 8).
- **Efficiency**: par / presentations. The SRT is a search: par is `srt_par`. Word and party lists are fixed (25
  words, 6 sentences a list), so a sheet's `strokes` and `par` are both the player's presentations and efficiency
  is 1.0 (a list cannot be cut short; a wrong set-up costs a new list, which technique and golf count).
- **Golf**, one hole per measurement:
  - SRT: one hole per ear, the player's words against `srt_par` (`ClinicRules.fair_golf`; a slip or an SRT
    stored off its bracket gets no golf name).
  - Word and party lists: each list the player runs is a hole. `golf_par` = the player's words or sentences;
    `slips` = the misscored items (a word list confirmed wrong adds `LIST_CONFIRM_SLIP` 3);
    `tee_bonus = LIST_TEE_BONUS` (2) only for a solo list whose set-up the player made unprompted (a party level
    Hoot set never earns it); `golf_strokes = golf_par + slips - tee_bonus`; `golf = fair_golf(golf_strokes,
    golf_par, slips == 0)`. A perfect solo list is a birdie, a clean coached list is par, and lists have no
    eagles. The sheet's `golf` is its newest player list's; `holes` keeps every list's. A list with no player
    items is `&"hoot"`.
- **Hoot's work is never scored**: his words, sentences and off-screen lists stay out of accuracy, units and golf.
- The visit's accuracy, technique and efficiency average the scored speech measurements (by units) together with
  any scored tone stamps (Hoot runs the tones on speech days, so usually none).
- Word lists add `speech.wrs_summary` (best scores, the flags and the referral) and party lists
  `speech.sin_summary` (the band, the aided benefit and whether it is a real change): `CONTRACTS.md` §9.15.3.

## 7. Recordings (later)

Drop files at `assets/speech/<list_id>/<item_id>.wav` (16-bit PCM, mono, any rate; 8-bit and stereo work too).
WAV only: the voice decodes it into the test ear's channel, which a streamed `.ogg` could not do, and
`project.godot` imports WAVs uncompressed (`[importer_defaults]` wav `compress/mode` 0: a global, project-wide default,
so it applies to every WAV in the project, not only speech). For sentences, `<item_id>` is the sentence id (e.g. `p1_3`).
`SpeechVoice` uses a recording when it exists and the synthesized murmur otherwise. A recording is scaled to the
same safe level as the murmur, measured over its speech (20 ms windows within 35 dB of the loudest), so silence
and room noise don't make it louder, and clamped sample by sample. Babble for the party test can be dropped
in as `assets/speech/babble/babble.wav` (four voices reading unrelated text). The game stays fully playable
without any of it.

## 8. Speech technique kinds (`Events.technique_event`, data has `ear`, `freq` -1, `test`)

| kind | when |
|---|---|
| `srt_start` | the first SRT word is outside PTA + 10..25 (at least 10 dB below the PTA is clean with plan `low_start_ok`) |
| `srt_wrong_step` | not "got it = down 10 (or 5), missed = up 5", nor another word at the same level (up to 4 there) |
| `srt_store_no_bracket` | stored with no level below scoring under half |
| `srt_store_wrong_level` | stored a level that is not the lowest one with 2+ right and half or more |
| `misscored` | the player scored a word or key word differently from what the patient said |
| `wrs_level` | the first word of a comfortable word list is outside the window (`wrs_level_ok`) |
| `rollover_level` | the first word of a louder word list is not 15-25 dB above its comfortable list (or past 100) |
| `wrs_unmasked` | a word list's first word goes out with no noise in the other ear when the rule needs it |
| `sin_level` | the party test is not at its level |
| `speech_textbook` | a by-the-book step or score (combo +1) |
| `srt_low_start` | clean: a first word at least 10 dB below the PTA with plan `low_start_ok` (combo +1, 10 points, Hoot's line in `message`) |
| `wrs_good_start` | clean: a word list's first word inside its window (a louder list: 15-25 dB above the comfortable one; combo +1, 10 points) |
| `wrs_mask_ok` | clean: the noise was on before the first word of a list that needs it (combo +1, 20 points) |
| `srt_stored` / `wrs_done` / `sin_done` | observations at the end of a measurement |
| `half_word` | the patient gave half a word ("Lots of half-words can be a sign of a non-organic loss.") |
| `cross_heard_speech` | unmasked: the other ear repeated the word |
| `wrs_verdict` | a word list made the ear's best final: `below_predicted` or `best_ok`, plus the ear difference when it is new (`lines`) |
| `wrs_below_predicted` | the ear's final best is below its predicted minimum (A1) |
| `wrs_asymmetry` | both ears' bests are final and too far apart for chance (A3) |
| `rollover_found` | the louder list made the ear's rollover index reach 0.45 (A2) |
| `wrs_mask_capped` | the word-list noise was clamped to the test ear's ceiling (`mask`, `naive`) |
| `ghost_lurk` / `boo` | the lurking Ghost showed on a coached list / the BOO chip on an unmasked solo PRESENT (once per list) |
| `ghost_word` | a word list's word was answered by the other cochlea (once per list; `cross_heard_speech` once per ear) |
| `audible_miss` | plan `audible_stamp`: a word whose every sound reached the patient was missed (once per list) |
| `wrs_level_locked` / `wrs_noise_locked` | the player tried to change the level or the noise after a list's first word |
| `wrs_no_store` / `wrs_list_reused` / `score_first` | STORE on a word list; a list id used twice in a visit (refused); PRESENT before the last word was scored |
| `call_it` | a Call it guess (`word`, `guess`, `outcome`, `moment`): unscored |
| `aside` | a non-blocking side line (an item's in-joke, the noise, the lens, the loud list), once per visit |
| `birdie` / `par` / `bogey` ... | a finished player word list's golf name (`ClinicRules.fair_golf`; no eagles on lists) (`golf_strokes`, `golf_par`, `slips`, `tee_bonus`, `points`) |

Each error, and `srt_low_start`, carries a Hoot `message` of 18 words or fewer (`SpeechSession.TIPS`). The word-list
kinds take theirs from `WrsTest.TIPS`, `MISSCORED_WRS` (a misscore, by what the patient said) and `VERDICTS`
(`wrs_done` and the verdicts); their data adds `list_id` and `list_n`. The word-list errors and verdicts are
Day 4's only (`CONTRACTS.md` §9.13.6).
