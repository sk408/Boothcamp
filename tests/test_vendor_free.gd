extends TestCase
## Guards the "everything original" rule (CONTRACTS.md §1.3): no vendor names in any string
## literal a player could see, and no vendor font. Comments and the internal setting ids
## "otosuite" / "affinity" (lowercase, required by the settings contract) are allowed.

const BANNED: PackedStringArray = ["OTOsuite", "Otosuite", "Affinity", "Interacoustics", "Otometrics", "Tahoma"]
const EXTS: PackedStringArray = [".gd", ".tscn", ".tres", ".cfg"]


func test_no_vendor_names_in_strings() -> void:
	var files: PackedStringArray = []
	_collect("res://", files)
	assert_true(files.size() > 10, "found files")
	var quoted := RegEx.create_from_string("\"[^\"\\n]*\"")
	for path in files:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var line := lines[i]
			var code := _strip_comment(line) if path.ends_with(".gd") else line
			for m: RegExMatch in quoted.search_all(code):
				for word in BANNED:
					if m.get_string().contains(word):
						fail("%s:%d player-facing vendor name '%s': %s" % [path, i + 1, word, line.strip_edges()])


## The line up to its first '#' that is outside a string literal.
func _strip_comment(line: String) -> String:
	var in_str := false
	for i in line.length():
		var ch := line[i]
		if ch == "\"" and (i == 0 or line[i - 1] != "\\"):
			in_str = not in_str
		elif ch == "#" and not in_str:
			return line.substr(0, i)
	return line


func _collect(dir: String, out: PackedStringArray) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		for e in EXTS:
			if f.ends_with(e):
				out.append(dir.path_join(f))
	for sub in d.get_directories():
		if not sub.begins_with(".") and sub != "build" and sub != "tests":  # tests are not shipped
			_collect(dir.path_join(sub), out)
