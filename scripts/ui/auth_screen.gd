extends Control
class_name AuthScreen

## auth_screen.gd
## Local authentication gateway managing account registration and sign-in
## persisted in user://accounts.json, with automatic legacy user import.

const ACCOUNTS_FILE := "user://accounts.json"

@onready var username_input: LineEdit = $CenterContainer/Panel/VBoxContainer/UsernameRow/UsernameInput
@onready var password_input: LineEdit = $CenterContainer/Panel/VBoxContainer/PasswordRow/PasswordInput
@onready var login_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonsHBox/LoginButton
@onready var signup_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonsHBox/SignUpButton
@onready var status_label: Label = $CenterContainer/Panel/VBoxContainer/StatusLabel

var accounts: Dictionary = {}

func _ready() -> void:
	AudioManager.play_music("menu")
	accounts = _load_accounts()
	
	login_button.pressed.connect(_on_login_pressed)
	signup_button.pressed.connect(_on_signup_pressed)
	
	username_input.text_submitted.connect(func(_text): password_input.grab_focus())
	password_input.text_submitted.connect(func(_text): _on_login_pressed())
	
	username_input.grab_focus()

func _load_accounts() -> Dictionary:
	if FileAccess.file_exists(ACCOUNTS_FILE):
		var file := FileAccess.open(ACCOUNTS_FILE, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			var parsed = JSON.parse_string(content)
			if typeof(parsed) == TYPE_DICTIONARY:
				return parsed
				
	# Auto-seed accounts from user_details.txt if available
	var default_accounts: Dictionary = {
		"Player": "1234",
		"admin": "123456"
	}
	
	var details_path := "res://user_details.txt"
	if FileAccess.file_exists(details_path):
		var file := FileAccess.open(details_path, FileAccess.READ)
		if file:
			while not file.eof_reached():
				var line := file.get_line().strip_edges()
				if line.is_empty():
					continue
				var parts := line.split(", ")
				if parts.size() >= 2:
					var uname := parts[0].strip_edges()
					var pwd := parts[1].strip_edges()
					if not uname.is_empty():
						default_accounts[uname] = pwd
						
	_save_accounts(default_accounts)
	return default_accounts

func _save_accounts(data: Dictionary) -> void:
	var file := FileAccess.open(ACCOUNTS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))

func _on_login_pressed() -> void:
	var uname := username_input.text.strip_edges()
	var pwd := password_input.text.strip_edges()
	
	if uname.is_empty() or pwd.is_empty():
		_set_status("Please enter both username and password.", Color(1.0, 0.4, 0.4, 1.0))
		return
		
	if not accounts.has(uname):
		_set_status("Username not found. Click 'Sign Up' to create it!", Color(1.0, 0.6, 0.3, 1.0))
		return
		
	if accounts[uname] != pwd:
		_set_status("Incorrect password! Please try again.", Color(1.0, 0.4, 0.4, 1.0))
		return
		
	_set_status("Login successful! Welcome back, %s!" % uname, Color(0.4, 1.0, 0.5, 1.0))
	login_button.disabled = true
	signup_button.disabled = true
	
	Global.set_active_user(uname)
	get_tree().change_scene_to_file.call_deferred("res://scenes/main/MainMenu.tscn")

func _on_signup_pressed() -> void:
	var uname := username_input.text.strip_edges()
	var pwd := password_input.text.strip_edges()
	
	if uname.is_empty() or pwd.is_empty():
		_set_status("Please enter both username and password.", Color(1.0, 0.4, 0.4, 1.0))
		return
		
	if accounts.has(uname):
		_set_status("Username already exists! Please click 'Login'.", Color(1.0, 0.8, 0.3, 1.0))
		return
		
	accounts[uname] = pwd
	_save_accounts(accounts)
	
	_set_status("Account created successfully! Welcome, %s!" % uname, Color(0.4, 1.0, 0.5, 1.0))
	login_button.disabled = true
	signup_button.disabled = true
	
	Global.set_active_user(uname)
	get_tree().change_scene_to_file.call_deferred("res://scenes/main/MainMenu.tscn")

func _set_status(msg: String, col: Color) -> void:
	status_label.text = msg
	status_label.add_theme_color_override("font_color", col)
	

# --- HTML BRIDGE WORKAROUND FOR HUAWEI QUICK APP KEYBOARD ---
func spawn_html_input(input_type: String, field_id: String) -> void:
	var js_code = """
		var old_box = document.getElementById('godot_temp_input');
		if (old_box) old_box.remove();
		
		var box = document.createElement('input');
		box.id = 'godot_temp_input';
		box.type = '%s';
		box.placeholder = 'Enter %s...';
		box.style.position = 'fixed';
		box.style.top = '10px';
		box.style.left = '50%';
		box.style.transform = 'translateX(-50%)';
		box.style.fontSize = '20px';
		box.style.padding = '10px';
		box.style.zIndex = '9999';
		document.body.appendChild(box);
		box.focus();
		
		box.onblur = function() {
			window.godotHtmlCallback([box.value, '%s']);
			box.remove();
		};
		box.onkeydown = function(e) {
			if (e.key === 'Enter') box.blur();
		};
	""" % [input_type, field_id, field_id]
	
	JavaScriptBridge.eval(js_code)

func _on_html_input(args) -> void:
	var typed_text = args[0]
	var field = args[1]
	
	if field == "username":
		username_input.text = typed_text
	elif field == "password":
		password_input.text = typed_text

func _on_username_button_pressed() -> void:
	if OS.has_feature("web"):
		spawn_html_input("text", "username")

func _on_password_button_pressed() -> void:
	if OS.has_feature("web"):
		spawn_html_input("password", "password")
