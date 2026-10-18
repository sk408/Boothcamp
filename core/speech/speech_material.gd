class_name SpeechMaterial
extends RefCounted
## SpeechMaterial: loads the game's own speech lists (CONTRACTS.md §9.2, docs/SPEECH.md §1).
##
## Every list lives in res://core/speech/material/<list_id>.json and was written for Booth Camp: no
## list, order or recording is copied; every word is checked against ASHA (1988) Appendices A-C and
## CID W-1 (the guard in core/tests/test_speech_core.gd). A spondee is a two-part word said with equal
## stress on both parts, chosen because such words are about equally easy to hear. Shapes:
##   {"id", "title", "kind": "spondee" | "monosyllable" | "sentence", "original": true, "items": [...]}
##   spondee item:      {"id", "text", "parts": [first, second], "mishears": [funny wrong words]}
##   monosyllable item: {"id", "text", "key_sound", "foils": [3 words that differ in the key sound]}
##   sentence item:     {"id", "text", "key_words": [5 words]}
## Recordings are optional: res://assets/speech/<list_id>/<item_id>.wav (§7 of docs/SPEECH.md). WAV only:
## the voice decodes it into the test ear's channel, which a streamed .ogg could not do.

const DIR := "res://core/speech/material/"
const RECORDINGS_DIR := "res://assets/speech/"
const KINDS: Array[StringName] = [&"spondee", &"monosyllable", &"sentence"]
const RECORDING_EXTS: PackedStringArray = ["wav"]

static var _cache: Dictionary = {}


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
			&"sentence":
				if (d.get("key_words", []) as Array).size() != 5:
					out.append("%s/%s: needs 5 key words" % [id, iid])
	return out


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
