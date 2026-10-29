extends Node
class_name MovementComponent

@export_range(0.0, 1000.0, 1.0) var speed: float = 220.0


func get_velocity() -> Vector2:
	return _get_direction() * speed


func _get_direction() -> Vector2:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var wasd_direction := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	return (direction + wasd_direction).limit_length(1.0)
