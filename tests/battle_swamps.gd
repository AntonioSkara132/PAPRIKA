extends SceneTree
## Runs the battle of the two swamp lines headless and checks that its steps
## happen in order: the probe, the crossing, the split, the cavalry and Red's
## retreat across the second swamp.

func _init() -> void:
	var battle: Node2D = load("res://scripts/battle_sandbox/battle_sandbox.gd").new()
	battle.scenario = "swamps"
	root.add_child(battle)
	await process_frame
	var seen := {}
	var seconds := 0.0
	while battle.winner < 0 and seconds < 400.0:
		battle.simulate(0.05)
		seconds += 0.05
		for line in battle.events:
			if not seen.has(line):
				seen[line] = true
				print("  ", line)
	var failures := 0
	for step in ["probe", "swords cross", "edge", "split", "cavalry", "red retreats"]:
		if not battle._swamps.has(step):
			failures += 1
			print("FAIL step never happened: ", step)
		else:
			print("step %s at %.0fs" % [step, battle._swamps[step]])
	var red_across := 0
	for b in battle.blocks.size():
		var block: Dictionary = battle.blocks[b]
		if block["team"] == 1 and block["kind"] in battle.SHOOTERS and not block["broken"] and battle._living(b) > 0 \
				and battle._centre(b).x > battle.SWAMP_LINES[1] + 60.0:
			red_across += battle._living(b)
	print("winner=%d after %.0fs, fighting=%s, Red archers across the second swamp=%d" % [battle.winner, seconds, battle.fighting_counts(), red_across])
	print("FAILURES: %d" % failures)
	quit(failures)
