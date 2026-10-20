extends RefCounted
## Hoot's tympanometer movie, "The Eardrum Trampoline" (clinical review C12). Plays just before the
## tympanometer step on the player's first case day (any of Days 6 to 11), after Hoot's lead-in
## (story/level_case.gd CASE_MOVIES); replay from the pause menu on any case day, or the title.
## DATA ONLY: the scenes are drawn by this movie's own sets, story/case_movies/tymp_sets.gd.
## Facts (Steve reviews), the game's own numbers (core/cases/case_rules.gd, docs/CASES.md §5): look in
## the ear first; a soft tip seals the canal's entrance gently, never pushed; a 226 Hz probe tone; the
## pump sweeps +200 to -400 daPa; the drum moves most where the canal pressure matches the middle
## ear's, which is the curve's peak; normal box -100 to +50 daPa and 0.3 to 1.7 mL; types A, As
## (shallow, stiff), Ad (very tall, floppy), C (peak at negative pressure), B (flat); a flat B is read
## with the canal volume: under 0.6 mL blocked (wax, or the probe against the canal wall), 0.6 to 2.0
## (the adult band) often fluid, over 2.0 a hole in the drum or an open ear tube; always compare both
## ears; a tympanogram shows how the middle ear moves, not how well someone hears.

const MOVIE: Dictionary = {
	"id": "tymp",
	"title": "Hoot's tympanometer movie",
	"subtitle": "The Eardrum Trampoline",
	"chapter": "rocco",
	"also_chapters": ["marina", "dash", "ginger", "barnaby", "skye"],
	"narrator": "Hoot",
	"stage": "res://story/case_movies/tymp_sets.gd",
	"seen_at": "compare",
	"scenes": [
		{
			"id": "open", "set": "ty_open", "title": "Today's mystery", "duration": 11.0,
			"captions": ["Today's mystery: beeps show how well someone hears. What shows how the eardrum moves?",
				"The answer: the tympanometer! It bounces a tone off the eardrum. Let's jump in."],
			"caption_at": [0.3, 5.0],
			"teaches": "What the movie answers: beeps show how well someone hears; the tympanometer shows how the eardrum moves.",
			"board": "Curtains open on a marquee card HOOT'S TYMPANOMETER MOVIE / The Eardrum Trampoline, a tiny trampoline with a bouncing buddy beside the title; it holds 8 s with two question chips. Then Drummy (the eardrum as a trampoline with a face) bounces a little buddy; Hoot waves.",
			"params": {"card_hold": 8.0, "questions": ["What can't the beeps show?", "How do we read the curve?"]},
			"cues": [{"t": 0.2, "sfx": "fanfare", "vol_db": -14.0}, {"t": 2.0, "sfx": "pop", "vol_db": -10.0}, {"t": 4.6, "sfx": "pop", "pitch": 1.1, "vol_db": -10.0}, {"t": 8.4, "sfx": "boing", "pitch": 1.1, "vol_db": -12.0}, {"t": 9.0, "sfx": "boing", "pitch": 1.2, "vol_db": -14.0}],
		},
		{
			"id": "seal", "set": "ty_seal", "title": "Look, then seal", "duration": 11.0,
			"captions": ["First, look in the ear. Then a soft tip gently seals the canal's entrance. Never push!",
				"Too small: it leaks, hisss. Too big: it won't go in. Just right: sealed!"],
			"caption_at": [0.3, 5.8],
			"teaches": "Look in the ear first; the probe's soft tip seals the canal's entrance gently, never pushed in; the tip must fit to seal.",
			"board": "A cut-away ear canal with the eardrum at the end. An otoscope peeks in (its light fills the canal: Look first!). The probe glides up with a medium tip and rests at the entrance (Gentle: just the entrance), then backs off. A small tip leaks (hisss!), a big tip bonks at the entrance (won't fit!), the medium tip seals with a mint ring: SEALED!",
			"params": {},
			"cues": [{"t": 0.4, "sfx": "pop", "vol_db": -10.0}, {"t": 1.0, "sfx": "click", "vol_db": -12.0}, {"t": 2.8, "sfx": "pop", "pitch": 1.1, "vol_db": -12.0}, {"t": 6.6, "sfx": "whoosh", "pitch": 1.4, "vol_db": -16.0}, {"t": 8.5, "sfx": "thunk", "pitch": 1.1, "vol_db": -10.0}, {"t": 9.8, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}, {"t": 10.0, "sfx": "sparkle", "vol_db": -14.0}],
		},
		{
			"id": "sweep", "set": "ty_sweep", "title": "The pressure sweep", "duration": 13.0,
			"captions": ["The probe hums a 226 Hz tone and pumps the air pressure from +200 down to -400.",
				"The drum bounces best where the pressure matches both sides. That's the peak of the curve!"],
			"caption_at": [0.3, 6.4],
			"teaches": "A 226 Hz probe tone and a pressure sweep from +200 to -400 daPa; the eardrum moves most where the canal pressure matches the middle ear's: the peak of the tympanogram.",
			"board": "Drummy bounces the buddy; a probe hums little cyan notes (226 Hz probe tone). The pump sweeps: a chip counts the canal pressure down from +200 daPa while the middle ear stays at 0; the bounce grows as they meet (MATCH!) and shrinks after. On the right the tympanogram traces right to left and peaks at 0: PEAK: the pressures match.",
			"params": {},
			"cues": [{"t": 1.0, "sfx": "note", "pitch": 1.0, "vol_db": -16.0}, {"t": 2.4, "sfx": "click", "vol_db": -12.0}, {"t": 4.0, "sfx": "whoosh", "pitch": 0.6, "vol_db": -16.0}, {"t": 6.8, "sfx": "boing", "pitch": 1.2, "vol_db": -14.0}, {"t": 7.4, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}],
		},
		{
			"id": "types", "set": "ty_types", "title": "Five shapes", "duration": 16.0,
			"captions": ["Type A: a mountain inside the box. Normal pressure, normal movement. A happy middle ear!",
				"As: a shallow hill, stiff. Ad: a skyscraper, floppy. C: shifted left, negative pressure.",
				"B: flat as a pancake. No peak at all. Now check the canal volume!"],
			"caption_at": [0.3, 5.4, 10.6],
			"teaches": "The tympanogram types: A (peak inside the normal box), As (shallow: stiff), Ad (very tall: floppy), C (peak at negative pressure), B (flat: read it with the canal volume).",
			"board": "One big tympanogram with the green normal box (-100 to +50 daPa, 0.3 to 1.7 mL). The red curve morphs: a mountain with a flag (A), a low hill (stiff), a skyscraper with lit windows (floppy), a mountain sliding left (negative pressure), then flat with a pancake on it. Five thumbnails fill in along the bottom, the current one lit.",
			"params": {},
			"cues": [{"t": 0.4, "sfx": "pop", "vol_db": -12.0}, {"t": 5.6, "sfx": "pop", "pitch": 0.9, "vol_db": -12.0}, {"t": 7.2, "sfx": "pop", "pitch": 1.3, "vol_db": -12.0}, {"t": 8.8, "sfx": "whoosh", "pitch": 1.2, "vol_db": -16.0}, {"t": 10.8, "sfx": "squeak", "pitch": 0.7, "vol_db": -16.0}],
		},
		{
			"id": "volume", "set": "ty_volume", "title": "Canal volume", "duration": 13.0,
			"captions": ["Flat B? Read the canal volume. Tiny, under 0.6 mL: wax, or the probe hits the wall.",
				"Normal, 0.6 to 2.0: often fluid behind the drum. Over 2.0: a hole or open ear tube."],
			"caption_at": [0.3, 6.4],
			"teaches": "A flat B is read with the canal volume: under 0.6 mL blocked (wax, or the probe against the wall); 0.6 to 2.0 mL (the adult band) often fluid behind the eardrum; over 2.0 mL a hole in the eardrum or an open ear tube.",
			"board": "A measuring cup with lines at 0.6 and 2.0 mL. The level rises: tiny (a wax plug icon, card TINY: wax, or the probe on the wall), normal (an eardrum with bubbles, card NORMAL: fluid behind the eardrum), big (an eardrum with a hole and a tube, card BIG: a hole, or an open ear tube). The zone the level sits in glows.",
			"params": {},
			"cues": [{"t": 1.8, "sfx": "blip", "pitch": 0.9, "vol_db": -12.0}, {"t": 7.0, "sfx": "blip", "pitch": 1.1, "vol_db": -12.0}, {"t": 10.0, "sfx": "blip", "pitch": 1.3, "vol_db": -12.0}],
		},
		{
			"id": "compare", "set": "ty_compare", "title": "Both ears", "duration": 8.0,
			"captions": ["Always compare both ears. And remember: a tymp shows how the drum moves, not hearing."],
			"teaches": "Always compare the two ears; a tympanogram shows how the middle ear moves, not how well someone hears.",
			"board": "Two tympanograms side by side: RIGHT EAR in red (a mountain), LEFT EAR in blue (flat). Hoot gasps at the difference. Sign: MOVES, not HEARS!",
			"params": {},
			"cues": [{"t": 0.3, "sfx": "pop", "vol_db": -12.0}, {"t": 0.8, "sfx": "pop", "pitch": 1.1, "vol_db": -12.0}, {"t": 1.6, "sfx": "boing", "pitch": 0.8, "vol_db": -14.0}, {"t": 4.6, "sfx": "stamp", "pitch": 1.2, "vol_db": -12.0}],
		},
		{
			"id": "bow", "set": "ty_bow", "title": "That's a wrap", "duration": 6.0,
			"captions": ["Seal, sweep, then read the shape and the volume. Now, back to our patient!"],
			"teaches": "Recap: seal, sweep, read the shape and the canal volume.",
			"board": "Drummy and the buddy bow; Hoot bows; THE END?; the curtains close. Back to our patient!",
			"params": {},
			"cues": [{"t": 0.4, "sfx": "fanfare", "pitch": 1.2, "vol_db": -16.0}, {"t": 3.6, "sfx": "ding", "pitch": 1.1, "vol_db": -12.0}],
		},
	],
}
