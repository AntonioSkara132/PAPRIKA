class_name TiledLoader
extends Node2D

signal actor_spawn_requested(kind: String, position: Vector2, variant: String, persistent_id: String)
signal service_requested(service_id: String, display_name: String)

const FLIP_MASK := 0x0FFFFFFF

var map_size := Vector2.ZERO
var _navigation: AStarGrid2D
var _collision_footprints: Array[Rect2] = []
var tile_size := Vector2i(16, 16)
var _map_field_prefix := "paprika"
var map_loaded := false
var _missing_texture := false
var _tilesets: Array[Dictionary] = []
var _texture_cache: Dictionary = {}
var _tile_root: Node2D
var _object_root: Node2D
var _field_root: Node2D
var _collision_body: StaticBody2D

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
	_navigation = null
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
		if layer_name in ["Common Fields", "Private Fields"] and GameData.CROP_BY_TILE_ID.has(local_id):
			_create_field_plot(cell, local_id, sprite, texture, layer_name == "Common Fields")
		if (layer_name == "Water" or local_id in [5, 6]
				or layer_name == "Field Boundaries and Forest Details" and gid in [14, 15]):
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
		if name in ["wolf", "zombie", "zombie_bear", "bandit", "hacker", "finling", "lake_maw", "river_serpent"]:
			actor_spawn_requested.emit("enemy", feet, texture_path, "%s_%d" % [name, int(object.get("id", 0))])
			continue
		var service := _service_for_object(name)
		if not service.is_empty():
			var service_node := WorldService.new()
			service_node.name = name
			service_node.position = top_left
			service_node.z_index = 10 + int(object.get("y", 0))
			_object_root.add_child(service_node)
			service_node.configure(texture, size, String(service["id"]), String(service["name"]))
			_record_service_collisions(service_node)
			service_node.service_requested.connect(_on_service_requested)
		else:
			_create_static_object(name, texture, top_left, size, int(object.get("y", 0)))

func _create_static_object(name: String, texture: Texture2D, top_left: Vector2, size: Vector2, bottom_y: int) -> void:
	var holder := Node2D.new()
	holder.name = name
	holder.position = top_left
	holder.z_index = 10 + bottom_y
	_object_root.add_child(holder)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.add_child(sprite)
	if name in ["stone_bridge", "arrow_target"]:
		return
	if name == "spaceship":
		_add_collision_rect(Vector2(size.x * 0.70, 8), top_left + Vector2(size.x * 0.5, size.y - 9))
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
				_collision_footprints.append(Rect2(service_node.position + collision.position - size * 0.5, size))

func _service_for_object(name: String) -> Dictionary:
	match name:
		"food_shop": return {"id": "food", "name": "Paprika Food Shop"}
		"north_food_shop": return {"id": "north_food", "name": "Northern Food Shop"}
		"forge": return {"id": "forge", "name": "Forge & Armor"}
		"north_forge": return {"id": "north_forge", "name": "Northern Forge"}
		"mercenary": return {"id": "mercenary", "name": "Mercenary Center"}
		"work_office": return {"id": "work_office", "name": "Village Work Office"}
		"clothing_shop": return {"id": "clothing", "name": "Clothing & Armor"}
		"north_clothing_shop": return {"id": "north_clothing", "name": "Northern Clothier"}
		"travel": return {"id": "travel", "name": "Brudet Travel Agency" if _map_field_prefix == "brudet" else "Paprika Travel Agency"}
		"river_market": return {"id": "river_market", "name": "Brudet Market"}
		"river_library": return {"id": "river_library", "name": "Brudet Library"}
		"military_hq": return {"id": "military_hq", "name": "Military Headquarters"}
		"river_town_hall": return {"id": "river_town_hall", "name": "Brudet Town Hall"}
		"fishing_pond": return {"id": "fishing_pond", "name": "Fishing Pond"}
		_: return {}

func _add_outer_boundaries() -> void:
	var thickness := 16.0
	_add_collision_rect(Vector2(map_size.x + thickness * 2.0, thickness), Vector2(map_size.x * 0.5, -thickness * 0.5))
	_add_collision_rect(Vector2(map_size.x + thickness * 2.0, thickness), Vector2(map_size.x * 0.5, map_size.y + thickness * 0.5))
	_add_collision_rect(Vector2(thickness, map_size.y), Vector2(-thickness * 0.5, map_size.y * 0.5))
	_add_collision_rect(Vector2(thickness, map_size.y), Vector2(map_size.x + thickness * 0.5, map_size.y * 0.5))

func _add_collision_rect(size: Vector2, center: Vector2) -> void:
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.position = center
	_collision_body.add_child(collision)
	_collision_footprints.append(Rect2(center - size * 0.5, size))

func _build_navigation() -> void:
	_navigation = AStarGrid2D.new()
	_navigation.region = Rect2i(0, 0, int(map_size.x / tile_size.x), int(map_size.y / tile_size.y))
	_navigation.cell_size = Vector2(tile_size)
	_navigation.offset = Vector2(tile_size) * 0.5
	_navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_navigation.update()
	for footprint in _collision_footprints:
		if footprint.end.x <= 0.0 or footprint.end.y <= 0.0 or footprint.position.x >= map_size.x or footprint.position.y >= map_size.y:
			continue
		var first_x := clampi(floori(footprint.position.x / tile_size.x), 0, _navigation.region.size.x - 1)
		var first_y := clampi(floori(footprint.position.y / tile_size.y), 0, _navigation.region.size.y - 1)
		var last_x := clampi(ceili(footprint.end.x / tile_size.x) - 1, 0, _navigation.region.size.x - 1)
		var last_y := clampi(ceili(footprint.end.y / tile_size.y) - 1, 0, _navigation.region.size.y - 1)
		for y in range(first_y, last_y + 1):
			for x in range(first_x, last_x + 1):
				_navigation.set_point_solid(Vector2i(x, y))

func is_walkable_position(world_position: Vector2) -> bool:
	if _navigation == null:
		return false
	var local := to_local(world_position)
	var cell := Vector2i(floori(local.x / tile_size.x), floori(local.y / tile_size.y))
	return _navigation.is_in_boundsv(cell) and not _navigation.is_point_solid(cell)

func get_walk_path(start: Vector2, destination: Vector2) -> PackedVector2Array:
	var path := PackedVector2Array()
	if _navigation == null:
		return path
	var local_start := to_local(start)
	var local_destination := to_local(destination)
	var from_cell := Vector2i(floori(local_start.x / tile_size.x), floori(local_start.y / tile_size.y))
	var destination_cell := Vector2i(floori(local_destination.x / tile_size.x), floori(local_destination.y / tile_size.y))
	if not _navigation.is_in_boundsv(from_cell) or not _navigation.is_in_boundsv(destination_cell):
		return path
	var from_open := _nearest_open_cell(from_cell)
	var destination_open := _nearest_open_cell(destination_cell)
	if from_open.x < 0 or destination_open.x < 0:
		return path
	var cells := _navigation.get_id_path(from_open, destination_open)
	if cells.is_empty():
		return path
	if from_open == destination_open and from_cell == destination_cell:
		path.append(destination)
		return path
	for cell in cells:
		path.append(to_global(_navigation.get_point_position(cell)))
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

func _nearest_open_cell(cell: Vector2i) -> Vector2i:
	if not _navigation.is_point_solid(cell):
		return cell
	for radius in range(1, 7):
		var closest := Vector2i(-1, -1)
		var closest_distance := 1 << 30
		for y in range(cell.y - radius, cell.y + radius + 1):
			for x in range(cell.x - radius, cell.x + radius + 1):
				if maxi(absi(x - cell.x), absi(y - cell.y)) != radius:
					continue
				var candidate := Vector2i(x, y)
				if _navigation.is_in_boundsv(candidate) and not _navigation.is_point_solid(candidate):
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
