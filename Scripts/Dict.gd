extends Node

# The dictionary, in the same shape as dict.json:
#   French word -> {"en": English translation, "kr": Kracnodar word, "class": word class}
# "class" is one of the CLASSES ids, and is left out when the entry has none.
# "derived", also optional, gives meanings to the module's derived forms, by
# form name (FORMS): {"Nom": "freedom", "Action": "liberation"}. A form spelled
# otherwise than its affix makes it (the grammar's short forms, 2.1.1) gives
# its own spelling too: {"Nom": {"en": "love", "kr": "gerex"}}, or {"kr": ...}
# alone. In memory every form is kept in that longer shape (see derived_data).
# It loads at startup and saves itself after every change (add_entries,
# replace_entry, remove_entry).
#
# Where the app keeps its files: the repo (dict.json, grammar.md and the rest
# next to project.godot), run from the Godot editor or as the exported app kept
# in the repo. An exported copy that is not inside the repo falls back on its
# user-data folder, seeded from the copies packed with it. KRACNODAR_DATA_DIR
# overrides all of these, so tests can run on scratch copies.

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
	["nombre", "nombre"],
	["autre", "autre"],
]

# The classes of modules, the words the other forms are derived from (grammar 2.1).
const MODULE_CLASSES = ["verbe", "nom", "adjectif", "adverbe"]

# The forms of a module, from the grammar's table of affixes (2.1.1). The affix
# goes after the word ("suffix") or before it ("prefix"). A module already is
# the form of its own class, with no affix:
# felek, a verb, is "to free"; dol, an adjective, gives the verb doltan.
const FORMS = [
	{"name": "Verbe", "affix": "tan", "at": "suffix", "class": "verbe"},
	{"name": "Nom", "affix": "ex", "at": "suffix", "class": "nom"},
	{"name": "Action", "affix": "am", "at": "suffix"},
	{"name": "Adverbe", "affix": "ken", "at": "prefix", "class": "adverbe"},
	{"name": "Adjectif", "affix": "pax", "at": "suffix", "class": "adjectif"},
	{"name": "Agent, instrument", "affix": "rom", "at": "suffix"},
	{"name": "Diminutif", "affix": "fo", "at": "suffix"},
	{"name": "Augmentatif", "affix": "op", "at": "suffix"},
	{"name": "Lieu", "affix": "bar", "at": "suffix"},
]

# The consonant that links two lexemes sharing a vowel where they join, when
# dropping one of the two vowels would spell another word or affix (grammar 1.3).
const LINKING_CONSONANTS = {"e": "n", "a": "n", "i": "n", "o": "v", "u": "v"}

var dict = {}

# Set when dict.json exists but can't be read. Saving is then off, so a bad
# file is never replaced by an empty dictionary.
var load_problem = ""

# The exported app's data folder, found once (see data_dir).
var _repo = ""

# Each data file's text as the app last read or wrote it, by file name, so
# Refresh can tell which ones were changed outside the app (see changed_on_disk).
var _disk = {}

# Bumped whenever the dictionary changes (see _changed), so callers can keep
# what they work out from it until then. Every change goes through this file.
var revision = 0

# Spellings looked up across the whole dictionary (see _lookups_of), worked out
# once per change instead of on every call: {} until needed.
var _lookups = {}


func _ready():
	print("Kracnodar data: ", ProjectSettings.globalize_path(data_dir()))
	var path = read_path(DICT_FILE)
	if FileAccess.file_exists(path):
		var problem = load_file(path)
		if problem != "":
			dict = {}
			load_problem = problem
	_changed()


func data_dir() -> String:
	var override = OS.get_environment("KRACNODAR_DATA_DIR")
	if override != "":
		return override
	if OS.has_feature("editor"):
		return "res://"
	if _repo == "":
		_repo = repo_dir()
		if _repo == "":
			_repo = "user://"
	return _repo


# The Kracnodar repo the exported app sits in: the nearest folder holding this
# project's project.godot, from the executable's own folder up ("" if none).
static func repo_dir(executable := OS.get_executable_path()) -> String:
	var dir = executable.replace("\\", "/").get_base_dir()
	while dir != "":
		var project = ConfigFile.new()
		if project.load(dir.path_join("project.godot")) == OK \
				and project.get_value("application", "config/name", "") == "Kracnodar":
			return dir
		var parent = dir.get_base_dir()
		if parent == dir:
			break
		dir = parent
	return ""


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
	var text = to_json()
	file.store_string(text)
	remember(DICT_FILE, text)
	return true


# Reads dict.json again, in place of the dictionary loaded (after it was edited
# outside the app). Returns "" or what went wrong; then the dictionary loaded
# stays, and saving is off until a reload works, so the bad file isn't replaced.
func reload() -> String:
	var path = read_path(DICT_FILE)
	if not FileAccess.file_exists(path):
		return ""
	var before = dict
	dict = {}
	load_problem = load_file(path)
	if load_problem != "":
		dict = before
	_changed()
	return load_problem


# Notes a data file's text, as just read or written (see changed_on_disk).
func remember(file_name: String, text: String) -> void:
	_disk[file_name] = text


# Whether a data file on disk differs from what the app last read or wrote.
func changed_on_disk(file_name: String) -> bool:
	var path = read_path(file_name)
	var text = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	return text != _disk.get(file_name, "")


# Reads a dictionary file and merges it in. Returns "" or what went wrong.
func load_file(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		if FileAccess.get_open_error() == ERR_FILE_NOT_FOUND:
			return "« %s » est introuvable." % path
		return "impossible de lire « %s » (%s)." % [path, error_string(FileAccess.get_open_error())]
	var text = file.get_as_text()
	remember(path.get_file(), text)
	var json = JSON.new()
	if json.parse(text) != OK:
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
#   [{"name": the form, "word": the Kracnodar word, "regular": the word as the
#     affix makes it, "respelled": whether the form was given a spelling of its
#     own instead, "affix": how it was made ("" for the module itself),
#     "existing": the French of another entry already spelled that way, or "",
#     "meaning": its meaning, or "" when none was given (see set_derived)}]
func derived_forms(french: String) -> Array:
	if not has_derived_forms(french):
		return []
	var given = _given(french)
	var forms = []
	for form in FORMS:
		var made = _regular_form(french, form)
		var word = made[0]
		var affix = made[1]
		var data = given.get(form["name"], {}) if affix != "" else {}
		var spelling = str(data.get("kr", "")).strip_edges()
		var respelled = spelling != "" and spelling.to_lower() != word.to_lower()
		var existing = french_for_krac(spelling if respelled else word) if affix != "" else ""
		forms.append({"name": form["name"], "word": spelling if respelled else word, "regular": word,
			"respelled": respelled, "affix": affix, "existing": existing, "meaning": str(data.get("en", ""))})
	return forms


# A form of a module as its affix makes it: [the word, how it was made], where
# how is "" for the module itself (the form of its own class).
func _regular_form(french: String, form: Dictionary) -> Array:
	var module = krac_of(french).strip_edges()
	if form.get("class", "") == class_of(french):
		return [module, ""]
	if form["at"] == "prefix":
		var link = linking_consonant(form["affix"], module)
		return [form["affix"] + link + module,
			form["affix"] + (" + %s (liaison)" % link if link != "" else "") + " +"]
	var link = linking_consonant(module, form["affix"])
	return [module + link + form["affix"],
		("+ %s (liaison) " % link if link != "" else "") + "+ " + form["affix"]]


# What was given to an entry's derived forms, by form name (see "derived"):
#   {"Nom": {"en": "love", "kr": "gerex"}, "Diminutif": {"en": "to like"}}
# A form with neither a meaning nor a spelling of its own isn't listed.
func derived_data(french: String) -> Dictionary:
	return _given(french).duplicate(true)


# derived_data without the copy, for reading only.
func _given(french: String) -> Dictionary:
	var entry = dict.get(french)
	var given = entry.get("derived", {}) if entry is Dictionary else {}
	return given if given is Dictionary else {}


# Gives a derived form a meaning and a spelling of its own, or takes either
# away with "". A spelling the affix already gives is no spelling of its own.
# Saves at once.
func set_derived(french: String, form_name: String, meaning: String, krac := "") -> bool:
	if not dict.has(french):
		return false
	var before = dict.duplicate(true)
	var given = derived_data(french)
	var data = {}
	if meaning.strip_edges() != "":
		data["en"] = meaning.strip_edges()
	var spelling = krac.strip_edges()
	for form in FORMS:
		if form["name"] == form_name and spelling.to_lower() == _regular_form(french, form)[0].to_lower():
			spelling = ""
	if spelling != "":
		data["kr"] = spelling
	if data.is_empty():
		given.erase(form_name)
	else:
		given[form_name] = data
	if given.is_empty():
		dict[french].erase("derived")
	else:
		dict[french]["derived"] = given
	return _commit(before)


# How many words the modules give through their affixes (see derived_forms):
# each spelling counted once, and none that is already an entry of its own.
func derived_count() -> int:
	var words = {}
	for french in dict:
		for form in derived_forms(french):
			if form["affix"] != "" and form["existing"] == "":
				words[form["word"].to_lower()] = true
	return words.size()


# The consonant that goes between two lexemes joined into one word, or "" when
# they join as they are (grammar 1.3): only where the first ends with the vowel
# the second starts with, and dropping one of the two would spell another word
# or affix. e + ex gives enex, since dropping a vowel would leave ex. `second`
# is the whole rest of the word: da + avatagu needs no link, as davatagu is new.
func linking_consonant(first: String, second: String) -> String:
	var vowel = first.right(1).to_lower()
	if not LINKING_CONSONANTS.has(vowel) or second.left(1).to_lower() != vowel:
		return ""
	return LINKING_CONSONANTS[vowel] if is_spelled(first + second.substr(1)) else ""


# Whether a word is already spelled this way: an entry of the dictionary, a
# module with one of its affixes joined on (FORMS), or a derived form's own
# spelling (see set_derived).
func is_spelled(word: String) -> bool:
	return _lookups_of()["spelled"].has(word.to_lower())


# The French word that already uses this Kracnodar word, or "" if none does.
func french_for_krac(krac: String) -> String:
	return _lookups_of()["french_of"].get(krac, "")


# What is_spelled and french_for_krac look up, built from the whole dictionary
# once after each change: {"spelled": {every spelling, lowercase: true},
# "french_of": {Kracnodar word: the first French word, in file order, using it}}.
func _lookups_of() -> Dictionary:
	if not _lookups.is_empty():
		return _lookups
	var spelled = {}
	var french_of = {}
	for french in dict:
		var word = krac_of(french)
		if not french_of.has(word):
			french_of[word] = french
		var krac = word.strip_edges().to_lower()
		spelled[krac] = true
		if class_of(french) in MODULE_CLASSES and krac != "":
			for form in FORMS:
				if form["at"] == "suffix":
					spelled[krac + form["affix"]] = true
				elif form["at"] == "prefix":
					spelled[form["affix"] + krac] = true
			var given = _given(french)
			for form_name in given:
				spelled[str(given[form_name].get("kr", "")).strip_edges().to_lower()] = true
	_lookups = {"spelled": spelled, "french_of": french_of}
	return _lookups


# After any change to dict: what was worked out from it is out of date.
func _changed() -> void:
	revision += 1
	_lookups = {}


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
				rebuilt[french] = _entry(krac, english, word_class, _given(old_french))
			else:
				rebuilt[key] = dict[key]
		dict = rebuilt
	return _commit(before)


func remove_entry(french: String) -> bool:
	var before = dict.duplicate(true)
	dict.erase(french)
	return _commit(before)


func _commit(before: Dictionary) -> bool:
	_changed()
	if save():
		return true
	dict = before
	_changed()
	return false


# Keeps what was already given to the entry's derived forms.
func _set_entry(french: String, krac: String, english: String, word_class := "") -> void:
	dict[french] = _entry(krac, english, word_class, _given(french))


func _entry(krac: String, english: String, word_class: String, derived := {}) -> Dictionary:
	var entry = {"en": english, "kr": krac}
	if word_class != "":
		entry["class"] = word_class
	if not derived.is_empty():
		entry["derived"] = derived.duplicate(true)
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
			var derived = {}
			if value.get("derived") is Dictionary:
				derived = _derived_from_json(value["derived"])
			else:
				derived = _given(str(key))  # a file without meanings keeps the ones given here
			dict[str(key)] = _entry(value["kr"], str(value.get("en", "")), word_class, derived)
			merged += 1
		elif value is String:
			_set_entry(value, str(key), "")
			merged += 1
	_changed()
	return merged


# One entry per line, in dictionary order, so saved files diff cleanly.
func to_json() -> String:
	var lines = []
	for french in dict:
		var fields = '"en": %s, "kr": %s' % [JSON.stringify(english_of(french)), JSON.stringify(krac_of(french))]
		if class_of(french) != "":
			fields += ', "class": %s' % JSON.stringify(class_of(french))
		if not _given(french).is_empty():
			fields += ', "derived": %s' % JSON.stringify(_derived_to_json(_given(french)), "", false)
		lines.append('  %s: {%s}' % [JSON.stringify(french), fields])
	if lines.is_empty():
		return "{}\n"
	return "{\n" + ",\n".join(lines) + "\n}\n"


# A "derived" object read from a file, in the shape kept in memory (see
# derived_data): a form given as a string is its meaning.
static func _derived_from_json(value: Dictionary) -> Dictionary:
	var derived = {}
	for form_name in value:
		var item = value[form_name]
		var data = {}
		if item is String:
			if item != "":
				data["en"] = item
		elif item is Dictionary:
			for field in ["en", "kr"]:
				if item.get(field) is String and item[field].strip_edges() != "":
					data[field] = item[field]
		if not data.is_empty():
			derived[str(form_name)] = data
	return derived


# The shape saved to dict.json: a form with only a meaning is written as that
# meaning, as before spellings could be given, so those lines don't change.
static func _derived_to_json(derived: Dictionary) -> Dictionary:
	var saved = {}
	for form_name in derived:
		var data = derived[form_name]
		saved[form_name] = data["en"] if data.size() == 1 and data.has("en") else data
	return saved
