extends Control
class_name BackpackUI

## backpack_ui.gd
## Two-pane inventory & equipment manager with equipped gear top section,
## category filters, scrollable inventory grid, and detailed inspection panel.

@onready var grid_container: GridContainer = $CenterContainer/Panel/RootVBox/BottomSection/LeftPane/ScrollContainer/InventoryGrid
@onready var slot_weapon: TextureButton = $CenterContainer/Panel/RootVBox/EquippedSection/EquippedSlots/SlotWeapon
@onready var slot_shield: TextureButton = $CenterContainer/Panel/RootVBox/EquippedSection/EquippedSlots/SlotShield
@onready var slot_helmet: TextureButton = $CenterContainer/Panel/RootVBox/EquippedSection/EquippedSlots/SlotHelmet
@onready var slot_armor: TextureButton = $CenterContainer/Panel/RootVBox/EquippedSection/EquippedSlots/SlotArmor
@onready var slot_boots: TextureButton = $CenterContainer/Panel/RootVBox/EquippedSection/EquippedSlots/SlotBoots

# Right Pane Detail Viewer
@onready var item_icon: TextureRect = $CenterContainer/Panel/RootVBox/BottomSection/RightPane/DetailVBox/IconCenter/ItemIcon
@onready var item_name_label: Label = $CenterContainer/Panel/RootVBox/BottomSection/RightPane/DetailVBox/ItemName
@onready var item_desc_label: Label = $CenterContainer/Panel/RootVBox/BottomSection/RightPane/DetailVBox/ItemDesc
@onready var item_stats_label: Label = $CenterContainer/Panel/RootVBox/BottomSection/RightPane/DetailVBox/ItemStats
@onready var action_button: Button = $CenterContainer/Panel/RootVBox/BottomSection/RightPane/DetailVBox/ActionButton
@onready var close_button: Button = $CenterContainer/Panel/RootVBox/TopBar/CloseButton

# Category buttons container
@onready var category_bar: HBoxContainer = $CenterContainer/Panel/RootVBox/BottomSection/LeftPane/CategoryBar

var selected_item_id: String = ""
var selected_is_equipped: bool = false
var selected_slot_type: String = ""
var active_category: String = "all"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	close_button.pressed.connect(toggle)
	action_button.pressed.connect(_on_action_button_pressed)
	Global.inventory_updated.connect(refresh_ui)
	
	_connect_slot(slot_weapon, "w")
	_connect_slot(slot_shield, "shi")
	_connect_slot(slot_helmet, "h")
	_connect_slot(slot_armor, "a")
	_connect_slot(slot_boots, "sho")
	
	_setup_category_buttons()
	refresh_ui()

func _exit_tree() -> void:
	if is_inside_tree() and get_tree().paused:
		get_tree().paused = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_backpack") and not event.is_echo():
		toggle()

func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		refresh_ui()

func _setup_category_buttons() -> void:
	for child in category_bar.get_children():
		if child is Button:
			var cat: String = child.name.to_lower().replace("btn", "")
			child.pressed.connect(func(): _set_category(cat))

func _set_category(cat: String) -> void:
	active_category = cat
	_highlight_active_category()
	_update_inventory_grid()

func _highlight_active_category() -> void:
	for child in category_bar.get_children():
		if child is Button:
			var cat: String = child.name.to_lower().replace("btn", "")
			if cat == active_category:
				child.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
			else:
				child.remove_theme_color_override("font_color")

func _connect_slot(btn: TextureButton, slot_key: String) -> void:
	btn.pressed.connect(func():
		var eq_id: String = Global.equipped.get(slot_key, "no")
		if eq_id != "no" and not eq_id.is_empty():
			_select_item(eq_id, true, slot_key)
	)

func refresh_ui() -> void:
	_update_equipped_slots()
	_highlight_active_category()
	_update_inventory_grid()
	_clear_selection()

func _update_equipped_slots() -> void:
	_update_slot_icon(slot_weapon, Global.equipped.get("w", "no"))
	_update_slot_icon(slot_shield, Global.equipped.get("shi", "no"))
	_update_slot_icon(slot_helmet, Global.equipped.get("h", "no"))
	_update_slot_icon(slot_armor, Global.equipped.get("a", "no"))
	_update_slot_icon(slot_boots, Global.equipped.get("sho", "no"))

func _update_slot_icon(btn: TextureButton, item_id: String) -> void:
	if btn == null:
		return
	var clean_id: String = item_id.strip_edges()
	if clean_id != "no" and not clean_id.is_empty():
		var item_data: Dictionary = ItemDatabase.get_item(clean_id)
		var tex_path: String = item_data.get("texture_path", "")
		if ResourceLoader.exists(tex_path):
			btn.texture_normal = load(tex_path)
			return
	btn.texture_normal = null

func _update_inventory_grid() -> void:
	for child in grid_container.get_children():
		grid_container.remove_child(child)
		child.queue_free()

	for item_id in Global.inventory:
		var clean_id: String = String(item_id).strip_edges()
		var item_data: Dictionary = ItemDatabase.get_item(clean_id)
		if item_data.is_empty():
			continue

		var slot: String = item_data.get("slot", "")
		if not _matches_category(slot, clean_id):
			continue

		var slot_btn := Button.new()
		slot_btn.custom_minimum_size = Vector2(76, 76)
		slot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_btn.expand_icon = true
		slot_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		var tex_path: String = item_data.get("texture_path", "")
		if ResourceLoader.exists(tex_path):
			slot_btn.icon = load(tex_path)
		else:
			slot_btn.text = item_data.get("name", clean_id)

		var captured_id: String = clean_id
		var captured_slot: String = slot
		slot_btn.pressed.connect(func():
			_select_item(captured_id, false, captured_slot)
		)
		grid_container.add_child(slot_btn)

func _matches_category(slot: String, item_id: String) -> bool:
	if active_category == "all":
		return true
	if active_category == "weapons" and slot == "w":
		return true
	if active_category == "helmets" and slot == "h":
		return true
	if active_category == "armor" and slot == "a":
		return true
	if active_category == "shields" and slot == "shi":
		return true
	if active_category == "boots" and slot == "sho":
		return true
	if active_category == "tools" and (slot == "tool" or item_id == "torch"):
		return true
	return false

func _select_item(id: String, is_eq: bool, slot_key: String) -> void:
	selected_item_id = id
	selected_is_equipped = is_eq
	selected_slot_type = slot_key
	
	var data := ItemDatabase.get_item(id)
	if data.is_empty():
		_clear_selection()
		return

	var tex_path: String = data.get("texture_path", "")
	if ResourceLoader.exists(tex_path):
		item_icon.texture = load(tex_path)
		item_icon.visible = true
	else:
		item_icon.visible = false

	item_name_label.text = ItemDatabase.get_item_display_name(id)
	item_desc_label.text = data.get("desc", "")
	
	var up_stats := ItemDatabase.get_upgraded_stats(id)
	var stats_str := ""
	if up_stats.get("atk", 0.0) > 0:
		stats_str += "ATK: +%d  " % int(up_stats["atk"])
	if up_stats.get("def", 0.0) > 0:
		stats_str += "DEF: +%d  " % int(up_stats["def"])
	if up_stats.get("cd", 0.0) > 0:
		stats_str += "CD: -%.1fs  " % up_stats["cd"]
	item_stats_label.text = stats_str

	action_button.visible = true
	if is_eq:
		action_button.text = "UNEQUIP"
	elif id == "torch":
		action_button.text = "REFUEL TORCH"
	else:
		action_button.text = "EQUIP"

func _clear_selection() -> void:
	selected_item_id = ""
	item_icon.texture = null
	item_icon.visible = false
	item_name_label.text = "Select an item"
	item_desc_label.text = "Choose gear from inventory or equipped slots to inspect."
	item_stats_label.text = ""
	action_button.visible = false

func _on_action_button_pressed() -> void:
	if selected_item_id.is_empty():
		return

	if selected_is_equipped:
		Global.unequip_item(selected_slot_type)
	elif selected_item_id == "torch":
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			players[0].refuel_torch_from_inventory()
	else:
		Global.equip_item(selected_item_id)

	refresh_ui()
