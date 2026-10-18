extends SceneTree
## Runs the battle sandbox headless until one side holds the field.

func _init() -> void:
	var battle: Node2D = load("res://scripts/battle_sandbox/battle_sandbox.gd").new()
	root.add_child(battle)
	await process_frame
	var failures := 0
	var counts: Array = battle.fighting_counts()
	if counts != [100, 100]:
		failures += 1
		print("FAIL start counts ", counts)
	var seconds := 0.0
	while battle.winner < 0 and seconds < 600.0:
		battle.simulate(0.05)
		seconds += 0.05
	var broken := 0
	for b in battle.blocks:
		broken += int(b["broken"])
	print("winner=%d after %.0fs, fighting=%s, broken blocks=%d, corpses=%d" % [battle.winner, seconds, battle.fighting_counts(), broken, battle.corpses.size()])
	if battle.winner < 0:
		failures += 1
		print("FAIL no winner after 600 s")
	print("FAILURES: %d" % failures)
	quit(failures)
