extends Control

# Sent whenever the Kracnodar words in the list change (a row added, removed or
# retyped), with those words in lowercase, so the generator can grey out the
# ones already picked and bring back the others.
signal words_changed(words)

const WordLinkerScene = preload("res://Scenes/WordLinker.tscn")

# The rows not yet added to the dictionary, kept between sessions.
const PENDING_FILE = "new_terms.json"

var _restoring = false


func _ready():
	%AddButton.pressed.connect(add_word.bind(""))
	%AddAllButton.pressed.connect(add_all.bind(false))
	%OverlapDialog.confirmed.connect(add_all.bind(true))
	%Rows.child_order_changed.connect(_update_empty_hint)
	%Rows.child_order_changed.connect(_announce_words)
	%Rows.child_order_changed.connect(_save_pending)
	_restore_pending()
	_update_empty_hint()


func add_word(krac: String) -> void:
	var linker = _add_row()
	linker.set_word(krac)
	_announce_words()
	_save_pending()
	if krac == "":
		linker.get_node("%KracText").grab_focus()
	else:
		linker.get_node("%FrenchText").grab_focus()


func _add_row():
	var linker = WordLinkerScene.instantiate()
	%Rows.add_child(linker)
	linker.word_changed.connect(_announce_words)
	linker.edited.connect(_save_pending)
	return linker


func _rows() -> Array:
	return %Rows.get_children().filter(func(row): return not row.is_queued_for_deletion())


# Writes the rows to new_terms.json, so closing the app loses nothing.
func _save_pending() -> void:
	if _restoring or not is_inside_tree():
		return
	var file = FileAccess.open(Dict.scratch_path(PENDING_FILE), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_rows().map(func(row): return row.get_entry()), "  "))


func _restore_pending() -> void:
	var path = Dict.scratch_path(PENDING_FILE)
	if not FileAccess.file_exists(path):
		return
	var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not saved is Array:
		return
	_restoring = true
	for entry in saved:
		if entry is Dictionary:
			_add_row().set_entry(entry)
	_restoring = false


func listed_words() -> Array:
	var words = []
	for row in _rows():
		var krac = row.get_entry().kr.to_lower()
		if krac != "":
			words.append(krac)
	return words


func _announce_words() -> void:
	if is_inside_tree():
		words_changed.emit(listed_words())


# Adds every row to the dictionary. Empty fields and exact clashes are refused;
# words that only overlap dictionary words ask first, unless already confirmed.
func add_all(overlaps_confirmed: bool) -> void:
	var linkers = %Rows.get_children().filter(func(row): return not row.is_queued_for_deletion())
	if linkers.is_empty():
		return
	var entries = linkers.map(func(row): return row.get_entry())

	var problems = []
	var seen_fr = {}
	var seen_kr = {}
	for entry in entries:
		if entry.kr == "" or entry.fr == "":
			_show(%WarningDialog, "Certains termes sont vides ou n'ont pas de traduction française.")
			return
		problems.append_array(Dict.clashes(entry.fr, entry.kr))
		if seen_fr.has(entry.fr):
			problems.append("« %s » figure deux fois dans la liste." % entry.fr)
		if seen_kr.has(entry.kr):
			problems.append("« %s » figure deux fois dans la liste." % entry.kr)
		seen_fr[entry.fr] = true
		seen_kr[entry.kr] = true
	if not problems.is_empty():
		_show(%WarningDialog, "Rien n'a été ajouté :\n" + "\n".join(problems))
		return

	if not overlaps_confirmed:
		var lines = []
		for entry in entries:
			var found = Dict.overlaps(entry.kr)
			if not found.is_empty():
				var words = found.slice(0, 4).map(func(o): return "%s (%s)" % [o["krac"], o["french"]])
				var more = found.size() - 4
				lines.append("« %s » ressemble à %s%s" % [entry.kr, ", ".join(words), " et %d autre%s" % [more, "s" if more > 1 else ""] if more > 0 else ""])
		if not lines.is_empty():
			_show(%OverlapDialog, "Ces mots ont au moins %d lettres à la suite en commun avec des mots du dictionnaire :\n%s" % [Dict.MIN_OVERLAP, "\n".join(lines)])
			return

	if not Dict.add_entries(entries):  # saves dict.json; on failure the rows stay
		return
	for linker in linkers:
		linker.queue_free()
	_save_pending()
	var count = entries.size()
	_show(%AcceptDialog, "%d terme%s ajouté%s au dictionnaire." % [count, "s" if count > 1 else "", "s" if count > 1 else ""])


func _show(dialog: AcceptDialog, message: String) -> void:
	dialog.dialog_text = message
	# Fix the width so the text wraps there; the height then grows to fit.
	dialog.size = Vector2i(480, 0)
	dialog.popup_centered()


func _update_empty_hint():
	if not is_inside_tree():
		return
	var empty = %Rows.get_children().all(func(row): return row.is_queued_for_deletion())
	%EmptyLabel.visible = empty
	%Columns.visible = not empty
	%AddAllButton.disabled = empty
