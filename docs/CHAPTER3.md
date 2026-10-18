# Booth Camp, Chapter 3 (Day 3): Mike Lenders, "SRT"

Design for the third playable day: the speech recognition threshold (SRT, ASHA's preferred term), the PTA/SRT
agreement check, and the signs of a non-organic loss. Shared speech rules and numbers: `docs/SPEECH.md`. API:
`CONTRACTS.md` §9. Days 1, 2 and 6-9 must not change. Steve reviews every number and every clinical line.

| | |
|---|---|
| Teaches | what PTA and SRT mean, spondees, familiarisation, SRT bracketing ("got it: down 10, missed: up 5", another word at the same level is fine, half right twice), scoring what the patient actually said, PTA/SRT agreement and its direction, signs of a non-organic loss (most aren't fibs), never accuse, recheck, objective tests and the doctor for a sudden loss |
| Length | 10-12 minutes with "quick visit" on (the default) |
| Opens | always (chapter select; `requires` = `bonnie` is only the "suggested next" hint) |
| New controls | the SPEECH screen: Space presents a word, Up / Down level, Right (or + / =) = repeated it, Left (or - ) = missed it, S stores the SRT; every control is a button too |
| Level scene | `res://story/level_mike.tscn` (`story/level_mike.gd`) |

---------------------------------------------------------------------------------------------

## 1. The patient

**Mike Lenders**, 41, forklift driver at a big warehouse. Hi-vis vest over a bowling shirt, a foam neck brace
"just in case", sunglasses pushed up on his head, a clipboard of forms from his cousin Vinnie. A big, hammy,
harmless show-off. Not a villain: the game never calls him a liar. His name plate on every line is plain "Mike
Lenders": no joke nickname about deafness, since Deaf and hard-of-hearing visitors play this at career fairs.

> "I can't hear ANYTHING since the forklift beeped at work. Not a THING."

Hoot whispers "Would you like a coffee, Mike?" and Mike answers "Two sugars, thanks." Then: "I mean... WHAT?"

Case history (two rounds of three choices, 2 / 1 / 0 points):

| Question | Points | Answer | Case note |
|---|---|---|---|
| When did it start, and how? | 2 | Tuesday. The forklift reversed, BEEP BEEP BEEP, then silence. Both ears. | Sudden, both ears, after a reversing beeper (Tuesday) |
| Any pain, dizziness or ringing? | 2 | No pain, no spinning, no ringing. Just... nothing. Total silence. | No pain, dizziness or tinnitus |
| What's your favourite forklift? | 0 | Old Rumbles, bay six. She's a beauty. Purrs like a kitten. | (joke) |
| Is the test for a work form? | 2 | My cousin Vinnie says you get paid leave for this. I mean: what form? | Wants a form for paid leave from work |
| How do you manage phone calls? | 1 | Fine, I just put it on speaker... I mean, I DON'T. Can't hear phones. | Nearly said he uses the phone on speaker |
| Have you tried switching your ears off and on again? | 0 | Is that a thing? Hang on. *wiggles ears* Nope. | (joke) |

Hoot, after the history: "Sudden loss in both ears is a red flag. A doctor needs to know fast, if it's real."
That sets the stakes: the clinic's job today is an accurate answer, not a gotcha.

## 2. Truth tables (`core/patients/mike.tres`)

**Voluntary tone thresholds** (what Mike chooses to answer, dB HL; the tone simulator uses these):

| Hz | 250 | 500 | 750 | 1k | 1.5k | 2k | 3k | 4k | 6k | 8k |
|---|---|---|---|---|---|---|---|---|---|---|
| right (O) | 65 | 70 | 70 | 70 | 70 | 75 | 75 | 75 | 70 | 70 |
| left (X) | 70 | 70 | 70 | 75 | 75 | 75 | 80 | 80 | 75 | 75 |

PTA (500/1k/2k): right 71.7, left 73.3, a "severe" flat loss on paper. No bone data (bone = air, no gap).

**Speech** (`speech` field): `srt` right 30, left 30; `half_words` 0.6 (most of his misses are half a word).
Agreement: 72 - 30 = 42 dB better, far past the 13 dB "poor" line. An SRT of 30 is an upper bound on his hearing
(he repeats words at least that soft), not his real hearing: only objective tests can say more.

His head: slope 2.0, attention 0.95, fatigue 0.0005, false alarms 0.1 / min (he is careful NOT to press),
reaction 0.8-1.5 s (dramatic pauses), rhythm sensitivity 0.3, tags non_organic, chapter_3. Pronoun he.

**What a textbook player sees** (checked in `core/tests/test_speech_core.gd`):

| | right | left |
|---|---|---|
| PTA from Hoot's tones | about 70 | about 75 |
| SRT start (PTA rounded + 15) | 85 | 90 |
| Words to bracket / par | 11 / 12 | 10 / 11 |
| Stored SRT | 30 (sometimes 25 or 35) | 30 |
| Agreement | poor (about 40 dB) | poor |
| Speech masking | not needed (85 - 40 = 45 is below his claimed left ear) | not needed |
| Hoot's 1 kHz retest | 15 dB better than his first 1 kHz (about 55 vs 70) | (right ear only) |

## 3. Beat by beat (about 11 minutes)

Every blocking beat emits `Events.awaiting_input`. "Hoot runs" = Hoot's turn at top speed (not scored).

| # | Phase (`phase_changed`) | What happens | Beat(s) | Time |
|---|---|---|---|---|
| 1 | `intro` | Mike swaggers in with his clipboard and neck brace. Hoot: "Day 3, trainee: speech! Today we check if words agree with the beeps." The coffee whisper gag. | dialogue | 0:50 |
| 2 | `history` | Two rounds (table above). Red-flag card: "Sudden, both ears: a doctor must know fast." Medal `history`. The flag is closed at beat 10 (his doctor hears about it). | choice | 1:20 |
| 3 | `otoscopy` | A quick look: canals clear, eardrums normal. Medal `otoscopy` gold. | dialogue | 0:20 |
| 4 | `instructions` | "Beeps AND words today." Pick: press for every beep, repeat every word, guess if unsure. Wrong picks: "only when you're sure" (too strict), "shout every word" (the gag). Medal `instructions`. | choice | 0:40 |
| 5 | `audiometry` {right, ac} / {left, ac} | Hoot pops the earphones on and runs both ears as a few-second montage each (`montage`, `skip_hoot_retest`, as on Day 2: the beeps aren't today's lesson). After the right ear he retests 1000 Hz, and it comes back 15 dB better than the first time (`LevelMike.RETEST_BETTER_DB`, from his measured 1 kHz result): "1000 Hz again: 55 dB, 15 better than before. Retests usually agree within 5 dB." Mike: "Must be the earphones warming up." (a test-retest mismatch, one more sign; the PTA keeps the first stamp, the retest goes on the record as `retest_1k`). "About 75 dB in both ears. Severe, on paper." The degree comes from `ClinicRules.degree_name` (at 70 it is "Moderately severe", and Mike says "Skip the 'moderately'."). Then Hoot defines the PTA. | (AudiOtron), dialogue | 0:40 |
| 6 | `familiarize` | Hoot's spondee line ("two-part words, equal stress on both parts, like rain-bow"). "Go through the word list with Mike first?" Yes = gold. Twelve word cards flip over on the clinician's side (a small "CLINICIAN'S SIDE: Mike can't see this" sign): Hoot says each word and Mike says it back by ear, never reading it. The player sees every word on the cards and on the "now saying" line (Hoot: "rainbow"  Mike: "Rainbow!"), with a tick per card; nothing depends on hearing. Mike repeats "Wind... mill?" and has never seen one, so the player drops that card ("Drop any word they don't know"). Then his SRT instructions: every test word comes from this list; say back what you hear, guess if unsure. Medal `familiarize`. | choice, dialogue, familiarize_cards | 0:50 |
| 7 | `speech` {right, srt} | Hoot defines the SRT, then the dance. The SPEECH screen, coached. PTA + 15 = 85. Mike repeats words all the way down to the 30s. The tell (once, on the screen): the first word scored as repeated 30 dB or more below the ear's PTA, "He's repeating words 40 dB below his beeps. Hmm!", with Hoot's hand on the agreement meter, then the coach's tip comes back. Half-word tip. Store at 30 (the coached ear never stores before a bracket). | (speech beats) | 2:30 |
| 7b | | The **agreement meter** swings: PTA 72, SRT 30, difference 42: **POOR**. The needle clunks into the red. Hoot: "SRT should sit within 6 dB of the PTA. His is 42 dB better. Poor agreement!" (the 6 is `SpeechRules.AGREE_GOOD_DB`; an SRT worse than the PTA gets the instructions / language / word scores / slope line instead). | | 0:15 |
| 7c | `speech` {right, srt} (recheck) | Only when the player's right SRT can't show the mismatch (not poor, not better than the PTA, or not stored at its bracket: `_srt_shows_mismatch`). Hoot says why ("That SRT didn't get a full bracket. I'll recheck the right ear by the book.", or "The bracket said N dB, not that one...") and reruns the right ear at 8x on a fresh session (plan `fresh_session`). The board uses his recheck; the player's own sheet stays for the grade. | (Hoot's turn) | 0:20 |
| 8 | `speech` {left, srt} | Solo: "Left ear: yours to the first miss and back up 5! PTA plus 15 is 90 dB." The player scores the descent from 90 (about eight words, down to his first miss below the SRT) and the word stepped up 5 after it, so they play every rule of the bracket alone; then Hoot takes over and finishes the bracket (quick visit; plan `hoot_turn_after_up`, with 12 words as the cap). Same story: poor agreement. | (speech beats) | 1:00 |
| 9 | `evidence` | **OBJECTION!** Mike's claim card "I can't hear ANYTHING" and three clues: "SRT 30 vs PTA 72" (or "Hoot's recheck: SRT 30 vs PTA 72"), "answered a whispered coffee offer", "canals clear". The captions stay neutral ("Two sugars, thanks." Hoot whispered it at the desk. / Otoscopy, both ears: clear canals, normal-looking eardrums.); the explanations come in the "why" after a wrong pick. The measurement is always the strongest clue; the whisper never outranks it. Medal `evidence`. | objection_present | 0:45 |
| 10 | `referral` | "What's next for Mike?" Fit strong hearing aids / **Re-instruct, retest, objective tests, tell his doctor** / Call him a fibber. Then the **RECHECK + OBJECTIVE TESTS + DOCTOR TODAY** stamp. Medal `referral`. | choice, referral_stamp | 0:45 |
| 11 | `results` | Mike owns up ("Cousin Vinnie said to say I can't hear, for paid leave. I can hear you fine."; the game never says his ears are fine: an SRT of 30 is an upper bound on his hearing, and the objective tests still follow). Hoot thanks him, then the main-path lesson: "Most non-organic losses aren't fibs: stress, worry, even a real loss underneath. So we never accuse." and "We'll still finish the objective tests and send your results to your doctor." He leaves; Hoot whispers "free donuts in the break room" and Mike yells "GLAZED?!" from the hall. The Daily Decibel, Day 3. | results_continue | 1:00 |

## 4. Teaching moments (Hoot, 18 words or fewer)

| Moment | Line |
|---|---|
| Purpose | "Day 3, trainee: speech! Today we check if words agree with the beeps." |
| Red flag | "Sudden loss in both ears is a red flag. A doctor needs to know fast, if it's real." |
| Instructions | "Beeps AND words today. Repeat every word you hear, and guess if you're not sure." |
| Retest | "1000 Hz again: 55 dB, 15 better than before. Retests usually agree within 5 dB." (his numbers; the 5 is `ClinicRules.RETEST_TOLERANCE_DB`) |
| After tones | "About 75 dB in both ears. Severe, on paper. Yet he heard my whisper..." (the degree from `ClinicRules`) |
| PTA | "That's his PTA, pure-tone average: his beeps at 500, 1000 and 2000 Hz, averaged." (with a best-two PTA: "his best two beeps of 500, 1000 and 2000 Hz, averaged.") |
| Spondees | "Spondees: two-part words, equal stress on both parts, like rain-bow. Chosen because they're equally easy to hear." |
| Familiarise | "Familiarise first, or you test his vocabulary, not his hearing." |
| By ear | "I'll say each word, nice and loud. You say it back. No peeking: the cards face me!" |
| Drop a word | "Never seen a windmill? Drop it. Only use words they know." |
| SRT instructions | "Every test word comes from this list, Mike. Say back what you hear, and guess if unsure." |
| SRT start | "Start at his PTA plus 15: 85 dB. He should repeat that easily." |
| SRT | "SRT, speech recognition threshold: the softest level where he repeats at least two words, half or more." |
| The dance | "Got it: down 10. Missed: up 5. Another word at the same level is fine too!" (the wrong-step tip: "...Another word here is fine too!") |
| Low start | "Starting low and coming up: smart when answers look exaggerated." (a first word at least 10 dB below the PTA, once the whisper has been on screen: `low_start_ok`) |
| Scoring | "Score what he SAID. Half a word, a different word, or silence: all misses." |
| SRT rule | "SRT: the softest level with two right and half or more. Check the trail!" |
| Bracket (coach) | "Bracketed! 30 dB: the softest level with half or more right. Press S to STORE." |
| The tell | "He's repeating words 40 dB below his beeps. Hmm!" |
| Half words | "Half a word is a miss. Lots of half-words can be a sign of a non-organic loss." |
| Agreement | "SRT should sit within 6 dB of the PTA. His is 42 dB better. Poor agreement!" |
| Agreement, worse | "Words worse than beeps? Think instructions, language, word scores or a sloping loss." |
| Recheck | "That SRT didn't get a full bracket. I'll recheck the right ear by the book." |
| No aids yet | "Not on results we can't trust. And a sudden loss sees a doctor before any hearing aid." |
| Never accuse (wrong pick) | "Never accuse! Non-organic loss has many causes. Stay kind and record the facts." |
| Next step | "Re-instruct, retest, objective tests that don't need his answers, and his doctor hears about the sudden loss today." |
| After the confession | "Thank you for telling us, Mike. That took guts." |
| Non-organic (main path) | "Most non-organic losses aren't fibs: stress, worry, even a real loss underneath. So we never accuse." |
| The doctor | "We'll still finish the objective tests and send your results to your doctor." |

**Non-organic, on the main path.** A player who answers everything well never sees the "Call him a fibber" reply,
so the term and its meaning come on the main path: the half-word tip names a non-organic loss, and right after
Mike's confession Hoot says most non-organic losses aren't fibs (stress, worry, even a real loss underneath) and
that we never accuse. The fibber branch keeps its short reminder. The game never teaches "non-organic = faking".

**The sudden loss.** The history's red flag ("A doctor needs to know fast, if it's real.") is closed on every path:
the next-step line, the stamp (+ DOCTOR TODAY) and the closing line send his results to his doctor, and the fit
rejection adds that a sudden loss sees a doctor before any hearing aid. A non-organic overlay can hide a real loss,
and a sudden loss is referred before any fitting.

Speech-screen tips (`SpeechSession.TIPS`): `srt_start`, `srt_wrong_step`, `srt_store_no_bracket`,
`srt_store_wrong_level`, `misscored`, `half_word`, `srt_low_start` (`docs/SPEECH.md` §8). Every Hoot line is 18
words or fewer (`story/tests/test_level_mike.gd::test_hoot_lines_fit`).

## 5. Fun moments

- **The coffee whisper.** Hoot whispers; Mike answers before he remembers he's "deaf".
- **The lie-detector needle.** The agreement meter on the SPEECH screen is a big analogue needle over
  green / amber / red. It wobbles while you test and clunks into the red when SRT and PTA disagree.
- **Half-word answers.** "...bow?", "Light...?" in Mike's bubble, with a wink chip. Score them as
  misses; Hoot explains why lots of them are a tell.
- **The descent.** Starting at 85, Mike keeps repeating words as the level falls through 70, 60, 50... the
  level digits turn from white to amber as he passes his own "threshold".
- **OBJECTION!** The board slams the stamp across Mike's claim card, with a screen shake (on the measurement:
  the player's SRT when it shows the mismatch, else Hoot's recheck).
- **The neck brace.** It has nothing to do with ears. Hoot: "...And the neck brace?" Mike: "Just in case."
- **GLAZED?!** The donut whisper on his way out.

## 6. Scoring additions

- Results: the tone sheets from Hoot's run (not scored) plus `speech.srt.right` and `speech.srt.left` (the
  player's own sheets, with `bracketed`; Hoot's recheck is kept apart for the board and never graded).
- Feedback after a store: praise ("ear done: nice work!", the golf name, the fanfare) only for a bracketed store;
  the Daily Decibel's C-grade subhead names the slip that actually happened (`SPEECH_C_SUBHEADS`), and its golf
  cell reads "no bracket" for an unbracketed store.
- Accuracy: `ClinicRules.accuracy_for_error(|stored SRT - true SRT|)`. Technique: every step and every score is
  a check. Efficiency: par / words. Golf per SRT (fair golf, like tones).
- Medals (Day 3 paper row): Chat (`history`), Explain (`instructions`), Words (`familiarize`), Case (`evidence`),
  Next (`referral`).

## 7. Open questions for Steve

1. SRT stepping: "down 10 / up 5" with "at least 2 right and half or more", or your clinic's routine (for example
   down 5 after each correct word, or 2-dB steps with the Tillman-Olsen arithmetic)? Another word at the same
   level is tolerated, after a hit or a miss, up to 4 words at a level per ear (`SRT_MAX_WORDS_PER_LEVEL`); the
   5th is a wrong step. Is 4 right?
2. Start level PTA + 15 (rounded) and the acceptable window PTA + 10..25. ASHA (1988) starts 30-40 dB above the
   estimated SRT, and allows an ascending start when pseudohypacusis (an exaggerated loss) is suspected. The game
   now scores an ascending start (a first word at least 10 dB below the PTA) clean once the whisper is on screen
   (`low_start_ok`); a start above PTA + 25 is
   still an error (`SRT_START_MAX_DB` waits for your answer).
3. Agreement bands 6 / 12 dB (good / fair / poor) with the 3-frequency PTA (best two when the three spread 20+).
4. Is the next step right: re-instruct, retest (an ascending retest?), objective tests that don't need his answers
   (the objective cross-checks: acoustic reflexes, OAEs, ABR / ASSR; a Stenger only for a one-sided claim, so not
   for Mike, who claims both ears), no aids on unreliable results,
   and a medical referral for the reported sudden loss (his doctor hears about it today)?
5. The tone of the case: kind, never accusing, with a jokey confession. OK for career-fair players?
