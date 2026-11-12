extends Control

signal wordPicked(word)

const WordButtonScene = preload("res://Scenes/WordButton.tscn")

const CONSONANTS = ["w", "r", "t", "p", "s", "d", "f", "g", "h", "j", "k", "l", "z", "x", "c", "v", "b", "n", "m"]
const VOWELS = ["a", "e", "i", "o", "u"]

enum Start { CONSONANT, VOWEL, EITHER }

var rng = RandomNumberGenerator.new()


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
		var used_by = Dict.french_for_krac(word)
		if used_by != "":
			button.disabled = true
			button.tooltip_text = "Déjà utilisé pour « %s »" % used_by
		button.wordSelected.connect(_on_word_picked.bind(button))
		%WordGrid.add_child(button)
	_update_empty_hint()


func _on_word_picked(word, button):
	# A word goes to the list once; the chip stays, dimmed, as a reminder.
	button.disabled = true
	button.tooltip_text = "Déjà dans la liste"
	wordPicked.emit(word)


func _on_ClearButton_pressed():
	for child in %WordGrid.get_children():
		%WordGrid.remove_child(child)
		child.queue_free()
	_update_empty_hint()


func _update_empty_hint():
	%EmptyLabel.visible = %WordGrid.get_child_count() == 0
