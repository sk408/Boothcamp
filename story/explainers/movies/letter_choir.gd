extends RefCounted
## Hoot's word movie, "The Letter Choir" (Day 4, Nora): the S0a STUB (CONTRACTS.md §9.10.7, §9.20).
## Three "card" scenes (data only, no stage code) so Movies.validate() passes before Day 4 exists.
## The Day 4 builder replaces this whole file with the real movie (W5a: the data, every scene
## playing as its card; W5b: the "stage" line and its sets script). Until the "nora" chapter is in
## Game.CHAPTERS no replay list shows it (Movies.replay_ids()) and no level plays it.

const MOVIE: Dictionary = {
	"id": "letter_choir",
	"title": "Hoot's word movie",
	"subtitle": "The Letter Choir",
	"chapter": "nora",
	"narrator": "Hoot",
	"scenes": [
		{
			"id": "mystery", "set": "card", "title": "Today's mystery", "duration": 16.0,
			"captions": ["Hoot's Movie Matinee! Today's mystery: why can loud-enough words still come out mushy?"],
			"teaches": "What the movie is about: hearing words clearly once they are loud enough.",
			"board": "A cream title card pops in; three starred lines appear one by one; a music note bobs beside them; a little Hoot waves bottom-left.",
			"params": {"heading": "Hoot's word movie", "icon": "note", "tint": "#fff4c2",
				"lines": ["Coming soon to this booth", "Words, not beeps", "How clear is loud enough?"]},
			"cues": [{"t": 0.2, "sfx": "pop", "pitch": 1.1, "vol_db": -10.0}],
		},
		{
			"id": "clear", "set": "card", "title": "Soft versus clear", "duration": 16.0,
			"captions": ["Beeps say how SOFT you can hear. Words say how CLEAR it is once it's loud enough."],
			"teaches": "Tones find the softest level; a word list scores clarity at a comfortable level.",
			"board": "The same card style: three lines pop in; Hoot waves.",
			"params": {"heading": "One list, one ear", "icon": "hoot", "tint": "#fff4c2",
				"lines": ["Words at a comfy loudness", "The patient says each one back", "Every word counts the same"]},
			"cues": [{"t": 0.2, "sfx": "pop", "pitch": 1.0, "vol_db": -10.0}],
		},
		{
			"id": "soon", "set": "card", "title": "Coming soon", "duration": 16.0,
			"captions": ["The full show plays on Day 4, with Nora. Grab some popcorn!"],
			"teaches": "The real movie comes with Day 4.",
			"board": "The same card style: two lines pop in; a soft ding at the end.",
			"params": {"heading": "The full show: Day 4", "icon": "note", "tint": "#fff4c2",
				"lines": ["Nora's visit brings the rest", "Popcorn is on Hoot"]},
			"cues": [{"t": 6.0, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}],
		},
	],
}
