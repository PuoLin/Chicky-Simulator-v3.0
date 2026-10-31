extends Area2D
class_name ItemDrop

## item_drop.gd
## Floating equipment drop in the cave with gentle illumination and tooltip pickup.

@export var item_id: String = "axe"
var is_picked: bool = false
var initial_y: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var light: PointLight2D = $PointLight2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	initial_y = position.y
	_setup_item_display()
	_start_float_animation()

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

func _on_body_entered(body: Node2D) -> void:
	if is_picked or not body.is_in_group("player"):
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

