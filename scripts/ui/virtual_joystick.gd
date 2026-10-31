extends Control
class_name MobileVirtualJoystick

## virtual_joystick.gd
## Procedural circular virtual joystick designed for mobile and tablet touch controls.
## Renders smooth circular base and thumb knob via _draw() and clamps input within circular radius.

@export var base_radius: float = 100.0
@export var knob_radius: float = 40.0
@export var deadzone: float = 0.12

var touch_id: int = -1
var knob_offset: Vector2 = Vector2.ZERO
var output_vector: Vector2 = Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2((base_radius + 20.0) * 2.0, (base_radius + 20.0) * 2.0)
	queue_redraw()

func _draw() -> void:
	var center := size / 2.0
	
	# Outer circular base
	draw_circle(center, base_radius, Color(0.12, 0.14, 0.20, 0.45))
	draw_arc(center, base_radius, 0.0, TAU, 36, Color(0.7, 0.75, 0.9, 0.5), 3.5)

	# Inner circular thumb knob
	var knob_center := center + knob_offset
	draw_circle(knob_center, knob_radius, Color(0.85, 0.90, 1.0, 0.75))
	draw_arc(knob_center, knob_radius, 0.0, TAU, 28, Color(1.0, 1.0, 1.0, 0.95), 3.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			touch_id = event.index
			_update_knob(event.position)
		elif not event.pressed and event.index == touch_id:
			_reset_knob()

	elif event is InputEventScreenDrag and event.index == touch_id:
		_update_knob(event.position)

	# Mouse fallback for desktop / editor testing
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_update_knob(event.position)
			else:
				_reset_knob()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_knob(event.position)

func _update_knob(touch_pos: Vector2) -> void:
	var center := size / 2.0
	var touch_offset := touch_pos - center
	
	# Clamp knob position within circular radius
	knob_offset = touch_offset.limit_length(base_radius)
	
	var raw_vec := knob_offset / base_radius
	if raw_vec.length() < deadzone:
		output_vector = Vector2.ZERO
	else:
		output_vector = raw_vec

	queue_redraw()
	_dispatch_to_player()

func _reset_knob() -> void:
	touch_id = -1
	knob_offset = Vector2.ZERO
	output_vector = Vector2.ZERO
	queue_redraw()
	_dispatch_to_player()

func _dispatch_to_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p = players[0]
		if "virtual_input_vector" in p:
			p.virtual_input_vector = output_vector
