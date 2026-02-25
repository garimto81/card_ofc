class_name Card
extends RefCounted

## 트럼프 카드 데이터 클래스
## Python card.py 기반 GDScript 포팅

enum Rank {
	TWO = 2, THREE = 3, FOUR = 4, FIVE = 5,
	SIX = 6, SEVEN = 7, EIGHT = 8, NINE = 9,
	TEN = 10, JACK = 11, QUEEN = 12, KING = 13, ACE = 14
}

enum Suit {
	CLUB = 1, DIAMOND = 2, HEART = 3, SPADE = 4
}

var rank: int
var suit: int
var stars: int = 1

func _init(r: int, s: int, st: int = 1) -> void:
	rank = r
	suit = s
	stars = st

var is_enhanced: bool:
	get: return stars > 1

var cost: int:
	get:
		if rank <= 5: return 1
		if rank <= 8: return 2
		if rank <= 11: return 3
		if rank <= 13: return 4
		return 5  # ACE

func beats_suit(other: Card) -> bool:
	## 수트 순환 우위: SPADE>HEART>DIAMOND>CLUB>SPADE
	## 공식: (defender.suit % 4) + 1 == attacker.suit
	return (other.suit % 4) + 1 == self.suit

func rank_name() -> String:
	match rank:
		2: return "2"
		3: return "3"
		4: return "4"
		5: return "5"
		6: return "6"
		7: return "7"
		8: return "8"
		9: return "9"
		10: return "10"
		11: return "J"
		12: return "Q"
		13: return "K"
		14: return "A"
	return "?"

func suit_symbol() -> String:
	match suit:
		Suit.SPADE: return "♠"
		Suit.HEART: return "♥"
		Suit.DIAMOND: return "♦"
		Suit.CLUB: return "♣"
	return "?"

func is_red() -> bool:
	return suit == Suit.HEART or suit == Suit.DIAMOND

func _to_string() -> String:
	var star_str = "★".repeat(stars)
	return "%s%s%s" % [rank_name(), suit_symbol(), star_str]

func equals(other: Card) -> bool:
	return rank == other.rank and suit == other.suit and stars == other.stars

func same_type(other: Card) -> bool:
	## 별 강화용: 랭크+수트만 비교 (stars 무시)
	return rank == other.rank and suit == other.suit
