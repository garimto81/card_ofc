from dataclasses import dataclass
from enum import IntEnum


class Rank(IntEnum):
    TWO = 2
    THREE = 3
    FOUR = 4
    FIVE = 5
    SIX = 6
    SEVEN = 7
    EIGHT = 8
    NINE = 9
    TEN = 10
    JACK = 11
    QUEEN = 12
    KING = 13
    ACE = 14


class Suit(IntEnum):
    # 순환 우위: SPADE > HEART > DIAMOND > CLUB > SPADE
    CLUB = 1
    DIAMOND = 2
    HEART = 3
    SPADE = 4


@dataclass
class Card:
    rank: Rank
    suit: Suit
    stars: int = 1

    @property
    def is_enhanced(self) -> bool:
        return self.stars > 1

    @property
    def cost(self) -> int:
        if self.rank <= 5:
            return 1
        if self.rank <= 8:
            return 2
        if self.rank <= 11:
            return 3
        if self.rank <= 13:
            return 4
        return 5

    def beats_suit(self, other: 'Card') -> bool:
        """수트 순환 우위: SPADE>HEART>DIAMOND>CLUB>SPADE
        SPADE(4)>HEART(3)>DIAMOND(2)>CLUB(1)>SPADE(4)
        공식: (defender.value % 4) + 1 == attacker.value
        """
        return (other.suit.value % 4) + 1 == self.suit.value

    def __repr__(self) -> str:
        star_str = "*" * self.stars
        return f"{self.rank.name[:1]}{self.suit.name[:1]}{star_str}"

    def __hash__(self):
        return hash((self.rank, self.suit, self.stars))

    def __eq__(self, other):
        if not isinstance(other, Card):
            return False
        return self.rank == other.rank and self.suit == other.suit and self.stars == other.stars
