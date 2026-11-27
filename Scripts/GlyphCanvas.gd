extends Control

# The drawing surface of the Alphabet tab: one letter, magnified in its em
# square. Places dots, lines and tapered lines with the mouse (a line takes two
# clicks, its start then its end, and shows itself in between), and moves
# strokes and their handles. The strokes belong to the tab's document; this
# edits the list it's given and says when, edit_started before and edited
# after, so the tab can keep its undo history and save.

const Quill = preload("res://Scripts/Quill.gd")

signal edit_started(tag)
signal edited
signal selection_changed
signal state_changed  # the tool, or a line half placed

const INK = Color(0.9254902, 0.8980392, 0.85490197)
const EMBER = Color(0.8862745, 0.4745098, 0.22745098)
const PAPER = Color(0.08235294, 0.07450981, 0.06666667)
const RULE = Color(1, 1, 1, 0.04)
const RULE_STRONG = Color(1, 1, 1, 0.1)
const MARGIN = 24.0
const HANDLE_RADIUS = 6.0
const SNAP_RADIUS = 10.0  # pixels: how near another stroke's end a point snaps to it
const MIN_LENGTH = 0.01  # em: a shorter line is taken for a double click

var strokes: Array = []  # the letter's strokes, shared with the document
var settings: Dictionary = {}  # for a diacritic, the quill magnified (Quill.magnified)
var editable = false  # false when there's no letter to draw in
var tool = "line"  # "select", "dot", "line" or "taper"
var selected = -1
var grid_divisions = 16
var snap_to_grid = true
# What the next stroke placed starts with; the tab updates it as strokes are adjusted.
var defaults = {"size": 1.0, "weight": 1.0, "thickness": 1.4, "curve": 0.3}

var _start = null  # em: the first point of the line being placed
var _mouse = Vector2(-1, -1)  # em, snapped
var _inside = false
var _snap_mark = null  # em: the stroke end the mouse snapped to
var _hover = -1
var _drag = {}  # {"part": "move", "from", "to", "at" or "curve", "grab": em, "was": the stroke before, "moved": bool}


func _ready():
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	mouse_entered.connect(func(): _inside = true)
	mouse_exited.connect(func():
		_inside = false
		_hover = -1
		_snap_mark = null
		queue_redraw())
	resized.connect(queue_redraw)
	_update_cursor()


func set_letter(new_strokes, new_settings: Dictionary) -> void:
	editable = new_strokes != null
	strokes = new_strokes if editable else []
	settings = new_settings
	selected = -1
	_start = null
	_drag = {}
	_hover = -1
	state_changed.emit()
	selection_changed.emit()
	queue_redraw()


func set_tool(new_tool: String) -> void:
	tool = new_tool
	_start = null
	_hover = -1
	_update_cursor()
	state_changed.emit()
	queue_redraw()


func is_placing() -> bool:
	return _start != null


func select(index: int) -> void:
	index = index if index >= 0 and index < strokes.size() else -1
	if index != selected:
		selected = index
		selection_changed.emit()
	queue_redraw()


func delete_selected() -> void:
	if selected < 0:
		return
	edit_started.emit("")
	strokes.remove_at(selected)
	selected = -1
	_drag = {}
	edited.emit()
	selection_changed.emit()
	queue_redraw()


# Right-click (and Esc in the Select tool, or mid-line): drops the line being
# placed, or else the selection.
func cancel() -> void:
	if _start != null:
		_start = null
		state_changed.emit()
	elif selected >= 0:
		select(-1)
	queue_redraw()


func _update_cursor() -> void:
	mouse_default_cursor_shape = Control.CURSOR_ARROW if tool == "select" else Control.CURSOR_CROSS


# --- Geometry -------------------------------------------------------------

# The em square, in pixels.
func box() -> Rect2:
	var side = maxf(0.0, minf(size.x, size.y) - 2.0 * MARGIN)
	return Rect2((size - Vector2(side, side)) / 2.0, Vector2(side, side))


func to_px(p: Vector2) -> Vector2:
	var b = box()
	return b.position + p * b.size.x


func to_em(p: Vector2) -> Vector2:
	var b = box()
	return (p - b.position) / maxf(b.size.x, 1.0)


# Where a point under the mouse lands. With Shift, a line from anchor keeps to
# steps of 15°; otherwise it snaps to the end of another stroke nearby (not
# exclude's), or else to the grid. Alt places it freely.
func _snap(px: Vector2, anchor = null, exclude := -1) -> Vector2:
	_snap_mark = null
	var p = to_em(px)
	if anchor != null and Input.is_key_pressed(KEY_SHIFT):
		var d = p - anchor
		return anchor + Vector2.from_angle(snappedf(d.angle(), PI / 12.0)) * d.length()
	if Input.is_key_pressed(KEY_ALT):
		return p
	var best = SNAP_RADIUS
	for i in strokes.size():
		if i == exclude:
			continue
		for q in Quill.anchors(strokes[i]):
			var d = to_px(q).distance_to(px)
			if d < best:
				best = d
				_snap_mark = q
	if _snap_mark != null:
		return _snap_mark
	if snap_to_grid:
		return p.snapped(Vector2.ONE / grid_divisions)
	return p


# The topmost stroke under px, or -1.
func hit(px: Vector2) -> int:
	var side = box().size.x
	if side <= 0.0:
		return -1
	var p = to_em(px)
	for i in range(strokes.size() - 1, -1, -1):
		var allowed = maxf(Quill.reach(strokes[i], settings) * side, 6.0)
		if Quill.distance(strokes[i], p) * side <= allowed:
			return i
	return -1


# The selected stroke's handles that can be grabbed now: {part: em}. Its ends
# move with the Select tool; a taper's curve handle works with any tool,
# between placements, so a taper can be bent right after it's drawn.
func _handles() -> Dictionary:
	if selected < 0:
		return {}
	var stroke = strokes[selected]
	var handles = {}
	if tool == "select":
		for key in ["at", "from", "to"]:
			if stroke.has(key):
				handles[key] = stroke[key]
	if stroke["type"] == "taper":
		handles["curve"] = Quill.curve_handle(stroke)
	return handles


func _handle_at(px: Vector2) -> String:
	if _start != null:
		return ""
	var handles = _handles()
	# The curve handle first: it can sit on top of an end of a short taper.
	for part in ["curve", "at", "from", "to"]:
		if handles.has(part) and to_px(handles[part]).distance_to(px) <= HANDLE_RADIUS + 3.0:
			return part
	return ""


# --- Input ----------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not editable:
		return
	if event is InputEventMouseMotion:
		_on_motion(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				grab_focus()
				_on_press(event.position)
			else:
				_drag = {}
				queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel()
			accept_event()
	elif event is InputEventKey and event.pressed:
		_on_key(event)


func _on_motion(px: Vector2) -> void:
	if not _drag.is_empty():
		_drag_to(px)
		return
	_mouse = _snap(px, _start)
	if tool == "select":
		_hover = hit(px)
	queue_redraw()


func _on_press(px: Vector2) -> void:
	var part = _handle_at(px)
	if part != "":
		_begin_drag(part, px)
		return
	match tool:
		"select":
			var i = hit(px)
			select(i)
			if i >= 0:
				_begin_drag("move", px)
		"dot":
			_add({"type": "dot", "at": _snap(px), "size": defaults["size"]})
		"line", "taper":
			var p = _snap(px, _start)
			if _start == null:
				_start = p
				state_changed.emit()
			elif _start.distance_to(p) >= MIN_LENGTH:
				var stroke = {"type": tool, "from": _start, "to": p}
				if tool == "line":
					stroke["weight"] = defaults["weight"]
				else:
					stroke["thickness"] = defaults["thickness"]
					stroke["curve"] = defaults["curve"]
				_start = null
				_add(stroke)
				state_changed.emit()
	queue_redraw()


func _add(stroke: Dictionary) -> void:
	edit_started.emit("")
	strokes.append(stroke)
	edited.emit()
	select(strokes.size() - 1)


func _begin_drag(part: String, px: Vector2) -> void:
	_drag = {"part": part, "grab": to_em(px), "was": strokes[selected].duplicate(true), "moved": false}


func _drag_to(px: Vector2) -> void:
	if not _drag["moved"]:
		edit_started.emit("")  # one undo step for the whole drag
		_drag["moved"] = true
	var stroke = strokes[selected]
	var was = _drag["was"]
	match _drag["part"]:
		"move":
			# The end nearest where the stroke was grabbed snaps; the rest follows.
			var grab: Vector2 = _drag["grab"]
			var held: Vector2 = Quill.anchors(was)[0]
			for q in Quill.anchors(was):
				if q.distance_to(grab) < held.distance_to(grab):
					held = q
			var target = _snap(to_px(held + to_em(px) - grab), null, selected)
			for key in ["at", "from", "to"]:
				if was.has(key):
					stroke[key] = was[key] + target - held
		"at":
			stroke["at"] = _snap(px, null, selected)
		"from", "to":
			var other = "to" if _drag["part"] == "from" else "from"
			stroke[_drag["part"]] = _snap(px, stroke[other], selected)
		"curve":
			_snap_mark = null
			stroke["curve"] = Quill.curve_for_handle(stroke, to_em(px))
	edited.emit()
	queue_redraw()


func _on_key(event: InputEventKey) -> void:
	if event.is_command_or_control_pressed() or event.alt_pressed:
		return
	var nudge = Vector2.ZERO
	match event.keycode:
		KEY_V:
			set_tool("select")
		KEY_D:
			set_tool("dot")
		KEY_L:
			set_tool("line")
		KEY_T:
			set_tool("taper")
		KEY_ESCAPE:
			# Nothing half drawn: back to the Select tool, keeping the selection
			# so the stroke just drawn can be adjusted.
			if _start == null and tool != "select":
				set_tool("select")
			else:
				cancel()
		KEY_DELETE, KEY_BACKSPACE:
			delete_selected()
		KEY_LEFT:
			nudge = Vector2.LEFT
		KEY_RIGHT:
			nudge = Vector2.RIGHT
		KEY_UP:
			nudge = Vector2.UP
		KEY_DOWN:
			nudge = Vector2.DOWN
		_:
			return
	if nudge != Vector2.ZERO:
		if selected < 0:
			return
		# A grid step, or a hundredth of the em with Shift.
		var step = 0.01 if event.shift_pressed else 1.0 / grid_divisions
		edit_started.emit("nudge %d" % selected)
		Quill.translate(strokes[selected], nudge * step)
		edited.emit()
		queue_redraw()
	accept_event()


# --- Drawing --------------------------------------------------------------

func _draw() -> void:
	var b = box()
	draw_rect(b, PAPER)
	for i in grid_divisions + 1:
		var t = b.position.x + b.size.x * i / grid_divisions
		var s = b.position.y + b.size.y * i / grid_divisions
		var color = RULE_STRONG if i % (grid_divisions / 4) == 0 else RULE
		draw_line(Vector2(t, b.position.y), Vector2(t, b.end.y), color, 1.0)
		draw_line(Vector2(b.position.x, s), Vector2(b.end.x, s), color, 1.0)
	if not editable:
		return
	for i in strokes.size():
		var color = INK
		if i == selected:
			color = EMBER
		elif i == _hover:
			color = INK.lerp(EMBER, 0.45)
		Quill.draw_stroke(self, strokes[i], settings, b.position, b.size.x, color)
	var ghost = _ghost()
	if ghost != null:
		Quill.draw_stroke(self, ghost, settings, b.position, b.size.x, EMBER.lerp(PAPER, 0.4))
	if _start != null:
		_draw_point(to_px(_start), EMBER)
	if selected >= 0:
		_draw_handles()
	if _snap_mark != null and (_inside or not _drag.is_empty()):
		draw_arc(to_px(_snap_mark), SNAP_RADIUS, 0.0, TAU, 32, EMBER, 1.5, true)


# The stroke the next click would place, shown under the mouse.
func _ghost():
	if not _inside or not _drag.is_empty():
		return null
	if tool == "dot":
		return {"type": "dot", "at": _mouse, "size": defaults["size"]}
	if _start == null or not tool in ["line", "taper"]:
		return null
	if tool == "line":
		return {"type": "line", "from": _start, "to": _mouse, "weight": defaults["weight"]}
	return {"type": "taper", "from": _start, "to": _mouse, "thickness": defaults["thickness"], "curve": defaults["curve"]}


func _draw_handles() -> void:
	var stroke = strokes[selected]
	var handles = _handles()
	if handles.has("curve"):
		var chord = to_px((stroke["from"] + stroke["to"]) * 0.5)
		draw_dashed_line(chord, to_px(handles["curve"]), Color(EMBER, 0.5), 1.0, 4.0)
		var c = to_px(handles["curve"])
		var r = HANDLE_RADIUS + 1.0
		var diamond = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		draw_colored_polygon(diamond, PAPER)
		diamond.append(diamond[0])
		draw_polyline(diamond, EMBER, 1.5, true)
	for part in handles:
		if part != "curve":
			_draw_point(to_px(handles[part]), EMBER)


func _draw_point(c: Vector2, color: Color) -> void:
	draw_circle(c, HANDLE_RADIUS, PAPER)
	draw_arc(c, HANDLE_RADIUS, 0.0, TAU, 24, color, 1.5, true)
