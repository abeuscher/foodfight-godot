extends Control
## Main game scene - Phase 5: Arsenal Expansion.

const IslandGrid = preload("res://scripts/resources/island_grid.gd")
const Structure = preload("res://scripts/resources/structure.gd")
const PlacementManager = preload("res://scripts/components/placement_manager.gd")
const TargetingManager = preload("res://scripts/components/targeting_manager.gd")
const ExecutionManager = preload("res://scripts/components/execution_manager.gd")
const FogManager = preload("res://scripts/components/fog_manager.gd")
const IntroScreen = preload("res://scenes/main/intro.gd")

@onready var player_grid_view: Control = %PlayerGrid
@onready var enemy_grid_view: Control = %EnemyGrid
@onready var canal: ColorRect = %Canal
@onready var status_label: Label = %StatusLabel
@onready var player_money_label: Label = %PlayerMoney
@onready var enemy_money_label: Label = %EnemyMoney
@onready var btn_base: Button = %BtnBase
@onready var btn_cannon: Button = %BtnCannon
@onready var btn_condiment: Button = %BtnCondiment
@onready var btn_interceptor: Button = %BtnInterceptor
@onready var btn_radar: Button = %BtnRadar
@onready var btn_lemonade: Button = %BtnLemonade
@onready var btn_salad: Button = %BtnSalad
@onready var btn_jammer: Button = %BtnJammer
@onready var sep1: HSeparator = %Sep1
@onready var sep2: HSeparator = %Sep2
@onready var btn_undo: Button = %BtnUndo
@onready var btn_end_turn: Button = %BtnEndTurn
@onready var round_label: Label = %RoundLabel
@onready var slate: ColorRect = %Slate
@onready var slate_title: Label = %SlateTitle
@onready var slate_subtitle: Label = %SlateSubtitle
@onready var btn_slate_continue: Button = %BtnSlateContinue
@onready var btn_slate_reset: Button = %BtnSlateReset
@onready var toolbar_container: VBoxContainer = %ToolbarContainer
# Info panel elements
@onready var info_panel: PanelContainer = %InfoPanel
@onready var info_title: Label = %InfoTitle
@onready var info_description: Label = %InfoDescription
# Dev toolbar elements
@onready var dev_toolbar: HBoxContainer = %DevToolbar
@onready var btn_toggle_fog: Button = %BtnToggleFog
@onready var btn_restart: Button = %BtnRestart

enum TurnPhase { BASE_PLACEMENT, PLACEMENT, TARGETING, FIGHT }

var player_grid: IslandGrid
var enemy_grid: IslandGrid
var placement_manager: PlacementManager
var enemy_placement_manager: PlacementManager
var targeting_manager: TargetingManager
var enemy_targeting_manager: TargetingManager
var execution_manager: ExecutionManager
var enemy_fog_manager: FogManager  # Tracks what enemy can see on player grid
var current_phase: TurnPhase = TurnPhase.BASE_PLACEMENT

# Unified action history for undo
# Each entry: {"type": "placement", "grid_pos": Vector2i, "structure_type": Type} or {"type": "target", "structure": Resource, "prev_target": Variant}
var _action_history: Array = []

# Player inventory - how many of each structure type can still be placed
# Note: Bases are free; other structures require purchase via economy
var _inventory: Dictionary = {
	Structure.Type.BASE: 3,  # Adjusted in _ready based on grid size
	Structure.Type.HOT_DOG_CANNON: 0,  # Must purchase
	Structure.Type.CONDIMENT_STATION: 0,  # Must purchase
	Structure.Type.COFFEE_RADAR: 0,  # Must purchase
	Structure.Type.VEGGIE_CANNON: 0,  # Must purchase
	Structure.Type.LEMONADE_STAND: 0,  # Must purchase
	Structure.Type.SALAD_BAR: 0,  # Must purchase
	Structure.Type.RADAR_JAMMER: 0,  # Must purchase
}


func _get_base_count_for_grid_size() -> int:
	# Scale bases with grid size: 8x8=1, 16x16=2, 32x32=3
	match GRID_SIZE:
		8:
			return 1
		16:
			return 2
		_:
			return 3


var GRID_SIZE: int = 16  # Set from intro screen


func _ready() -> void:
	# Get grid size from intro screen selection
	GRID_SIZE = IntroScreen.selected_grid_size

	# Scale bases based on grid size
	_inventory[Structure.Type.BASE] = _get_base_count_for_grid_size()

	# Calculate grid view size based on grid size and cell size (16x16 pixels per cell)
	var grid_pixel_size = GRID_SIZE * 16
	player_grid_view.custom_minimum_size = Vector2(grid_pixel_size, grid_pixel_size)
	enemy_grid_view.custom_minimum_size = Vector2(grid_pixel_size, grid_pixel_size)
	canal.custom_minimum_size = Vector2(64, grid_pixel_size)

	# Initialize player island
	player_grid = IslandGrid.new(GRID_SIZE, GRID_SIZE)
	player_grid_view.initialize(player_grid)

	placement_manager = PlacementManager.new()
	add_child(placement_manager)
	placement_manager.initialize(player_grid, player_grid_view)

	# Initialize enemy island
	enemy_grid = IslandGrid.new(GRID_SIZE, GRID_SIZE)
	enemy_grid_view.initialize(enemy_grid)
	enemy_grid_view.enable_fog()  # Fog of war on enemy grid

	enemy_placement_manager = PlacementManager.new()
	add_child(enemy_placement_manager)
	enemy_placement_manager.initialize(enemy_grid, enemy_grid_view)

	# Initialize enemy's fog of war (tracks what enemy can see on player grid)
	enemy_fog_manager = FogManager.new()
	enemy_fog_manager.initialize(GRID_SIZE, GRID_SIZE)

	# Initialize player targeting manager (drawn on top of fog)
	targeting_manager = TargetingManager.new()
	targeting_manager.z_index = 200  # Above fog overlay (z_index 100)
	add_child(targeting_manager)
	targeting_manager.initialize(
		placement_manager,
		enemy_placement_manager,
		player_grid_view,
		enemy_grid_view
	)

	# Initialize enemy targeting manager (for AI targets)
	enemy_targeting_manager = TargetingManager.new()
	add_child(enemy_targeting_manager)
	enemy_targeting_manager.initialize(
		enemy_placement_manager,
		placement_manager,
		enemy_grid_view,
		player_grid_view
	)
	# Hide enemy targeting lines - player shouldn't see where enemy is aiming
	enemy_targeting_manager.show_lines = false

	# Initialize execution manager
	execution_manager = ExecutionManager.new()
	add_child(execution_manager)
	execution_manager.initialize(
		placement_manager,
		enemy_placement_manager,
		targeting_manager,
		enemy_targeting_manager,
		player_grid_view,
		enemy_grid_view
	)
	execution_manager.enemy_fog_manager = enemy_fog_manager  # For enemy projectile fog reveal

	# Note: Enemy structures are set up after player base placement phase ends

	# Connect placement signals
	placement_manager.structure_placed.connect(_on_structure_placed)
	placement_manager.placement_failed.connect(_on_placement_failed)
	placement_manager.selection_changed.connect(_on_placement_selection_changed)

	# Connect targeting signals
	targeting_manager.structure_selected.connect(_on_targeting_structure_selected)
	targeting_manager.structure_deselected.connect(_on_targeting_structure_deselected)
	targeting_manager.target_assigned.connect(_on_target_assigned)

	# Disconnect automatic grid connections - we'll handle clicks manually
	# to properly separate phases and check inventory
	player_grid_view.cell_clicked.disconnect(targeting_manager._on_player_cell_clicked)
	enemy_grid_view.cell_clicked.disconnect(targeting_manager._on_enemy_cell_clicked)
	player_grid_view.cell_clicked.disconnect(placement_manager._on_cell_clicked)

	# Connect our custom click handlers (check phase and inventory before placement)
	player_grid_view.cell_clicked.connect(_on_player_grid_clicked)
	enemy_grid_view.cell_clicked.connect(_on_targeting_enemy_click)

	# Connect grid hover for status
	player_grid_view.cell_hovered.connect(_on_player_cell_hovered)
	enemy_grid_view.cell_hovered.connect(_on_enemy_cell_hovered)

	# Connect buttons
	btn_base.pressed.connect(_on_btn_base_pressed)
	btn_cannon.pressed.connect(_on_btn_cannon_pressed)
	btn_condiment.pressed.connect(_on_btn_condiment_pressed)
	btn_interceptor.pressed.connect(_on_btn_interceptor_pressed)
	btn_radar.pressed.connect(_on_btn_radar_pressed)
	btn_lemonade.pressed.connect(_on_btn_lemonade_pressed)
	btn_salad.pressed.connect(_on_btn_salad_pressed)
	btn_jammer.pressed.connect(_on_btn_jammer_pressed)
	btn_undo.pressed.connect(_on_btn_undo_pressed)
	btn_end_turn.pressed.connect(_on_btn_end_turn_pressed)
	btn_slate_continue.pressed.connect(_on_slate_continue_pressed)
	btn_slate_reset.pressed.connect(_on_slate_reset_pressed)

	# Connect dev toolbar buttons
	btn_toggle_fog.pressed.connect(_on_btn_toggle_fog_pressed)
	btn_restart.pressed.connect(_on_btn_restart_pressed)

	# Connect button hover signals for info panel
	_setup_button_hover_signals()

	# Connect execution manager signals
	execution_manager.execution_started.connect(_on_execution_started)
	execution_manager.execution_finished.connect(_on_execution_finished)
	execution_manager.projectile_intercepted.connect(_on_projectile_intercepted)
	execution_manager.structure_hit.connect(_on_structure_hit)
	execution_manager.structure_destroyed.connect(_on_structure_destroyed)
	execution_manager.fog_reveal_path.connect(_on_fog_reveal_path)
	execution_manager.radar_jammed.connect(_on_radar_jammed)

	# Connect GameManager signals
	GameManager.state_changed.connect(_on_game_state_changed)

	# Connect EconomyManager signals
	EconomyManager.money_changed.connect(_on_money_changed)
	EconomyManager.reset()
	_update_money_display()

	_update_inventory_buttons()
	_update_phase_ui()

	# Auto-select bases for base placement phase
	placement_manager.select_structure_type(Structure.Type.BASE)

	# Show game start slate
	_show_slate("FOOD FIGHT ISLAND", "Base Placement Phase", false)


func _setup_enemy_structures() -> void:
	# Place enemy bases - number scaled to grid size (same as player)
	var base_count = _get_base_count_for_grid_size()
	var back_x = int(GRID_SIZE * 0.8)  # 80% across

	if base_count >= 1:
		enemy_placement_manager.place_structure(Structure.Type.BASE, Vector2i(back_x, int(GRID_SIZE * 0.5)))
	if base_count >= 2:
		enemy_placement_manager.place_structure(Structure.Type.BASE, Vector2i(back_x, int(GRID_SIZE * 0.25)))
	if base_count >= 3:
		enemy_placement_manager.place_structure(Structure.Type.BASE, Vector2i(back_x, int(GRID_SIZE * 0.75)))

	# Place enemy offensive structures - front of island (low x)
	var front_x = int(GRID_SIZE * 0.25)
	enemy_placement_manager.place_structure(Structure.Type.HOT_DOG_CANNON, Vector2i(front_x, int(GRID_SIZE * 0.5)))
	if GRID_SIZE >= 16:
		enemy_placement_manager.place_structure(Structure.Type.HOT_DOG_CANNON, Vector2i(front_x, int(GRID_SIZE * 0.25)))

	# Place enemy defensive structures - radar + two missile silos (all board sizes)
	var mid_x = int(GRID_SIZE * 0.6)
	# Place radar in middle-back area
	enemy_placement_manager.place_structure(Structure.Type.COFFEE_RADAR, Vector2i(mid_x, int(GRID_SIZE * 0.5)))
	# Place two Veggie Cannons near the radar (within 6 blocks)
	enemy_placement_manager.place_structure(Structure.Type.VEGGIE_CANNON, Vector2i(mid_x - 2, int(GRID_SIZE * 0.35)))
	enemy_placement_manager.place_structure(Structure.Type.VEGGIE_CANNON, Vector2i(mid_x - 2, int(GRID_SIZE * 0.65)))

	# Assign initial targets for enemy cannons
	_assign_enemy_targets()


func _assign_enemy_targets() -> void:
	# Smart AI: target player structures that enemy has discovered through fog
	var player_structures = placement_manager.get_structures()
	var visible_targets: Array = []

	# Build list of valid targets (non-destroyed player structures that enemy can see)
	for s in player_structures:
		if not s.is_destroyed:
			# Only target if enemy has revealed this cell
			if enemy_fog_manager.is_revealed(s.grid_position):
				visible_targets.append(s)

	# If no visible structures, fire at random revealed cells (scouting)
	if visible_targets.is_empty():
		_assign_scouting_enemy_targets()
		return

	# Sort targets by priority (higher priority = more valuable target)
	visible_targets.sort_custom(_compare_target_priority)

	# Assign targets to enemy offensive structures
	for structure in enemy_placement_manager.get_structures():
		if structure.is_destroyed:
			continue
		if not structure.is_offensive():
			continue

		# Pick a target - prioritize high-value targets with some randomness
		var target: Resource
		if randf() < 0.7 and not visible_targets.is_empty():
			# 70% chance to pick from top priorities
			var pick_range = mini(3, visible_targets.size())  # Top 3 targets
			target = visible_targets[randi_range(0, pick_range - 1)]
		elif not visible_targets.is_empty():
			# 30% chance for any valid target
			target = visible_targets[randi_range(0, visible_targets.size() - 1)]
		else:
			continue

		enemy_targeting_manager.assign_target(structure, target.grid_position)


func _compare_target_priority(a: Resource, b: Resource) -> bool:
	# Higher priority targets first
	return _get_target_priority(a) > _get_target_priority(b)


func _get_target_priority(structure: Resource) -> int:
	# Priority scoring for AI targeting
	var priority = 0
	match structure.type:
		Structure.Type.BASE:
			priority = 100  # Highest priority - win condition
		Structure.Type.HOT_DOG_CANNON, Structure.Type.CONDIMENT_CANNON, Structure.Type.CONDIMENT_STATION:
			priority = 80  # High priority - reduce player offense
		Structure.Type.LEMONADE_STAND:
			priority = 70  # Good priority - reduce player income
		Structure.Type.VEGGIE_CANNON, Structure.Type.PICKLE_INTERCEPTOR:
			priority = 60  # Medium priority - reduce player defense
		Structure.Type.COFFEE_RADAR:
			priority = 50  # Lower priority - support structure
		Structure.Type.SALAD_BAR:
			priority = 40  # Lowest priority - healing

	# Bonus for low health targets (easier to destroy)
	if structure.health == 1:
		priority += 15

	return priority


func _assign_scouting_enemy_targets() -> void:
	# Scouting: fire at unexplored areas to reveal the player's grid
	# Prefer areas that might have structures (middle/back of grid)
	for structure in enemy_placement_manager.get_structures():
		if structure.is_destroyed:
			continue
		if not structure.is_offensive():
			continue

		# Try to find an unrevealed cell in a strategic location
		var target_pos = _find_scouting_target()
		enemy_targeting_manager.assign_target(structure, target_pos)


func _find_scouting_target() -> Vector2i:
	# Try to find an unrevealed cell - prefer areas likely to have structures
	# Player typically places bases in back (high x) and offense in front (low x)
	var margin = maxi(1, GRID_SIZE / 8)

	# First, try to scout the back area where bases likely are (60-90% of grid)
	for _attempt in range(15):
		var x = randi_range(int(GRID_SIZE * 0.6), int(GRID_SIZE * 0.9))
		var y = randi_range(margin, player_grid.height - margin - 1)
		var pos = Vector2i(x, y)
		if not enemy_fog_manager.is_revealed(pos):
			return pos

	# Then try middle area (30-60% of grid)
	for _attempt in range(10):
		var x = randi_range(int(GRID_SIZE * 0.3), int(GRID_SIZE * 0.6))
		var y = randi_range(margin, player_grid.height - margin - 1)
		var pos = Vector2i(x, y)
		if not enemy_fog_manager.is_revealed(pos):
			return pos

	# Then try front area (10-30% of grid)
	for _attempt in range(10):
		var x = randi_range(int(GRID_SIZE * 0.1), int(GRID_SIZE * 0.3))
		var y = randi_range(margin, player_grid.height - margin - 1)
		var pos = Vector2i(x, y)
		if not enemy_fog_manager.is_revealed(pos):
			return pos

	# Fallback: any unrevealed cell
	for _attempt in range(20):
		var x = randi_range(1, player_grid.width - 2)
		var y = randi_range(1, player_grid.height - 2)
		var pos = Vector2i(x, y)
		if not enemy_fog_manager.is_revealed(pos):
			return pos

	# Everything revealed, just pick random
	return Vector2i(randi_range(1, player_grid.width - 2), randi_range(1, player_grid.height - 2))


func _enemy_ai_purchase() -> void:
	# Enemy AI decides what to buy based on current situation
	var money = EconomyManager.enemy_money

	# Count current enemy structures by category
	var offense_count = 0
	var defense_count = 0
	var income_count = 0
	for s in enemy_placement_manager.get_structures():
		if s.is_destroyed:
			continue
		if s.is_offensive():
			offense_count += 1
		elif s.type == Structure.Type.LEMONADE_STAND:
			income_count += 1
		elif s.is_defensive():
			defense_count += 1

	# CPU economic bailout: If enemy has $0 and no offensive weapons, give them $10
	if money == 0 and offense_count == 0:
		EconomyManager.earn("enemy", 10, "bailout")
		money = EconomyManager.enemy_money

	# Decide what to buy based on priorities
	var purchase_list: Array = []

	# Priority 1: Always want at least 2 offensive structures
	if offense_count < 2:
		purchase_list.append(Structure.Type.HOT_DOG_CANNON)  # $5

	# Priority 2: Get income generation early
	if income_count < 1 and money >= 20:
		purchase_list.append(Structure.Type.LEMONADE_STAND)  # $20

	# Priority 3: More offense
	if offense_count < 4:
		purchase_list.append(Structure.Type.HOT_DOG_CANNON)  # $5
		if money >= 10:
			purchase_list.append(Structure.Type.CONDIMENT_STATION)  # $10

	# Priority 4: Defense if taking hits
	if defense_count < 2:
		purchase_list.append(Structure.Type.VEGGIE_CANNON)  # $5

	# Priority 5: More income if rich
	if money >= 25 and income_count < 2:
		purchase_list.append(Structure.Type.LEMONADE_STAND)  # $20

	# Try to purchase from the list
	var purchases_made = 0
	for structure_type in purchase_list:
		var cost = Structure.get_cost(structure_type)
		if EconomyManager.can_afford("enemy", cost):
			var pos = _find_enemy_placement_position(structure_type)
			if pos != Vector2i(-1, -1):
				if EconomyManager.spend("enemy", cost, Structure.get_display_name(structure_type)):
					enemy_placement_manager.place_structure(structure_type, pos)
					purchases_made += 1

	# Notify player if enemy built new structures
	if purchases_made > 0:
		_update_status("Enemy built %d new structure(s)!" % purchases_made)


func _find_enemy_placement_position(structure_type) -> Vector2i:
	# Find a valid position on the enemy grid for placement
	# Strategy: place offensive structures toward the front (lower x), defensive toward back (higher x)
	var preferred_x_min: int
	var preferred_x_max: int
	var margin = maxi(1, GRID_SIZE / 8)

	if Structure.get_category(structure_type) == Structure.Category.OFFENSIVE:
		preferred_x_min = int(GRID_SIZE * 0.1)
		preferred_x_max = int(GRID_SIZE * 0.4)
	else:
		preferred_x_min = int(GRID_SIZE * 0.55)
		preferred_x_max = int(GRID_SIZE * 0.85)

	# Try random positions in preferred zone first
	for _attempt in range(20):
		var x = randi_range(preferred_x_min, preferred_x_max)
		var y = randi_range(margin, enemy_grid.height - margin - 1)
		var pos = Vector2i(x, y)
		if enemy_grid.is_cell_empty(pos):
			return pos

	# Fallback: try anywhere on the grid
	for _attempt in range(30):
		var x = randi_range(1, enemy_grid.width - 2)
		var y = randi_range(1, enemy_grid.height - 2)
		var pos = Vector2i(x, y)
		if enemy_grid.is_cell_empty(pos):
			return pos

	return Vector2i(-1, -1)  # No valid position found


func _on_btn_base_pressed() -> void:
	targeting_manager.deselect()
	# Toggle: if already selected, deselect; otherwise select
	if placement_manager.selected_type == Structure.Type.BASE:
		placement_manager.deselect()
	elif _has_inventory(Structure.Type.BASE):
		placement_manager.select_structure_type(Structure.Type.BASE)


func _on_btn_cannon_pressed() -> void:
	targeting_manager.deselect()
	if placement_manager.selected_type == Structure.Type.HOT_DOG_CANNON:
		placement_manager.deselect()
	elif _can_select_structure(Structure.Type.HOT_DOG_CANNON):
		placement_manager.select_structure_type(Structure.Type.HOT_DOG_CANNON)


func _on_btn_condiment_pressed() -> void:
	targeting_manager.deselect()
	if placement_manager.selected_type == Structure.Type.CONDIMENT_STATION:
		placement_manager.deselect()
	elif _can_select_structure(Structure.Type.CONDIMENT_STATION):
		placement_manager.select_structure_type(Structure.Type.CONDIMENT_STATION)


func _on_btn_interceptor_pressed() -> void:
	targeting_manager.deselect()
	if placement_manager.selected_type == Structure.Type.VEGGIE_CANNON:
		placement_manager.deselect()
	elif _can_select_structure(Structure.Type.VEGGIE_CANNON):
		placement_manager.select_structure_type(Structure.Type.VEGGIE_CANNON)


func _on_btn_radar_pressed() -> void:
	targeting_manager.deselect()
	if placement_manager.selected_type == Structure.Type.COFFEE_RADAR:
		placement_manager.deselect()
	elif _can_select_structure(Structure.Type.COFFEE_RADAR):
		placement_manager.select_structure_type(Structure.Type.COFFEE_RADAR)


func _on_btn_lemonade_pressed() -> void:
	targeting_manager.deselect()
	if placement_manager.selected_type == Structure.Type.LEMONADE_STAND:
		placement_manager.deselect()
	elif _can_select_structure(Structure.Type.LEMONADE_STAND):
		placement_manager.select_structure_type(Structure.Type.LEMONADE_STAND)


func _on_btn_salad_pressed() -> void:
	targeting_manager.deselect()
	if placement_manager.selected_type == Structure.Type.SALAD_BAR:
		placement_manager.deselect()
	elif _can_select_structure(Structure.Type.SALAD_BAR):
		placement_manager.select_structure_type(Structure.Type.SALAD_BAR)


func _on_btn_jammer_pressed() -> void:
	targeting_manager.deselect()
	if placement_manager.selected_type == Structure.Type.RADAR_JAMMER:
		placement_manager.deselect()
	elif _can_select_structure(Structure.Type.RADAR_JAMMER):
		placement_manager.select_structure_type(Structure.Type.RADAR_JAMMER)


func _on_btn_undo_pressed() -> void:
	placement_manager.deselect()
	targeting_manager.deselect()

	# Determine which action types can be undone in current phase
	var allowed_type: String
	if current_phase == TurnPhase.BASE_PLACEMENT or current_phase == TurnPhase.PLACEMENT:
		allowed_type = "placement"
	elif current_phase == TurnPhase.TARGETING:
		allowed_type = "target"
	else:
		_update_status("Cannot undo during this phase")
		return

	# Find the last action of the allowed type
	var action_index = -1
	for i in range(_action_history.size() - 1, -1, -1):
		if _action_history[i].type == allowed_type:
			action_index = i
			break

	if action_index == -1:
		_update_status("Nothing to undo")
		return

	var action = _action_history[action_index]
	_action_history.remove_at(action_index)

	match action.type:
		"placement":
			# Also clear any target for this structure before removing it
			var structure = placement_manager.get_structure_at(action.grid_pos)
			if structure:
				targeting_manager.clear_target(structure)
			placement_manager.remove_structure_at(action.grid_pos)
			# Restore inventory
			_restore_inventory(action.structure_type)
			if current_phase == TurnPhase.BASE_PLACEMENT:
				_update_status(_get_phase_status_text())
				# Re-select bases for continued placement
				placement_manager.select_structure_type(Structure.Type.BASE)
			else:
				_update_status("Undid placement")
		"target":
			targeting_manager.clear_target(action.structure)
			_update_status("Undid target assignment")


func _on_structure_placed(structure: Resource, grid_pos: Vector2i) -> void:
	var sname = Structure.get_display_name(structure.type)
	# Spend money now (for purchased structures) or use inventory (for free structures like bases)
	var cost = Structure.get_cost(structure.type)
	if cost > 0:
		_spend_on_structure(structure.type)
	else:
		_use_inventory(structure.type)
	# Record action for undo (include structure_type for inventory restore)
	_action_history.append({"type": "placement", "grid_pos": grid_pos, "structure_type": structure.type})
	# Block targeting from responding to this same click
	targeting_manager.block_next_player_click = true

	if current_phase == TurnPhase.BASE_PLACEMENT:
		# During base placement, update status with remaining count
		_update_status(_get_phase_status_text())
		# Keep bases selected for continued placement only if more remain
		if _get_inventory_count(Structure.Type.BASE) > 0:
			placement_manager.select_structure_type(Structure.Type.BASE)
		else:
			# All bases placed - automatically end the base placement phase
			placement_manager.deselect()
			_end_base_placement_phase()
	else:
		_update_status("Placed %s at (%d, %d)" % [sname, grid_pos.x, grid_pos.y])
		# Deselect after placement so cursor returns to normal
		placement_manager.deselect()
		# Explicitly reset toolbar button states and release focus
		_reset_all_build_buttons()


func _on_placement_failed(_grid_pos: Vector2i, reason: String) -> void:
	_update_status("Cannot place: %s" % reason)


func _on_placement_selection_changed(structure_type) -> void:
	_update_button_states(structure_type)
	if structure_type != null:
		var sname = Structure.get_display_name(structure_type)
		_update_status("Selected: %s - click your grid to place" % sname)
	else:
		if not targeting_manager.selected_structure:
			_update_status("Click a cannon to select it for targeting")


func _on_targeting_structure_selected(structure: Resource) -> void:
	placement_manager.deselect()  # Clear placement when targeting
	_update_button_states(null)
	var sname = Structure.get_display_name(structure.type)
	_update_status("%s selected - click ENEMY grid to assign target" % sname)


func _on_targeting_structure_deselected() -> void:
	_update_status("Target selection cancelled")


func _on_target_assigned(structure: Resource, target_pos: Vector2i) -> void:
	var sname = Structure.get_display_name(structure.type)
	_update_status("%s targeting (%d, %d)" % [sname, target_pos.x, target_pos.y])
	# Record action for undo (prev_target is null for new assignment, handled before this call)
	# Note: We need to get prev_target BEFORE the assignment happens, so we track it differently
	# For simplicity, we'll just clear the target on undo (prev_target = null means remove)
	_action_history.append({"type": "target", "structure": structure, "prev_target": null})


func _on_player_cell_hovered(grid_pos: Vector2i) -> void:
	var structure = placement_manager.get_structure_at(grid_pos)
	_update_info_panel_from_grid(structure)

	if placement_manager.selected_type != null:
		var can_place = placement_manager.can_place_at(grid_pos)
		var status = "Can place" if can_place else "Cannot place"
		_update_status("Your island (%d, %d) - %s" % [grid_pos.x, grid_pos.y, status])
	elif targeting_manager.selected_structure:
		_update_status("Click ENEMY grid to assign target (or ESC to cancel)")
	else:
		if structure:
			var sname = Structure.get_display_name(structure.type)
			if structure.is_offensive():
				var has_target = targeting_manager.has_target(structure)
				var target_info = ""
				if has_target:
					var t = targeting_manager.get_target(structure)
					target_info = " -> (%d,%d)" % [t.x, t.y]
				_update_status("Your %s%s - click to target" % [sname, target_info])
			else:
				_update_status("Your %s" % sname)


func _on_enemy_cell_hovered(grid_pos: Vector2i) -> void:
	var structure = enemy_placement_manager.get_structure_at(grid_pos)
	_update_info_panel_from_grid(structure)

	if targeting_manager.selected_structure:
		_update_status("Click to target (%d, %d)" % [grid_pos.x, grid_pos.y])
	else:
		if structure:
			var sname = Structure.get_display_name(structure.type)
			_update_status("Enemy %s at (%d, %d)" % [sname, grid_pos.x, grid_pos.y])
		else:
			_update_status("Enemy island (%d, %d) - empty" % [grid_pos.x, grid_pos.y])


func _update_button_states(selected_type) -> void:
	btn_base.set_pressed_no_signal(selected_type == Structure.Type.BASE)
	btn_cannon.set_pressed_no_signal(selected_type == Structure.Type.HOT_DOG_CANNON)
	btn_condiment.set_pressed_no_signal(selected_type == Structure.Type.CONDIMENT_STATION)
	btn_interceptor.set_pressed_no_signal(selected_type == Structure.Type.VEGGIE_CANNON)
	btn_radar.set_pressed_no_signal(selected_type == Structure.Type.COFFEE_RADAR)
	btn_lemonade.set_pressed_no_signal(selected_type == Structure.Type.LEMONADE_STAND)
	btn_salad.set_pressed_no_signal(selected_type == Structure.Type.SALAD_BAR)
	btn_jammer.set_pressed_no_signal(selected_type == Structure.Type.RADAR_JAMMER)
	# Release focus from all buttons when nothing is selected
	if selected_type == null:
		btn_base.release_focus()
		btn_cannon.release_focus()
		btn_condiment.release_focus()
		btn_interceptor.release_focus()
		btn_radar.release_focus()
		btn_lemonade.release_focus()
		btn_salad.release_focus()
		btn_jammer.release_focus()


func _update_status(text: String) -> void:
	status_label.text = text


func _get_inventory_count(structure_type) -> int:
	return _inventory.get(structure_type, 0)


func _has_inventory(structure_type) -> bool:
	return _get_inventory_count(structure_type) > 0


func _use_inventory(structure_type) -> void:
	if _inventory.has(structure_type):
		_inventory[structure_type] -= 1
	_update_inventory_buttons()


func _restore_inventory(structure_type) -> void:
	var cost = Structure.get_cost(structure_type)
	if cost > 0:
		# Purchased structure - refund the money
		EconomyManager.refund("player", cost)
	else:
		# Free structure (like bases) - restore inventory count
		if _inventory.has(structure_type):
			_inventory[structure_type] += 1
	_update_inventory_buttons()


func _update_inventory_buttons() -> void:
	# Update button enabled state and text based on inventory/affordability
	var base_count = _get_inventory_count(Structure.Type.BASE)

	btn_base.disabled = base_count <= 0
	btn_base.text = "Base(%d)" % base_count

	# Show cost for purchasable structures - disable if can't afford (abbreviated labels)
	_update_purchasable_button(btn_cannon, Structure.Type.HOT_DOG_CANNON, "HD")
	_update_purchasable_button(btn_condiment, Structure.Type.CONDIMENT_STATION, "CS")
	_update_purchasable_button(btn_interceptor, Structure.Type.VEGGIE_CANNON, "VC")
	_update_purchasable_button(btn_radar, Structure.Type.COFFEE_RADAR, "CR")
	_update_purchasable_button(btn_lemonade, Structure.Type.LEMONADE_STAND, "LS")
	_update_purchasable_button(btn_salad, Structure.Type.SALAD_BAR, "SB")
	_update_purchasable_button(btn_jammer, Structure.Type.RADAR_JAMMER, "RJ")


func _update_purchasable_button(btn: Button, structure_type, label: String) -> void:
	var cost = Structure.get_cost(structure_type)
	btn.disabled = not EconomyManager.can_afford("player", cost)
	btn.text = "%s$%d" % [label, cost]


func _reset_all_build_buttons() -> void:
	var buttons = [btn_base, btn_cannon, btn_condiment, btn_interceptor, btn_radar, btn_lemonade, btn_salad, btn_jammer]
	for btn in buttons:
		btn.set_pressed_no_signal(false)
		btn.release_focus()


func _can_select_structure(structure_type) -> bool:
	# For free structures (like bases), check inventory
	var cost = Structure.get_cost(structure_type)
	if cost == 0:
		return _has_inventory(structure_type)
	# For purchasable structures, just check if can afford (don't spend yet)
	if EconomyManager.can_afford("player", cost):
		return true
	_update_status("Cannot afford %s ($%d needed)" % [Structure.get_display_name(structure_type), cost])
	return false


func _spend_on_structure(structure_type) -> void:
	# Actually spend money when structure is placed (not when selected)
	var cost = Structure.get_cost(structure_type)
	if cost > 0:
		EconomyManager.spend("player", cost, Structure.get_display_name(structure_type))


func _end_base_placement_phase() -> void:
	# Transition from base placement to regular game loop
	# Set up enemy structures now that player has placed bases
	_setup_enemy_structures()
	# Clear bases from inventory (already placed)
	_inventory[Structure.Type.BASE] = 0
	# Start Round 1 placement phase
	current_phase = TurnPhase.PLACEMENT
	_update_phase_ui()
	_update_inventory_buttons()
	_show_slate("ROUND %d" % GameManager.turn_number, "Placement Phase", false)


func _on_btn_end_turn_pressed() -> void:
	if not GameManager.is_planning():
		return

	# Deselect everything
	placement_manager.deselect()
	targeting_manager.deselect()
	_update_button_states(null)

	if current_phase == TurnPhase.BASE_PLACEMENT:
		_end_base_placement_phase()
	elif current_phase == TurnPhase.PLACEMENT:
		# Enemy has fixed arsenal - no purchasing
		# Transition from placement to targeting phase
		current_phase = TurnPhase.TARGETING
		_update_phase_ui()
		_show_slate("ROUND %d" % GameManager.turn_number, "Targeting Phase", false)
	elif current_phase == TurnPhase.TARGETING:
		# Transition to fight phase
		current_phase = TurnPhase.FIGHT
		_update_phase_ui()
		_show_slate("ROUND %d" % GameManager.turn_number, "Fight!", false)


func _on_execution_started() -> void:
	_update_status("Executing turn...")
	_set_planning_ui_enabled(false)
	# Hide targeting lines during execution
	targeting_manager.show_lines = false
	targeting_manager.queue_redraw()


func _on_execution_finished() -> void:
	# Clear all targets - players must reassign each turn
	targeting_manager.clear_all_targets()
	enemy_targeting_manager.clear_all_targets()

	# Process passive income and healing for player only (enemy has fixed arsenal)
	_process_turn_end_effects(placement_manager, "player")

	# Process jam countdown for both sides
	_process_jam_countdown(placement_manager)
	_process_jam_countdown(enemy_placement_manager)

	# Check for loss condition: no offensive weapons and can't afford any
	if _check_no_offense_loss():
		return  # Game over was triggered

	GameManager.end_execution()
	if GameManager.is_planning():
		# Reset to placement phase for new round
		current_phase = TurnPhase.PLACEMENT
		# Clear action history for new round
		_action_history.clear()
		_update_phase_ui()
		_set_planning_ui_enabled(true)
		# Show targeting lines again for planning phase
		targeting_manager.show_lines = true
		targeting_manager.queue_redraw()
		# Assign new enemy targets for this turn
		_assign_enemy_targets()
		# Show new round slate
		_show_slate("ROUND %d" % GameManager.turn_number, "Placement Phase", false)


func _on_projectile_intercepted(interceptor: Resource, _target_pos: Vector2i) -> void:
	var owner_str = "Your" if not _is_enemy_structure(interceptor) else "Enemy"
	_update_status("%s Pickle Interceptor caught the missile!" % owner_str)


func _on_radar_jammed(radar: Resource) -> void:
	var is_enemy = _is_enemy_structure(radar)
	var owner_str = "Enemy" if is_enemy else "Your"
	_update_status("%s Coffee Cup Radar has been jammed!" % owner_str)


func _on_structure_hit(structure: Resource, damage: int) -> void:
	var sname = Structure.get_display_name(structure.type)
	var is_enemy = _is_enemy_structure(structure)
	var owner_str = "Enemy" if is_enemy else "Your"
	_update_status("%s %s hit for %d damage! (HP: %d)" % [owner_str, sname, damage, structure.health])
	# Award money to player for dealing damage (enemy has fixed arsenal, no economy)
	if is_enemy:
		EconomyManager.earn_from_damage("player", damage)


func _on_structure_destroyed(structure: Resource) -> void:
	var sname = Structure.get_display_name(structure.type)
	var is_enemy = _is_enemy_structure(structure)
	var owner_str = "Enemy" if is_enemy else "Your"
	_update_status("%s %s destroyed!" % [owner_str, sname])

	# Fully remove the structure (view, from structures array, and grid cell)
	var pm = enemy_placement_manager if is_enemy else placement_manager
	pm.remove_structure_at(structure.grid_position)

	# Check for win/lose condition - all bases must be destroyed
	if structure.type == Structure.Type.BASE:
		if is_enemy:
			# Check if all enemy bases are destroyed
			if _count_surviving_bases(enemy_placement_manager) == 0:
				GameManager.set_winner(GameManager.Winner.PLAYER)
		else:
			# Check if all player bases are destroyed
			if _count_surviving_bases(placement_manager) == 0:
				GameManager.set_winner(GameManager.Winner.ENEMY)


func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.GAME_OVER:
			_set_planning_ui_enabled(false)
			if GameManager.winner == GameManager.Winner.PLAYER:
				_show_slate("VICTORY!", "You destroyed all enemy bases!", true)
			else:
				_show_slate("DEFEAT!", "All your bases were destroyed!", true)


func _set_planning_ui_enabled(enabled: bool) -> void:
	if not enabled:
		btn_base.disabled = true
		btn_cannon.disabled = true
		btn_condiment.disabled = true
		btn_interceptor.disabled = true
		btn_radar.disabled = true
		btn_lemonade.disabled = true
		btn_salad.disabled = true
		btn_jammer.disabled = true
	else:
		_update_inventory_buttons()
	btn_undo.disabled = not enabled
	btn_end_turn.disabled = not enabled


func _is_enemy_structure(structure: Resource) -> bool:
	return enemy_placement_manager.get_structures().has(structure)


func _count_surviving_bases(pm: PlacementManager) -> int:
	var count = 0
	for structure in pm.get_structures():
		if structure.type == Structure.Type.BASE and not structure.is_destroyed:
			count += 1
	return count


func _count_offensive_weapons(pm: PlacementManager) -> int:
	var count = 0
	for structure in pm.get_structures():
		if not structure.is_destroyed and structure.is_offensive():
			count += 1
	return count


func _get_cheapest_offensive_cost() -> int:
	# Returns the cost of the cheapest offensive weapon
	var min_cost = 999999
	for structure_type in [Structure.Type.HOT_DOG_CANNON, Structure.Type.CONDIMENT_STATION, Structure.Type.RADAR_JAMMER]:
		var cost = Structure.get_cost(structure_type)
		if cost < min_cost:
			min_cost = cost
	return min_cost


func _check_no_offense_loss() -> bool:
	# Check if player has lost: no offensive weapons and can't afford any
	var player_offense = _count_offensive_weapons(placement_manager)
	var player_money = EconomyManager.player_money
	var min_cost = _get_cheapest_offensive_cost()

	if player_offense == 0 and player_money < min_cost:
		GameManager.set_winner(GameManager.Winner.ENEMY)
		_set_planning_ui_enabled(false)
		_show_slate("DEFEAT!", "No offensive weapons and not enough money!", true)
		return true

	return false


func _process_turn_end_effects(pm: PlacementManager, side: String) -> void:
	var structures = pm.get_structures()

	# Process passive income from Lemonade Stands
	for structure in structures:
		if structure.is_destroyed:
			continue
		if structure.income_per_turn > 0:
			EconomyManager.add_passive_income(side, structure.income_per_turn)

	# Process healing from Salad Bars
	for structure in structures:
		if structure.is_destroyed:
			continue
		if structure.heal_radius > 0 and structure.heal_amount > 0:
			_apply_area_healing(structure, pm)


func _process_jam_countdown(pm: PlacementManager) -> void:
	# Decrement jam timers on radars and clear jam when expired
	for structure in pm.get_structures():
		if structure.is_destroyed or not structure.is_jammed:
			continue
		if structure.jam_turns_remaining > 0:
			structure.jam_turns_remaining -= 1
			if structure.jam_turns_remaining <= 0:
				structure.is_jammed = false
				var sname = Structure.get_display_name(structure.type)
				var is_enemy = _is_enemy_structure(structure)
				var owner_str = "Enemy" if is_enemy else "Your"
				_update_status("%s %s is no longer jammed!" % [owner_str, sname])


func _apply_area_healing(healer: Resource, pm: PlacementManager) -> void:
	var radius = healer.heal_radius
	var amount = healer.heal_amount
	var center = healer.grid_position

	for structure in pm.get_structures():
		if structure.is_destroyed or structure == healer:
			continue
		# Check if structure is within heal radius
		var dx = abs(structure.grid_position.x - center.x)
		var dy = abs(structure.grid_position.y - center.y)
		if dx <= radius and dy <= radius:
			var healed = structure.heal(amount)
			if healed > 0:
				var sname = Structure.get_display_name(structure.type)
				# Note: Could emit a signal here for UI feedback


func _on_money_changed(_side: String, _new_amount: int) -> void:
	_update_money_display()


func _update_money_display() -> void:
	player_money_label.text = "$%d" % EconomyManager.player_money
	enemy_money_label.text = "$%d" % EconomyManager.enemy_money


func _on_fog_reveal_path(from_grid: Vector2i, to_grid: Vector2i, is_player_projectile: bool) -> void:
	# Player projectiles reveal the enemy grid
	if is_player_projectile and enemy_grid_view.fog_manager:
		enemy_grid_view.fog_manager.reveal_path(from_grid, to_grid)
		# Also reveal a small area around the impact point
		enemy_grid_view.fog_manager.reveal_area(to_grid, 1)


func _show_slate(title: String, subtitle: String, is_game_over: bool) -> void:
	slate_title.text = title
	slate_subtitle.text = subtitle
	btn_slate_continue.visible = false  # No continue button - auto-dismiss
	btn_slate_reset.visible = is_game_over
	slate.visible = true

	if not is_game_over:
		# Auto-dismiss after 2 seconds for round announcements
		await get_tree().create_timer(2.0).timeout
		_hide_slate()
		if current_phase == TurnPhase.FIGHT:
			# Start execution after Fight slate auto-dismisses
			GameManager.start_execution()
			execution_manager.execute_turn()
		else:
			_update_status(_get_phase_status_text())


func _hide_slate() -> void:
	slate.visible = false


func _on_slate_continue_pressed() -> void:
	_hide_slate()
	if current_phase == TurnPhase.FIGHT:
		# Start execution after Fight slate is dismissed
		GameManager.start_execution()
		execution_manager.execute_turn()
	else:
		_update_status(_get_phase_status_text())


func _on_slate_reset_pressed() -> void:
	# Return to intro screen so player can select new island size
	get_tree().change_scene_to_file("res://scenes/main/intro.tscn")


func _update_phase_ui() -> void:
	# Update round label and button text based on current phase
	var phase_name: String
	var hide_structure_buttons = false
	var hide_end_turn = false
	match current_phase:
		TurnPhase.BASE_PLACEMENT:
			phase_name = "Base Placement"
			hide_structure_buttons = true
			hide_end_turn = true  # Auto-ends when last base is placed
		TurnPhase.PLACEMENT:
			phase_name = "Placement"
			btn_end_turn.text = "End Placement"
			btn_end_turn.disabled = false
		TurnPhase.TARGETING:
			phase_name = "Targeting"
			btn_end_turn.text = "End Targeting"
			btn_end_turn.disabled = false
		TurnPhase.FIGHT:
			phase_name = "Fight!"
			btn_end_turn.text = "Fighting..."
			btn_end_turn.disabled = true

	# Hide structure buttons during base placement (but keep Undo visible)
	btn_base.visible = not hide_structure_buttons
	sep1.visible = not hide_structure_buttons
	btn_cannon.visible = not hide_structure_buttons
	btn_condiment.visible = not hide_structure_buttons
	btn_interceptor.visible = not hide_structure_buttons
	btn_radar.visible = not hide_structure_buttons
	btn_lemonade.visible = not hide_structure_buttons
	btn_salad.visible = not hide_structure_buttons
	btn_jammer.visible = not hide_structure_buttons
	sep2.visible = not hide_structure_buttons

	# Hide end turn button during base placement (auto-ends when done)
	btn_end_turn.visible = not hide_end_turn

	if current_phase == TurnPhase.BASE_PLACEMENT:
		round_label.text = "Base Placement Phase"
	else:
		round_label.text = "Round %d - %s" % [GameManager.turn_number, phase_name]
	_update_status(_get_phase_status_text())
	_update_phase_button_states()


func _get_phase_status_text() -> String:
	match current_phase:
		TurnPhase.BASE_PLACEMENT:
			var bases_remaining = _get_inventory_count(Structure.Type.BASE)
			if bases_remaining > 0:
				return "Place your bases. %d remaining." % bases_remaining
			else:
				return "All bases placed!"
		TurnPhase.PLACEMENT:
			return "Place your structures on your island"
		TurnPhase.TARGETING:
			return "Click your cannons, then click enemy grid to assign targets"
		TurnPhase.FIGHT:
			return "Executing turn..."
	return ""


func _update_phase_button_states() -> void:
	# During targeting or fight phase, disable placement buttons
	if current_phase == TurnPhase.TARGETING or current_phase == TurnPhase.FIGHT:
		btn_base.disabled = true
		btn_cannon.disabled = true
		btn_condiment.disabled = true
		btn_interceptor.disabled = true
		btn_radar.disabled = true
		btn_lemonade.disabled = true
		btn_salad.disabled = true
		btn_jammer.disabled = true
	else:
		_update_inventory_buttons()
		# Clear any targeting selection when entering placement phase
		targeting_manager.deselect()


func _on_player_grid_clicked(grid_pos: Vector2i) -> void:
	# Handle clicks based on current phase
	match current_phase:
		TurnPhase.BASE_PLACEMENT:
			# Check inventory before allowing base placement
			if _get_inventory_count(Structure.Type.BASE) <= 0:
				_update_status("All bases placed!")
				return
			# Place base if cell is valid
			if placement_manager.can_place_at(grid_pos):
				placement_manager.place_structure(Structure.Type.BASE, grid_pos)
				if placement_manager.structure_views.has(grid_pos):
					placement_manager.structure_views[grid_pos].flash_placed()
		TurnPhase.PLACEMENT:
			# Check if player can place the selected structure
			if placement_manager.selected_type != null:
				var structure_type = placement_manager.selected_type
				var cost = Structure.get_cost(structure_type)
				# For free structures, check inventory; for purchased, check affordability
				if cost == 0:
					if not _has_inventory(structure_type):
						_update_status("No more of this structure available")
						return
				else:
					if not EconomyManager.can_afford("player", cost):
						_update_status("Cannot afford %s ($%d needed)" % [Structure.get_display_name(structure_type), cost])
						return
				if placement_manager.can_place_at(grid_pos):
					placement_manager.place_structure(structure_type, grid_pos)
					if placement_manager.structure_views.has(grid_pos):
						placement_manager.structure_views[grid_pos].flash_placed()
		TurnPhase.TARGETING:
			# Targeting: select offensive structures
			var structure = placement_manager.get_structure_at(grid_pos)
			if structure and structure.is_offensive():
				targeting_manager.select_structure(structure)
			else:
				targeting_manager.deselect()
		TurnPhase.FIGHT:
			# No interactions during fight
			pass


func _on_targeting_enemy_click(grid_pos: Vector2i) -> void:
	# Only allow targeting interactions during targeting phase
	if current_phase != TurnPhase.TARGETING:
		return
	if targeting_manager.selected_structure:
		targeting_manager.assign_target(targeting_manager.selected_structure, grid_pos)
		targeting_manager.deselect()


# --- Dev Toolbar ---

func _on_btn_toggle_fog_pressed() -> void:
	if enemy_grid_view.fog_manager:
		var is_enabled = enemy_grid_view.fog_manager.is_enabled
		if is_enabled:
			enemy_grid_view.fog_manager.disable()
			btn_toggle_fog.text = "Fog: OFF"
		else:
			enemy_grid_view.fog_manager.enable()
			btn_toggle_fog.text = "Fog: ON"
		enemy_grid_view.redraw_fog_overlay()


func _on_btn_restart_pressed() -> void:
	# Return to intro/title screen
	get_tree().change_scene_to_file("res://scenes/main/intro.tscn")


# --- Info Panel Hover System ---

# Structure descriptions for info panel
const STRUCTURE_INFO: Dictionary = {
	Structure.Type.BASE: {
		"name": "Base",
		"desc": "Your headquarters. Protect it! Lose all bases and you lose the game."
	},
	Structure.Type.HOT_DOG_CANNON: {
		"name": "Hot Dog Cannon",
		"desc": "Fires hot dogs at enemy structures. Basic offensive weapon."
	},
	Structure.Type.CONDIMENT_CANNON: {
		"name": "Condiment Cannon",
		"desc": "Fires condiments in a splash pattern. Area damage."
	},
	Structure.Type.CONDIMENT_STATION: {
		"name": "Condiment Station",
		"desc": "Fires condiments with area damage. More powerful than cannon."
	},
	Structure.Type.PICKLE_INTERCEPTOR: {
		"name": "Pickle Interceptor",
		"desc": "Defensive. Can intercept incoming projectiles when radar is active."
	},
	Structure.Type.COFFEE_RADAR: {
		"name": "Coffee Cup Radar",
		"desc": "Detects incoming missiles in a 20-block radius. Required for interception."
	},
	Structure.Type.VEGGIE_CANNON: {
		"name": "Veggie Cannon",
		"desc": "Defensive interceptor. Shoots down enemy projectiles within radar range."
	},
	Structure.Type.LEMONADE_STAND: {
		"name": "Lemonade Stand",
		"desc": "Generates $5 passive income each round. Economic structure."
	},
	Structure.Type.SALAD_BAR: {
		"name": "Salad Bar",
		"desc": "Heals nearby structures by 1 HP each round. Support structure."
	},
	Structure.Type.RADAR_JAMMER: {
		"name": "Radar Jammer",
		"desc": "Jams enemy radars within 5 blocks of impact. Disables their defense."
	},
}

func _setup_button_hover_signals() -> void:
	# Map buttons to their structure types
	var button_map: Dictionary = {
		btn_base: Structure.Type.BASE,
		btn_cannon: Structure.Type.HOT_DOG_CANNON,
		btn_condiment: Structure.Type.CONDIMENT_STATION,
		btn_interceptor: Structure.Type.VEGGIE_CANNON,
		btn_radar: Structure.Type.COFFEE_RADAR,
		btn_lemonade: Structure.Type.LEMONADE_STAND,
		btn_salad: Structure.Type.SALAD_BAR,
		btn_jammer: Structure.Type.RADAR_JAMMER,
	}

	for btn in button_map.keys():
		var structure_type = button_map[btn]
		btn.mouse_entered.connect(_on_toolbar_button_hover.bind(structure_type))
		btn.mouse_exited.connect(_on_toolbar_button_unhover)

	# Undo button has special info
	btn_undo.mouse_entered.connect(_on_undo_button_hover)
	btn_undo.mouse_exited.connect(_on_toolbar_button_unhover)


func _on_toolbar_button_hover(structure_type) -> void:
	if STRUCTURE_INFO.has(structure_type):
		var info = STRUCTURE_INFO[structure_type]
		info_title.text = info.name
		info_description.text = info.desc


func _on_undo_button_hover() -> void:
	info_title.text = "Undo"
	info_description.text = "Undo your last placement or target assignment."


func _on_toolbar_button_unhover() -> void:
	info_title.text = ""
	info_description.text = ""


func _update_info_panel_from_grid(structure: Resource) -> void:
	if structure and STRUCTURE_INFO.has(structure.type):
		var info = STRUCTURE_INFO[structure.type]
		var health_str = " (HP: %d)" % structure.health if not structure.is_destroyed else " (Destroyed)"
		info_title.text = info.name + health_str
		info_description.text = info.desc
	else:
		info_title.text = ""
		info_description.text = ""
