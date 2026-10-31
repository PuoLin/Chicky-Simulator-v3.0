extends Control
class_name WinDialog

## win_dialog.gd
## Stage victory popup displaying performance rewards, HMS Core cloud sync hook,
## and next stage progression (including grand game completion at stage 20).

@onready var title_label: Label = $CenterContainer/Panel/VBoxContainer/TitleLabel
@onready var reward_label: Label = $CenterContainer/Panel/VBoxContainer/RewardLabel
@onready var diamond_bonus_label: Label = $CenterContainer/Panel/VBoxContainer/DiamondBonusLabel
@onready var time_label: Label = $CenterContainer/Panel/VBoxContainer/TimeLabel
@onready var next_button: Button = $CenterContainer/Panel/VBoxContainer/HBoxContainer/NextButton
@onready var menu_button: Button = $CenterContainer/Panel/VBoxContainer/HBoxContainer/MenuButton

func _ready() -> void:
	visible = false
	next_button.pressed.connect(_on_next_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

func show_victory(stage: int, coins_earned: int, time_spent: float, is_replay: bool = false, milestone_diamonds: int = 0) -> void:
	visible = true
	
	var reward_text := "+%d Coins" % coins_earned
	if is_replay:
		reward_text += ""
	else:
		reward_text += " (First Clear!)"
	
	if stage >= 30:
		title_label.text = "VICTORY!\nALL 30 STAGES CLEARED!"
		reward_label.text = "Grand Reward: " + reward_text
		next_button.visible = false
		menu_button.text = "MAIN MENU"
	else:
		title_label.text = "STAGE %d CLEARED!" % stage
		reward_label.text = "Reward: " + reward_text
		next_button.visible = true
		next_button.text = "NEXT STAGE"
		menu_button.text = "MENU"
	
	if diamond_bonus_label:
		if milestone_diamonds > 0:
			if stage in [10, 20, 30]:
				diamond_bonus_label.text = "★ BOSS MILESTONE: +%d DIAMONDS! ★" % milestone_diamonds
			else:
				diamond_bonus_label.text = "Milestone Bonus: +%d Diamonds" % milestone_diamonds
			diamond_bonus_label.visible = true
		else:
			diamond_bonus_label.visible = false

	
	var m := int(time_spent / 60.0)
	var s := int(fmod(time_spent, 60.0))
	time_label.text = "Time: %02d:%02d" % [m, s]

	# Unlock next stage if progressing
	if stage >= Global.highest_stage and Global.highest_stage < 30:
		Global.highest_stage = stage + 1
	Global.save_player_data()

	# Hook into PlatformManager for Huawei GameCenter achievements & leaderboard
	PlatformManager.submit_score("leaderboard_stage_clears", stage)
	PlatformManager.unlock_achievement("achieve_stage_%d" % stage)

func _on_next_pressed() -> void:
	visible = false
	if Global.current_stage < 30:
		Global.init_stage(Global.current_stage + 1)
		if is_inside_tree() and get_tree():
			get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	visible = false
	if is_inside_tree() and get_tree():
		get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
