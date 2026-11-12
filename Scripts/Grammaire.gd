extends Control

# The grammar reference. It reads grammar.md (format described at the top of
# that file), shows each article as rules, notes, examples and tables, filters
# them with the search field, and lets articles be added, edited, deleted and
# reordered. Every change saves at once, to the same place as dict.json
# (see Dict.data_dir: the repo when run from Godot).

const TextFold = preload("res://Scripts/TextFold.gd")

const GRAMMAR_FILE = "grammar.md"
const CHAPTER = 1
const ARTICLE = 2
const FORMAT_NOTE = """<!--
The Kracnodar grammar, shown (and editable) in the app's Grammaire tab.
  # Title             the page title, once at the top; the line under it is the subtitle
  ## Heading          a chapter        ### Heading   an article within it
  - text              a rule, one per line
  > text              a note
  English → Kracnodar an example line (-> works too)
  | a | b |           a table: the first row is the header; an optional dashed row
  |---|------|        under it sets the relative column widths
  *word*              a Kracnodar word, shown in the Kracnodar style
-->"""

# Search highlights are marked with these before the text becomes BBCode.
const MARK_OPEN = "\u0001"
const MARK_CLOSE = "\u0002"

var title = ""
var subtitle = ""
var sections = []  # [{"title": String, "level": CHAPTER or ARTICLE, "body": String}]
var load_problem = ""
var editing_index = -1  # the article in the editor; -1 for a new one

var _headings = {}  # section index -> its heading on the page
var _krac_word = RegEx.create_from_string("\\*([^*]+)\\*")
var _comment = RegEx.create_from_string("(?s)<!--.*?-->")
var _separator_cell = RegEx.create_from_string("^:?-+:?$")


func _ready():
	%LevelInput.add_item("Chapter", CHAPTER)
	%LevelInput.add_item("Article", ARTICLE)
	%SearchInput.text_changed.connect(func(_text): render())
	%SearchInput.gui_input.connect(_on_SearchInput_gui_input)
	%OrganizeButton.toggled.connect(func(_on): render())
	%AddButton.pressed.connect(open_editor.bind(-1))
	%SaveArticleButton.pressed.connect(save_article)
	%CancelButton.pressed.connect(close_editor)
	%DeleteArticleButton.pressed.connect(_on_DeleteArticleButton_pressed)
	%DeleteConfirm.confirmed.connect(delete_article)
	load_grammar()
	render()


# --- The file -------------------------------------------------------------

func load_grammar() -> void:
	var path = Dict.read_path(GRAMMAR_FILE)
	load_problem = ""
	if not FileAccess.file_exists(path):
		load_problem = "%s is missing. New articles will create it." % GRAMMAR_FILE
		parse_document("")
		return
	parse_document(FileAccess.get_file_as_string(path))


func save_grammar() -> bool:
	var path = Dict.data_path(GRAMMAR_FILE)
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
	sections = []
	var subtitle_lines = []
	var body_lines = []
	for line in text.split("\n"):
		if line.begins_with("### ") or line.begins_with("## "):
			if not sections.is_empty():
				sections[-1]["body"] = "\n".join(body_lines).strip_edges()
			var level = ARTICLE if line.begins_with("### ") else CHAPTER
			sections.append({"title": line.substr(level + 2).strip_edges(), "level": level, "body": ""})
			body_lines = []
		elif sections.is_empty():
			if line.begins_with("# ") and title == "":
				title = line.substr(2).strip_edges()
			elif line.strip_edges() != "":
				subtitle_lines.append(line.strip_edges())
		else:
			body_lines.append(line)
	if not sections.is_empty():
		sections[-1]["body"] = "\n".join(body_lines).strip_edges()
	subtitle = " ".join(subtitle_lines)


func to_markdown() -> String:
	var parts = [FORMAT_NOTE, "# " + (title if title != "" else "Grammar")]
	if subtitle != "":
		parts.append(subtitle)
	for section in sections:
		parts.append(("## " if section["level"] == CHAPTER else "### ") + section["title"])
		if section["body"] != "":
			parts.append(section["body"])
	return "\n\n".join(parts) + "\n"


# Splits an article's text into blocks of one kind: rules, notes, examples, tables, text.
func parse_body(body: String) -> Array:
	var blocks = []
	var current = null
	for raw in body.split("\n"):
		var line = raw.strip_edges()
		if line == "":
			current = null
			continue
		var kind = "text"
		var item = line
		if line.begins_with("- "):
			kind = "rules"
			item = line.substr(2)
		elif line.begins_with(">"):
			kind = "note"
			item = line.substr(1).strip_edges()
		elif line.begins_with("|"):
			kind = "table"
		elif line.contains(" → ") or line.contains(" -> "):
			kind = "examples"
		if current == null or current["kind"] != kind:
			current = {"kind": kind, "items": []}
			blocks.append(current)
		current["items"].append(item)
	return blocks


# --- Reordering and editing ------------------------------------------------

# The sections that move with the one at `index`: a chapter carries its articles.
func _group_end(index: int) -> int:
	var end = index + 1
	if sections[index]["level"] == CHAPTER:
		while end < sections.size() and sections[end]["level"] == ARTICLE:
			end += 1
	return end


func can_move(index: int, direction: int) -> bool:
	if direction < 0:
		return index > 0
	return _group_end(index) < sections.size()


# Moves an article one place, or a chapter (with its articles) past its neighbour.
func move_section(index: int, direction: int) -> void:
	if not can_move(index, direction):
		return
	var before = sections.duplicate(true)
	var end = _group_end(index)
	var group = sections.slice(index, end)
	var target: int
	if sections[index]["level"] == ARTICLE:
		target = index + direction
		sections.remove_at(index)
		sections.insert(target, group[0])
	else:
		if direction < 0:
			target = index - 1
			while target > 0 and sections[target]["level"] == ARTICLE:
				target -= 1
		else:
			target = _group_end(end) - group.size()
		for i in group.size():
			sections.remove_at(index)
		for i in group.size():
			sections.insert(target + i, group[i])
	if not save_grammar():
		sections = before
		return
	render()
	_reveal(target)


func open_editor(index: int) -> void:
	editing_index = index
	var section = sections[index] if index >= 0 else {"title": "", "level": ARTICLE, "body": ""}
	%EditorHeading.text = "Edit article" if index >= 0 else "New article"
	%TitleInput.text = section["title"]
	%LevelInput.select(%LevelInput.get_item_index(section["level"]))
	%BodyInput.text = section["body"]
	%DeleteArticleButton.visible = index >= 0
	%Reader.visible = false
	%Editor.visible = true
	%TitleInput.grab_focus()


func close_editor() -> void:
	%Editor.visible = false
	%Reader.visible = true


func save_article() -> void:
	var article_title = %TitleInput.text.strip_edges()
	if article_title == "":
		_error("Give the article a title.")
		return
	var article = {"title": article_title, "level": %LevelInput.get_selected_id(), "body": %BodyInput.text.strip_edges()}
	var before = sections.duplicate(true)
	var index = editing_index
	if index >= 0:
		sections[index] = article
	else:
		sections.append(article)
		index = sections.size() - 1
	if not save_grammar():
		sections = before
		return
	close_editor()
	%SearchInput.text = ""  # so the saved article is on the page
	render()
	_reveal(index)


func _on_DeleteArticleButton_pressed() -> void:
	%DeleteConfirm.dialog_text = "Delete “%s”? Only its own text goes; articles under a chapter stay." % sections[editing_index]["title"]
	%DeleteConfirm.popup_centered()


func delete_article() -> void:
	if editing_index < 0:
		return
	var before = sections.duplicate(true)
	sections.remove_at(editing_index)
	if not save_grammar():
		sections = before
		return
	close_editor()
	render()


# --- Showing it --------------------------------------------------------------

func _search_text() -> String:
	return %SearchInput.text.strip_edges()


# The text a reader sees (no * marks), folded for search.
func _searchable(text: String) -> String:
	return TextFold.fold(text.replace("*", ""))


func _hit(text: String, query: String) -> bool:
	return query != "" and _searchable(text).contains(query)


func render() -> void:
	var query = TextFold.fold(_search_text())
	var parsed = sections.map(func(section): return parse_body(section["body"]))

	# Which sections show: all without a search; with one, those whose title or
	# text matches, plus the chapter headings above them.
	var shows = []
	for i in sections.size():
		var hit = query == "" or _hit(sections[i]["title"], query)
		if not hit:
			for block in parsed[i]:
				if block["items"].any(func(item): return _hit(item, query)):
					hit = true
					break
		shows.append(hit)
	for i in sections.size():
		if sections[i]["level"] == CHAPTER and not shows[i]:
			for j in range(i + 1, _group_end(i)):
				if shows[j]:
					shows[i] = true
					break

	for child in %Content.get_children():
		%Content.remove_child(child)
		child.queue_free()
	_headings = {}
	if load_problem != "":
		%Content.add_child(_label(load_problem, "HintLabel"))
	%Content.add_child(_label(title if title != "" else "Grammar", "SectionTitle"))
	if subtitle != "" and query == "":
		%Content.add_child(_label(subtitle, "HintLabel"))

	var hits = 0
	var shown = 0
	for i in sections.size():
		if not shows[i]:
			continue
		shown += 1
		var level = sections[i]["level"]
		if level == CHAPTER and %Content.get_child_count() > 1:
			var gap = Control.new()
			gap.custom_minimum_size.y = 10
			%Content.add_child(gap)
		var heading = _label(sections[i]["title"], "SectionTitle" if level == CHAPTER else "HeadingLabel")
		%Content.add_child(heading)
		_headings[i] = heading
		# A matching title shows the whole article; otherwise only matching lines.
		var everything = query == "" or _hit(sections[i]["title"], query)
		for block in parsed[i]:
			var items = block["items"]
			var matching = items.filter(func(item): return _hit(item, query))
			hits += matching.size()
			if not everything:
				if block["kind"] == "table" and not matching.is_empty():
					# Keep the header (and width row) above the matching rows.
					var top = [items[0]]
					if items.size() > 1 and _is_separator(items[1]):
						top.append(items[1])
					items = top + matching.filter(func(item): return not item in top)
				else:
					items = matching
			if not items.is_empty():
				%Content.add_child(_block(block["kind"], items, query))

	if query == "":
		%MatchLabel.text = "%d articles" % sections.size()
	elif hits == 0 and shown == 0:
		%MatchLabel.text = "No match for “%s”" % _search_text()
	else:
		%MatchLabel.text = "%d match%s in %d article%s" % [hits, "" if hits == 1 else "es", shown, "" if shown == 1 else "s"]
	_render_toc(shows, query != "")


func _render_toc(shows: Array, searching: bool) -> void:
	for child in %TocList.get_children():
		%TocList.remove_child(child)
		child.queue_free()
	var organizing = %OrganizeButton.button_pressed
	for i in sections.size():
		if not shows[i]:
			continue
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var link = Button.new()
		link.text = sections[i]["title"]
		link.tooltip_text = sections[i]["title"]
		link.alignment = HORIZONTAL_ALIGNMENT_LEFT
		link.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		link.clip_text = true
		link.focus_mode = Control.FOCUS_NONE
		link.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		link.theme_type_variation = "TocButton" if sections[i]["level"] == CHAPTER else "TocSubButton"
		link.pressed.connect(scroll_to.bind(i))
		row.add_child(link)
		if organizing:
			var hint = "Clear the search to reorder" if searching else ""
			var up = _row_button("↑", hint if hint else "Move up")
			up.disabled = searching or not can_move(i, -1)
			up.pressed.connect(move_section.bind(i, -1))
			var down = _row_button("↓", hint if hint else "Move down")
			down.disabled = searching or not can_move(i, 1)
			down.pressed.connect(move_section.bind(i, 1))
			var edit = _row_button("✎", "Edit")
			edit.pressed.connect(open_editor.bind(i))
			for button in [up, down, edit]:
				row.add_child(button)
		%TocList.add_child(row)


func scroll_to(index: int) -> void:
	if _headings.has(index):
		%ContentScroll.scroll_vertical = int(_headings[index].position.y)


# Layout settles over a few frames after a rebuild (or once the editor closes),
# and until then the scroll range is too short; so scroll on each of them.
func _reveal(index: int) -> void:
	for attempt in 3:
		await get_tree().process_frame
		scroll_to(index)


func _block(kind: String, items: Array, query: String) -> Control:
	match kind:
		"rules":
			return _rules(items, query)
		"examples":
			return _examples(items, query)
		"table":
			return _table(items, query)
		"note":
			var note = _rich(" ".join(items), query)
			note.add_theme_color_override("default_color", get_theme_color("font_color", "HintLabel"))
			return note
	return _rich(" ".join(items), query)


func _rules(items: Array, query: String) -> Control:
	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	for rule in items:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var bullet = _label("•", "BulletLabel", false)
		bullet.size_flags_vertical = Control.SIZE_SHRINK_BEGIN  # on the first line of a long rule
		row.add_child(bullet)
		row.add_child(_rich(rule, query))
		list.add_child(row)
	return list


func _examples(items: Array, query: String) -> Control:
	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	for i in items.size():
		var arrow = " → " if items[i].contains(" → ") else " -> "
		var at = items[i].find(arrow)
		var panel = PanelContainer.new()
		panel.theme_type_variation = "DictRowAlt" if i % 2 == 0 else "DictRow"
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(_rich(items[i].substr(0, at).strip_edges(), query))
		row.add_child(_label("→", "DimLabel", false))
		row.add_child(_rich(_as_krac(items[i].substr(at + arrow.length()).strip_edges()), query))
		panel.add_child(row)
		list.add_child(panel)
	return list


func _cells(line: String) -> Array:
	var inner = line.strip_edges()
	if inner.begins_with("|"):
		inner = inner.substr(1)
	if inner.ends_with("|"):
		inner = inner.substr(0, inner.length() - 1)
	return Array(inner.split("|")).map(func(cell): return cell.strip_edges())


func _is_separator(line: String) -> bool:
	return _cells(line).all(func(cell): return _separator_cell.search(cell) != null)


func _table(lines: Array, query: String) -> Control:
	var rows = lines.map(_cells)
	var widths = []
	if lines.size() > 1 and _is_separator(lines[1]):
		widths = rows[1].map(func(cell): return float(max(1, cell.count("-"))))
		rows.remove_at(1)
	var table = VBoxContainer.new()
	table.add_theme_constant_override("separation", 2)
	for r in rows.size():
		var panel = PanelContainer.new()
		panel.theme_type_variation = "DictRow" if r == 0 or r % 2 == 0 else "DictRowAlt"
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		for c in rows[r].size():
			var cell: Control
			if r == 0:
				cell = _label(rows[r][c].replace("*", "").to_upper(), "ColumnLabel")
			else:
				cell = _rich(rows[r][c], query)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.size_flags_stretch_ratio = widths[c] if c < widths.size() else 1.0
			row.add_child(cell)
		panel.add_child(row)
		table.add_child(panel)
	return table


# Marks a whole text as Kracnodar, unless it already marks its own words.
func _as_krac(text: String) -> String:
	if text.contains("*") or text == "" or text == "—":
		return text
	return "*%s*" % text


# Wraps each match of `query` (already folded) in highlight marks. Matching
# ignores the * marks, and highlights stop at them so the BBCode nests.
func _highlight(text: String, query: String) -> String:
	var folded = ""
	var origin = []  # folded character -> index in text
	for i in text.length():
		if text[i] == "*":
			continue
		var piece = TextFold.fold(text[i])
		for k in piece.length():
			folded += piece[k]
			origin.append(i)
	var marked = []
	marked.resize(text.length())
	marked.fill(false)
	var from = 0
	while query != "":
		var at = folded.find(query, from)
		if at < 0:
			break
		for k in range(at, at + query.length()):
			marked[origin[k]] = true
		from = at + query.length()
	var out = ""
	var open = false
	for i in text.length():
		var want = marked[i] and text[i] != "*"
		if want and not open:
			out += MARK_OPEN
		elif open and not want:
			out += MARK_CLOSE
		open = want
		out += text[i]
	if open:
		out += MARK_CLOSE
	return out


# `wrap` is off for short marks (bullets, arrows): a wrapping label in a row
# shrinks to nothing and pushes the row taller.
func _label(text: String, variation: String, wrap := true) -> Label:
	var label = Label.new()
	label.text = text
	label.theme_type_variation = variation
	if wrap:
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


func _rich(text: String, query := "") -> RichTextLabel:
	var rich = RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.selection_enabled = true
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich.mouse_filter = Control.MOUSE_FILTER_PASS
	var krac_color = get_theme_color("font_color", "KracLabel").to_html(false)
	var highlight = get_theme_color("selection_color", "LineEdit").to_html(true)
	var marked = _highlight(text, query) if query != "" else text
	var bbcode = _krac_word.sub(marked.replace("[", "[lb]"), "[b][color=#%s]$1[/color][/b]" % krac_color, true)
	rich.text = bbcode.replace(MARK_OPEN, "[bgcolor=#%s]" % highlight).replace(MARK_CLOSE, "[/bgcolor]")
	return rich


func _error(message: String) -> void:
	%ErrorDialog.dialog_text = message
	%ErrorDialog.size = Vector2i(480, 0)
	%ErrorDialog.popup_centered()


# --- Keys ----------------------------------------------------------------

func _on_SearchInput_gui_input(event) -> void:
	if event.is_action_pressed("ui_cancel") and %SearchInput.text != "":
		%SearchInput.clear()
		%SearchInput.accept_event()


# Ctrl+F (Cmd+F on a Mac) jumps to the search; Ctrl+S saves the open article.
func _shortcut_input(event) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if not event.is_command_or_control_pressed():
		return
	if event.keycode == KEY_F and %Reader.visible:
		%SearchInput.grab_focus()
		%SearchInput.select_all()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_S and %Editor.visible:
		save_article()
		get_viewport().set_input_as_handled()
