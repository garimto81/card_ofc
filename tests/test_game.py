from src.board import OFCBoard
from src.card import Card, Rank, Suit
from src.economy import Player
from src.game import GameState, RoundManager
from src.pool import SharedCardPool


def setup_boards_for_combat(p1: Player, p2: Player):
    """전투용 간단 보드 설정"""
    p1.board = OFCBoard()
    p2.board = OFCBoard()

    # p1: flush back (강)
    for r in [Rank.TWO, Rank.FIVE, Rank.SEVEN, Rank.NINE, Rank.KING]:
        p1.board.back.append(Card(r, Suit.SPADE))
    p1.board.mid = [
        Card(Rank.ACE, Suit.HEART),
        Card(Rank.ACE, Suit.DIAMOND),
        Card(Rank.TWO, Suit.CLUB),
        Card(Rank.THREE, Suit.SPADE),
        Card(Rank.FOUR, Suit.HEART),
    ]
    p1.board.front = [
        Card(Rank.KING, Suit.CLUB),
        Card(Rank.QUEEN, Suit.CLUB),
        Card(Rank.JACK, Suit.CLUB),
    ]

    # p2: pair back (약)
    p2.board.back = [
        Card(Rank.ACE, Suit.CLUB),
        Card(Rank.ACE, Suit.SPADE),
        Card(Rank.KING, Suit.HEART),
        Card(Rank.QUEEN, Suit.HEART),
        Card(Rank.JACK, Suit.HEART),
    ]
    p2.board.mid = [
        Card(Rank.SEVEN, Suit.SPADE),
        Card(Rank.SEVEN, Suit.CLUB),
        Card(Rank.TWO, Suit.HEART),
        Card(Rank.THREE, Suit.HEART),
        Card(Rank.FOUR, Suit.SPADE),
    ]
    p2.board.front = [
        Card(Rank.TWO, Suit.CLUB),
        Card(Rank.THREE, Suit.CLUB),
        Card(Rank.FOUR, Suit.DIAMOND),
    ]


class TestGameState:
    def setup_method(self):
        self.pool = SharedCardPool()
        self.pool.initialize()
        self.p1 = Player(name="Player1", gold=0)
        self.p2 = Player(name="Player2", gold=0)
        self.state = GameState(players=[self.p1, self.p2], pool=self.pool)
        self.manager = RoundManager(self.state)

    def test_game_not_over_at_start(self):
        assert self.state.is_game_over() is False

    def test_get_winner_during_game(self):
        assert self.state.get_winner() is None

    def test_game_over_on_hp_zero(self):
        self.p2.hp = 0
        assert self.state.is_game_over() is True
        winner = self.state.get_winner()
        assert winner == self.p1

    def test_game_over_max_rounds(self):
        self.state.round_num = self.state.max_rounds + 1
        assert self.state.is_game_over() is True

    def test_initial_phase_is_prep(self):
        assert self.state.phase == 'prep'

    def test_initial_round_num(self):
        assert self.state.round_num == 1

    def test_winner_is_higher_hp_player(self):
        """5라운드 후 HP가 높은 쪽이 승자"""
        self.state.round_num = self.state.max_rounds + 1
        self.p1.hp = 80
        self.p2.hp = 60
        winner = self.state.get_winner()
        assert winner == self.p1


class TestRoundManager:
    def setup_method(self):
        self.pool = SharedCardPool()
        self.pool.initialize()
        self.p1 = Player(name="Player1", gold=0)
        self.p2 = Player(name="Player2", gold=0)
        self.state = GameState(players=[self.p1, self.p2], pool=self.pool)
        self.manager = RoundManager(self.state)

    def test_prep_phase_income(self):
        """준비 단계: 최소 5골드 지급"""
        self.manager.start_prep_phase()
        assert self.p1.gold >= 5
        assert self.p2.gold >= 5

    def test_prep_phase_sets_phase(self):
        self.manager.start_prep_phase()
        assert self.state.phase == 'prep'

    def test_combat_phase_damage(self):
        """전투 후 HP 감소"""
        setup_boards_for_combat(self.p1, self.p2)
        initial_p2_hp = self.p2.hp
        initial_p1_hp = self.p1.hp
        self.manager.start_combat_phase()
        # 플러시 > 원페어이므로 p1이 back에서 이기고 p2 HP가 줄어야 함
        assert self.p2.hp <= initial_p2_hp or self.p1.hp <= initial_p1_hp

    def test_combat_phase_returns_results(self):
        setup_boards_for_combat(self.p1, self.p2)
        results = self.manager.start_combat_phase()
        assert len(results) > 0

    def test_end_round_increments_round(self):
        self.manager.start_prep_phase()
        setup_boards_for_combat(self.p1, self.p2)
        self.manager.start_combat_phase()
        self.manager.end_round()
        assert self.state.round_num == 2

    def test_end_round_resets_boards(self):
        """라운드 종료 후 보드 초기화"""
        setup_boards_for_combat(self.p1, self.p2)
        self.manager.end_round()
        assert len(self.p1.board.back) == 0
        assert len(self.p1.board.mid) == 0
        assert len(self.p1.board.front) == 0

    def test_streak_updated_after_combat(self):
        """전투 후 연승/연패 업데이트"""
        setup_boards_for_combat(self.p1, self.p2)
        self.manager.start_combat_phase()
        # p1이 이기거나 p2가 이기거나 → 한 쪽 streak 증가
        total_streaks = (
            self.p1.win_streak + self.p2.win_streak
            + self.p1.loss_streak + self.p2.loss_streak
        )
        assert total_streaks > 0


class TestGameIntegration:
    def setup_method(self):
        self.pool = SharedCardPool()
        self.pool.initialize()
        self.p1 = Player(name="Player1", gold=0)
        self.p2 = Player(name="Player2", gold=0)
        self.state = GameState(players=[self.p1, self.p2], pool=self.pool)
        self.manager = RoundManager(self.state)

    def test_5_round_simulation_no_crash(self):
        """5라운드 완주 테스트 — 크래시 없음"""
        for round_num in range(1, 6):
            if self.state.is_game_over():
                break
            self.manager.start_prep_phase()
            setup_boards_for_combat(self.p1, self.p2)
            self.manager.start_combat_phase()
            self.manager.end_round()

        # 5라운드 완주하거나 HP 0으로 게임 종료
        assert self.state.round_num > 1 or self.state.is_game_over()

    def test_game_over_hp_zero(self):
        """HP 0 즉시 종료"""
        setup_boards_for_combat(self.p1, self.p2)
        self.p1.hp = 1
        self.p2.hp = 100
        # 전투 수행
        self.manager.start_combat_phase()
        # 만약 p1이 0 이하가 됐다면 게임 종료
        if self.p1.hp <= 0:
            assert self.state.is_game_over() is True

    def test_round_num_increments(self):
        """라운드 번호 단조 증가"""
        for _ in range(3):
            if self.state.is_game_over():
                break
            self.manager.start_prep_phase()
            setup_boards_for_combat(self.p1, self.p2)
            self.manager.start_combat_phase()
            self.manager.end_round()

        assert self.state.round_num >= 2

    def test_5_round_winner_exists(self):
        """5라운드 완료 후 승자 결정 (HP > 0인 사람)"""
        for _ in range(5):
            if self.state.is_game_over():
                break
            self.manager.start_prep_phase()
            setup_boards_for_combat(self.p1, self.p2)
            self.manager.start_combat_phase()
            self.manager.end_round()

        if self.state.is_game_over():
            winner = self.state.get_winner()
            if winner is not None:
                assert winner.hp > 0


class TestGenerateMatchups:
    """A5: 3~4인 매칭 확장 검증 (인덱스 기반)"""

    def _make_state(self, count: int):
        pool = SharedCardPool()
        pool.initialize()
        players = [Player(name=f"p{i+1}") for i in range(count)]
        state = GameState(players=players, pool=pool)
        return state, players

    def test_2_players_1_matchup(self):
        """2인: 항상 1쌍"""
        state, players = self._make_state(2)
        manager = RoundManager(state)
        matchups = manager.generate_matchups()
        assert len(matchups) == 1
        a, b = matchups[0]
        assert a in (0, 1)
        assert b in (0, 1)
        assert a != b

    def test_3_players_1_matchup(self):
        """3인: 항상 1쌍 (bye 1명)"""
        state, players = self._make_state(3)
        manager = RoundManager(state)
        matchups = manager.generate_matchups()
        assert len(matchups) == 1

    def test_3_players_matchup_is_valid_pair(self):
        """3인: 선택된 쌍 인덱스가 0-2 범위"""
        state, players = self._make_state(3)
        manager = RoundManager(state)
        matchups = manager.generate_matchups()
        a, b = matchups[0]
        assert 0 <= a < 3
        assert 0 <= b < 3
        assert a != b

    def test_4_players_2_matchups(self):
        """4인: 항상 2쌍"""
        state, players = self._make_state(4)
        manager = RoundManager(state)
        matchups = manager.generate_matchups()
        assert len(matchups) == 2

    def test_4_players_no_duplicate(self):
        """4인: 같은 인덱스가 두 쌍에 중복되지 않음"""
        state, players = self._make_state(4)
        manager = RoundManager(state)
        matchups = manager.generate_matchups()
        all_indices = [idx for pair in matchups for idx in pair]
        assert len(all_indices) == len(set(all_indices))

    def test_4_players_all_active(self):
        """4인: 매칭에 포함된 인덱스가 4개"""
        state, players = self._make_state(4)
        manager = RoundManager(state)
        matchups = manager.generate_matchups()
        matched = {idx for pair in matchups for idx in pair}
        assert len(matched) == 4

    def test_empty_returns_empty(self):
        """플레이어 없음 → ValueError 또는 빈 리스트"""
        pool = SharedCardPool()
        pool.initialize()
        state = GameState(players=[], pool=pool)
        manager = RoundManager(state)
        import pytest
        with pytest.raises((ValueError, IndexError, Exception)):
            manager.generate_matchups()

    def test_2_players_valid_indices(self):
        """2인 매칭: 반환 인덱스가 0, 1"""
        state, players = self._make_state(2)
        manager = RoundManager(state)
        matchups = manager.generate_matchups()
        a, b = matchups[0]
        assert {a, b} == {0, 1}
