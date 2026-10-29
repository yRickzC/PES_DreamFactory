extends Node2D
class_name RoofOcclusionRenderer

const ROOF_SHADER := preload("res://src/world/roof_occlusion.gdshader")

@onready var world_system: WorldSystem = get_node("../WorldSystem")
@onready var player_system: PlayerSystem = get_node("../Player")

var roof_material: ShaderMaterial


func _ready() -> void:
	roof_material = ShaderMaterial.new()
	roof_material.shader = ROOF_SHADER
	material = roof_material
	queue_redraw()


func _process(_delta: float) -> void:
	if not is_instance_valid(player_system):
		return
	var screen_position := get_viewport().get_canvas_transform() * player_system.global_position
	screen_position.y -= player_system.elevation * WorldSystem.HEIGHT_STEP_PIXELS
	roof_material.set_shader_parameter("player_screen_position", screen_position)
	roof_material.set_shader_parameter("viewport_size", get_viewport_rect().size)
	roof_material.set_shader_parameter("player_top", player_system.elevation + PlayerSystem.BODY_HEIGHT)


func _draw() -> void:
	var bounds := world_system.get_visible_cell_bounds()
	for y in range(bounds.position.y, bounds.position.y + bounds.size.y):
		for x in range(bounds.position.x, bounds.position.x + bounds.size.x):
			for level in range(WorldSystem.HEIGHT_LEVELS):
				if not world_system.is_overhead_cell(x, y, level):
					continue
				var roof_height := world_system.get_overhead_height(x, y, level)
				var top_left := Vector2(
					x * WorldSystem.TILE_SIZE,
					y * WorldSystem.TILE_SIZE - roof_height * WorldSystem.HEIGHT_STEP_PIXELS
				)
				var tile := Rect2(top_left, Vector2(WorldSystem.TILE_SIZE, WorldSystem.TILE_SIZE))
				var roof_color := world_system.get_overhead_color(x, y, level)
				draw_rect(tile, roof_color)
				draw_rect(tile, Color(0.08, 0.10, 0.13, roof_color.a), false, 1.0)
