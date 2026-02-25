class_name SimpleAI
extends RefCounted

## 간단한 AI 플레이어
## 전략: 살 수 있는 카드 중 가장 비싼 것 구매 후 빈 슬롯에 배치

const LINE_SLOTS: Dictionary = {"back": 5, "mid": 5, "front": 3}
const LINE_ORDER = ["back", "mid", "front"]

func take_turn(
	economy: Economy,
	bench: Array,
	board: Dictionary,
	shop_cards: Array,
	pool: Pool
) -> Dictionary:
	## AI 턴 실행
	## 반환: {actions: Array, bench: Array, board: Dictionary}

	var actions: Array = []

	# 구매: 살 수 있는 카드 중 가장 비싼 것 하나만 구매
	var best_card = null
	for card in shop_cards:
		if card == null:
			continue
		if not economy.can_afford(card.cost):
			continue
		if pool.get_available(card.rank, card.suit) <= 0:
			continue
		if best_card == null or card.cost > best_card.cost:
			best_card = card

	if best_card != null:
		var drawn = pool.draw(best_card.rank, best_card.suit)
		if drawn != null:
			economy.spend_gold(best_card.cost)
			bench.append(drawn)
			actions.append({"type": "buy", "card": drawn})

	# 배치: bench의 카드를 board 빈 슬롯에 순서대로 배치
	# Back → Mid → Front 순서로 채움
	for line_name in LINE_ORDER:
		var current: Array = board.get(line_name, [])
		var max_slots = LINE_SLOTS[line_name]
		while current.size() < max_slots and not bench.is_empty():
			var card = bench.pop_front()
			current.append(card)
			actions.append({"type": "place", "card": card, "line": line_name})
		board[line_name] = current

	return {"actions": actions, "bench": bench, "board": board}
