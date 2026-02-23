import random
from dataclasses import dataclass, field

from src.card import Card, Rank, Suit

# PRD §10.6 레벨별 코스트 확률 테이블 [1코스트, 2코스트, 3코스트, 4코스트, 5코스트]
_LEVEL_WEIGHTS: dict[int, list[float]] = {
    1: [0.75, 0.20, 0.05, 0.00, 0.00],
    2: [0.75, 0.20, 0.05, 0.00, 0.00],
    3: [0.55, 0.30, 0.15, 0.00, 0.00],
    4: [0.55, 0.30, 0.15, 0.00, 0.00],
    5: [0.35, 0.35, 0.25, 0.05, 0.00],
    6: [0.20, 0.35, 0.30, 0.14, 0.01],
    7: [0.15, 0.25, 0.35, 0.20, 0.05],
    8: [0.10, 0.15, 0.35, 0.30, 0.10],
    9: [0.05, 0.10, 0.25, 0.35, 0.25],
}


def _get_copy_count(rank: Rank) -> int:
    # PRD §4.5.1 풀 구조: Common(2~4), Rare(5~7), Epic(8~10), Legendary(J~K), Mythic(A)
    if rank <= 4:
        return 29   # Common (2,3,4)
    elif rank <= 7:
        return 22   # Rare (5,6,7)
    elif rank <= 10:
        return 18   # Epic (8,9,10)
    elif rank <= 13:
        return 12   # Legendary (J,Q,K)
    return 10       # Mythic (A)


@dataclass
class SharedCardPool:
    _pool: dict = field(default_factory=dict)

    def initialize(self) -> None:
        """52종 × 등급별 복사본 수로 초기화"""
        self._pool = {}
        for rank in Rank:
            copies = _get_copy_count(rank)
            for suit in Suit:
                self._pool[(rank, suit)] = copies

    def draw(self, rank: Rank, suit: Suit) -> bool:
        """풀에서 카드 1장 차감. 실패 시 False"""
        key = (rank, suit)
        if self._pool.get(key, 0) > 0:
            self._pool[key] -= 1
            return True
        return False

    def return_card(self, card: Card) -> None:
        """매각 시 풀에 1장 반환"""
        key = (card.rank, card.suit)
        self._pool[key] = self._pool.get(key, 0) + 1

    def remaining(self, rank: Rank, suit: Suit) -> int:
        """특정 카드 잔여 수 반환"""
        return self._pool.get((rank, suit), 0)

    def random_draw_n(self, n: int, level: int = 1) -> list:
        """레벨 기반 코스트 가중치로 n장 무작위 드로우 (PRD §10.6)"""
        # 레벨 범위 클램핑
        level = max(1, min(9, level))
        weights_by_cost = _LEVEL_WEIGHTS[level]

        # 코스트 티어별 가용 카드 분류 (Card.cost == 1~5)
        cost_buckets: list[list] = [[] for _ in range(5)]
        for (rank, suit), count in self._pool.items():
            if count > 0:
                card = Card(rank, suit)
                cost_idx = card.cost - 1  # 0-indexed
                cost_buckets[cost_idx].append(card)

        # 가용 카드가 없는 티어 확률 재분배
        effective_weights = list(weights_by_cost)
        total_removed = 0.0
        available_indices = []
        for i, bucket in enumerate(cost_buckets):
            if not bucket:
                total_removed += effective_weights[i]
                effective_weights[i] = 0.0
            else:
                available_indices.append(i)

        # 재분배: 제거된 확률을 가용 티어에 균등 분배
        if available_indices and total_removed > 0:
            per_tier = total_removed / len(available_indices)
            for i in available_indices:
                effective_weights[i] += per_tier

        # 모든 티어가 비어있으면 빈 리스트
        if not available_indices:
            return []

        selected = []
        for _ in range(n):
            # 1장씩 코스트 티어 선택 → 티어 내 카드 무작위 선택
            chosen_tier_idx = random.choices(
                range(5), weights=effective_weights, k=1
            )[0]
            bucket = cost_buckets[chosen_tier_idx]
            if not bucket:
                # 방어: 재분배 후에도 빈 경우 다른 티어에서 선택
                all_available = [c for b in cost_buckets for c in b]
                if not all_available:
                    break
                card = random.choice(all_available)
            else:
                card = random.choice(bucket)

            # 풀에서 차감
            if self.draw(card.rank, card.suit):
                selected.append(card)
                bucket.remove(card)  # 동일 루프에서 중복 선택 방지

        return selected
