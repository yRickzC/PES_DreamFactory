extends Node2D
class_name PlayerSystem

@onready var movement_component: MovementComponent = $MovementComponent
@onready var texture_component: TextureComponent = $TextureComponent
@onready var world_system: WorldSystem = get_node("../WorldSystem")

const BODY_HEIGHT := 0.72
const MAX_STEP_UP := 1.0
const GRAVITY := 18.0
const JUMP_IMPULSE := 7.4
const FALL_LIMIT := -2.5

var elevation := 0.0
var vertical_velocity := 0.0
var is_grounded := true
var spawn_position := Vector2.ZERO
var _jump_was_pressed := false
var _reset_was_pressed := false


func _ready() -> void:
	spawn_position = global_position
	var cell := world_system.world_to_cell(global_position)
	var support := world_system.get_support_below(cell.x, cell.y, 0.05)
	if support >= 0.0:
		elevation = support
	_update_visual_height()


func _physics_process(delta: float) -> void:
	var jump_pressed := Input.is_key_pressed(KEY_SPACE) or Input.is_action_pressed("ui_accept")
	var jump_just_pressed := jump_pressed and not _jump_was_pressed
	_jump_was_pressed = jump_pressed
	var reset_pressed := Input.is_key_pressed(KEY_R)
	if reset_pressed and not _reset_was_pressed:
		_respawn()
	_reset_was_pressed = reset_pressed

	_move_on_ground(movement_component.get_direction() * movement_component.speed * delta)
	_update_vertical_motion(delta, jump_just_pressed)
	_update_visual_height()


func _move_on_ground(displacement: Vector2) -> void:
	var step_count := maxi(1, ceili(displacement.length() / 4.0))
	var substep := displacement / float(step_count)
	for _step in range(step_count):
		_try_move_by(Vector2(substep.x, 0.0))
		_try_move_by(Vector2(0.0, substep.y))


func _try_move_by(displacement: Vector2) -> void:
	if displacement.is_zero_approx():
		return
	var target_position := global_position + displacement
	var target_cell := world_system.world_to_cell(target_position)
	if not world_system.is_inside_cell(target_cell.x, target_cell.y):
		return

	var target_elevation := elevation
	var target_support := world_system.get_support_below(target_cell.x, target_cell.y, elevation + MAX_STEP_UP + 0.01)
	if is_grounded and target_support > elevation + MAX_STEP_UP + 0.01:
		return
	if is_grounded and target_support >= elevation - 0.05 and target_support <= elevation + MAX_STEP_UP + 0.01:
		target_elevation = target_support
	if not world_system.can_occupy(target_cell.x, target_cell.y, target_elevation, BODY_HEIGHT):
		return

	global_position = target_position
	if is_grounded:
		if target_support >= elevation - 0.05 and target_support <= elevation + MAX_STEP_UP + 0.01:
			elevation = target_support
		elif target_support < elevation - 0.05:
			is_grounded = false
		elif target_support < 0.0:
			is_grounded = false


func _update_vertical_motion(delta: float, jump_just_pressed: bool) -> void:
	var cell := world_system.world_to_cell(global_position)
	if is_grounded:
		var support := world_system.get_support_below(cell.x, cell.y, elevation + 0.05)
		if support < 0.0 or support < elevation - 0.05:
			is_grounded = false
		else:
			elevation = support
		if jump_just_pressed and is_grounded:
			vertical_velocity = JUMP_IMPULSE
			is_grounded = false

	if not is_grounded:
		var previous_elevation := elevation
		vertical_velocity -= GRAVITY * delta
		var next_elevation := elevation + vertical_velocity * delta
		if vertical_velocity > 0.0:
			var ceiling_bottom := world_system.find_ceiling_bottom(
				cell.x,
				cell.y,
				previous_elevation + BODY_HEIGHT,
				next_elevation + BODY_HEIGHT
			)
			if ceiling_bottom >= 0.0:
				next_elevation = ceiling_bottom - BODY_HEIGHT
				vertical_velocity = 0.0
		if vertical_velocity <= 0.0:
			var landing_height := world_system.get_support_below(cell.x, cell.y, previous_elevation + 0.01)
			if landing_height >= 0.0 and next_elevation <= landing_height and previous_elevation >= landing_height - 0.01:
				next_elevation = landing_height
				vertical_velocity = 0.0
				is_grounded = true
		elevation = next_elevation

	if elevation < FALL_LIMIT:
		_respawn()


func _update_visual_height() -> void:
	texture_component.position.y = -elevation * WorldSystem.HEIGHT_STEP_PIXELS
	queue_redraw()


func _respawn() -> void:
	global_position = spawn_position
	var cell := world_system.world_to_cell(global_position)
	elevation = world_system.get_support_below(cell.x, cell.y, WorldSystem.HEIGHT_LEVELS)
	if elevation < 0.0:
		elevation = 0.0
	vertical_velocity = 0.0
	is_grounded = true


func _draw() -> void:
	draw_rect(Rect2(Vector2(-7.0, -3.0), Vector2(14.0, 6.0)), Color(0.06, 0.13, 0.12, 0.42))
