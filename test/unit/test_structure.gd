extends GutTest
## Tests for Structure resource class.

const Structure = preload("res://scripts/resources/structure.gd")


# --- Factory Tests ---

func test_create_hq():
	var s = Structure.create(Structure.Type.BASE, Vector2i(2, 1))
	assert_eq(s.type, Structure.Type.BASE, "Type should be BASE")
	assert_eq(s.grid_position, Vector2i(2, 1), "Position should be set")
	assert_eq(s.health, 3, "BASE should have 3 health")
	assert_eq(s.attack_priority, 0, "BASE priority should be 0")


func test_create_condiment_cannon():
	var s = Structure.create(Structure.Type.CONDIMENT_CANNON)
	assert_eq(s.type, Structure.Type.CONDIMENT_CANNON, "Type should be CONDIMENT_CANNON")
	assert_eq(s.health, 1, "Cannon should have 1 health")
	assert_eq(s.attack_priority, 50, "Cannon priority should be 50")


func test_create_pickle_interceptor():
	var s = Structure.create(Structure.Type.PICKLE_INTERCEPTOR)
	assert_eq(s.type, Structure.Type.PICKLE_INTERCEPTOR, "Type should be PICKLE_INTERCEPTOR")
	assert_eq(s.health, 1, "Interceptor should have 1 health")
	assert_eq(s.attack_priority, 100, "Interceptor priority should be 100")


# --- Abbreviation Tests ---

func test_abbreviation_hq():
	assert_eq(Structure.get_abbreviation(Structure.Type.BASE), "BASE", "BASE abbreviation")


func test_abbreviation_cannon():
	assert_eq(Structure.get_abbreviation(Structure.Type.CONDIMENT_CANNON), "CC", "Cannon abbreviation")


func test_abbreviation_interceptor():
	assert_eq(Structure.get_abbreviation(Structure.Type.PICKLE_INTERCEPTOR), "PI", "Interceptor abbreviation")


# --- Category Tests ---

func test_hq_is_critical():
	var cat = Structure.get_category(Structure.Type.BASE)
	assert_eq(cat, Structure.Category.CRITICAL, "BASE should be CRITICAL")


func test_cannon_is_offensive():
	var cat = Structure.get_category(Structure.Type.CONDIMENT_CANNON)
	assert_eq(cat, Structure.Category.OFFENSIVE, "Cannon should be OFFENSIVE")


func test_interceptor_is_defensive():
	var cat = Structure.get_category(Structure.Type.PICKLE_INTERCEPTOR)
	assert_eq(cat, Structure.Category.DEFENSIVE, "Interceptor should be DEFENSIVE")


func test_is_offensive_helper():
	var cannon = Structure.create(Structure.Type.CONDIMENT_CANNON)
	var interceptor = Structure.create(Structure.Type.PICKLE_INTERCEPTOR)
	assert_true(cannon.is_offensive(), "Cannon should be offensive")
	assert_false(interceptor.is_offensive(), "Interceptor should not be offensive")


func test_is_defensive_helper():
	var cannon = Structure.create(Structure.Type.CONDIMENT_CANNON)
	var interceptor = Structure.create(Structure.Type.PICKLE_INTERCEPTOR)
	assert_false(cannon.is_defensive(), "Cannon should not be defensive")
	assert_true(interceptor.is_defensive(), "Interceptor should be defensive")


# --- Damage Tests ---

func test_take_damage_reduces_health():
	var s = Structure.create(Structure.Type.BASE)  # 3 health
	s.take_damage(1)
	assert_eq(s.health, 2, "Health should be reduced by 1")


func test_take_damage_destroys_at_zero():
	var s = Structure.create(Structure.Type.CONDIMENT_CANNON)  # 1 health
	var destroyed = s.take_damage(1)
	assert_true(destroyed, "take_damage should return true when destroyed")
	assert_true(s.is_destroyed, "is_destroyed should be true")


func test_take_damage_returns_false_when_alive():
	var s = Structure.create(Structure.Type.BASE)  # 3 health
	var destroyed = s.take_damage(1)
	assert_false(destroyed, "take_damage should return false when still alive")
	assert_false(s.is_destroyed, "is_destroyed should be false")


# --- Priority Ordering Tests ---

func test_interceptor_has_highest_priority():
	var cannon = Structure.create(Structure.Type.CONDIMENT_CANNON)
	var interceptor = Structure.create(Structure.Type.PICKLE_INTERCEPTOR)
	assert_gt(interceptor.attack_priority, cannon.attack_priority,
		"Interceptor should have higher priority than cannon")


# --- Color Tests ---

func test_each_type_has_distinct_color():
	var hq_color = Structure.get_color(Structure.Type.BASE)
	var cc_color = Structure.get_color(Structure.Type.CONDIMENT_CANNON)
	var pi_color = Structure.get_color(Structure.Type.PICKLE_INTERCEPTOR)

	assert_ne(hq_color, cc_color, "BASE and Cannon should have different colors")
	assert_ne(hq_color, pi_color, "BASE and Interceptor should have different colors")
	assert_ne(cc_color, pi_color, "Cannon and Interceptor should have different colors")
