import os
import sys

# 프로젝트 루트를 sys.path에 추가
_project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if _project_root not in sys.path:
    sys.path.insert(0, _project_root)

from src.board import OFCBoard  # noqa: E402
from src.combat import CombatResult  # noqa: E402
from src.economy import Player  # noqa: E402
from src.game import GameState  # noqa: E402

# 랭크 표시 문자열 매핑 (rank.value → 표시 문자)
RANK_DISPLAY = {
    2: '2', 3: '3', 4: '4', 5: '5', 6: '6', 7: '7', 8: '8',
    9: '9', 10: 'T', 11: 'J', 12: 'Q', 13: 'K', 14: 'A',
}
# 수트 유니코드 심볼
SUIT_SYMBOLS = {1: '♣', 2: '♦', 3: '♥', 4: '♠'}
# CSS 클래스용 수트 이름
SUIT_NAMES = {1: 'club', 2: 'diamond', 3: 'heart', 4: 'spade'}


def serialize_card(card) -> dict | None:
    """Card 객체를 JSON 직렬화 가능한 dict로 변환. None 입력 시 None 반환."""
    if card is None:
        return None
    rank_str = RANK_DISPLAY.get(card.rank.value, card.rank.name)
    suit_int = card.suit.value
    return {
        'rank': rank_str,
        'suit': suit_int,
        'suit_symbol': SUIT_SYMBOLS[suit_int],
        'suit_name': SUIT_NAMES[suit_int],
        'stars': card.stars,
        'cost': card.cost,
        'key': f'{rank_str}_{suit_int}',
    }


def _pad_line(cards: list, max_len: int) -> list:
    """카드 리스트를 직렬화 후 null 패딩으로 고정 크기 배열 반환."""
    serialized = [serialize_card(c) for c in cards]
    while len(serialized) < max_len:
        serialized.append(None)
    return serialized


def serialize_board(board: OFCBoard) -> dict:
    """OFCBoard를 JSON 직렬화 가능한 dict로 변환. hand_results + foul 포함."""
    hand_results = board.get_hand_results()
    foul = board.check_foul()

    return {
        'front': _pad_line(board.front, 3),
        'mid': _pad_line(board.mid, 5),
        'back': _pad_line(board.back, 5),
        'foul': foul.has_foul,
        'foul_lines': foul.foul_lines,
        'hand_strengths': {
            'front': hand_results['front'].hand_type.name if 'front' in hand_results else None,
            'mid': hand_results['mid'].hand_type.name if 'mid' in hand_results else None,
            'back': hand_results['back'].hand_type.name if 'back' in hand_results else None,
        },
        'warnings': board.get_foul_warning(),
    }


def serialize_player(player: Player, player_id: int) -> dict:
    """Player 객체를 JSON 직렬화 가능한 dict로 변환."""
    return {
        'id': player_id,
        'name': player.name,
        'hp': player.hp,
        'gold': player.gold,
        'level': player.level,
        'xp': player.xp,
        'win_streak': player.win_streak,
        'loss_streak': player.loss_streak,
        'board': serialize_board(player.board),
        'bench': [serialize_card(c) for c in player.bench],
        'shop_cards': [serialize_card(c) for c in player.shop_cards],
        'augments': [
            {'id': a.id, 'name': a.name, 'description': a.description}
            for a in player.augments
        ],
        'in_fantasyland': player.in_fantasyland,
        'hula_declared': player.hula_declared,
    }


def serialize_combat_result(result: CombatResult, player_name: str) -> dict:
    """CombatResult 객체를 JSON 직렬화 가능한 dict로 변환."""
    return {
        'player_name': player_name,
        'line_results': result.line_results,
        'winner_lines': result.winner_lines,
        'is_scoop': result.is_scoop,
        'damage': result.damage,
        'hula_applied': result.hula_applied,
        'stop_applied': result.stop_applied,
    }


def _serialize_results_with_names(results: list, state: GameState) -> list:
    """[(CombatResult_A, CombatResult_B), ...] → [{pair}, ...] 변환.
    state.combat_pairs에서 플레이어 인덱스 추출 후 이름 매핑.
    """
    serialized = []
    for idx, (result_a, result_b) in enumerate(results):
        # combat_pairs: [(idx_p1, idx_p2), ...] 형태
        if idx < len(state.combat_pairs):
            pair = state.combat_pairs[idx]
            n = len(state.players)
            name_a = state.players[pair[0]].name if pair[0] < n else f'Player{idx * 2 + 1}'
            name_b = state.players[pair[1]].name if pair[1] < n else f'Player{idx * 2 + 2}'
        else:
            name_a = f'Player{idx * 2 + 1}'
            name_b = f'Player{idx * 2 + 2}'
        serialized.append({
            'player_a': serialize_combat_result(result_a, name_a),
            'player_b': serialize_combat_result(result_b, name_b),
        })
    return serialized


def serialize_game(
    state: GameState,
    combat_results: list = None,
    ready_flags: dict = None,
) -> dict:
    """GameState 전체를 JSON 직렬화 가능한 dict로 변환."""
    # ready_flags 키를 문자열로 변환 (JSON 직렬화 호환)
    ready_flags_str = {str(k): v for k, v in (ready_flags or {}).items()}

    return {
        'round_num': state.round_num,
        'max_rounds': state.max_rounds,
        'phase': state.phase,
        'players': [serialize_player(p, i) for i, p in enumerate(state.players)],
        'combat_pairs': state.combat_pairs,
        'last_combat_results': (
            _serialize_results_with_names(combat_results, state)
            if combat_results else None
        ),
        'ready_flags': ready_flags_str,
        'is_game_over': state.is_game_over(),
        'winner': state.get_winner().name if state.get_winner() else None,
    }
