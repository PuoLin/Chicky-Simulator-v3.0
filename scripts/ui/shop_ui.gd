extends Control
class_name ShopUI

## shop_ui.gd
## Equipment shop allowing players to spend collected coins to purchase weapons,
## armor, accessories, and torches with category filtering and uniform grid sizing.

@onready var grid: GridContainer = $CenterContainer/Panel/ScrollContainer/ItemGrid
@onready var close_btn: Button = $CenterContainer/Panel/CloseButton
@onready var coin_label: Label = get_node_or_null("CenterContainer/Panel/TopBar/CoinBox/CoinLabel") if get_node_or_null("CenterContainer/Panel/TopBar/CoinBox/CoinLabel") else get_node_or_null("CenterContainer/Panel/TopBar/CoinLabel")
@onready var diamond_label: Label = get_node_or_null("CenterContainer/Panel/TopBar/DiamondBox/DiamondLabel") if get_node_or_null("CenterContainer/Panel/TopBar/DiamondBox/DiamondLabel") else get_node_or_null("CenterContainer/Panel/TopBar/DiamondLabel")
@onready var buy_diamonds_btn: Button = get_node_or_null("CenterContainer/Panel/TopBar/BuyDiamondsButton") if get_node_or_null("CenterContainer/Panel/TopBar/BuyDiamondsButton") else get_node_or_null("CenterContainer/Panel/TopBar/BuyDiamondsBtn")
@onready var mock_payment_gateway: Control = get_node_or_null("MockPaymentGateway")
@onready var feedback_label: Label = $CenterContainer/Panel/FeedbackLabel
@onready var category_bar: HBoxContainer = $CenterContainer/Panel/CategoryBar

const SHOP_CATALOG := [
	{"id": "axe", "price": 250},
	{"id": "hammer", "price": 800},
	{"id": "sword", "price": 2000},
	{"id": "shield3", "price": 170},
	{"id": "shield4", "price": 500},
	{"id": "shield5", "price": 1400},
	{"id": "helmet3", "price": 170},
	{"id": "helmet4", "price": 500},
	{"id": "helmet5", "price": 1400},
	{"id": "armor3", "price": 250},
	{"id": "armor4", "price": 750},
	{"id": "armor5", "price": 1800},
	{"id": "shoe3", "price": 160},
	{"id": "shoe4", "price": 450},
	{"id": "shoe5", "price": 1400},
	{"id": "torch", "price": 50}
]

var active_category: String = "all"

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(toggle)
	Global.coins_changed.connect(_on_coins_changed)
	Global.diamonds_changed.connect(_on_diamonds_changed)
	_setup_categories()
	_setup_iap_gateway()
	_on_coins_changed(Global.coins)
	_on_diamonds_changed(Global.diamonds)

func _setup_iap_gateway() -> void:
	if buy_diamonds_btn and not buy_diamonds_btn.pressed.is_connected(_on_buy_diamonds_pressed):
		buy_diamonds_btn.pressed.connect(_on_buy_diamonds_pressed)
	
	if mock_payment_gateway:
		mock_payment_gateway.visible = false
		var confirm_btn: BaseButton = mock_payment_gateway.find_child("ConfirmButton", true, false) as BaseButton
		if not confirm_btn:
			confirm_btn = mock_payment_gateway.find_child("ConfirmPayment", true, false) as BaseButton
		if confirm_btn and not confirm_btn.pressed.is_connected(_on_confirm_payment_pressed):
			confirm_btn.pressed.connect(_on_confirm_payment_pressed)
			
		var cancel_btn: BaseButton = mock_payment_gateway.find_child("CancelButton", true, false) as BaseButton
		if not cancel_btn:
			cancel_btn = mock_payment_gateway.find_child("Cancel", true, false) as BaseButton
		if cancel_btn and not cancel_btn.pressed.is_connected(_on_cancel_payment_pressed):
			cancel_btn.pressed.connect(_on_cancel_payment_pressed)

func _setup_categories() -> void:
	for child in category_bar.get_children():
		if child is Button:
			var cat: String = child.name.to_lower().replace("btn", "")
			child.pressed.connect(func(): _set_category(cat))

func _set_category(cat: String) -> void:
	active_category = cat
	_highlight_active_category()
	refresh_shop()

func _highlight_active_category() -> void:
	for child in category_bar.get_children():
		if child is Button:
			var cat: String = child.name.to_lower().replace("btn", "")
			if cat == active_category:
				child.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
			else:
				child.remove_theme_color_override("font_color")

func toggle() -> void:
	visible = not visible
	if visible:
		feedback_label.text = ""
		_highlight_active_category()
		refresh_shop()
	else:
		if mock_payment_gateway:
			mock_payment_gateway.hide()

func _on_coins_changed(amount: int) -> void:
	if coin_label:
		coin_label.text = str(amount)

func _on_diamonds_changed(amount: int) -> void:
	if diamond_label:
		diamond_label.text = str(amount)

func _on_buy_diamonds_pressed() -> void:
	if mock_payment_gateway:
		mock_payment_gateway.show()

func _on_cancel_payment_pressed() -> void:
	if mock_payment_gateway:
		mock_payment_gateway.hide()

func _on_confirm_payment_pressed() -> void:
	if mock_payment_gateway:
		mock_payment_gateway.hide()
	Global.diamonds += 1000
	Global.save_player_data()
	Global.emit_signal("diamonds_changed", Global.diamonds)
	if diamond_label:
		diamond_label.text = str(Global.diamonds)
	_show_feedback("Purchased 1000 Diamonds!", Color(0.4, 1.0, 0.4, 1.0))

func refresh_shop() -> void:
	_on_coins_changed(Global.coins)
	_on_diamonds_changed(Global.diamonds)
	for child in grid.get_children():
		child.queue_free()

	for entry in SHOP_CATALOG:
		var item_data := ItemDatabase.get_item(entry["id"])
		if item_data.is_empty():
			continue

		var slot: String = item_data.get("slot", "")
		if not _matches_category(slot, entry["id"]):
			continue

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(210, 230)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 6)
		
		# Icon
		var tex_rect := TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(64, 64)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_path: String = item_data.get("texture_path", "")
		if ResourceLoader.exists(icon_path):
			tex_rect.texture = load(icon_path)
			
		var name_lbl := Label.new()
		name_lbl.text = item_data.get("name", entry["id"])
		name_lbl.add_theme_font_size_override("font_size", 24)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		var desc_lbl := Label.new()
		desc_lbl.text = item_data.get("desc", "")
		desc_lbl.add_theme_font_size_override("font_size", 18)
		desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		var buy_btn := Button.new()
		buy_btn.text = "%d Coins" % entry["price"]
		buy_btn.custom_minimum_size = Vector2(150, 48)
		buy_btn.add_theme_font_size_override("font_size", 22)
		buy_btn.pressed.connect(func(): _buy_item(entry["id"], entry["price"], item_data.get("name", entry["id"])))

		vbox.add_child(tex_rect)
		vbox.add_child(name_lbl)
		vbox.add_child(desc_lbl)
		vbox.add_child(buy_btn)
		
		card.add_child(vbox)
		grid.add_child(card)

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

func _buy_item(item_id: String, price: int, item_name: String) -> void:
	if Global.spend_coins(price):
		var item_data := ItemDatabase.get_item(item_id).duplicate(true)
		item_data["level"] = 1
		Global.add_inventory_item(item_data)
		_show_feedback("Purchased %s!" % item_name, Color(0.4, 1.0, 0.4, 1.0))
	else:
		_show_feedback("Not enough coins for %s!" % item_name, Color(1.0, 0.4, 0.4, 1.0))

func _show_feedback(msg: String, color: Color) -> void:
	feedback_label.text = msg
	feedback_label.add_theme_color_override("font_color", color)
	var tween := create_tween()
	tween.tween_property(feedback_label, "modulate:a", 1.0, 0.2)
	tween.tween_interval(2.0)
	tween.tween_property(feedback_label, "modulate:a", 0.0, 0.4)
