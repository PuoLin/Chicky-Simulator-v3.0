extends Control
class_name GameOverDialog

## game_over_dialog.gd
## Game over dialog shown safely when player dies, providing Retry and Main Menu options
## without removing nodes from tree or nullifying get_tree().

@onready var stage_label: Label = $CenterContainer/Panel/VBoxContainer/StageLabel
@onready var retry_button: Button = $CenterContainer/Panel/VBoxContainer/HBoxContainer/RetryButton
@onready var menu_button: Button = $CenterContainer/Panel/VBoxContainer/HBoxContainer/MenuButton

func _ready() -> void:
	visible = false
	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

func show_game_over(stage: int) -> void:
	visible = true
	stage_label.text = "You fell in Stage %d" % stage

func _on_retry_pressed() -> void:
	visible = false
	if is_inside_tree() and get_tree():
		get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	visible = false
	if is_inside_tree() and get_tree():
		get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")

