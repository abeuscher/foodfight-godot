class_name TargetingManager
extends Node2D
## Manages target assignment for offensive structures.

const Structure = preload("res://scripts/resources/structure.gd")
const PlacementManager = preload("res://scripts/components/placement_manager.gd")

signal structure_selected(structure: Resource)
signal structure_deselected()
signal target_assigned(structure: Resource, target_pos: Vector2i)
signal target_cleared(structure: Resource)

var player_placement: PlacementManager
var enemy_placement: PlacementManager
var player_grid_view: Control
var enemy_grid_view: Control

var selected_structure: Resource = null
var target_assignments: Dictionary = {}  # Structure -> Vector2i
var block_next_player_click: bool = false  # Set by game.gd after placement
var show_lines: bool = true  # Whether to draw targeting lines

var _target_line_color: Color = Color(1.0, 0.5, 0.2, 0.8)
var _selected_highlight_color: Color = Color(1.0, 1.0, 0.5, 0.4)


func initialize(
	p_placement: PlacementManager,
	e_placement: PlacementManager,
	p_grid_view: Control,
	e_grid_view: Control
) -> void:
	player_placement = p_placement
	enemy_placement = e_placement
	player_grid_view = p_grid_view
	enemy_grid_view = e_grid_view

	# Connect to grid clicks
	player_grid_view.cell_clicked.connect(_on_player_cell_clicked)
	enemy_grid_view.cell_clicked.connect(_on_enemy_cell_clicked)


func select_structure(structure: Resource) -> bool:
	if not structure:
		return false
	if not structure.is_offensive():
		return false

	selected_structure = structure
	structure_selected.emit(structure)
	queue_redraw()
	return true


func deselect() -> void:
	if selected_structure:
		selected_structure = null
		structure_deselected.emit()
		queue_redraw()


func assign_target(structure: Resource, target_pos: Vector2i) -> void:
	if not structure or not structure.is_offensive():
		return

	target_assignments[structure] = target_pos
	target_assigned.emit(structure, target_pos)
	queue_redraw()


func clear_target(structure: Resource) -> void:
	if target_assignments.has(structure):
		target_assignments.erase(structure)
		target_cleared.emit(structure)
		queue_redraw()


func get_target(structure: Resource) -> Vector2i:
	if target_assignments.has(structure):
		return target_assignments[structure]
	return Vector2i(-1, -1)


func has_target(structure: Resource) -> bool:
	return target_assignments.has(structure)


func get_all_assignments() -> Dictionary:
	return target_assignments.duplicate()


func clear_all_targets() -> void:
	target_assignments.clear()
	queue_redraw()


func _on_player_cell_clicked(grid_pos: Vector2i) -> void:
	# Block click if a structure was just placed (same click event)
	if block_next_player_click:
		block_next_player_click = false
		return

	# Don't handle targeting if we're in placement mode
	if player_placement.selected_type != null:
		return

	# When clicking player grid, try to select an offensive structure there
	var structure = player_placement.get_structure_at(grid_pos)
	if structure and structure.is_offensive():
		select_structure(structure)
	else:
		deselect()


func _on_enemy_cell_clicked(grid_pos: Vector2i) -> void:
	# When clicking enemy grid with a structure selected, assign target
	if selected_structure:
		assign_target(selected_structure, grid_pos)
		deselect()  # Deselect after assigning


func _input(event: InputEvent) -> void:
	# ESC or right-click to deselect
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			deselect()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			deselect()


func _draw() -> void:
	_draw_target_lines()
	_draw_selection_highlight()


func _draw_target_lines() -> void:
	if not show_lines:
		return
	if not player_grid_view or not enemy_grid_view:
		return

	for structure in target_assignments:
		if structure.is_destroyed:
			continue

		var target_pos: Vector2i = target_assignments[structure]
		var start = _get_structure_screen_pos(structure)
		var end = _get_enemy_cell_screen_pos(target_pos)

		# Draw line
		draw_line(start, end, _target_line_color, 2.0)

		# Draw arrowhead
		_draw_arrowhead(start, end)


func _draw_selection_highlight() -> void:
	if not selected_structure or not player_grid_view:
		return

	var pos = _get_structure_screen_pos(selected_structure)
	var radius = min(player_grid_view.cell_size.x, player_grid_view.cell_size.y) * 0.5
	draw_arc(pos, radius, 0, TAU, 32, _selected_highlight_color, 4.0)


func _draw_arrowhead(start: Vector2, end: Vector2) -> void:
	var direction = (end - start).normalized()
	var arrow_size = 12.0
	var arrow_angle = 0.4  # radians

	var left = end - direction.rotated(arrow_angle) * arrow_size
	var right = end - direction.rotated(-arrow_angle) * arrow_size

	draw_line(end, left, _target_line_color, 2.0)
	draw_line(end, right, _target_line_color, 2.0)


func _get_structure_screen_pos(structure: Resource) -> Vector2:
	var local_pos = player_grid_view.grid_to_screen_center(structure.grid_position)
	return player_grid_view.global_position + local_pos - global_position


func _get_enemy_cell_screen_pos(grid_pos: Vector2i) -> Vector2:
	var local_pos = enemy_grid_view.grid_to_screen_center(grid_pos)
	return enemy_grid_view.global_position + local_pos - global_position
