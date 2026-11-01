extends Area2D
class_name ItemDrop

## item_drop.gd
## Floating equipment drop in the cave with gentle illumination and tooltip pickup.

@export var item_id: String = "axe"
var is_picked: bool = false
var initial_y: float = 0.0
var player: CharacterBody2D = null
var magnet_radius: float = 210.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var light: PointLight2D = $PointLight2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	initial_y = position.y
	_setup_item_display()
	_start_float_animation()
	_find_player()

	if Global.active_chick == "magnet":
		magnet_radius = 420.0 # Double pickup range for Richie Chick

func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(delta: float) -> void:
	if is_picked:
		return

	if not is_instance_valid(player):
		_find_player()
		return

	var dist := global_position.distance_to(player.global_position)
	if dist <= magnet_radius:
		# Magnetically fly towards player
		var dir := (player.global_position - global_position).normalized()
		var pull_speed := 300.0 * (1.0 - (dist / magnet_radius)) + 150.0
		global_position += dir * pull_speed * delta

func set_item(id: String) -> void:
	item_id = id
	if is_inside_tree():
		_setup_item_display()

func _setup_item_display() -> void:
	var item_data := ItemDatabase.get_item(item_id)
	if not item_data.is_empty():
		var tex_path: String = item_data.get("texture_path", "")
		if ResourceLoader.exists(tex_path):
			sprite.texture = load(tex_path)

func _start_float_animation() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "position:y", -6.0, 0.7).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", 2.0, 0.7).set_trans(Tween.TRANS_SINE)

func _on_area_entered(area: Area2D) -> void:
	if area and (area.is_in_group("player_pickup") or (area.get_parent() and area.get_parent().is_in_group("player"))):
		_collect()

func _on_body_entered(body: Node2D) -> void:
	if body and (body.is_in_group("player") or body.is_in_group("player_pickup") or (body.get_parent() and body.get_parent().is_in_group("player"))):
		_collect()

func _collect() -> void:
	if is_picked:
		return

	is_picked = true
	Global.add_inventory_item(item_id)
	
	var item_data := ItemDatabase.get_item(item_id)
	var item_name: String = item_data.get("name", item_id)
	print("[ItemDrop] Player picked up: ", item_name)

	# Pickup pop animation
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	queue_free()

