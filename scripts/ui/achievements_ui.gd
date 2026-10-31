extends Control
class_name AchievementsUI

## achievements_ui.gd
## Continuous tiered achievement system with Diamond claim rewards,
## automatic tier upgrades, thematic milestones, and warm gold styling.

@onready var close_btn: Button = $CenterContainer/Panel/CloseButton
@onready var count_lbl: Label = $CenterContainer/Panel/TopBar/CountLabel
@onready var diamond_lbl: Label = $CenterContainer/Panel/TopBar/DiamondLabel
@onready var achievement_list: VBoxContainer = $CenterContainer/Panel/ScrollContainer/AchievementList

const WARM_GOLD := Color(1.0, 0.84, 0.0, 1.0) # #FFD700
const SOFT_WHITE := Color(0.95, 0.95, 0.95, 1.0)

const TRACKS := [
	{
		"track_id": "slayer",
		"type": "kills",
		"icon": "res://graphic/achievement.png",
		"tiers": [
			{"title": "First Blood", "desc": "Defeat your very first monster in the cave.", "target": 1, "reward": 10},
			{"title": "Cave Hunter", "desc": "Defeat 25 monsters across all expeditions.", "target": 25, "reward": 15},
			{"title": "Cave Slayer", "desc": "Defeat 50 monsters across all expeditions.", "target": 50, "reward": 25},
			{"title": "Monster Exterminator", "desc": "Defeat 150 monsters across all expeditions.", "target": 150, "reward": 40},
			{"title": "Abyssal Legend", "desc": "Defeat 500 monsters across all expeditions.", "target": 500, "reward": 60}
		]
	},
	{
		"track_id": "stage",
		"type": "stage",
		"icon": "res://graphic/star.png",
		"tiers": [
			{"title": "Cave Scout", "desc": "Conquer Stage 3 of the cave system.", "target": 3, "reward": 10},
			{"title": "Deep Spelunker", "desc": "Conquer Stage 5 of the cave system.", "target": 5, "reward": 20},
			{"title": "Underground Veteran", "desc": "Conquer Stage 10 and deeper depths.", "target": 10, "reward": 30},
			{"title": "Abyssal Conqueror", "desc": "Conquer Stage 15 of the cave system.", "target": 15, "reward": 40},
			{"title": "Cave Master", "desc": "Survive and conquer final Stage 20.", "target": 20, "reward": 60}
		]
	},
	{
		"track_id": "hoarder",
		"type": "coins",
		"icon": "res://graphic/itemcoin.png",
		"tiers": [
			{"title": "Hoarder I", "desc": "Accumulate a total of 1,000 Coins.", "target": 1000, "reward": 15},
			{"title": "Hoarder II", "desc": "Accumulate a total of 5,000 Coins.", "target": 5000, "reward": 30},
			{"title": "Hoarder III", "desc": "Accumulate a total of 10,000 Coins.", "target": 10000, "reward": 50}
		]
	},
	{
		"track_id": "speed_demon",
		"type": "speed_demon",
		"icon": "res://graphic/speedychic.png",
		"tiers": [
			{"title": "Speed Demon", "desc": "Conquer any cave stage in under 30 seconds.", "target": 1, "reward": 30}
		]
	},
	{
		"track_id": "iron_skin",
		"type": "iron_skin",
		"icon": "res://graphic/shield4.png",
		"tiers": [
			{"title": "Iron Skin", "desc": "Conquer any cave stage without taking damage.", "target": 1, "reward": 30}
		]
	},
	{
		"track_id": "gacha_addict",
		"type": "pulls",
		"icon": "res://graphic/allchicky.png",
		"tiers": [
			{"title": "Novice Summoner", "desc": "Perform 10 Gacha pulls from the hero pool.", "target": 10, "reward": 15},
			{"title": "Gacha Fanatic", "desc": "Perform 50 Gacha pulls from the hero pool.", "target": 50, "reward": 35},
			{"title": "Gacha Addict", "desc": "Perform 100 Gacha pulls from the hero pool.", "target": 100, "reward": 60}
		]
	},
	{
		"track_id": "collector",
		"type": "chicks",
		"icon": "res://graphic/chicky.png",
		"tiers": [
			{"title": "Duo Flock", "desc": "Unlock at least 2 unique Chick heroes.", "target": 2, "reward": 15},
			{"title": "Flock Leader", "desc": "Unlock at least 4 unique Chick heroes.", "target": 4, "reward": 30},
			{"title": "Grand Flock", "desc": "Unlock all 6 unique Chick heroes.", "target": 6, "reward": 50}
		]
	},
	{
		"track_id": "survivor",
		"type": "survivor",
		"icon": "res://graphic/helmet5.png",
		"tiers": [
			{"title": "Survivor I", "desc": "Survive for 30 seconds in any level.", "target": 30, "reward": 15},
			{"title": "Survivor II", "desc": "Survive for 60 seconds in any level.", "target": 60, "reward": 25},
			{"title": "Survivor III", "desc": "Survive for 90 seconds in any level.", "target": 90, "reward": 40},
			{"title": "Ultimate Survivor", "desc": "Survive for 120 seconds in Stage 30.", "target": 120, "reward": 60}
		]
	}
]

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(toggle)
	Global.diamonds_changed.connect(_on_diamonds_changed)
	Global.achievement_claimed.connect(func(_t, _i, _r): if visible: refresh_achievements())

func toggle() -> void:
	visible = not visible
	if visible:
		_on_diamonds_changed(Global.diamonds)
		refresh_achievements()

func _on_diamonds_changed(amount: int) -> void:
	if diamond_lbl:
		diamond_lbl.text = "Diamonds: %d 💎" % amount

func refresh_achievements() -> void:
	for child in achievement_list.get_children():
		achievement_list.remove_child(child)
		child.queue_free()

	var total_tiers: int = 0
	var claimed_tiers: int = 0
	for track in TRACKS:
		var tiers_arr: Array = track["tiers"]
		total_tiers += tiers_arr.size()
		var curr_tier: int = Global.achievement_tiers.get(track["track_id"], 0)
		claimed_tiers += int(min(curr_tier, tiers_arr.size()))

	count_lbl.text = "Tier Progress: %d / %d 🏆" % [claimed_tiers, total_tiers]

	for track in TRACKS:
		var track_id: String = track["track_id"]
		var tiers_arr: Array = track["tiers"]
		var curr_tier_idx: int = Global.achievement_tiers.get(track_id, 0)
		var is_max_claimed: bool = (curr_tier_idx >= tiers_arr.size())
		
		# Show current tier or last completed tier
		var display_idx: int = int(min(curr_tier_idx, tiers_arr.size() - 1))
		var tier_data: Dictionary = tiers_arr[display_idx]
		
		var curr_val: int = _get_current_val(track["type"])
		var target_val: int = tier_data["target"]
		var reward_val: int = tier_data["reward"]
		var is_completed: bool = (curr_val >= target_val)

		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(0, 80)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)

		# Icon
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(50, 50)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_path: String = track["icon"]
		if ResourceLoader.exists(icon_path):
			icon.texture = load(icon_path)

		if is_max_claimed:
			icon.modulate = WARM_GOLD
		elif is_completed:
			icon.modulate = WARM_GOLD
		else:
			icon.modulate = Color(0.6, 0.6, 0.6, 0.8)

		# Text Description
		var text_vbox := VBoxContainer.new()
		text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER

		var title_lbl := Label.new()
		var tier_str: String = " (Tier %d/%d)" % [display_idx + 1, tiers_arr.size()]
		title_lbl.text = tier_data["title"] + tier_str
		title_lbl.add_theme_font_size_override("font_size", 22)
		if is_max_claimed or is_completed:
			title_lbl.add_theme_color_override("font_color", WARM_GOLD)
		else:
			title_lbl.add_theme_color_override("font_color", SOFT_WHITE)

		var desc_lbl := Label.new()
		desc_lbl.text = tier_data["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 16)
		desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1.0))

		text_vbox.add_child(title_lbl)
		text_vbox.add_child(desc_lbl)

		# Progress & Claim Action
		var action_box := VBoxContainer.new()
		action_box.custom_minimum_size = Vector2(170, 0)
		action_box.alignment = BoxContainer.ALIGNMENT_CENTER
		action_box.add_theme_constant_override("separation", 4)

		if is_max_claimed:
			var max_lbl := Label.new()
			max_lbl.text = "CLAIMED (MAX) 🏆"
			max_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			max_lbl.add_theme_font_size_override("font_size", 18)
			max_lbl.add_theme_color_override("font_color", WARM_GOLD)
			action_box.add_child(max_lbl)
		elif is_completed:
			var claim_btn := Button.new()
			claim_btn.custom_minimum_size = Vector2(160, 42)
			claim_btn.text = "CLAIM (+%d 💎)" % reward_val
			claim_btn.add_theme_font_size_override("font_size", 20)
			claim_btn.add_theme_color_override("font_color", WARM_GOLD)
			var cap_track: String = track_id
			var cap_tier: int = curr_tier_idx
			var cap_rew: int = reward_val
			claim_btn.pressed.connect(func():
				Global.claim_achievement_tier(cap_track, cap_tier, cap_rew)
			)
			action_box.add_child(claim_btn)
		else:
			var prog_bar := ProgressBar.new()
			prog_bar.custom_minimum_size = Vector2(160, 14)
			prog_bar.max_value = target_val
			prog_bar.value = min(curr_val, target_val)
			prog_bar.show_percentage = false

			var prog_lbl := Label.new()
			prog_lbl.text = "%d / %d (+%d 💎)" % [min(curr_val, target_val), target_val, reward_val]
			prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			prog_lbl.add_theme_font_size_override("font_size", 16)
			prog_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))

			action_box.add_child(prog_bar)
			action_box.add_child(prog_lbl)

		hbox.add_child(icon)
		hbox.add_child(text_vbox)
		hbox.add_child(action_box)
		row.add_child(hbox)
		achievement_list.add_child(row)

func _get_current_val(type: String) -> int:
	match type:
		"kills":
			return Global.total_kills
		"stage":
			return Global.highest_stage
		"coins":
			return Global.total_coins_earned
		"chicks":
			return Global.unlocked_chicks.size()
		"pulls":
			return Global.pulls
		"speed_demon":
			return 1 if Global.speed_demon_cleared else 0
		"iron_skin":
			return 1 if Global.iron_skin_cleared else 0
		"survivor":
			var curr_tier: int = Global.achievement_tiers.get("survivor", 0)
			if curr_tier >= 3:
				return int(Global.max_survived_stage_30_seconds)
			return int(Global.max_survived_seconds)
	return 0
