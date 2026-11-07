extends Node

## Starts the real game at Chvarak with the embassy waiting by the diplomatic
## ship, and saves there, so being downed reloads on the pad. Run it with its
## own XDG_DATA_HOME so the player's real save is not touched.

func _ready() -> void:
	call_deferred("_start")

func _start() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	GameState.military_stage = "graduated"
	GameState.military_cannon_hits.assign(GameState.MILITARY_CANNON_TARGETS.duplicate())
	GameState.military_trap_progress = GameState.MILITARY_TRAP_STEPS.size()
	for flag in [GameState.POMIDOR_UNLOCK_FLAG, PomidorWorld.EMBASSY_FLAG]:
		if not GameState.defeated_persistent_enemies.has(flag):
			GameState.defeated_persistent_enemies.append(flag)
	GameState.current_planet = "chvarak"
	GameState.current_area = "exterior"
	GameState.player_position = GameState.CHVARAK_ARRIVAL
	game._switch_world("chvarak")
	await get_tree().process_frame
	if game.world != null and game.world.has_method("capture_player_position"):
		game.world.capture_player_position()
	GameState.remember_player_position(GameState.player_position)
	GameState.save_game()
	GameState.notify("Chvarak: the diplomatic ship waits on the east pad. Saved here.")
