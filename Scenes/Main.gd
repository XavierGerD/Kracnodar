extends Control


func _ready():
	_open_at_screen_scale()
	%TabContainer.set_tab_title(0, "Générateur")
	%TabContainer.set_tab_title(3, "Bibliothèque")
	%WordGenerator.wordPicked.connect(%WordSelector.add_word)
	%WordSelector.words_changed.connect(%WordGenerator.set_listed_words)
	%TabContainer.tab_changed.connect(_on_TabContainer_tab_changed)
	Dict.save_failed.connect(_show_save_problem)
	if Dict.load_problem != "":
		_show_save_problem.call_deferred(
			"Le dictionnaire n'a pas pu être lu, et rien ne sera enregistré tant qu'il ne l'est pas : %s" % Dict.load_problem)


# The layout stretches to fit the window (display/window/stretch in the project
# settings), but window sizes are physical pixels, so on a retina display the
# window would open at half size. This opens it at the screen's scale instead,
# as far as the screen allows.
func _open_at_screen_scale() -> void:
	var window = get_window()
	var screen = window.current_screen
	var scale = DisplayServer.screen_get_scale(screen)
	if scale <= 1.0 or window.is_embedded() or window.mode != Window.MODE_WINDOWED:
		return
	var usable = Vector2(DisplayServer.screen_get_usable_rect(screen).size)
	window.size = Vector2i((Vector2(window.size) * scale).min(usable * 0.95))
	window.move_to_center()


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
