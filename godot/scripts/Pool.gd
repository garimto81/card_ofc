class_name Pool
extends RefCounted

## 공유 카드 풀
## Python pool.py (SharedCardPool) 기반 GDScript 포팅
## PRD §4.5.1, §10.6

# 레벨별 코스트 가중치 [cost1, cost2, cost3, cost4, cost5]
# Python pool.py _LEVEL_WEIGHTS 기반
const LEVEL_WEIGHTS: Dictionary = {
	1: [0.75, 0.20, 0.05, 0.00, 0.00],
	2: [0.75, 0.20, 0.05, 0.00, 0.00],
	3: [0.55, 0.30, 0.15, 0.00, 0.00],
	4: [0.55, 0.30, 0.15, 0.00, 0.00],
	5: [0.35, 0.35, 0.25, 0.05, 0.00],
	6: [0.20, 0.35, 0.30, 0.14, 0.01],
	7: [0.15, 0.25, 0.35, 0.20, 0.05],
	8: [0.10, 0.15, 0.35, 0.30, 0.10],
	9: [0.05, 0.10, 0.25, 0.35, 0.25]
}

# 풀 내부 저장: key = "rank_suit" (e.g. "2_1"), value = 남은 수량
var _pool: Dictionary = {}

func _init() -> void:
	initialize()

func initialize() -> void:
	## 52종 × 등급별 복사본 수로 초기화
	_pool = {}
	for r in range(2, 15):  # Rank.TWO(2) ~ Rank.ACE(14)
		var copies = _get_copy_count(r)
		for s in range(1, 5):  # Suit.CLUB(1) ~ Suit.SPADE(4)
			var key = _make_key(r, s)
			_pool[key] = copies

func _get_copy_count(rank: int) -> int:
	## PRD §4.5.1 등급별 복사본 수
	## Python _get_copy_count 기반
	if rank <= 4: return 29    # Common (2,3,4)
	elif rank <= 7: return 22  # Rare (5,6,7)
	elif rank <= 10: return 18 # Epic (8,9,10)
	elif rank <= 13: return 12 # Legendary (J,Q,K)
	return 10                  # Mythic (A)

func _make_key(rank: int, suit: int) -> String:
	return "%d_%d" % [rank, suit]

func draw(rank: int, suit: int) -> Card:
	## 풀에서 카드 1장 차감. 성공 시 Card 반환, 실패 시 null
	var key = _make_key(rank, suit)
	var remaining = _pool.get(key, 0)
	if remaining > 0:
		_pool[key] = remaining - 1
		return Card.new(rank, suit)
	return null

func return_card(card: Card) -> void:
	## 매각 시 풀에 1장 반환
	var key = _make_key(card.rank, card.suit)
	_pool[key] = _pool.get(key, 0) + 1

func get_available(rank: int, suit: int) -> int:
	## 특정 카드 잔여 수 반환
	return _pool.get(_make_key(rank, suit), 0)

func random_draw_n(n: int, level: int = 1) -> Array:
	## 레벨 기반 코스트 가중치로 n장 무작위 드로우 (PRD §10.6)
	## Python random_draw_n 로직 포팅

	level = clampi(level, 1, 9)
	var weights_by_cost: Array = LEVEL_WEIGHTS[level]

	# 코스트 티어별 가용 카드 분류 (cost 1~5 → index 0~4)
	var cost_buckets: Array = [[], [], [], [], []]
	for key in _pool:
		var count = _pool[key]
		if count > 0:
			var parts = key.split("_")
			var r = int(parts[0])
			var s = int(parts[1])
			var temp_card = Card.new(r, s)
			var cost_idx = temp_card.cost - 1  # 0-indexed
			cost_buckets[cost_idx].append({"rank": r, "suit": s})

	# 가용 카드가 없는 티어 확률 재분배
	var effective_weights: Array = weights_by_cost.duplicate()
	var total_removed: float = 0.0
	var available_indices: Array = []

	for i in range(5):
		if cost_buckets[i].is_empty():
			total_removed += effective_weights[i]
			effective_weights[i] = 0.0
		else:
			available_indices.append(i)

	if not available_indices.is_empty() and total_removed > 0.0:
		var per_tier = total_removed / float(available_indices.size())
		for i in available_indices:
			effective_weights[i] += per_tier

	if available_indices.is_empty():
		return []

	# 누적 가중치 계산 (weighted random selection용)
	var cumulative: Array = []
	var cum = 0.0
	for w in effective_weights:
		cum += w
		cumulative.append(cum)

	var selected: Array = []
	for _i in range(n):
		# 코스트 티어 가중치 선택
		var rng = randf() * cumulative[4]
		var chosen_tier = 4
		for t in range(5):
			if rng <= cumulative[t]:
				chosen_tier = t
				break

		var bucket: Array = cost_buckets[chosen_tier]
		if bucket.is_empty():
			# 방어: 다른 티어에서 선택
			var all_available: Array = []
			for b in cost_buckets:
				all_available.append_array(b)
			if all_available.is_empty():
				break
			var fallback = all_available[randi() % all_available.size()]
			# 프리뷰 전용 — 풀에서 실제 차감 없음 (buy_card에서 draw 호출)
			selected.append(Card.new(fallback["rank"], fallback["suit"]))
			for b in cost_buckets:
				b.erase(fallback)
		else:
			var entry = bucket[randi() % bucket.size()]
			# 프리뷰 전용 — 풀에서 실제 차감 없음 (buy_card에서 draw 호출)
			selected.append(Card.new(entry["rank"], entry["suit"]))
			bucket.erase(entry)  # 동일 라운드 상점 내 중복 방지

	return selected
