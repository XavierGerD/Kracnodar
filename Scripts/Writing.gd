extends RefCounted

# Kracnodar written in its own script, the letters, diacritics, punctuation
# and numbers drawn in the Alphabet tab (glyphs.json). Its state is static: every script that preloads
# this shares one alphabet, and the Alphabet tab calls reload() after it saves.
#
# How a word is spelled:
# - each consonant is its letter;
# - a vowel after a consonant is that vowel's diacritic, on top of the
#   consonant's letter: "ga" is the letter for g with the diacritic for a;
# - any other vowel (one that starts a word, or follows a vowel, or a sign like
#   the dash) is that vowel's own letter;
# - a punctuation mark or a number drawn is written like a letter, and a vowel
#   after it is a letter too.
# What isn't drawn yet shows as an empty square: a letter, or a diacritic
# shrunk on top of its letter. A sign that isn't drawn (punctuation, digits)
# is left out.
#
# Words are drawn into textures, registered under a path of their own so that
# BBCode can show them: [img]res://writing/...[/img] (see image_path). Whole
# texts are laid out as polygons for the Sandbox and its exports (text_layout).

const Quill = preload("res://Scripts/Quill.gd")

const FILE = "glyphs.json"
const VOWELS = ["a", "e", "i", "o", "u"]
# Stands for a letter or diacritic not drawn yet.
const MISSING = [
	{"type": "line", "from": Vector2(0.25, 0.2), "to": Vector2(0.75, 0.2), "weight": 0.5},
	{"type": "line", "from": Vector2(0.75, 0.2), "to": Vector2(0.75, 0.8), "weight": 0.5},
	{"type": "line", "from": Vector2(0.75, 0.8), "to": Vector2(0.25, 0.8), "weight": 0.5},
	{"type": "line", "from": Vector2(0.25, 0.8), "to": Vector2(0.25, 0.2), "weight": 0.5},
]
const LETTER_GAP = 0.14  # em between two letters of a word
const SIDE = 0.06  # em of space at each end of a word
const SUPERSAMPLE = 4  # drawn this many times larger, then shrunk: smooth edges

static var _loaded = false
static var _settings = {}
static var _letters = {}  # sound -> strokes ("i/y" gives both sounds the letter); punctuation and numbers too
static var _marks = {}  # vowel -> its diacritic's strokes
static var _textures = {}  # image path -> ImageTexture, kept alive for BBCode
static var _sizes = {}  # image path -> [word, height in pixels, scale]
static var _shaped = {}  # word -> what word_shapes gives for it
# Working out a word's layout is slow (every taper is many pieces), and pages
# ask for it on every render, so it is kept until the alphabet changes:
static var _laid_out = {}  # word -> [what _layout gives, what it found missing]
static var _composed = {}  # [letter, diacritic] strokes -> [their layers, their ink]
static var _word_run = RegEx.create_from_string("\\S+")


# Reads glyphs.json again, and redraws every word already drawn.
static func reload() -> void:
	_loaded = true
	_settings = Quill.DEFAULTS.duplicate()
	_letters = {}
	_marks = {}
	_shaped = {}
	_laid_out = {}
	_composed = {}
	var path = Dict.read_path(FILE)
	var data = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if data is Dictionary:
		var saved = data.get("settings", {})
		if saved is Dictionary:
			for key in Quill.DEFAULTS:
				if saved.has(key):
					_settings[key] = float(saved[key])
		_read_glyphs(data.get("letters", []), "sound", _letters)
		_read_glyphs(data.get("diacritics", []), "symbol", _marks)
		_read_glyphs(data.get("punctuation", []), "symbol", _letters)
		_read_glyphs(data.get("numbers", []), "symbol", _letters)
	for image_path in _textures:
		var size = _sizes[image_path]
		_textures[image_path].set_image(_draw_word(size[0], size[1], size[2]))


static func _read_glyphs(entries, key: String, into: Dictionary) -> void:
	if not entries is Array:
		return
	for entry in entries:
		if not entry is Dictionary:
			continue
		var strokes = []
		for saved in entry.get("strokes", []) if entry.get("strokes") is Array else []:
			var stroke = Quill.stroke_from_json(saved)
			if stroke != null:
				strokes.append(stroke)
		if strokes.is_empty():
			continue  # not drawn yet
		var written = str(entry.get(key, "")).to_lower()
		# "/" between sounds gives each the glyph ("i/y"), but a slash alone is the slash.
		for sound in [written] if written.strip_edges() == "/" else written.split("/", false):
			sound = sound.strip_edges()
			if sound != "" and not into.has(sound):
				into[sound] = strokes


static func _ensure_loaded() -> void:
	if not _loaded:
		reload()


# The letters of a word, as [{"letter": strokes, "mark": strokes or []}]:
# what gets drawn, one glyph after the other. What has nothing drawn for it
# goes in `missing`, if given: sound -> "letter", "diacritic", or "sign" (left out).
static func spell(word: String, missing = null) -> Array:
	_ensure_loaded()
	var text = word.to_lower()
	var longest = 1
	for sound in _letters.keys() + _marks.keys():
		longest = maxi(longest, sound.length())
	var glyphs = []
	var after_consonant = false
	var i = 0
	while i < text.length():
		# The longest sound that matches here: "i/y" style letters can be digraphs.
		var sound = text[i]
		for n in range(mini(longest, text.length() - i), 1, -1):
			var candidate = text.substr(i, n)
			if _letters.has(candidate) or _marks.has(candidate):
				sound = candidate
				break
		i += sound.length()
		var letter = sound.to_upper() != sound.to_lower()
		if not letter and not _letters.has(sound) and not _marks.has(sound):
			_note(missing, sound, "sign")
			continue
		if sound in VOWELS or (_marks.has(sound) and not _letters.has(sound)):
			if after_consonant:
				if not _marks.has(sound):
					_note(missing, sound, "diacritic")
				glyphs[-1]["mark"] = _marks.get(sound, MISSING)
				after_consonant = false
			else:
				if not _letters.has(sound):
					_note(missing, sound, "letter")
				glyphs.append({"letter": _letters.get(sound, MISSING), "mark": []})
		else:
			if not _letters.has(sound):
				_note(missing, sound, "letter")
			glyphs.append({"letter": _letters.get(sound, MISSING), "mark": []})
			# A sign (the dash) takes no diacritic: a vowel after it is a letter.
			after_consonant = letter
	return glyphs


static func _note(missing, sound: String, kind: String) -> void:
	if missing is Dictionary:
		missing[sound] = kind


# The top of the space a word is drawn in, in em: high enough for a diacritic
# over the tallest letter. The bottom is the letters' baseline, 1.
static func _top() -> float:
	return -(Quill.value(_settings, "diacritic_size") + Quill.value(_settings, "diacritic_gap") + 0.08)


# How wide a word is drawn, as a multiple of its height.
static func aspect(word: String) -> float:
	_ensure_loaded()
	return _layout(word)["width"] / (1.0 - _top())


# Each glyph's strokes (letter and diacritic composed), where it starts along
# the word, and the word's width, all in em. Kept (see _laid_out): don't change
# what it gives.
static func _layout(word: String, missing = null) -> Dictionary:
	word = word.to_lower()
	if not _laid_out.has(word):
		var found = {}
		var placed = []
		var x = SIDE
		for glyph in spell(word, found):
			var composed = _compose(glyph["letter"], glyph["mark"])
			placed.append({"layers": composed[0], "offset": x - composed[1].position.x})
			x += composed[1].size.x + LETTER_GAP
		_laid_out[word] = [{"glyphs": placed, "width": maxf(x - LETTER_GAP + SIDE, 2.0 * SIDE)}, found]
	if missing is Dictionary:
		missing.merge(_laid_out[word][1])
	return _laid_out[word][0]


# A letter with its diacritic, as [its layers (see Quill.compose), the box
# round their ink]. Kept (see _composed).
static func _compose(letter: Array, mark: Array) -> Array:
	var key = [letter, mark]
	if not _composed.has(key):
		var layers = Quill.compose(letter, mark, _settings)
		var ink = Rect2()
		for list in layers:
			if not list.is_empty():
				var bounds = Quill.ink_bounds(list, _settings)
				ink = bounds if ink.size == Vector2.ZERO else ink.merge(bounds)
		_composed[key] = [layers, ink]
	return _composed[key]


# How tall a line of the script is, in em: from above the diacritics down to
# the letters' baseline.
static func line_height() -> float:
	_ensure_loaded()
	return 1.0 - _top()


# A word's ink as polygons (convex, in em): its box starts at x = 0, its line
# at y = 0, with the letters' baseline at line_height(). Kept until the
# alphabet changes:
#   {"shapes": [PackedVector2Array], "strokes": the same polygons, a list per
#    stroke, in the order the quill sweeps them, "width": the box's, in em,
#    "missing": what has nothing drawn for it (see spell)}
static func word_shapes(word: String) -> Dictionary:
	_ensure_loaded()
	word = word.to_lower()
	if _shaped.has(word):
		return _shaped[word]
	var missing = {}
	var layout = _layout(word, missing)
	var shapes = []
	var strokes = []
	for glyph in layout["glyphs"]:
		var origin = Vector2(glyph["offset"], -_top())
		for list in glyph["layers"]:
			for stroke in list:
				var pieces = []
				for shape in Quill.shapes(stroke, _settings):
					if shape.size() >= 3:
						pieces.append(Transform2D(0.0, origin) * shape)
				if not pieces.is_empty():
					strokes.append(pieces)
					shapes.append_array(pieces)
	_shaped[word] = {"shapes": shapes, "strokes": strokes, "width": layout["width"], "missing": missing}
	return _shaped[word]


# A text in the script, as polygons in em: a line of the text to a line, its
# words (runs of anything but spaces) word_gap em apart, its lines
# line_spacing line heights apart, each aligned in the widest (align 0 left,
# 0.5 centred, 1 right). What it gives:
#   {"words": [{"word": as typed, "shapes": [PackedVector2Array],
#               "strokes": the same, a list per stroke (see word_shapes)}],
#    "bounds": the ink's box, "inked": whether there is any ink,
#    "box": the lines' box, from the first line's top to the last's baseline,
#    "missing": what has nothing drawn for it (see spell)}
static func text_layout(text: String, word_gap: float, line_spacing: float, align: float) -> Dictionary:
	_ensure_loaded()
	var height = line_height()
	var lines = []
	var widest = 0.0
	var missing = {}
	for line in text.strip_edges().split("\n"):
		var words = []
		var x = 0.0
		for found in _word_run.search_all(line):
			var shaped = word_shapes(found.get_string())
			missing.merge(shaped["missing"])
			if shaped["shapes"].is_empty():
				continue  # nothing but signs left out
			words.append({"word": found.get_string(), "x": x, "shaped": shaped})
			x += shaped["width"] + word_gap
		var width = x - word_gap if not words.is_empty() else 0.0
		lines.append({"words": words, "width": width})
		widest = maxf(widest, width)
	var placed = []
	var bounds = Rect2()
	var inked = false
	for i in lines.size():
		var line = lines[i]
		var y = i * height * line_spacing
		for word in line["words"]:
			var move = Transform2D(0.0, Vector2((widest - line["width"]) * align + word["x"], y))
			var shapes = []
			var strokes = []
			for pieces in word["shaped"]["strokes"]:
				var stroke = []
				for shape in pieces:
					var moved = move * shape
					stroke.append(moved)
					shapes.append(moved)
					for p in moved:
						if inked:
							bounds = bounds.expand(p)
						else:
							bounds = Rect2(p, Vector2.ZERO)
							inked = true
				strokes.append(stroke)
			placed.append({"word": word["word"], "shapes": shapes, "strokes": strokes})
	var box = Rect2(0.0, 0.0, widest, ((lines.size() - 1) * line_spacing + 1.0) * height)
	return {"words": placed, "bounds": bounds, "inked": inked, "box": box, "missing": missing}


# The path of a word drawn height pixels tall (scale times as many pixels,
# for a scaled-up window), for BBCode's [img]. Drawn once, then kept.
static func image_path(word: String, height: int, scale := 1.0) -> String:
	_ensure_loaded()
	word = word.to_lower()
	var path = "res://writing/%s/%d/%d.tex" % [word.uri_encode(), height, int(round(scale * 100))]
	if not _textures.has(path):
		var texture = ImageTexture.create_from_image(_draw_word(word, height, scale))
		texture.take_over_path(path)
		_textures[path] = texture
		_sizes[path] = [word, height, scale]
	return path


# The word in white on transparent, to be tinted where it's shown.
static func _draw_word(word: String, height: int, scale: float) -> Image:
	var layout = _layout(word)
	var top = _top()
	var pixels = maxf(1.0, round(height * scale))
	var em = pixels / (1.0 - top) * SUPERSAMPLE
	var size = Vector2i(ceili(layout["width"] * em / SUPERSAMPLE) * SUPERSAMPLE, int(pixels) * SUPERSAMPLE)
	var image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))  # white, so the edges shrink to white too
	for glyph in layout["glyphs"]:
		var origin = Vector2(glyph["offset"], -top) * em
		for list in glyph["layers"]:
			for stroke in list:
				for shape in Quill.shapes(stroke, _settings):
					_fill(image, shape, origin, em)
	image.shrink_x2()
	image.shrink_x2()
	return image


# Fills a convex polygon (in em) a pixel row at a time.
static func _fill(image: Image, shape: PackedVector2Array, origin: Vector2, em: float) -> void:
	var points = PackedVector2Array()
	var low = INF
	var high = -INF
	for p in shape:
		var q = origin + p * em
		points.append(q)
		low = minf(low, q.y)
		high = maxf(high, q.y)
	var count = points.size()
	if count < 3:
		return
	for row in range(maxi(0, floori(low)), mini(image.get_height(), ceili(high))):
		var y = row + 0.5
		var left = INF
		var right = -INF
		for i in count:
			var a = points[i]
			var b = points[(i + 1) % count]
			if (a.y <= y) != (b.y <= y):
				var x = a.x + (y - a.y) * (b.x - a.x) / (b.y - a.y)
				left = minf(left, x)
				right = maxf(right, x)
		var from = clampi(roundi(left), 0, image.get_width())
		var to = clampi(roundi(right), 0, image.get_width())
		if to > from:
			image.fill_rect(Rect2i(from, row, to - from, 1), Color.WHITE)
