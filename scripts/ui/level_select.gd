extends Control
class_name LevelSelect

## level_select.gd
## Stage selector displaying all 30 stages across 3 dynamic biomes:
## Prairie (1-10), Shallow Cave (11-20), and Deep Cave (21-30).

@onready var grid: GridContainer = $CenterContainer/Panel/GridCenter/StageGrid
@onready var back_btn: Button = $BackButton

func _ready() -> void:
	back_btn.pressed.connect(_on_back_pressed)
	_populate_stages()

func _populate_stages() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

	for stage in range(1, 31):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(100, 100)
		btn.add_theme_font_size_override("font_size", 44)
		btn.text = str(stage)

		if stage <= Global.highest_stage:
			btn.disabled = false
			if stage <= 10:
				btn.add_theme_color_override("font_color", Color(0.65, 1.0, 0.65, 1.0))
			elif stage <= 20:
				btn.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0, 1.0))
			else:
				btn.add_theme_color_override("font_color", Color(1.0, 0.75, 0.95, 1.0))
			var target_stage: int = stage
			btn.pressed.connect(func(): _start_stage(target_stage))
		else:
			btn.disabled = true
			btn.modulate = Color(0.6, 0.6, 0.6, 0.5)

		grid.add_child(btn)

func _start_stage(stage: int) -> void:
	Global.init_stage(stage)
	get_tree().change_scene_to_file("res://scenes/main/Level.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
