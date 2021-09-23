extends Control
signal saveFile

var wordEntryNode = load("res://Scenes/DictEntry.tscn")

func drawDict(dict):
	for dictEntry in dict.keys():
		var newWordEntry = wordEntryNode.instance()
		newWordEntry.get_node("WordEntry").set_text(dictEntry)
		newWordEntry.get_node("WordTranslation").set_text(dict[dictEntry])
		$ScrollContainer/VBoxContainer.add_child(newWordEntry)

func redrawDict(dict):
	for child in $ScrollContainer/VBoxContainer.get_children():
		$ScrollContainer/VBoxContainer.remove_child(child)
		child.queue_free()
	drawDict(dict)

func _on_SaveButton_pressed():
	$SaveDialog.popup()

func _on_ImportButton_pressed():
	$ImportDialog.popup()

func _on_ImportDialog_file_selected(path):
	var newFile = File.new()
	newFile.open(path, newFile.READ)
	var json = JSON.parse(newFile.get_as_text()).result
	redrawDict(json)

func _on_SaveDialog_file_selected(path):
	var newFile = File.new()
	newFile.open(path, newFile.WRITE)
	var json = JSON.print(Dict.dict)
	newFile.store_string(json)
