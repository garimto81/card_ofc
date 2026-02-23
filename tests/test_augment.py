import pytest

from src.augment import Augment, AugmentPool, SILVER_AUGMENTS
from src.economy import Player


class TestAugmentPool:
    def test_offer_augments_returns_3(self):
        pool = AugmentPool()
        result = pool.offer_augments(3)
        assert len(result) == 3

    def test_offer_augments_returns_less_when_count_lower(self):
        pool = AugmentPool()
        result = pool.offer_augments(1)
        assert len(result) == 1

    def test_all_silver_tier(self):
        pool = AugmentPool()
        for aug in pool.offer_augments(3):
            assert aug.tier == "silver"

    def test_silver_augments_ids(self):
        ids = {a.id for a in SILVER_AUGMENTS}
        assert "economist" in ids
        assert "suit_mystery" in ids
        assert "lucky_shop" in ids

    def test_get_augment_economist(self):
        pool = AugmentPool()
        aug = pool.get_augment("economist")
        assert aug is not None
        assert aug.id == "economist"

    def test_get_augment_suit_mystery(self):
        pool = AugmentPool()
        aug = pool.get_augment("suit_mystery")
        assert aug is not None
        assert aug.id == "suit_mystery"

    def test_get_augment_lucky_shop(self):
        pool = AugmentPool()
        aug = pool.get_augment("lucky_shop")
        assert aug is not None
        assert aug.id == "lucky_shop"

    def test_get_augment_unknown_returns_none(self):
        pool = AugmentPool()
        assert pool.get_augment("nonexistent") is None

    def test_augment_has_name_and_description(self):
        pool = AugmentPool()
        for aug in pool.offer_augments(3):
            assert aug.name
            assert aug.description


class TestAugmentDataclass:
    def test_augment_frozen(self):
        aug = Augment(id="test", name="테스트", tier="silver", description="설명", effect_type="passive")
        with pytest.raises((AttributeError, TypeError)):
            aug.id = "other"  # frozen=True이므로 수정 불가

    def test_augment_fields(self):
        aug = Augment(id="economist", name="경제학자", tier="silver", description="설명", effect_type="passive")
        assert aug.id == "economist"
        assert aug.name == "경제학자"
        assert aug.tier == "silver"
        assert aug.description == "설명"
        assert aug.effect_type == "passive"

    def test_augment_tier_silver(self):
        aug = Augment(id="x", name="테스트", tier="silver", description="설명", effect_type="passive")
        assert aug.tier == "silver"


class TestPlayerAugments:
    def test_add_augment_by_id(self):
        p = Player("p1")
        pool = AugmentPool()
        aug = pool.get_augment("economist")
        p.add_augment(aug)
        assert len(p.augments) == 1

    def test_add_two_augments(self):
        p = Player("p1")
        pool = AugmentPool()
        p.add_augment(pool.get_augment("economist"))
        p.add_augment(pool.get_augment("suit_mystery"))
        assert len(p.augments) == 2

    def test_no_duplicate_augment_id(self):
        p = Player("p1")
        pool = AugmentPool()
        aug = pool.get_augment("economist")
        p.add_augment(aug)
        p.add_augment(aug)  # 중복 추가 시도
        assert len(p.augments) == 1

    def test_augments_empty_by_default(self):
        p = Player("p1")
        assert p.augments == []

    def test_has_augment_true(self):
        p = Player("p1")
        pool = AugmentPool()
        p.add_augment(pool.get_augment("economist"))
        assert p.has_augment("economist") is True

    def test_has_augment_false(self):
        p = Player("p1")
        assert p.has_augment("economist") is False

    def test_has_augment_other_id_false(self):
        p = Player("p1")
        pool = AugmentPool()
        p.add_augment(pool.get_augment("suit_mystery"))
        assert p.has_augment("economist") is False


class TestEconomistAugment:
    def test_calc_interest_default_cap_5(self):
        p = Player("p1")
        p.gold = 50
        assert p.calc_interest() == 5

    def test_calc_interest_default_no_augment(self):
        p = Player("p1")
        p.gold = 20
        assert p.calc_interest() == 2

    def test_calc_interest_economist_cap_6(self):
        p = Player("p1")
        p.gold = 60
        pool = AugmentPool()
        p.add_augment(pool.get_augment("economist"))
        assert p.calc_interest() == 6

    def test_calc_interest_economist_intermediate(self):
        p = Player("p1")
        p.gold = 40
        pool = AugmentPool()
        p.add_augment(pool.get_augment("economist"))
        assert p.calc_interest() == 4  # 40//10=4, cap=6이므로 4

    def test_calc_interest_without_economist_capped(self):
        p = Player("p1")
        p.gold = 100
        # economist 없이 골드 100 → 한도 5
        assert p.calc_interest() == 5

    def test_other_augment_no_cap_change(self):
        p = Player("p1")
        p.gold = 100
        pool = AugmentPool()
        p.add_augment(pool.get_augment("suit_mystery"))
        assert p.calc_interest() == 5  # economist 없으면 cap=5


class TestFantasylandFields:
    def test_in_fantasyland_default_false(self):
        p = Player("p1")
        assert p.in_fantasyland is False

    def test_fantasyland_next_default_false(self):
        p = Player("p1")
        assert p.fantasyland_next is False

    def test_enter_fantasyland(self):
        p = Player("p1")
        p.enter_fantasyland()
        assert p.in_fantasyland is True

    def test_exit_fantasyland(self):
        p = Player("p1")
        p.enter_fantasyland()
        p.exit_fantasyland()
        assert p.in_fantasyland is False
        assert p.fantasyland_next is False
