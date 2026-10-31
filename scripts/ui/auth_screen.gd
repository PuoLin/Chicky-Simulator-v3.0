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
	set_process(false)
	AudioManager.play_music("menu")
	accounts = _load_accounts()
	
	login_button.pressed.connect(_on_login_pressed)
	signup_button.pressed.connect(_on_signup_pressed)
	
	username_input.text_submitted.connect(func(_text): password_input.grab_focus())
	password_input.text_submitted.connect(func(_text): _on_login_pressed())
	
	if OS.has_feature("web"):
		username_input.gui_input.connect(_on_line_edit_gui_input.bind("username"))
		password_input.gui_input.connect(_on_line_edit_gui_input.bind("password"))
	else:
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

func _on_line_edit_gui_input(event: InputEvent, field_id: String) -> void:
	if not OS.has_feature("web"):
		return
		
	var is_touch := (event is InputEventScreenTouch and event.pressed)
	var is_click := (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	
	if is_touch or is_click:
		var current_val: String = username_input.text if field_id == "username" else password_input.text
		var input_type: String = "text" if field_id == "username" else "password"
		var title_label: String = "Username" if field_id == "username" else "Password"
		
		# Release Godot LineEdit focus to prevent internal cursor conflicts
		if field_id == "username":
			username_input.release_focus()
		else:
			password_input.release_focus()
			
		spawn_html_input(input_type, field_id, title_label, current_val)


func spawn_html_input(input_type: String, field_id: String, title_label: String, initial_val: String) -> void:
	var field_json := JSON.stringify(field_id)
	var type_json := JSON.stringify(input_type)
	var title_json := JSON.stringify(title_label)
	var val_json := JSON.stringify(initial_val)
	
	var js_code := """
	(function() {
		var fieldId = %s;
		var inputType = %s;
		var titleLabel = %s;
		var initVal = %s;
		
		// Remove any existing overlay
		var existingModal = document.getElementById('godot_input_modal');
		if (existingModal) existingModal.remove();
		
		// Reset global bridge state
		window._godot_input_bridge = {
			active: true,
			field: fieldId,
			status: 'typing',
			value: initVal
		};
		
		// Create modal container
		var modal = document.createElement('div');
		modal.id = 'godot_input_modal';
		modal.style.position = 'fixed';
		modal.style.top = '0';
		modal.style.left = '0';
		modal.style.width = '100vw';
		modal.style.height = '100vh';
		modal.style.backgroundColor = 'rgba(0, 0, 0, 0.72)';
		modal.style.zIndex = '2147483647';
		modal.style.display = 'flex';
		modal.style.flexDirection = 'column';
		modal.style.alignItems = 'center';
		modal.style.justifyContent = 'flex-start';
		modal.style.paddingTop = '40px';
		modal.style.boxSizing = 'border-box';
		modal.style.fontFamily = 'Arial, sans-serif';
		modal.style.touchAction = 'auto';
		
		var card = document.createElement('div');
		card.style.width = '88%%';
		card.style.maxWidth = '420px';
		card.style.backgroundColor = '#1c1f2b';
		card.style.border = '2px solid #5a73a3';
		card.style.borderRadius = '12px';
		card.style.padding = '18px';
		card.style.boxShadow = '0 10px 28px rgba(0,0,0,0.7)';
		card.style.display = 'flex';
		card.style.flexDirection = 'column';
		card.style.gap = '14px';
		
		var header = document.createElement('div');
		header.style.color = '#ffd74a';
		header.style.fontSize = '18px';
		header.style.fontWeight = 'bold';
		header.innerText = 'Enter ' + titleLabel;
		
		var input = document.createElement('input');
		input.id = 'godot_temp_input';
		input.type = inputType;
		input.value = initVal;
		input.placeholder = 'Type here...';
		input.autocomplete = 'off';
		input.autocapitalize = 'off';
		input.spellcheck = false;
		input.style.width = '100%%';
		input.style.boxSizing = 'border-box';
		input.style.fontSize = '20px';
		input.style.padding = '12px 14px';
		input.style.borderRadius = '8px';
		input.style.border = '2px solid #3c4860';
		input.style.backgroundColor = '#0c0e14';
		input.style.color = '#ffffff';
		input.style.outline = 'none';
		
		var btnRow = document.createElement('div');
		btnRow.style.display = 'flex';
		btnRow.style.gap = '12px';
		btnRow.style.justifyContent = 'flex-end';
		
		var btnCancel = document.createElement('button');
		btnCancel.type = 'button';
		btnCancel.innerText = 'Cancel';
		btnCancel.style.padding = '10px 18px';
		btnCancel.style.fontSize = '16px';
		btnCancel.style.fontWeight = 'bold';
		btnCancel.style.borderRadius = '6px';
		btnCancel.style.border = 'none';
		btnCancel.style.backgroundColor = '#4b5563';
		btnCancel.style.color = '#ffffff';
		btnCancel.style.cursor = 'pointer';
		
		var btnDone = document.createElement('button');
		btnDone.type = 'button';
		btnDone.innerText = 'Done';
		btnDone.style.padding = '10px 24px';
		btnDone.style.fontSize = '16px';
		btnDone.style.fontWeight = 'bold';
		btnDone.style.borderRadius = '6px';
		btnDone.style.border = 'none';
		btnDone.style.backgroundColor = '#2b78e4';
		btnDone.style.color = '#ffffff';
		btnDone.style.cursor = 'pointer';
		
		btnRow.appendChild(btnCancel);
		btnRow.appendChild(btnDone);
		
		card.appendChild(header);
		card.appendChild(input);
		card.appendChild(btnRow);
		modal.appendChild(card);
		document.body.appendChild(modal);
		
		function finishSubmit() {
			window._godot_input_bridge.value = input.value;
			window._godot_input_bridge.status = 'submitted';
			var m = document.getElementById('godot_input_modal');
			if (m) m.remove();
		}
		
		function finishCancel() {
			window._godot_input_bridge.status = 'cancelled';
			var m = document.getElementById('godot_input_modal');
			if (m) m.remove();
		}
		
		input.oninput = function() {
			window._godot_input_bridge.value = input.value;
		};
		
		input.onkeydown = function(e) {
			if (e.key === 'Enter' || e.keyCode === 13) {
				e.preventDefault();
				finishSubmit();
			}
		};
		
		btnDone.onclick = finishSubmit;
		btnDone.ontouchend = function(e) {
			e.preventDefault();
			finishSubmit();
		};
		
		btnCancel.onclick = finishCancel;
		btnCancel.ontouchend = function(e) {
			e.preventDefault();
			finishCancel();
		};
		
		modal.onclick = function(e) {
			if (e.target === modal) {
				finishCancel();
			}
		};
		
		// Force Android / Huawei WebView soft keyboard to open
		// 1. Immediate synchronous focus in current user-activation event cycle
		input.focus();
		try {
			var len = input.value.length;
			input.setSelectionRange(len, len);
		} catch(e) {}
		
		// 2. Delayed ticks for WebViews where layout/IME binding needs a frame
		if (window.requestAnimationFrame) {
			window.requestAnimationFrame(function() {
				if (document.getElementById('godot_temp_input') === input) {
					input.focus();
				}
			});
		}
		setTimeout(function() {
			if (document.getElementById('godot_temp_input') === input) {
				input.focus();
			}
		}, 30);
		setTimeout(function() {
			if (document.getElementById('godot_temp_input') === input) {
				input.focus();
			}
		}, 100);
	})();
	""" % [field_json, type_json, title_json, val_json]
	
	JavaScriptBridge.eval(js_code, true)
	set_process(true)


func _process(_delta: float) -> void:
	if not OS.has_feature("web"):
		set_process(false)
		return
		
	var raw = JavaScriptBridge.eval("""
		(function() {
			var b = window._godot_input_bridge;
			if (!b || !b.active) return '';
			if (b.status === 'submitted') {
				var res = b.field + '|||' + b.value;
				b.active = false;
				b.status = 'idle';
				return res;
			} else if (b.status === 'cancelled') {
				b.active = false;
				b.status = 'idle';
				return '__CANCELLED__';
			}
			return '';
		})();
	""", true)
	
	if raw == null:
		return
		
	var result_str := str(raw)
	if result_str.is_empty():
		return
		
	set_process(false)
	
	if result_str == "__CANCELLED__":
		return
		
	var parts = result_str.split("|||", true, 1)
	if parts.size() >= 2:
		var field = parts[0]
		var val = parts[1]
		if field == "username":
			username_input.text = val
			username_input.text_changed.emit(val)
		elif field == "password":
			password_input.text = val
			password_input.text_changed.emit(val)
