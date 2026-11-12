extends Control

# A vertical letter index beside the dictionary list. Each letter's slot is as
# tall as its share of the words (plus a minimum, so every letter stays
# readable), so the index reads like a map of the list. Clicking a letter, or
# dragging along the index, selects it.

signal letter_selected(index)

var groups = []  # [{"letter": "A", "count": 10, ...}], in list order
var active = -1  # the letter at the top of the list, drawn in ember
var _hover = -1
var _dragging = false


func _ready():
	theme_type_variation = "AlphabetRail"
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "A–Z"  # replaced per letter by _get_tooltip
	mouse_exited.connect(func():
		_hover = -1
		queue_redraw())
	resized.connect(queue_redraw)


func set_groups(new_groups: Array) -> void:
	groups = new_groups
	active = -1
	_hover = -1
	queue_redraw()


func set_active(index: int) -> void:
	if index != active:
		active = index
		queue_redraw()


# One rectangle per letter, top to bottom.
func slots() -> Array:
	var rects = []
	if groups.is_empty():
		return rects
	var panel = get_theme_stylebox("panel")
	var top = panel.get_margin(SIDE_TOP)
	var height = maxf(0.0, size.y - top - panel.get_margin(SIDE_BOTTOM))
	var total = 0
	for group in groups:
		total += group["count"]
	var minimum = minf(float(get_theme_constant("min_slot_height")), height / groups.size())
	var spare = height - minimum * groups.size()
	var y = top
	for group in groups:
		var slot_height = minimum + (spare * group["count"] / total if total > 0 else 0.0)
		rects.append(Rect2(0, y, size.x, slot_height))
		y += slot_height
	return rects


func slot_at(y: float) -> int:
	var rects = slots()
	for i in rects.size():
		if y < rects[i].end.y:
			return i
	return rects.size() - 1


func _draw() -> void:
	draw_style_box(get_theme_stylebox("panel"), Rect2(Vector2.ZERO, size))
	var font = get_theme_font("font")
	var font_size = get_theme_font_size("font_size")
	var rects = slots()
	for i in rects.size():
		var rect = rects[i]
		var color = get_theme_color("font_color")
		if i == active:
			color = get_theme_color("font_active_color")
			draw_rect(Rect2(size.x - 3, rect.position.y + 2, 2, maxf(0.0, rect.size.y - 4)), color)
		elif i == _hover:
			color = get_theme_color("font_hover_color")
		if i == _hover:
			draw_style_box(get_theme_stylebox("hover"), rect.grow_individual(-3, 0, -3, 0))
		var baseline = rect.position.y + (rect.size.y - font.get_height(font_size)) / 2.0 + font.get_ascent(font_size)
		draw_string(font, Vector2(0, baseline), groups[i]["letter"], HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, color)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_select(slot_at(event.position.y))
		accept_event()
	elif event is InputEventMouseMotion:
		var index = slot_at(event.position.y)
		if index != _hover:
			_hover = index
			queue_redraw()
		if _dragging and index != active:
			_select(index)


func _select(index: int) -> void:
	if index < 0:
		return
	active = index
	queue_redraw()
	letter_selected.emit(index)


func _get_tooltip(at_position: Vector2) -> String:
	var index = slot_at(at_position.y)
	if index < 0:
		return ""
	var count = groups[index]["count"]
	return "%s · %d mot%s" % [groups[index]["letter"], count, "s" if count > 1 else ""]
