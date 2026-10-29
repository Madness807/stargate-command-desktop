extends Node

var checks := 0
var fails := 0


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		printerr("ÉCHEC AUDIO : ", text)


func _ready() -> void:
	await get_tree().process_frame
	var saved_background: bool = Audio._background
	var saved_mute: bool = Audio._mute_background
	var saved_silent: bool = Audio._master_silent
	var master := AudioServer.get_bus_index("Master")
	var saved_db := AudioServer.get_bus_volume_db(master)
	check(Audio._streams.size() == Audio.SOUNDS.size(), "tous les sons sont chargés")
	for name in Audio.SOUNDS:
		var stream: AudioStreamWAV = Audio._streams[name]
		check(stream.get_length() > 0 and not stream.data.is_empty(), "fichier valide : " + name)
	check(ProjectSettings.get_setting("audio/driver/output_latency") >= 40, "tampon de sortie adapté à Android")
	Audio.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	Audio.set_background_mute(true)
	Audio.set_volume("Master", 0.55)
	check(not AudioServer.is_bus_mute(master), "son actif au premier plan")
	Audio.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(AudioServer.is_bus_mute(master), "silence en arrière-plan")
	Audio.set_volume("Master", 0.55)
	check(AudioServer.is_bus_mute(master), "changer le volume ne réactive pas une fenêtre en arrière-plan")
	Audio.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not AudioServer.is_bus_mute(master), "retour du son au premier plan")
	check(is_equal_approx(AudioServer.get_bus_volume_db(master), linear_to_db(0.55)), "volume conservé")
	Audio.set_volume("Master", 0)
	Audio.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	Audio.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	check(AudioServer.is_bus_mute(master), "volume zéro reste silencieux au retour")
	Audio.set_volume("Master", 0.55)
	Audio.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	Audio.set_background_mute(false)
	check(not AudioServer.is_bus_mute(master), "son en arrière-plan configurable")
	Audio.set_volume("Master", 0)
	Audio.set_background_mute(false)
	check(AudioServer.is_bus_mute(master), "option arrière-plan respecte le volume zéro")
	Audio.loop_play("horizon", -16)
	check(Audio._loops.has("horizon"), "création d'une boucle")
	var previous: AudioStreamPlayer = Audio._loops["horizon"]
	Audio.loop_play("horizon", -16)
	check(Audio._loops.size() == 1, "relancer une boucle ne la duplique pas")
	check(not previous.playing and previous.is_queued_for_deletion(), "ancienne boucle arrêtée avant sa suppression")
	var current: AudioStreamPlayer = Audio._loops["horizon"]
	Audio.loop_stop("horizon", 0)
	check(Audio._loops.is_empty(), "arrêt de la boucle")
	check(not current.playing and current.is_queued_for_deletion(), "arrêt immédiat libère la lecture audio")
	Audio.loop_play("horizon", -16)
	var fading: AudioStreamPlayer = Audio._loops["horizon"]
	Audio.loop_stop("horizon", 0.01)
	check(fading.playing and Audio._loops.is_empty(), "fondu conserve la lecture jusqu'à son terme")
	await get_tree().create_timer(0.05).timeout
	await get_tree().process_frame
	check(not is_instance_valid(fading), "fondu terminé supprime le lecteur")
	var isolated_audio = load("res://scripts/audio.gd").new()
	add_child(isolated_audio)
	isolated_audio.play("press")
	isolated_audio.loop_play("horizon")
	remove_child(isolated_audio)
	for player in isolated_audio.get_children():
		check(not player.playing, "sortie de scène arrête chaque lecture")
	check(isolated_audio._loops.is_empty(), "sortie de scène vide les boucles")
	isolated_audio.free()
	Audio._background = saved_background
	Audio._mute_background = saved_mute
	Audio._master_silent = saved_silent
	AudioServer.set_bus_volume_db(master, saved_db)
	Audio._update_master_mute()
	await get_tree().process_frame
	print("Audio : %d/%d vérifications réussies" % [checks - fails, checks])
	get_tree().quit(1 if fails else 0)
