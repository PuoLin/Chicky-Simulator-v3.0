extends Control
class_name SettingsUI

## settings_ui.gd
## Audio and game settings dialog allowing players to toggle background music
## and sound effects, reusable across Main Menu and in-game Pause Menu.

@onready var music_toggle_btn: Button = $CenterContainer/Panel/VBoxContainer/MusicRow/MusicToggleBtn
@onready var sfx_toggle_btn: Button = $CenterContainer/Panel/VBoxContainer/SfxRow/SfxToggleBtn
@onready var volume_slider: HSlider = $CenterContainer/Panel/VBoxContainer/VolumeRow/VolumeSlider
@onready var close_btn: Button = $CenterContainer/Panel/TopBar/CloseButton
@onready var done_btn: Button = $CenterContainer/Panel/VBoxContainer/ButtonsHBox/DoneBtn
@onready var logout_btn: Button = $CenterContainer/Panel/VBoxContainer/ButtonsHBox/LogoutBtn

func _ready() -> void:
	visible = false
	if close_btn:
		close_btn.pressed.connect(toggle)
	if done_btn:
		done_btn.pressed.connect(toggle)
	if logout_btn:
		logout_btn.pressed.connect(_on_logout_pressed)
	music_toggle_btn.pressed.connect(_on_music_toggle_pressed)
	sfx_toggle_btn.pressed.connect(_on_sfx_toggle_pressed)
	if volume_slider:
		volume_slider.value_changed.connect(_on_volume_changed)
	refresh_buttons()

func toggle() -> void:
	visible = not visible
	if visible:
		refresh_buttons()
	else:
		Global.save_player_data()

func refresh_buttons() -> void:
	if volume_slider:
		volume_slider.value = AudioManager.get_master_volume()
	if AudioManager.is_music_enabled:
		music_toggle_btn.text = "ON"
		music_toggle_btn.modulate = Color(0.4, 0.95, 0.5, 1.0)
	else:
		music_toggle_btn.text = "OFF"
		music_toggle_btn.modulate = Color(0.95, 0.4, 0.4, 1.0)

	if AudioManager.is_sfx_enabled:
		sfx_toggle_btn.text = "ON"
		sfx_toggle_btn.modulate = Color(0.4, 0.95, 0.5, 1.0)
	else:
		sfx_toggle_btn.text = "OFF"
		sfx_toggle_btn.modulate = Color(0.95, 0.4, 0.4, 1.0)

func _on_music_toggle_pressed() -> void:
	AudioManager.toggle_music()
	refresh_buttons()

func _on_sfx_toggle_pressed() -> void:
	AudioManager.toggle_sfx()
	refresh_buttons()

func _on_volume_changed(val: float) -> void:
	AudioManager.set_master_volume(val)

func _on_logout_pressed() -> void:
	visible = false
	if get_tree().paused:
		get_tree().paused = false
	Global.clear_session()
	AudioManager.stop_bgm()
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/AuthScreen.tscn")


