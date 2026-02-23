from src.card import Card, Rank, Suit
from src.economy import Player
from src.pool import SharedCardPool


class TestInterestCalculation:
    def test_interest_0_gold(self):
        player = Player(name="P1")
        player.gold = 0
        assert player.calc_interest() == 0

    def test_interest_9_gold(self):
        player = Player(name="P1")
        player.gold = 9
        assert player.calc_interest() == 0

    def test_interest_10_gold(self):
        player = Player(name="P1")
        player.gold = 10
        assert player.calc_interest() == 1

    def test_interest_20_gold(self):
        player = Player(name="P1")
        player.gold = 20
        assert player.calc_interest() == 2

    def test_interest_35_gold(self):
        player = Player(name="P1")
        player.gold = 35
        assert player.calc_interest() == 3

    def test_interest_40_gold(self):
        player = Player(name="P1")
        player.gold = 40
        assert player.calc_interest() == 4

    def test_interest_50_gold(self):
        player = Player(name="P1")
        player.gold = 50
        assert player.calc_interest() == 5

    def test_interest_cap_at_5(self):
        """100골드도 이자 최대 5"""
        player = Player(name="P1")
        player.gold = 100
        assert player.calc_interest() == 5

    def test_interest_cap_200(self):
        player = Player(name="P1")
        player.gold = 200
        assert player.calc_interest() == 5


class TestStreakBonus:
    def test_streak_bonus_0(self):
        player = Player(name="P1")
        player.win_streak = 0
        assert player.streak_bonus() == 0

    def test_streak_bonus_1(self):
        player = Player(name="P1")
        player.win_streak = 1
        assert player.streak_bonus() == 0

    def test_streak_bonus_2(self):
        player = Player(name="P1")
        player.win_streak = 2
        assert player.streak_bonus() == 1

    def test_streak_bonus_3(self):
        player = Player(name="P1")
        player.win_streak = 3
        assert player.streak_bonus() == 2

    def test_streak_bonus_4(self):
        player = Player(name="P1")
        player.win_streak = 4
        assert player.streak_bonus() == 2

    def test_streak_bonus_5(self):
        player = Player(name="P1")
        player.win_streak = 5
        assert player.streak_bonus() == 3

    def test_streak_bonus_loss(self):
        """연패도 동일하게 보너스 적용"""
        player = Player(name="P1")
        player.loss_streak = 3
        assert player.streak_bonus() == 2

    def test_streak_bonus_win_takes_max(self):
        """연승/연패 중 더 큰 값 기준"""
        player = Player(name="P1")
        player.win_streak = 2
        player.loss_streak = 5
        assert player.streak_bonus() == 3


class TestRoundIncome:
    def test_round_income_base_zero_gold(self):
        """0골드, 연승 0 → 수입 5"""
        player = Player(name="P1", gold=0)
        assert player.round_income() == 5

    def test_round_income_with_interest(self):
        """20골드 → 5 + 2 이자 = 7"""
        player = Player(name="P1", gold=20)
        assert player.round_income() == 7

    def test_round_income_with_streak(self):
        """10골드 보유, 연승 3 → 5 + 1 이자 + 2 보너스 = 8"""
        player = Player(name="P1", gold=10)
        player.win_streak = 3
        assert player.round_income() == 8

    def test_round_income_max(self):
        """50골드 이상 + 연승 5+ → 5 + 5 이자 + 3 보너스 = 13"""
        player = Player(name="P1", gold=60)
        player.win_streak = 5
        assert player.round_income() == 13


class TestBuyAndSell:
    def test_buy_card_success(self):
        pool = SharedCardPool()
        pool.initialize()
        player = Player(name="P1", gold=5)
        card = Card(Rank.ACE, Suit.SPADE)  # cost=5
        assert player.buy_card(card, pool) is True
        assert player.gold == 0
        assert card in player.bench

    def test_buy_card_insufficient_gold(self):
        pool = SharedCardPool()
        pool.initialize()
        player = Player(name="P1", gold=3)
        card = Card(Rank.ACE, Suit.SPADE)  # cost=5
        assert player.buy_card(card, pool) is False
        assert card not in player.bench

    def test_buy_card_pool_empty(self):
        """풀에 카드 없을 때 구매 실패"""
        pool = SharedCardPool()
        pool.initialize()
        card = Card(Rank.ACE, Suit.SPADE)
        # ACE SPADE 10장 모두 소진
        for _ in range(10):
            pool.draw(Rank.ACE, Suit.SPADE)
        player = Player(name="P1", gold=10)
        assert player.buy_card(card, pool) is False

    def test_can_buy_true(self):
        player = Player(name="P1", gold=5)
        card = Card(Rank.ACE, Suit.SPADE)
        assert player.can_buy(card) is True

    def test_can_buy_false(self):
        player = Player(name="P1", gold=4)
        card = Card(Rank.ACE, Suit.SPADE)
        assert player.can_buy(card) is False

    def test_sell_card_returns_gold(self):
        pool = SharedCardPool()
        pool.initialize()
        player = Player(name="P1", gold=5)
        card = Card(Rank.ACE, Suit.SPADE)  # cost=5, sell=4
        player.buy_card(card, pool)
        initial_gold = player.gold
        sell_price = player.sell_card(card, pool)
        assert sell_price == 4
        assert player.gold == initial_gold + 4

    def test_sell_card_pool_return(self):
        """매각 시 풀에 1장 반환"""
        pool = SharedCardPool()
        pool.initialize()
        initial_remaining = pool.remaining(Rank.ACE, Suit.SPADE)
        player = Player(name="P1", gold=5)
        card = Card(Rank.ACE, Suit.SPADE)
        player.buy_card(card, pool)
        player.sell_card(card, pool)
        assert pool.remaining(Rank.ACE, Suit.SPADE) == initial_remaining

    def test_sell_card_not_in_bench(self):
        """벤치에 없는 카드 매각 → 0 반환"""
        pool = SharedCardPool()
        pool.initialize()
        player = Player(name="P1", gold=5)
        card = Card(Rank.ACE, Suit.SPADE)
        result = player.sell_card(card, pool)
        assert result == 0

    def test_sell_common_card_cost_1(self):
        """cost=1 카드 매각 → sell_price=1 (max(1, cost-1))"""
        pool = SharedCardPool()
        pool.initialize()
        player = Player(name="P1", gold=1)
        card = Card(Rank.TWO, Suit.SPADE)  # cost=1
        player.buy_card(card, pool)
        sell_price = player.sell_card(card, pool)
        assert sell_price == 1


class TestStarUpgrade:
    def test_star_upgrade_1to2(self):
        """같은 카드(랭크+수트) 3장 → 2성"""
        pool = SharedCardPool()
        pool.initialize()
        player = Player(name="P1", gold=15)
        card1 = Card(Rank.ACE, Suit.SPADE)
        card2 = Card(Rank.ACE, Suit.SPADE)
        card3 = Card(Rank.ACE, Suit.SPADE)
        player.bench = [card1, card2, card3]
        upgraded = player.try_star_upgrade()
        assert upgraded is not None
        assert upgraded.stars == 2
        assert upgraded.rank == Rank.ACE
        assert upgraded.suit == Suit.SPADE
        # 3장 소모 → 2성 1장
        assert len(player.bench) == 1

    def test_star_upgrade_2to3(self):
        """2성 3장 → 3성"""
        player = Player(name="P1")
        card1 = Card(Rank.KING, Suit.HEART, stars=2)
        card2 = Card(Rank.KING, Suit.HEART, stars=2)
        card3 = Card(Rank.KING, Suit.HEART, stars=2)
        player.bench = [card1, card2, card3]
        upgraded = player.try_star_upgrade()
        assert upgraded is not None
        assert upgraded.stars == 3

    def test_star_upgrade_max_3stars(self):
        """3성은 더 이상 합성 불가"""
        player = Player(name="P1")
        card1 = Card(Rank.ACE, Suit.SPADE, stars=3)
        card2 = Card(Rank.ACE, Suit.SPADE, stars=3)
        card3 = Card(Rank.ACE, Suit.SPADE, stars=3)
        player.bench = [card1, card2, card3]
        upgraded = player.try_star_upgrade()
        assert upgraded is None

    def test_star_upgrade_not_enough_cards(self):
        """2장만 있으면 업그레이드 불가"""
        player = Player(name="P1")
        player.bench = [
            Card(Rank.ACE, Suit.SPADE),
            Card(Rank.ACE, Suit.SPADE),
        ]
        upgraded = player.try_star_upgrade()
        assert upgraded is None

    def test_star_upgrade_different_suit_no_upgrade(self):
        """다른 수트는 업그레이드 불가"""
        player = Player(name="P1")
        player.bench = [
            Card(Rank.ACE, Suit.SPADE),
            Card(Rank.ACE, Suit.HEART),
            Card(Rank.ACE, Suit.DIAMOND),
        ]
        upgraded = player.try_star_upgrade()
        assert upgraded is None


class TestApplyDamage:
    def test_apply_damage_normal(self):
        """S7: 정상 피해 적용"""
        player = Player(name="P1", hp=100)
        player.apply_damage(30)
        assert player.hp == 70

    def test_apply_damage_zero_floor(self):
        """S7: hp가 음수가 되지 않음"""
        player = Player(name="P1", hp=5)
        player.apply_damage(10)
        assert player.hp == 0

    def test_apply_damage_zero(self):
        """S7: 0 피해는 HP 변화 없음"""
        player = Player(name="P1", hp=50)
        player.apply_damage(0)
        assert player.hp == 50

    def test_apply_damage_already_zero(self):
        """S7: 이미 HP=0인 플레이어에게 피해 적용 시 0 유지"""
        player = Player(name="P1", hp=0)
        player.apply_damage(5)
        assert player.hp == 0


class TestStarUpgradeAuto:
    def test_buy_3_same_card_auto_upgrade(self):
        """S8: 같은 카드 3회 구매 시 자동 2성 합성"""
        pool = SharedCardPool()
        pool.initialize()
        player = Player(name="P1", gold=30)
        card = Card(Rank.TWO, Suit.SPADE)  # cost=1
        player.buy_card(card, pool)
        player.buy_card(Card(Rank.TWO, Suit.SPADE), pool)
        player.buy_card(Card(Rank.TWO, Suit.SPADE), pool)
        assert len(player.bench) == 1
        assert player.bench[0].stars == 2

    def test_buy_2_same_card_no_upgrade(self):
        """S8: 2장만 구매 → 합성 없음"""
        pool = SharedCardPool()
        pool.initialize()
        player = Player(name="P1", gold=10)
        player.buy_card(Card(Rank.TWO, Suit.SPADE), pool)
        player.buy_card(Card(Rank.TWO, Suit.SPADE), pool)
        assert len(player.bench) == 2
        assert player.bench[0].stars == 1

    def test_buy_3rd_triggers_upgrade(self):
        """S8: 3번째 구매가 자동 합성 트리거"""
        pool = SharedCardPool()
        pool.initialize()
        player = Player(name="P1", gold=30)
        player.buy_card(Card(Rank.TWO, Suit.SPADE), pool)
        player.buy_card(Card(Rank.TWO, Suit.SPADE), pool)
        assert len(player.bench) == 2  # 아직 합성 없음
        player.buy_card(Card(Rank.TWO, Suit.SPADE), pool)
        assert len(player.bench) == 1
        assert player.bench[0].stars == 2


class TestShopCards:
    def test_shop_cards_default_empty(self):
        """S9: 초기 shop_cards는 빈 리스트"""
        player = Player(name="P1")
        assert player.shop_cards == []

    def test_shop_cards_assignable(self):
        """S9: shop_cards 필드에 카드 목록 할당 가능"""
        player = Player(name="P1")
        card = Card(Rank.ACE, Suit.SPADE)
        player.shop_cards = [card]
        assert len(player.shop_cards) == 1
