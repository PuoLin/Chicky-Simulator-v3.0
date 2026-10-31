extends Control
class_name PauseMenu

## pause_menu.gd
## In-game pause menu popup with Resume, Settings, and Exit to Main Menu options.
## Runs in PROCESS_MODE_ALWAYS so buttons and inputs respond while get_tree().paused is true.

@onready var resume_btn: Button = get_node_or_null("CenterContainer/Panel/VBoxContainer/ResumeBtn")
@onready var restart_btn: Button = get_node_or_null("CenterContainer/Panel/VBoxContainer/RestartBtn")
@onready var settings_btn: Button = get_node_or_null("CenterContainer/Panel/VBoxContainer/SettingsBtn")
@onready var main_menu_btn: Button = get_node_or_null("CenterContainer/Panel/VBoxContainer/MainMenuBtn")
@onready var close_btn: Button = get_node_or_null("CenterContainer/Panel/CloseButton")
@onready var settings_ui: SettingsUI = $SettingsUI

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("pause_menu")
	
	if resume_btn:
		resume_btn.pressed.connect(resume_game)
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_pressed)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
	if main_menu_btn:
		main_menu_btn.pressed.connect(_on_main_menu_pressed)
	if close_btn:
		close_btn.pressed.connect(resume_game)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if settings_ui and settings_ui.visible:
			settings_ui.visible = false
		elif visible:
			resume_game()
		else:
			pause_game()

func pause_game() -> void:
	visible = true
	get_tree().paused = true

func resume_game() -> void:
	if settings_ui:
		settings_ui.visible = false
	visible = false
	get_tree().paused = false

func _on_restart_pressed() -> void:
	if settings_ui:
		settings_ui.visible = false
	visible = false
	get_tree().paused = false
	if is_inside_tree() and get_tree():
		get_tree().reload_current_scene.call_deferred()

func _on_settings_pressed() -> void:
	if settings_ui:
		settings_ui.toggle()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred("res://scenes/main/MainMenu.tscn")

