extends Node

## PlatformManager.gd
## Decoupled platform bridge interface designed for Huawei GameCenter / HMS Core (Account Kit, Game Service).
## Automatically provides clean mock responses on Desktop / Windows / Editor while interfacing with
## native Android Java plugins when available.

signal hms_login_result(success: bool, user_id: String, display_name: String)
signal hms_score_submitted(leaderboard_id: String, score: int, success: bool)
signal hms_achievement_unlocked(achievement_id: String, success: bool)

var hms_game_service = null
var hms_account_service = null

func _ready() -> void:
	_init_platform()

func _init_platform() -> void:
	if OS.get_name() == "Android":
		if Engine.has_singleton("GodotHMSGameService"):
			hms_game_service = Engine.get_singleton("GodotHMSGameService")
			print("[PlatformManager] GodotHMSGameService singleton found.")
		if Engine.has_singleton("GodotHMSAccount"):
			hms_account_service = Engine.get_singleton("GodotHMSAccount")
			print("[PlatformManager] GodotHMSAccount singleton found.")
	else:
		print("[PlatformManager] Desktop mode: Using mock HMS platform bridge.")

func sign_in() -> void:
	if hms_account_service:
		hms_account_service.signIn()
	else:
		# Mock desktop response
		print("[PlatformManager - Mock] Simulating Huawei Account Kit sign in...")
		await get_tree().create_timer(0.3).timeout
		emit_signal("hms_login_result", true, "mock_huawei_uid_12345", Global.username)

func submit_score(leaderboard_id: String, score: int) -> void:
	if hms_game_service:
		hms_game_service.submitScore(leaderboard_id, score)
	else:
		print("[PlatformManager - Mock] Submitted score ", score, " to leaderboard: ", leaderboard_id)
		emit_signal("hms_score_submitted", leaderboard_id, score, true)

func unlock_achievement(achievement_id: String) -> void:
	if hms_game_service:
		hms_game_service.unlockAchievement(achievement_id)
	else:
		print("[PlatformManager - Mock] Unlocked HMS achievement: ", achievement_id)
		emit_signal("hms_achievement_unlocked", achievement_id, true)

