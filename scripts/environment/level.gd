extends Node2D
class_name Level

## level.gd
## Central stage controller handling 30 stages with dynamic biomes (Prairie, Shallow Cave, Deep Cave),
## procedural block obstacles, randomized exit portal placement, monster spawner lifecycle,
## and complete post-game monster state freezing.

@onready var player: Player = $Player
@onready var exit_portal: ExitPortal = $ExitPortal
@onready var win_dialog: WinDialog = $CanvasLayer/WinDialog
@onready var game_over_dialog: GameOverDialog = $CanvasLayer/GameOverDialog
@onready var hud: HUD = $CanvasLayer/HUD
@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var background: Sprite2D = $Background
@onready var spawner: Node2D = $Spawner
@onready var obstacles_container: Node2D = $ObstaclesContainer

var game_over: bool = false
var stage_elapsed_time: float = 0.0
var obstacle_positions: Array[Vector2] = []

func _process(delta: float) -> void:
	if not game_over and Global.stage_active:
		stage_elapsed_time += delta

func _ready() -> void:
	game_over = false
	stage_elapsed_time = 0.0
	AudioManager.play_music("battle")
	Global.init_stage(Global.current_stage)
	
	if exit_portal:
		exit_portal.portal_entered.connect(_on_stage_cleared)
	Global.player_died.connect(_on_player_died)
	Global.kill_count_changed.connect(_on_kill_count_changed)
	
	_spawn_obstacles()
	_apply_biome_configuration()
	_spawn_map_initial_coins()

func _apply_biome_configuration() -> void:
	var stage := Global.current_stage
	var bg_texture_path := "res://graphic/map.jpg"
	
	if stage <= 10:
		# Biome 1: Prairie (Stages 1-10)
		bg_texture_path = "res://graphic/map.jpg"
		canvas_modulate.color = Color(1.0, 1.0, 1.0, 1.0) # Full daylight
		if is_instance_valid(player):
			player.configure_biome_lighting(1)
	elif stage <= 20:
		# Biome 2: Shallow Cave (Stages 11-20)
		bg_texture_path = "res://graphic/cavebg.png"
		canvas_modulate.color = Color(0.04, 0.04, 0.07, 1.0)
		if is_instance_valid(player):
			player.configure_biome_lighting(2)
	else:
		# Biome 3: Deep Cave (Stages 21-30)
		bg_texture_path = "res://graphic/deepcave.png"
		canvas_modulate.color = Color(0.02, 0.02, 0.04, 1.0)
		if is_instance_valid(player):
			player.configure_biome_lighting(3)
			
	if not ResourceLoader.exists(bg_texture_path):
		bg_texture_path = "res://graphic/map.jpg"
		
	if ResourceLoader.exists(bg_texture_path):
		background.texture = load(bg_texture_path)
		var tex_size := background.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			background.position = Vector2(800, 500)
			background.scale = Vector2(1650.0 / tex_size.x, 1050.0 / tex_size.y)

func _spawn_obstacles() -> void:
	var obstacle_scene: PackedScene = load("res://scenes/environment/Obstacle.tscn")
	if not obstacle_scene or not obstacles_container:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = Global.current_stage * 987654321
	
	obstacle_positions.clear()
	var base_obstacles: int = 4
	var cluster_count: int = base_obstacles + int((Global.current_stage - 1) / 5) * 2
	var player_start := Vector2(160, 160)
	var initial_portal := Vector2(1480, 860)

	for c in range(cluster_count):
		var cluster_center := Vector2(
			rng.randf_range(380.0, 1220.0),
			rng.randf_range(260.0, 740.0)
		)
		cluster_center.x = roundf(cluster_center.x / 50.0) * 50.0
		cluster_center.y = roundf(cluster_center.y / 50.0) * 50.0

		if cluster_center.distance_to(player_start) < 280.0 or cluster_center.distance_to(initial_portal) < 220.0:
			continue

		var block_count := rng.randi_range(1, 4)
		var offsets: Array[Vector2] = [
			Vector2(0, 0),
			Vector2(50, 0),
			Vector2(0, 50),
			Vector2(-50, 0),
			Vector2(0, -50)
		]
		
		for b in range(block_count):
			var b_pos := cluster_center + offsets[b]
			if b_pos.x < 100 or b_pos.x > 1500 or b_pos.y < 100 or b_pos.y > 900:
				continue
			if b_pos.distance_to(player_start) < 260.0 or b_pos.distance_to(initial_portal) < 200.0:
				continue
			if obstacle_positions.has(b_pos):
				continue

			obstacle_positions.append(b_pos)
			var obs := obstacle_scene.instantiate() as StaticBody2D
			obs.global_position = b_pos
			obstacles_container.add_child(obs)

func _is_position_blocked_by_obstacle(pos: Vector2, min_dist: float = 45.0) -> bool:
	for obs_pos in obstacle_positions:
		if pos.distance_to(obs_pos) < min_dist:
			return true
	return false

func _spawn_map_initial_coins() -> void:
	var coin_scene: PackedScene = load("res://scenes/items/Coin.tscn")
	if not coin_scene:
		return
	var drops_node: Node2D = $DropsContainer
	var positions: Array[Vector2] = [
		Vector2(200, 200),
		Vector2(1400, 200),
		Vector2(300, 750),
		Vector2(1300, 800),
		Vector2(800, 500)
	]
	for pos in positions:
		var target_pos: Vector2 = pos
		if _is_position_blocked_by_obstacle(target_pos):
			target_pos += Vector2(60, 60)
		var c := coin_scene.instantiate() as Node2D
		c.position = target_pos
		drops_node.add_child(c)

func _on_kill_count_changed(current: int, target: int) -> void:
	if current >= target and target > 0 and exit_portal and not exit_portal.is_open:
		_spawn_random_exit_portal()

func _spawn_random_exit_portal() -> void:
	var player_pos := Vector2(160, 160)
	if is_instance_valid(player):
		player_pos = player.global_position

	var chosen_pos := Vector2.ZERO
	for attempt in range(30):
		var candidate := Vector2(
			randf_range(240.0, 1360.0),
			randf_range(200.0, 800.0)
		)
		if candidate.distance_to(player_pos) >= 350.0 and not _is_position_blocked_by_obstacle(candidate, 65.0):
			chosen_pos = candidate
			break

	if chosen_pos == Vector2.ZERO:
		chosen_pos = Vector2(1400, 800)

	exit_portal.global_position = chosen_pos
	exit_portal.open_portal()
	if is_instance_valid(player) and player.has_method("set_exit_portal_target"):
		player.set_exit_portal_target(exit_portal)
	print("[Level] Exit portal opened at random coordinate: ", chosen_pos)

func get_stage_clear_reward(stage_num: int) -> int:
	# Structured economy reward curve:
	# Stages 1-8: exactly 1,000 coins total (affords Tier 1 set milestone)
	# Stages 9-18: exactly 3,000 coins total (affords Tier 2 set milestone)
	# Stages 19-25: exactly 8,000 coins total (affords Tier 3 set milestone)
	# Stages 26-30: endgame scaling for duplicate farming & Blacksmith upgrades
	match stage_num:
		1: return 50
		2: return 70
		3: return 90
		4: return 110
		5: return 130
		6: return 150
		7: return 180
		8: return 220    # Sum(1..8) = 1,000 coins
		9: return 240
		10: return 250
		11: return 260
		12: return 280
		13: return 300
		14: return 310
		15: return 320
		16: return 340
		17: return 350
		18: return 350   # Sum(9..18) = 3,000 coins
		19: return 600
		20: return 800
		21: return 1000
		22: return 1150
		23: return 1300
		24: return 1500
		25: return 1650  # Sum(19..25) = 8,000 coins
		26: return 1800
		27: return 2000
		28: return 2500
		29: return 3000
		30: return 4000
		_: return stage_num * 100

func _on_stage_cleared() -> void:
	game_over = true
	Global.stage_active = false
	if is_instance_valid(player):
		if player.has_method("stop_movement"):
			player.stop_movement()
		else:
			player.velocity = Vector2.ZERO
			player.virtual_input_vector = Vector2.ZERO
		if player.has_method("hide_exit_portal_arrow"):
			player.hide_exit_portal_arrow()
	if hud and is_instance_valid(hud) and hud.has_method("disable_controls"):
		hud.disable_controls()
	for joy in get_tree().get_nodes_in_group("virtual_joystick"):
		if joy.has_method("disable_joystick"):
			joy.disable_joystick()
	if spawner and spawner.has_method("stop_spawning"):
		spawner.stop_spawning()
	AudioManager.play_victory_jingle()
	
	var stage_num := Global.current_stage
	var base_reward: int = get_stage_clear_reward(stage_num)
	var is_first_time: bool = not Global.is_stage_cleared(stage_num)
	var reward_coins: int = base_reward
	if not is_first_time:
		reward_coins = int(base_reward * 0.40) # Replay penalty: 40% coins
		
	if Global.active_chick == "magnet":
		reward_coins = int(reward_coins * 1.3)
	Global.add_coins(reward_coins)
	Global.mark_stage_cleared(stage_num)
	
	# Award stage diamonds for milestone stages on first clear
	var bonus_diamonds: int = 0
	if is_first_time:
		if stage_num == 10:
			bonus_diamonds = 50
		elif stage_num == 20:
			bonus_diamonds = 100
		elif stage_num == 30:
			bonus_diamonds = 150
		elif stage_num % 5 == 0:
			bonus_diamonds = 10
		if bonus_diamonds > 0:
			Global.add_diamonds(bonus_diamonds)
	
	# Record speed and flawless clears for achievements
	var time_spent: float = stage_elapsed_time if stage_elapsed_time > 0.0 else (hud.elapsed_seconds if hud else 0.0)
	var damage_taken: float = player.damage_taken_this_stage if is_instance_valid(player) else 0.0
	Global.record_stage_clear(time_spent, damage_taken)
	Global.record_survival_time(stage_num, time_spent)

	# Restore player health and defense upon advancing
	if is_instance_valid(player):
		player.refresh_stats()

	win_dialog.show_victory(stage_num, reward_coins, time_spent, not is_first_time, bonus_diamonds)

func _on_player_died() -> void:
	game_over = true
	Global.stage_active = false
	if is_instance_valid(player):
		if player.has_method("stop_movement"):
			player.stop_movement()
		else:
			player.velocity = Vector2.ZERO
			player.virtual_input_vector = Vector2.ZERO
		if player.has_method("hide_exit_portal_arrow"):
			player.hide_exit_portal_arrow()
	if hud and is_instance_valid(hud) and hud.has_method("disable_controls"):
		hud.disable_controls()
	for joy in get_tree().get_nodes_in_group("virtual_joystick"):
		if joy.has_method("disable_joystick"):
			joy.disable_joystick()
	if spawner and spawner.has_method("stop_spawning"):
		spawner.stop_spawning()
	AudioManager.play_defeat_jingle()
	var time_spent: float = stage_elapsed_time if stage_elapsed_time > 0.0 else (hud.elapsed_seconds if hud else 0.0)
	Global.record_survival_time(Global.current_stage, time_spent)
	print("[Level] Player fell in battle after %.1fs. Displaying game over dialog..." % time_spent)
	if is_instance_valid(game_over_dialog):
		game_over_dialog.show_game_over(Global.current_stage)
