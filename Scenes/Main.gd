extends Control

# The data files Refresh reads again when they changed outside the app (edited
# by hand, pulled with git, saved by another copy of the app).
const DATA_FILES = ["dict.json", "grammar.md", "library.md", "glyphs.json"]

var _refresh_status: Label
var _refresh_confirm: ConfirmationDialog
var _status_tween: Tween
var _waiting = []  # the changed files, while the confirmation is open


func _ready():
	_open_at_screen_scale()
	%TabContainer.set_tab_title(0, "Générateur")
	%TabContainer.set_tab_title(3, "Bibliothèque")
	%TabContainer.set_tab_title(%TabContainer.get_tab_idx_from_control(%Sandbox), "Bac à sable")
	%WordGenerator.wordPicked.connect(%WordSelector.add_word)
	%WordSelector.words_changed.connect(%WordGenerator.set_listed_words)
	%TabContainer.tab_changed.connect(_on_TabContainer_tab_changed)
	%Alphabet.alphabet_changed.connect(%Grammaire.alphabet_changed)
	%Alphabet.alphabet_changed.connect(%Sandbox.alphabet_changed)
	%Alphabet.alphabet_changed.connect(%Bibliotheque.alphabet_changed)
	Dict.save_failed.connect(_show_save_problem)
	if Dict.load_problem != "":
		_show_save_problem.call_deferred(
			"Le dictionnaire n'a pas pu être lu, et rien ne sera enregistré tant qu'il ne l'est pas : %s" % Dict.load_problem)
	_add_refresh_button()
	
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN:
			refresh()

# --- Refresh ----------------------------------------------------------------

# A button at the right of the header, and F5 (or Ctrl+R, Cmd+R on a Mac):
# reads again the data files changed on disk, without restarting the app.
func _add_refresh_button() -> void:
	var header = $Margin/Layout/Header
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	_refresh_status = Label.new()
	_refresh_status.theme_type_variation = "HintLabel"
	_refresh_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_refresh_status)
	var button = Button.new()
	button.name = "RefreshButton"
	button.text = "↻  Recharger"
	button.tooltip_text = "Relit les fichiers modifiés en dehors de l'app (%s) · F5" % ", ".join(DATA_FILES)
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(refresh)
	header.add_child(button)
	_refresh_confirm = ConfirmationDialog.new()
	_refresh_confirm.title = "Recharger"
	_refresh_confirm.ok_button_text = "Recharger"
	_refresh_confirm.cancel_button_text = "Annuler"
	_refresh_confirm.dialog_autowrap = true
	_refresh_confirm.confirmed.connect(func(): _reload(_waiting))
	add_child(_refresh_confirm)


func _shortcut_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F5 or (event.keycode == KEY_R and event.is_command_or_control_pressed()):
		refresh()
		get_viewport().set_input_as_handled()


# Reads again the files changed on disk. A change open in an editor, in a tab
# whose file changed, would be lost: that asks first.
func refresh() -> void:
	var changed = DATA_FILES.filter(func(file_name): return Dict.changed_on_disk(file_name))
	if changed.is_empty():
		_show_refresh_status("Rien n'a changé sur le disque.")
		return
	var open = []
	if "dict.json" in changed and %Dictionnaire.has_open_edit():
		open.append("un terme du dictionnaire")
	if "grammar.md" in changed and %Grammaire.has_open_edit():
		open.append("l'article de la grammaire")
	if "library.md" in changed and %Bibliotheque.has_open_edit():
		open.append("le texte de la bibliothèque")
	if open.is_empty():
		_reload(changed)
		return
	_waiting = changed
	_refresh_confirm.dialog_text = "%s %s changé sur le disque. Ce qui est en cours de modification (%s) sera perdu." % [
		", ".join(changed), "a" if changed.size() == 1 else "ont", ", ".join(open)]
	_refresh_confirm.size = Vector2i(480, 0)
	_refresh_confirm.popup_centered()


func _reload(changed: Array) -> void:
	var done = []
	if "dict.json" in changed:
		var problem = Dict.reload()
		if problem == "":
			done.append("dict.json")
		else:
			_show_save_problem("Le dictionnaire n'a pas pu être relu ; celui d'avant reste affiché, et rien ne sera enregistré tant qu'il ne l'est pas : %s" % problem)
		%Dictionnaire.refresh()
		%WordGenerator.refresh_chips()
		%Bibliotheque.dictionary_changed()
	if "grammar.md" in changed:
		%Grammaire.reload()
		done.append("grammar.md")
	if "library.md" in changed:
		%Bibliotheque.reload()
		done.append("library.md")
	if "glyphs.json" in changed and %Alphabet.reload():
		done.append("glyphs.json")
	if not done.is_empty():
		_show_refresh_status("Rechargé : " + ", ".join(done))


# A short note by the button, which fades out.
func _show_refresh_status(text: String) -> void:
	if _status_tween:
		_status_tween.kill()
	_refresh_status.text = text
	_refresh_status.modulate.a = 1.0
	_status_tween = create_tween()
	_status_tween.tween_interval(3.0)
	_status_tween.tween_property(_refresh_status, "modulate:a", 0.0, 0.6)


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
	elif shown == %Sandbox:
		%Sandbox.shown()
	elif shown == %TabContainer.get_node("Generateur"):
		# The dictionary may have been edited meanwhile.
		%WordGenerator.refresh_chips()
