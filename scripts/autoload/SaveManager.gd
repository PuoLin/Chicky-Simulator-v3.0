extends Node

## SaveManager.gd
## Manages persistence with user://save_game.json, tracking coins, diamonds,
## mission states, lifetime stats, and legacy Pygame user import.

const SAVE_PATH := "user://save_game.json"

func _ready() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[SaveManager] No existing save found. Attempting legacy import...")
		var imported := _try_import_legacy_txt()
		if imported:
			save_data(imported)
		else:
			save_data(_get_default_save())

func _get_default_save() -> Dictionary:
	return {
		"username": "Player",
		"highest_stage": 1,
		"coins": 0,
		"diamonds": 30,
		"pulls": 0,
		"total_kills": 0,
		"total_coins_earned": 0,
		"claimed_missions": [],
		"unlocked_achievements": [],
		"achievement_tiers": {"slayer": 0, "stage": 0, "rich": 0, "collector": 0, "hoarder": 0, "gacha_addict": 0, "speed_demon": 0, "iron_skin": 0, "survivor": 0},
		"max_survived_seconds": 0.0,
		"max_survived_stage_30_seconds": 0.0,
		"active_chick": "normal",
		"unlocked_chicks": ["normal"],
		"equipped": {
			"w": "axe",
			"shi": "no",
			"h": "no",
			"a": "no",
			"sho": "no"
		},
		"inventory": ["axe", "torch", "torch"],
		"item_upgrades": {},
		"master_volume": 0.8,
		"cleared_stages": []
	}

func get_save_path_for_user(uname: String) -> String:
	var clean := uname.strip_edges()
	if clean.is_empty() or clean == "Player":
		return SAVE_PATH
	var safe := clean.validate_filename()
	if safe.is_empty():
		return SAVE_PATH
	return "user://save_%s.json" % safe

func load_data(uname: String = "") -> Dictionary:
	var path := ""
	if not uname.is_empty() and uname != "Player":
		var user_specific_path := get_save_path_for_user(uname)
		if FileAccess.file_exists(user_specific_path):
			path = user_specific_path
		elif FileAccess.file_exists(SAVE_PATH):
			var main_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
			if main_file:
				var parsed = JSON.parse_string(main_file.get_as_text())
				if typeof(parsed) == TYPE_DICTIONARY and parsed.get("username", "") == uname:
					path = SAVE_PATH
	else:
		if FileAccess.file_exists(SAVE_PATH):
			path = SAVE_PATH

	if path.is_empty() or not FileAccess.file_exists(path):
		var def := _get_default_save()
		if not uname.is_empty():
			def["username"] = uname
		return def

		
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		var def := _get_default_save()
		if not uname.is_empty():
			def["username"] = uname
		return def
		
	var content := file.get_as_text()
	var parsed = JSON.parse_string(content)
	if typeof(parsed) == TYPE_DICTIONARY:
		# Ensure default keys exist for backwards compatibility
		var defaults := _get_default_save()
		if not uname.is_empty():
			defaults["username"] = uname
		for key in defaults.keys():
			if not parsed.has(key):
				parsed[key] = defaults[key]
		return parsed
		
	var def := _get_default_save()
	if not uname.is_empty():
		def["username"] = uname
	return def

func save_data(data: Dictionary) -> void:
	var uname: String = data.get("username", "")
	var user_path := get_save_path_for_user(uname)
	if user_path != SAVE_PATH:
		var ufile := FileAccess.open(user_path, FileAccess.WRITE)
		if ufile:
			ufile.store_string(JSON.stringify(data, "\t"))

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


func _try_import_legacy_txt() -> Dictionary:
	var details_path := "res://user_details.txt"
	var backpack_path := "res://user_backpack.txt"
	if not FileAccess.file_exists(details_path):
		return {}

	var file := FileAccess.open(details_path, FileAccess.READ)
	if not file:
		return {}

	var target_user := {}
	# Choose user with highest level or first valid user
	var best_lvl := 0
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parts := line.split(", ")
		if parts.size() >= 8:
			var uname := parts[0]
			var lvl := int(parts[2])
			var coins := int(parts[4])
			var pulls := int(parts[5])
			var chick := parts[6]
			var equip_parts := parts[7].split("/")
			
			if lvl > best_lvl or target_user.is_empty():
				best_lvl = lvl
				var equip_dict := {
					"w": equip_parts[0] if equip_parts.size() > 0 else "no",
					"shi": equip_parts[1] if equip_parts.size() > 1 else "no",
					"h": equip_parts[2] if equip_parts.size() > 2 else "no",
					"a": equip_parts[3] if equip_parts.size() > 3 else "no",
					"sho": equip_parts[4] if equip_parts.size() > 4 else "no"
				}
				target_user = {
					"username": uname,
					"highest_stage": max(1, lvl),
					"coins": coins,
					"diamonds": 50,
					"pulls": pulls,
					"total_kills": 0,
					"total_coins_earned": coins,
					"claimed_missions": [],
					"unlocked_achievements": [],
					"achievement_tiers": {"slayer": 0, "stage": 0, "rich": 0, "collector": 0, "hoarder": 0, "gacha_addict": 0, "speed_demon": 0, "iron_skin": 0, "survivor": 0},
					"max_survived_seconds": 0.0,
					"max_survived_stage_30_seconds": 0.0,
					"active_chick": chick,
					"unlocked_chicks": [chick],
					"equipped": equip_dict,
					"inventory": ["torch", "torch"],
					"master_volume": 0.8,
					"cleared_stages": []
				}

	if target_user.is_empty():
		return {}

	# Load inventory from user_backpack.txt
	if FileAccess.file_exists(backpack_path):
		var bp_file := FileAccess.open(backpack_path, FileAccess.READ)
		if bp_file:
			while not bp_file.eof_reached():
				var bp_line := bp_file.get_line().strip_edges()
				if bp_line.is_empty():
					continue
				var bp_parts := bp_line.split(", ")
				if bp_parts.size() >= 3 and bp_parts[0] == target_user["username"]:
					# chicks unlocked
					var chick_list := bp_parts[1].split("/")
					for c in chick_list:
						if c != "0" and not target_user["unlocked_chicks"].has(c):
							target_user["unlocked_chicks"].append(c)
					# inventory items
					var inv_items := bp_parts[2].split("/")
					for itm in inv_items:
						if itm != "no" and not itm.is_empty():
							target_user["inventory"].append(itm)

	print("[SaveManager] Successfully auto-imported user: ", target_user["username"], " (Stage: ", target_user["highest_stage"], ", Coins: ", target_user["coins"], ")")
	return target_user
