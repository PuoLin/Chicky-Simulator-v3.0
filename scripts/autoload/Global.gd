extends Node

## Global.gd
## Central game manager holding session state, active player stats,
## stage progression, dual currencies (Coins & Diamonds), meta progression,
## and broadcasting game events.

signal coins_changed(new_coins: int)
signal diamonds_changed(new_diamonds: int)
signal kill_count_changed(current: int, target: int)
signal torch_fuel_changed(current_fuel: float, max_fuel: float, is_active: bool, is_unlimited: bool)
signal inventory_updated()
signal stage_completed(stage: int, coins_earned: int, time_spent: float)
signal player_died()
signal mission_claimed(mission_id: String)
signal achievement_unlocked(achievement_id: String)
signal achievement_claimed(track_id: String, tier_index: int, reward: int)

var username: String = "Player"
var highest_stage: int = 1
var current_stage: int = 1
var coins: int = 0
var diamonds: int = 30
var pulls: int = 0
var total_kills: int = 0
var total_coins_earned: int = 0
var claimed_missions: Array = []
var unlocked_achievements: Array = []
var achievement_tiers: Dictionary = {"slayer": 0, "stage": 0, "rich": 0, "collector": 0, "hoarder": 0, "gacha_addict": 0, "speed_demon": 0, "iron_skin": 0, "survivor": 0}
var max_survived_seconds: float = 0.0
var max_survived_stage_30_seconds: float = 0.0
var speed_demon_cleared: bool = false
var iron_skin_cleared: bool = false
var cleared_stages: Array = []

var active_chick: String = "normal"
var unlocked_chicks: Array = ["normal"]
var equipped: Dictionary = {
	"w": "axe",
	"shi": "no",
	"h": "no",
	"a": "no",
	"sho": "no"
}
var inventory: Array = []
var item_upgrades: Dictionary = {}

var kill_count: int = 0
var target_kills: int = 0
var stage_time: float = 0.0
var stage_active: bool = false

# Chick base stats definitions
const CHICK_STATS := {
	"normal": {
		"name": "Normal Chick",
		"hp": 100.0, "def": 0.0, "atk": 15.0, "cd": 4.0, "mag": 0.0, "speed": 180.0,
		"lore": "The brave, plucky adventurer who started it all. Well-balanced and reliable in any cave exploration.",
		"portrait": "res://graphic/chicky.png"
	},
	"kitty": {
		"name": "Kitty Chick",
		"hp": 150.0, "def": 0.0, "atk": 14.0, "cd": 4.0, "mag": 0.0, "speed": 180.0,
		"lore": "A gentle feline-inspired chick blessed with high vital energy. Starts with an impressive 150 HP pool.",
		"portrait": "res://graphic/miaoji.png"
	},
	"worrier": {
		"name": "Ninja Chick",
		"hp": 75.0, "def": 0.0, "atk": 25.0, "cd": 3.5, "mag": 0.0, "speed": 210.0,
		"lore": "Trained in the ancient art of shadows. Deals devastating melee damage with rapid attack speeds.",
		"portrait": "res://graphic/ninjachic.png"
	},
	"magnet": {
		"name": "Richie Chick",
		"hp": 100.0, "def": 0.0, "atk": 15.0, "cd": 4.0, "mag": 1.0, "speed": 180.0,
		"lore": "Obsessed with treasure! Features a strong magnetic aura that pulls coins from afar and grants +30% gold rewards.",
		"portrait": "res://graphic/magnetchic.png"
	},
	"speedy": {
		"name": "Speedy Chick",
		"hp": 75.0, "def": 0.0, "atk": 15.0, "cd": 3.0, "mag": 0.0, "speed": 250.0,
		"lore": "Light on its feet and lightning fast. Zips across the cave floor with a blazing 250 move speed.",
		"portrait": "res://graphic/speedychic.png"
	},
	"tanker": {
		"name": "Tanker Chick",
		"hp": 200.0, "def": 0.0, "atk": 15.0, "cd": 5.0, "mag": 0.0, "speed": 140.0,
		"lore": "A hulking behemoth clad in thick feathers. Absorbs relentless punishment with a massive 200 HP pool.",
		"portrait": "res://graphic/tank chic.png"
	},
	"pink": {
		"name": "Pink Chick",
		"hp": 120.0, "def": 5.0, "atk": 16.0, "cd": 3.8, "mag": 0.0, "speed": 190.0,
		"lore": "A cheerful, pastel-feathered hero with innate defense and charm. Naturally resilient in harsh environments.",
		"portrait": "res://graphic/pinkchic.png"
	},
	"geek": {
		"name": "Geek Chick",
		"hp": 90.0, "def": 0.0, "atk": 22.0, "cd": 3.2, "mag": 0.5, "speed": 195.0,
		"lore": "A hyper-intelligent strategist who calculates enemy trajectories and attacks with surgical precision.",
		"portrait": "res://graphic/geekchic.png"
	},
	"kun": {
		"name": "Kun Chick",
		"hp": 110.0, "def": 8.0, "atk": 20.0, "cd": 3.6, "mag": 0.0, "speed": 200.0,
		"lore": "Master of rhythm, agility, and martial arts. Swift maneuvers make it elusive and tough to hit.",
		"portrait": "res://graphic/kunchic.png"
	}
}

func _ready() -> void:
	load_player_data()

func load_player_data() -> void:
	var data := SaveManager.load_data(username)
	username = data.get("username", username if not username.is_empty() else "Player")
	highest_stage = data.get("highest_stage", 1)
	coins = data.get("coins", 500)
	diamonds = data.get("diamonds", 30)
	pulls = data.get("pulls", 0)
	total_kills = data.get("total_kills", 0)
	total_coins_earned = data.get("total_coins_earned", coins)
	claimed_missions = data.get("claimed_missions", [])
	unlocked_achievements = data.get("unlocked_achievements", [])
	achievement_tiers = data.get("achievement_tiers", {"slayer": 0, "stage": 0, "rich": 0, "collector": 0, "hoarder": 0, "gacha_addict": 0, "speed_demon": 0, "iron_skin": 0, "survivor": 0})
	if not achievement_tiers.has("survivor"):
		achievement_tiers["survivor"] = 0
	max_survived_seconds = float(data.get("max_survived_seconds", 0.0))
	max_survived_stage_30_seconds = float(data.get("max_survived_stage_30_seconds", 0.0))
	speed_demon_cleared = data.get("speed_demon_cleared", false)
	iron_skin_cleared = data.get("iron_skin_cleared", false)
	
	cleared_stages = []
	for s in data.get("cleared_stages", []):
		cleared_stages.append(int(s))
	if cleared_stages.is_empty() and highest_stage > 1:
		for s in range(1, highest_stage):
			cleared_stages.append(s)
	
	active_chick = data.get("active_chick", "normal")
	if active_chick in ["pink", "pinky", "geek", "kun"]:
		active_chick = "normal"
	unlocked_chicks = data.get("unlocked_chicks", ["normal"])
	for cs in ["pink", "pinky", "geek", "kun"]:
		unlocked_chicks.erase(cs)
	if not unlocked_chicks.has("normal"):
		unlocked_chicks.append("normal")
	equipped = data.get("equipped", {
		"w": "axe", "shi": "no", "h": "no", "a": "no", "sho": "no"
	})
	inventory = data.get("inventory", ["axe", "torch", "torch"])
	item_upgrades = {}
	var raw_upgrades = data.get("item_upgrades", {})
	if raw_upgrades is Dictionary:
		for k in raw_upgrades.keys():
			item_upgrades[str(k)] = clampi(int(raw_upgrades[k]), 0, 15)

	var vol: float = data.get("master_volume", 0.8)
	AudioManager.set_master_volume(vol)
	
	emit_signal("coins_changed", coins)
	emit_signal("diamonds_changed", diamonds)
	emit_signal("inventory_updated")

func save_player_data() -> void:
	var data := {
		"username": username,
		"highest_stage": highest_stage,
		"coins": coins,
		"diamonds": diamonds,
		"pulls": pulls,
		"total_kills": total_kills,
		"total_coins_earned": total_coins_earned,
		"claimed_missions": claimed_missions,
		"unlocked_achievements": unlocked_achievements,
		"achievement_tiers": achievement_tiers,
		"max_survived_seconds": max_survived_seconds,
		"max_survived_stage_30_seconds": max_survived_stage_30_seconds,
		"speed_demon_cleared": speed_demon_cleared,
		"iron_skin_cleared": iron_skin_cleared,
		"cleared_stages": cleared_stages,
		"active_chick": active_chick,
		"unlocked_chicks": unlocked_chicks,
		"equipped": equipped,
		"inventory": inventory,
		"item_upgrades": item_upgrades,
		"master_volume": AudioManager.get_master_volume()
	}
	SaveManager.save_data(data)

func is_stage_cleared(stage_num: int) -> bool:
	for s in cleared_stages:
		if int(s) == stage_num:
			return true
	return false

func mark_stage_cleared(stage_num: int) -> bool:
	var first_time := not is_stage_cleared(stage_num)
	if first_time:
		cleared_stages.append(int(stage_num))
		save_player_data()
	return first_time

func init_stage(stage: int) -> void:
	current_stage = stage
	kill_count = 0
	stage_time = 0.0
	stage_active = true
	
	# Stage Kill Quotas scaled across 30 stages
	if stage <= 5:
		target_kills = 5
	elif stage <= 10:
		target_kills = 8
	elif stage <= 15:
		target_kills = 10
	elif stage <= 20:
		target_kills = 12
	elif stage <= 25:
		target_kills = 15
	else:
		target_kills = 18
		
	emit_signal("kill_count_changed", kill_count, target_kills)

func add_kill() -> void:
	kill_count += 1
	total_kills += 1
	emit_signal("kill_count_changed", kill_count, target_kills)
	check_achievements()
	save_player_data()

func add_coins(amount: int) -> void:
	if active_chick == "magnet":
		amount = int(amount * 1.3)
	coins += amount
	total_coins_earned += amount
	emit_signal("coins_changed", coins)
	check_achievements()
	save_player_data()

func spend_coins(amount: int) -> bool:
	if coins >= amount:
		coins -= amount
		emit_signal("coins_changed", coins)
		save_player_data()
		return true
	return false

func add_diamonds(amount: int) -> void:
	diamonds += amount
	emit_signal("diamonds_changed", diamonds)
	save_player_data()

func spend_diamonds(amount: int) -> bool:
	if diamonds >= amount:
		diamonds -= amount
		emit_signal("diamonds_changed", diamonds)
		save_player_data()
		return true
	return false

func add_pulls(count: int) -> void:
	pulls += count
	check_achievements()
	save_player_data()

func record_stage_clear(time_spent: float, damage_taken: float) -> void:
	if time_spent > 0.0 and time_spent <= 30.0:
		speed_demon_cleared = true
	if damage_taken <= 0.0:
		iron_skin_cleared = true
	check_achievements()
	save_player_data()

func record_survival_time(stage_num: int, elapsed: float) -> void:
	if elapsed > max_survived_seconds:
		max_survived_seconds = elapsed
	if stage_num == 30 and elapsed > max_survived_stage_30_seconds:
		max_survived_stage_30_seconds = elapsed
	check_achievements()
	save_player_data()

func unlock_character(chick_key: String) -> bool:
	if chick_key in ["pink", "pinky", "geek", "kun"]:
		return false
	if not unlocked_chicks.has(chick_key):
		unlocked_chicks.append(chick_key)
		check_achievements()
		save_player_data()
		return true
	return false

func claim_mission(mission_id: String, reward_amount: int, reward_type: String = "diamonds") -> bool:
	if not claimed_missions.has(mission_id):
		claimed_missions.append(mission_id)
		if reward_type == "coins":
			add_coins(reward_amount)
		else:
			add_diamonds(reward_amount)
		emit_signal("mission_claimed", mission_id)
		save_player_data()
		return true
	return false

func claim_achievement_tier(track_id: String, tier_index: int, reward: int) -> bool:
	if not achievement_tiers.has(track_id):
		achievement_tiers[track_id] = 0
	if achievement_tiers[track_id] == tier_index:
		achievement_tiers[track_id] = tier_index + 1
		add_diamonds(reward)
		emit_signal("achievement_claimed", track_id, tier_index, reward)
		PlatformManager.unlock_achievement("%s_tier_%d" % [track_id, tier_index + 1])
		save_player_data()
		return true
	return false

func check_achievements() -> void:
	var to_check := [
		{"id": "achieve_first_blood", "cond": total_kills >= 1},
		{"id": "achieve_slayer_50", "cond": total_kills >= 50},
		{"id": "achieve_slayer_200", "cond": total_kills >= 200},
		{"id": "achieve_stage_5", "cond": highest_stage >= 5},
		{"id": "achieve_stage_10", "cond": highest_stage >= 10},
		{"id": "achieve_stage_20", "cond": highest_stage >= 20},
		{"id": "achieve_stage_30", "cond": highest_stage >= 30},
		{"id": "achieve_rich", "cond": total_coins_earned >= 5000},
		{"id": "achieve_collector", "cond": unlocked_chicks.size() >= 4},
		{"id": "achieve_speed_demon", "cond": speed_demon_cleared},
		{"id": "achieve_iron_skin", "cond": iron_skin_cleared},
		{"id": "achieve_gacha_10", "cond": pulls >= 10},
		{"id": "achieve_gacha_50", "cond": pulls >= 50},
		{"id": "achieve_gacha_100", "cond": pulls >= 100},
		{"id": "achieve_hoarder_1k", "cond": total_coins_earned >= 1000},
		{"id": "achieve_hoarder_5k", "cond": total_coins_earned >= 5000},
		{"id": "achieve_hoarder_10k", "cond": total_coins_earned >= 10000},
		{"id": "achieve_survivor_t1", "cond": max_survived_seconds >= 30.0},
		{"id": "achieve_survivor_t2", "cond": max_survived_seconds >= 60.0},
		{"id": "achieve_survivor_t3", "cond": max_survived_seconds >= 90.0},
		{"id": "achieve_survivor_t4", "cond": max_survived_stage_30_seconds >= 120.0}
	]
	
	for entry in to_check:
		if entry["cond"] and not unlocked_achievements.has(entry["id"]):
			unlocked_achievements.append(entry["id"])
			emit_signal("achievement_unlocked", entry["id"])
			PlatformManager.unlock_achievement(entry["id"])
			save_player_data()

func add_inventory_item(item_id: String) -> bool:
	inventory.append(item_id)
	emit_signal("inventory_updated")
	save_player_data()
	return true

func remove_inventory_item(item_id: String) -> bool:
	var idx := inventory.find(item_id)
	if idx != -1:
		inventory.remove_at(idx)
		emit_signal("inventory_updated")
		save_player_data()
		return true
	return false

func count_inventory_item(item_id: String) -> int:
	var count := 0
	for itm in inventory:
		if itm == item_id:
			count += 1
	return count

func equip_item(item_id: String) -> void:
	var item_data := ItemDatabase.get_item(item_id)
	if item_data.is_empty():
		return
	var slot: String = item_data.get("slot", "")
	if not equipped.has(slot):
		return
		
	var currently_equipped: String = equipped[slot]
	if currently_equipped != "no" and not currently_equipped.is_empty():
		inventory.append(currently_equipped)
		
	remove_inventory_item(item_id)
	equipped[slot] = item_id
	save_player_data()
	emit_signal("inventory_updated")

func unequip_item(slot: String) -> void:
	if not equipped.has(slot):
		return
	var currently_equipped: String = equipped[slot]
	if currently_equipped != "no" and not currently_equipped.is_empty():
		inventory.append(currently_equipped)
		equipped[slot] = "no"
		save_player_data()
		emit_signal("inventory_updated")

func get_player_stats() -> Dictionary:
	var base: Dictionary = CHICK_STATS.get(active_chick, CHICK_STATS["normal"]).duplicate()
	var total_hp: float = base["hp"]
	var total_def: float = base["def"]
	var total_atk: float = base["atk"]
	var total_cd: float = base["cd"]
	var speed: float = base["speed"]

	for slot in equipped.keys():
		var eq_id: String = equipped[slot]
		if eq_id != "no" and not eq_id.is_empty():
			var itm: Dictionary = ItemDatabase.get_item(eq_id)
			if not itm.is_empty():
				var up_lvl: int = get_item_upgrade_level(eq_id)
				var mult: float = 1.0 + 0.05 * float(up_lvl)
				total_atk += itm.get("atk", 0.0) * mult
				total_def += itm.get("def", 0.0) * mult
				total_cd = max(0.5, total_cd - (itm.get("cd", 0.0) * mult))

	return {
		"max_hp": total_hp,
		"max_def": total_def,
		"atk": total_atk,
		"cd": total_cd,
		"speed": speed,
		"magnet": base["mag"]
	}

func get_item_upgrade_level(item_id: String) -> int:
	var clean_id: String = item_id.strip_edges()
	return clampi(int(item_upgrades.get(clean_id, 0)), 0, 15)

func is_item_equipped(item_id: String) -> bool:
	var clean_id: String = item_id.strip_edges()
	for slot in equipped.keys():
		if equipped[slot] == clean_id:
			return true
	return false

func get_upgrade_info(item_id: String) -> Dictionary:
	var clean_id: String = item_id.strip_edges()
	var itm: Dictionary = ItemDatabase.get_item(clean_id)
	if itm.is_empty() or not ItemDatabase.is_upgradeable(clean_id):
		return {"can_upgrade": false, "reason": "Not upgradeable"}
	
	var current_lvl: int = get_item_upgrade_level(clean_id)
	if current_lvl >= 15:
		return {
			"can_upgrade": false,
			"reason": "Max level (+15) reached",
			"current_level": 15,
			"next_level": 15,
			"has_duplicate": false,
			"duplicate_count": 0,
			"coin_cost": 0,
			"max_reached": true
		}
	
	var next_lvl: int = current_lvl + 1
	var inv_count: int = count_inventory_item(clean_id)
	var is_eq: bool = is_item_equipped(clean_id)
	var duplicate_count: int = inv_count if is_eq else max(0, inv_count - 1)
	var has_duplicate: bool = duplicate_count > 0
	
	# Upgrade cost formula:
	# Requires 1 duplicate copy + 50 * next_lvl Coins
	var coin_cost: int = 50 * next_lvl
	var can_afford: bool = coins >= coin_cost
	var can_upgrade: bool = has_duplicate and can_afford
	
	var reason: String = "Ready to upgrade"
	if not has_duplicate:
		reason = "Requires 1 unequipped duplicate in inventory"
	elif not can_afford:
		reason = "Need %d coins" % coin_cost
		
	return {
		"can_upgrade": can_upgrade,
		"current_level": current_lvl,
		"next_level": next_lvl,
		"has_duplicate": has_duplicate,
		"duplicate_count": duplicate_count,
		"coin_cost": coin_cost,
		"reason": reason,
		"max_reached": false
	}

func upgrade_item(item_id: String) -> Dictionary:
	var clean_id: String = item_id.strip_edges()
	var info: Dictionary = get_upgrade_info(clean_id)
	if not info.get("can_upgrade", false):
		return {"success": false, "reason": info.get("reason", "Cannot upgrade")}
	
	# Explicitly verify unequipped duplicate in inventory
	var inv_idx := inventory.find(clean_id)
	if inv_idx == -1:
		return {"success": false, "reason": "No unequipped duplicate found in inventory"}

	var is_eq: bool = is_item_equipped(clean_id)
	if not is_eq and count_inventory_item(clean_id) < 2:
		return {"success": false, "reason": "Requires at least 1 spare duplicate in inventory"}

	var coin_cost: int = info["coin_cost"]
	if not spend_coins(coin_cost):
		return {"success": false, "reason": "Not enough coins"}
		
	# Explicitly remove/consume one instance of that duplicate item from inventory
	inventory.remove_at(inv_idx)
	
	var current_lvl: int = info["current_level"]
	item_upgrades[clean_id] = current_lvl + 1
	save_player_data()
	emit_signal("inventory_updated")
	return {
		"success": true,
		"new_level": current_lvl + 1,
		"reason": "Upgraded to +%d!" % (current_lvl + 1)
	}

func clear_session() -> void:
	username = "Player"
	highest_stage = 1
	current_stage = 1
	coins = 0
	diamonds = 30
	pulls = 0
	total_kills = 0
	total_coins_earned = 0
	claimed_missions = []
	unlocked_achievements = []
	achievement_tiers = {"slayer": 0, "stage": 0, "rich": 0, "collector": 0, "hoarder": 0, "gacha_addict": 0, "speed_demon": 0, "iron_skin": 0, "survivor": 0}
	max_survived_seconds = 0.0
	max_survived_stage_30_seconds = 0.0
	speed_demon_cleared = false
	iron_skin_cleared = false
	cleared_stages = []
	active_chick = "normal"
	unlocked_chicks = ["normal"]
	equipped = {
		"w": "axe",
		"shi": "no",
		"h": "no",
		"a": "no",
		"sho": "no"
	}
	inventory = ["axe", "torch", "torch"]
	item_upgrades = {}
	kill_count = 0
	target_kills = 0
	stage_time = 0.0
	stage_active = false
	emit_signal("coins_changed", coins)
	emit_signal("diamonds_changed", diamonds)
	emit_signal("inventory_updated")

func set_active_user(user_name: String) -> void:
	clear_session()
	username = user_name.strip_edges()
	load_player_data()
	username = user_name.strip_edges()


func sell_item(item_id: String) -> Dictionary:
	var clean_id: String = item_id.strip_edges()
	var inv_count: int = count_inventory_item(clean_id)
	if inv_count <= 0:
		return {"success": false, "reason": "No copies in backpack to sell"}
		
	var price: int = ItemDatabase.get_sell_price(clean_id)
	remove_inventory_item(clean_id)
	add_coins(price)
	save_player_data()
	emit_signal("inventory_updated")
	return {
		"success": true,
		"earned_coins": price,
		"reason": "Sold for %d Coins" % price
	}

