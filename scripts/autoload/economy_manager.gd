extends Node
## EconomyManager singleton - tracks money for both player and enemy.

signal money_changed(side: String, new_amount: int)
signal purchase_made(side: String, item_name: String, cost: int)
signal income_earned(side: String, amount: int, reason: String)

const PLAYER_STARTING_MONEY: int = 30
const ENEMY_STARTING_MONEY: int = 0  # Enemy has fixed arsenal, no economy
const MONEY_PER_DAMAGE: int = 5  # $5 per HP damage dealt

var player_money: int = PLAYER_STARTING_MONEY:
	set(value):
		var old_value = player_money
		player_money = max(0, value)
		if player_money != old_value:
			money_changed.emit("player", player_money)

var enemy_money: int = ENEMY_STARTING_MONEY:
	set(value):
		var old_value = enemy_money
		enemy_money = max(0, value)
		if enemy_money != old_value:
			money_changed.emit("enemy", enemy_money)


func _ready() -> void:
	reset()


func reset() -> void:
	player_money = PLAYER_STARTING_MONEY
	enemy_money = ENEMY_STARTING_MONEY


func get_money(side: String) -> int:
	if side == "player":
		return player_money
	elif side == "enemy":
		return enemy_money
	return 0


func can_afford(side: String, cost: int) -> bool:
	return get_money(side) >= cost


func spend(side: String, cost: int, item_name: String = "") -> bool:
	if not can_afford(side, cost):
		return false

	if side == "player":
		player_money -= cost
	elif side == "enemy":
		enemy_money -= cost
	else:
		return false

	purchase_made.emit(side, item_name, cost)
	return true


func earn(side: String, amount: int, reason: String = "") -> void:
	if side == "player":
		player_money += amount
	elif side == "enemy":
		enemy_money += amount

	income_earned.emit(side, amount, reason)


func earn_from_damage(side: String, damage_dealt: int) -> void:
	var amount = damage_dealt * MONEY_PER_DAMAGE
	earn(side, amount, "damage")


func add_passive_income(side: String, amount: int) -> void:
	earn(side, amount, "passive")


func refund(side: String, amount: int) -> void:
	earn(side, amount, "refund")
