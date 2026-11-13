extends PanelContainer

# One row of the dictionary list. A click shows the forms derived from a module
# (a verb, noun, adjective or adverb; see Dict.derived_forms). The pencil, or a
# double-click, turns it into fields; Enter saves and Escape cancels.

signal deleted
signal edit_started
signal edited(french)
signal edit_failed(message)
signal expanded_changed(french, on)

var key = ""
var editing = false
var alternate = false
var expanded = false  # the derived forms are shown


func _ready():
	%EditButton.pressed.connect(start_edit)
	%DeleteButton.pressed.connect(_on_DeleteButton_pressed)
	%SaveButton.pressed.connect(save_edit)
	%CancelButton.pressed.connect(cancel_edit)
	for field in [%KracEdit, %FrenchEdit, %EnglishEdit]:
		field.text_submitted.connect(func(_text): save_edit())
	Dict.fill_class_picker(%ClassEdit)
	set_process_input(false)


func set_entry(french: String, is_alternate: bool, show_derived := false) -> void:
	key = french
	alternate = is_alternate
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
		if form["existing"] != "":
			note += "   ⚠ déjà dans le dictionnaire : « %s »" % form["existing"]
		_add_cell(form["name"], "HintLabel")
		_add_cell(form["word"], "KracLabel")
		_add_cell(note, "DimLabel")


func _add_cell(text: String, variation: String) -> void:
	var label = Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	%DerivedGrid.add_child(label)


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
	set_entry(french, alternate, was_expanded)
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
