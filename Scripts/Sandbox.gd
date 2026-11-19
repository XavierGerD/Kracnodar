extends HBoxContainer

# The Sandbox tab (Bac à sable): Kracnodar typed in Latin letters, shown in the
# script as it's typed, and exported as a PNG image or an SVG drawing.
#
# The text and the settings are kept between sessions in sandbox.json, with
# the machine's other scratch files (Dict.scratch_path), shortly after every change.
# The preview shows the image as it will be saved, shrunk to fit if it must:
# on a checkerboard where the background is transparent.

const Writing = preload("res://Scripts/Writing.gd")
const WritingExport = preload("res://Scripts/WritingExport.gd")
const GlyphCanvas = preload("res://Scripts/GlyphCanvas.gd")

const FILE = "sandbox.json"
const ALIGNS = [["Left", 0.0], ["Centre", 0.5], ["Right", 1.0]]
const CROPS = [["Around the ink", "ink"], ["Whole lines", "lines"]]
const CROP_TIPS = "Around the ink: as small as the text allows. Whole lines: as tall as a line is, diacritics' room included, so that words exported apart line up alike."
const CHECKER = [Color(0.78, 0.78, 0.78), Color(0.62, 0.62, 0.62)]
const CHECKER_SIDE = 8.0
const PREVIEW_PAD = 24.0

var options = {
	"text": "Kracnodar",
	"size": 128.0,  # pixels to the em: a letter's square
	"margin": 16.0,  # pixels round the text
	"word_gap": 0.45,  # em
	"line_spacing": 1.0,  # line heights
	"align": 0.5,
	"crop": "ink",
	"ink": Color.BLACK,
	"background": Color.WHITE,
	"transparent": true,
	"folder": "",  # where the last export went
}

var _layout = {}
var _canvas = {}
var _stale = false
var _save_timer: Timer
var _dialog: FileDialog
var _format = "png"
var _exported = ""  # the last file exported
var _size_input: SpinBox
var _margin_input: SpinBox
var _sliders = {}  # option -> HSlider
var _align_picker: OptionButton
var _crop_picker: OptionButton
var _ink_picker: ColorPickerButton
var _transparent_box: CheckBox
var _background_picker: ColorPickerButton


func _ready():
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.5
	_save_timer.timeout.connect(save)
	add_child(_save_timer)
	_dialog = FileDialog.new()
	_dialog.use_native_dialog = true
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_dialog.file_selected.connect(_export_to)
	add_child(_dialog)
	load_options()
	_build_settings()
	%TextInput.text = options["text"]
	%TextInput.text_changed.connect(func():
		options["text"] = %TextInput.text
		_changed())
	%PngButton.pressed.connect(_ask_where.bind("png"))
	%SvgButton.pressed.connect(_ask_where.bind("svg"))
	%ShowButton.pressed.connect(func(): OS.shell_show_in_file_manager(_exported))
	%Preview.draw.connect(_draw_preview)
	%Preview.resized.connect(%Preview.queue_redraw)
	refresh()


# --- Settings -------------------------------------------------------------

func _build_settings() -> void:
	var box = %Sections
	_size_input = _spin(box, "Letter size", 8, 2048, options["size"],
		"The height of a letter's square in the image, in pixels. Diacritics rise above it.", "size")
	_margin_input = _spin(box, "Margin", 0, 2048, options["margin"], "The space round the text, in pixels.", "margin")
	_sliders["word_gap"] = _slider(box, "Word spacing", 0.0, 2.0, 0.01, "word_gap",
		"The space between two words, in letter squares.")
	_sliders["line_spacing"] = _slider(box, "Line spacing", 0.6, 3.0, 0.01, "line_spacing",
		"How far apart lines are, in line heights (from above the diacritics to the baseline).")
	_align_picker = _picker(box, "Align", ALIGNS, options["align"], "How lines shorter than the longest sit", "align")
	_crop_picker = _picker(box, "Crop", CROPS, options["crop"], CROP_TIPS, "crop")
	box.add_child(HSeparator.new())
	_ink_picker = _colour(box, "Ink", options["ink"], "The colour of the letters", "ink")
	var label = _label(box, "Background")
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_transparent_box = CheckBox.new()
	_transparent_box.text = "Transparent"
	_transparent_box.tooltip_text = "No background: only the letters are drawn (SVG and PNG)"
	_transparent_box.button_pressed = options["transparent"]
	_transparent_box.toggled.connect(func(on):
		options["transparent"] = on
		_background_picker.disabled = on
		_changed())
	_background_picker = ColorPickerButton.new()
	_background_picker.edit_alpha = false
	_background_picker.color = options["background"]
	_background_picker.disabled = options["transparent"]
	_background_picker.custom_minimum_size = Vector2(0, 30)
	_background_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_background_picker.tooltip_text = "The colour behind the letters"
	_background_picker.color_changed.connect(func(c):
		options["background"] = c
		_changed())
	row.add_child(_transparent_box)
	row.add_child(_background_picker)
	box.add_child(row)
	label.tooltip_text = _background_picker.tooltip_text


func _label(parent: Control, text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.theme_type_variation = "FieldLabel"
	parent.add_child(label)
	return label


func _spin(parent: Control, title: String, low: float, high: float, value: float, tip: String, key: String) -> SpinBox:
	var row = HBoxContainer.new()
	row.tooltip_text = tip
	var label = _label(row, title)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	var spin = SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = 1
	spin.suffix = "px"
	spin.value = value
	spin.select_all_on_focus = true
	spin.tooltip_text = tip
	spin.value_changed.connect(func(v):
		options[key] = v
		_changed())
	row.add_child(spin)
	parent.add_child(row)
	return spin


func _slider(parent: Control, title: String, low: float, high: float, step: float, key: String, tip: String) -> HSlider:
	var row = VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.tooltip_text = tip
	var head = HBoxContainer.new()
	var label = _label(head, title)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	var shown = Label.new()
	shown.theme_type_variation = "HintLabel"
	head.add_child(shown)
	var slider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.tooltip_text = tip
	slider.set_value_no_signal(options[key])
	shown.text = String.num(options[key], 2)
	slider.value_changed.connect(func(v):
		shown.text = String.num(v, 2)
		options[key] = v
		_changed())
	row.add_child(head)
	row.add_child(slider)
	parent.add_child(row)
	return slider


# A picker of [title, value] choices.
func _picker(parent: Control, title: String, choices: Array, value, tip: String, key: String) -> OptionButton:
	var row = HBoxContainer.new()
	row.tooltip_text = tip
	var label = _label(row, title)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	var picker = OptionButton.new()
	picker.tooltip_text = tip
	picker.custom_minimum_size = Vector2(150, 0)
	for choice in choices:
		picker.add_item(choice[0])
		if choice[1] == value:
			picker.select(picker.item_count - 1)
	picker.item_selected.connect(func(item):
		options[key] = choices[item][1]
		_changed())
	row.add_child(picker)
	parent.add_child(row)
	return picker


func _colour(parent: Control, title: String, value: Color, tip: String, key: String) -> ColorPickerButton:
	var row = HBoxContainer.new()
	row.tooltip_text = tip
	var label = _label(row, title)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	var picker = ColorPickerButton.new()
	picker.edit_alpha = false
	picker.color = value
	picker.custom_minimum_size = Vector2(150, 30)
	picker.tooltip_text = tip
	picker.color_changed.connect(func(c):
		options[key] = c
		_changed())
	row.add_child(picker)
	parent.add_child(row)
	return picker


# --- The text -------------------------------------------------------------

# Lays the text out again and redraws it.
func refresh() -> void:
	_stale = false
	_layout = Writing.text_layout(options["text"], options["word_gap"], options["line_spacing"], options["align"])
	_canvas = WritingExport.canvas(_layout, options["size"], options["margin"], options["crop"])
	var inked = _layout["inked"]
	var too_big = WritingExport.too_big(_canvas)
	%EmptyLabel.visible = not inked
	%PngButton.disabled = not inked or too_big
	%SvgButton.disabled = not inked or too_big
	if not inked:
		%SizeLabel.text = ""
	elif too_big:
		%SizeLabel.text = "%d × %d px: too big to export (%d px a side at most)" % [
			_canvas["size"].x, _canvas["size"].y, WritingExport.MAX_SIDE]
	else:
		%SizeLabel.text = "%d × %d px" % [_canvas["size"].x, _canvas["size"].y]
	%MissingLabel.text = _missing_text(_layout["missing"])
	%Preview.queue_redraw()


# What has nothing drawn for it in the Alphabet tab, said in a line.
func _missing_text(missing: Dictionary) -> String:
	var groups = {"letter": [], "diacritic": [], "sign": []}
	for sound in missing:
		groups[missing[sound]].append(sound)
	var parts = []
	if not groups["letter"].is_empty():
		parts.append("letters not drawn yet, shown as squares: " + ", ".join(groups["letter"]))
	if not groups["diacritic"].is_empty():
		parts.append("diacritics not drawn yet, shown as squares: " + ", ".join(groups["diacritic"]))
	if not groups["sign"].is_empty():
		parts.append("left out, not in the alphabet: " + "  ".join(groups["sign"]))
	if parts.is_empty():
		return ""
	var text = " · ".join(parts)
	return text.left(1).to_upper() + text.substr(1)


# The Alphabet tab changed the letters: shown now, or when next shown.
func alphabet_changed() -> void:
	if is_visible_in_tree():
		refresh()
	else:
		_stale = true


func shown() -> void:
	if _stale:
		refresh()


func _changed() -> void:
	refresh()
	_save_timer.start()


func _ink() -> Color:
	return Color(options["ink"], 1.0)


func _background() -> Color:
	return Color(options["background"], 0.0 if options["transparent"] else 1.0)


# --- Preview --------------------------------------------------------------

func _draw_preview() -> void:
	var view: Control = %Preview
	view.draw_rect(Rect2(Vector2.ZERO, view.size), GlyphCanvas.PAPER)
	if not _layout.get("inked", false):
		return
	var size = Vector2(_canvas["size"])
	var room = view.size - Vector2.ONE * PREVIEW_PAD * 2.0
	if room.x <= 0.0 or room.y <= 0.0:
		return
	var fit = minf(1.0, minf(room.x / size.x, room.y / size.y))
	var shown_size = size * fit
	var at = ((view.size - shown_size) / 2.0).floor()
	var page = Rect2(at, shown_size)
	if options["transparent"]:
		_draw_checker(view, page)
	else:
		view.draw_rect(page, _background())
	var to_view = Transform2D(0.0, Vector2.ONE * _canvas["em"] * fit, 0.0, at + _canvas["origin"] * fit)
	var ink = _ink()
	var polygons = []
	for word in _layout["words"]:
		for shape in word["shapes"]:
			var polygon = to_view * shape
			if absf(WritingExport._area(polygon)) > 0.01:
				polygons.append(polygon)
	for polygon in polygons:
		view.draw_colored_polygon(polygon, ink)
	# A soft edge, as the Alphabet tab draws letters (Quill.draw_stroke).
	for polygon in polygons:
		var loop = polygon.duplicate()
		loop.append(polygon[0])
		view.draw_polyline(loop, ink, 1.0, true)


func _draw_checker(view: Control, page: Rect2) -> void:
	view.draw_rect(page, CHECKER[0])
	var rows = ceili(page.size.y / CHECKER_SIDE)
	var columns = ceili(page.size.x / CHECKER_SIDE)
	for row in rows:
		for column in range(row % 2, columns, 2):
			var square = Rect2(page.position + Vector2(column, row) * CHECKER_SIDE, Vector2.ONE * CHECKER_SIDE)
			view.draw_rect(square.intersection(page), CHECKER[1])


# --- Export ---------------------------------------------------------------

func _ask_where(format: String) -> void:
	_format = format
	_dialog.title = "Export %s" % format.to_upper()
	_dialog.filters = PackedStringArray(["*.png ; PNG image"] if format == "png" else ["*.svg ; SVG drawing"])
	var folder = options["folder"]
	if folder == "" or not DirAccess.dir_exists_absolute(folder):
		folder = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	_dialog.current_dir = folder
	_dialog.current_file = _file_name() + "." + format
	_dialog.popup_centered_ratio(0.6)


# A file name from the text's first words, what a file name can't hold left out.
func _file_name() -> String:
	var words = []
	var length = 0
	var line = options["text"].strip_edges().split("\n")[0]
	for found in RegEx.create_from_string("[^\\s:/\\\\?*\"|%<>]+").search_all(line):
		var word = found.get_string()
		if length + word.length() > 40 and not words.is_empty():
			break
		words.append(word)
		length += word.length() + 1
	var name = " ".join(words)
	return name if name != "" else "kracnodar"


func _export_to(path: String) -> void:
	if path.get_extension().to_lower() != _format:
		path += "." + _format
	%StatusLabel.text = "Exporting…"
	%ShowButton.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	var error = export_file(path, _format)
	options["folder"] = path.get_base_dir()
	_save_timer.start()
	if error == OK:
		_exported = path
		%StatusLabel.text = "Saved %s" % path.get_file()
		%StatusLabel.tooltip_text = path
		%ShowButton.visible = true
	else:
		%StatusLabel.text = "Couldn't save %s (%s)." % [path.get_file(), error_string(error)]
		%StatusLabel.tooltip_text = path


# Writes the text as it is now to a PNG or SVG file.
func export_file(path: String, format: String) -> Error:
	refresh()
	if not _layout["inked"] or WritingExport.too_big(_canvas):
		return ERR_INVALID_DATA
	if format == "png":
		return WritingExport.png(_layout, _canvas, _ink(), _background()).save_png(path)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(WritingExport.svg(_layout, _canvas, _ink(), _background(), options["text"].strip_edges()))
	file.close()
	return OK


# --- The file -------------------------------------------------------------

func load_options() -> void:
	var path = Dict.scratch_path(FILE)
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return
	for key in options:
		if not data.has(key):
			continue
		var value = data[key]
		match typeof(options[key]):
			TYPE_COLOR:
				if value is String and Color.html_is_valid(value):
					options[key] = Color.html(value)
			TYPE_FLOAT:
				if value is float or value is int:
					options[key] = float(value)
			TYPE_BOOL:
				if value is bool:
					options[key] = value
			_:
				if value is String:
					options[key] = value


func save() -> void:
	_save_timer.stop()
	var saved = {}
	for key in options:
		var value = options[key]
		saved[key] = "#" + value.to_html(false) if value is Color else value
	var file = FileAccess.open(Dict.scratch_path(FILE), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(saved, "\t") + "\n")


# Whatever is waiting to be saved is saved when the app closes.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		if _save_timer and not _save_timer.is_stopped():
			save()
