extends Control
class_name BlacksmithUI

## blacksmith_ui.gd
## Workshop interface allowing players to upgrade owned equipment up to +15
## (consuming duplicate items or coins, boosting stats by +5% per level)
## and sell surplus gear for Coins.

@onready var close_btn: Button = $CenterContainer/Panel/RootVBox/TopBar/CloseButton
@onready var coins_label: Label = get_node_or_null("CenterContainer/Panel/RootVBox/TopBar/CoinBox/CoinsLabel") if get_node_or_null("CenterContainer/Panel/RootVBox/TopBar/CoinBox/CoinsLabel") else get_node_or_null("CenterContainer/Panel/RootVBox/TopBar/CoinsLabel")
@onready var item_list_container: VBoxContainer = $CenterContainer/Panel/RootVBox/ContentHBox/LeftPane/ScrollContainer/ItemList
@onready var item_icon: TextureRect = $CenterContainer/Panel/RootVBox/ContentHBox/RightPane/DetailVBox/IconCenter/ItemIcon
@onready var item_name_label: Label = $CenterContainer/Panel/RootVBox/ContentHBox/RightPane/DetailVBox/ItemName
@onready var stats_current_label: Label = $CenterContainer/Panel/RootVBox/ContentHBox/RightPane/DetailVBox/CurrentStats
@onready var stats_next_label: Label = $CenterContainer/Panel/RootVBox/ContentHBox/RightPane/DetailVBox/NextStats
@onready var cost_label: Label = $CenterContainer/Panel/RootVBox/ContentHBox/RightPane/DetailVBox/CostLabel
@onready var status_label: Label = $CenterContainer/Panel/RootVBox/ContentHBox/RightPane/DetailVBox/StatusLabel
@onready var upgrade_btn: Button = $CenterContainer/Panel/RootVBox/ContentHBox/RightPane/DetailVBox/ButtonHBox/UpgradeButton
@onready var sell_btn: Button = $CenterContainer/Panel/RootVBox/ContentHBox/RightPane/DetailVBox/ButtonHBox/SellButton

var selected_item_id: String = ""
var _status_timer_token: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	status_label.text = ""
	
	close_btn.pressed.connect(toggle)
	upgrade_btn.pressed.connect(_on_upgrade_pressed)
	sell_btn.pressed.connect(_on_sell_pressed)
	
	Global.inventory_updated.connect(refresh_ui)
	Global.coins_changed.connect(func(_val): _update_coins_display())
	
	_update_coins_display()
	refresh_ui()

func toggle() -> void:
	visible = not visible
	status_label.text = ""
	if visible:
		_update_coins_display()
		refresh_ui()

func _update_coins_display() -> void:
	if coins_label:
		coins_label.text = str(Global.coins)

func _get_all_owned_equipment_ids() -> Array[String]:
	var result: Array[String] = []
	# Check equipped
	for slot in Global.equipped.keys():
		var eq_val = Global.equipped[slot]
		var eq_id: String = str(eq_val.get("id", "no")).strip_edges() if eq_val is Dictionary else str(eq_val).strip_edges()
		if eq_id != "no" and not eq_id.is_empty() and ItemDatabase.is_upgradeable(eq_id):
			if not result.has(eq_id):
				result.append(eq_id)
				
	# Check inventory
	for itm in Global.inventory:
		var itm_id: String = str(itm.get("id", "")).strip_edges() if itm is Dictionary else str(itm).strip_edges()
		if itm_id != "no" and not itm_id.is_empty() and ItemDatabase.is_upgradeable(itm_id):
			if not result.has(itm_id):
				result.append(itm_id)
				
	return result

func refresh_ui() -> void:
	_update_coins_display()
	_populate_item_list()
	if not selected_item_id.is_empty():
		_select_item(selected_item_id)
	else:
		_clear_detail()

func _populate_item_list() -> void:
	for child in item_list_container.get_children():
		item_list_container.remove_child(child)
		child.queue_free()

	var equipment_ids := _get_all_owned_equipment_ids()
	if equipment_ids.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No equipment found.\nCollect gear from stages or Shop!"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
		item_list_container.add_child(empty_lbl)
		return

	for itm_id in equipment_ids:
		var itm_data := ItemDatabase.get_item(itm_id)
		if itm_data.is_empty():
			continue

		var display_title: String = ItemDatabase.get_item_display_name(itm_id)
		var is_eq: bool = Global.is_item_equipped(itm_id)
		var inv_count: int = Global.count_inventory_item(itm_id)
		var total_owned: int = (1 if is_eq else 0) + inv_count
		
		# Row button container
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 64)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.clip_contents = true

		var hbox := HBoxContainer.new()
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hbox.offset_left = 10
		hbox.offset_right = -10
		hbox.offset_top = 4
		hbox.offset_bottom = -4
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_theme_constant_override("separation", 12)
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER

		# 1. Icon on the left
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(48, 48)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex_path: String = itm_data.get("texture_path", "")
		if ResourceLoader.exists(tex_path):
			icon_rect.texture = load(tex_path)
		hbox.add_child(icon_rect)

		# 2. Item Name in the center with text_overrun_behavior
		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text = display_title
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 24)
		if itm_id == selected_item_id:
			name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
		else:
			name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1.0))
		hbox.add_child(name_label)

		# 3. Owned Quantity aligned to the right (e.g. Owned: 2)
		var qty_label := Label.new()
		qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		qty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		qty_label.add_theme_font_size_override("font_size", 22)
		if is_eq and inv_count > 0:
			qty_label.text = "Owned: %d (Eq)" % total_owned
			qty_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5, 1.0))
		elif is_eq:
			qty_label.text = "Equipped"
			qty_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5, 1.0))
		else:
			qty_label.text = "Owned: %d" % total_owned
			qty_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95, 1.0))
		hbox.add_child(qty_label)

		btn.add_child(hbox)

		var captured_id := itm_id
		btn.pressed.connect(func(): _on_item_selected(captured_id))
		item_list_container.add_child(btn)

func _on_item_selected(itm_id: String) -> void:
	status_label.text = ""
	_select_item(itm_id)

func _select_item(itm_id: String) -> void:
	selected_item_id = itm_id
	var itm_data := ItemDatabase.get_item(itm_id)
	if itm_data.is_empty():
		_clear_detail()
		return

	var tex_path: String = itm_data.get("texture_path", "")
	if ResourceLoader.exists(tex_path):
		item_icon.texture = load(tex_path)
		item_icon.visible = true
	else:
		item_icon.visible = false

	var current_lvl := Global.get_item_upgrade_level(itm_id)
	item_name_label.text = "%s  (+%d / 15)" % [itm_data.get("name", itm_id), current_lvl]
	
	var cur_stats := ItemDatabase.get_upgraded_stats(itm_id, current_lvl)
	var next_stats := ItemDatabase.get_upgraded_stats(itm_id, min(15, current_lvl + 1))
	
	stats_current_label.text = "Current:  ATK +%d  |  DEF +%d  |  CD -%.1fs" % [
		int(cur_stats.get("atk", 0.0)),
		int(cur_stats.get("def", 0.0)),
		cur_stats.get("cd", 0.0)
	]
	
	if current_lvl < 15:
		stats_next_label.text = "Next (+%d): ATK +%d  |  DEF +%d  |  CD -%.1fs  (+12%%)" % [
			current_lvl + 1,
			int(next_stats.get("atk", 0.0)),
			int(next_stats.get("def", 0.0)),
			next_stats.get("cd", 0.0)
		]
	else:
		stats_next_label.text = "★ Maximum Upgrade Level (+15) Reached! ★"

	var info := Global.get_upgrade_info(itm_id)
	upgrade_btn.visible = true
	sell_btn.visible = true
	
	var sell_price := ItemDatabase.get_sell_price(itm_id)
	var bag_count := Global.count_inventory_item(itm_id)
	sell_btn.text = "SELL (1x for %d Coins)" % sell_price
	sell_btn.disabled = bag_count <= 0

	if info.get("max_reached", false):
		upgrade_btn.disabled = true
		upgrade_btn.text = "MAX LEVEL (+15)"
		cost_label.text = "Item has reached its absolute peak power."
	else:
		var coin_cost: int = info["coin_cost"]
		var has_dup: bool = info["has_duplicate"]
		if has_dup:
			cost_label.text = "Upgrade Cost: 1 Duplicate copy + %d Coins" % coin_cost
			upgrade_btn.text = "UPGRADE (+1)"
			upgrade_btn.disabled = not info.get("can_upgrade", false)
		else:
			cost_label.text = "Upgrade Requires: 1 Spare Duplicate + %d Coins\n(No unequipped duplicate in inventory)" % coin_cost
			upgrade_btn.text = "NEED DUPLICATE"
			upgrade_btn.disabled = true

func _clear_detail() -> void:
	selected_item_id = ""
	item_icon.texture = null
	item_icon.visible = false
	item_name_label.text = "Select an Equipment"
	stats_current_label.text = ""
	stats_next_label.text = "Select any weapon, shield, or armor to upgrade or sell."
	cost_label.text = ""
	status_label.text = ""
	upgrade_btn.visible = false
	sell_btn.visible = false

func _on_upgrade_pressed() -> void:
	if selected_item_id.is_empty():
		return
	var res := Global.upgrade_item(selected_item_id)
	if res.get("success", false):
		status_label.text = "Success! %s (1 duplicate consumed)" % res.get("reason", "")
		status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1.0))
		refresh_ui()
		_status_timer_token += 1
		var token := _status_timer_token
		await get_tree().create_timer(3.0).timeout
		if is_instance_valid(status_label) and _status_timer_token == token:
			status_label.text = ""
	else:
		status_label.text = "Upgrade Failed: %s" % res.get("reason", "")
		status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))


func _on_sell_pressed() -> void:
	if selected_item_id.is_empty():
		return
	var res := Global.sell_item(selected_item_id)
	if res.get("success", false):
		status_label.text = "Item sold! %s" % res.get("reason", "")
		status_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
		refresh_ui()
		_status_timer_token += 1
		var token := _status_timer_token
		await get_tree().create_timer(3.0).timeout
		if is_instance_valid(status_label) and _status_timer_token == token:
			status_label.text = ""
	else:
		status_label.text = "Cannot Sell: %s" % res.get("reason", "")
		status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))

