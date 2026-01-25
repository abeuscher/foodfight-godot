class_name GroundUnit
extends Resource
## Base data class for ground units that can be loaded into transports.

enum UnitType { INFANTRY, DEMOLITION, PATROL }

# Centralized ground unit data
const UNIT_DATA: Dictionary = {
	UnitType.INFANTRY: {
		"abbreviation": "IN",
		"name": "Infantry",
		"description": "Basic ground unit. Moves 1 cell/turn, attacks adjacent structures for 1 damage.",
		"color": Color(0.6, 0.4, 0.2),  # Brown (army)
		"cost": 5,
		"health": 3,
		"attack_damage": 1,
		"movement_speed": 1,  # Cells per turn
		"attack_range": 1,  # Must be adjacent
		"is_suicide": false,
		# Target priority: higher = more preferred (Radar > Defensive > Offensive > Economic > Base)
		"priority_radar": 50,
		"priority_defensive": 40,
		"priority_offensive": 30,
		"priority_economic": 20,
		"priority_base": 10,
	},
	UnitType.DEMOLITION: {
		"abbreviation": "DM",
		"name": "Demolition",
		"description": "Fast suicide unit. Moves 2 cells/turn, explodes for 3 damage on arrival.",
		"color": Color(0.8, 0.2, 0.1),  # Red (explosive)
		"cost": 10,
		"health": 2,
		"attack_damage": 3,
		"movement_speed": 2,  # Cells per turn (fast)
		"attack_range": 1,  # Must be adjacent
		"is_suicide": true,  # Destroys self on attack
		# Target priority: Base > Radar > Economic > Defensive > Offensive
		"priority_base": 50,
		"priority_radar": 40,
		"priority_economic": 30,
		"priority_defensive": 20,
		"priority_offensive": 10,
	},
	UnitType.PATROL: {
		"abbreviation": "PT",
		"name": "Patrol",
		"description": "Mobile defense. Moves 1 cell/turn, attacks adjacent enemy ground units.",
		"color": Color(0.3, 0.5, 0.3),  # Dark green (patrol)
		"cost": 15,
		"health": 4,
		"attack_damage": 1,
		"movement_speed": 1,  # Cells per turn
		"attack_range": 1,  # Must be adjacent
		"is_suicide": false,
		"is_defender": true,  # Attacks enemy ground units, not structures
		# No structure targeting priorities - targets enemy ground units
		"priority_radar": 0,
		"priority_defensive": 0,
		"priority_offensive": 0,
		"priority_economic": 0,
		"priority_base": 0,
	},
}

@export var unit_type: UnitType
@export var health: int = 1
@export var max_health: int = 1
@export var attack_damage: int = 1
@export var movement_speed: int = 1
@export var attack_range: int = 1
@export var is_suicide: bool = false
@export var is_defender: bool = false  # True for patrol units that attack ground units

var current_position: Vector2i = Vector2i(-1, -1)
var landing_position: Vector2i = Vector2i(-1, -1)  # Where the unit landed (for range limits)
var source_transport: Resource = null  # The transport this unit came from
var target_structure: Resource = null  # Structure being targeted
var target_ground_unit: Resource = null  # Enemy ground unit being targeted (for defenders)
var is_deployed: bool = false
var is_destroyed: bool = false
var is_returning: bool = false  # True when unit is heading back to transport
var owner_is_player: bool = true  # Which side owns this unit

const MAX_RANGE_FROM_LANDING: int = 3  # Units can only move 3 cells from landing site


# --- Static accessor functions ---

static func get_abbreviation(type: UnitType) -> String:
	return UNIT_DATA[type]["abbreviation"]


static func get_display_name(type: UnitType) -> String:
	return UNIT_DATA[type]["name"]


static func get_description(type: UnitType) -> String:
	return UNIT_DATA[type]["description"]


static func get_color(type: UnitType) -> Color:
	return UNIT_DATA[type]["color"]


static func get_cost(type: UnitType) -> int:
	return UNIT_DATA[type]["cost"]


static func create(type: UnitType, owner_player: bool = true) -> Resource:
	var script = load("res://scripts/resources/ground_unit.gd")
	var u = script.new()
	u.unit_type = type
	u.owner_is_player = owner_player

	# Load stats from centralized data
	var data = UNIT_DATA[type]
	u.health = data["health"]
	u.max_health = data["health"]
	u.attack_damage = data["attack_damage"]
	u.movement_speed = data["movement_speed"]
	u.attack_range = data["attack_range"]
	u.is_suicide = data["is_suicide"]
	u.is_defender = data.get("is_defender", false)

	return u


# --- Instance methods ---

func take_damage(amount: int = 1) -> bool:
	health -= amount
	if health <= 0:
		is_destroyed = true
	return is_destroyed


func deploy_at(pos: Vector2i) -> void:
	current_position = pos
	landing_position = pos  # Remember where we landed for range limits
	is_deployed = true


func move_toward(target_pos: Vector2i) -> Vector2i:
	# Move up to movement_speed cells toward target
	# Returns the new position
	if is_destroyed or not is_deployed:
		return current_position

	var dx = target_pos.x - current_position.x
	var dy = target_pos.y - current_position.y

	# Normalize direction and move up to movement_speed
	var move_x = clampi(dx, -movement_speed, movement_speed)
	var move_y = clampi(dy, -movement_speed, movement_speed)

	# Prioritize the larger distance
	if abs(dx) > abs(dy):
		move_y = 0 if abs(move_x) >= movement_speed else clampi(dy, -(movement_speed - abs(move_x)), movement_speed - abs(move_x))
	else:
		move_x = 0 if abs(move_y) >= movement_speed else clampi(dx, -(movement_speed - abs(move_y)), movement_speed - abs(move_y))

	current_position = Vector2i(current_position.x + move_x, current_position.y + move_y)
	return current_position


func is_adjacent_to(pos: Vector2i) -> bool:
	var dx = abs(pos.x - current_position.x)
	var dy = abs(pos.y - current_position.y)
	return dx <= attack_range and dy <= attack_range and (dx > 0 or dy > 0)


func is_within_operation_range(pos: Vector2i) -> bool:
	# Check if position is within MAX_RANGE_FROM_LANDING cells of landing site
	var dx = abs(pos.x - landing_position.x)
	var dy = abs(pos.y - landing_position.y)
	return dx <= MAX_RANGE_FROM_LANDING and dy <= MAX_RANGE_FROM_LANDING


func is_at_landing_site() -> bool:
	return current_position == landing_position


func can_attack_structure(structure: Resource) -> bool:
	if is_destroyed or not is_deployed:
		return false
	if is_defender:
		return false  # Defenders attack ground units, not structures
	if structure.is_destroyed:
		return false
	return is_adjacent_to(structure.grid_position)


func can_attack_ground_unit(other_unit: Resource) -> bool:
	if is_destroyed or not is_deployed:
		return false
	if not is_defender:
		return false  # Only defenders attack ground units
	if other_unit.is_destroyed or not other_unit.is_deployed:
		return false
	if other_unit.owner_is_player == owner_is_player:
		return false  # Can't attack friendly units
	return is_adjacent_to(other_unit.current_position)


func get_target_priority(structure: Resource) -> int:
	# Returns priority for targeting this structure (higher = more preferred)
	var data = UNIT_DATA[unit_type]
	var category = structure.get_category(structure.type)

	match category:
		0:  # CRITICAL (Base, Lemonade Stand)
			if structure.type == 0:  # BASE
				return data["priority_base"]
			else:
				return data["priority_economic"]
		1:  # OFFENSIVE
			return data["priority_offensive"]
		2:  # DEFENSIVE
			if structure.radar_range > 0:
				return data["priority_radar"]
			return data["priority_defensive"]
		_:
			return 0
