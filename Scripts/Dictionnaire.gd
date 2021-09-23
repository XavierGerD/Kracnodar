extends Control
signal saveFile

var filePath
var reverseMappedDictionary
var wordEntryNode = load("res://Scenes/DictEntry.tscn")

func drawSortedDict(dict, invert, fr):
	var sortedKeys = dict.keys()
	sortedKeys.sort()
	if invert:
		sortedKeys.invert()
	var sortedDict = {}
	for key in sortedKeys:
		sortedDict[key] = dict[key]
	drawDict(sortedDict, invert, fr)

func drawDict(dict, invert, fr):
	for dictEntry in dict:
		var newWordEntry = wordEntryNode.instance()
		if fr:
			newWordEntry.get_node("WordEntry").set_text(dict[dictEntry])
			newWordEntry.get_node("WordTranslation").set_text(dictEntry)
			newWordEntry.key = dict[dictEntry]
		else:
			newWordEntry.get_node("WordEntry").set_text(dictEntry)
			newWordEntry.get_node("WordTranslation").set_text(dict[dictEntry])
			newWordEntry.key = dictEntry
		$ScrollContainer/VBoxContainer.add_child(newWordEntry)

func redrawDict(dict, invert, fr):
	for child in $ScrollContainer/VBoxContainer.get_children():
		$ScrollContainer/VBoxContainer.remove_child(child)
		child.queue_free()
	drawSortedDict(dict, invert, fr)
	
func generateInverseMappedDict(dict):
	var reverseMapped = {}
	for key in dict.keys():
		var newKey = dict[key]
		reverseMapped[newKey] = key
	reverseMappedDictionary = reverseMapped
	print(reverseMappedDictionary)

func _on_SaveButton_pressed():
	$SaveDialog.popup()

func _on_ImportButton_pressed():
	$ImportDialog.popup()

func _on_ImportDialog_file_selected(path):
	filePath = path
	$AcceptDialog.popup()

func _on_SaveDialog_file_selected(path):
	var newFile = File.new()
	newFile.open(path, newFile.WRITE)
	var json = JSON.print(Dict.dict)
	newFile.store_string(json)


func _on_AcceptDialog_confirmed():
	if filePath:
		var newFile = File.new()
		newFile.open(filePath, newFile.READ)
		var json = JSON.parse(newFile.get_as_text()).result
		for key in json.keys():
			Dict.dict[key] = json[key]
		redrawDict(Dict.dict, false, false)
	filePath = ""


func _on_KracAscButton_pressed():
	redrawDict(Dict.dict, false, false)

func _on_KracDesButton_pressed():
	redrawDict(Dict.dict, true, false)

func _on_FraAscButton_pressed():
	redrawDict(reverseMappedDictionary, false, true)

func _on_FraDesButton_pressed():
	redrawDict(reverseMappedDictionary, true, true)
