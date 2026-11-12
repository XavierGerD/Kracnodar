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
	%SaveButton.pressed.connect(%SaveDialog.popup_centered_ratio.bind(0.6))
	%ImportButton.pressed.connect(%ImportDialog.popup_centered_ratio.bind(0.6))
	%SaveDialog.file_selected.connect(_on_SaveDialog_file_selected)
	%ImportDialog.file_selected.connect(_on_ImportDialog_file_selected)
	%ImportConfirmDialog.confirmed.connect(_on_ImportConfirmDialog_confirmed)
	refresh()


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


func _on_SaveDialog_file_selected(path):
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_error("Impossible d'écrire « %s » (%s)." % [path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(Dict.to_json())


func _on_ImportDialog_file_selected(path):
	import_path = path
	%ImportConfirmDialog.popup_centered()


func _on_ImportConfirmDialog_confirmed():
	if import_path != "":
		import_file(import_path)
	import_path = ""


func import_file(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_error("Impossible de lire « %s » (%s)." % [path, error_string(FileAccess.get_open_error())])
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		_error("Ce fichier n'est pas du JSON valide (ligne %d : %s)." % [json.get_error_line() + 1, json.get_error_message()])
		return
	if Dict.merge(json.data) < 0:
		_error("Ce fichier ne contient pas de dictionnaire.")
		return
	refresh()


func _error(message: String) -> void:
	%ErrorDialog.dialog_text = message
	# Fix the width so the text wraps there; the height then grows to fit.
	%ErrorDialog.size = Vector2i(480, 0)
	%ErrorDialog.popup_centered()
