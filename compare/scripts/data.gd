extends RefCounted
## Loads the JSON data files. Nothing in the code holds a spec or a price: edit data/*.json.

const FLAG_PASS := ["yes", "some"]

var aids: Array = []          # aids.json "aids", in display order
var meta: Dictionary = {}     # aids.json "meta" (specs_as_of, notes)
var rows: Array = []          # rows.json "rows"
var groups: Array = []        # rows.json "groups"
var needs: Array = []         # rows.json "needs"
var prices: Dictionary = {}   # prices.json "prices" by aid id
var prices_meta: Dictionary = {}
var sources: Dictionary = {}  # sources.json by source id
var source_order: Array = []
var errors: PackedStringArray = []


func load_all(dir: String = "res://data") -> bool:
	var a: Variant = _read(dir.path_join("aids.json"))
	var r: Variant = _read(dir.path_join("rows.json"))
	var p: Variant = _read(dir.path_join("prices.json"))
	var s: Variant = _read(dir.path_join("sources.json"))
	if a == null or r == null or p == null or s == null:
		return false
	aids = a.get("aids", [])
	meta = a.get("meta", {})
	rows = r.get("rows", [])
	groups = r.get("groups", [])
	needs = r.get("needs", [])
	prices = p.get("prices", {})
	prices_meta = p.get("meta", {})
	for src in s.get("sources", []):
		sources[src.id] = src
		source_order.append(src.id)
	return errors.is_empty()


func aid(id: String) -> Dictionary:
	for a in aids:
		if a.id == id:
			return a
	return {}


func row(id: String) -> Dictionary:
	for r in rows:
		if r.id == id:
			return r
	return {}


## The cell for one aid and one row: {v, src, status, note}. Prices come from prices.json.
func cell(a: Dictionary, field: String) -> Dictionary:
	if field == "price_pair" or field == "price_single":
		var p: Dictionary = prices.get(a.id, {})
		var key := "pair" if field == "price_pair" else "single"
		var e: Dictionary = p.get(key, {})
		if e.is_empty() or e.get("usd", null) == null:
			return {"v": "", "status": "unverified", "src": e.get("src", []), "note": e.get("note", "")}
		return {"v": "$%s" % _money(float(e.usd)), "status": e.get("status", "reported"),
				"src": e.get("src", []), "note": e.get("note", ""), "item": e.get("item", "")}
	var c: Variant = a.get("specs", {}).get(field, null)
	if c == null:
		return {"v": "", "status": "unverified", "src": [], "note": ""}
	return c


## True when the aid meets the need ("yes" or "some" for a flag).
func meets(a: Dictionary, need: String) -> bool:
	var c := cell(a, need)
	return str(c.get("v", "")) in FLAG_PASS


func missing_needs(a: Dictionary, wanted: Array) -> Array:
	var out := []
	for n in wanted:
		if not meets(a, n):
			out.append(n)
	return out


func need_label(id: String) -> String:
	for n in needs:
		if n.id == id:
			return n.label
	return id


static func flag_text(v: String) -> String:
	match v:
		"yes":
			return "Yes"
		"no":
			return "No"
		"some":
			return "Some styles"
		"later":
			return "Promised by update"
	return "Not verified"


static func _money(x: float) -> String:
	var whole := int(floor(x))
	var cents := int(round((x - whole) * 100.0))
	var s := str(whole)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return "%s%s.%02d" % [s, out, cents]


func _read(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		errors.append("cannot open " + path)
		return null
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK:
		errors.append("%s line %d: %s" % [path, j.get_error_line(), j.get_error_message()])
		return null
	return j.data
