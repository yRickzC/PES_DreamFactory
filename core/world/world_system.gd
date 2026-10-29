extends Node2D
class_name WorldSystem

const MAP_WIDTH := 64
const MAP_DEPTH := 64
const HEIGHT_LEVELS := 8
const TILE_SIZE := 16
const HEIGHT_STEP_PIXELS := 8
const DRAW_MARGIN_TILES := 6
const NO_FLOOR := -1.0
const STAIR_START_X := 4
const STAIR_MARKER_ROW := 11
const STONE_LEVEL_COLORS := [
	Color8(101, 126, 124),
	Color8(112, 139, 127),
	Color8(128, 151, 126),
	Color8(148, 160, 123),
	Color8(169, 165, 117),
	Color8(188, 160, 105),
	Color8(197, 143, 95),
	Color8(194, 122, 91),
]

enum CellType { EMPTY, GRASS, PATH, STONE, WATER, SOLID, ROOF, CEILING }

var cells := PackedByteArray()
var _support_masks := PackedInt32Array()
var _blocker_masks := PackedInt32Array()
var _surface_levels := PackedInt32Array()
var _surface_types := PackedByteArray()
var overhead_cells: Array[Vector3i] = []
var _render_dirty := true
var render_revision := 0
var _last_visible_bounds := Rect2i(-1, -1, -1, -1)


func _ready() -> void:
	cells.resize(MAP_WIDTH * MAP_DEPTH * HEIGHT_LEVELS)
	cells.fill(CellType.EMPTY)
	_support_masks.resize(MAP_WIDTH * MAP_DEPTH)
	_blocker_masks.resize(MAP_WIDTH * MAP_DEPTH)
	_surface_levels.resize(MAP_WIDTH * MAP_DEPTH)
	_surface_types.resize(MAP_WIDTH * MAP_DEPTH)
	_build_test_map()
	_rebuild_render_cache()
	queue_redraw()


func _process(_delta: float) -> void:
	if _render_dirty:
		_rebuild_render_cache()
		queue_redraw()
	var bounds := get_visible_cell_bounds()
	if bounds != _last_visible_bounds:
		_last_visible_bounds = bounds
		queue_redraw()


func get_cell(x: int, y: int, level: int) -> int:
	if not is_inside_cell(x, y) or level < 0 or level >= HEIGHT_LEVELS:
		return CellType.EMPTY
	return cells[_cell_index(x, y, level)]


func set_cell(x: int, y: int, level: int, cell_type: int) -> void:
	if not is_inside_cell(x, y) or level < 0 or level >= HEIGHT_LEVELS:
		return
	cells[_cell_index(x, y, level)] = cell_type
	var column := y * MAP_WIDTH + x
	var bit := 1 << level
	_support_masks[column] &= ~bit
	_blocker_masks[column] &= ~bit
	if cell_type in [CellType.GRASS, CellType.PATH, CellType.STONE, CellType.WATER]:
		_support_masks[column] |= bit
	if cell_type == CellType.SOLID or cell_type == CellType.CEILING:
		_blocker_masks[column] |= bit
	_render_dirty = true


func is_inside_cell(x: int, y: int) -> bool:
	return x >= 0 and x < MAP_WIDTH and y >= 0 and y < MAP_DEPTH


func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / TILE_SIZE), floori(world_position.y / TILE_SIZE))


func get_support_below(x: int, y: int, max_height: float) -> float:
	if not is_inside_cell(x, y):
		return NO_FLOOR
	var top_level := mini(HEIGHT_LEVELS - 1, floori(max_height + 0.001))
	var mask := _support_masks[y * MAP_WIDTH + x]
	for level in range(top_level, -1, -1):
		if mask & (1 << level):
			return float(level)
	return NO_FLOOR


func get_support_below_area(center: Vector2, radius: float, max_height: float) -> float:
	var bounds := _get_footprint_cell_bounds(center, radius)
	var support := NO_FLOOR
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			support = maxf(support, get_support_below(x, y, max_height))
	return support


func can_occupy(x: int, y: int, bottom_height: float, body_height: float) -> bool:
	if not is_inside_cell(x, y):
		return false
	var mask := _blocker_masks[y * MAP_WIDTH + x]
	var first := maxi(0, floori(bottom_height + 0.001))
	var last := mini(HEIGHT_LEVELS - 1, ceili(bottom_height + body_height - 0.001) - 1)
	for level in range(first, last + 1):
		if mask & (1 << level):
			return false
	return true


func can_occupy_area(center: Vector2, radius: float, bottom_height: float, body_height: float) -> bool:
	var bounds := _get_footprint_cell_bounds(center, radius)
	for y in range(bounds.position.y, bounds.position.y + bounds.size.y):
		for x in range(bounds.position.x, bounds.position.x + bounds.size.x):
			if not can_occupy(x, y, bottom_height, body_height):
				return false
	return true


func find_ceiling_bottom(x: int, y: int, old_top: float, new_top: float) -> float:
	if new_top <= old_top or not is_inside_cell(x, y):
		return NO_FLOOR
	var first := maxi(0, ceili(old_top))
	var last := mini(HEIGHT_LEVELS - 1, ceili(new_top) - 1)
	var mask := _blocker_masks[y * MAP_WIDTH + x]
	for level in range(first, last + 1):
		if mask & (1 << level):
			return float(level)
	return NO_FLOOR


func find_ceiling_bottom_area(center: Vector2, radius: float, old_top: float, new_top: float) -> float:
	var bounds := _get_footprint_cell_bounds(center, radius)
	var nearest_ceiling := NO_FLOOR
	for y in range(bounds.position.y, bounds.position.y + bounds.size.y):
		for x in range(bounds.position.x, bounds.position.x + bounds.size.x):
			var ceiling_bottom := find_ceiling_bottom(x, y, old_top, new_top)
			if ceiling_bottom >= 0.0 and (nearest_ceiling < 0.0 or ceiling_bottom < nearest_ceiling):
				nearest_ceiling = ceiling_bottom
	return nearest_ceiling


func _get_footprint_cell_bounds(center: Vector2, radius: float) -> Rect2i:
	var minimum_cell := world_to_cell(center - Vector2.ONE * radius)
	var maximum_cell := world_to_cell(center + Vector2.ONE * radius - Vector2.ONE * 0.001)
	return Rect2i(
		minimum_cell,
		Vector2i(maximum_cell.x - minimum_cell.x + 1, maximum_cell.y - minimum_cell.y + 1)
	)


func is_overhead_cell(x: int, y: int, level: int) -> bool:
	var cell_type := get_cell(x, y, level)
	return cell_type == CellType.ROOF or cell_type == CellType.CEILING


func get_overhead_height(x: int, y: int, level: int) -> float:
	if get_cell(x, y, level) == CellType.CEILING:
		return float(level + 1)
	return float(level)


func get_overhead_color(x: int, y: int, level: int) -> Color:
	var cell_type := get_cell(x, y, level)
	var color := Color(0.53, 0.25, 0.18, 1.0) if cell_type == CellType.ROOF else Color(0.34, 0.38, 0.43, 1.0)
	var encoded_height := get_overhead_height(x, y, level) / float(HEIGHT_LEVELS)
	return Color(color.r, color.g, color.b, encoded_height)


func get_visible_cell_bounds() -> Rect2i:
	var inverse_canvas := get_viewport().get_canvas_transform().affine_inverse()
	var view_size := get_viewport_rect().size
	var first_corner := inverse_canvas * Vector2.ZERO
	var last_corner := inverse_canvas * view_size
	var left := clampi(floori(minf(first_corner.x, last_corner.x) / TILE_SIZE) - 3, 0, MAP_WIDTH)
	var right := clampi(ceili(maxf(first_corner.x, last_corner.x) / TILE_SIZE) + 3, 0, MAP_WIDTH)
	var top := clampi(floori(minf(first_corner.y, last_corner.y) / TILE_SIZE) - DRAW_MARGIN_TILES, 0, MAP_DEPTH)
	var bottom := clampi(ceili(maxf(first_corner.y, last_corner.y) / TILE_SIZE) + DRAW_MARGIN_TILES, 0, MAP_DEPTH)
	return Rect2i(Vector2i(left, top), Vector2i(right - left, bottom - top))


func _draw() -> void:
	var bounds := get_visible_cell_bounds()
	for y in range(bounds.position.y, bounds.position.y + bounds.size.y):
		for x in range(bounds.position.x, bounds.position.x + bounds.size.x):
			_draw_cell_surface(x, y)
	_draw_stair_height_markers(bounds)


func _rebuild_render_cache() -> void:
	overhead_cells.clear()
	for y in range(MAP_DEPTH):
		for x in range(MAP_WIDTH):
			var column := y * MAP_WIDTH + x
			_surface_levels[column] = -1
			for level in range(HEIGHT_LEVELS - 1, -1, -1):
				var kind := get_cell(x, y, level)
				if kind in [CellType.ROOF, CellType.CEILING]:
					overhead_cells.append(Vector3i(x, y, level))
					break
			for level in range(HEIGHT_LEVELS - 1, -1, -1):
				var kind := get_cell(x, y, level)
				if kind in [CellType.GRASS, CellType.PATH, CellType.STONE, CellType.WATER, CellType.SOLID]:
					_surface_levels[column] = level
					_surface_types[column] = kind
					break
	_render_dirty = false
	render_revision += 1


func _draw_cell_surface(x: int, y: int) -> void:
	var column := y * MAP_WIDTH + x
	var level := _surface_levels[column]
	if level < 0:
		return
	var kind := _surface_types[column]
	if kind == CellType.SOLID:
		_draw_solid_column(x, y, level + 1)
	else:
		_draw_floor(x, y, level, kind)


func _draw_floor(x: int, y: int, level: int, cell_type: int) -> void:
	var color := _floor_color(x, y, cell_type, level)
	_draw_raised_surface(x, y, level, color)
	if cell_type == CellType.WATER:
		var ripple_x := x * TILE_SIZE + 3 + ((y * 5) % 5)
		var ripple_y := y * TILE_SIZE + 4 + ((x * 3) % 7)
		draw_rect(Rect2(Vector2(ripple_x, ripple_y), Vector2(5, 2)), Color(0.55, 0.83, 0.92, 0.58))
		draw_rect(Rect2(Vector2(ripple_x + 5, ripple_y + 6), Vector2(4, 2)), Color(0.55, 0.83, 0.92, 0.38))


func _draw_solid_column(x: int, y: int, surface_level: int) -> void:
	var color := Color(0.36, 0.42, 0.43).lightened(float(surface_level) * 0.025)
	_draw_raised_surface(x, y, surface_level, color)


func _draw_raised_surface(x: int, y: int, level: int, color: Color) -> void:
	var top_left := Vector2(x * TILE_SIZE, y * TILE_SIZE - level * HEIGHT_STEP_PIXELS)
	var front_level := _render_height(x, y + 1)
	var exposed_height := maxi(0, level - maxi(0, front_level))
	if exposed_height > 0:
		var face_top := top_left + Vector2(0, TILE_SIZE)
		draw_rect(Rect2(face_top, Vector2(TILE_SIZE, exposed_height * HEIGHT_STEP_PIXELS)), color.darkened(0.46))
		for band in range(1, exposed_height):
			var start := face_top + Vector2(0, band * HEIGHT_STEP_PIXELS)
			draw_line(start, start + Vector2(TILE_SIZE, 0), color.darkened(0.6), 1.0)
	draw_rect(Rect2(top_left, Vector2(TILE_SIZE, TILE_SIZE)), color)
	if exposed_height > 0:
		draw_line(top_left + Vector2(0, TILE_SIZE - 1), top_left + Vector2(TILE_SIZE, TILE_SIZE - 1), color.lightened(0.25), 1.0)
	if level > _render_height(x - 1, y):
		draw_line(top_left, top_left + Vector2(0, TILE_SIZE), color.darkened(0.35), 1.0)


func _render_height(x: int, y: int) -> int:
	if not is_inside_cell(x, y):
		return 0
	var column := y * MAP_WIDTH + x
	return _surface_levels[column] + (1 if _surface_types[column] == CellType.SOLID else 0)


func _draw_stair_height_markers(bounds: Rect2i) -> void:
	var marker_y := STAIR_MARKER_ROW
	if marker_y < bounds.position.y or marker_y >= bounds.position.y + bounds.size.y:
		return
	for level in range(HEIGHT_LEVELS):
		var x := STAIR_START_X + level * 2
		if x < bounds.position.x or x >= bounds.position.x + bounds.size.x:
			continue
		var marker_position := Vector2(x * TILE_SIZE + 3, marker_y * TILE_SIZE - level * HEIGHT_STEP_PIXELS + 3)
		draw_rect(Rect2(marker_position, Vector2(10, 11)), Color(0.035, 0.075, 0.075, 0.9))
		draw_string(ThemeDB.fallback_font, marker_position + Vector2(2, 9), str(level), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.95, 0.98, 0.86))


func _floor_color(x: int, y: int, cell_type: int, level: int) -> Color:
	var shade := float((x * 7 + y * 11) % 4) * 0.012
	match cell_type:
		CellType.PATH:
			return Color(0.66 + shade, 0.50 + shade, 0.29 + shade)
		CellType.STONE:
			return STONE_LEVEL_COLORS[clampi(level, 0, HEIGHT_LEVELS - 1)].lightened(shade)
		CellType.WATER:
			return Color(0.12, 0.39 + shade, 0.66 + shade)
		_:
			return Color(0.20 + shade, 0.53 + shade, 0.24 + shade)


func _cell_index(x: int, y: int, level: int) -> int:
	return (level * MAP_DEPTH + y) * MAP_WIDTH + x


func _build_test_map() -> void:
	for y in range(MAP_DEPTH):
		for x in range(MAP_WIDTH):
			set_cell(x, y, 0, CellType.GRASS)

	# Dirt paths frame the test areas.
	for x in range(2, 62):
		for y in range(29, 32):
			set_cell(x, y, 0, CellType.PATH)
	for y in range(15, 30):
		set_cell(21, y, 0, CellType.PATH)
	for x in range(19, 25):
		set_cell(x, 20, 0, CellType.PATH)

	# Eight-level staircase: each pair of columns rises one level.
	for x in range(4, 20):
		var step_height := mini(7, int((x - 4) / 2))
		for y in range(8, 16):
			_set_stair_tile(x, y, step_height)
	for y in range(15, 22):
		for x in range(3, 6):
			set_cell(x, y, 0, CellType.PATH)

	# A pit with stepping stones: missing ground is a real fall, not a painted hole.
	for y in range(12, 29):
		for x in range(24, 42):
			set_cell(x, y, 0, CellType.EMPTY)
	_add_platform(25, 20, 1, 2, 2)
	_add_platform(29, 17, 2, 2, 2)
	_add_platform(33, 20, 3, 2, 2)
	_add_platform(37, 16, 2, 2, 2)
	_add_platform(37, 24, 1, 3, 2)

	# Jump-over walls and a taller block on the southern course.
	for x in range(9, 18):
		set_cell(x, 47, 0, CellType.SOLID)
		set_cell(x, 47, 1, CellType.STONE)
	for x in range(18, 20):
		set_cell(x, 47, 0, CellType.SOLID)
		set_cell(x, 47, 1, CellType.SOLID)
		set_cell(x, 47, 2, CellType.STONE)

	# Raised bridge with a walkable tunnel beneath it and ramps at both ends.
	for x in range(28, 43):
		for y in range(38, 43):
			set_cell(x, y, 2, CellType.CEILING)
			set_cell(x, y, 3, CellType.STONE)
	for y in range(34, 38):
		var level := y - 34
		for x in range(32, 36):
			_set_stair_tile(x, y, level)
	for y in range(43, 47):
		var level := 46 - y
		for x in range(32, 36):
			_set_stair_tile(x, y, level)
	for y in range(38, 42):
		for level in range(2):
			set_cell(30, y, level, CellType.SOLID)
			set_cell(40, y, level, CellType.SOLID)

	# A roofed room. The shader opens a window around the player under its roof.
	for x in range(47, 57):
		for y in range(17, 28):
			set_cell(x, y, 2, CellType.CEILING)
			set_cell(x, y, 3, CellType.ROOF)
	for x in range(46, 58):
		if x != 52:
			set_cell(x, 28, 0, CellType.SOLID)
			set_cell(x, 28, 1, CellType.SOLID)
	for y in range(17, 28):
		for x in [46, 57]:
			set_cell(x, y, 0, CellType.SOLID)
			set_cell(x, y, 1, CellType.SOLID)
	for x in range(49, 55):
		set_cell(x, 28, 0, CellType.PATH)

	# Water supports the player at level zero without damage or respawn.
	for y in range(49, 57):
		for x in range(4, 13):
			set_cell(x, y, 0, CellType.WATER)


func _set_stair_tile(x: int, y: int, level: int) -> void:
	if level <= 0:
		set_cell(x, y, 0, CellType.PATH)
		return
	for lower_level in range(level):
		set_cell(x, y, lower_level, CellType.SOLID)
	set_cell(x, y, level, CellType.STONE)


func _add_platform(start_x: int, start_y: int, level: int, width: int, depth: int) -> void:
	for y in range(start_y, start_y + depth):
		for x in range(start_x, start_x + width):
			for lower_level in range(level):
				set_cell(x, y, lower_level, CellType.SOLID)
			set_cell(x, y, level, CellType.STONE)
