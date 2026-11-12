extends Control

const DictEntryScene = preload("res://Scenes/DictEntry.tscn")

enum Column { KRAC, FRENCH, ENGLISH }

const HEADER_TITLES = {Column.KRAC: "KRACNODAR", Column.FRENCH: "FRANÇAIS", Column.ENGLISH: "ENGLISH"}
const TextFold = preload("res://Scripts/TextFold.gd")

var sort_column = Column.KRAC
var sort_ascending = true
var shown_count = 0


func _ready():
	for column in HEADER_TITLES:
		_header(column).pressed.connect(sort_by.bind(column))
	%SearchInput.text_changed.connect(func(_text): refresh())
	%SearchInput.gui_input.connect(_on_SearchInput_gui_input)
	refresh()


# Clicking a column header sorts by it; clicking the same header again reverses.
func sort_by(column: int) -> void:
	if column == sort_column:
		sort_ascending = not sort_ascending
	else:
		sort_column = column
		sort_ascending = true
	refresh()


func _header(column: int) -> Button:
	return [%KracHeader, %FrenchHeader, %EnglishHeader][column]


func _update_headers() -> void:
	for column in HEADER_TITLES:
		var active = column == sort_column
		var header = _header(column)
		header.text = HEADER_TITLES[column] + (("  ↑" if sort_ascending else "  ↓") if active else "")
		header.theme_type_variation = "ColumnHeaderActive" if active else "ColumnHeader"


# The text an entry sorts on in the current column.
func _sort_text(french: String) -> String:
	match sort_column:
		Column.KRAC:
			return Dict.krac_of(french)
		Column.FRENCH:
			return french
		_:
			# "to gnaw" files under g, as in a printed dictionary.
			var english = Dict.english_of(french)
			return english.substr(3) if english.to_lower().begins_with("to ") else english


func _comes_before(a: String, b: String) -> bool:
	var left = _sort_text(a)
	var right = _sort_text(b)
	if (left == "") != (right == ""):
		return right == ""  # entries missing this word go last, in either direction
	var order = left.naturalnocasecmp_to(right)
	if order == 0:
		order = a.naturalnocasecmp_to(b)  # same word: fall back to the French
	return order < 0 if sort_ascending else order > 0


func _fold(text: String) -> String:
	return TextFold.fold(text)


func _search_text() -> String:
	return %SearchInput.text.strip_edges()


# Whether any of the entry's three words contains the (folded) search text.
func _matches(french: String, query: String) -> bool:
	if query == "":
		return true
	return _fold("\n".join([Dict.krac_of(french), french, Dict.english_of(french)])).contains(query)


# Rebuilds the list; `reveal` names an entry to scroll to and highlight. It is
# shown even if it no longer matches the search, so an edit never makes it vanish.
func refresh(reveal := "") -> void:
	for child in %Rows.get_children():
		%Rows.remove_child(child)
		child.queue_free()

	var query = _fold(_search_text())
	var keys = Dict.dict.keys().filter(func(key): return key == reveal or _matches(key, query))
	keys.sort_custom(_comes_before)
	_update_headers()
	shown_count = keys.size()

	for i in keys.size():
		var row = DictEntryScene.instantiate()
		%Rows.add_child(row)
		row.set_entry(keys[i], i % 2 == 1)
		row.deleted.connect(_on_row_deleted)
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


func _on_row_deleted() -> void:
	shown_count -= 1
	_update_count()


func _update_count() -> void:
	var total = Dict.dict.size()
	var plural = "s" if total > 1 else ""
	if _search_text() == "":
		%CountLabel.text = "%d terme%s" % [total, plural]
	else:
		%CountLabel.text = "%d sur %d terme%s" % [shown_count, total, plural]
	%EmptyLabel.visible = shown_count == 0
	if total == 0:
		%EmptyLabel.text = "Le dictionnaire est vide."
	else:
		%EmptyLabel.text = "Aucun terme ne correspond à « %s »." % _search_text()
	# Where changes go; it also pushes the search field right.
	var path = ProjectSettings.globalize_path(Dict.data_path(Dict.DICT_FILE))
	if Dict.load_problem != "":
		%FileLabel.text = "· non enregistré : dict.json est illisible"
		%FileLabel.tooltip_text = Dict.load_problem
	else:
		%FileLabel.text = "· enregistré automatiquement"
		%FileLabel.tooltip_text = path


# Escape clears the search; Ctrl+F (Cmd+F on a Mac) jumps to it.
func _on_SearchInput_gui_input(event) -> void:
	if event.is_action_pressed("ui_cancel") and %SearchInput.text != "":
		%SearchInput.clear()
		%SearchInput.accept_event()


func _shortcut_input(event) -> void:
	if is_visible_in_tree() and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F and event.is_command_or_control_pressed():
		%SearchInput.grab_focus()
		%SearchInput.select_all()
		get_viewport().set_input_as_handled()


func _error(message: String) -> void:
	%ErrorDialog.dialog_text = message
	# Fix the width so the text wraps there; the height then grows to fit.
	%ErrorDialog.size = Vector2i(480, 0)
	%ErrorDialog.popup_centered()
