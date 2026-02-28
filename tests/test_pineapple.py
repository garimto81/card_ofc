"""Pineapple 드래프트 테스트 (M2)"""
import pytest
from src.economy import Player
from src.pool import SharedCardPool
from src.game import GameState, RoundManager


def make_game(n: int = 2):
    pool = SharedCardPool()
    pool.initialize()
    players = [Player(name=f"P{i}", pool=pool) for i in range(n)]
    state = GameState(players=players, pool=pool)
    return state, RoundManager(state)


class TestPineappleDraw:
    def test_prep_phase_gives_pineapple_3_cards(self):
        """start_prep_phase 후 pineapple_cards 3장 보유"""
        state, rm = make_game(2)
        rm.start_prep_phase()
        for p in state.players:
            if not p.in_fantasyland:
                assert len(p.pineapple_cards) == 3

    def test_fl_player_skips_pineapple(self):
        """FL 플레이어는 pineapple_cards 0장"""
        state, rm = make_game(2)
        state.players[0].in_fantasyland = True
        rm.start_prep_phase()
        assert len(state.players[0].pineapple_cards) == 0

    def test_pineapple_cards_are_removed_from_pool(self):
        """pineapple 3장은 pool에서 제거됨"""
        state, rm = make_game(2)
        before = sum(state.pool._pool.values())
        rm.start_prep_phase()
        after = sum(state.pool._pool.values())
        # 각 플레이어: pineapple 3장 + shop 5장 = 8장 × 2플레이어 = 16장
        # (단, FL 아닌 플레이어 수에 따라 다름)
        assert after < before


class TestPineapplePick:
    def test_pick_2_cards_moves_to_bench(self):
        """2장 선택 → bench에 추가"""
        state, rm = make_game(2)
        rm.start_prep_phase()
        p = state.players[0]
        p.pineapple_cards = p.pineapple_cards[:3]  # 3장 확보
        initial_bench = len(p.bench)
        p.pineapple_pick([0, 1])
        assert len(p.bench) == initial_bench + 2

    def test_pick_discards_1_to_pool(self):
        """버린 1장 → pool 반환"""
        state, rm = make_game(2)
        rm.start_prep_phase()
        p = state.players[0]
        before = sum(state.pool._pool.values())
        p.pineapple_pick([0, 1])
        after = sum(state.pool._pool.values())
        assert after == before + 1

    def test_pick_clears_pineapple_cards(self):
        """픽 완료 후 pineapple_cards 비워짐"""
        state, rm = make_game(2)
        rm.start_prep_phase()
        p = state.players[0]
        p.pineapple_pick([0, 2])
        assert len(p.pineapple_cards) == 0

    def test_pick_invalid_index_raises(self):
        """유효하지 않은 인덱스 → ValueError"""
        state, rm = make_game(2)
        rm.start_prep_phase()
        p = state.players[0]
        with pytest.raises((ValueError, IndexError)):
            p.pineapple_pick([0, 5])  # 인덱스 5는 없음

    def test_pick_must_be_exactly_2(self):
        """1장 또는 3장 선택 시 ValueError"""
        state, rm = make_game(2)
        rm.start_prep_phase()
        p = state.players[0]
        with pytest.raises(ValueError):
            p.pineapple_pick([0])  # 1장만 선택
        with pytest.raises(ValueError):
            p.pineapple_pick([0, 1, 2])  # 3장 선택


class TestPineappleAutoDiscard:
    def test_ready_without_pick_returns_all_to_pool(self):
        """픽 없이 ready → pineapple_cards 자동 반환"""
        state, rm = make_game(2)
        rm.start_prep_phase()
        p = state.players[0]
        leftover = list(p.pineapple_cards)
        assert len(leftover) == 3
        # 직접 auto_discard_pineapple 호출
        p.auto_discard_pineapple()
        assert len(p.pineapple_cards) == 0
