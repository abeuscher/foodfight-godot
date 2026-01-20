class_name IslandGridView
extends Control
## Visual representation of an IslandGrid. Handles rendering and input.

signal cell_clicked(grid_pos: Vector2i)
signal cell_hovered(grid_pos: Vector2i)

const IslandGrid = preload("res://scripts/resources/island_grid.gd")
const FogManager = preload("res://scripts/components/fog_manager.gd")

@export var cell_size: Vector2 = Vector2(64, 64)
@export var grid_line_color: Color = Color(0.4, 0.4, 0.4, 1.0)
@export var grid_line_width: float = 2.0
@export var empty_cell_color: Color = Color(0.2, 0.25, 0.2, 1.0)
@export var occupied_cell_color: Color = Color(0.3, 0.35, 0.5, 1.0)
@export var blocked_cell_color: Color = Color(0.15, 0.15, 0.15, 1.0)
@export var hover_color: Color = Color(1.0, 1.0, 1.0, 0.2)
@export var fog_color: Color = Color(0.05, 0.05, 0.1, 1.0)

var grid: IslandGrid
var fog_manager: FogManager  # Optional - set to enable fog of war
var _hovered_cell: Vector2i = Vector2i(-1, -1)
var _fog_overlay: Node2D = null  # Draws fog on top of structures


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func initialize(island_grid: IslandGrid) -> void:
	grid = island_grid
	grid.cell_changed.connect(_on_cell_changed)
	_update_size()
	queue_redraw()


func enable_fog() -> void:
	fog_manager = FogManager.new()
	fog_manager.initialize(grid.width, grid.height)
	fog_manager.cell_revealed.connect(_on_fog_cell_revealed)
	# Create fog overlay that draws on top of structures
	_create_fog_overlay()
	queue_redraw()


func disable_fog() -> void:
	fog_manager = null
	if _fog_overlay:
		_fog_overlay.queue_free()
		_fog_overlay = null
	queue_redraw()


func _create_fog_overlay() -> void:
	if _fog_overlay:
		_fog_overlay.queue_free()
	_fog_overlay = _FogOverlay.new()
	_fog_overlay.grid_view = self
	# Add with high z_index to draw on top of structures
	_fog_overlay.z_index = 100
	add_child(_fog_overlay)


func redraw_fog_overlay() -> void:
	if _fog_overlay:
		_fog_overlay.queue_redraw()


func _update_size() -> void:
	if grid:
		custom_minimum_size = Vector2(grid.width, grid.height) * cell_size
		size = custom_minimum_size


func _draw() -> void:
	if not grid:
		return

	_draw_cells()
	_draw_grid_lines()
	# Note: Fog is now drawn by _fog_overlay to cover structures
	_draw_hover()


func _draw_cells() -> void:
	for y in range(grid.height):
		for x in range(grid.width):
			var cell_pos = Vector2i(x, y)
			var rect = _get_cell_rect(cell_pos)
			var color = _get_cell_color(grid.get_cell(cell_pos))
			draw_rect(rect, color)


func _draw_grid_lines() -> void:
	var total_width = grid.width * cell_size.x
	var total_height = grid.height * cell_size.y

	# Vertical lines
	for x in range(grid.width + 1):
		var start = Vector2(x * cell_size.x, 0)
		var end = Vector2(x * cell_size.x, total_height)
		draw_line(start, end, grid_line_color, grid_line_width)

	# Horizontal lines
	for y in range(grid.height + 1):
		var start = Vector2(0, y * cell_size.y)
		var end = Vector2(total_width, y * cell_size.y)
		draw_line(start, end, grid_line_color, grid_line_width)


func _draw_hover() -> void:
	if _hovered_cell.x >= 0 and grid.is_valid_position(_hovered_cell):
		var rect = _get_cell_rect(_hovered_cell)
		draw_rect(rect, hover_color)


func _get_cell_rect(cell_pos: Vector2i) -> Rect2:
	return Rect2(Vector2(cell_pos) * cell_size, cell_size)


func _get_cell_color(state: IslandGrid.CellState) -> Color:
	match state:
		IslandGrid.CellState.EMPTY:
			return empty_cell_color
		IslandGrid.CellState.OCCUPIED:
			return occupied_cell_color
		IslandGrid.CellState.BLOCKED:
			return blocked_cell_color
	return empty_cell_color


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var new_hover = _screen_to_grid(event.position)
	if new_hover != _hovered_cell:
		_hovered_cell = new_hover
		if grid and grid.is_valid_position(_hovered_cell):
			cell_hovered.emit(_hovered_cell)
		queue_redraw()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell_pos = _screen_to_grid(event.position)
		if grid and grid.is_valid_position(cell_pos):
			cell_clicked.emit(cell_pos)


func _screen_to_grid(screen_pos: Vector2) -> Vector2i:
	if cell_size.x <= 0 or cell_size.y <= 0:
		return Vector2i(-1, -1)
	return Vector2i(
		int(screen_pos.x / cell_size.x),
		int(screen_pos.y / cell_size.y)
	)


func grid_to_screen_center(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos) * cell_size + cell_size / 2.0


func _on_cell_changed(_position: Vector2i, _new_state: IslandGrid.CellState) -> void:
	queue_redraw()


func _on_fog_cell_revealed(_grid_pos: Vector2i) -> void:
	queue_redraw()
	redraw_fog_overlay()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hovered_cell = Vector2i(-1, -1)
		queue_redraw()


# Inner class for fog overlay that draws on top of structures
class _FogOverlay extends Node2D:
	var grid_view: Control = null  # Parent IslandGridView

	func _draw() -> void:
		if not grid_view or not grid_view.fog_manager:
			return
		var fog_manager = grid_view.fog_manager
		# Don't draw fog if it's disabled
		if not fog_manager.is_enabled:
			return
		var grid = grid_view.grid
		var cell_size = grid_view.cell_size
		var fog_color = grid_view.fog_color

		for y in range(grid.height):
			for x in range(grid.width):
				var cell_pos = Vector2i(x, y)
				if not fog_manager.is_revealed(cell_pos):
					var rect = Rect2(Vector2(cell_pos) * cell_size, cell_size)
					draw_rect(rect, fog_color)
