extends Node2D
class_name PlayerSystem

@onready var movement_component: MovementComponent = $MovementComponent
@onready var texture_component: TextureComponent = $TextureComponent
@onready var follow_camera: Camera2D = $FollowCamera
@onready var world_system: WorldSystem = get_node("../WorldSystem")

const BODY_HEIGHT := 0.72
const BODY_RADIUS := 5.0
const GRAVITY := 18.0
const JUMP_IMPULSE := 7.4
const FALL_LIMIT := -2.5

var elevation := 0.0
var vertical_velocity := 0.0
var is_grounded := true
var spawn_position := Vector2.ZERO
var shadow_elevation := 0.0
var landing_target := Vector3.ZERO
var has_landing_target := false
var landing_time := 0.0
var _prediction_timer := 0.0
var _has_ground_shadow := false
var _jump_was_pressed := false
var _reset_was_pressed := false


func _ready() -> void:
	spawn_position = global_position
	var support := world_system.get_support_below_area(global_position, BODY_RADIUS, 0.05)
	if support >= 0.0:
		elevation = support
	_update_shadow_projection()
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
	_update_shadow_projection()
	_update_visual_height()
	_prediction_timer -= delta
	if _prediction_timer <= 0.0:
		_update_landing_prediction()
		_prediction_timer = 0.1
	if not is_grounded:
		queue_redraw()


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

	if not world_system.can_occupy_area(target_position, BODY_RADIUS, elevation, BODY_HEIGHT):
		return
	global_position = target_position
	if is_grounded:
		var support := world_system.get_support_below_area(global_position, BODY_RADIUS, elevation + 0.001)
		if support < elevation - 0.01:
			is_grounded = false


func _update_vertical_motion(delta: float, jump_just_pressed: bool) -> void:
	if is_grounded:
		var support := world_system.get_support_below_area(global_position, BODY_RADIUS, elevation + 0.001)
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
			var ceiling_bottom := world_system.find_ceiling_bottom_area(
				global_position,
				BODY_RADIUS,
				previous_elevation + BODY_HEIGHT,
				next_elevation + BODY_HEIGHT
			)
			if ceiling_bottom >= 0.0:
				next_elevation = ceiling_bottom - BODY_HEIGHT
				vertical_velocity = 0.0
		if vertical_velocity <= 0.0:
			var landing_height := world_system.get_support_below_area(global_position, BODY_RADIUS, previous_elevation + 0.001)
			if landing_height >= 0.0 and next_elevation <= landing_height and previous_elevation >= landing_height - 0.01:
				next_elevation = landing_height
				vertical_velocity = 0.0
				is_grounded = true
		elevation = next_elevation

	if elevation < FALL_LIMIT:
		_respawn()


func _update_visual_height() -> void:
	var visual_y := -elevation * WorldSystem.HEIGHT_STEP_PIXELS
	if not is_equal_approx(texture_component.position.y, visual_y):
		texture_component.position.y = visual_y
		follow_camera.position.y = visual_y
		queue_redraw()


func _update_shadow_projection() -> void:
	var support := world_system.get_support_below_area(global_position, BODY_RADIUS, elevation + 0.001)
	var has_shadow := support >= 0.0
	var shadow_changed := has_shadow != _has_ground_shadow
	if has_shadow:
		shadow_changed = shadow_changed or not is_equal_approx(shadow_elevation, support)
		shadow_elevation = support
	_has_ground_shadow = has_shadow
	if shadow_changed:
		queue_redraw()


func _respawn() -> void:
	global_position = spawn_position
	var cell := world_system.world_to_cell(global_position)
	elevation = world_system.get_support_below(cell.x, cell.y, WorldSystem.HEIGHT_LEVELS)
	if elevation < 0.0:
		elevation = 0.0
	vertical_velocity = 0.0
	is_grounded = true
	_update_shadow_projection()


func _update_landing_prediction() -> void:
	has_landing_target = false
	landing_time = 0.0
	if is_grounded:
		landing_target = Vector3(global_position.x, global_position.y, elevation)
		return
	var predicted_position := global_position
	var predicted_height := elevation
	var predicted_velocity := vertical_velocity
	var direction := movement_component.get_direction()
	var dt := 1.0 / 60.0
	# Same collision footprint and vertical rules as actual motion; preview assumes held input.
	for step in range(180):
		var motion := direction * movement_component.speed * dt
		for axis in [Vector2(motion.x, 0), Vector2(0, motion.y)]:
			var candidate: Vector2 = predicted_position + axis
			if world_system.can_occupy_area(candidate, BODY_RADIUS, predicted_height, BODY_HEIGHT):
				predicted_position = candidate
		predicted_velocity -= GRAVITY * dt
		var next_height := predicted_height + predicted_velocity * dt
		if predicted_velocity > 0.0:
			var ceiling := world_system.find_ceiling_bottom_area(predicted_position, BODY_RADIUS, predicted_height + BODY_HEIGHT, next_height + BODY_HEIGHT)
			if ceiling >= 0.0:
				next_height = ceiling - BODY_HEIGHT
				predicted_velocity = 0.0
		if predicted_velocity <= 0.0:
			var floor_height := world_system.get_support_below_area(predicted_position, BODY_RADIUS, predicted_height + 0.001)
			if floor_height >= 0.0 and next_height <= floor_height:
				landing_target = Vector3(predicted_position.x, predicted_position.y, floor_height)
				landing_time = (step + 1) * dt
				has_landing_target = true
				break
		predicted_height = next_height
		if predicted_height < FALL_LIMIT:
			break
	queue_redraw()


func _draw() -> void:
	var feet := Vector2(0, -elevation * WorldSystem.HEIGHT_STEP_PIXELS + 5)
	if _has_ground_shadow:
		var ground := Vector2(0, -shadow_elevation * WorldSystem.HEIGHT_STEP_PIXELS + 5)
		draw_rect(Rect2(ground - Vector2(5, 1), Vector2(10, 4)), Color(0.04, 0.08, 0.07, 0.38))
		if not is_grounded:
			draw_dashed_line(feet, ground, Color(0.95, 0.91, 0.55, 0.8), 1.0, 2.0)
	# This badge follows the avatar rather than the unprojected level-zero position.
	var gauge_base := feet + Vector2(15, 0)
	draw_line(gauge_base, gauge_base - Vector2(0, 28), Color(0.04, 0.08, 0.1), 3.0)
	for level in range(WorldSystem.HEIGHT_LEVELS):
		var tick := gauge_base - Vector2(0, level * 4)
		draw_line(tick - Vector2(2, 0), tick + Vector2(2, 0), WorldSystem.STONE_LEVEL_COLORS[level], 1.0)
	var indicator := gauge_base - Vector2(0, clampf(elevation, 0, 7) * 4)
	draw_circle(indicator, 2.0, Color(1, 0.95, 0.35))
	var badge := feet + Vector2(-10, -25)
	draw_rect(Rect2(badge - Vector2(1, 9), Vector2(26, 12)), Color(0.025, 0.055, 0.08, 0.9))
	draw_string(ThemeDB.fallback_font, badge, "Z %.1f" % elevation, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.95, 0.5))
	if not is_grounded and has_landing_target:
		var target := Vector2(landing_target.x, landing_target.y - landing_target.z * WorldSystem.HEIGHT_STEP_PIXELS) - global_position
		draw_dashed_line(feet, target, Color(0.25, 0.95, 1, 0.7), 1.0, 3.0)
		draw_rect(Rect2(target - Vector2(7, 7), Vector2(14, 14)), Color(0.1, 0.9, 1, 0.2))
		draw_rect(Rect2(target - Vector2(7, 7), Vector2(14, 14)), Color(0.3, 1, 1), false, 1.0)
		draw_string(ThemeDB.fallback_font, target + Vector2(-12, 17), "POUSO Z%d" % roundi(landing_target.z), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 1, 1))
	elif not is_grounded and not _has_ground_shadow:
		draw_string(ThemeDB.fallback_font, feet + Vector2(9, 4), "VAO", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.5, 0.2))
