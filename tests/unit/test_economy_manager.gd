extends GutTest
## Unit tests for EconomyManager autoload.

var economy: Node


func before_each() -> void:
	# Create a fresh instance for testing
	economy = preload("res://scripts/autoload/economy_manager.gd").new()
	economy.reset()


func after_each() -> void:
	economy.free()


func test_initial_money() -> void:
	assert_eq(economy.player_money, 10, "Player should start with $10")
	assert_eq(economy.enemy_money, 10, "Enemy should start with $10")


func test_get_money() -> void:
	assert_eq(economy.get_money("player"), 10)
	assert_eq(economy.get_money("enemy"), 10)
	assert_eq(economy.get_money("invalid"), 0)


func test_can_afford() -> void:
	assert_true(economy.can_afford("player", 10), "Should afford exactly $10")
	assert_true(economy.can_afford("player", 5), "Should afford $5")
	assert_false(economy.can_afford("player", 11), "Should not afford $11")


func test_spend_success() -> void:
	var result = economy.spend("player", 5, "test item")
	assert_true(result, "Spend should succeed")
	assert_eq(economy.player_money, 5, "Should have $5 remaining")


func test_spend_failure_insufficient_funds() -> void:
	var result = economy.spend("player", 15, "expensive item")
	assert_false(result, "Spend should fail")
	assert_eq(economy.player_money, 10, "Money should be unchanged")


func test_spend_invalid_side() -> void:
	var result = economy.spend("invalid", 5, "test")
	assert_false(result, "Spend should fail for invalid side")


func test_earn() -> void:
	economy.earn("player", 10, "bonus")
	assert_eq(economy.player_money, 20, "Should have $20 after earning")

	economy.earn("enemy", 5, "bonus")
	assert_eq(economy.enemy_money, 15, "Enemy should have $15")


func test_earn_from_damage() -> void:
	economy.earn_from_damage("player", 1)
	assert_eq(economy.player_money, 15, "1 HP damage = $5")

	economy.earn_from_damage("player", 3)
	assert_eq(economy.player_money, 30, "3 HP damage = $15 more")


func test_add_passive_income() -> void:
	economy.add_passive_income("player", 5)
	assert_eq(economy.player_money, 15, "Should have $15 after passive income")


func test_money_cannot_go_negative() -> void:
	economy.player_money = -10
	assert_eq(economy.player_money, 0, "Money should not go negative")


func test_reset() -> void:
	economy.player_money = 100
	economy.enemy_money = 50
	economy.reset()
	assert_eq(economy.player_money, 10, "Player money reset to $10")
	assert_eq(economy.enemy_money, 10, "Enemy money reset to $10")


func test_money_changed_signal_emitted() -> void:
	watch_signals(economy)
	economy.player_money = 20
	assert_signal_emitted(economy, "money_changed")


func test_purchase_made_signal_emitted() -> void:
	watch_signals(economy)
	economy.spend("player", 5, "test item")
	assert_signal_emitted(economy, "purchase_made")


func test_income_earned_signal_emitted() -> void:
	watch_signals(economy)
	economy.earn("player", 10, "test bonus")
	assert_signal_emitted(economy, "income_earned")
