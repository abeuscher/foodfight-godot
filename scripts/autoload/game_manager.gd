extends Node
## GameManager singleton - tracks game state, turns, and win/lose conditions.

enum GameState { PLANNING, EXECUTING, GAME_OVER }
enum Winner { NONE, PLAYER, ENEMY }

signal state_changed(new_state: GameState)
signal turn_started(turn_number: int)
signal game_over(winner: Winner)

var current_state: GameState = GameState.PLANNING:
	set(value):
		if current_state != value:
			current_state = value
			state_changed.emit(current_state)

var turn_number: int = 1
var winner: Winner = Winner.NONE


func _ready() -> void:
	reset_game()


func reset_game() -> void:
	current_state = GameState.PLANNING
	turn_number = 1
	winner = Winner.NONE


func start_execution() -> void:
	if current_state == GameState.PLANNING:
		current_state = GameState.EXECUTING


func end_execution() -> void:
	if current_state == GameState.EXECUTING:
		if winner == Winner.NONE:
			turn_number += 1
			turn_started.emit(turn_number)
			current_state = GameState.PLANNING
		else:
			current_state = GameState.GAME_OVER


func set_winner(who: Winner) -> void:
	if winner == Winner.NONE and who != Winner.NONE:
		winner = who
		game_over.emit(winner)


func is_game_over() -> bool:
	return current_state == GameState.GAME_OVER


func is_planning() -> bool:
	return current_state == GameState.PLANNING


func is_executing() -> bool:
	return current_state == GameState.EXECUTING
