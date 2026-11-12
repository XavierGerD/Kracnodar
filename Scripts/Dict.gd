extends Node

const SETTINGS_PATH = "user://settings.cfg"

# The dictionary, in the same shape as dict.json:
#   French word -> {"en": English translation, "kr": Kracnodar word}
var dict = {}

# The file last imported or saved, reopened when the app starts ("" if none).
var file_path = ""


func _ready():
	var settings = ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		file_path = str(settings.get_value("dictionary", "last_file", ""))


func remember_file(path: String) -> void:
	file_path = path
	var settings = ConfigFile.new()
	settings.load(SETTINGS_PATH)  # keeps any other settings; a missing file is fine
	settings.set_value("dictionary", "last_file", path)
	settings.save(SETTINGS_PATH)


# Reads a dictionary file and merges it in. Returns "" or what went wrong.
func load_file(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		if FileAccess.get_open_error() == ERR_FILE_NOT_FOUND:
			return "« %s » est introuvable." % path
		return "Impossible de lire « %s » (%s)." % [path, error_string(FileAccess.get_open_error())]
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return "« %s » n'est pas du JSON valide (ligne %d : %s)." % [
			path.get_file(), json.get_error_line() + 1, json.get_error_message()]
	if merge(json.data) < 0:
		return "« %s » ne contient pas de dictionnaire." % path.get_file()
	return ""


# Writes the dictionary to a file. Returns "" or what went wrong.
func save_file(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "Impossible d'écrire « %s » (%s)." % [path, error_string(FileAccess.get_open_error())]
	file.store_string(to_json())
	return ""


func krac_of(french: String) -> String:
	var entry = dict.get(french)
	return str(entry.get("kr", "")) if entry is Dictionary else ""


func english_of(french: String) -> String:
	var entry = dict.get(french)
	return str(entry.get("en", "")) if entry is Dictionary else ""


# The French word that already uses this Kracnodar word, or "" if none does.
func french_for_krac(krac: String) -> String:
	for french in dict:
		if krac_of(french) == krac:
			return french
	return ""


func add_entry(french: String, krac: String, english: String) -> void:
	dict[french] = {"en": english, "kr": krac}


# Why this French/Kracnodar pair cannot go in the dictionary, as messages;
# empty when it can. `except_french` is the entry being edited, which may keep its words.
func clashes(french: String, krac: String, except_french := "") -> Array:
	var problems = []
	if french != except_french and dict.has(french):
		problems.append("« %s » est déjà dans le dictionnaire (%s)." % [french, krac_of(french)])
	for other in dict:
		if other != except_french and krac_of(other) == krac:
			problems.append("« %s » est déjà utilisé pour « %s »." % [krac, other])
			break
	return problems


# Changes an entry, renaming its French key in place so the file order stays put.
func replace_entry(old_french: String, french: String, krac: String, english: String) -> void:
	if old_french == french:
		add_entry(french, krac, english)
		return
	var rebuilt = {}
	for key in dict:
		if key == old_french:
			rebuilt[french] = {"en": english, "kr": krac}
		else:
			rebuilt[key] = dict[key]
	dict = rebuilt


# Merges parsed JSON into the dictionary; imported entries replace existing ones.
# Also reads the older {"kracnodar": "français"} files. Returns how many entries
# were merged, or -1 when the data is not a dictionary file at all.
func merge(data) -> int:
	if not data is Dictionary:
		return -1
	var merged = 0
	for key in data:
		var value = data[key]
		if value is Dictionary and value.get("kr") is String:
			dict[str(key)] = {"en": str(value.get("en", "")), "kr": value["kr"]}
			merged += 1
		elif value is String:
			add_entry(value, str(key), "")
			merged += 1
	return merged


# One entry per line, in dictionary order, so saved files diff cleanly.
func to_json() -> String:
	var lines = []
	for french in dict:
		lines.append('  %s: {"en": %s, "kr": %s}' % [
			JSON.stringify(french), JSON.stringify(english_of(french)), JSON.stringify(krac_of(french))])
	if lines.is_empty():
		return "{}\n"
	return "{\n" + ",\n".join(lines) + "\n}\n"
