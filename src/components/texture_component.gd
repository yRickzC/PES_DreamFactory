extends Node2D
class_name TextureComponent

const OUTLINE_COLOR := Color(0.055, 0.12, 0.18, 1.0)

@export var texture: Texture2D
@export var placeholder_size := Vector2(32.0, 32.0)
@export var placeholder_color := Color(0.24, 0.78, 0.98, 1.0)


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-placeholder_size * 0.5, placeholder_size)
	if texture != null:
		draw_texture_rect(texture, rect, false)
	else:
		draw_rect(rect, placeholder_color)
	draw_rect(rect, OUTLINE_COLOR, false, 2.0)
