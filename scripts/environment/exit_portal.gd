extends Area2D
class_name ExitPortal

## exit_portal.gd
## Exit gateway represented by bananacat.png that appears at a randomized cave location
## and illuminates once the stage kill target has been met.

signal portal_entered()

var is_open: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var light: PointLight2D = $PointLight2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_setup_light()
	_update_state()

func _setup_light() -> void:
	if light.texture == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(0.4, 1.0, 0.5, 1.0))
		grad.set_color(1, Color(0.1, 0.8, 0.2, 0.0))
		
		var grad_tex := GradientTexture2D.new()
		grad_tex.gradient = grad
		grad_tex.fill = GradientTexture2D.FILL_RADIAL
		grad_tex.fill_from = Vector2(0.5, 0.5)
		grad_tex.fill_to = Vector2(1.0, 0.5)
		grad_tex.width = 128
		grad_tex.height = 128
		light.texture = grad_tex

func open_portal() -> void:
	is_open = true
	_update_state()
	
	# Exciting activation pulse
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)

func _update_state() -> void:
	if is_open:
		visible = true
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		light.enabled = true
		light.energy = 1.2
	else:
		visible = false
		modulate = Color(0.35, 0.35, 0.45, 0.0)
		light.enabled = false

func _on_body_entered(body: Node2D) -> void:
	if is_open and body.is_in_group("player"):
		emit_signal("portal_entered")
