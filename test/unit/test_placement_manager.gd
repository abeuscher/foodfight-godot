extends GutTest
## Tests for PlacementManager.

const IslandGrid = preload("res://scripts/resources/island_grid.gd")
const Structure = preload("res://scripts/resources/structure.gd")
const IslandGridView = preload("res://scripts/components/island_grid_view.gd")
const PlacementManager = preload("res://scripts/components/placement_manager.gd")

var grid: IslandGrid
var grid_view: IslandGridView
var manager: PlacementManager


func before_each() -> void:
	grid = IslandGrid.new(4, 3)
	grid_view = IslandGridView.new()
	grid_view.cell_size = Vector2(64, 64)
	add_child_autofree(grid_view)
	grid_view.initialize(grid)

	manager = PlacementManager.new()
	add_child_autofree(manager)
	manager.initialize(grid, grid_view)


# --- Placement Tests ---

func test_can_place_on_empty_cell():
	assert_true(manager.can_place_at(Vector2i(0, 0)), "Should be able to place on empty cell")


func test_cannot_place_on_occupied_cell():
	manager.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(1, 1))
	assert_false(manager.can_place_at(Vector2i(1, 1)), "Should not be able to place on occupied cell")


func test_cannot_place_outside_grid():
	assert_false(manager.can_place_at(Vector2i(-1, 0)), "Should not place outside grid")
	assert_false(manager.can_place_at(Vector2i(10, 10)), "Should not place outside grid")


func test_place_structure_returns_structure():
	var result = manager.place_structure(Structure.Type.BASE, Vector2i(2, 1))
	assert_not_null(result, "place_structure should return the structure")
	assert_eq(result.type, Structure.Type.BASE, "Structure type should match")
	assert_eq(result.grid_position, Vector2i(2, 1), "Structure position should match")


func test_place_structure_updates_grid():
	manager.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	assert_eq(grid.get_cell(Vector2i(0, 0)), IslandGrid.CellState.OCCUPIED,
		"Grid cell should be OCCUPIED after placement")


func test_place_structure_adds_to_structures_array():
	manager.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	manager.place_structure(Structure.Type.PICKLE_INTERCEPTOR, Vector2i(1, 0))
	assert_eq(manager.structures.size(), 2, "Should have 2 structures")


func test_place_structure_on_occupied_returns_null():
	manager.place_structure(Structure.Type.BASE, Vector2i(0, 0))
	var result = manager.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	assert_null(result, "Should return null when placing on occupied cell")


# --- Signal Tests ---

func test_structure_placed_signal_emitted():
	var result = {"structure": null, "pos": Vector2i(-1, -1)}
	manager.structure_placed.connect(func(s, p):
		result.structure = s
		result.pos = p
	)

	manager.place_structure(Structure.Type.BASE, Vector2i(1, 2))

	assert_not_null(result.structure, "Signal should emit with structure")
	assert_eq(result.pos, Vector2i(1, 2), "Signal should emit with position")


func test_placement_failed_signal_emitted():
	var result = {"pos": Vector2i(-1, -1), "reason": ""}
	manager.placement_failed.connect(func(p, r):
		result.pos = p
		result.reason = r
	)

	manager.place_structure(Structure.Type.BASE, Vector2i(0, 0))
	manager.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))  # Should fail

	assert_eq(result.pos, Vector2i(0, 0), "Signal should emit with position")
	assert_eq(result.reason, "Cell occupied", "Signal should emit with reason")


func test_selection_changed_signal_emitted():
	var result = {"type": -999}
	manager.selection_changed.connect(func(t): result.type = t)

	manager.select_structure_type(Structure.Type.CONDIMENT_CANNON)

	assert_eq(result.type, Structure.Type.CONDIMENT_CANNON, "Signal should emit with type")


# --- Selection Tests ---

func test_select_structure_type():
	manager.select_structure_type(Structure.Type.PICKLE_INTERCEPTOR)
	assert_eq(manager.selected_type, Structure.Type.PICKLE_INTERCEPTOR, "Selected type should be set")


func test_deselect():
	manager.select_structure_type(Structure.Type.BASE)
	manager.deselect()
	assert_null(manager.selected_type, "Selected type should be null after deselect")


# --- Query Tests ---

func test_get_structure_at():
	manager.place_structure(Structure.Type.BASE, Vector2i(2, 2))
	var found = manager.get_structure_at(Vector2i(2, 2))
	assert_not_null(found, "Should find structure at position")
	assert_eq(found.type, Structure.Type.BASE, "Should find correct structure")


func test_get_structure_at_empty_returns_null():
	var found = manager.get_structure_at(Vector2i(0, 0))
	assert_null(found, "Should return null for empty cell")


func test_get_structures_by_type():
	manager.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	manager.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(1, 0))
	manager.place_structure(Structure.Type.PICKLE_INTERCEPTOR, Vector2i(2, 0))

	var cannons = manager.get_structures_by_type(Structure.Type.CONDIMENT_CANNON)
	assert_eq(cannons.size(), 2, "Should find 2 cannons")


# --- Remove Tests ---

func test_remove_structure_at():
	manager.place_structure(Structure.Type.BASE, Vector2i(1, 1))
	var removed = manager.remove_structure_at(Vector2i(1, 1))

	assert_true(removed, "remove_structure_at should return true")
	assert_eq(manager.structures.size(), 0, "Structures array should be empty")
	assert_true(grid.is_cell_empty(Vector2i(1, 1)), "Grid cell should be EMPTY")


func test_remove_structure_at_empty_returns_false():
	var removed = manager.remove_structure_at(Vector2i(0, 0))
	assert_false(removed, "Should return false when no structure at position")
