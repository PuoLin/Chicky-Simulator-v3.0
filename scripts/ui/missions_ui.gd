extends Control
class_name MissionsUI

## missions_ui.gd
## Missions UI displaying trackable objectives with progress bars, diamond rewards,
## and claiming mechanisms.

@onready var mission_list: VBoxContainer = $CenterContainer/Panel/ScrollContainer/MissionList
@onready var close_btn: Button = $CenterContainer/Panel/CloseButton
@onready var diamond_label: Label = get_node_or_null("CenterContainer/Panel/TopBar/DiamondContainer/DiamondLabel") if get_node_or_null("CenterContainer/Panel/TopBar/DiamondContainer/DiamondLabel") else get_node_or_null("CenterContainer/Panel/TopBar/DiamondLabel")

const MISSIONS := [
	{
		"id": "m_first_kill",
		"title": "First Blood",
		"desc": "Defeat your first monster in the cave.",
		"target": 1,
		"type": "kills",
		"reward": 100,
		"reward_type": "coins"
	},
	{
		"id": "m_kill_10",
		"title": "Cave Skirmisher",
		"desc": "Defeat 10 Monsters in the cave.",
		"target": 10,
		"type": "kills",
		"reward": 250,
		"reward_type": "coins"
	},
	{
		"id": "m_stage_3",
		"title": "Into the Deep",
		"desc": "Reach and clear Stage 3.",
		"target": 3,
		"type": "stage",
		"reward": 300,
		"reward_type": "coins"
	},
	{
		"id": "m_torches",
		"title": "Prepared Explorer",
		"desc": "Hold 3 torches in your backpack at once.",
		"target": 3,
		"type": "torch",
		"reward": 150,
		"reward_type": "coins"
	},
	{
		"id": "m_kill_50",
		"title": "Monster Slayer",
		"desc": "Defeat 50 Monsters across all stages.",
		"target": 50,
		"type": "kills",
		"reward": 15,
		"reward_type": "diamonds"
	},
	{
		"id": "m_kill_100",
		"title": "Dungeon Cleanser",
		"desc": "Defeat 100 Monsters total.",
		"target": 100,
		"type": "kills",
		"reward": 30,
		"reward_type": "diamonds"
	},
	{
		"id": "m_stage_5",
		"title": "Cave Veteran",
		"desc": "Conquer Stage 5 and enter Tier 2.",
		"target": 5,
		"type": "stage",
		"reward": 15,
		"reward_type": "diamonds"
	},
	{
		"id": "m_stage_10",
		"title": "Halfway Hero",
		"desc": "Clear Stage 10 and enter Tier 3.",
		"target": 10,
		"type": "stage",
		"reward": 25,
		"reward_type": "diamonds"
	},
	{
		"id": "m_stage_20",
		"title": "Grand Champion",
		"desc": "Conquer Stage 20.",
		"target": 20,
		"type": "stage",
		"reward": 50,
		"reward_type": "diamonds"
	},
	{
		"id": "m_coins_1000",
		"title": "Treasure Hunter",
		"desc": "Accumulate 1,000 total coins.",
		"target": 1000,
		"type": "coins",
		"reward": 10,
		"reward_type": "diamonds"
	},
	{
		"id": "m_gacha_pull",
		"title": "First Wish",
		"desc": "Perform at least 1 Gacha chick summon.",
		"target": 1,
		"type": "pulls",
		"reward": 5,
		"reward_type": "diamonds"
	}
]

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(toggle)
	Global.diamonds_changed.connect(_on_currency_changed)
	Global.coins_changed.connect(_on_currency_changed)
	Global.mission_claimed.connect(func(_id): refresh_ui())
	_update_currency_label()

func toggle() -> void:
	visible = not visible
	if visible:
		refresh_ui()

func _update_currency_label() -> void:
	if diamond_label:
		diamond_label.text = str(Global.diamonds)

func _on_currency_changed(_amount: int) -> void:
	_update_currency_label()

func refresh_ui() -> void:
	_update_currency_label()
	for child in mission_list.get_children():
		child.queue_free()

	for m in MISSIONS:
		var current_val: int = _get_current_value(m["type"])
		var target_val: int = m["target"]
		var is_claimed: bool = Global.claimed_missions.has(m["id"])
		var is_ready: bool = current_val >= target_val and not is_claimed

		var item_panel := PanelContainer.new()
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		
		# Left text details
		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var title := Label.new()
		title.text = m["title"]
		title.add_theme_font_size_override("font_size", 24)
		
		var desc := Label.new()
		desc.text = m["desc"]
		desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1.0))
		desc.add_theme_font_size_override("font_size", 18)
		
		var pbar := ProgressBar.new()
		pbar.custom_minimum_size = Vector2(240, 14)
		pbar.max_value = target_val
		pbar.value = min(current_val, target_val)
		pbar.show_percentage = false
		
		var count_lbl := Label.new()
		count_lbl.text = "%d / %d" % [min(current_val, target_val), target_val]
		count_lbl.add_theme_font_size_override("font_size", 16)
		
		var bar_box := HBoxContainer.new()
		bar_box.add_theme_constant_override("separation", 8)
		bar_box.add_child(pbar)
		bar_box.add_child(count_lbl)
		
		vbox.add_child(title)
		vbox.add_child(desc)
		vbox.add_child(bar_box)
		
		# Right reward / claim button
		var right_vbox := VBoxContainer.new()
		right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var reward_type: String = m.get("reward_type", "diamonds")
		var reward_lbl := Label.new()
		if reward_type == "coins":
			reward_lbl.text = "+%d Coins" % m["reward"]
			reward_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
		else:
			reward_lbl.text = "+%d Diamonds" % m["reward"]
			reward_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0, 1.0))
		reward_lbl.add_theme_font_size_override("font_size", 20)
		reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		var claim_btn := Button.new()
		claim_btn.custom_minimum_size = Vector2(110, 42)
		
		if is_claimed:
			claim_btn.text = "CLAIMED"
			claim_btn.disabled = true
			claim_btn.modulate = Color(0.5, 0.5, 0.5, 0.6)
		elif is_ready:
			claim_btn.text = "CLAIM"
			claim_btn.disabled = false
			claim_btn.modulate = Color(0.4, 1.0, 0.4, 1.0)
			var captured_id: String = m["id"]
			var captured_reward: int = m["reward"]
			var captured_type: String = reward_type
			claim_btn.pressed.connect(func():
				Global.claim_mission(captured_id, captured_reward, captured_type)
			)
		else:
			claim_btn.text = "IN PROGRESS"
			claim_btn.disabled = true
			claim_btn.modulate = Color(0.8, 0.8, 0.8, 0.5)

		right_vbox.add_child(reward_lbl)
		right_vbox.add_child(claim_btn)
		
		hbox.add_child(vbox)
		hbox.add_child(right_vbox)
		item_panel.add_child(hbox)
		mission_list.add_child(item_panel)

func _get_current_value(type: String) -> int:
	match type:
		"kills":
			return Global.total_kills
		"stage":
			return Global.highest_stage
		"coins":
			return Global.total_coins_earned
		"pulls":
			return Global.pulls
		"torch":
			return Global.count_inventory_item("torch")
	return 0
