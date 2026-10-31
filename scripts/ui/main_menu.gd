extends Control
class_name MainMenu

## main_menu.gd
## Main menu scene controller providing navigation to Play, Stage Select, Backpack,
## Shop, Hero Gacha, Hero Collection, Missions, Achievements, Audio Settings, and Huawei HMS sign in.

@onready var title_label: Label = $Title
@onready var profile_label: Label = $TopBar/ProfileLabel
@onready var currency_box: Control = get_node_or_null("TopBar/CurrencyBox")
@onready var coin_label: Label = get_node_or_null("TopBar/CurrencyBox/CoinLabel")
@onready var diamond_label: Label = get_node_or_null("TopBar/CurrencyBox/DiamondLabel")
@onready var currency_label: Label = get_node_or_null("TopBar/CurrencyLabel")
@onready var settings_btn: Button = $TopBar/SettingsButton

# Center Action Buttons
@onready var play_btn: Button = $CenterVBox/PlayButton
@onready var select_btn: Button = $CenterVBox/SelectButton

# Left Flank Icon Navigation
@onready var backpack_btn: Button = $LeftNav/BackpackBox/BackpackBtn
@onready var collection_btn: Button = $LeftNav/CollectionBox/CollectionBtn
@onready var missions_btn: Button = $LeftNav/MissionsBox/MissionsBtn
@onready var blacksmith_btn: Button = $LeftNav/BlacksmithBox/BlacksmithBtn

# Right Flank Icon Navigation
@onready var achievements_btn: Button = $RightNav/AchievementsBox/AchievementsBtn
@onready var gacha_btn: Button = $RightNav/GachaBox/GachaBtn
@onready var shop_btn: Button = $RightNav/ShopBox/ShopBtn

# Modals in CanvasLayer
@onready var backpack_ui: Control = $CanvasLayer/BackpackUI
@onready var shop_ui: Control = $CanvasLayer/ShopUI
@onready var gacha_ui: Control = $CanvasLayer/GachaUI
@onready var collection_ui: Control = $CanvasLayer/CollectionUI
@onready var missions_ui: Control = $CanvasLayer/MissionsUI
@onready var achievements_ui: Control = $CanvasLayer/AchievementsUI
@onready var settings_ui: Control = $CanvasLayer/SettingsUI
@onready var blacksmith_ui: Control = $CanvasLayer/BlacksmithUI

func _ready() -> void:
	AudioManager.play_music("menu")
	
	play_btn.pressed.connect(_on_play_pressed)
	select_btn.pressed.connect(_on_select_pressed)
	
	backpack_btn.pressed.connect(func(): _open_modal(backpack_ui))
	collection_btn.pressed.connect(func(): _open_modal(collection_ui))
	missions_btn.pressed.connect(func(): _open_modal(missions_ui))
	blacksmith_btn.pressed.connect(func(): _open_modal(blacksmith_ui))
	
	achievements_btn.pressed.connect(func(): _open_modal(achievements_ui))
	gacha_btn.pressed.connect(func(): _open_modal(gacha_ui))
	shop_btn.pressed.connect(func(): _open_modal(shop_ui))
	
	settings_btn.pressed.connect(func(): _open_modal(settings_ui))
	
	Global.coins_changed.connect(func(_val): _update_profile_display())
	Global.diamonds_changed.connect(func(_val): _update_profile_display())
	
	_update_profile_display()

func _update_profile_display() -> void:
	if profile_label:
		profile_label.text = "Hero: %s | Stage: %d" % [
			Global.CHICK_STATS.get(Global.active_chick, {}).get("name", Global.active_chick.capitalize()),
			Global.highest_stage
		]
	if coin_label:
		coin_label.text = str(Global.coins)
	if diamond_label:
		diamond_label.text = str(Global.diamonds)
	elif currency_label:
		currency_label.text = "%d  |  %d" % [Global.coins, Global.diamonds]

func _open_modal(target_modal: Control) -> void:
	if not target_modal:
		return
	# Close others first
	var modals := [backpack_ui, shop_ui, gacha_ui, collection_ui, missions_ui, achievements_ui, settings_ui, blacksmith_ui]
	for m in modals:
		if m and m != target_modal and m.visible:
			m.visible = false
			
	if target_modal.has_method("toggle"):
		target_modal.toggle()
	else:
		target_modal.visible = not target_modal.visible
		
	_update_profile_display()

func _on_play_pressed() -> void:
	Global.init_stage(min(30, Global.highest_stage))
	get_tree().change_scene_to_file("res://scenes/main/Level.tscn")

func _on_select_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/LevelSelect.tscn")
