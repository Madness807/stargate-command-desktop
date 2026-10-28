extends RefCounted
## Les options de la ligne de commande (après « -- »), lues une seule fois.
## Drapeaux : --fps, --noglow, --fight, --armory, --options, --pause, --trace, --debugflash, --inputlog
## Valeurs : --auto=<planète>, --planet=<planète>, --tab=<onglet>, --options=<onglet>, --zoom=<facteur>, --quit=<s>, --shot=<png>@<s>,…

static var _args: PackedStringArray
static var _read := false


static func _all() -> PackedStringArray:
	if not _read:
		_args = OS.get_cmdline_user_args()
		_read = true
	return _args


static func has(flag: String) -> bool:
	return _all().has(flag)


## La valeur de --clé=valeur, ou fallback si l'option est absente
static func value(key: String, fallback: String = "") -> String:
	var prefix := key + "="
	for a in _all():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback


static func number(key: String, fallback: float = -1.0) -> float:
	var v := value(key)
	return float(v) if v.is_valid_float() else fallback
