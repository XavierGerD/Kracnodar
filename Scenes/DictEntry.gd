extends PanelContainer

# One row of the dictionary list. The pencil, or a double-click, turns it into
# fields; Enter saves and Escape cancels.

signal deleted
signal edit_started
signal edited(french)
signal edit_failed(message)

var key = ""
var editing = false
var alternate = false


func _ready():
	%EditButton.pressed.connect(start_edit)
	%DeleteButton.pressed.connect(_on_DeleteButton_pressed)
	%SaveButton.pressed.connect(save_edit)
	%CancelButton.pressed.connect(cancel_edit)
	for field in [%KracEdit, %FrenchEdit, %EnglishEdit]:
		field.text_submitted.connect(func(_text): save_edit())
	set_process_input(false)


func set_entry(french: String, is_alternate: bool) -> void:
	key = french
	alternate = is_alternate
	%WordEntry.text = Dict.krac_of(french)
	%WordTranslation.text = french
	%WordEnglish.text = Dict.english_of(french)
	_show_fields(false)


func start_edit() -> void:
	if editing:
		return
	%KracEdit.text = Dict.krac_of(key)
	%FrenchEdit.text = key
	%EnglishEdit.text = Dict.english_of(key)
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
	if krac == "" or french == "":
		edit_failed.emit("Le mot kracnodar et le mot français ne peuvent pas être vides.")
		return
	var problems = Dict.clashes(french, krac, key)
	if not problems.is_empty():
		edit_failed.emit("Modification refusée :\n" + "\n".join(problems))
		return
	if not Dict.replace_entry(key, french, krac, english):  # saves dict.json
		return  # not saved: stay open with the edit
	set_entry(french, alternate)
	edited.emit(french)


# Briefly highlights the row, so it can be found after a save re-sorts the list.
func flash() -> void:
	theme_type_variation = "DictRowEditing"
	create_tween().tween_callback(_apply_style).set_delay(1.2)


func _show_fields(on: bool) -> void:
	editing = on
	for label in [%WordEntry, %WordTranslation, %WordEnglish, %EditButton, %DeleteButton]:
		label.visible = not on
	for field in [%KracEdit, %FrenchEdit, %EnglishEdit, %SaveButton, %CancelButton]:
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


func _gui_input(event):
	if event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT and not editing:
		start_edit()
		accept_event()


func _on_DeleteButton_pressed():
	if not Dict.remove_entry(key):  # saves dict.json; on failure the row stays
		return
	deleted.emit()
	queue_free()
