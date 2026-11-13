extends HBoxContainer

# A row of buttons above a TextEdit that holds the Grammaire's or the Library's
# markdown, the same in every editor. Each button writes the markup both readers
# understand (see Markup.gd): on the selected lines, around the selection, or at
# the caret. Each press is one undo step, and the caret and selection stay in
# the text (the buttons never take focus).
#
#   var bar = MarkdownToolbar.new()
#   bar.setup(%BodyInput)
#   then add it to the editor, above the TextEdit

const Markup = preload("res://Scripts/Markup.gd")

# The marks a line can start with; giving a line one of them replaces the other.
const LINE_PREFIXES = ["- ", "> "]
const FENCE = Markup.FENCE

# The buttons, in order: tool -> [button text, tooltip]
const TOOLS = {
	"rule": ["- Rule", "A rule: starts each selected line with “- ” (again to take it off)"],
	"note": ["> Note", "A note: starts each selected line with “> ” (again to take it off)"],
	"translation": ["→ Translation", "A line in both languages, English → Kracnodar: puts the arrow at the caret.\nA line without an arrow is a paragraph; a blank line starts a new block."],
	"table": ["| Table |", "A table: a header row, a row setting the column widths, and a row to fill in"],
	"krac": ["*Krac*", "A Kracnodar word: puts * around the selection, or the word at the caret (again to take them off)"],
	"mask": ["~~Mask~~", "A masked word, struck through and hidden from the Library's players: puts ~~ around the selection, or the word at the caret (again to take them off)"],
	"quote": ["``` Quote", "A quote block: puts ``` lines above and below the selected lines (again to take them off)"],
}

var editor: TextEdit
var _word = RegEx.create_from_string("[\\p{L}\\p{N}'’\\-]+")


func setup(target: TextEdit) -> void:
	editor = target
	add_theme_constant_override("separation", 4)
	for tool in TOOLS:
		var button = Button.new()
		button.name = tool.capitalize() + "Tool"
		button.text = TOOLS[tool][0]
		button.tooltip_text = TOOLS[tool][1]
		button.focus_mode = Control.FOCUS_NONE
		button.theme_type_variation = "RowButton"
		button.pressed.connect(run.bind(tool))
		add_child(button)


# RowButton's own colour is dimmer than the hint above, which reads as disabled.
func _ready() -> void:
	var colour = get_theme_color("font_color", "HintLabel")
	for button in get_children():
		button.add_theme_color_override("font_color", colour)
		button.add_theme_color_override("font_focus_color", colour)


func run(tool: String) -> void:
	editor.begin_complex_operation()
	match tool:
		"rule":
			toggle_prefix("- ")
		"note":
			toggle_prefix("> ")
		"translation":
			insert_arrow()
		"table":
			insert_table()
		"krac":
			toggle_wrap("*")
		"mask":
			toggle_wrap("~~")
		"quote":
			toggle_fence()
	editor.end_complex_operation()
	editor.grab_focus()


# --- Lines -------------------------------------------------------------------

# The lines the selection covers, or the caret's line, as [first, last]. A
# selection that ends at the very start of a line leaves that line out.
func _line_range() -> Array:
	if not editor.has_selection():
		return [editor.get_caret_line(), editor.get_caret_line()]
	var first = editor.get_selection_from_line()
	var last = editor.get_selection_to_line()
	if last > first and editor.get_selection_to_column() == 0:
		last -= 1
	return [first, last]


# Starts each line with `prefix`, replacing the other line mark, or takes it
# off when every line already has it. Blank lines inside a selection stay blank.
func toggle_prefix(prefix: String) -> void:
	var lines = _line_range()
	var first = lines[0]
	var last = lines[1]
	var selected = editor.has_selection()
	var caret_line = editor.get_caret_line()
	var caret_column = editor.get_caret_column()
	var targets = []
	for n in range(first, last + 1):
		if first == last or editor.get_line(n).strip_edges() != "":
			targets.append(n)
	var removing = targets.all(func(n): return editor.get_line(n).begins_with(prefix))
	var shift = 0
	for n in targets:
		var text = editor.get_line(n)
		var bare = text
		for mark in LINE_PREFIXES:
			if bare.begins_with(mark):
				bare = bare.substr(mark.length())
				break
		var changed = bare if removing else prefix + bare
		if n == caret_line:
			shift = changed.length() - text.length()
		editor.set_line(n, changed)
	if selected:
		editor.select(first, 0, last, editor.get_line(last).length())
	else:
		editor.deselect()
		editor.set_caret_line(caret_line)
		editor.set_caret_column(clampi(caret_column + shift, 0, editor.get_line(caret_line).length()))


# --- At the caret ------------------------------------------------------------

func insert_arrow() -> void:
	editor.deselect()
	var text = editor.get_line(editor.get_caret_line())
	var column = editor.get_caret_column()
	var arrow = " → "
	if column > 0 and text[column - 1] == " ":
		arrow = arrow.substr(1)
	if column < text.length() and text[column] == " ":
		arrow = arrow.substr(0, arrow.length() - 1)
	editor.insert_text_at_caret(arrow)


# A table under the caret's line (or on it, when it is blank), its first
# header selected so typing replaces it.
func insert_table() -> void:
	editor.deselect()
	var line = editor.get_caret_line()
	var table = "| Column | Column |\n|---|---|\n|  |  |"
	if editor.get_line(line).strip_edges() == "":
		editor.set_line(line, "")
		editor.set_caret_column(0)
	else:
		editor.set_caret_column(editor.get_line(line).length())
		table = "\n" + table
		line += 1
	editor.insert_text_at_caret(table)
	editor.select(line, 2, line, 8)


# --- Around the selection ------------------------------------------------------

# Puts `mark` on each side of the selection (line by line, since a mark never
# spans lines) or of the word at the caret; takes them off when every part
# already has them. With nothing to wrap, puts a pair with the caret between.
func toggle_wrap(mark: String) -> void:
	var parts = _wrap_parts()
	if parts.is_empty():
		editor.deselect()
		editor.insert_text_at_caret(mark + mark)
		editor.set_caret_column(editor.get_caret_column() - mark.length())
		return
	var removing = parts.all(func(part): return _wrapped(part, mark) != 0)
	var size = mark.length()
	for part in parts:
		var text = editor.get_line(part[0])
		var from = part[1]
		var to = part[2]
		if removing:
			if _wrapped(part, mark) > 0:  # the marks are just outside the part
				text = text.substr(0, from - size) + text.substr(from, to - from) + text.substr(to + size)
				from -= size
				to -= size
			else:  # the part holds them
				text = text.substr(0, from) + text.substr(from + size, to - from - 2 * size) + text.substr(to)
				to -= 2 * size
		else:
			text = text.substr(0, from) + mark + text.substr(from, to - from) + mark + text.substr(to)
			from += size
			to += size
		editor.set_line(part[0], text)
		part[1] = from
		part[2] = to
	editor.select(parts[0][0], parts[0][1], parts[-1][0], parts[-1][2])


# [[line, from, to]] for each line's share of the selection, its spaces at
# either end left out; or for the word at the caret; [] when there is neither.
func _wrap_parts() -> Array:
	var parts = []
	if editor.has_selection():
		var first = editor.get_selection_from_line()
		var last = editor.get_selection_to_line()
		for n in range(first, last + 1):
			var text = editor.get_line(n)
			var from = editor.get_selection_from_column() if n == first else 0
			var to = editor.get_selection_to_column() if n == last else text.length()
			while from < to and text[from] == " ":
				from += 1
			while to > from and text[to - 1] == " ":
				to -= 1
			if to > from:
				parts.append([n, from, to])
		return parts
	var line = editor.get_caret_line()
	var column = editor.get_caret_column()
	for found in _word.search_all(editor.get_line(line)):
		if found.get_start() <= column and column <= found.get_end():
			return [[line, found.get_start(), found.get_end()]]
	return parts


# 1 when `mark` sits just outside the part, -1 when the part starts and ends
# with it, 0 when it is not wrapped.
func _wrapped(part: Array, mark: String) -> int:
	var text = editor.get_line(part[0])
	var from = part[1]
	var to = part[2]
	var size = mark.length()
	if from >= size and text.substr(from - size, size) == mark and text.substr(to, size) == mark:
		return 1
	var inner = text.substr(from, to - from)
	if inner.length() >= 2 * size and inner.begins_with(mark) and inner.ends_with(mark):
		return -1
	return 0


# --- Blocks --------------------------------------------------------------------

func _is_fence(line: int) -> bool:
	return line >= 0 and line < editor.get_line_count() and editor.get_line(line).strip_edges().begins_with(FENCE)


func _remove_line(line: int) -> void:
	if line + 1 < editor.get_line_count():
		editor.remove_text(line, 0, line + 1, 0)
	else:
		editor.remove_text(line - 1, editor.get_line(line - 1).length(), line, editor.get_line(line).length())


# Puts ``` lines above and below the selected lines (or the caret's line), or
# takes them off when the lines are already between two.
func toggle_fence() -> void:
	var lines = _line_range()
	var first = lines[0]
	var last = lines[1]
	var outer = [first - 1, last + 1]  # the fence lines, when there are some
	if last > first and _is_fence(first) and _is_fence(last):
		outer = [first, last]
	if _is_fence(outer[0]) and _is_fence(outer[1]):
		_remove_line(outer[1])
		_remove_line(outer[0])
		if outer[0] == first:  # the fences were part of the selection
			last -= 2
		else:
			first -= 1
			last -= 1
		if last >= first:
			editor.select(first, 0, last, editor.get_line(last).length())
		else:
			editor.deselect()
		return
	editor.deselect()
	editor.insert_text("\n" + FENCE, last, editor.get_line(last).length())
	editor.insert_text(FENCE + "\n", first, 0)
	first += 1
	last += 1
	if first == last and editor.get_line(first) == "":
		editor.set_caret_line(first)
		editor.set_caret_column(0)
	else:
		editor.select(first, 0, last, editor.get_line(last).length())
