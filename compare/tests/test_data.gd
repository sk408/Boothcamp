extends SceneTree
## Data checks: every spec has a status and real sources, verified values cite a primary source, flags hold
## known words, prices parse. Run: godot --headless --path . -s res://tests/test_data.gd  (exit 0 = all good)

const Data := preload("res://scripts/data.gd")
const FLAGS := ["yes", "no", "some", "later", ""]
const STATUSES := ["verified", "reported", "unverified"]

var fails: PackedStringArray = []
var checks := 0


func _initialize() -> void:
	var d := Data.new()
	_ok(d.load_all(), "data files load: " + ", ".join(d.errors))
	_ok(d.aids.size() == 5, "five aids")
	var fields := []
	for r in d.rows:
		_ok(r.has_all(["id", "group", "kind", "label", "plain", "help"]), "row has its keys: %s" % r.get("id"))
		fields.append(r.id)
	for n in d.needs:
		if not fields.has(n.id):
			fields.append(n.id)
	for a in d.aids:
		_ok(a.has_all(["id", "name", "model_styles", "shell", "good_for", "specs"]), "aid has its keys: " + a.get("id", "?"))
		for f in fields:
			if f.begins_with("price_"):
				continue
			_ok(a.specs.has(f), "%s has %s" % [a.id, f])
		for f in a.specs:
			var c: Dictionary = a.specs[f]
			var where := "%s.%s" % [a.id, f]
			_ok(c.get("status") in STATUSES, where + " status")
			var r := d.row(f)
			if r.get("kind", "") == "flag" or f == "in_canal":
				_ok(c.get("v") in FLAGS, where + " is a known flag word")
			if c.status != "unverified":
				_ok(str(c.v) != "", where + " has a value")
				_ok(not c.src.is_empty(), where + " cites a source")
			else:
				_ok(str(c.v) == "", where + " unverified holds no value")
			var primary := false
			for s in c.get("src", []):
				_ok(d.sources.has(s), where + " source exists: " + s)
				if d.sources.has(s) and d.sources[s].kind in ["costco", "maker"]:
					primary = true
			if c.status == "verified":
				_ok(primary, where + " verified cites a maker or Costco page")
		_ok(d.prices.has(a.id), a.id + " has a price entry")
		for key in ["pair", "single"]:
			var p: Dictionary = d.prices.get(a.id, {}).get(key, {})
			_ok(p.has("usd") and p.has("checked"), "%s %s price has usd and checked" % [a.id, key])
			if p.get("usd") != null:
				_ok(typeof(p.usd) == TYPE_FLOAT and p.usd > 0, "%s %s price is a number" % [a.id, key])
				_ok(not p.get("src", []).is_empty(), "%s %s price cites a source" % [a.id, key])
		for s in a.model_styles:
			_ok(s in ["ric", "bte", "itc", "cic"], "%s style %s is drawn" % [a.id, s])
	for s in d.sources.values():
		_ok(s.url.begins_with("https://"), s.id + " has an https url")
		_ok(s.kind in ["costco", "maker", "third"], s.id + " kind")
	_ok(Data._money(1599.99) == "1,599.99", "money format")
	for f in fails:
		print("FAIL ", f)
	print("COMPARE_TESTS %d checks, %d failed" % [checks, fails.size()])
	quit(0 if fails.is_empty() else 1)


func _ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails.append(what)
