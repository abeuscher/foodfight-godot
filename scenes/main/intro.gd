extends Control
## Intro screen - title and island size selection.

@onready var size_dropdown: OptionButton = %SizeDropdown
@onready var btn_start: Button = %BtnStart

# Store selected grid size globally so game.gd can access it
static var selected_grid_size: int = 16


func _ready() -> void:
	# Populate dropdown with island sizes
	size_dropdown.add_item("8 x 8 (Small)", 0)
	size_dropdown.add_item("16 x 16 (Medium)", 1)
	size_dropdown.add_item("32 x 32 (Large)", 2)

	# Select 16x16 as default (index 1)
	size_dropdown.select(1)
	selected_grid_size = 16

	# Connect signals
	size_dropdown.item_selected.connect(_on_size_selected)
	btn_start.pressed.connect(_on_start_pressed)


func _on_size_selected(index: int) -> void:
	match index:
		0:
			selected_grid_size = 8
		1:
			selected_grid_size = 16
		2:
			selected_grid_size = 32


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/game.tscn")
