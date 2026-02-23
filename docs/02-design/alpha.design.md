# Trump Card Auto Chess — Alpha 단계 기술 설계 문서

**버전**: 1.0.0
**작성일**: 2026-02-20
**기반**: alpha.prd.md + alpha.plan.md + poc.design.md v1.0

---

## 목차

1. [아키텍처 변경 개요](#1-아키텍처-변경-개요)
2. [A1 — 상점 레벨별 드롭률](#2-a1--상점-레벨별-드롭률-이미-구현-완료)
3. [A2 — 증강체 시스템 설계](#3-a2--증강체-시스템-설계)
4. [A3 — 홀덤 이벤트 시스템 설계](#4-a3--홀덤-이벤트-시스템-설계)
5. [A4 — 스톱(×8) + 판타지랜드 설계](#5-a4--스톱8--판타지랜드-설계)
6. [A5 — 3~4인 매칭 확장 설계](#6-a5--34인-매칭-확장-설계)
7. [TDD 테스트 설계](#7-tdd-테스트-설계)
8. [위험 요소 해결 방안](#8-위험-요소-해결-방안-r1r6)
9. [구현 파일 목록](#9-구현-파일-목록-변경신규-전체)

---

## 1. 아키텍처 변경 개요

### 1.1 기존 POC 아키텍처 대비 변경점

POC에서 확립한 7-레이어 구조는 유지하면서, Alpha는 신규 도메인 모듈 2개(`augment.py`, `holdem.py`)를 Domain Layer에 추가하고 Game Engine Layer의 상태 범위를 확장한다.

```
  +--------------------------------------------------------------+
  |                   Alpha 시스템 (Python 3.11+)               |
  |                                                              |
  |  +------------------+     +-----------------------------+   |
  |  |   CLI Layer      |     |       Test Layer            |   |
  |  |  cli/main.py     |     |  tests/test_*.py (pytest)   |   |
  |  |  (플레이어 수 선택 |     |  test_augment.py (신규)     |   |
  |  |   이벤트 출력 추가)|     |  test_holdem.py  (신규)     |   |
  |  +--------+---------+     +-------------+---------------+   |
  |           |                             |                   |
  |           v                             v                   |
  |  +------------------------------------------------------+   |
  |  |                  Game Engine Layer                   |   |
  |  |  game.py  — GameState (holdem_state, match_history)  |   |
  |  |             RoundManager (generate_matchups 추가)     |   |
  |  |  combat.py — CombatResolver (events, player 파라미터) |   |
  |  +--+----------------+----------------+----------------+   |
  |     |                |                |                    |
  |     v                v                v                    |
  |  +--------+    +----------+    +-----------+              |
  |  |Domain  |    |Domain    |    |Domain     |              |
  |  |card.py |    |hand.py   |    |board.py   |              |
  |  |pool.py |    |(핸드판정) |    |(OFC+Foul  |              |
  |  |        |    |          |    | +FL판정)   |              |
  |  +--------+    +----------+    +-----------+              |
  |     |                                                      |
  |     v                                                      |
  |  +--------------------------------------------+           |
  |  |economy.py  (augments, in_fantasyland 추가)  |           |
  |  +--------------------------------------------+           |
  |  +--------------------+  +--------------------+           |
  |  |augment.py (신규)   |  |holdem.py (신규)    |           |
  |  |Augment, SILVER_AUG |  |HoldemEvent, State  |           |
  |  +--------------------+  +--------------------+           |
  +--------------------------------------------------------------+
```

### 1.2 신규 모듈 위치 및 의존성 업데이트

```
  src/
  ├── card.py          (변경 없음)
  ├── pool.py          (변경 없음 — A1 이미 구현)
  ├── hand.py          (변경 없음)
  ├── board.py         (check_fantasyland 추가)
  ├── economy.py       (augments, in_fantasyland, fantasyland_next 추가)
  ├── augment.py       [신규] Augment 도메인 모델
  ├── holdem.py        [신규] HoldemEvent 도메인 모델
  ├── combat.py        (CombatResult.stop_applied, resolve 확장)
  └── game.py          (GameState, RoundManager 다인 지원)
```

의존성 방향 (`→` = import):
- `augment.py` → 없음 (순수 데이터 클래스)
- `holdem.py` → 없음 (순수 데이터 클래스)
- `economy.py` → `augment.py` (Augment 타입 참조)
- `combat.py` → `board.py`, `hand.py`, `augment.py` (타입 확인용)
- `game.py` → `economy.py`, `combat.py`, `pool.py`, `holdem.py`, `augment.py`
- `cli/main.py` → `game.py`, `holdem.py`

의존성 역방향 금지: 하위 모듈(`pool.py`, `augment.py`, `holdem.py`)은 `game.py`를 import 금지.

### 1.3 레이어별 변경 영향

| 레이어 | 모듈 | 변경 규모 | 영향 범위 |
|--------|------|----------|---------|
| CLI | `cli/main.py` | 소 (플레이어 수 선택, 이벤트 출력) | 수동 테스트 |
| Game Engine | `game.py` | 대 (3개 필드 추가, 3개 메서드 추가) | `test_game.py` |
| Game Engine | `combat.py` | 중 (1개 필드, 시그니처 확장) | `test_combat.py` |
| Domain | `board.py` | 소 (1개 함수 추가) | `test_board.py` |
| Domain | `economy.py` | 소 (3개 필드, 3개 메서드 추가) | `test_economy.py` |
| Domain | `augment.py` | 신규 | `test_augment.py` |
| Domain | `holdem.py` | 신규 | `test_holdem.py` |
| Domain | `pool.py` | 없음 (A1 완료) | `test_card.py` 확장만 |

---

## 2. A1 — 상점 레벨별 드롭률 (이미 구현 완료)

### 2.1 현재 구현 상태 확인

`src/pool.py` 분석 결과 (lines 6~17):

```python
# PRD §10.6 레벨별 코스트 확률 테이블 [1코스트, 2코스트, 3코스트, 4코스트, 5코스트]
_LEVEL_WEIGHTS: dict[int, list[float]] = {
    1: [0.75, 0.20, 0.05, 0.00, 0.00],
    2: [0.75, 0.20, 0.05, 0.00, 0.00],
    3: [0.55, 0.30, 0.15, 0.00, 0.00],
    4: [0.55, 0.30, 0.15, 0.00, 0.00],
    5: [0.35, 0.35, 0.25, 0.05, 0.00],
    6: [0.20, 0.35, 0.30, 0.14, 0.01],
    7: [0.15, 0.25, 0.35, 0.20, 0.05],
    8: [0.10, 0.15, 0.35, 0.30, 0.10],
    9: [0.05, 0.10, 0.25, 0.35, 0.25],
}
```

`random_draw_n(n, level)` 메서드 (lines 62~118)에서:
1. level 클램핑 (`max(1, min(9, level))`)
2. 코스트 티어별 가용 카드 분류 및 빈 티어 확률 재분배
3. `random.choices()` 가중치 샘플링
4. 드로우된 카드 즉시 풀에서 차감

결론: **A1 구현 완료. 코드 변경 불필요.**

### 2.2 PRD §10.6과 일치 여부 대조표

| 레벨 | PRD §10.6 (1/2/3/4/5코스트 %) | `_LEVEL_WEIGHTS` (소수) | 일치 |
|------|------------------------------|------------------------|------|
| 1 | 75 / 20 / 5 / 0 / 0 | 0.75/0.20/0.05/0.00/0.00 | 일치 |
| 2 | 75 / 20 / 5 / 0 / 0 | 0.75/0.20/0.05/0.00/0.00 | 일치 |
| 3 | 55 / 30 / 15 / 0 / 0 | 0.55/0.30/0.15/0.00/0.00 | 일치 |
| 4 | 55 / 30 / 15 / 0 / 0 | 0.55/0.30/0.15/0.00/0.00 | 일치 |
| 5 | 35 / 35 / 25 / 5 / 0 | 0.35/0.35/0.25/0.05/0.00 | 일치 |
| 6 | 20 / 35 / 30 / 14 / 1 | 0.20/0.35/0.30/0.14/0.01 | 일치 |
| 7 | 15 / 25 / 35 / 20 / 5 | 0.15/0.25/0.35/0.20/0.05 | 일치 |
| 8 | 10 / 15 / 35 / 30 / 10 | 0.10/0.15/0.35/0.30/0.10 | 일치 |
| 9 | 5 / 10 / 25 / 35 / 25 | 0.05/0.10/0.25/0.35/0.25 | 일치 |

합계 검증:
- 모든 레벨에서 가중치 합 = 1.0
- 레벨 1~2: 4/5코스트 0% (A 카드 드롭 불가)
- 레벨 5: 4코스트 5%, 5코스트 0% (Mythic 진입 차단)
- 레벨 9: 5코스트 25% (Mythic 높은 출현율)

### 2.3 추가 필요 테스트 명세

구현은 완료됐으나 통계적 분포 검증 테스트가 없다. `tests/test_card.py`에 아래 테스트를 추가한다.

| 테스트 함수 | 검증 내용 | 방법 |
|-----------|---------|------|
| `test_level1_no_high_cost` | level=1 드로우 1000회 → 4/5코스트 카드 0건 | count 검증 |
| `test_level9_five_cost_distribution` | level=9 드로우 1000회 → 5코스트 카드 20~30% 범위 | 통계 범위 검증 |
| `test_level5_no_five_cost` | level=5 드로우 500회 → 5코스트 카드 0건 | `_LEVEL_WEIGHTS[5][4] == 0.0` |
| `test_level_clamp_min` | level=0 입력 → level=1로 처리 (예외 없음) | 정상 반환 |
| `test_level_clamp_max` | level=10 입력 → level=9로 처리 (예외 없음) | 정상 반환 |
| `test_draw_n_returns_n_cards` | n=5 요청 → 5장 반환 (풀 충분 시) | `len(result) == 5` |
| `test_drawn_cards_removed_from_pool` | 드로우된 카드 즉시 풀에서 차감 | `remaining()` 감소 확인 |
| `test_level6_four_cost_appears` | level=6에서 4코스트 카드 출현 가능 | `_LEVEL_WEIGHTS[6][3] == 0.14` |
| `test_empty_cost_bucket_fallback` | 특정 코스트 풀 고갈 시 다른 코스트로 폴백 | 빈 풀 상태에서 draw 성공 |
| `test_weight_sum_equals_one` | 모든 레벨의 가중치 합 == 1.0 | 9개 레벨 각각 검증 |

---

## 3. A2 — 증강체 시스템 설계

### 3.1 augment.py 신규 모듈 설계

파일 위치: `src/augment.py`
역할: 증강체 데이터 모델 정의 (순수 데이터 클래스, 비즈니스 로직 없음)
의존성: 없음 (표준 라이브러리만 사용)
예상 크기: 40~60줄

```
  augment.py
  ├── Augment (dataclass)
  │   ├── id: str
  │   ├── name: str
  │   ├── tier: str
  │   ├── description: str
  │   └── effect_type: str
  └── SILVER_AUGMENTS: list[Augment]
      ├── economist
      ├── suit_mystery
      └── lucky_shop
```

### 3.2 Augment 데이터 모델 (코드 명세)

```python
# src/augment.py
from dataclasses import dataclass


@dataclass(frozen=True)
class Augment:
    id: str               # 고유 식별자 (예: "economist")
    name: str             # 표시 이름 (예: "경제학자")
    tier: str             # "silver" | "gold" | "prismatic"
    description: str      # 효과 설명 (UI 출력용)
    effect_type: str      # "passive" | "trigger"


SILVER_AUGMENTS: list[Augment] = [
    Augment(
        id="economist",
        name="경제학자",
        tier="silver",
        description="이자 수입 상한 5 → 6골드",
        effect_type="passive",
    ),
    Augment(
        id="suit_mystery",
        name="수트의 신비",
        tier="silver",
        description="가장 많이 보유한 수트 시너지 카운트 +1 (영구)",
        effect_type="passive",
    ),
    Augment(
        id="lucky_shop",
        name="행운의 상점",
        tier="silver",
        description="매 라운드 상점 공개 +1장 (5 → 6장)",
        effect_type="passive",
    ),
]
```

`frozen=True` 사용 이유: 증강체는 불변 상수이며, 런타임에 수정 시 게임 상태 불일치 방지.

### 3.3 SILVER_AUGMENTS 3종 상세

#### economist (경제학자)

| 항목 | 내용 |
|------|------|
| 효과 | 이자 수입 상한 5골드 → 6골드 |
| 적용 위치 | `economy.py:Player.calc_interest()` |
| 트리거 | 매 라운드 수입 계산 시 (passive) |
| 수치 예시 | gold=60 + economist → interest=6 (기존: 5) |
| 한계 | 이자 계산식(`gold // 10`) 자체는 변경 없음. 상한값만 6으로 변경 |

#### suit_mystery (수트의 신비)

| 항목 | 내용 |
|------|------|
| 효과 | 가장 많이 보유한 수트의 시너지 카운트 +1 |
| 적용 위치 | `combat.py:count_synergies()` |
| 트리거 | 전투 중 훌라 판정 시 (passive) |
| 수치 예시 | ♠ 5장, ♥ 2장 보유 → 기존 synergies=2, suit_mystery 보정 후 synergies=3 |
| Alpha 간소화 | "선택 수트" 대신 "가장 많이 보유한 수트" 자동 선택 (선택 UI는 STANDARD 이연) |
| 상한 | `min(base + 1, 4)` — 수트 종류는 최대 4 |

#### lucky_shop (행운의 상점)

| 항목 | 내용 |
|------|------|
| 효과 | 상점 드로우 수 5장 → 6장 |
| 적용 위치 | `game.py:RoundManager` 상점 드로우 호출부 |
| 트리거 | 매 라운드 prep 페이즈 상점 공개 시 (passive) |
| 수치 예시 | 기본 `pool.random_draw_n(5, level)` → lucky_shop 시 `pool.random_draw_n(6, level)` |
| 범위 외 | 상점 UI(CLI 표시)는 현재 단순 드로우로 처리 |

### 3.4 Player 통합 (economy.py 변경 명세)

**변경 전** (`src/economy.py`, lines 8~28):

```python
@dataclass
class Player:
    name: str
    hp: int = 100
    gold: int = 0
    level: int = 1
    xp: int = 0
    board: object = None
    bench: list = field(default_factory=list)
    win_streak: int = 0
    loss_streak: int = 0
    hula_declared: bool = False

    def calc_interest(self) -> int:
        return min(self.gold // 10, 5)
```

**변경 후**:

```python
from __future__ import annotations
from dataclasses import dataclass, field

from src.augment import Augment  # 신규 import

@dataclass
class Player:
    name: str
    hp: int = 100
    gold: int = 0
    level: int = 1
    xp: int = 0
    board: object = None
    bench: list = field(default_factory=list)
    win_streak: int = 0
    loss_streak: int = 0
    hula_declared: bool = False
    # Alpha 신규 필드
    augments: list = field(default_factory=list)       # Augment 인스턴스 목록
    in_fantasyland: bool = False                       # 현재 라운드 판타지랜드 여부
    fantasyland_next: bool = False                     # 다음 라운드 판타지랜드 진입 예약

    def calc_interest(self) -> int:
        """이자 = min(floor(gold / 10), cap). economist 증강체 시 cap=6."""
        cap = 6 if self.has_augment("economist") else 5
        return min(self.gold // 10, cap)

    def add_augment(self, augment: Augment) -> None:
        """증강체 추가. 동일 id 중복 허용 안 함."""
        if not self.has_augment(augment.id):
            self.augments.append(augment)

    def has_augment(self, augment_id: str) -> bool:
        """특정 id 증강체 보유 여부."""
        return any(a.id == augment_id for a in self.augments)
```

기존 테스트 영향: `calc_interest` 기존 케이스(`gold=50 → interest=5`)는 `has_augment("economist")==False`이므로 cap=5로 동작. **기존 테스트 수정 불필요**.

### 3.5 전투 적용 (combat.py 변경 명세)

**변경 전** (`count_synergies`, line 17~23):

```python
def count_synergies(board: OFCBoard) -> int:
    all_cards = board.back + board.mid + board.front
    if not all_cards:
        return 0
    suit_counts = Counter(c.suit for c in all_cards)
    return sum(1 for cnt in suit_counts.values() if cnt >= 2)
```

**변경 후**:

```python
def count_synergies(board: OFCBoard, player=None) -> int:
    """같은 수트 2장 이상인 수트 수. suit_mystery 증강체 보유 시 최다 수트 +1."""
    all_cards = board.back + board.mid + board.front
    if not all_cards:
        return 0
    suit_counts = Counter(c.suit for c in all_cards)
    base = sum(1 for cnt in suit_counts.values() if cnt >= 2)

    if player is not None and player.has_augment("suit_mystery"):
        # 가장 많이 보유한 수트 1개에 +1 보정
        base = min(base + 1, 4)  # 수트는 최대 4종

    return base
```

`resolve()` 내부에서 `count_synergies` 호출 시 player 전달:

```python
# 변경 전
synergies_a = count_synergies(board_a)
synergies_b = count_synergies(board_b)

# 변경 후
synergies_a = count_synergies(board_a, player=player_a)
synergies_b = count_synergies(board_b, player=player_b)
```

### 3.6 증강체 선택 페이즈 (game.py 변경 명세)

`RoundManager.end_round()` 수정: 라운드 2, 3, 4 종료 시 각 플레이어에게 Silver 증강체 선택 기회 제공.

```python
def end_round(self):
    self.state.phase = 'result'
    self.state.round_num += 1

    from src.board import OFCBoard, check_fantasyland
    for player in self.state.players:
        # 판타지랜드 플래그 전환
        if player.fantasyland_next:
            player.in_fantasyland = True
            player.fantasyland_next = False
        else:
            player.in_fantasyland = False

        # 보드 리셋
        player.board = OFCBoard()

    # 증강체 선택 페이즈 (라운드 2, 3, 4 종료 후)
    if self.state.round_num in (3, 4, 5):  # round_num은 이미 +1된 상태
        self._offer_augments()

    # 탈락자 처리
    self.state.players = [p for p in self.state.players if p.hp > 0]

    if self.state.is_game_over():
        self.state.phase = 'end'
    else:
        self.state.phase = 'prep'

def _offer_augments(self) -> None:
    """각 플레이어에게 SILVER_AUGMENTS 중 랜덤 3개 제시 후 1개 선택 처리.
    Alpha에서는 자동으로 첫 번째 증강체 선택 (CLI 선택 UI는 STANDARD 이연).
    """
    from src.augment import SILVER_AUGMENTS
    import random
    for player in self.state.players:
        choices = random.sample(SILVER_AUGMENTS, min(3, len(SILVER_AUGMENTS)))
        # Alpha 범위: 자동 선택 (CLI 상호작용은 STANDARD)
        player.add_augment(choices[0])
```

GameState에 `augment_offered` 이벤트 플래그 추가:

```python
@dataclass
class GameState:
    players: list
    pool: SharedCardPool
    round_num: int = 1
    phase: str = 'prep'
    max_rounds: int = 5
    # Alpha 신규 필드
    match_history: dict = field(default_factory=dict)
    combat_pairs: list = field(default_factory=list)
    holdem_state: object = None  # HoldemState | None
```

### 3.7 엣지케이스 목록

| 케이스 | 처리 방법 |
|--------|---------|
| 동일 증강체 중복 추가 | `add_augment()` 내 `has_augment()` 검사로 차단 |
| economist + gold=0 | `min(0 // 10, 6) = 0` — 정상 동작 |
| suit_mystery + 보드 비어있음 | `count_synergies` base=0, +1해도 `min(1, 4)=1` |
| suit_mystery + 시너지 이미 4 | `min(4+1, 4)=4` — 상한 초과 방지 |
| lucky_shop + 풀 카드 5장 미만 | `random_draw_n`이 가용 카드 수만큼 반환 (기존 폴백 로직) |
| 증강체 없는 Player 생성 | `augments=[]` 기본값, `has_augment()` 항상 False |

---

## 4. A3 — 홀덤 이벤트 시스템 설계

### 4.1 holdem.py 신규 모듈 설계

파일 위치: `src/holdem.py`
역할: 홀덤 이벤트 데이터 모델 + 상태 관리 (순수 도메인)
의존성: 없음 (표준 라이브러리만)
예상 크기: 70~90줄

```
  holdem.py
  ├── HoldemEvent (dataclass, frozen=True)
  │   ├── id, name, phase, description, effect_type
  ├── HoldemState (dataclass)
  │   ├── stage: int
  │   ├── flop: list[HoldemEvent]
  │   ├── turn: HoldemEvent | None
  │   ├── river: HoldemEvent | None
  │   ├── active_events: list[HoldemEvent]
  │   └── advance(round_in_stage) → None
  └── PILOT_EVENTS: list[HoldemEvent] (5종)
```

### 4.2 HoldemEvent, HoldemState 데이터 모델 (코드 명세)

```python
# src/holdem.py
from __future__ import annotations
from dataclasses import dataclass, field


@dataclass(frozen=True)
class HoldemEvent:
    id: str
    name: str
    phase: str          # "flop" | "turn" | "river"
    description: str
    effect_type: str    # "suit_boost" | "economy" | "foul" | "combat"


@dataclass
class HoldemState:
    stage: int                              # 현재 스테이지 번호
    flop: list = field(default_factory=list)   # HoldemEvent 최대 3장
    turn: object = None                     # HoldemEvent | None
    river: object = None                    # HoldemEvent | None
    active_events: list = field(default_factory=list)  # 현재 라운드 적용 이벤트

    def advance(self, round_in_stage: int) -> None:
        """라운드 내 순서(1=Flop, 2=Turn, 3=River)에 따라 이벤트 공개.
        active_events에 해당 단계 이벤트를 누적 추가한다.
        """
        if round_in_stage == 1:
            # Flop: 3장 동시 공개
            self.active_events = list(self.flop)
        elif round_in_stage == 2:
            # Turn: 1장 추가 공개
            if self.turn is not None:
                self.active_events = list(self.flop) + [self.turn]
        elif round_in_stage == 3:
            # River: 1장 추가 공개
            events = list(self.flop)
            if self.turn is not None:
                events.append(self.turn)
            if self.river is not None:
                events.append(self.river)
            self.active_events = events

    def get_active_by_type(self, effect_type: str) -> list:
        """특정 effect_type의 활성 이벤트만 필터링하여 반환."""
        return [e for e in self.active_events if e.effect_type == effect_type]

    def has_active_event(self, event_id: str) -> bool:
        """특정 id의 이벤트가 현재 활성화 되어 있는지 확인."""
        return any(e.id == event_id for e in self.active_events)
```

### 4.3 PILOT_EVENTS 5종 상세

```python
PILOT_EVENTS: list[HoldemEvent] = [
    HoldemEvent(
        id="suit_bonus_spade",
        name="스페이드 우위",
        phase="flop",
        description="이번 라운드 ♠ 수트 시너지 카운트 +1",
        effect_type="suit_boost",
    ),
    HoldemEvent(
        id="double_interest",
        name="이자 배가",
        phase="flop",
        description="이번 라운드 이자 수입 ×2",
        effect_type="economy",
    ),
    HoldemEvent(
        id="foul_amnesty",
        name="폴 면제",
        phase="turn",
        description="이번 라운드 Foul 패널티 미적용",
        effect_type="foul",
    ),
    HoldemEvent(
        id="scoop_bonus",
        name="스쿠프 강화",
        phase="turn",
        description="스쿠프 시 추가 피해 +4 (기존 +2에서 +6으로)",
        effect_type="combat",
    ),
    HoldemEvent(
        id="low_card_power",
        name="로우카드 역전",
        phase="river",
        description="이번 라운드 하이카드 비교 역전 (낮은 랭크 우선)",
        effect_type="combat",
    ),
]
```

HoldemState 초기화 시 PILOT_EVENTS에서 Flop(3장), Turn(1장), River(1장) 배분:

```python
def create_holdem_state(stage: int) -> HoldemState:
    """스테이지용 HoldemState 생성. PILOT_EVENTS에서 무작위 배분."""
    import random
    flop_candidates = [e for e in PILOT_EVENTS if e.phase == "flop"]
    turn_candidates = [e for e in PILOT_EVENTS if e.phase == "turn"]
    river_candidates = [e for e in PILOT_EVENTS if e.phase == "river"]

    return HoldemState(
        stage=stage,
        flop=random.sample(flop_candidates, min(3, len(flop_candidates))),
        turn=random.choice(turn_candidates) if turn_candidates else None,
        river=random.choice(river_candidates) if river_candidates else None,
    )
```

### 4.4 GameState 통합 (game.py 변경 명세)

**변경 전** (GameState, `src/game.py` lines 8~14):

```python
@dataclass
class GameState:
    players: list
    pool: SharedCardPool
    round_num: int = 1
    phase: str = 'prep'
    max_rounds: int = 5
```

**변경 후**:

```python
from __future__ import annotations
from dataclasses import dataclass, field

@dataclass
class GameState:
    players: list
    pool: SharedCardPool
    round_num: int = 1
    phase: str = 'prep'
    max_rounds: int = 5
    # Alpha 신규 필드
    match_history: dict = field(default_factory=dict)    # player_name → 최근 상대 이름 목록
    combat_pairs: list = field(default_factory=list)     # [(idx_a, idx_b), ...]
    holdem_state: object = None                          # HoldemState | None
```

`RoundManager.start_prep_phase()` 수정 — holdem advance 및 `double_interest` 적용:

```python
def start_prep_phase(self):
    self.state.phase = 'prep'

    # 홀덤 이벤트 공개 (스테이지 내 순서 계산)
    if self.state.holdem_state is not None:
        round_in_stage = ((self.state.round_num - 1) % 3) + 1
        self.state.holdem_state.advance(round_in_stage)

    for player in self.state.players:
        income = player.round_income()

        # double_interest 이벤트 적용
        if (self.state.holdem_state is not None
                and self.state.holdem_state.has_active_event("double_interest")):
            interest = player.calc_interest()
            income += interest  # 이자 부분만 추가 (×2 효과)

        player.gold += income
```

### 4.5 전투 적용 (combat.py 변경 명세 — events 파라미터)

**resolve() 시그니처 확장**:

```python
def resolve(
    self,
    board_a: OFCBoard,
    board_b: OFCBoard,
    hula_a: bool = False,
    hula_b: bool = False,
    player_a=None,       # Player | None (증강체 보정용)
    player_b=None,       # Player | None
    events: list = None, # list[HoldemEvent] | None (활성 이벤트)
) -> tuple:
```

이벤트 효과 적용 블록 (Foul 판정 전에 처리):

```python
if events is None:
    events = []

# foul_amnesty 이벤트: Foul 판정 스킵
foul_amnesty_active = any(e.id == "foul_amnesty" for e in events)
if foul_amnesty_active:
    foul_a = []
    foul_b = []
else:
    foul_a = board_a.check_foul().foul_lines
    foul_b = board_b.check_foul().foul_lines
```

`calc_damage()` 이벤트 보정:

```python
def calc_damage(
    self,
    winner_lines: int,
    is_scoop: bool,
    stage_damage: int = 2,
    events: list = None,
) -> int:
    """기본: 이긴라인수 × stage_damage + 스쿠프 +2. scoop_bonus 시 +4 추가."""
    base = winner_lines * stage_damage
    if is_scoop:
        scoop_extra = 2
        if events and any(e.id == "scoop_bonus" for e in events):
            scoop_extra += 4  # 기존 +2에서 +6으로
        base += scoop_extra
    return base
```

`suit_bonus_spade` 이벤트 처리 (`count_synergies` 호출 후 보정):

```python
synergies_a = count_synergies(board_a, player=player_a)
synergies_b = count_synergies(board_b, player=player_b)

# suit_bonus_spade: ♠ 시너지 카운트 +1
if events and any(e.id == "suit_bonus_spade" for e in events):
    from src.card import Suit
    spade_a = sum(1 for c in (board_a.back + board_a.mid + board_a.front)
                  if c.suit == Suit.SPADE)
    spade_b = sum(1 for c in (board_b.back + board_b.mid + board_b.front)
                  if c.suit == Suit.SPADE)
    if spade_a >= 2:
        synergies_a = min(synergies_a + 1, 4)
    if spade_b >= 2:
        synergies_b = min(synergies_b + 1, 4)
```

`low_card_power` 이벤트 처리: Alpha 범위 외 (STANDARD 이연). 이벤트는 정의만 하고 전투 효과 미적용. CLI에서 "이번 라운드 활성: 로우카드 역전 (Alpha 미구현)"으로 출력.

### 4.6 엣지케이스 목록

| 케이스 | 처리 방법 |
|--------|---------|
| `holdem_state=None` (게임 초기) | `events=None` → 빈 리스트로 처리, 이벤트 효과 없음 |
| advance(2) 호출 시 flop이 비어있음 | `active_events = []` (turn만 추가 시도 → turn이 있으면 추가) |
| PILOT_EVENTS 부족으로 flop 3장 미달 | `random.sample(candidates, min(3, len))` — 가용 수만큼 |
| foul_amnesty + 실제 Foul 보드 | Foul 판정 스킵, 핸드 강도 원본 사용 |
| scoop_bonus + 비스쿠프 상황 | `is_scoop=False` → `scoop_extra` 코드 블록 진입 안 함 |
| double_interest + economist 중복 | `calc_interest()` 상한 6 적용 후 이자 ×2 누적 |
| 같은 effect_type 이벤트 2개 동시 활성 | Alpha에서는 발생 불가 (Flop 2개는 id가 다름) |

---

## 5. A4 — 스톱(×8) + 판타지랜드 설계

### 5.1 스톱 선언 조건 및 처리 알고리즘

스톱은 훌라 선언 성공 후 추가 조건을 만족할 때 배수를 ×4에서 ×8로 격상하는 메커니즘이다.

```
  훌라 선언 처리 흐름 (변경 후):

  hula_declared == True
       |
       v
  winner_lines >= 2 AND synergies >= 3?
    Yes → hula_applied = True, damage *= 4
       |
       v
  스톱 조건 검사:
    [로우 스톱] opponent.hp <= 10?
    [하이 스톱] is_scoop == True AND back_hand.hand_type == ROYAL_FLUSH?
       |
    조건 충족
       v
  damage = damage // 4 * 8   (×4 취소 후 ×8 재적용)
  stop_applied = True
  hula_applied = True         (hula도 True 유지 — 훌라 성공 전제)
```

배수 중첩 규칙: 스톱 성공 시 최종 배수 = ×8. 훌라 ×4와 스톱 ×8은 **중첩 불가**, 스톱이 우선.

### 5.2 CombatResult 변경 명세 (stop_applied 필드)

**변경 전** (`src/combat.py` lines 8~14):

```python
@dataclass
class CombatResult:
    line_results: dict
    winner_lines: int
    is_scoop: bool
    damage: int
    hula_applied: bool
```

**변경 후**:

```python
@dataclass
class CombatResult:
    line_results: dict
    winner_lines: int
    is_scoop: bool
    damage: int
    hula_applied: bool
    stop_applied: bool = False  # 스톱(×8) 선언 적용 여부
```

`stop_applied=False`를 기본값으로 설정하여 기존 `CombatResult(...)` 생성 코드와 호환.

스톱 판정 코드 블록 (`resolve()` 내, 훌라 처리 직후):

```python
# 스톱(×8) 판정: 훌라 성공 후 추가 조건 검증
if hula_applied_a:
    low_stop = (player_b is not None and player_b.hp <= 10)
    back_hand_a = evaluate_hand(board_a.back) if board_a.back else None
    high_stop = (
        is_scoop_a
        and back_hand_a is not None
        and back_hand_a.hand_type.value == 10  # HandType.ROYAL_FLUSH
    )
    if low_stop or high_stop:
        damage_a = damage_a // 4 * 8   # 훌라 ×4 취소 후 ×8 재적용
        stop_applied_a = True
    else:
        stop_applied_a = False
else:
    stop_applied_a = False

# player_b / board_b 대칭 처리 (동일 패턴)
if hula_applied_b:
    low_stop = (player_a is not None and player_a.hp <= 10)
    back_hand_b = evaluate_hand(board_b.back) if board_b.back else None
    high_stop = (
        is_scoop_b
        and back_hand_b is not None
        and back_hand_b.hand_type.value == 10
    )
    if low_stop or high_stop:
        damage_b = damage_b // 4 * 8
        stop_applied_b = True
    else:
        stop_applied_b = False
else:
    stop_applied_b = False
```

### 5.3 판타지랜드 판정 로직 (board.py check_fantasyland)

`check_fantasyland()` 함수를 `src/board.py`에 모듈 레벨 함수로 추가:

```python
def check_fantasyland(board: 'OFCBoard') -> bool:
    """Front 라인 QQ+ 원페어 이상 달성 여부 판정 (PRD §6.6).

    판정 기준:
    - ONE_PAIR: 페어 랭크가 QUEEN(12) 이상
    - TWO_PAIR, THREE_OF_A_KIND: 항상 True (Front 최강 핸드)
    - 그 외 (HIGH_CARD, ONE_PAIR with rank < Q): False
    """
    from collections import Counter
    from src.hand import evaluate_hand, HandType
    from src.card import Rank

    if not board.front:
        return False

    front_hand = evaluate_hand(board.front)

    if front_hand.hand_type == HandType.ONE_PAIR:
        rank_counts = Counter(c.rank for c in board.front)
        pair_ranks = [r for r, cnt in rank_counts.items() if cnt >= 2]
        return bool(pair_ranks) and max(pair_ranks) >= Rank.QUEEN

    # THREE_OF_A_KIND 이상 (Front 3장 기준 최강)
    return front_hand.hand_type > HandType.ONE_PAIR
```

배치 위치: `OFCBoard` 클래스 정의 후 모듈 레벨에 추가 (클래스 외부 함수).

의존성 순환 방지: `check_fantasyland`는 `board.py` 내에 정의되지만, `game.py`에서 `from src.board import check_fantasyland`로 import.

### 5.4 Player 필드 추가 (in_fantasyland, fantasyland_next)

§3.4에서 정의한 Player 변경 사항에 포함:

```python
in_fantasyland: bool = False     # 현재 라운드 판타지랜드 중 여부
fantasyland_next: bool = False   # 다음 라운드 판타지랜드 진입 예약 플래그
```

라운드 종료 시 플래그 전환 로직 (`RoundManager.end_round()`):

```python
for player in self.state.players:
    # 판타지랜드 상태 전환
    if player.fantasyland_next:
        player.in_fantasyland = True
        player.fantasyland_next = False
    else:
        player.in_fantasyland = False

    # 판타지랜드 유지 조건: 판타지랜드 중 Front 스리카인드 이상 달성
    if player.in_fantasyland and check_fantasyland(player.board):
        # Front THREE_OF_A_KIND 이상 여부 별도 확인
        from src.hand import evaluate_hand, HandType
        front_hand = evaluate_hand(player.board.front) if player.board.front else None
        if front_hand and front_hand.hand_type >= HandType.THREE_OF_A_KIND:
            player.fantasyland_next = True  # 다음 라운드 유지
```

전투 중 판타지랜드 진입 판정 (`start_combat_phase()` 내):

```python
from src.board import check_fantasyland
if check_fantasyland(p_a.board):
    p_a.fantasyland_next = True
if check_fantasyland(p_b.board):
    p_b.fantasyland_next = True
```

### 5.5 배수 중첩 규칙 (훌라 ×4 vs 스톱 ×8)

| 상황 | hula_applied | stop_applied | 최종 배수 |
|------|:------------:|:------------:|:--------:|
| 일반 전투 | False | False | ×1 |
| 훌라 성공 | True | False | ×4 |
| 스톱 성공 | True | True | ×8 |
| 훌라 조건 미달 | False | False | ×1 (스톱 불가) |

스톱은 훌라 성공을 전제 조건으로 한다. 훌라 조건 미달 시 스톱 판정 자체 진행 안 함.

### 5.6 판타지랜드 13장 드로우 처리 (Alpha 범위: 플래그+Foul면제)

Alpha 범위 제한:
- `in_fantasyland = True` 플래그 설정 및 전환 로직 구현
- `check_fantasyland()` 판정 함수 구현
- 판타지랜드 진입 라운드 Foul 면제: `combat.py`에서 `player.in_fantasyland` 확인

**Foul 면제 적용**:

```python
# 판타지랜드 플레이어는 Foul 패널티 면제
if player_a is not None and player_a.in_fantasyland:
    foul_a = []
elif foul_amnesty_active:
    foul_a = []
else:
    foul_a = board_a.check_foul().foul_lines
```

**Alpha 범위 외** (STANDARD 이연):
- 13장 드로우 후 배치 선택 인터페이스
- 나머지 카드 풀 반환 로직
- 판타지랜드 진입 라운드 CLI 특별 처리

---

## 6. A5 — 3~4인 매칭 확장 설계

### 6.1 generate_matchups() 알고리즘

```python
def generate_matchups(self) -> list[tuple[int, int]]:
    """생존 플레이어 인덱스 기반 전투 쌍 생성.

    N=2: [(0, 1)]
    N=3: 3인 라운드 로빈 중 바이 횟수 최소 플레이어 1명 제외 후 2쌍 결정
    N=4: match_history 기반 3연속 금지 매칭 2쌍

    Returns:
        list of (player_idx_a, player_idx_b) 쌍
    """
    players = self.state.players
    n = len(players)
    indices = list(range(n))

    if n == 2:
        return [(0, 1)]

    elif n == 3:
        # 바이 횟수 추적: bye_count[player_name] = 바이 받은 횟수
        bye_counts = self._get_bye_counts()
        # 가장 많이 바이 받은 플레이어에게 바이 부여 (공정성)
        bye_idx = max(indices, key=lambda i: bye_counts.get(players[i].name, 0))
        active = [i for i in indices if i != bye_idx]
        self._record_bye(players[bye_idx].name)
        return [(active[0], active[1])]

    elif n == 4:
        return self._pick_pairs_avoid_repeat(indices)

    else:
        # N < 2 또는 N > 4: Alpha 범위 외
        raise ValueError(f"Alpha 지원 플레이어 수: 2~4. 현재: {n}")
```

### 6.2 match_history 추적 방식

`GameState.match_history`는 `dict[str, list[str]]` 구조:
- key: 플레이어 이름
- value: 최근 상대 이름 목록 (최대 3개 유지)

```python
def _update_match_history(self, idx_a: int, idx_b: int) -> None:
    """매칭 쌍 전투 후 history 갱신. 최근 3명만 유지."""
    p_a = self.state.players[idx_a]
    p_b = self.state.players[idx_b]

    hist_a = self.state.match_history.setdefault(p_a.name, [])
    hist_a.append(p_b.name)
    if len(hist_a) > 3:
        hist_a.pop(0)

    hist_b = self.state.match_history.setdefault(p_b.name, [])
    hist_b.append(p_a.name)
    if len(hist_b) > 3:
        hist_b.pop(0)
```

### 6.3 바이(Bye) 처리 로직

3인 매칭에서 바이 플레이어:
- 전투에 참여하지 않으므로 HP 피해 없음
- 골드 수입은 `start_prep_phase()`에서 정상 지급
- 바이 횟수는 `match_history`에 별도 `__bye__` 키로 추적

```python
def _get_bye_counts(self) -> dict[str, int]:
    """플레이어별 바이 횟수 반환."""
    result = {}
    for player in self.state.players:
        bye_list = self.state.match_history.get(f"__bye__{player.name}", [])
        result[player.name] = len(bye_list)
    return result

def _record_bye(self, player_name: str) -> None:
    """바이 기록 추가."""
    key = f"__bye__{player_name}"
    self.state.match_history.setdefault(key, []).append(self.state.round_num)
```

### 6.4 GameState 변경 명세

§4.4에서 정의한 GameState 변경 사항과 동일. 추가로 `is_game_over()` 수정:

```python
def is_game_over(self) -> bool:
    """HP ≤ 0이거나 생존자 1명 이하이거나 max_rounds 초과 여부."""
    alive = [p for p in self.players if p.hp > 0]
    if len(alive) <= 1:
        return True
    return self.round_num > self.max_rounds
```

`get_winner()` 수정: 생존자 1명 시 자동 승자, 다수 생존 시 최고 HP 기준.

`start_combat_phase()` 전체 구조:

```python
def start_combat_phase(self) -> list:
    self.state.phase = 'combat'
    pairs = self.generate_matchups()
    self.state.combat_pairs = pairs

    active_events = (
        self.state.holdem_state.active_events
        if self.state.holdem_state else []
    )

    results = []
    for idx_a, idx_b in pairs:
        p_a = self.state.players[idx_a]
        p_b = self.state.players[idx_b]

        result_a, result_b = self.resolver.resolve(
            p_a.board, p_b.board,
            hula_a=p_a.hula_declared,
            hula_b=p_b.hula_declared,
            player_a=p_a,
            player_b=p_b,
            events=active_events,
        )

        p_b.hp -= result_a.damage
        p_a.hp -= result_b.damage

        # 판타지랜드 판정
        from src.board import check_fantasyland
        if check_fantasyland(p_a.board):
            p_a.fantasyland_next = True
        if check_fantasyland(p_b.board):
            p_b.fantasyland_next = True

        self._update_streaks(p_a, p_b, result_a, result_b)
        self._update_match_history(idx_a, idx_b)
        results.append((result_a, result_b))

    return results
```

### 6.5 CLI 변경 명세

`cli/main.py` 변경 사항:

1. **플레이어 수 선택 프롬프트** (게임 시작 시):

```python
def select_player_count() -> int:
    """2~4인 선택. --auto 모드에서는 4인 기본."""
    print("플레이어 수를 선택하세요 (2~4):")
    while True:
        try:
            n = int(input("> "))
            if 2 <= n <= 4:
                return n
        except (ValueError, EOFError):
            pass
        print("2에서 4 사이의 숫자를 입력하세요.")
```

2. **활성 홀덤 이벤트 출력** (전투 전):

```python
def print_active_events(holdem_state) -> None:
    if holdem_state and holdem_state.active_events:
        print("\n[ 활성 이벤트 ]")
        for ev in holdem_state.active_events:
            print(f"  - {ev.name}: {ev.description}")
```

3. **다인 전투 결과 출력**: 각 매칭 쌍 결과를 순차 출력.

4. **탈락 플레이어 알림**: HP 0 시 "플레이어 X 탈락" 메시지 출력.

---

## 7. TDD 테스트 설계

### 7.1 테스트 파일 구조 (신규 2개 + 확장 4개)

```
  tests/
  ├── test_card.py      (확장: +10개) — A1 드롭률 검증
  ├── test_hand.py      (변경 없음)
  ├── test_board.py     (확장: +5개) — A4 판타지랜드 판정
  ├── test_economy.py   (확장: 필요 시) — economist 이자 상한
  ├── test_combat.py    (확장: +5개) — A4 스톱 선언
  ├── test_game.py      (확장: +8개) — A5 다인 매칭
  ├── test_augment.py   [신규: 15개+] — A2 증강체 전체
  └── test_holdem.py    [신규: 15개+] — A3 홀덤 이벤트 전체
```

TDD 순서: 각 파일 먼저 작성 후 구현 파일 변경. Red → Green → Refactor.

### 7.2 test_augment.py 케이스 목록 (15개+)

| # | 테스트 함수 | 검증 내용 | 모듈 |
|---|-----------|---------|------|
| 1 | `test_augment_dataclass_fields` | Augment 필드 id/name/tier/description/effect_type 존재 | augment |
| 2 | `test_silver_augments_count` | `SILVER_AUGMENTS` 길이 == 3 | augment |
| 3 | `test_silver_augments_ids` | economist/suit_mystery/lucky_shop 모두 포함 | augment |
| 4 | `test_all_silver_tier` | 모든 항목 `.tier == "silver"` | augment |
| 5 | `test_augment_is_frozen` | Augment 필드 변경 시 FrozenInstanceError | augment |
| 6 | `test_player_add_augment` | `player.add_augment(aug)` 후 `len(augments) == 1` | economy |
| 7 | `test_player_has_augment_true` | 추가 후 `has_augment("economist")` == True | economy |
| 8 | `test_player_has_augment_false` | 미추가 시 `has_augment("economist")` == False | economy |
| 9 | `test_add_augment_no_duplicate` | 동일 id 중복 추가 시 len 변화 없음 | economy |
| 10 | `test_economist_interest_cap_6` | economist 보유 + gold=60 → `calc_interest()` == 6 | economy |
| 11 | `test_no_economist_interest_cap_5` | economist 없음 + gold=60 → `calc_interest()` == 5 | economy |
| 12 | `test_economist_gold_0` | economist + gold=0 → `calc_interest()` == 0 | economy |
| 13 | `test_suit_mystery_synergy_boost` | suit_mystery 보유 시 count_synergies 기본값보다 +1 | combat |
| 14 | `test_suit_mystery_max_cap_4` | 시너지 이미 4인 상태 + suit_mystery → 4 유지 | combat |
| 15 | `test_lucky_shop_draw_6` | lucky_shop 보유 시 상점 드로우 6장 반환 (게임 레벨 smoke) | game |
| 16 | `test_player_multiple_augments` | 2개 증강체 모두 보유 가능, `len == 2` | economy |
| 17 | `test_augment_offered_round2_end` | 라운드 2 종료 후 플레이어에 증강체 추가됨 | game |

### 7.3 test_holdem.py 케이스 목록 (15개+)

| # | 테스트 함수 | 검증 내용 | 모듈 |
|---|-----------|---------|------|
| 1 | `test_holdem_event_dataclass_fields` | HoldemEvent 필드 5개 존재 | holdem |
| 2 | `test_pilot_events_count` | `PILOT_EVENTS` 길이 == 5 | holdem |
| 3 | `test_pilot_events_phase_distribution` | flop 2개, turn 2개, river 1개 | holdem |
| 4 | `test_holdem_state_init_empty` | 초기화 후 `active_events == []` | holdem |
| 5 | `test_advance_flop_activates_3` | `advance(1)` → active_events 길이 == flop 수 | holdem |
| 6 | `test_advance_turn_adds_1` | `advance(2)` → active_events += 1 (turn 추가) | holdem |
| 7 | `test_advance_river_adds_1` | `advance(3)` → active_events += 1 (river 추가) | holdem |
| 8 | `test_has_active_event_true` | advance 후 해당 id `has_active_event()` == True | holdem |
| 9 | `test_has_active_event_false` | advance 없이 `has_active_event("x")` == False | holdem |
| 10 | `test_foul_amnesty_skips_foul_penalty` | foul_amnesty 활성 시 Foul 핸드 강등 없음 | combat |
| 11 | `test_scoop_bonus_extra_damage` | scoop_bonus 활성 + 스쿠프 → 피해 +6 (기존 +2) | combat |
| 12 | `test_suit_bonus_spade_synergy` | suit_bonus_spade 활성 + ♠ 2장 → synergies +1 | combat |
| 13 | `test_double_interest_effect` | double_interest 활성 → prep 단계 이자 ×2 추가 | game |
| 14 | `test_holdem_state_in_gamestate` | `GameState.holdem_state` 필드 존재 | game |
| 15 | `test_no_events_without_advance` | advance 없으면 `active_events == []` 보장 | holdem |
| 16 | `test_create_holdem_state_factory` | `create_holdem_state(1)` 정상 HoldemState 반환 | holdem |

### 7.4 기존 테스트 확장 케이스 목록

#### test_card.py 확장 (A1 검증, +10개)

| # | 테스트 함수 | 검증 |
|---|-----------|------|
| 1 | `test_level1_no_high_cost` | level=1 드로우 1000회 → 4/5코스트 0건 |
| 2 | `test_level9_five_cost_distribution` | level=9 드로우 1000회 → 5코스트 20~30% |
| 3 | `test_level5_no_five_cost` | level=5 → 5코스트 0건 |
| 4 | `test_level_clamp_min` | level=0 → 예외 없이 실행 |
| 5 | `test_level_clamp_max` | level=10 → 예외 없이 실행 |
| 6 | `test_draw_n_returns_n_cards` | n=5 요청 → 5장 반환 |
| 7 | `test_drawn_cards_removed_from_pool` | 드로우 후 `remaining()` 감소 확인 |
| 8 | `test_level6_four_cost_appears` | level=6 → `_LEVEL_WEIGHTS[6][3] == 0.14` |
| 9 | `test_empty_cost_bucket_fallback` | 풀 고갈 시 폴백 동작 |
| 10 | `test_weight_sum_one` | 9개 레벨 각 가중치 합 == 1.0 |

#### test_combat.py 확장 (A4 스톱, +5개)

| # | 테스트 함수 | 검증 |
|---|-----------|------|
| 1 | `test_combat_result_has_stop_field` | `hasattr(result, 'stop_applied')` == True |
| 2 | `test_stop_not_applied_without_hula` | 훌라 없음 → `stop_applied == False` |
| 3 | `test_low_stop_hula_low_hp` | 훌라 성공 + 상대 HP ≤ 10 → `damage == 훌라값 * 2`, `stop_applied=True` |
| 4 | `test_high_stop_scoop_royal_flush` | 훌라 성공 + 스쿠프 + 로열플러시 → `stop_applied=True` |
| 5 | `test_stop_replaces_hula_multiplier` | 스톱 적용 시 최종 배수 ×8 (×4 + ×4 중첩 아님) |

#### test_board.py 확장 (A4 판타지랜드, +5개)

| # | 테스트 함수 | 검증 |
|---|-----------|------|
| 1 | `test_fantasyland_qq_pair` | Front QQ 원페어 → `check_fantasyland()` == True |
| 2 | `test_fantasyland_jj_pair_false` | Front JJ 원페어 → `check_fantasyland()` == False |
| 3 | `test_fantasyland_three_of_a_kind` | Front 스리카인드 → True |
| 4 | `test_fantasyland_empty_front` | Front 비어있음 → False |
| 5 | `test_fantasyland_high_card_false` | Front 하이카드 → False |

#### test_game.py 확장 (A5 다인, +8개)

| # | 테스트 함수 | 검증 |
|---|-----------|------|
| 1 | `test_2player_matchup` | 2인 → `[(0, 1)]` |
| 2 | `test_3player_matchup_2pairs` | 3인 → 쌍 수 == 1 (바이 1명) |
| 3 | `test_3player_bye_no_damage` | 바이 플레이어 HP 변화 없음 |
| 4 | `test_4player_matchup_2pairs` | 4인 → 쌍 수 == 2 |
| 5 | `test_match_history_updates` | 전투 후 match_history 갱신됨 |
| 6 | `test_no_3_consecutive_opponent` | 10라운드 시뮬레이션 → 동일 상대 3연속 없음 |
| 7 | `test_eliminated_player_removed` | HP 0 → players 목록에서 제거 |
| 8 | `test_4player_full_game_no_crash` | 4인 5라운드 자동 완주 예외 없음 |

---

## 8. 위험 요소 해결 방안 (R1~R6)

### R1: count_synergies() 시그니처 변경 — 기존 테스트 깨짐

**위험**: `count_synergies(board, player=None)` 추가 시 기존 `count_synergies(board)` 호출에서 TypeError 발생 가능.

**코드 레벨 해결**:

```python
# player 파라미터를 키워드 인자 + 기본값 None으로 정의
def count_synergies(board: OFCBoard, player=None) -> int:
    ...
    if player is not None and player.has_augment("suit_mystery"):
        ...
```

기존 `count_synergies(board)` 호출은 `player=None` 기본값으로 처리. **기존 테스트 수정 불필요**.

`resolve()` 내부 호출 시에만 `player=player_a` 전달.

### R2: resolve() 시그니처 확장 — 기존 테스트 호환성

**위험**: `resolve()` 에 `player_a`, `player_b`, `events` 파라미터 추가 시 기존 2인수 호출 깨짐.

**코드 레벨 해결**:

```python
def resolve(
    self,
    board_a: OFCBoard,
    board_b: OFCBoard,
    hula_a: bool = False,
    hula_b: bool = False,
    player_a=None,       # 기본값 None — 기존 테스트 호환
    player_b=None,       # 기본값 None
    events: list = None, # 기본값 None → 빈 리스트로 처리
) -> tuple:
    if events is None:
        events = []
```

기존 `resolver.resolve(board_a, board_b)` 호출: `player_a=None, player_b=None, events=[]` 로 동작. 스톱 판정 시 `player_b is not None` 조건 실패 → `low_stop = False`. **기존 테스트 수정 불필요**.

### R3: suit_mystery 선택 수트 명시성 부재

**위험**: PRD §A2.2에서 "선택 수트 1개"라 명시하나, 어떤 수트를 선택했는지 Augment 데이터에 저장되지 않음.

**Alpha 간소화 방안**:
- "선택 수트" → "가장 많이 보유한 수트의 시너지가 충족되면 +1"로 단순화
- 구체적으로: `count_synergies` 결과 `base`에 +1 (어떤 수트인지 무관)
- 선택 UI 없이 자동 적용 → 플레이어 의사 결정 없음 (게임플레이 영향 최소화)

**STANDARD 이연**: Augment에 `selected_suit: str | None = None` 필드 추가 + 증강체 획득 시 수트 선택 CLI 제공.

### R4: double_interest 이자 적용 타이밍 충돌

**위험**: 이자는 `start_prep_phase()`에서 계산되지만, 이벤트는 `advance()` 호출 시 활성화된다. `advance()` 호출이 prep 이전에 발생해야 이자 효과 적용 가능.

**코드 레벨 해결**: `start_prep_phase()` 첫 단계에서 `holdem_state.advance(round_in_stage)` 호출 후 이자 계산:

```python
def start_prep_phase(self):
    self.state.phase = 'prep'

    # 1. 홀덤 이벤트 advance (이자 계산 전에 반드시 먼저)
    if self.state.holdem_state:
        round_in_stage = ((self.state.round_num - 1) % 3) + 1
        self.state.holdem_state.advance(round_in_stage)

    # 2. 골드 수입 계산 (active_events 기반)
    for player in self.state.players:
        income = player.round_income()
        if (self.state.holdem_state
                and self.state.holdem_state.has_active_event("double_interest")):
            income += player.calc_interest()  # 이자 부분 추가 (×2 효과)
        player.gold += income
```

`advance()` 호출 순서를 명시적으로 보장. 타이밍 충돌 없음.

### R5: 판타지랜드 13장 드로우 구현 복잡도

**위험**: 판타지랜드 진입 시 13장 드로우 + CLI 상호작용은 복잡도가 높다.

**Alpha 범위 제한**:
- `in_fantasyland = True` 플래그 설정
- Foul 면제 효과 적용
- 13장 드로우 및 반환: STANDARD 단계 이연

**코드 레벨 명시**: `game.py`에 주석으로 명시:

```python
# Alpha 범위: 판타지랜드 플래그 설정 + Foul 면제만 구현.
# 13장 드로우/반환 인터랙션은 STANDARD 단계에서 구현.
# if player.in_fantasyland:
#     shop_cards = pool.random_draw_n(13, player.level)  # STANDARD
```

### R6: 3인 바이 플레이어 매칭 공정성

**위험**: 순수 랜덤 바이 배정 시 동일 플레이어에게 바이 편중 가능.

**코드 레벨 해결**: `_get_bye_counts()` + 바이 최소 플레이어 우선 배정:

```python
def generate_matchups(self) -> list:
    ...
    elif n == 3:
        bye_counts = self._get_bye_counts()
        # 바이 횟수 최소인 플레이어에게 바이 부여 (동률 시 첫 번째)
        bye_idx = min(indices, key=lambda i: bye_counts.get(players[i].name, 0))
        active = [i for i in indices if i != bye_idx]
        self._record_bye(players[bye_idx].name)
        return [(active[0], active[1])]
```

주의: 바이 횟수 동률 시 `min()`이 첫 번째 인덱스를 선택 — 결정론적 동작 보장. 랜덤성 제거로 테스트 재현 가능.

---

## 9. 구현 파일 목록 (변경/신규 전체)

### 신규 파일 (2개)

| 파일 | 크기 예상 | 내용 요약 |
|------|---------|---------|
| `src/augment.py` | 40~60줄 | `Augment` dataclass(frozen), `SILVER_AUGMENTS` 3종 상수 |
| `src/holdem.py` | 70~90줄 | `HoldemEvent`(frozen), `HoldemState`, `PILOT_EVENTS` 5종, `create_holdem_state()` |

### 수정 파일 (5개)

| 파일 | 변경 규모 | 주요 변경 내용 |
|------|---------|------------|
| `src/economy.py` | 소 (+25줄) | Player에 augments/in_fantasyland/fantasyland_next 필드 + add_augment/has_augment 메서드, calc_interest economist 분기 |
| `src/board.py` | 소 (+20줄) | 모듈 레벨에 `check_fantasyland()` 함수 추가 |
| `src/combat.py` | 중 (+40줄) | CombatResult.stop_applied 필드, count_synergies player 파라미터, resolve() 시그니처 확장 + 스톱/이벤트 처리 블록 |
| `src/game.py` | 대 (+80줄) | GameState 3개 필드 추가, RoundManager: generate_matchups/start_combat_phase 전면 재작성, end_round 확장, 헬퍼 메서드 추가 |
| `cli/main.py` | 소 (+30줄) | 플레이어 수 선택 프롬프트, 활성 이벤트 출력, 다인 전투 루프, 탈락 알림 |

### 불변 파일 (변경 없음)

| 파일 | 사유 |
|------|------|
| `src/card.py` | 기반 도메인 완성 |
| `src/pool.py` | A1 이미 완전 구현 |
| `src/hand.py` | 핸드 판정 완성 |

### 신규 테스트 파일 (2개)

| 파일 | 케이스 수 | 대상 |
|------|---------|------|
| `tests/test_augment.py` | 17개+ | A2 증강체 전체 |
| `tests/test_holdem.py` | 16개+ | A3 홀덤 이벤트 전체 |

### 확장 테스트 파일 (4개)

| 파일 | 추가 케이스 | 대상 |
|------|-----------|------|
| `tests/test_card.py` | +10개 | A1 드롭률 통계 검증 |
| `tests/test_combat.py` | +5개 | A4 스톱 선언 |
| `tests/test_board.py` | +5개 | A4 판타지랜드 판정 |
| `tests/test_game.py` | +8개 | A5 다인 매칭 |

### 목표 테스트 수

```
기존 176개 + 신규 58개+ = 234개+
```

---

## 부록: 증강체 효과 빠른 참조

| ID | 이름 | 효과 위치 | 수치 변경 | 조건 |
|----|------|---------|---------|------|
| `economist` | 경제학자 | `economy.py:calc_interest()` | 이자 상한 5 → 6 | 항상 (passive) |
| `suit_mystery` | 수트의 신비 | `combat.py:count_synergies()` | 시너지 +1, 최대 4 | 전투 시 (passive) |
| `lucky_shop` | 행운의 상점 | `game.py:RoundManager` 상점 드로우 | 드로우 수 5 → 6 | prep 페이즈 (passive) |

상한/하한:
- economist: gold ≥ 60 시 이자 6 (gold < 60 시 정상 공식 적용)
- suit_mystery: base + 1 결과가 4 초과하면 4로 클램핑
- lucky_shop: 풀 카드가 6장 미만이면 가용 카드 수만 반환

---

## 부록: 홀덤 이벤트 빠른 참조

| ID | 이름 | 단계 | 효과 위치 | 수치/조건 |
|----|------|------|---------|---------|
| `suit_bonus_spade` | 스페이드 우위 | Flop | `combat.py:resolve()` | ♠ 2장 이상 시 synergies +1 |
| `double_interest` | 이자 배가 | Flop | `game.py:start_prep_phase()` | 이자 수입 1회 추가 (×2 효과) |
| `foul_amnesty` | 폴 면제 | Turn | `combat.py:resolve()` | Foul 판정 완전 스킵 |
| `scoop_bonus` | 스쿠프 강화 | Turn | `combat.py:calc_damage()` | 스쿠프 추가 피해 +2 → +6 |
| `low_card_power` | 로우카드 역전 | River | Alpha 범위 외 | STANDARD 구현 예정 |

이벤트 누적 규칙:
- Flop(라운드 1): 3장 동시 활성
- Turn(라운드 2): Flop 3장 + Turn 1장 = 최대 4장
- River(라운드 3): 전체 최대 5장 활성
- 스테이지 초기화 시 active_events 리셋
