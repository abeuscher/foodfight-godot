extends RefCounted
class_name FogManager
## Manages fog of war for a single island view.
## Tracks which cells have been revealed by projectiles or other means.

signal cell_revealed(grid_pos: Vector2i)
signal fog_cleared()

var _grid_width: int = 0
var _grid_height: int = 0
var _revealed: Dictionary = {}  # Vector2i -> bool
var is_enabled: bool = true  # Whether fog is currently active


func initialize(width: int, height: int) -> void:
	_grid_width = width
	_grid_height = height
	_revealed.clear()


func is_revealed(grid_pos: Vector2i) -> bool:
	return _revealed.get(grid_pos, false)


func reveal_cell(grid_pos: Vector2i) -> void:
	if not _is_valid_pos(grid_pos):
		return
	if not _revealed.get(grid_pos, false):
		_revealed[grid_pos] = true
		cell_revealed.emit(grid_pos)


func reveal_cells(positions: Array) -> void:
	for pos in positions:
		reveal_cell(pos)


func reveal_path(from: Vector2i, to: Vector2i) -> void:
	# Reveal all cells along a line from 'from' to 'to' using Bresenham's algorithm
	var cells = _get_line_cells(from, to)
	for cell in cells:
		reveal_cell(cell)


func reveal_area(center: Vector2i, radius: int) -> void:
	# Reveal a square area around center
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			reveal_cell(Vector2i(center.x + dx, center.y + dy))


func reveal_all() -> void:
	for x in range(_grid_width):
		for y in range(_grid_height):
			_revealed[Vector2i(x, y)] = true
	fog_cleared.emit()


func get_revealed_count() -> int:
	var count = 0
	for revealed in _revealed.values():
		if revealed:
			count += 1
	return count


func get_total_cells() -> int:
	return _grid_width * _grid_height


func reset() -> void:
	_revealed.clear()


func enable() -> void:
	is_enabled = true


func disable() -> void:
	is_enabled = false


func _is_valid_pos(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < _grid_width and \
		   grid_pos.y >= 0 and grid_pos.y < _grid_height


func _get_line_cells(from: Vector2i, to: Vector2i) -> Array:
	# Bresenham's line algorithm
	var cells: Array = []
	var x0 = from.x
	var y0 = from.y
	var x1 = to.x
	var y1 = to.y

	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx - dy

	while true:
		cells.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy

	return cells
