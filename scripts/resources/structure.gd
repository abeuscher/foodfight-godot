class_name Structure
extends Resource
## Base data class for all placeable structures.

enum Type { BASE, HOT_DOG_CANNON, CONDIMENT_CANNON, CONDIMENT_STATION, PICKLE_INTERCEPTOR, COFFEE_RADAR, VEGGIE_CANNON, LEMONADE_STAND, SALAD_BAR, RADAR_JAMMER }
enum Category { CRITICAL, OFFENSIVE, DEFENSIVE }

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
@export var grid_position: Vector2i = Vector2i(-1, -1)

var is_destroyed: bool = false
var is_jammed: bool = false  # For radars - when jammed, they cannot detect missiles
var jam_turns_remaining: int = 0  # Turns until jam wears off (0 = not jammed)


static func get_abbreviation(structure_type: Type) -> String:
	match structure_type:
		Type.BASE:
			return "B"
		Type.HOT_DOG_CANNON:
			return "HD"
		Type.CONDIMENT_CANNON:
			return "CC"
		Type.CONDIMENT_STATION:
			return "CS"
		Type.PICKLE_INTERCEPTOR:
			return "PI"
		Type.COFFEE_RADAR:
			return "CR"
		Type.VEGGIE_CANNON:
			return "VC"
		Type.LEMONADE_STAND:
			return "LS"
		Type.SALAD_BAR:
			return "SB"
		Type.RADAR_JAMMER:
			return "RJ"
	return "??"


static func get_display_name(structure_type: Type) -> String:
	match structure_type:
		Type.BASE:
			return "Base"
		Type.HOT_DOG_CANNON:
			return "Hot Dog Cannon"
		Type.CONDIMENT_CANNON:
			return "Condiment Cannon"
		Type.CONDIMENT_STATION:
			return "Condiment Station"
		Type.PICKLE_INTERCEPTOR:
			return "Pickle Interceptor"
		Type.COFFEE_RADAR:
			return "Coffee Cup Radar"
		Type.VEGGIE_CANNON:
			return "Veggie Cannon"
		Type.LEMONADE_STAND:
			return "Lemonade Stand"
		Type.SALAD_BAR:
			return "Salad Bar"
		Type.RADAR_JAMMER:
			return "Radar Jammer"
	return "Unknown"


static func get_category(structure_type: Type) -> Category:
	match structure_type:
		Type.BASE:
			return Category.CRITICAL
		Type.HOT_DOG_CANNON:
			return Category.OFFENSIVE
		Type.CONDIMENT_CANNON:
			return Category.OFFENSIVE
		Type.CONDIMENT_STATION:
			return Category.OFFENSIVE
		Type.PICKLE_INTERCEPTOR:
			return Category.DEFENSIVE
		Type.COFFEE_RADAR:
			return Category.DEFENSIVE
		Type.VEGGIE_CANNON:
			return Category.DEFENSIVE
		Type.LEMONADE_STAND:
			return Category.CRITICAL  # Economic building
		Type.SALAD_BAR:
			return Category.DEFENSIVE  # Support building
		Type.RADAR_JAMMER:
			return Category.OFFENSIVE  # Anti-defense weapon
	return Category.CRITICAL


static func get_default_priority(structure_type: Type) -> int:
	match structure_type:
		Type.BASE:
			return 0  # Base doesn't attack
		Type.HOT_DOG_CANNON:
			return 50  # Medium priority
		Type.CONDIMENT_CANNON:
			return 50  # Medium priority
		Type.CONDIMENT_STATION:
			return 40  # Slightly lower - area attacks after direct
		Type.PICKLE_INTERCEPTOR:
			return 100  # High priority - intercepts first
		Type.COFFEE_RADAR:
			return 0  # Doesn't attack
		Type.VEGGIE_CANNON:
			return 90  # High priority for defense
		Type.LEMONADE_STAND:
			return 0  # Doesn't attack
		Type.SALAD_BAR:
			return 0  # Doesn't attack
		Type.RADAR_JAMMER:
			return 120  # Highest priority - jams radar before other attacks
	return 0


static func get_color(structure_type: Type) -> Color:
	match structure_type:
		Type.BASE:
			return Color(0.9, 0.75, 0.2)  # Gold
		Type.HOT_DOG_CANNON:
			return Color(0.85, 0.45, 0.2)  # Orange (hot dog)
		Type.CONDIMENT_CANNON:
			return Color(0.8, 0.3, 0.3)  # Red
		Type.CONDIMENT_STATION:
			return Color(0.9, 0.8, 0.2)  # Mustard yellow
		Type.PICKLE_INTERCEPTOR:
			return Color(0.3, 0.7, 0.4)  # Green
		Type.COFFEE_RADAR:
			return Color(0.5, 0.35, 0.2)  # Brown (coffee)
		Type.VEGGIE_CANNON:
			return Color(0.2, 0.6, 0.2)  # Dark green
		Type.LEMONADE_STAND:
			return Color(1.0, 0.95, 0.3)  # Bright yellow
		Type.SALAD_BAR:
			return Color(0.4, 0.8, 0.4)  # Light green
		Type.RADAR_JAMMER:
			return Color(0.6, 0.2, 0.8)  # Purple (electronic warfare)
	return Color.WHITE


static func get_cost(structure_type: Type) -> int:
	match structure_type:
		Type.BASE:
			return 0  # Free
		Type.HOT_DOG_CANNON:
			return 5
		Type.CONDIMENT_CANNON:
			return 5  # Same as hot dog cannon
		Type.CONDIMENT_STATION:
			return 10
		Type.PICKLE_INTERCEPTOR:
			return 5
		Type.COFFEE_RADAR:
			return 10
		Type.VEGGIE_CANNON:
			return 5
		Type.LEMONADE_STAND:
			return 20
		Type.SALAD_BAR:
			return 20
		Type.RADAR_JAMMER:
			return 15  # Specialized anti-radar weapon
	return 0


static func create(structure_type: Type, pos: Vector2i = Vector2i(-1, -1)) -> Resource:
	var script = load("res://scripts/resources/structure.gd")
	var s = script.new()
	s.type = structure_type
	s.grid_position = pos
	s.attack_priority = get_default_priority(structure_type)
	match structure_type:
		Type.BASE:
			s.health = 3
		Type.HOT_DOG_CANNON:
			s.health = 1
			s.attack_damage = 1
		Type.CONDIMENT_CANNON:
			s.health = 1
			s.attack_damage = 1
		Type.CONDIMENT_STATION:
			s.health = 2
			s.attack_damage = 1
			s.area_attack_radius = 1  # 3x3 area attack
		Type.PICKLE_INTERCEPTOR:
			s.health = 1
			s.interception_range = 1  # Marker that this can intercept (actual range from radar)
		Type.COFFEE_RADAR:
			s.health = 2
			s.radar_range = 20  # Detection radius - silos can intercept within this zone
		Type.VEGGIE_CANNON:
			s.health = 1
			s.interception_range = 1  # Marker that this can intercept (actual range from radar)
		Type.LEMONADE_STAND:
			s.health = 2
			s.income_per_turn = 5  # $5 per turn
		Type.SALAD_BAR:
			s.health = 2
			s.heal_radius = 1  # 3x3 area
			s.heal_amount = 1  # 1 HP per turn
		Type.RADAR_JAMMER:
			s.health = 1
			s.attack_damage = 0  # Doesn't deal damage, just jams
			s.jam_radius = 5  # Jams radars within 5 blocks of impact
	s.max_health = s.health  # Set max health after initial health is set
	return s


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
