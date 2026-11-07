extends Node

## Starts the real game on Smokva at the end of its chapter: the Parrots' ship is
## beaten, Donat has joined and waits by the Lasta, Davor has been taken, and the
## player is a Brine with an iron sword and iron armor. Talk to Veki to fly to
## Bavarin. The game is saved there, so F9 comes back to this point. Run it with
## its own XDG_DATA_HOME so the player's real save is not touched.

func _ready() -> void:
	call_deferred("_start")

func _start() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	GameState.military_stage = "graduated"
	GameState.military_cannon_hits.assign(GameState.MILITARY_CANNON_TARGETS.duplicate())
	GameState.military_trap_progress = GameState.MILITARY_TRAP_STEPS.size()
	var flags: Array = [GameState.POMIDOR_UNLOCK_FLAG, PomidorWorld.EMBASSY_FLAG, GameState.PASSAGE_FLAG]
	flags.append_array(SkoljkaWorld.FLAGS)
	flags.append_array([GameState.OTPORNIK_UNLOCK_FLAG, GameState.ROCK_UNLOCK_FLAG, "otpornik_arrival", GameState.DAVOR_TAKEN_FLAG,
			GameState.SMOKVA_UNLOCK_FLAG, "smokva_asked_ship", "smokva_fivecap_met", "smokva_switched_once",
			"smokva_parrots_beaten", "smokva_donat_joined", GameState.BAVARIN_UNLOCK_FLAG])
	for flag in flags:
		if not GameState.defeated_persistent_enemies.has(flag):
			GameState.defeated_persistent_enemies.append(flag)
	GameState.max_health = GameState.GRADUATED_MAX_HEALTH
	GameState.become_brine()
	GameState.gold = 200
	for item in ["iron_sword", "iron_armor"]:
		GameState.add_item(item)
		GameState.equip_item(item)
	GameState.add_item("bread", 4)
	GameState.restore_health()
	GameState.current_planet = "smokva"
	GameState.current_area = "exterior"
	game._switch_world("smokva")
	await get_tree().process_frame
	var world := game.world as SmokvaWorld
	if world != null:
		world.player.global_position = world.marker("veki_post") + Vector2(-24, 12)
		world.capture_player_position()
	GameState.remember_player_position(GameState.player_position)
	GameState.save_game()
	GameState.notify("Smokva, after the battle with the Parrots. Talk to Veki to fly to Bavarin. Saved here.")
