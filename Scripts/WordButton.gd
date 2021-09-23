extends Button

signal wordSelected
var word

func _on_WordButton_pressed():
	emit_signal("wordSelected", word)
	pass # Replace with function body.
