extends Control

# A letter drawn small, for the list of letters in the Alphabet tab, or a
# letter with diacritics for its preview (fit, as they reach out of the em
# square).

const Quill = preload("res://Scripts/Quill.gd")
const GlyphCanvas = preload("res://Scripts/GlyphCanvas.gd")

var strokes: Array = []
var layers: Array = []  # more stroke lists drawn with it: the diacritics on a letter
var settings: Dictionary = {}
var fit = false  # scale to the em square and all the ink, not just the square


func _draw() -> void:
	var side = minf(size.x, size.y)
	var origin = (size - Vector2(side, side)) / 2.0
	draw_rect(Rect2(origin, Vector2(side, side)), GlyphCanvas.PAPER)
	var pad = side * 0.06
	var lists = [strokes] + layers
	var area = Rect2(0, 0, 1, 1)  # what to show, in em
	if fit:
		for list in lists:
			if not list.is_empty():
				area = area.merge(Quill.ink_bounds(list, settings))
	var extent = maxf(area.size.x, area.size.y)
	var scale = (side - 2.0 * pad) / extent
	# The area centred in the square.
	var at = origin + Vector2(pad, pad) + (Vector2(extent, extent) - area.size) * scale / 2.0 - area.position * scale
	for list in lists:
		Quill.draw_strokes(self, list, settings, at, scale, GlyphCanvas.INK)
