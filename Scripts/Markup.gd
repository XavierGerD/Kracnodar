extends RefCounted

# The markup the Grammaire and the Library share, and the toolbar writes
# (see MarkdownToolbar). Line by line:
#   - text                a rule, one per line
#   > text                a note
#   | a | b |             a table row: the first row is the header; an optional
#   |---|------|          dashed row under it sets the relative column widths
#   English → Kracnodar   a line in both languages (-> works too; either side may be empty)
#   ```                   opens or closes a quote block, whose lines are kept as written
#   other text            a paragraph; a blank line starts a new block
# and within a line:
#   *word*                a Kracnodar word, in the Kracnodar style
#   ~~word~~              a masked word: struck through, and hidden from the
#                         Library's players until revealed
#   ==word==              a required word or module (the Library's Required list);
#                         ==lok====tag== marks lok and tag, one after the other
#   {word}                an appearance the Required list doesn't count

const Writing = preload("res://Scripts/Writing.gd")

const FENCE = "```"

# A word in the Kracnodar script, against the text's font size: taller than an
# image, as it leaves room above its letters for diacritics.
const SCRIPT_SCALE = 2.4
# What separates two Kracnodar parts of one text in a script column.
const SCRIPT_PARTS = "  ·  "
# The room added to the space between two words in the script, against the
# text's font size: a plain space is narrow beside the script's tall words.
const SCRIPT_WORD_GAP = 0.4

static var _gap_texture: ImageTexture  # see script_gap()

# What a character of a text is, past its marks (see parse_marks); one bit each.
const MASKED = 1
const REQUIRED = 2
const IGNORED = 4
# The first character of a required stretch that starts right where another
# ends, as tag in ==lok====tag==: the two are two entries, not one.
const SPLIT = 8

static var _arrow := RegEx.create_from_string("\\s*(?:→|->)\\s*")
static var _separator_cell := RegEx.create_from_string("^:?-+:?$")


# A text without its ~~, == and {} marks, and what each of its characters is:
#   {"plain": String, "flags": [MASKED | REQUIRED | IGNORED | SPLIT for each character]}
# ~~ and == each open or close their kind; a last one with no partner runs to
# the end of the text. A { with no } after it, or a } with no {, is just itself.
static func parse_marks(text: String) -> Dictionary:
	var plain = ""
	var flags = []
	var state = 0
	var split = false  # a == opened right after a required character
	var i = 0
	while i < text.length():
		var pair = text.substr(i, 2)
		if pair == "~~":
			state ^= MASKED
			i += 2
			continue
		if pair == "==":
			state ^= REQUIRED
			split = state & REQUIRED != 0 and not flags.is_empty() and flags[-1] & REQUIRED != 0
			i += 2
			continue
		var c = text[i]
		if c == "{" and state & IGNORED == 0 and text.find("}", i + 1) != -1:
			state |= IGNORED
		elif c == "}" and state & IGNORED != 0:
			state &= ~IGNORED
		else:
			plain += c
			flags.append(state | SPLIT if split else state)
			split = false
		i += 1
	return {"plain": plain, "flags": flags}


# Where the required stretch that starts at `from` ends: at the first character
# not required, or the next stretch's first (see SPLIT).
static func required_end(flags: Array, from: int) -> int:
	var to = from + 1
	while to < flags.size() and flags[to] & REQUIRED != 0 and flags[to] & SPLIT == 0:
		to += 1
	return to


# The text parse_marks() read, its marks put back where the flags change.
static func join_marks(plain: String, flags: Array) -> String:
	var out = ""
	var before = 0
	for i in plain.length() + 1:
		var now = flags[i] if i < plain.length() else 0
		# A required stretch right after another closes it and opens anew: ====
		var split = now & SPLIT != 0 and now & REQUIRED != 0 and before & REQUIRED != 0
		if now != before or split:
			if before & IGNORED and not now & IGNORED:
				out += "}"
			if before & REQUIRED and (split or not now & REQUIRED):
				out += "=="
			if before & MASKED and not now & MASKED:
				out += "~~"
			if now & MASKED and not before & MASKED:
				out += "~~"
			if now & REQUIRED and (split or not before & REQUIRED):
				out += "=="
			if now & IGNORED and not before & IGNORED:
				out += "{"
		if i < plain.length():
			out += plain[i]
		before = now
	return out


# Splits a text into blocks of one kind, in order:
#   [{"kind": "rules", "note", "table", "lines", "text" or "quote",
#     "items": [{"line": n, "text": the line, "skip": how many characters at
#                its start are the line's mark ("- ", "> ")}]}]
# where n is the line's number in the text. A line with an arrow ("lines") also
# has its two sides as "en" and "kr". A quote keeps its lines as written (blank
# ones included); one left open runs to the end of the text.
static func blocks(body: String) -> Array:
	var out = []
	var current = null
	var quote = null
	var raw_lines = body.split("\n")
	for n in raw_lines.size():
		var raw = raw_lines[n]
		var line = raw.strip_edges()
		if line.begins_with(FENCE):
			if quote == null:
				quote = {"kind": "quote", "items": []}
				out.append(quote)
			else:
				quote = null
			current = null
			continue
		if quote != null:
			quote["items"].append({"line": n, "text": raw.strip_edges(false, true), "skip": 0})
			continue
		if line == "":
			current = null
			continue
		var item = {"line": n, "text": line, "skip": 0}
		var kind = "text"
		if line.begins_with("- "):
			kind = "rules"
			item["skip"] = 2
		elif line.begins_with(">"):
			kind = "note"
			item["skip"] = line.length() - line.substr(1).strip_edges(true, false).length()
		elif line.begins_with("|"):
			kind = "table"
		else:
			var sides = split_line(line)
			if sides.has("en"):
				kind = "lines"
				item.merge(sides)
		if current == null or current["kind"] != kind:
			current = {"kind": kind, "items": []}
			out.append(current)
		current["items"].append(item)
	return out


# A line as {"en", "kr"} when it holds an arrow, otherwise {"text"}.
static func split_line(line: String) -> Dictionary:
	var arrow = _arrow.search(line)
	if arrow == null:
		return {"text": line}
	return {"en": line.substr(0, arrow.get_start()).strip_edges(), "kr": line.substr(arrow.get_end()).strip_edges()}


# The cells of a table row, without the pipes and the spaces around them.
static func cells(line: String) -> Array:
	var inner = line.strip_edges()
	if inner.begins_with("|"):
		inner = inner.substr(1)
	if inner.ends_with("|"):
		inner = inner.substr(0, inner.length() - 1)
	return Array(inner.split("|")).map(func(cell): return cell.strip_edges())


# Where each cell of a table row lies in it, as [[from, to]]: the same cells as
# cells(), their spaces at either end left out.
static func cell_ranges(line: String) -> Array:
	var pipes = []
	for i in line.length():
		if line[i] == "|":
			pipes.append(i)
	var trimmed = line.strip_edges()
	var left = -1
	var right = line.length()
	if trimmed.begins_with("|"):
		left = pipes.pop_front()
	if trimmed.ends_with("|") and not pipes.is_empty():
		right = pipes.pop_back()
	var bounds = [left] + pipes + [right]
	var ranges = []
	for i in bounds.size() - 1:
		var from = bounds[i] + 1
		var to = bounds[i + 1]
		while from < to and line[from] == " ":
			from += 1
		while to > from and line[to - 1] == " ":
			to -= 1
		ranges.append([from, to])
	return ranges


# Whether a table row is the dashed one that sets the column widths.
static func is_separator(line: String) -> bool:
	return cells(line).all(func(cell): return _separator_cell.search(cell) != null)


# The panel a quote block sits in: the alternate row colour, with a bar in the
# Kracnodar colour down its left side. `owner` gives the theme.
static func quote_panel(owner: Control) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = owner.get_theme_stylebox("panel", "DictRowAlt").duplicate()
	if style is StyleBoxFlat:
		style.border_width_left = 3
		style.border_color = owner.get_theme_color("font_color", "KracLabel")
		style.corner_radius_top_left = 0
		style.corner_radius_bottom_left = 0
		style.content_margin_left = 14
		style.content_margin_top = 8
		style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	return panel


# The items of a quote without the blank lines at either end.
static func trimmed_quote(items: Array) -> Array:
	var lines = items.duplicate()
	while not lines.is_empty() and lines[0]["text"].strip_edges() == "":
		lines.pop_front()
	while not lines.is_empty() and lines[-1]["text"].strip_edges() == "":
		lines.pop_back()
	return lines


# A word in the Kracnodar script as BBCode, drawn for text `font_size` tall
# in `color` (hex), its letters shown on hover unless `hint` is off. `owner`
# gives the window's scale.
static func script_image(word: String, owner: Control, font_size: int, color: String, hint := true) -> String:
	var height = int(round(font_size * SCRIPT_SCALE))
	var scale = maxf(1.0, ceilf(owner.get_viewport().get_final_transform().get_scale().y * 2.0) / 2.0)
	# A quotation mark would end the tooltip's value: it shows as a curly one.
	var tooltip = " tooltip=\"%s\"" % word.replace("\"", "”") if hint else ""
	return "[img height=%d color=#%s%s]%s[/img]" % [height, color, tooltip, Writing.image_path(word, height, scale)]


# The room added after the space between two words in the script, as BBCode:
# a clear image SCRIPT_WORD_GAP wide.
static func script_gap(font_size: int) -> String:
	if _gap_texture == null:
		var image = Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color(1, 1, 1, 0))
		_gap_texture = ImageTexture.create_from_image(image)
		_gap_texture.take_over_path("res://writing/gap.tex")
	return "[img width=%d height=1]res://writing/gap.tex[/img]" % script_gap_width(font_size)


static func script_gap_width(font_size: int) -> int:
	return int(round(font_size * SCRIPT_WORD_GAP))


# How wide script_image() draws a word.
static func script_image_width(word: String, font_size: int) -> float:
	return round(font_size * SCRIPT_SCALE) * Writing.aspect(word)


# A table row's cells centred on its height: a line in the script is taller
# than the text around it.
static func center_cells(row: HBoxContainer) -> HBoxContainer:
	for cell in row.get_children():
		cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return row


# Lets a table's text break between words wherever it can: each text column is
# kept at least as wide as its widest word (headings included). When the row
# is too narrow for all of them, those widths shrink alike, and only then do
# long words break. Columns with a width of their own (the script's: an image
# can't break) and those that don't stretch (arrows) keep theirs. `table` holds
# a row per child, each a PanelContainer around an HBoxContainer of cells.
static func keep_words_whole(table: Container) -> void:
	table.resized.connect(func(): _fit_words(table))


static func _fit_words(table: Container) -> void:
	var rows = []
	for panel in table.get_children():
		if panel is PanelContainer and panel.get_child_count() > 0 and panel.get_child(0) is HBoxContainer:
			rows.append(panel.get_child(0))
	if rows.is_empty() or table.size.x <= 0.0:
		return
	if not table.has_meta("word_widths"):
		_measure_words(table, rows)
	var words: Dictionary = table.get_meta("word_widths")  # column -> its widest word
	var fixed: Dictionary = table.get_meta("fixed_widths")  # column -> its own width
	var columns = 0
	for row in rows:
		columns = maxi(columns, row.get_child_count())
	var panel: PanelContainer = rows[0].get_parent()
	var room = table.size.x - panel.get_theme_stylebox("panel").get_minimum_size().x
	room -= rows[0].get_theme_constant("separation") * (columns - 1)
	for c in fixed:
		room -= fixed[c]
	var need = 0.0
	for c in words:
		need += words[c]
	var share = clampf(room / need, 0.0, 1.0) if need > 0.0 else 1.0
	for row in rows:
		for c in row.get_child_count():
			if words.has(c):
				row.get_child(c).custom_minimum_size.x = floorf(words[c] * share)


# Once, before _fit_words sets any: each column's widest word, or its own width.
static func _measure_words(table: Container, rows: Array) -> void:
	var words = {}
	var fixed = {}
	for row in rows:
		for c in row.get_child_count():
			var cell: Control = row.get_child(c)
			if cell.custom_minimum_size.x > 0.0 or not cell.size_flags_horizontal & Control.SIZE_EXPAND:
				fixed[c] = maxf(fixed.get(c, 0.0), cell.get_combined_minimum_size().x)
			else:
				words[c] = maxf(words.get(c, 0.0), _widest_word(cell))
	for c in fixed:
		words.erase(c)
	table.set_meta("word_widths", words)
	table.set_meta("fixed_widths", fixed)


# About how wide a label's widest word is drawn. A line can break after a
# dash, so the parts of a dashed word count apart. Rich text is measured in
# its plain and bold fonts both, the wider of the two.
static func _widest_word(cell: Control) -> float:
	var text = ""
	var fonts = []
	if cell is Label:
		text = cell.text
		fonts = [[cell.get_theme_font("font"), cell.get_theme_font_size("font_size")]]
	elif cell is RichTextLabel:
		text = cell.get_parsed_text()
		fonts = [[cell.get_theme_font("normal_font"), cell.get_theme_font_size("normal_font_size")],
			[cell.get_theme_font("bold_font"), cell.get_theme_font_size("bold_font_size")]]
	var widest = 0.0
	for word in text.replace("\n", " ").replace("\t", " ").split(" ", false):
		var parts = word.split("-")
		for i in parts.size():
			var part = parts[i] + ("-" if i < parts.size() - 1 else "")
			for font in fonts:
				widest = maxf(widest, font[0].get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, font[1]).x)
	return ceilf(widest) + 2.0 if widest > 0.0 else 0.0
