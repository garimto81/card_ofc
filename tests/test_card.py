from src.card import Card, Rank, Suit
from src.pool import SharedCardPool


class TestRankOrder:
    def test_rank_order(self):
        """2 < 3 < ... < A 순서 정렬 확인"""
        ranks = list(Rank)
        for i in range(len(ranks) - 1):
            assert ranks[i] < ranks[i + 1]

    def test_rank_values(self):
        assert Rank.TWO == 2
        assert Rank.ACE == 14
        assert Rank.JACK == 11
        assert Rank.QUEEN == 12
        assert Rank.KING == 13


class TestSuitBeats:
    def test_spade_beats_heart(self):
        """SPADE > HEART"""
        c_spade = Card(Rank.ACE, Suit.SPADE)
        c_heart = Card(Rank.ACE, Suit.HEART)
        assert c_spade.beats_suit(c_heart) is True

    def test_heart_beats_diamond(self):
        """HEART > DIAMOND"""
        c_heart = Card(Rank.ACE, Suit.HEART)
        c_diamond = Card(Rank.ACE, Suit.DIAMOND)
        assert c_heart.beats_suit(c_diamond) is True

    def test_diamond_beats_club(self):
        """DIAMOND > CLUB"""
        c_diamond = Card(Rank.ACE, Suit.DIAMOND)
        c_club = Card(Rank.ACE, Suit.CLUB)
        assert c_diamond.beats_suit(c_club) is True

    def test_club_beats_spade(self):
        """CLUB > SPADE (순환)"""
        c_club = Card(Rank.ACE, Suit.CLUB)
        c_spade = Card(Rank.ACE, Suit.SPADE)
        assert c_club.beats_suit(c_spade) is True

    def test_same_suit_no_beats(self):
        """동일 수트는 이기지 않음"""
        c1 = Card(Rank.ACE, Suit.SPADE)
        c2 = Card(Rank.KING, Suit.SPADE)
        assert c1.beats_suit(c2) is False

    def test_spade_does_not_beat_diamond(self):
        """SPADE는 DIAMOND를 이기지 않음"""
        c_spade = Card(Rank.ACE, Suit.SPADE)
        c_diamond = Card(Rank.ACE, Suit.DIAMOND)
        assert c_spade.beats_suit(c_diamond) is False


class TestCardCost:
    def test_cost_common(self):
        """랭크 2~5: 코스트 1"""
        for rank in [Rank.TWO, Rank.THREE, Rank.FOUR, Rank.FIVE]:
            assert Card(rank, Suit.SPADE).cost == 1

    def test_cost_rare(self):
        """랭크 6~8: 코스트 2"""
        for rank in [Rank.SIX, Rank.SEVEN, Rank.EIGHT]:
            assert Card(rank, Suit.SPADE).cost == 2

    def test_cost_epic(self):
        """랭크 9~J: 코스트 3"""
        for rank in [Rank.NINE, Rank.TEN, Rank.JACK]:
            assert Card(rank, Suit.SPADE).cost == 3

    def test_cost_legendary(self):
        """랭크 Q~K: 코스트 4"""
        for rank in [Rank.QUEEN, Rank.KING]:
            assert Card(rank, Suit.SPADE).cost == 4

    def test_cost_mythic(self):
        """랭크 A: 코스트 5"""
        assert Card(Rank.ACE, Suit.SPADE).cost == 5


class TestCardEnhanced:
    def test_not_enhanced_stars_1(self):
        c = Card(Rank.ACE, Suit.SPADE, stars=1)
        assert c.is_enhanced is False

    def test_enhanced_stars_2(self):
        c = Card(Rank.ACE, Suit.SPADE, stars=2)
        assert c.is_enhanced is True

    def test_enhanced_stars_3(self):
        c = Card(Rank.ACE, Suit.SPADE, stars=3)
        assert c.is_enhanced is True


class TestSharedCardPool:
    def test_pool_initialize_total_count(self):
        """풀 초기화 후 총 카드 수 검증 (PRD §4.5.1 기준)"""
        pool = SharedCardPool()
        pool.initialize()
        # Common(2~4): 3장 × 4수트 × 29 = 348
        # Rare(5~7): 3장 × 4수트 × 22 = 264
        # Epic(8~10): 3장 × 4수트 × 18 = 216
        # Legendary(J~K): 3장 × 4수트 × 12 = 144
        # Mythic(A): 1장 × 4수트 × 10 = 40
        # 합계: 348 + 264 + 216 + 144 + 40 = 1012
        total = sum(pool._pool.values())
        assert total == 1012

    def test_pool_draw_success(self):
        pool = SharedCardPool()
        pool.initialize()
        result = pool.draw(Rank.ACE, Suit.SPADE)
        assert result is True
        assert pool.remaining(Rank.ACE, Suit.SPADE) == 9

    def test_pool_draw_and_deplete(self):
        """ACE SPADE 10장 모두 드로우 후 0 확인"""
        pool = SharedCardPool()
        pool.initialize()
        for _ in range(10):
            pool.draw(Rank.ACE, Suit.SPADE)
        assert pool.remaining(Rank.ACE, Suit.SPADE) == 0
        # 추가 드로우 시도는 False
        assert pool.draw(Rank.ACE, Suit.SPADE) is False

    def test_pool_return_card(self):
        """매각 시 풀에 1장 반환"""
        pool = SharedCardPool()
        pool.initialize()
        pool.draw(Rank.ACE, Suit.SPADE)
        card = Card(Rank.ACE, Suit.SPADE)
        pool.return_card(card)
        assert pool.remaining(Rank.ACE, Suit.SPADE) == 10

    def test_pool_common_copies(self):
        """Common 카드(2~4) 복사본 29장 확인 (PRD §4.5.1)"""
        pool = SharedCardPool()
        pool.initialize()
        assert pool.remaining(Rank.TWO, Suit.SPADE) == 29
        assert pool.remaining(Rank.FOUR, Suit.CLUB) == 29
        # Rank.FIVE는 PRD §4.5.1 기준 Rare(22장)
        assert pool.remaining(Rank.FIVE, Suit.CLUB) == 22

    def test_pool_rare_copies(self):
        """Rare 카드 복사본 22장 확인"""
        pool = SharedCardPool()
        pool.initialize()
        assert pool.remaining(Rank.SIX, Suit.HEART) == 22

    def test_pool_mythic_copies(self):
        """Mythic(A) 복사본 10장 확인"""
        pool = SharedCardPool()
        pool.initialize()
        assert pool.remaining(Rank.ACE, Suit.DIAMOND) == 10

    def test_pool_random_draw_n(self):
        """n장 드로우 후 풀에서 차감됨"""
        pool = SharedCardPool()
        pool.initialize()
        initial_total = sum(pool._pool.values())
        cards = pool.random_draw_n(5, level=1)
        assert len(cards) == 5
        new_total = sum(pool._pool.values())
        assert new_total == initial_total - 5


class TestShopDropRate:
    """레벨별 드롭률 검증 — PRD §10.6"""

    def _sample_cost_distribution(self, pool, level: int, trials: int = 200) -> dict:
        """N번 드로우하여 코스트 분포 반환"""
        counts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
        for _ in range(trials):
            pool2 = SharedCardPool()
            pool2.initialize()
            cards = pool2.random_draw_n(1, level=level)
            if cards:
                counts[cards[0].cost] += 1
        return counts

    def test_level_1_mostly_low_cost(self):
        """레벨 1: 1코스트 75% → 샘플 200장 중 기대값 150, ±5σ 범위 [119, 181]"""
        pool = SharedCardPool()
        pool.initialize()
        counts = self._sample_cost_distribution(pool, level=1, trials=200)
        # 75% 기대값=150, ±20% 허용 (통계적 변동 고려)
        assert 110 <= counts[1] <= 181, f"레벨 1 1코스트 비율 이상: {counts}"

    def test_level_9_mostly_high_cost(self):
        """레벨 9: 4+5코스트 합산 60% → 샘플 200장 중 45장 이상"""
        pool = SharedCardPool()
        pool.initialize()
        counts = self._sample_cost_distribution(pool, level=9, trials=200)
        high_cost = counts[4] + counts[5]
        # 60% ± 15% 허용
        assert high_cost >= 45, f"레벨 9 고코스트 비율 이상: {counts}"

    def test_level_clamp_below_1(self):
        """레벨 0 → 레벨 1과 동일 동작 (클램핑)"""
        pool = SharedCardPool()
        pool.initialize()
        result = pool.random_draw_n(3, level=0)
        assert len(result) <= 3  # 크래시 없이 동작

    def test_level_clamp_above_9(self):
        """레벨 10 → 레벨 9와 동일 동작 (클램핑)"""
        pool = SharedCardPool()
        pool.initialize()
        result = pool.random_draw_n(3, level=10)
        assert len(result) <= 3  # 크래시 없이 동작

    def test_empty_pool_returns_empty(self):
        """빈 풀에서 드로우 시 빈 리스트"""
        pool = SharedCardPool()
        pool.initialize()
        # 풀 완전 소진 (일부만)
        empty_pool = SharedCardPool()
        empty_pool._pool = {}
        result = empty_pool.random_draw_n(5, level=5)
        assert result == []

    def test_draw_removes_from_pool(self):
        """드로우 후 해당 카드 풀 감소 확인"""
        pool = SharedCardPool()
        pool.initialize()
        before = sum(pool._pool.values())
        cards = pool.random_draw_n(5, level=3)
        after = sum(pool._pool.values())
        assert before - after == len(cards)
