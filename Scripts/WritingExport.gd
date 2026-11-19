extends RefCounted

# A text in the script (laid out by Writing.text_layout) as an image file:
# PNG, drawn here a pixel row at a time, or SVG, its polygons as paths.
#
# Both draw it on the same canvas (see canvas): the ink, or the whole lines,
# with a margin round them, `em` pixels to the em. The ink is opaque; the
# background is a colour, or transparent when its alpha is 0.

const SUPERSAMPLE = 4  # PNGs are drawn this many times larger, then shrunk: smooth edges
const BAND_PIXELS = 1 << 22  # how many supersampled pixels are drawn at once
const MAX_SIDE = 16384  # pixels: the largest image made


# Where a layout goes on its image, in pixels:
#   {"size": Vector2i, "origin": where the layout's (0, 0) is, "em": pixels to the em}
# crop "ink" fits the image to the ink; "lines", to the whole lines (the same
# height for every word on one line) and the ink. The size is zero without ink.
static func canvas(layout: Dictionary, em: float, margin: float, crop := "ink") -> Dictionary:
	if not layout.get("inked", false):
		return {"size": Vector2i.ZERO, "origin": Vector2.ZERO, "em": em}
	var area: Rect2 = layout["bounds"]
	if crop == "lines":
		area = area.merge(layout["box"])
	var exact = area.size * em + Vector2(margin, margin) * 2.0
	var size = Vector2i(maxi(1, ceili(exact.x)), maxi(1, ceili(exact.y)))
	# Centred in the whole pixels.
	var origin = Vector2(margin, margin) - area.position * em + (Vector2(size) - exact) / 2.0
	return {"size": size, "origin": origin, "em": em}


static func too_big(canvas: Dictionary) -> bool:
	return canvas["size"].x > MAX_SIDE or canvas["size"].y > MAX_SIDE


# The layout drawn in `ink` on `background`, antialiased.
static func png(layout: Dictionary, canvas: Dictionary, ink: Color, background: Color) -> Image:
	var size: Vector2i = canvas["size"]
	var s = SUPERSAMPLE
	ink.a = 1.0
	# Every polygon in supersampled pixels, with the rows it covers.
	var placed = []
	var to_pixels = Transform2D(0.0, Vector2.ONE * canvas["em"] * s, 0.0, canvas["origin"] * s)
	for word in layout["words"]:
		for shape in word["shapes"]:
			var points = to_pixels * shape
			var low = INF
			var high = -INF
			for p in points:
				low = minf(low, p.y)
				high = maxf(high, p.y)
			placed.append([points, low, high])
	# Ink on clear ink, so that shrinking leaves the edges the ink's colour.
	var clear = Color(ink, 0.0)
	var image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(clear)
	var band = clampi(BAND_PIXELS / (size.x * s * s), 1, size.y)
	var top = 0
	while top < size.y:
		var rows = mini(band, size.y - top)
		var strip = Image.create_empty(size.x * s, rows * s, false, Image.FORMAT_RGBA8)
		strip.fill(clear)
		var from = top * s
		var to = (top + rows) * s
		for item in placed:
			if item[2] > from and item[1] < to:
				_fill(strip, item[0], from, ink)
		strip.shrink_x2()
		strip.shrink_x2()
		image.blit_rect(strip, Rect2i(0, 0, size.x, rows), Vector2i(0, top))
		top += rows
	if background.a <= 0.0:
		return image
	var out = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	out.fill(Color(background, 1.0))
	out.blend_rect(image, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
	return out


# Fills a convex polygon (in pixels; the strip starts at row `from`) a row at a time.
static func _fill(image: Image, points: PackedVector2Array, from: int, color: Color) -> void:
	var count = points.size()
	if count < 3:
		return
	var low = INF
	var high = -INF
	for p in points:
		low = minf(low, p.y)
		high = maxf(high, p.y)
	var width = image.get_width()
	for row in range(maxi(from, floori(low)), mini(from + image.get_height(), ceili(high))):
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
		var start = clampi(roundi(left), 0, width)
		var end = clampi(roundi(right), 0, width)
		if end > start:
			image.fill_rect(Rect2i(start, row - from, end - start, 1), color)


# The layout as an SVG document: a path per word, its ink as outlines (see
# _outlines): outlines turning one way, holes the other, so that the nonzero
# rule fills it as drawn.
static func svg(layout: Dictionary, canvas: Dictionary, ink: Color, background: Color, title := "") -> String:
	var size: Vector2i = canvas["size"]
	var to_pixels = Transform2D(0.0, Vector2.ONE * canvas["em"], 0.0, canvas["origin"])
	var lines = [
		"<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
		"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\">" % [size.x, size.y, size.x, size.y],
	]
	if title != "":
		lines.append("  <title>%s</title>" % _xml(title))
	if background.a > 0.0:
		lines.append("  <rect width=\"%d\" height=\"%d\" fill=\"#%s\"/>" % [size.x, size.y, background.to_html(false)])
	lines.append("  <g fill=\"#%s\">" % ink.to_html(false))
	for word in layout["words"]:
		var d = []
		for points in _outlines(word["strokes"], to_pixels):
			var parts = []
			for p in points:
				parts.append("%s %s" % [_number(p.x), _number(p.y)])
			d.append("M" + " L".join(parts) + "Z")
		if not d.is_empty():
			lines.append("    <path aria-label=\"%s\" d=\"%s\"/>" % [_xml(word["word"]), "".join(d)])
	lines.append("  </g>")
	lines.append("</svg>")
	return "\n".join(lines) + "\n"


# A word's strokes (lists of pieces, see Writing.word_shapes) as the outlines
# of its ink, in pixels: each stroke merged into its outline, then strokes
# that overlap merged together. Outlines turn one way (positive area), the
# holes inside them the other. A shape with holes isn't merged any further:
# what overlaps it stays apart, which the nonzero rule fills all the same.
static func _outlines(strokes: Array, to_pixels: Transform2D) -> Array:
	var regions = []  # [outline, holes]
	for stroke in strokes:
		var pieces = []
		for shape in stroke:
			pieces.append(to_pixels * shape)
		for shape in _outline(pieces):
			var current = [_turned(shape, true), []]
			var i = 0
			while i < regions.size():
				var region = regions[i]
				if region[1].is_empty() and current[1].is_empty() and _box(region[0]).intersects(_box(current[0])):
					var joined = _join(region[0], current[0])
					if not joined.is_empty():
						regions.remove_at(i)
						current = joined
						i = 0
						continue
				i += 1
			regions.append(current)
	var contours = []
	for region in regions:
		contours.append(region[0])
		contours.append_array(region[1])
	return contours


# Two outlines merged: [outline, holes], or [] if they don't overlap.
static func _join(a: PackedVector2Array, b: PackedVector2Array) -> Array:
	var merged = Geometry2D.merge_polygons(a, b)
	if merged.is_empty():
		return []
	var outer = 0
	for i in merged.size():
		if absf(_area(merged[i])) > absf(_area(merged[outer])):
			outer = i
	var sign = signf(_area(merged[outer]))
	var holes = []
	for i in merged.size():
		if i == outer:
			continue
		if signf(_area(merged[i])) == sign:
			return []  # two shapes apart
		holes.append(_turned(merged[i], false))
	return [_turned(merged[outer], true), holes]


# The polygon turning the positive way (an outline) or the other (a hole).
static func _turned(polygon: PackedVector2Array, positive: bool) -> PackedVector2Array:
	if (_area(polygon) > 0.0) != positive:
		polygon = polygon.duplicate()
		polygon.reverse()
	return polygon


static func _box(polygon: PackedVector2Array) -> Rect2:
	var box = Rect2(polygon[0], Vector2.ZERO)
	for p in polygon:
		box = box.expand(p)
	return box


# A stroke's pieces (a taper is many, each overlapping the one before) merged
# into its outline: [outline]. If they don't make one shape without holes,
# the pieces as they are.
static func _outline(pieces: Array) -> Array:
	var outline = PackedVector2Array()
	for piece in pieces:
		if absf(_area(piece)) < 1e-6:
			continue  # flat: adds nothing
		if outline.is_empty():
			outline = piece
			continue
		var merged = Geometry2D.merge_polygons(outline, piece)
		if merged.size() != 1:
			return pieces
		outline = merged[0]
	return [outline] if not outline.is_empty() else []


static func _number(v: float) -> String:
	var text = String.num(v, 2)
	return "0" if text == "-0" else text


static func _area(polygon: PackedVector2Array) -> float:
	var sum = 0.0
	for i in polygon.size():
		sum += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	return sum * 0.5


static func _xml(text: String) -> String:
	return text.xml_escape(true)
