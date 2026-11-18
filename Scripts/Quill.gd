extends RefCounted

# How the letters of the Kracnodar script are drawn. Every stroke is the trace
# of a broad quill nib held at one fixed angle: a thin rectangle (the nib's
# width by its hairline thickness) swept from one point to another. So edges
# are straight, and a stroke is thick when it crosses the nib and thin when it
# runs along it; with the nib held near upright, vertical strokes come out
# thinnest.
#
# Strokes, with points in the letter's em square (0..1, y down):
#   {"type": "dot", "at": Vector2, "size": nib widths}
#   {"type": "line", "from": Vector2, "to": Vector2, "weight": nib widths}
#   {"type": "taper", "from": Vector2 (thin end), "to": Vector2 (thick end),
#    "thickness": nib widths at the thick end, "curve": bend, -1..1}
# A taper is a quadratic curve; its curve is how far its middle sits off the
# straight line between its ends, in half its length, to the left of
# from -> to as drawn (negative bends the other way).

# The alphabet-wide settings, and their values when not set.
const DEFAULTS = {
	"nib_angle": 80.0,  # degrees from horizontal, counter-clockwise
	"nib_width": 0.09,  # em
	"hairline": 0.012,  # em: the nib's thickness, the thinnest any stroke gets
	"taper_start": 0.1,  # nib widths: where every taper begins
	"taper_min": 0.6,  # nib widths: the range a taper's thick end can be set within
	"taper_max": 2.2,
	"taper_swell": 1.6,  # above 1 a taper stays thin longer, then swells near its end
	# Diacritics are drawn centred in a square of their own, which is this much
	# of a letter's when one goes on a letter. The nib stays the same.
	"diacritic_size": 0.35,
	"diacritic_gap": 0.06,  # em: between a letter's ink and the diacritic above it
}

const TYPES = ["dot", "line", "taper"]
const TAPER_SAMPLES = 40


static func value(settings: Dictionary, key: String) -> float:
	return float(settings.get(key, DEFAULTS[key]))


# The nib's two axes: along its edge, and across it.
static func _nib(settings: Dictionary) -> Array:
	var angle = deg_to_rad(value(settings, "nib_angle"))
	var along = Vector2(cos(angle), -sin(angle))  # y points down
	return [along, along.orthogonal()]


# The shape the nib leaves going straight from a to b, its width changing from
# wa to wb on the way: the convex hull of the nib at both ends.
static func _sweep(a: Vector2, wa: float, b: Vector2, wb: float, thickness: float, nib: Array) -> PackedVector2Array:
	var points = PackedVector2Array()
	var across = nib[1] * thickness * 0.5
	for end in [[a, wa], [b, wb]]:
		var along = nib[0] * end[1] * 0.5
		var p = end[0]
		points.append(p + along + across)
		points.append(p + along - across)
		points.append(p - along - across)
		points.append(p - along + across)
	var hull = Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0] == hull[hull.size() - 1]:
		hull.remove_at(hull.size() - 1)
	return hull


# The polygons a stroke is made of, in em.
static func shapes(stroke: Dictionary, settings: Dictionary) -> Array:
	var nib = _nib(settings)
	var width = value(settings, "nib_width")
	var hairline = value(settings, "hairline")
	match stroke["type"]:
		"dot":
			# A short twist of the nib: a lozenge.
			var size = float(stroke.get("size", 1.0))
			var reach = nib[1].rotated(-PI / 6.0) * width * size * 0.3
			return [_sweep(stroke["at"] - reach, width * size, stroke["at"] + reach, width * size, hairline * size, nib)]
		"line":
			var weight = float(stroke.get("weight", 1.0))
			return [_sweep(stroke["from"], width * weight, stroke["to"], width * weight, hairline * weight, nib)]
		"taper":
			var points = taper_points(stroke, TAPER_SAMPLES)
			var result = []
			for i in TAPER_SAMPLES:
				var t0 = float(i) / TAPER_SAMPLES
				var t1 = float(i + 1) / TAPER_SAMPLES
				result.append(_sweep(points[i], taper_width(stroke, settings, t0),
					points[i + 1], taper_width(stroke, settings, t1), hairline, nib))
			return result
	return []


# The nib's width, in em, a fraction t of the way along a taper.
static func taper_width(stroke: Dictionary, settings: Dictionary, t: float) -> float:
	var start = value(settings, "taper_start")
	var end = clampf(float(stroke.get("thickness", 1.0)), value(settings, "taper_min"), value(settings, "taper_max"))
	return value(settings, "nib_width") * lerpf(start, end, pow(t, value(settings, "taper_swell")))


# The middle control point of a taper's curve.
static func taper_control(stroke: Dictionary) -> Vector2:
	var a: Vector2 = stroke["from"]
	var b: Vector2 = stroke["to"]
	return (a + b) * 0.5 + (b - a).orthogonal() * float(stroke.get("curve", 0.0))


static func taper_points(stroke: Dictionary, samples: int) -> PackedVector2Array:
	var a: Vector2 = stroke["from"]
	var b: Vector2 = stroke["to"]
	var c = taper_control(stroke)
	var points = PackedVector2Array()
	for i in samples + 1:
		var t = float(i) / samples
		points.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return points


# Where a taper's curve handle sits: the middle of the curve.
static func curve_handle(stroke: Dictionary) -> Vector2:
	return (stroke["from"] + stroke["to"]) * 0.25 + taper_control(stroke) * 0.5


# The curve that puts a taper's middle at p (or as near as the bend goes).
static func curve_for_handle(stroke: Dictionary, p: Vector2) -> float:
	var a: Vector2 = stroke["from"]
	var b: Vector2 = stroke["to"]
	var normal = (b - a).orthogonal()
	if normal.length_squared() < 1e-9:
		return 0.0
	return clampf((p - (a + b) * 0.5).dot(normal) / (0.5 * normal.length_squared()), -1.0, 1.0)


# The points other strokes snap to: a dot's centre, a line's ends.
static func anchors(stroke: Dictionary) -> Array:
	return [stroke["at"]] if stroke["type"] == "dot" else [stroke["from"], stroke["to"]]


static func translate(stroke: Dictionary, delta: Vector2) -> void:
	for key in ["at", "from", "to"]:
		if stroke.has(key):
			stroke[key] += delta


# How far p is from the stroke's middle line, in em.
static func distance(stroke: Dictionary, p: Vector2) -> float:
	match stroke["type"]:
		"dot":
			return p.distance_to(stroke["at"])
		"line":
			return p.distance_to(Geometry2D.get_closest_point_to_segment(p, stroke["from"], stroke["to"]))
	var points = taper_points(stroke, 24)
	var best = INF
	for i in points.size() - 1:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, points[i], points[i + 1])))
	return best


# Half the stroke's widest, in em: how near a click must come to hit it.
static func reach(stroke: Dictionary, settings: Dictionary) -> float:
	var width = value(settings, "nib_width") * 0.5
	match stroke["type"]:
		"dot":
			return width * float(stroke.get("size", 1.0))
		"line":
			return width * float(stroke.get("weight", 1.0))
	return width * float(stroke.get("thickness", 1.0))


# The settings of the same quill, seen magnified: a diacritic in its own
# square, its nib as wide as it will be next to a letter.
static func magnified(settings: Dictionary, factor: float) -> Dictionary:
	var out = settings.duplicate()
	for key in ["nib_width", "hairline"]:
		out[key] = value(settings, key) * factor
	return out


# The box round the ink of some strokes, in em; an empty Rect2 if there is none.
static func ink_bounds(strokes: Array, settings: Dictionary) -> Rect2:
	var bounds = Rect2()
	var first = true
	for stroke in strokes:
		for shape in shapes(stroke, settings):
			for p in shape:
				if first:
					bounds = Rect2(p, Vector2.ZERO)
					first = false
				else:
					bounds = bounds.expand(p)
	return bounds


# Strokes copied, scaled by factor about the middle of the em square, then moved by offset.
static func transformed(strokes: Array, factor: float, offset: Vector2) -> Array:
	var out = []
	for stroke in strokes:
		var copy = stroke.duplicate()
		for key in ["at", "from", "to"]:
			if copy.has(key):
				copy[key] = (copy[key] - Vector2(0.5, 0.5)) * factor + Vector2(0.5, 0.5) + offset
		out.append(copy)
	return out


# A letter with a diacritic on it (a letter has one at most): the letter's
# strokes, and the diacritic's shrunk to the diacritic size and set above the
# letter's ink, centred on it.
static func compose(letter: Array, mark: Array, settings: Dictionary) -> Array:
	if mark.is_empty():
		return [letter]
	var below = ink_bounds(letter, settings) if not letter.is_empty() else Rect2(0.5, 0.5, 0.0, 0.0)
	var placed = transformed(mark, value(settings, "diacritic_size"), Vector2.ZERO)
	var ink = ink_bounds(placed, settings)
	var shift = Vector2(below.get_center().x - ink.get_center().x, below.position.y - value(settings, "diacritic_gap") - ink.end.y)
	return [letter, transformed(placed, 1.0, shift)]


static func draw_strokes(canvas: CanvasItem, strokes: Array, settings: Dictionary, origin: Vector2, scale: float, color: Color) -> void:
	for stroke in strokes:
		draw_stroke(canvas, stroke, settings, origin, scale, color)


# Draws a stroke with its em square at origin, scale pixels to the em. The
# colour should be opaque: a taper is many overlapping pieces.
static func draw_stroke(canvas: CanvasItem, stroke: Dictionary, settings: Dictionary, origin: Vector2, scale: float, color: Color) -> void:
	var placed = []
	for shape in shapes(stroke, settings):
		var polygon = PackedVector2Array()
		for p in shape:
			polygon.append(origin + p * scale)
		if polygon.size() >= 3 and absf(_area(polygon)) > 0.01:
			placed.append(polygon)
	for polygon in placed:
		canvas.draw_colored_polygon(polygon, color)
	# A soft edge: a thin antialiased outline round each piece. The edges inside
	# a taper fall on its own ink, so only its outside shows.
	for polygon in placed:
		var loop = polygon.duplicate()
		loop.append(polygon[0])
		canvas.draw_polyline(loop, color, 1.0, true)


static func _area(polygon: PackedVector2Array) -> float:
	var sum = 0.0
	for i in polygon.size():
		sum += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	return sum * 0.5


# --- The file -------------------------------------------------------------

static func stroke_to_json(stroke: Dictionary) -> Dictionary:
	var out = {}
	for key in stroke:
		var v = stroke[key]
		if v is Vector2:
			out[key] = [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001)]
		elif v is float:
			out[key] = snappedf(v, 0.0001)
		else:
			out[key] = v
	return out


# The stroke a saved one describes, or null if it isn't one.
static func stroke_from_json(data) -> Variant:
	if not data is Dictionary or not str(data.get("type", "")) in TYPES:
		return null
	var stroke = {"type": str(data["type"])}
	var points = ["at"] if stroke["type"] == "dot" else ["from", "to"]
	for key in points:
		var p = data.get(key)
		if not (p is Array and p.size() == 2):
			return null
		stroke[key] = Vector2(float(p[0]), float(p[1]))
	var numbers = {"dot": {"size": 1.0}, "line": {"weight": 1.0}, "taper": {"thickness": 1.4, "curve": 0.0}}
	for key in numbers[stroke["type"]]:
		stroke[key] = float(data.get(key, numbers[stroke["type"]][key]))
	return stroke
