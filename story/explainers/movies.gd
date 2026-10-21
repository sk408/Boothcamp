extends RefCounted
## Hoot's movies: the registry of in-engine animated explainers (v4, CONTRACTS.md §3.4).
## A movie is DATA (a scene list) in story/explainers/movies/<id>.gd (`const MOVIE: Dictionary`);
## the player (story/explainers/explainer_player.tscn) types the captions, fires the cues and asks the
## stage (story/explainers/explainer_stage.gd) to animate each scene's "set". Adding a movie = one file
## in movies/ plus one line here (docs/ADDING_A_CHAPTER.md, "Hoot's movies"); a movie may bring
## its own scene sets (MOVIE.stage, story/explainers/explainer_sets.gd).
## Usage (story-internal): const Movies := preload("res://story/explainers/movies.gd")
##   Movies.movie("masking") -> Dictionary, Movies.for_chapter("bonnie") -> ["masking"],
##   Movies.replay_ids() -> every movie the replay lists show (not the "short" recaps)

const MOVIES: Dictionary = {
	"masking": "res://story/explainers/movies/masking.gd",
	"masking_recap": "res://story/explainers/movies/masking_recap.gd",
	"letter_choir": "res://story/explainers/movies/letter_choir.gd",
	"party_noise": "res://story/explainers/movies/party_noise.gd",
	## (cases, clinical review C12) Hoot's case movies, on every case day (also_chapters)
	"case_files": "res://story/explainers/movies/case_files.gd",
	"tymp": "res://story/explainers/movies/tymp.gd",
	"shapes": "res://story/explainers/movies/shapes.gd",
}
## Tests and dev tools only: more movies at run time, id -> a movie file path or the MOVIE
## Dictionary itself (tests/test_contracts_v4.gd adds fakes and clears it after). Never set by the game.
static var extra: Dictionary = {}
## Every caption line is a Hoot line: 18 words or fewer (like Hoot.MAX_WORDS for tips).
const MAX_CAPTION_WORDS := 18
## A movie should stay a short (CHAPTER2.md: about 60-100 s).
const MIN_TOTAL_S := 45.0
const MAX_TOTAL_S := 110.0
## A "short": true movie is a recap (5-30 s): played by its level, never listed for replay.
const SHORT_MIN_S := 5.0
const SHORT_MAX_S := 30.0
## Keys every scene must have. Optional: "title" (the scene's numbered chip on the screen),
## "caption_at" (seconds per caption, default spread evenly), "params" (set-specific),
## "cues" ([{t, sfx, pitch, vol_db}] Sfx stings, quiet), "board" (the animation brief, never shown).
## A scene needs no new stage code when it uses the generic set "card" (a title card from data:
## params {heading, lines, line_at, icon, hoot, tint}, see explainer_stage.gd _set_card()).
const SCENE_KEYS: Array[String] = ["id", "set", "duration", "captions", "teaches"]
const MOVIE_KEYS: Array[String] = ["id", "title", "subtitle", "chapter", "narrator", "scenes"]
## Optional movie keys: "seen_at" (the scene id that counts as seen, default the last), "short"
## (a recap: see SHORT_MIN_S), "stage" (the movie's own sets script, extending
## story/explainers/explainer_sets.gd: CONTRACTS.md §3.4), (cases) "also_chapters" (more
## Game.CHAPTERS ids whose pause menu lists it: a movie shared by several days).
## The generic "card" set: at most this many lines, each this many characters (they never wrap).
const CARD_MAX_LINES := 4
const CARD_MAX_CHARS := 36


static func ids() -> Array[String]:
	var out: Array[String] = []
	for k: String in MOVIES:
		out.append(k)
	for k: String in extra:
		if not out.has(k):
			out.append(k)
	return out


static func _source(id: String) -> Variant:
	if extra.has(id):
		return extra[id]
	return MOVIES.get(id, null)


static func has(id: String) -> bool:
	var src: Variant = _source(id)
	if src is Dictionary:
		return true
	return src is String and ResourceLoader.exists(String(src))


## The movie's data (a deep copy of its file's MOVIE const), {} when unknown.
static func movie(id: String) -> Dictionary:
	if not has(id):
		return {}
	var src: Variant = _source(id)
	if src is Dictionary:
		return (src as Dictionary).duplicate(true)
	var sc: Script = load(String(src)) as Script
	if sc == null:
		return {}
	var m: Variant = sc.get_script_constant_map().get("MOVIE", {})
	return (m as Dictionary).duplicate(true) if m is Dictionary else {}


## A recap ("short": true): played by its level, never listed for replay.
static func is_short(id: String) -> bool:
	return bool(movie(id).get("short", false))


## The movies a chapter (Game.CHAPTERS id) offers for replay, in registry order (recaps only with
## include_short). (cases) A movie's "also_chapters" list it there too.
static func for_chapter(chapter_id: String, include_short: bool = false) -> Array[String]:
	var out: Array[String] = []
	for id: String in ids():
		var m := movie(id)
		if chapters_of(m).has(chapter_id) and (include_short or not bool(m.get("short", false))):
			out.append(id)
	return out


## (cases) The chapter ids a movie belongs to: its "chapter", then its "also_chapters".
static func chapters_of(m: Dictionary) -> Array[String]:
	var out: Array[String] = [String(m.get("chapter", ""))]
	var more: Variant = m.get("also_chapters", [])
	if more is Array:
		for c: Variant in more:
			if not out.has(String(c)):
				out.append(String(c))
	return out


## (E19) The group a level joins when it can mask (the cases, Freestyle): its pause menu offers
## every replay movie, so Day 2's masking movie is one tap away.
const MASKING_LEVEL_GROUP := &"masking_level"


## The movies a level's pause menu offers: the chapter's own, or (E19) every replay movie when the
## level can mask. (cases) That holds even when the chapter has movies of its own (the case days'
## three, through "also_chapters"), so the masking movie stays one tap away there.
static func for_level(chapter_id: String, masks: bool) -> Array[String]:
	if masks:
		return replay_ids()
	return for_chapter(chapter_id)


## Every movie the replay lists show (the pause menu's and the title's "Hoot's Movies"): all but
## the recaps, in registry order. (Days 4-5) A movie whose chapter is not in Game.CHAPTERS yet (a
## stub registered before its day exists) is left out too, so nobody sees it before its day.
static func replay_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in ids():
		if not is_short(id) and not Game.chapter(String(movie(id).get("chapter", ""))).is_empty():
			out.append(id)
	return out


## The chapter's day label for the replay list ("Day 2"; "Days 6-12" with "also_chapters"), ""
## when unknown.
static func day_label(id: String) -> String:
	var days: Array[int] = []
	for cid: String in chapters_of(movie(id)):
		var c: Dictionary = Game.chapter(cid)
		if c.has("day"):
			days.append(int(c["day"]))
	if days.is_empty():
		return ""
	days.sort()
	return "Day %d" % days[0] if days[0] == days[-1] else "Days %d-%d" % [days[0], days[-1]]


## The movie's own set ids from its sets script (MOVIE.stage), [] when it has none.
static func own_sets(id: String) -> Array[StringName]:
	var out: Array[StringName] = []
	var path := String(movie(id).get("stage", ""))
	if path == "" or not ResourceLoader.exists(path):
		return out
	var sc := load(path) as GDScript
	if sc == null or not sc.can_instantiate():
		return out
	var o: Variant = sc.new()
	if o is Object and (o as Object).has_method("set_ids"):
		out.assign((o as Object).call("set_ids"))
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


## Problems with a movie's data ([] = fine): missing keys, unknown stage sets (known_sets: the
## stage's built-in SETS; the movie's own sets script adds its SETS), caption length, running time.
## tests/test_contracts_v4.gd runs it on every registered movie.
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
	if m.has("also_chapters") and not m["also_chapters"] is Array:
		bad.append("%s: also_chapters is a list of chapter ids" % id)
	var sets: Array = known_sets.duplicate()
	if m.has("stage"):
		var path := String(m["stage"])
		var mine := own_sets(id)
		if not ResourceLoader.exists(path):
			bad.append("%s: stage script %s not found" % [id, path])
		elif mine.is_empty():
			bad.append("%s: stage script %s is not an explainer_sets.gd with a SETS list" % [id, path])
		else:
			var probe: Object = (load(path) as GDScript).new()
			for sid: StringName in mine:
				if not probe.has_method("_set_%s" % sid):
					bad.append("%s: stage script has no _set_%s()" % [id, sid])
		if not sets.is_empty():
			sets.append_array(mine)
	if m.has("seen_at"):
		var found := false
		for sc: Dictionary in m.get("scenes", []):
			found = found or String(sc.get("id", "")) == String(m["seen_at"])
		if not found:
			bad.append("%s: seen_at %s is not a scene" % [id, m["seen_at"]])
	var seen: Dictionary = {}
	for sc: Dictionary in m.get("scenes", []):
		var sid := String(sc.get("id", "?"))
		for k: String in SCENE_KEYS:
			if not sc.has(k):
				bad.append("%s/%s: missing %s" % [id, sid, k])
		if seen.has(sid):
			bad.append("%s: two scenes called %s" % [id, sid])
		seen[sid] = true
		if not sets.is_empty() and not sets.has(StringName(String(sc.get("set", "")))):
			bad.append("%s/%s: unknown set %s" % [id, sid, sc.get("set", "")])
		var caps: Array = sc.get("captions", [])
		if caps.is_empty():
			bad.append("%s/%s: no caption" % [id, sid])
		for c: Variant in caps:
			if word_count(String(c)) > MAX_CAPTION_WORDS:
				bad.append("%s/%s: caption over %d words: %s" % [id, sid, MAX_CAPTION_WORDS, c])
		if float(sc.get("duration", 0.0)) < 3.0:
			bad.append("%s/%s: shorter than 3 s" % [id, sid])
		if String(sc.get("set", "")) == "card":
			var lines: Array = (sc.get("params", {}) as Dictionary).get("lines", [])
			if lines.size() > CARD_MAX_LINES:
				bad.append("%s/%s: a card shows %d lines at most" % [id, sid, CARD_MAX_LINES])
			for ln: Variant in lines:
				if String(ln).length() > CARD_MAX_CHARS:
					bad.append("%s/%s: card line over %d characters: %s" % [id, sid, CARD_MAX_CHARS, ln])
	var total := total_s(id)
	var lo := SHORT_MIN_S if bool(m.get("short", false)) else MIN_TOTAL_S
	var hi := SHORT_MAX_S if bool(m.get("short", false)) else MAX_TOTAL_S
	if total < lo or total > hi:
		bad.append("%s: %.0f s long (keep it %.0f-%.0f s)" % [id, total, lo, hi])
	return bad
