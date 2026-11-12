extends Control

const DictEntryScene = preload("res://Scenes/DictEntry.tscn")

enum SortBy { KRAC_ASC, KRAC_DESC, FR_ASC, FR_DESC }

var sort_by = SortBy.KRAC_ASC
var import_path = ""


func _ready():
	%KracAscButton.pressed.connect(_sort.bind(SortBy.KRAC_ASC))
	%KracDesButton.pressed.connect(_sort.bind(SortBy.KRAC_DESC))
	%FraAscButton.pressed.connect(_sort.bind(SortBy.FR_ASC))
	%FraDesButton.pressed.connect(_sort.bind(SortBy.FR_DESC))
	%SaveButton.pressed.connect(_on_SaveButton_pressed)
	%ImportButton.pressed.connect(_on_ImportButton_pressed)
	%SaveDialog.file_selected.connect(_on_SaveDialog_file_selected)
	%ImportDialog.file_selected.connect(_on_ImportDialog_file_selected)
	%ImportConfirmDialog.confirmed.connect(_on_ImportConfirmDialog_confirmed)
	_load_last_file()
	refresh()


# Reopens the dictionary from last time. A file that can no longer be read is
# forgotten, so the warning shows once rather than at every start.
func _load_last_file() -> void:
	if Dict.file_path == "":
		return
	var error = Dict.load_file(Dict.file_path)
	if error != "":
		Dict.remember_file("")
		_error.call_deferred("Le dernier dictionnaire n'a pas pu être rouvert.\n" + error)


func _sort(order: int) -> void:
	sort_by = order
	refresh()


# Rebuilds the list; `reveal` names an entry to scroll to and highlight.
func refresh(reveal := "") -> void:
	for child in %Rows.get_children():
		%Rows.remove_child(child)
		child.queue_free()

	var by_krac = sort_by == SortBy.KRAC_ASC or sort_by == SortBy.KRAC_DESC
	var keys = Dict.dict.keys()
	keys.sort_custom(func(a, b):
		var left = Dict.krac_of(a) if by_krac else a
		var right = Dict.krac_of(b) if by_krac else b
		return left.naturalnocasecmp_to(right) < 0)
	if sort_by == SortBy.KRAC_DESC or sort_by == SortBy.FR_DESC:
		keys.reverse()

	for i in keys.size():
		var row = DictEntryScene.instantiate()
		%Rows.add_child(row)
		row.set_entry(keys[i], i % 2 == 1)
		row.deleted.connect(_update_count)
		row.edit_started.connect(_on_row_edit_started.bind(row))
		# Deferred: the row that saved is freed by the rebuild, mid-signal otherwise.
		row.edited.connect(func(french): refresh.call_deferred(french))
		row.edit_failed.connect(_error)
		if keys[i] == reveal:
			_reveal(row)
	_update_count()


func _on_row_edit_started(editing_row) -> void:
	for row in %Rows.get_children():
		if row != editing_row:
			row.cancel_edit()


func _reveal(row) -> void:
	await get_tree().process_frame
	if is_instance_valid(row) and row.is_inside_tree():
		%Scroll.ensure_control_visible(row)
		row.flash()


func _update_count() -> void:
	var count = Dict.dict.size()
	%CountLabel.text = "%d terme%s" % [count, "s" if count > 1 else ""]
	%EmptyLabel.visible = count == 0
	%SaveButton.disabled = count == 0
	# Blank rather than hidden: the label also pushes the sort buttons right.
	%FileLabel.text = "· " + Dict.file_path.get_file() if Dict.file_path != "" else ""
	%FileLabel.tooltip_text = Dict.file_path


# Both dialogs open on the current file, so saving back to it is one click.
func _on_SaveButton_pressed():
	if Dict.file_path != "":
		%SaveDialog.current_path = Dict.file_path
	%SaveDialog.popup_centered_ratio(0.6)


func _on_ImportButton_pressed():
	if Dict.file_path != "":
		%ImportDialog.current_dir = Dict.file_path.get_base_dir()
	%ImportDialog.popup_centered_ratio(0.6)


func _on_SaveDialog_file_selected(path):
	var error = Dict.save_file(path)
	if error != "":
		_error(error)
		return
	Dict.remember_file(path)
	_update_count()


func _on_ImportDialog_file_selected(path):
	import_path = path
	%ImportConfirmDialog.popup_centered()


func _on_ImportConfirmDialog_confirmed():
	if import_path != "":
		import_file(import_path)
	import_path = ""


func import_file(path: String) -> void:
	var error = Dict.load_file(path)
	if error != "":
		_error(error)
		return
	Dict.remember_file(path)
	refresh()


func _error(message: String) -> void:
	%ErrorDialog.dialog_text = message
	# Fix the width so the text wraps there; the height then grows to fit.
	%ErrorDialog.size = Vector2i(480, 0)
	%ErrorDialog.popup_centered()
