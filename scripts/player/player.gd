extends CharacterBody2D
class_name Player

## player.gd
## CharacterBody2D player controller with 8-directional movement, dynamic lighting / torch system,
## melee attack detection, real-time defense/health syncing, and responsive movement animation state machine.

signal health_changed(current_hp: float, max_hp: float)
signal defense_changed(current_def: float, max_def: float)
signal attack_cooldown_updated(ratio: float)
signal torch_toggled(active: bool)

@export_group("Torch Configuration")
@export var stage_fuel_threshold: int = 4 ## Stages >= this threshold require torch fuel
@export var max_torch_fuel: float = 60.0 ## Burn duration in seconds for late stages

var current_hp: float = 100.0
var max_hp: float = 100.0
var current_def: float = 0.0
var max_def: float = 0.0
var attack_dmg: float = 15.0
var attack_cd: float = 4.0
var move_speed: float = 180.0

var is_attacking: bool = false
var last_attack_time: float = -999.0
var facing_direction: int = 1 # 1 = right, -1 = left
var virtual_input_vector: Vector2 = Vector2.ZERO # for mobile virtual joystick
var damage_taken_this_stage: float = 0.0

# Torch state
var is_torch_active: bool = true
var current_torch_fuel: float = 60.0
var base_light_energy: float = 1.0

# References
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var torch_light: PointLight2D = $TorchLight
@onready var attack_timer: Timer = $AttackCooldownTimer
@onready var hp_bar: ProgressBar = $OverheadBars/HealthBar
@onready var def_bar: ProgressBar = $OverheadBars/DefenseBar
@onready var cd_bar: ProgressBar = $OverheadBars/CooldownBar
@onready var pickup_area: Area2D = get_node_or_null("PickupArea")
@onready var pickup_collision: CollisionShape2D = get_node_or_null("PickupArea/CollisionShape2D")
@onready var arrow_indicator: Node2D = get_node_or_null("ArrowIndicator")

var current_variant_id: String = "normal"
var exit_portal_target: Node2D = null
var hurt_tween: Tween = null
const BASE_PICKUP_RADIUS: float = 60.0 * 1.4 

func _ready() -> void:
	add_to_group("player")
	current_variant_id = Global.active_chick
	refresh_stats()
	_setup_animations()
	_setup_light_texture()
	_setup_pickup_area()
	_setup_arrow_indicator()
	current_torch_fuel = max_torch_fuel
	_update_torch_state()

func _process(_delta: float) -> void:
	if is_instance_valid(exit_portal_target) and arrow_indicator and arrow_indicator.visible:
		arrow_indicator.rotation = (exit_portal_target.global_position - global_position).angle()

func refresh_stats() -> void:
	current_variant_id = Global.active_chick
	var stats := Global.get_player_stats()
	max_hp = stats["max_hp"]
	current_hp = max_hp
	max_def = stats["max_def"]
	current_def = max_def
	attack_dmg = stats["atk"]
	attack_cd = stats["cd"]
	move_speed = stats["speed"]
	damage_taken_this_stage = 0.0
	
	_update_pickup_radius()
	_update_overhead_bars()
	emit_signal("health_changed", current_hp, max_hp)
	emit_signal("defense_changed", current_def, max_def)

func _setup_pickup_area() -> void:
	if not pickup_area:
		pickup_area = get_node_or_null("PickupArea")
	if not pickup_area:
		pickup_area = Area2D.new()
		pickup_area.name = "PickupArea"
		pickup_area.collision_layer = 1
		pickup_area.collision_mask = 4
		add_child(pickup_area)
	pickup_area.add_to_group("player_pickup")

	if not pickup_collision:
		pickup_collision = pickup_area.get_node_or_null("CollisionShape2D")
	if not pickup_collision:
		pickup_collision = CollisionShape2D.new()
		pickup_collision.name = "CollisionShape2D"
		var shape := CircleShape2D.new()
		pickup_collision.shape = shape
		pickup_area.add_child(pickup_collision)

	if not pickup_area.area_entered.is_connected(_on_pickup_area_entered):
		pickup_area.area_entered.connect(_on_pickup_area_entered)
	if not pickup_area.body_entered.is_connected(_on_pickup_body_entered):
		pickup_area.body_entered.connect(_on_pickup_body_entered)

	_update_pickup_radius()

func _update_pickup_radius() -> void:
	var radius := BASE_PICKUP_RADIUS
	if Global.active_chick == "magnet":
		radius *= 2.0 # 210.0 px for magnet chick variant
	if not pickup_collision and pickup_area:
		pickup_collision = pickup_area.get_node_or_null("CollisionShape2D")
	if pickup_collision:
		if pickup_collision.shape == null:
			pickup_collision.shape = CircleShape2D.new()
		elif not pickup_collision.shape.resource_local_to_scene:
			pickup_collision.shape = pickup_collision.shape.duplicate()
			pickup_collision.shape.resource_local_to_scene = true
		if pickup_collision.shape is CircleShape2D:
			(pickup_collision.shape as CircleShape2D).radius = radius

func _on_pickup_area_entered(area: Area2D) -> void:
	if is_instance_valid(area) and area.has_method("_on_body_entered"):
		area._on_body_entered(self)

func _on_pickup_body_entered(body: Node2D) -> void:
	if is_instance_valid(body) and body.has_method("_on_body_entered"):
		body._on_body_entered(self)

func _setup_arrow_indicator() -> void:
	if not arrow_indicator:
		arrow_indicator = get_node_or_null("ArrowIndicator")
	if not arrow_indicator:
		arrow_indicator = Node2D.new()
		arrow_indicator.name = "ArrowIndicator"
		arrow_indicator.visible = false
		arrow_indicator.z_index = 20
		add_child(arrow_indicator)

	var poly := arrow_indicator.get_node_or_null("ArrowPolygon") as Polygon2D
	if not poly:
		poly = Polygon2D.new()
		poly.name = "ArrowPolygon"
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		poly.material = mat
		poly.position = Vector2(55, 0)
		poly.color = Color(1.0, 0.85, 0.1, 1.0)
		poly.polygon = PackedVector2Array([
			Vector2(-8, -9),
			Vector2(14, 0),
			Vector2(-8, 9),
			Vector2(-2, 0)
		])
		arrow_indicator.add_child(poly)
	elif not poly.material:
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		poly.material = mat

func set_exit_portal_target(portal: Node2D) -> void:
	exit_portal_target = portal
	if arrow_indicator and is_instance_valid(portal):
		arrow_indicator.visible = true
		arrow_indicator.rotation = (portal.global_position - global_position).angle()

func hide_exit_portal_arrow() -> void:
	exit_portal_target = null
	if arrow_indicator:
		arrow_indicator.visible = false

func heal(amount: float) -> void:
	if current_hp <= 0:
		return
	current_hp = min(max_hp, current_hp + amount)
	_update_overhead_bars()
	emit_signal("health_changed", current_hp, max_hp)
	print("[Player] Healed for %f HP. Current HP: %f / %f" % [amount, current_hp, max_hp])

func _setup_animations() -> void:
	current_variant_id = Global.active_chick
	var frames := SpriteFrames.new()
	var variants: Array = Global.CHICK_STATS.keys()
	
	for v in variants:
		var v_str: String = str(v)
		# Idle animation
		var idle_name := v_str + "_idle"
		frames.add_animation(idle_name)
		frames.set_animation_speed(idle_name, 1.0)
		frames.set_animation_loop(idle_name, true)
		var idle_path := "res://graphic/%s/walk/1.png" % v_str
		if ResourceLoader.exists(idle_path):
			frames.add_frame(idle_name, load(idle_path))
			
		# Walk, Attack
		for act in ["walk", "attack"]:
			var act_name: String = v_str + "_" + act
			frames.add_animation(act_name)
			frames.set_animation_speed(act_name, 8.0)
			frames.set_animation_loop(act_name, act == "walk")
			for num in range(1, 6):
				var frame_path := "res://graphic/%s/%s/%d.png" % [v_str, act, num]
				if ResourceLoader.exists(frame_path):
					var tex: Texture2D = load(frame_path)
					frames.add_frame(act_name, tex)
		
		# Fallbacks if frames missing
		if frames.get_frame_count(idle_name) == 0:
			var fallback_path: String = Global.CHICK_STATS.get(v_str, {}).get("portrait", "res://graphic/chicky.png")
			if not ResourceLoader.exists(fallback_path):
				fallback_path = "res://graphic/normal/walk/1.png"
			var fallback_tex: Texture2D = load(fallback_path)
			if fallback_tex:
				frames.add_frame(idle_name, fallback_tex)
				for act in ["walk", "attack"]:
					frames.add_frame(v_str + "_" + act, fallback_tex)

	# Also register base unprefixed aliases pointing to the current variant frames
	for act in ["idle", "walk", "attack"]:
		var target_name: String = current_variant_id + "_" + act
		if frames.has_animation(target_name):
			frames.add_animation(act)
			frames.set_animation_speed(act, frames.get_animation_speed(target_name))
			frames.set_animation_loop(act, frames.get_animation_loop(target_name))
			for i in range(frames.get_frame_count(target_name)):
				frames.add_frame(act, frames.get_frame_texture(target_name, i))

	sprite.sprite_frames = frames
	play_anim("idle")
	
	# Scale down sprite texture to ~44px height matching collision circle
	var cur_idle := current_variant_id + "_idle"
	if frames.has_animation(cur_idle) and frames.get_frame_count(cur_idle) > 0:
		var frame_tex: Texture2D = frames.get_frame_texture(cur_idle, 0)
		if frame_tex:
			var target_height := 44.0
			var s := target_height / float(frame_tex.get_height())
			sprite.scale = Vector2(s, s)
	else:
		sprite.scale = Vector2(0.06, 0.06)

func play_anim(action_name: String) -> void:
	var variant_anim := current_variant_id + "_" + action_name
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(variant_anim):
		if sprite.animation != variant_anim or not sprite.is_playing():
			sprite.play(variant_anim)
	elif sprite.sprite_frames and sprite.sprite_frames.has_animation(action_name):
		if sprite.animation != action_name or not sprite.is_playing():
			sprite.play(action_name)

func _setup_light_texture() -> void:
	if torch_light.texture == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 0.95, 0.8, 1.0))
		grad.set_color(1, Color(1, 0.85, 0.6, 0.0))
		
		var grad_tex := GradientTexture2D.new()
		grad_tex.gradient = grad
		grad_tex.fill = GradientTexture2D.FILL_RADIAL
		grad_tex.fill_from = Vector2(0.5, 0.5)
		grad_tex.fill_to = Vector2(1.0, 0.5)
		grad_tex.width = 256
		grad_tex.height = 256
		torch_light.texture = grad_tex

func _physics_process(delta: float) -> void:
	if current_hp <= 0:
		return

	_handle_movement(delta)
	_handle_torch_fuel(delta)
	_update_cooldown(delta)

func _handle_movement(_delta: float) -> void:
	var input_vec := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if virtual_input_vector != Vector2.ZERO:
		input_vec = virtual_input_vector

	if input_vec != Vector2.ZERO:
		velocity = input_vec.normalized() * move_speed
		if input_vec.x < 0:
			facing_direction = -1
			sprite.flip_h = true
		elif input_vec.x > 0:
			facing_direction = 1
			sprite.flip_h = false
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	# Continuous movement animation state machine
	if not is_attacking:
		if velocity.length() > 0.0:
			play_anim("walk")
		else:
			play_anim("idle")

	if Input.is_action_just_pressed("attack"):
		perform_attack()
	if Input.is_action_just_pressed("toggle_torch"):
		toggle_torch()

func perform_attack() -> void:
	var current_time := Time.get_ticks_msec() / 1000.0
	if current_time - last_attack_time < attack_cd:
		return

	last_attack_time = current_time
	is_attacking = true
	play_anim("attack")
	
	# Deal melee damage to overlapping monsters
	var targets := attack_area.get_overlapping_bodies()
	for body in targets:
		if body.is_in_group("monsters") and body.has_method("take_damage"):
			body.take_damage(attack_dmg)

	await sprite.animation_finished
	is_attacking = false
	if velocity.length() > 0.0:
		play_anim("walk")
	else:
		play_anim("idle")

func take_damage(amount: float) -> void:
	if current_hp <= 0:
		return

	var incoming_dmg := amount

	# Defense absorption first
	if current_def > 0:
		if current_def >= amount:
			current_def -= amount
			amount = 0.0
		else:
			amount -= current_def
			current_def = 0.0

	if amount > 0:
		damage_taken_this_stage += amount
		current_hp = max(0.0, current_hp - amount)

	# Real-time HUD and overhead bar sync IMMEDIATELY
	_update_overhead_bars()
	emit_signal("health_changed", current_hp, max_hp)
	emit_signal("defense_changed", current_def, max_def)

	if current_hp <= 0:
		die()
		return

	# Hit feedback: Pure red flash Tween (~0.2s) without interrupting current animation
	if incoming_dmg > 0 and sprite:
		if is_instance_valid(hurt_tween) and hurt_tween.is_valid():
			hurt_tween.kill()
		sprite.modulate = Color(1.0, 0.0, 0.0, 1.0)
		hurt_tween = create_tween()
		hurt_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func die() -> void:
	velocity = Vector2.ZERO
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	if has_node("AttackArea/CollisionShape2D"):
		$AttackArea/CollisionShape2D.set_deferred("disabled", true)
	hide_exit_portal_arrow()
	if is_instance_valid(hurt_tween) and hurt_tween.is_valid():
		hurt_tween.kill()
	# Fade out gently instead of calling queue_free
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	Global.emit_signal("player_died")

var current_biome: int = 1

func configure_biome_lighting(biome: int) -> void:
	current_biome = biome
	if current_biome == 1:
		# Prairie (Stages 1-10): Bright outdoor daylight, torch disabled
		is_torch_active = false
		torch_light.enabled = false
		torch_light.energy = 0.0
		Global.emit_signal("torch_fuel_changed", 60.0, 60.0, false, false)
	elif current_biome == 2:
		# Shallow Cave (Stages 11-20): Darkness enabled, baseline vision medium (1.5), torch unlimited
		is_torch_active = true
		current_torch_fuel = max_torch_fuel
		_update_torch_state()
		Global.emit_signal("torch_fuel_changed", 60.0, 60.0, true, true)
	elif current_biome == 3:
		# Deep Cave (Stages 21-30): Deep darkness, baseline vision shrinks (0.8), torch consumable with 60s fuel
		is_torch_active = true
		current_torch_fuel = max_torch_fuel
		_update_torch_state()
		Global.emit_signal("torch_fuel_changed", current_torch_fuel, max_torch_fuel, true, false)

func toggle_torch() -> void:
	if current_biome == 1:
		print("[Player] Daylight: Torch is not needed in the Prairie!")
		return

	if is_torch_active:
		is_torch_active = false
	else:
		if current_biome == 3 and current_torch_fuel <= 0.0:
			if not refuel_torch_from_inventory():
				print("[Player] Cannot activate torch: Out of fuel!")
				return
		is_torch_active = true

	_update_torch_state()
	emit_signal("torch_toggled", is_torch_active)

func is_stage_fuel_required() -> bool:
	return current_biome == 3

func refuel_torch_from_inventory() -> bool:
	if Global.count_inventory_item("torch") > 0:
		Global.remove_inventory_item("torch")
		current_torch_fuel = max_torch_fuel
		is_torch_active = true
		_update_torch_state()
		print("[Player] Consumed a torch from backpack. Fuel fully replenished!")
		return true
	return false

func _handle_torch_fuel(delta: float) -> void:
	if current_biome == 1:
		torch_light.enabled = false
		return

	var is_consumable := (current_biome == 3)
	
	if is_torch_active and is_consumable:
		current_torch_fuel = max(0.0, current_torch_fuel - delta)
		if current_torch_fuel <= 0.0:
			is_torch_active = false
			_update_torch_state()
			print("[Player] Deep Cave: Torch burned out!")

	if is_torch_active:
		torch_light.enabled = true
		var flicker := sin(Time.get_ticks_msec() * 0.01) * 0.05
		torch_light.energy = base_light_energy + flicker
	else:
		torch_light.enabled = true
		if current_biome == 2:
			torch_light.texture_scale = 1.5
			torch_light.energy = 0.55
		elif current_biome == 3:
			torch_light.texture_scale = 0.8
			torch_light.energy = 0.35

	Global.emit_signal("torch_fuel_changed", current_torch_fuel, max_torch_fuel, is_torch_active, not is_consumable)

func _update_torch_state() -> void:
	if current_biome == 1:
		torch_light.enabled = false
		torch_light.energy = 0.0
		return

	if is_torch_active:
		torch_light.enabled = true
		torch_light.texture_scale = 2.4
		base_light_energy = 1.1
		torch_light.energy = 1.1
		torch_light.color = Color(1.0, 0.92, 0.75, 1.0)
	else:
		# Baseline cave vision when torch is toggled off or fuel depleted
		torch_light.enabled = true
		if current_biome == 2:
			torch_light.texture_scale = 1.5
			base_light_energy = 0.55
			torch_light.energy = 0.55
			torch_light.color = Color(0.7, 0.75, 0.85, 1.0)
		elif current_biome == 3:
			torch_light.texture_scale = 0.8
			base_light_energy = 0.35
			torch_light.energy = 0.35
			torch_light.color = Color(0.5, 0.55, 0.7, 1.0)

func _update_cooldown(_delta: float) -> void:
	var current_time := Time.get_ticks_msec() / 1000.0
	var elapsed := current_time - last_attack_time
	var ratio := clampf(elapsed / attack_cd, 0.0, 1.0)
	cd_bar.value = ratio * 100.0
	emit_signal("attack_cooldown_updated", ratio)

func _update_overhead_bars() -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	def_bar.max_value = max(1.0, max_def)
	def_bar.value = current_def
	def_bar.visible = (max_def > 0.0)
