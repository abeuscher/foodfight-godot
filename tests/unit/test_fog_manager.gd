extends GutTest
## Unit tests for FogManager.

const FogManager = preload("res://scripts/components/fog_manager.gd")

var fog: FogManager


func before_each() -> void:
	fog = FogManager.new()
	fog.initialize(10, 10)


func test_initial_state_all_hidden() -> void:
	assert_false(fog.is_revealed(Vector2i(0, 0)), "Cell should start hidden")
	assert_false(fog.is_revealed(Vector2i(5, 5)), "Cell should start hidden")
	assert_eq(fog.get_revealed_count(), 0, "No cells revealed initially")


func test_reveal_single_cell() -> void:
	fog.reveal_cell(Vector2i(3, 4))
	assert_true(fog.is_revealed(Vector2i(3, 4)), "Cell should be revealed")
	assert_eq(fog.get_revealed_count(), 1)


func test_reveal_does_not_affect_neighbors() -> void:
	fog.reveal_cell(Vector2i(5, 5))
	assert_false(fog.is_revealed(Vector2i(4, 5)), "Neighbor should still be hidden")
	assert_false(fog.is_revealed(Vector2i(5, 4)), "Neighbor should still be hidden")
	assert_false(fog.is_revealed(Vector2i(6, 5)), "Neighbor should still be hidden")


func test_reveal_cells_array() -> void:
	var cells = [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2)]
	fog.reveal_cells(cells)
	assert_true(fog.is_revealed(Vector2i(0, 0)))
	assert_true(fog.is_revealed(Vector2i(1, 1)))
	assert_true(fog.is_revealed(Vector2i(2, 2)))
	assert_eq(fog.get_revealed_count(), 3)


func test_reveal_path_horizontal() -> void:
	fog.reveal_path(Vector2i(0, 5), Vector2i(4, 5))
	# Should reveal cells along the horizontal line
	assert_true(fog.is_revealed(Vector2i(0, 5)))
	assert_true(fog.is_revealed(Vector2i(1, 5)))
	assert_true(fog.is_revealed(Vector2i(2, 5)))
	assert_true(fog.is_revealed(Vector2i(3, 5)))
	assert_true(fog.is_revealed(Vector2i(4, 5)))


func test_reveal_path_vertical() -> void:
	fog.reveal_path(Vector2i(3, 0), Vector2i(3, 4))
	assert_true(fog.is_revealed(Vector2i(3, 0)))
	assert_true(fog.is_revealed(Vector2i(3, 1)))
	assert_true(fog.is_revealed(Vector2i(3, 2)))
	assert_true(fog.is_revealed(Vector2i(3, 3)))
	assert_true(fog.is_revealed(Vector2i(3, 4)))


func test_reveal_path_diagonal() -> void:
	fog.reveal_path(Vector2i(0, 0), Vector2i(3, 3))
	assert_true(fog.is_revealed(Vector2i(0, 0)))
	assert_true(fog.is_revealed(Vector2i(1, 1)))
	assert_true(fog.is_revealed(Vector2i(2, 2)))
	assert_true(fog.is_revealed(Vector2i(3, 3)))


func test_reveal_area() -> void:
	fog.reveal_area(Vector2i(5, 5), 1)
	# Should reveal 3x3 area around center
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var pos = Vector2i(5 + dx, 5 + dy)
			assert_true(fog.is_revealed(pos), "Cell (%d, %d) should be revealed" % [pos.x, pos.y])
	assert_eq(fog.get_revealed_count(), 9)


func test_reveal_area_larger() -> void:
	fog.reveal_area(Vector2i(5, 5), 2)
	# Should reveal 5x5 area
	assert_eq(fog.get_revealed_count(), 25)


func test_reveal_all() -> void:
	fog.reveal_all()
	assert_eq(fog.get_revealed_count(), 100, "All 100 cells should be revealed")
	assert_true(fog.is_revealed(Vector2i(0, 0)))
	assert_true(fog.is_revealed(Vector2i(9, 9)))


func test_reset() -> void:
	fog.reveal_all()
	fog.reset()
	assert_eq(fog.get_revealed_count(), 0, "All cells should be hidden after reset")


func test_get_total_cells() -> void:
	assert_eq(fog.get_total_cells(), 100, "10x10 grid = 100 cells")


func test_reveal_out_of_bounds_ignored() -> void:
	fog.reveal_cell(Vector2i(-1, 0))
	fog.reveal_cell(Vector2i(0, -1))
	fog.reveal_cell(Vector2i(10, 0))
	fog.reveal_cell(Vector2i(0, 10))
	assert_eq(fog.get_revealed_count(), 0, "Out of bounds reveals should be ignored")


func test_reveal_cell_signal_emitted() -> void:
	watch_signals(fog)
	fog.reveal_cell(Vector2i(3, 3))
	assert_signal_emitted(fog, "cell_revealed")


func test_reveal_cell_duplicate_no_signal() -> void:
	fog.reveal_cell(Vector2i(3, 3))
	watch_signals(fog)
	fog.reveal_cell(Vector2i(3, 3))  # Reveal same cell again
	assert_signal_not_emitted(fog, "cell_revealed", "Should not emit for already revealed cell")


func test_fog_cleared_signal_emitted() -> void:
	watch_signals(fog)
	fog.reveal_all()
	assert_signal_emitted(fog, "fog_cleared")
