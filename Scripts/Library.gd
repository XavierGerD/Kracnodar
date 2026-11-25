extends Control

# The Library: chapters, each holding documents (tablets, notes, labels, riddles)
# written in English and Kracnodar side by side. Each document is read by the
# players in English, Kracnodar or both, a setting saved with it; the language
# they don't read is greyed out, and its masked words are struck through. In
# "Preview" both disappear, as the players will see the document; in "Mask
# words" mode a click on a word masks or unmasks it.
# Everything lives in library.md (format at the top of that file), saved at
# once after each change, next to dict.json (see Dict.data_dir). Its markup is
# the Grammaire's (see Markup.gd), in documents and descriptions alike.
#
# Words and modules marked ==required== show green, and are listed under the
# chapters on every page: green when the players can read them somewhere else
# (see _required_index), red when they can't. An appearance that shouldn't
# count is wrapped in {}, which the list's page for that word does on a click.
# By chapter (the default), a word must be read in the chapter that requires
# it, and the list groups the words by chapter; Global counts the whole library.
#
# As in the Grammaire, the Kracnodar of each table is shown in the script too,
# in a column of its own (see _script_of).

const MarkdownToolbar = preload("res://Scripts/MarkdownToolbar.gd")
const Markup = preload("res://Scripts/Markup.gd")
const MarksHighlighter = preload("res://Scripts/MarksHighlighter.gd")

const LIBRARY_FILE = "library.md"
const FOLDS_FILE = "library_folds.cfg"  # the chapters folded in the sidebar, on this machine
const FORMAT_NOTE = """<!--
The Kracnodar Library, shown (and editable) in the app's Bibliothèque tab.
  # Title             the library's title, once at the top; the text under it introduces it
  ## Chapter name     a chapter; the text under it, up to its first document, describes it
  ### Document        a document in that chapter: a tablet, a note, a label, a riddle…
  ### Document [Kracnodar]   one the players read in Kracnodar only ([English]: in English only)
  English → Kracnodar a line in both languages (-> works too; either side may be empty)
  ~~word~~            a masked word: hidden from the players until revealed
  ==word==            a required word or module (==lok==tag for a module, ==lok====tag== for two): green, and listed under Required
  {word}              an appearance that Required doesn't count
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
const MASKED = Markup.MASKED
const REQUIRED = Markup.REQUIRED
const IGNORED = Markup.IGNORED
const SPLIT = Markup.SPLIT
const FOUND_COLOR = Color(0.52, 0.78, 0.45)  # a required word, and one the players can read somewhere

var title = ""
var intro = ""
# [{"name": String, "description": String,
#   "docs": [{"title": String, "body": String, "language": ENGLISH/KRAC/BOTH}]}]
var chapters = []
var load_problem = ""

var chapter_index = -1  # the chapter on the page; -1 for the library itself
var doc_index = -1   # the document open in that chapter; -1 for the chapter itself
var editing = {}     # {"kind": "library"/"chapter"/"doc", "chapter": int, "doc": int}; -1 for a new one
var _struck_font: FontVariation  # see _strike_font()
var _doc_modes = false  # whether Preview and Mask words apply: on a document's page
var required_key = ""  # the required word whose page shows, over the page above; "" for none
var _required = {}     # see _required_index(), as of the last render
var required_by_chapter = true  # whether a required word must be read in its own chapter
var _scope_button: Button  # switches required_by_chapter, by the Required heading

var _comment = RegEx.create_from_string("(?s)<!--.*?-->")
var _word = RegEx.create_from_string("[\\p{L}\\p{N}'’\\-]+")
var _heading = RegEx.create_from_string("^#{1,3} ")
var _language_tag = RegEx.create_from_string("(?i)^(.*?)\\s*\\[(english|kracnodar|krac|both)\\]$")
var _edge_punctuation = RegEx.create_from_string("^[^\\p{L}\\p{N}]+|[^\\p{L}\\p{N}]+$")
var _letter = RegEx.create_from_string("[A-Za-z]")
var _stale = false  # the alphabet changed while the page was hidden
var _collapsed = {}  # the names of the chapters whose documents the sidebar hides


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
	%AddChapterButton.pressed.connect(open_editor.bind("chapter", -1, -1))
	%NewDocButton.pressed.connect(func(): open_editor("doc", chapter_index, -1))
	%EditButton.pressed.connect(_on_EditButton_pressed)
	%BackButton.pressed.connect(_on_BackButton_pressed)
	%SaveButton.pressed.connect(save_editor)
	%CancelButton.pressed.connect(close_editor)
	%DeleteButton.pressed.connect(_on_DeleteButton_pressed)
	%DeleteConfirm.confirmed.connect(delete_edited)
	var toolbar = MarkdownToolbar.new()
	toolbar.name = "MarkdownToolbar"
	toolbar.setup(%BodyInput, ["required"])
	%Editor.add_child(toolbar)
	%Editor.move_child(toolbar, %BodyInput.get_index())
	%BodyInput.syntax_highlighter = _marks_highlighter()
	_scope_button = Button.new()
	_scope_button.focus_mode = Control.FOCUS_NONE
	_scope_button.pressed.connect(_on_scope_pressed)
	%RequiredCount.get_parent().add_child(_scope_button)
	%RequiredCount.get_parent().move_child(_scope_button, %RequiredCount.get_index())
	visibility_changed.connect(func():
		if _stale and is_visible_in_tree():
			_stale = false
			_rerender())
	_load_folds()
	load_library()
	render()


# --- The file -------------------------------------------------------------

func load_library() -> void:
	var path = Dict.read_path(LIBRARY_FILE)
	load_problem = ""
	if not FileAccess.file_exists(path):
		load_problem = "%s is missing. A new chapter will create it." % LIBRARY_FILE
		parse_document("")
		return
	var text = FileAccess.get_file_as_string(path)
	Dict.remember(LIBRARY_FILE, text)
	parse_document(text)


# Reads library.md again (after it was edited outside the app), staying on the
# same chapter and document, found by name, where it was scrolled. What is
# open in the editor is closed unsaved.
func reload() -> void:
	var chapter_name = chapters[chapter_index]["name"] if _has_chapter() else ""
	var doc_title = chapters[chapter_index]["docs"][doc_index]["title"] if _has_doc() else ""
	close_editor()
	load_library()
	chapter_index = -1
	doc_index = -1
	for i in chapters.size():
		if chapters[i]["name"] == chapter_name:
			chapter_index = i
			for j in chapters[i]["docs"].size():
				if chapters[i]["docs"][j]["title"] == doc_title:
					doc_index = j
					break
			break
	_rerender()


func has_open_edit() -> bool:
	return %Editor.visible


func save_library() -> bool:
	var path = Dict.data_path(LIBRARY_FILE)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_error("Couldn't save %s (%s)." % [ProjectSettings.globalize_path(path), error_string(FileAccess.get_open_error())])
		return false
	var text = to_markdown()
	file.store_string(text)
	Dict.remember(LIBRARY_FILE, text)
	load_problem = ""
	return true


func parse_document(text: String) -> void:
	text = _comment.sub(text.replace("\r\n", "\n"), "", true)
	title = ""
	chapters = []
	var intro_lines = []
	var body_lines = []
	var target = null  # the chapter or document the lines under the last heading belong to
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
				chapters.append({"name": heading, "description": "", "docs": []})
				target = chapters[-1]
				key = "description"
			else:
				if chapters.is_empty():  # a document needs a chapter
					chapters.append({"name": "Chapter 1", "description": "", "docs": []})
				var parts = split_heading(heading)
				chapters[-1]["docs"].append({"title": parts[0], "body": "", "language": parts[1]})
				target = chapters[-1]["docs"][-1]
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
	for chapter in chapters:
		parts.append("## " + chapter["name"])
		if chapter["description"] != "":
			parts.append(chapter["description"])
		for doc in chapter["docs"]:
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

# One side of a line as words and the text between them, in pieces whose
# characters are all marked alike (see Markup.parse_marks):
#   [{"text": String, "word": bool, "flags": int, "start": where the piece starts
#     in plain(text), "word_start": where its word (or the text between) starts}]
# A word partly marked, like ==lok==tag, comes in several pieces, and so does
# one with two required stretches back to back, like ==lok====tag==.
func tokens(text: String) -> Array:
	var marks = Markup.parse_marks(text)
	var shown: String = marks["plain"]
	var flags: Array = marks["flags"]
	var spans = []  # [from, to, is a word]
	var at = 0
	for found in _word.search_all(shown):
		if found.get_start() > at:
			spans.append([at, found.get_start(), false])
		spans.append([found.get_start(), found.get_end(), true])
		at = found.get_end()
	if at < shown.length():
		spans.append([at, shown.length(), false])
	var out = []
	for span in spans:
		var i = span[0]
		while i < span[1]:
			var j = i + 1
			while j < span[1] and flags[j] & SPLIT == 0 and flags[j] & ~SPLIT == flags[i] & ~SPLIT:
				j += 1
			out.append({"text": shown.substr(i, j - i), "word": span[2], "flags": flags[i], "start": i, "word_start": span[0]})
			i = j
	return out


# Masks or unmasks the word that starts `offset` characters into plain(text).
# What lies between two words is masked only when both are, so neighbouring
# masked words share one ~~ span. The other marks stay as they were.
func toggle_mask(text: String, offset: int) -> String:
	var marks = Markup.parse_marks(text)
	var shown: String = marks["plain"]
	var flags: Array = marks["flags"]
	var words = _word.search_all(shown)
	var target = words.filter(func(found): return found.get_start() == offset)
	if target.is_empty():
		return text
	var masking = not _all_flagged(flags, target[0].get_start(), target[0].get_end(), MASKED)
	_set_flag(flags, target[0].get_start(), target[0].get_end(), MASKED, masking)
	var at = 0
	for w in words.size() + 1:
		var gap_end = words[w].get_start() if w < words.size() else shown.length()
		var before = w > 0 and _all_flagged(flags, words[w - 1].get_start(), words[w - 1].get_end(), MASKED)
		var after = w < words.size() and _all_flagged(flags, words[w].get_start(), words[w].get_end(), MASKED)
		_set_flag(flags, at, gap_end, MASKED, before and after)
		if w < words.size():
			at = words[w].get_end()
	return Markup.join_marks(shown, flags)


func _all_flagged(flags: Array, from: int, to: int, flag: int) -> bool:
	for i in range(from, to):
		if flags[i] & flag == 0:
			return false
	return to > from


func _set_flag(flags: Array, from: int, to: int, flag: int, on: bool) -> void:
	for i in range(from, to):
		flags[i] = flags[i] | flag if on else flags[i] & ~flag


# The text a reader sees, without its marks.
func plain(text: String) -> String:
	return Markup.parse_marks(text)["plain"]


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
	var doc = chapters[chapter_index]["docs"][doc_index]
	var raw_lines = doc["body"].split("\n")
	var n = int(parts[0])
	var side = parts[1]
	var item = item_at(doc["body"], n)
	if n < 0 or n >= raw_lines.size() or not item.has(side):
		return
	item[side] = toggle_mask(item[side], int(parts[2]))
	var before = doc["body"]
	raw_lines[n] = item[TEXT] if side == TEXT else join_line(item)
	doc["body"] = "\n".join(raw_lines)
	if not save_library():
		doc["body"] = before
		return
	_rerender()


# --- Reordering and editing ------------------------------------------------

func _has_chapter() -> bool:
	return chapter_index >= 0 and chapter_index < chapters.size()


func _has_doc() -> bool:
	return _has_chapter() and doc_index >= 0 and doc_index < chapters[chapter_index]["docs"].size()


func move_chapter(index: int, direction: int) -> void:
	var target = index + direction
	if target < 0 or target >= chapters.size():
		return
	var before = chapters.duplicate(true)
	var chapter = chapters[index]
	chapters.remove_at(index)
	chapters.insert(target, chapter)
	if not save_library():
		chapters = before
		return
	if chapter_index == index:
		chapter_index = target
	elif chapter_index == target:
		chapter_index = index
	render()


func move_doc(chapter: int, index: int, direction: int) -> void:
	var docs = chapters[chapter]["docs"]
	var target = index + direction
	if target < 0 or target >= docs.size():
		return
	var before = chapters.duplicate(true)
	var doc = docs[index]
	docs.remove_at(index)
	docs.insert(target, doc)
	if not save_library():
		chapters = before
		return
	if chapter_index == chapter:
		if doc_index == index:
			doc_index = target
		elif doc_index == target:
			doc_index = index
	render()


func open_editor(kind: String, chapter: int, doc: int) -> void:
	editing = {"kind": kind, "chapter": chapter, "doc": doc}
	%ChapterInput.visible = kind == "doc"
	%DeleteButton.visible = (kind == "chapter" and chapter >= 0) or (kind == "doc" and doc >= 0)
	match kind:
		"library":
			%EditorHeading.text = "Edit the library"
			%NameInput.placeholder_text = "Title"
			%NameInput.text = _library_title()
			%BodyInput.placeholder_text = "What the library is, how the players go through it…"
			%BodyInput.text = intro
		"chapter":
			%EditorHeading.text = "Edit chapter" if chapter >= 0 else "New chapter"
			%NameInput.placeholder_text = "Chapter name, e.g. Chapter 4"
			%NameInput.text = chapters[chapter]["name"] if chapter >= 0 else "Chapter %d" % (chapters.size() + 1)
			%BodyInput.placeholder_text = "What the players see when they enter…"
			%BodyInput.text = chapters[chapter]["description"] if chapter >= 0 else ""
		"doc":
			var current = chapters[chapter]["docs"][doc] if doc >= 0 else {"title": "", "body": ""}
			%EditorHeading.text = "Edit document" if doc >= 0 else "New document"
			%NameInput.placeholder_text = "Title, e.g. The stone tablet"
			%NameInput.text = current["title"]
			%BodyInput.placeholder_text = "Written on a stone tablet:\n\nIn my house of stone → Ga eno ~~tinod~~ kintag"
			%BodyInput.text = current["body"]
			%ChapterInput.clear()
			for i in chapters.size():
				%ChapterInput.add_item(chapters[i]["name"], i)
			%ChapterInput.select(chapter)
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
		_error("Give it a name." if editing["kind"] == "chapter" else "Give the document a title.")
		return
	var quoting = false  # a # line inside a ``` block is quoted, not a heading
	for line in body.split("\n"):
		if line.strip_edges().begins_with(Markup.FENCE):
			quoting = not quoting
		elif not quoting and _heading.search(line) != null:
			_error("A line can't start with # (it would read as a heading): “%s”" % line)
			return
	var before = [title, intro, chapters.duplicate(true), chapter_index, doc_index]
	var chapter = editing["chapter"]
	match editing["kind"]:
		"library":
			title = name_text
			intro = body
			chapter_index = -1
			doc_index = -1
		"chapter":
			if chapter >= 0:
				if _collapsed.erase(chapters[chapter]["name"]):  # a renamed chapter stays folded
					_collapsed[name_text] = true
					_save_folds()
				chapters[chapter]["name"] = name_text
				chapters[chapter]["description"] = body
			else:
				chapters.append({"name": name_text, "description": body, "docs": []})
				chapter = chapters.size() - 1
			chapter_index = chapter
			doc_index = -1
		"doc":
			var index = editing["doc"]
			var doc = {"title": name_text, "body": body,
				"language": _doc_language(chapters[chapter]["docs"][index]) if index >= 0 else BOTH}
			var target = %ChapterInput.get_selected_id()
			if index >= 0 and target == chapter:
				chapters[chapter]["docs"][index] = doc
			else:
				if index >= 0:
					chapters[chapter]["docs"].remove_at(index)
				chapters[target]["docs"].append(doc)
				index = chapters[target]["docs"].size() - 1
			chapter_index = target
			doc_index = index
	if not save_library():
		title = before[0]
		intro = before[1]
		chapters = before[2]
		chapter_index = before[3]
		doc_index = before[4]
		return
	required_key = ""
	close_editor()
	render()


func _on_DeleteButton_pressed() -> void:
	if editing["kind"] == "chapter":
		var chapter = chapters[editing["chapter"]]
		var count = chapter["docs"].size()
		%DeleteConfirm.dialog_text = "Delete “%s”%s?" % [chapter["name"],
			"" if count == 0 else " and its %d document%s" % [count, "" if count == 1 else "s"]]
	else:
		%DeleteConfirm.dialog_text = "Delete “%s”?" % chapters[editing["chapter"]]["docs"][editing["doc"]]["title"]
	%DeleteConfirm.popup_centered()


func delete_edited() -> void:
	var before = [chapters.duplicate(true), chapter_index, doc_index]
	if editing["kind"] == "chapter":
		chapters.remove_at(editing["chapter"])
		chapter_index = -1
		doc_index = -1
	elif editing["kind"] == "doc":
		chapters[editing["chapter"]]["docs"].remove_at(editing["doc"])
		chapter_index = editing["chapter"]
		doc_index = -1
	else:
		return
	if not save_library():
		chapters = before[0]
		chapter_index = before[1]
		doc_index = before[2]
		return
	required_key = ""
	close_editor()
	render()


func _on_EditButton_pressed() -> void:
	if _has_doc():
		open_editor("doc", chapter_index, doc_index)
	elif _has_chapter():
		open_editor("chapter", chapter_index, -1)
	else:
		open_editor("library", -1, -1)


func _on_BackButton_pressed() -> void:
	if required_key != "":
		required_key = ""
		render()
	elif _has_doc():
		show_page(chapter_index, -1)
	else:
		show_page(-1, -1)


func show_page(chapter: int, doc: int) -> void:
	chapter_index = chapter
	doc_index = doc
	required_key = ""
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
	if not _has_chapter():
		chapter_index = -1
	if not _has_doc():
		doc_index = -1
	for child in %Content.get_children():
		%Content.remove_child(child)
		child.queue_free()
	if load_problem != "":
		%Content.add_child(_label(load_problem, "HintLabel"))
	_required = _required_index()
	if not _required.has(required_key):
		required_key = ""

	var on_required = required_key != ""
	var on_doc = _has_doc() and not on_required
	_doc_modes = on_doc
	%BackButton.visible = _has_chapter() or on_required
	if on_required:  # back to the page under it
		%BackButton.text = "← " + _place_name(chapter_index, doc_index)
	else:
		%BackButton.text = "← " + (chapters[chapter_index]["name"] if on_doc else "Library")
	%LangBox.visible = on_doc
	if on_doc:
		var language = _doc_language(chapters[chapter_index]["docs"][doc_index])
		%EnglishButton.set_pressed_no_signal(language == ENGLISH)
		%BothButton.set_pressed_no_signal(language == BOTH)
		%KracButton.set_pressed_no_signal(language == KRAC)
	%PreviewButton.visible = on_doc
	%MarkButton.visible = on_doc
	%NewDocButton.visible = _has_chapter() and not on_doc and not on_required
	%EditButton.visible = not on_required
	%EditButton.text = "Edit document" if on_doc else ("Edit chapter" if _has_chapter() else "Edit library")

	if on_required:
		_render_required(required_key)
	elif on_doc:
		_render_doc(chapters[chapter_index]["docs"][doc_index])
	elif _has_chapter():
		_render_chapter(chapters[chapter_index])
	else:
		_render_library()
	_render_toc()
	_render_required_list()


func _render_library() -> void:
	%Content.add_child(_label(_library_title(), "SectionTitle"))
	_render_blocks(intro, BOTH)
	if chapters.is_empty():
		%Content.add_child(_label("No chapters yet. Add one with + New chapter.", "HintLabel"))
	for i in chapters.size():
		var count = chapters[i]["docs"].size()
		%Content.add_child(_link("%s   ·   %d document%s" % [chapters[i]["name"], count, "" if count == 1 else "s"],
			"TocButton", show_page.bind(i, -1)))


func _render_chapter(chapter: Dictionary) -> void:
	%Content.add_child(_label(chapter["name"], "SectionTitle"))
	_render_blocks(chapter["description"], BOTH)
	%Content.add_child(_label("Documents", "HeadingLabel"))
	if chapter["docs"].is_empty():
		%Content.add_child(_label("No documents yet. Add one with + New document.", "HintLabel"))
	for j in chapter["docs"].size():
		%Content.add_child(_link(chapter["docs"][j]["title"], "TocButton", show_page.bind(chapter_index, j)))


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
	var ranges = rows.map(func(item): return Markup.cell_ranges(plain(item[TEXT])))
	# Each column with Kracnodar in it is followed by one with it in the script,
	# as in the Grammaire: {column: [the script of each row, its widest word]}.
	var scripts = {}
	for r in range(1, rows.size()):
		for c in ranges[r].size():
			var script = _script_of(rows[r][TEXT], ranges[r][c][0], ranges[r][c][1], false)
			if script["width"] > 0.0 and not scripts.has(c):
				scripts[c] = [[], 0.0]
	for c in scripts:
		for r in range(1, rows.size()):
			var script = _script_of(rows[r][TEXT], ranges[r][c][0], ranges[r][c][1], false) if c < ranges[r].size() else {"bbcode": "", "width": 0.0, "widest": 0.0}
			scripts[c][0].append(script["bbcode"])
			scripts[c][1] = max(scripts[c][1], script["widest"])
	var table = VBoxContainer.new()
	table.add_theme_constant_override("separation", 2)
	for r in rows.size():
		var text = rows[r][TEXT]
		var panel = PanelContainer.new()
		panel.theme_type_variation = "DictRow" if r == 0 or r % 2 == 0 else "DictRowAlt"
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		for c in ranges[r].size():
			var cell: Control
			var ratio = widths[c] if c < widths.size() else 1.0
			if r == 0:
				var heading = plain(text).substr(ranges[r][c][0], ranges[r][c][1] - ranges[r][c][0])
				cell = _label(heading.replace("*", "").to_upper(), "ColumnLabel")
			else:
				cell = _text_rich(_side_bbcode(text, rows[r]["line"], TEXT, ranges[r][c][0], ranges[r][c][1]))
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.size_flags_stretch_ratio = ratio
			row.add_child(cell)
			if scripts.has(c):
				var script = _script_cell(scripts[c][0][r - 1] if r > 0 else "", scripts[c][1], r == 0)
				script.size_flags_stretch_ratio = ratio
				row.add_child(script)
		panel.add_child(Markup.center_cells(row))
		table.add_child(panel)
	Markup.keep_words_whole(table)
	return table


# A cell of a script column, which wraps between its words, at least `width`
# wide (its column's widest word), so that no word sticks out of its cell and
# each row lines its columns up alike; or its heading.
func _script_cell(bbcode: String, width: float, heading: bool) -> Control:
	var cell: Control
	if heading:
		cell = _label("SCRIPT", "ColumnLabel")
	else:
		var rich = _rich("")
		rich.text = bbcode
		_make_clickable(rich)
		cell = rich
	cell.custom_minimum_size.x = width
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return cell


# The lines of a block in two columns, the language the players don't read
# greyed out; in preview, only theirs. Null when nothing is left to show.
func _lines_table(items: Array, language: String) -> Control:
	var hiding = language != BOTH and %PreviewButton.button_pressed
	var sides = [language] if hiding else [ENGLISH, KRAC]
	var faded = "" if language == BOTH else (KRAC if language == ENGLISH else ENGLISH)
	var rows = items.filter(func(item): return sides.any(func(side): return item[side] != ""))
	if rows.is_empty():
		return null
	# The Kracnodar side in the script too, in a column after it (see _table).
	var scripts = []
	var script_width = 0.0  # its widest word
	if sides.has(KRAC):
		for item in rows:
			var script = _script_of(item[KRAC], 0, -1, true)
			scripts.append(script["bbcode"])
			script_width = max(script_width, script["widest"])
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
		if side == KRAC and script_width > 0.0:
			var script = _script_cell("", script_width, true)
			script.modulate.a = column.modulate.a
			header.add_child(script)
	header_panel.add_child(Markup.center_cells(header))
	table.add_child(header_panel)
	for r in rows.size():
		var panel = PanelContainer.new()
		panel.theme_type_variation = "DictRowAlt" if r % 2 == 0 else "DictRow"
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		for side in sides:
			var cell = _rich("")
			if side == KRAC:
				_krac_style(cell)
			else:
				cell.add_theme_font_override("normal_font", _strike_font())
			if side == faded:
				cell.modulate.a = FADED
			cell.text = _side_bbcode(rows[r][side], rows[r]["line"], side)
			_make_clickable(cell)
			row.add_child(cell)
			if side == KRAC and script_width > 0.0:
				var script = _script_cell(scripts[r], script_width, false)
				script.modulate.a = cell.modulate.a
				row.add_child(script)
		panel.add_child(Markup.center_cells(row))
		table.add_child(panel)
	Markup.keep_words_whole(table)
	return table


func _krac_style(rich: RichTextLabel) -> void:
	rich.add_theme_color_override("default_color", get_theme_color("font_color", "KracLabel"))
	rich.add_theme_font_override("normal_font", get_theme_font("font", "KracLabel"))
	rich.add_theme_font_size_override("normal_font_size", get_theme_font_size("font_size", "KracLabel"))


# The language the players read the open document in, saved with it at once.
func _on_language_toggled(on: bool, language: String) -> void:
	if not on or not _has_doc():
		return
	var doc = chapters[chapter_index]["docs"][doc_index]
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
# *Kracnodar words* show in the Kracnodar style, as in the Grammaire, and
# ==required== ones green (not in preview: the players don't see them).
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
	for token in tokens(text):
		var start = token["start"]
		var lo = max(start, from)
		var hi = min(start + token["text"].length(), to)
		if hi <= lo:
			continue
		var piece = token["text"].substr(lo - start, hi - lo)
		var masked = token["flags"] & MASKED != 0
		var required = token["flags"] & REQUIRED != 0 and not hiding
		if token["word"]:
			var meta = "%d:%s:%d" % [line, side, token["word_start"]] if marking else ""
			out += _token_bbcode(piece, masked, required, hiding, dim, meta)
			continue
		# The Kracnodar style opens and closes outside a token's own tags, so they nest.
		var bits = piece.split("*")
		for b in bits.size():
			if b > 0:
				if in_krac or stars >= 2:
					out += "[/color][/b]" if in_krac else "[b][color=#%s]" % krac
					in_krac = not in_krac
				else:
					out += _token_bbcode("*", masked, required, hiding, dim, "")
				stars -= 1
			if bits[b] != "":
				out += _token_bbcode(bits[b], masked, required, hiding, dim, "")
	if in_krac:
		out += "[/color][/b]"
	return out


func _token_bbcode(text: String, masked: bool, required: bool, hiding: bool, dim: String, meta: String) -> String:
	var shown = text.replace("[", "[lb]")
	var colour = FOUND_COLOR.to_html(false) if required else dim
	if masked:
		if hiding:
			shown = "[color=#00000000]%s[/color]" % shown
		else:  # the line in full colour: a plain [s] draws it at half strength
			shown = "[s color=#%s][color=#%s]%s[/color][/s]" % [dim, colour, shown]
	elif required:
		shown = "[color=#%s]%s[/color]" % [colour, shown]
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
	var here = required_key == ""  # whether the page shown is the TOC's
	var top = _toc_button(_library_title(), "TocButton", here and chapter_index < 0, show_page.bind(-1, -1))
	var top_row = HBoxContainer.new()
	top_row.add_child(top)
	if organizing:
		var edit = _row_button("✎", "Edit")
		edit.pressed.connect(open_editor.bind("library", -1, -1))
		top_row.add_child(edit)
	%TocList.add_child(top_row)
	for i in chapters.size():
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		row.add_child(_toc_button(chapters[i]["name"], "TocButton", here and chapter_index == i and doc_index < 0, show_page.bind(i, -1)))
		var docs = chapters[i]["docs"]
		var folded = _collapsed.has(chapters[i]["name"])
		if not docs.is_empty():
			var fold = _row_button("▶" if folded else "▼",
				"Show its %d documents" % docs.size() if folded else "Hide its documents")
			fold.add_theme_font_size_override("font_size", 10)
			fold.pressed.connect(_toggle_chapter.bind(chapters[i]["name"]))
			row.add_child(fold)
		if organizing:
			_add_row_tools(row, i > 0, i < chapters.size() - 1, move_chapter.bind(i, -1), move_chapter.bind(i, 1),
				open_editor.bind("chapter", i, -1))
		%TocList.add_child(row)
		for j in docs.size():
			# A folded chapter still shows the document open on the page.
			if folded and not (here and chapter_index == i and doc_index == j):
				continue
			var doc_row = HBoxContainer.new()
			doc_row.add_theme_constant_override("separation", 2)
			doc_row.add_child(_toc_button(docs[j]["title"], "TocSubButton", here and chapter_index == i and doc_index == j, show_page.bind(i, j)))
			if organizing:
				_add_row_tools(doc_row, j > 0, j < docs.size() - 1, move_doc.bind(i, j, -1), move_doc.bind(i, j, 1),
					open_editor.bind("doc", i, j))
			%TocList.add_child(doc_row)


func _toggle_chapter(chapter_name: String) -> void:
	if not _collapsed.erase(chapter_name):
		_collapsed[chapter_name] = true
	_save_folds()
	_render_toc()


# The folded chapters are kept on this machine (FOLDS_FILE), not in the library.
func _load_folds() -> void:
	var folds = ConfigFile.new()
	if folds.load(Dict.scratch_path(FOLDS_FILE)) == OK:
		for chapter_name in folds.get_value("sidebar", "collapsed", []):
			_collapsed[str(chapter_name)] = true


func _save_folds() -> void:
	var folds = ConfigFile.new()
	folds.set_value("sidebar", "collapsed", _collapsed.keys())
	folds.save(Dict.scratch_path(FOLDS_FILE))


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
# its masks dropped (chapter descriptions and the introduction have none).
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


# --- The script ------------------------------------------------------------

# The Alphabet tab changed the letters: the page shows them now, or when next shown.
func alphabet_changed() -> void:
	if is_visible_in_tree():
		_rerender()
	else:
		_stale = true


# The dictionary was read again: the Required list shows its English.
func dictionary_changed() -> void:
	alphabet_changed()


# The Kracnodar of a text, from `from` to `to` in plain(text) (-1 for its end),
# in the script: {"bbcode", "width" (about how wide it's drawn on one line; 0
# for nothing), "widest" (about how wide its widest word is, with room for a
# sign after it: a comma can't start a line)}.
# That is its *Kracnodar words*, the parts apart, as in the Grammaire; or, with
# `whole` and no * in it, all of it (the Kracnodar side of a line). Each word is
# an image; what isn't a letter stays as it is. Masked words show dim, or in
# preview vanish, keeping their room, as in _side_bbcode.
func _script_of(text: String, from: int, to: int, whole: bool) -> Dictionary:
	var marks = Markup.parse_marks(text)
	var shown: String = marks["plain"]
	var flags: Array = marks["flags"]
	if to < 0:
		to = shown.length()
	var spans = _star_spans(shown.substr(from, to - from)).map(func(span): return [span[0] + from, span[1] + from])
	if spans.is_empty() and whole and not shown.substr(from, to - from).contains("*"):
		spans = [[from, to]]
	var hiding = _doc_modes and %PreviewButton.button_pressed and not %MarkButton.button_pressed
	var krac = get_theme_color("font_color", "KracLabel").to_html(false)
	var dim = get_theme_color("font_color", "DimLabel").to_html(false)
	var size = get_theme_font_size("normal_font_size", "RichTextLabel")
	var parts = []
	var width = 0.0
	var widest = 0.0
	for span in spans:
		var out = ""
		var letters = false
		var i = span[0]
		while i < span[1]:
			var masked = flags[i] & MASKED != 0
			var j = i + 1
			var is_letter = _letter.search(shown[i]) != null
			while j < span[1] and (_letter.search(shown[j]) != null) == is_letter and (flags[j] & MASKED != 0) == masked:
				j += 1
			var piece = shown.substr(i, j - i)
			if is_letter:
				var vanish = masked and hiding  # nor shown on hover
				out += Markup.script_image(piece, self, size, "00000000" if vanish else (dim if masked else krac), not vanish)
				width += Markup.script_image_width(piece, size)
				widest = max(widest, Markup.script_image_width(piece, size))
				letters = true
			else:
				# Between two words, more room (see Markup.script_gap), before the
				# space, so that a line broken at the space doesn't start with it.
				if i > span[0] and j < span[1] and piece.strip_edges() == "" and _letter.search(shown[i - 1]) != null and _letter.search(shown[j]) != null:
					out += Markup.script_gap(size)
					width += Markup.script_gap_width(size)
				var escaped = piece.replace("[", "[lb]")
				out += "[color=#00000000]%s[/color]" % escaped if masked and hiding else escaped
				width += piece.length() * size * 0.5
			i = j
		if letters:
			parts.append(out.strip_edges())
	if parts.is_empty():
		return {"bbcode": "", "width": 0.0, "widest": 0.0}
	width += (parts.size() - 1) * Markup.SCRIPT_PARTS.length() * size * 0.5
	return {"bbcode": Markup.SCRIPT_PARTS.join(parts), "width": ceil(width), "widest": ceil(widest + size * 0.5)}


# --- Required words ---------------------------------------------------------

# Every ==required== word or module, in the order the library first marks it:
#   {key: {"word": String, "chapter": int, "required": [place], "found": [place], "ignored": [place]}}
# where a place is {"chapter", "doc" (-1 for a description or the introduction),
# "line" (in that body), "side" (en, kr or text), "plain" (that side without
# its marks), "from", "to" (where in it)}. "required" holds its marks; "found"
# where the players read it otherwise, which is: on the Kracnodar side of lines
# in a language they read, or in a *Kracnodar word* in any other text, not in
# a masked word or a required mark; "ignored" the same within {} marks.
# A word is matched anywhere in a word, so a module shows inside the words built on it.
# By chapter, a word required in two chapters is two entries, keyed
# "chapter:word" (-1 for the introduction), each found in its own chapter
# only; globally, the key is the word, found anywhere, and "chapter" is -2.
func _required_index() -> Dictionary:
	var index = {}
	var regions = []  # the Kracnodar the players read: [place, lowercase plain, flags, [[from, to]]]
	for place in _places():
		var language = place[3]
		for block in parse_body(place[2]):
			for item in block["items"]:
				for side in ([ENGLISH, KRAC] if item.has(ENGLISH) else [TEXT]):
					var marks = Markup.parse_marks(item[side])
					var shown: String = marks["plain"]
					var flags: Array = marks["flags"]
					var where = {"chapter": place[0], "doc": place[1], "line": item["line"], "side": side, "plain": shown}
					var i = 0
					while i < shown.length():
						if flags[i] & REQUIRED == 0:
							i += 1
							continue
						var j = Markup.required_end(flags, i)
						var word = _required_key(shown.substr(i, j - i))
						if word != "":
							var key = "%d:%s" % [place[0], word] if required_by_chapter else word
							if not index.has(key):
								index[key] = {"word": word, "chapter": place[0] if required_by_chapter else -2,
									"required": [], "found": [], "ignored": []}
							index[key]["required"].append(where.merged({"from": i, "to": j}))
						i = j
					var read = side == TEXT or (side == ENGLISH and language != KRAC) or (side == KRAC and language != ENGLISH)
					if read:
						var spans = [[0, shown.length()]] if side == KRAC else _star_spans(shown)
						regions.append([where, shown.to_lower(), flags, spans])
	for key in index:
		var word: String = index[key]["word"]
		for region in regions:
			if required_by_chapter and region[0]["chapter"] != index[key]["chapter"]:
				continue
			for span in region[3]:
				var at = region[1].find(word, span[0])
				while at != -1 and at + word.length() <= span[1]:
					var to = at + word.length()
					var flags = region[2]
					var unseen = false  # masked, or another required mark
					for c in range(at, to):
						if flags[c] & (MASKED | REQUIRED) != 0:
							unseen = true
					if not unseen:
						var kind = "ignored" if _all_flagged(flags, at, to, IGNORED) else "found"
						index[key][kind].append(region[0].merged({"from": at, "to": to}))
					at = region[1].find(word, at + 1)
	return index


# Switches between By chapter and Global, the page of a required word kept:
# globally, the word's; by chapter, the word's in the first chapter requiring it.
func _on_scope_pressed() -> void:
	var entry = _required.get(required_key, {})
	required_by_chapter = not required_by_chapter
	if not entry.is_empty():
		required_key = "%d:%s" % [entry["required"][0]["chapter"], entry["word"]] if required_by_chapter else entry["word"]
	_rerender()


# The name of a chapter, the introduction (-1) included.
func _chapter_name(chapter: int) -> String:
	return "Introduction" if chapter < 0 else chapters[chapter]["name"]


# [chapter, doc, body, language] for the introduction, each chapter's
# description and each document, in reading order.
func _places() -> Array:
	var out = [[-1, -1, intro, BOTH]]
	for i in chapters.size():
		out.append([i, -1, chapters[i]["description"], BOTH])
		for j in chapters[i]["docs"].size():
			var doc = chapters[i]["docs"][j]
			out.append([i, j, doc["body"], _doc_language(doc)])
	return out


# A marked stretch as the list shows it: lowercase, without the * marks and
# the spaces, hyphens and punctuation at either end (==-ex== is ex).
func _required_key(text: String) -> String:
	return _edge_punctuation.sub(text.replace("*", ""), "", true).to_lower()


# The insides of the *Kracnodar words* of a text, as [[from, to]].
func _star_spans(text: String) -> Array:
	var stars = []
	for i in text.length():
		if text[i] == "*":
			stars.append(i)
	var out = []
	for k in range(0, stars.size() - 1, 2):
		out.append([stars[k] + 1, stars[k + 1]])
	return out


func _body_at(chapter: int, doc: int) -> String:
	if chapter < 0:
		return intro
	return chapters[chapter]["description"] if doc < 0 else chapters[chapter]["docs"][doc]["body"]


func _set_body(chapter: int, doc: int, body: String) -> void:
	if chapter < 0:
		intro = body
	elif doc < 0:
		chapters[chapter]["description"] = body
	else:
		chapters[chapter]["docs"][doc]["body"] = body


func _place_name(chapter: int, doc: int) -> String:
	if chapter < 0 or chapter >= chapters.size():
		return "Library"
	if doc < 0 or doc >= chapters[chapter]["docs"].size():
		return chapters[chapter]["name"]
	return chapters[chapter]["docs"][doc]["title"]


func _found_colour(key: String) -> Color:
	return FOUND_COLOR if not _required[key]["found"].is_empty() else get_theme_color("font_color", "DangerButton")


func show_required(key: String) -> void:
	required_key = key
	close_editor()
	render()
	%ContentScroll.scroll_vertical = 0


# The list under the chapters, on every page: each word green when the
# players can read it somewhere, red when not, with how many places. On a
# chapter's pages, only the words that chapter requires.
func _render_required_list() -> void:
	for child in %RequiredList.get_children():
		%RequiredList.remove_child(child)
		child.queue_free()
	_scope_button.text = "By chapter" if required_by_chapter else "Global"
	_scope_button.tooltip_text = ("By chapter: a required word counts as found only where the players read it in the same chapter. Click for Global."
		if required_by_chapter else "Global: a required word counts as found wherever the players read it in the library. Click for By chapter.")
	# On a chapter, or anything in it, only the words it requires; on the library, all.
	var focus = chapter_index
	var keys = _required.keys().filter(func(key): return focus < 0 or _required[key]["required"].any(func(place): return place["chapter"] == focus))
	var found = keys.filter(func(key): return not _required[key]["found"].is_empty()).size()
	%RequiredCount.text = "" if keys.is_empty() else "%d of %d found" % [found, keys.size()]
	if _required.is_empty():
		%RequiredList.add_child(_label("None yet. In the editor, select a word or part of one and press ==Required==.", "HintLabel"))
		return
	if keys.is_empty():
		%RequiredList.add_child(_label("None in this chapter.", "HintLabel"))
		return
	var chapter = -2  # the chapter of the words listed last
	for key in keys:
		var entry = _required[key]
		if required_by_chapter and entry["chapter"] != chapter:
			chapter = entry["chapter"]
			var heading = _label(_chapter_name(chapter).to_upper(), "ColumnLabel")
			heading.autowrap_mode = TextServer.AUTOWRAP_OFF
			heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			heading.clip_text = true
			%RequiredList.add_child(heading)
		var count = entry["found"].size()
		var row = HBoxContainer.new()
		var button = _toc_button(entry["word"], "TocSubButton", key == required_key, show_required.bind(key))
		var colour = _found_colour(key)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, colour)
		var anywhere = " in this chapter" if required_by_chapter else ""
		button.tooltip_text = "%s: %s" % [entry["word"], "found in %d place%s%s" % [count, "" if count == 1 else "s", anywhere] if count > 0 else "not found in any text the players read" + anywhere]
		row.add_child(button)
		var meaning = _english_for(entry["word"])
		var english = _label(meaning if meaning != "" else "—", "DimLabel")
		english.autowrap_mode = TextServer.AUTOWRAP_OFF
		english.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		english.clip_text = true
		english.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		english.mouse_filter = Control.MOUSE_FILTER_PASS
		english.tooltip_text = meaning if meaning != "" else "Not in the dictionary"
		row.add_child(english)
		var number = _label(str(count), "HintLabel")
		number.autowrap_mode = TextServer.AUTOWRAP_OFF
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		number.custom_minimum_size.x = 22
		row.add_child(number)
		%RequiredList.add_child(row)


# The English of a Kracnodar word or module, from the dictionary; "" when it isn't there.
func _english_for(word: String) -> String:
	for french in Dict.dict:
		if Dict.krac_of(french).strip_edges().to_lower() == word:
			return Dict.english_of(french)
	return ""


# A required word's page: where it is required, where the players read it,
# and the appearances set aside, each with a button to change that.
func _render_required(key: String) -> void:
	var entry = _required[key]
	%Content.add_child(_label(entry["word"], "SectionTitle"))
	var within = " in %s" % _chapter_name(entry["chapter"]) if required_by_chapter else ""
	var count = entry["found"].size()
	var status = _label("Found in %d place%s the players read%s." % [count, "" if count == 1 else "s", within] if count > 0
		else "Not found in any text the players read%s." % within, "HeadingLabel")
	status.add_theme_color_override("font_color", _found_colour(key))
	%Content.add_child(status)
	%Content.add_child(_label("What counts: the Kracnodar side of lines in a language the players read, and *Kracnodar words* in any other text, outside masked words and required marks%s. A part of a word counts too, so ignore the appearances that only look alike." % (", in the same chapter (By chapter, by the Required heading)" if required_by_chapter else ""), "HintLabel"))
	%Content.add_child(_label("Required in", "HeadingLabel"))
	for place in entry["required"]:
		%Content.add_child(_appearance_row(place, FOUND_COLOR, "", Callable()))
	%Content.add_child(_label("Found in", "HeadingLabel"))
	if entry["found"].is_empty():
		%Content.add_child(_label("Nowhere yet.", "HintLabel"))
	for place in entry["found"]:
		%Content.add_child(_appearance_row(place, FOUND_COLOR, "Ignore", _set_ignored.bind(place, true)))
	if not entry["ignored"].is_empty():
		%Content.add_child(_label("Ignored", "HeadingLabel"))
		for place in entry["ignored"]:
			%Content.add_child(_appearance_row(place, get_theme_color("font_color", "DimLabel"), "Count it", _set_ignored.bind(place, false)))


# One place a word is: where, as a link to that page, and its line, the word
# picked out in `colour`; with a button when `action` is given.
func _appearance_row(place: Dictionary, colour: Color, button_text: String, action: Callable) -> Control:
	var panel = PanelContainer.new()
	panel.theme_type_variation = "DictRowAlt"
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var text = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var where = _place_name(place["chapter"], place["doc"])
	if place["chapter"] >= 0 and place["doc"] >= 0:
		where = chapters[place["chapter"]]["name"] + "  ›  " + where
	text.add_child(_link(where, "TocSubButton", show_page.bind(place["chapter"], place["doc"])))
	var line = _rich("")
	if place["side"] == KRAC:
		_krac_style(line)
	line.text = _context_bbcode(place, colour)
	text.add_child(line)
	row.add_child(text)
	if action.is_valid():
		var button = _row_button(button_text, "Count this appearance again" if button_text == "Count it" else "Don't count this appearance: puts {} around it")
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var hint = get_theme_color("font_color", "HintLabel")  # RowButton's own reads as disabled
		button.add_theme_color_override("font_color", hint)
		button.add_theme_color_override("font_focus_color", hint)
		button.pressed.connect(action)
		row.add_child(button)
	panel.add_child(row)
	return panel


# The line around a place, cut to a few words either side, the place in bold.
func _context_bbcode(place: Dictionary, colour: Color) -> String:
	var shown: String = place["plain"]
	var from: int = place["from"]
	var to: int = place["to"]
	var lo = max(0, from - 48)
	var hi = min(shown.length(), to + 48)
	var clean = func(part: String) -> String: return part.replace("*", "").replace("[", "[lb]")
	return ("…" if lo > 0 else "") + clean.call(shown.substr(lo, from - lo)) \
		+ "[b][color=#%s]%s[/color][/b]" % [colour.to_html(false), clean.call(shown.substr(from, to - from))] \
		+ clean.call(shown.substr(to, hi - to)) + ("…" if hi < shown.length() else "")


# Puts {} around an appearance, or takes them off it, and saves at once.
func _set_ignored(place: Dictionary, on: bool) -> void:
	var body = _body_at(place["chapter"], place["doc"])
	var raw_lines = body.split("\n")
	var side = place["side"]
	var item = item_at(body, place["line"])
	if not item.has(side):
		return
	var marks = Markup.parse_marks(item[side])
	if marks["plain"] != place["plain"]:  # the text changed since the page showed
		render()
		return
	_set_flag(marks["flags"], place["from"], place["to"], IGNORED, on)
	item[side] = Markup.join_marks(marks["plain"], marks["flags"])
	raw_lines[place["line"]] = item[TEXT] if side == TEXT else join_line(item)
	_set_body(place["chapter"], place["doc"], "\n".join(raw_lines))
	if not save_library():
		_set_body(place["chapter"], place["doc"], body)
		return
	_rerender()


# Colours the editor's marks: required stretches green, ignored ones dim.
func _marks_highlighter() -> SyntaxHighlighter:
	var highlighter = MarksHighlighter.new()
	highlighter.required_color = FOUND_COLOR
	highlighter.ignored_color = get_theme_color("font_color", "DimLabel")
	highlighter.text_color = get_theme_color("font_color", "TextEdit")
	return highlighter


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
