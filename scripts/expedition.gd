extends Node
## Préparation RTS en mémoire uniquement. Ne lit ni n'écrit la sauvegarde de campagne.

var difficulty := "normal"
var profile := "balanced"


func options() -> Dictionary:
	return {"difficulty": difficulty, "profile": profile}
