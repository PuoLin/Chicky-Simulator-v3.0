extends Node

## drop_manager.gd
## Manages monster loot drops including guaranteed 1-3 coins,
## stage-scaled equipment drops (10%), and health restoration drops (25%).

@export var coin_scene: PackedScene
@export var item_drop_scene: PackedScene
@export var health_pickup_scene: PackedScene
@export var equipment_drop_rate: float = 0.10 ## 10% chance to drop gear
@export var health_drop_rate: float = 0.25 ## 25% chance to drop HP item

@onready var drops_container: Node2D = get_node_or_null("../DropsContainer")

func _ready() -> void:
	if not drops_container:
		drops_container = get_parent() as Node2D

func on_monster_died(death_pos: Vector2, _monster_type: int) -> void:
	_drop_coins(death_pos)
	_drop_equipment_check(death_pos)
	_drop_health_check(death_pos)

func _drop_coins(pos: Vector2) -> void:
	if not coin_scene:
		coin_scene = load("res://scenes/items/Coin.tscn")
	if not coin_scene:
		return

	# 100% probability to drop 1–3 collectible coin items
	var coin_count := 1 + (randi() % 3)
	for i in range(coin_count):
		var coin := coin_scene.instantiate() as Node2D
		coin.global_position = pos
		drops_container.add_child(coin)

func _drop_equipment_check(pos: Vector2) -> void:
	# Baseline 10% drop rate for equipment
	if randf() > equipment_drop_rate:
		return

	if not item_drop_scene:
		item_drop_scene = load("res://scenes/items/ItemDrop.tscn")
	if not item_drop_scene:
		return

	var item_data := ItemDatabase.get_drop_for_stage(Global.current_stage)
	if item_data.is_empty():
		return

	var drop := item_drop_scene.instantiate() as ItemDrop
	drop.global_position = pos
	drop.set_item(item_data["id"])
	drops_container.add_child(drop)
	print("[DropManager] Spawned stage-scaled equipment drop: ", item_data["name"], " (Stage: ", Global.current_stage, ")")

func _drop_health_check(pos: Vector2) -> void:
	# Independent 25% drop rate for health restoration item
	if randf() > health_drop_rate:
		return

	if not health_pickup_scene:
		health_pickup_scene = load("res://scenes/items/HealthPickup.tscn")
	if not health_pickup_scene:
		return

	var hp_item := health_pickup_scene.instantiate() as Node2D
	# Offset slightly to prevent stacking on coins
	hp_item.global_position = pos + Vector2(randf_range(-16.0, 16.0), randf_range(-16.0, 16.0))
	drops_container.add_child(hp_item)
	print("[DropManager] Spawned Health Recovery Item drop at: ", hp_item.global_position)
