from collections import Counter
from dataclasses import dataclass, field

from src.card import Card
from src.pool import SharedCardPool

# 레벨별 필요 XP 테이블 (레벨 9는 최대)
_XP_TABLE: dict[int, int] = {1: 2, 2: 4, 3: 6, 4: 10, 5: 20, 6: 36, 7: 56, 8: 80}


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
    shop_cards: list = field(default_factory=list)
    pineapple_cards: list = field(default_factory=list)
    pool: object = None  # SharedCardPool

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
        self.try_star_upgrade()
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

    def apply_damage(self, amount: int) -> None:
        """HP 차감. 음수 방지 (최소 0)."""
        self.hp = max(0, self.hp - amount)

    def calc_roll_cost(self, club_synergy_level: int = 0) -> int:
        """♣ 사냥 시너지 레벨에 따른 리롤 비용 반환.
        레벨0~1: 2골드, 레벨2: 1골드, 레벨3: 0골드(무료)
        """
        if club_synergy_level >= 3:
            return 0
        elif club_synergy_level >= 2:
            return 1
        return 2

    def pineapple_pick(self, indices: list) -> None:
        """2장 선택 → bench 이동, 나머지 1장 → pool 반환."""
        if len(indices) != 2:
            raise ValueError(f"Pineapple pick requires exactly 2 indices, got {len(indices)}")
        if any(i < 0 or i >= len(self.pineapple_cards) for i in indices):
            raise IndexError("Invalid pineapple index")
        kept = [self.pineapple_cards[i] for i in sorted(set(indices))]
        discarded = [c for i, c in enumerate(self.pineapple_cards) if i not in set(indices)]
        self.bench.extend(kept)
        for card in discarded:
            if self.pool is not None:
                self.pool.return_card(card)
        self.pineapple_cards = []

    def auto_discard_pineapple(self) -> None:
        """미픽 pineapple_cards 전부 풀 반환 (ready 시 자동 호출)."""
        for card in self.pineapple_cards:
            if self.pool is not None:
                self.pool.return_card(card)
        self.pineapple_cards = []

    def buy_xp(self, cost: int = 4) -> bool:
        """XP 구매: cost 골드 소모 → XP +cost 획득 → 자동 레벨업 체크.
        레벨 9(최대)이거나 골드 부족 시 False 반환.
        """
        if self.level >= 9:
            return False
        if self.gold < cost:
            return False
        self.gold -= cost
        self.xp += cost
        self._try_level_up()
        return True

    def _try_level_up(self) -> None:
        """XP 임계값 충족 시 자동 레벨업. 초과 XP 이월. 연속 레벨업 처리."""
        while self.level < 9 and self.xp >= _XP_TABLE[self.level]:
            self.xp -= _XP_TABLE[self.level]
            self.level += 1

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
