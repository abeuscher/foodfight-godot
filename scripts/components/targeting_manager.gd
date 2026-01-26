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
var show_all_lines: bool = false  # When true, show all lines (Review All mode)

var _target_line_color: Color = Color(1.0, 0.5, 0.2, 0.8)  # Orange for weapons
var _transport_line_color: Color = Color(0.3, 0.6, 1.0, 0.8)  # Blue for transports
var _selected_highlight_color: Color = Color(1.0, 1.0, 0.5, 0.4)
var _assigned_dot_color: Color = Color(1.0, 0.5, 0.2, 0.6)  # Dot for assigned but not selected
var _transport_dot_color: Color = Color(0.3, 0.6, 1.0, 0.6)  # Blue dot for transports


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
	# Allow offensive structures OR loaded transports
	if not structure.is_offensive() and not _is_loaded_transport(structure):
		return false

	selected_structure = structure
	structure_selected.emit(structure)
	queue_redraw()
	return true


func _is_loaded_transport(structure: Resource) -> bool:
	return structure.is_transport() and structure.get_carried_unit_count() > 0


func deselect() -> void:
	if selected_structure:
		selected_structure = null
		structure_deselected.emit()
		queue_redraw()


func assign_target(structure: Resource, target_pos: Vector2i) -> bool:
	if not structure:
		return false
	# Allow offensive structures OR loaded transports
	if not structure.is_offensive() and not _is_loaded_transport(structure):
		return false

	# For transports, validate landing zone is clear of structures
	if _is_loaded_transport(structure):
		var target_structure = enemy_placement.get_structure_at(target_pos)
		if target_structure and not target_structure.is_destroyed:
			return false  # Can't land on a structure

	target_assignments[structure] = target_pos
	target_assigned.emit(structure, target_pos)
	queue_redraw()
	return true


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


func set_review_all(enabled: bool) -> void:
	show_all_lines = enabled
	queue_redraw()


func toggle_review_all() -> void:
	show_all_lines = not show_all_lines
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

		# Determine color based on structure type
		var is_transport = structure.is_transport()
		var line_color = _transport_line_color if is_transport else _target_line_color
		var dot_color = _transport_dot_color if is_transport else _assigned_dot_color

		# Show full line for selected structure OR when "Show All Paths" is active
		var is_selected = (structure == selected_structure)
		if is_selected or show_all_lines:
			# Draw full line with arrow
			draw_line(start, end, line_color, 2.0)
			_draw_arrowhead(start, end, line_color)
		else:
			# Draw small indicator dot on the structure to show it has a target
			draw_circle(start, 6.0, dot_color)


func _draw_selection_highlight() -> void:
	if not selected_structure or not player_grid_view:
		return

	var pos = _get_structure_screen_pos(selected_structure)
	var radius = min(player_grid_view.cell_size.x, player_grid_view.cell_size.y) * 0.5
	draw_arc(pos, radius, 0, TAU, 32, _selected_highlight_color, 4.0)


func _draw_arrowhead(start: Vector2, end: Vector2, color: Color = Color.WHITE) -> void:
	var direction = (end - start).normalized()
	var arrow_size = 12.0
	var arrow_angle = 0.4  # radians

	var left = end - direction.rotated(arrow_angle) * arrow_size
	var right = end - direction.rotated(-arrow_angle) * arrow_size

	draw_line(end, left, color, 2.0)
	draw_line(end, right, color, 2.0)


func _get_structure_screen_pos(structure: Resource) -> Vector2:
	var local_pos = player_grid_view.grid_to_screen_center(structure.grid_position)
	return player_grid_view.global_position + local_pos - global_position


func _get_enemy_cell_screen_pos(grid_pos: Vector2i) -> Vector2:
	var local_pos = enemy_grid_view.grid_to_screen_center(grid_pos)
	return enemy_grid_view.global_position + local_pos - global_position
