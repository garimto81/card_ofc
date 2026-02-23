# Trump Card Auto Chess — MVP 구현 계획

**버전**: 1.0.0
**복잡도**: STANDARD (3/5)
**기반 PRD**: docs/01-plan/card-autochess.prd.md §17
**작성일**: 2026-02-23
**선행 단계**: POC → Alpha → Standard → Web GUI (모두 완료)

---

## 목차

1. [개요](#1-개요)
2. [MVP 갭 분석](#2-mvp-갭-분석)
3. [구현 순서 (M1~M4)](#3-구현-순서-m1m4)
4. [파일별 변경 명세](#4-파일별-변경-명세)
5. [TDD 테스트 계획](#5-tdd-테스트-계획)
6. [완료 기준](#6-완료-기준-definition-of-done)
7. [위험 요소 및 완화 방안](#7-위험-요소-및-완화-방안)

---

## 1. 개요

### 1.1 배경 및 목적

Trump Card Auto Chess는 POC → Alpha → Standard → Web GUI 4단계 PDCA를 거쳐 코어 게임 루프와 Flask 기반 Web GUI가 구현된 상태다. 현재 319개 테스트가 전부 통과하며 2인 로컬 대전이 브라우저에서 가능하다.

MVP 단계는 PRD §17.1 P0 필수 기능 목록 중 **미구현 항목**을 완성하여 8인 실전 플레이가 가능한 최소 출시 가능 제품(Minimum Viable Product)을 완성하는 단계다.

### 1.2 현재 구현 현황

#### 완료된 파일 구조

```
src/
├── card.py        - Card, Rank, Suit (완료)
├── hand.py        - evaluate_hand(), compare_hands() (완료)
├── board.py       - OFCBoard, check_foul(), check_fantasyland() (완료)
├── economy.py     - Player, 골드/이자/연승연패/별강화 (완료)
├── pool.py        - SharedCardPool, 레벨별 드롭률 (완료)
├── combat.py      - CombatResolver, 3라인 전투, 훌라, 스톱 (완료)
├── game.py        - GameState, RoundManager, 2~8인 매칭 (완료)
├── augment.py     - Augment, Silver 3종 (완료)
└── holdem.py      - HoldemEvent, HoldemState, 파일럿 5종 (완료)

web/
├── app.py         - Flask REST API (7개 action_type) (완료)
├── serializer.py  - GameState JSON 직렬화 (완료)
└── static/        - HTML/CSS/JS Web GUI (완료)

tests/             - 319개 테스트 (모두 PASS)
```

#### 단계별 완료 요약

| 단계 | 테스트 수 | 주요 성과 |
|------|-----------|---------|
| POC | 182개 | 카드/핸드/보드/경제/전투 코어 |
| Alpha | 261개 (+79) | 증강체/홀덤/스톱/판타지랜드/3~8인 매칭 |
| Standard (S1~S9) | 293개 (+32) | 풀 레벨별 드롭률, 판타지랜드 13장, 매칭 확장 |
| Web GUI | 319개 (+26) | Flask API, 직렬화, HTML/JS 프론트엔드 |

### 1.3 MVP 정의 — P0 필수 기능 갭 분석 요약

PRD §17.1 P0 기능 12개 중 미구현/불완전 항목이 존재한다. 상세 갭 분석은 §2에서 기술한다.

---

## 2. MVP 갭 분석

PRD §17.1 P0 기능 12개 전체를 현재 구현 상태와 대조한다.

| P0 기능 | PRD 정의 | 현재 상태 | 갭 |
|---------|---------|---------|-----|
| 코어 게임 루프 | 준비→판정→결과 사이클 | **완료** (`game.py` RoundManager) | 없음 |
| 카드 시스템 52장 | A 최강, 표준 포커 강도 | **완료** (`card.py`, `hand.py`) | 없음 |
| 수트 시너지 4종 | ♠♥♦♣ 각 3단계 효과 | **미구현** (`count_synergies`는 훌라 조건 판정용 카운트만 존재. 실제 3단계 효과 적용 없음) | **M1** |
| OFC 3라인 배치 | Front/Mid/Back + 폴 패널티 | **완료** (`board.py`) | 없음 |
| 핸드 비교 판정 | 핸드>강화>수트순환 3단계 | **완료** (`hand.py` compare_hands) | 없음 |
| 별 강화 시스템 | 1성→2성→3성 (같은 랭크+수트 3장) | **완료** (`economy.py` try_star_upgrade) | 없음 |
| TFT 경제 | 기본 5골드 + 이자 + 연승/연패 | **완료** (`economy.py` round_income) | 없음 |
| 상점 시스템 | 카드 구매, 리롤(2골드), **레벨업(4골드)** | **부분 구현** (구매/리롤 완료. 레벨업 미구현 — `Player.xp=0` 필드만 존재) | **M3** |
| 훌라 선언 기본 | ×4 배수 | **완료** (`combat.py` apply_hula) | 없음 |
| 수트 순환 우위 | ♠>♥>♦>♣>♠ | **완료** (`hand.py` compare_hands 타이브레이커) | 없음 |
| Pineapple 드래프트 | 3장 중 2장 선택 | **미구현** (FL 13장 드래프트는 구현됨. 매 라운드 일반 Pineapple 미구현) | **M2** |
| 8인 매칭 | 단순 랜덤 매칭 | **완료** (`game.py` generate_matchups_from, 2~8인 지원) | 없음 |

### 갭 상세 분석

#### GAP-1: 수트 시너지 4종 3단계 효과 (M1)

현재 `count_synergies(board, player)` 함수는 훌라 선언 조건용 시너지 카운트(숫자)만 반환한다. PRD §5.1 수트 시너지 3단계 효과(♠ 방어 보정, ♥ 강화 효과, ♦ 이벤트 효과, ♣ 드래프트 우선권)가 전투 판정에 적용되지 않는다.

MVP에서 구현할 최소 범위:
- ♠ 전사: 1단계(2~3장) = 동률 시 타이브레이커 보정, 2단계(4~5장) = 동률 자동 승리, 3단계(6장+) = 동률 자동 승리 강화
- ♥ 치유: 1단계 = 강화 카드(stars>0) 효과 +10%, 2단계 = +20%, 3단계 = +35%
- ♦ 마법: 홀덤 이벤트 연동 — MVP에서는 수트 카운트 보너스로 단순화
- ♣ 사냥: 리롤 비용 보정 (2단계: -1골드, 3단계: 무료)

#### GAP-2: Pineapple 드래프트 (M2)

매 라운드 준비 페이즈 시작 시 공유 풀에서 3장을 공개하고, 플레이어가 2장을 선택 후 1장을 반환하는 메커니즘이 없다. 현재 `start_prep_phase`는 5장 상점 드로우만 실행한다.

Pineapple과 상점은 **동시 진행** (PRD §3.2 준비 페이즈 플로우): 상점 5장 + Pineapple 3장을 동시 제시하고, 플레이어가 Pineapple에서 2장 선택 후 상점에서 추가 구매.

#### GAP-3: 상점 레벨업 (M3)

`Player.level=1`, `Player.xp=0` 필드가 존재하지만 레벨업 로직이 없다. PRD §10.6: 레벨업 비용 4골드, XP 필요량은 레벨별 상이, 레벨에 따라 상점 드롭률이 달라진다 (pool.py `_LEVEL_WEIGHTS` 레벨 1~9 가중치 이미 구현됨).

---

## 3. 구현 순서 (M1~M4)

### 의존성 그래프

```
  [M1] 수트 시너지 효과 적용
  src/combat.py — SynergyEffect 계산 + compare_hands 연동
  src/economy.py — ♣ 리롤 비용 보정
       |
       v
  [M2] Pineapple 드래프트
  src/game.py — start_prep_phase() Pineapple 드로우 분기
  web/app.py  — pineapple_draft action_type
  web/static/ — Pineapple UI 컴포넌트
       |
       v
  [M3] 상점 레벨업 완성
  src/economy.py — buy_xp(), level_up_xp_table
  web/app.py     — buy_xp action_type
  web/static/    — 레벨업 버튼 UI
       |
       v
  [M4] 통합 테스트 + 8인 실전 매칭 검증
  tests/ — M1~M3 신규 기능 테스트
  pytest — 전체 통과 확인
  web/static/ — 8인 UI 레이아웃 (M2 MINOR 해결)
```

### M1: 수트 시너지 효과 적용

**목표**: `count_synergies` 결과를 기반으로 실제 전투 보정치를 계산하고 `resolve()`에 반영한다.

**신규**: `src/combat.py` — `get_suit_synergy_level(board, suit)` 함수, `SuitSynergyBonus` 데이터클래스

**변경**: `CombatResolver.resolve()` — 시너지 레벨 계산 → 전투 보정 적용

**구현 범위 (MVP 최소)**:
- ♠ 전사 시너지: 동률(compare_hands == 0) 시 ♠ 시너지 레벨로 자동 승리 판정
- ♥ 치유 시너지: 강화 카드(stars >= 1) 핸드 비교 시 가중치 보정
- ♦ 마법 시너지: 홀덤 이벤트 효과 배율 보정 (이벤트 없으면 패스)
- ♣ 사냥 시너지: 리롤 비용 보정 (Player 레벨에 연동)

### M2: Pineapple 드래프트

**목표**: 매 라운드 준비 페이즈에서 공유 풀 3장 공개 → 2장 선택 → 1장 반환 흐름을 구현한다.

**변경**: `src/game.py` — `start_prep_phase()` Pineapple 드로우 추가, `Player.pineapple_cards` 필드

**변경**: `web/app.py` — `pineapple_pick` action_type 추가

**변경**: `web/serializer.py` — `pineapple_cards` 직렬화

**변경**: `web/static/` — Pineapple 카드 선택 UI 모달

### M3: 상점 레벨업 완성

**목표**: 골드 4개 소모 → XP 획득 → 레벨 상승 → 상점 드롭률 개선 흐름을 구현한다.

**변경**: `src/economy.py` — `buy_xp(cost=4)`, `_XP_TABLE` (레벨별 XP 필요량), `level_up()` 자동 처리

**변경**: `web/app.py` — `buy_xp` action_type 추가

**변경**: `web/static/` — 레벨업 버튼 (현재 레벨/XP 표시)

### M4: 통합 테스트 + 8인 UI

**목표**: M1~M3 모든 기능 테스트 통과 + 8인 플레이어 Web UI 레이아웃 구현 (MINOR M2 해결)

**신규**: `tests/test_suit_synergy.py` — 수트 시너지 단계별 효과 테스트

**신규**: `tests/test_pineapple.py` — Pineapple 드래프트 흐름 테스트

**신규**: `tests/test_level_up.py` — 레벨업 XP 로직 테스트

**변경**: `web/static/index.html`, `style.css`, `game.js` — 8인 플레이어 UI 레이아웃

---

## 4. 파일별 변경 명세

### 4.1 `src/combat.py`

**추가 내용**:

```python
# 수트별 시너지 단계 계산
def get_suit_synergy_level(board: OFCBoard, suit: Suit) -> int:
    """특정 수트의 시너지 레벨 반환 (0, 1, 2, 3)"""
    all_cards = board.back + board.mid + board.front
    count = sum(1 for c in all_cards if c.suit == suit)
    if count >= 6:
        return 3
    elif count >= 4:
        return 2
    elif count >= 2:
        return 1
    return 0

# CombatResolver.resolve() 내부에 시너지 효과 적용 블록 추가
# ♠ 전사: 동률 라인에서 ♠ 시너지 레벨 우열 비교
# ♥ 치유: 강화 카드 수 비교 시 시너지 레벨 × 보정계수
# ♣ 사냥: resolve() 외부 — Player.calc_roll_cost() 연동
```

### 4.2 `src/economy.py`

**추가 내용**:

```python
# 레벨별 XP 필요량 테이블 (PRD §10.6)
_XP_TABLE: dict[int, int] = {
    1: 2, 2: 4, 3: 6, 4: 10, 5: 20,
    6: 36, 7: 56, 8: 80, 9: None   # 9레벨 = 최대
}

# Player 메서드 추가
def buy_xp(self, cost: int = 4) -> bool:
    """4골드 소모 → XP+4 획득 → 레벨업 자동 처리"""

def _try_level_up(self) -> bool:
    """XP가 다음 레벨 필요량 이상이면 레벨업"""

def calc_roll_cost(self) -> int:
    """♣ 시너지 레벨에 따른 리롤 비용 반환 (기본 2골드)"""
```

### 4.3 `src/game.py`

**변경 내용** (`start_prep_phase`):

```python
def start_prep_phase(self):
    for player in self.state.players:
        income = player.round_income()
        player.gold += income
        # Pineapple 드래프트: 공유 풀에서 3장 공개
        player.pineapple_cards = self.state.pool.random_draw_n(3, player.level)
        # 기존 상점 드로우 유지
        if player.in_fantasyland:
            player.shop_cards = self.state.pool.random_draw_n(13, player.level)
        else:
            shop_size = 6 if player.has_augment("lucky_shop") else 5
            player.shop_cards = self.state.pool.random_draw_n(shop_size, player.level)
```

**Player 필드 추가**: `pineapple_cards: list = field(default_factory=list)`

### 4.4 `web/app.py`

**추가 action_type**:

| action_type | 처리 내용 |
|------------|---------|
| `pineapple_pick` | payload: `{keep: [idx_a, idx_b]}` — 2장 선택, 1장 풀 반환, pineapple_cards → bench 이동 |
| `buy_xp` | 골드 4 소모 + player.buy_xp() 호출 |

### 4.5 `web/serializer.py`

**추가 직렬화 필드**:

```python
# Player 직렬화에 추가
"level": player.level,
"xp": player.xp,
"xp_needed": _xp_needed(player.level),
"pineapple_cards": [serialize_card(c) for c in player.pineapple_cards],
```

### 4.6 `web/static/` (index.html + style.css + game.js)

- Pineapple 드래프트 모달 (3장 표시 → 2장 클릭 선택 → 확인)
- 레벨업 버튼 (현재 레벨/XP/다음 레벨 XP 표시)
- 8인 플레이어 UI 레이아웃 (grid 2×4 배치)

---

## 5. TDD 테스트 계획

총 예상 신규 테스트: 약 60개

### 5.1 `tests/test_suit_synergy.py` — 예상 20개

| 테스트 | 검증 내용 |
|--------|---------|
| test_get_spade_synergy_level_0 | ♠ 1장 → 레벨 0 |
| test_get_spade_synergy_level_1 | ♠ 2장 → 레벨 1 |
| test_get_spade_synergy_level_2 | ♠ 4장 → 레벨 2 |
| test_get_spade_synergy_level_3 | ♠ 6장 → 레벨 3 |
| test_spade_synergy_tie_broken | ♠ 시너지 보유 → 동률 라인 자동 승리 |
| test_spade_no_synergy_no_bonus | ♠ 시너지 없음 → 동률 그대로 |
| test_heart_synergy_stars_bonus | ♥ 시너지 1단계 → 강화 카드 보정 |
| test_heart_synergy_level3 | ♥ 시너지 3단계 → 최대 보정 |
| test_club_synergy_roll_cost_level1 | ♣ 1단계 → 리롤 비용 2골드 |
| test_club_synergy_roll_cost_level2 | ♣ 2단계 → 리롤 비용 1골드 |
| test_club_synergy_roll_cost_level3 | ♣ 3단계 → 리롤 무료 |
| test_all_four_suits_no_synergy | 각 수트 1장 → 모두 레벨 0 |
| test_synergy_vs_synergy | ♠ vs ♥ 시너지 동시 활성 |
| ... (추가 엣지케이스) | |

### 5.2 `tests/test_pineapple.py` — 예상 15개

| 테스트 | 검증 내용 |
|--------|---------|
| test_pineapple_draw_3_cards | start_prep_phase → pineapple_cards 3장 |
| test_pineapple_pick_2_keep | 2장 선택 → bench에 추가 |
| test_pineapple_discard_1_returns_pool | 버린 1장 → pool 반환 |
| test_pineapple_pick_invalid_index | 유효하지 않은 인덱스 → 에러 |
| test_pineapple_must_pick_exactly_2 | 1장 또는 3장 선택 시 에러 |
| test_pineapple_cards_cleared_after_pick | 픽 완료 후 pineapple_cards 비워짐 |
| test_pineapple_web_api_action | POST /api/action pineapple_pick |
| test_pineapple_serialized | pineapple_cards JSON 직렬화 |
| ... | |

### 5.3 `tests/test_level_up.py` — 예상 15개

| 테스트 | 검증 내용 |
|--------|---------|
| test_buy_xp_deducts_gold | buy_xp() → gold -4 |
| test_buy_xp_adds_xp | buy_xp() → xp +4 |
| test_level_up_triggers_on_xp | xp >= 임계값 → level +1 |
| test_level_cap_at_9 | 레벨 9 → buy_xp 실패 |
| test_no_gold_no_xp | 골드 부족 → buy_xp 반환 False |
| test_xp_carry_over | XP 초과분 이월 (레벨업 후 남은 XP 유지) |
| test_level_affects_shop_odds | 레벨 5 → random_draw_n weight 변경됨 |
| test_buy_xp_web_api | POST /api/action buy_xp |
| test_level_serialized | level/xp JSON 직렬화 |
| ... | |

### 5.4 기존 테스트 확장 — 약 10개

| 파일 | 추가 내용 |
|------|---------|
| `test_web_api.py` | pineapple_pick, buy_xp action_type 테스트 |
| `test_game.py` | start_prep_phase Pineapple 분기 테스트 |
| `test_serializer.py` | pineapple_cards, level, xp 직렬화 테스트 |

---

## 6. 완료 기준 (Definition of Done)

### 기능 완료 기준

| 기준 | 검증 방법 |
|------|---------|
| 수트 시너지 4종 3단계 효과 적용 | `test_suit_synergy.py` 전체 통과 |
| Pineapple 드래프트 흐름 정상 작동 | `test_pineapple.py` 전체 통과 + Web GUI 수동 확인 |
| 상점 레벨업 (4골드 → XP → 레벨 증가) | `test_level_up.py` 전체 통과 |
| 레벨업에 따른 드롭률 변화 | `level` 파라미터 → `random_draw_n` 분기 확인 |
| 8인 Web UI 레이아웃 | 브라우저에서 8인 플레이어 표시 정상 |

### 품질 기준

| 항목 | 기준 |
|------|------|
| 전체 테스트 | 기존 319 + 신규 60 = **약 379개 이상 PASS** |
| 린트 | `ruff check src/ --fix` PASS (0건) |
| 기존 테스트 회귀 | 기존 319개 테스트 전부 유지 |
| Architect 검증 | APPROVE 필수 |
| src/ 인터페이스 | `web/app.py` 변경 시 `web/serializer.py` 동기화 |

---

## 7. 위험 요소 및 완화 방안

| 위험 | 심각도 | 가능성 | 완화 방안 |
|------|--------|--------|---------|
| 수트 시너지 효과가 기존 `compare_hands()` 인터페이스와 충돌 | 높음 | 중간 | `resolve()` 내부에서 시너지 보정을 별도 계산 후 line_result 덮어쓰기 방식으로 격리 |
| Pineapple 드래프트와 FL 13장 드래프트 로직 충돌 | 중간 | 중간 | FL 진입 플레이어는 Pineapple 드래프트 스킵 (기존 FL 13장 우선) |
| ♣ 리롤 비용 보정이 `_handle_roll_shop` 수정 필요 | 낮음 | 높음 | `player.calc_roll_cost()` 메서드 추가, `_handle_roll_shop`은 해당 메서드 호출로 변경 |
| 레벨업 XP 이월 로직 복잡도 | 낮음 | 중간 | while 루프로 연속 레벨업 처리, 9레벨 상한 예외 처리 |
| 8인 Web UI 레이아웃 CSS 복잡도 | 낮음 | 높음 | 기존 2인 레이아웃을 그리드 확장으로 단순화, 카드 크기 축소 |
| pineapple_cards 미픽 상태로 전투 진행 시 카드 풀 누수 | 높음 | 중간 | `_handle_ready()` 에서 pineapple_cards가 남아있으면 자동 반환 처리 |
| 신규 action_type 추가 시 test_web_api.py 회귀 가능성 | 중간 | 낮음 | 기존 테스트 로직 분리, 신규 action_type 테스트 독립 작성 |
