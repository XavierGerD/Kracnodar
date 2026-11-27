extends Control

const DictEntryScene = preload("res://Scenes/DictEntry.tscn")

enum Column { KRAC, FRENCH, ENGLISH, CLASS }

const HEADER_TITLES = {Column.KRAC: "KRACNODAR", Column.FRENCH: "FRANÇAIS", Column.ENGLISH: "ENGLISH", Column.CLASS: "CLASSE"}
const TextFold = preload("res://Scripts/TextFold.gd")

var sort_column = Column.KRAC
var sort_ascending = true
var shown_count = 0
var _derived = [{"defined": 0, "derived": 0}, -1]  # [Dict.derived_counts(), the hash of the dictionary it counted]
var _groups = []  # the letter index: [{"letter", "count", "first": French key of its first row}]
var _row_groups = []  # for each row, its letter's index in _groups (-1 for none)
var _expanded = {}  # French keys of the rows showing their derived forms, kept across rebuilds

# What the search works out for each entry, kept until the dictionary changes
# (Dict.revision), so typing doesn't fold every entry again on each key:
#   French key -> {"text": its three words and class, folded, "krac": its
#   Kracnodar word, folded, "derived": the folded word and meaning of each
#   derived form with a meaning or a spelling of its own}
var _index = {}
var _sort_keys = {}  # French key -> its folded _sort_text in _sort_keys_column
var _sort_keys_column = -1
var _index_revision = -1


func _ready():
	for column in HEADER_TITLES:
		_header(column).pressed.connect(sort_by.bind(column))
	%SearchInput.text_changed.connect(func(_text): refresh())
	%SearchInput.gui_input.connect(_on_SearchInput_gui_input)
	%Rail.letter_selected.connect(_on_letter_selected)
	%Scroll.get_v_scroll_bar().value_changed.connect(func(_value): _update_active_letter())
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
	return [%KracHeader, %FrenchHeader, %EnglishHeader, %ClassHeader][column]


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
		Column.CLASS:
			return Dict.class_label(Dict.class_of(french))
		_:
			# "to gnaw" files under g, as in a printed dictionary.
			var english = Dict.english_of(french)
			return english.substr(3) if english.to_lower().begins_with("to ") else english


# Compared without accents, so "étincelle" files under e, with its letter.
func _comes_before(a: String, b: String) -> bool:
	var left = _sort_key(a)
	var right = _sort_key(b)
	if (left == "") != (right == ""):
		return right == ""  # entries missing this word go last, in either direction
	var order = left.naturalnocasecmp_to(right)
	if order == 0 and sort_column == Column.CLASS:
		order = _indexed(a)["krac"].naturalnocasecmp_to(_indexed(b)["krac"])  # within a class, by Kracnodar
	if order == 0:
		order = a.naturalnocasecmp_to(b)  # same word: fall back to the French
	return order < 0 if sort_ascending else order > 0


func _fold(text: String) -> String:
	return TextFold.fold(text)


# Forgets what was worked out from the dictionary once it has changed.
func _check_index() -> void:
	if _index_revision != Dict.revision:
		_index = {}
		_sort_keys = {}
		_index_revision = Dict.revision


# The entry's folded texts (see _index), worked out the first time they are asked for.
func _indexed(french: String) -> Dictionary:
	_check_index()
	if not _index.has(french):
		var texts = [Dict.krac_of(french), french, Dict.english_of(french), Dict.class_label(Dict.class_of(french))]
		var derived = []
		if not Dict.derived_data(french).is_empty():
			for form in Dict.derived_forms(french):
				if form["meaning"] != "" or form["respelled"]:
					derived.append(_fold(form["word"] + "\n" + form["meaning"]))
		_index[french] = {"text": _fold("\n".join(texts)), "krac": _fold(Dict.krac_of(french)), "derived": derived}
	return _index[french]


# The folded text the entry sorts on in the current column.
func _sort_key(french: String) -> String:
	_check_index()
	if _sort_keys_column != sort_column:
		_sort_keys = {}
		_sort_keys_column = sort_column
	if not _sort_keys.has(french):
		_sort_keys[french] = _fold(_sort_text(french))
	return _sort_keys[french]


func _search_text() -> String:
	return %SearchInput.text.strip_edges()


# Whether the entry's three words, or its class, contain the (folded) search
# text, or one of its derived forms that was given a meaning or a spelling does.
func _matches(french: String, query: String) -> bool:
	if query == "":
		return true
	return _indexed(french)["text"].contains(query) or _matches_derived(french, query)


# Whether a derived form with a meaning or a spelling of its own, its word or
# that meaning, contains the search text.
func _matches_derived(french: String, query: String) -> bool:
	if query == "":
		return false
	for text in _indexed(french)["derived"]:
		if text.contains(query):
			return true
	return false


# Rebuilds the list; `reveal` names an entry to scroll to and highlight. It is
# shown even if it no longer matches the search, so an edit never makes it vanish.
# The rows already made are filled again rather than made anew, since adding a
# row to the tree is what costs the most; those left over are hidden, after the
# shown ones, until a longer list needs them.
func refresh(reveal := "") -> void:
	var rows = []
	for child in %Rows.get_children():
		if child.is_queued_for_deletion():
			%Rows.remove_child(child)  # a deleted row, freed at the end of the frame
		else:
			rows.append(child)

	var query = _fold(_search_text())
	var keys = Dict.dict.keys().filter(func(key): return key == reveal or _matches(key, query))
	keys.sort_custom(_comes_before)
	_update_headers()
	shown_count = keys.size()

	# An entry gets back the row that showed it, if any, whose derived forms
	# may then stay as they are (see DictEntry._set_expanded).
	var shown = {}
	for key in keys:
		shown[key] = true
	var by_key = {}
	var spare = []
	for row in rows:
		if shown.has(row.key) and not by_key.has(row.key):
			by_key[row.key] = row
		else:
			spare.append(row)
	for i in keys.size():
		var row = by_key.get(keys[i])
		if row == null:
			row = spare.pop_back() if not spare.is_empty() else _new_row()
		if row.get_index() != i:
			%Rows.move_child(row, i)
		row.visible = true
		# A row the search found through a derived form opens on it.
		row.set_entry(keys[i], i % 2 == 1, _expanded.has(keys[i]) or _matches_derived(keys[i], query), query)
		if keys[i] == reveal:
			_reveal(row)
	for row in spare:
		row.cancel_edit()
		row.visible = false
	_build_letter_index(keys)
	_update_count()


# The letter an entry files under in the current column: A–Z, or # for anything
# else; "" when it has no word there (an entry without English).
func _initial(french: String) -> String:
	var text = _sort_key(french).strip_edges()
	if text == "":
		return ""
	var letter = text[0].to_upper()
	return letter if letter >= "A" and letter <= "Z" else "#"


func _new_row():
	var row = DictEntryScene.instantiate()
	%Rows.add_child(row)
	row.expanded_changed.connect(_on_row_expanded_changed)
	row.deleted.connect(_on_row_deleted)
	row.edit_started.connect(_on_row_edit_started.bind(row))
	# Deferred: the row that saved is filled again by the rebuild, mid-signal otherwise.
	row.edited.connect(func(french): refresh.call_deferred(french))
	row.edit_failed.connect(_error)
	return row


# The rows on show, in order (the hidden ones wait after them, see refresh).
func _shown_rows() -> Array:
	return %Rows.get_children().filter(func(row): return row.visible and not row.is_queued_for_deletion())


func _build_letter_index(keys: Array) -> void:
	_groups = []
	_row_groups = []
	for key in keys:
		var letter = _initial(key)
		if letter == "":
			_row_groups.append(-1)
			continue
		if _groups.is_empty() or _groups[-1]["letter"] != letter:
			_groups.append({"letter": letter, "count": 0, "first": key})
		_groups[-1]["count"] += 1
		_row_groups.append(_groups.size() - 1)
	%Rail.set_groups(_groups)
	_update_active_letter.call_deferred()


func _on_letter_selected(index: int) -> void:
	for row in _shown_rows():
		if row.key == _groups[index]["first"]:
			%Scroll.scroll_vertical = int(row.position.y)
			row.flash()
			return


# Lights the letter of the row at the top of the list.
func _update_active_letter() -> void:
	var top = %Scroll.scroll_vertical
	var rows = %Rows.get_children()
	for i in mini(rows.size(), _row_groups.size()):
		if rows[i].position.y + rows[i].size.y > top + 1:
			%Rail.set_active(_row_groups[i])
			return
	%Rail.set_active(-1)


func _on_row_expanded_changed(french: String, on: bool) -> void:
	if on:
		_expanded[french] = true
	else:
		_expanded.erase(french)


# Whether a row is open for editing, or one of its derived forms' meanings:
# a change not saved yet.
func has_open_edit() -> bool:
	for row in _shown_rows():
		if row.editing or row._defining != "":
			return true
	return false


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
	refresh.call_deferred()  # the letter index and row stripes follow


func _update_count() -> void:
	# Counted again only when the dictionary changed, not as the search is typed.
	if _derived[1] != Dict.dict.hash():
		_derived = [Dict.derived_counts(), Dict.dict.hash()]
	var entries = Dict.dict.size()
	var defined = _derived[0]["defined"]
	var total = entries + defined  # the entries and the derived forms given a meaning
	var plural = "s" if total > 1 else ""
	if _search_text() == "":
		%CountLabel.text = "%d terme%s" % [total, plural]
	else:
		%CountLabel.text = "%d sur %d terme%s" % [shown_count, total, plural]
	var derived = _derived[0]["derived"]
	if derived > 0:
		%CountLabel.text += " · %d mot%s dérivé%s" % [derived, "s" if derived > 1 else "", "s" if derived > 1 else ""]
	%CountLabel.mouse_filter = Control.MOUSE_FILTER_PASS  # for the tooltip
	%CountLabel.tooltip_text = "Termes : les %d entrées du dictionnaire et les %d formes dérivées auxquelles un sens a été donné.\nMots dérivés : les autres formes que les modules (verbes, noms, adjectifs, adverbes) donnent avec leurs affixes, chacune comptée une fois, sans celles qui sont déjà des termes du dictionnaire." % [entries, defined]
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
