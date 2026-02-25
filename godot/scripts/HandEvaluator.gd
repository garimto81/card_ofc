class_name HandEvaluator
extends RefCounted

## 포커 핸드 평가기
## Python hand.py 기반 GDScript 포팅
## Front(3장): THREE_OF_A_KIND/ONE_PAIR/HIGH_CARD만
## Back/Mid(5장): 모든 핸드 타입 가능

enum HandType {
	HIGH_CARD = 1,
	ONE_PAIR = 2,
	TWO_PAIR = 3,
	THREE_OF_A_KIND = 4,
	STRAIGHT = 5,
	FLUSH = 6,
	FULL_HOUSE = 7,
	FOUR_OF_A_KIND = 8,
	STRAIGHT_FLUSH = 9,
	ROYAL_FLUSH = 10
}

## 핸드 평가 결과 딕셔너리 키:
## hand_type: HandType enum 값 (int)
## enhanced_count: 강화 카드 수 (stars > 1)
## dominant_suit: 대표 수트 (Card.Suit int)
## high_card_rank: 최고 랭크 (int)
## cards: 원본 카드 배열

func evaluate_hand(cards: Array) -> Dictionary:
	## 카드 배열에서 최강 포커 핸드 판정
	if cards.is_empty():
		return {
			"hand_type": HandType.HIGH_CARD,
			"enhanced_count": 0,
			"dominant_suit": Card.Suit.CLUB,
			"high_card_rank": Card.Rank.TWO,
			"cards": []
		}

	var n = cards.size()

	# 랭크별 카드 수 집계
	var rank_counts: Dictionary = {}
	for card in cards:
		rank_counts[card.rank] = rank_counts.get(card.rank, 0) + 1

	# 수트별 카드 수 집계
	var suit_counts: Dictionary = {}
	for card in cards:
		suit_counts[card.suit] = suit_counts.get(card.suit, 0) + 1

	# 랭크를 내림차순 정렬
	var ranks = rank_counts.keys()
	ranks.sort_custom(func(a, b): return a > b)

	# 5장일 때만 플러시/스트레이트 판정
	var is_flush = false
	var is_straight = false

	if n >= 5:
		var max_suit_count = 0
		for cnt in suit_counts.values():
			if cnt > max_suit_count:
				max_suit_count = cnt
		is_flush = max_suit_count >= 5

		if rank_counts.size() == 5:
			var rank_vals: Array = rank_counts.keys()
			rank_vals.sort()
			var min_val = rank_vals[0]
			var max_val = rank_vals[rank_vals.size() - 1]
			if max_val - min_val == 4:
				is_straight = true
			else:
				# A-2-3-4-5 로우 스트레이트 판정
				var rank_set = {}
				for rv in rank_vals:
					rank_set[rv] = true
				if rank_set.has(14) and rank_set.has(2) and rank_set.has(3) \
						and rank_set.has(4) and rank_set.has(5):
					is_straight = true

	# 핸드 타입 결정
	var hand_type: int
	var count_values: Array = rank_counts.values()
	var pair_count = count_values.count(2)
	var has_three = count_values.has(3)
	var has_four = count_values.has(4)

	if n >= 5:
		if is_flush and is_straight:
			var rank_vals_2: Array = rank_counts.keys()
			rank_vals_2.sort()
			var rv_set = {}
			for rv in rank_vals_2:
				rv_set[rv] = true
			if rv_set.has(10) and rv_set.has(11) and rv_set.has(12) \
					and rv_set.has(13) and rv_set.has(14):
				hand_type = HandType.ROYAL_FLUSH
			else:
				hand_type = HandType.STRAIGHT_FLUSH
		elif has_four:
			hand_type = HandType.FOUR_OF_A_KIND
		elif has_three and pair_count >= 1:
			hand_type = HandType.FULL_HOUSE
		elif is_flush:
			hand_type = HandType.FLUSH
		elif is_straight:
			hand_type = HandType.STRAIGHT
		elif has_three:
			hand_type = HandType.THREE_OF_A_KIND
		elif pair_count == 2:
			hand_type = HandType.TWO_PAIR
		elif pair_count == 1:
			hand_type = HandType.ONE_PAIR
		else:
			hand_type = HandType.HIGH_CARD
	else:
		# 3장 이하 (Front 라인): 스트레이트/플러시 등 불가
		if has_three:
			hand_type = HandType.THREE_OF_A_KIND
		elif pair_count >= 1:
			hand_type = HandType.ONE_PAIR
		else:
			hand_type = HandType.HIGH_CARD

	var enhanced_count = 0
	for card in cards:
		if card.is_enhanced:
			enhanced_count += 1

	var dominant_suit = _calc_dominant_suit(cards, suit_counts, hand_type, rank_counts)
	var high_card_rank = ranks[0] if not ranks.is_empty() else Card.Rank.TWO

	return {
		"hand_type": hand_type,
		"enhanced_count": enhanced_count,
		"dominant_suit": dominant_suit,
		"high_card_rank": high_card_rank,
		"cards": cards
	}


func _calc_dominant_suit(
	cards: Array,
	suit_counts: Dictionary,
	hand_type: int,
	rank_counts: Dictionary
) -> int:
	## dominant_suit 계산: Python _calc_dominant_suit 로직 포팅

	# 풀하우스: 스리카인드 파트의 수트
	if hand_type == HandType.FULL_HOUSE:
		var three_rank = -1
		for r in rank_counts:
			if rank_counts[r] == 3:
				three_rank = r
				break
		if three_rank != -1:
			var three_suit_counts: Dictionary = {}
			for card in cards:
				if card.rank == three_rank:
					three_suit_counts[card.suit] = three_suit_counts.get(card.suit, 0) + 1
			var best_suit = -1
			var best_cnt = -1
			for s in three_suit_counts:
				if three_suit_counts[s] > best_cnt:
					best_cnt = three_suit_counts[s]
					best_suit = s
			if best_suit != -1:
				return best_suit

	# 가장 많이 보유한 수트
	var sorted_suits = suit_counts.keys()
	sorted_suits.sort_custom(func(a, b): return suit_counts[a] > suit_counts[b])

	if sorted_suits.size() == 1:
		return sorted_suits[0]

	var top_count = suit_counts[sorted_suits[0]]
	var second_count = suit_counts[sorted_suits[1]]

	if top_count > second_count:
		return sorted_suits[0]

	# 동수 시: 더 높은 랭크 카드가 속한 수트
	var tied_count = top_count
	var tied_suits: Dictionary = {}
	for s in suit_counts:
		if suit_counts[s] == tied_count:
			tied_suits[s] = true

	var sorted_cards = cards.duplicate()
	sorted_cards.sort_custom(func(a, b): return a.rank > b.rank)

	for card in sorted_cards:
		if tied_suits.has(card.suit):
			return card.suit

	return sorted_suits[0]


func compare_hands(h1: Dictionary, h2: Dictionary) -> int:
	## +1: h1 승, -1: h2 승, 0: 무승부
	## 1단계: 핸드 강도 비교
	if h1["hand_type"] != h2["hand_type"]:
		return 1 if h1["hand_type"] > h2["hand_type"] else -1

	# 2단계: 강화 카드 수 비교
	if h1["enhanced_count"] != h2["enhanced_count"]:
		return 1 if h1["enhanced_count"] > h2["enhanced_count"] else -1

	# 3단계: 수트 순환 우위 비교
	var s1 = h1["dominant_suit"]
	var s2 = h2["dominant_suit"]
	if s1 != s2:
		if _beats_suit(s1, s2):
			return 1
		if _beats_suit(s2, s1):
			return -1

	# 4단계: 최고 랭크 비교
	if h1["high_card_rank"] != h2["high_card_rank"]:
		return 1 if h1["high_card_rank"] > h2["high_card_rank"] else -1

	return 0


func _beats_suit(attacker: int, defender: int) -> bool:
	## 수트 순환 우위: (defender % 4) + 1 == attacker
	return (defender % 4) + 1 == attacker


func apply_foul_penalty(hand: Dictionary) -> Dictionary:
	## Foul 발생 라인의 HandType -1등급 강등 (최하 HIGH_CARD=1 유지)
	var new_type = max(1, hand["hand_type"] - 1)
	return {
		"hand_type": new_type,
		"enhanced_count": hand["enhanced_count"],
		"dominant_suit": hand["dominant_suit"],
		"high_card_rank": hand["high_card_rank"],
		"cards": hand["cards"]
	}


func hand_type_name(hand_type: int) -> String:
	match hand_type:
		HandType.HIGH_CARD: return "하이카드"
		HandType.ONE_PAIR: return "원 페어"
		HandType.TWO_PAIR: return "투 페어"
		HandType.THREE_OF_A_KIND: return "트리플"
		HandType.STRAIGHT: return "스트레이트"
		HandType.FLUSH: return "플러시"
		HandType.FULL_HOUSE: return "풀하우스"
		HandType.FOUR_OF_A_KIND: return "포카인드"
		HandType.STRAIGHT_FLUSH: return "스트레이트 플러시"
		HandType.ROYAL_FLUSH: return "로열 플러시"
	return "알 수 없음"
