extends SyntaxHighlighter

# Colours the Library editor's marks as Markup.parse_marks reads them:
# ==required== stretches (their == included) in `required_color`, {ignored}
# ones in `ignored_color`, the rest in the TextEdit's own colour.

var required_color: Color
var ignored_color: Color
var text_color: Color


func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var text = get_text_edit().get_line(line)
	var out = {}
	var required = false
	var ignored = false
	var shown = null  # the colour the last column set
	var i = 0
	while i < text.length():
		var width = 1
		var opening_required = false
		if text.substr(i, 2) == "==":
			width = 2
			opening_required = not required
			required = not required
		elif text[i] == "{" and not ignored and text.find("}", i + 1) != -1:
			ignored = true
		# A closing == or } is drawn like what it closes.
		var colour = required_color if required or (width == 2 and not opening_required) \
			else (ignored_color if ignored else text_color)
		if text[i] == "}" and ignored:
			ignored = false
			colour = ignored_color
		if colour != shown:
			out[i] = {"color": colour}
			shown = colour
		i += width
	return out
