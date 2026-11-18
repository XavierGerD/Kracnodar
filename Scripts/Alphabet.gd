extends HBoxContainer

# The Alphabet tab: where the letters and diacritics of the Kracnodar script
# are drawn, with dots, lines and tapered lines traced by a quill (see
# Quill.gd). The list of letters and diacritics on the left, the one being
# drawn in the middle, and on the right its name, a preview of a letter with a
# diacritic, the selected stroke's settings, and the quill's.
#
# A letter takes one diacritic at most. A diacritic is drawn centred in a
# square of its own. On a letter it shrinks
# to the diacritic size and sits above the letter's ink, centred on it (see
# Quill.compose); the nib doesn't shrink with it, so while a diacritic is drawn
# the canvas shows its nib magnified as much as the diacritic is.
#
# Saved in glyphs.json, where Dict keeps its files, shortly after every change:
#   {"settings": {the quill's settings, see Quill.DEFAULTS},
#    "letters": [{"name": "...", "sound": "...", "strokes": [stroke, ...]}],
#    "diacritics": [{"name": "...", "symbol": "...", "strokes": [stroke, ...]}]}
# with strokes as Quill.gd describes them, their points as [x, y]. A letter's
# sound is what it writes; a diacritic's symbol, the mark it stands for.

const Quill = preload("res://Scripts/Quill.gd")
const GlyphThumb = preload("res://Scripts/GlyphThumb.gd")
const Writing = preload("res://Scripts/Writing.gd")

# Saved: the rest of the app writes with the letters as they are now.
signal alphabet_changed

const FILE = "glyphs.json"
const HISTORY_LIMIT = 200
# A run of changes with the same tag this close together is one undo step:
# dragging a slider, typing a name.
const MERGE_MSEC = 1500

const STROKE_NAMES = {"dot": "Dot", "line": "Line", "taper": "Tapered line"}

const KINDS = ["letter", "diacritic"]
const KIND_TITLES = {"letter": "Letter", "diacritic": "Diacritic"}
const SECTION_TITLES = {"letter": "Letters", "diacritic": "Diacritics"}
const FILE_SECTIONS = {"letter": "letters", "diacritic": "diacritics"}

var settings = Quill.DEFAULTS.duplicate()
# Letters and diacritics: [{"kind", "name", "sound" or "symbol", "strokes": [...]}],
# strokes with Vector2 points. Each kind keeps its own order; the list shows them apart.
var letters = []
var current = -1
# What the preview shows: a letter, and the diacritic on it or -1 (indices into letters).
var preview_letter = -1
var preview_mark = -1

var _undo = []
var _redo = []
var _last_tag = ""
var _last_msec = 0
var _load_problem = ""
var _save_timer: Timer
var _buttons = []  # list Button per letter
var _thumbs = []  # GlyphThumb per letter
var _titles = []  # [name Label, sound Label] per letter
var _letter_heading: Label
var _name_edit: LineEdit
var _sound_label: Label
var _sound_edit: LineEdit
var _delete_letter_button: Button
var _preview_picker: OptionButton
var _preview_choices = []  # the letter index of each picker item
var _preview_big: Control
var _preview_small: Control
var _mark_picker: OptionButton
var _mark_choices = []  # the diacritic index of each picker item, -1 for none
var _stroke_box: VBoxContainer
var _stroke_sliders = {}  # setting -> HSlider, for the selected stroke
var _quill_sliders = {}  # setting -> HSlider


func _ready():
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.5
	_save_timer.timeout.connect(save)
	add_child(_save_timer)
	var tools = ButtonGroup.new()
	for pair in [[%SelectTool, "select"], [%DotTool, "dot"], [%LineTool, "line"], [%TaperTool, "taper"]]:
		pair[0].button_group = tools
		pair[0].pressed.connect(%Canvas.set_tool.bind(pair[1]))
	%GridButton.toggled.connect(func(on):
		%Canvas.snap_to_grid = on
		%Canvas.queue_redraw())
	%UndoButton.pressed.connect(undo)
	%RedoButton.pressed.connect(redo)
	%AddLetterButton.pressed.connect(add_letter.bind("letter"))
	%AddDiacriticButton.pressed.connect(add_letter.bind("diacritic"))
	%Canvas.edit_started.connect(_begin_change)
	%Canvas.edited.connect(_on_canvas_edited)
	%Canvas.selection_changed.connect(_build_stroke_section)
	%Canvas.state_changed.connect(_sync_tool)
	_build_inspector()
	load_letters()
	if letters.is_empty():
		letters.append(_new_letter("letter"))
	_render_list()
	select_letter(0)
	_sync_history_buttons()


func _new_letter(kind: String) -> Dictionary:
	var letter = {"kind": kind, "name": "", "strokes": []}
	letter[_mark_key(letter)] = ""
	return letter


# The field that says what a letter writes ("sound") or what a diacritic marks ("symbol").
func _mark_key(letter: Dictionary) -> String:
	return "symbol" if letter["kind"] == "diacritic" else "sound"


# The quill a letter is drawn with, at the size it's shown in its own square.
func _pen(index: int) -> Dictionary:
	if _is(index, "diacritic"):
		return Quill.magnified(settings, 1.0 / Quill.value(settings, "diacritic_size"))
	return settings


func _is(index: int, kind: String) -> bool:
	return index >= 0 and index < letters.size() and letters[index]["kind"] == kind


# --- Letters --------------------------------------------------------------

func select_letter(index: int) -> void:
	current = clampi(index, -1, letters.size() - 1)
	var letter = letters[current] if current >= 0 else null
	%Canvas.set_letter(letter["strokes"] if letter else null, _pen(current))
	var kind = letter["kind"] if letter else "letter"
	_letter_heading.text = KIND_TITLES[kind]
	_sound_label.text = "Symbol" if kind == "diacritic" else "Sound"
	_name_edit.placeholder_text = "The diacritic's name" if kind == "diacritic" else "The letter's name, like Spyr"
	_sound_edit.placeholder_text = "The mark it stands for, like ´ or ¨" if kind == "diacritic" else "What it writes, like a or i/y"
	_delete_letter_button.text = "Delete " + KIND_TITLES[kind].to_lower()
	_name_edit.text = letter["name"] if letter else ""
	_sound_edit.text = letter[_mark_key(letter)] if letter else ""
	_name_edit.editable = letter != null
	_sound_edit.editable = letter != null
	_delete_letter_button.disabled = letter == null
	for i in _buttons.size():
		_buttons[i].set_pressed_no_signal(i == current)
	# The preview follows: a letter chosen is the one previewed; a diacritic chosen goes on it.
	if _is(current, "letter"):
		preview_letter = current
	elif _is(current, "diacritic"):
		preview_mark = current
	_render_preview()


func add_letter(kind: String) -> void:
	_begin_change("")
	letters.append(_new_letter(kind))
	_render_list()
	select_letter(letters.size() - 1)
	_name_edit.grab_focus()
	_changed()


func delete_letter() -> void:
	if current < 0:
		return
	_begin_change("")
	var gone = current
	letters.remove_at(gone)
	# The preview's indices past the one deleted move down with it.
	preview_letter = -1 if preview_letter == gone else (preview_letter - 1 if preview_letter > gone else preview_letter)
	preview_mark = -1 if preview_mark == gone else (preview_mark - 1 if preview_mark > gone else preview_mark)
	_render_list()
	# The next of the same kind, or else the one before.
	var next = gone if gone < letters.size() else letters.size() - 1
	select_letter(next)
	_changed()


func _render_list() -> void:
	for child in %LetterList.get_children():
		%LetterList.remove_child(child)
		child.queue_free()
	_buttons = []
	_thumbs = []
	_titles = []
	_buttons.resize(letters.size())
	_thumbs.resize(letters.size())
	_titles.resize(letters.size())
	var group = ButtonGroup.new()
	for kind in KINDS:
		var heading = Label.new()
		heading.text = SECTION_TITLES[kind]
		heading.theme_type_variation = "HeadingLabel"
		if kind != KINDS[0]:
			heading.custom_minimum_size = Vector2(0, 40)
			heading.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		%LetterList.add_child(heading)
		var count = 0
		for i in letters.size():
			if letters[i]["kind"] == kind:
				_add_row(i, group)
				count += 1
		if count == 0:
			var none = Label.new()
			none.text = "None yet." if kind == "letter" else "None yet: a diacritic is drawn where it sits on a letter."
			none.theme_type_variation = "HintLabel"
			none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			%LetterList.add_child(none)


func _add_row(i: int, group: ButtonGroup) -> void:
	var button = Button.new()
	button.theme_type_variation = "TocButton"
	button.toggle_mode = true
	button.button_group = group
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 60)
	button.pressed.connect(select_letter.bind(i))
	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6
	var thumb = GlyphThumb.new()
	thumb.custom_minimum_size = Vector2(48, 48)
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.strokes = letters[i]["strokes"]
	thumb.settings = _pen(i)
	var titles = VBoxContainer.new()
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label = Label.new()
	var sound_label = Label.new()
	sound_label.theme_type_variation = "HintLabel"
	titles.add_child(name_label)
	titles.add_child(sound_label)
	row.add_child(thumb)
	row.add_child(titles)
	button.add_child(row)
	%LetterList.add_child(button)
	_buttons[i] = button
	_thumbs[i] = thumb
	_titles[i] = [name_label, sound_label]
	_update_titles(i)


func _update_titles(i: int) -> void:
	var name = letters[i]["name"]
	_titles[i][0].text = name if name != "" else "Untitled"
	_titles[i][0].theme_type_variation = "" if name != "" else "HintLabel"
	_titles[i][1].text = letters[i][_mark_key(letters[i])]


# --- Inspector ------------------------------------------------------------

func _build_inspector() -> void:
	var box = %Sections
	_letter_heading = _heading(box, "Letter")
	_name_edit = _field(box, "Name", "")
	_name_edit.text_changed.connect(_set_letter_text.bind("name"))
	_sound_edit = _field(box, "Sound", "")
	_sound_label = _sound_edit.get_meta("label")
	_sound_edit.text_changed.connect(_set_letter_text.bind("mark"))
	_delete_letter_button = Button.new()
	_delete_letter_button.theme_type_variation = "DangerButton"
	_delete_letter_button.tooltip_text = "Undo brings it back"
	_delete_letter_button.pressed.connect(delete_letter)
	box.add_child(_delete_letter_button)
	box.add_child(HSeparator.new())
	_build_preview_section(box)
	box.add_child(HSeparator.new())
	_stroke_box = VBoxContainer.new()
	_stroke_box.add_theme_constant_override("separation", 8)
	box.add_child(_stroke_box)
	box.add_child(HSeparator.new())
	_heading(box, "Quill")
	_hint(box, "For every letter.")
	_quill_slider(box, "nib_angle", "Nib angle", 0.0, 180.0, 1.0,
		"The angle the nib is held at, from horizontal. Strokes along it are thinnest: near 90°, the vertical ones.")
	_quill_slider(box, "nib_width", "Nib width", 0.02, 0.25, 0.005, "The width of the nib, in em: the weight of a line at weight 1.")
	_quill_slider(box, "hairline", "Hairline", 0.002, 0.05, 0.001, "The thickness of the nib, in em: the thinnest any stroke gets.")
	_quill_slider(box, "taper_start", "Taper start", 0.0, 1.0, 0.01, "How wide every tapered line begins, in nib widths.")
	_quill_slider(box, "taper_min", "Taper end, least", 0.2, 4.0, 0.05, "The least a tapered line's thick end can be set to, in nib widths.")
	_quill_slider(box, "taper_max", "Taper end, most", 0.2, 4.0, 0.05, "The most a tapered line's thick end can be set to, in nib widths.")
	_quill_slider(box, "taper_swell", "Taper swell", 0.5, 4.0, 0.1,
		"How a tapered line widens: 1 evenly; more, staying thin longer and swelling near its end.")
	box.add_child(HSeparator.new())
	_heading(box, "Diacritics")
	_hint(box, "For every diacritic, on every letter.")
	_quill_slider(box, "diacritic_size", "Size on a letter", 0.15, 0.8, 0.01,
		"How big a diacritic's square is next to a letter's. The nib stays the same, so the canvas shows it magnified while a diacritic is drawn.")
	_quill_slider(box, "diacritic_gap", "Gap above the letter", 0.0, 0.3, 0.005,
		"The space between a letter's ink and the diacritic above it, in em.")
	_build_stroke_section()


func _build_stroke_section() -> void:
	for child in _stroke_box.get_children():
		_stroke_box.remove_child(child)
		child.queue_free()
	_stroke_sliders = {}
	var index = %Canvas.selected
	if index < 0:
		_heading(_stroke_box, "Stroke")
		_hint(_stroke_box, "Select a stroke to adjust it.")
		return
	var stroke = %Canvas.strokes[index]
	_heading(_stroke_box, STROKE_NAMES[stroke["type"]])
	match stroke["type"]:
		"dot":
			_stroke_slider("size", "Size", 0.3, 3.0, 0.05, "In nib widths")
		"line":
			_stroke_slider("weight", "Weight", 0.3, 3.0, 0.05, "The nib's width for this line, in nib widths")
		"taper":
			_stroke_slider("thickness", "Thickness", Quill.value(settings, "taper_min"), Quill.value(settings, "taper_max"), 0.05,
				"How wide the thick end is, in nib widths, within the quill's taper range")
			_stroke_slider("curve", "Curve", -1.0, 1.0, 0.01, "How far the line bends, and which way; 0 is straight")
			var flip = Button.new()
			flip.text = "Swap thin and thick ends"
			flip.pressed.connect(_flip_taper)
			_stroke_box.add_child(flip)
	var delete = Button.new()
	delete.text = "Delete stroke"
	delete.theme_type_variation = "DangerButton"
	delete.tooltip_text = "Delete or Backspace on the drawing"
	delete.pressed.connect(%Canvas.delete_selected)
	_stroke_box.add_child(delete)


func _stroke_slider(key: String, title: String, low: float, high: float, step: float, tip: String) -> void:
	var stroke = %Canvas.strokes[%Canvas.selected]
	_stroke_sliders[key] = _slider(_stroke_box, title, low, high, step, stroke[key], tip, func(v):
		var index = %Canvas.selected
		if index < 0:
			return
		_begin_change("stroke %d %s" % [index, key])
		%Canvas.strokes[index][key] = v
		%Canvas.defaults[key] = v  # the next stroke placed starts the same
		_changed())


func _quill_slider(parent: Control, key: String, title: String, low: float, high: float, step: float, tip: String) -> void:
	_quill_sliders[key] = _slider(parent, title, low, high, step, Quill.value(settings, key), tip, func(v):
		_begin_change("quill " + key)
		settings[key] = v
		# The taper range stays a range.
		if key == "taper_min" and v > Quill.value(settings, "taper_max"):
			settings["taper_max"] = v
			_set_slider(_quill_sliders["taper_max"], v)
		elif key == "taper_max" and v < Quill.value(settings, "taper_min"):
			settings["taper_min"] = v
			_set_slider(_quill_sliders["taper_min"], v)
		if key in ["taper_min", "taper_max"]:
			_build_stroke_section()
		_changed(true))


func _slider(parent: Control, title: String, low: float, high: float, step: float, value: float, tip: String, on_change: Callable) -> HSlider:
	var row = VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.tooltip_text = tip
	var head = HBoxContainer.new()
	var label = Label.new()
	label.text = title
	label.theme_type_variation = "FieldLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shown = Label.new()
	shown.theme_type_variation = "HintLabel"
	head.add_child(label)
	head.add_child(shown)
	var slider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.tooltip_text = tip
	slider.set_meta("shown", shown)
	_set_slider(slider, value)
	slider.value_changed.connect(func(v):
		shown.text = _format(v, step)
		on_change.call(v))
	row.add_child(head)
	row.add_child(slider)
	parent.add_child(row)
	return slider


func _set_slider(slider: HSlider, value: float) -> void:
	slider.set_value_no_signal(value)
	slider.get_meta("shown").text = _format(value, slider.step)


func _format(value: float, step: float) -> String:
	var decimals = 0 if step >= 1.0 else (3 if step < 0.01 else 2)
	return String.num(value, decimals)


func _heading(parent: Control, text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.theme_type_variation = "HeadingLabel"
	parent.add_child(label)
	return label


func _hint(parent: Control, text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.theme_type_variation = "HintLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _field(parent: Control, title: String, placeholder: String) -> LineEdit:
	var label = Label.new()
	label.text = title
	label.theme_type_variation = "FieldLabel"
	parent.add_child(label)
	var edit = LineEdit.new()
	edit.placeholder_text = placeholder
	edit.set_meta("label", label)
	parent.add_child(edit)
	return edit


func _set_letter_text(text: String, key: String) -> void:
	if current < 0:
		return
	if key == "mark":
		key = _mark_key(letters[current])
	_begin_change("letter %d %s" % [current, key])
	letters[current][key] = text
	_update_titles(current)
	_render_preview()
	_save_timer.start()


# --- Preview --------------------------------------------------------------

# A letter with diacritics on it, at a large size and at text sizes.
func _build_preview_section(box: Control) -> void:
	_heading(box, "Preview")
	_preview_picker = OptionButton.new()
	_preview_picker.tooltip_text = "The letter to preview"
	_preview_picker.item_selected.connect(func(item):
		preview_letter = _preview_choices[item]
		_render_preview())
	box.add_child(_preview_picker)
	_preview_big = GlyphThumb.new()
	_preview_big.fit = true
	_preview_big.custom_minimum_size = Vector2(0, 200)
	box.add_child(_preview_big)
	var sizes = HBoxContainer.new()
	sizes.add_theme_constant_override("separation", 10)
	sizes.alignment = BoxContainer.ALIGNMENT_CENTER
	for side in [56, 32, 20]:
		var small = GlyphThumb.new()
		small.fit = true
		small.custom_minimum_size = Vector2(side, side)
		small.size_flags_vertical = Control.SIZE_SHRINK_END
		sizes.add_child(small)
	_preview_small = sizes
	box.add_child(sizes)
	_mark_picker = OptionButton.new()
	_mark_picker.tooltip_text = "The diacritic on it"
	_mark_picker.item_selected.connect(func(item):
		preview_mark = _mark_choices[item]
		_render_preview())
	box.add_child(_mark_picker)
	box.move_child(_mark_picker, _preview_picker.get_index() + 1)


func _glyph_title(i: int) -> String:
	var letter = letters[i]
	var title = letter["name"] if letter["name"] != "" else "Untitled"
	var mark = letter[_mark_key(letter)]
	return title + ("  ·  " + mark if mark != "" else "")


# Brings the preview and its pickers up to date.
func _render_preview() -> void:
	if _preview_picker == null:
		return
	if not _is(preview_letter, "letter"):
		preview_letter = -1
		for i in letters.size():
			if _is(i, "letter"):
				preview_letter = i
				break
	if not _is(preview_mark, "diacritic"):
		preview_mark = -1
	_preview_picker.clear()
	_preview_choices = []
	for i in letters.size():
		if _is(i, "letter"):
			_preview_picker.add_item(_glyph_title(i))
			_preview_choices.append(i)
			if i == preview_letter:
				_preview_picker.select(_preview_choices.size() - 1)
	_preview_picker.disabled = _preview_choices.is_empty()
	_mark_picker.clear()
	_mark_choices = [-1]
	_mark_picker.add_item("No diacritic")
	for i in letters.size():
		if _is(i, "diacritic"):
			_mark_picker.add_item(_glyph_title(i))
			_mark_choices.append(i)
			if i == preview_mark:
				_mark_picker.select(_mark_choices.size() - 1)
	if preview_mark < 0:
		_mark_picker.select(0)
	_mark_picker.disabled = _mark_choices.size() == 1
	_refresh_preview()


# Redraws the preview, for strokes changed.
func _refresh_preview() -> void:
	var letter = letters[preview_letter]["strokes"] if preview_letter >= 0 else []
	var mark = letters[preview_mark]["strokes"] if preview_mark >= 0 else []
	var layers = Quill.compose(letter, mark, settings)
	for thumb in [_preview_big] + _preview_small.get_children():
		thumb.strokes = []
		thumb.layers = layers
		thumb.settings = settings
		thumb.queue_redraw()


func _flip_taper() -> void:
	var index = %Canvas.selected
	if index < 0:
		return
	_begin_change("")
	var stroke = %Canvas.strokes[index]
	var from = stroke["from"]
	stroke["from"] = stroke["to"]
	stroke["to"] = from
	stroke["curve"] = -stroke["curve"]  # the same bend, seen from the other end
	_set_slider(_stroke_sliders["curve"], stroke["curve"])
	_changed()


func _on_canvas_edited() -> void:
	# A dragged curve handle moves its slider.
	var index = %Canvas.selected
	if index >= 0 and _stroke_sliders.has("curve"):
		_set_slider(_stroke_sliders["curve"], %Canvas.strokes[index]["curve"])
	_changed()


# Redraws what a change shows in (every letter when the quill changed), and saves soon.
func _changed(every_letter := false) -> void:
	_refresh_preview()
	%Canvas.queue_redraw()
	if every_letter:
		# The quill changed: diacritics' magnified pens with it.
		%Canvas.settings = _pen(current)
		for i in _thumbs.size():
			_thumbs[i].settings = _pen(i)
			_thumbs[i].queue_redraw()
	elif current >= 0 and current < _thumbs.size():
		_thumbs[current].queue_redraw()
	_save_timer.start()


func _sync_tool() -> void:
	var tool = %Canvas.tool
	for pair in [[%SelectTool, "select"], [%DotTool, "dot"], [%LineTool, "line"], [%TaperTool, "taper"]]:
		pair[0].set_pressed_no_signal(pair[1] == tool)
	var keys = "Shift: steps of 15° · Alt: no snapping · Esc or right-click: cancel"
	match tool:
		"select":
			%Hint.text = "Click a stroke to select it, drag it or its handles to move it. Arrows nudge it, Delete removes it."
		"dot":
			%Hint.text = "Click to place a dot."
		"line":
			%Hint.text = ("Click where the line ends.  " + keys) if %Canvas.is_placing() else "Click where the line starts."
		"taper":
			%Hint.text = ("Click the thick end.  " + keys) if %Canvas.is_placing() else "Click the thin end of the tapered line."


# --- Undo -----------------------------------------------------------------

func _snapshot() -> Dictionary:
	return {"letters": letters.duplicate(true), "settings": settings.duplicate(), "current": current, "selected": %Canvas.selected,
		"preview_letter": preview_letter, "preview_mark": preview_mark}


# Called before every change. Changes with the same tag close together make one step.
func _begin_change(tag: String) -> void:
	var now = Time.get_ticks_msec()
	if tag != "" and tag == _last_tag and now - _last_msec < MERGE_MSEC:
		_last_msec = now
		return
	_last_tag = tag
	_last_msec = now
	_undo.append(_snapshot())
	if _undo.size() > HISTORY_LIMIT:
		_undo.pop_front()
	_redo.clear()
	_sync_history_buttons()


func undo() -> void:
	if not _undo.is_empty():
		_redo.append(_snapshot())
		_restore(_undo.pop_back())


func redo() -> void:
	if not _redo.is_empty():
		_undo.append(_snapshot())
		_restore(_redo.pop_back())


func _restore(snapshot: Dictionary) -> void:
	letters = snapshot["letters"]
	settings = snapshot["settings"]
	preview_letter = snapshot["preview_letter"]
	preview_mark = snapshot["preview_mark"]
	_last_tag = ""
	for key in _quill_sliders:
		_set_slider(_quill_sliders[key], Quill.value(settings, key))
	_render_list()
	select_letter(snapshot["current"])
	%Canvas.select(snapshot["selected"])
	_sync_history_buttons()
	_changed(true)


func _sync_history_buttons() -> void:
	%UndoButton.disabled = _undo.is_empty()
	%RedoButton.disabled = _redo.is_empty()


# Cmd+Z (Ctrl+Z) undoes, with Shift (or Ctrl+Y) redoes. A text field undoes its own typing first.
func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.pressed or not event.is_command_or_control_pressed():
		return
	if event.keycode == KEY_Z:
		if event.shift_pressed:
			redo()
		else:
			undo()
		accept_event()
	elif event.keycode == KEY_Y:
		redo()
		accept_event()


# --- The file -------------------------------------------------------------

func load_letters() -> void:
	var path = Dict.read_path(FILE)
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.get("letters", []) is Array or not data.get("diacritics", []) is Array:
		_load_problem = "« %s » couldn't be read, so the alphabet won't be saved until it is fixed." % ProjectSettings.globalize_path(path)
		var problem = _load_problem
		(func(): Dict.save_failed.emit(problem)).call_deferred()
		return
	var saved = data.get("settings", {})
	if saved is Dictionary:
		for key in Quill.DEFAULTS:
			if saved.has(key):
				settings[key] = float(saved[key])
	for kind in KINDS:
		for entry in data.get(FILE_SECTIONS[kind], []):
			if not entry is Dictionary:
				continue
			var letter = _new_letter(kind)
			letter["name"] = str(entry.get("name", ""))
			letter[_mark_key(letter)] = str(entry.get(_mark_key(letter), ""))
			var strokes = entry.get("strokes", [])
			for saved_stroke in (strokes if strokes is Array else []):
				var stroke = Quill.stroke_from_json(saved_stroke)
				if stroke != null:
					letter["strokes"].append(stroke)
			letters.append(letter)


func save() -> bool:
	_save_timer.stop()
	if _load_problem != "":
		Dict.save_failed.emit(_load_problem)
		return false
	var path = Dict.data_path(FILE)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		Dict.save_failed.emit("Couldn't save « %s » (%s)." % [
			ProjectSettings.globalize_path(path), error_string(FileAccess.get_open_error())])
		return false
	file.store_string(to_json())
	file.close()
	Writing.reload()
	alphabet_changed.emit()
	return true


# The file's text: one stroke to a line, so it reads (and diffs) a stroke at a time.
func to_json() -> String:
	var saved_settings = {}
	for key in settings:
		saved_settings[key] = snappedf(settings[key], 0.0001)
	var lines = ["{", "\t\"settings\": %s," % JSON.stringify(saved_settings, "", false)]
	for k in KINDS.size():
		var kind = KINDS[k]
		var glyphs = letters.filter(func(letter): return letter["kind"] == kind)
		lines.append("\t\"%s\": [" % FILE_SECTIONS[kind])
		for i in glyphs.size():
			var letter = glyphs[i]
			var key = _mark_key(letter)
			var strokes = []
			for stroke in letter["strokes"]:
				strokes.append("\t\t\t" + JSON.stringify(Quill.stroke_to_json(stroke), "", false))
			var head = "\t\t{\"name\": %s, \"%s\": %s, \"strokes\": [" % [JSON.stringify(letter["name"]), key, JSON.stringify(letter[key])]
			var body = ("\n" + ",\n".join(strokes) + "\n\t\t") if not strokes.is_empty() else ""
			lines.append(head + body + "]}" + ("," if i < glyphs.size() - 1 else ""))
		lines.append("\t]" + ("," if k < KINDS.size() - 1 else ""))
	lines.append("}")
	return "\n".join(lines) + "\n"


# Whatever is waiting to be saved is saved when the app closes.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		if _save_timer and not _save_timer.is_stopped():
			save()
