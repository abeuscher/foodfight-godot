extends GutTest
## Tests for ExecutionManager and turn execution flow.

const IslandGrid = preload("res://scripts/resources/island_grid.gd")
const Structure = preload("res://scripts/resources/structure.gd")
const IslandGridView = preload("res://scripts/components/island_grid_view.gd")
const PlacementManager = preload("res://scripts/components/placement_manager.gd")
const TargetingManager = preload("res://scripts/components/targeting_manager.gd")
const ExecutionManager = preload("res://scripts/components/execution_manager.gd")

var player_grid: IslandGrid
var enemy_grid: IslandGrid
var player_view: IslandGridView
var enemy_view: IslandGridView
var player_placement: PlacementManager
var enemy_placement: PlacementManager
var player_targeting: TargetingManager
var enemy_targeting: TargetingManager
var execution: ExecutionManager


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

	# Set up targeting managers
	player_targeting = TargetingManager.new()
	add_child_autofree(player_targeting)
	player_targeting.initialize(player_placement, enemy_placement, player_view, enemy_view)

	enemy_targeting = TargetingManager.new()
	add_child_autofree(enemy_targeting)
	enemy_targeting.initialize(enemy_placement, player_placement, enemy_view, player_view)

	# Set up execution manager
	execution = ExecutionManager.new()
	add_child_autofree(execution)
	execution.initialize(
		player_placement,
		enemy_placement,
		player_targeting,
		enemy_targeting,
		player_view,
		enemy_view
	)


# --- Execution Queue Tests ---

func test_execution_queue_sorts_by_priority():
	# Place structures with different priorities
	var cannon1 = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	var cannon2 = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(1, 0))

	# Give cannon2 higher priority
	cannon2.attack_priority = 100

	player_targeting.assign_target(cannon1, Vector2i(0, 0))
	player_targeting.assign_target(cannon2, Vector2i(1, 0))

	var queue = execution._build_execution_queue()
	assert_eq(queue.size(), 2, "Queue should have 2 entries")
	assert_eq(queue[0].structure, cannon2, "Higher priority cannon should be first")
	assert_eq(queue[1].structure, cannon1, "Lower priority cannon should be second")


func test_execution_queue_excludes_destroyed_structures():
	var cannon = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	player_targeting.assign_target(cannon, Vector2i(0, 0))

	cannon.is_destroyed = true

	var queue = execution._build_execution_queue()
	assert_eq(queue.size(), 0, "Queue should not include destroyed structures")


func test_execution_queue_excludes_untargeted_structures():
	var cannon = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	# No target assigned

	var queue = execution._build_execution_queue()
	assert_eq(queue.size(), 0, "Queue should not include structures without targets")


func test_execution_queue_includes_both_sides():
	var player_cannon = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	var enemy_cannon = enemy_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))

	player_targeting.assign_target(player_cannon, Vector2i(1, 1))
	enemy_targeting.assign_target(enemy_cannon, Vector2i(2, 2))

	var queue = execution._build_execution_queue()
	assert_eq(queue.size(), 2, "Queue should include both player and enemy structures")


# --- Signal Tests ---

func test_execution_started_signal_emitted():
	var player_cannon = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	player_targeting.assign_target(player_cannon, Vector2i(1, 1))

	var emitted = {"value": false}
	execution.execution_started.connect(func(): emitted.value = true)

	execution.execute_turn()
	await get_tree().create_timer(0.1).timeout

	assert_true(emitted.value, "Execution started signal should emit")


func test_execution_finished_signal_emitted():
	# No targets, so execution finishes immediately
	var emitted = {"value": false}
	execution.execution_finished.connect(func(): emitted.value = true)

	execution.execute_turn()
	await get_tree().create_timer(0.1).timeout

	assert_true(emitted.value, "Execution finished signal should emit")


# --- Hit Resolution Tests ---

func test_hit_damages_structure():
	var player_cannon = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	var enemy_hq = enemy_placement.place_structure(Structure.Type.BASE, Vector2i(1, 1))
	var initial_health = enemy_hq.health

	player_targeting.assign_target(player_cannon, Vector2i(1, 1))

	var hit_data = {"structure": null, "damage": 0}
	execution.structure_hit.connect(func(s, d):
		hit_data.structure = s
		hit_data.damage = d
	)

	execution.execute_turn()
	await get_tree().create_timer(2.0).timeout  # Wait for projectile

	assert_eq(hit_data.structure, enemy_hq, "Hit signal should report correct structure")
	assert_lt(enemy_hq.health, initial_health, "Structure should take damage")


func test_structure_destroyed_signal():
	var player_cannon = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	var enemy_cannon = enemy_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(1, 1))
	# Enemy cannon has 1 HP, so it should be destroyed

	player_targeting.assign_target(player_cannon, Vector2i(1, 1))

	var destroyed_struct = {"value": null}
	execution.structure_destroyed.connect(func(s): destroyed_struct.value = s)

	execution.execute_turn()
	await get_tree().create_timer(2.0).timeout

	assert_eq(destroyed_struct.value, enemy_cannon, "Destroyed signal should emit for enemy cannon")
	assert_true(enemy_cannon.is_destroyed, "Structure should be marked as destroyed")


func test_miss_on_empty_cell():
	var player_cannon = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	# Target an empty cell
	player_targeting.assign_target(player_cannon, Vector2i(3, 2))

	var hit_count = {"value": 0}
	execution.structure_hit.connect(func(_s, _d): hit_count.value += 1)

	execution.execute_turn()
	await get_tree().create_timer(2.0).timeout

	assert_eq(hit_count.value, 0, "No hit signal should emit for empty cell")


# --- Is Executing State ---

func test_is_executing_during_execution():
	var player_cannon = player_placement.place_structure(Structure.Type.CONDIMENT_CANNON, Vector2i(0, 0))
	player_targeting.assign_target(player_cannon, Vector2i(1, 1))

	assert_false(execution.is_executing(), "Should not be executing before start")

	execution.execute_turn()
	await get_tree().process_frame

	# Give it a moment to start
	await get_tree().create_timer(0.05).timeout
	assert_true(execution.is_executing(), "Should be executing during turn")

	await get_tree().create_timer(2.0).timeout
	assert_false(execution.is_executing(), "Should not be executing after finish")
