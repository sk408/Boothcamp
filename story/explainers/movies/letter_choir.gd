extends RefCounted
## Day 4's explainer: Hoot's word movie, "The Letter Choir" (docs/CHAPTER4.md §4, CONTRACTS.md §9.20).
## Plays at the start of Day 4 before Nora arrives (story/level_nora.gd, the &"explainer" phase, as
## Day 2 plays the masking movie); replay from the pause menu or the title's "Hoot's Movies".
## DATA ONLY. The player types "captions", fires "cues" (quiet Sfx, seconds from the scene start) and
## hands "set" + "params" to the stage; the scenes are drawn by this movie's own sets,
## story/explainers/stages/letter_choir_sets.gd (MOVIE.stage). Every scene's top-level params are its
## card (heading, lines, icon, tint: the fallback when a set is not drawn); the set's own data sits
## under params.<set>. "board" is the art brief (never shown).
## (Steve) Scene 1 opens the way Day 2's movie does: the marquee holds (params.card_hold) while Hoot
## asks the movie's question and names its answer, with two question chips (params.questions); the
## choir then runs card_hold - 2 s later.
## (Clinical review A5) The level is "loud enough for every sound, never uncomfortable", never
## "comfortably loud" as the goal; the game's rule stays PTA + 35, at least 55.
## Facts (Steve reviews; story/tests/test_movie_letter_choir.gd pins them): the singers' spots are
## SpeechRules.SOUND_CUES positions for a chatting voice (CHAT_DB, 50); the curtain's chart is a
## made-up high-pitch loss, not Nora's; the louder slide is WRS_ABOVE_PTA_DB (35); 25 words
## (WRS_WORDS) at 4% each; on-ear phones lose at least 40 dB crossing the head (SPEECH_IA_DB).
## Written fresh for this game: the example words and sentences are our own, never taken from a
## published word list or rhyme test. Every sound is quiet: the loud knob, the loud word and the
## speech noise are drawn, never played.

const MOVIE: Dictionary = {
	"id": "letter_choir", "title": "Hoot's word movie", "subtitle": "The Letter Choir",
	"chapter": "nora", "narrator": "Hoot",
	## Watching up to this scene counts as seen (Game.mark_movie_seen): a skip of only the teaser still counts.
	"seen_at": "count",
	"stage": "res://story/explainers/stages/letter_choir_sets.gd",
	"scenes": [
		{
			"id": "choir", "set": "choir", "title": "The letter choir", "duration": 15.0,
			"captions": ["Hoot's Movie Matinee! Today's mystery: why can loud-enough words still come out mushy?",
				"The answer is a WORD SCORE: it counts clear words, because beeps can't measure clarity.",
				"Every word is a tiny choir: vowels sing low and loud, consonants whisper high."],
			"caption_at": [0.3, 4.4, 8.4],
			"teaches": "What the movie answers (why loud-enough words can still be unclear: the word score measures clarity), then: speech sounds differ, vowels low-pitched and loud, consonants such as s, f and th high-pitched and soft.",
			"board": "Curtains swish open on the cinema screen (0-1.2 s) on the marquee HOOT'S MOVIE MATINEE / The Letter Choir, two little singers beside the title; it holds 8 s while Hoot asks the question and names the answer, with two question chips under it. Then the card flips away and the word SOFT steps forward as four singers on choir risers: a big round 'o' sings with an open mouth; 's', 'f' and 't' are small and whisper. They sing in turn, left to right, each lighting its letter of SOFT and putting its note on a music staff (the vowel's big and low, the consonants' tiny and high), then all together; Hoot conducts. Reduced motion: no sway, the singers fade in.",
			"params": {"heading": "The Letter Choir", "icon": "note", "tint": "#fff4c2",
				"lines": ["Every word is a tiny choir", "Vowels sing low and loud", "Consonants whisper, high", "s, f and th whisper softest"],
				"card_hold": 8.0, "questions": ["Loud enough, so why mushy?", "How do we score clear words?"],
				"choir": {"title": "The Letter Choir", "starring": "starring the speech sounds", "word": "SOFT",
					"singers": [["s", "s"], ["o", "vowel"], ["f", "f"], ["t", "t"]]}},
			"cues": [{"t": 0.2, "sfx": "fanfare", "vol_db": -14.0}, {"t": 0.5, "sfx": "whoosh", "pitch": 0.9, "vol_db": -12.0}, {"t": 2.0, "sfx": "pop", "pitch": 1.0, "vol_db": -10.0}, {"t": 4.6, "sfx": "pop", "pitch": 1.1, "vol_db": -10.0}, {"t": 8.6, "sfx": "pop", "pitch": 1.3, "vol_db": -10.0}, {"t": 9.1, "sfx": "pop", "pitch": 0.8, "vol_db": -10.0}, {"t": 9.6, "sfx": "pop", "pitch": 1.4, "vol_db": -10.0}, {"t": 10.1, "sfx": "pop", "pitch": 1.2, "vol_db": -10.0}],
		},
		{
			"id": "banana", "set": "banana", "title": "The speech banana", "duration": 8.0,
			"captions": ["Line up every speech sound by pitch and loudness, and you get a banana. The speech banana!"],
			"caption_at": [0.3],
			"teaches": "Plotted by pitch and level on an audiogram, everyday speech sounds form the speech banana.",
			"board": "An audiogram stage: pitch from low (left) to high (right), soft at the TOP and loud at the bottom, as on a real chart. The letter singers hop up to their spots in three groups (SpeechRules.SOUND_CUES positions for a chatting voice, dial 50, copied as data: frequency across, dial + offset down) and a yellow banana outline draws itself around them. Vowels sit low-left and loud; s, f and th sit high-right and soft, near the top. Reduced motion: the singers fade in at their spots.",
			"params": {"heading": "The speech banana", "icon": "", "tint": "#fff7d6",
				"lines": ["Pitch: low left, high right", "Soft sounds at the top", "Vowels: low and loud", "s, f, th: high and soft"],
				"banana": {"dial": 50}},
			"cues": [{"t": 1.0, "sfx": "pop", "pitch": 0.8, "vol_db": -12.0}, {"t": 2.0, "sfx": "pop", "pitch": 1.0, "vol_db": -12.0}, {"t": 3.0, "sfx": "pop", "pitch": 1.3, "vol_db": -12.0}, {"t": 5.0, "sfx": "sparkle", "vol_db": -12.0}],
		},
		{
			"id": "curtain", "set": "curtain", "title": "The hearing curtain", "duration": 8.0,
			"captions": ["A high-pitch hearing loss drops a curtain over the soft, high singers: s, f, th."],
			"caption_at": [0.3],
			"teaches": "A sloping high-pitch loss hides the soft high consonants first.",
			"board": "A sloping threshold line draws itself across the banana (a made-up sloping loss, not Nora's chart). A velvet curtain drops from the TOP of the chart down to the line. The singers above the line duck behind it, only their tiny feet showing under the hem; the vowels below the line keep singing. Reduced motion: the curtain fades in.",
			"params": {"heading": "The hearing curtain", "icon": "", "tint": "#f6e3ff",
				"lines": ["A high-pitch loss hangs a curtain", "from the top down to her line", "Sounds above the line vanish", "s, f and th go first"],
				"curtain": {"thresholds": {250: 10, 500: 15, 1000: 25, 2000: 40, 4000: 55, 8000: 65}, "dial": 50}},
			"cues": [{"t": 1.0, "sfx": "whoosh", "pitch": 0.7, "vol_db": -12.0}, {"t": 2.6, "sfx": "thunk", "pitch": 0.9, "vol_db": -12.0}],
		},
		{
			"id": "mush", "set": "mush", "title": "Voices, not words", "duration": 8.0,
			"captions": ["Vowels still get through, so she knows you're talking. She just can't tell which word."],
			"caption_at": [0.3],
			"teaches": "With the consonants lost, speech is heard but not understood: voices, not words.",
			"board": "Two beans at a little cafe table. His bubble says 'Let's meet at six!'. A copy flies to her ear, dropping its consonants on the way, and arrives as 'Le__ mee_ a_ _i_!' (the lost letters are dotted gaps). Her bubble: 'Lettuce... meat...?' A question mark bounces beside her guess; a chip over the table: 'voices, not words'.",
			"params": {"heading": "Voices, not words", "icon": "", "tint": "#e9f4ff",
				"lines": ["Vowels still get through", "She knows someone is talking", "But not which word it was"],
				"mush": {"said": "Let's meet at six!", "heard": "Le__ mee_ a_ _i_!", "reply": "Lettuce... meat...?"}},
			"cues": [{"t": 0.8, "sfx": "pop", "pitch": 1.0, "vol_db": -10.0}, {"t": 3.4, "sfx": "boing", "pitch": 0.8, "vol_db": -14.0}],
		},
		{
			"id": "louder", "set": "louder", "title": "Loud enough", "duration": 8.0,
			"captions": ["Turn the words up: loud enough for every sound, never uncomfortable. Most singers step out."],
			"caption_at": [0.3],
			"teaches": "A level loud enough for every sound (never uncomfortable) makes most speech sounds audible, so the word score tests clarity, not loudness.",
			"board": "Hoot turns a big volume knob (drawn; nothing gets louder). The whole banana slides DOWN the chart by 35 dB, out from under the curtain; most singers step out and bow. Two (f and th) stay behind it: 'most', not all. A 'too loud' strip at the bottom of the chart stays empty. Reduced motion: the banana crossfades down.",
			"params": {"heading": "Loud enough, never too loud", "icon": "dial", "tint": "#e8f7e4",
				"lines": ["Turn the words up", "The banana slides down", "Most singers step out", "A few may still hide"],
				"louder": {"from_dial": 50, "to_dial": 85, "thresholds": {250: 10, 500: 15, 1000: 25, 2000: 40, 4000: 55, 8000: 65}}},
			"cues": [{"t": 0.8, "sfx": "click", "vol_db": -10.0}, {"t": 1.4, "sfx": "click", "pitch": 1.1, "vol_db": -10.0}, {"t": 2.0, "sfx": "click", "pitch": 1.2, "vol_db": -10.0}, {"t": 3.4, "sfx": "sparkle", "vol_db": -12.0}],
		},
		{
			"id": "crossing", "set": "crossing", "title": "The Ghost is back", "duration": 8.0,
			"captions": ["Loud words can cross the head to the good ear. Speech noise there keeps it out."],
			"caption_at": [0.3],
			"teaches": "Loud speech can cross the skull to the better cochlea, so the better (non-test) ear gets speech noise.",
			"board": "The masking movie's front-view head with Righty (her right, the screen's LEFT) and Lefty. A chunky word bubble tagged 80 dB goes into Lefty's side (the poorer ear today); a smaller copy squeezes through the skull wall under its '-40 dB' toll sign to Righty, who throws on the Ghost's bedsheet: 'I HEARD IT!' Then a phone on her right ear fills Righty's corner with a purple cloud labelled SPEECH NOISE, the next crossing word bonks off it, and the sheet slides off. Visual only: no noise plays.",
			"params": {"heading": "The Ghost is back", "icon": "ghost", "tint": "#efe7ff",
				"lines": ["Loud words can cross the skull", "The good ear answers instead", "Speech noise in the good ear", "keeps the Ghost out"],
				"crossing": {"test_ear": "left", "mask_ear": "right", "ia": 40, "level": 80, "word": "banana!"}},
			"cues": [{"t": 1.0, "sfx": "whoosh", "pitch": 1.2, "vol_db": -12.0}, {"t": 2.2, "sfx": "boing", "pitch": 0.7, "vol_db": -14.0}, {"t": 4.4, "sfx": "pop", "pitch": 0.9, "vol_db": -8.0}, {"t": 5.6, "sfx": "thunk", "pitch": 0.8, "vol_db": -12.0}],
		},
		{
			"id": "count", "set": "count", "title": "Count the clear words", "duration": 8.0,
			"captions": ["Then we count: twenty-five words, 4% each. A rhyme is a miss. The score measures CLEAR."],
			"caption_at": [0.3],
			"teaches": "The word recognition score: 25 whole words at 4% each; a rhyme or near-miss scores as a miss.",
			"board": "A 5 x 5 board of tiles flips one by one (mint tick or coral cross, each with its symbol). 'sock' comes back as 'lock': a callout card shows both and stamps coral with 'A RHYME IS A MISS'. The ticks add up on a scoreboard: 22 of 25, 88%. Reduced motion: the tiles change without flipping.",
			"params": {"heading": "Count the clear words", "icon": "", "tint": "#ffe9e4",
				"lines": ["25 words, 4% each", "'Lock' for 'sock' is a miss", "Whole words only", "The score measures CLEAR"],
				"count": {"tiles": 25, "misses": [3, 9, 17], "example": ["sock", "lock"], "right": 22}},
			"cues": [{"t": 1.0, "sfx": "blip", "vol_db": -14.0}, {"t": 2.4, "sfx": "stamp", "pitch": 1.2, "vol_db": -12.0}, {"t": 5.6, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}],
		},
		{
			"id": "tease", "set": "tease", "title": "Coming up...", "duration": 7.0,
			"captions": ["But what if louder DOESN'T make it clearer? Ooh, someone's humming at the door!"],
			"caption_at": [0.3],
			"teaches": "Teaser: sometimes louder is not clearer (the day will show why).",
			"board": "The volume knob turns again and a big question mark pops on it. The stage door opens a crack; little music notes float in on a staff (a hum, drawn); Hoot perks up. The curtains close.",
			"params": {"heading": "Coming up...", "icon": "dial", "tint": "#fff4c2",
				"lines": ["What if louder", "doesn't make it clearer?", "Someone's humming at the door"],
				"tease": {"notes": 3}},
			"cues": [{"t": 0.6, "sfx": "click", "vol_db": -10.0}, {"t": 3.0, "sfx": "door", "vol_db": -12.0}, {"t": 3.6, "sfx": "note", "pitch": 1.0, "vol_db": -14.0}, {"t": 4.0, "sfx": "note", "pitch": 1.12, "vol_db": -14.0}, {"t": 4.4, "sfx": "note", "pitch": 1.26, "vol_db": -14.0}],
		},
	],
}
