extends RefCounted
## Day 3's explainer: Hoot's spondee movie, "The Spondee Ladder" (clinical review S7 / A3; the shape of
## Day 4's story/explainers/movies/letter_choir.gd, CONTRACTS.md §3.4 and §9.20).
## story/level_mike.gd plays it at the start of Day 3 (_movie: the &"explainer" phase, as Day 4
## plays its own); replay from the pause menu or the title's "Hoot's Movies".
## DATA ONLY. The player types "captions", fires "cues" (quiet Sfx, seconds from the scene start) and
## hands "set" + "params" to the stage; the scenes are drawn by this movie's own sets,
## story/explainers/stages/srt_ladder_sets.gd (MOVIE.stage). Every scene's top-level params are its
## card (heading, lines, icon, tint: the fallback when a set is not drawn); the set's own data sits
## under params.<set>. "board" is the art brief (never shown).
## (Steve) Scene 1 opens the way Day 2's movie does: the marquee holds (params.card_hold) while Hoot
## asks the movie's question and names its answer, with two question chips (params.questions); the
## balance beams then run card_hold - 2 s later.
## (Clinical review S5) The ladder is the game's own, down SRT_DOWN_DB (10) after a right word and up
## SRT_UP_DB (5) after a miss, and Hoot calls it one common way, not the only one.
## Facts (Steve reviews; story/tests/test_movie_srt_ladder.gd pins them): the halfway board's SRT is
## what SpeechRules.srt_candidate gives for its dots; the ladder's levels follow srt_next_level; the
## agreeing pair is within 6 dB (AGREE_GOOD_DB; SpeechRules.agreement: good), the two that disagree
## are "poor" both ways, and the recheck brings the beeps back within 6 dB (AGREE_GOOD_DB). Every
## word shown is one of core/speech/material/spondee_a.json's own (three of them, in our own order),
## never a word or order from a published list. Every sound is a quiet cue: the words are drawn,
## never played.

const MOVIE: Dictionary = {
	"id": "srt_ladder", "title": "Hoot's spondee movie", "subtitle": "The Spondee Ladder",
	"chapter": "mike", "narrator": "Hoot",
	## Watching up to this scene counts as seen (Game.mark_movie_seen): a skip of only the recap still counts.
	"seen_at": "mismatch",
	"stage": "res://story/explainers/stages/srt_ladder_sets.gd",
	"scenes": [
		{
			"id": "spondees", "set": "spondees", "title": "Two-part words", "duration": 15.0,
			"captions": ["Hoot's Movie Matinee! Today's mystery: we already have beeps, so why test with words?",
				"The answer is the SRT, a speech threshold, because words double-check the beeps.",
				"Meet the spondees: two-part words, both halves equally strong, like LIGHT-HOUSE and RAIN-BOW."],
			"caption_at": [0.3, 4.4, 8.4],
			"teaches": "What the movie answers (why words after beeps: the SRT, a speech threshold, double-checks the tones), then: spondees are two-part words with both halves stressed the same.",
			"board": "Curtains swish open on the cinema screen (0-1.2 s) on the marquee HOOT'S MOVIE MATINEE / The Spondee Ladder, a little ladder with two word blocks beside the title; it holds 8 s while Hoot asks the question and names the answer, with two question chips under it. Then the card flips away and two balance beams pop up. LIGHT and HOUSE drop onto the first beam's ends as chunky blocks with faces, RAIN and BOW onto the second; each beam tips as the first half lands and settles dead level when the second does (both halves weigh the same). Then each half thumps its beat in turn, DUM! DUM!, with the same accent mark over every half; Hoot conducts. Reduced motion: the blocks fade in, the beams never tip.",
			"params": {"heading": "Two-part words", "icon": "note", "tint": "#fff4c2",
				"lines": ["Spondees: two-part words", "Both halves equally strong", "light-house, rain-bow"],
				"card_hold": 8.0, "questions": ["Why test words after beeps?", "Do words and beeps agree?"],
				"spondees": {"title": "The Spondee Ladder", "starring": "starring the two-part words",
					"words": [["light", "house"], ["rain", "bow"]]}},
			"cues": [{"t": 0.2, "sfx": "fanfare", "vol_db": -14.0}, {"t": 0.5, "sfx": "whoosh", "pitch": 0.9, "vol_db": -12.0}, {"t": 2.0, "sfx": "pop", "pitch": 1.0, "vol_db": -10.0}, {"t": 4.6, "sfx": "pop", "pitch": 1.1, "vol_db": -10.0}, {"t": 8.8, "sfx": "thunk", "pitch": 1.0, "vol_db": -12.0}, {"t": 9.2, "sfx": "thunk", "pitch": 1.0, "vol_db": -12.0}, {"t": 10.4, "sfx": "thunk", "pitch": 1.1, "vol_db": -12.0}, {"t": 10.8, "sfx": "thunk", "pitch": 1.1, "vol_db": -12.0}, {"t": 11.4, "sfx": "pop", "pitch": 0.8, "vol_db": -10.0}, {"t": 11.8, "sfx": "pop", "pitch": 0.8, "vol_db": -10.0}, {"t": 12.2, "sfx": "pop", "pitch": 0.8, "vol_db": -10.0}, {"t": 12.6, "sfx": "pop", "pitch": 0.8, "vol_db": -10.0}],
		},
		{
			"id": "edge", "set": "edge", "title": "Easy at the edge", "duration": 8.0,
			"captions": ["Two strong halves make a spondee easy to guess right, even at the edge of hearing."],
			"caption_at": [0.3],
			"teaches": "Both halves of a spondee are equally strong, so even a very soft one is easy to guess right: the words stay fair right at the edge of hearing.",
			"board": "Hoot at the left with a slider from LOUD to soft; its knob slides almost to the soft end, into a dashed zone labelled 'the edge of hearing'. A word bubble floats from Hoot to a listener bean, fading on the way: LIGHT and HOUSE arrive equally faint, dotted at the edges. The bean squints, then beams: 'Lighthouse!' and a big mint tick. Chips: 'both halves equally soft', 'easy to guess right'. Reduced motion: the bubble fades across instead of floating.",
			"params": {"heading": "Easy at the edge", "icon": "dial", "tint": "#e9f4ff",
				"lines": ["Both halves equally strong", "Even very soft words", "are easy to guess right"],
				"edge": {"word": ["light", "house"], "guess": "Lighthouse!"}},
			"cues": [{"t": 0.8, "sfx": "click", "vol_db": -12.0}, {"t": 1.3, "sfx": "click", "pitch": 0.9, "vol_db": -12.0}, {"t": 2.0, "sfx": "whoosh", "pitch": 1.2, "vol_db": -14.0}, {"t": 4.4, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}, {"t": 5.2, "sfx": "sparkle", "vol_db": -14.0}],
		},
		{
			"id": "half", "set": "half", "title": "The halfway mark", "duration": 9.0,
			"captions": ["The SRT: the softest level where the patient repeats about half the words.",
				"Two of four at 30 dB, none at 25: the SRT is 30."],
			"caption_at": [0.3, 4.8],
			"teaches": "The speech recognition threshold (SRT) is the softest level where the patient repeats about half the words.",
			"board": "A score board like the SPEECH screen's: one row per level, LOUDER at the top and softer at the bottom, so it reads like the ladder. Four word dots pop in along each row, top row first (mint tick or coral cross), and a tally at the end of each row: 4 of 4 at 40, 3 of 4 at 35, 2 of 4 at 30, 0 of 4 at 25. The 30 row lights mint and a rubber stamp lands beside it: SRT 30 dB. A chip by the 25 row: 'too soft'. Hoot cheers at the stamp. Reduced motion: the dots fade in, the stamp lands without the drop.",
			"params": {"heading": "The halfway mark", "icon": "", "tint": "#e8f7e4",
				"lines": ["SRT: speech recognition threshold", "The softest level where", "about half the words come back"],
				"half": {"rows": [[40, "YYYY"], [35, "YYNY"], [30, "YNYN"], [25, "NNNN"]], "srt": 30}},
			"cues": [{"t": 1.0, "sfx": "blip", "vol_db": -14.0}, {"t": 2.0, "sfx": "blip", "pitch": 0.9, "vol_db": -14.0}, {"t": 3.0, "sfx": "blip", "pitch": 0.8, "vol_db": -14.0}, {"t": 4.0, "sfx": "blip", "pitch": 0.7, "vol_db": -14.0}, {"t": 5.0, "sfx": "stamp", "pitch": 1.1, "vol_db": -12.0}],
		},
		{
			"id": "ladder", "set": "ladder", "title": "Down 10, up 5", "duration": 11.0,
			"captions": ["Our ladder: a right word, step down 10 dB. A miss, climb up 5.",
				"That's one common way, not the only one. Clinics have their own recipes."],
			"caption_at": [0.3, 6.4],
			"teaches": "The game's search: down 10 dB after a repeated word, up 5 dB after a miss; one common way to find the SRT, not the only one.",
			"board": "A tall wooden ladder, one rung per 5 dB, LOUDER at the top (55) and softer at the bottom (15), as on the SPEECH screen's ladder. Hoot sits on the 50 rung. Six words in turn: each pops a bubble beside him, gets a mint tick or a coral cross, and Hoot hops DOWN two rungs ('-10') after a tick or climbs UP one ('+5') after a cross: 50, 40, 30 right, 20 and 25 missed, 30 right. Beside the ladder the same words land as dots on a trail, level by level, lined up with the rungs. Then two chips: 'one common way', 'not the only one'. Reduced motion: Hoot slides between rungs instead of hopping.",
			"params": {"heading": "Down 10, up 5", "icon": "", "tint": "#fff7d6",
				"lines": ["Right word: down 10 dB", "Missed it: up 5 dB", "One common way,", "not the only one"],
				"ladder": {"start": 50, "answers": [true, true, true, false, false, true], "down": 10, "up": 5, "top": 55, "bottom": 15}},
			"cues": [{"t": 1.35, "sfx": "pop", "pitch": 1.2, "vol_db": -12.0}, {"t": 2.45, "sfx": "pop", "pitch": 1.1, "vol_db": -12.0}, {"t": 3.55, "sfx": "pop", "pitch": 1.0, "vol_db": -12.0}, {"t": 4.65, "sfx": "boing", "pitch": 0.8, "vol_db": -14.0}, {"t": 5.75, "sfx": "boing", "pitch": 0.9, "vol_db": -14.0}, {"t": 6.85, "sfx": "pop", "pitch": 1.0, "vol_db": -12.0}, {"t": 7.6, "sfx": "sparkle", "vol_db": -14.0}],
		},
		{
			"id": "practice", "set": "practice", "title": "Say them first", "duration": 9.0,
			"captions": ["Before any ladder, familiarise: Hoot says each word aloud, and the patient repeats it.",
				"By ear, never by reading: we test hearing, not vocabulary."],
			"caption_at": [0.3, 5.0],
			"teaches": "Familiarisation: before the SRT the clinician says each word aloud and the patient repeats it, by ear, never by reading, so the test measures hearing, not vocabulary.",
			"board": "Hoot at the left beside a little easel of word cards that faces HIM (its back to the patient, a 'no peeking!' sign on it). Three words in turn: Hoot's bubble says the word, the patient bean's bubble says it back, a mint tick pops. Then an ear chip 'by ear' and a crossed-out eye 'not by reading', and a ribbon: 'hearing, not vocabulary'. Reduced motion: the bubbles fade in.",
			"params": {"heading": "Say them first", "icon": "hoot", "tint": "#ffe9e4",
				"lines": ["Familiarise first", "Hoot says each word aloud", "By ear, never by reading", "Test hearing, not vocabulary"],
				"practice": {"words": ["rainbow", "goldfish", "lighthouse"]}},
			"cues": [{"t": 0.8, "sfx": "pop", "pitch": 1.0, "vol_db": -12.0}, {"t": 1.7, "sfx": "ding", "pitch": 1.0, "vol_db": -14.0}, {"t": 2.2, "sfx": "pop", "pitch": 1.1, "vol_db": -12.0}, {"t": 3.1, "sfx": "ding", "pitch": 1.1, "vol_db": -14.0}, {"t": 3.6, "sfx": "pop", "pitch": 1.2, "vol_db": -12.0}, {"t": 4.5, "sfx": "ding", "pitch": 1.2, "vol_db": -14.0}, {"t": 6.2, "sfx": "sparkle", "vol_db": -14.0}],
		},
		{
			"id": "agree", "set": "agree", "title": "Words check the beeps", "duration": 8.0,
			"captions": ["The SRT usually lands within 6 dB of the tone average: good agreement. Within 12 is fair."],
			"caption_at": [0.3],
			"teaches": "PTA/SRT agreement: the SRT usually lands within 6 dB of the pure-tone average (good; within 12 fair), so the words double-check the beeps.",
			"board": "A tall dB ruler down the middle, soft at the TOP as on an audiogram. A beep (a music note) drops in on the left at the tone average, 40; a little two-block word drops in on the right at the SRT, 35. A mint band grows 6 dB either side of the beep: 'within 6 dB'. A dashed line joins the two ('5 dB apart'), and a big sign pops: THEY AGREE! Hoot cheers. Reduced motion: the markers fade in.",
			"params": {"heading": "Words check the beeps", "icon": "note", "tint": "#e8f7e4",
				"lines": ["Tone average: 500, 1k, 2k Hz", "The SRT lands near it", "Within 6 dB: good agreement"],
				"agree": {"pta": 40, "srt": 35, "within": 6}},
			"cues": [{"t": 0.8, "sfx": "pop", "pitch": 1.0, "vol_db": -12.0}, {"t": 1.6, "sfx": "pop", "pitch": 1.2, "vol_db": -12.0}, {"t": 2.6, "sfx": "whoosh", "pitch": 1.1, "vol_db": -14.0}, {"t": 4.4, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}],
		},
		{
			"id": "mismatch", "set": "mismatch", "title": "When they disagree", "duration": 12.0,
			"captions": ["Words much better than beeps? Kindly re-instruct and recheck the beeps. Never accuse.",
				"Words much worse? Check the instructions, and that the words are in their language."],
			"caption_at": [0.3, 6.3],
			"teaches": "Poor agreement: words much better than the beeps means re-instruct kindly and recheck the beeps (never accuse); words much worse means check the instructions and the patient's language.",
			"board": "Two panels, each with its own small ruler (soft at the top). Left, 'words much BETTER': the beep sits at 45, the word floats way up at 10, far above the mint band; a question mark pops. Hoot steps in with a kind face and holds up a card ('Every beep, even the faint ones!'): 're-instruct, kindly'. The beep is rechecked and slides up to 15, into the band: a tick, and a heart chip 'never accuse'. Then Hoot hops to the right panel, 'words much WORSE': the beep at 40, the word sinks to 65. Chips: 'instructions clear?', 'words in their language?'. Reduced motion: the markers fade, Hoot cuts across.",
			"params": {"heading": "When they disagree", "icon": "", "tint": "#f6e3ff",
				"lines": ["Words much better: re-instruct,", "recheck the beeps, kindly", "Words much worse: check the", "instructions and the language"],
				"mismatch": {"better": {"pta": 45, "srt": 10, "recheck": 15}, "worse": {"pta": 40, "srt": 65}, "within": 6}},
			"cues": [{"t": 1.6, "sfx": "boing", "pitch": 1.1, "vol_db": -14.0}, {"t": 2.2, "sfx": "pop", "pitch": 1.0, "vol_db": -12.0}, {"t": 3.4, "sfx": "whoosh", "pitch": 1.0, "vol_db": -14.0}, {"t": 4.6, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}, {"t": 6.0, "sfx": "whoosh", "pitch": 0.8, "vol_db": -14.0}, {"t": 7.0, "sfx": "boing", "pitch": 0.8, "vol_db": -14.0}, {"t": 7.6, "sfx": "pop", "pitch": 1.0, "vol_db": -12.0}, {"t": 8.4, "sfx": "pop", "pitch": 1.1, "vol_db": -12.0}],
		},
		{
			"id": "recap", "set": "recap", "title": "Recap", "duration": 8.0,
			"captions": ["Recap: two-part words, said first by ear. Find the halfway level, then check it against the beeps."],
			"caption_at": [0.3],
			"teaches": "Recap: spondees, familiarised by ear; down 10, up 5 to the softest level with about half right; the SRT should agree with the tone average.",
			"board": "Four tiles pop up in a row, numbered: two word blocks ('two-part words'), an ear ('say them first'), a little ladder with -10 and +5 ('find about half'), a beep beside a word block ('check the beeps'). Hoot bows; the curtains close and a chip says 'Your turn, trainee!'. Reduced motion: the tiles fade in.",
			"params": {"heading": "Recap", "icon": "hoot", "tint": "#fff4c2",
				"lines": ["Spondees, said first by ear", "Down 10, up 5: find about half", "SRT near the tone average"],
				"recap": {"tiles": ["two-part words", "say them first", "find about half", "check the beeps"]}},
			"cues": [{"t": 0.6, "sfx": "pop", "pitch": 0.9, "vol_db": -12.0}, {"t": 1.2, "sfx": "pop", "pitch": 1.0, "vol_db": -12.0}, {"t": 1.8, "sfx": "pop", "pitch": 1.1, "vol_db": -12.0}, {"t": 2.4, "sfx": "pop", "pitch": 1.2, "vol_db": -12.0}, {"t": 5.6, "sfx": "whoosh", "pitch": 0.8, "vol_db": -12.0}, {"t": 6.7, "sfx": "fanfare", "vol_db": -16.0}],
		},
	],
}
