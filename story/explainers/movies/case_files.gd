extends RefCounted
## Hoot's case files movie, "Three Stamps and the Red Flags" (clinical review C12). Plays before the
## first patient knocks on the player's first case day (any of Days 6 to 12), after Hoot's lead-in
## (story/level_case.gd CASE_MOVIES); replay from the pause menu on any case day, or the title.
## DATA ONLY (like masking.gd): the player types the captions and fires the cues; the scenes are drawn
## by this movie's own sets, story/case_movies/case_files_sets.gd.
## Facts (Steve reviews), from the game's own rules (core/cases/case_rules.gd, docs/CASES.md §7):
## a dispenser spots patterns and refers, a doctor diagnoses; FIT = no red flag, ears match, and aids
## can help; REFER = a doctor soon (days to about two weeks), before any fitting; DOCTOR TODAY = a
## sudden hearing loss (over 72 hours or less, within the last 30 days, not explained by wax or the
## middle ear): same day, the emergency department if no ear doctor can see them today. The red flags
## are CaseRules.RED_FLAGS (FDA, 21 CFR 801.422). Every sound is a quiet Sfx sting.

const MOVIE: Dictionary = {
	"id": "case_files",
	"title": "Hoot's case files movie",
	"subtitle": "Three Stamps and the Red Flags",
	"chapter": "rocco",
	"also_chapters": ["marina", "dash", "ginger", "barnaby", "skye", "morgan"],
	"narrator": "Hoot",
	"stage": "res://story/case_movies/case_files_sets.gd",
	## Watching up to this scene counts as seen (a skip before it offers the movie again next case).
	"seen_at": "proof",
	"scenes": [
		{
			"id": "open", "set": "cf_open", "title": "Today's mystery", "duration": 11.0,
			"captions": ["Hoot's Case Files! Today's mystery: who gets hearing aids, and who sees a doctor first?",
				"The answer: spot the clues, then pick one of three stamps. Let's meet them!"],
			"caption_at": [0.3, 5.0],
			"teaches": "What the movie answers (who we fit, who sees a doctor and how soon): spot the clues, then one of three stamps.",
			"board": "Curtains swish open on a marquee card HOOT'S CASE FILES / Three Stamps & the Red Flags, with three tiny stamps beside the title; it holds 8 s while Hoot asks the question and names the answer, two question chips under it. Then the card flips away and three rubber stamps with faces (FIT mint, REFER sunny, DOCTOR TODAY coral) bounce in a row while Hoot waves.",
			"params": {"card_hold": 8.0, "questions": ["Who do we fit?", "Who sees a doctor, and how fast?"]},
			"cues": [{"t": 0.2, "sfx": "fanfare", "vol_db": -14.0}, {"t": 2.0, "sfx": "pop", "vol_db": -10.0}, {"t": 4.6, "sfx": "pop", "pitch": 1.1, "vol_db": -10.0}, {"t": 8.3, "sfx": "pop", "pitch": 0.9, "vol_db": -10.0}, {"t": 8.55, "sfx": "pop", "pitch": 1.0, "vol_db": -10.0}, {"t": 8.8, "sfx": "pop", "pitch": 1.1, "vol_db": -10.0}],
		},
		{
			"id": "detective", "set": "cf_detective", "title": "Clue spotters", "duration": 10.0,
			"captions": ["Dispensers are clue spotters: we test, spot patterns, and pass worries on.",
				"Naming the disease is a doctor's job. Ours is knowing when to send them."],
			"caption_at": [0.3, 5.0],
			"teaches": "A dispenser spots patterns and refers; a doctor makes the diagnosis.",
			"board": "Hoot in a deerstalker sweeps a magnifying glass over four clue cards pinned on a cork board (Ringing ears, Loud job, Both ears alike, No pain); a red string joins them. Then a friendly doctor in a white coat pops up on the right and an arrow runs from the board to her. Chips: YOU: spot and send / DOCTOR: names it.",
			"params": {},
			"cues": [{"t": 0.8, "sfx": "pop", "vol_db": -12.0}, {"t": 1.4, "sfx": "pop", "pitch": 1.1, "vol_db": -12.0}, {"t": 2.0, "sfx": "pop", "pitch": 1.2, "vol_db": -12.0}, {"t": 2.6, "sfx": "pop", "pitch": 1.3, "vol_db": -12.0}, {"t": 3.0, "sfx": "whoosh", "pitch": 1.3, "vol_db": -16.0}, {"t": 5.0, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}],
		},
		{
			"id": "stamps", "set": "cf_stamps", "title": "Three stamps", "duration": 15.0,
			"captions": ["FIT: no red flags, ears match, and hearing aids can help. Let's get listening!",
				"REFER: a doctor soon, within days to about two weeks, before any fitting.",
				"DOCTOR TODAY: a new sudden loss wax or fluid can't explain. Same day, or the emergency department."],
			"caption_at": [0.3, 5.3, 10.2],
			"teaches": "The three calls: FIT (no red flag, ears match, aids can help), REFER (a doctor within days to about two weeks, before fitting), DOCTOR TODAY (a new sudden loss not explained by wax or the middle ear: same day).",
			"board": "A traffic light at the top lights green, amber, red in turn. Each stamp hops in over a sheet of paper, slams down (squash) and leaves its mark: FIT, REFER, TODAY!; an info card pops under it and a little prop beside it (a hearing aid, a letter, a ringing alarm clock).",
			"params": {},
			"cues": [{"t": 0.6, "sfx": "pop", "vol_db": -12.0}, {"t": 2.0, "sfx": "stamp", "vol_db": -10.0}, {"t": 5.6, "sfx": "pop", "pitch": 1.1, "vol_db": -12.0}, {"t": 7.0, "sfx": "stamp", "pitch": 0.95, "vol_db": -10.0}, {"t": 10.5, "sfx": "pop", "pitch": 1.2, "vol_db": -12.0}, {"t": 11.9, "sfx": "stamp", "pitch": 0.9, "vol_db": -10.0}],
		},
		{
			"id": "flags", "set": "cf_flags", "title": "Red flags", "duration": 17.0,
			"captions": ["Red flags mean a doctor first: an odd-shaped ear, drainage, pain, or a canal full of wax.",
				"Dizziness, a sudden or changing loss, one ear worse, or a big air-bone gap.",
				"Any flag means REFER. A new sudden drop, with no wax or fluid to blame? DOCTOR TODAY!"],
			"caption_at": [0.3, 7.0, 12.4],
			"teaches": "The red flags (CaseRules.RED_FLAGS): deformity, drainage in the last 6 months, pain, a lot of wax or something in the canal, dizziness, a sudden or fluctuating loss, one ear worse, an air-bone gap of 15 dB or more at 500 to 2k. Any one means REFER; a new sudden drop that wax or the middle ear does not explain means DOCTOR TODAY.",
			"board": "Two washing lines between two poles. Red flags drop onto the lines one by one as Hoot names them, each with its short label (ODD-SHAPED EAR, DRAINAGE, EAR PAIN, LOTS OF WAX; then DIZZINESS, CHANGING LOSS, ONE EAR WORSE, AIR-BONE GAP). The flags flutter. Then two chips: Any flag: REFER, and New sudden drop: TODAY.",
			"params": {},
			"cues": [{"t": 0.8, "sfx": "pop", "pitch": 0.9, "vol_db": -14.0}, {"t": 1.9, "sfx": "pop", "pitch": 1.0, "vol_db": -14.0}, {"t": 3.0, "sfx": "pop", "pitch": 1.1, "vol_db": -14.0}, {"t": 4.1, "sfx": "pop", "pitch": 1.2, "vol_db": -14.0}, {"t": 7.4, "sfx": "pop", "pitch": 0.9, "vol_db": -14.0}, {"t": 8.6, "sfx": "pop", "pitch": 1.0, "vol_db": -14.0}, {"t": 9.8, "sfx": "pop", "pitch": 1.1, "vol_db": -14.0}, {"t": 11.0, "sfx": "pop", "pitch": 1.2, "vol_db": -14.0}, {"t": 12.6, "sfx": "ding", "pitch": 1.1, "vol_db": -12.0}],
		},
		{
			"id": "proof", "set": "cf_proof", "title": "Show the proof", "duration": 12.0,
			"captions": ["Every stamp needs proof. Pick the clue card that shows WHY, like a real case note.",
				"'Loves jazz' proves nothing. 'Left ear only' proves REFER. Case closed!"],
			"caption_at": [0.3, 6.8],
			"teaches": "Every call is backed by the clue that proves it (the game's present-the-evidence step).",
			"board": "A case file opens; a REFER stamp lands on it. A dashed PROOF? slot waits. Three clue cards sit below: Loves jazz flies up, bounces off the slot with a question mark; Left ear only flies up, clicks in and shines mint with sparkles and a PROOF! sticker. CASE CLOSED! sign.",
			"params": {},
			"cues": [{"t": 1.4, "sfx": "stamp", "vol_db": -10.0}, {"t": 7.4, "sfx": "boing", "pitch": 0.9, "vol_db": -12.0}, {"t": 9.2, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}, {"t": 9.3, "sfx": "sparkle", "vol_db": -12.0}, {"t": 10.2, "sfx": "fanfare", "pitch": 1.2, "vol_db": -16.0}],
		},
		{
			"id": "bow", "set": "cf_bow", "title": "That's a wrap", "duration": 7.0,
			"captions": ["Clues first, then the stamp, then the proof. Ooh, a knock! Places, trainee!"],
			"teaches": "Recap: clues, then the stamp, then the proof.",
			"board": "The three stamps bow; Hoot bows; THE END?; the curtains close. Two soft knocks: the next patient is here.",
			"params": {},
			"cues": [{"t": 0.4, "sfx": "fanfare", "pitch": 1.2, "vol_db": -16.0}, {"t": 3.6, "sfx": "thunk", "pitch": 0.8, "vol_db": -8.0}, {"t": 3.9, "sfx": "thunk", "pitch": 0.8, "vol_db": -8.0}],
		},
	],
}
