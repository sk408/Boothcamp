extends RefCounted
## The drawings (data/art.json, made by tools/make_art.py), rasterized at the size they are shown at, so they stay
## sharp on phones. Keys: <style>-<shell> (a style worn on an ear) and product-<aid id>[-<style>] (the aid itself).
## Sketch.texture("ric-silver", 380.0) -> Texture2D (cached).

static var _svgs: Dictionary = {}
static var _cache: Dictionary = {}


static func has(key: String) -> bool:
	_load()
	return _svgs.has(key)


static func _load() -> void:
	if _svgs.is_empty():
		var f := FileAccess.open("res://data/art.json", FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_svgs = parsed.get("art", {})


static func texture(key: String, px_height: float) -> Texture2D:
	_load()
	if not _svgs.has(key):
		return null
	# The drawings are 380 px tall at scale 1 (the product drawings 380 x 380); round the scale so a few sizes
	# share one texture.
	var scale: float = clampf(snappedf(px_height / 380.0, 0.25), 0.25, 4.0)
	var ck := "%s@%s" % [key, scale]
	if not _cache.has(ck):
		var img := Image.new()
		if img.load_svg_from_string(String(_svgs[key]), scale) != OK:
			return null
		_cache[ck] = ImageTexture.create_from_image(img)
	return _cache[ck]
