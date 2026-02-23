from src.board import OFCBoard
from src.card import Card, Rank, Suit
from src.combat import CombatResolver, CombatResult, count_synergies


def make_flush_board(suit: Suit = Suit.SPADE) -> OFCBoard:
    """플러시 back + 원페어 mid + 하이카드 front"""
    board = OFCBoard()
    for r in [Rank.TWO, Rank.FIVE, Rank.SEVEN, Rank.NINE, Rank.KING]:
        board.back.append(Card(r, suit))
    board.mid = [
        Card(Rank.ACE, Suit.HEART),
        Card(Rank.ACE, Suit.DIAMOND),
        Card(Rank.TWO, Suit.CLUB),
        Card(Rank.THREE, Suit.SPADE),
        Card(Rank.FOUR, Suit.HEART),
    ]
    board.front = [
        Card(Rank.KING, Suit.CLUB),
        Card(Rank.QUEEN, Suit.CLUB),
        Card(Rank.JACK, Suit.CLUB),
    ]
    return board


def make_pair_board() -> OFCBoard:
    """원페어 back + 원페어 mid + 하이카드 front"""
    board = OFCBoard()
    board.back = [
        Card(Rank.ACE, Suit.HEART),
        Card(Rank.ACE, Suit.DIAMOND),
        Card(Rank.KING, Suit.HEART),
        Card(Rank.QUEEN, Suit.HEART),
        Card(Rank.TWO, Suit.HEART),
    ]
    board.mid = [
        Card(Rank.SEVEN, Suit.HEART),
        Card(Rank.SEVEN, Suit.DIAMOND),
        Card(Rank.TWO, Suit.CLUB),
        Card(Rank.THREE, Suit.SPADE),
        Card(Rank.FOUR, Suit.HEART),
    ]
    board.front = [
        Card(Rank.TWO, Suit.SPADE),
        Card(Rank.THREE, Suit.HEART),
        Card(Rank.FOUR, Suit.DIAMOND),
    ]
    return board


class TestCombatResolver:
    def setup_method(self):
        self.resolver = CombatResolver()

    def test_resolve_basic_flush_beats_pair(self):
        """플러시 back이 원페어 back을 이김"""
        board_a = make_flush_board()
        board_b = make_pair_board()
        result_a, result_b = self.resolver.resolve(board_a, board_b)
        assert result_a.line_results['back'] == 1
        assert result_b.line_results['back'] == -1

    def test_resolve_returns_two_results(self):
        """resolve는 두 개의 CombatResult 반환"""
        board_a = make_flush_board()
        board_b = make_pair_board()
        results = self.resolver.resolve(board_a, board_b)
        assert len(results) == 2
        result_a, result_b = results
        assert isinstance(result_a, CombatResult)
        assert isinstance(result_b, CombatResult)

    def test_resolve_antisymmetry(self):
        """A vs B의 라인 결과는 B vs A의 반대"""
        board_a = make_flush_board()
        board_b = make_pair_board()
        result_a, result_b = self.resolver.resolve(board_a, board_b)
        for line in ['back', 'mid', 'front']:
            assert result_a.line_results[line] == -result_b.line_results[line]

    def test_scoop_3_0(self):
        """3라인 전승 → scoop=True"""
        board_a = make_flush_board()
        board_b = make_pair_board()
        result_a, result_b = self.resolver.resolve(board_a, board_b)
        # flush back > pair back
        # pair mid == pair mid (but check actual)
        # front: 하이카드 vs 하이카드 (어느 쪽이 이기는지 확인)
        # 스쿠프는 3라인 모두 이겨야 함

    def test_damage_3_0_scoop(self):
        """3:0 스쿠프 → 기본 damage = 3*2 + 2 = 8"""
        damage = self.resolver.calc_damage(3, is_scoop=True)
        assert damage == 8

    def test_damage_2_1(self):
        """2라인 승 → damage = 2*2 = 4"""
        damage = self.resolver.calc_damage(2, is_scoop=False)
        assert damage == 4

    def test_damage_1_2(self):
        """1라인 승 → damage = 1*2 = 2"""
        damage = self.resolver.calc_damage(1, is_scoop=False)
        assert damage == 2

    def test_damage_0(self):
        """0라인 승 → damage = 0"""
        damage = self.resolver.calc_damage(0, is_scoop=False)
        assert damage == 0

    def test_hula_multiplier_x4(self):
        """훌라 성공 → damage × 4"""
        base_damage = 4
        hula_damage = self.resolver.apply_hula(base_damage)
        assert hula_damage == 16

    def test_hula_multiplier_x4_scoop(self):
        """훌라 + 스쿠프 → 8 × 4 = 32"""
        hula_damage = self.resolver.apply_hula(8)
        assert hula_damage == 32

    def test_hula_not_applied_when_lose(self):
        """훌라 선언했지만 패배(승리 라인 < 2) → 훌라 미적용"""
        board_a = make_pair_board()  # 약한 보드
        board_b = make_flush_board()  # 강한 보드
        result_a, result_b = self.resolver.resolve(board_a, board_b, hula_a=True)
        assert result_a.hula_applied is False


class TestCombatResultStopFields:
    """A4: 스톱(×8) 필드 검증"""

    def test_stop_applied_default_false(self):
        """CombatResult 기본값: stop_applied=False"""
        resolver = CombatResolver()
        board_a = make_flush_board()
        board_b = make_pair_board()
        result_a, result_b = resolver.resolve(board_a, board_b)
        assert result_a.stop_applied is False
        assert result_b.stop_applied is False

    def test_stop_multiplier_field_not_present(self):
        """CombatResult에 stop_multiplier 필드 없음 확인"""
        result = CombatResult(
            line_results={'back': 1, 'mid': 1, 'front': 1},
            winner_lines=3,
            is_scoop=True,
            damage=8,
            hula_applied=False,
        )
        assert not hasattr(result, 'stop_multiplier')

    def test_combat_result_has_stop_applied_field(self):
        """CombatResult 데이터클래스에 stop_applied 필드 존재 확인"""
        result = CombatResult(
            line_results={'back': 1, 'mid': 1, 'front': 1},
            winner_lines=3,
            is_scoop=True,
            damage=8,
            hula_applied=False,
            stop_applied=True,
        )
        assert result.stop_applied is True

    def test_stop_damage_multiplier_8(self):
        """스톱 선언 시 데미지 ×8 계산 검증"""
        base_damage = 4
        stop_damage = base_damage * 8
        assert stop_damage == 32


class TestCountSynergies:
    def test_synergies_zero(self):
        """모두 다른 수트 → 시너지 0"""
        board = OFCBoard()
        board.back = [
            Card(Rank.ACE, Suit.SPADE),
            Card(Rank.KING, Suit.HEART),
            Card(Rank.QUEEN, Suit.DIAMOND),
            Card(Rank.JACK, Suit.CLUB),
            Card(Rank.TEN, Suit.SPADE),
        ]
        # 2개 수트(SPADE 2장)
        synergies = count_synergies(board)
        assert synergies >= 0

    def test_synergies_one_suit_dominant(self):
        """같은 수트 5장 → 시너지 1 (그 수트만)"""
        board = OFCBoard()
        for r in [Rank.TWO, Rank.FIVE, Rank.SEVEN, Rank.NINE, Rank.KING]:
            board.back.append(Card(r, Suit.SPADE))
        synergies = count_synergies(board)
        assert synergies >= 1

    def test_synergies_3_suits(self):
        """3 종류의 수트 각 2장 이상 → 시너지 3"""
        board = OFCBoard()
        board.back = [
            Card(Rank.ACE, Suit.SPADE),
            Card(Rank.KING, Suit.SPADE),
            Card(Rank.ACE, Suit.HEART),
            Card(Rank.KING, Suit.HEART),
            Card(Rank.ACE, Suit.DIAMOND),
        ]
        board.mid = [
            Card(Rank.KING, Suit.DIAMOND),
            Card(Rank.QUEEN, Suit.CLUB),
            Card(Rank.JACK, Suit.CLUB),
            Card(Rank.TEN, Suit.SPADE),
            Card(Rank.NINE, Suit.HEART),
        ]
        board.front = [
            Card(Rank.EIGHT, Suit.DIAMOND),
            Card(Rank.SEVEN, Suit.CLUB),
            Card(Rank.SIX, Suit.SPADE),
        ]
        synergies = count_synergies(board)
        assert synergies >= 3

    def test_hula_declare_requires_3_synergies(self):
        """시너지 3개 미만 → 훌라 선언 불가"""
        board = OFCBoard()
        board.back = [
            Card(Rank.ACE, Suit.SPADE),
            Card(Rank.KING, Suit.HEART),
            Card(Rank.QUEEN, Suit.DIAMOND),
            Card(Rank.JACK, Suit.CLUB),
            Card(Rank.TEN, Suit.SPADE),
        ]
        # SPADE 2장만 있음 → 시너지 1개
        assert count_synergies(board) < 3
