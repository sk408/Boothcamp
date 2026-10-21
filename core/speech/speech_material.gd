class_name SpeechMaterial
extends RefCounted
## SpeechMaterial: loads the game's own speech lists (CONTRACTS.md §9.2, docs/SPEECH.md §1).
##
## Every list lives in res://core/speech/material/<list_id>.json and was written for Booth Camp: no
## list, order or recording is copied; every word is checked against ASHA (1988) Appendices A-C and
## CID W-1 (the guard in core/tests/test_speech_core.gd). A spondee is a two-part word said with equal
## stress on both parts, chosen because such words are about equally easy to hear. Word lists 1-4
## (Day 4, words_<n>.json) were written fresh too: no word list, order or rhyme set comes from a
## published word test (NU-6, W-22, CID W-1, PB-50, AB / Boothroyd, NU-CHIPS, WIPI or the Modified
## Rhyme Test), and their guard (core/tests/test_speech_wrs.gd) checks only our own lists. Shapes:
##   {"id", "title", "kind": "spondee" | "monosyllable" | "sentence", "original": true, "items": [...]}
##   spondee item:      {"id", "text", "parts": [first, second], "mishears": [funny wrong words]}
##   monosyllable item: {"id", "text", "key_sound", "foils": [3 words that differ in the key sound]}
##     (Day 4) optional: "chunks": [[letters, sound id or "" for silent], ...] that spell the word,
##     "plural": "socks", "asides": {foil in lowercase: Hoot's side line}
##   sentence item:     {"id", "text", "key_words": [5 words]}
##     (Day 5) optional: "mishears": [5 groups of wrong words], "key_sounds": [5 groups of sound ids]
## Recordings are optional: res://assets/speech/<list_id>/<item_id>.wav (§7 of docs/SPEECH.md). WAV only:
## the voice decodes it into the test ear's channel, which a streamed .ogg could not do.

const DIR := "res://core/speech/material/"
const RECORDINGS_DIR := "res://assets/speech/"
const KINDS: Array[StringName] = [&"spondee", &"monosyllable", &"sentence"]
const RECORDING_EXTS: PackedStringArray = ["wav"]

static var _cache: Dictionary = {}
static var _word_re: RegEx = null


## The whole list ({} when missing or broken; the error is logged once).
static func load_list(list_id: String) -> Dictionary:
	if _cache.has(list_id):
		return _cache[list_id]
	var path := DIR + list_id + ".json"
	var out: Dictionary = {}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			out = parsed
		else:
			push_error("SpeechMaterial: %s is not a JSON object" % path)
	else:
		push_error("SpeechMaterial: no speech list " + path)
	_cache[list_id] = out
	return out


## The list's items, in order (typed copies).
static func items(list_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it: Variant in load_list(list_id).get("items", []):
		if it is Dictionary:
			out.append((it as Dictionary).duplicate(true))
	return out


static func item(list_id: String, item_id: String) -> Dictionary:
	for it: Dictionary in items(list_id):
		if String(it.get("id", "")) == item_id:
			return it
	return {}


static func title(list_id: String) -> String:
	return String(load_list(list_id).get("title", list_id))


static func kind(list_id: String) -> StringName:
	return StringName(String(load_list(list_id).get("kind", "")))


## Every list id in the material folder, sorted.
static func list_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for f: String in ResourceLoader.list_directory(DIR):
		if f.get_extension() == "json":
			out.append(f.get_basename())
	out.sort()
	return out


## Problems with a list (empty = valid). Used by tests.
static func validate(list: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var id := String(list.get("id", ""))
	if id.is_empty():
		out.append("missing id")
	if not bool(list.get("original", false)):
		out.append("%s: not marked original" % id)
	var k := StringName(String(list.get("kind", "")))
	if not KINDS.has(k):
		out.append("%s: unknown kind %s" % [id, k])
	var its: Variant = list.get("items", [])
	if not its is Array or (its as Array).is_empty():
		out.append("%s: no items" % id)
		return out
	var seen := {}
	for it: Variant in its:
		if not it is Dictionary:
			out.append("%s: an item is not an object" % id)
			continue
		var d: Dictionary = it
		var iid := String(d.get("id", ""))
		if iid.is_empty() or String(d.get("text", "")).is_empty():
			out.append("%s: item without id or text" % id)
		if seen.has(iid):
			out.append("%s: duplicate item %s" % [id, iid])
		seen[iid] = true
		match k:
			&"spondee":
				var parts: Variant = d.get("parts", [])
				if not parts is Array or (parts as Array).size() != 2:
					out.append("%s/%s: a spondee needs two parts" % [id, iid])
				elif String((parts as Array)[0]) + String((parts as Array)[1]) != String(d.get("text", "")):
					out.append("%s/%s: parts do not spell the word" % [id, iid])
				if (d.get("mishears", []) as Array).is_empty():
					out.append("%s/%s: no mishears" % [id, iid])
			&"monosyllable":
				if String(d.get("key_sound", "")).is_empty():
					out.append("%s/%s: no key_sound" % [id, iid])
				if (d.get("foils", []) as Array).size() < 3:
					out.append("%s/%s: needs 3 foils" % [id, iid])
				_check_word_extras("%s/%s" % [id, iid], d, out)
			&"sentence":
				if (d.get("key_words", []) as Array).size() != 5:
					out.append("%s/%s: needs 5 key words" % [id, iid])
				_check_sentence_extras("%s/%s" % [id, iid], d, out)
	return out


## (Days 4-5) The words of a sentence as a scorer compares them: lowercase, punctuation stripped.
## An apostrophe or hyphen inside a word stays ("Don't drop Nan’s x-ray!" -> don't, drop, nan's,
## x-ray); a curly apostrophe counts as a straight one.
static func tokens(text: String) -> PackedStringArray:
	if _word_re == null:
		_word_re = RegEx.create_from_string("[a-z0-9]+(?:['-][a-z0-9]+)*")
	var out := PackedStringArray()
	for m: RegExMatch in _word_re.search_all(text.to_lower().replace("’", "'")):
		out.append(m.get_string())
	return out


## (Day 4) The optional word-list fields (CONTRACTS.md §9.11.3): `chunks` spell the word with known
## sound ids and one carries the key sound; `asides` are keyed by a foil in lowercase; `plural`
## differs from the word and its foils.
static func _check_word_extras(where: String, d: Dictionary, out: PackedStringArray) -> void:
	var text := String(d.get("text", ""))
	var key := String(d.get("key_sound", ""))
	var foils := PackedStringArray()
	var given: Variant = d.get("foils", [])
	if given is Array:
		for f: Variant in given:
			foils.append(String(f).to_lower())
	if d.has("chunks"):
		var chunks: Variant = d["chunks"]
		if not chunks is Array or (chunks as Array).is_empty():
			out.append("%s: chunks must be a list of [letters, sound]" % where)
		else:
			var spelled := ""
			var carries_key := false
			for c: Variant in chunks:
				if not c is Array or (c as Array).size() != 2:
					out.append("%s: a chunk is not [letters, sound]" % where)
					continue
				var sound := String((c as Array)[1])
				spelled += String((c as Array)[0])
				if sound != "" and not SpeechRules.SOUND_CUES.has(sound):
					out.append("%s: unknown chunk sound %s" % [where, sound])
				carries_key = carries_key or (sound != "" and sound == key)
			if spelled != text:
				out.append("%s: chunks spell %s, not %s" % [where, spelled, text])
			if not carries_key:
				out.append("%s: no chunk carries the key sound %s" % [where, key])
	if d.has("asides"):
		var asides: Variant = d["asides"]
		if not asides is Dictionary:
			out.append("%s: asides must be {foil: line}" % where)
		else:
			for k: Variant in asides:
				if not foils.has(String(k)) or String(k) != String(k).to_lower():
					out.append("%s: aside %s is not a foil in lowercase" % [where, k])
				if not (asides as Dictionary)[k] is String:
					out.append("%s: the aside for %s is not text" % [where, k])
	if d.has("plural"):
		var plural: Variant = d["plural"]
		if not plural is String or (plural as String).is_empty():
			out.append("%s: plural must be a word" % where)
		elif (plural as String).to_lower() == text.to_lower() or foils.has((plural as String).to_lower()):
			out.append("%s: plural %s repeats the word or a foil" % [where, plural])


## (Day 5) The party-sentence fields (CONTRACTS.md §9.11.3): the key words are found in order among
## tokens(text); `mishears` (optional) has 5 groups, none repeating its key word; `key_sounds`
## (optional) has 5 groups of known sound ids.
static func _check_sentence_extras(where: String, d: Dictionary, out: PackedStringArray) -> void:
	var words: Array = []
	var given: Variant = d.get("key_words", [])
	if given is Array:
		words = given
	var toks := tokens(String(d.get("text", "")))
	var at := 0
	for w: Variant in words:
		var i := toks.find(String(w).strip_edges().to_lower(), at)
		if i < 0:
			out.append("%s: key word %s is not in the sentence (in order)" % [where, w])
		else:
			at = i + 1
	if d.has("mishears"):
		var groups: Variant = d["mishears"]
		if not groups is Array or (groups as Array).size() != SpeechRules.SIN_KEY_WORDS:
			out.append("%s: needs 5 mishear groups" % where)
		else:
			for g in (groups as Array).size():
				var group: Variant = (groups as Array)[g]
				if not group is Array or (group as Array).is_empty():
					out.append("%s: mishear group %d needs a word" % [where, g + 1])
					continue
				var kw := String(words[g]).strip_edges().to_lower() if g < words.size() else ""
				for m: Variant in group:
					if String(m).strip_edges().to_lower() == kw:
						out.append("%s: mishear %s repeats its key word" % [where, m])
	if d.has("key_sounds"):
		var sounds: Variant = d["key_sounds"]
		if not sounds is Array or (sounds as Array).size() != SpeechRules.SIN_KEY_WORDS:
			out.append("%s: needs 5 key_sounds groups" % where)
		else:
			for group: Variant in sounds:
				if not group is Array:
					out.append("%s: a key_sounds group is not a list" % where)
					continue
				for s: Variant in group:
					if not SpeechRules.SOUND_CUES.has(String(s)):
						out.append("%s: unknown key sound %s" % [where, s])


## The recording for an item, or "" when there is none (the murmur plays instead).
static func recording_path(list_id: String, item_id: String) -> String:
	for ext: String in RECORDING_EXTS:
		var p := "%s%s/%s.%s" % [RECORDINGS_DIR, list_id, item_id, ext]
		if ResourceLoader.exists(p) or FileAccess.file_exists(p):
			return p
	return ""


## Half of a spondee as the patient says it: "...bow?" (second part) or "Rain...?" (first part).
static func half_word(it: Dictionary, first_part: bool) -> String:
	var parts: Array = it.get("parts", [])
	if parts.size() != 2:
		return "...?"
	if first_part:
		return String(parts[0]).capitalize() + "...?"
	return "..." + String(parts[1]) + "?"
