## 디버그 테스트 - Combat 라인 결과 확인
extends SceneTree

func _init():
	var ev = HandEvaluator.new()
	var combat = Combat.new()

	var b1 = {
		"back": [Card.new(Card.Rank.ACE,Card.Suit.SPADE), Card.new(Card.Rank.ACE,Card.Suit.HEART),
				 Card.new(Card.Rank.ACE,Card.Suit.DIAMOND), Card.new(Card.Rank.KING,Card.Suit.SPADE),
				 Card.new(Card.Rank.QUEEN,Card.Suit.HEART)],
		"mid":  [Card.new(Card.Rank.KING,Card.Suit.SPADE), Card.new(Card.Rank.KING,Card.Suit.HEART),
				 Card.new(Card.Rank.TWO,Card.Suit.DIAMOND), Card.new(Card.Rank.THREE,Card.Suit.CLUB),
				 Card.new(Card.Rank.FOUR,Card.Suit.SPADE)],
		"front":[Card.new(Card.Rank.QUEEN,Card.Suit.SPADE), Card.new(Card.Rank.QUEEN,Card.Suit.HEART),
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

	print("=== 핸드 분석 ===")
	for line_name in ["back", "mid", "front"]:
		var h1 = ev.evaluate_hand(b1[line_name])
		var h2 = ev.evaluate_hand(b2[line_name])
		var cmp = ev.compare_hands(h1, h2)
		print("  %s: b1_type=%d b2_type=%d compare=%d" % [line_name, h1["hand_type"], h2["hand_type"], cmp])

	print("\n=== Foul 확인 ===")
	var foul1 = combat.check_foul_public(b1)
	var foul2 = combat.check_foul_public(b2)
	print("  b1 foul:", foul1)
	print("  b2 foul:", foul2)

	print("\n=== resolve 결과 ===")
	var res = combat.resolve(b1, b2, 1)
	print("  lines_won:", res["lines_won"])
	print("  lines_lost:", res["lines_lost"])
	print("  damage:", res["damage"])
	print("  scoop:", res["scoop"])
	print("  hula:", res["hula"])
	print("  line_results:", res["line_results"])

	quit(0)
