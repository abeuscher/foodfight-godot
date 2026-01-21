class_name ExecutionManager
extends Node2D
## Manages turn execution - fires projectiles, resolves hits, handles pacing.

const Structure = preload("res://scripts/resources/structure.gd")
const PlacementManager = preload("res://scripts/components/placement_manager.gd")
const TargetingManager = preload("res://scripts/components/targeting_manager.gd")

signal execution_started()
signal execution_finished()
signal projectile_fired(from_pos: Vector2, to_pos: Vector2, is_player: bool)
signal projectile_intercepted(interceptor: Resource, target_pos: Vector2i)
signal structure_hit(structure: Resource, damage: int)
signal structure_destroyed(structure: Resource)
signal radar_jammed(radar: Resource)
signal fog_reveal_path(from_grid: Vector2i, to_grid: Vector2i, is_player_projectile: bool)

var player_placement: PlacementManager
var enemy_placement: PlacementManager
var player_targeting: TargetingManager
var enemy_targeting: TargetingManager
var player_grid_view: Control
var enemy_grid_view: Control

var _action_delay: float = 0.5  # Delay between actions in seconds
var _projectile_speed: float = 400.0  # Pixels per second
var _is_executing: bool = false
var _active_projectiles: Array = []

# Projectile visual settings
var _player_projectile_color: Color = Color(0.2, 0.8, 0.2, 1.0)  # Green for player
var _enemy_projectile_color: Color = Color(0.8, 0.2, 0.2, 1.0)   # Red for enemy

# Enemy's fog manager (tracks what enemy can see on player grid - no visual)
var enemy_fog_manager = null  # Set by game.gd


func initialize(
	p_placement: PlacementManager,
	e_placement: PlacementManager,
	p_targeting: TargetingManager,
	e_targeting: TargetingManager,
	p_grid_view: Control,
	e_grid_view: Control
) -> void:
	player_placement = p_placement
	enemy_placement = e_placement
	player_targeting = p_targeting
	enemy_targeting = e_targeting
	player_grid_view = p_grid_view
	enemy_grid_view = e_grid_view


func is_executing() -> bool:
	return _is_executing


func execute_turn() -> void:
	if _is_executing:
		return

	_is_executing = true
	execution_started.emit()

	# Build execution queue from both sides
	var queue = _build_execution_queue()

	# Process queue sequentially
	for action in queue:
		if not _is_executing:
			break
		await _execute_action(action)
		await get_tree().create_timer(_action_delay).timeout

	_is_executing = false
	execution_finished.emit()


func _build_execution_queue() -> Array:
	var queue: Array = []

	# Collect player offensive structures with targets
	var player_assignments = player_targeting.get_all_assignments()
	for structure in player_assignments:
		if structure.is_destroyed:
			continue
		if not structure.is_offensive():
			continue
		queue.append({
			"structure": structure,
			"target_pos": player_assignments[structure],
			"is_player": true,
			"source_placement": player_placement,
			"target_placement": enemy_placement,
			"source_grid_view": player_grid_view,
			"target_grid_view": enemy_grid_view
		})

	# Collect enemy offensive structures with targets
	if enemy_targeting:
		var enemy_assignments = enemy_targeting.get_all_assignments()
		for structure in enemy_assignments:
			if structure.is_destroyed:
				continue
			if not structure.is_offensive():
				continue
			queue.append({
				"structure": structure,
				"target_pos": enemy_assignments[structure],
				"is_player": false,
				"source_placement": enemy_placement,
				"target_placement": player_placement,
				"source_grid_view": enemy_grid_view,
				"target_grid_view": player_grid_view
			})

	# Sort by attack priority (higher priority first)
	queue.sort_custom(func(a, b):
		return a.structure.attack_priority > b.structure.attack_priority
	)

	return queue


func _execute_action(action: Dictionary) -> void:
	var structure: Resource = action.structure
	var target_pos: Vector2i = action.target_pos
	var target_placement: PlacementManager = action.target_placement
	var source_grid_view: Control = action.source_grid_view
	var target_grid_view: Control = action.target_grid_view
	var is_player: bool = action.is_player

	# Skip if structure was destroyed during execution
	if structure.is_destroyed:
		return

	# Calculate screen positions
	var from_local = source_grid_view.grid_to_screen_center(structure.grid_position)
	var from_pos = source_grid_view.global_position + from_local

	var to_local = target_grid_view.grid_to_screen_center(target_pos)
	var to_pos = target_grid_view.global_position + to_local

	# Check for interception (radar jammers cannot be intercepted)
	var interceptor = null
	if structure.jam_radius <= 0:
		interceptor = _find_interceptor(target_placement, target_pos)
	if interceptor:
		# Calculate intercept position (midpoint between missile path and interceptor)
		var interceptor_local = target_grid_view.grid_to_screen_center(interceptor.grid_position)
		var interceptor_pos = target_grid_view.global_position + interceptor_local

		# Intercept point is past the canal (70%) - interceptors don't fire until missile enters enemy territory
		var intercept_point = from_pos.lerp(to_pos, 0.7)

		# Roll for intercept success (50% base + 5% per active radar)
		var intercept_chance = _calculate_intercept_chance(target_placement)
		var intercept_success = randf() < intercept_chance

		# Animate both projectiles - attack missile and interceptor missile firing to meet
		projectile_fired.emit(from_pos, to_pos, is_player)
		await _animate_interception(from_pos, to_pos, interceptor_pos, intercept_point, is_player, intercept_success)

		if intercept_success:
			projectile_intercepted.emit(interceptor, target_pos)
			return
		# If intercept failed, fall through to resolve hit

	# No interception or intercept failed - fire/animate projectile normally
	if not interceptor:
		projectile_fired.emit(from_pos, to_pos, is_player)
		await _animate_projectile(from_pos, to_pos, is_player)

	# Resolve hit - check for jammer, area attack, or single target
	if structure.jam_radius > 0:
		# Jammer attack - jam radars within radius of impact point
		_resolve_jam_attack(structure, target_pos, target_placement)
	elif structure.area_attack_radius > 0:
		# Area attack - damage all structures in radius
		_resolve_area_attack(structure, target_pos, target_placement)
	else:
		# Single target attack
		var target_structure = target_placement.get_structure_at(target_pos)
		if target_structure and not target_structure.is_destroyed:
			var damage = structure.attack_damage
			var destroyed = target_structure.take_damage(damage)
			structure_hit.emit(target_structure, damage)

			if destroyed:
				structure_destroyed.emit(target_structure)


func _resolve_area_attack(attacker: Resource, center: Vector2i, target_placement: PlacementManager) -> void:
	var radius = attacker.area_attack_radius
	var damage = attacker.attack_damage

	# Check all positions in the area
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var check_pos = Vector2i(center.x + dx, center.y + dy)
			var target_structure = target_placement.get_structure_at(check_pos)
			if target_structure and not target_structure.is_destroyed:
				var destroyed = target_structure.take_damage(damage)
				structure_hit.emit(target_structure, damage)
				if destroyed:
					structure_destroyed.emit(target_structure)


const JAM_DURATION: int = 3  # Jamming lasts 3 turns

func _resolve_jam_attack(attacker: Resource, center: Vector2i, target_placement: PlacementManager) -> void:
	# Jam all radars within jam_radius of impact point for JAM_DURATION turns
	var radius = attacker.jam_radius

	for structure in target_placement.get_structures():
		if structure.is_destroyed or structure.radar_range <= 0:
			continue
		# Check if radar is within jam radius
		var dx = abs(center.x - structure.grid_position.x)
		var dy = abs(center.y - structure.grid_position.y)
		if dx <= radius and dy <= radius:
			structure.is_jammed = true
			structure.jam_turns_remaining = JAM_DURATION
			radar_jammed.emit(structure)


const BASE_INTERCEPT_CHANCE: float = 0.5  # 50% base chance to intercept
const RADAR_INTERCEPT_BONUS: float = 0.05  # +5% per active radar


func _calculate_intercept_chance(defending_placement: PlacementManager) -> float:
	# Base intercept chance is 50%, +5% per active (non-jammed) radar
	var radar_count = 0
	for structure in defending_placement.get_structures():
		if structure.radar_range > 0 and not structure.is_destroyed and not structure.is_jammed:
			radar_count += 1

	return BASE_INTERCEPT_CHANCE + (radar_count * RADAR_INTERCEPT_BONUS)


func _find_interceptor(defending_placement: PlacementManager, target_pos: Vector2i) -> Resource:
	# Find an interceptor that can intercept a projectile heading to target_pos
	# KEY RULES:
	# - Defensive towers do NOTHING without radar
	# - Radar has 20-block detection radius
	# - Silos within radar's range can intercept ANY missile within radar's detection zone

	# First, find all active (non-jammed) radar structures
	var radars: Array = []
	for structure in defending_placement.get_structures():
		if structure.radar_range > 0 and not structure.is_destroyed and not structure.is_jammed:
			radars.append(structure)

	# If no radars, no interception possible
	if radars.is_empty():
		return null

	# Check if missile is within any radar's detection zone (20 blocks)
	var detecting_radar: Resource = null
	for radar in radars:
		var dx = abs(target_pos.x - radar.grid_position.x)
		var dy = abs(target_pos.y - radar.grid_position.y)
		if dx <= radar.radar_range and dy <= radar.radar_range:
			detecting_radar = radar
			break

	# If no radar can see the missile, no interception
	if not detecting_radar:
		return null

	# Find a defensive tower within the detecting radar's range
	for structure in defending_placement.get_structures():
		if structure.is_destroyed or structure.interception_range <= 0:
			continue

		# Check if this tower is within the detecting radar's range
		var dist_to_radar = max(
			abs(structure.grid_position.x - detecting_radar.grid_position.x),
			abs(structure.grid_position.y - detecting_radar.grid_position.y)
		)
		if dist_to_radar <= detecting_radar.radar_range:
			# This tower can attempt interception
			return structure

	return null


func _animate_projectile(from: Vector2, to: Vector2, is_player: bool) -> void:
	var projectile = _ProjectileVisual.new()
	projectile.color = _player_projectile_color if is_player else _enemy_projectile_color
	projectile.start_pos = from
	projectile.end_pos = to
	projectile.speed = _projectile_speed
	# Set up real-time fog reveal for player projectiles on enemy grid
	if is_player and enemy_grid_view.fog_manager:
		projectile.fog_grid_view = enemy_grid_view
		projectile.fog_reveal_enabled = true
	# Set up silent fog reveal for enemy projectiles (enemy's view of player grid)
	elif not is_player and enemy_fog_manager:
		projectile.silent_fog_manager = enemy_fog_manager
		projectile.silent_fog_grid_view = player_grid_view
		projectile.silent_fog_reveal_enabled = true
	add_child(projectile)
	_active_projectiles.append(projectile)

	await projectile.finished

	_active_projectiles.erase(projectile)
	projectile.queue_free()


func _animate_projectile_intercepted(from: Vector2, to: Vector2, is_player: bool) -> void:
	var projectile = _ProjectileVisual.new()
	projectile.color = _player_projectile_color if is_player else _enemy_projectile_color
	projectile.start_pos = from
	projectile.end_pos = to
	projectile.speed = _projectile_speed
	projectile.show_intercept_x = true  # Will show red X at end
	# Set up real-time fog reveal for player projectiles on enemy grid
	if is_player and enemy_grid_view.fog_manager:
		projectile.fog_grid_view = enemy_grid_view
		projectile.fog_reveal_enabled = true
	# Set up silent fog reveal for enemy projectiles (enemy's view of player grid)
	elif not is_player and enemy_fog_manager:
		projectile.silent_fog_manager = enemy_fog_manager
		projectile.silent_fog_grid_view = player_grid_view
		projectile.silent_fog_reveal_enabled = true
	add_child(projectile)
	_active_projectiles.append(projectile)

	await projectile.finished

	# Keep the X visible briefly
	await get_tree().create_timer(0.4).timeout

	_active_projectiles.erase(projectile)
	projectile.queue_free()


func _animate_interception(attack_from: Vector2, attack_to: Vector2, interceptor_pos: Vector2, intercept_point: Vector2, is_player: bool, success: bool) -> void:
	# Animate both projectiles - attack missile and interceptor missile meeting
	var interceptor_color = Color(0.2, 0.9, 0.2, 1.0)  # Bright green for interceptor

	# Create attack missile
	var attack_projectile = _ProjectileVisual.new()
	attack_projectile.color = _player_projectile_color if is_player else _enemy_projectile_color
	attack_projectile.start_pos = attack_from
	attack_projectile.end_pos = intercept_point if success else attack_to
	attack_projectile.speed = _projectile_speed
	# Set up fog reveal for attack missile
	if is_player and enemy_grid_view.fog_manager:
		attack_projectile.fog_grid_view = enemy_grid_view
		attack_projectile.fog_reveal_enabled = true
	elif not is_player and enemy_fog_manager:
		attack_projectile.silent_fog_manager = enemy_fog_manager
		attack_projectile.silent_fog_grid_view = player_grid_view
		attack_projectile.silent_fog_reveal_enabled = true
	add_child(attack_projectile)
	_active_projectiles.append(attack_projectile)

	# Create interceptor missile (fires from silo toward intercept point)
	var intercept_projectile = _ProjectileVisual.new()
	intercept_projectile.color = interceptor_color
	intercept_projectile.start_pos = interceptor_pos
	intercept_projectile.end_pos = intercept_point
	intercept_projectile.speed = _projectile_speed * 1.2  # Slightly faster
	add_child(intercept_projectile)
	_active_projectiles.append(intercept_projectile)

	# Wait for both to reach intercept point
	await intercept_projectile.finished

	if success:
		# Show explosion at intercept point
		var explosion = _ExplosionVisual.new()
		explosion.position = intercept_point - global_position
		explosion.success = true
		add_child(explosion)
		await explosion.finished
		explosion.queue_free()
	else:
		# Show failed intercept (miss indicator)
		var miss = _ExplosionVisual.new()
		miss.position = intercept_point - global_position
		miss.success = false
		add_child(miss)

		# Wait for attack missile to continue to target
		await attack_projectile.finished

		miss.queue_free()

	# Cleanup
	_active_projectiles.erase(attack_projectile)
	_active_projectiles.erase(intercept_projectile)
	attack_projectile.queue_free()
	intercept_projectile.queue_free()


func _draw() -> void:
	# Projectiles draw themselves
	pass


# Inner class for explosion/miss visual
class _ExplosionVisual extends Node2D:
	signal finished

	var success: bool = true
	var _timer: float = 0.0
	var _duration: float = 0.4

	func _process(delta: float) -> void:
		_timer += delta
		if _timer >= _duration:
			finished.emit()
			set_process(false)
		queue_redraw()

	func _draw() -> void:
		var t = _timer / _duration
		if success:
			# Green explosion burst
			var radius = 20.0 * (1.0 + t)
			var alpha = 1.0 - t
			draw_circle(Vector2.ZERO, radius, Color(0.2, 1.0, 0.2, alpha))
			draw_circle(Vector2.ZERO, radius * 0.6, Color(1.0, 1.0, 0.5, alpha))
		else:
			# Red X for miss
			var x_size = 15.0
			var alpha = 1.0 - t * 0.5
			var x_color = Color(1.0, 0.3, 0.3, alpha)
			draw_line(Vector2(-x_size, -x_size), Vector2(x_size, x_size), x_color, 3.0)
			draw_line(Vector2(x_size, -x_size), Vector2(-x_size, x_size), x_color, 3.0)


# Inner class for projectile visual
class _ProjectileVisual extends Node2D:
	signal finished

	var color: Color = Color.WHITE
	var start_pos: Vector2
	var end_pos: Vector2
	var speed: float = 400.0
	var show_intercept_x: bool = false  # Show red X when intercepted
	var fog_grid_view: Control = null  # For real-time fog reveal (visual)
	var fog_reveal_enabled: bool = false
	# Silent fog reveal (enemy's internal tracking, no visual update)
	var silent_fog_manager = null
	var silent_fog_grid_view: Control = null  # For position calculation only
	var silent_fog_reveal_enabled: bool = false
	var _progress: float = 0.0
	var _total_distance: float = 0.0
	var _is_finished: bool = false
	var _last_revealed_cell: Vector2i = Vector2i(-999, -999)
	var _last_silent_revealed_cell: Vector2i = Vector2i(-999, -999)

	func _ready() -> void:
		_total_distance = start_pos.distance_to(end_pos)
		if _total_distance < 1.0:
			_is_finished = true
			finished.emit()
			return

	func _process(delta: float) -> void:
		if _is_finished:
			return
		_progress += speed * delta

		# Real-time fog reveal (visual - for player projectiles)
		if fog_reveal_enabled and fog_grid_view and fog_grid_view.fog_manager:
			_reveal_fog_at_current_position()

		# Silent fog reveal (enemy's internal tracking)
		if silent_fog_reveal_enabled and silent_fog_manager and silent_fog_grid_view:
			_reveal_silent_fog_at_current_position()

		if _progress >= _total_distance:
			_is_finished = true
			finished.emit()
		queue_redraw()

	func _reveal_fog_at_current_position() -> void:
		var t = _progress / _total_distance if _total_distance > 0 else 1.0
		t = min(t, 1.0)
		var current_screen_pos = start_pos.lerp(end_pos, t)

		# Convert screen position to grid position on the fog grid
		var local_pos = current_screen_pos - fog_grid_view.global_position
		var cell_size = fog_grid_view.cell_size
		if cell_size.x > 0 and cell_size.y > 0:
			var grid_pos = Vector2i(int(local_pos.x / cell_size.x), int(local_pos.y / cell_size.y))
			# Only reveal if this is a new cell
			if grid_pos != _last_revealed_cell:
				_last_revealed_cell = grid_pos
				# Reveal a 3-wide trail (radius 1 around the cell)
				fog_grid_view.fog_manager.reveal_area(grid_pos, 1)
				fog_grid_view.redraw_fog_overlay()

	func _reveal_silent_fog_at_current_position() -> void:
		# Silent fog reveal for enemy's internal tracking (no visual update)
		var t = _progress / _total_distance if _total_distance > 0 else 1.0
		t = min(t, 1.0)
		var current_screen_pos = start_pos.lerp(end_pos, t)

		# Convert screen position to grid position using the target grid view
		var local_pos = current_screen_pos - silent_fog_grid_view.global_position
		var cell_size = silent_fog_grid_view.cell_size
		if cell_size.x > 0 and cell_size.y > 0:
			var grid_pos = Vector2i(int(local_pos.x / cell_size.x), int(local_pos.y / cell_size.y))
			# Only reveal if this is a new cell
			if grid_pos != _last_silent_revealed_cell:
				_last_silent_revealed_cell = grid_pos
				# Reveal a 3-wide trail (radius 1 around the cell)
				silent_fog_manager.reveal_area(grid_pos, 1)

	func _draw() -> void:
		var t = _progress / _total_distance if _total_distance > 0 else 1.0
		t = min(t, 1.0)
		var current_pos = start_pos.lerp(end_pos, t)
		# Draw relative to parent (ExecutionManager), so convert to local coords
		var local_pos = current_pos - global_position

		if _is_finished and show_intercept_x:
			# Draw red X at intercept point
			var x_size = 12.0
			var x_color = Color(1.0, 0.2, 0.2, 1.0)
			draw_line(local_pos + Vector2(-x_size, -x_size), local_pos + Vector2(x_size, x_size), x_color, 4.0)
			draw_line(local_pos + Vector2(x_size, -x_size), local_pos + Vector2(-x_size, x_size), x_color, 4.0)
		else:
			# Draw projectile circle
			draw_circle(local_pos, 8.0, color)
			# Draw trail
			var trail_length = min(_progress, 30.0)
			var trail_start_t = max(0, (_progress - trail_length) / _total_distance)
			var trail_start = start_pos.lerp(end_pos, trail_start_t) - global_position
			draw_line(trail_start, local_pos, color.darkened(0.3), 4.0)
