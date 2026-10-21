# Booth Camp, Chapter 3 (Day 3): Mike Lenders, "SRT"

Design for the third playable day: the speech recognition threshold (SRT, ASHA's preferred term), the PTA/SRT
agreement check, and the signs of a non-organic loss. Shared speech rules and numbers: `docs/SPEECH.md`. API:
`CONTRACTS.md` §9. Days 1, 2 and 6-9 must not change. Steve reviews every number and every clinical line.

| | |
|---|---|
| Teaches | what PTA and SRT mean, spondees, familiarisation, the better ear first, SRT bracketing ("got it: down 10, missed: up 5", one common way, not the only one; another word at the same level is fine, half right twice), scoring what the patient actually said, PTA/SRT agreement and its direction, signs of a non-organic loss (many causes, and the booth can't tell which), never accuse, recheck, objective tests and the doctor for a sudden loss |
| Length | 10-12 minutes with "quick visit" on (the default), plus the 80-second movie on its first play |
| Opens | always (chapter select; `requires` = `bonnie` is only the "suggested next" hint) |
| New controls | the SPEECH screen: Space presents a word, Up / Down level, Right (or + / =) = repeated it, Left (or - ) = missed it, S stores the SRT; every control is a button too |
| Level scene | `res://story/level_mike.tscn` (`story/level_mike.gd`). **(clinical review S7)** Movie data: `res://story/explainers/movies/srt_ladder.gd`, drawn by its own sets script `res://story/explainers/stages/srt_ladder_sets.gd` (`MOVIE.stage`), played by the shared `explainer_player.tscn` (§3.1) |

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
| Hoot's 1 kHz retest (`story/tests/test_level_mike.gd`) | 15 dB better than his first 1 kHz (about 55 vs 70) | (right ear only: the first air ear, the one that owes it, E2) |

## 3. Beat by beat (about 11 minutes, plus the movie)

Every blocking beat emits `Events.awaiting_input`. "Hoot runs" = Hoot's turn at top speed (not scored).

| # | Phase (`phase_changed`) | What happens | Beat(s) | Time |
|---|---|---|---|---|
| 0 | `explainer` | **(clinical review S7)** "The Spondee Ladder" (§3.1): until it has been seen (reached its `mismatch` scene) Hoot announces it ("New trick today: SPEECH THRESHOLDS. A quick cartoon first, then our next patient!") and it plays; after that Hoot offers it ("Hoot's spondee movie again? Popcorn's on me!"; the best answer is to skip). A skip at day start gets "Skipped! Rewatch it any time: pause menu, "Watch Hoot's spondee movie"." | the player's own `explainer` beat; `choice` on replays | 1:25 |
| 1 | `intro` | Mike swaggers in with his clipboard and neck brace. Hoot: "Day 3, trainee: speech! Today we check if words agree with the beeps." The coffee whisper gag. | dialogue | 0:50 |
| 2 | `history` | Two rounds (table above). Red-flag card: "Sudden, both ears: a doctor must know fast." Medal `history`. The flag is closed at beat 10 (his doctor hears about it). | choice | 1:20 |
| 3 | `otoscopy` | A quick look: canals clear, eardrums normal. The otoscope card: "Fresh speculum. Mike's RIGHT ear: clear canal, healthy eardrum." (clinical review A1, as on the case days). Medal `otoscopy` gold. | dialogue | 0:20 |
| 4 | `instructions` | "Beeps AND words today." Pick: press for every beep, repeat every word, guess if unsure. Wrong picks: "only when you're sure" (too strict), "shout every word" (the gag). Medal `instructions`. | choice | 0:40 |
| 5 | `audiometry` {right, ac} / {left, ac} | Hoot's routine line first, once, as on the case days (clinical review A1): "This morning's listening check: every beep clean, the button works. Dials stay out of view." Then he pops the earphones on and runs both ears as a few-second montage each (`montage`, `skip_hoot_retest`, as on Day 2: the beeps aren't today's lesson). After the right ear he retests 1000 Hz, and it comes back 15 dB better than the first time (`LevelMike.RETEST_BETTER_DB`, from his measured 1 kHz result): "1000 Hz again: 55 dB, 15 better than before. Retests usually agree within 5 dB." Mike: "Must be the earphones warming up." (a test-retest mismatch, one more sign; the PTA keeps the first stamp, the retest goes on the record as `retest_1k`). "About 75 dB in both ears. Severe, on paper." The degree comes from `ClinicRules.degree_name` (at 70 it is "Moderately severe", and Mike says "Skip the 'moderately'."). Then Hoot defines the PTA. Day 3 masks nothing (no bone, and no SRT level on the dial needs noise with his beeps), so it has no masking recap (clinical review A2). | (AudiOtron), dialogue | 0:40 |
| 6 | `familiarize` | Hoot's spondee line ("two-part words, equal stress on both parts, like rain-bow"). "Go through the word list with Mike first?" Yes = gold. Twelve word cards flip over on the clinician's side (a small "CLINICIAN'S SIDE: Mike can't see this" sign): Hoot says each word and Mike says it back by ear, never reading it. The player sees every word on the cards and on the "now saying" line (Hoot: "rainbow"  Mike: "Rainbow!"), with a tick per card; nothing depends on hearing. Mike repeats "Wind... mill?" and has never seen one, so the player drops that card ("Drop any word they don't know"). Then his SRT instructions: every test word comes from this list; say back what you hear, guess if unsure. Medal `familiarize`. | choice, dialogue, familiarize_cards | 0:50 |
| 7 | `speech` {right, srt} | Hoot defines the SRT, then the dance, and adds "Down 10, up 5 is one common way, not the only method." (clinical review S5). The SPEECH screen, coached, on the better ear (S6: the lower PTA from Hoot's tones goes first, right on a tie; for Mike normally the right: true PTAs 71.7 and 73.3, Hoot's tones about 70 and 75): "Better ear first: the right. Start at his PTA plus 15: 85 dB, easy to repeat." A better left ear would go first and be the coached one (`LevelMike.srt_ears`, the HUD lists SRT L first); the recheck and the board stay on the right ear. Mike repeats words all the way down to the 30s. The tell (once, on the screen): the first word scored as repeated 30 dB or more below the ear's PTA, "He's repeating words 40 dB below his beeps. Hmm!", with Hoot's hand on the agreement meter, then the coach's tip comes back. Half-word tip. Store at 30 (the coached ear never stores before a bracket). | (speech beats) | 2:30 |
| 7b | | The **agreement meter** swings: PTA 72, SRT 30, difference 42: **POOR**. The needle clunks into the red. Hoot: "SRT should sit within 6 dB of the PTA. His is 42 dB better. Poor agreement!" (the 6 is `SpeechRules.AGREE_GOOD_DB`; an SRT worse than the PTA gets the instructions / language / word scores line instead; a sloping loss is no reason for a worse SRT: a steep slope can make words a little better than the three-tone average, so the PTA uses the best two). | | 0:15 |
| 7c | `speech` {right, srt} (recheck) | Only when the player's right SRT can't show the mismatch (not poor, not better than the PTA, or not stored at its bracket: `_srt_shows_mismatch`). Hoot says why ("That SRT didn't get a full bracket. I'll recheck the right ear by the book.", or "The bracket said N dB, not that one...") and reruns the right ear at 8x on a fresh session (plan `fresh_session`). The board uses his recheck; the player's own sheet stays for the grade. | (Hoot's turn) | 0:20 |
| 8 | `speech` {left, srt} | Solo, the second ear: "Left ear: yours to the first miss and back up 5! PTA plus 15 is 90 dB." The player scores the descent from 90 (about eight words, down to his first miss below the SRT) and the word stepped up 5 after it, so they play every rule of the bracket alone; then Hoot takes over and finishes the bracket (quick visit; plan `hoot_turn_after_up`, with 12 words as the cap). Same story: poor agreement. | (speech beats) | 1:00 |
| 9 | `evidence` | **OBJECTION!** Mike's claim card "I can't hear ANYTHING" and three clues: "SRT 30 vs PTA 72" (or "Hoot's recheck: SRT 30 vs PTA 72"), "answered a whispered coffee offer", "canals clear". The captions stay neutral ("Two sugars, thanks." Hoot whispered it at the desk. / Otoscopy, both ears: clear canals, normal-looking eardrums.); the explanations come in the "why" after a wrong pick. The measurement is always the strongest clue; the whisper never outranks it. Medal `evidence`. | objection_present | 0:45 |
| 10 | `referral` | "What's next for Mike?" Fit strong hearing aids / **Re-instruct, retest, objective tests, tell his doctor** / Call him a fibber. Then the **RECHECK + OBJECTIVE TESTS + DOCTOR TODAY** stamp. Medal `referral`. | choice, referral_stamp | 0:45 |
| 11 | `results` | Mike owns up ("Cousin Vinnie said to say I can't hear, for paid leave. I can hear you fine."; the game never says his ears are fine: an SRT of 30 is an upper bound on his hearing, and the objective tests still follow). Hoot thanks him, then the main-path lesson: "Non-organic loss has many causes: money, stress, worry, even a real loss underneath." and "We can't tell which from the booth, so we never accuse." (clinical review S11), then "We'll still finish the objective tests and send your results to your doctor." He leaves; Hoot whispers "free donuts in the break room" and Mike yells "GLAZED?!" from the hall. The Daily Decibel, Day 3. | results_continue | 1:00 |

That is about 12:40 with quick visit on and the movie watched; about 11:15 on replays.

### 3.1 Hoot's spondee movie: "The Spondee Ladder" (clinical review S7)

Eight scenes, 80 s, one idea each. It opens with what the movie answers (Steve's rule, 2026-10-19: every movie first
says what it will explain): why test with words when we already have beeps. Then: spondees, why they stay fair at
the edge of hearing, the SRT as the halfway level, the game's ladder (one common way), familiarisation by ear, and
PTA/SRT agreement both ways. It shows none of Mike's numbers; the windmill, the whisper and the OBJECTION! board are
the day's own. Scene 5 is the familiarisation Mike then does for real (beat 6).

"Hoot's Movie Matinee: The Spondee Ladder" (`MOVIE.title` "Hoot's spondee movie", `subtitle` "The Spondee Ladder").
The lead-in is in rows 0 and 1: the announcement in the clinic, then the marquee that holds while Hoot asks the
movie's question and names its answer.

| # | Scene (`set`) | Visuals (the stage brief) | Caption(s), Hoot | s | The one idea |
|---|---|---|---|---|---|
| 0 | (the clinic, first play only) | The door camera, before the movie starts. A replay instead gets the offer (below), never this line. | Dialogue box: "New trick today: SPEECH THRESHOLDS. A quick cartoon first, then our next patient!" | ~4 | (Steve) What today is for, before the cartoon. |
| 1 | `spondees` | Curtains swish open (0-1.2 s) on the marquee HOOT'S MOVIE MATINEE / The Spondee Ladder, a little ladder with two word blocks beside the title. **The marquee holds 8 s** (`params.card_hold`) while Hoot asks the question and names the answer, with **two question chips** under it ("Why test words after beeps?", "Do words and beeps agree?", `params.questions`). Then two balance beams: LIGHT and HOUSE, then RAIN and BOW, land as chunky blocks with faces; each beam tips as the first half lands and settles dead level with the second. Each half thumps its beat, DUM! DUM!, under the same accent mark; Hoot conducts. | "Hoot's Movie Matinee! Today's mystery: we already have beeps, so why test with words?" / "The answer is the SRT, a speech threshold, because words double-check the beeps." / "Meet the spondees: two-part words, both halves equally strong, like LIGHT-HOUSE and RAIN-BOW." (at 0.3, 4.4 and 8.4 s) | 15 | (Steve, 2026-10-19: the movie must say what it will explain) What the movie answers; then: spondees are two-part words with both halves stressed the same. |
| 2 | `edge` | Hoot's slider from LOUD to soft slides almost to the soft end, into a dashed zone "the edge of hearing". A word bubble floats to a listener bean, LIGHT and HOUSE arriving equally faint. The bean squints, then beams: "Lighthouse!", a mint tick. Chips: "both halves equally soft", "easy to guess right". | "Two strong halves make a spondee easy to guess right, even at the edge of hearing." | 8 | Both halves are equally strong, so even a very soft spondee is easy to guess right. |
| 3 | `half` | A score board like the SPEECH screen's, louder rows at the top: four word dots per row, 4 of 4 at 40, 3 of 4 at 35, 2 of 4 at 30, 0 of 4 at 25. The 30 row lights mint and a stamp lands: SRT 30 dB. A chip by the 25 row: "too soft". | "The SRT: the softest level where the patient repeats about half the words." / "Two of four at 30 dB, none at 25: the SRT is 30." | 9 | The SRT is the softest level where the patient repeats about half the words (the board's SRT is `SpeechRules.srt_candidate`'s). |
| 4 | `ladder` | A tall ladder, one rung per 5 dB, LOUDER at the top (55), softer at the bottom (15). Hoot hops down two rungs ("-10") after a tick and climbs one ("+5") after a cross: 50, 40, 30 right, 20 and 25 missed, 30 right, the words landing as dots on a trail beside it. Chips: "one common way", "not the only one". | "Our ladder: a right word, step down 10 dB. A miss, climb up 5." / "That's one common way, not the only one. Clinics have their own recipes." | 11 | (S5) The game's search, down 10 after a repeated word and up 5 after a miss (`srt_next_level`): one common way, not the only one. |
| 5 | `practice` | Hoot beside an easel of word cards that faces HIM (a "no peeking!" sign on its back). Three words: Hoot says it, the patient bean says it back, a mint tick. Then an ear chip "by ear", a crossed-out eye "not by reading", and a ribbon: "hearing, not vocabulary". | "Before any ladder, familiarise: Hoot says each word aloud, and the patient repeats it." / "By ear, never by reading: we test hearing, not vocabulary." | 9 | Familiarisation: each word said aloud and repeated by ear, never read, so the test measures hearing, not vocabulary. |
| 6 | `agree` | A tall dB ruler, soft at the TOP: a beep (a music note) at the tone average, 40, and a two-block word at the SRT, 35. A mint band grows 10 dB either side of the beep, a dashed line says "5 dB apart", and a sign pops: THEY AGREE! | "The SRT usually lands within about 10 dB of the tone average. Beeps and words agree!" | 8 | PTA/SRT agreement: the SRT usually lands near the pure-tone average, so the words double-check the beeps ("about 10 dB" is the plain-words band; the day grades 6 good and 12 fair, beat 7b). |
| 7 | `mismatch` | Two panels with small rulers. "Words much BETTER": beep at 45, word at 10; Hoot re-instructs kindly ("Every beep, even the faint ones!") and the rechecked beep slides up to 15, into the band, with a heart chip "never accuse". "Words much WORSE": beep at 40, word at 65; chips "instructions clear?", "words in their language?". Watching up to here counts as seen (`seen_at`). | "Words much better than beeps? Kindly re-instruct and recheck the beeps. Never accuse." / "Words much worse? Check the instructions, and that the words are in their language." | 12 | Poor agreement both ways: much better words, re-instruct kindly and recheck the beeps (never accuse); much worse, check the instructions and the language. |
| 8 | `recap` | Four numbered tiles: two word blocks ("two-part words"), an ear ("say them first"), a little ladder with -10 and +5 ("find about half"), a beep beside a word block ("check the beeps"). Hoot bows, the curtains close: "Your turn, trainee!". | "Recap: two-part words, said first by ear. Find the halfway level, then check it against the beeps." | 8 | Recap: spondees said first by ear, down 10 / up 5 to about half right, then the SRT checked against the beeps. |

Scene totals: 15 + 8 + 9 + 11 + 9 + 8 + 12 + 8 = **80 s**. The longest caption is 17 words. The words shown
(lighthouse, rainbow, goldfish) are `spondee_a.json`'s own, in the game's own order. Reduced motion: fades and cuts
only. Every sound is a quiet `Sfx` cue; the words are drawn, never played.

**How the level plays it.** `level_mike._movie()` is `level_nora._movie()` with the id `"srt_ladder"`, before the
intro: `_phase(&"explainer", {movie, source: "day_start", seen})`, then, until `Game.is_movie_seen("srt_ladder")`,
row 0 and the movie; once seen, only the offer, "Hoot's spondee movie again? Popcorn's on me!" with ["Roll the film!
(about 80 s)", "Skip it: I know my spondees."], best answer 1 (skip), and no announcement. `Game.set_visit_flag(
"movie_watched", ...)` takes the result's `watched`. An Esc before the `mismatch` scene plays it again next visit.
The pause menu offers "Watch Hoot's spondee movie" (`Movies.for_chapter("mike")`); the replay lists label it "Day 3".
If `Movies.has("srt_ladder")` is false, the day starts at the intro. Tests: `story/tests/test_movie_srt_ladder.gd`
(the data and its facts) and `test_level_mike.gd::test_movie_announced_only_when_unseen`. The bot reports `movies`
on Day 3, and a fresh save must start `srt_ladder`.

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
| SRT start | "Better ear first: the right. Start at his PTA plus 15: 85 dB, easy to repeat." ("Right ear first." when the PTAs tie) |
| SRT | "SRT, speech recognition threshold: the softest level where he repeats at least two words, half or more." |
| The dance | "Got it: down 10. Missed: up 5. Another word at the same level is fine too!" (the wrong-step tip: "...Another word here is fine too!") |
| One way | "Down 10, up 5 is one common way, not the only method." |
| Start window | "Start at his PTA plus 15, plus 40 at most: easy words first, then work down." (the `srt_start` tip: a first word below PTA + 10 or above PTA + 40) |
| Low start | "Starting below his beeps and coming up: smart when answers look exaggerated." (the first step up after a first word at least 10 dB below the PTA, once the whisper has been on screen: `low_start_ok`) |
| Scoring | "Score what he SAID. Half a word, a different word, or silence: all misses." |
| SRT rule | "SRT: the softest level with two right and half or more. Check the trail!" |
| Bracket (coach) | "Bracketed! 30 dB: the softest level with half or more right. Press S to STORE." |
| The tell | "He's repeating words 40 dB below his beeps. Hmm!" |
| Half words | "Half a word is a miss. Lots of half-words can be a sign of a non-organic loss." |
| Agreement | "SRT should sit within 6 dB of the PTA. His is 42 dB better. Poor agreement!" |
| Agreement, worse | "Words worse than beeps? Think instructions, language or word scores." |
| Recheck | "That SRT didn't get a full bracket. I'll recheck the right ear by the book." |
| No aids yet | "Not on results we can't trust. And a sudden loss sees a doctor before any hearing aid." |
| Never accuse (wrong pick) | "Never accuse! Non-organic loss has many causes. Stay kind and record the facts." |
| Next step | "Re-instruct, retest, objective tests that don't need his answers, and his doctor hears about the sudden loss today." |
| After the confession | "Thank you for telling us, Mike. That took guts." |
| Non-organic (main path) | "Non-organic loss has many causes: money, stress, worry, even a real loss underneath." / "We can't tell which from the booth, so we never accuse." |
| The doctor | "We'll still finish the objective tests and send your results to your doctor." |

**Non-organic, on the main path.** A player who answers everything well never sees the "Call him a fibber" reply,
so the term and its meaning come on the main path: the half-word tip names a non-organic loss, and right after
Mike's confession Hoot says non-organic loss has many causes (money, stress, worry, even a real loss underneath),
that we can't tell which from the booth, and so we never accuse. The fibber branch keeps its short reminder. The game never teaches "non-organic = faking".

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
  the Daily Decibel's C-grade subhead names the slip that actually happened (`SPEECH_C_SUBHEADS`; a misscored C
  says which way the scores went, generous or strict, `SPEECH_C_MISSCORED`), and its golf cell reads "no bracket"
  for an unbracketed store and "N slips" / "no golf" for a bracketed store with slips. Hoot's recheck gets its own
  line under the card ("Hoot's recheck: SRT N dB on the right, by the book... Not graded."), and the agreement
  legend says which way a gap points (words better than beeps: non-organic; worse: instructions, language or word
  recognition).
- Accuracy: `ClinicRules.accuracy_for_error(|stored SRT - true SRT|)`. Technique: every step and every score is
  a check. Efficiency: par / words. Golf per SRT (fair golf, like tones).
- Medals (Day 3 paper row): Chat (`history`), Explain (`instructions`), Words (`familiarize`), Case (`evidence`),
  Next (`referral`).

## 7. Open questions for Steve

1. SRT stepping: "down 10 / up 5" with "at least 2 right and half or more", or your clinic's routine (for example
   down 5 after each correct word, or 2-dB steps with the Tillman-Olsen arithmetic)? Another word at the same
   level is tolerated, after a hit or a miss, up to 4 words at a level per ear (`SRT_MAX_WORDS_PER_LEVEL`); the
   5th is a wrong step. Is 4 right? **(clinical review S5, question 11, default taken)** Down 10 / up 5 stays, and
   Hoot calls it one common way, not the only method (ASHA 1988 describes a descending method of its own).
2. Start level PTA + 15 (rounded), with a first word from PTA + 10 to PTA + 40 accepted. ASHA (1988) starts
   30-40 dB above the estimated SRT, and allows an ascending start when pseudohypacusis (an exaggerated loss) is
   suspected. **(clinical review S4, question 11, default taken)** A first word 30 to 40 above the PTA is a clean
   start (`SRT_START_MAX_DB` 40; par counts from the first word, so the extra words cost nothing); the
   recommended start stays PTA + 15, and the `srt_start` tip says "plus 40 at most". For Mike the dial's top
   (100) is his PTA + 28. An ascending start (a first word at least 10 dB below the PTA) is clean once the whisper
   is on screen (`low_start_ok`), and **(S2)** Hoot's praise, "Starting below his beeps and coming up: smart when
   answers look exaggerated.", comes with the first step up after it, never on the low first word alone: a first
   word at 60 (about 12 below his right PTA) that he still repeats steps down first, and the praise waits. Is
   starting 10+ dB below the PTA the right trigger, or should it be lower (nearer the expected SRT)?
3. Agreement bands 6 / 12 dB (good / fair / poor) with the 3-frequency PTA (best two when the three spread 20+).
4. Is the next step right: re-instruct, retest (an ascending retest?), objective tests that don't need his answers
   (the objective cross-checks: acoustic reflexes, OAEs, ABR / ASSR; a Stenger only for a one-sided claim, so not
   for Mike, who claims both ears), no aids on unreliable results,
   and a medical referral for the reported sudden loss (his doctor hears about it today)?
5. The tone of the case: kind, never accusing, with a jokey confession. OK for career-fair players?
