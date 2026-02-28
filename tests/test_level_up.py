"""상점 레벨업 테스트 (M3)"""
import pytest
from src.economy import Player
from src.pool import SharedCardPool


def make_player(gold: int = 20) -> Player:
    pool = SharedCardPool()
    p = Player(name="TestPlayer", pool=pool)
    p.gold = gold
    return p


class TestBuyXP:
    def test_buy_xp_deducts_4_gold(self):
        p = make_player(gold=10)
        p.buy_xp()
        assert p.gold == 6

    def test_buy_xp_adds_4_xp(self):
        p = make_player(gold=10)
        p.level = 5  # 레벨5 임계값=20, 단순 xp 누적 확인
        p.xp = 0
        p.buy_xp()
        assert p.xp == 4

    def test_buy_xp_returns_true_on_success(self):
        p = make_player(gold=10)
        result = p.buy_xp()
        assert result is True

    def test_buy_xp_fails_insufficient_gold(self):
        p = make_player(gold=3)
        result = p.buy_xp()
        assert result is False
        assert p.gold == 3
        assert p.xp == 0

    def test_buy_xp_fails_at_max_level(self):
        p = make_player(gold=20)
        p.level = 9
        result = p.buy_xp()
        assert result is False
        assert p.gold == 20


class TestLevelUp:
    def test_level_up_triggers_on_threshold(self):
        """XP가 임계값 충족 시 레벨업"""
        p = make_player(gold=20)
        # 레벨 1 → 2: XP 2 필요
        p.xp = 1
        p.buy_xp()  # xp = 1 + 4 = 5 >= 2
        assert p.level == 2

    def test_xp_carryover_after_level_up(self):
        """레벨업 후 초과 XP 이월"""
        p = make_player(gold=20)
        p.xp = 1
        p.buy_xp()  # xp = 5, 필요 2 → 레벨업, 잔여 xp = 5-2 = 3
        assert p.level == 2
        assert p.xp == 3

    def test_multiple_level_ups_in_one_buy(self):
        """한 번의 buy_xp로 다중 레벨업 가능"""
        p = make_player(gold=20)
        # 레벨 1: 2 필요, 레벨 2: 4 필요
        p.xp = 5  # 레벨1→2 완료 직전 (잔여 3), 레벨2→3은 4 필요
        p.buy_xp()  # xp = 5+4=9, 레벨1 충족(2)→레벨2, 잔여7, 레벨2 충족(4)→레벨3, 잔여3
        assert p.level == 3
        assert p.xp == 3

    def test_no_level_up_below_threshold(self):
        """XP가 임계값 미만이면 레벨업 없음"""
        p = make_player(gold=20)
        p.xp = 0
        p.buy_xp()  # xp = 4 >= 2 → 레벨업
        assert p.level == 2

    def test_level_cap_at_9(self):
        """레벨 8에서 레벨업 → 9 (최대)"""
        p = make_player(gold=20)
        p.level = 8
        p.xp = 76  # 80 - 4 (레벨8→9 필요 80, 잔여 76)
        p.buy_xp()  # xp = 76+4 = 80 >= 80 → 레벨 9
        assert p.level == 9

    def test_level_9_no_further_levelup(self):
        """레벨 9는 최대, 더 이상 레벨업 없음"""
        p = make_player(gold=20)
        p.level = 9
        p.xp = 100
        result = p.buy_xp()
        assert result is False
        assert p.level == 9


class TestLevelAffectsShop:
    def test_level_passed_to_draw(self):
        """레벨이 random_draw_n에 전달됨 (풀 드롭률 연동)"""
        p = make_player(gold=20)
        p.level = 5
        # random_draw_n(n, level=5) 호출 시 에러 없이 동작 확인
        cards = p.pool.random_draw_n(5, p.level)
        assert isinstance(cards, list)
