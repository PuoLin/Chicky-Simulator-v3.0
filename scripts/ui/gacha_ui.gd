extends Control
class_name GachaUI

## gacha_ui.gd
## Mixed-pool Gacha system: spend Diamonds to roll for Chick heroes (duplicate converts to Coins)
## and various Coin bundles (50, 150, 300, 600 Coins).
## Features a prominent centered showcase, 1x/5x roll buttons, and real-time Diamond sync.

@onready var close_btn: Button = $CenterContainer/Panel/CloseButton
@onready var diamond_label: Label = get_node_or_null("CenterContainer/Panel/TopBar/DiamondContainer/DiamondLabel") if get_node_or_null("CenterContainer/Panel/TopBar/DiamondContainer/DiamondLabel") else get_node_or_null("CenterContainer/Panel/TopBar/DiamondLabel")
@onready var pull_1_btn: Button = $CenterContainer/Panel/MainVBox/RollButtons/Pull1Button
@onready var pull_5_btn: Button = $CenterContainer/Panel/MainVBox/RollButtons/Pull5Button
@onready var status_label: Label = $CenterContainer/Panel/MainVBox/StatusLabel

# Prominent Centered Showcase
@onready var showcase_placeholder: VBoxContainer = $CenterContainer/Panel/MainVBox/ShowcasePanel/PlaceholderVBox
@onready var showcase_results: HBoxContainer = $CenterContainer/Panel/MainVBox/ShowcasePanel/ResultsHBox
@onready var gacha_animator: AnimatedSprite2D = get_node_or_null("CenterContainer/Panel/GachaAnimator")
@onready var animation_player: AnimationPlayer = get_node_or_null("CenterContainer/Panel/AnimationPlayer")
@onready var video_player: VideoStreamPlayer = get_node_or_null("VideoStreamPlayer")
@onready var video_skip_btn: Button = get_node_or_null("VideoSkipButton")

var video_streams: Dictionary = {}
var is_video_playing: bool = false

const SINGLE_COST := 10
const FIVE_COST := 45
const DUPLICATE_COIN_PAYOUT := 300

# Probability weights for rarity tiers (Hero-based shared rates: Rare: 3, Epic: 2)
const TIER_WEIGHTS := {
	"Rare": 3,
	"Epic": 2
}

# Rare Pool: Heroes + Diamond Equipment
const RARE_POOL := [
	{"type": "chick", "id": "kitty", "rarity": "Rare"},
	{"type": "chick", "id": "magnet", "rarity": "Rare"},
	{"type": "chick", "id": "speedy", "rarity": "Rare"},
	{"type": "equipment", "id": "shield5", "name": "Diamond Shield", "rarity": "Rare"},
	{"type": "equipment", "id": "helmet5", "name": "Diamond Helmet", "rarity": "Rare"},
	{"type": "equipment", "id": "shoe5", "name": "Diamond Boots", "rarity": "Rare"}
]

# Epic Pool: Heroes + Diamond Equipment
const EPIC_POOL := [
	{"type": "chick", "id": "worrier", "rarity": "Epic"},
	{"type": "chick", "id": "tanker", "rarity": "Epic"},
	{"type": "equipment", "id": "sword", "name": "Sword", "rarity": "Epic"},
	{"type": "equipment", "id": "armor5", "name": "Diamond Armor", "rarity": "Epic"}
]

const COIN_POOL := [
	{"type": "coins", "id": "coin_50", "amount": 50, "name": "Coin Pouch", "icon": "res://graphic/coin.png", "weight": 40, "rarity": "Common"},
	{"type": "coins", "id": "coin_150", "amount": 150, "name": "Coin Sack", "icon": "res://graphic/coin2.png", "weight": 30, "rarity": "Uncommon"},
	{"type": "coins", "id": "coin_300", "amount": 300, "name": "Treasure Chest", "icon": "res://graphic/itemcoin.png", "weight": 15, "rarity": "Rare"},
	{"type": "coins", "id": "coin_600", "amount": 600, "name": "Jackpot Stash", "icon": "res://graphic/manycoin.png", "weight": 10, "rarity": "Epic"}
]

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(toggle)
	pull_1_btn.pressed.connect(func(): _do_pull(1, SINGLE_COST))
	pull_5_btn.pressed.connect(func(): _do_pull(5, FIVE_COST))
	if video_skip_btn:
		video_skip_btn.pressed.connect(_skip_video)
	
	Global.diamonds_changed.connect(_on_diamonds_changed)
	_on_diamonds_changed(Global.diamonds)
	_setup_video_streams()
	_setup_gacha_animator()
	_reset_showcase()

func _setup_video_streams() -> void:
	for vname in ["onegold", "onepurple", "fivegold", "fivepurple"]:
		var ogv_path := "res://graphic/%s.ogv" % vname
		if ResourceLoader.exists(ogv_path):
			var theora_stream := VideoStreamTheora.new()
			theora_stream.file = ogv_path
			video_streams[vname] = theora_stream

func _input(event: InputEvent) -> void:
	if video_player and video_player.visible and (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		_skip_video()

func _skip_video() -> void:
	if video_player and video_player.visible:
		is_video_playing = false
		if video_skip_btn:
			video_skip_btn.visible = false
		video_player.stop()
		video_player.finished.emit()

func _setup_gacha_animator() -> void:
	if not gacha_animator:
		gacha_animator = get_node_or_null("CenterContainer/Panel/GachaAnimator")
	if not gacha_animator:
		gacha_animator = find_child("GachaAnimator", true, false)
	if not gacha_animator:
		gacha_animator = find_child("AnimatedSprite2D", true, false)
	if not gacha_animator:
		return

	var frames: SpriteFrames = gacha_animator.sprite_frames
	if not frames:
		frames = SpriteFrames.new()
		gacha_animator.sprite_frames = frames

	for anim_name in ["onegold", "onepurple", "fivegold", "fivepurple"]:
		if not frames.has_animation(anim_name):
			frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, false)
		frames.set_animation_speed(anim_name, 8.0)
		
		# If frames not already populated, load from graphic/gacha_anim/
		if frames.get_frame_count(anim_name) == 0:
			for i in range(1, 17):
				var frame_path := "res://graphic/gacha_anim/%s/%d.png" % [anim_name, i]
				if ResourceLoader.exists(frame_path):
					var tex: Texture2D = load(frame_path)
					if tex:
						frames.add_frame(anim_name, tex)
			# Fallback if no frames were loaded
			if frames.get_frame_count(anim_name) == 0:
				var fallback_path: String = "res://graphic/star.png"
				if ResourceLoader.exists(fallback_path):
					var star_tex: Texture2D = load(fallback_path)
					frames.add_frame(anim_name, star_tex)

func toggle() -> void:
	visible = not visible
	if visible:
		status_label.text = ""
		_on_diamonds_changed(Global.diamonds)
		_reset_showcase()
	else:
		if is_video_playing:
			_skip_video()

func _on_diamonds_changed(amount: int) -> void:
	if diamond_label:
		diamond_label.text = str(amount)

func _reset_showcase() -> void:
	if is_video_playing:
		_skip_video()
	if video_player:
		video_player.visible = false
		video_player.stop()
	if video_skip_btn:
		video_skip_btn.visible = false
	if gacha_animator:
		gacha_animator.visible = false
		gacha_animator.stop()
	if animation_player:
		animation_player.stop()
	if AudioManager:
		AudioManager.resume_music()
	pull_1_btn.disabled = false
	pull_5_btn.disabled = false
	close_btn.disabled = false
	showcase_placeholder.visible = true
	showcase_results.visible = false
	for child in showcase_results.get_children():
		showcase_results.remove_child(child)
		child.queue_free()

func _do_pull(count: int, cost: int) -> void:
	if not Global.spend_diamonds(cost):
		status_label.text = "Not enough Diamonds! Need %d Diamonds" % cost
		status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))
		return
		
	Global.add_pulls(count)
	status_label.text = ""

	# Disable buttons during roll animation
	pull_1_btn.disabled = true
	pull_5_btn.disabled = true
	close_btn.disabled = true

	# Hide showcase during animation (do not immediately display reward showcase UI)
	showcase_placeholder.visible = false
	showcase_results.visible = false

	# 1. Pre-calculate the results of the pull(s) in memory
	var pulled_results: Array = []
	var has_high_tier: bool = false
	
	for i in range(count):
		var rolled_entry := _pick_random_item()
		if rolled_entry["type"] == "chick":
			has_high_tier = true
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
		elif rolled_entry["type"] == "equipment":
			has_high_tier = true
			var eq_id: String = rolled_entry["id"]
			Global.add_inventory_item(eq_id)
			var base_item := ItemDatabase.get_item(eq_id)
			pulled_results.append({
				"type": "equipment",
				"id": eq_id,
				"name": base_item.get("name", rolled_entry.get("name", eq_id)),
				"icon": base_item.get("texture_path", ""),
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

	# Determine the Rarity of the pull:
	# Gold (High Rarity): If the pull (or any of the 5 pulls) results in a Hero Character or Diamond Equipment
	# Purple (Common): If the pull (or all 5 pulls) results in only Coin bundles
	var anim_name: String = ""
	if count == 1:
		anim_name = "onegold" if has_high_tier else "onepurple"
	else:
		anim_name = "fivegold" if has_high_tier else "fivepurple"

	# 2. Audio Override Logic: dynamically mute or pause background music before playing video
	if AudioManager:
		AudioManager.pause_music()

	# 3. Fullscreen Video Playback & Tap to Skip Handling
	if video_player:
		if video_streams.has(anim_name):
			video_player.stream = video_streams[anim_name]
		elif ResourceLoader.exists("res://graphic/%s.ogv" % anim_name):
			var st := VideoStreamTheora.new()
			st.file = "res://graphic/%s.ogv" % anim_name
			video_player.stream = st
		
		video_player.visible = true
		if video_skip_btn:
			video_skip_btn.visible = true
		is_video_playing = true
		video_player.play()

		await video_player.finished

		is_video_playing = false
		video_player.stop()
		video_player.visible = false
		if video_skip_btn:
			video_skip_btn.visible = false
	elif gacha_animator:
		gacha_animator.visible = true
		gacha_animator.play(anim_name)
		await gacha_animator.animation_finished
		gacha_animator.visible = false

	# Resume background music
	if AudioManager:
		AudioManager.resume_music()

	# Re-enable buttons after animation finishes
	pull_1_btn.disabled = false
	pull_5_btn.disabled = false
	close_btn.disabled = false

	# Reveal standard reward showcase box
	_display_results(pulled_results)

func _pick_random_item() -> Dictionary:
	# Exactly 5% chance of pulling high-tier rewards (Chick Heroes or Diamond Equipment), 95% coin bundles
	if randf() <= 0.05:
		return _pick_premium_item()
	else:
		return _pick_from_weighted_array(COIN_POOL)

func _pick_premium_item() -> Dictionary:
	# 1. Determine rarity tier based on the exact same probability weights (Rare: 3, Epic: 2)
	var total_tier_weight: int = TIER_WEIGHTS["Rare"] + TIER_WEIGHTS["Epic"] # 3 + 2 = 5
	var roll: int = randi_range(1, total_tier_weight)
	var chosen_tier: String = "Rare" if roll <= TIER_WEIGHTS["Rare"] else "Epic"
	
	# 2. Randomly select an item from that tier (Hero or Diamond Equipment)
	var tier_pool: Array = RARE_POOL if chosen_tier == "Rare" else EPIC_POOL
	var picked: Dictionary = tier_pool.pick_random()
	return picked.duplicate(true)

func _pick_from_weighted_array(pool: Array) -> Dictionary:
	var total_weight := 0
	for entry in pool:
		total_weight += entry["weight"]
		
	var roll := randi_range(1, total_weight)
	var current := 0
	for entry in pool:
		current += entry["weight"]
		if roll <= current:
			return entry
	return pool[0]

func _display_results(results: Array) -> void:
	for child in showcase_results.get_children():
		showcase_results.remove_child(child)
		child.queue_free()
		
	showcase_placeholder.visible = false
	showcase_results.visible = true
	
	for res in results:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(140, 230)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 4)
		
		# Category badge
		var category_lbl := Label.new()
		category_lbl.add_theme_font_size_override("font_size", 14)
		category_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(72, 72)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var name_lbl := Label.new()
		name_lbl.add_theme_font_size_override("font_size", 20)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		var rarity_lbl := Label.new()
		var rarity_str: String = res.get("rarity", "Common")
		rarity_lbl.text = rarity_str
		rarity_lbl.add_theme_font_size_override("font_size", 16)
		rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_apply_rarity_color(rarity_lbl, rarity_str)
		
		var tag_lbl := Label.new()
		tag_lbl.add_theme_font_size_override("font_size", 18)
		tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		if res["type"] == "chick":
			category_lbl.text = "[ HERO ]"
			category_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
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
		elif res["type"] == "equipment":
			category_lbl.text = "[ EQUIPMENT ]"
			category_lbl.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0, 1.0))
			name_lbl.text = res.get("name", "Diamond Gear")
			var eq_icon_path: String = res.get("icon", "")
			if ResourceLoader.exists(eq_icon_path):
				icon.texture = load(eq_icon_path)
			tag_lbl.text = "EQUIPMENT"
			tag_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5, 1.0))
		else: # coins
			category_lbl.text = "[ COINS ]"
			category_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
			name_lbl.text = res["name"]
			var coin_icon_path: String = res["icon"]
			if ResourceLoader.exists(coin_icon_path):
				icon.texture = load(coin_icon_path)
			tag_lbl.text = "+%d Coins" % res["amount"]
			tag_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
			
		vbox.add_child(category_lbl)
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
