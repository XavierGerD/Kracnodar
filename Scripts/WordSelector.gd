extends Control

var wordLinkerNode = load("res://Scenes/WordLinker.tscn")

func addWordLinker(text):
	var newWordLinker = wordLinkerNode.instance()
	newWordLinker.get_node("WordButton").set_text(text)
	newWordLinker.wordText = text
	$VBoxContainer.add_child(newWordLinker)


func _on_Button_pressed():
	var newWordLinker = wordLinkerNode.instance()
	$VBoxContainer.add_child(newWordLinker)


func _on_AddAllButton_pressed():
	if ($VBoxContainer.get_child_count() > 0):

		var isAnyEntryEmpty = false
		var children = $VBoxContainer.get_children()
		for child in children:
			if child.get_node("WordButton").get_text() == "" || child.get_node("TranslationText").get_text() == "":
				$WarningDialog.popup()
				return
		for child in children:
			Dict.dict[child.wordText] = child.translationText
			$VBoxContainer.remove_child(child)
			child.queue_free()
		$AcceptDialog.popup()
