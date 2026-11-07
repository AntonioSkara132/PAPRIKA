extends Node

## Plays a ship battle on its own, for trying it out:
## godot --path . tests/ship_battle_play.tscn for the Purple Parrots, or
## add `-- scrap_ship` for the scrap thieves, or `-- hacker_ship` for the
## hackers who attack the Chvarak diplomatic ship. A new battle starts when one
## ends.

var layer: CanvasLayer
var enemy_id := "parrot_ship"

func _ready() -> void:
	var main: Node2D = load("res://scripts/main.gd").new()
	main._ensure_input_actions()
	main.free()
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty() and not GameData.ship(arguments[0]).is_empty():
		enemy_id = arguments[0]
	layer = CanvasLayer.new()
	add_child(layer)
	_new_battle()

func _new_battle() -> void:
	var battle := ShipBattle.new()
	battle.enemy_id = enemy_id
	match enemy_id:
		"scrap_ship":
			battle.lines = OtpornikWorld.SCRAP_BATTLE_LINES
			battle.crew = ["You", "Veki", "Davor"]
		"hacker_ship":
			battle.player_id = "diplomatic_ship"
			battle.lines = ChvarakWorld.HACKER_BATTLE_LINES
			battle.crew = ChvarakWorld.BATTLE_CREW
		_:
			battle.lines = SmokvaWorld.PARROT_BATTLE_LINES
			battle.crew = ["You", "Veki", "Donat"]
	battle.finished.connect(func(result: String) -> void:
		print("Ship battle: ", result)
		_new_battle.call_deferred())
	layer.add_child(battle)
