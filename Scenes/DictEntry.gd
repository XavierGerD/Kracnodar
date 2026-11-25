extends PanelContainer

# One row of the dictionary list. A click shows the forms derived from a module
# (a verb, noun, adjective or adverb; see Dict.derived_forms). The pencil, or a
# double-click, turns it into fields; Enter saves and Escape cancels. Each
# derived form has its own pencil, which opens fields for its spelling (empty =
# the one its affix gives, see Dict.set_derived) and its meaning.

const TextFold = preload("res://Scripts/TextFold.gd")
const MATCH_COLOUR = Color(0.9411765, 0.5647059, 0.30980393)  # a derived form the search found

signal deleted
signal edit_started
signal edited(french)
signal edit_failed(message)
signal expanded_changed(french, on)

var key = ""
var editing = false
var alternate = false
var expanded = false  # the derived forms are shown
var query = ""  # the folded search text, to light up the derived forms it found
var _defining = ""  # the name of the derived form being edited, or ""


func _ready():
	%EditButton.pressed.connect(start_edit)
	%DeleteButton.pressed.connect(_on_DeleteButton_pressed)
	%SaveButton.pressed.connect(save_edit)
	%CancelButton.pressed.connect(cancel_edit)
	for field in [%KracEdit, %FrenchEdit, %EnglishEdit]:
		field.text_submitted.connect(func(_text): save_edit())
	Dict.fill_class_picker(%ClassEdit)
	set_process_input(false)


func set_entry(french: String, is_alternate: bool, show_derived := false, search := "") -> void:
	key = french
	alternate = is_alternate
	query = search
	_defining = ""
	%WordEntry.text = Dict.krac_of(french)
	%WordTranslation.text = french
	%WordEnglish.text = Dict.english_of(french)
	%WordClass.text = Dict.class_label(Dict.class_of(french))
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if Dict.has_derived_forms(french) else CURSOR_ARROW
	_show_fields(false)
	_set_expanded(show_derived)


# Shows or hides the derived forms; does nothing for words that have none.
func toggle_derived() -> void:
	if not Dict.has_derived_forms(key):
		return
	_set_expanded(not expanded)
	expanded_changed.emit(key, expanded)


func _set_expanded(on: bool) -> void:
	var derivable = Dict.has_derived_forms(key)
	expanded = on and derivable
	%Chevron.text = ("▾" if expanded else "▸") if derivable else ""
	%Derived.visible = expanded
	if expanded:
		_fill_derived()


func _fill_derived() -> void:
	for child in %DerivedGrid.get_children():
		%DerivedGrid.remove_child(child)
		child.queue_free()
	for form in Dict.derived_forms(key):
		var note = form["affix"] if form["affix"] != "" else "le module, sans affixe"
		if form["respelled"]:
			note += "   au lieu de « %s »" % form["regular"]
		if form["existing"] != "":
			note += "   ⚠ déjà dans le dictionnaire : « %s »" % form["existing"]
		_add_cell(form["name"], "HintLabel")
		var tools = HBoxContainer.new()
		tools.add_theme_constant_override("separation", 2)
		if form["affix"] != "" and form["name"] == _defining:
			var word = _add_field(form["word"], form["regular"], 120)
			var meaning = _add_field(form["meaning"], "Sens, ex. : freedom", 200)
			var save = func(): _save_derived(form["name"], meaning.text, word.text)
			for field in [word, meaning]:
				field.text_submitted.connect(func(_text): save.call())
			(func():
				if meaning.is_inside_tree():
					meaning.grab_focus()
					meaning.select_all()).call_deferred()
			tools.add_child(_derived_button("✓", "Enregistrer (Entrée)", save))
			tools.add_child(_derived_button("↩", "Annuler (Échap)", _define.bind("")))
		else:
			var found = _found(form)
			var word_label = _add_cell(form["word"], "KracLabel")
			var meaning_label = _add_meaning(form)
			if found:
				(meaning_label if form["meaning"] != "" else word_label).add_theme_color_override("font_color", MATCH_COLOUR)
			if form["affix"] != "":  # none on the module's own line: it is the entry itself
				tools.add_child(_derived_button("✎", "Définir ce mot ou changer son orthographe", _define.bind(form["name"])))
		_add_cell(note, "DimLabel")
		%DerivedGrid.add_child(tools)


func _derived_button(text: String, tooltip: String, action: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(32, 0)
	button.focus_mode = Control.FOCUS_NONE
	button.theme_type_variation = "RowButton"
	button.pressed.connect(action)
	return button


# The meaning of a derived form (the entry's own on the module's line).
func _add_meaning(form: Dictionary) -> Label:
	var meaning = form["meaning"] if form["affix"] != "" else Dict.english_of(key)
	return _add_cell(meaning, "DimLabel" if form["affix"] == "" else "")


# Whether the search found this derived form, through its meaning or its own spelling.
func _found(form: Dictionary) -> bool:
	return form["affix"] != "" and query != "" and (form["meaning"] != "" or form["respelled"]) \
			and TextFold.fold(form["word"] + "\n" + form["meaning"]).contains(query)


# A field of the derived form being edited; Escape closes the form's fields.
func _add_field(text: String, placeholder: String, width: float) -> LineEdit:
	var field = LineEdit.new()
	field.text = text
	field.placeholder_text = placeholder
	field.custom_minimum_size = Vector2(width, 0)
	field.theme_type_variation = "CompactLineEdit"
	field.gui_input.connect(func(event):
		if event.is_action_pressed("ui_cancel"):
			field.accept_event()
			_define(""))
	%DerivedGrid.add_child(field)
	return field


# Opens the fields of a derived form ("" closes them).
func _define(form_name: String) -> void:
	_defining = form_name
	_fill_derived()


func _save_derived(form_name: String, meaning: String, krac: String) -> void:
	if Dict.set_derived(key, form_name, meaning, krac):  # saves dict.json; on failure the fields stay
		_define("")


func _add_cell(text: String, variation: String) -> Label:
	var label = Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	%DerivedGrid.add_child(label)
	return label


func start_edit() -> void:
	if editing:
		return
	%KracEdit.text = Dict.krac_of(key)
	%FrenchEdit.text = key
	%EnglishEdit.text = Dict.english_of(key)
	Dict.pick_class(%ClassEdit, Dict.class_of(key))
	_show_fields(true)
	edit_started.emit()
	%KracEdit.grab_focus()
	%KracEdit.caret_column = %KracEdit.text.length()


func cancel_edit() -> void:
	if editing:
		_show_fields(false)


func save_edit() -> void:
	if not editing:
		return
	var krac = %KracEdit.text.strip_edges()
	var french = %FrenchEdit.text.strip_edges()
	var english = %EnglishEdit.text.strip_edges()
	var word_class = Dict.picked_class(%ClassEdit)
	if krac == "" or french == "":
		edit_failed.emit("Le mot kracnodar et le mot français ne peuvent pas être vides.")
		return
	var problems = Dict.clashes(french, krac, key)
	if not problems.is_empty():
		edit_failed.emit("Modification refusée :\n" + "\n".join(problems))
		return
	if not Dict.replace_entry(key, french, krac, english, word_class):  # saves dict.json
		return  # not saved: stay open with the edit
	var old_key = key
	var was_expanded = expanded
	set_entry(french, alternate, was_expanded, query)
	if old_key != french or expanded != was_expanded:
		expanded_changed.emit(old_key, false)
		expanded_changed.emit(french, expanded)
	edited.emit(french)


# Briefly highlights the row, so it can be found after a save re-sorts the list.
func flash() -> void:
	theme_type_variation = "DictRowEditing"
	create_tween().tween_callback(_apply_style).set_delay(1.2)


func _show_fields(on: bool) -> void:
	editing = on
	for label in [%WordEntry, %WordTranslation, %WordEnglish, %WordClass, %EditButton, %DeleteButton]:
		label.visible = not on
	for field in [%KracEdit, %FrenchEdit, %EnglishEdit, %ClassEdit, %SaveButton, %CancelButton]:
		field.visible = on
	set_process_input(on)
	_apply_style()


func _apply_style() -> void:
	if editing:
		theme_type_variation = "DictRowEditing"
	else:
		theme_type_variation = "DictRowAlt" if alternate else "DictRow"


func _input(event):
	if editing and event.is_action_pressed("ui_cancel"):
		cancel_edit()
		get_viewport().set_input_as_handled()


# A click on the row shows or hides the derived forms; a double-click edits.
# Clicks among the derived forms leave them open.
func _gui_input(event):
	if editing or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not %Row.get_global_rect().has_point(event.global_position):
		return
	toggle_derived()  # on a double-click, this undoes the first click's
	if event.double_click:
		start_edit()
	accept_event()


func _on_DeleteButton_pressed():
	if not Dict.remove_entry(key):  # saves dict.json; on failure the row stays
		return
	deleted.emit()
	queue_free()
