extends Control
class_name AuthScreen

## auth_screen.gd
## 100% Offline, serverless Auto-Guest authentication system.
## Generates and caches a persistent guest UID in user://guest_id.save.

const GUEST_ID_FILE := "user://guest_id.save"

@onready var start_game_button: Button = $CenterContainer/Panel/VBoxContainer/StartGameButton
@onready var admin_login_button: Button = $CenterContainer/Panel/VBoxContainer/AdminLoginButton

func _ready() -> void:
	AudioManager.play_music("menu")
	start_game_button.pressed.connect(_on_start_game_pressed)
	admin_login_button.pressed.connect(_on_admin_login_pressed)

func _on_start_game_pressed() -> void:
	start_game_button.disabled = true
	admin_login_button.disabled = true
	Global.is_god_mode = false
	var uid := _get_or_create_guest_id()
	Global.set_active_user(uid)
	get_tree().change_scene_to_file.call_deferred("res://scenes/main/MainMenu.tscn")

func _on_admin_login_pressed() -> void:
	start_game_button.disabled = true
	admin_login_button.disabled = true
	Global.set_active_user("admin")
	Global.is_god_mode = true
	get_tree().change_scene_to_file.call_deferred("res://scenes/main/MainMenu.tscn")

func _get_or_create_guest_id() -> String:
	if FileAccess.file_exists(GUEST_ID_FILE):
		var file := FileAccess.open(GUEST_ID_FILE, FileAccess.READ)
		if file:
			var saved_id := file.get_as_text().strip_edges()
			if not saved_id.is_empty():
				return saved_id
	
	# Generate a new unique guest ID
	var new_id := "guest_%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 100000]
	var file := FileAccess.open(GUEST_ID_FILE, FileAccess.WRITE)
	if file:
		file.store_string(new_id)
	return new_id
