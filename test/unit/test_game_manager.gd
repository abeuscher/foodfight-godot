extends GutTest
## Tests for GameManager singleton.

var gm: Node


func before_each() -> void:
	# Create a fresh instance for testing (don't use the autoload directly)
	gm = load("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(gm)


# --- State Transition Tests ---

func test_initial_state_is_planning():
	assert_eq(gm.current_state, gm.GameState.PLANNING, "Game should start in PLANNING state")


func test_start_execution_changes_state():
	gm.start_execution()
	assert_eq(gm.current_state, gm.GameState.EXECUTING, "State should be EXECUTING after start_execution()")


func test_end_execution_returns_to_planning():
	gm.start_execution()
	gm.end_execution()
	assert_eq(gm.current_state, gm.GameState.PLANNING, "State should return to PLANNING after end_execution()")


func test_cannot_start_execution_when_not_planning():
	gm.start_execution()  # Now EXECUTING
	gm.start_execution()  # Should have no effect
	assert_eq(gm.current_state, gm.GameState.EXECUTING, "State should remain EXECUTING")


func test_game_over_state_after_winner_set():
	gm.start_execution()
	gm.set_winner(gm.Winner.PLAYER)
	gm.end_execution()
	assert_eq(gm.current_state, gm.GameState.GAME_OVER, "State should be GAME_OVER when winner exists")


func test_state_changed_signal_emitted():
	watch_signals(gm)
	gm.start_execution()
	assert_signal_emitted(gm, "state_changed", "state_changed signal should emit on transition")


# --- Turn Counter Tests ---

func test_initial_turn_is_one():
	assert_eq(gm.turn_number, 1, "Turn counter should start at 1")


func test_turn_increments_after_execution():
	gm.start_execution()
	gm.end_execution()
	assert_eq(gm.turn_number, 2, "Turn counter should increment after execution ends")


func test_turn_does_not_increment_on_game_over():
	gm.start_execution()
	gm.set_winner(gm.Winner.ENEMY)
	gm.end_execution()
	assert_eq(gm.turn_number, 1, "Turn counter should not increment when game ends")


func test_turn_started_signal_emitted():
	var result = {"turn": -1}
	gm.turn_started.connect(func(turn): result.turn = turn)
	gm.start_execution()
	gm.end_execution()
	assert_eq(result.turn, 2, "turn_started should emit with new turn number")


# --- Win/Lose Tests ---

func test_initial_winner_is_none():
	assert_eq(gm.winner, gm.Winner.NONE, "Winner should be NONE initially")


func test_set_winner_player():
	gm.set_winner(gm.Winner.PLAYER)
	assert_eq(gm.winner, gm.Winner.PLAYER, "Winner should be PLAYER after set_winner(PLAYER)")


func test_set_winner_enemy():
	gm.set_winner(gm.Winner.ENEMY)
	assert_eq(gm.winner, gm.Winner.ENEMY, "Winner should be ENEMY after set_winner(ENEMY)")


func test_winner_cannot_change_once_set():
	gm.set_winner(gm.Winner.PLAYER)
	gm.set_winner(gm.Winner.ENEMY)
	assert_eq(gm.winner, gm.Winner.PLAYER, "Winner should not change once set")


func test_game_over_signal_emitted():
	var result = {"winner": gm.Winner.NONE}
	gm.game_over.connect(func(w): result.winner = w)
	gm.set_winner(gm.Winner.PLAYER)
	assert_eq(result.winner, gm.Winner.PLAYER, "game_over should emit with winner")


func test_is_game_over_helper():
	assert_false(gm.is_game_over(), "is_game_over() should be false initially")
	gm.start_execution()
	gm.set_winner(gm.Winner.PLAYER)
	gm.end_execution()
	assert_true(gm.is_game_over(), "is_game_over() should be true after game ends")


# --- Reset Tests ---

func test_reset_game_restores_initial_state():
	gm.start_execution()
	gm.set_winner(gm.Winner.PLAYER)
	gm.end_execution()

	gm.reset_game()

	assert_eq(gm.current_state, gm.GameState.PLANNING, "State should be PLANNING after reset")
	assert_eq(gm.turn_number, 1, "Turn should be 1 after reset")
	assert_eq(gm.winner, gm.Winner.NONE, "Winner should be NONE after reset")
