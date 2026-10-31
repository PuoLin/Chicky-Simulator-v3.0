extends Area2D
class_name CoinPickup

## coin.gd
## Collectible coin with spawn bounce physics, magnetic attraction towards Richie Chick,
## and coin counter integration.

@export var coin_value: int = 15
var player: CharacterBody2D = null
var is_collecting: bool = false
var magnet_radius: float = 120.0
var base_scale: Vector2 = Vector2(0.08, 0.08)

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	base_scale = sprite.scale
	_spawn_bounce()
	_find_player()
	
	if Global.active_chick == "magnet":
		magnet_radius = 240.0 # Double pickup range for Richie Chick

func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _spawn_bounce() -> void:
	var scatter_offset := Vector2(randf_range(-25, 25), randf_range(-25, 25))
	var target_pos := global_position + scatter_offset
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", target_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", base_scale * Vector2(1.2, 0.8), 0.15)
	tween.chain().tween_property(sprite, "scale", base_scale, 0.2)

func _physics_process(delta: float) -> void:
	if is_collecting:
		return

	if not is_instance_valid(player):
		_find_player()
		return

	var dist := global_position.distance_to(player.global_position)
	if dist <= magnet_radius:
		# Magnetically fly towards player
		var dir := (player.global_position - global_position).normalized()
		var pull_speed := 280.0 * (1.0 - (dist / magnet_radius)) + 140.0
		global_position += dir * pull_speed * delta

func _on_body_entered(body: Node2D) -> void:
	if is_collecting or not body.is_in_group("player"):
		return

	is_collecting = true
	Global.add_coins(coin_value)

	# Collection sparkle effect
	var tween := create_tween().set_parallel(true)
	tween.tween_property(sprite, "scale", base_scale * 1.5, 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	await tween.finished
	queue_free()
