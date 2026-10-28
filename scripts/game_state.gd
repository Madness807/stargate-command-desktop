extends Node
## L'état de la partie (autoload « Game ») : progression de SG-1, équipe, équipement et sauvegarde.
## Pas d'interface ici : les écrans lisent cet état et réagissent à ses signaux.

const Data = preload("res://scripts/data.gd")

## Variable pour que les tests (dev/tests.gd) écrivent ailleurs que dans la vraie partie
var save_path := "user://sg1_3d.json"
const SAVE_VERSION := 1

signal changed
signal leveled_up(level: int)

## naq, xp, lvl, done (missions accomplies), hp (PV par membre), weapon, armor (rang dans l'armurerie), kits
var stats := {}
var team: Array = []


func _ready() -> void:
	load_game()


func _fresh() -> Dictionary:
	return {"naq": Data.START_NAQ, "xp": 0, "lvl": 1, "done": 0, "hp": {}, "weapon": 0, "armor": 0, "kits": Data.START_KITS}


# ---------- Sauvegarde ----------

func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func load_game() -> void:
	stats = _fresh()
	if has_save():
		var d = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if d is Dictionary:
			for k in ["naq", "xp", "lvl", "done", "weapon", "armor", "kits"]:
				if d.has(k):
					stats[k] = int(d[k])
			if d.get("hp") is Dictionary:
				for k in d.hp:
					if Data.MEMBERS.has(k):
						stats.hp[k] = int(d.hp[k])
		else:
			push_warning("Sauvegarde illisible, nouvelle partie : %s" % save_path)
	_sanitize()
	refresh_team()


## Des bornes sûres, même face à une sauvegarde modifiée à la main
func _sanitize() -> void:
	stats.lvl = maxi(1, stats.lvl)
	stats.xp = maxi(0, stats.xp)
	stats.naq = maxi(0, stats.naq)
	stats.done = clampi(stats.done, 0, Data.PLANETS.size())
	stats.weapon = clampi(stats.weapon, 0, Data.WEAPONS.size() - 1)
	stats.armor = clampi(stats.armor, 0, Data.ARMORS.size() - 1)
	stats.kits = clampi(stats.kits, 0, Data.KIT_MAX)


## Écrit d'abord un fichier temporaire puis le renomme : une coupure en pleine écriture ne corrompt pas la partie
func save_game() -> void:
	var out := stats.duplicate(true)
	out["version"] = SAVE_VERSION
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Sauvegarde impossible (%s) : %s" % [error_string(FileAccess.get_open_error()), tmp])
		return
	f.store_string(JSON.stringify(out))
	f.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(save_path))
	if err != OK:
		push_error("Sauvegarde impossible (%s) : %s" % [error_string(err), save_path])
	changed.emit()


func new_game() -> void:
	stats = _fresh()
	refresh_team()
	heal_all()
	save_game()


# ---------- L'équipe ----------

## Maître Bra'tac rejoint SG-1 une fois Chulak libérée
func refresh_team() -> void:
	team = Data.CORE_TEAM.duplicate()
	if int(stats.done) >= Data.BRATAC_AFTER:
		team.append("bratac")
	heal_all(false)


static func member_max(k: String, level: int) -> int:
	return int(Data.MEMBERS[k].hp) + Data.HP_PER_LEVEL * (level - 1)


func hp_max(k: String) -> int:
	return member_max(k, stats.lvl)


## Les soins du Dr Fraiser ; full = false ne fait que borner les PV au maximum
func heal_all(full: bool = true) -> void:
	for k in team:
		if full or not stats.hp.has(k):
			stats.hp[k] = hp_max(k)
		stats.hp[k] = clampi(int(stats.hp[k]), 0, hp_max(k))


## Des dégâts pour toute l'équipe (piège, décharge) ; renvoie false si plus personne n'est debout
func hurt_all(dmg: int) -> bool:
	var standing := false
	for k in team:
		stats.hp[k] = maxi(0, stats.hp[k] - dmg)
		if stats.hp[k] > 0:
			standing = true
	return standing


## Le membre le plus blessé, ou "" si tout le monde est à fond
func most_wounded() -> String:
	var worst := ""
	var ratio := 1.0
	for k in team:
		var r := float(stats.hp[k]) / hp_max(k)
		if r < ratio:
			ratio = r
			worst = k
	return worst


## Utilise une trousse sur k ; renvoie les PV rendus (0 si aucune trousse)
func use_kit(k: String) -> int:
	if stats.kits <= 0:
		return 0
	stats.kits -= 1
	var before: int = stats.hp[k]
	stats.hp[k] = mini(hp_max(k), before + Data.kit_heal(stats.lvl))
	save_game()
	return stats.hp[k] - before


# ---------- Progression ----------

func xp_to_next() -> int:
	return int(stats.lvl) * Data.XP_PER_LEVEL


func gain_xp(g: int) -> void:
	stats.xp += g
	while stats.xp >= xp_to_next():
		stats.xp -= xp_to_next()
		stats.lvl += 1
		heal_all()
		leveled_up.emit(stats.lvl)
	save_game()


func add_naq(n: int) -> void:
	stats.naq = maxi(0, stats.naq + n)


## Une planète libérée ; renvoie true si Bra'tac vient de rejoindre l'équipe
func complete_mission(i: int) -> bool:
	var had_bratac := team.has("bratac")
	stats.done = maxi(int(stats.done), i + 1)
	refresh_team()
	save_game()
	return team.has("bratac") and not had_bratac


func unlocked(i: int) -> bool:
	return i <= int(stats.done)


# ---------- Équipement ----------

func gear() -> Dictionary:
	var w: Dictionary = Data.WEAPONS[stats.weapon]
	return {"dmg": w.dmg, "hit": w.hit, "armor": Data.ARMORS[stats.armor].armor}


## what : "weapon", "armor" ou "kits" ; renvoie false s'il manque du naquadah
func buy(what: String, value: int, price: int) -> bool:
	if stats.naq < price:
		return false
	stats.naq -= price
	stats[what] = value
	save_game()
	return true
