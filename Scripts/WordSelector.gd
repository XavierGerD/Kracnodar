extends Control

const WordLinkerScene = preload("res://Scenes/WordLinker.tscn")


func _ready():
	%AddButton.pressed.connect(add_word.bind(""))
	%AddAllButton.pressed.connect(_on_AddAllButton_pressed)
	%Rows.child_order_changed.connect(_update_empty_hint)
	_update_empty_hint()


func add_word(krac: String) -> void:
	var linker = WordLinkerScene.instantiate()
	%Rows.add_child(linker)
	linker.set_word(krac)
	if krac == "":
		linker.get_node("KracText").grab_focus()
	else:
		linker.get_node("FrenchText").grab_focus()


func _on_AddAllButton_pressed():
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

	for entry in entries:
		Dict.add_entry(entry.fr, entry.kr, entry.en)
	for linker in linkers:
		linker.queue_free()
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
