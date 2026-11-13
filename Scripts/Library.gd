extends Control

# The Library: rooms, each holding documents (tablets, notes, labels, riddles)
# written in English and Kracnodar side by side. Each document is read by the
# players in English, Kracnodar or both, a setting saved with it; the language
# they don't read is greyed out, and its masked words are struck through. In
# "Preview" both disappear, as the players will see the document; in "Mask
# words" mode a click on a word masks or unmasks it.
# Everything lives in library.md (format at the top of that file), saved at
# once after each change, next to dict.json (see Dict.data_dir). Its markup is
# the Grammaire's (see Markup.gd), in documents and descriptions alike.

const MarkdownToolbar = preload("res://Scripts/MarkdownToolbar.gd")
const Markup = preload("res://Scripts/Markup.gd")

const LIBRARY_FILE = "library.md"
const FORMAT_NOTE = """<!--
The Kracnodar Library, shown (and editable) in the app's Bibliothèque tab.
  # Title             the library's title, once at the top; the text under it introduces it
  ## Room name        a room; the text under it, up to its first document, describes it
  ### Document        a document in that room: a tablet, a note, a label, a riddle…
  ### Document [Kracnodar]   one the players read in Kracnodar only ([English]: in English only)
  English → Kracnodar a line in both languages (-> works too; either side may be empty)
  ~~word~~            a masked word: hidden from the players until revealed
  - text              a rule, one per line
  > text              a note
  | a | b |           a table: the first row is the header; an optional dashed row
  |---|------|        under it sets the relative column widths
  *word*              a Kracnodar word, shown in the Kracnodar style
  ```                 a quote block: the lines between two ``` lines, shown as written
  other text          a paragraph; a blank line starts a new block
The Grammaire uses the same markup.
-->"""

const ENGLISH = "en"
const KRAC = "kr"
const TEXT = "text"  # a line that is not in the two columns (see Markup.blocks)
const BOTH = "both"
const FADED = 0.35  # the opacity of the language the players don't read

var title = ""
var intro = ""
# [{"name": String, "description": String,
#   "docs": [{"title": String, "body": String, "language": ENGLISH/KRAC/BOTH}]}]
var rooms = []
var load_problem = ""

var room_index = -1  # the room on the page; -1 for the library itself
var doc_index = -1   # the document open in that room; -1 for the room itself
var editing = {}     # {"kind": "library"/"room"/"doc", "room": int, "doc": int}; -1 for a new one
var _struck_font: FontVariation  # see _strike_font()
var _doc_modes = false  # whether Preview and Mask words apply: on a document's page

var _comment = RegEx.create_from_string("(?s)<!--.*?-->")
var _word = RegEx.create_from_string("[\\p{L}\\p{N}'’\\-]+")
var _heading = RegEx.create_from_string("^#{1,3} ")
var _language_tag = RegEx.create_from_string("(?i)^(.*?)\\s*\\[(english|kracnodar|krac|both)\\]$")


func _ready():
	var languages = ButtonGroup.new()
	for button in [%EnglishButton, %BothButton, %KracButton]:
		button.button_group = languages
	%EnglishButton.toggled.connect(_on_language_toggled.bind(ENGLISH))
	%BothButton.toggled.connect(_on_language_toggled.bind(BOTH))
	%KracButton.toggled.connect(_on_language_toggled.bind(KRAC))
	%PreviewButton.toggled.connect(_on_view_toggled.bind(%MarkButton))
	%MarkButton.toggled.connect(_on_view_toggled.bind(%PreviewButton))
	%OrganizeButton.toggled.connect(func(_on): render())
	%AddRoomButton.pressed.connect(open_editor.bind("room", -1, -1))
	%NewDocButton.pressed.connect(func(): open_editor("doc", room_index, -1))
	%EditButton.pressed.connect(_on_EditButton_pressed)
	%BackButton.pressed.connect(_on_BackButton_pressed)
	%SaveButton.pressed.connect(save_editor)
	%CancelButton.pressed.connect(close_editor)
	%DeleteButton.pressed.connect(_on_DeleteButton_pressed)
	%DeleteConfirm.confirmed.connect(delete_edited)
	var toolbar = MarkdownToolbar.new()
	toolbar.name = "MarkdownToolbar"
	toolbar.setup(%BodyInput)
	%Editor.add_child(toolbar)
	%Editor.move_child(toolbar, %BodyInput.get_index())
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
	var quoting = false  # inside a ``` block, where a # line is quoted text, not a heading
	for line in text.split("\n"):
		if target != null and line.strip_edges().begins_with(Markup.FENCE):
			quoting = not quoting
		if not quoting and (line.begins_with("## ") or line.begins_with("### ")):
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
				var parts = split_heading(heading)
				rooms[-1]["docs"].append({"title": parts[0], "body": "", "language": parts[1]})
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
			parts.append("### " + doc["title"] + {ENGLISH: " [English]", KRAC: " [Kracnodar]"}.get(_doc_language(doc), ""))
			if doc["body"] != "":
				parts.append(doc["body"])
	return "\n\n".join(parts) + "\n"


func _library_title() -> String:
	return title if title != "" else "The Kracnodar Library"


# A document heading as [title, language]: "The note [Kracnodar]" → ["The note", KRAC].
func split_heading(heading: String) -> Array:
	var found = _language_tag.search(heading)
	if found == null:
		return [heading, BOTH]
	var tag = found.get_string(2).to_lower()
	return [found.get_string(1), ENGLISH if tag == "english" else (BOTH if tag == "both" else KRAC)]


func _doc_language(doc: Dictionary) -> String:
	return doc.get("language", BOTH)


# Splits a document (or a description) into blocks of one kind, in order; see
# Markup.blocks. Each item keeps its line's number in the body, so a click on
# a word finds it again.
func parse_body(body: String) -> Array:
	return Markup.blocks(body)


# A body line as {"en", "kr"} when it holds an arrow, otherwise {"text"}.
func split_line(line: String) -> Dictionary:
	return Markup.split_line(line)


func join_line(item: Dictionary) -> String:
	if not item.has(ENGLISH):
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


# The index in tokens(text) of the word that starts `offset` characters into
# plain(text) (an offset masking never moves); -1 when no word starts there.
func token_at(text: String, offset: int) -> int:
	var at = 0
	var list = tokens(text)
	for i in list.size():
		if at == offset and list[i]["word"]:
			return i
		at += list[i]["text"].length()
	return -1


# The item of line n of a body (see Markup.blocks), or {} for a blank or fence line.
func item_at(body: String, n: int) -> Dictionary:
	for block in parse_body(body):
		for item in block["items"]:
			if item["line"] == n:
				return item
	return {}


# A click in "Mask words" mode: meta is "line:side:offset", the word's line in
# the body, the side it is on (en, kr or text) and where it starts in plain().
func _on_word_clicked(meta) -> void:
	var parts = str(meta).split(":")
	if parts.size() != 3 or not _has_doc():
		return
	var doc = rooms[room_index]["docs"][doc_index]
	var raw_lines = doc["body"].split("\n")
	var n = int(parts[0])
	var side = parts[1]
	var item = item_at(doc["body"], n)
	if n < 0 or n >= raw_lines.size() or not item.has(side):
		return
	item[side] = toggle_mask(item[side], token_at(item[side], int(parts[2])))
	var before = doc["body"]
	raw_lines[n] = item[TEXT] if side == TEXT else join_line(item)
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
	var quoting = false  # a # line inside a ``` block is quoted, not a heading
	for line in body.split("\n"):
		if line.strip_edges().begins_with(Markup.FENCE):
			quoting = not quoting
		elif not quoting and _heading.search(line) != null:
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
			var index = editing["doc"]
			var doc = {"title": name_text, "body": body,
				"language": _doc_language(rooms[room]["docs"][index]) if index >= 0 else BOTH}
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
	_doc_modes = on_doc
	%BackButton.visible = _has_room()
	%BackButton.text = "← " + (rooms[room_index]["name"] if on_doc else "Library")
	%LangBox.visible = on_doc
	if on_doc:
		var language = _doc_language(rooms[room_index]["docs"][doc_index])
		%EnglishButton.set_pressed_no_signal(language == ENGLISH)
		%BothButton.set_pressed_no_signal(language == BOTH)
		%KracButton.set_pressed_no_signal(language == KRAC)
	%PreviewButton.visible = on_doc
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
	_render_blocks(intro, BOTH)
	if rooms.is_empty():
		%Content.add_child(_label("No rooms yet. Add one with + New room.", "HintLabel"))
	for i in rooms.size():
		var count = rooms[i]["docs"].size()
		%Content.add_child(_link("%s   ·   %d document%s" % [rooms[i]["name"], count, "" if count == 1 else "s"],
			"TocButton", show_page.bind(i, -1)))


func _render_room(room: Dictionary) -> void:
	%Content.add_child(_label(room["name"], "SectionTitle"))
	_render_blocks(room["description"], BOTH)
	%Content.add_child(_label("Documents", "HeadingLabel"))
	if room["docs"].is_empty():
		%Content.add_child(_label("No documents yet. Add one with + New document.", "HintLabel"))
	for j in room["docs"].size():
		%Content.add_child(_link(room["docs"][j]["title"], "TocButton", show_page.bind(room_index, j)))


func _render_doc(doc: Dictionary) -> void:
	%Content.add_child(_label(doc["title"], "SectionTitle"))
	var language = _doc_language(doc)
	var shown = _render_blocks(doc["body"], language)
	if doc["body"] == "":
		%Content.add_child(_label("Nothing written yet. Edit the document to add its lines.", "HintLabel"))
	elif shown == 0 and language != BOTH and %PreviewButton.button_pressed and parse_body(doc["body"]).any(func(b): return b["kind"] == "lines"):
		%Content.add_child(_label("Nothing in %s here." % ("English" if language == ENGLISH else "Kracnodar"), "HintLabel"))


# Adds a body's blocks to the page; the lines in two columns are shown as
# `language` asks (see _lines_table). Returns how many of those tables show.
func _render_blocks(body: String, language: String) -> int:
	var shown = 0
	for block in parse_body(body):
		var items = block["items"]
		match block["kind"]:
			"lines":
				var table = _lines_table(items, language)
				if table != null:
					%Content.add_child(table)
					shown += 1
			"rules":
				%Content.add_child(_rules(items))
			"note":
				var note = _text_rich(" ".join(items.map(_item_bbcode)))
				note.add_theme_color_override("default_color", get_theme_color("font_color", "HintLabel"))
				%Content.add_child(note)
			"table":
				%Content.add_child(_table(items))
			"quote":
				var panel = Markup.quote_panel(self)
				panel.add_child(_text_rich("\n".join(Markup.trimmed_quote(items).map(_item_bbcode))))
				%Content.add_child(panel)
			_:
				%Content.add_child(_text_rich("\n".join(items.map(_item_bbcode))))
	return shown


# A line that is not in the two columns, without its mark ("- ", "> "), as BBCode.
func _item_bbcode(item: Dictionary) -> String:
	return _side_bbcode(item[TEXT], item["line"], TEXT, item["skip"])


# A wrapping text for BBCode from _side_bbcode, its masked words clickable.
func _text_rich(bbcode: String) -> RichTextLabel:
	var rich = _rich("")
	rich.add_theme_font_override("normal_font", _strike_font())
	rich.text = bbcode
	_make_clickable(rich)
	return rich


func _rules(items: Array) -> Control:
	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	for item in items:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var bullet = _label("•", "BulletLabel")
		bullet.autowrap_mode = TextServer.AUTOWRAP_OFF
		bullet.size_flags_vertical = Control.SIZE_SHRINK_BEGIN  # on the first line of a long rule
		row.add_child(bullet)
		row.add_child(_text_rich(_item_bbcode(item)))
		list.add_child(row)
	return list


# A table (see Markup.cells): the first row the header, an optional dashed row
# under it setting the relative column widths. Masks work in every cell.
func _table(items: Array) -> Control:
	var rows = items.duplicate()
	var widths = []
	if rows.size() > 1 and Markup.is_separator(plain(rows[1][TEXT])):
		widths = Markup.cells(plain(rows[1][TEXT])).map(func(cell): return float(max(1, cell.count("-"))))
		rows.remove_at(1)
	var table = VBoxContainer.new()
	table.add_theme_constant_override("separation", 2)
	for r in rows.size():
		var text = rows[r][TEXT]
		var panel = PanelContainer.new()
		panel.theme_type_variation = "DictRow" if r == 0 or r % 2 == 0 else "DictRowAlt"
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var ranges = Markup.cell_ranges(plain(text))
		for c in ranges.size():
			var cell: Control
			if r == 0:
				var heading = plain(text).substr(ranges[c][0], ranges[c][1] - ranges[c][0])
				cell = _label(heading.replace("*", "").to_upper(), "ColumnLabel")
			else:
				cell = _text_rich(_side_bbcode(text, rows[r]["line"], TEXT, ranges[c][0], ranges[c][1]))
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.size_flags_stretch_ratio = widths[c] if c < widths.size() else 1.0
			row.add_child(cell)
		panel.add_child(row)
		table.add_child(panel)
	return table


# The lines of a block in two columns, the language the players don't read
# greyed out; in preview, only theirs. Null when nothing is left to show.
func _lines_table(items: Array, language: String) -> Control:
	var hiding = language != BOTH and %PreviewButton.button_pressed
	var sides = [language] if hiding else [ENGLISH, KRAC]
	var faded = "" if language == BOTH else (KRAC if language == ENGLISH else ENGLISH)
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
		if side == faded:
			column.modulate.a = FADED
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
			else:
				cell.add_theme_font_override("normal_font", _strike_font())
			if side == faded:
				cell.modulate.a = FADED
			cell.text = _side_bbcode(rows[r][side], rows[r]["line"], side)
			_make_clickable(cell)
			row.add_child(cell)
		panel.add_child(row)
		table.add_child(panel)
	return table


# The language the players read the open document in, saved with it at once.
func _on_language_toggled(on: bool, language: String) -> void:
	if not on or not _has_doc():
		return
	var doc = rooms[room_index]["docs"][doc_index]
	var before = _doc_language(doc)
	if before == language:
		return
	doc["language"] = language
	if not save_library():
		doc["language"] = before
	_rerender()  # also puts the buttons back if the save failed


# Preview and Mask words exclude each other: a preview hides the very words
# a click would mask.
func _on_view_toggled(on: bool, other: Button) -> void:
	if on:
		other.set_pressed_no_signal(false)
	_rerender()


# One side of a line as BBCode, or the part of it from `from` to `to`
# (characters of plain(text); -1 for its end). Masked words show struck
# through, or in preview vanish (fully transparent, so they keep their room);
# in mask mode every word is a link that toggles its mask (see _on_word_clicked).
# *Kracnodar words* show in the Kracnodar style, as in the Grammaire.
func _side_bbcode(text: String, line: int, side: String, from := 0, to := -1) -> String:
	var marking = _doc_modes and %MarkButton.button_pressed
	var hiding = _doc_modes and %PreviewButton.button_pressed and not marking
	var dim = get_theme_color("font_color", "DimLabel").to_html(false)
	var krac = get_theme_color("font_color", "KracLabel").to_html(false)
	if to < 0:
		to = plain(text).length()
	# A * opens or closes a Kracnodar word; a last one with no partner is just a *.
	var stars = plain(text).substr(from, to - from).count("*")
	var in_krac = false
	var out = ""
	var at = 0  # where the token starts in plain(text)
	for token in tokens(text):
		var start = at
		at += token["text"].length()
		var lo = max(start, from)
		var hi = min(at, to)
		if hi <= lo:
			continue
		var piece = token["text"].substr(lo - start, hi - lo)
		if token["word"]:
			var meta = "%d:%s:%d" % [line, side, start] if marking else ""
			out += _token_bbcode(piece, token["masked"], hiding, dim, meta)
			continue
		# The Kracnodar style opens and closes outside a token's own tags, so they nest.
		var bits = piece.split("*")
		for b in bits.size():
			if b > 0:
				if in_krac or stars >= 2:
					out += "[/color][/b]" if in_krac else "[b][color=#%s]" % krac
					in_krac = not in_krac
				else:
					out += _token_bbcode("*", token["masked"], hiding, dim, "")
				stars -= 1
			if bits[b] != "":
				out += _token_bbcode(bits[b], token["masked"], hiding, dim, "")
	if in_krac:
		out += "[/color][/b]"
	return out


func _token_bbcode(text: String, masked: bool, hiding: bool, dim: String, meta: String) -> String:
	var shown = text.replace("[", "[lb]")
	if masked:
		if hiding:
			shown = "[color=#00000000]%s[/color]" % shown
		else:  # the line in full colour: a plain [s] draws it at half strength
			shown = "[s color=#%s][color=#%s]%s[/color][/s]" % [dim, dim, shown]
	if meta != "":
		shown = "[url=%s]%s[/url]" % [meta, shown]
	return shown


# The UI font for text that may hold struck words. Godot strikes text through
# the middle of the line box, which for the UI font (Segoe UI and its stand-ins,
# tall above the letters) is the top of the lowercase letters, where the line
# melts into them. Trading 2 px of room above for 2 px below (at the theme's
# 15 px) lowers the line to mid-letter; the lines keep their height.
func _strike_font() -> Font:
	if _struck_font == null:
		_struck_font = FontVariation.new()
		_struck_font.base_font = get_theme_font("normal_font", "RichTextLabel")
		_struck_font.spacing_top = -2
		_struck_font.spacing_bottom = 2
	return _struck_font


func _make_clickable(rich: RichTextLabel) -> void:
	if not _doc_modes:
		return
	if %PreviewButton.button_pressed:
		rich.selection_enabled = false  # a selection would draw the hidden words
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
