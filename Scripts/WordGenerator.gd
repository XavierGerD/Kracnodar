extends Control

signal wordPicked

onready var wordButtonScene = load('res://Scenes/WordButton.tscn')
var rng = RandomNumberGenerator.new()

var consonants = [
	'w',
	'r',
	't',
	'p',
	's',
	'd',
	'f',
	'g',
	'h',
	'j',
	'k',
	'l',
	'z',
	'x',
	'c',
	'v',
	'b',
	'n',
	'm'
]

var vowels = ['a', 'e', 'i', 'o', 'u']

var wordStartDropdownItems = [
	"Consonne",
	"Voyelle",
	"Any"
]

var regex = RegEx.new()
var oldSyllabelText = ""
var oldWordsText = ""

func _ready():
	regex.compile("^[0-9]*$")
	for item in wordStartDropdownItems:
		$WordStartDropdown.add_item(item)
	$WordStartDropdown.select(0)

func getFirstSyllable():
	var dropDownIndex = $WordStartDropdown.get_selected_id()
	rng.randomize()
	var syllableConsonantIndex = rng.randi() % consonants.size()
	rng.randomize()
	var syllableVowelIndex = rng.randi() % vowels.size()
	var selection = dropDownIndex
	if (dropDownIndex == 2):
		rng.randomize()
		selection = rng.randi() % 2
	if (selection == 0):
		return consonants[syllableConsonantIndex] + vowels[syllableVowelIndex]
	if (selection == 1):
		return vowels[syllableVowelIndex]

func getWord():
	var newWord = ""
	for syllableIndex in int($NumberOfSyllablesInput.get_text()):
		if (syllableIndex == 0):
			newWord += getFirstSyllable()
		else:
			rng.randomize()
			var syllableConsonantIndex = rng.randi() % consonants.size()
			rng.randomize()
			var syllableVowelIndex = rng.randi() % vowels.size()
			newWord +=  consonants[syllableConsonantIndex] + vowels[syllableVowelIndex]
	return newWord
	
func _on_GeneratorButton_pressed():
	for wordIndex in int($NumberOfWordsInput.get_text()):
		var newWord = getWord()
		var newButton = wordButtonScene.instance()
		newButton.set_text(newWord)
		newButton.word = newWord
		newButton.connect("wordSelected", self, "onWordPicked")
		$TextEdit.add_child(newButton)
		
func _on_NumberOfSyllablesInput_text_changed(newText):
	if regex.search(newText):
		$NumberOfSyllablesInput.set_text(newText)
		oldSyllabelText = newText
		$NumberOfSyllablesInput.set_cursor_position(oldSyllabelText.length())
		return
	$NumberOfSyllablesInput.set_text(oldSyllabelText)
	
func _on_NumberOfWordsInput_text_changed(newText):
	if regex.search(newText):
		$NumberOfWordsInput.set_text(newText)
		oldWordsText = newText
		$NumberOfWordsInput.set_cursor_position(oldWordsText.length())
		return
	$NumberOfWordsInput.set_text(oldWordsText)
	
func onWordPicked(text):
	emit_signal("wordPicked", text)

func _on_Button_pressed():
	for child in $TextEdit.get_children():
		$TextEdit.remove_child(child)
		child.queue_free()
