extends Node
## Préparation et sauvegarde RTS, indépendantes de la campagne.
const SessionSave = preload("res://scripts/session_save.gd")
var save_path := "user://sg1_expedition.json"
var resume_pending := false
var last_error := ""

var difficulty := "normal"
var profile := "balanced"


func options() -> Dictionary:
	return {"difficulty": difficulty, "profile": profile, "operation": true}

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

func save_session(state: Dictionary) -> bool:
	var ok := SessionSave.write(save_path, {"version": 1, "session": SessionSave.pack(state)})
	last_error = "" if ok else "Échec de la sauvegarde. La partie reste ouverte."
	return ok

func load_session() -> Dictionary:
	var data := SessionSave.read(save_path)
	var state := SessionSave.unpack(data.get("session", ""))
	if data.get("version", 0) != 1 or state.get("version", 0) != 1 or not state.has_all(["simulation", "view"]):
		last_error = "Sauvegarde d'expédition illisible ou incompatible. Elle a été conservée."
		return {}
	if not state.simulation is Dictionary or not state.view is Dictionary or not state.view.has_all(["focus", "distance", "selected", "tab", "logs"]) or not state.view.focus is Vector3 or not state.view.selected is Array or not state.view.logs is Array:
		last_error = "Sauvegarde d'expédition illisible ou incompatible. Elle a été conservée."
		return {}
	last_error = ""
	return state

func clear_session() -> bool:
	resume_pending = false
	if not has_save():
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path)) == OK
