## Trump Card Auto Chess — 게임 로직 통합 테스트
## 실행: godot --headless --rendering-driver dummy --path . --script test_logic.gd

extends SceneTree

var _passed: int = 0
var _failed: int = 0

func _assert(name: String, condition: bool) -> void:
	if condition:
		print("  ✓ %s" % name)
		_passed += 1
	else:
		print("  ✗ FAIL: %s" % name)
		_failed += 1

func _init():
	print("=== Trump Card Auto Chess 로직 테스트 ===\n")

	# ── 1. Card 테스트 ───────────────────────
	print("■ Card 테스트")
	var ace_s  = Card.new(Card.Rank.ACE,  Card.Suit.SPADE)
	var two_c  = Card.new(Card.Rank.TWO,  Card.Suit.CLUB)
	var king_h = Card.new(Card.Rank.KING, Card.Suit.HEART, 2)

	_assert("ACE 코스트=5",  ace_s.cost  == 5)
	_assert("TWO 코스트=1",  two_c.cost  == 1)
	_assert("KING 코스트=4", king_h.cost == 4)
	_assert("2성 enhanced",  king_h.is_enhanced)
	_assert("♠ beats ♥",    ace_s.beats_suit(Card.new(Card.Rank.ACE, Card.Suit.HEART)))
	_assert("♥ beats ♦",    Card.new(2, Card.Suit.HEART).beats_suit(Card.new(2, Card.Suit.DIAMOND)))
	_assert("♦ beats ♣",    Card.new(2, Card.Suit.DIAMOND).beats_suit(Card.new(2, Card.Suit.CLUB)))
	_assert("♣ beats ♠",    Card.new(2, Card.Suit.CLUB).beats_suit(Card.new(2, Card.Suit.SPADE)))

	# ── 2. HandEvaluator 테스트 ─────────────
	print("\n■ HandEvaluator 테스트")
	var ev = HandEvaluator.new()

	var royal = [Card.new(Card.Rank.ACE,Card.Suit.SPADE), Card.new(Card.Rank.KING,Card.Suit.SPADE),
				 Card.new(Card.Rank.QUEEN,Card.Suit.SPADE), Card.new(Card.Rank.JACK,Card.Suit.SPADE),
				 Card.new(Card.Rank.TEN,Card.Suit.SPADE)]
	_assert("로열 플러시=10", ev.evaluate_hand(royal)["hand_type"] == HandEvaluator.HandType.ROYAL_FLUSH)

	var four_aces = [Card.new(Card.Rank.ACE,Card.Suit.SPADE), Card.new(Card.Rank.ACE,Card.Suit.HEART),
					 Card.new(Card.Rank.ACE,Card.Suit.DIAMOND), Card.new(Card.Rank.ACE,Card.Suit.CLUB),
					 Card.new(Card.Rank.KING,Card.Suit.SPADE)]
	_assert("포카인드=8", ev.evaluate_hand(four_aces)["hand_type"] == HandEvaluator.HandType.FOUR_OF_A_KIND)

	var fh = [Card.new(Card.Rank.ACE,Card.Suit.SPADE), Card.new(Card.Rank.ACE,Card.Suit.HEART),
			  Card.new(Card.Rank.ACE,Card.Suit.DIAMOND), Card.new(Card.Rank.KING,Card.Suit.CLUB),
			  Card.new(Card.Rank.KING,Card.Suit.SPADE)]
	_assert("풀하우스=7", ev.evaluate_hand(fh)["hand_type"] == HandEvaluator.HandType.FULL_HOUSE)

	var low_str = [Card.new(Card.Rank.ACE,Card.Suit.SPADE), Card.new(Card.Rank.TWO,Card.Suit.HEART),
				   Card.new(Card.Rank.THREE,Card.Suit.DIAMOND), Card.new(Card.Rank.FOUR,Card.Suit.CLUB),
				   Card.new(Card.Rank.FIVE,Card.Suit.SPADE)]
	_assert("로우 스트레이트=5", ev.evaluate_hand(low_str)["hand_type"] == HandEvaluator.HandType.STRAIGHT)

	var front3 = [Card.new(Card.Rank.ACE,Card.Suit.SPADE), Card.new(Card.Rank.KING,Card.Suit.HEART),
				  Card.new(Card.Rank.QUEEN,Card.Suit.DIAMOND)]
	_assert("Front 3장=하이카드", ev.evaluate_hand(front3)["hand_type"] == HandEvaluator.HandType.HIGH_CARD)

	var pair_h = ev.evaluate_hand([Card.new(Card.Rank.ACE,Card.Suit.SPADE),
								   Card.new(Card.Rank.ACE,Card.Suit.HEART),
								   Card.new(Card.Rank.TWO,Card.Suit.CLUB)])
	var high_h = ev.evaluate_hand([Card.new(Card.Rank.KING,Card.Suit.SPADE),
								   Card.new(Card.Rank.QUEEN,Card.Suit.HEART),
								   Card.new(Card.Rank.JACK,Card.Suit.DIAMOND)])
	_assert("원페어 > 하이카드", ev.compare_hands(pair_h, high_h) == 1)

	var flush_h = ev.evaluate_hand([Card.new(Card.Rank.ACE,Card.Suit.SPADE),
									Card.new(Card.Rank.KING,Card.Suit.SPADE),
									Card.new(Card.Rank.QUEEN,Card.Suit.SPADE),
									Card.new(Card.Rank.JACK,Card.Suit.SPADE),
									Card.new(Card.Rank.NINE,Card.Suit.SPADE)])
	var pen = ev.apply_foul_penalty(flush_h)
	_assert("Foul 플러시→스트레이트", pen["hand_type"] == HandEvaluator.HandType.STRAIGHT)

	# ── 3. Economy 테스트 ───────────────────
	print("\n■ Economy 테스트")
	var eco = Economy.new()
	eco.earn_gold(50)
	_assert("이자=5 (50G)", eco.calc_interest() == 5)
	eco.gold = 20
	_assert("이자=2 (20G)", eco.calc_interest() == 2)
	eco.win_streak = 2
	_assert("2연승 보너스=1", eco.streak_bonus() == 1)
	eco.win_streak = 4
	_assert("4연승 보너스=2", eco.streak_bonus() == 2)
	eco.win_streak = 5
	_assert("5연승 보너스=3", eco.streak_bonus() == 3)
	eco.gold = 20; eco.win_streak = 5
	_assert("수입=10 (5+2+3)", eco.round_income() == 10)

	var eco2 = Economy.new()
	eco2.earn_gold(10)
	eco2.buy_xp()  # 4G -> xp+4, lv1 needs 2 -> lv2
	_assert("레벨2 도달", eco2.level == 2)
	_assert("잔여골드=6", eco2.gold == 6)

	# ── 4. Pool 테스트 ──────────────────────
	print("\n■ Pool 테스트")
	var pool = Pool.new()
	var ace_spade_count = pool.get_available(Card.Rank.ACE, Card.Suit.SPADE)
	_assert("ACE♠ 초기 > 0", ace_spade_count > 0)

	var d = pool.draw(Card.Rank.ACE, Card.Suit.SPADE)
	_assert("ACE♠ draw 성공", d != null)
	_assert("draw 후 감소", pool.get_available(Card.Rank.ACE, Card.Suit.SPADE) == ace_spade_count - 1)
	pool.return_card(d)
	_assert("반환 후 복구", pool.get_available(Card.Rank.ACE, Card.Suit.SPADE) == ace_spade_count)

	var before = pool.get_available(Card.Rank.TWO, Card.Suit.CLUB)
	var preview = pool.random_draw_n(5, 1)
	_assert("프리뷰 5장", preview.size() == 5)
	_assert("프리뷰는 풀 불변", pool.get_available(Card.Rank.TWO, Card.Suit.CLUB) == before)

	# ── 5. Combat 테스트 ────────────────────
	print("\n■ Combat 테스트")
	var combat = Combat.new()

	var b1 = {
		"back":  [Card.new(Card.Rank.ACE,Card.Suit.SPADE), Card.new(Card.Rank.ACE,Card.Suit.HEART),
				  Card.new(Card.Rank.ACE,Card.Suit.DIAMOND), Card.new(Card.Rank.KING,Card.Suit.SPADE),
				  Card.new(Card.Rank.KING,Card.Suit.HEART)],  # AAA KK = FULL_HOUSE(7) > STRAIGHT(5)
		"mid":   [Card.new(Card.Rank.KING,Card.Suit.SPADE), Card.new(Card.Rank.KING,Card.Suit.HEART),
				  Card.new(Card.Rank.TWO,Card.Suit.DIAMOND), Card.new(Card.Rank.THREE,Card.Suit.CLUB),
				  Card.new(Card.Rank.FOUR,Card.Suit.SPADE)],
		"front": [Card.new(Card.Rank.QUEEN,Card.Suit.SPADE), Card.new(Card.Rank.QUEEN,Card.Suit.HEART),
				  Card.new(Card.Rank.TWO,Card.Suit.DIAMOND)]
	}
	var b2 = {
		"back":  [Card.new(Card.Rank.TEN,Card.Suit.SPADE), Card.new(Card.Rank.NINE,Card.Suit.HEART),
				  Card.new(Card.Rank.EIGHT,Card.Suit.DIAMOND), Card.new(Card.Rank.SEVEN,Card.Suit.CLUB),
				  Card.new(Card.Rank.SIX,Card.Suit.SPADE)],
		"mid":   [Card.new(Card.Rank.FIVE,Card.Suit.SPADE), Card.new(Card.Rank.FOUR,Card.Suit.HEART),
				  Card.new(Card.Rank.THREE,Card.Suit.DIAMOND), Card.new(Card.Rank.TWO,Card.Suit.CLUB),
				  Card.new(Card.Rank.TWO,Card.Suit.SPADE)],
		"front": [Card.new(Card.Rank.JACK,Card.Suit.SPADE), Card.new(Card.Rank.TEN,Card.Suit.HEART),
				  Card.new(Card.Rank.NINE,Card.Suit.DIAMOND)]
	}
	var res = combat.resolve(b1, b2, 1)
	_assert("3라인 모두 승리", res["lines_won"] == 3 and res["lines_lost"] == 0)
	_assert("스쿠프 감지", res["scoop"])
	_assert("훌라 감지", res["hula"])
	_assert("데미지 > 0", res["damage"] > 0)
	print("  ℹ 데미지값: %d" % res["damage"])

	# ── 결과 ────────────────────────────────
	print("\n=== 결과: %d/%d PASS ===" % [_passed, _passed + _failed])
	if _failed > 0:
		print("FAIL: %d 테스트 실패!" % _failed)
		quit(1)
	else:
		print("ALL PASS — Godot MVP 로직 검증 완료! ✓")
		quit(0)
