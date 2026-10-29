extends SceneTree

var failures := 0
var world: WorldSystem
var player: PlayerSystem

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _place(cell: Vector2i, height: float, grounded: bool = true) -> void:
	player.global_position = Vector2(cell) * 16 + Vector2(8, 8)
	player.elevation = height
	player.vertical_velocity = 0.0
	player.is_grounded = grounded

func _simulate(direction: Vector2, frames: int, jump: bool = false) -> void:
	for frame in range(frames):
		player._move_on_ground(direction * 112.0 / 60.0)
		player._update_vertical_motion(1.0 / 60.0, jump and frame == 0)
		_check(world.can_occupy_area(player.global_position, PlayerSystem.BODY_RADIUS, player.elevation, PlayerSystem.BODY_HEIGHT), "Body entered solid terrain at %s, z %.3f" % [player.global_position, player.elevation])

func _run() -> void:
	var main := (load("res://src/scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	world = main.get_node("WorldSystem")
	player = main.get_node("Player")
	player.set_physics_process(false)
	_check(player.get_node("FollowCamera").zoom == Vector2(2.5, 2.5), "Camera needs close zoom")
	_check(world.cells.size() == 64 * 64 * 8, "Wrong map size")
	# Walk into water and fall onto water: both must remain supported, without respawn.
	_place(Vector2i(7, 48), 0.0)
	_simulate(Vector2.DOWN, 30)
	_check(player.global_position.y > 49 * 16 and player.is_grounded, "Water must be traversable")
	_place(Vector2i(7, 52), 5.0, false)
	_simulate(Vector2.ZERO, 90)
	_check(player.is_grounded and is_equal_approx(player.elevation, 0.0), "Water must catch a fall at level zero")
	_check(world.world_to_cell(player.global_position) == Vector2i(7, 52), "Water must not respawn the player")
	# Regression: descend each step edge and the outer ledge with the entire hitbox.
	for level in range(1, 8):
		for direction in [Vector2.LEFT, Vector2.DOWN, Vector2.UP, Vector2(-1, 1).normalized()]:
			_place(Vector2i(4 + level * 2, 15), float(level))
			_simulate(direction, 180)
			_check(player.is_grounded, "Player stuck falling off stair %d" % level)
	_place(Vector2i(18, 11), 7.0)
	_simulate(Vector2.LEFT, 180)
	_check(player.is_grounded and is_equal_approx(player.elevation, 0.0), "Descending the whole staircase should reach ground")
	_place(Vector2i(5, 11), 0.0)
	_simulate(Vector2.RIGHT, 60)
	_check(is_equal_approx(player.elevation, 0.0), "No automatic stair climbing")
	_simulate(Vector2.RIGHT, 90, true)
	_check(player.is_grounded and is_equal_approx(player.elevation, 1.0), "Jump should land on next step")
	# The bridge deck must not prevent traversing the lower tunnel.
	# Start inside the lower corridor, away from the solid ramp.
	_place(Vector2i(32, 39), 0.0)
	_simulate(Vector2.RIGHT, 35)
	_check(player.global_position.x > 35 * 16 and is_equal_approx(player.elevation, 0.0), "Tunnel traversal must stay on ground")
	_place(Vector2i(32, 40), 0.0)
	_simulate(Vector2.ZERO, 90, true)
	_check(player.is_grounded and is_equal_approx(player.elevation, 0.0), "Ceiling must stop jump and allow landing")
	# Preview uses held direction, then compare against actual fixed-step landing.
	_place(Vector2i(7, 52), 3.0, false)
	Input.action_press("ui_right")
	player._update_landing_prediction()
	Input.action_release("ui_right")
	_check(player.has_landing_target and is_equal_approx(player.landing_target.z, 0.0), "Preview must identify safe water landing")
	var expected := player.landing_target
	for frame in range(180):
		_simulate(Vector2.RIGHT, 1)
		if player.is_grounded:
			break
	_check(player.global_position.distance_to(Vector2(expected.x, expected.y)) < 5.0, "Preview must match held-direction landing")
	# Mutation must invalidate collision masks and render caches.
	world.set_cell(60, 60, 0, WorldSystem.CellType.WATER)
	_check(world.get_support_below(60, 60, 0.01) == 0.0 and world.can_occupy(60, 60, 0.0, 0.72), "Water mutation must update caches")
	world.set_cell(60, 60, 0, WorldSystem.CellType.SOLID)
	_check(world.get_support_below(60, 60, 0.01) < 0.0 and not world.can_occupy(60, 60, 0.0, 0.72), "Replacing water must clear support mask")
	print("WORLD PHYSICS: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
