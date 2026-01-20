class_name StructureView
extends Node2D
## Visual representation of a Structure. Draws a colored circle with abbreviation.

const Structure = preload("res://scripts/resources/structure.gd")

var structure: Resource  # Structure type
var cell_size: Vector2 = Vector2(64, 64)
var is_ghost: bool = false
var is_valid_placement: bool = true


func initialize(struct: Resource, size: Vector2 = Vector2(64, 64)) -> void:
	structure = struct
	cell_size = size
	queue_redraw()


func set_ghost_mode(ghost: bool, valid: bool = true) -> void:
	is_ghost = ghost
	is_valid_placement = valid
	queue_redraw()


func _draw() -> void:
	if not structure:
		return

	var radius = min(cell_size.x, cell_size.y) * 0.4
	var center = Vector2.ZERO
	var base_color = Structure.get_color(structure.type)

	# Apply ghost/validity modifiers
	var draw_color = base_color
	if is_ghost:
		draw_color.a = 0.5
		if not is_valid_placement:
			draw_color = Color(0.8, 0.2, 0.2, 0.5)  # Red tint for invalid

	# Draw circle
	draw_circle(center, radius, draw_color)

	# Draw border
	var border_color = draw_color.lightened(0.3)
	border_color.a = draw_color.a
	draw_arc(center, radius, 0, TAU, 32, border_color, 2.0)

	# Draw abbreviation text
	var abbrev = Structure.get_abbreviation(structure.type)
	var font = ThemeDB.fallback_font
	var font_size = int(radius * 0.8)

	var text_size = font.get_string_size(abbrev, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = Vector2(-text_size.x / 2, text_size.y / 4)

	var text_color = Color.WHITE if draw_color.get_luminance() < 0.6 else Color.BLACK
	text_color.a = draw_color.a
	draw_string(font, text_pos, abbrev, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_color)


func flash_placed() -> void:
	# Simple scale animation for placement feedback
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
