extends RefCounted
## Hoot's tune-up movie, "The Tune-Up" (docs/TUNEUP.md §5). Plays at the start of Day 15 before Gus
## arrives (story/level_tuneup.gd, the &"explainer" phase, as Day 5 plays its party movie: Hoot's
## one-line announcement the first time, a replay offer once watched); replay from Day 15's pause menu
## or the title's "Hoot's Movies". DATA ONLY: the scenes are drawn by story/case_movies/tuneup_sets.gd.
## Facts (Steve reviews): new aids make everyday sounds loud at first, and the brain gets used to them
## over the first few weeks; a sound that stays sharp gets the loud highs softened, never the whole
## aid. The aids log hours worn a day (the datalog); the goal is all waking hours. A whistle is
## feedback: amplified sound leaking out and back into the mics; a hug or a cap bounces more of it
## back. The feedback test plays a test sound to map that path so the aid can cancel it. A
## noisy-places program points the mics forward and calms the noise; with the talker in front and the
## crowd behind it helps, but it never erases the crowd. The diary's numbers are Gus's own
## (TuneDesk.DATALOG_HOURS: mean 3.5, the goal line at 12). Visual only: nothing loud ever plays.

const MOVIE: Dictionary = {
	"id": "tuneup",
	"title": "Hoot's tune-up movie",
	"subtitle": "The Tune-Up",
	"chapter": "gus_tune",
	"narrator": "Hoot",
	"stage": "res://story/case_movies/tuneup_sets.gd",
	"seen_at": "crowd",
	"scenes": [
		{
			"id": "open", "set": "tu_open", "title": "Today's mystery", "duration": 12.0,
			"captions": ["Hoot's Movie Matinee! Today's mystery: why do new hearing aids need a second visit?",
				"The answer: a TUNE-UP. Real life shows what the fitting room can't.",
				"Meet Gus's brain, back from years of quiet."],
			"caption_at": [0.3, 4.6, 8.8],
			"teaches": "What the movie answers: a fitting is tuned at follow-ups, from what real life shows.",
			"board": "Curtains open on a marquee card HOOT'S TUNE-UP MOVIE / The Tune-Up, a little hearing aid with a spanner beside the title; it holds 8 s with two question chips. Then Gus's brain pops in, a pink blob with a face and headphones-shaped ears; Hoot waves.",
			"params": {"card_hold": 8.0, "questions": ["Why is everything LOUD at first?", "What fixes each complaint?"]},
			"cues": [{"t": 0.2, "sfx": "fanfare", "vol_db": -14.0}, {"t": 2.0, "sfx": "pop", "vol_db": -10.0}, {"t": 4.6, "sfx": "pop", "pitch": 1.1, "vol_db": -10.0}, {"t": 8.6, "sfx": "pop", "pitch": 0.9, "vol_db": -10.0}],
		},
		{
			"id": "brain", "set": "tu_brain", "title": "Loud at first", "duration": 14.0,
			"captions": ["Years of quiet, then suddenly: the fridge! The paper! The teaspoon!",
				"Loud at first. Over a few weeks, the brain learns to file them away.",
				"If one stays sharp, we soften just the loud highs. Not the whole aid."],
			"caption_at": [0.3, 5.0, 9.6],
			"teaches": "Everyday sounds seem loud with new aids; the brain gets used to them over a few weeks; a sharp sound that stays gets the loud highs softened, not the whole aid turned down.",
			"board": "The brain in the middle, eyes wide. Three sound icons pop in around it, big and red with zigzag lines: FRIDGE (hum lines), PAPER (crackle), TEASPOON (clang). A calendar flips WEEK 1, 2, 3 and the icons shrink to calm grey, filed into a drawer marked 'normal'. Then a slider panel: LOUD HIGHS dips a notch (green tick), WHOLE AID stays put.",
			"params": {"weeks": 3, "sounds": ["FRIDGE", "PAPER", "TEASPOON"]},
			"cues": [{"t": 0.6, "sfx": "pop", "pitch": 0.8, "vol_db": -12.0}, {"t": 1.3, "sfx": "pop", "pitch": 1.0, "vol_db": -12.0}, {"t": 2.0, "sfx": "pop", "pitch": 1.2, "vol_db": -12.0}, {"t": 5.6, "sfx": "click", "vol_db": -12.0}, {"t": 6.4, "sfx": "click", "vol_db": -12.0}, {"t": 7.2, "sfx": "click", "vol_db": -12.0}, {"t": 10.6, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}],
		},
		{
			"id": "diary", "set": "tu_diary", "title": "The aid's diary", "duration": 11.0,
			"captions": ["The aids keep a diary: every hour they're worn, every day.",
				"A little wear, a little practice. All waking hours is the goal."],
			"caption_at": [0.3, 5.4],
			"teaches": "Hearing aids log the hours they are worn (the datalog); the brain adapts with practice, so the goal is all waking hours.",
			"board": "A hearing aid opens a tiny diary. Fourteen bars grow one by one (Gus's own hours; two zeros on bingo nights), a dashed green goal line at 12 hours: ALL WAKING HOURS. A chip: average 3.5. The brain on a treadmill jogs faster when the bars are taller.",
			"params": {"hours": [4.5, 4.0, 5.0, 3.5, 4.0, 0.0, 4.5, 4.0, 3.5, 5.0, 4.5, 4.0, 0.0, 2.5], "goal": 12.0, "max": 14.0},
			"cues": [{"t": 0.6, "sfx": "whoosh", "pitch": 1.2, "vol_db": -14.0}, {"t": 4.2, "sfx": "ding", "vol_db": -12.0}],
		},
		{
			"id": "whistle", "set": "tu_whistle", "title": "The whistle", "duration": 13.0,
			"captions": ["A whistle is the aid hearing itself: sound leaks out and loops back in.",
				"Hugs and caps bounce more sound back. WHEEE!",
				"The feedback test maps that loop, so the aid can cancel it."],
			"caption_at": [0.3, 4.8, 8.4],
			"teaches": "Feedback: amplified sound leaks out and back into the microphones; a hug or a cap bounces more back; the feedback test maps the path so the aid cancels it.",
			"board": "A giant hearing aid in an ear, a mic on top. A dotted orange loop runs from the dome out of the ear and back into the mic, round and round, faster; WHEEE! letters wobble. A big cap swings down over the ear and the loop thickens. Then a TEST card: the aid plays a little test chirp, traces the loop in blue, and stamps a red X on it: SILENCE (a green tick).",
			"params": {},
			"cues": [{"t": 5.6, "sfx": "chirp", "pitch": 1.6, "vol_db": -18.0}, {"t": 8.8, "sfx": "chirp", "pitch": 1.1, "vol_db": -16.0}, {"t": 10.6, "sfx": "stamp", "vol_db": -10.0}],
		},
		{
			"id": "crowd", "set": "tu_crowd", "title": "A noisy hall", "duration": 13.0,
			"captions": ["In a crowd, a noisy-places program points the mics forward and calms the chatter.",
				"Face the talker, back to the crowd. It helps, but it can't erase the crowd."],
			"caption_at": [0.3, 6.4],
			"teaches": "A noisy-places program uses forward-facing microphones and noise reduction; with the talker in front and the crowd behind it helps, but it never removes the noise.",
			"board": "Gus in the middle, a talker in front, a crowd behind with grey chatter bubbles. A green cone grows from his aids toward the talker; the chatter bubbles behind fade by half (never vanish). A chip: 'Helps! Not magic.'",
			"params": {},
			"cues": [{"t": 1.2, "sfx": "pop", "pitch": 0.9, "vol_db": -12.0}, {"t": 2.6, "sfx": "whoosh", "pitch": 1.1, "vol_db": -14.0}, {"t": 7.0, "sfx": "ding", "pitch": 1.1, "vol_db": -12.0}],
		},
		{
			"id": "bow", "set": "tu_bow", "title": "That's a wrap", "duration": 7.0,
			"captions": ["Ask where it's hard, read the diary, fix one thing at a time. Here's Gus!"],
			"teaches": "Recap: open question, datalog, one fix per complaint.",
			"board": "The brain, the hearing aid and Hoot bow; the curtains close; THE END?; two knocks: places, trainee, a patient!",
			"params": {},
			"cues": [{"t": 0.4, "sfx": "fanfare", "pitch": 1.2, "vol_db": -16.0}, {"t": 3.6, "sfx": "thunk", "pitch": 1.3, "vol_db": -12.0}, {"t": 3.9, "sfx": "thunk", "pitch": 1.3, "vol_db": -12.0}],
		},
	],
}
