extends Control


func _ready():
	%TabContainer.set_tab_title(0, "Générateur")
	%WordGenerator.wordPicked.connect(%WordSelector.add_word)
	%WordSelector.words_changed.connect(%WordGenerator.set_listed_words)
	%TabContainer.tab_changed.connect(_on_TabContainer_tab_changed)
	Dict.save_failed.connect(_show_save_problem)
	if Dict.load_problem != "":
		_show_save_problem.call_deferred(
			"Le dictionnaire n'a pas pu être lu, et rien ne sera enregistré tant qu'il ne l'est pas : %s" % Dict.load_problem)


func _show_save_problem(message: String) -> void:
	%SaveErrorDialog.dialog_text = message
	%SaveErrorDialog.size = Vector2i(480, 0)
	%SaveErrorDialog.popup_centered()


func _on_TabContainer_tab_changed(tab):
	var shown = %TabContainer.get_tab_control(tab)
	if shown == %Dictionnaire:
		%Dictionnaire.refresh()
	elif shown == %TabContainer.get_node("Generateur"):
		# The dictionary may have been edited meanwhile.
		%WordGenerator.refresh_chips()
