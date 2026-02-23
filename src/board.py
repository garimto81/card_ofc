from dataclasses import dataclass, field

from src.card import Card
from src.hand import evaluate_hand


@dataclass
class FoulResult:
    has_foul: bool
    foul_lines: list


@dataclass
class OFCBoard:
    front: list = field(default_factory=list)  # 최대 3칸
    mid: list = field(default_factory=list)    # 최대 5칸
    back: list = field(default_factory=list)   # 최대 5칸

    _VALID_LINES = {'front', 'mid', 'back'}
    _LINE_LIMITS = {'front': 3, 'mid': 5, 'back': 5}

    def place_card(self, line: str, card: Card) -> bool:
        """카드 배치. 슬롯 초과 시 False. 유효하지 않은 라인명은 ValueError."""
        if line not in self._VALID_LINES:
            raise ValueError(f"유효하지 않은 라인: '{line}'. 'front', 'mid', 'back' 중 하나.")
        slot = getattr(self, line)
        if len(slot) >= self._LINE_LIMITS[line]:
            return False
        slot.append(card)
        return True

    def remove_card(self, line: str, card: Card) -> bool:
        """카드 제거. 유효하지 않은 라인명은 ValueError."""
        if line not in self._VALID_LINES:
            raise ValueError(f"유효하지 않은 라인: '{line}'. 'front', 'mid', 'back' 중 하나.")
        slot = getattr(self, line)
        if card in slot:
            slot.remove(card)
            return True
        return False

    def is_full(self) -> bool:
        """front=3, mid=5, back=5 모두 채워졌는지"""
        return len(self.front) == 3 and len(self.mid) == 5 and len(self.back) == 5

    def check_foul(self) -> FoulResult:
        """Back ≥ Mid ≥ Front 핸드 강도 위반 감지"""
        back_hand = evaluate_hand(self.back) if self.back else None
        mid_hand = evaluate_hand(self.mid) if self.mid else None
        front_hand = evaluate_hand(self.front) if self.front else None

        foul_lines = []

        if back_hand and mid_hand:
            if back_hand.hand_type < mid_hand.hand_type:
                foul_lines.append('back')

        if mid_hand and front_hand:
            if mid_hand.hand_type < front_hand.hand_type:
                foul_lines.append('mid')

        return FoulResult(has_foul=len(foul_lines) > 0, foul_lines=foul_lines)

    def get_foul_warning(self) -> list:
        """현재 배치 기준 폴 위험 경고 문자열 반환"""
        warnings = []

        back_type = evaluate_hand(self.back).hand_type if self.back else None
        mid_type = evaluate_hand(self.mid).hand_type if self.mid else None
        front_type = evaluate_hand(self.front).hand_type if self.front else None

        if back_type is not None and mid_type is not None:
            if back_type < mid_type:
                warnings.append("경고: Back 라인이 Mid보다 약합니다 (Foul 위험)")

        if mid_type is not None and front_type is not None:
            if mid_type < front_type:
                warnings.append("경고: Mid 라인이 Front보다 약합니다 (Foul 위험)")

        if len(self.front) < 3:
            warnings.append("알림: Front 라인 미완성 (배치 전 반드시 확인)")

        return warnings

    def get_hand_results(self) -> dict:
        """front/mid/back 각 라인 핸드 판정 결과 반환"""
        result = {}
        if self.front:
            result['front'] = evaluate_hand(self.front)
        if self.mid:
            result['mid'] = evaluate_hand(self.mid)
        if self.back:
            result['back'] = evaluate_hand(self.back)
        return result

    def check_fantasyland(self) -> bool:
        """판타지랜드 진입 조건: Front QQ 이상 페어 + Foul 없음 (모듈 레벨 함수 위임)"""
        return check_fantasyland(self)


def check_fantasyland(board: 'OFCBoard') -> bool:
    """Front 라인 QQ+ 원페어 이상 달성 여부 판정 (PRD §6.6, alpha.design.md §5.3).

    판정 기준:
    - ONE_PAIR: 페어 랭크가 QUEEN(12) 이상
    - THREE_OF_A_KIND: 항상 True (Front 최강 핸드)
    - 그 외 (HIGH_CARD, ONE_PAIR with rank < Q): False
    """
    from collections import Counter

    from src.card import Rank
    from src.hand import HandType

    if not board.front:
        return False

    front_hand = evaluate_hand(board.front)

    if front_hand.hand_type == HandType.ONE_PAIR:
        rank_counts = Counter(c.rank for c in board.front)
        pair_ranks = [r for r, cnt in rank_counts.items() if cnt >= 2]
        return bool(pair_ranks) and max(pair_ranks) >= Rank.QUEEN

    # THREE_OF_A_KIND 이상 (Front 3장 기준 최강)
    return front_hand.hand_type > HandType.ONE_PAIR
