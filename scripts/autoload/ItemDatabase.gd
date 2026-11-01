extends Node

## ItemDatabase.gd
## Autoload singleton managing equipment and item statistics, parsing equipment_details.txt,
## and providing stage-based drop pools.

var items: Dictionary = {}
var tiers: Dictionary = {
	1: ["axe", "shield3", "helmet3", "armor3", "shoe3", "torch"],
	2: ["hammer", "shield4", "helmet4", "armor4", "shoe4", "torch"],
	3: ["sword", "shield5", "helmet5", "armor5", "shoe5", "diamond_amulet", "torch"]
}

func _ready() -> void:
	_init_default_database()
	_load_from_equipment_details()

func _init_default_database() -> void:
	# Built-in fallback database matching equipment_details.txt
	items = {
		"axe": {
			"id": "axe",
			"name": "Axe",
			"desc": "Attack +15",
			"slot": "w",
			"atk": 15.0,
			"def": 0.0,
			"cd": 0.0,
			"tier": 1,
			"price": 250,
			"texture_path": "res://graphic/axe.png"
		},
		"hammer": {
			"id": "hammer",
			"name": "Hammer",
			"desc": "Attack +25",
			"slot": "w",
			"atk": 25.0,
			"def": 0.0,
			"cd": 0.0,
			"tier": 2,
			"price": 800,
			"texture_path": "res://graphic/hammer.png"
		},
		"sword": {
			"id": "sword",
			"name": "Diamond Sword",
			"desc": "Attack +40",
			"slot": "w",
			"atk": 40.0,
			"def": 0.0,
			"cd": 0.0,
			"tier": 3,
			"price": 2000,
			"texture_path": "res://graphic/sword.png"
		},
		"shield3": {
			"id": "shield3",
			"name": "Wood Shield",
			"desc": "Defence +5",
			"slot": "shi",
			"atk": 0.0,
			"def": 5.0,
			"cd": 0.0,
			"tier": 1,
			"price": 170,
			"texture_path": "res://graphic/shield5.png"
		},
		"shield4": {
			"id": "shield4",
			"name": "Iron Shield",
			"desc": "Defence +7",
			"slot": "shi",
			"atk": 0.0,
			"def": 7.0,
			"cd": 0.0,
			"tier": 2,
			"price": 500,
			"texture_path": "res://graphic/shield3.png"
		},
		"shield5": {
			"id": "shield5",
			"name": "Diamond Shield",
			"desc": "Defence +10",
			"slot": "shi",
			"atk": 0.0,
			"def": 10.0,
			"cd": 0.0,
			"tier": 3,
			"price": 1400,
			"texture_path": "res://graphic/shield4.png"
		},
		"helmet3": {
			"id": "helmet3",
			"name": "Leather Helmet",
			"desc": "Defence +5",
			"slot": "h",
			"atk": 0.0,
			"def": 5.0,
			"cd": 0.0,
			"tier": 1,
			"price": 170,
			"texture_path": "res://graphic/helmet3.png"
		},
		"helmet4": {
			"id": "helmet4",
			"name": "Iron Helmet",
			"desc": "Defence +7",
			"slot": "h",
			"atk": 0.0,
			"def": 7.0,
			"cd": 0.0,
			"tier": 2,
			"price": 500,
			"texture_path": "res://graphic/helmet4.png"
		},
		"helmet5": {
			"id": "helmet5",
			"name": "Diamond Helmet",
			"desc": "Defence +10",
			"slot": "h",
			"atk": 0.0,
			"def": 10.0,
			"cd": 0.0,
			"tier": 3,
			"price": 1400,
			"texture_path": "res://graphic/helmet5.png"
		},
		"armor3": {
			"id": "armor3",
			"name": "Leather Armor",
			"desc": "Defence +5",
			"slot": "a",
			"atk": 0.0,
			"def": 5.0,
			"cd": 0.0,
			"tier": 1,
			"price": 250,
			"texture_path": "res://graphic/armor5.png"
		},
		"armor4": {
			"id": "armor4",
			"name": "Iron Armor",
			"desc": "Defence +7",
			"slot": "a",
			"atk": 0.0,
			"def": 7.0,
			"cd": 0.0,
			"tier": 2,
			"price": 750,
			"texture_path": "res://graphic/armor3.png"
		},
		"armor5": {
			"id": "armor5",
			"name": "Diamond Armor",
			"desc": "Defence +10",
			"slot": "a",
			"atk": 0.0,
			"def": 10.0,
			"cd": 0.0,
			"tier": 3,
			"price": 1800,
			"texture_path": "res://graphic/armor4.png"
		},
		"shoe3": {
			"id": "shoe3",
			"name": "Leather Boots",
			"desc": "Cd -0.5s",
			"slot": "sho",
			"atk": 0.0,
			"def": 0.0,
			"cd": 0.5,
			"tier": 1,
			"price": 160,
			"texture_path": "res://graphic/shoe3.png"
		},
		"shoe4": {
			"id": "shoe4",
			"name": "Iron Boots",
			"desc": "Cd -1.0s",
			"slot": "sho",
			"atk": 0.0,
			"def": 0.0,
			"cd": 1.0,
			"tier": 2,
			"price": 450,
			"texture_path": "res://graphic/shoe4.png"
		},
		"shoe5": {
			"id": "shoe5",
			"name": "Diamond Boots",
			"desc": "Cd -2.0s",
			"slot": "sho",
			"atk": 0.0,
			"def": 0.0,
			"cd": 2.0,
			"tier": 3,
			"price": 1400,
			"texture_path": "res://graphic/shoe5.png"
		},
		"torch": {
			"id": "torch",
			"name": "Torch",
			"desc": "Illuminates dark caves.",
			"slot": "tool",
			"atk": 0.0,
			"def": 0.0,
			"cd": 0.0,
			"tier": 1,
			"price": 50,
			"texture_path": "res://graphic/star.png"
		},
		"diamond_amulet": {
			"id": "diamond_amulet",
			"name": "Diamond Amulet",
			"desc": "Attack +15, Defence +15, CD -0.5s",
			"slot": "acc",
			"atk": 15.0,
			"def": 15.0,
			"cd": 0.5,
			"tier": 3,
			"price": 2500,
			"texture_path": "res://graphic/diamond.svg"
		}
	}

func _load_from_equipment_details() -> void:
	var path := "res://equipment_details.txt"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parts := line.split(",")
		if parts.size() >= 6:
			var id := parts[0].strip_edges()
			var img := "res://" + parts[1].strip_edges()
			var item_name := parts[2].strip_edges()
			if id == "sword":
				item_name = "Diamond Sword"
			var desc := parts[3].strip_edges()
			var stats := parts[4].strip_edges().split("/")
			var slot := parts[5].strip_edges()
			
			var atk_val := 0.0
			var def_val := 0.0
			var cd_val := 0.0
			if stats.size() >= 3:
				atk_val = float(stats[0])
				def_val = float(stats[1])
				cd_val = float(stats[2])
				
			var tier := 1
			if id.ends_with("4") or id == "hammer":
				tier = 2
			elif id.ends_with("5") or id == "sword":
				tier = 3
				
			var price_val := 100
			if parts.size() >= 7:
				price_val = int(parts[6].strip_edges())
			elif items.has(id) and items[id].has("price"):
				price_val = items[id]["price"]
				
			items[id] = {
				"id": id,
				"name": item_name,
				"desc": desc,
				"slot": slot,
				"atk": atk_val,
				"def": def_val,
				"cd": cd_val,
				"tier": tier,
				"price": price_val,
				"texture_path": img
			}

	# Ensure Diamond Amulet is always present
	if not items.has("diamond_amulet"):
		items["diamond_amulet"] = {
			"id": "diamond_amulet",
			"name": "Diamond Amulet",
			"desc": "Attack +15, Defence +15, CD -0.5s",
			"slot": "acc",
			"atk": 15.0,
			"def": 15.0,
			"cd": 0.5,
			"tier": 3,
			"price": 2500,
			"texture_path": "res://graphic/diamond.svg"
		}

func get_buy_price(id: String) -> int:
	var itm := get_item(id)
	if itm.has("price"):
		return int(itm["price"])
	return 100

func get_item(id: String) -> Dictionary:
	var clean_id: String = id.strip_edges()
	if items.has(clean_id):
		return items[clean_id].duplicate(true)
	# Check Diamond equipment aliases
	if (clean_id == "diamond_sword" or clean_id == "dsword") and items.has("sword"):
		return items["sword"].duplicate(true)
	if (clean_id == "diamond_armor" or clean_id == "darmor") and items.has("armor5"):
		return items["armor5"].duplicate(true)
	if (clean_id == "diamond_shield" or clean_id == "dshield") and items.has("shield5"):
		return items["shield5"].duplicate(true)
	if (clean_id == "diamond_helmet" or clean_id == "dhelmet") and items.has("helmet5"):
		return items["helmet5"].duplicate(true)
	if (clean_id == "diamond_boots" or clean_id == "dboots" or clean_id == "diamond_shoes") and items.has("shoe5"):
		return items["shoe5"].duplicate(true)
	return {}

func get_items_by_tier(tier: int) -> Array:
	if tiers.has(tier):
		return tiers[tier]
	return tiers[1]

func get_drop_for_stage(stage: int) -> Dictionary:
	var tier := 1
	if stage >= 13:
		tier = 3
	elif stage >= 6:
		tier = 2
	else:
		tier = 1
	var pool: Array = get_items_by_tier(tier)
	var random_id: String = pool[randi() % pool.size()]
	return get_item(random_id)

func is_upgradeable(id: String) -> bool:
	var itm := get_item(id)
	if itm.is_empty():
		return false
	var slot: String = itm.get("slot", "")
	return slot in ["w", "shi", "h", "a", "sho", "acc", "accessory"]

func get_item_display_name(item_input) -> String:
	var itm: Dictionary = {}
	var itm_id: String = ""
	var lvl: int = 1
	if typeof(item_input) == TYPE_DICTIONARY:
		itm = item_input
		itm_id = itm.get("id", "")
		lvl = itm.get("level", 1)
	elif typeof(item_input) == TYPE_STRING:
		itm_id = str(item_input).strip_edges()
		itm = get_item(itm_id)
		if get_node_or_null("/root/Global"):
			lvl = Global.get_item_upgrade_level(itm_id)
	if itm.is_empty():
		return itm_id
	var base_name: String = itm.get("name", itm_id)
	if is_upgradeable(itm_id) and lvl > 1:
		return "%s +%d" % [base_name, lvl - 1]
	return base_name

func get_upgraded_stats(item_input, level: int = -1) -> Dictionary:
	var itm: Dictionary = {}
	if typeof(item_input) == TYPE_DICTIONARY:
		itm = item_input
		if level < 0:
			level = itm.get("level", 1)
	elif typeof(item_input) == TYPE_STRING:
		itm = get_item(str(item_input))
		if level < 0:
			if get_node_or_null("/root/Global"):
				level = Global.get_item_upgrade_level(str(item_input))
			else:
				level = 1
	if itm.is_empty():
		return {}
	level = clampi(level, 1, 15)
	# Explicit base level: level 1 guarantees 100% exact base stats (0% bonus).
	# Each upgrade level above 1 adds +12% bonus stats.
	var bonus_levels: int = max(0, level - 1)
	var mult: float = 1.0 + 0.12 * float(bonus_levels)
	return {
		"atk": itm.get("atk", 0.0) * mult,
		"def": itm.get("def", 0.0) * mult,
		"cd": itm.get("cd", 0.0) * mult,
		"level": level,
		"multiplier": mult
	}

func get_sell_price(id: String) -> int:
	var itm := get_item(id)
	if itm.is_empty():
		return 10
	if id == "torch":
		return 20
	var tier: int = itm.get("tier", 1)
	var base_price: int = 80
	if tier == 2:
		base_price = 250
	elif tier == 3:
		base_price = 700
	var lvl: int = 0
	if get_node_or_null("/root/Global"):
		lvl = Global.get_item_upgrade_level(id)
	return base_price + (lvl * 50)

