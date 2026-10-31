extends CharacterBody2D
class_name Monster

## monster.gd
## Reusable monster entity with chase AI, attack cooldown, damage dealing,
## and death signal emission.

signal died(death_pos: Vector2, type: int)

@export var monster_type: int = 1 ## 1: Balanced, 2: Tanker, 3: Speedy Assassin
@export var attack_range: float = 38.0

var max_hp: float = 50.0
var current_hp: float = 50.0
var damage: float = 10.0
var attack_cd: float = 8.0
var speed: float = 90.0

var last_attack_time: float = -999.0
var player: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var hp_bar: ProgressBar = $OverheadBars/HealthBar
@onready var cd_bar: ProgressBar = $OverheadBars/CDBar

func _ready() -> void:
	add_to_group("monsters")
	_configure_type()
	_find_player()
	_update_bars()

func _configure_type() -> void:
	match monster_type:
		1:
			max_hp = 25.0
			damage = 8.0
			attack_cd = 3.5
			speed = 80.0
			if ResourceLoader.exists("res://graphic/monster1.png"):
				sprite.texture = load("res://graphic/monster1.png")
		2:
			max_hp = 45.0
			damage = 5.0
			attack_cd = 4.5
			speed = 55.0
			if ResourceLoader.exists("res://graphic/monster2.png"):
				sprite.texture = load("res://graphic/monster2.png")
		3:
			max_hp = 18.0
			damage = 12.0
			attack_cd = 3.0
			speed = 115.0
			if ResourceLoader.exists("res://graphic/monster3.png"):
				sprite.texture = load("res://graphic/monster3.png")
				
	# Step-scale monster health based on stage (every 5 stages increases HP by 25%)
	var stage: int = 1
	if get_node_or_null("/root/Global"):
		stage = max(1, Global.current_stage)
	var stage_step: int = int((stage - 1) / 5)
	var hp_multiplier: float = 1.0 + float(stage_step) * 0.25
	
	# Late-Game Difficulty Balancing (Stages 28-30 Endgame Challenges)
	# Challenging but mathematically winnable for players with maxed (+15) Tier 3 equipment
	if stage in [28, 29]:
		hp_multiplier *= 1.5
		damage *= 1.4
	elif stage >= 30:
		hp_multiplier *= 1.8
		damage *= 1.75
		speed *= 1.15
		attack_cd = max(2.2, attack_cd * 0.9)
		
	max_hp *= hp_multiplier
	current_hp = max_hp


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(_delta: float) -> void:
	if current_hp <= 0:
		return

	var level = get_tree().current_scene
	var is_game_over: bool = (level and "game_over" in level and level.game_over) or not Global.stage_active
	if is_game_over:
		velocity = Vector2.ZERO
		move_and_slide()
		last_attack_time = Time.get_ticks_msec() / 1000.0
		if has_node("AnimatedSprite2D") and $AnimatedSprite2D.sprite_frames and $AnimatedSprite2D.sprite_frames.has_animation("idle"):
			$AnimatedSprite2D.play("idle")
		elif has_node("AnimationPlayer") and $AnimationPlayer.has_animation("idle"):
			$AnimationPlayer.play("idle")
		return

	if not is_instance_valid(player):
		_find_player()
		return

	var dist := global_position.distance_to(player.global_position)
	var dir := (player.global_position - global_position).normalized()
	
	# Flip sprite based on chase direction
	if dir.x < 0:
		sprite.flip_h = true
	elif dir.x > 0:
		sprite.flip_h = false

	# Chase player if outside melee range
	if dist > attack_range:
		var target_vel := dir * speed
		# Smoothly navigate around obstacle blocks using wall tangent projection
		if get_slide_collision_count() > 0:
			var col := get_slide_collision(0)
			var normal := col.get_normal()
			if dir.dot(normal) < -0.2:
				var tangent := Vector2(-normal.y, normal.x)
				if tangent.dot(dir) < 0.0:
					tangent = -tangent
				target_vel = tangent * speed
		velocity = target_vel
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		_check_attack()

	_update_cd_bar()

func _check_attack() -> void:
	var current_time := Time.get_ticks_msec() / 1000.0
	if current_time - last_attack_time >= attack_cd:
		last_attack_time = current_time
		if is_instance_valid(player) and player.has_method("take_damage"):
			player.take_damage(damage)

func take_damage(amount: float) -> void:
	current_hp = max(0.0, current_hp - amount)
	_update_bars()
	
	# Hurt flash
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.5, 0.4, 0.4, 1.0), 0.08)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08)

	if current_hp <= 0:
		die()

func die() -> void:
	emit_signal("died", global_position, monster_type)
	Global.add_kill()
	queue_free()

func _update_bars() -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp

func _update_cd_bar() -> void:
	var current_time := Time.get_ticks_msec() / 1000.0
	var elapsed := current_time - last_attack_time
	var ratio := clampf(elapsed / attack_cd, 0.0, 1.0)
	cd_bar.value = ratio * 100.0

