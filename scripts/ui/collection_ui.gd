extends Control
class_name CollectionUI

## collection_ui.gd
## Hero Chick Collection gallery displaying all playable chicks.
## Locked chicks appear as dark silhouettes. Selecting an unlocked chick
## shows stats, lore, and enables equipping as the active hero.

@onready var close_btn: Button = $CenterContainer/Panel/CloseButton
@onready var chick_grid: GridContainer = $CenterContainer/Panel/HBoxContainer/LeftScroll/ChickGrid

# Detail Panel
@onready var detail_portrait: TextureRect = $CenterContainer/Panel/HBoxContainer/DetailPanel/VBoxContainer/PortraitCenter/Portrait
@onready var detail_name: Label = $CenterContainer/Panel/HBoxContainer/DetailPanel/VBoxContainer/NameLabel
@onready var detail_stats: Label = $CenterContainer/Panel/HBoxContainer/DetailPanel/VBoxContainer/StatsLabel
@onready var detail_lore: Label = $CenterContainer/Panel/HBoxContainer/DetailPanel/VBoxContainer/LoreLabel
@onready var equip_btn: Button = $CenterContainer/Panel/HBoxContainer/DetailPanel/VBoxContainer/EquipButton
@onready var status_lbl: Label = $CenterContainer/Panel/HBoxContainer/DetailPanel/VBoxContainer/StatusLabel

const COMING_SOON_CHICKS := ["pink", "pinky", "geek", "kun"]

var selected_chick_id: String = "normal"

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(toggle)
	equip_btn.pressed.connect(_on_equip_pressed)

func toggle() -> void:
	visible = not visible
	if visible:
		selected_chick_id = Global.active_chick
		if selected_chick_id in COMING_SOON_CHICKS:
			selected_chick_id = "normal"
		refresh_collection()

func refresh_collection() -> void:
	for child in chick_grid.get_children():
		chick_grid.remove_child(child)
		child.queue_free()

	for chick_key in Global.CHICK_STATS.keys():
		var chick_id: String = String(chick_key)
		var info: Dictionary = Global.CHICK_STATS[chick_id]
		var is_coming_soon: bool = (chick_id in COMING_SOON_CHICKS)
		var is_unlocked: bool = Global.unlocked_chicks.has(chick_id) and not is_coming_soon
		var is_active: bool = (Global.active_chick == chick_id) and not is_coming_soon
		
		var card := Button.new()
		card.custom_minimum_size = Vector2(130, 150)
		card.clip_contents = true
		
		var vbox := VBoxContainer.new()
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var icon_center := CenterContainer.new()
		icon_center.custom_minimum_size = Vector2(120, 80)
		icon_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(72, 72)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = true
		
		var portrait_path: String = info.get("portrait", "")
		if ResourceLoader.exists(portrait_path):
			icon.texture = load(portrait_path)
		elif ResourceLoader.exists("res://graphic/chicky.png"):
			icon.texture = load("res://graphic/chicky.png")
			
		if is_coming_soon:
			icon.modulate = Color(0.2, 0.2, 0.2, 1.0)
		elif not is_unlocked:
			icon.modulate = Color(0.2, 0.2, 0.2, 0.85)
		else:
			icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
			
		icon_center.add_child(icon)
			
		var name_lbl := Label.new()
		name_lbl.text = info.get("name", chick_id)
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var sub_lbl := Label.new()
		sub_lbl.add_theme_font_size_override("font_size", 18)
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_coming_soon:
			sub_lbl.text = "COMING SOON"
			sub_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
			card.disabled = true
			card.focus_mode = Control.FOCUS_NONE
		elif is_active:
			sub_lbl.text = "[EQUIPPED]"
			sub_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
		elif is_unlocked:
			sub_lbl.text = "Unlocked"
			sub_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4, 1.0))
		else:
			sub_lbl.text = "LOCKED"
			sub_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
			
		vbox.add_child(icon_center)
		vbox.add_child(name_lbl)
		vbox.add_child(sub_lbl)
		card.add_child(vbox)
		
		if not is_coming_soon:
			var captured_id: String = chick_id
			card.pressed.connect(func(): _select_chick(captured_id))
			
		chick_grid.add_child(card)

	_show_chick_details(selected_chick_id)

func _select_chick(chick_id: String) -> void:
	if chick_id in COMING_SOON_CHICKS:
		return
	selected_chick_id = chick_id
	_show_chick_details(chick_id)

func _show_chick_details(chick_id: String) -> void:
	var info: Dictionary = Global.CHICK_STATS.get(chick_id, Global.CHICK_STATS["normal"])
	var is_coming_soon: bool = (chick_id in COMING_SOON_CHICKS)
	var is_unlocked: bool = Global.unlocked_chicks.has(chick_id) and not is_coming_soon
	var is_active: bool = (Global.active_chick == chick_id) and not is_coming_soon
	
	detail_name.text = info.get("name", chick_id)
	var portrait_path: String = info.get("portrait", "")
	if ResourceLoader.exists(portrait_path):
		detail_portrait.texture = load(portrait_path)
	elif ResourceLoader.exists("res://graphic/chicky.png"):
		detail_portrait.texture = load("res://graphic/chicky.png")
	detail_portrait.visible = true
	detail_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
	if is_coming_soon:
		detail_portrait.modulate = Color(0.2, 0.2, 0.2, 1.0)
		detail_stats.text = "HP: ???   DEF: ???   ATK: ???\nCooldown: ???   Speed: ???"
		detail_lore.text = "This Chick is currently under development. Coming soon in a future update!"
		status_lbl.text = "COMING SOON"
		status_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
		equip_btn.disabled = true
		equip_btn.text = "COMING SOON"
	elif is_unlocked:
		detail_portrait.modulate = Color(1, 1, 1, 1)
		detail_stats.text = "HP: %d   DEF: %d   ATK: %d\nCooldown: %.1fs   Speed: %d" % [
			int(info.get("hp", 100)),
			int(info.get("def", 0)),
			int(info.get("atk", 15)),
			float(info.get("cd", 4.0)),
			int(info.get("speed", 180))
		]
		detail_lore.text = info.get("lore", "")
		status_lbl.text = ""
		
		if is_active:
			equip_btn.disabled = true
			equip_btn.text = "CURRENTLY EQUIPPED"
		else:
			equip_btn.disabled = false
			equip_btn.text = "EQUIP HERO"
	else:
		detail_portrait.modulate = Color(0.2, 0.2, 0.2, 0.85)
		detail_stats.text = "HP: ???   DEF: ???   ATK: ???\nCooldown: ???   Speed: ???"
		detail_lore.text = "This Chick is currently locked. Try your luck in the Hero Gacha to summon them!"
		status_lbl.text = "LOCKED HERO"
		status_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))
		equip_btn.disabled = true
		equip_btn.text = "LOCKED"

func _on_equip_pressed() -> void:
	if selected_chick_id in COMING_SOON_CHICKS:
		return
	if Global.unlocked_chicks.has(selected_chick_id):
		Global.active_chick = selected_chick_id
		Global.save_player_data()
		refresh_collection()
