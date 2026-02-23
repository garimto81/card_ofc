from src.board import FoulResult, OFCBoard, check_fantasyland
from src.card import Card, Rank, Suit


class TestOFCBoardPlacement:
    def test_place_card_back_success(self):
        board = OFCBoard()
        card = Card(Rank.ACE, Suit.SPADE)
        assert board.place_card('back', card) is True
        assert card in board.back

    def test_place_card_mid_success(self):
        board = OFCBoard()
        card = Card(Rank.KING, Suit.HEART)
        assert board.place_card('mid', card) is True
        assert card in board.mid

    def test_place_card_front_success(self):
        board = OFCBoard()
        card = Card(Rank.QUEEN, Suit.DIAMOND)
        assert board.place_card('front', card) is True
        assert card in board.front

    def test_place_card_back_over_limit(self):
        """back 5장 초과 시 False"""
        board = OFCBoard()
        for i in range(5):
            board.place_card('back', Card(Rank(i + 2), Suit.SPADE))
        assert board.place_card('back', Card(Rank.ACE, Suit.HEART)) is False

    def test_place_card_mid_over_limit(self):
        """mid 5장 초과 시 False"""
        board = OFCBoard()
        for i in range(5):
            board.place_card('mid', Card(Rank(i + 2), Suit.HEART))
        assert board.place_card('mid', Card(Rank.ACE, Suit.SPADE)) is False

    def test_place_card_front_over_limit(self):
        """front 3장 초과 시 False"""
        board = OFCBoard()
        for i in range(3):
            board.place_card('front', Card(Rank(i + 2), Suit.SPADE))
        assert board.place_card('front', Card(Rank.ACE, Suit.HEART)) is False

    def test_is_full_true(self):
        board = OFCBoard()
        for r in [Rank.TWO, Rank.THREE, Rank.FOUR]:
            board.place_card('front', Card(r, Suit.SPADE))
        for r in [Rank.FIVE, Rank.SIX, Rank.SEVEN, Rank.EIGHT, Rank.NINE]:
            board.place_card('mid', Card(r, Suit.HEART))
        for r in [Rank.TEN, Rank.JACK, Rank.QUEEN, Rank.KING, Rank.ACE]:
            board.place_card('back', Card(r, Suit.DIAMOND))
        assert board.is_full() is True

    def test_is_full_false_partial(self):
        board = OFCBoard()
        board.place_card('back', Card(Rank.ACE, Suit.SPADE))
        assert board.is_full() is False

    def test_remove_card_success(self):
        board = OFCBoard()
        card = Card(Rank.ACE, Suit.SPADE)
        board.place_card('back', card)
        assert board.remove_card('back', card) is True
        assert card not in board.back

    def test_remove_card_not_present(self):
        board = OFCBoard()
        card = Card(Rank.ACE, Suit.SPADE)
        assert board.remove_card('back', card) is False


class TestFoulDetection:
    def test_no_foul_normal_back_gt_mid_gt_front(self):
        """정상: Back(플러시) > Mid(원페어) > Front(하이카드)"""
        board = OFCBoard()
        # back: 플러시
        for r in [Rank.TWO, Rank.FIVE, Rank.SEVEN, Rank.NINE, Rank.KING]:
            board.back.append(Card(r, Suit.SPADE))
        # mid: 원페어
        board.mid = [
            Card(Rank.ACE, Suit.HEART),
            Card(Rank.ACE, Suit.DIAMOND),
            Card(Rank.KING, Suit.HEART),
            Card(Rank.QUEEN, Suit.HEART),
            Card(Rank.TWO, Suit.HEART),
        ]
        # front: 하이카드
        board.front = [
            Card(Rank.KING, Suit.CLUB),
            Card(Rank.QUEEN, Suit.CLUB),
            Card(Rank.JACK, Suit.CLUB),
        ]
        result = board.check_foul()
        assert result.has_foul is False
        assert result.foul_lines == []

    def test_no_foul_equal_hands(self):
        """Back=Mid=Front (동률) → Foul 없음"""
        board = OFCBoard()
        # back: 하이카드
        board.back = [
            Card(Rank.ACE, Suit.SPADE),
            Card(Rank.KING, Suit.HEART),
            Card(Rank.QUEEN, Suit.DIAMOND),
            Card(Rank.JACK, Suit.CLUB),
            Card(Rank.NINE, Suit.SPADE),
        ]
        # mid: 하이카드
        board.mid = [
            Card(Rank.EIGHT, Suit.SPADE),
            Card(Rank.SEVEN, Suit.HEART),
            Card(Rank.SIX, Suit.DIAMOND),
            Card(Rank.FIVE, Suit.CLUB),
            Card(Rank.THREE, Suit.SPADE),
        ]
        # front: 하이카드
        board.front = [
            Card(Rank.TEN, Suit.SPADE),
            Card(Rank.EIGHT, Suit.CLUB),
            Card(Rank.SIX, Suit.HEART),
        ]
        result = board.check_foul()
        assert result.has_foul is False

    def test_foul_back_weaker_than_mid(self):
        """폴: Back(원페어) < Mid(플러시)"""
        board = OFCBoard()
        board.back = [
            Card(Rank.ACE, Suit.SPADE),
            Card(Rank.ACE, Suit.HEART),
            Card(Rank.TWO, Suit.CLUB),
            Card(Rank.THREE, Suit.DIAMOND),
            Card(Rank.FOUR, Suit.SPADE),
        ]
        board.mid = [
            Card(Rank.TWO, Suit.HEART),
            Card(Rank.FIVE, Suit.HEART),
            Card(Rank.SEVEN, Suit.HEART),
            Card(Rank.NINE, Suit.HEART),
            Card(Rank.KING, Suit.HEART),
        ]
        board.front = [
            Card(Rank.TWO, Suit.SPADE),
            Card(Rank.THREE, Suit.SPADE),
            Card(Rank.FOUR, Suit.CLUB),
        ]
        result = board.check_foul()
        assert result.has_foul is True
        assert 'back' in result.foul_lines

    def test_foul_mid_weaker_than_front(self):
        """폴: Mid(하이카드) < Front(원페어)"""
        board = OFCBoard()
        # back: 투페어
        board.back = [
            Card(Rank.ACE, Suit.SPADE),
            Card(Rank.ACE, Suit.HEART),
            Card(Rank.KING, Suit.SPADE),
            Card(Rank.KING, Suit.HEART),
            Card(Rank.TWO, Suit.CLUB),
        ]
        # mid: 하이카드
        board.mid = [
            Card(Rank.ACE, Suit.DIAMOND),
            Card(Rank.KING, Suit.DIAMOND),
            Card(Rank.QUEEN, Suit.DIAMOND),
            Card(Rank.JACK, Suit.CLUB),
            Card(Rank.NINE, Suit.CLUB),
        ]
        # front: 원페어 (mid보다 강함 → Foul)
        board.front = [
            Card(Rank.QUEEN, Suit.SPADE),
            Card(Rank.QUEEN, Suit.HEART),
            Card(Rank.TWO, Suit.DIAMOND),
        ]
        result = board.check_foul()
        assert result.has_foul is True
        assert 'mid' in result.foul_lines

    def test_foul_both_lines(self):
        """Back < Mid AND Mid < Front → 두 라인 폴"""
        board = OFCBoard()
        # back: 하이카드
        board.back = [
            Card(Rank.TWO, Suit.SPADE),
            Card(Rank.THREE, Suit.HEART),
            Card(Rank.FIVE, Suit.DIAMOND),
            Card(Rank.SEVEN, Suit.CLUB),
            Card(Rank.NINE, Suit.SPADE),
        ]
        # mid: 원페어
        board.mid = [
            Card(Rank.ACE, Suit.SPADE),
            Card(Rank.ACE, Suit.HEART),
            Card(Rank.TWO, Suit.CLUB),
            Card(Rank.THREE, Suit.DIAMOND),
            Card(Rank.FOUR, Suit.SPADE),
        ]
        # front: 스리카인드 (mid보다 강함 → Foul)
        board.front = [
            Card(Rank.KING, Suit.SPADE),
            Card(Rank.KING, Suit.HEART),
            Card(Rank.KING, Suit.DIAMOND),
        ]
        result = board.check_foul()
        assert result.has_foul is True
        assert 'back' in result.foul_lines
        assert 'mid' in result.foul_lines

    def test_foul_result_dataclass(self):
        """FoulResult 타입 확인"""
        board = OFCBoard()
        result = board.check_foul()
        assert isinstance(result, FoulResult)
        assert isinstance(result.has_foul, bool)
        assert isinstance(result.foul_lines, list)


class TestFoulWarning:
    def test_foul_warning_front_incomplete(self):
        """Front 라인 미완성 → 경고"""
        board = OFCBoard()
        board.front = [Card(Rank.ACE, Suit.SPADE)]  # 1장만
        warnings = board.get_foul_warning()
        assert any("Front" in w for w in warnings)

    def test_foul_warning_back_weaker_than_mid(self):
        """Back < Mid → 경고"""
        board = OFCBoard()
        board.back = [
            Card(Rank.ACE, Suit.SPADE),
            Card(Rank.ACE, Suit.HEART),
            Card(Rank.TWO, Suit.CLUB),
            Card(Rank.THREE, Suit.DIAMOND),
            Card(Rank.FOUR, Suit.SPADE),
        ]
        board.mid = [
            Card(Rank.TWO, Suit.HEART),
            Card(Rank.FIVE, Suit.HEART),
            Card(Rank.SEVEN, Suit.HEART),
            Card(Rank.NINE, Suit.HEART),
            Card(Rank.KING, Suit.HEART),
        ]
        warnings = board.get_foul_warning()
        assert any("Back" in w or "Foul" in w for w in warnings)

    def test_no_warning_when_valid(self):
        """올바른 배치 → 경고 없음 (front 완성 + 강도 순서 맞을 때)"""
        board = OFCBoard()
        # back: 플러시
        for r in [Rank.TWO, Rank.FIVE, Rank.SEVEN, Rank.NINE, Rank.KING]:
            board.back.append(Card(r, Suit.SPADE))
        # mid: 원페어
        board.mid = [
            Card(Rank.ACE, Suit.HEART),
            Card(Rank.ACE, Suit.DIAMOND),
            Card(Rank.KING, Suit.HEART),
            Card(Rank.QUEEN, Suit.HEART),
            Card(Rank.TWO, Suit.HEART),
        ]
        # front: 하이카드 (3장)
        board.front = [
            Card(Rank.KING, Suit.CLUB),
            Card(Rank.QUEEN, Suit.CLUB),
            Card(Rank.JACK, Suit.CLUB),
        ]
        warnings = board.get_foul_warning()
        # 경고 없거나 foul 관련 경고 없음
        foul_warnings = [w for w in warnings if "Foul" in w]
        assert len(foul_warnings) == 0


class TestGetHandResults:
    def test_get_hand_results_all_lines(self):
        """3라인 모두 HandResult 반환"""
        board = OFCBoard()
        for r in [Rank.TWO, Rank.FIVE, Rank.SEVEN, Rank.NINE, Rank.KING]:
            board.back.append(Card(r, Suit.SPADE))
        board.mid = [
            Card(Rank.ACE, Suit.HEART),
            Card(Rank.ACE, Suit.DIAMOND),
            Card(Rank.KING, Suit.HEART),
            Card(Rank.QUEEN, Suit.HEART),
            Card(Rank.TWO, Suit.HEART),
        ]
        board.front = [
            Card(Rank.KING, Suit.CLUB),
            Card(Rank.QUEEN, Suit.CLUB),
            Card(Rank.JACK, Suit.CLUB),
        ]
        results = board.get_hand_results()
        assert 'back' in results
        assert 'mid' in results
        assert 'front' in results

    def test_get_hand_results_empty_lines_excluded(self):
        """빈 라인은 결과에서 제외"""
        board = OFCBoard()
        board.back.append(Card(Rank.ACE, Suit.SPADE))
        results = board.get_hand_results()
        assert 'back' in results
        assert 'mid' not in results
        assert 'front' not in results


class TestFantasyland:
    """A4: 판타지랜드 진입 조건 검증"""

    def test_fantasyland_front_pair_no_foul(self):
        """Front QQ 이상 원페어 + Foul 없음 → 판타지랜드 진입"""
        board = OFCBoard()
        # back: 플러시 (강함)
        for r in [Rank.TWO, Rank.FIVE, Rank.SEVEN, Rank.NINE, Rank.KING]:
            board.back.append(Card(r, Suit.SPADE))
        # mid: 원페어 (중간)
        board.mid = [
            Card(Rank.ACE, Suit.HEART),
            Card(Rank.ACE, Suit.DIAMOND),
            Card(Rank.KING, Suit.HEART),
            Card(Rank.QUEEN, Suit.HEART),
            Card(Rank.TWO, Suit.HEART),
        ]
        # front: QQ 페어 (QQ 이상 조건 충족)
        board.front = [
            Card(Rank.QUEEN, Suit.SPADE),
            Card(Rank.QUEEN, Suit.CLUB),
            Card(Rank.TWO, Suit.CLUB),
        ]
        assert board.check_fantasyland() is True

    def test_fantasyland_front_three_of_a_kind(self):
        """Front 스리카인드 + Foul 없음 → 판타지랜드 진입"""
        board = OFCBoard()
        # back: 풀하우스 (강)
        board.back = [
            Card(Rank.ACE, Suit.SPADE),
            Card(Rank.ACE, Suit.HEART),
            Card(Rank.ACE, Suit.DIAMOND),
            Card(Rank.KING, Suit.SPADE),
            Card(Rank.KING, Suit.HEART),
        ]
        # mid: 스리카인드 (중간 — 스리카인드 ≥ 스리카인드이므로 Foul 없음)
        board.mid = [
            Card(Rank.QUEEN, Suit.SPADE),
            Card(Rank.QUEEN, Suit.HEART),
            Card(Rank.QUEEN, Suit.DIAMOND),
            Card(Rank.TWO, Suit.CLUB),
            Card(Rank.THREE, Suit.DIAMOND),
        ]
        # front: 스리카인드 (QQ 이상 → 판타지랜드 진입, mid와 동급이므로 Foul 없음)
        board.front = [
            Card(Rank.QUEEN, Suit.CLUB),
            Card(Rank.QUEEN, Suit.DIAMOND),
            Card(Rank.QUEEN, Suit.HEART),
        ]
        assert board.check_fantasyland() is True

    def test_no_fantasyland_front_high_card(self):
        """Front 하이카드 → 판타지랜드 진입 불가"""
        board = OFCBoard()
        for r in [Rank.TWO, Rank.FIVE, Rank.SEVEN, Rank.NINE, Rank.KING]:
            board.back.append(Card(r, Suit.SPADE))
        board.mid = [
            Card(Rank.ACE, Suit.HEART),
            Card(Rank.ACE, Suit.DIAMOND),
            Card(Rank.KING, Suit.HEART),
            Card(Rank.QUEEN, Suit.HEART),
            Card(Rank.TWO, Suit.HEART),
        ]
        # front: 하이카드 (페어 없음)
        board.front = [
            Card(Rank.KING, Suit.CLUB),
            Card(Rank.QUEEN, Suit.CLUB),
            Card(Rank.JACK, Suit.CLUB),
        ]
        assert board.check_fantasyland() is False

    def test_no_fantasyland_with_foul(self):
        """Foul 발생 시 → 판타지랜드 진입 불가"""
        board = OFCBoard()
        # back: 원페어 (약함)
        board.back = [
            Card(Rank.ACE, Suit.SPADE),
            Card(Rank.ACE, Suit.HEART),
            Card(Rank.TWO, Suit.CLUB),
            Card(Rank.THREE, Suit.DIAMOND),
            Card(Rank.FOUR, Suit.SPADE),
        ]
        # mid: 플러시 (back보다 강함 → Foul)
        board.mid = [
            Card(Rank.TWO, Suit.HEART),
            Card(Rank.FIVE, Suit.HEART),
            Card(Rank.SEVEN, Suit.HEART),
            Card(Rank.NINE, Suit.HEART),
            Card(Rank.KING, Suit.HEART),
        ]
        # front: 원페어
        board.front = [
            Card(Rank.FIVE, Suit.SPADE),
            Card(Rank.FIVE, Suit.DIAMOND),
            Card(Rank.TWO, Suit.CLUB),
        ]
        assert board.check_fantasyland() is False

    def test_no_fantasyland_front_incomplete(self):
        """Front 3장 미완성 → 판타지랜드 진입 불가"""
        board = OFCBoard()
        for r in [Rank.TWO, Rank.FIVE, Rank.SEVEN, Rank.NINE, Rank.KING]:
            board.back.append(Card(r, Suit.SPADE))
        board.mid = [
            Card(Rank.ACE, Suit.HEART),
            Card(Rank.ACE, Suit.DIAMOND),
            Card(Rank.KING, Suit.HEART),
            Card(Rank.QUEEN, Suit.HEART),
            Card(Rank.TWO, Suit.HEART),
        ]
        board.front = [Card(Rank.FIVE, Suit.HEART), Card(Rank.FIVE, Suit.DIAMOND)]  # 2장만
        assert board.check_fantasyland() is False

    def test_no_fantasyland_empty_board(self):
        """빈 보드 → 판타지랜드 진입 불가"""
        board = OFCBoard()
        assert board.check_fantasyland() is False


class TestCheckFantasylandFunction:
    """모듈 레벨 check_fantasyland() 함수 — QQ+ 조건 검증"""

    def test_empty_board_no_fantasyland(self):
        from src.board import check_fantasyland
        board = OFCBoard()
        assert check_fantasyland(board) is False

    def test_high_card_no_fantasyland(self):
        from src.board import check_fantasyland
        board = OFCBoard()
        board.front = [Card(Rank.ACE, Suit.SPADE), Card(Rank.KING, Suit.HEART), Card(Rank.QUEEN, Suit.DIAMOND)]
        assert check_fantasyland(board) is False

    def test_low_pair_no_fantasyland(self):
        """JJ 이하 페어는 판타지랜드 진입 불가"""
        from src.board import check_fantasyland
        board = OFCBoard()
        board.front = [Card(Rank.FIVE, Suit.SPADE), Card(Rank.FIVE, Suit.HEART), Card(Rank.ACE, Suit.DIAMOND)]
        assert check_fantasyland(board) is False

    def test_jack_pair_no_fantasyland(self):
        from src.board import check_fantasyland
        board = OFCBoard()
        board.front = [Card(Rank.JACK, Suit.SPADE), Card(Rank.JACK, Suit.HEART), Card(Rank.ACE, Suit.DIAMOND)]
        assert check_fantasyland(board) is False

    def test_queen_pair_fantasyland(self):
        """QQ 페어 → 판타지랜드 진입"""
        from src.board import check_fantasyland
        board = OFCBoard()
        board.front = [Card(Rank.QUEEN, Suit.SPADE), Card(Rank.QUEEN, Suit.HEART), Card(Rank.ACE, Suit.DIAMOND)]
        assert check_fantasyland(board) is True

    def test_king_pair_fantasyland(self):
        from src.board import check_fantasyland
        board = OFCBoard()
        board.front = [Card(Rank.KING, Suit.SPADE), Card(Rank.KING, Suit.HEART), Card(Rank.ACE, Suit.DIAMOND)]
        assert check_fantasyland(board) is True

    def test_ace_pair_fantasyland(self):
        from src.board import check_fantasyland
        board = OFCBoard()
        board.front = [Card(Rank.ACE, Suit.SPADE), Card(Rank.ACE, Suit.HEART), Card(Rank.KING, Suit.DIAMOND)]
        assert check_fantasyland(board) is True

    def test_three_of_a_kind_fantasyland(self):
        from src.board import check_fantasyland
        board = OFCBoard()
        board.front = [Card(Rank.TWO, Suit.SPADE), Card(Rank.TWO, Suit.HEART), Card(Rank.TWO, Suit.DIAMOND)]
        assert check_fantasyland(board) is True
