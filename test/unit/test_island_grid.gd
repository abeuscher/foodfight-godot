extends GutTest
## Tests for IslandGrid data structure.

const IslandGrid = preload("res://scripts/resources/island_grid.gd")


func test_grid_initializes_with_correct_dimensions():
	var grid = IslandGrid.new(8, 5)
	assert_eq(grid.width, 8, "Width should be 8")
	assert_eq(grid.height, 5, "Height should be 5")


func test_grid_uses_default_dimensions():
	var grid = IslandGrid.new()
	assert_eq(grid.width, 6, "Default width should be 6")
	assert_eq(grid.height, 4, "Default height should be 4")


func test_all_cells_start_empty():
	var grid = IslandGrid.new(3, 3)
	for y in range(3):
		for x in range(3):
			assert_eq(grid.get_cell(Vector2i(x, y)), IslandGrid.CellState.EMPTY,
				"Cell (%d,%d) should be EMPTY" % [x, y])


func test_get_cell_returns_correct_state():
	var grid = IslandGrid.new(3, 3)
	grid.set_cell(Vector2i(1, 1), IslandGrid.CellState.OCCUPIED)
	assert_eq(grid.get_cell(Vector2i(1, 1)), IslandGrid.CellState.OCCUPIED,
		"Cell should be OCCUPIED after setting")


func test_set_cell_updates_state():
	var grid = IslandGrid.new(3, 3)
	var result = grid.set_cell(Vector2i(2, 0), IslandGrid.CellState.BLOCKED)
	assert_true(result, "set_cell should return true for valid position")
	assert_eq(grid.get_cell(Vector2i(2, 0)), IslandGrid.CellState.BLOCKED,
		"Cell should be BLOCKED")


func test_is_valid_position_returns_true_for_valid():
	var grid = IslandGrid.new(4, 4)
	assert_true(grid.is_valid_position(Vector2i(0, 0)), "Origin should be valid")
	assert_true(grid.is_valid_position(Vector2i(3, 3)), "Max corner should be valid")
	assert_true(grid.is_valid_position(Vector2i(2, 1)), "Middle cell should be valid")


func test_is_valid_position_returns_false_for_invalid():
	var grid = IslandGrid.new(4, 4)
	assert_false(grid.is_valid_position(Vector2i(-1, 0)), "Negative X should be invalid")
	assert_false(grid.is_valid_position(Vector2i(0, -1)), "Negative Y should be invalid")
	assert_false(grid.is_valid_position(Vector2i(4, 0)), "X at width should be invalid")
	assert_false(grid.is_valid_position(Vector2i(0, 4)), "Y at height should be invalid")
	assert_false(grid.is_valid_position(Vector2i(10, 10)), "Far out of bounds should be invalid")


func test_get_cell_returns_blocked_for_invalid_position():
	var grid = IslandGrid.new(3, 3)
	assert_eq(grid.get_cell(Vector2i(-1, 0)), IslandGrid.CellState.BLOCKED,
		"Out of bounds should return BLOCKED")
	assert_eq(grid.get_cell(Vector2i(5, 5)), IslandGrid.CellState.BLOCKED,
		"Out of bounds should return BLOCKED")


func test_set_cell_returns_false_for_invalid_position():
	var grid = IslandGrid.new(3, 3)
	var result = grid.set_cell(Vector2i(-1, 0), IslandGrid.CellState.OCCUPIED)
	assert_false(result, "set_cell should return false for invalid position")


func test_is_cell_empty_helper():
	var grid = IslandGrid.new(3, 3)
	assert_true(grid.is_cell_empty(Vector2i(0, 0)), "Unset cell should be empty")
	grid.set_cell(Vector2i(0, 0), IslandGrid.CellState.OCCUPIED)
	assert_false(grid.is_cell_empty(Vector2i(0, 0)), "Occupied cell should not be empty")


func test_clear_resets_all_cells():
	var grid = IslandGrid.new(3, 3)
	grid.set_cell(Vector2i(0, 0), IslandGrid.CellState.OCCUPIED)
	grid.set_cell(Vector2i(1, 1), IslandGrid.CellState.BLOCKED)
	grid.set_cell(Vector2i(2, 2), IslandGrid.CellState.OCCUPIED)

	grid.clear()

	for y in range(3):
		for x in range(3):
			assert_eq(grid.get_cell(Vector2i(x, y)), IslandGrid.CellState.EMPTY,
				"Cell (%d,%d) should be EMPTY after clear" % [x, y])


func test_cell_changed_signal_emitted():
	var grid = IslandGrid.new(3, 3)
	var result = {"pos": Vector2i(-1, -1), "state": -1}
	grid.cell_changed.connect(func(pos, state):
		result.pos = pos
		result.state = state
	)

	grid.set_cell(Vector2i(1, 2), IslandGrid.CellState.OCCUPIED)

	assert_eq(result.pos, Vector2i(1, 2), "Signal should emit with correct position")
	assert_eq(result.state, IslandGrid.CellState.OCCUPIED, "Signal should emit with correct state")


func test_cell_changed_signal_not_emitted_when_same_state():
	var grid = IslandGrid.new(3, 3)
	var emit_count = {"value": 0}
	grid.cell_changed.connect(func(_pos, _state): emit_count.value += 1)

	grid.set_cell(Vector2i(0, 0), IslandGrid.CellState.EMPTY)  # Already empty

	assert_eq(emit_count.value, 0, "Signal should not emit when state unchanged")


func test_get_all_cells_with_state():
	var grid = IslandGrid.new(3, 3)
	grid.set_cell(Vector2i(0, 0), IslandGrid.CellState.OCCUPIED)
	grid.set_cell(Vector2i(2, 1), IslandGrid.CellState.OCCUPIED)
	grid.set_cell(Vector2i(1, 1), IslandGrid.CellState.BLOCKED)

	var occupied = grid.get_all_cells_with_state(IslandGrid.CellState.OCCUPIED)
	assert_eq(occupied.size(), 2, "Should find 2 occupied cells")
	assert_has(occupied, Vector2i(0, 0), "Should include (0,0)")
	assert_has(occupied, Vector2i(2, 1), "Should include (2,1)")
