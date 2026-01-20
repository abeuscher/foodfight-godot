extends GutTest
## Tests for TargetingManager.

const IslandGrid = preload("res://scripts/resources/island_grid.gd")
const Structure = preload("res://scripts/resources/structure.gd")
const IslandGridView = preload("res://scripts/components/island_grid_view.gd")
const PlacementManager = preload("res://scripts/components/placement_manager.gd")
const TargetingManager = preload("res://scripts/components/targeting_manager.gd")

var player_grid: IslandGrid
var enemy_grid: IslandGrid
var player_view: IslandGridView
var enemy_view: IslandGridView
var player_placement: PlacementManager
var enemy_placement: PlacementManager
var targeting: TargetingManager


func before_each() -> void:
	# Set up player side
	player_grid = IslandGrid.new(4, 3)
	player_view = IslandGridView.new()
	player_view.cell_size = Vector2(64, 64)
	add_child_autofree(player_view)
	player_view.initialize(player_grid)

	player_placement = PlacementManager.new()
	add_child_autofree(player_placement)
	player_placement.initialize(player_grid, player_view)

	# Set up enemy side
	enemy_grid = IslandGrid.new(4, 3)
	enemy_view = IslandGridView.new()
	enemy_view.cell_size = Vector2(64, 64)
	add_child_autofree(enemy_view)
	enemy_view.initialize(enemy_grid)

	enemy_placement = PlacementManager.new()
	add_child_autofree(enemy_placement)
	enemy_placement.initialize(enemy_grid, enemy_view)

	# Set up targeting manager
	targeting = TargetingManager.new()
	add_child_autofree(targeting)
	targeting.initialize(player_placement, enemy_placement, player_view, enemy_view)


# --- Selection Tests ---

func test_can_select_offensive_structure():
	var cannon = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	var result = targeting.select_structure(cannon)
	assert_true(result, "Should be able to select offensive structure")
	assert_eq(targeting.selected_structure, cannon, "Selected structure should be stored")


func test_cannot_select_defensive_structure():
	var interceptor = player_placement.place_structure(Structure.Type.PICKLE_INTERCEPTOR, Vector2i(0, 0))
	var result = targeting.select_structure(interceptor)
	assert_false(result, "Should not be able to select defensive structure")
	assert_null(targeting.selected_structure, "Selected structure should be null")


func test_cannot_select_hq():
	var hq = player_placement.place_structure(Structure.Type.BASE, Vector2i(0, 0))
	var result = targeting.select_structure(hq)
	assert_false(result, "Should not be able to select BASE")


func test_deselect_clears_selection():
	var cannon = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	targeting.select_structure(cannon)
	targeting.deselect()
	assert_null(targeting.selected_structure, "Selection should be cleared")


func test_structure_selected_signal_emitted():
	var cannon = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	var result = {"structure": null}
	targeting.structure_selected.connect(func(s): result.structure = s)

	targeting.select_structure(cannon)

	assert_eq(result.structure, cannon, "Signal should emit with structure")


func test_structure_deselected_signal_emitted():
	var cannon = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	targeting.select_structure(cannon)

	var emitted = {"value": false}
	targeting.structure_deselected.connect(func(): emitted.value = true)

	targeting.deselect()

	assert_true(emitted.value, "Deselected signal should emit")


# --- Target Assignment Tests ---

func test_assign_target():
	var cannon = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	targeting.assign_target(cannon, Vector2i(2, 1))

	assert_true(targeting.has_target(cannon), "Cannon should have target")
	assert_eq(targeting.get_target(cannon), Vector2i(2, 1), "Target should be correct")


func test_target_assigned_signal_emitted():
	var cannon = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	var result = {"structure": null, "pos": Vector2i(-1, -1)}
	targeting.target_assigned.connect(func(s, p):
		result.structure = s
		result.pos = p
	)

	targeting.assign_target(cannon, Vector2i(3, 2))

	assert_eq(result.structure, cannon, "Signal should have structure")
	assert_eq(result.pos, Vector2i(3, 2), "Signal should have position")


func test_clear_target():
	var cannon = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	targeting.assign_target(cannon, Vector2i(2, 1))
	targeting.clear_target(cannon)

	assert_false(targeting.has_target(cannon), "Target should be cleared")


func test_get_target_returns_invalid_when_no_target():
	var cannon = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	var target = targeting.get_target(cannon)
	assert_eq(target, Vector2i(-1, -1), "Should return invalid position when no target")


func test_reassign_target():
	var cannon = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	targeting.assign_target(cannon, Vector2i(1, 1))
	targeting.assign_target(cannon, Vector2i(2, 2))

	assert_eq(targeting.get_target(cannon), Vector2i(2, 2), "Target should be updated")


func test_multiple_structures_have_independent_targets():
	var cannon1 = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	var cannon2 = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(1, 0))

	targeting.assign_target(cannon1, Vector2i(0, 0))
	targeting.assign_target(cannon2, Vector2i(3, 2))

	assert_eq(targeting.get_target(cannon1), Vector2i(0, 0), "Cannon1 target correct")
	assert_eq(targeting.get_target(cannon2), Vector2i(3, 2), "Cannon2 target correct")


func test_clear_all_targets():
	var cannon1 = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	var cannon2 = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(1, 0))

	targeting.assign_target(cannon1, Vector2i(0, 0))
	targeting.assign_target(cannon2, Vector2i(1, 1))

	targeting.clear_all_targets()

	assert_false(targeting.has_target(cannon1), "Cannon1 target should be cleared")
	assert_false(targeting.has_target(cannon2), "Cannon2 target should be cleared")


func test_get_all_assignments():
	var cannon1 = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	var cannon2 = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(1, 0))

	targeting.assign_target(cannon1, Vector2i(0, 0))
	targeting.assign_target(cannon2, Vector2i(1, 1))

	var assignments = targeting.get_all_assignments()
	assert_eq(assignments.size(), 2, "Should have 2 assignments")
