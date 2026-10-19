extends RefCounted
## Hoot's party movie, "The Party Problem" (Day 5, Marco): the S0a STUB (CONTRACTS.md §9.10.7, §9.20).
## Three "card" scenes (data only, no stage code) so Movies.validate() passes before Day 5 exists.
## The Day 5 builder replaces this whole file with the real movie (P5a: the data, every scene
## playing as its card; P5b: the "stage" line and its sets script). Until the "marco" chapter is in
## Game.CHAPTERS no replay list shows it (Movies.replay_ids()) and no level plays it. The crowd is
## only ever drawn, never played.

const MOVIE: Dictionary = {
	"id": "party_noise",
	"title": "Hoot's party movie",
	"subtitle": "The Party Problem",
	"chapter": "marco",
	"narrator": "Hoot",
	"scenes": [
		{
			"id": "mystery", "set": "card", "title": "Today's mystery", "duration": 16.0,
			"captions": ["Hoot's Movie Matinee! Today's mystery: why do some people get lost at a busy table?"],
			"teaches": "What the movie is about: following talk when other people talk too.",
			"board": "A peach title card pops in; three starred lines appear one by one; a dial bobs beside them; a little Hoot waves bottom-left.",
			"params": {"heading": "Hoot's party movie", "icon": "dial", "tint": "#ffe9c7",
				"lines": ["Coming soon to this booth", "Words with a crowd around", "Fine in quiet, lost at a party?"]},
			"cues": [{"t": 0.2, "sfx": "pop", "pitch": 1.1, "vol_db": -10.0}],
		},
		{
			"id": "crowd", "set": "card", "title": "Talk over chatter", "duration": 16.0,
			"captions": ["Sentences play over party chatter, and the talker gets a little softer each time."],
			"teaches": "A speech-in-noise list: the chatter stays put while the talker steps down.",
			"board": "The same card style: three lines pop in; Hoot waves.",
			"params": {"heading": "Sentences in the noise", "icon": "hoot", "tint": "#ffe9c7",
				"lines": ["The chatter stays the same", "The talker gets softer", "Count the key words caught"]},
			"cues": [{"t": 0.2, "sfx": "pop", "pitch": 1.0, "vol_db": -10.0}],
		},
		{
			"id": "soon", "set": "card", "title": "Coming soon", "duration": 16.0,
			"captions": ["The full show plays on Day 5, with Marco. Save me a seat!"],
			"teaches": "The real movie comes with Day 5.",
			"board": "The same card style: two lines pop in; a soft ding at the end.",
			"params": {"heading": "The full show: Day 5", "icon": "dial", "tint": "#ffe9c7",
				"lines": ["Marco's visit brings the rest", "Popcorn is on Hoot"]},
			"cues": [{"t": 6.0, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}],
		},
	],
}
