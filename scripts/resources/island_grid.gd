class_name IslandGrid
extends RefCounted
## Data structure representing an island's grid for structure placement.

enum CellState { EMPTY, OCCUPIED, BLOCKED }

signal cell_changed(position: Vector2i, new_state: CellState)

var width: int
var height: int
var _cells: Array[Array]


func _init(grid_width: int = 6, grid_height: int = 4) -> void:
	width = grid_width
	height = grid_height
	_cells = []
	for y in range(height):
		var row: Array[CellState] = []
		row.resize(width)
		row.fill(CellState.EMPTY)
		_cells.append(row)


func get_cell(position: Vector2i) -> CellState:
	if not is_valid_position(position):
		return CellState.BLOCKED
	return _cells[position.y][position.x]


func set_cell(position: Vector2i, state: CellState) -> bool:
	if not is_valid_position(position):
		return false
	if _cells[position.y][position.x] != state:
		_cells[position.y][position.x] = state
		cell_changed.emit(position, state)
	return true


func is_valid_position(position: Vector2i) -> bool:
	return position.x >= 0 and position.x < width and position.y >= 0 and position.y < height


func is_cell_empty(position: Vector2i) -> bool:
	return get_cell(position) == CellState.EMPTY


func clear() -> void:
	for y in range(height):
		for x in range(width):
			set_cell(Vector2i(x, y), CellState.EMPTY)


func get_all_cells_with_state(state: CellState) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			if _cells[y][x] == state:
				result.append(Vector2i(x, y))
	return result
