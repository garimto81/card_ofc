class_name GameController
extends Node

## 메인 게임 컨트롤러
## 게임 상태 관리, 페이즈 전환, 경제/전투 조율

signal state_changed(state: String)
signal combat_done(result: Dictionary)
signal round_started(round_num: int)
signal player_hp_changed(hp: int)
signal ai_hp_changed(hp: int)
signal shop_refreshed(cards: Array)

enum Phase { PREP, COMBAT, RESULT }

var pool: Pool
var player_economy: Economy
var ai_economy: Economy
var player_bench: Array = []
var ai_bench: Array = []
var player_board: Dictionary = {"back": [], "mid": [], "front": []}
var ai_board: Dictionary = {"back": [], "mid": [], "front": []}
var player_shop: Array = []
var player_hp: int = 100
var ai_hp: int = 100
var round_num: int = 1
var current_phase: Phase = Phase.PREP
var ai: SimpleAI
var evaluator: HandEvaluator
var combat: Combat

func _ready() -> void:
	pool = Pool.new()
	player_economy = Economy.new()
	ai_economy = Economy.new()
	ai = SimpleAI.new()
	evaluator = HandEvaluator.new()
	combat = Combat.new()

func start_game() -> void:
	round_num = 1
	player_hp = 100
	ai_hp = 100
	player_economy = Economy.new()
	ai_economy = Economy.new()
	player_board = {"back": [], "mid": [], "front": []}
	ai_board = {"back": [], "mid": [], "front": []}
	player_bench = []
	ai_bench = []
	pool = Pool.new()
	start_prep_phase()

func start_prep_phase() -> void:
	current_phase = Phase.PREP
	var income = player_economy.round_income()
	player_economy.earn_gold(income)
	var ai_income = ai_economy.round_income()
	ai_economy.earn_gold(ai_income)
	refresh_shop()
	emit_signal("round_started", round_num)
	emit_signal("state_changed", "prep")

func refresh_shop() -> void:
	player_shop = pool.random_draw_n(5, player_economy.level)
	emit_signal("shop_refreshed", player_shop)

func reroll_shop() -> bool:
	if not player_economy.spend_gold(2):
		return false
	refresh_shop()
	return true

func buy_card(card_index: int) -> bool:
	if card_index < 0 or card_index >= player_shop.size():
		return false
	var card = player_shop[card_index]
	if card == null:
		return false
	if not player_economy.spend_gold(card.cost):
		return false
	var drawn = pool.draw(card.rank, card.suit)
	if drawn == null:
		player_economy.earn_gold(card.cost)
		return false
	player_shop[card_index] = null
	player_bench.append(drawn)
	_check_star_upgrade()
	return true

func sell_card_from_bench(bench_index: int) -> bool:
	if bench_index < 0 or bench_index >= player_bench.size():
		return false
	var card = player_bench[bench_index]
	player_bench.remove_at(bench_index)
	pool.return_card(card)
	player_economy.earn_gold(max(1, card.cost - 1))
	return true

func place_card(bench_index: int, line_name: String, _slot_index: int = -1) -> bool:
	if bench_index < 0 or bench_index >= player_bench.size():
		return false
	var line: Array = player_board.get(line_name, [])
	var max_slots = 3 if line_name == "front" else 5
	if line.size() >= max_slots:
		return false
	var card = player_bench[bench_index]
	player_bench.remove_at(bench_index)
	line.append(card)
	player_board[line_name] = line
	return true

func remove_from_board(line_name: String, slot_index: int) -> bool:
	var line: Array = player_board.get(line_name, [])
	if slot_index < 0 or slot_index >= line.size():
		return false
	var card = line[slot_index]
	line.remove_at(slot_index)
	player_board[line_name] = line
	player_bench.append(card)
	return true

func _check_star_upgrade() -> void:
	## 벤치에서 동일 rank+suit+stars 3장 발견 시 stars+1 합성 (최대 3성)
	var found = true
	while found:
		found = false
		var key_counts: Dictionary = {}
		for card in player_bench:
			if card.stars < 3:
				var key = "%d_%d_%d" % [card.rank, card.suit, card.stars]
				key_counts[key] = key_counts.get(key, 0) + 1
		for key in key_counts:
			if key_counts[key] >= 3:
				var parts = key.split("_")
				var r = int(parts[0])
				var s = int(parts[1])
				var st = int(parts[2])
				var removed = 0
				var new_bench: Array = []
				for card in player_bench:
					if card.rank == r and card.suit == s and card.stars == st and removed < 3:
						removed += 1
					else:
						new_bench.append(card)
				player_bench = new_bench
				var new_card = Card.new(r, s, st + 1)
				player_bench.append(new_card)
				found = true
				break

func start_combat() -> void:
	current_phase = Phase.COMBAT
	emit_signal("state_changed", "combat")
	var ai_shop = pool.random_draw_n(5, ai_economy.level)
	var ai_result = ai.take_turn(ai_economy, ai_bench, ai_board, ai_shop, pool)
	ai_bench = ai_result.get("bench", ai_bench)
	ai_board = ai_result.get("board", ai_board)
	var result = combat.resolve(player_board, ai_board, round_num)
	_apply_combat_result(result)

func _apply_combat_result(result: Dictionary) -> void:
	var lines_won: int = result.get("lines_won", 0)
	var lines_lost: int = result.get("lines_lost", 0)
	if lines_won > lines_lost:
		player_economy.record_win()
		ai_economy.record_loss()
		ai_hp = max(0, ai_hp - result.get("damage", 0))
		emit_signal("ai_hp_changed", ai_hp)
	elif lines_lost > lines_won:
		player_economy.record_loss()
		ai_economy.record_win()
		player_hp = max(0, player_hp - result.get("damage", 0))
		emit_signal("player_hp_changed", player_hp)
	else:
		player_economy.record_draw()
		ai_economy.record_draw()
	emit_signal("combat_done", result)
	current_phase = Phase.RESULT

func end_round() -> void:
	for line_name in ["back", "mid", "front"]:
		for card in player_board.get(line_name, []):
			pool.return_card(card)
		player_board[line_name] = []
		for card in ai_board.get(line_name, []):
			pool.return_card(card)
		ai_board[line_name] = []
	round_num += 1
	if player_hp <= 0 or ai_hp <= 0:
		emit_signal("state_changed", "game_over")
	else:
		start_prep_phase()
