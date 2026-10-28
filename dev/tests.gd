extends Node
## Tests de la logique du jeu (réglages, progression, sauvegarde), sans affichage :
## godot --headless --path . res://dev/tests.tscn
## Ils écrivent dans des fichiers à part : la vraie partie et les vrais réglages ne sont pas touchés.
## Code de sortie : 0 si tout passe, 1 sinon.

const Data = preload("res://scripts/data.gd")

var _fails := 0
var _count := 0


func _ready() -> void:
	var real_save: String = Game.save_path
	var real_cfg: String = Settings.path
	Game.save_path = "user://test_save.json"
	Settings.path = "user://test_settings.cfg"

	_test_settings()
	_test_progression()
	_test_save()
	_test_difficulty()

	# On remet tout comme avant
	for p in [Game.save_path, Game.save_path + ".tmp", Settings.path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	Game.save_path = real_save
	Settings.path = real_cfg
	Game.load_game()
	Settings._load()
	Settings.apply_all()

	print("%d/%d vérifications réussies" % [_count - _fails, _count])
	get_tree().quit(1 if _fails > 0 else 0)


func check(ok: bool, what: String) -> void:
	_count += 1
	if not ok:
		_fails += 1
		printerr("ÉCHEC : ", what)


func _test_settings() -> void:
	Settings.reset_defaults()
	check(Settings.value("preset") == "normal", "les réglages par défaut forment le préréglage Normale")
	Settings.set_value("preset", "eco")
	check(Settings.value("render_scale") == 45 and Settings.value("shadows") == "low" and not Settings.value("glow"),
		"le préréglage Économie règle résolution, ombres et halo")
	Settings.set_value("msaa", 2)
	check(Settings.value("preset") == "custom", "retoucher un réglage passe en Personnalisée")
	Settings.set_value("msaa", 0)
	check(Settings.value("preset") == "eco", "revenir aux valeurs d'un préréglage le retrouve")
	Settings.set_value("render_scale", 7)
	check(Settings.value("render_scale") == 40, "une valeur trop basse est ramenée au minimum")
	Settings.set_value("render_scale", 83)
	check(Settings.value("render_scale") == 85, "une valeur est arrondie au pas du curseur")
	Settings.set_value("difficulty", "n'importe quoi")
	check(Settings.value("difficulty") == "normal", "une valeur inconnue reprend la valeur par défaut")
	Settings.set_value("preset", "normal")
	Settings.step("preset", -1)
	check(Settings.value("preset") == "eco", "◀ sur Normale donne Économie")
	Settings.step("preset", -1)
	check(Settings.value("preset") == "max", "◀ sur Économie boucle sur Maximale, sans passer par Personnalisée")
	Settings.step("show_fps", 1)
	check(Settings.value("show_fps") == true, "▶ sur un Oui/Non l'inverse")
	check(not Settings.is_active("resolution"), "la taille de fenêtre est inactive en plein écran")
	check(Settings.display("vol_music") == "100 %", "affichage d'un pourcentage")
	Settings._save()
	var cf := ConfigFile.new()
	check(cf.load(Settings.path) == OK and cf.get_value("graphics", "preset") == "max", "les réglages sont enregistrés")
	Settings.reset_defaults()


func _test_progression() -> void:
	Game.new_game()
	check(Game.team == Data.CORE_TEAM, "nouvelle partie : SG-1 à quatre")
	check(Game.stats.naq == Data.START_NAQ and Game.stats.lvl == 1, "nouvelle partie : niveau 1, naquadah de départ")
	var lv := []
	Game.leveled_up.connect(func(l): lv.append(l))
	Game.gain_xp(Data.XP_PER_LEVEL * 3)   # 40 pour le niveau 2, 80 pour le 3 : il reste 0
	check(Game.stats.lvl == 3 and Game.stats.xp == 0 and lv == [2, 3], "l'XP fait monter de plusieurs niveaux d'un coup")
	check(Game.hp_max("oneill") == Data.MEMBERS.oneill.hp + 2 * Data.HP_PER_LEVEL, "PV max selon le niveau")
	check(not Game.buy("weapon", 3, 9999), "pas d'achat sans assez de naquadah")
	Game.stats.naq = 100
	check(Game.buy("weapon", 1, 60) and Game.stats.naq == 40 and Game.gear().dmg == 1, "un achat équipe et débite")
	Game.stats.hp.carter = 3
	check(Game.most_wounded() == "carter", "on trouve le plus blessé")
	var kits: int = Game.stats.kits
	check(Game.use_kit("carter") == Data.kit_heal(3) and Game.stats.kits == kits - 1, "une trousse soigne et se consomme")
	check(Game.hurt_all(5), "l'équipe tient debout après 5 dégâts")
	check(not Game.hurt_all(9999), "tout le monde à terre")
	Game.heal_all()
	check(not Game.complete_mission(0), "Abydos libérée : pas encore Bra'tac")
	check(Game.complete_mission(1) and Game.team.has("bratac"), "Chulak libérée : Bra'tac rejoint SG-1")
	check(Game.unlocked(2) and not Game.unlocked(3), "la mission suivante se débloque")


func _test_save() -> void:
	Game.new_game()
	Game.stats.naq = 123
	Game.stats.done = 2
	Game.save_game()
	Game.stats.naq = 0
	Game.load_game()
	check(Game.stats.naq == 123 and Game.team.has("bratac"), "la sauvegarde se relit (et Bra'tac avec)")
	check(not FileAccess.file_exists(Game.save_path + ".tmp"), "pas de fichier temporaire qui traîne")
	var f := FileAccess.open(Game.save_path, FileAccess.WRITE)
	f.store_string('{"naq": -50, "lvl": 0, "done": 99, "weapon": 42, "hp": {"inconnu": 3}}')
	f.close()
	Game.load_game()
	check(Game.stats.naq == 0 and Game.stats.lvl == 1 and Game.stats.done == Data.PLANETS.size()
		and Game.stats.weapon == Data.WEAPONS.size() - 1 and not Game.stats.hp.has("inconnu"), "une sauvegarde absurde est bornée")
	f = FileAccess.open(Game.save_path, FileAccess.WRITE)
	f.store_string("pas du JSON")
	f.close()
	Game.load_game()
	check(Game.stats.lvl == 1 and Game.stats.naq == Data.START_NAQ, "une sauvegarde illisible donne une nouvelle partie")


func _test_difficulty() -> void:
	const CombatScript = preload("res://scripts/combat.gd")
	var c := CombatScript.new()
	c.tier = 2
	Settings.set_value("difficulty", "normal")
	var normal: Dictionary = c._enemy_stats("jaffa", false)
	Settings.set_value("difficulty", "easy")
	var easy: Dictionary = c._enemy_stats("jaffa", false)
	Settings.set_value("difficulty", "hard")
	var hard: Dictionary = c._enemy_stats("jaffa", false)
	check(easy.hp < normal.hp and normal.hp < hard.hp, "la difficulté change les PV ennemis")
	check(easy.dmg < normal.dmg and normal.dmg < hard.dmg, "la difficulté change les dégâts ennemis")
	Settings.set_value("difficulty", "normal")
	c.free()
