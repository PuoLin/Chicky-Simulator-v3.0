extends CanvasLayer
class_name HUD

## hud.gd
## Responsive game HUD with tablet/mobile anchor presets, live health/defense bars,
## stage timer, kill counter, stage-aware torch gauge, mobile touch buttons,
## and exit portal notification banner.

@onready var stage_label: Label = $TopLeft/VBoxContainer/StageLabel
@onready var kill_label: Label = $TopLeft/VBoxContainer/KillLabel
@onready var timer_label: Label = $TopCenter/TimerLabel
@onready var coin_label: Label = $TopRight/HBoxContainer/CoinLabel

# Player stats
@onready var hp_bar: ProgressBar = $TopLeft/VBoxContainer/Bars/HealthBar
@onready var def_bar: ProgressBar = $TopLeft/VBoxContainer/Bars/DefenseBar

# Torch widget (Bottom-Left)
@onready var torch_container: VBoxContainer = $BottomLeft/TorchContainer
@onready var torch_btn: Button = $BottomLeft/TorchContainer/TorchButton
@onready var torch_fuel_bar: ProgressBar = $BottomLeft/TorchContainer/FuelBar
@onready var torch_status_label: Label = $BottomLeft/TorchContainer/StatusLabel

# Action buttons (Bottom-Right & Top-Right)
@onready var attack_btn: Button = $BottomRight/HBoxContainer/AttackButton
@onready var backpack_btn: Button = $BottomRight/HBoxContainer/BackpackButton
@onready var pause_btn: Button = $TopRight/HBoxContainer/PauseButton

# Center Alert
@onready var alert_label: Label = $CenterAlert/AlertLabel

var elapsed_seconds: float = 0.0
var portal_alerted: bool = false

func _ready() -> void:
	Global.coins_changed.connect(_on_coins_changed)
	Global.kill_count_changed.connect(_on_kill_count_changed)
	Global.torch_fuel_changed.connect(_on_torch_fuel_changed)

	torch_btn.pressed.connect(_on_torch_button_pressed)
	attack_btn.pressed.connect(_on_attack_button_pressed)
	backpack_btn.pressed.connect(_on_backpack_button_pressed)
	if pause_btn:
		pause_btn.pressed.connect(_on_pause_button_pressed)

	if alert_label:
		alert_label.visible = false

	_update_stage_display()
	_on_coins_changed(Global.coins)
	_on_kill_count_changed(Global.kill_count, Global.target_kills)
	_connect_player()

var player_connected: bool = false

func _connect_player() -> void:
	if player_connected:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p: Player = players[0]
		if not p.health_changed.is_connected(_on_player_health_changed):
			p.health_changed.connect(_on_player_health_changed)
		if not p.defense_changed.is_connected(_on_player_defense_changed):
			p.defense_changed.connect(_on_player_defense_changed)
		_on_player_health_changed(p.current_hp, p.max_hp)
		_on_player_defense_changed(p.current_def, p.max_def)
		player_connected = true

func _process(delta: float) -> void:
	if not player_connected:
		_connect_player()

	if Global.stage_active:
		elapsed_seconds += delta
		var minutes := int(elapsed_seconds / 60.0)
		var seconds := int(fmod(elapsed_seconds, 60.0))
		timer_label.text = "%02d:%02d" % [minutes, seconds]

func _update_stage_display() -> void:
	var biome_name := "Prairie"
	if Global.current_stage > 20:
		biome_name = "Deep Cave"
	elif Global.current_stage > 10:
		biome_name = "Shallow Cave"
	stage_label.text = "STAGE %d (%s)" % [Global.current_stage, biome_name]

func _on_coins_changed(amount: int) -> void:
	coin_label.text = "x %d" % amount

func _on_kill_count_changed(current: int, target: int) -> void:
	kill_label.text = "Kills: %d / %d" % [current, target]
	if current >= target and target > 0:
		kill_label.text = "Exit Portal Open! (%d/%d)" % [current, target]
		if not portal_alerted:
			portal_alerted = true
			show_portal_alert()

func show_portal_alert() -> void:
	if not alert_label:
		return
	alert_label.text = "EXIT PORTAL OPENED!"
	alert_label.visible = true
	alert_label.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(alert_label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.5)
	tween.tween_property(alert_label, "modulate:a", 0.0, 0.5)

func _on_torch_fuel_changed(current_fuel: float, max_fuel: float, is_active: bool, is_unlimited: bool) -> void:
	if Global.current_stage <= 10:
		if torch_container:
			torch_container.visible = false
		return

	if torch_container:
		torch_container.visible = true

	if is_unlimited:
		torch_fuel_bar.visible = false
		torch_status_label.text = "Torch: %s (Unlimited)" % ("ON" if is_active else "OFF")
	else:
		torch_fuel_bar.visible = true
		torch_fuel_bar.max_value = max_fuel
		torch_fuel_bar.value = current_fuel
		var pct := int((current_fuel / max(0.001, max_fuel)) * 100.0)
		if current_fuel <= 0.0:
			torch_status_label.text = "Torch: OUT OF FUEL"
		else:
			torch_status_label.text = "Torch: %s (%d%%)" % [("ON" if is_active else "OFF"), pct]

func _on_player_health_changed(curr: float, max_val: float) -> void:
	hp_bar.max_value = max_val
	hp_bar.value = curr

func _on_player_defense_changed(curr: float, max_val: float) -> void:
	def_bar.max_value = max(1.0, max_val)
	def_bar.value = curr
	def_bar.visible = (max_val > 0.0)

func _on_torch_button_pressed() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		players[0].toggle_torch()

func _on_attack_button_pressed() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		players[0].perform_attack()

func _on_backpack_button_pressed() -> void:
	var bp := get_node_or_null("../BackpackUI")
	if bp and bp.has_method("toggle"):
		bp.toggle()

func _on_pause_button_pressed() -> void:
	var pauses := get_tree().get_nodes_in_group("pause_menu")
	if pauses.size() > 0:
		pauses[0].pause_game()
	else:
		var pause_menu := get_node_or_null("../PauseMenu")
		if pause_menu and pause_menu.has_method("pause_game"):
			pause_menu.pause_game()
