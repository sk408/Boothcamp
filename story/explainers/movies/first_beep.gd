extends RefCounted
## Hoot's Day 1 movie, "The First Beep" (clinical review D1-8). Plays at the start of Day 1 before
## Gus arrives (story/level_gus.gd, the &"explainer" phase, as Day 15 plays its tune-up movie: Hoot's
## one-line announcement the first time, a replay offer once watched); replay from Day 1's pause menu
## or the title's "Hoot's Movies". DATA ONLY: the scenes are drawn by story/case_movies/first_beep_sets.gd.
## Facts (Steve reviews): air conduction sends the tone through the earphone, down the ear canal, past
## the eardrum and the tiny middle-ear bones to the cochlea, and on to the brain. The audiogram runs
## low to high pitch from left to right and soft to loud from top to bottom (lower = a bigger loss;
## O right ear, X left ear; normal down to 25 dB HL). Look in the ears before testing. The search the
## game teaches: heard, down 10 dB; missed, up 5 dB; the threshold is the softest level heard twice on
## the way up (the ladder below stores 30 dB). Visual only: nothing loud ever plays.

const MOVIE: Dictionary = {
	"id": "first_beep",
	"title": "Hoot's first movie",
	"subtitle": "The First Beep",
	"chapter": "gus",
	"narrator": "Hoot",
	"stage": "res://story/case_movies/first_beep_sets.gd",
	"seen_at": "ladder",
	"scenes": [
		{
			"id": "open", "set": "fb_open", "title": "Today's mystery", "duration": 11.0,
			"captions": ["Hoot's Movie Matinee! Today's mystery: how do we find the softest beep someone hears?",
				"The answer: a beep's path, a chart, a quick look, and a little ladder.",
				"Our first patient is on his way. Quick, roll the film!"],
			"caption_at": [0.3, 4.6, 8.6],
			"teaches": "What the movie answers: how a hearing test finds the softest tone a person hears.",
			"board": "Curtains open on a marquee card HOOT'S FIRST MOVIE / The First Beep, a cyan musical note beside the title; it holds 8 s with two question chips. Then a 'Today: Grandpa Gus' chip; Hoot waves.",
			"params": {"card_hold": 8.0, "questions": ["Where does a beep go?", "How do we find the softest one?"]},
			"cues": [{"t": 0.2, "sfx": "fanfare", "vol_db": -14.0}, {"t": 2.0, "sfx": "pop", "vol_db": -10.0}, {"t": 4.6, "sfx": "pop", "pitch": 1.1, "vol_db": -10.0}],
		},
		{
			"id": "path", "set": "fb_path", "title": "A beep's path", "duration": 10.0,
			"captions": ["One earphone, one ear. The beep runs down the ear canal and taps the eardrum.",
				"Tiny bones pass it to the cochlea, Righty here, who rings it up to the brain."],
			"caption_at": [0.3, 5.0],
			"teaches": "Air conduction: earphone, ear canal, eardrum, middle-ear bones, cochlea, brain; one ear at a time.",
			"board": "The masking movie's air scene: one red earphone on her right ear, beeps hop down the canal into Righty's shell and he rings; Lefty sleeps. Across the top, chips pop in one by one: earphone > ear canal > eardrum > cochlea > brain.",
			"params": {"stops": ["earphone", "ear canal", "eardrum", "cochlea", "brain"]},
			"cues": [{"t": 1.6, "sfx": "blip", "vol_db": -16.0}, {"t": 4.0, "sfx": "blip", "pitch": 1.1, "vol_db": -16.0}, {"t": 6.4, "sfx": "ding", "vol_db": -14.0}],
		},
		{
			"id": "chart", "set": "fb_chart", "title": "Reading the chart", "duration": 13.0,
			"captions": ["The audiogram: low pitches on the left, high on the right.",
				"Soft at the top, loud at the bottom. O is the right ear, X the left.",
				"Lower on the chart means a bigger loss. Normal reaches down to 25 dB."],
			"caption_at": [0.3, 3.0, 8.6],
			"teaches": "The audiogram's axes: pitch left to right, loudness top to bottom; O right, X left; lower = bigger loss; normal down to 25 dB HL.",
			"board": "The shapes movie's chart scene: the grid draws in, a pitch arrow runs left to right, a loudness arrow from soft to LOUD, a right ear of Os and a left ear of Xs plot point by point, 'lower = a bigger loss', and the normal band to 25 dB.",
			"params": {},
			"cues": [{"t": 0.8, "sfx": "whoosh", "pitch": 1.2, "vol_db": -14.0}, {"t": 5.8, "sfx": "pop", "vol_db": -12.0}, {"t": 7.2, "sfx": "pop", "pitch": 1.1, "vol_db": -12.0}],
		},
		{
			"id": "look", "set": "fb_look", "title": "Look before you beep", "duration": 10.0,
			"captions": ["Before any beep, look in both ears with the otoscope.",
				"Is the canal clear? Does the eardrum look healthy? Then we test."],
			"caption_at": [0.3, 3.4],
			"teaches": "Otoscopy first: check the canal is clear and the eardrum looks normal before testing.",
			"board": "An otoscope tilts in from the left; its view opens on the right: a pink canal, a pearly eardrum with its cone of light. Two chips tick in turn: 'Canal clear?' and 'Eardrum OK?'. Then a big chip: Look before you beep!",
			"params": {"checks": ["Canal clear?", "Eardrum OK?"]},
			"cues": [{"t": 1.2, "sfx": "whoosh", "vol_db": -14.0}, {"t": 3.8, "sfx": "ding", "vol_db": -14.0}, {"t": 5.4, "sfx": "ding", "pitch": 1.1, "vol_db": -14.0}],
		},
		{
			"id": "ladder", "set": "fb_ladder", "title": "Down 10, up 5", "duration": 12.0,
			"captions": ["Heard it? Go down 10 dB. Missed it? Come up 5.",
				"Heard twice on the way up? That's the threshold. Store it!"],
			"caption_at": [0.3, 6.0],
			"teaches": "The search the game teaches: heard, down 10 dB; missed, up 5 dB; store the softest level heard twice on the way up.",
			"board": "A trail of dots like the AudiOtron's: 40 heard, 30 heard, 20 missed, 25 missed, 30 heard (up #1), 20 missed, 25 missed, 30 heard (up #2), each step labelled -10 or +5; filled = heard, hollow = missed. Then 'Heard twice going up: STORE 30 dB!'.",
			"params": {"start": 40, "heard": [true, true, false, false, true, false, false, true]},
			"cues": [{"t": 1.0, "sfx": "blip", "vol_db": -16.0}, {"t": 2.0, "sfx": "blip", "pitch": 0.9, "vol_db": -16.0}, {"t": 5.0, "sfx": "blip", "pitch": 1.1, "vol_db": -16.0}, {"t": 8.0, "sfx": "blip", "pitch": 1.1, "vol_db": -16.0}, {"t": 9.4, "sfx": "stamp", "vol_db": -12.0}],
		},
		{
			"id": "bow", "set": "fb_bow", "title": "That's a wrap", "duration": 7.0,
			"captions": ["Path, chart, look, ladder. Ooh, a knock! Places, trainee!"],
			"teaches": "Recap: the beep's path, the chart, look first, down 10 up 5.",
			"board": "The little note and Hoot bow; the curtains close; THE END?; two knocks: places, trainee, a patient!",
			"params": {},
			"cues": [{"t": 0.4, "sfx": "fanfare", "pitch": 1.2, "vol_db": -16.0}, {"t": 3.6, "sfx": "thunk", "pitch": 1.3, "vol_db": -12.0}, {"t": 3.9, "sfx": "thunk", "pitch": 1.3, "vol_db": -12.0}],
		},
	],
}
