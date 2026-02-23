# Trump Card Auto Chess — Alpha 단계 구현 계획

**버전**: 1.0.0
**복잡도**: STANDARD (3/5)
**기반 PRD**: docs/00-prd/alpha.prd.md

---

## 목차

1. [작업 개요](#1-작업-개요)
2. [구현 순서](#2-구현-순서)
3. [파일별 변경 명세](#3-파일별-변경-명세)
4. [TDD 테스트 계획](#4-tdd-테스트-계획)
5. [위험 요소 및 완화 방안](#5-위험-요소-및-완화-방안)
6. [완료 기준](#6-완료-기준)

---

## 1. 작업 개요

### 1.1 배경

POC 단계에서 176개 TDD 테스트를 전부 통과하고 2인 로컬 대전 CLI가 정상 동작하는 것을 확인했다.
Alpha 단계는 POC에서 의도적으로 제외한 5개 기능을 추가하여 게임 깊이를 확보하는 단계다.

### 1.2 Alpha 구현 대상 (POC 미구현 5항목)

| 요구사항 ID | 이름 | 우선순위 | 독립 여부 |
|------------|------|--------|---------|
| A1 | 상점 레벨별 드롭률 가중치 | P1 — 블로킹 | 독립 (선행 필수) |
| A2 | 증강체 Silver 3종 | P2 | A1 이후 착수 |
| A3 | 홀덤 이벤트 파일럿 5종 | P3 | A1~A2 이후 착수 |
| A4 | 스톱(×8) 선언 + 판타지랜드 | P2 | 독립 병렬 가능 |
| A5 | 3~4인 매칭 확장 | P4 | A3 이후 착수 |

### 1.3 현재 코드 상태 요약

읽은 소스 파일 기준 실제 현황:

| 파일 | 현재 상태 | Alpha 작업 필요 |
|------|---------|--------------|
| `src/pool.py` | `_LEVEL_WEIGHTS` 상수 + `random_draw_n` 완전 구현됨 (레벨 기반 가중치 이미 적용) | 없음 (A1 이미 구현) |
| `src/economy.py` | `Player.level: int = 1` 필드 존재. `calc_interest()` 상한=5 | 증강체 필드 추가, `calc_interest` 수정 |
| `src/combat.py` | `CombatResult` 5필드, `CombatResolver.resolve()` 2인 구현 | `stop_applied` 필드 추가, 스톱 판정 로직 |
| `src/game.py` | `GameState` 4필드, `RoundManager` 2인 하드코딩 | `HoldemState`, 다인 매칭 로직 추가 |
| `src/board.py` | `OFCBoard`, `check_foul()` 구현. `check_fantasyland()` 없음 | `check_fantasyland()` 추가 |

> **발견 사항**: `pool.py`의 `random_draw_n`에 레벨 기반 가중치 드롭률이 이미 완전 구현되어 있다 (lines 7~118).
> A1 요구사항의 `LEVEL_DROP_RATES` 상수와 `random_draw_n` 로직 변경은 **이미 완료 상태**다.
> 단, PRD §A1의 확률 테이블과 `_LEVEL_WEIGHTS` 값이 일부 다르다 (POC 설계 §5.5 기준 적용된 것으로 추정).
> 테스트 파일에서 실제 커버리지를 검증하고 PRD §10.6 기준 값과 대조하는 테스트 추가 필요.

### 1.4 산출물 목표

- 신규 파일: 2개 (`src/augment.py`, `src/holdem.py`)
- 수정 파일: 5개 (`src/economy.py`, `src/combat.py`, `src/board.py`, `src/game.py`, `cli/main.py`)
- 신규 테스트 파일: 2개 (`tests/test_augment.py`, `tests/test_holdem.py`)
- 기존 테스트 확장: 4개 (`test_card.py`, `test_combat.py`, `test_board.py`, `test_game.py`)
- 목표 총 테스트 수: 234개+ (기존 176 + 신규 58+)

---

## 2. 구현 순서

### 2.1 의존성 그래프

```
  [A1 검증] pool.py _LEVEL_WEIGHTS 확인 + 테스트 추가
      |
      v
  [A4 병렬] ──────────────────────────────────────────────+
  combat.py: CombatResult.stop_applied                    |
  combat.py: 스톱 판정 로직                                |
  board.py:  check_fantasyland()                          |
  economy.py: Player.in_fantasyland, fantasyland_next     |
                                                          |
      v                                                   |
  [A2] augment.py 신규 생성                               |
  economy.py: Player.augments 필드                        |
  economy.py: calc_interest() economist 보정              |
  combat.py:  count_synergies() suit_mystery 보정         |
  game.py:    증강체 선택 페이즈                            |
      |                                                   |
      v                                                   |
  [A3] holdem.py 신규 생성                                 |
  game.py:   GameState.holdem_state                       |
  combat.py: resolve() events 파라미터                     |
  cli/main.py: 이벤트 출력                                 |
      |                                                   |
      v                                                   v
  [A5] game.py: generate_matchups()                      통합
  game.py: match_history 추적
  cli/main.py: 플레이어 수 선택
      |
      v
  [통합 검증] pytest 234개+ PASS
```

### 2.2 Phase별 구현 계획

#### Phase Alpha-1: 기반 확립

**목표**: A1 검증 + A4 완료

| 순서 | 작업 | 대상 파일 | 핵심 내용 |
|------|------|---------|---------|
| 1-1 | A1 확률 테이블 검증 | `src/pool.py` (읽기) | `_LEVEL_WEIGHTS` vs PRD §10.6 값 대조 |
| 1-2 | A1 테스트 추가 | `tests/test_card.py` | 레벨=9 시 5코스트 25% 분포 통계 검증 |
| 1-3 | `check_fantasyland()` 추가 | `src/board.py` | Front QQ+ 원페어 이상 판정 |
| 1-4 | `CombatResult.stop_applied` | `src/combat.py` | dataclass 필드 추가 |
| 1-5 | 스톱 판정 로직 | `src/combat.py` | 훌라 성공 후 스톱 조건 추가 검증 |
| 1-6 | `Player` 판타지랜드 필드 | `src/economy.py` | `in_fantasyland`, `fantasyland_next` |
| 1-7 | 판타지랜드 게임 적용 | `src/game.py` | 라운드 종료 시 판타지랜드 상태 갱신 |
| 1-8 | Phase Alpha-1 테스트 | `tests/test_board.py`, `tests/test_combat.py` | 판타지랜드 5개+, 스톱 선언 5개+ |

#### Phase Alpha-2: 증강체 + 홀덤 이벤트

**목표**: A2 + A3 완료

| 순서 | 작업 | 대상 파일 | 핵심 내용 |
|------|------|---------|---------|
| 2-1 | `Augment` dataclass | `src/augment.py` (신규) | `SILVER_AUGMENTS` 3종 상수 |
| 2-2 | `Player.augments` 통합 | `src/economy.py` | `add_augment()`, `has_augment()` |
| 2-3 | `calc_interest()` 수정 | `src/economy.py` | economist 증강체 시 상한 6 |
| 2-4 | `count_synergies()` 수정 | `src/combat.py` | suit_mystery 증강체 보정 |
| 2-5 | 증강체 선택 페이즈 | `src/game.py` | 라운드 2-4 종료 시 Silver 선택 |
| 2-6 | `HoldemEvent` dataclass | `src/holdem.py` (신규) | `PILOT_EVENTS` 5종 상수 |
| 2-7 | `GameState.holdem_state` | `src/game.py` | `HoldemState` 필드 + 라운드별 이벤트 진행 |
| 2-8 | `resolve()` 이벤트 파라미터 | `src/combat.py` | `events` 파라미터 추가 + 효과 적용 |
| 2-9 | CLI 이벤트 출력 | `cli/main.py` | 전투 전 활성 이벤트 목록 출력 |
| 2-10 | Phase Alpha-2 테스트 | `tests/test_augment.py`, `tests/test_holdem.py` | 각 15개+ |

#### Phase Alpha-3: 다인 매칭 + 통합 검증

**목표**: A5 완료 + 전체 통합 검증

| 순서 | 작업 | 대상 파일 | 핵심 내용 |
|------|------|---------|---------|
| 3-1 | `generate_matchups()` | `src/game.py` | N=2,3,4인 매칭 쌍 생성 |
| 3-2 | `match_history` 추적 | `src/game.py` | 3연속 같은 상대 방지 |
| 3-3 | `start_combat_phase()` 리팩토링 | `src/game.py` | 다인 지원, 하드코딩 제거 |
| 3-4 | CLI 플레이어 수 선택 | `cli/main.py` | 2~4인 선택 프롬프트 |
| 3-5 | 다인 전투 루프 | `cli/main.py` | 각 매칭 쌍 결과 순차 출력 |
| 3-6 | 3인/4인 매칭 테스트 | `tests/test_game.py` | 바이 처리, 매칭 히스토리 8개+ |
| 3-7 | 전체 통합 테스트 | `pytest tests/ -v` | 234개+ PASS 확인 |
| 3-8 | 린트 검사 | `ruff check src/` | PASS 확인 |

---

## 3. 파일별 변경 명세

### 3.1 `src/pool.py` (검증만 필요, 코드 변경 최소)

**현재 상태**: `_LEVEL_WEIGHTS` 딕셔너리 (lines 7~17)에 레벨 1~9의 5코스트 가중치가 정의되어 있다.
`random_draw_n(n, level)` 메서드가 완전 구현되어 있다 (lines 62~118).

**PRD §10.6 vs 현재 구현 비교**:

| 레벨 | PRD §10.6 (1/2/3/4/5코스트) | 현재 `_LEVEL_WEIGHTS` | 일치 여부 |
|------|--------------------------|---------------------|---------|
| 1 | 75/20/5/0/0 | 75/20/5/0/0 | 일치 |
| 2 | 75/20/5/0/0 | 75/20/5/0/0 | 일치 |
| 3 | 55/30/15/0/0 | 55/30/15/0/0 | 일치 |
| 4 | 55/30/15/0/0 | 55/30/15/0/0 | 일치 |
| 5 | 35/35/25/5/0 | 35/35/25/5/0 | 일치 |
| 6 | 20/35/30/14/1 | 20/35/30/14/1 | 일치 |
| 7 | 15/25/35/20/5 | 15/25/35/20/5 | 일치 |
| 8 | 10/15/35/30/10 | 10/15/35/30/10 | 일치 |
| 9 | 5/10/25/35/25 | 5/10/25/35/25 | 일치 |

> **결론**: `pool.py`는 변경 불필요. 테스트만 추가한다.

**변경 내용**: 없음 (읽기 전용 검증)
**영향 범위**: 없음

---

### 3.2 `src/economy.py` (수정)

**현재 상태**:
- `Player.level: int = 1` 필드 존재 (line 13)
- `calc_interest()`: `min(self.gold // 10, 5)` — 상한 5 고정 (line 26-28)
- 증강체 관련 필드/메서드 없음
- 판타지랜드 관련 필드 없음

**변경 내용**:

```
추가 필드 (Player dataclass):
  augments: list = field(default_factory=list)   # Augment 인스턴스 목록
  in_fantasyland: bool = False                    # 현재 라운드 판타지랜드 여부
  fantasyland_next: bool = False                  # 다음 라운드 판타지랜드 진입 예약

추가 메서드:
  add_augment(augment: Augment) -> None
    - self.augments.append(augment)

  has_augment(augment_id: str) -> bool
    - return any(a.id == augment_id for a in self.augments)

수정 메서드:
  calc_interest() -> int:
    cap = 6 if self.has_augment("economist") else 5
    return min(self.gold // 10, cap)
```

**영향 범위**: `test_economy.py` (기존 테스트 `calc_interest` 상한=5 케이스는 유지됨)

---

### 3.3 `src/augment.py` (신규 생성)

**현재 상태**: 파일 없음

**변경 내용**:

```
신규 파일 구조:
  @dataclass
  class Augment:
      id: str
      name: str
      tier: str            # "silver" | "gold" | "prismatic"
      description: str
      effect_type: str     # "passive" | "trigger"

  SILVER_AUGMENTS: list[Augment] = [
      Augment(
          id="economist",
          name="경제학자",
          tier="silver",
          description="이자 수입 상한 5→6골드",
          effect_type="passive"
      ),
      Augment(
          id="suit_mystery",
          name="수트의 신비",
          tier="silver",
          description="선택 수트 1개 시너지 카운트 +1 (영구)",
          effect_type="passive"
      ),
      Augment(
          id="lucky_shop",
          name="행운의 상점",
          tier="silver",
          description="매 라운드 상점 공개 +1장 (5→6장)",
          effect_type="passive"
      ),
  ]
```

**영향 범위**: `economy.py`(import), `combat.py`(import), `game.py`(import)

---

### 3.4 `src/combat.py` (수정)

**현재 상태**:
- `CombatResult`: 5필드 (`line_results`, `winner_lines`, `is_scoop`, `damage`, `hula_applied`) (lines 9-14)
- `count_synergies()`: 수트별 2장 이상 수트 카운트 (lines 17-23)
- `CombatResolver.resolve()`: 훌라 `winner_lines >= 2 AND synergies >= 3` 적용 후 `damage *= 4` (lines 73-87)
- 스톱 선언 로직 없음

**변경 내용**:

```
CombatResult 필드 추가:
  stop_applied: bool = False      # 스톱(×8) 선언 적용 여부

count_synergies() 시그니처 변경:
  def count_synergies(board: OFCBoard, player=None) -> int:
    # player가 suit_mystery 증강체 보유 시 선호 수트 카운트 +1
    base = sum(1 for cnt in suit_counts.values() if cnt >= 2)
    if player and player.has_augment("suit_mystery"):
        # 선택 수트 1개를 +1 보정 (시너지 임계값 충족 유리)
        base = min(base + 1, 4)   # 수트는 최대 4종
    return base

resolve() 시그니처 확장:
  def resolve(
      self,
      board_a: OFCBoard,
      board_b: OFCBoard,
      hula_a: bool = False,
      hula_b: bool = False,
      player_a=None,           # 증강체 보정용 Player 참조
      player_b=None,
      events: list = None,     # HoldemEvent 목록
  ) -> tuple:

스톱 판정 로직 추가 (훌라 처리 블록 직후):
  # 스톱(×8) 판정: 훌라 성공 후 추가 조건 검증
  if hula_applied_a:
      # 로우 스톱: opponent.hp <= 10
      low_stop_a = (player_b is not None and player_b.hp <= 10)
      # 하이 스톱: 스쿠프 + Back 로열 플러시
      back_hand_a = evaluate_hand(board_a.back) if board_a.back else None
      high_stop_a = (
          is_scoop_a
          and back_hand_a is not None
          and back_hand_a.hand_type.value == 10  # ROYAL_FLUSH
      )
      if low_stop_a or high_stop_a:
          damage_a = damage_a // 4 * 8   # 훌라 ×4 취소 후 ×8 적용
          stop_applied_a = True
      else:
          stop_applied_a = False
  else:
      stop_applied_a = False
  # (player_a / board_b 대칭 처리)

이벤트 효과 적용 블록 추가 (Foul 판정 이전):
  # 활성 이벤트에서 foul_amnesty 감지 → Foul 판정 스킵
  # 활성 이벤트에서 scoop_bonus 감지 → calc_damage() 추가 피해 +4
  # 활성 이벤트에서 suit_bonus_spade 감지 → count_synergies 보정
  # 활성 이벤트에서 low_card_power 감지 → compare_hands 역전 플래그
```

**영향 범위**: `tests/test_combat.py` (기존 테스트 시그니처 호환 유지: `player_a/b`, `events` 기본값 None)

---

### 3.5 `src/board.py` (수정)

**현재 상태**:
- `OFCBoard`: `front`, `mid`, `back` 리스트 (lines 14-17)
- `check_foul()`: Back≥Mid≥Front 위반 감지 (lines 46-62)
- `check_fantasyland()` 없음

**변경 내용**:

```
추가 함수 (모듈 레벨):
  def check_fantasyland(board: OFCBoard) -> bool:
      """Front 라인 QQ+ 원페어 이상 달성 여부 판정"""
      from src.hand import evaluate_hand, HandType
      from src.card import Rank

      if not board.front:
          return False

      front_hand = evaluate_hand(board.front)

      if front_hand.hand_type == HandType.ONE_PAIR:
          # 페어를 구성하는 랭크가 Q(12) 이상인지 확인
          from collections import Counter
          rank_counts = Counter(c.rank for c in board.front)
          pair_ranks = [r for r, cnt in rank_counts.items() if cnt >= 2]
          return bool(pair_ranks) and max(pair_ranks) >= Rank.QUEEN
      # 스리카인드 이상 (Front 최강 핸드)
      return front_hand.hand_type > HandType.ONE_PAIR
```

**영향 범위**: `tests/test_board.py` (판타지랜드 판정 5개+ 테스트)

---

### 3.6 `src/holdem.py` (신규 생성)

**현재 상태**: 파일 없음

**변경 내용**:

```
신규 파일 구조:
  @dataclass
  class HoldemEvent:
      id: str
      name: str
      phase: str           # "flop" | "turn" | "river"
      description: str
      effect_type: str     # "suit_boost" | "economy" | "foul" | "combat"

  @dataclass
  class HoldemState:
      stage: int
      flop: list           # HoldemEvent 3장
      turn: 'HoldemEvent | None'
      river: 'HoldemEvent | None'
      active_events: list  # 현재 라운드 적용 이벤트

      def advance(self, round_in_stage: int) -> None:
          """라운드 내 순서(1=Flop, 2=Turn, 3=River)에 따라 이벤트 공개"""

  PILOT_EVENTS: list[HoldemEvent] = [
      HoldemEvent(id="suit_bonus_spade", name="스페이드 우위",
                  phase="flop", description="♠ 수트 시너지 카운트 +1",
                  effect_type="suit_boost"),
      HoldemEvent(id="double_interest", name="이자 배가",
                  phase="flop", description="이번 라운드 이자 수입 ×2",
                  effect_type="economy"),
      HoldemEvent(id="foul_amnesty", name="폴 면제",
                  phase="turn", description="이번 라운드 Foul 패널티 미적용",
                  effect_type="foul"),
      HoldemEvent(id="scoop_bonus", name="스쿠프 강화",
                  phase="turn", description="스쿠프 시 추가 피해 +4",
                  effect_type="combat"),
      HoldemEvent(id="low_card_power", name="로우카드 역전",
                  phase="river", description="하이카드 비교 역전",
                  effect_type="combat"),
  ]
```

**영향 범위**: `game.py`(import), `combat.py`(import)

---

### 3.7 `src/game.py` (수정)

**현재 상태**:
- `GameState`: 4필드 (`players`, `pool`, `round_num`, `phase`) (lines 9-14)
- `RoundManager.start_combat_phase()`: `len(players) == 2` 하드코딩 (lines 45-76)
- `HoldemState`, 증강체 선택, `match_history` 없음

**변경 내용**:

```
GameState 필드 추가:
  match_history: dict = field(default_factory=dict)  # player.name → 최근 3명 상대
  combat_pairs: list = field(default_factory=list)   # 현재 라운드 [(idx_a, idx_b)]
  holdem_state: 'HoldemState | None' = None          # 홀덤 이벤트 상태

RoundManager 추가 메서드:
  def generate_matchups(self) -> list[tuple[int, int]]:
      """생존 플레이어 수에 따라 전투 쌍 생성 (N=2,3,4 지원)
      - N=2: [(0,1)]
      - N=3: 3인 라운드 로빈 중 2쌍, 1명 바이 (랜덤)
      - N=4: 2쌍 동시 전투 (match_history 3연속 금지)
      """

  def _pick_pairs_avoid_repeat(
      self, players: list, history: dict
  ) -> list[tuple[int, int]]:
      """match_history 기반 같은 상대 3연속 방지 매칭 쌍 선택"""

start_combat_phase() 리팩토링:
  def start_combat_phase(self) -> list:
      self.state.phase = 'combat'
      pairs = self.generate_matchups()
      self.state.combat_pairs = pairs
      results = []
      active_events = (
          self.state.holdem_state.active_events
          if self.state.holdem_state else []
      )
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
          # 연승/연패 업데이트 (기존 로직 유지)
          self._update_streaks(p_a, p_b, result_a, result_b)
          # match_history 업데이트
          self._update_match_history(idx_a, idx_b)
          results.append((result_a, result_b))
      return results

  def _update_streaks(self, p_a, p_b, r_a, r_b) -> None: ...
  def _update_match_history(self, idx_a: int, idx_b: int) -> None: ...

end_round() 수정:
  - 판타지랜드 플래그 전환 처리 (fantasyland_next → in_fantasyland)
  - 증강체 선택 페이즈 처리 (라운드 2, 3, 4 종료 시)
  - HP 0 플레이어 제거 및 생존자만 유지
  - 홀덤 이벤트 advance()
```

**영향 범위**: `tests/test_game.py` (3인/4인 매칭 8개+ 테스트)

---

### 3.8 `cli/main.py` (수정)

**현재 상태**: 읽지 않음 (Alpha 계획에서 CLI 변경 명세만 기록)

**변경 내용**:
- 플레이어 수 선택 프롬프트 추가 (2~4인)
- 각 매칭 쌍 전투 결과 순차 출력
- 전투 전 활성 홀덤 이벤트 목록 출력
- 탈락 플레이어 제거 및 생존자 상태 업데이트
- `--auto` 모드: 4인 기본 설정으로 자동 진행

**영향 범위**: 수동 테스트 (`python cli/main.py --auto` 크래시 없이 완료)

---

## 4. TDD 테스트 계획

### 4.1 테스트 원칙

TDD 순서: Red(실패 테스트 먼저) → Green(최소 구현) → Refactor

모든 신규 테스트는 구현 전 작성한다.

### 4.2 `tests/test_card.py` 확장 (A1 검증)

**기존**: 24개 테스트 (추정)
**추가 목표**: 10개+

| 테스트 함수 | 검증 내용 | Red 조건 |
|-----------|---------|---------|
| `test_level1_drop_only_low_cost` | level=1 드로우 1000회 → 5코스트 카드 0% 기대 | `_LEVEL_WEIGHTS[1][4] == 0` 확인 |
| `test_level9_five_cost_distribution` | level=9 드로우 1000회 → 5코스트 20~30% 범위 | 통계적 범위 검증 |
| `test_level5_no_five_cost` | level=5 드로우 → 5코스트 출현 없음 | `weights[4] == 0` |
| `test_empty_cost_bucket_fallback` | 특정 코스트 풀 고갈 시 인접 코스트로 폴백 | 빈 풀에서 draw 시 빈 리스트 아님 |
| `test_draw_n_depletes_pool` | 드로우 후 풀 카드 수 정확히 감소 | `remaining()` 값 검증 |
| `test_level_clamp_min` | level=0 입력 → level=1로 처리 | ValueError 없이 실행 |
| `test_level_clamp_max` | level=10 입력 → level=9로 처리 | ValueError 없이 실행 |
| `test_random_draw_n_returns_n_cards` | n=5 요청 → 5장 반환 (풀 충분 시) | `len(result) == 5` |
| `test_drawn_cards_removed_from_pool` | 드로우된 카드 즉시 풀에서 차감 | `remaining(rank, suit)` 감소 확인 |
| `test_level6_four_cost_appears` | level=6 드로우 → 4코스트 카드 출현 가능 | `weights[3] == 0.14` |

### 4.3 `tests/test_augment.py` 신규 (A2)

**목표**: 15개+

| 테스트 함수 | 검증 내용 | Red 조건 |
|-----------|---------|---------|
| `test_augment_dataclass_fields` | Augment 필드 id/name/tier/description/effect_type | 임포트 성공 |
| `test_silver_augments_count` | `SILVER_AUGMENTS` 길이 == 3 | 상수 정의 확인 |
| `test_silver_augments_ids` | economist/suit_mystery/lucky_shop 모두 포함 | id 집합 일치 |
| `test_all_silver_tier` | 모든 SILVER_AUGMENTS.tier == "silver" | tier 값 검증 |
| `test_player_add_augment` | `player.add_augment(aug)` 후 `player.augments` 길이 +1 | AttributeError 없음 |
| `test_player_has_augment_true` | 추가 후 `has_augment("economist")` == True | 반환값 검증 |
| `test_player_has_augment_false` | 미추가 시 `has_augment("economist")` == False | 반환값 검증 |
| `test_economist_interest_cap_6` | economist 보유 시 gold=60 → interest=6 | `calc_interest()` == 6 |
| `test_economist_interest_cap_5_without` | economist 없을 때 gold=60 → interest=5 | `calc_interest()` == 5 |
| `test_suit_mystery_synergy_boost` | suit_mystery 보유 시 시너지 카운트 +1 | `count_synergies()` 증가 |
| `test_suit_mystery_max_cap` | 시너지 4개인 상태에서 +1 → 4 유지 (상한 초과 방지) | `count_synergies()` <= 4 |
| `test_lucky_shop_draw_count` | lucky_shop 보유 시 상점 드로우 6장 | `game` 레벨에서 검증 |
| `test_augment_selection_round2` | 라운드 2 종료 시 Silver 증강체 선택 제안 | GameState 내 augment_offered |
| `test_augment_not_offered_round1` | 라운드 1 종료 시 증강체 선택 없음 | 해당 이벤트 없음 |
| `test_player_multiple_augments` | 플레이어 2개 증강체 보유 가능 | `len(player.augments) == 2` |

### 4.4 `tests/test_holdem.py` 신규 (A3)

**목표**: 15개+

| 테스트 함수 | 검증 내용 | Red 조건 |
|-----------|---------|---------|
| `test_holdem_event_dataclass` | HoldemEvent 필드 정확 | 임포트 성공 |
| `test_pilot_events_count` | `PILOT_EVENTS` 길이 == 5 | 상수 정의 확인 |
| `test_pilot_events_phases` | flop 2개, turn 2개, river 1개 | phase 분포 검증 |
| `test_holdem_state_init` | HoldemState 초기화 후 active_events 빈 리스트 | 필드 기본값 |
| `test_flop_advances_3_events` | `advance(1)` 호출 → active_events 3개 (flop) | Flop 이벤트 3개 |
| `test_turn_advances_1_event` | `advance(2)` 호출 → active_events +1 (turn) | Turn 이벤트 추가 |
| `test_river_advances_1_event` | `advance(3)` 호출 → active_events +1 (river) | River 이벤트 추가 |
| `test_foul_amnesty_skips_penalty` | foul_amnesty 이벤트 활성 시 Foul 패널티 미적용 | CombatResolver 검증 |
| `test_scoop_bonus_extra_damage` | scoop_bonus 활성 시 스쿠프 피해 +4 → 총 +6 | `damage` 값 검증 |
| `test_suit_bonus_spade_synergy` | suit_bonus_spade 활성 시 ♠ 시너지 +1 | `count_synergies` 값 |
| `test_double_interest_effect` | double_interest 활성 시 이자 ×2 | `calc_interest()` 배가 |
| `test_low_card_power_reversal` | low_card_power 활성 시 하이카드 비교 역전 | 낮은 랭크 우선 |
| `test_event_not_active_without_advance` | advance 없으면 active_events 빈 리스트 | 초기 상태 보장 |
| `test_holdem_state_in_gamestate` | GameState.holdem_state 필드 존재 | AttributeError 없음 |
| `test_active_events_display` | CLI가 active_events를 출력하는지 (smoke) | stdout 포함 확인 |

### 4.5 `tests/test_combat.py` 확장 (A4 스톱 선언)

**기존**: 15개 테스트 (추정)
**추가 목표**: 5개+

| 테스트 함수 | 검증 내용 | Red 조건 |
|-----------|---------|---------|
| `test_stop_not_applied_without_hula` | 훌라 없으면 stop_applied=False | `CombatResult.stop_applied` 존재 |
| `test_low_stop_hula_plus_low_hp` | 훌라 성공 + 상대 HP ≤ 10 → damage × 8 | `result.damage == 훌라×4값 × 2` |
| `test_high_stop_scoop_royal` | 훌라 성공 + 스쿠프 + 로열 플러시 → damage × 8 | `stop_applied=True` |
| `test_stop_replaces_hula` | 스톱 적용 시 훌라 ×4 중첩 없음 (×8이 최우선) | `hula_applied=True` AND `stop_applied=True` → damage 배율 확인 |
| `test_combat_result_has_stop_field` | `CombatResult` 인스턴스에 `stop_applied` 필드 | `hasattr` 확인 |

### 4.6 `tests/test_board.py` 확장 (A4 판타지랜드)

**기존**: 21개 테스트 (추정)
**추가 목표**: 5개+

| 테스트 함수 | 검증 내용 | Red 조건 |
|-----------|---------|---------|
| `test_fantasyland_qq_pair` | Front QQ 원페어 → `check_fantasyland()` == True | 함수 존재 |
| `test_fantasyland_jj_pair_false` | Front JJ 원페어 → `check_fantasyland()` == False | Q 미달 |
| `test_fantasyland_three_of_a_kind` | Front 스리카인드 → `check_fantasyland()` == True | 스리카인드 이상 |
| `test_fantasyland_empty_front` | Front 비어있음 → `check_fantasyland()` == False | 빈 라인 처리 |
| `test_fantasyland_high_card_false` | Front 하이카드 → `check_fantasyland()` == False | 패 상태 |

### 4.7 `tests/test_game.py` 확장 (A5 다인 매칭)

**기존**: 18개 테스트 (추정)
**추가 목표**: 8개+

| 테스트 함수 | 검증 내용 | Red 조건 |
|-----------|---------|---------|
| `test_2player_matchup` | 2인 → 쌍 [(0,1)] | `generate_matchups()` 존재 |
| `test_3player_matchup_2pairs` | 3인 → 2쌍 + 바이 1명 | 쌍 수 == 2 |
| `test_3player_bye_player_no_damage` | 바이 플레이어 HP 변화 없음 | HP 유지 |
| `test_4player_matchup_2pairs` | 4인 → 2쌍 동시 | 쌍 수 == 2 |
| `test_match_history_updates` | 전투 후 match_history 기록 | history 길이 > 0 |
| `test_no_3_consecutive_same_opponent` | 같은 상대 3연속 금지 | 10라운드 시뮬레이션 |
| `test_eliminated_player_removed` | HP 0 → players 목록에서 제거 | 탈락 후 생존자 수 |
| `test_4player_full_game_no_crash` | 4인 5라운드 자동 완주 크래시 없음 | 예외 없이 완료 |

---

## 5. 위험 요소 및 완화 방안

### R1: `count_synergies()` 시그니처 변경에 따른 기존 테스트 깨짐

**설명**: `count_synergies(board, player=None)` 으로 파라미터 추가 시, 기존 `count_synergies(board)` 호출 코드에서 TypeError 발생 가능.

**완화 방안**:
- `player` 파라미터를 키워드 인자 + 기본값 `None`으로 추가하여 하위 호환 유지
- 기존 테스트 수정 불필요 (`player=None`이면 기존 로직 그대로)

### R2: `CombatResolver.resolve()` 시그니처 확장에 따른 기존 테스트 호환성

**설명**: `resolve()` 에 `player_a`, `player_b`, `events` 파라미터 추가 시 기존 2인수 호출이 깨질 수 있음.

**완화 방안**:
- 모든 신규 파라미터를 키워드 인자 + 기본값 `None`으로 정의
- `start_combat_phase()` 에서만 신규 파라미터 전달
- 기존 테스트는 파라미터 없이 호출 → 변경 없이 PASS

### R3: `suit_mystery` 증강체의 선택 수트 명시성 부재

**설명**: PRD §A2.2에서 "선택 수트 1개" 라 명시하지만, 어떤 수트를 선택했는지 Augment 데이터에 저장되지 않음.

**완화 방안 1 (Alpha 간소화)**: `suit_mystery` 효과를 "가장 많이 보유한 수트의 시너지 +1"로 단순화하여 선택 저장 불필요.
**완화 방안 2 (정확 구현)**: Augment에 `selected_suit: str | None` 필드 추가. 증강체 획득 시 수트 선택 UI 제공.

> Alpha에서는 완화 방안 1 적용. 선택 UI는 STANDARD 단계로 이연.

### R4: 홀덤 이벤트 `double_interest`의 이자 적용 타이밍 충돌

**설명**: 이자는 `start_prep_phase()`에서 계산되지만, 홀덤 이벤트는 `start_combat_phase()` 전에 활성화된다. 이자를 전투 결과 기반으로 받는다면 `double_interest` 효과가 prep 페이즈에서 사전 적용되어야 함.

**완화 방안**: `start_prep_phase()`에서 `holdem_state.active_events` 를 확인하여 `double_interest` 이벤트가 있으면 `calc_interest()` 반환값을 ×2 처리. 이벤트 활성화는 라운드 시작 시 advance() 호출로 pre-set.

### R5: 판타지랜드 13장 드로우 구현 복잡도

**설명**: 판타지랜드 진입 시 다음 라운드 공유 풀에서 13장 드로우 후 필요 카드 선택하고 나머지 반환하는 로직은 CLI 인터렉션이 필요.

**완화 방안 (Alpha 범위 제한)**:
- Alpha에서는 `in_fantasyland = True` 플래그 설정 + `check_fantasyland()` 판정까지만 구현
- 13장 드로우 및 반환 인터랙션은 STANDARD 단계로 이연
- 판타지랜드 플래그의 Foul 면제 효과는 Alpha에서 `check_foul()` 호출 전 `in_fantasyland` 확인으로 적용

### R6: 3인 바이 플레이어의 매칭 공정성

**설명**: 3인 중 바이를 받는 플레이어가 매 라운드 다른 플레이어여야 공정하지만, 순수 랜덤이면 편향 발생 가능.

**완화 방안**: `match_history`에서 바이 횟수도 추적하여 가장 적게 바이를 받은 플레이어에게 바이 부여. `_pick_pairs_avoid_repeat()` 내부에서 처리.

---

## 6. 완료 기준

### 6.1 기능 완료 체크리스트

```
A1 — 상점 레벨별 드롭률:
[ ] _LEVEL_WEIGHTS 값이 PRD §10.6 테이블과 100% 일치 확인
[ ] level=9 플레이어 드로우 1000회 → 5코스트 카드 비율 20~30% 범위
[ ] level=1 플레이어 드로우 → 4코스트/5코스트 카드 0건

A2 — 증강체 Silver:
[ ] SILVER_AUGMENTS 3종 정의 및 ID 확인
[ ] economist 보유 시 이자 상한 6골드
[ ] suit_mystery 보유 시 count_synergies +1 (상한 4)
[ ] lucky_shop 보유 시 상점 드로우 6장
[ ] 라운드 2-4 종료 시 증강체 선택 페이즈 진행

A3 — 홀덤 이벤트:
[ ] PILOT_EVENTS 5종 정의 및 phase 분포 확인
[ ] Flop 3장 → Turn +1 → River +1 순서 공개
[ ] foul_amnesty 활성 시 Foul 패널티 미적용 전투 결과 확인
[ ] scoop_bonus 활성 시 스쿠프 피해 총 +6 (기존 +2 → +6)
[ ] CLI에서 활성 이벤트 목록 출력 확인

A4 — 스톱 + 판타지랜드:
[ ] Front QQ 달성 → check_fantasyland() == True
[ ] Front JJ 달성 → check_fantasyland() == False
[ ] 스톱 조건 충족 시 damage × 8 적용 (훌라 ×4 대체)
[ ] stop_applied=True 일 때 hula_applied=True 중첩 배율 없음
[ ] in_fantasyland 플래그 갱신 (라운드 종료 시 fantasyland_next → in_fantasyland)

A5 — 다인 매칭:
[ ] 3인 매칭 → 2쌍 전투 + 1명 바이
[ ] 4인 매칭 → 2쌍 동시 전투
[ ] match_history 기반 같은 상대 3연속 방지
[ ] HP 0 플레이어 즉시 제거 및 생존자만 다음 라운드 진행
```

### 6.2 테스트 통과 기준

```
pytest tests/ -v → 234개+ 전체 PASS (기존 176개 + 신규 58개+)
ruff check src/ --fix → PASS (린트 오류 0건)
python cli/main.py --auto → 4인 1게임 크래시 없이 완료
```

### 6.3 신규 테스트 파일별 최소 케이스

| 파일 | 신규 추가 | 최소 기준 |
|------|---------|---------|
| `tests/test_card.py` | 드롭률 검증 | 10개+ |
| `tests/test_augment.py` | 증강체 전체 | 15개+ |
| `tests/test_holdem.py` | 홀덤 이벤트 전체 | 15개+ |
| `tests/test_combat.py` | 스톱 선언 | 5개+ |
| `tests/test_board.py` | 판타지랜드 판정 | 5개+ |
| `tests/test_game.py` | 다인 매칭 | 8개+ |
| **합계** | | **58개+** |

### 6.4 커밋 전략

```
Conventional Commit 형식:

Phase Alpha-1:
  feat(board): check_fantasyland() 함수 추가
  feat(combat): CombatResult.stop_applied 필드 + 스톱 판정 로직
  feat(economy): Player 판타지랜드 필드 추가
  test(board): 판타지랜드 판정 5개 테스트
  test(combat): 스톱 선언 5개 테스트
  test(card): 레벨별 드롭률 10개 테스트

Phase Alpha-2:
  feat(augment): Augment dataclass + SILVER_AUGMENTS 3종
  feat(economy): Player.augments 통합 + calc_interest economist 보정
  feat(combat): count_synergies suit_mystery 보정 + resolve events 파라미터
  feat(holdem): HoldemEvent + HoldemState + PILOT_EVENTS 5종
  feat(game): GameState.holdem_state 통합 + 증강체 선택 페이즈
  test(augment): 증강체 15개 테스트
  test(holdem): 홀덤 이벤트 15개 테스트

Phase Alpha-3:
  feat(game): generate_matchups() 3~4인 지원 + match_history
  feat(cli): 플레이어 수 선택 + 다인 전투 루프
  test(game): 다인 매칭 8개 테스트
  test: 전체 통합 234개+ PASS 확인
```
