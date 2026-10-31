extends Control
class_name AuthScreen

## auth_screen.gd
## Local authentication gateway managing account registration and sign-in
## persisted in user://accounts.json, with automatic legacy user import.
## Features a Document Title Hijacking pipeline to bypass Huawei Quick App webview sandbox.

const ACCOUNTS_FILE := "user://accounts.json"
const DEFAULT_TITLE := "Chicky Simulator 2.0"

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
		username_input.gui_input.connect(_on_line_edit_gui_input)
		password_input.gui_input.connect(_on_line_edit_gui_input)
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
	if OS.has_feature("web"):
		spawn_html_auth_form("LOGIN")
		return
	_execute_login(username_input.text, password_input.text)

func _on_signup_pressed() -> void:
	if OS.has_feature("web"):
		spawn_html_auth_form("SIGNUP")
		return
	_execute_signup(username_input.text, password_input.text)

func _execute_login(uname: String, pwd: String) -> void:
	uname = uname.strip_edges()
	pwd = pwd.strip_edges()
	
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

func _execute_signup(uname: String, pwd: String) -> void:
	uname = uname.strip_edges()
	pwd = pwd.strip_edges()
	
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


# --- DOCUMENT TITLE HIJACKING HTML BRIDGE FOR HUAWEI QUICK APP ---

func _on_line_edit_gui_input(event: InputEvent) -> void:
	if not OS.has_feature("web"):
		return
		
	var is_touch := (event is InputEventScreenTouch and event.pressed)
	var is_click := (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	
	if is_touch or is_click:
		username_input.release_focus()
		password_input.release_focus()
		spawn_html_auth_form("LOGIN")


func spawn_html_auth_form(action: String) -> void:
	var action_title := "LOGIN" if action == "LOGIN" else "SIGN UP"
	var pwd_autocomplete := "current-password" if action == "LOGIN" else "new-password"
	
	var action_json := JSON.stringify(action)
	var title_json := JSON.stringify(action_title)
	var pwd_auto_json := JSON.stringify(pwd_autocomplete)
	var initial_user_json := JSON.stringify(username_input.text)
	var initial_pass_json := JSON.stringify(password_input.text)
	
	var js_code := """
	(function() {
		var action = %s;
		var actionTitle = %s;
		var pwdAuto = %s;
		var initUser = %s;
		var initPass = %s;
		
		var existing = document.getElementById('godot_auth_modal');
		if (existing) existing.remove();
		
		var modal = document.createElement('div');
		modal.id = 'godot_auth_modal';
		modal.style.position = 'fixed';
		modal.style.top = '0';
		modal.style.left = '0';
		modal.style.width = '100vw';
		modal.style.height = '100vh';
		modal.style.backgroundColor = 'rgba(0, 0, 0, 0.75)';
		modal.style.zIndex = '2147483647';
		modal.style.display = 'flex';
		modal.style.flexDirection = 'column';
		modal.style.alignItems = 'center';
		modal.style.justifyContent = 'flex-start';
		modal.style.paddingTop = '35px';
		modal.style.boxSizing = 'border-box';
		modal.style.fontFamily = 'Arial, sans-serif';
		modal.style.touchAction = 'auto';
		
		var card = document.createElement('div');
		card.style.width = '90%%';
		card.style.maxWidth = '420px';
		card.style.backgroundColor = '#1c1f2b';
		card.style.border = '2px solid #5a73a3';
		card.style.borderRadius = '12px';
		card.style.padding = '20px';
		card.style.boxShadow = '0 10px 30px rgba(0,0,0,0.8)';
		card.style.display = 'flex';
		card.style.flexDirection = 'column';
		card.style.gap = '14px';
		
		var title = document.createElement('div');
		title.style.color = '#ffd74a';
		title.style.fontSize = '20px';
		title.style.fontWeight = 'bold';
		title.style.textAlign = 'center';
		title.innerText = 'CHICKY - ' + actionTitle;
		card.appendChild(title);
		
		var form = document.createElement('form');
		form.id = 'godot_auth_form';
		form.action = '#';
		form.method = 'post';
		form.autocomplete = 'on';
		form.style.display = 'flex';
		form.style.flexDirection = 'column';
		form.style.gap = '12px';
		
		// Username Group
		var userGroup = document.createElement('div');
		userGroup.style.display = 'flex';
		userGroup.style.flexDirection = 'column';
		userGroup.style.gap = '4px';
		var userLabel = document.createElement('label');
		userLabel.style.color = '#cbd5e1';
		userLabel.style.fontSize = '14px';
		userLabel.innerText = 'Username:';
		var userInput = document.createElement('input');
		userInput.id = 'godot_user_input';
		userInput.type = 'text';
		userInput.name = 'username';
		userInput.autocomplete = 'username';
		userInput.placeholder = 'Enter username...';
		userInput.value = initUser;
		userInput.required = true;
		userInput.style.width = '100%%';
		userInput.style.boxSizing = 'border-box';
		userInput.style.fontSize = '18px';
		userInput.style.padding = '10px 12px';
		userInput.style.borderRadius = '8px';
		userInput.style.border = '2px solid #3c4860';
		userInput.style.backgroundColor = '#0c0e14';
		userInput.style.color = '#ffffff';
		userInput.style.outline = 'none';
		userGroup.appendChild(userLabel);
		userGroup.appendChild(userInput);
		form.appendChild(userGroup);
		
		// Password Group
		var passGroup = document.createElement('div');
		passGroup.style.display = 'flex';
		passGroup.style.flexDirection = 'column';
		passGroup.style.gap = '4px';
		var passLabel = document.createElement('label');
		passLabel.style.color = '#cbd5e1';
		passLabel.style.fontSize = '14px';
		passLabel.innerText = 'Password:';
		var passInput = document.createElement('input');
		passInput.id = 'godot_pass_input';
		passInput.type = 'password';
		passInput.name = 'password';
		passInput.autocomplete = pwdAuto;
		passInput.placeholder = 'Enter password...';
		passInput.value = initPass;
		passInput.required = true;
		passInput.style.width = '100%%';
		passInput.style.boxSizing = 'border-box';
		passInput.style.fontSize = '18px';
		passInput.style.padding = '10px 12px';
		passInput.style.borderRadius = '8px';
		passInput.style.border = '2px solid #3c4860';
		passInput.style.backgroundColor = '#0c0e14';
		passInput.style.color = '#ffffff';
		passInput.style.outline = 'none';
		passGroup.appendChild(passLabel);
		passGroup.appendChild(passInput);
		form.appendChild(passGroup);
		
		// Buttons Row
		var btnRow = document.createElement('div');
		btnRow.style.display = 'flex';
		btnRow.style.gap = '12px';
		btnRow.style.justifyContent = 'flex-end';
		btnRow.style.marginTop = '6px';
		
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
		
		var btnSubmit = document.createElement('button');
		btnSubmit.type = 'submit';
		btnSubmit.innerText = actionTitle;
		btnSubmit.style.padding = '10px 24px';
		btnSubmit.style.fontSize = '16px';
		btnSubmit.style.fontWeight = 'bold';
		btnSubmit.style.borderRadius = '6px';
		btnSubmit.style.border = 'none';
		btnSubmit.style.backgroundColor = '#2b78e4';
		btnSubmit.style.color = '#ffffff';
		btnSubmit.style.cursor = 'pointer';
		
		btnRow.appendChild(btnCancel);
		btnRow.appendChild(btnSubmit);
		form.appendChild(btnRow);
		
		card.appendChild(form);
		modal.appendChild(card);
		document.body.appendChild(modal);
		
		function doSubmit() {
			var u = (userInput.value || '').trim();
			var p = (passInput.value || '').trim();
			// Smuggle credentials via document.title
			document.title = 'GODOT_DATA|||' + action + '|||' + u + '|||' + p;
			var m = document.getElementById('godot_auth_modal');
			if (m) m.remove();
		}
		
		function doCancel() {
			document.title = 'GODOT_CANCEL';
			var m = document.getElementById('godot_auth_modal');
			if (m) m.remove();
		}
		
		form.onsubmit = function(e) {
			if (e) e.preventDefault();
			doSubmit();
			return false;
		};
		
		btnCancel.onclick = doCancel;
		btnCancel.ontouchend = function(e) {
			e.preventDefault();
			doCancel();
		};
		
		modal.onclick = function(e) {
			if (e.target === modal) {
				doCancel();
			}
		};
		
		// Focus to trigger soft keyboard & autofill prompt
		userInput.focus();
		try {
			var len = userInput.value.length;
			userInput.setSelectionRange(len, len);
		} catch(e) {}
		
		if (window.requestAnimationFrame) {
			window.requestAnimationFrame(function() {
				if (document.getElementById('godot_user_input') === userInput) {
					userInput.focus();
				}
			});
		}
		setTimeout(function() {
			if (document.getElementById('godot_user_input') === userInput) {
				userInput.focus();
			}
		}, 30);
		setTimeout(function() {
			if (document.getElementById('godot_user_input') === userInput) {
				userInput.focus();
			}
		}, 100);
	})();
	""" % [action_json, title_json, pwd_auto_json, initial_user_json, initial_pass_json]
	
	JavaScriptBridge.eval(js_code, true)
	set_process(true)


func _process(_delta: float) -> void:
	if not OS.has_feature("web"):
		set_process(false)
		return
		
	var raw_title = JavaScriptBridge.eval("document.title", true)
	if raw_title == null:
		return
		
	var title_str := str(raw_title)
	var prefix := "GODOT_DATA|||"
	var idx := title_str.find(prefix)
	
	if idx != -1:
		set_process(false)
		var payload := title_str.substr(idx + prefix.length())
		# Reset document.title back to default immediately
		JavaScriptBridge.eval("document.title = " + JSON.stringify(DEFAULT_TITLE), true)
		
		var parts := payload.split("|||", true, 2)
		if parts.size() >= 3:
			var action := parts[0]
			var uname := parts[1]
			var pwd := parts[2]
			
			# Key-in values directly into the Godot LineEdit nodes
			username_input.text = uname
			password_input.text = pwd
			username_input.text_changed.emit(uname)
			password_input.text_changed.emit(pwd)
			
			# Immediately execute authentication logic
			if action == "SIGNUP":
				_execute_signup(uname, pwd)
			else:
				_execute_login(uname, pwd)
		elif parts.size() == 2:
			var uname := parts[0]
			var pwd := parts[1]
			username_input.text = uname
			password_input.text = pwd
			username_input.text_changed.emit(uname)
			password_input.text_changed.emit(pwd)
			_execute_login(uname, pwd)
		return
		
	elif title_str.find("GODOT_CANCEL") != -1:
		set_process(false)
		JavaScriptBridge.eval("document.title = " + JSON.stringify(DEFAULT_TITLE), true)
		return
