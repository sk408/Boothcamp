extends RefCounted
## Hoot's audiogram movie, "Slopes, Notches & Cookie Bites" (clinical review C12). Plays just before
## the player names the chart's shape on their first case day (any of Days 6 to 12), after Hoot's
## lead-in (story/level_case.gd CASE_MOVIES); replay from the pause menu on any case day, or the title.
## DATA ONLY: the scenes are drawn by this movie's own sets, story/case_movies/shapes_sets.gd.
## Facts (Steve reviews), the game's own rules (autoload/clinic_rules.gd classify_shape and
## hearing_type, docs/CASES.md §5): pitch runs low to high, left to right, and softer sounds sit
## higher; red O is the right ear, blue X the left; 25 dB HL or better is normal; sloping (poorer
## highs, the most common chart in a dispensing clinic), rising (poorer lows), flat; the noise notch
## dips at 3 to 6 kHz and recovers at 8 kHz; the cookie bite dips in the middle and often runs in
## families; bone conduction bypasses the outer and middle ear: bone with air = sensorineural, bone
## normal with air down = conductive, both down with a gap = mixed; a gap over 10 dB counts, and an
## air-bone gap of 15 dB or more at 500, 1000 and 2000 Hz is a red flag (refer).

const MOVIE: Dictionary = {
	"id": "shapes",
	"title": "Hoot's audiogram movie",
	"subtitle": "Slopes, Notches & Cookie Bites",
	"chapter": "rocco",
	"also_chapters": ["marina", "dash", "ginger", "barnaby", "skye", "morgan"],
	"narrator": "Hoot",
	"stage": "res://story/case_movies/shapes_sets.gd",
	"seen_at": "door",
	"scenes": [
		{
			"id": "open", "set": "sh_open", "title": "Today's mystery", "duration": 11.0,
			"captions": ["Today's mystery: a chart full of Os and Xs. What is its shape trying to tell us?",
				"The answer: the shape shows WHICH pitches are hard; bone shows WHERE the trouble is. Let's read!"],
			"caption_at": [0.3, 5.0],
			"teaches": "What the movie answers: an audiogram's shape shows which pitches are hard to hear; bone conduction shows where the trouble is.",
			"board": "Curtains open on a marquee card HOOT'S AUDIOGRAM MOVIE / Slopes, Notches & Cookie Bites, a choc-chip cookie with a bite beside the title; it holds 8 s with two question chips. Then a big red O, a big blue X and the cookie hop in with faces; Hoot waves.",
			"params": {"card_hold": 8.0, "questions": ["What does the shape say?", "What do the bone marks add?"]},
			"cues": [{"t": 0.2, "sfx": "fanfare", "vol_db": -14.0}, {"t": 2.0, "sfx": "pop", "vol_db": -10.0}, {"t": 4.6, "sfx": "pop", "pitch": 1.1, "vol_db": -10.0}, {"t": 8.3, "sfx": "pop", "pitch": 0.9, "vol_db": -10.0}, {"t": 8.55, "sfx": "pop", "pitch": 1.1, "vol_db": -10.0}, {"t": 8.8, "sfx": "pop", "pitch": 1.3, "vol_db": -10.0}],
		},
		{
			"id": "grid", "set": "sh_grid", "title": "Reading the chart", "duration": 15.0,
			"captions": ["Pitch runs low to high, left to right. Soft sounds sit at the top, loud below.",
				"Red O: right ear. Blue X: left. Lower on the chart means a bigger loss.",
				"Anything up top, in the band down to 25 dB? That's normal hearing."],
			"caption_at": [0.3, 5.6, 10.4],
			"teaches": "How to read an audiogram: frequency from low to high across, softer levels higher up; red O for the right ear, blue X for the left; lower means a bigger loss; 25 dB HL or better is normal.",
			"board": "An empty audiogram (250 to 8k across, -10 to 120 dB down). An arrow runs under it from low pitch (a big note) to high pitch (a small note); another runs down its left side from soft to LOUD. Red Os pop in one by one and join up, then blue Xs; chips O = right ear and X = left ear. A pointer: lower = a bigger loss. Then the band from the top down to 25 dB glows mint: normal.",
			"params": {},
			"cues": [{"t": 0.2, "sfx": "pop", "vol_db": -12.0}, {"t": 0.8, "sfx": "whoosh", "pitch": 1.2, "vol_db": -16.0}, {"t": 1.0, "sfx": "note", "pitch": 0.7, "vol_db": -16.0}, {"t": 1.8, "sfx": "note", "pitch": 1.5, "vol_db": -16.0}, {"t": 2.8, "sfx": "whoosh", "pitch": 0.8, "vol_db": -16.0}, {"t": 5.8, "sfx": "pop", "vol_db": -12.0}, {"t": 7.2, "sfx": "pop", "pitch": 1.1, "vol_db": -12.0}, {"t": 8.8, "sfx": "boing", "pitch": 0.8, "vol_db": -14.0}, {"t": 10.6, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}],
		},
		{
			"id": "slopes", "set": "sh_slopes", "title": "Slopes and flats", "duration": 12.0,
			"captions": ["Sloping: good lows, poor highs. A ski slope, and the most common chart dispensers see.",
				"Rising: the lows are worse, the highs better. Flat: about the same everywhere."],
			"caption_at": [0.3, 6.0],
			"teaches": "Three shapes the game names: sloping (poorer highs; the most common chart in a dispensing clinic), rising (poorer lows) and flat (about the same at every pitch).",
			"board": "A red O line slopes down to the right; a little skier in a bobble hat whooshes down it (WHEEE!). Pointers: good lows, poor highs. The line tips into a rising one (chip RISING) and the skier skis back down it to the left (poor lows, better highs); then it levels out (chip FLAT) and the skier glides along: about the same everywhere.",
			"params": {},
			"cues": [{"t": 0.4, "sfx": "pop", "vol_db": -12.0}, {"t": 1.0, "sfx": "whoosh", "pitch": 0.8, "vol_db": -14.0}, {"t": 4.6, "sfx": "squeak", "pitch": 1.3, "vol_db": -14.0}, {"t": 6.3, "sfx": "pop", "pitch": 1.1, "vol_db": -12.0}, {"t": 7.0, "sfx": "whoosh", "vol_db": -14.0}, {"t": 9.3, "sfx": "pop", "pitch": 1.2, "vol_db": -12.0}],
		},
		{
			"id": "notch", "set": "sh_notch", "title": "The noise notch", "duration": 12.0,
			"captions": ["The noise notch: a dip around 3 to 6 kHz that climbs back up at 8k.",
				"Years of loud noise, like drums or machines, carve it out. Earplugs protect what's left!"],
			"caption_at": [0.3, 6.0],
			"teaches": "The noise notch: a dip at 3 to 6 kHz that recovers at 8 kHz, from years of loud noise; hearing protection keeps it from growing.",
			"board": "A blue X line sits in the normal range, with dashed 3k and 6k lines. A bass drum on the right goes BOOM four times; purple sound waves fly at the line and each hit digs the dip around 4k deeper. Chips: NOISE NOTCH, back up at 8k! Then two foam earplugs with faces pop up: EARPLUGS! Hoot gasps at the booms, then cheers.",
			"params": {},
			"cues": [{"t": 1.2, "sfx": "thunk", "pitch": 0.6, "vol_db": -8.0}, {"t": 1.9, "sfx": "thunk", "pitch": 0.6, "vol_db": -8.0}, {"t": 2.6, "sfx": "thunk", "pitch": 0.6, "vol_db": -8.0}, {"t": 3.3, "sfx": "thunk", "pitch": 0.6, "vol_db": -8.0}, {"t": 4.2, "sfx": "pop", "vol_db": -12.0}, {"t": 5.0, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}, {"t": 8.4, "sfx": "pop", "pitch": 1.2, "vol_db": -12.0}, {"t": 8.8, "sfx": "sparkle", "vol_db": -14.0}],
		},
		{
			"id": "cookie", "set": "sh_cookie", "title": "The cookie bite", "duration": 11.0,
			"captions": ["Cookie bite: the middle pitches dip, like someone took a CHOMP out of the chart.",
				"It often runs in families, and the middle pitches carry lots of speech."],
			"caption_at": [0.3, 5.8],
			"teaches": "The cookie bite: the middle pitches are poorer than the lows and the highs; it often runs in families, and the middle pitches carry much of speech.",
			"board": "A red O line sits flat at the edge of normal. A cookie flies in; CHOMP! A bite vanishes from the cookie and the line dips in the middle at the same moment, scalloped bite marks and crumbs falling. Chip: COOKIE BITE! Then a framed family portrait pops up (runs in families) and a pointer at the dip: lots of speech lives here!",
			"params": {},
			"cues": [{"t": 0.6, "sfx": "whoosh", "pitch": 1.2, "vol_db": -16.0}, {"t": 2.0, "sfx": "thunk", "pitch": 1.4, "vol_db": -10.0}, {"t": 2.2, "sfx": "pop", "pitch": 1.6, "vol_db": -14.0}, {"t": 2.6, "sfx": "pop", "vol_db": -12.0}, {"t": 6.0, "sfx": "pop", "pitch": 1.1, "vol_db": -12.0}, {"t": 8.0, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}],
		},
		{
			"id": "door", "set": "sh_door", "title": "What bone adds", "duration": 17.0,
			"captions": ["Air beeps come in the front door: outer and middle ear. Bone beeps skip straight to the cochlea.",
				"Bone matches air: sensorineural, the inner ear. Bone normal, air down: conductive, something blocks.",
				"Both down, with a gap? Mixed. A 15 dB gap or more at 500 to 2k: red flag!"],
			"caption_at": [0.3, 5.8, 11.4],
			"teaches": "What bone conduction adds: it bypasses the outer and middle ear. Bone with air = sensorineural; bone normal, air down = conductive; both down with a gap = mixed; an air-bone gap of 15 dB or more at 500, 1000 and 2000 Hz is a red flag (refer).",
			"board": "A house in cross-section: the front room is the outer and middle ear, the back room holds the cochlea snail. Air notes come in the front door and through to the snail; a buzzer on the back wall sends bone buzz straight through to it. A small chart (O air, < bone) appears: sensorineural (bone with air, the snail asleep); then a JAM jar sticks in the front door, the notes stop at it, bone jumps up to normal and yellow gap bars appear: conductive; then the snail sleeps again and both lines drop with the gap: mixed. A red flag plants itself at the gap: 15+ gap at 500, 1k, 2k: RED FLAG.",
			"params": {},
			"cues": [{"t": 0.2, "sfx": "pop", "vol_db": -12.0}, {"t": 0.9, "sfx": "note", "vol_db": -16.0}, {"t": 2.6, "sfx": "click", "vol_db": -12.0}, {"t": 2.9, "sfx": "blip", "pitch": 0.6, "vol_db": -16.0}, {"t": 5.6, "sfx": "pop", "pitch": 1.1, "vol_db": -12.0}, {"t": 8.6, "sfx": "thunk", "pitch": 1.1, "vol_db": -10.0}, {"t": 9.2, "sfx": "pop", "vol_db": -12.0}, {"t": 11.8, "sfx": "pop", "pitch": 0.9, "vol_db": -12.0}, {"t": 14.0, "sfx": "stamp", "pitch": 1.2, "vol_db": -12.0}],
		},
		{
			"id": "bow", "set": "sh_bow", "title": "That's a wrap", "duration": 6.0,
			"captions": ["Shape says which pitches, bone says where. Now, back to that chart!"],
			"teaches": "Recap: the shape says which pitches are hard; bone says where the trouble is.",
			"board": "The O, the X and the cookie bow; Hoot bows; THE END?; the curtains close. Back to our patient!",
			"params": {},
			"cues": [{"t": 0.4, "sfx": "fanfare", "pitch": 1.2, "vol_db": -16.0}, {"t": 3.6, "sfx": "ding", "pitch": 1.1, "vol_db": -12.0}],
		},
	],
}
