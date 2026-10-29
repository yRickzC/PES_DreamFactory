extends Node2D
class_name RoofOcclusionRenderer

const ROOF_SHADER := preload("res://src/world/roof_occlusion.gdshader")

@onready var world_system: WorldSystem = get_node("../WorldSystem")
@onready var player_system: PlayerSystem = get_node("../Player")

var roof_material: ShaderMaterial
var _last_revision := -1
var _last_visible_bounds := Rect2i(-1, -1, -1, -1)


func _ready() -> void:
	roof_material = ShaderMaterial.new()
	roof_material.shader = ROOF_SHADER
	material = roof_material
	queue_redraw()


func _process(_delta: float) -> void:
	if not is_instance_valid(player_system):
		return
	var bounds := world_system.get_visible_cell_bounds()
	if bounds != _last_visible_bounds or _last_revision != world_system.render_revision:
		_last_revision = world_system.render_revision
		_last_visible_bounds = bounds
		queue_redraw()
	var screen_position := get_viewport().get_canvas_transform() * (player_system.global_position - Vector2(0, player_system.elevation * WorldSystem.HEIGHT_STEP_PIXELS))
	roof_material.set_shader_parameter("player_screen_position", screen_position)
	roof_material.set_shader_parameter("viewport_size", get_viewport_rect().size)
	roof_material.set_shader_parameter("reveal_radius", 28.0 * player_system.get_node("FollowCamera").zoom.x)
	roof_material.set_shader_parameter("player_top", player_system.elevation + PlayerSystem.BODY_HEIGHT)


func _draw() -> void:
	var bounds := world_system.get_visible_cell_bounds()
	for cell in world_system.overhead_cells:
		if not bounds.has_point(Vector2i(cell.x, cell.y)):
			continue
		var roof_height := world_system.get_overhead_height(cell.x, cell.y, cell.z)
		var top_left := Vector2(cell.x * WorldSystem.TILE_SIZE, cell.y * WorldSystem.TILE_SIZE - roof_height * WorldSystem.HEIGHT_STEP_PIXELS)
		var roof_color := world_system.get_overhead_color(cell.x, cell.y, cell.z)
		draw_rect(Rect2(top_left, Vector2.ONE * WorldSystem.TILE_SIZE), roof_color)
