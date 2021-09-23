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
	for child in $VBoxContainer.get_children():
		Dict.dict[child.wordText] = child.translationText
