extends GutTest
## Tests for IslandGridView component.

const IslandGrid = preload("res://scripts/resources/island_grid.gd")
const IslandGridView = preload("res://scripts/components/island_grid_view.gd")

var view: IslandGridView
var grid: IslandGrid


func before_each() -> void:
	grid = IslandGrid.new(4, 3)
	view = IslandGridView.new()
	view.cell_size = Vector2(64, 64)
	add_child_autofree(view)
	view.initialize(grid)


# --- Initialization Tests ---

func test_view_initializes_with_grid():
	assert_eq(view.grid, grid, "View should store reference to grid")


func test_view_size_matches_grid_dimensions():
	var expected_size = Vector2(4 * 64, 3 * 64)
	assert_eq(view.size, expected_size, "View size should match grid * cell_size")


func test_view_updates_size_on_initialize():
	var new_grid = IslandGrid.new(8, 6)
	var new_view = IslandGridView.new()
	new_view.cell_size = Vector2(32, 32)
	add_child_autofree(new_view)
	new_view.initialize(new_grid)

	var expected_size = Vector2(8 * 32, 6 * 32)
	assert_eq(new_view.size, expected_size, "View should resize for new grid")


# --- Coordinate Conversion Tests ---

func test_screen_to_grid_conversion():
	var result = view._screen_to_grid(Vector2(100, 80))
	assert_eq(result, Vector2i(1, 1), "Screen pos (100,80) should map to grid (1,1) with 64px cells")


func test_screen_to_grid_at_origin():
	var result = view._screen_to_grid(Vector2(0, 0))
	assert_eq(result, Vector2i(0, 0), "Screen origin should map to grid origin")


func test_screen_to_grid_at_cell_boundary():
	var result = view._screen_to_grid(Vector2(64, 128))
	assert_eq(result, Vector2i(1, 2), "Screen pos at cell boundary should map correctly")


func test_grid_to_screen_center():
	var result = view.grid_to_screen_center(Vector2i(1, 1))
	var expected = Vector2(1 * 64 + 32, 1 * 64 + 32)
	assert_eq(result, expected, "Grid center should be at cell center")


func test_grid_to_screen_center_at_origin():
	var result = view.grid_to_screen_center(Vector2i(0, 0))
	var expected = Vector2(32, 32)
	assert_eq(result, expected, "Grid (0,0) center should be at (32,32)")


# --- Cell Rect Tests ---

func test_get_cell_rect():
	var rect = view._get_cell_rect(Vector2i(2, 1))
	assert_eq(rect.position, Vector2(128, 64), "Cell rect position should be correct")
	assert_eq(rect.size, Vector2(64, 64), "Cell rect size should match cell_size")


# --- Signal Tests ---

func test_cell_clicked_signal_emitted():
	var result = {"pos": Vector2i(-1, -1)}
	view.cell_clicked.connect(func(pos): result.pos = pos)

	# Simulate a click at position (100, 80) which should be cell (1, 1)
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(100, 80)
	view._gui_input(event)

	assert_eq(result.pos, Vector2i(1, 1), "cell_clicked should emit with correct grid position")


func test_cell_hovered_signal_emitted():
	var result = {"pos": Vector2i(-1, -1)}
	view.cell_hovered.connect(func(pos): result.pos = pos)

	# Simulate mouse motion to position (150, 100) which should be cell (2, 1)
	var event = InputEventMouseMotion.new()
	event.position = Vector2(150, 100)
	view._gui_input(event)

	assert_eq(result.pos, Vector2i(2, 1), "cell_hovered should emit with correct grid position")


func test_click_outside_grid_does_not_emit():
	var emit_count = {"value": 0}
	view.cell_clicked.connect(func(_pos): emit_count.value += 1)

	# Click outside the grid bounds
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(500, 500)  # Outside 4x3 grid with 64px cells
	view._gui_input(event)

	assert_eq(emit_count.value, 0, "Should not emit for clicks outside grid")


# --- Color Tests ---

func test_get_cell_color_empty():
	var color = view._get_cell_color(IslandGrid.CellState.EMPTY)
	assert_eq(color, view.empty_cell_color, "Empty cells should use empty_cell_color")


func test_get_cell_color_occupied():
	var color = view._get_cell_color(IslandGrid.CellState.OCCUPIED)
	assert_eq(color, view.occupied_cell_color, "Occupied cells should use occupied_cell_color")


func test_get_cell_color_blocked():
	var color = view._get_cell_color(IslandGrid.CellState.BLOCKED)
	assert_eq(color, view.blocked_cell_color, "Blocked cells should use blocked_cell_color")
