extends RefCounted
## Enveloppe JSON atomique. Les états contiennent uniquement des valeurs, jamais des objets exécutables.

static func pack(state: Dictionary) -> String:
	return Marshalls.raw_to_base64(var_to_bytes(state))

static func unpack(encoded: Variant) -> Dictionary:
	if not encoded is String or encoded.is_empty():
		return {}
	var value = bytes_to_var(Marshalls.base64_to_raw(encoded))
	return value if value is Dictionary else {}

static func write(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) == OK

static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		return {}
	return parser.data
