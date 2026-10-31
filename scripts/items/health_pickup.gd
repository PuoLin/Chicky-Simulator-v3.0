extends Area2D
class_name HealthPickup

## health_pickup.gd
## HP-restoring food/potion pickup dropped by defeated monsters.
## Restores player HP upon contact and syncs overhead bars and HUD.

@export var heal_amount: float = 30.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# Gentle hovering bounce effect
	var tween := create_tween().set_loops()
	tween.tween_property($Sprite2D, "position:y", -3.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property($Sprite2D, "position:y", 3.0, 0.5).set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("heal"):
		body.heal(heal_amount)
		queue_free()

