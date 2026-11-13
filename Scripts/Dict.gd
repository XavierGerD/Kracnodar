extends Node

# The dictionary, in the same shape as dict.json:
#   French word -> {"en": English translation, "kr": Kracnodar word, "class": word class}
# "class" is one of the CLASSES ids, and is left out when the entry has none.
# It loads at startup and saves itself after every change (add_entries,
# replace_entry, remove_entry).
#
# Where the app keeps its files: run from the Godot editor, the project folder
# itself (dict.json and grammar.md in the repo); exported, its user-data folder,
# seeded from the copies packed with it. KRACNODAR_DATA_DIR overrides both, so
# tests can run on scratch copies.

signal save_failed(message)

const DICT_FILE = "dict.json"

# The word classes, in the order the pickers list them: [id saved in dict.json, name shown].
const CLASSES = [
	["verbe", "verbe"],
	["nom", "nom"],
	["adjectif", "adjectif"],
	["adverbe", "adverbe"],
	["pronom", "pronom"],
	["affixe", "affixe"],
	["relation", "marqueur de relation"],
	["temps", "marqueur de temps"],
	["preposition", "préposition"],
	["determinant", "déterminant"],
	["interrogatif", "interrogatif"],
	["negation", "négation"],
	["conjonction", "conjonction"],
	["autre", "autre"],
]

# The classes of modules, the words the other forms are derived from (grammar 2.1).
const MODULE_CLASSES = ["verbe", "nom", "adjectif", "adverbe"]

# The forms of a module, from the grammar's table of affixes (2.1.1). The affix
# goes after the word ("suffix"), before it ("prefix") or after it as a separate
# word ("word"). A module already is the form of its own class, with no affix:
# felek, a verb, is "to free"; dol, an adjective, gives the verb doltan.
const FORMS = [
	{"name": "Verbe", "affix": "tan", "at": "suffix", "class": "verbe"},
	{"name": "Nom", "affix": "ex", "at": "suffix", "class": "nom"},
	{"name": "Action", "affix": "am", "at": "suffix"},
	{"name": "Adverbe", "affix": "ken", "at": "prefix", "class": "adverbe"},
	{"name": "Adjectif", "affix": "pax", "at": "word", "class": "adjectif"},
	{"name": "Agent, instrument", "affix": "rom", "at": "suffix"},
	{"name": "Diminutif", "affix": "fo", "at": "suffix"},
	{"name": "Augmentatif", "affix": "op", "at": "suffix"},
	{"name": "Lieu", "affix": "bar", "at": "suffix"},
]

var dict = {}

# Set when dict.json exists but can't be read. Saving is then off, so a bad
# file is never replaced by an empty dictionary.
var load_problem = ""


func _ready():
	var path = read_path(DICT_FILE)
	if FileAccess.file_exists(path):
		var problem = load_file(path)
		if problem != "":
			dict = {}
			load_problem = problem


func data_dir() -> String:
	var override = OS.get_environment("KRACNODAR_DATA_DIR")
	if override != "":
		return override
	return "res://" if OS.has_feature("editor") else "user://"


# Where a data file is saved.
func data_path(file_name: String) -> String:
	return data_dir().path_join(file_name)


# Where a data file is read: the saved copy, or else the one packed with the app.
func read_path(file_name: String) -> String:
	var path = data_path(file_name)
	return path if FileAccess.file_exists(path) else "res://".path_join(file_name)


# Where per-machine scratch files go (the new terms not yet added).
func scratch_path(file_name: String) -> String:
	var override = OS.get_environment("KRACNODAR_DATA_DIR")
	return (override if override != "" else "user://").path_join(file_name)


# Writes the dictionary to dict.json. Reports and returns false if it can't.
func save() -> bool:
	if load_problem != "":
		save_failed.emit("Les changements ne sont pas enregistrés : %s" % load_problem)
		return false
	var path = data_path(DICT_FILE)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		save_failed.emit("Impossible d'enregistrer « %s » (%s)." % [
			ProjectSettings.globalize_path(path), error_string(FileAccess.get_open_error())])
		return false
	file.store_string(to_json())
	return true


# Reads a dictionary file and merges it in. Returns "" or what went wrong.
func load_file(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		if FileAccess.get_open_error() == ERR_FILE_NOT_FOUND:
			return "« %s » est introuvable." % path
		return "impossible de lire « %s » (%s)." % [path, error_string(FileAccess.get_open_error())]
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return "« %s » n'est pas du JSON valide (ligne %d : %s)." % [
			path.get_file(), json.get_error_line() + 1, json.get_error_message()]
	if merge(json.data) < 0:
		return "« %s » ne contient pas de dictionnaire." % path.get_file()
	return ""


func krac_of(french: String) -> String:
	var entry = dict.get(french)
	return str(entry.get("kr", "")) if entry is Dictionary else ""


func english_of(french: String) -> String:
	var entry = dict.get(french)
	return str(entry.get("en", "")) if entry is Dictionary else ""


# The entry's class id, or "" if it has none.
func class_of(french: String) -> String:
	var entry = dict.get(french)
	return str(entry.get("class", "")) if entry is Dictionary else ""


# The name shown for a class id ("" for none; an unknown id is shown as is).
func class_label(id: String) -> String:
	for pair in CLASSES:
		if pair[0] == id:
			return pair[1]
	return id


# Fills a picker with "—" (no class) and the classes; each item's metadata is its id.
func fill_class_picker(picker: OptionButton) -> void:
	picker.clear()
	picker.add_item("—")
	picker.set_item_metadata(0, "")
	for pair in CLASSES:
		picker.add_item(pair[1])
		picker.set_item_metadata(picker.item_count - 1, pair[0])


# Selects a class id in a picker filled by fill_class_picker. An id it doesn't
# list is added, so editing an entry never loses its class.
func pick_class(picker: OptionButton, id: String) -> void:
	for i in picker.item_count:
		if picker.get_item_metadata(i) == id:
			picker.select(i)
			return
	picker.add_item(id)
	picker.set_item_metadata(picker.item_count - 1, id)
	picker.select(picker.item_count - 1)


func picked_class(picker: OptionButton) -> String:
	return str(picker.get_item_metadata(picker.selected)) if picker.selected >= 0 else ""


func has_derived_forms(french: String) -> bool:
	return class_of(french) in MODULE_CLASSES and krac_of(french).strip_edges() != ""


# The forms derived from a module (see FORMS), [] for other classes:
#   [{"name": the form, "word": the Kracnodar word, "affix": how it was made
#     ("" for the module itself), "existing": the French of another entry
#     already spelled that way, or ""}]
func derived_forms(french: String) -> Array:
	if not has_derived_forms(french):
		return []
	var word_class = class_of(french)
	var module = krac_of(french).strip_edges()
	var forms = []
	for form in FORMS:
		var word = module
		var affix = ""
		if form.get("class", "") != word_class:
			match form["at"]:
				"prefix":
					word = form["affix"] + module
					affix = form["affix"] + " +"
				"word":
					word = module + " " + form["affix"]
					affix = "+ " + form["affix"]
				_:
					word = module + form["affix"]
					affix = "+ " + form["affix"]
		var existing = french_for_krac(word) if affix != "" else ""
		forms.append({"name": form["name"], "word": word, "affix": affix, "existing": existing})
	return forms


# The French word that already uses this Kracnodar word, or "" if none does.
func french_for_krac(krac: String) -> String:
	for french in dict:
		if krac_of(french) == krac:
			return french
	return ""


# Each change below saves at once; if saving fails it is undone, so what the
# app shows is always what's on disk. They return whether it worked.

# Adds entries ({"fr", "kr", "en", and optionally "class"}).
func add_entries(entries: Array) -> bool:
	var before = dict.duplicate(true)
	for entry in entries:
		_set_entry(entry["fr"], entry["kr"], entry["en"], str(entry.get("class", "")))
	return _commit(before)


# Changes an entry, renaming its French key in place so the file order stays put.
func replace_entry(old_french: String, french: String, krac: String, english: String, word_class := "") -> bool:
	var before = dict.duplicate(true)
	if old_french == french:
		_set_entry(french, krac, english, word_class)
	else:
		var rebuilt = {}
		for key in dict:
			if key == old_french:
				rebuilt[french] = _entry(krac, english, word_class)
			else:
				rebuilt[key] = dict[key]
		dict = rebuilt
	return _commit(before)


func remove_entry(french: String) -> bool:
	var before = dict.duplicate(true)
	dict.erase(french)
	return _commit(before)


func _commit(before: Dictionary) -> bool:
	if save():
		return true
	dict = before
	return false


func _set_entry(french: String, krac: String, english: String, word_class := "") -> void:
	dict[french] = _entry(krac, english, word_class)


func _entry(krac: String, english: String, word_class: String) -> Dictionary:
	var entry = {"en": english, "kr": krac}
	if word_class != "":
		entry["class"] = word_class
	return entry


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


# The shortest run of letters two Kracnodar words may share before they count as overlapping.
const MIN_OVERLAP = 3


# Dictionary words that share at least MIN_OVERLAP letters in a row with `krac`
# (an exact match included), longest shared run first:
#   [{"french": ..., "krac": ..., "shared": the run, lowercase, "exact": bool}]
func overlaps(krac: String, except_french := "") -> Array:
	var word = krac.strip_edges().to_lower()
	var found = []
	if word.length() < MIN_OVERLAP:
		return found
	for french in dict:
		if french == except_french:
			continue
		var other = krac_of(french)
		var shared = longest_shared_run(word, other.to_lower())
		if shared.length() >= MIN_OVERLAP:
			found.append({"french": french, "krac": other, "shared": shared, "exact": other.to_lower() == word})
	found.sort_custom(func(a, b):
		if a["exact"] != b["exact"]:
			return a["exact"]
		if a["shared"].length() != b["shared"].length():
			return a["shared"].length() > b["shared"].length()
		return a["krac"] < b["krac"])
	return found


static func longest_shared_run(a: String, b: String) -> String:
	var best = ""
	for i in a.length():
		for j in b.length():
			var k = 0
			while i + k < a.length() and j + k < b.length() and a[i + k] == b[j + k]:
				k += 1
			if k > best.length():
				best = a.substr(i, k)
	return best


# Merges parsed JSON into the dictionary; its entries replace existing ones.
# Also reads the older {"kracnodar": "français"} files. Returns how many entries
# were merged, or -1 when the data is not a dictionary file at all.
func merge(data) -> int:
	if not data is Dictionary:
		return -1
	var merged = 0
	for key in data:
		var value = data[key]
		if value is Dictionary and value.get("kr") is String:
			var word_class = value.get("class") if value.get("class") is String else ""
			dict[str(key)] = _entry(value["kr"], str(value.get("en", "")), word_class)
			merged += 1
		elif value is String:
			_set_entry(value, str(key), "")
			merged += 1
	return merged


# One entry per line, in dictionary order, so saved files diff cleanly.
func to_json() -> String:
	var lines = []
	for french in dict:
		var fields = '"en": %s, "kr": %s' % [JSON.stringify(english_of(french)), JSON.stringify(krac_of(french))]
		if class_of(french) != "":
			fields += ', "class": %s' % JSON.stringify(class_of(french))
		lines.append('  %s: {%s}' % [JSON.stringify(french), fields])
	if lines.is_empty():
		return "{}\n"
	return "{\n" + ",\n".join(lines) + "\n}\n"
