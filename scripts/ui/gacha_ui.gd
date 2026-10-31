extends Control
class_name GachaUI

## gacha_ui.gd
## Mixed-pool Gacha system: spend Diamonds to roll for Chick heroes (duplicate converts to Coins)
## and various Coin bundles (50, 150, 300, 600 Coins).
## Features a prominent centered showcase, 1x/5x roll buttons, and real-time Diamond sync.

@onready var close_btn: Button = $CenterContainer/Panel/CloseButton
@onready var diamond_label: Label = $CenterContainer/Panel/TopBar/DiamondLabel
@onready var pull_1_btn: Button = $CenterContainer/Panel/MainVBox/RollButtons/Pull1Button
@onready var pull_5_btn: Button = $CenterContainer/Panel/MainVBox/RollButtons/Pull5Button
@onready var status_label: Label = $CenterContainer/Panel/MainVBox/StatusLabel

# Prominent Centered Showcase
@onready var showcase_placeholder: VBoxContainer = $CenterContainer/Panel/MainVBox/ShowcasePanel/PlaceholderVBox
@onready var showcase_results: HBoxContainer = $CenterContainer/Panel/MainVBox/ShowcasePanel/ResultsHBox

const SINGLE_COST := 10
const FIVE_COST := 45
const DUPLICATE_COIN_PAYOUT := 300

# Mixed Reward Pool: exactly 25% Chick Characters (upgraded variants only), 75% Coin Bundles
const MIXED_POOL := [
	# Upgraded Hero Characters (Total Weight = 25: 5% each for 5 finished variants)
	{"type": "chick", "id": "kitty", "weight": 5, "rarity": "Rare"},
	{"type": "chick", "id": "magnet", "weight": 5, "rarity": "Rare"},
	{"type": "chick", "id": "speedy", "weight": 5, "rarity": "Rare"},
	{"type": "chick", "id": "worrier", "weight": 5, "rarity": "Epic"},
	{"type": "chick", "id": "tanker", "weight": 5, "rarity": "Epic"},

	# Coin Bundles (Total Weight = 75)
	{"type": "coins", "id": "coin_50", "amount": 50, "name": "Coin Pouch", "icon": "res://graphic/coin.png", "weight": 30, "rarity": "Common"},
	{"type": "coins", "id": "coin_150", "amount": 150, "name": "Coin Sack", "icon": "res://graphic/coin2.png", "weight": 25, "rarity": "Uncommon"},
	{"type": "coins", "id": "coin_300", "amount": 300, "name": "Treasure Chest", "icon": "res://graphic/itemcoin.png", "weight": 15, "rarity": "Rare"},
	{"type": "coins", "id": "coin_600", "amount": 600, "name": "Jackpot Stash", "icon": "res://graphic/manycoin.png", "weight": 5, "rarity": "Epic"}
]

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(toggle)
	pull_1_btn.pressed.connect(func(): _do_pull(1, SINGLE_COST))
	pull_5_btn.pressed.connect(func(): _do_pull(5, FIVE_COST))
	
	Global.diamonds_changed.connect(_on_diamonds_changed)
	_on_diamonds_changed(Global.diamonds)
	_reset_showcase()

func toggle() -> void:
	visible = not visible
	if visible:
		status_label.text = ""
		_on_diamonds_changed(Global.diamonds)
		_reset_showcase()

func _on_diamonds_changed(amount: int) -> void:
	if diamond_label:
		diamond_label.text = "Diamonds: %d 💎" % amount

func _reset_showcase() -> void:
	showcase_placeholder.visible = true
	showcase_results.visible = false
	for child in showcase_results.get_children():
		showcase_results.remove_child(child)
		child.queue_free()

func _do_pull(count: int, cost: int) -> void:
	if not Global.spend_diamonds(cost):
		status_label.text = "Not enough Diamonds! Need %d 💎" % cost
		status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))
		return
		
	Global.add_pulls(count)
	status_label.text = ""
	var pulled_results: Array = []
	
	for i in range(count):
		var rolled_entry := _pick_random_item()
		if rolled_entry["type"] == "chick":
			var chick_id: String = rolled_entry["id"]
			var was_new := Global.unlock_character(chick_id)
			if not was_new:
				Global.add_coins(DUPLICATE_COIN_PAYOUT)
			pulled_results.append({
				"type": "chick",
				"id": chick_id,
				"is_new": was_new,
				"rarity": rolled_entry["rarity"]
			})
		else: # coins
			var coin_amt: int = rolled_entry["amount"]
			Global.add_coins(coin_amt)
			pulled_results.append({
				"type": "coins",
				"id": rolled_entry["id"],
				"amount": coin_amt,
				"name": rolled_entry["name"],
				"icon": rolled_entry["icon"],
				"rarity": rolled_entry["rarity"]
			})
		
	_display_results(pulled_results)

func _pick_random_item() -> Dictionary:
	var total_weight := 0
	for entry in MIXED_POOL:
		total_weight += entry["weight"]
		
	var roll := randi_range(1, total_weight)
	var current := 0
	for entry in MIXED_POOL:
		current += entry["weight"]
		if roll <= current:
			return entry
	return MIXED_POOL[0]

func _display_results(results: Array) -> void:
	for child in showcase_results.get_children():
		showcase_results.remove_child(child)
		child.queue_free()
		
	showcase_placeholder.visible = false
	showcase_results.visible = true
	
	for res in results:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(140, 210)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 6)
		
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(64, 64)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var name_lbl := Label.new()
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		var rarity_lbl := Label.new()
		var rarity_str: String = res.get("rarity", "Common")
		rarity_lbl.text = rarity_str
		rarity_lbl.add_theme_font_size_override("font_size", 15)
		rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_apply_rarity_color(rarity_lbl, rarity_str)
		
		var tag_lbl := Label.new()
		tag_lbl.add_theme_font_size_override("font_size", 16)
		tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		if res["type"] == "chick":
			var chick_id: String = res["id"]
			var info: Dictionary = Global.CHICK_STATS.get(chick_id, Global.CHICK_STATS["normal"])
			name_lbl.text = info.get("name", chick_id)
			var portrait_path: String = info.get("portrait", "")
			if ResourceLoader.exists(portrait_path):
				icon.texture = load(portrait_path)
			if res["is_new"]:
				tag_lbl.text = "NEW HERO!"
				tag_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1.0))
			else:
				tag_lbl.text = "+%d Coins" % DUPLICATE_COIN_PAYOUT
				tag_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1.0))
		else:
			name_lbl.text = res["name"]
			var coin_icon_path: String = res["icon"]
			if ResourceLoader.exists(coin_icon_path):
				icon.texture = load(coin_icon_path)
			tag_lbl.text = "+%d Coins 🪙" % res["amount"]
			tag_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
			
		vbox.add_child(icon)
		vbox.add_child(name_lbl)
		vbox.add_child(rarity_lbl)
		vbox.add_child(tag_lbl)
		
		card.add_child(vbox)
		showcase_results.add_child(card)

func _apply_rarity_color(lbl: Label, rarity: String) -> void:
	match rarity:
		"Epic":
			lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 1.0, 1.0))
		"Rare":
			lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0, 1.0))
		"Uncommon":
			lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4, 1.0))
		_:
			lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
