"""tests/test_web_api.py — Flask test_client 기반 API 엔드포인트 테스트 (14개)"""
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import pytest


@pytest.fixture(autouse=True)
def reset_app_state():
    """각 테스트 전후 앱 전역 상태 초기화"""
    import web.app as app_module
    app_module._game_state = None
    app_module._round_manager = None
    app_module._pool = None
    app_module._ready_flags = {}
    app_module._last_combat_results = []
    yield
    app_module._game_state = None
    app_module._round_manager = None
    app_module._pool = None
    app_module._ready_flags = {}
    app_module._last_combat_results = []


@pytest.fixture
def client():
    """Flask test_client 픽스처"""
    from web.app import app
    app.config['TESTING'] = True
    with app.test_client() as c:
        yield c


@pytest.fixture
def started_client(client):
    """게임 시작 상태의 클라이언트 픽스처"""
    client.post('/api/start', json={'num_players': 2, 'player_names': ['P1', 'P2']})
    return client


# ── Test 1: 게임 시작 성공 ────────────────────────────────────────────────────

def test_start_game_success(client):
    """POST /api/start → 200, success=true, phase='prep', players 길이 = 2"""
    resp = client.post('/api/start', json={'num_players': 2, 'player_names': ['Alice', 'Bob']})
    data = resp.get_json()

    assert resp.status_code == 200
    assert data['success'] is True
    assert data['state']['phase'] == 'prep'
    assert len(data['state']['players']) == 2
    assert data['state']['players'][0]['name'] == 'Alice'
    assert data['state']['players'][1]['name'] == 'Bob'


# ── Test 2: 잘못된 플레이어 수 ──────────────────────────────────────────────

def test_start_game_invalid_players(client):
    """num_players=10 → 400, success=false"""
    resp = client.post('/api/start', json={'num_players': 10})
    data = resp.get_json()

    assert resp.status_code == 400
    assert data['success'] is False
    assert 'error' in data


# ── Test 3: 게임 시작 전 상태 조회 ──────────────────────────────────────────

def test_get_state_before_start(client):
    """게임 미시작 시 GET /api/state → 400"""
    resp = client.get('/api/state')
    data = resp.get_json()

    assert resp.status_code == 400
    assert data['success'] is False


# ── Test 4: 게임 시작 후 상태 조회 ──────────────────────────────────────────

def test_get_state_after_start(started_client):
    """게임 시작 후 GET /api/state → 200, round_num=1, phase='prep'"""
    resp = started_client.get('/api/state')
    data = resp.get_json()

    assert resp.status_code == 200
    assert data['success'] is True
    assert data['state']['round_num'] == 1
    assert data['state']['phase'] == 'prep'


# ── Test 5: 카드 구매 ─────────────────────────────────────────────────────────

def test_action_buy_card(started_client):
    """buy_card 성공 → 골드 차감 + 벤치에 카드 추가"""
    # 먼저 플레이어 0의 현재 상태 확인
    state_resp = started_client.get('/api/state')
    state = state_resp.get_json()['state']
    player0 = state['players'][0]
    initial_gold = player0['gold']
    shop = player0['shop_cards']

    # 구매 가능한 카드 찾기 (골드 충분한 카드)
    buyable_idx = None
    for i, card in enumerate(shop):
        if card and card['cost'] <= initial_gold:
            buyable_idx = i
            break

    if buyable_idx is None:
        pytest.skip('구매 가능한 카드가 없습니다 (골드 부족)')

    card_cost = shop[buyable_idx]['cost']
    resp = started_client.post('/api/action', json={
        'player_id': 0,
        'action_type': 'buy_card',
        'payload': {'card_index': buyable_idx},
    })
    data = resp.get_json()

    assert resp.status_code == 200
    assert data['success'] is True
    # 골드 차감 확인
    new_gold = data['state']['players'][0]['gold']
    assert new_gold == initial_gold - card_cost
    # 벤치에 카드 추가 확인
    assert len(data['state']['players'][0]['bench']) > 0


# ── Test 6: 골드 부족 시 카드 구매 실패 ──────────────────────────────────────

def test_action_buy_card_insufficient_gold(started_client):
    """골드 부족 시 buy_card → 400, success=false"""
    # 플레이어 0의 골드를 강제로 0으로 설정
    import web.app as app_module
    app_module._game_state.players[0].gold = 0

    resp = started_client.post('/api/action', json={
        'player_id': 0,
        'action_type': 'buy_card',
        'payload': {'card_index': 0},
    })
    data = resp.get_json()

    assert resp.status_code == 400
    assert data['success'] is False


# ── Test 7: 카드 배치 ─────────────────────────────────────────────────────────

def test_action_place_card(started_client):
    """place_card 성공 → 보드 해당 라인에 카드 + 벤치에서 제거"""
    import web.app as app_module
    from src.card import Card, Rank, Suit

    # 벤치에 직접 카드 추가
    test_card = Card(Rank.ACE, Suit.SPADE)
    app_module._game_state.players[0].bench.append(test_card)

    resp = started_client.post('/api/action', json={
        'player_id': 0,
        'action_type': 'place_card',
        'payload': {'card_index': 0, 'line': 'back'},
    })
    data = resp.get_json()

    assert resp.status_code == 200
    assert data['success'] is True
    # 보드 back[0]에 카드 있음
    assert data['state']['players'][0]['board']['back'][0] is not None
    # 벤치 비어있음
    assert len(data['state']['players'][0]['bench']) == 0


# ── Test 8: 카드 매각 ─────────────────────────────────────────────────────────

def test_action_sell_card(started_client):
    """sell_card 성공 → 골드 증가 + 벤치에서 제거"""
    import web.app as app_module
    from src.card import Card, Rank, Suit

    # 벤치에 직접 카드 추가
    test_card = Card(Rank.ACE, Suit.SPADE)
    app_module._game_state.players[0].bench.append(test_card)
    initial_gold = app_module._game_state.players[0].gold

    resp = started_client.post('/api/action', json={
        'player_id': 0,
        'action_type': 'sell_card',
        'payload': {'card_index': 0},
    })
    data = resp.get_json()

    assert resp.status_code == 200
    assert data['success'] is True
    # 골드 증가 확인
    assert data['state']['players'][0]['gold'] > initial_gold
    # 벤치 비어있음
    assert len(data['state']['players'][0]['bench']) == 0


# ── Test 9: 상점 새로고침 ────────────────────────────────────────────────────

def test_action_roll_shop(started_client):
    """roll_shop 성공 → 골드 2 차감 + 새 shop_cards 최대 5장"""
    import web.app as app_module
    # 골드 충분하게 설정
    app_module._game_state.players[0].gold = 10
    initial_gold = 10

    resp = started_client.post('/api/action', json={
        'player_id': 0,
        'action_type': 'roll_shop',
        'payload': {},
    })
    data = resp.get_json()

    assert resp.status_code == 200
    assert data['success'] is True
    # 골드 2 차감
    assert data['state']['players'][0]['gold'] == initial_gold - 2
    # shop_cards 존재 (최대 5장)
    assert len(data['state']['players'][0]['shop_cards']) <= 5


# ── Test 10: ready 후 전투 트리거 ────────────────────────────────────────────

def test_action_ready_triggers_combat(started_client):
    """2인 모두 ready → phase='result', last_combat_results 존재"""
    resp0 = started_client.post('/api/action', json={
        'player_id': 0, 'action_type': 'ready', 'payload': {},
    })
    assert resp0.get_json()['success'] is True

    resp1 = started_client.post('/api/action', json={
        'player_id': 1, 'action_type': 'ready', 'payload': {},
    })
    data = resp1.get_json()

    assert resp1.status_code == 200
    assert data['success'] is True
    assert data['state']['phase'] == 'result'
    assert data['state']['last_combat_results'] is not None


# ── Test 11: 다음 라운드 ─────────────────────────────────────────────────────

def test_action_next_round(started_client):
    """2인 ready 후 next_round → phase='prep', round_num=2, ready_flags false"""
    # 두 플레이어 모두 ready
    started_client.post('/api/action', json={
        'player_id': 0, 'action_type': 'ready', 'payload': {},
    })
    started_client.post('/api/action', json={
        'player_id': 1, 'action_type': 'ready', 'payload': {},
    })

    # next_round 호출
    resp = started_client.post('/api/action', json={
        'player_id': 0, 'action_type': 'next_round', 'payload': {},
    })
    data = resp.get_json()

    assert resp.status_code == 200
    assert data['success'] is True
    assert data['state']['round_num'] == 2
    assert data['state']['phase'] == 'prep'
    assert data['state']['last_combat_results'] is None
    assert all(v is False for v in data['state']['ready_flags'].values())


# ── Test 12: 잘못된 action_type ─────────────────────────────────────────────

def test_action_invalid_type(started_client):
    """잘못된 action_type='invalid' → 400, success=false"""
    resp = started_client.post('/api/action', json={
        'player_id': 0,
        'action_type': 'invalid',
        'payload': {},
    })
    data = resp.get_json()

    assert resp.status_code == 400
    assert data['success'] is False


# ── Test 13: 게임 리셋 ───────────────────────────────────────────────────────

def test_reset_game(started_client):
    """POST /api/reset → success=true, state=null"""
    resp = started_client.post('/api/reset')
    data = resp.get_json()

    assert resp.status_code == 200
    assert data['success'] is True
    assert data['state'] is None

    # 리셋 후 상태 조회 시 400
    state_resp = started_client.get('/api/state')
    assert state_resp.status_code == 400


# ── Test 14: remove_card ────────────────────────────────────────────────────

def test_full_round_flow(started_client):
    """start → place_card → remove_card → ready×2 → next_round 전체 플로우"""
    import web.app as app_module
    from src.card import Card, Rank, Suit

    # 벤치에 카드 추가 후 배치
    test_card = Card(Rank.ACE, Suit.SPADE)
    app_module._game_state.players[0].bench.append(test_card)

    # place_card
    place_resp = started_client.post('/api/action', json={
        'player_id': 0,
        'action_type': 'place_card',
        'payload': {'card_index': 0, 'line': 'back'},
    })
    assert place_resp.get_json()['success'] is True
    assert place_resp.get_json()['state']['players'][0]['board']['back'][0] is not None

    # remove_card (Architect 권장 케이스)
    remove_resp = started_client.post('/api/action', json={
        'player_id': 0,
        'action_type': 'remove_card',
        'payload': {'line': 'back', 'slot': 0},
    })
    data = remove_resp.get_json()
    assert data['success'] is True
    # 보드 슬롯 null 확인
    assert all(s is None for s in data['state']['players'][0]['board']['back'])
    # 벤치에 카드 복원 확인
    assert len(data['state']['players'][0]['bench']) > 0

    # 두 플레이어 ready
    started_client.post('/api/action', json={
        'player_id': 0, 'action_type': 'ready', 'payload': {},
    })
    started_client.post('/api/action', json={
        'player_id': 1, 'action_type': 'ready', 'payload': {},
    })

    # next_round
    nr_resp = started_client.post('/api/action', json={
        'player_id': 0, 'action_type': 'next_round', 'payload': {},
    })
    nr_data = nr_resp.get_json()
    assert nr_data['success'] is True
    assert nr_data['state']['phase'] == 'prep'
    assert nr_data['state']['round_num'] == 2
