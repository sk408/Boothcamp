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
  NU-6, AB, BKB, HINT, IEEE or QuickSIN list, order or recording is used either. The in-game test names are
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

One-syllable words at a **comfortably loud** level. The score is the percentage repeated correctly: when speech
is loud enough, how clearly does it come through?

| Rule | Value | Constant / function |
|---|---|---|
| Level | PTA + 35 rounded to 5 dB, at least 55 dB HL | `WRS_ABOVE_PTA_DB` 35, `WRS_MIN_DB` 55, `wrs_level` |
| Acceptable level | PTA + 30 to PTA + 40 (at least 50) | `wrs_level_ok` |
| List | 25 words, each worth 4 % | `WRS_WORDS` 25 |
| Scoring | whole word only; a rhyme ("heap" for "sheep") is wrong | `SpeechSession.score` |
| Bands | 90+ excellent, 78-89 good, 66-77 fair, 54-65 poor, below 54 very poor | `WRS_BANDS`, `wrs_band` |
| Ear difference | 20 % or more between ears is a red flag | `WRS_ASYMMETRY_PCT` 20 |
| Worse than the audiogram predicts | below the minimum the PTA predicts (PTA 25 or less: 88; 40: 76; 55: 64; 70: 48) | `WRS_PREDICTED_MIN`, `wrs_below_predicted` |
| Rollover | 20 dB louder scores 20 points or more lower (rollover index 0.25 or more) | `ROLLOVER_STEP_DB` 20, `ROLLOVER_DROP_PCT` 20, `rollover_index` |
| Speech masking | as SRT (level - 40 reaches the other ear's bone: speech noise at level - 20 plus that ear's largest air-bone gap) | `speech_masking_needed`, `speech_mask_level` |

**The patient model.** At level L, an ear repeats a fraction `p(L) = wrs_max x A(L) - rollover(L)` of the words:
`A(L) = logistic((L - (SRT_true + 12)) / 5)` (audibility of the whole word), `wrs_max` from `speech.wrs_max[ear]`
or predicted from the audiogram, rollover from `speech.rollover[ear] = {after, drop_per_10db}`. The number right in a
list is `round(p x N)` give or take one, so a clean test lands on the patient's real score. Which words are missed
follows the **speech banana**: each word's key sound (the one its rhymes differ in) has a frequency and a level
below the overall speech level (`SOUND_CUES`), and words whose key sound falls below the patient's threshold
are missed first (a high-frequency loss loses s, f, th, t and k first: "sit" becomes "fit"). A
`speech.neural[ear]` ear smears words at random instead, whatever the audiogram says.

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
| `wrs_level` | the first word of a list is outside the comfortable window |
| `sin_level` | the party test is not at its level |
| `speech_textbook` | a by-the-book step or score (combo +1) |
| `srt_low_start` | clean: a first word at least 10 dB below the PTA with plan `low_start_ok` (combo +1, 10 points, Hoot's line in `message`) |
| `srt_stored` / `wrs_done` / `sin_done` | observations at the end of a measurement |
| `half_word` | the patient gave half a word ("Lots of half-words can be a sign of a non-organic loss.") |
| `cross_heard_speech` | unmasked: the other ear repeated the word |

Each error, and `srt_low_start`, carries a Hoot `message` of 18 words or fewer (`SpeechSession.TIPS`).
