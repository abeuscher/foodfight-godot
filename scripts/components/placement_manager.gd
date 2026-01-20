class_name PlacementManager
extends Node
## Manages structure placement on an island grid.

const IslandGrid = preload("res://scripts/resources/island_grid.gd")
const Structure = preload("res://scripts/resources/structure.gd")
const StructureView = preload("res://scripts/components/structure_view.gd")

signal structure_placed(structure: Resource, grid_pos: Vector2i)
signal structure_removed(grid_pos: Vector2i)
signal placement_failed(grid_pos: Vector2i, reason: String)
signal selection_changed(structure_type)  # null if deselected

var grid: IslandGrid
var grid_view: Control  # IslandGridView
var structures: Array[Resource] = []  # All placed structures
var structure_views: Dictionary = {}  # grid_pos -> StructureView
var _placement_history: Array[Vector2i] = []  # For undo

var selected_type = null  # Structure.Type or null
var ghost_view: Node2D = null
var _structures_container: Node2D


func initialize(island_grid: IslandGrid, island_grid_view: Control) -> void:
	grid = island_grid
	grid_view = island_grid_view

	# Create container for structure views
	_structures_container = Node2D.new()
	_structures_container.name = "Structures"
	grid_view.add_child(_structures_container)

	# Connect to grid view signals
	grid_view.cell_clicked.connect(_on_cell_clicked)
	grid_view.cell_hovered.connect(_on_cell_hovered)


func select_structure_type(structure_type) -> void:
	selected_type = structure_type
	selection_changed.emit(selected_type)
	_update_ghost()


func deselect() -> void:
	selected_type = null
	selection_changed.emit(null)
	_destroy_ghost()


func can_place_at(grid_pos: Vector2i) -> bool:
	if not grid:
		return false
	if not grid.is_valid_position(grid_pos):
		return false
	if not grid.is_cell_empty(grid_pos):
		return false
	return true


func place_structure(structure_type, grid_pos: Vector2i) -> Resource:
	if not can_place_at(grid_pos):
		var reason = _get_placement_failure_reason(grid_pos)
		placement_failed.emit(grid_pos, reason)
		return null

	# Create structure
	var structure = Structure.create(structure_type, grid_pos)
	structures.append(structure)

	# Update grid state
	grid.set_cell(grid_pos, IslandGrid.CellState.OCCUPIED)

	# Create visual
	var view = _create_structure_view(structure)
	structure_views[grid_pos] = view

	# Track for undo
	_placement_history.append(grid_pos)

	structure_placed.emit(structure, grid_pos)
	return structure


func can_undo() -> bool:
	return _placement_history.size() > 0


func undo_last_placement() -> bool:
	if not can_undo():
		return false

	var last_pos = _placement_history.pop_back()
	var removed = remove_structure_at(last_pos)
	if removed:
		structure_removed.emit(last_pos)
	return removed


func remove_structure_at(grid_pos: Vector2i) -> bool:
	if not structure_views.has(grid_pos):
		return false

	# Find and remove structure from array
	for i in range(structures.size() - 1, -1, -1):
		if structures[i].grid_position == grid_pos:
			structures.remove_at(i)
			break

	# Remove visual immediately
	var view = structure_views[grid_pos]
	view.get_parent().remove_child(view)
	view.queue_free()
	structure_views.erase(grid_pos)

	# Update grid state
	grid.set_cell(grid_pos, IslandGrid.CellState.EMPTY)

	return true


func get_structure_at(grid_pos: Vector2i) -> Resource:
	for s in structures:
		if s.grid_position == grid_pos:
			return s
	return null


func get_structures() -> Array[Resource]:
	return structures


func get_structures_by_type(structure_type) -> Array[Resource]:
	var result: Array[Resource] = []
	for s in structures:
		if s.type == structure_type:
			result.append(s)
	return result


func _on_cell_clicked(grid_pos: Vector2i) -> void:
	if selected_type != null:
		var placed = place_structure(selected_type, grid_pos)
		if placed and structure_views.has(grid_pos):
			structure_views[grid_pos].flash_placed()


func _on_cell_hovered(grid_pos: Vector2i) -> void:
	_update_ghost_position(grid_pos)


func _create_structure_view(structure: Resource) -> Node2D:
	var view = StructureView.new()
	view.initialize(structure, grid_view.cell_size)
	view.position = grid_view.grid_to_screen_center(structure.grid_position)
	_structures_container.add_child(view)
	return view


func _update_ghost() -> void:
	_destroy_ghost()
	if selected_type != null:
		var temp_struct = Structure.create(selected_type)
		ghost_view = StructureView.new()
		ghost_view.initialize(temp_struct, grid_view.cell_size)
		ghost_view.set_ghost_mode(true, true)
		ghost_view.visible = false  # Hidden until mouse moves over grid
		_structures_container.add_child(ghost_view)


func _destroy_ghost() -> void:
	if ghost_view:
		ghost_view.queue_free()
		ghost_view = null


func _update_ghost_position(grid_pos: Vector2i) -> void:
	if ghost_view and selected_type != null:
		ghost_view.visible = grid.is_valid_position(grid_pos)
		ghost_view.position = grid_view.grid_to_screen_center(grid_pos)
		ghost_view.set_ghost_mode(true, can_place_at(grid_pos))


func _get_placement_failure_reason(grid_pos: Vector2i) -> String:
	if not grid.is_valid_position(grid_pos):
		return "Invalid position"
	if not grid.is_cell_empty(grid_pos):
		return "Cell occupied"
	return "Unknown"
