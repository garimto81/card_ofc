from collections import Counter
from dataclasses import dataclass, field

from src.card import Card
from src.pool import SharedCardPool


@dataclass
class Player:
    name: str
    hp: int = 100
    gold: int = 0
    level: int = 1
    xp: int = 0
    board: object = None  # OFCBoard
    bench: list = field(default_factory=list)
    win_streak: int = 0
    loss_streak: int = 0
    hula_declared: bool = False
    augments: list = field(default_factory=list)  # List[Augment]
    in_fantasyland: bool = False
    fantasyland_next: bool = False

    def __post_init__(self):
        if self.board is None:
            from src.board import OFCBoard
            self.board = OFCBoard()

    def has_augment(self, augment_id: str) -> bool:
        """특정 id 증강체 보유 여부."""
        return any(a.id == augment_id for a in self.augments)

    def add_augment(self, augment) -> None:
        """증강체 추가. 동일 id 중복 허용 안 함."""
        if not self.has_augment(augment.id):
            self.augments.append(augment)

    def calc_interest(self) -> int:
        """이자 = min(floor(gold / 10), cap). economist 증강체 시 cap=6."""
        cap = 6 if self.has_augment("economist") else 5
        return min(self.gold // 10, cap)

    def enter_fantasyland(self) -> None:
        self.in_fantasyland = True

    def exit_fantasyland(self) -> None:
        self.in_fantasyland = False
        self.fantasyland_next = False

    def streak_bonus(self) -> int:
        """연승/연패 보너스 계산"""
        streak = max(self.win_streak, self.loss_streak)
        if streak >= 5:
            return 3
        elif streak >= 3:
            return 2
        elif streak >= 2:
            return 1
        return 0

    def round_income(self, base: int = 5) -> int:
        """라운드 수입: 기본 + 이자 + 연승/연패 보너스"""
        return base + self.calc_interest() + self.streak_bonus()

    def can_buy(self, card: Card) -> bool:
        """골드 충분 여부 확인"""
        return self.gold >= card.cost

    def buy_card(self, card: Card, pool: SharedCardPool) -> bool:
        """카드 구매: 골드 차감 + 풀에서 드로우 + 벤치 추가"""
        if not self.can_buy(card):
            return False
        if not pool.draw(card.rank, card.suit):
            return False
        self.gold -= card.cost
        self.bench.append(card)
        return True

    def sell_card(self, card: Card, pool: SharedCardPool) -> int:
        """카드 매각: 골드 반환 + 풀 반환"""
        if card not in self.bench:
            return 0
        sell_price = max(1, card.cost - 1)
        self.bench.remove(card)
        self.gold += sell_price
        pool.return_card(card)
        return sell_price

    def try_star_upgrade(self) -> 'Card | None':
        """같은 카드(랭크+수트) 3장 → 2성 합성 시도 (3성은 불가)"""
        key_counts = Counter(
            (c.rank, c.suit, c.stars) for c in self.bench if c.stars < 3
        )
        for (rank, suit, stars), count in key_counts.items():
            if count >= 3:
                # 3장 제거
                removed = 0
                remaining_bench = []
                for card in self.bench:
                    if (card.rank == rank and card.suit == suit
                            and card.stars == stars and removed < 3):
                        removed += 1
                    else:
                        remaining_bench.append(card)
                self.bench = remaining_bench
                new_card = Card(rank, suit, stars=stars + 1)
                self.bench.append(new_card)
                return new_card
        return None
