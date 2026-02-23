import os
import sys

# 프로젝트 루트를 sys.path에 추가
_project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if _project_root not in sys.path:
    sys.path.insert(0, _project_root)

from flask import Flask, abort, jsonify, request, send_from_directory  # noqa: E402

from src.economy import Player  # noqa: E402
from src.game import GameState, RoundManager  # noqa: E402
from src.pool import SharedCardPool  # noqa: E402
from web.serializer import serialize_game  # noqa: E402

app = Flask(__name__, static_folder='static', static_url_path='/static')

# 모듈 레벨 단일 게임 인스턴스 (threaded=False로 경쟁 조건 방지)
_game_state: 'GameState | None' = None
_round_manager: 'RoundManager | None' = None
_pool: 'SharedCardPool | None' = None
_ready_flags: 'dict[int, bool]' = {}
_last_combat_results: list = []


# ── 라우트 ──────────────────────────────────────────────────────────────────

@app.route('/')
def index():
    """메인 HTML 페이지 서빙"""
    return send_from_directory(app.static_folder, 'index.html')


@app.route('/api/start', methods=['POST'])
def start_game():
    """새 게임 초기화. num_players(2~8) + player_names 파라미터."""
    global _game_state, _round_manager, _pool, _ready_flags, _last_combat_results

    data = request.get_json(silent=True)
    if data is None:
        abort(400, '잘못된 요청 형식입니다')

    num_players = data.get('num_players', 2)
    if not isinstance(num_players, int) or not (2 <= num_players <= 8):
        abort(400, '플레이어 수는 2~8 사이여야 합니다')

    player_names = data.get('player_names', [])
    names = [
        player_names[i] if i < len(player_names) and player_names[i]
        else f'Player{i + 1}'
        for i in range(num_players)
    ]

    _pool = SharedCardPool()
    _pool.initialize()
    players = [Player(name=names[i]) for i in range(num_players)]
    _game_state = GameState(players=players, pool=_pool)
    _round_manager = RoundManager(_game_state)
    _round_manager.start_prep_phase()
    _ready_flags = {i: False for i in range(num_players)}
    _last_combat_results = []

    state_data = serialize_game(_game_state, _last_combat_results, _ready_flags)
    return jsonify({'success': True, 'state': state_data})


@app.route('/api/state', methods=['GET'])
def get_state():
    """현재 게임 상태 반환"""
    if _game_state is None:
        abort(400, '게임이 시작되지 않았습니다')
    state_data = serialize_game(_game_state, _last_combat_results, _ready_flags)
    return jsonify({'success': True, 'state': state_data})


@app.route('/api/action', methods=['POST'])
def action():
    """플레이어 액션 처리. 7가지 action_type 지원."""
    if _game_state is None:
        abort(400, '게임이 시작되지 않았습니다')

    data = request.get_json(silent=True)
    if data is None:
        abort(400, '잘못된 요청 형식입니다')

    player_id = data.get('player_id')
    action_type = data.get('action_type')
    payload = data.get('payload', {})

    if not isinstance(player_id, int) or not (0 <= player_id < len(_game_state.players)):
        abort(400, '유효하지 않은 player_id입니다')

    player = _game_state.players[player_id]

    try:
        if action_type == 'buy_card':
            return _handle_buy_card(player, payload)
        elif action_type == 'place_card':
            return _handle_place_card(player, payload)
        elif action_type == 'sell_card':
            return _handle_sell_card(player, payload)
        elif action_type == 'remove_card':
            return _handle_remove_card(player, payload)
        elif action_type == 'roll_shop':
            return _handle_roll_shop(player)
        elif action_type == 'ready':
            return _handle_ready(player_id, player)
        elif action_type == 'next_round':
            return _handle_next_round()
        else:
            abort(400, f"알 수 없는 action_type: '{action_type}'")
    except ValueError as e:
        abort(400, str(e))


@app.route('/api/reset', methods=['POST'])
def reset_game():
    """게임 인스턴스 초기화"""
    global _game_state, _round_manager, _pool, _ready_flags, _last_combat_results
    _game_state = None
    _round_manager = None
    _pool = None
    _ready_flags = {}
    _last_combat_results = []
    return jsonify({'success': True, 'state': None})


# ── 액션 핸들러 ──────────────────────────────────────────────────────────────

def _handle_buy_card(player, payload):
    """상점 카드 구매: 골드 차감 + 벤치 추가 + 별 강화 자동 트리거"""
    if _game_state.phase != 'prep':
        raise ValueError('현재 페이즈에서 수행할 수 없는 액션입니다')

    card_index = payload.get('card_index')
    if not isinstance(card_index, int) or not (0 <= card_index < len(player.shop_cards)):
        raise ValueError('유효하지 않은 card_index입니다')

    card = player.shop_cards[card_index]
    if not player.can_buy(card):
        raise ValueError('골드가 부족합니다')

    # buy_card 내부에서 pool.draw() + bench.append() + try_star_upgrade() 호출
    success = player.buy_card(card, _pool)
    if not success:
        raise ValueError('카드 구매에 실패했습니다 (풀에서 드로우 불가)')

    player.shop_cards.pop(card_index)
    return _ok_response()


def _handle_place_card(player, payload):
    """벤치 카드를 OFC 보드 라인에 배치"""
    if _game_state.phase != 'prep':
        raise ValueError('현재 페이즈에서 수행할 수 없는 액션입니다')

    card_index = payload.get('card_index')
    line = payload.get('line')
    if not isinstance(card_index, int) or not (0 <= card_index < len(player.bench)):
        raise ValueError('유효하지 않은 card_index입니다')
    if line not in ('front', 'mid', 'back'):
        raise ValueError('유효하지 않은 라인입니다')

    card = player.bench[card_index]
    success = player.board.place_card(line, card)
    if not success:
        raise ValueError(f"'{line}' 라인이 가득 찼습니다")

    player.bench.pop(card_index)
    return _ok_response()


def _handle_sell_card(player, payload):
    """벤치 카드 매각: 골드 반환 + 풀 반환"""
    if _game_state.phase != 'prep':
        raise ValueError('현재 페이즈에서 수행할 수 없는 액션입니다')

    card_index = payload.get('card_index')
    if not isinstance(card_index, int) or not (0 <= card_index < len(player.bench)):
        raise ValueError('유효하지 않은 card_index입니다')

    card = player.bench[card_index]
    sell_price = player.sell_card(card, _pool)
    if sell_price == 0:
        raise ValueError('카드 매각에 실패했습니다')

    return _ok_response()


def _handle_remove_card(player, payload):
    """보드 카드를 벤치로 회수 (prep 페이즈에서만 허용)"""
    if _game_state.phase != 'prep':
        raise ValueError('현재 페이즈에서 수행할 수 없는 액션입니다')

    line = payload.get('line')
    slot = payload.get('slot')
    if line not in ('front', 'mid', 'back'):
        raise ValueError('유효하지 않은 라인입니다')

    board_line = getattr(player.board, line)
    if not isinstance(slot, int) or not (0 <= slot < len(board_line)):
        raise ValueError('유효하지 않은 slot 인덱스입니다')

    card = board_line[slot]
    success = player.board.remove_card(line, card)
    if not success:
        raise ValueError('카드 제거에 실패했습니다')

    player.bench.append(card)
    return _ok_response()


def _handle_roll_shop(player):
    """상점 새로고침: 골드 2 소모 + 기존 shop_cards 풀 반환 + 재드로우"""
    if _game_state.phase != 'prep':
        raise ValueError('현재 페이즈에서 수행할 수 없는 액션입니다')

    roll_cost = 2
    if player.gold < roll_cost:
        raise ValueError('골드가 부족합니다 (새로고침 비용: 2골드)')

    # 기존 shop_cards 풀 반환
    for card in player.shop_cards:
        _pool.return_card(card)
    player.shop_cards = []

    # 새 카드 드로우 (lucky_shop 증강체 시 6장)
    shop_size = 6 if player.has_augment('lucky_shop') else 5
    player.shop_cards = _pool.random_draw_n(shop_size, player.level)
    player.gold -= roll_cost

    return _ok_response()


def _handle_ready(player_id: int, player):
    """준비 완료 선언. 모든 플레이어 준비 시 전투 자동 트리거."""
    global _ready_flags, _last_combat_results

    if _game_state.phase != 'prep':
        raise ValueError('현재 페이즈에서 수행할 수 없는 액션입니다')

    _ready_flags[player_id] = True

    if all(_ready_flags.values()):
        # 모든 플레이어 준비 완료 → 전투 실행
        results = _round_manager.start_combat_phase()
        _last_combat_results = results
        _game_state.phase = 'result'

    return _ok_response()


def _handle_next_round():
    """다음 라운드 시작.
    1. 미구매 shop_cards → pool.return_card() (풀 누수 방지)
    2. end_round() 호출 (라운드 번호 증가 + 보드 리셋)
    3. start_prep_phase() 호출 (골드 지급 + 새 상점 드로우)
    4. ready_flags 재초기화
    """
    global _ready_flags, _last_combat_results

    if _game_state.phase not in ('result', 'combat'):
        raise ValueError('현재 페이즈에서 수행할 수 없는 액션입니다')

    # 미구매 shop_cards 풀 반환 (풀 누수 방지)
    for p in _game_state.players:
        for card in p.shop_cards:
            _pool.return_card(card)
        p.shop_cards = []

    # 라운드 종료 처리 (번호 증가, 보드 리셋, 증강체 선택, 탈락자 처리)
    _round_manager.end_round()
    _last_combat_results = []

    if _game_state.phase == 'end':
        # 게임 종료 상태 — start_prep_phase 불필요
        return _ok_response()

    # 다음 라운드 prep 시작 (골드 지급 + 새 상점 드로우)
    _round_manager.start_prep_phase()

    # ready_flags 재초기화
    _ready_flags = {i: False for i in range(len(_game_state.players))}

    return _ok_response()


# ── 헬퍼 + 에러 핸들러 ───────────────────────────────────────────────────────

def _ok_response():
    """표준 성공 응답 반환 헬퍼"""
    state_data = serialize_game(_game_state, _last_combat_results, _ready_flags)
    return jsonify({'success': True, 'state': state_data})


@app.errorhandler(400)
def bad_request(e):
    return jsonify({'success': False, 'error': str(e.description)}), 400


@app.errorhandler(500)
def internal_error(e):
    return jsonify({'success': False, 'error': '서버 내부 오류'}), 500


if __name__ == '__main__':
    # threaded=False: 단일 게임 인스턴스 패턴에서 경쟁 조건 방지
    app.run(debug=True, threaded=False, port=5000)
