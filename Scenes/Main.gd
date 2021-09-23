extends Control

func _ready():
	$TabContainer/Generateur/WordGenerator.connect("wordPicked", self, "onWordPicked")

func onWordPicked(text):
	$TabContainer/Generateur/WordSelector.addWordLinker(text)


func _on_TabContainer_tab_changed(tab):
	if (tab == 1):
		$TabContainer/Dictionnaire.redrawDict(Dict.dict, false, false)
		$TabContainer/Dictionnaire.generateInverseMappedDict(Dict.dict)
