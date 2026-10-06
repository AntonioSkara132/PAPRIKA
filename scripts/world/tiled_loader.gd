class_name TiledLoader
extends Node2D

signal actor_spawn_requested(kind: String, position: Vector2, variant: String, persistent_id: String)
signal service_requested(service_id: String, display_name: String)

const FLIP_MASK := 0x0FFFFFFF

var map_size := Vector2.ZERO
var _navigation: AStarGrid2D
var _amphibious_navigation: AStarGrid2D
var _collision_footprints: Array[Rect2] = []
var _solid_footprints: Array[Rect2] = []
var tile_size := Vector2i(16, 16)
var _map_field_prefix := "paprika"
var map_loaded := false
var scenery_only := false
var _missing_texture := false
var _tilesets: Array[Dictionary] = []
var _texture_cache: Dictionary = {}
var _tile_root: Node2D
var _object_root: Node2D
var _field_root: Node2D
var _collision_body: StaticBody2D
var _water_body: StaticBody2D

func _ready() -> void:
	add_to_group("tiled_world")

func load_map(path: String) -> bool:
	clear_map()
	var data = _read_json(path)
	if not data is Dictionary:
		push_error("Could not parse Tiled map: %s" % path)
		return false
	if bool(data.get("infinite", false)) or String(data.get("orientation", "")) != "orthogonal":
		push_error("Craft supports only finite orthogonal Tiled maps.")
		return false
	_map_field_prefix = path.get_file().get_basename()
	tile_size = Vector2i(int(data.get("tilewidth", 16)), int(data.get("tileheight", 16)))
	map_size = Vector2(int(data.get("width", 0)) * tile_size.x, int(data.get("height", 0)) * tile_size.y)
	if map_size.x <= 0 or map_size.y <= 0:
		push_error("Tiled map has invalid dimensions.")
		return false
	if not _load_tilesets(data.get("tilesets", []), path.get_base_dir()):
		return false
	_build_roots()
	var layer_index := 0
	for layer_value in data.get("layers", []):
		if not layer_value is Dictionary:
			continue
		var layer: Dictionary = layer_value
		if not bool(layer.get("visible", true)) or String(layer.get("name", "")) == "Gameplay HUD":
			continue
		match String(layer.get("type", "")):
			"tilelayer":
				_create_tile_layer(layer, layer_index)
			"objectgroup":
				_create_object_layer(layer)
			"imagelayer":
				pass
			_:
				push_warning("Skipping unsupported Tiled layer type: %s" % layer.get("type", ""))
		layer_index += 1
	_add_outer_boundaries()
	_build_navigation()
	map_loaded = not _missing_texture
	return map_loaded

func clear_map() -> void:
	map_loaded = false
	_missing_texture = false
	_tilesets.clear()
	_texture_cache.clear()
	_collision_footprints.clear()
	_solid_footprints.clear()
	_navigation = null
	_amphibious_navigation = null
	while get_child_count() > 0:
		get_child(0).free()

func _build_roots() -> void:
	_tile_root = Node2D.new()
	_tile_root.name = "TiledLayers"
	add_child(_tile_root)
	_object_root = Node2D.new()
	_object_root.name = "MapObjects"
	add_child(_object_root)
	_field_root = Node2D.new()
	_field_root.name = "FieldPlots"
	add_child(_field_root)
	_collision_body = StaticBody2D.new()
	_collision_body.name = "WorldCollision"
	_collision_body.collision_layer = 1
	_collision_body.collision_mask = 0
	add_child(_collision_body)
	_water_body = StaticBody2D.new()
	_water_body.name = "WaterCollision"
	_water_body.collision_layer = 16
	_water_body.collision_mask = 0
	add_child(_water_body)

func _load_tilesets(references: Array, base_dir: String) -> bool:
	for reference_value in references:
		if not reference_value is Dictionary:
			continue
		var reference: Dictionary = reference_value
		if not reference.has("source"):
			push_error("Embedded Tiled tilesets are not supported.")
			return false
		var tsj_path := base_dir.path_join(String(reference["source"])).simplify_path()
		var definition = _read_json(tsj_path)
		if not definition is Dictionary:
			push_error("Could not parse Tiled tileset: %s" % tsj_path)
			return false
		_tilesets.append({
			"firstgid": int(reference.get("firstgid", 1)),
			"path": tsj_path,
			"definition": definition,
		})
	_tilesets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["firstgid"]) < int(b["firstgid"]))
	return not _tilesets.is_empty()

func _create_tile_layer(layer: Dictionary, layer_index: int) -> void:
	var layer_node := Node2D.new()
	layer_node.name = String(layer.get("name", "TileLayer"))
	layer_node.z_index = layer_index
	_tile_root.add_child(layer_node)
	var width := int(layer.get("width", 0))
	var layer_name := String(layer.get("name", ""))
	var data: Array = layer.get("data", [])
	if width <= 0 or data.is_empty():
		return
	for index in data.size():
		var raw_gid := int(data[index])
		if raw_gid == 0:
			continue
		var gid := raw_gid & FLIP_MASK
		if raw_gid != gid:
			push_warning("Flipped Tiled cells are not supported yet; rendering unflipped.")
		var texture := _texture_for_gid(gid)
		if texture == null:
			continue
		var cell := Vector2i(index % width, index / width)
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.position = Vector2(cell.x * tile_size.x, cell.y * tile_size.y)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer_node.add_child(sprite)
		var local_id := _local_tile_id(gid)
		if not scenery_only and layer_name in ["Common Fields", "Private Fields"] and GameData.CROP_BY_TILE_ID.has(local_id):
			_create_field_plot(cell, local_id, sprite, texture, layer_name == "Common Fields")
		if layer_name == "Water":
			_add_collision_rect(Vector2(tile_size), sprite.position + Vector2(tile_size) * 0.5, true)
		elif layer_name in ["Station Walls", "Station Void", "Barracks Walls", "Artichoke Cliffs"] or (_map_field_prefix in ["paprika", "brudet"] and local_id in [5, 6]) or layer_name == "Field Boundaries and Forest Details" and gid in [14, 15]:
			_add_collision_rect(Vector2(tile_size), sprite.position + Vector2(tile_size) * 0.5)

func _create_field_plot(cell: Vector2i, local_id: int, sprite: Sprite2D, ready_texture: Texture2D, common: bool) -> void:
	var crop_id := String(GameData.CROP_BY_TILE_ID[local_id])
	var field := FieldPlot.new()
	field.name = "Field_%d_%d" % [cell.x, cell.y]
	field.position = Vector2(cell.x * tile_size.x + tile_size.x * 0.5, cell.y * tile_size.y + tile_size.y * 0.5)
	_field_root.add_child(field)
	field.configure("%s:%d:%d" % [_map_field_prefix, cell.x, cell.y], crop_id, common, sprite, ready_texture, _texture_for_gid(_gid_for_local_tile(4)))

func _create_object_layer(layer: Dictionary) -> void:
	for object_value in layer.get("objects", []):
		if not object_value is Dictionary:
			continue
		var object: Dictionary = object_value
		if not object.has("gid"):
			continue
		var name := String(object.get("name", "object"))
		var gid := int(object.get("gid", 0)) & FLIP_MASK
		var texture := _texture_for_gid(gid)
		if texture == null:
			continue
		var size := Vector2(float(object.get("width", texture.get_width())), float(object.get("height", texture.get_height())))
		var top_left := Vector2(float(object.get("x", 0)), float(object.get("y", 0)) - size.y)
		var feet := Vector2(top_left.x + size.x * 0.5, top_left.y + size.y - 2.0)
		var texture_path := _texture_path_for_gid(gid)
		if name == "player":
			actor_spawn_requested.emit("player", feet, texture_path, "player")
			continue
		if name.begins_with("villager"):
			actor_spawn_requested.emit("villager", feet, texture_path, name + "_%d" % int(object.get("id", 0)))
			continue
		if name == "rabbit":
			actor_spawn_requested.emit("rabbit", feet, texture_path, "rabbit_%d" % int(object.get("id", 0)))
			continue
		if name in ["station_recruit", "station_instructor", "station_cook", "station_soldier", "front_soldier", "republic_soldier", "republic_battery_soldier", "confederation_officer", "confederation_cook"]:
			actor_spawn_requested.emit(name, feet, texture_path, "%s_%d" % [name, int(object.get("id", 0))])
			continue
		if name in ["wolf", "zombie", "armed_zombie", "armored_zombie", "zombie_bear", "bandit", "bandit_spear", "bandit_bow", "bandit_sword", "hacker", "finling", "lake_maw", "river_serpent"]:
			actor_spawn_requested.emit("enemy", feet, texture_path, "%s_%d" % [name, int(object.get("id", 0))])
			continue
		var service := _service_for_object(name)
		if not service.is_empty():
			var service_node := WorldService.new()
			service_node.name = name
			service_node.set_meta("object_name", name)
			service_node.position = top_left
			service_node.z_index = 10 + int(object.get("y", 0))
			_object_root.add_child(service_node)
			service_node.configure(texture, size, String(service["id"]), String(service["name"]), float(service.get("door_ratio", 0.5)))
			if name.begins_with("station_") and name not in ["station_depot", "station_barracks", "station_canteen"] or name in ["player_bed", "player_chest", "recruit_bed", "recruit_chest", "barracks_exit", "artichoke_ship"]:
				for child in service_node.get_children():
					if child is CollisionShape2D:
						child.free()
				if name in ["station_ship", "artichoke_ship"]:
					_add_collision_rect(Vector2(size.x * 0.70, 8), top_left + Vector2(size.x * 0.5, size.y - 9))
				else:
					service_node.collision_layer = 0
			else:
				_record_service_collisions(service_node)
			if scenery_only:
				service_node.remove_from_group("interactable")
			else:
				service_node.service_requested.connect(_on_service_requested)
		else:
			_create_static_object(name, texture, top_left, size, int(object.get("y", 0)))

func _create_static_object(name: String, texture: Texture2D, top_left: Vector2, size: Vector2, bottom_y: int) -> void:
	var holder := Node2D.new()
	holder.name = name
	holder.set_meta("object_name", name)
	holder.position = top_left
	holder.z_index = 10 + bottom_y
	_object_root.add_child(holder)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = size / Vector2(texture.get_width(), texture.get_height())
	holder.add_child(sprite)
	# Barbed wire slows walkers and minefield marks are stepped on, so neither blocks movement.
	if name in ["stone_bridge", "arrow_target", "training_ground", "barbed_wire", "trap_marker"] or name.begins_with("landing_pad") or name.begins_with("station_range_target") or name.begins_with("station_trap_dummy"):
		return
	if name == "spaceship":
		_add_collision_rect(Vector2(size.x * 0.70, 8), top_left + Vector2(size.x * 0.5, size.y - 9))
	elif name == "republic_wall":
		# Wall pieces sit one per tile; full-width footprints leave no gaps between them.
		_add_collision_rect(Vector2(tile_size.x, 12), top_left + Vector2(size.x * 0.5, size.y - 6))
	elif name.begins_with("tree"):
		_add_collision_rect(Vector2(9, 7), top_left + Vector2(size.x * 0.52, size.y - 5))
	elif name == "fountain":
		_add_collision_rect(Vector2(size.x * 0.72, 10), top_left + Vector2(size.x * 0.5, size.y - 9))
	elif not name.ends_with("_sign"):
		_add_collision_rect(Vector2(size.x * 0.72, maxf(7.0, size.y * 0.16)), top_left + Vector2(size.x * 0.5, size.y - maxf(6.0, size.y * 0.10)))

func _record_service_collisions(service_node: WorldService) -> void:
	for child in service_node.get_children():
		if child is CollisionShape2D:
			var collision := child as CollisionShape2D
			if collision.shape is RectangleShape2D:
				var size := (collision.shape as RectangleShape2D).size
				var footprint := Rect2(service_node.position + collision.position - size * 0.5, size)
				_collision_footprints.append(footprint)
				_solid_footprints.append(footprint)

func _service_for_object(name: String) -> Dictionary:
	match name:
		"food_shop": return {"id": "food", "name": "Paprika Food Shop"}
		"north_food_shop": return {"id": "north_food", "name": "Northern Food Shop"}
		"forge": return {"id": "forge", "name": "Forge & Armor"}
		"north_forge": return {"id": "north_forge", "name": "Northern Forge"}
		"mercenary": return {"id": "mercenary", "name": "Mercenary Center"}
		"north_mercenary": return {"id": "north_mercenary", "name": "Northern Mercenary Center"}
		"river_forge": return {"id": "river_forge", "name": "Brudet Forge"}
		"work_office": return {"id": "work_office", "name": "Village Work Office"}
		"clothing_shop": return {"id": "clothing", "name": "Clothing & Armor"}
		"north_clothing_shop": return {"id": "north_clothing", "name": "Northern Clothier"}
		"travel": return {"id": "travel", "name": "Brudet Travel Agency" if _map_field_prefix == "brudet" else "Paprika Travel Agency"}
		"river_market": return {"id": "river_market", "name": "Brudet Market"}
		"river_library": return {"id": "river_library", "name": "Brudet Library"}
		"military_hq": return {"id": "military_hq", "name": "Military Headquarters"}
		"river_town_hall": return {"id": "river_town_hall", "name": "Brudet Town Hall"}
		"fishing_pond": return {"id": "fishing_pond", "name": "Fishing Pond"}
		"station_ship": return {"id": "station_ship", "name": "Military Transport"}
		"artichoke_ship": return {"id": "artichoke_ship", "name": "Military Transport"}
		"confederation_arms": return {"id": "artichoke_arms", "name": "Arms"}
		"confederation_mess": return {"id": "artichoke_mess", "name": "Mess", "door_ratio": 0.32}
		"station_depot": return {"id": "station_depot", "name": "Military Depot"}
		"station_barracks": return {"id": "station_barracks", "name": "Military Barracks", "door_ratio": 0.27}
		"station_canteen": return {"id": "station_canteen", "name": "Station Canteen", "door_ratio": 0.32}
		"station_track": return {"id": "station_track", "name": "Running Field"}
		"station_spar": return {"id": "station_spar", "name": "Sparring Ring"}
		"station_squad_spar": return {"id": "station_squad_spar", "name": "Squad Sparring Ring"}
		"station_range": return {"id": "station_range", "name": "Moving-Target Range"}
		"station_cannon_start": return {"id": "station_cannon_start", "name": "Cannon Range Flag"}
		"station_tnt_pile": return {"id": "station_tnt_pile", "name": "Practice TNT Pile"}
		"station_cannon": return {"id": "station_cannon", "name": "Training Cannon"}
		"station_trap_pad": return {"id": "station_trap_pad", "name": "Trap Practice Pad"}
		"player_bed": return {"id": "player_bed", "name": "Your Bunk"}
		"player_chest": return {"id": "player_chest", "name": "Your Footlocker"}
		"recruit_bed": return {"id": "recruit_bed", "name": "Occupied Bunk"}
		"recruit_chest": return {"id": "recruit_chest", "name": "Occupied Footlocker"}
		"barracks_exit": return {"id": "barracks_exit", "name": "Barracks Exit"}
		_: return {}

func _add_outer_boundaries() -> void:
	var thickness := 16.0
	_add_collision_rect(Vector2(map_size.x + thickness * 2.0, thickness), Vector2(map_size.x * 0.5, -thickness * 0.5))
	_add_collision_rect(Vector2(map_size.x + thickness * 2.0, thickness), Vector2(map_size.x * 0.5, map_size.y + thickness * 0.5))
	_add_collision_rect(Vector2(thickness, map_size.y), Vector2(-thickness * 0.5, map_size.y * 0.5))
	_add_collision_rect(Vector2(thickness, map_size.y), Vector2(map_size.x + thickness * 0.5, map_size.y * 0.5))

func _add_collision_rect(size: Vector2, center: Vector2, water: bool = false) -> void:
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.position = center
	(_water_body if water else _collision_body).add_child(collision)
	var footprint := Rect2(center - size * 0.5, size)
	_collision_footprints.append(footprint)
	if not water:
		_solid_footprints.append(footprint)

func _build_navigation() -> void:
	_navigation = _new_navigation_grid()
	_amphibious_navigation = _new_navigation_grid()
	_mark_solid_cells(_navigation, _collision_footprints)
	_mark_solid_cells(_amphibious_navigation, _solid_footprints)

func _new_navigation_grid() -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, int(map_size.x / tile_size.x), int(map_size.y / tile_size.y))
	grid.cell_size = Vector2(tile_size)
	grid.offset = Vector2(tile_size) * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	return grid

func _mark_solid_cells(grid: AStarGrid2D, footprints: Array[Rect2]) -> void:
	for footprint in footprints:
		if footprint.end.x <= 0.0 or footprint.end.y <= 0.0 or footprint.position.x >= map_size.x or footprint.position.y >= map_size.y:
			continue
		var first_x := clampi(floori(footprint.position.x / tile_size.x), 0, grid.region.size.x - 1)
		var first_y := clampi(floori(footprint.position.y / tile_size.y), 0, grid.region.size.y - 1)
		var last_x := clampi(ceili(footprint.end.x / tile_size.x) - 1, 0, grid.region.size.x - 1)
		var last_y := clampi(ceili(footprint.end.y / tile_size.y) - 1, 0, grid.region.size.y - 1)
		for y in range(first_y, last_y + 1):
			for x in range(first_x, last_x + 1):
				grid.set_point_solid(Vector2i(x, y))

## Static map objects named `object_name`, as their sprite holders, in map order.
## A holder's position is the object's top-left corner.
func map_objects(object_name: String) -> Array[Node2D]:
	var found: Array[Node2D] = []
	if not is_instance_valid(_object_root):
		return found
	for child in _object_root.get_children():
		if child is Node2D and String(child.get_meta("object_name", "")) == object_name:
			found.append(child)
	return found

## Size in pixels of a static object holder created by this loader.
static func map_object_size(holder: Node2D) -> Vector2:
	for child in holder.get_children():
		if child is Sprite2D and (child as Sprite2D).texture != null:
			var sprite := child as Sprite2D
			return Vector2(sprite.texture.get_width(), sprite.texture.get_height()) * sprite.scale
	return Vector2.ZERO

## Makes routes through the tile at world_position cost `weight` times a normal step,
## so walkers go around it when a reasonable detour exists. 1.0 restores the tile.
func set_walk_cost(world_position: Vector2, weight: float) -> void:
	if _navigation == null:
		return
	var local := to_local(world_position)
	var cell := Vector2i(floori(local.x / tile_size.x), floori(local.y / tile_size.y))
	if _navigation.is_in_boundsv(cell):
		_navigation.set_point_weight_scale(cell, maxf(1.0, weight))

func is_walkable_position(world_position: Vector2) -> bool:
	return _walkable_on_grid(_navigation, world_position)

func is_amphibious_walkable_position(world_position: Vector2) -> bool:
	return _walkable_on_grid(_amphibious_navigation, world_position)

func _walkable_on_grid(grid: AStarGrid2D, world_position: Vector2) -> bool:
	if grid == null:
		return false
	var local := to_local(world_position)
	var cell := Vector2i(floori(local.x / tile_size.x), floori(local.y / tile_size.y))
	return grid.is_in_boundsv(cell) and not grid.is_point_solid(cell)

func get_walk_path(start: Vector2, destination: Vector2) -> PackedVector2Array:
	return _path_on_grid(_navigation, start, destination)

func get_walk_path_avoiding(start: Vector2, destination: Vector2, occupied: PackedVector2Array, clearance: float = 14.0) -> PackedVector2Array:
	if not start.is_finite() or not destination.is_finite() or not is_finite(clearance) or clearance < 0.0:
		return PackedVector2Array()
	for point in occupied:
		if not point.is_finite() or destination.distance_to(point) < clearance:
			return PackedVector2Array()
	if _navigation == null or occupied.is_empty():
		return get_walk_path(start, destination)
	var changed: Array[Vector2i] = []
	for point in occupied:
		var local := to_local(point)
		var first_x := maxi(_navigation.region.position.x, floori((local.x - clearance) / tile_size.x))
		var first_y := maxi(_navigation.region.position.y, floori((local.y - clearance) / tile_size.y))
		var last_x := mini(_navigation.region.end.x - 1, floori((local.x + clearance) / tile_size.x))
		var last_y := mini(_navigation.region.end.y - 1, floori((local.y + clearance) / tile_size.y))
		# An actor on a cell corner is half a tile diagonal from all four centers, so a
		# small clearance blocks none of them and a diagonal step would cross the actor.
		# Blocking the cell that contains it also forbids those diagonal steps.
		var actor_cell := Vector2i(floori(local.x / tile_size.x), floori(local.y / tile_size.y))
		for y in range(first_y, last_y + 1):
			for x in range(first_x, last_x + 1):
				var cell := Vector2i(x, y)
				if _navigation.is_point_solid(cell):
					continue
				if (clearance > 0.0 and cell == actor_cell) or to_global(_navigation.get_point_position(cell)).distance_to(point) < clearance:
					_navigation.set_point_solid(cell, true)
					changed.append(cell)
	var local_start := to_local(start)
	var start_cell := Vector2i(floori(local_start.x / tile_size.x), floori(local_start.y / tile_size.y))
	var actor_blocks_start := changed.has(start_cell)
	if actor_blocks_start:
		# The soldier can leave its current cell even when an actor makes its center unsafe.
		_navigation.set_point_solid(start_cell, false)
	var path := _path_on_grid(_navigation, start, destination)
	if actor_blocks_start and path.size() > 1 and path[0].distance_to(to_global(_navigation.get_point_position(start_cell))) < 0.1:
		# Do not send it back to that unsafe center before following the route out.
		path.remove_at(0)
	# Occupied positions apply only to this route; terrain navigation stays unchanged.
	for cell in changed:
		_navigation.set_point_solid(cell, false)
	return path

func get_amphibious_path(start: Vector2, destination: Vector2) -> PackedVector2Array:
	return _path_on_grid(_amphibious_navigation, start, destination)

func _path_on_grid(grid: AStarGrid2D, start: Vector2, destination: Vector2) -> PackedVector2Array:
	var path := PackedVector2Array()
	if grid == null:
		return path
	var local_start := to_local(start)
	var local_destination := to_local(destination)
	var from_cell := Vector2i(floori(local_start.x / tile_size.x), floori(local_start.y / tile_size.y))
	var destination_cell := Vector2i(floori(local_destination.x / tile_size.x), floori(local_destination.y / tile_size.y))
	if not grid.is_in_boundsv(from_cell) or not grid.is_in_boundsv(destination_cell):
		return path
	var from_open := _nearest_open_cell(grid, from_cell)
	var destination_open := _nearest_open_cell(grid, destination_cell)
	if from_open.x < 0 or destination_open.x < 0:
		return path
	var cells := grid.get_id_path(from_open, destination_open)
	if cells.is_empty():
		return path
	if from_open == destination_open and from_cell == destination_cell:
		path.append(destination)
		return path
	for cell in cells:
		path.append(to_global(grid.get_point_position(cell)))
	if destination_open == destination_cell:
		path.append(destination)
	return path

func get_common_field_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if not is_instance_valid(_field_root):
		return positions
	for child in _field_root.get_children():
		if child is FieldPlot and child.is_common:
			positions.append(child.global_position)
	return positions

func _nearest_open_cell(grid: AStarGrid2D, cell: Vector2i) -> Vector2i:
	if not grid.is_point_solid(cell):
		return cell
	for radius in range(1, 7):
		var closest := Vector2i(-1, -1)
		var closest_distance := 1 << 30
		for y in range(cell.y - radius, cell.y + radius + 1):
			for x in range(cell.x - radius, cell.x + radius + 1):
				if maxi(absi(x - cell.x), absi(y - cell.y)) != radius:
					continue
				var candidate := Vector2i(x, y)
				if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate):
					var distance := (candidate - cell).length_squared()
					if distance < closest_distance:
						closest = candidate
						closest_distance = distance
		if closest.x >= 0:
			return closest
	return Vector2i(-1, -1)

func _texture_for_gid(gid: int) -> Texture2D:
	if _texture_cache.has(gid):
		return _texture_cache[gid]
	var selected := _tileset_for_gid(gid)
	if selected.is_empty():
		return null
	var firstgid := int(selected["firstgid"])
	var definition: Dictionary = selected["definition"]
	var folder := String(selected["path"]).get_base_dir()
	var local_id := gid - firstgid
	var texture: Texture2D
	if definition.has("image"):
		var sheet_path := folder.path_join(String(definition["image"])).simplify_path()
		var sheet := load(sheet_path) as Texture2D
		if sheet == null:
			push_error("Could not load Tiled texture: %s" % sheet_path)
			_missing_texture = true
			_texture_cache[gid] = null
			return null
		var columns := int(definition.get("columns", 1))
		var tw := int(definition.get("tilewidth", tile_size.x))
		var th := int(definition.get("tileheight", tile_size.y))
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2((local_id % columns) * tw, (local_id / columns) * th, tw, th)
		texture = atlas
	else:
		var image_path := _collection_image_path(definition, local_id, folder)
		texture = load(image_path) as Texture2D
		if texture == null:
			push_error("Could not load Tiled texture: %s" % image_path)
			_missing_texture = true
	_texture_cache[gid] = texture
	return texture

func _texture_path_for_gid(gid: int) -> String:
	var selected := _tileset_for_gid(gid)
	if selected.is_empty():
		return ""
	var definition: Dictionary = selected["definition"]
	var folder := String(selected["path"]).get_base_dir()
	return _collection_image_path(definition, gid - int(selected["firstgid"]), folder)

func _collection_image_path(definition: Dictionary, local_id: int, folder: String) -> String:
	for tile_value in definition.get("tiles", []):
		if tile_value is Dictionary and int(tile_value.get("id", -1)) == local_id:
			return folder.path_join(String(tile_value.get("image", ""))).simplify_path()
	return ""

func _tileset_for_gid(gid: int) -> Dictionary:
	var selected: Dictionary = {}
	for entry in _tilesets:
		if gid >= int(entry["firstgid"]):
			selected = entry
		else:
			break
	return selected

func _local_tile_id(gid: int) -> int:
	var selected := _tileset_for_gid(gid)
	return gid - int(selected.get("firstgid", gid))

func _gid_for_local_tile(local_id: int) -> int:
	for entry in _tilesets:
		var definition: Dictionary = entry["definition"]
		if definition.has("image"):
			return int(entry["firstgid"]) + local_id
	return local_id + 1

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Missing Tiled file: %s" % path)
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _on_service_requested(service_id: String, display_name: String) -> void:
	service_requested.emit(service_id, display_name)
