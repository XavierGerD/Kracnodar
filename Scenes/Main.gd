extends Control


func _ready():
	%TabContainer.set_tab_title(0, "Générateur")
	%WordGenerator.wordPicked.connect(%WordSelector.add_word)
	%TabContainer.tab_changed.connect(_on_TabContainer_tab_changed)


func _on_TabContainer_tab_changed(tab):
	if %TabContainer.get_tab_control(tab) == %Dictionnaire:
		%Dictionnaire.refresh()
