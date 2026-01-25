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
signal transport_launched(transport: Resource, is_player: bool)
signal transport_intercepted(transport: Resource)
signal transport_landed(transport: Resource, landing_pos: Vector2i)
signal ground_unit_deployed(unit: Resource, grid_pos: Vector2i)
signal ground_unit_moved(unit: Resource, from_pos: Vector2i, to_pos: Vector2i)
signal ground_unit_attacked(attacker: Resource, target: Resource, damage: int)
signal ground_unit_destroyed(unit: Resource)
signal structure_attacked_by_ground(structure: Resource, attacker: Resource, damage: int)
signal transport_returned(transport: Resource, units_returned: int)

const GroundUnit = preload("res://scripts/resources/ground_unit.gd")

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

# Ground combat tracking
var _player_deployed_units: Array = []  # Ground units player deployed on enemy island
var _enemy_deployed_units: Array = []   # Ground units enemy deployed on player island

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

	# Phase 1: Missiles fire and resolve (existing system)
	var queue = _build_execution_queue()
	for action in queue:
		if not _is_executing:
			break
		await _execute_action(action)
		await get_tree().create_timer(_action_delay).timeout

	# Phase 2: Transports travel (can be intercepted)
	await _execute_transport_phase()

	# Phase 3: Ground combat (deployed units act)
	await _execute_ground_combat_phase()

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

	# Show impact area visualization
	var impact_radius = structure.area_attack_radius if structure.area_attack_radius > 0 else (1 if structure.jam_radius > 0 else 0)
	if impact_radius > 0:
		await _show_impact_area(to_pos, target_grid_view.cell_size, impact_radius)

	# Resolve hit - check for jammer, area attack, or single target
	if structure.jam_radius > 0:
		# Jammer attack - jam radars within radius of impact point
		_resolve_jam_attack(structure, target_pos, target_placement)
	elif structure.area_attack_radius > 0:
		# Area attack - damage all structures in radius
		_resolve_area_attack(structure, target_pos, target_placement)
	else:
		# Single target attack - still show single cell impact
		if impact_radius == 0:
			await _show_impact_area(to_pos, target_grid_view.cell_size, 0)
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
	var jam_radius = attacker.jam_radius

	for structure in target_placement.get_structures():
		if structure.is_destroyed or structure.radar_range <= 0:
			continue
		# Check if radar is within jam radius
		var dx = abs(center.x - structure.grid_position.x)
		var dy = abs(center.y - structure.grid_position.y)
		if dx <= jam_radius and dy <= jam_radius:
			structure.is_jammed = true
			structure.jam_turns_remaining = JAM_DURATION
			radar_jammed.emit(structure)

	# Radar jammer also does 1 damage in 3x3 area (area_attack_radius = 1)
	var damage_radius = 1  # 3x3 area
	for dx in range(-damage_radius, damage_radius + 1):
		for dy in range(-damage_radius, damage_radius + 1):
			var check_pos = Vector2i(center.x + dx, center.y + dy)
			var target_structure = target_placement.get_structure_at(check_pos)
			if target_structure and not target_structure.is_destroyed:
				var destroyed = target_structure.take_damage(1)
				structure_hit.emit(target_structure, 1)
				if destroyed:
					structure_destroyed.emit(target_structure)


const BASE_INTERCEPT_CHANCE: float = 0.5  # 50% base chance to intercept
const RADAR_INTERCEPT_BONUS: float = 0.05  # +5% per active radar
const TRANSPORT_INTERCEPT_CHANCE: float = 0.1  # 10% chance to intercept transports (they're harder to hit)


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


func _show_impact_area(screen_pos: Vector2, cell_size: Vector2, radius: int) -> void:
	var impact = _ImpactAreaVisual.new()
	impact.center_pos = screen_pos
	impact.cell_size = cell_size
	impact.radius = radius
	add_child(impact)
	await impact.finished
	impact.queue_free()


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


const CANAL_CROSS_POINT: float = 0.55  # Interceptors don't fire until missile is 55% across (past canal)

func _animate_interception(attack_from: Vector2, attack_to: Vector2, interceptor_pos: Vector2, intercept_point: Vector2, is_player: bool, success: bool) -> void:
	# Animate interception - interceptor only fires AFTER attack missile crosses canal
	var interceptor_color = Color(0.2, 0.9, 0.2, 1.0)  # Bright green for interceptor

	# Phase 1: Attack missile travels to canal crossing point
	var canal_point = attack_from.lerp(attack_to, CANAL_CROSS_POINT)
	var attack_phase1 = _ProjectileVisual.new()
	attack_phase1.color = _player_projectile_color if is_player else _enemy_projectile_color
	attack_phase1.start_pos = attack_from
	attack_phase1.end_pos = canal_point
	attack_phase1.speed = _projectile_speed
	# Set up fog reveal for attack missile
	if is_player and enemy_grid_view.fog_manager:
		attack_phase1.fog_grid_view = enemy_grid_view
		attack_phase1.fog_reveal_enabled = true
	elif not is_player and enemy_fog_manager:
		attack_phase1.silent_fog_manager = enemy_fog_manager
		attack_phase1.silent_fog_grid_view = player_grid_view
		attack_phase1.silent_fog_reveal_enabled = true
	add_child(attack_phase1)
	_active_projectiles.append(attack_phase1)

	# Wait for attack missile to cross the canal
	await attack_phase1.finished
	_active_projectiles.erase(attack_phase1)
	attack_phase1.queue_free()

	# Phase 2: Now interceptor fires AND attack continues simultaneously
	var attack_phase2 = _ProjectileVisual.new()
	attack_phase2.color = _player_projectile_color if is_player else _enemy_projectile_color
	attack_phase2.start_pos = canal_point
	attack_phase2.end_pos = intercept_point if success else attack_to
	attack_phase2.speed = _projectile_speed
	# Continue fog reveal
	if is_player and enemy_grid_view.fog_manager:
		attack_phase2.fog_grid_view = enemy_grid_view
		attack_phase2.fog_reveal_enabled = true
	elif not is_player and enemy_fog_manager:
		attack_phase2.silent_fog_manager = enemy_fog_manager
		attack_phase2.silent_fog_grid_view = player_grid_view
		attack_phase2.silent_fog_reveal_enabled = true
	add_child(attack_phase2)
	_active_projectiles.append(attack_phase2)

	# Interceptor missile fires NOW (after canal crossed)
	var intercept_projectile = _ProjectileVisual.new()
	intercept_projectile.color = interceptor_color
	intercept_projectile.start_pos = interceptor_pos
	intercept_projectile.end_pos = intercept_point
	intercept_projectile.speed = _projectile_speed * 1.5  # Faster to catch up
	add_child(intercept_projectile)
	_active_projectiles.append(intercept_projectile)

	# Wait for interceptor to reach intercept point
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

		# Wait for attack missile to continue to target (only if not already finished)
		if not attack_phase2._is_finished:
			await attack_phase2.finished

		miss.queue_free()

	# Cleanup - check if nodes are still valid before erasing/freeing
	if attack_phase2 and is_instance_valid(attack_phase2):
		_active_projectiles.erase(attack_phase2)
		attack_phase2.queue_free()
	if intercept_projectile and is_instance_valid(intercept_projectile):
		_active_projectiles.erase(intercept_projectile)
		intercept_projectile.queue_free()


func _draw() -> void:
	# Projectiles draw themselves
	pass


# === TRANSPORT PHASE ===

func _execute_transport_phase() -> void:
	# Process player transports heading to enemy island (only those with targets)
	var player_assignments = player_targeting.get_all_assignments()
	for transport in player_assignments:
		if transport.is_destroyed:
			continue
		if not transport.is_transport():
			continue
		if transport.get_carried_unit_count() == 0:
			continue
		var landing_pos = player_assignments[transport]
		await _process_transport(transport, true, landing_pos)
		await get_tree().create_timer(_action_delay).timeout

	# Process enemy transports heading to player island
	if enemy_targeting:
		var enemy_assignments = enemy_targeting.get_all_assignments()
		for transport in enemy_assignments:
			if transport.is_destroyed:
				continue
			if not transport.is_transport():
				continue
			if transport.get_carried_unit_count() == 0:
				continue
			var landing_pos = enemy_assignments[transport]
			await _process_transport(transport, false, landing_pos)
			await get_tree().create_timer(_action_delay).timeout


func _get_loaded_transports(pm: PlacementManager) -> Array:
	var transports: Array = []
	for structure in pm.get_structures():
		if structure.is_destroyed:
			continue
		if structure.is_transport() and structure.get_carried_unit_count() > 0:
			transports.append(structure)
	return transports


func _process_transport(transport: Resource, is_player: bool, landing_pos: Vector2i) -> void:
	var source_grid_view = player_grid_view if is_player else enemy_grid_view
	var target_grid_view = enemy_grid_view if is_player else player_grid_view
	var target_placement = enemy_placement if is_player else player_placement

	transport_launched.emit(transport, is_player)

	# Calculate screen positions
	var from_local = source_grid_view.grid_to_screen_center(transport.grid_position)
	var from_pos = source_grid_view.global_position + from_local

	var to_local = target_grid_view.grid_to_screen_center(landing_pos)
	var to_pos = target_grid_view.global_position + to_local

	# Check for interception (transports can be shot down, but are harder to hit)
	var interceptor = _find_interceptor(target_placement, landing_pos)
	if interceptor:
		var interceptor_local = target_grid_view.grid_to_screen_center(interceptor.grid_position)
		var interceptor_pos = target_grid_view.global_position + interceptor_local
		var intercept_point = from_pos.lerp(to_pos, 0.7)

		# Transports use fixed lower intercept chance (harder to hit than missiles)
		var intercept_success = randf() < TRANSPORT_INTERCEPT_CHANCE

		# Animate transport and interceptor
		await _animate_transport_interception(from_pos, to_pos, interceptor_pos, intercept_point, is_player, intercept_success)

		if intercept_success:
			# Transport destroyed - all carried units lost
			transport_intercepted.emit(transport)
			return

	# No interception or intercept failed - transport lands
	if not interceptor:
		await _animate_transport(from_pos, to_pos, is_player)

	# Deploy units at landing zone
	transport_landed.emit(transport, landing_pos)
	await _deploy_transport_units(transport, landing_pos, is_player)


func _animate_transport(from: Vector2, to: Vector2, is_player: bool) -> void:
	var transport = _TransportVisual.new()
	transport.color = Color(0.3, 0.6, 0.9, 1.0) if is_player else Color(0.9, 0.4, 0.3, 1.0)
	transport.start_pos = from
	transport.end_pos = to
	transport.speed = _projectile_speed * 0.6  # Slower than missiles
	add_child(transport)

	await transport.finished

	transport.queue_free()


func _animate_transport_interception(transport_from: Vector2, transport_to: Vector2, interceptor_pos: Vector2, intercept_point: Vector2, is_player: bool, success: bool) -> void:
	var interceptor_color = Color(0.2, 0.9, 0.2, 1.0)

	# Phase 1: Transport travels to canal crossing point
	var canal_point = transport_from.lerp(transport_to, CANAL_CROSS_POINT)
	var transport_phase1 = _TransportVisual.new()
	transport_phase1.color = Color(0.3, 0.6, 0.9, 1.0) if is_player else Color(0.9, 0.4, 0.3, 1.0)
	transport_phase1.start_pos = transport_from
	transport_phase1.end_pos = canal_point
	transport_phase1.speed = _projectile_speed * 0.6
	add_child(transport_phase1)

	await transport_phase1.finished
	transport_phase1.queue_free()

	# Phase 2: Transport continues AND interceptor fires
	var transport_phase2 = _TransportVisual.new()
	transport_phase2.color = Color(0.3, 0.6, 0.9, 1.0) if is_player else Color(0.9, 0.4, 0.3, 1.0)
	transport_phase2.start_pos = canal_point
	transport_phase2.end_pos = intercept_point if success else transport_to
	transport_phase2.speed = _projectile_speed * 0.6
	add_child(transport_phase2)

	var intercept_projectile = _ProjectileVisual.new()
	intercept_projectile.color = interceptor_color
	intercept_projectile.start_pos = interceptor_pos
	intercept_projectile.end_pos = intercept_point
	intercept_projectile.speed = _projectile_speed * 1.5
	add_child(intercept_projectile)
	_active_projectiles.append(intercept_projectile)

	await intercept_projectile.finished

	if success:
		var explosion = _ExplosionVisual.new()
		explosion.position = intercept_point - global_position
		explosion.success = true
		add_child(explosion)
		await explosion.finished
		explosion.queue_free()
	else:
		var miss = _ExplosionVisual.new()
		miss.position = intercept_point - global_position
		miss.success = false
		add_child(miss)
		if not transport_phase2._is_finished:
			await transport_phase2.finished
		miss.queue_free()

	if transport_phase2 and is_instance_valid(transport_phase2):
		transport_phase2.queue_free()
	if intercept_projectile and is_instance_valid(intercept_projectile):
		_active_projectiles.erase(intercept_projectile)
		intercept_projectile.queue_free()


func _deploy_transport_units(transport: Resource, landing_pos: Vector2i, is_player: bool) -> void:
	var units = transport.unload_all_units()
	var deployed_list = _player_deployed_units if is_player else _enemy_deployed_units
	var target_grid_view = enemy_grid_view if is_player else player_grid_view

	# Deploy units in a spread pattern around landing zone
	var offset = 0
	for unit in units:
		var deploy_pos = Vector2i(landing_pos.x, landing_pos.y + offset)
		# Clamp to grid bounds
		deploy_pos.y = clampi(deploy_pos.y, 0, target_grid_view.grid.height - 1)
		unit.deploy_at(deploy_pos)
		unit.source_transport = transport  # Remember which transport we came from
		deployed_list.append(unit)
		ground_unit_deployed.emit(unit, deploy_pos)

		# Reveal fog at deployment position
		if is_player and enemy_grid_view.fog_manager:
			enemy_grid_view.fog_manager.reveal_area(deploy_pos, 1)
			enemy_grid_view.redraw_fog_overlay()
		elif not is_player and enemy_fog_manager:
			enemy_fog_manager.reveal_area(deploy_pos, 1)

		# Animate deployment
		var screen_pos = target_grid_view.global_position + target_grid_view.grid_to_screen_center(deploy_pos)
		await _animate_unit_deploy(screen_pos, unit)
		await get_tree().create_timer(0.2).timeout

		offset = -offset if offset <= 0 else -(offset + 1)  # 0, -1, 1, -2, 2...


func _animate_unit_deploy(screen_pos: Vector2, unit: Resource) -> void:
	var deploy_visual = _UnitDeployVisual.new()
	deploy_visual.position = screen_pos - global_position
	deploy_visual.unit_color = GroundUnit.get_color(unit.unit_type)
	add_child(deploy_visual)
	await deploy_visual.finished
	deploy_visual.queue_free()


# === GROUND COMBAT PHASE ===

func _execute_ground_combat_phase() -> void:
	# Run ground combat until one side is eliminated or all attackers reach targets
	var max_turns = 20  # Safety limit
	var turn = 0

	while turn < max_turns:
		turn += 1

		# Check if any ground units remain
		var player_units_alive = _count_alive_units(_player_deployed_units)
		var enemy_units_alive = _count_alive_units(_enemy_deployed_units)

		if player_units_alive == 0 and enemy_units_alive == 0:
			break  # No ground units left

		# Phase 1: Turrets fire at enemy ground units
		await _process_turret_attacks()

		# Phase 2: All ground units move simultaneously
		await _process_ground_movement()

		# Phase 3: All ground units attack simultaneously
		await _process_ground_attacks()

		# Phase 4: Resolve damage
		_resolve_ground_damage()

		await get_tree().create_timer(_action_delay).timeout


func _count_alive_units(units: Array) -> int:
	var count = 0
	for unit in units:
		if not unit.is_destroyed:
			count += 1
	return count


func _process_turret_attacks() -> void:
	# Player turrets attack enemy ground units on player island
	await _turrets_attack(player_placement, _enemy_deployed_units, player_grid_view)
	# Enemy turrets attack player ground units on enemy island
	await _turrets_attack(enemy_placement, _player_deployed_units, enemy_grid_view)


func _turrets_attack(pm: PlacementManager, enemy_units: Array, grid_view: Control) -> void:
	for structure in pm.get_structures():
		if structure.is_destroyed or not structure.is_turret():
			continue

		# Find enemy ground unit in range
		var target_unit = _find_ground_unit_in_turret_range(structure, enemy_units)
		if target_unit:
			# Animate turret attack
			var turret_pos = grid_view.global_position + grid_view.grid_to_screen_center(structure.grid_position)
			var target_pos = grid_view.global_position + grid_view.grid_to_screen_center(target_unit.current_position)
			await _animate_turret_attack(turret_pos, target_pos)

			# Deal damage
			var destroyed = target_unit.take_damage(structure.attack_damage)
			ground_unit_attacked.emit(structure, target_unit, structure.attack_damage)
			if destroyed:
				ground_unit_destroyed.emit(target_unit)


func _find_ground_unit_in_turret_range(turret: Resource, enemy_units: Array) -> Resource:
	var closest_unit: Resource = null
	var closest_dist: int = 999

	for unit in enemy_units:
		if unit.is_destroyed or not unit.is_deployed:
			continue
		# Check if unit is in turret range
		var dx = abs(unit.current_position.x - turret.grid_position.x)
		var dy = abs(unit.current_position.y - turret.grid_position.y)
		var dist = max(dx, dy)
		if dist <= turret.turret_range and dist < closest_dist:
			closest_dist = dist
			closest_unit = unit

	return closest_unit


func _animate_turret_attack(from_pos: Vector2, to_pos: Vector2) -> void:
	var projectile = _ProjectileVisual.new()
	projectile.color = Color(0.8, 0.8, 0.3, 1.0)  # Yellow for turret
	projectile.start_pos = from_pos
	projectile.end_pos = to_pos
	projectile.speed = _projectile_speed * 2.0  # Fast
	add_child(projectile)
	await projectile.finished
	projectile.queue_free()


func _process_ground_movement() -> void:
	# Move player units on enemy island toward targets
	for unit in _player_deployed_units:
		if unit.is_destroyed or not unit.is_deployed:
			continue
		var target_pos = _find_target_for_ground_unit(unit, enemy_placement, _enemy_deployed_units)
		if target_pos != Vector2i(-1, -1):
			var old_pos = unit.current_position
			var new_pos = unit.move_toward(target_pos)
			if new_pos != old_pos:
				ground_unit_moved.emit(unit, old_pos, new_pos)
				await _animate_unit_move(enemy_grid_view, old_pos, new_pos, unit)
				# Reveal fog around unit's new position (player units reveal enemy island)
				if enemy_grid_view.fog_manager:
					enemy_grid_view.fog_manager.reveal_area(new_pos, 1)
					enemy_grid_view.redraw_fog_overlay()

	# Move enemy units on player island toward targets
	for unit in _enemy_deployed_units:
		if unit.is_destroyed or not unit.is_deployed:
			continue
		var target_pos = _find_target_for_ground_unit(unit, player_placement, _player_deployed_units)
		if target_pos != Vector2i(-1, -1):
			var old_pos = unit.current_position
			var new_pos = unit.move_toward(target_pos)
			if new_pos != old_pos:
				ground_unit_moved.emit(unit, old_pos, new_pos)
				await _animate_unit_move(player_grid_view, old_pos, new_pos, unit)
				# Enemy units reveal player island for enemy's internal fog tracking
				if enemy_fog_manager:
					enemy_fog_manager.reveal_area(new_pos, 1)


func _find_target_for_ground_unit(unit: Resource, target_pm: PlacementManager, enemy_units: Array) -> Vector2i:
	# If unit is returning to transport, head back to landing site
	if unit.is_returning:
		return unit.landing_position

	# Defenders (patrol units) target enemy ground units within operation range
	if unit.is_defender:
		var closest_enemy: Resource = null
		var closest_dist: int = 999
		for enemy in enemy_units:
			if enemy.is_destroyed or not enemy.is_deployed:
				continue
			# Only target enemies within our operation range
			if not unit.is_within_operation_range(enemy.current_position):
				continue
			var dist = _manhattan_distance(unit.current_position, enemy.current_position)
			if dist < closest_dist:
				closest_dist = dist
				closest_enemy = enemy
		if closest_enemy:
			return closest_enemy.current_position
		# No enemies in range - return to landing
		unit.is_returning = true
		return unit.landing_position

	# Attackers target structures based on priority (within operation range)
	var best_target: Resource = null
	var best_priority: int = -1

	for structure in target_pm.get_structures():
		if structure.is_destroyed:
			continue
		# Only target structures within operation range
		if not unit.is_within_operation_range(structure.grid_position):
			continue
		var priority = unit.get_target_priority(structure)
		if priority > best_priority:
			best_priority = priority
			best_target = structure

	if best_target:
		return best_target.grid_position

	# No targets in range - return to landing
	unit.is_returning = true
	return unit.landing_position


func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


func _animate_unit_move(grid_view: Control, from_grid: Vector2i, to_grid: Vector2i, unit: Resource) -> void:
	var from_pos = grid_view.global_position + grid_view.grid_to_screen_center(from_grid)
	var to_pos = grid_view.global_position + grid_view.grid_to_screen_center(to_grid)

	var move_visual = _UnitMoveVisual.new()
	move_visual.start_pos = from_pos
	move_visual.end_pos = to_pos
	move_visual.unit_color = GroundUnit.get_color(unit.unit_type)
	move_visual.speed = _projectile_speed * 0.4
	add_child(move_visual)
	await move_visual.finished
	move_visual.queue_free()


func _process_ground_attacks() -> void:
	# Player units attack on enemy island
	for unit in _player_deployed_units:
		if unit.is_destroyed or not unit.is_deployed:
			continue
		if unit.is_returning:
			continue  # Returning units don't attack

		if unit.is_defender:
			# Attack adjacent enemy ground units
			for enemy in _enemy_deployed_units:
				if unit.can_attack_ground_unit(enemy):
					await _animate_ground_attack(enemy_grid_view, unit, enemy.current_position)
					var destroyed = enemy.take_damage(unit.attack_damage)
					ground_unit_attacked.emit(unit, enemy, unit.attack_damage)
					if destroyed:
						ground_unit_destroyed.emit(enemy)
					break
		else:
			# Attack adjacent structures
			for structure in enemy_placement.get_structures():
				if unit.can_attack_structure(structure):
					await _animate_ground_attack(enemy_grid_view, unit, structure.grid_position)
					var destroyed = structure.take_damage(unit.attack_damage)
					structure_attacked_by_ground.emit(structure, unit, unit.attack_damage)
					structure_hit.emit(structure, unit.attack_damage)
					if destroyed:
						structure_destroyed.emit(structure)

					# Suicide units destroy themselves after attacking
					if unit.is_suicide:
						unit.is_destroyed = true
						ground_unit_destroyed.emit(unit)
					break

	# Enemy units attack on player island
	for unit in _enemy_deployed_units:
		if unit.is_destroyed or not unit.is_deployed:
			continue
		if unit.is_returning:
			continue  # Returning units don't attack

		if unit.is_defender:
			# Attack adjacent player ground units
			for enemy in _player_deployed_units:
				if unit.can_attack_ground_unit(enemy):
					await _animate_ground_attack(player_grid_view, unit, enemy.current_position)
					var destroyed = enemy.take_damage(unit.attack_damage)
					ground_unit_attacked.emit(unit, enemy, unit.attack_damage)
					if destroyed:
						ground_unit_destroyed.emit(enemy)
					break
		else:
			# Attack adjacent structures
			for structure in player_placement.get_structures():
				if unit.can_attack_structure(structure):
					await _animate_ground_attack(player_grid_view, unit, structure.grid_position)
					var destroyed = structure.take_damage(unit.attack_damage)
					structure_attacked_by_ground.emit(structure, unit, unit.attack_damage)
					structure_hit.emit(structure, unit.attack_damage)
					if destroyed:
						structure_destroyed.emit(structure)

					# Suicide units destroy themselves after attacking
					if unit.is_suicide:
						unit.is_destroyed = true
						ground_unit_destroyed.emit(unit)
					break


func _animate_ground_attack(grid_view: Control, attacker: Resource, target_pos: Vector2i) -> void:
	var attacker_screen = grid_view.global_position + grid_view.grid_to_screen_center(attacker.current_position)
	var target_screen = grid_view.global_position + grid_view.grid_to_screen_center(target_pos)

	var attack_visual = _GroundAttackVisual.new()
	attack_visual.start_pos = attacker_screen
	attack_visual.end_pos = target_screen
	attack_visual.attack_color = GroundUnit.get_color(attacker.unit_type)
	attack_visual.is_suicide = attacker.is_suicide
	add_child(attack_visual)
	await attack_visual.finished
	attack_visual.queue_free()


func _resolve_ground_damage() -> void:
	# Check for units that have returned to their landing site
	_check_returned_units(_player_deployed_units, true)
	_check_returned_units(_enemy_deployed_units, false)

	# Remove destroyed OR returned (no longer deployed) units from tracking arrays
	_player_deployed_units = _player_deployed_units.filter(func(u): return not u.is_destroyed and u.is_deployed)
	_enemy_deployed_units = _enemy_deployed_units.filter(func(u): return not u.is_destroyed and u.is_deployed)


func _check_returned_units(units: Array, _is_player: bool) -> void:
	# Find units that are returning and have reached landing site
	var returned_count: int = 0
	var return_transport: Resource = null

	for unit in units:
		if unit.is_destroyed:
			continue
		if unit.is_returning and unit.is_at_landing_site():
			returned_count += 1
			return_transport = unit.source_transport
			# Reload unit back into its transport
			if unit.source_transport and not unit.source_transport.is_destroyed:
				# Reset unit state for reuse
				unit.is_deployed = false
				unit.is_returning = false
				unit.current_position = Vector2i(-1, -1)
				unit.landing_position = Vector2i(-1, -1)
				# Put back in transport
				unit.source_transport.carried_units.append(unit)
			else:
				# Transport destroyed, unit has nowhere to go - mark as lost
				unit.is_destroyed = true

	# Note: Returned units will be filtered out in _resolve_ground_damage by is_deployed check

	if returned_count > 0:
		transport_returned.emit(return_transport, returned_count)


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


# Inner class for impact area visualization
class _ImpactAreaVisual extends Node2D:
	signal finished

	var center_pos: Vector2  # Screen position of impact center
	var cell_size: Vector2 = Vector2(64, 64)
	var radius: int = 1  # In cells (1 = 3x3 area)
	var impact_color: Color = Color(1.0, 0.5, 0.0, 0.6)  # Orange highlight
	var _timer: float = 0.0
	var _duration: float = 0.5

	func _process(delta: float) -> void:
		_timer += delta
		if _timer >= _duration:
			finished.emit()
			set_process(false)
		queue_redraw()

	func _draw() -> void:
		var t = _timer / _duration
		var alpha = 0.6 * (1.0 - t)  # Fade out
		var draw_color = impact_color
		draw_color.a = alpha

		# Draw all affected cells
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var cell_offset = Vector2(dx, dy) * cell_size
				var cell_rect = Rect2(center_pos + cell_offset - cell_size / 2 - global_position, cell_size)
				draw_rect(cell_rect, draw_color)


# Inner class for transport visual
class _TransportVisual extends Node2D:
	signal finished

	var color: Color = Color(0.3, 0.6, 0.9, 1.0)
	var start_pos: Vector2
	var end_pos: Vector2
	var speed: float = 240.0
	var _progress: float = 0.0
	var _total_distance: float = 0.0
	var _is_finished: bool = false

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
		if _progress >= _total_distance:
			_is_finished = true
			finished.emit()
		queue_redraw()

	func _draw() -> void:
		var t = _progress / _total_distance if _total_distance > 0 else 1.0
		t = min(t, 1.0)
		var current_pos = start_pos.lerp(end_pos, t)
		var local_pos = current_pos - global_position

		# Draw transport as a larger rectangle (boat shape)
		var boat_size = Vector2(20, 12)
		var boat_rect = Rect2(local_pos - boat_size / 2, boat_size)
		draw_rect(boat_rect, color)
		# Draw deck
		var deck_rect = Rect2(local_pos - Vector2(8, 3), Vector2(16, 6))
		draw_rect(deck_rect, color.lightened(0.2))
		# Draw trail (wake)
		var trail_length = min(_progress, 40.0)
		var trail_start_t = max(0, (_progress - trail_length) / _total_distance)
		var trail_start = start_pos.lerp(end_pos, trail_start_t) - global_position
		draw_line(trail_start, local_pos, Color(0.5, 0.7, 0.9, 0.4), 3.0)


# Inner class for unit deployment visual
class _UnitDeployVisual extends Node2D:
	signal finished

	var unit_color: Color = Color(0.6, 0.4, 0.2)
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
		# Expanding ring effect
		var radius = 8.0 + 12.0 * t
		var alpha = 1.0 - t
		draw_circle(Vector2.ZERO, radius, Color(unit_color.r, unit_color.g, unit_color.b, alpha * 0.5))
		# Solid unit marker in center
		draw_circle(Vector2.ZERO, 6.0, unit_color)


# Inner class for unit movement visual
class _UnitMoveVisual extends Node2D:
	signal finished

	var start_pos: Vector2
	var end_pos: Vector2
	var unit_color: Color = Color(0.6, 0.4, 0.2)
	var speed: float = 160.0
	var _progress: float = 0.0
	var _total_distance: float = 0.0
	var _is_finished: bool = false

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
		if _progress >= _total_distance:
			_is_finished = true
			finished.emit()
		queue_redraw()

	func _draw() -> void:
		var t = _progress / _total_distance if _total_distance > 0 else 1.0
		t = min(t, 1.0)
		var current_pos = start_pos.lerp(end_pos, t)
		var local_pos = current_pos - global_position

		# Draw unit as colored circle
		draw_circle(local_pos, 6.0, unit_color)
		# Draw movement trail
		var trail_length = min(_progress, 20.0)
		var trail_start_t = max(0, (_progress - trail_length) / _total_distance)
		var trail_start = start_pos.lerp(end_pos, trail_start_t) - global_position
		draw_line(trail_start, local_pos, unit_color.darkened(0.3), 2.0)


# Inner class for ground attack visual
class _GroundAttackVisual extends Node2D:
	signal finished

	var start_pos: Vector2
	var end_pos: Vector2
	var attack_color: Color = Color(0.8, 0.2, 0.1)
	var is_suicide: bool = false
	var _timer: float = 0.0
	var _duration: float = 0.3

	func _process(delta: float) -> void:
		_timer += delta
		if _timer >= _duration:
			finished.emit()
			set_process(false)
		queue_redraw()

	func _draw() -> void:
		var t = _timer / _duration
		var local_start = start_pos - global_position
		var local_end = end_pos - global_position

		if is_suicide:
			# Explosion effect for suicide units
			var center = local_end
			var radius = 15.0 * (0.5 + t)
			var alpha = 1.0 - t
			draw_circle(center, radius, Color(1.0, 0.5, 0.0, alpha))
			draw_circle(center, radius * 0.6, Color(1.0, 0.8, 0.2, alpha))
		else:
			# Quick strike line
			var alpha = 1.0 - t
			var strike_color = Color(attack_color.r, attack_color.g, attack_color.b, alpha)
			draw_line(local_start, local_end, strike_color, 3.0)
			# Impact flash at target
			var impact_radius = 8.0 * (1.0 - t * 0.5)
			draw_circle(local_end, impact_radius, strike_color)
