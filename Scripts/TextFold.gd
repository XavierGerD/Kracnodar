extends RefCounted

# Text folding for search: lowercase, accents removed, so "Être" finds "etre".
# Used through preload (no class_name), so it works before the editor rescans.

const ACCENTS = {
	"à": "a", "â": "a", "ä": "a", "á": "a", "ã": "a", "å": "a", "ç": "c",
	"é": "e", "è": "e", "ê": "e", "ë": "e", "î": "i", "ï": "i", "í": "i", "ì": "i",
	"ô": "o", "ö": "o", "ó": "o", "ò": "o", "õ": "o", "ù": "u", "û": "u", "ü": "u", "ú": "u",
	"ÿ": "y", "ñ": "n", "œ": "oe", "æ": "ae",
}


static func fold(text: String) -> String:
	var folded = text.to_lower()
	for accented in ACCENTS:
		folded = folded.replace(accented, ACCENTS[accented])
	return folded
