"""tests/test_serializer.py — web/serializer.py 직렬화 단위 테스트 (12개)"""
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import pytest
from src.card import Card, Rank, Suit
from src.board import OFCBoard
from src.economy import Player
from src.game import GameState
from src.pool import SharedCardPool
from src.combat import CombatResult
from web.serializer import (
    serialize_card,
    serialize_board,
    serialize_player,
    serialize_game,
    serialize_combat_result,
)


# ── Test 1: 기본 카드 직렬화 ──────────────────────────────────────────────────

def test_serialize_card_basic():
    """ACE of SPADE 기본 직렬화 검증"""
    card = Card(Rank.ACE, Suit.SPADE, stars=1)
    result = serialize_card(card)
    assert result['rank'] == 'A'
    assert result['suit'] == 4
    assert result['suit_symbol'] == '♠'
    assert result['suit_name'] == 'spade'
    assert result['stars'] == 1
    assert result['cost'] == 5
    assert result['key'] == 'A_4'


# ── Test 2: None 카드 직렬화 ──────────────────────────────────────────────────

def test_serialize_card_none():
    """None 입력 시 None 반환"""
    assert serialize_card(None) is None


# ── Test 3: 별 강화 카드 직렬화 ───────────────────────────────────────────────

def test_serialize_card_starred():
    """2성 카드의 stars 필드 + cost 유지 검증"""
    card = Card(Rank.KING, Suit.HEART, stars=2)
    result = serialize_card(card)
    assert result['stars'] == 2
    assert result['cost'] == 4
    assert result['rank'] == 'K'
    assert result['suit_symbol'] == '♥'


# ── Test 4: 빈 보드 직렬화 ───────────────────────────────────────────────────

def test_serialize_board_empty():
    """빈 OFCBoard → null 패딩 + foul=false + hand_strengths 모두 null"""
    board = OFCBoard()
    result = serialize_board(board)

    assert result['front'] == [None, None, None]
    assert result['mid'] == [None, None, None, None, None]
    assert result['back'] == [None, None, None, None, None]
    assert result['foul'] is False
    assert result['foul_lines'] == []
    assert result['hand_strengths']['front'] is None
    assert result['hand_strengths']['mid'] is None
    assert result['hand_strengths']['back'] is None


# ── Test 5: 카드 있는 보드 직렬화 ────────────────────────────────────────────

def test_serialize_board_with_cards():
    """카드 배치된 보드 → 올바른 직렬화 + null 패딩 정확도"""
    board = OFCBoard()
    card1 = Card(Rank.ACE, Suit.SPADE)
    card2 = Card(Rank.KING, Suit.HEART)
    board.place_card('back', card1)
    board.place_card('back', card2)

    result = serialize_board(board)
    # back[0] 카드 존재
    assert result['back'][0] is not None
    assert result['back'][0]['rank'] == 'A'
    assert result['back'][1] is not None
    assert result['back'][1]['rank'] == 'K'
    # back[2]~[4] null 패딩
    assert result['back'][2] is None
    assert result['back'][3] is None
    assert result['back'][4] is None
    # front, mid는 모두 null
    assert all(s is None for s in result['front'])
    assert all(s is None for s in result['mid'])


# ── Test 6: Foul 보드 직렬화 ─────────────────────────────────────────────────

def test_serialize_board_foul():
    """Back에 약한 핸드, Mid에 강한 핸드 → foul=true, foul_lines 포함"""
    board = OFCBoard()
    # Back: HIGH_CARD (낮은 핸드)
    board.place_card('back', Card(Rank.TWO, Suit.CLUB))
    board.place_card('back', Card(Rank.FOUR, Suit.DIAMOND))
    board.place_card('back', Card(Rank.SIX, Suit.HEART))
    board.place_card('back', Card(Rank.EIGHT, Suit.SPADE))
    board.place_card('back', Card(Rank.TEN, Suit.CLUB))
    # Mid: FLUSH (강한 핸드)
    board.place_card('mid', Card(Rank.ACE, Suit.SPADE))
    board.place_card('mid', Card(Rank.KING, Suit.SPADE))
    board.place_card('mid', Card(Rank.QUEEN, Suit.SPADE))
    board.place_card('mid', Card(Rank.JACK, Suit.SPADE))
    board.place_card('mid', Card(Rank.NINE, Suit.SPADE))

    result = serialize_board(board)
    assert result['foul'] is True
    assert 'back' in result['foul_lines']


# ── Test 7: hand_strengths 직렬화 ─────────────────────────────────────────────

def test_serialize_board_hand_results():
    """Back에 플러시 5장 배치 → hand_strengths.back == 'FLUSH'"""
    board = OFCBoard()
    board.place_card('back', Card(Rank.ACE, Suit.SPADE))
    board.place_card('back', Card(Rank.KING, Suit.SPADE))
    board.place_card('back', Card(Rank.QUEEN, Suit.SPADE))
    board.place_card('back', Card(Rank.JACK, Suit.SPADE))
    board.place_card('back', Card(Rank.NINE, Suit.SPADE))

    result = serialize_board(board)
    assert result['hand_strengths']['back'] == 'FLUSH'
    assert result['hand_strengths']['front'] is None
    assert result['hand_strengths']['mid'] is None


# ── Test 8: 기본 플레이어 직렬화 ─────────────────────────────────────────────

def test_serialize_player_basic():
    """Player 전체 필드 직렬화 검증"""
    player = Player(name='TestPlayer')
    result = serialize_player(player, player_id=0)

    assert result['id'] == 0
    assert result['name'] == 'TestPlayer'
    assert result['hp'] == 100
    assert result['gold'] == 0
    assert result['level'] == 1
    assert result['xp'] == 0
    assert result['win_streak'] == 0
    assert result['loss_streak'] == 0
    assert isinstance(result['board'], dict)
    assert result['bench'] == []
    assert result['shop_cards'] == []
    assert result['augments'] == []
    assert result['in_fantasyland'] is False
    assert result['hula_declared'] is False


# ── Test 9: 증강체 보유 플레이어 직렬화 ──────────────────────────────────────

def test_serialize_player_with_augments():
    """증강체 보유 플레이어 → augments 배열에 id/name/description 필드 존재"""
    from src.augment import SILVER_AUGMENTS
    player = Player(name='AugPlayer')
    if SILVER_AUGMENTS:
        augment = SILVER_AUGMENTS[0]
        player.add_augment(augment)

    result = serialize_player(player, player_id=1)
    if SILVER_AUGMENTS:
        assert len(result['augments']) == 1
        aug_result = result['augments'][0]
        assert 'id' in aug_result
        assert 'name' in aug_result
        assert 'description' in aug_result
    else:
        assert result['augments'] == []


# ── Test 10: 게임 상태 직렬화 ────────────────────────────────────────────────

def test_serialize_game_state():
    """GameState 전체 직렬화 → round_num=1, phase='prep', players 길이 일치"""
    pool = SharedCardPool()
    pool.initialize()
    players = [Player(name='P1'), Player(name='P2')]
    state = GameState(players=players, pool=pool)

    result = serialize_game(state, combat_results=None, ready_flags={0: False, 1: False})

    assert result['round_num'] == 1
    assert result['phase'] == 'prep'
    assert len(result['players']) == 2
    assert result['is_game_over'] is False
    assert result['winner'] is None
    assert result['last_combat_results'] is None
    assert result['ready_flags']['0'] is False
    assert result['ready_flags']['1'] is False


# ── Test 11: 전투 결과 직렬화 ────────────────────────────────────────────────

def test_serialize_combat_result():
    """CombatResult 직렬화 → 모든 필드 정확도 검증"""
    result = CombatResult(
        line_results={'back': 1, 'mid': -1, 'front': 0},
        winner_lines=1,
        is_scoop=False,
        damage=2,
        hula_applied=False,
        stop_applied=False,
    )
    serialized = serialize_combat_result(result, player_name='Player1')

    assert serialized['player_name'] == 'Player1'
    assert serialized['line_results'] == {'back': 1, 'mid': -1, 'front': 0}
    assert serialized['winner_lines'] == 1
    assert serialized['is_scoop'] is False
    assert serialized['damage'] == 2
    assert serialized['hula_applied'] is False
    assert serialized['stop_applied'] is False


# ── Test 12: remove_card 후 직렬화 ───────────────────────────────────────────

def test_remove_card_roundtrip():
    """카드 배치 후 remove_card 호출 → 슬롯 null 처리 반영 확인"""
    board = OFCBoard()
    card = Card(Rank.ACE, Suit.SPADE)
    board.place_card('back', card)

    # 배치 직후 직렬화 확인
    before = serialize_board(board)
    assert before['back'][0] is not None
    assert before['back'][0]['rank'] == 'A'

    # remove_card 후 직렬화
    board.remove_card('back', card)
    after = serialize_board(board)
    assert all(s is None for s in after['back'])
    assert after['foul'] is False
