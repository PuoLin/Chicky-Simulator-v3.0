extends Control
class_name PauseMenu

## pause_menu.gd
## In-game pause menu popup with Resume, Settings, and Exit to Main Menu options.
## Runs in PROCESS_MODE_ALWAYS so buttons and inputs respond while get_tree().paused is true.

@onready var resume_btn: Button = $CenterContainer/Panel/VBoxContainer/ResumeBtn
@onready var settings_btn: Button = $CenterContainer/Panel/VBoxContainer/SettingsBtn
@onready var main_menu_btn: Button = $CenterContainer/Panel/VBoxContainer/MainMenuBtn
@onready var settings_ui: SettingsUI = $SettingsUI

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("pause_menu")
	
	resume_btn.pressed.connect(resume_game)
	settings_btn.pressed.connect(_on_settings_pressed)
	main_menu_btn.pressed.connect(_on_main_menu_pressed)

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

func _on_settings_pressed() -> void:
	if settings_ui:
		settings_ui.toggle()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")

