extends RefCounted
## Hoot's movies: the registry of in-engine animated explainers (v4, CONTRACTS.md §3.4).
## A movie is DATA (a scene list) in story/explainers/movies/<id>.gd (`const MOVIE: Dictionary`);
## the player (story/explainers/explainer_player.tscn) types the captions, fires the cues and asks the
## stage (story/explainers/explainer_stage.gd) to animate each scene's "set". Adding a movie = one file
## in movies/ plus one line here (docs/ADDING_A_CHAPTER.md, "Hoot's movies").
## Usage (story-internal): const Movies := preload("res://story/explainers/movies.gd")
##   Movies.movie("masking") -> Dictionary, Movies.for_chapter("bonnie") -> ["masking"]

const MOVIES: Dictionary = {
	"masking": "res://story/explainers/movies/masking.gd",
}
## Every caption line is a Hoot line: 18 words or fewer (like Hoot.MAX_WORDS for tips).
const MAX_CAPTION_WORDS := 18
## A movie should stay a short (CHAPTER2.md: about 60-100 s).
const MIN_TOTAL_S := 45.0
const MAX_TOTAL_S := 110.0
## Keys every scene must have. Optional: "caption_at" (seconds per caption, default spread evenly),
## "params" (set-specific), "cues" ([{t, sfx, pitch, vol_db}] Sfx stings, quiet).
const SCENE_KEYS: Array[String] = ["id", "set", "duration", "captions", "teaches"]
const MOVIE_KEYS: Array[String] = ["id", "title", "subtitle", "chapter", "narrator", "scenes"]


static func ids() -> Array[String]:
	var out: Array[String] = []
	for k: String in MOVIES:
		out.append(k)
	return out


static func has(id: String) -> bool:
	return MOVIES.has(id) and ResourceLoader.exists(String(MOVIES[id]))


## The movie's data (a deep copy of its file's MOVIE const), {} when unknown.
static func movie(id: String) -> Dictionary:
	if not has(id):
		return {}
	var sc: Script = load(String(MOVIES[id])) as Script
	if sc == null:
		return {}
	var m: Variant = sc.get_script_constant_map().get("MOVIE", {})
	return (m as Dictionary).duplicate(true) if m is Dictionary else {}


## The movies a chapter (Game.CHAPTERS id) plays and offers for replay, in registry order.
static func for_chapter(chapter_id: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in ids():
		if String(movie(id).get("chapter", "")) == chapter_id:
			out.append(id)
	return out


static func title(id: String) -> String:
	return String(movie(id).get("title", id))


## The planned running time: the sum of the scene durations (the player may hold a scene a little
## longer so a slow reader can finish the caption).
static func total_s(id: String) -> float:
	var t := 0.0
	for sc: Dictionary in movie(id).get("scenes", []):
		t += float(sc.get("duration", 0.0))
	return t


static func word_count(text: String) -> int:
	return text.split(" ", false).size()


## Problems with a movie's data ([] = fine): missing keys, unknown stage sets, caption length,
## running time. tests/test_explainers.gd runs it on every registered movie.
static func validate(id: String, known_sets: Array = []) -> PackedStringArray:
	var bad: PackedStringArray = []
	var m := movie(id)
	if m.is_empty():
		return PackedStringArray(["%s: no movie data" % id])
	for k: String in MOVIE_KEYS:
		if not m.has(k):
			bad.append("%s: missing %s" % [id, k])
	if String(m.get("id", "")) != id:
		bad.append("%s: id says %s" % [id, m.get("id", "")])
	var seen: Dictionary = {}
	for sc: Dictionary in m.get("scenes", []):
		var sid := String(sc.get("id", "?"))
		for k: String in SCENE_KEYS:
			if not sc.has(k):
				bad.append("%s/%s: missing %s" % [id, sid, k])
		if seen.has(sid):
			bad.append("%s: two scenes called %s" % [id, sid])
		seen[sid] = true
		if not known_sets.is_empty() and not known_sets.has(StringName(String(sc.get("set", "")))):
			bad.append("%s/%s: unknown set %s" % [id, sid, sc.get("set", "")])
		var caps: Array = sc.get("captions", [])
		if caps.is_empty():
			bad.append("%s/%s: no caption" % [id, sid])
		for c: Variant in caps:
			if word_count(String(c)) > MAX_CAPTION_WORDS:
				bad.append("%s/%s: caption over %d words: %s" % [id, sid, MAX_CAPTION_WORDS, c])
		if float(sc.get("duration", 0.0)) < 3.0:
			bad.append("%s/%s: shorter than 3 s" % [id, sid])
	var total := total_s(id)
	if total < MIN_TOTAL_S or total > MAX_TOTAL_S:
		bad.append("%s: %.0f s long (keep it %.0f-%.0f s)" % [id, total, MIN_TOTAL_S, MAX_TOTAL_S])
	return bad
