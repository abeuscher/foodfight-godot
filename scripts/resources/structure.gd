class_name Structure
extends Resource
## Base data class for all placeable structures.

enum Type { BASE, HOT_DOG_CANNON, CONDIMENT_CANNON, CONDIMENT_STATION, PICKLE_INTERCEPTOR, COFFEE_RADAR, VEGGIE_CANNON, LEMONADE_STAND, SALAD_BAR, RADAR_JAMMER, TRANSPORT, TURRET, GENERATOR }
enum Category { CRITICAL, OFFENSIVE, DEFENSIVE, GROUND_TRANSPORT, GROUND_DEFENSE }

# Centralized structure data - all attributes in one place
const STRUCTURE_DATA: Dictionary = {
	Type.BASE: {
		"abbreviation": "B",
		"name": "Base",
		"description": "Your headquarters. Generates +5 energy/turn. Lose all bases = lose game.",
		"category": Category.CRITICAL,
		"priority": 0,
		"color": Color(0.9, 0.75, 0.2),  # Gold
		"cost": 0,
		"health": 4,  # Reduced from 5 - still tanky but killable
		"attack_damage": 0,
		"area_attack_radius": 0,
		"interception_range": 0,
		"radar_range": 0,
		"income_per_turn": 0,
		"heal_radius": 0,
		"heal_amount": 0,
		"jam_radius": 0,
		"transport_capacity": 0,
		"turret_range": 0,
		"energy_per_turn": 5,  # Each base provides baseline power
		"energy_cost": 0,  # No cost to operate
	},
	Type.HOT_DOG_CANNON: {
		"abbreviation": "HD",
		"name": "Hot Dog Cannon",
		"description": "Precision strike. 2 dmg to single target. Costs 2 energy to fire.",
		"category": Category.OFFENSIVE,
		"priority": 50,
		"color": Color(0.85, 0.45, 0.2),  # Orange (hot dog)
		"cost": 5,
		"health": 2,  # Glass cannon - hits hard, dies fast
		"attack_damage": 2,  # High single-target damage
		"area_attack_radius": 0,  # 1x1 precision strike
		"interception_range": 0,
		"radar_range": 0,
		"income_per_turn": 0,
		"heal_radius": 0,
		"heal_amount": 0,
		"jam_radius": 0,
		"transport_capacity": 0,
		"turret_range": 0,
		"energy_per_turn": 0,
		"energy_cost": 2,  # Cheap, spammable
	},
	Type.CONDIMENT_CANNON: {
		"abbreviation": "CC",
		"name": "Condiment Cannon",
		"description": "Splash damage. 1 dmg to 3x3 area. Costs 2 energy to fire.",
		"category": Category.OFFENSIVE,
		"priority": 50,
		"color": Color(0.8, 0.3, 0.3),  # Red
		"cost": 5,
		"health": 2,  # Glass cannon - hits hard, dies fast
		"attack_damage": 1,
		"area_attack_radius": 1,  # 3x3 area
		"interception_range": 0,
		"radar_range": 0,
		"income_per_turn": 0,
		"heal_radius": 0,
		"heal_amount": 0,
		"jam_radius": 0,
		"transport_capacity": 0,
		"turret_range": 0,
		"energy_per_turn": 0,
		"energy_cost": 2,  # Same as hot dog
	},
	Type.CONDIMENT_STATION: {
		"abbreviation": "CS",
		"name": "Condiment Station",
		"description": "Premium splash. 2 dmg to 3x3 area. Costs 4 energy to fire.",
		"category": Category.OFFENSIVE,
		"priority": 40,  # Slightly lower - area attacks after direct
		"color": Color(0.9, 0.8, 0.2),  # Mustard yellow
		"cost": 10,
		"health": 2,  # Glass cannon - hits hard, dies fast
		"attack_damage": 2,  # High area damage
		"area_attack_radius": 1,  # 3x3 area
		"interception_range": 0,
		"radar_range": 0,
		"income_per_turn": 0,
		"heal_radius": 0,
		"heal_amount": 0,
		"jam_radius": 0,
		"transport_capacity": 0,
		"turret_range": 0,
		"energy_per_turn": 0,
		"energy_cost": 4,  # Premium weapon
	},
	Type.PICKLE_INTERCEPTOR: {
		"abbreviation": "PI",
		"name": "Pickle Interceptor",
		"description": "Intercepts missiles when radar active. 1 energy per attempt.",
		"category": Category.DEFENSIVE,
		"priority": 100,  # High priority - intercepts first
		"color": Color(0.3, 0.7, 0.4),  # Green
		"cost": 5,
		"health": 3,  # Defensive - slightly tougher
		"attack_damage": 0,
		"area_attack_radius": 0,
		"interception_range": 1,  # Can intercept
		"radar_range": 0,
		"income_per_turn": 0,
		"heal_radius": 0,
		"heal_amount": 0,
		"jam_radius": 0,
		"transport_capacity": 0,
		"turret_range": 0,
		"energy_per_turn": 0,
		"energy_cost": 1,  # Per intercept attempt
	},
	Type.COFFEE_RADAR: {
		"abbreviation": "CR",
		"name": "Coffee Cup Radar",
		"description": "Detection for interception. +5% intercept. 1 energy/turn to operate.",
		"category": Category.DEFENSIVE,
		"priority": 0,  # Doesn't attack
		"color": Color(0.5, 0.35, 0.2),  # Brown (coffee)
		"cost": 10,
		"health": 3,  # Defensive - slightly tougher
		"attack_damage": 0,
		"area_attack_radius": 0,
		"interception_range": 0,
		"radar_range": 20,  # Detection radius
		"income_per_turn": 0,
		"heal_radius": 0,
		"heal_amount": 0,
		"jam_radius": 0,
		"transport_capacity": 0,
		"turret_range": 0,
		"energy_per_turn": 0,
		"energy_cost": 1,  # Must be powered to give bonus
	},
	Type.VEGGIE_CANNON: {
		"abbreviation": "VC",
		"name": "Veggie Cannon",
		"description": "Intercepts missiles when radar active. 1 energy per attempt.",
		"category": Category.DEFENSIVE,
		"priority": 90,  # High priority for defense
		"color": Color(0.2, 0.6, 0.2),  # Dark green
		"cost": 5,
		"health": 3,  # Defensive - slightly tougher
		"attack_damage": 0,
		"area_attack_radius": 0,
		"interception_range": 1,  # Can intercept
		"radar_range": 0,
		"income_per_turn": 0,
		"heal_radius": 0,
		"heal_amount": 0,
		"jam_radius": 0,
		"transport_capacity": 0,
		"turret_range": 0,
		"energy_per_turn": 0,
		"energy_cost": 1,  # Per intercept attempt
	},
	Type.LEMONADE_STAND: {
		"abbreviation": "LS",
		"name": "Lemonade Stand",
		"description": "Generates $3 income and +3 energy per turn. Economic structure.",
		"category": Category.CRITICAL,  # Economic building
		"priority": 0,  # Doesn't attack
		"color": Color(1.0, 0.95, 0.3),  # Bright yellow
		"cost": 20,
		"health": 2,  # High value target, fragile
		"attack_damage": 0,
		"area_attack_radius": 0,
		"interception_range": 0,
		"radar_range": 0,
		"income_per_turn": 3,  # Reduced from $5 to $3
		"heal_radius": 0,
		"heal_amount": 0,
		"jam_radius": 0,
		"transport_capacity": 0,
		"turret_range": 0,
		"energy_per_turn": 3,  # Also generates energy
		"energy_cost": 0,
	},
	Type.SALAD_BAR: {
		"abbreviation": "SB",
		"name": "Salad Bar",
		"description": "Heals nearby structures by 1 HP each round. Support structure.",
		"category": Category.DEFENSIVE,  # Support building
		"priority": 0,  # Doesn't attack
		"color": Color(0.4, 0.8, 0.4),  # Light green
		"cost": 20,
		"health": 2,  # High value target, fragile
		"attack_damage": 0,
		"area_attack_radius": 0,
		"interception_range": 0,
		"radar_range": 0,
		"income_per_turn": 0,
		"heal_radius": 1,  # 3x3 area
		"heal_amount": 1,  # 1 HP per turn
		"jam_radius": 0,
		"transport_capacity": 0,
		"turret_range": 0,
		"energy_per_turn": 0,
		"energy_cost": 0,  # Passive healing, no energy cost
	},
	Type.RADAR_JAMMER: {
		"abbreviation": "RJ",
		"name": "Radar Jammer",
		"description": "Jams enemy radars 3 turns. Uninterceptable. 3 energy to fire.",
		"category": Category.OFFENSIVE,  # Anti-defense weapon
		"priority": 120,  # Highest priority - jams radar before other attacks
		"color": Color(0.6, 0.2, 0.8),  # Purple (electronic warfare)
		"cost": 15,
		"health": 2,  # Glass cannon - hits hard, dies fast
		"attack_damage": 0,  # Jams only, no damage
		"area_attack_radius": 0,  # 1x1 - jam effect only
		"interception_range": 0,
		"radar_range": 0,
		"income_per_turn": 0,
		"heal_radius": 0,
		"heal_amount": 0,
		"jam_radius": 1,  # Must be > 0 to identify as jammer (prevents interception)
		"transport_capacity": 0,
		"turret_range": 0,
		"energy_per_turn": 0,
		"energy_cost": 3,  # Tactical strike
	},
	Type.TRANSPORT: {
		"abbreviation": "TR",
		"name": "Transport",
		"description": "Carries 3 ground units. 4 energy to launch. Can be intercepted.",
		"category": Category.GROUND_TRANSPORT,
		"priority": 30,  # Moves after jammers but before regular attacks
		"color": Color(0.4, 0.6, 0.8),  # Light blue (naval/transport)
		"cost": 25,
		"health": 3,  # Meaningful to lose
		"attack_damage": 0,
		"area_attack_radius": 0,
		"interception_range": 0,
		"radar_range": 0,
		"income_per_turn": 0,
		"heal_radius": 0,
		"heal_amount": 0,
		"jam_radius": 0,
		"transport_capacity": 3,  # Can carry 3 ground units
		"turret_range": 0,
		"energy_per_turn": 0,
		"energy_cost": 4,  # Significant investment
	},
	Type.TURRET: {
		"abbreviation": "TU",
		"name": "Turret",
		"description": "Auto-attacks ground units within 2 cells. 1 energy per attack.",
		"category": Category.GROUND_DEFENSE,
		"priority": 0,  # Defensive - doesn't initiate attacks
		"color": Color(0.5, 0.5, 0.5),  # Gray (fortification)
		"cost": 10,
		"health": 3,  # Can survive a hit
		"attack_damage": 1,  # 1 damage to ground units
		"area_attack_radius": 0,
		"interception_range": 0,
		"radar_range": 0,
		"income_per_turn": 0,
		"heal_radius": 0,
		"heal_amount": 0,
		"jam_radius": 0,
		"transport_capacity": 0,
		"turret_range": 2,  # Attacks ground units within 2 cells
		"energy_per_turn": 0,
		"energy_cost": 1,  # Per attack
	},
	Type.GENERATOR: {
		"abbreviation": "GN",
		"name": "Food Truck",
		"description": "Mobile kitchen. Generates +5 energy per turn. High value target.",
		"category": Category.CRITICAL,  # Power infrastructure
		"priority": 0,  # Doesn't attack
		"color": Color(0.9, 0.5, 0.1),  # Orange (food truck)
		"cost": 15,
		"health": 2,  # High value target, fragile
		"attack_damage": 0,
		"area_attack_radius": 0,
		"interception_range": 0,
		"radar_range": 0,
		"income_per_turn": 0,
		"heal_radius": 0,
		"heal_amount": 0,
		"jam_radius": 0,
		"transport_capacity": 0,
		"turret_range": 0,
		"energy_per_turn": 5,  # Primary energy source
		"energy_cost": 0,
	},
}

@export var type: Type
@export var health: int = 1
@export var max_health: int = 1
@export var attack_priority: int = 0
@export var attack_damage: int = 1
@export var interception_range: int = 0  # 0 = no interception, 1 = 3x3 area, 2 = 5x5 area, etc.
@export var area_attack_radius: int = 0  # 0 = single target, 1 = 3x3 area, 2 = 5x5 area, etc.
@export var income_per_turn: int = 0  # Passive income generated each turn
@export var heal_radius: int = 0  # 0 = no healing, 1 = 3x3 area, etc.
@export var heal_amount: int = 0  # HP healed per turn
@export var radar_range: int = 0  # Range at which radar boosts nearby defenses
@export var jam_radius: int = 0  # Radius for jamming radars (0 = no jamming)
@export var transport_capacity: int = 0  # How many ground units this can carry (0 = not a transport)
@export var turret_range: int = 0  # Range at which turret attacks ground units (0 = not a turret)
@export var energy_per_turn: int = 0  # Energy generated each turn
@export var energy_cost: int = 0  # Energy required to fire/operate this structure
@export var grid_position: Vector2i = Vector2i(-1, -1)

var is_destroyed: bool = false
var is_jammed: bool = false  # For radars - when jammed, they cannot detect missiles
var jam_turns_remaining: int = 0  # Turns until jam wears off (0 = not jammed)
var carried_units: Array = []  # For transports - ground units being carried


# --- Static accessor functions (read from STRUCTURE_DATA) ---

static func get_abbreviation(structure_type: Type) -> String:
	return STRUCTURE_DATA[structure_type]["abbreviation"]


static func get_display_name(structure_type: Type) -> String:
	return STRUCTURE_DATA[structure_type]["name"]


static func get_description(structure_type: Type) -> String:
	return STRUCTURE_DATA[structure_type]["description"]


static func get_category(structure_type: Type) -> Category:
	return STRUCTURE_DATA[structure_type]["category"]


static func get_default_priority(structure_type: Type) -> int:
	return STRUCTURE_DATA[structure_type]["priority"]


static func get_color(structure_type: Type) -> Color:
	return STRUCTURE_DATA[structure_type]["color"]


static func get_cost(structure_type: Type) -> int:
	return STRUCTURE_DATA[structure_type]["cost"]


static func get_energy_per_turn(structure_type: Type) -> int:
	return STRUCTURE_DATA[structure_type]["energy_per_turn"]


static func get_energy_cost(structure_type: Type) -> int:
	return STRUCTURE_DATA[structure_type]["energy_cost"]


static func create(structure_type: Type, pos: Vector2i = Vector2i(-1, -1)) -> Resource:
	var script = load("res://scripts/resources/structure.gd")
	var s = script.new()
	s.type = structure_type
	s.grid_position = pos

	# Load all stats from centralized data
	var data = STRUCTURE_DATA[structure_type]
	s.attack_priority = data["priority"]
	s.health = data["health"]
	s.max_health = data["health"]
	s.attack_damage = data["attack_damage"]
	s.area_attack_radius = data["area_attack_radius"]
	s.interception_range = data["interception_range"]
	s.radar_range = data["radar_range"]
	s.income_per_turn = data["income_per_turn"]
	s.heal_radius = data["heal_radius"]
	s.heal_amount = data["heal_amount"]
	s.jam_radius = data["jam_radius"]
	s.transport_capacity = data["transport_capacity"]
	s.turret_range = data["turret_range"]
	s.energy_per_turn = data["energy_per_turn"]
	s.energy_cost = data["energy_cost"]

	return s


# --- Instance methods ---

func take_damage(amount: int = 1) -> bool:
	health -= amount
	if health <= 0:
		is_destroyed = true
	return is_destroyed


func heal(amount: int = 1) -> int:
	var old_health = health
	health = min(health + amount, max_health)
	return health - old_health  # Return actual amount healed


func is_offensive() -> bool:
	return get_category(type) == Category.OFFENSIVE


func is_defensive() -> bool:
	return get_category(type) == Category.DEFENSIVE


func can_intercept_at(target_pos: Vector2i) -> bool:
	if interception_range <= 0:
		return false
	if is_destroyed:
		return false
	# Check if target_pos is within interception_range of this structure
	var dx = abs(target_pos.x - grid_position.x)
	var dy = abs(target_pos.y - grid_position.y)
	return dx <= interception_range and dy <= interception_range


func is_transport() -> bool:
	return transport_capacity > 0


func is_turret() -> bool:
	return turret_range > 0


func is_ground_defense() -> bool:
	return get_category(type) == Category.GROUND_DEFENSE


func can_load_unit(unit: Resource) -> bool:
	if not is_transport():
		return false
	if is_destroyed:
		return false
	return carried_units.size() < transport_capacity


func load_unit(unit: Resource) -> bool:
	if not can_load_unit(unit):
		return false
	carried_units.append(unit)
	return true


func unload_all_units() -> Array:
	var units = carried_units.duplicate()
	carried_units.clear()
	return units


func get_carried_unit_count() -> int:
	return carried_units.size()


func can_target_ground_unit_at(target_pos: Vector2i) -> bool:
	if turret_range <= 0:
		return false
	if is_destroyed:
		return false
	var dx = abs(target_pos.x - grid_position.x)
	var dy = abs(target_pos.y - grid_position.y)
	return dx <= turret_range and dy <= turret_range
