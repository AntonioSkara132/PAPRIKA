class_name FrontSoldier
extends CharacterBody2D

## A soldier holding a position on the Artichoke front. Confederation soldiers
## can be talked to; New Republic soldiers only stand guard on the other side.
## A soldier given a service (the base officer) opens that service instead of talking.

const CONFEDERATION_LINES := [
	"Keep your head below the sandbags. Their lookouts watch the whole slope.",
	"The ruined houses in no man's land are the only cover between us and them.",
	"Do not step on the ground by the red marks. Somebody buried mines there.",
	"Blue coats with gold on the shoulders. If you see them close, you are too far forward.",
	"The flagship stays on the cleared ground until the transport crew calls for passengers.",
	"Snow again. At least it covers the wire so the sun does not glint off it.",
]

var soldier_id := ""
var side := "confederation"
var _sprite: Sprite2D
var _dialogue_index := 0
var service_id := ""
var service_name := ""

func configure(id: String, soldier_side: String, texture_path: String, position: Vector2) -> void:
	soldier_id = id
	side = soldier_side
	global_position = position
	_dialogue_index = absi(soldier_id.hash()) % CONFEDERATION_LINES.size()
	collision_layer = 4
	collision_mask = 0
	z_index = 100 + int(position.y)
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture = load(texture_path) as Texture2D
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false
	if _sprite.texture != null:
		_sprite.position = Vector2(-_sprite.texture.get_width() * 0.5, -_sprite.texture.get_height() + 2)
	add_child(_sprite)
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(8, 6)
	collision.shape = box
	collision.position = Vector2(0, -3)
	add_child(collision)

func _ready() -> void:
	if side == "confederation":
		add_to_group("interactable")

## Makes this soldier open `id` in the game UI when the player talks to them.
func offer_service(id: String, display_name: String) -> void:
	service_id = id
	service_name = display_name

func get_interaction_text() -> String:
	if not service_id.is_empty():
		return "Talk to %s" % service_name
	return "Talk to Confederation soldier"

func interact(_actor: Node) -> void:
	if side != "confederation":
		return
	if not service_id.is_empty():
		var world := get_tree().get_first_node_in_group("game_world")
		if world != null and world.has_method("_on_service_requested"):
			world.call("_on_service_requested", service_id, service_name)
		return
	GameState.notify("Confederation soldier: %s" % CONFEDERATION_LINES[_dialogue_index])
	_dialogue_index = (_dialogue_index + 1) % CONFEDERATION_LINES.size()

func get_texture() -> Texture2D:
	return _sprite.texture if _sprite != null else null
