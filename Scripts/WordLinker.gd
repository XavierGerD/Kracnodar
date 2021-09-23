extends Control

export var wordText: String
export var translationText: String

func _on_DeleteButton_pressed():
	self.queue_free()


func _on_WordButton_text_changed(new_text):
	wordText = new_text
	pass # Replace with function body.


func _on_TranslationText_text_changed(new_text):
	translationText = new_text
	pass # Replace with function body.
