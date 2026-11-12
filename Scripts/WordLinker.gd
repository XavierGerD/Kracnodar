extends HBoxContainer

# One row of the "new terms" list: a Kracnodar word and its translations.


func _ready():
	$DeleteButton.pressed.connect(queue_free)


func set_word(krac: String) -> void:
	$KracText.text = krac


func get_entry() -> Dictionary:
	return {
		"kr": $KracText.text.strip_edges(),
		"fr": $FrenchText.text.strip_edges(),
		"en": $EnglishText.text.strip_edges(),
	}
