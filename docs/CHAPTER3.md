# Booth Camp, Chapter 3 (Day 3): Mike "Totally Deaf" Lenders, "SRT"

Design for the third playable day: speech reception threshold, the PTA/SRT agreement check, and catching a
non-organic loss. Shared speech rules and numbers: `docs/SPEECH.md`. API: `CONTRACTS.md` §9. Days 1 and 2 must not
change. Steve reviews every number and every clinical line.

| | |
|---|---|
| Teaches | spondees, familiarisation, SRT bracketing ("got it: down 10, missed: up 5", half right twice), scoring what the patient actually said, PTA/SRT agreement, signs of a non-organic loss, never accuse, recheck and refer for objective tests |
| Length | 10-12 minutes with "quick visit" on (the default) |
| Opens | always (chapter select; `requires` = `bonnie` is only the "suggested next" hint) |
| New controls | the SPEECH screen: Space presents a word, Up / Down level, Right (or + / =) = repeated it, Left (or - ) = missed it, S stores the SRT; every control is a button too |
| Level scene | `res://story/level_mike.tscn` (`story/level_mike.gd`) |

---------------------------------------------------------------------------------------------

## 1. The patient

**Mike "Totally Deaf" Lenders**, 41, forklift driver at a big warehouse. Hi-vis vest over a bowling shirt, a
foam neck brace "just in case", sunglasses pushed up on his head, a clipboard of forms from his cousin Vinnie.
A big, hammy, harmless show-off. Not a villain: the game never calls him a liar.

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
Agreement: 72 - 30 = 42 dB, far past the 13 dB "poor" line. His real ears are fine; his speech answers give it away.

His head: slope 2.0, attention 0.95, fatigue 0.0005, false alarms 0.1 / min (he is careful NOT to press),
reaction 0.8-1.5 s (dramatic pauses), rhythm sensitivity 0.3, tags non_organic, chapter_3. Pronoun he.

**What a textbook player sees** (checked in `core/tests/test_speech_core.gd`):

| | right | left |
|---|---|---|
| PTA from Hoot's tones | about 70 | about 75 |
| SRT start (PTA rounded + 15) | 85 | 90 |
| Words to bracket (par) | 10 | 11 |
| Stored SRT | 30 (sometimes 25 or 35) | 30 |
| Agreement | poor (about 40 dB) | poor |
| Speech masking | not needed (85 - 40 = 45 is below his claimed left ear) | not needed |

## 3. Beat by beat (about 11 minutes)

Every blocking beat emits `Events.awaiting_input`. "Hoot runs" = Hoot's turn at top speed (not scored).

| # | Phase (`phase_changed`) | What happens | Beat(s) | Time |
|---|---|---|---|---|
| 1 | `intro` | Mike swaggers in with his clipboard and neck brace. Hoot: "Day 3, trainee: speech! Today we check if words agree with the beeps." The coffee whisper gag. | dialogue | 0:50 |
| 2 | `history` | Two rounds (table above). Red-flag card: "Sudden, both ears: a doctor must know fast." Medal `history`. | choice | 1:20 |
| 3 | `otoscopy` | A quick look: canals clear, eardrums normal. Medal `otoscopy` gold. | dialogue | 0:20 |
| 4 | `instructions` | "Beeps AND words today." Pick: press for every beep, repeat every word, guess if unsure. Wrong picks: "only when you're sure" (too strict), "shout every word" (the gag). Medal `instructions`. | choice | 0:40 |
| 5 | `audiometry` {right, ac} / {left, ac} | Hoot pops the earphones on and runs both ears at top speed. "About 70 dB in both ears. Severe, on paper." | (AudiOtron) | 1:20 |
| 6 | `familiarize` | "Go through the word list with Mike first?" Yes = gold. Twelve word cards flip; Mike reads them; he has never seen a windmill, so that card is crossed out ("Drop any word they don't know"). Medal `familiarize`. | choice, dialogue | 0:50 |
| 7 | `speech` {right, srt} | The SPEECH screen, coached. PTA + 15 = 85. Mike repeats words all the way down to the 30s. Hoot (once): "He's repeating words 40 dB below his beeps. Hmm!" Half-word tip. Store at 30. | (speech beats) | 2:30 |
| 7b | | The **agreement meter** swings: PTA 72, SRT 30, difference 42: **POOR**. The needle clunks into the red. | | 0:15 |
| 8 | `speech` {left, srt} | Solo. Hoot takes over after 4 words (quick visit). Same story: poor agreement. | (speech beats) | 1:00 |
| 9 | `evidence` | **OBJECTION!** Mike's claim card "I can't hear ANYTHING" and three clues: "SRT 30 vs PTA 72", "answered a whispered coffee offer", "canals clear". Present the strongest (the SRT/PTA mismatch). Medal `evidence`. | objection_present | 0:45 |
| 10 | `referral` | "What's next for Mike?" Fit strong hearing aids / **Re-instruct, retest, refer for objective tests** / Call him a fibber. Then the **RECHECK + OBJECTIVE TESTS** stamp. Medal `referral`. | choice, referral_stamp | 0:45 |
| 11 | `results` | Mike owns up ("Cousin Vinnie said..."); Hoot: "Honest ears earn honest results." He leaves; Hoot whispers "free donuts in the break room" and Mike yells "GLAZED?!" from the hall. The Daily Decibel, Day 3. | results_continue | 1:00 |

## 4. Teaching moments (Hoot, 18 words or fewer)

| Moment | Line |
|---|---|
| Purpose | "Day 3, trainee: speech! Today we check if words agree with the beeps." |
| Red flag | "Sudden loss in both ears is a red flag. A doctor needs to know fast, if it's real." |
| Instructions | "Beeps AND words today. Repeat every word you hear, and guess if you're not sure." |
| After tones | "About 70 dB in both ears. Severe, on paper. Yet he heard my whisper..." |
| Spondees | "Spondees: two-part words like cup-cake. Easy to guess, so they find the softest level fast." |
| Familiarise | "Familiarise first, or you test his vocabulary, not his hearing." |
| Drop a word | "Never seen a windmill? Drop it. Only use words they know." |
| SRT start | "Start at his PTA plus 15: 85 dB. He should repeat that easily." |
| The dance | "Got it: down 10. Missed: up 5. Same dance as the beeps!" |
| Scoring | "Score what he SAID. Half a word, a different word, or silence: all misses." |
| SRT rule | "SRT: the softest level where he gets at least two words, half or more." |
| The tell | "He's repeating words 40 dB below his beeps. Hmm!" |
| Half words | "Half a word is a miss. Lots of half-words can be a sign of exaggerating." |
| Agreement | "SRT should sit within 6 dB of the PTA. His is 42 dB better. Poor agreement!" |
| Never accuse | "Never accuse! Non-organic loss has many causes. Stay kind and record the facts." |
| Next step | "Re-instruct, retest, and refer for objective tests that don't need his answers." |
| Takeaway | "Honest ears earn honest results. And SRT keeps everyone honest, including us." |

Speech-screen tips (`SpeechSession.TIPS`): `srt_start`, `srt_wrong_step`, `srt_store_no_bracket`,
`srt_store_wrong_level`, `misscored` (`docs/SPEECH.md` §8).

## 5. Fun moments

- **The coffee whisper.** Hoot whispers; Mike answers before he remembers he's "deaf".
- **The lie-detector needle.** The agreement meter on the SPEECH screen is a big analogue needle over
  green / amber / red. It wobbles while you test and clunks into the red when SRT and PTA disagree.
- **Half-word answers.** "...cake?", "Snow-... something?" in Mike's bubble, with a wink chip. Score them as
  misses; Hoot explains why lots of them are a tell.
- **The descent.** Starting at 85, Mike keeps repeating words as the level falls through 70, 60, 50... the
  level digits turn from white to amber as he passes his own "threshold".
- **OBJECTION!** The board slams the stamp across Mike's claim card, with a screen shake.
- **The neck brace.** It has nothing to do with ears. Hoot: "...And the neck brace?" Mike: "Just in case."
- **GLAZED?!** The donut whisper on his way out.

## 6. Scoring additions

- Results: the tone sheets from Hoot's run (not scored) plus `speech.srt.right` and `speech.srt.left`.
- Accuracy: `ClinicRules.accuracy_for_error(|stored SRT - true SRT|)`. Technique: every step and every score is
  a check. Efficiency: par / words. Golf per SRT (fair golf, like tones).
- Medals (Day 3 paper row): Chat (`history`), Explain (`instructions`), Words (`familiarize`), Case (`evidence`),
  Next (`referral`).

## 7. Open questions for Steve

1. SRT stepping: "down 10 / up 5" with "at least 2 right and half or more", or your clinic's routine (for example
   down 5 after each correct word, or 2-dB steps with the Tillman-Olsen arithmetic)?
2. Start level PTA + 15 (rounded) and the acceptable window PTA + 10..25.
3. Agreement bands 6 / 12 dB (good / fair / poor) with the 3-frequency PTA (best two when the three spread 20+).
4. Is the next step right: re-instruct, retest, objective tests (OAE / ABR), and no aids on unreliable results?
5. The tone of the case: kind, never accusing, with a jokey confession. OK for career-fair players?
