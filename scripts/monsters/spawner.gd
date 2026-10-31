extends Node2D

## spawner.gd
## Manages periodic off-screen monster spawning in a perimeter ring outside the active camera.
## Dynamically scales monster difficulty, spawn intervals, and concurrent limits by stage.

@export var monster_scene: PackedScene
@export var level_min_bound: Vector2 = Vector2(60, 60)
@export var level_max_bound: Vector2 = Vector2(1540, 940)

var spawn_timer: Timer
var monsters_container: Node2D
var camera: Camera2D

func _ready() -> void:
	monsters_container = get_node_or_null("../MonstersContainer")
	if not monsters_container:
		monsters_container = self

	spawn_timer = Timer.new()
	var stage := Global.current_stage
	if stage >= 30:
		spawn_timer.wait_time = 1.2 # Balanced fast spawn for Stage 30
	elif stage in [28, 29]:
		spawn_timer.wait_time = 1.4 # Balanced spawn interval for Stages 28-29
	else:
		spawn_timer.wait_time = max(1.5, 4.2 - (stage * 0.2))
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_on_spawn_timeout)
	add_child(spawn_timer)

	_find_camera()

func _find_camera() -> void:
	var cams := get_tree().get_nodes_in_group("player_camera")
	if cams.size() > 0:
		camera = cams[0]
	else:
		# Fallback to viewport camera
		camera = get_viewport().get_camera_2d()

func stop_spawning() -> void:
	if spawn_timer:
		spawn_timer.stop()

func _on_spawn_timeout() -> void:
	var level = get_tree().current_scene
	if not Global.stage_active or (level and "game_over" in level and level.game_over):
		stop_spawning()
		return

	# Dynamic stage-based concurrent monster limit
	var stage := Global.current_stage
	var max_allowed: int = min(12, 3 + (stage * 2))
	if stage >= 30:
		max_allowed = 16 # Rebalanced concurrency cap for Stage 30
	elif stage in [28, 29]:
		max_allowed = 14 # Rebalanced concurrency cap for Stages 28-29

	var current_monsters := get_tree().get_nodes_in_group("monsters")
	if current_monsters.size() >= max_allowed:
		return

	spawn_monster()

func spawn_monster() -> void:
	if not monster_scene:
		monster_scene = load("res://scenes/monsters/Monster.tscn")
	if not monster_scene:
		return

	if not is_instance_valid(camera):
		_find_camera()

	var spawn_pos := _find_valid_spawn_position()
	var monster := monster_scene.instantiate() as Monster
	monster.global_position = spawn_pos
	monster.monster_type = _select_monster_type_for_stage(Global.current_stage)
	
	monsters_container.add_child(monster)

	# Connect death signal to DropManager
	var drop_mgr := get_node_or_null("../DropManager")
	if drop_mgr and drop_mgr.has_method("on_monster_died"):
		monster.died.connect(Callable(drop_mgr, "on_monster_died"))

func _find_valid_spawn_position() -> Vector2:
	for attempt in range(15):
		var pos := _calculate_offscreen_position()
		if not _is_position_blocked(pos):
			return pos
	return _calculate_offscreen_position()

func _is_position_blocked(pos: Vector2) -> bool:
	# 1. Distance check against level obstacles
	var level = get_tree().current_scene
	if level and "obstacle_positions" in level:
		for obs_pos in level.obstacle_positions:
			if pos.distance_to(obs_pos) < 55.0:
				return true

	# 2. Physics direct space state check on layer 1 (world / obstacles)
	var world := get_world_2d()
	if world:
		var space_state := world.direct_space_state
		if space_state:
			var query := PhysicsPointQueryParameters2D.new()
			query.position = pos
			query.collision_mask = 1
			var hits := space_state.intersect_point(query, 1)
			if hits.size() > 0:
				return true

	return false

func _calculate_offscreen_position(padding: float = 80.0) -> Vector2:
	var center := Vector2(800, 500)
	var half_size := Vector2(640, 360)
	
	if is_instance_valid(camera):
		center = camera.get_screen_center_position()
		var v_size := get_viewport_rect().size
		var zoom := camera.zoom
		half_size = (v_size / zoom) * 0.5

	var side := randi() % 4 # 0: Top, 1: Bottom, 2: Left, 3: Right
	var pos := Vector2.ZERO

	match side:
		0: # Top
			pos.x = randf_range(center.x - half_size.x - padding, center.x + half_size.x + padding)
			pos.y = center.y - half_size.y - padding
		1: # Bottom
			pos.x = randf_range(center.x - half_size.x - padding, center.x + half_size.x + padding)
			pos.y = center.y + half_size.y + padding
		2: # Left
			pos.x = center.x - half_size.x - padding
			pos.y = randf_range(center.y - half_size.y - padding, center.y + half_size.y + padding)
		3: # Right
			pos.x = center.x + half_size.x + padding
			pos.y = randf_range(center.y - half_size.y - padding, center.y + half_size.y + padding)

	# Clamp to dungeon boundaries so monsters don't spawn inside deep void
	pos.x = clampf(pos.x, level_min_bound.x, level_max_bound.x)
	pos.y = clampf(pos.y, level_min_bound.y, level_max_bound.y)
	return pos

func _select_monster_type_for_stage(stage: int) -> int:
	if stage <= 5:
		return 1 # Monster 1 only
	elif stage <= 10:
		return 1 if randf() < 0.6 else 2 # Monster 1 & 2
	elif stage >= 28:
		# Stages 28-30: High proportion of Tanks and Speedy Assassins
		var roll := randf()
		if roll < 0.2:
			return 1
		elif roll < 0.6:
			return 2
		else:
			return 3
	else:
		var roll := randf()
		if roll < 0.4:
			return 1
		elif roll < 0.7:
			return 2
		else:
			return 3 # Speedy assassin
