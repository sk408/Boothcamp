extends RefCounted
## Test fixture (tests/test_contracts_v4.gd): a tiny movie that brings its own scene sets through
## MOVIE.stage (CONTRACTS.md §3.4), plus one built-in set and one "card" scene. Registered only at
## test time through Movies.extra; tools: dev_explainer --extra-movie=res://tests/fixtures/fake_movie.gd.

const MOVIE: Dictionary = {
	"id": "fake_hook",
	"title": "A fake movie",
	"subtitle": "Its own sets",
	"chapter": "bonnie",
	"narrator": "Hoot",
	"short": true,
	"stage": "res://tests/fixtures/fake_movie_sets.gd",
	"scenes": [
		{"id": "word", "set": "fake_word", "title": "Its own set", "duration": 4.0,
			"captions": ["A set from the movie's own sets script."], "teaches": "the hook",
			"params": {"word": "HOOK!"}},
		{"id": "snail", "set": "fake_snail", "title": "Its own snail", "duration": 4.0,
			"captions": ["The stage's helpers and palette, from outside the stage."], "teaches": "the helpers",
			"params": {"word": "snail"}},
		{"id": "card", "set": "card", "title": "A data card", "duration": 4.0,
			"captions": ["And a no-code card."], "teaches": "the card",
			"params": {"heading": "No code", "lines": ["Just data"], "icon": "hoot"}},
	],
}
