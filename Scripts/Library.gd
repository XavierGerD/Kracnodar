extends Control

# The Library: rooms, each holding documents (tablets, notes, labels, riddles)
# written in English and Kracnodar side by side. A document shows either
# language or both, with its masked words blanked out (or revealed, struck
# through); in "Mask words" mode a click on a word masks or unmasks it.
# Everything lives in library.md (format at the top of that file), saved at
# once after each change, next to dict.json (see Dict.data_dir).

const LIBRARY_FILE = "library.md"
const FORMAT_NOTE = """<!--
The Kracnodar Library, shown (and editable) in the app's Bibliothèque tab.
  # Title             the library's title, once at the top; the text under it introduces it
  ## Room name        a room; the text under it, up to its first document, describes it
  ### Document        a document in that room: a tablet, a note, a label, a riddle…
  English → Kracnodar a line in both languages (-> works too; either side may be empty)
  ~~word~~            a masked word: hidden from the players until revealed
  other text          a paragraph of the document; a blank line starts a new block
-->"""

const ENGLISH = "en"
const KRAC = "kr"
const TEXT = "tx"  # a paragraph line, not in either column

var title = ""
var intro = ""
var rooms = []  # [{"name": String, "description": String, "docs": [{"title": String, "body": String}]}]
var load_problem = ""

var room_index = -1  # the room on the page; -1 for the library itself
var doc_index = -1   # the document open in that room; -1 for the room itself
var editing = {}     # {"kind": "library"/"room"/"doc", "room": int, "doc": int}; -1 for a new one

var _comment = RegEx.create_from_string("(?s)<!--.*?-->")
var _arrow = RegEx.create_from_string("\\s*(?:→|->)\\s*")
var _word = RegEx.create_from_string("[\\p{L}\\p{N}'’\\-]+")
var _heading = RegEx.create_from_string("^#{1,3} ")


func _ready():
	var languages = ButtonGroup.new()
	for button in [%EnglishButton, %BothButton, %KracButton]:
		button.button_group = languages
		button.toggled.connect(func(on): if on: _rerender())
	%RevealButton.toggled.connect(func(_on): _rerender())
	%MarkButton.toggled.connect(func(_on): _rerender())
	%OrganizeButton.toggled.connect(func(_on): render())
	%AddRoomButton.pressed.connect(open_editor.bind("room", -1, -1))
	%NewDocButton.pressed.connect(func(): open_editor("doc", room_index, -1))
	%EditButton.pressed.connect(_on_EditButton_pressed)
	%BackButton.pressed.connect(_on_BackButton_pressed)
	%SaveButton.pressed.connect(save_editor)
	%CancelButton.pressed.connect(close_editor)
	%DeleteButton.pressed.connect(_on_DeleteButton_pressed)
	%DeleteConfirm.confirmed.connect(delete_edited)
	load_library()
	render()


# --- The file -------------------------------------------------------------

func load_library() -> void:
	var path = Dict.read_path(LIBRARY_FILE)
	load_problem = ""
	if not FileAccess.file_exists(path):
		load_problem = "%s is missing. A new room will create it." % LIBRARY_FILE
		parse_document("")
		return
	parse_document(FileAccess.get_file_as_string(path))


func save_library() -> bool:
	var path = Dict.data_path(LIBRARY_FILE)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_error("Couldn't save %s (%s)." % [ProjectSettings.globalize_path(path), error_string(FileAccess.get_open_error())])
		return false
	file.store_string(to_markdown())
	load_problem = ""
	return true


func parse_document(text: String) -> void:
	text = _comment.sub(text.replace("\r\n", "\n"), "", true)
	title = ""
	rooms = []
	var intro_lines = []
	var body_lines = []
	var target = null  # the room or document the lines under the last heading belong to
	var key = ""
	for line in text.split("\n"):
		if line.begins_with("## ") or line.begins_with("### "):
			if target != null:
				target[key] = "\n".join(body_lines).strip_edges()
			body_lines = []
			var heading = line.substr(line.find(" ") + 1).strip_edges()
			if line.begins_with("## "):
				rooms.append({"name": heading, "description": "", "docs": []})
				target = rooms[-1]
				key = "description"
			else:
				if rooms.is_empty():  # a document needs a room
					rooms.append({"name": "Room 1", "description": "", "docs": []})
				rooms[-1]["docs"].append({"title": heading, "body": ""})
				target = rooms[-1]["docs"][-1]
				key = "body"
		elif target == null:
			if line.begins_with("# ") and title == "":
				title = line.substr(2).strip_edges()
			else:
				intro_lines.append(line)
		else:
			body_lines.append(line)
	if target != null:
		target[key] = "\n".join(body_lines).strip_edges()
	intro = "\n".join(intro_lines).strip_edges()


func to_markdown() -> String:
	var parts = [FORMAT_NOTE, "# " + _library_title()]
	if intro != "":
		parts.append(intro)
	for room in rooms:
		parts.append("## " + room["name"])
		if room["description"] != "":
			parts.append(room["description"])
		for doc in room["docs"]:
			parts.append("### " + doc["title"])
			if doc["body"] != "":
				parts.append(doc["body"])
	return "\n\n".join(parts) + "\n"


func _library_title() -> String:
	return title if title != "" else "The Kracnodar Library"


# Splits a document into blocks of one kind, "lines" or "text", in order:
#   [{"kind": "lines", "items": [{"line": n, "en": String, "kr": String}]},
#    {"kind": "text", "items": [{"line": n, "text": String}]}]
# where n is the line's number in the body, so a click on a word finds it again.
func parse_body(body: String) -> Array:
	var blocks = []
	var current = null
	var raw_lines = body.split("\n")
	for n in raw_lines.size():
		var line = raw_lines[n].strip_edges()
		if line == "":
			current = null
			continue
		var item = split_line(line)
		item["line"] = n
		var kind = "lines" if item.has(ENGLISH) else "text"
		if current == null or current["kind"] != kind:
			current = {"kind": kind, "items": []}
			blocks.append(current)
		current["items"].append(item)
	return blocks


# A body line as {"en", "kr"} when it holds an arrow, otherwise {"text"}.
func split_line(line: String) -> Dictionary:
	var arrow = _arrow.search(line)
	if arrow == null:
		return {TEXT: line}
	return {ENGLISH: line.substr(0, arrow.get_start()).strip_edges(), KRAC: line.substr(arrow.get_end()).strip_edges()}


func join_line(item: Dictionary) -> String:
	if item.has(TEXT):
		return item[TEXT]
	return ("%s → %s" % [item[ENGLISH], item[KRAC]]).strip_edges()


# --- Masks ---------------------------------------------------------------

# One side of a line as words and the text between them, each masked or not:
#   [{"text": String, "word": bool, "masked": bool}]
func tokens(text: String) -> Array:
	var out = []
	var parts = text.split("~~")
	for p in parts.size():
		var masked = p % 2 == 1
		var segment = parts[p]
		var at = 0
		for found in _word.search_all(segment):
			if found.get_start() > at:
				out.append({"text": segment.substr(at, found.get_start() - at), "word": false, "masked": masked})
			out.append({"text": found.get_string(), "word": true, "masked": masked})
			at = found.get_end()
		if at < segment.length():
			out.append({"text": segment.substr(at), "word": false, "masked": masked})
	return out


func untokens(list: Array) -> String:
	var out = ""
	var open = false
	for token in list:
		if token["masked"] != open:
			out += "~~"
			open = token["masked"]
		out += token["text"]
	if open:
		out += "~~"
	return out


# Masks or unmasks one word. What lies between two words is masked only when
# both are, so neighbouring masked words share one ~~ span.
func toggle_mask(text: String, index: int) -> String:
	var list = tokens(text)
	if index < 0 or index >= list.size() or not list[index]["word"]:
		return text
	list[index]["masked"] = not list[index]["masked"]
	for i in list.size():
		if not list[i]["word"]:
			var before = i > 0 and list[i - 1]["word"] and list[i - 1]["masked"]
			var after = i + 1 < list.size() and list[i + 1]["word"] and list[i + 1]["masked"]
			list[i]["masked"] = before and after
	return untokens(list)


# The text a reader sees, without the ~~ marks.
func plain(text: String) -> String:
	return text.replace("~~", "")


func _on_word_clicked(meta) -> void:
	var parts = str(meta).split(":")
	if parts.size() != 3 or not _has_doc():
		return
	var doc = rooms[room_index]["docs"][doc_index]
	var raw_lines = doc["body"].split("\n")
	var n = int(parts[0])
	if n < 0 or n >= raw_lines.size():
		return
	var item = split_line(raw_lines[n].strip_edges())
	var side = parts[1]
	if not item.has(side):
		return
	item[side] = toggle_mask(item[side], int(parts[2]))
	var before = doc["body"]
	raw_lines[n] = join_line(item)
	doc["body"] = "\n".join(raw_lines)
	if not save_library():
		doc["body"] = before
		return
	_rerender()


# --- Reordering and editing ------------------------------------------------

func _has_room() -> bool:
	return room_index >= 0 and room_index < rooms.size()


func _has_doc() -> bool:
	return _has_room() and doc_index >= 0 and doc_index < rooms[room_index]["docs"].size()


func move_room(index: int, direction: int) -> void:
	var target = index + direction
	if target < 0 or target >= rooms.size():
		return
	var before = rooms.duplicate(true)
	var room = rooms[index]
	rooms.remove_at(index)
	rooms.insert(target, room)
	if not save_library():
		rooms = before
		return
	if room_index == index:
		room_index = target
	elif room_index == target:
		room_index = index
	render()


func move_doc(room: int, index: int, direction: int) -> void:
	var docs = rooms[room]["docs"]
	var target = index + direction
	if target < 0 or target >= docs.size():
		return
	var before = rooms.duplicate(true)
	var doc = docs[index]
	docs.remove_at(index)
	docs.insert(target, doc)
	if not save_library():
		rooms = before
		return
	if room_index == room:
		if doc_index == index:
			doc_index = target
		elif doc_index == target:
			doc_index = index
	render()


func open_editor(kind: String, room: int, doc: int) -> void:
	editing = {"kind": kind, "room": room, "doc": doc}
	%RoomInput.visible = kind == "doc"
	%DeleteButton.visible = (kind == "room" and room >= 0) or (kind == "doc" and doc >= 0)
	%FormatHint.visible = kind == "doc"
	match kind:
		"library":
			%EditorHeading.text = "Edit the library"
			%NameInput.placeholder_text = "Title"
			%NameInput.text = _library_title()
			%BodyInput.placeholder_text = "What the library is, how the players go through it…"
			%BodyInput.text = intro
		"room":
			%EditorHeading.text = "Edit room" if room >= 0 else "New room"
			%NameInput.placeholder_text = "Room name, e.g. Room 4"
			%NameInput.text = rooms[room]["name"] if room >= 0 else "Room %d" % (rooms.size() + 1)
			%BodyInput.placeholder_text = "What the players see when they enter…"
			%BodyInput.text = rooms[room]["description"] if room >= 0 else ""
		"doc":
			var current = rooms[room]["docs"][doc] if doc >= 0 else {"title": "", "body": ""}
			%EditorHeading.text = "Edit document" if doc >= 0 else "New document"
			%NameInput.placeholder_text = "Title, e.g. The stone tablet"
			%NameInput.text = current["title"]
			%BodyInput.placeholder_text = "Written on a stone tablet:\n\nIn my house of stone → Ga enogo ~~tinod~~ kintag"
			%BodyInput.text = current["body"]
			%RoomInput.clear()
			for i in rooms.size():
				%RoomInput.add_item(rooms[i]["name"], i)
			%RoomInput.select(room)
	%Reader.visible = false
	%Editor.visible = true
	%NameInput.grab_focus()


func close_editor() -> void:
	%Editor.visible = false
	%Reader.visible = true


func save_editor() -> void:
	var name_text = %NameInput.text.strip_edges()
	var body = %BodyInput.text.strip_edges()
	if editing["kind"] != "library" and name_text == "":
		_error("Give it a name." if editing["kind"] == "room" else "Give the document a title.")
		return
	for line in body.split("\n"):
		if _heading.search(line) != null:
			_error("A line can't start with # (it would read as a heading): “%s”" % line)
			return
	var before = [title, intro, rooms.duplicate(true), room_index, doc_index]
	var room = editing["room"]
	match editing["kind"]:
		"library":
			title = name_text
			intro = body
			room_index = -1
			doc_index = -1
		"room":
			if room >= 0:
				rooms[room]["name"] = name_text
				rooms[room]["description"] = body
			else:
				rooms.append({"name": name_text, "description": body, "docs": []})
				room = rooms.size() - 1
			room_index = room
			doc_index = -1
		"doc":
			var doc = {"title": name_text, "body": body}
			var index = editing["doc"]
			var target = %RoomInput.get_selected_id()
			if index >= 0 and target == room:
				rooms[room]["docs"][index] = doc
			else:
				if index >= 0:
					rooms[room]["docs"].remove_at(index)
				rooms[target]["docs"].append(doc)
				index = rooms[target]["docs"].size() - 1
			room_index = target
			doc_index = index
	if not save_library():
		title = before[0]
		intro = before[1]
		rooms = before[2]
		room_index = before[3]
		doc_index = before[4]
		return
	close_editor()
	render()


func _on_DeleteButton_pressed() -> void:
	if editing["kind"] == "room":
		var room = rooms[editing["room"]]
		var count = room["docs"].size()
		%DeleteConfirm.dialog_text = "Delete “%s”%s?" % [room["name"],
			"" if count == 0 else " and its %d document%s" % [count, "" if count == 1 else "s"]]
	else:
		%DeleteConfirm.dialog_text = "Delete “%s”?" % rooms[editing["room"]]["docs"][editing["doc"]]["title"]
	%DeleteConfirm.popup_centered()


func delete_edited() -> void:
	var before = [rooms.duplicate(true), room_index, doc_index]
	if editing["kind"] == "room":
		rooms.remove_at(editing["room"])
		room_index = -1
		doc_index = -1
	elif editing["kind"] == "doc":
		rooms[editing["room"]]["docs"].remove_at(editing["doc"])
		room_index = editing["room"]
		doc_index = -1
	else:
		return
	if not save_library():
		rooms = before[0]
		room_index = before[1]
		doc_index = before[2]
		return
	close_editor()
	render()


func _on_EditButton_pressed() -> void:
	if _has_doc():
		open_editor("doc", room_index, doc_index)
	elif _has_room():
		open_editor("room", room_index, -1)
	else:
		open_editor("library", -1, -1)


func _on_BackButton_pressed() -> void:
	if _has_doc():
		show_page(room_index, -1)
	else:
		show_page(-1, -1)


func show_page(room: int, doc: int) -> void:
	room_index = room
	doc_index = doc
	close_editor()
	render()
	%ContentScroll.scroll_vertical = 0


# --- Showing it --------------------------------------------------------------

func _language() -> String:
	if %EnglishButton.button_pressed:
		return ENGLISH
	if %KracButton.button_pressed:
		return KRAC
	return "both"


# Re-renders the page where it was scrolled (after a mask or a view change).
func _rerender() -> void:
	var keep = %ContentScroll.scroll_vertical
	render()
	for attempt in 3:
		await get_tree().process_frame
		%ContentScroll.scroll_vertical = keep


func render() -> void:
	if not _has_room():
		room_index = -1
	if not _has_doc():
		doc_index = -1
	for child in %Content.get_children():
		%Content.remove_child(child)
		child.queue_free()
	if load_problem != "":
		%Content.add_child(_label(load_problem, "HintLabel"))

	var on_doc = _has_doc()
	%BackButton.visible = _has_room()
	%BackButton.text = "← " + (rooms[room_index]["name"] if on_doc else "Library")
	%LangBox.visible = on_doc
	%RevealButton.visible = on_doc
	%MarkButton.visible = on_doc
	%NewDocButton.visible = _has_room() and not on_doc
	%EditButton.text = "Edit document" if on_doc else ("Edit room" if _has_room() else "Edit library")

	if on_doc:
		_render_doc(rooms[room_index]["docs"][doc_index])
	elif _has_room():
		_render_room(rooms[room_index])
	else:
		_render_library()
	_render_toc()


func _render_library() -> void:
	%Content.add_child(_label(_library_title(), "SectionTitle"))
	if intro != "":
		%Content.add_child(_rich(intro))
	if rooms.is_empty():
		%Content.add_child(_label("No rooms yet. Add one with + New room.", "HintLabel"))
	for i in rooms.size():
		var count = rooms[i]["docs"].size()
		%Content.add_child(_link("%s   ·   %d document%s" % [rooms[i]["name"], count, "" if count == 1 else "s"],
			"TocButton", show_page.bind(i, -1)))


func _render_room(room: Dictionary) -> void:
	%Content.add_child(_label(room["name"], "SectionTitle"))
	if room["description"] != "":
		%Content.add_child(_rich(room["description"]))
	%Content.add_child(_label("Documents", "HeadingLabel"))
	if room["docs"].is_empty():
		%Content.add_child(_label("No documents yet. Add one with + New document.", "HintLabel"))
	for j in room["docs"].size():
		%Content.add_child(_link(room["docs"][j]["title"], "TocButton", show_page.bind(room_index, j)))


func _render_doc(doc: Dictionary) -> void:
	%Content.add_child(_label(doc["title"], "SectionTitle"))
	var language = _language()
	var shown = 0
	for block in parse_body(doc["body"]):
		if block["kind"] == "text":
			%Content.add_child(_paragraph(block["items"]))
			continue
		var table = _lines_table(block["items"], language)
		if table != null:
			%Content.add_child(table)
			shown += 1
	if doc["body"] == "":
		%Content.add_child(_label("Nothing written yet. Edit the document to add its lines.", "HintLabel"))
	elif shown == 0 and language != "both" and parse_body(doc["body"]).any(func(b): return b["kind"] == "lines"):
		%Content.add_child(_label("Nothing in %s here." % ("English" if language == ENGLISH else "Kracnodar"), "HintLabel"))


func _paragraph(items: Array) -> Control:
	var rich = _rich("")
	var lines = items.map(func(item): return _side_bbcode(item[TEXT], item["line"], TEXT))
	rich.text = "\n".join(lines)
	_make_clickable(rich)
	return rich


# The lines of a block in one or two columns; null when the language shown has none.
func _lines_table(items: Array, language: String) -> Control:
	var sides = [ENGLISH, KRAC] if language == "both" else [language]
	var rows = items.filter(func(item): return sides.any(func(side): return item[side] != ""))
	if rows.is_empty():
		return null
	var table = VBoxContainer.new()
	table.add_theme_constant_override("separation", 2)
	var header_panel = PanelContainer.new()
	header_panel.theme_type_variation = "DictRow"
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	for side in sides:
		var column = _label("ENGLISH" if side == ENGLISH else "KRACNODAR", "ColumnLabel")
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(column)
	header_panel.add_child(header)
	table.add_child(header_panel)
	for r in rows.size():
		var panel = PanelContainer.new()
		panel.theme_type_variation = "DictRowAlt" if r % 2 == 0 else "DictRow"
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		for side in sides:
			var cell = _rich("")
			if side == KRAC:
				cell.add_theme_color_override("default_color", get_theme_color("font_color", "KracLabel"))
				cell.add_theme_font_override("normal_font", get_theme_font("font", "KracLabel"))
				cell.add_theme_font_size_override("normal_font_size", get_theme_font_size("font_size", "KracLabel"))
			cell.text = _side_bbcode(rows[r][side], rows[r]["line"], side)
			_make_clickable(cell)
			row.add_child(cell)
		panel.add_child(row)
		table.add_child(panel)
	return table


# One side of a line as BBCode. Masked words show as blanks, or struck through
# when revealed; in mask mode every word is a link that toggles its mask.
func _side_bbcode(text: String, line: int, side: String) -> String:
	var marking = %MarkButton.button_pressed
	var reveal = %RevealButton.button_pressed or marking
	var dim = get_theme_color("font_color", "DimLabel").to_html(false)
	var out = ""
	var list = tokens(text)
	for i in list.size():
		var token = list[i]
		var shown = token["text"].replace("[", "[lb]")
		if token["masked"]:
			if reveal:
				shown = "[s][color=#%s]%s[/color][/s]" % [dim, shown]
			elif token["word"]:
				shown = "[color=#%s]%s[/color]" % [dim, "_".repeat(token["text"].length())]
		if marking and token["word"]:
			shown = "[url=%d:%s:%d]%s[/url]" % [line, side, i, shown]
		out += shown
	return out


func _make_clickable(rich: RichTextLabel) -> void:
	if %MarkButton.button_pressed:
		rich.selection_enabled = false
		rich.meta_clicked.connect(_on_word_clicked)


func _render_toc() -> void:
	for child in %TocList.get_children():
		%TocList.remove_child(child)
		child.queue_free()
	var organizing = %OrganizeButton.button_pressed
	var top = _toc_button(_library_title(), "TocButton", room_index < 0, show_page.bind(-1, -1))
	var top_row = HBoxContainer.new()
	top_row.add_child(top)
	if organizing:
		var edit = _row_button("✎", "Edit")
		edit.pressed.connect(open_editor.bind("library", -1, -1))
		top_row.add_child(edit)
	%TocList.add_child(top_row)
	for i in rooms.size():
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		row.add_child(_toc_button(rooms[i]["name"], "TocButton", room_index == i and doc_index < 0, show_page.bind(i, -1)))
		if organizing:
			_add_row_tools(row, i > 0, i < rooms.size() - 1, move_room.bind(i, -1), move_room.bind(i, 1),
				open_editor.bind("room", i, -1))
		%TocList.add_child(row)
		var docs = rooms[i]["docs"]
		for j in docs.size():
			var doc_row = HBoxContainer.new()
			doc_row.add_theme_constant_override("separation", 2)
			doc_row.add_child(_toc_button(docs[j]["title"], "TocSubButton", room_index == i and doc_index == j, show_page.bind(i, j)))
			if organizing:
				_add_row_tools(doc_row, j > 0, j < docs.size() - 1, move_doc.bind(i, j, -1), move_doc.bind(i, j, 1),
					open_editor.bind("doc", i, j))
			%TocList.add_child(doc_row)


func _add_row_tools(row: HBoxContainer, can_up: bool, can_down: bool, up_action: Callable, down_action: Callable, edit_action: Callable) -> void:
	var up = _row_button("↑", "Move up")
	up.disabled = not can_up
	up.pressed.connect(up_action)
	var down = _row_button("↓", "Move down")
	down.disabled = not can_down
	down.pressed.connect(down_action)
	var edit = _row_button("✎", "Edit")
	edit.pressed.connect(edit_action)
	for button in [up, down, edit]:
		row.add_child(button)


func _toc_button(text: String, variation: String, current: bool, action: Callable) -> Button:
	var button = _link(text, variation, action)
	button.toggle_mode = true
	button.set_pressed_no_signal(current)
	return button


func _link(text: String, variation: String, action: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.tooltip_text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.clip_text = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.theme_type_variation = variation
	button.pressed.connect(action)
	return button


func _label(text: String, variation: String) -> Label:
	var label = Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _row_button(text: String, tooltip: String) -> Button:
	var button = Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(28, 0)
	button.theme_type_variation = "RowButton"
	return button


# A wrapping, selectable text. Without BBCode given, the text is escaped and
# its masks dropped (room descriptions and the introduction have none).
func _rich(text: String) -> RichTextLabel:
	var rich = RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.selection_enabled = true
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich.mouse_filter = Control.MOUSE_FILTER_PASS
	rich.text = plain(text).replace("[", "[lb]")
	return rich


func _error(message: String) -> void:
	%ErrorDialog.dialog_text = message
	%ErrorDialog.size = Vector2i(480, 0)
	%ErrorDialog.popup_centered()


# Ctrl+S (Cmd+S on a Mac) saves what is in the editor.
func _shortcut_input(event) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.is_command_or_control_pressed() and event.keycode == KEY_S and %Editor.visible:
		save_editor()
		get_viewport().set_input_as_handled()
