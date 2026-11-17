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
#   ==word==              a required word or module (the Library's Required list)
#   {word}                an appearance the Required list doesn't count

const FENCE = "```"

# What a character of a text is, past its marks (see parse_marks); one bit each.
const MASKED = 1
const REQUIRED = 2
const IGNORED = 4

static var _arrow := RegEx.create_from_string("\\s*(?:→|->)\\s*")
static var _separator_cell := RegEx.create_from_string("^:?-+:?$")


# A text without its ~~, == and {} marks, and what each of its characters is:
#   {"plain": String, "flags": [MASKED | REQUIRED | IGNORED for each character]}
# ~~ and == each open or close their kind; a last one with no partner runs to
# the end of the text. A { with no } after it, or a } with no {, is just itself.
static func parse_marks(text: String) -> Dictionary:
	var plain = ""
	var flags = []
	var state = 0
	var i = 0
	while i < text.length():
		var pair = text.substr(i, 2)
		if pair == "~~":
			state ^= MASKED
			i += 2
			continue
		if pair == "==":
			state ^= REQUIRED
			i += 2
			continue
		var c = text[i]
		if c == "{" and state & IGNORED == 0 and text.find("}", i + 1) != -1:
			state |= IGNORED
		elif c == "}" and state & IGNORED != 0:
			state &= ~IGNORED
		else:
			plain += c
			flags.append(state)
		i += 1
	return {"plain": plain, "flags": flags}


# The text parse_marks() read, its marks put back where the flags change.
static func join_marks(plain: String, flags: Array) -> String:
	var out = ""
	var before = 0
	for i in plain.length() + 1:
		var now = flags[i] if i < plain.length() else 0
		if now != before:
			if before & IGNORED and not now & IGNORED:
				out += "}"
			if before & REQUIRED and not now & REQUIRED:
				out += "=="
			if before & MASKED and not now & MASKED:
				out += "~~"
			if now & MASKED and not before & MASKED:
				out += "~~"
			if now & REQUIRED and not before & REQUIRED:
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
