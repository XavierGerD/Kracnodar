extends VBoxContainer

# One row of the "new terms" list: a Kracnodar word and its translations, with
# a note under it naming dictionary words it overlaps (see Dict.overlaps).

signal word_changed  # the Kracnodar word
signal edited  # any of the three fields

const SHOWN_OVERLAPS = 4


func _ready():
	%DeleteButton.pressed.connect(queue_free)
	%KracText.text_changed.connect(func(_text):
		update_overlaps()
		word_changed.emit())
	for field in [%KracText, %FrenchText, %EnglishText]:
		field.text_changed.connect(func(_text): edited.emit())


func set_word(krac: String) -> void:
	%KracText.text = krac
	update_overlaps()


# Fills the row from a saved entry ({"kr", "fr", "en"}).
func set_entry(entry: Dictionary) -> void:
	%FrenchText.text = str(entry.get("fr", ""))
	%EnglishText.text = str(entry.get("en", ""))
	set_word(str(entry.get("kr", "")))


func get_entry() -> Dictionary:
	return {
		"kr": %KracText.text.strip_edges(),
		"fr": %FrenchText.text.strip_edges(),
		"en": %EnglishText.text.strip_edges(),
	}


func update_overlaps() -> void:
	var found = Dict.overlaps(%KracText.text)
	%OverlapRow.visible = not found.is_empty()
	if found.is_empty():
		return
	var krac_color = get_theme_color("font_color", "KracLabel").to_html(false)
	var mark = get_theme_color("selection_color", "LineEdit").to_html(true)
	var words = []
	for overlap in found.slice(0, SHOWN_OVERLAPS):
		words.append("[b][color=#%s]%s[/color][/b] (%s)" % [krac_color, _marked(overlap, mark), _escape(overlap["french"])])
	var lead = "⚠ Existe déjà : " if found[0]["exact"] else "⚠ Ressemble à : "
	var more = found.size() - SHOWN_OVERLAPS
	%OverlapNote.text = lead + ", ".join(words) + (" et %d autre%s" % [more, "s" if more > 1 else ""] if more > 0 else "")


# The existing word with the letters it shares highlighted.
func _marked(overlap: Dictionary, mark: String) -> String:
	var word = overlap["krac"]
	var at = word.to_lower().find(overlap["shared"])
	var length = overlap["shared"].length()
	return "%s[bgcolor=#%s]%s[/bgcolor]%s" % [
		_escape(word.substr(0, at)), mark, _escape(word.substr(at, length)), _escape(word.substr(at + length))]


func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
