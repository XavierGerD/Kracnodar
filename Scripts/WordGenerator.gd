extends Control

signal wordPicked(word)

const WordButtonScene = preload("res://Scenes/WordButton.tscn")

const CONSONANTS = ["w", "r", "t", "p", "s", "d", "f", "g", "h", "j", "k", "l", "z", "x", "c", "v", "b", "n", "m"]
const VOWELS = ["a", "e", "i", "o", "u"]

enum Start { CONSONANT, VOWEL, EITHER }

var rng = RandomNumberGenerator.new()
var listed_words = []  # words now in the "new terms" list, lowercase


func _ready():
	rng.randomize()
	%WordStartDropdown.add_item("Consonne", Start.CONSONANT)
	%WordStartDropdown.add_item("Voyelle", Start.VOWEL)
	%WordStartDropdown.add_item("Peu importe", Start.EITHER)
	%WordStartDropdown.select(0)
	%GeneratorButton.pressed.connect(_on_GeneratorButton_pressed)
	%ClearButton.pressed.connect(_on_ClearButton_pressed)
	_update_empty_hint()


func _pick(letters: Array) -> String:
	return letters[rng.randi() % letters.size()]


# Every syllable is consonant + vowel, except that a word may open on a bare vowel.
func make_word(syllables: int, start: int) -> String:
	if start == Start.EITHER:
		start = Start.VOWEL if rng.randi() % 2 else Start.CONSONANT
	var word = ""
	for i in syllables:
		if i == 0 and start == Start.VOWEL:
			word += _pick(VOWELS)
		else:
			word += _pick(CONSONANTS) + _pick(VOWELS)
	return word


func _on_GeneratorButton_pressed():
	var syllables = int(%SyllablesInput.value)
	var start = %WordStartDropdown.get_selected_id()
	for i in int(%WordsInput.value):
		var word = make_word(syllables, start)
		var button = WordButtonScene.instantiate()
		button.text = word
		button.word = word
		_update_chip(button)
		button.wordSelected.connect(_on_word_picked.bind(button))
		%WordGrid.add_child(button)
	_update_empty_hint()


func _on_word_picked(word, button):
	button.disabled = true  # the list's words_changed confirms it right away
	wordPicked.emit(word)


# Called with the list's words whenever they change.
func set_listed_words(words: Array) -> void:
	listed_words = words
	refresh_chips()


# Re-checks every generated word against the dictionary and the list.
func refresh_chips() -> void:
	for chip in %WordGrid.get_children():
		if not chip.is_queued_for_deletion():
			_update_chip(chip)


# A word is greyed out while it is in the dictionary or in the list, and gets a
# warm border when it only shares letters with dictionary words.
func _update_chip(button) -> void:
	var used_by = Dict.french_for_krac(button.word)
	var overlaps = Dict.overlaps(button.word)
	button.disabled = false
	button.tooltip_text = ""
	button.theme_type_variation = "WordChip"
	if used_by != "":
		button.disabled = true
		button.tooltip_text = "Déjà utilisé pour « %s »" % used_by
	elif button.word.to_lower() in listed_words:
		button.disabled = true
		button.tooltip_text = "Déjà dans la liste"
	elif not overlaps.is_empty():
		button.theme_type_variation = "WordChipOverlap"
		button.tooltip_text = "Ressemble à : " + ", ".join(overlaps.slice(0, 4).map(
			func(o): return "%s (%s)" % [o["krac"], o["french"]]))


func _on_ClearButton_pressed():
	for child in %WordGrid.get_children():
		%WordGrid.remove_child(child)
		child.queue_free()
	_update_empty_hint()


func _update_empty_hint():
	%EmptyLabel.visible = %WordGrid.get_child_count() == 0
