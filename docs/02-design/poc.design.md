# Trump Card Auto Chess — POC 기술 설계 문서

**버전**: 1.0.0
**작성일**: 2026-02-19
**기반**: PRD v4.0 + poc.plan.md v1.0
**목적**: POC 구현을 위한 기술 설계 확정

---

## 1. 아키텍처 개요

### 1.1 시스템 구성도

```
  +--------------------------------------------------------------+
  |                     POC 시스템 (Python 3.11+)               |
  |                                                              |
  |  +------------------+     +-----------------------------+   |
  |  |   CLI Layer      |     |       Test Layer            |   |
  |  |  cli/main.py     |     |  tests/test_*.py (pytest)   |   |
  |  +--------+---------+     +-------------+---------------+   |
  |           |                             |                   |
  |           v                             v                   |
  |  +------------------------------------------------------+   |
  |  |                  Game Engine Layer                   |   |
  |  |  game.py — GameState / RoundManager                 |   |
  |  |  combat.py — CombatResolver / HP / Hula             |   |
  |  +--+----------------+----------------+----------------+   |
  |     |                |                |                    |
  |     v                v                v                    |
  |  +--------+    +----------+    +-----------+              |
  |  |Domain  |    |Domain    |    |Domain     |              |
  |  |card.py |    |hand.py   |    |board.py   |              |
  |  |pool.py |    |(핸드판정) |    |(OFC+Foul) |              |
  |  +--------+    +----------+    +-----------+              |
  |     |                                                      |
  |     v                                                      |
  |  +----------+                                              |
  |  |economy.py|                                              |
  |  |(골드/이자)|                                              |
  |  +----------+                                              |
  +--------------------------------------------------------------+
```

### 1.2 레이어 구조

| 레이어 | 모듈 | 역할 |
|--------|------|------|
| **CLI** | `cli/main.py` | 사용자 입출력, 게임 진행 루프 |
| **Game Engine** | `game.py`, `combat.py` | 라운드 관리, 전투 판정, 상태 전환 |
| **Domain** | `card.py`, `hand.py`, `board.py`, `economy.py`, `pool.py` | 순수 게임 규칙 구현 |
| **Test** | `tests/test_*.py` | TDD 단위/통합 테스트 |

### 1.3 디렉토리 구조

```
  C:\claude\card_ofc\
  ├── src\
  │   ├── __init__.py
  │   ├── card.py          # Card, Rank, Suit Enum
  │   ├── pool.py          # SharedCardPool (2인 공유 풀)
  │   ├── hand.py          # PokerHand 판정, HandType Enum, 타이브레이커
  │   ├── board.py         # OFCBoard, Foul 판정, 경고
  │   ├── economy.py       # Gold, Interest, Shop, StarUpgrade
  │   ├── combat.py        # CombatResolver, HP 피해, Hula 선언
  │   └── game.py          # GameState, RoundManager
  ├── tests\
  │   ├── __init__.py
  │   ├── test_card.py     # Card/Deck/Pool 단위 테스트
  │   ├── test_hand.py     # 핸드 판정 100케이스
  │   ├── test_board.py    # OFC Foul 판정 20케이스
  │   ├── test_economy.py  # 이자/골드 계산 테스트
  │   ├── test_combat.py   # 전투 + 훌라 배수 테스트
  │   └── test_game.py     # 5라운드 통합 시뮬레이션
  ├── cli\
  │   ├── __init__.py
  │   └── main.py          # 2인 로컬 대전 진입점
  ├── docs\
  │   ├── 01-plan\
  │   │   ├── card-autochess.prd.md
  │   │   └── poc.plan.md
  │   └── 02-design\
  │       └── poc.design.md  (이 문서)
  ├── pyproject.toml
  └── CLAUDE.md
```

## 2. 핵심 도메인 모델

### 2.1 Card

```python
from enum import IntEnum
from dataclasses import dataclass, field

class Rank(IntEnum):
    TWO = 2; THREE = 3; FOUR = 4; FIVE = 5; SIX = 6
    SEVEN = 7; EIGHT = 8; NINE = 9; TEN = 10
    JACK = 11; QUEEN = 12; KING = 13; ACE = 14

class Suit(IntEnum):
    # 순환 우위: SPADE > HEART > DIAMOND > CLUB > SPADE
    CLUB = 1; DIAMOND = 2; HEART = 3; SPADE = 4

@dataclass
class Card:
    rank: Rank
    suit: Suit
    stars: int = 1          # 1성(기본) / 2성 / 3성

    @property
    def is_enhanced(self) -> bool:
        return self.stars > 1

    @property
    def cost(self) -> int:
        # Common=1, Rare=2, Epic=3, Legendary=4, Mythic=5
        if self.rank <= 5:   return 1
        if self.rank <= 8:   return 2
        if self.rank <= 11:  return 3
        if self.rank <= 13:  return 4
        return 5             # Ace

    def beats_suit(self, other: 'Card') -> bool:
        """수트 순환 우위: SPADE>HEART>DIAMOND>CLUB>SPADE"""
        # 순환 테이블: suit.beats = (suit.value % 4) + 1
        return (self.suit.value % 4) + 1 == other.suit.value

    def __repr__(self) -> str:
        star_str = "*" * self.stars
        return f"{self.rank.name[:1]}{self.suit.name[:1]}{star_str}"
```

### 2.2 SharedCardPool

```python
@dataclass
class SharedCardPool:
    # 공유 풀 복사본 수 (PRD §4.5.1 기준, POC 간소화)
    COPIES: ClassVar[dict] = {
        range(2, 6): 29,   # Common (2~5)
        range(6, 9): 22,   # Rare (6~8)
        range(9, 12): 18,  # Epic (9~J)
        range(12, 14): 12, # Legendary (Q~K)
        range(14, 15): 10  # Mythic (A)
    }
    _pool: dict[tuple[Rank, Suit], int] = field(default_factory=dict)

    def initialize(self) -> None:
        """52종 × 등급별 복사본 수로 초기화"""

    def draw(self, rank: Rank, suit: Suit) -> bool:
        """풀에서 카드 1장 차감. 실패 시 False"""

    def return_card(self, card: Card) -> None:
        """매각 시 풀에 반환 (1장만)"""

    def remaining(self, rank: Rank, suit: Suit) -> int:
        """특정 카드 잔여 수 반환"""

    def random_draw_n(self, n: int, level: int) -> list[Card]:
        """레벨 기반 등급 확률로 n장 무작위 드로우"""
```

### 2.3 Hand

```python
from enum import IntEnum

class HandType(IntEnum):
    HIGH_CARD       = 1
    ONE_PAIR        = 2
    TWO_PAIR        = 3
    THREE_OF_A_KIND = 4
    STRAIGHT        = 5
    FLUSH           = 6
    FULL_HOUSE      = 7
    FOUR_OF_A_KIND  = 8
    STRAIGHT_FLUSH  = 9
    ROYAL_FLUSH     = 10

@dataclass
class HandResult:
    hand_type: HandType
    cards: list[Card]        # 판정에 사용된 카드 목록
    enhanced_count: int      # 2성+3성 카드 수 (타이브레이커 2단계)
    dominant_suit: Suit      # 기준 수트 (타이브레이커 3단계)
    high_card_rank: Rank     # 최고 랭크 (최종 동률 해소)

def evaluate_hand(cards: list[Card]) -> HandResult:
    """카드 목록에서 최강 포커 핸드 판정"""

def compare_hands(h1: HandResult, h2: HandResult) -> int:
    """
    +1: h1 승, -1: h2 승, 0: 무승부
    타이브레이커 3단계 적용:
      1. hand_type 비교
      2. enhanced_count 비교
      3. 수트 순환 우위 비교
    """
```

### 2.4 OFCBoard

```python
@dataclass
class OFCBoard:
    front: list[Card] = field(default_factory=list)  # 최대 3칸
    mid:   list[Card] = field(default_factory=list)  # 최대 5칸
    back:  list[Card] = field(default_factory=list)  # 최대 5칸

    def place_card(self, line: str, card: Card) -> bool:
        """카드 배치. 슬롯 초과 시 False"""

    def remove_card(self, line: str, card: Card) -> bool:
        """카드 제거"""

    def is_full(self) -> bool:
        """front=3, mid=5, back=5 모두 채워졌는지"""

    def check_foul(self) -> 'FoulResult':
        """Back ≥ Mid ≥ Front 핸드 강도 위반 감지"""

    def get_foul_warning(self) -> list[str]:
        """현재 배치 기준 폴 위험 경고 문자열 반환"""

    def get_hand_results(self) -> dict[str, HandResult]:
        """front/mid/back 각 라인 핸드 판정 결과 반환"""

@dataclass
class FoulResult:
    has_foul: bool
    foul_lines: list[str]    # 폴 발생 라인 목록 ('front', 'mid', 'back')
```

### 2.5 Player

```python
@dataclass
class Player:
    name: str
    hp: int = 100
    gold: int = 0
    level: int = 1
    xp: int = 0
    board: OFCBoard = field(default_factory=OFCBoard)
    bench: list[Card] = field(default_factory=list)   # 최대 9칸
    win_streak: int = 0
    loss_streak: int = 0

    def round_income(self, base: int = 5) -> int:
        """라운드 수입: 기본 + 이자 + 연승/연패 보너스"""

    def calc_interest(self) -> int:
        """이자 = min(floor(gold / 10), 5)"""

    def streak_bonus(self) -> int:
        """연승/연패 보너스 계산"""

    def can_buy(self, card: Card) -> bool:
        """골드 충분 여부 확인"""

    def buy_card(self, card: Card, pool: SharedCardPool) -> bool:
        """카드 구매: 골드 차감 + 벤치 추가"""

    def sell_card(self, card: Card, pool: SharedCardPool) -> int:
        """카드 매각: 골드 반환 + 풀 반환"""

    def try_star_upgrade(self) -> 'Card | None':
        """같은 카드(랭크+수트) 3장 → 2성 합성 시도"""
```

### 2.6 GameState

```python
@dataclass
class GameState:
    players: list[Player]
    pool: SharedCardPool
    round_num: int = 1
    phase: str = 'prep'     # 'prep' | 'combat' | 'result' | 'end'
    max_rounds: int = 5     # POC: 5라운드

    def is_game_over(self) -> bool:
        """HP ≤ 0이거나 max_rounds 초과 여부"""

    def get_winner(self) -> 'Player | None':
        """현재 HP 기준 승자 반환. 진행 중이면 None"""
```

### 2.7 CombatResolver

```python
@dataclass
class CombatResult:
    line_results: dict[str, int]  # {'back': 1, 'mid': -1, 'front': 0}
    winner_lines: int             # 승자 라인 수 (1~3)
    is_scoop: bool                # 3:0 전승 여부
    damage: int                   # 기본 HP 피해
    hula_applied: bool            # 훌라 배수 적용 여부

class CombatResolver:
    def resolve(
        self,
        board_a: OFCBoard,
        board_b: OFCBoard,
        hula_a: bool = False,
        hula_b: bool = False
    ) -> tuple[CombatResult, CombatResult]:
        """3라인 비교 → CombatResult 쌍 반환"""

    def calc_damage(
        self, result: CombatResult, stage_damage: int = 2
    ) -> int:
        """기본: 이긴라인수 × stage_damage + 스쿠프 +2"""

    def apply_hula(self, damage: int) -> int:
        """훌라 성공 시 damage × 4"""
```

## 3. 포커 핸드 판정 알고리즘

### 3.1 핸드 강도 테이블

| 강도 순위 | HandType | 조건 | 핸드 강도 점수 |
|----------|----------|------|------------|
| 10 | ROYAL_FLUSH | 같은 수트 10-J-Q-K-A | 10 |
| 9 | STRAIGHT_FLUSH | 같은 수트 연속 5장 | 9 |
| 8 | FOUR_OF_A_KIND | 같은 랭크 4장 | 8 |
| 7 | FULL_HOUSE | 스리카인드 + 원페어 | 7 |
| 6 | FLUSH | 같은 수트 5장 | 6 |
| 5 | STRAIGHT | 연속 랭크 5장 | 5 |
| 4 | THREE_OF_A_KIND | 같은 랭크 3장 | 4 |
| 3 | TWO_PAIR | 다른 랭크 페어 2쌍 | 3 |
| 2 | ONE_PAIR | 같은 랭크 2장 | 2 |
| 1 | HIGH_CARD | 그 외 | 1 |

**Front 라인(3장) 주의사항**:
- 스트레이트/플러시/풀하우스/포카인드/스트레이트 플러시/로열 플러시 불가
- 최강: 스리카인드 (같은 랭크 3장)
- 최다: 원페어 / 하이카드

### 3.2 판정 알고리즘 (evaluate_hand)

```
evaluate_hand(cards: list[Card]) -> HandResult:

  n = len(cards)  # front=3, mid/back=5

  Step 1: 랭크/수트 빈도 계산
    rank_counts = Counter(card.rank for card in cards)
    suit_counts = Counter(card.suit for card in cards)
    ranks_sorted = sorted(rank_counts.keys(), reverse=True)

  Step 2: 핸드 탐지 (우선순위 순서)
    is_flush  = max(suit_counts.values()) >= 5 and n == 5
    is_straight = (len(rank_counts) == 5) and
                  (max(ranks) - min(ranks) == 4) and n == 5
    # A-2-3-4-5 로우 스트레이트 별도 처리

    if is_flush and is_straight:
      if min(ranks) == 10: return ROYAL_FLUSH
      else:                return STRAIGHT_FLUSH
    if 4 in rank_counts.values(): return FOUR_OF_A_KIND
    if 3 in rank_counts.values() and 2 in rank_counts.values():
      return FULL_HOUSE
    if is_flush:           return FLUSH
    if is_straight:        return STRAIGHT
    if 3 in rank_counts.values(): return THREE_OF_A_KIND
    if list(rank_counts.values()).count(2) == 2: return TWO_PAIR
    if 2 in rank_counts.values(): return ONE_PAIR
    return HIGH_CARD

  Step 3: dominant_suit 계산
    가장 많이 보유한 수트
    동수 시: 더 높은 랭크 카드가 속한 수트

  Step 4: HandResult 반환
```

### 3.3 타이브레이커 3단계

```
compare_hands(h1: HandResult, h2: HandResult) -> int:

  [1단계] 핸드 강도(HandType) 비교
    if h1.hand_type != h2.hand_type:
      return +1 if h1.hand_type > h2.hand_type else -1

  [2단계] 강화 카드 수(enhanced_count) 비교
    if h1.enhanced_count != h2.enhanced_count:
      return +1 if h1.enhanced_count > h2.enhanced_count else -1

  [3단계] 수트 순환 우위(dominant_suit) 비교
    s1, s2 = h1.dominant_suit, h2.dominant_suit
    if s1 == s2:
      # 동일 수트 → 최고 랭크 비교
      return +1 if h1.high_card_rank > h2.high_card_rank else -1
    if s1이 s2를 이기면: return +1
    if s2가 s1을 이기면: return -1

  return 0  # 완전 무승부 (드물게 발생)
```

### 3.4 수트 순환 우위 판정 로직

```
수트 순환 테이블 (이기는 방향):
  SPADE(4) → HEART(3) → DIAMOND(2) → CLUB(1) → SPADE(4)

beats(attacker: Suit, defender: Suit) -> bool:
  # 순환 공식: attacker.value % 4 + 1 == defender.value
  return (attacker.value % 4) + 1 == defender.value

혼합 수트 dominant_suit 결정:
  1. suit_counts.most_common(1)[0][0] → 가장 많은 수트
  2. 동수 시: max(cards where suit == tied_suit, key=lambda c: c.rank).suit
```

### 3.5 핵심 엣지 케이스 목록

| EC | 상황 | 처리 방법 |
|----|------|---------|
| EC1 | Front(3장)에서 스트레이트 시도 (A-2-3) | 3장 핸드는 스트레이트 불가 → ONE_PAIR 또는 HIGH_CARD로 판정 |
| EC2 | A-2-3-4-5 로우 스트레이트 | ranks = {14,2,3,4,5} → A를 1로 재해석 후 STRAIGHT 판정 |
| EC3 | 같은 핸드 + 같은 enhanced_count + 같은 dominant_suit | high_card_rank 비교 → 여전히 동점이면 0 반환 (무승부) |
| EC4 | 혼합 수트 풀하우스에서 dominant_suit 결정 | 스리카인드 파트의 수트를 dominant_suit로 강제 지정 |
| EC5 | 2성 카드가 있는 원페어 vs 1성 카드 원페어 | enhanced_count로 2단계에서 해소 |
| EC6 | SPADE vs CLUB 수트 충돌 | CLUB.value % 4 + 1 = 2 ≠ SPADE(4) → CLUB이 SPADE를 이김 |
| EC7 | Front 라인 1장만 배치 시 Foul 판정 | 빈 슬롯은 HIGH_CARD 0으로 처리, 경고 표시 |
| EC8 | 포카인드(5장 중 4장 동일) vs 스트레이트 플러시 | HandType 비교로 즉시 해소 (SF=9 > 4K=8) |

## 4. OFC 3라인 배치 시스템

### 4.1 Foul 판정 로직

**필수 조건**: Back 핸드 강도 ≥ Mid 핸드 강도 ≥ Front 핸드 강도

```
check_foul(board: OFCBoard) -> FoulResult:

  back_hand  = evaluate_hand(board.back)
  mid_hand   = evaluate_hand(board.mid)
  front_hand = evaluate_hand(board.front)

  foul_lines = []

  if back_hand.hand_type < mid_hand.hand_type:
    foul_lines.append('back')   # Back < Mid 위반

  if mid_hand.hand_type < front_hand.hand_type:
    foul_lines.append('mid')    # Mid < Front 위반

  return FoulResult(
    has_foul = len(foul_lines) > 0,
    foul_lines = foul_lines
  )
```

### 4.2 배치 순서 및 강도 비교 방법

```
  라인 강도 비교 흐름:

  [Back 핸드 판정]──────[Mid 핸드 판정]──────[Front 핸드 판정]
         |                     |                      |
         v                     v                      v
  evaluate_hand()        evaluate_hand()        evaluate_hand()
  (5장 기준)             (5장 기준)              (3장 기준)
         |                     |                      |
         +─────────────────────+──────────────────────+
                               |
                               v
                   Back.hand_type >= Mid.hand_type
                   Mid.hand_type >= Front.hand_type
                               |
                    YES ─── 정상 배치
                    NO  ─── Foul 감지 → 패널티 라인 기록
```

### 4.3 Foul 패널티 처리

```
apply_foul_penalty(hand: HandResult) -> HandResult:
  """폴 발생 라인의 핸드 강도를 -1등급 강등"""

  new_type = HandType(max(1, hand.hand_type.value - 1))
  return HandResult(
    hand_type = new_type,
    cards = hand.cards,
    enhanced_count = hand.enhanced_count,
    dominant_suit = hand.dominant_suit,
    high_card_rank = hand.high_card_rank
  )
```

**패널티 예시**:

| 폴 발생 전 핸드 | 패널티 후 핸드 |
|---------------|-------------|
| FLUSH (6) | STRAIGHT (5) |
| STRAIGHT (5) | THREE_OF_A_KIND (4) |
| HIGH_CARD (1) | HIGH_CARD (1) — 최하 유지 |

### 4.4 실시간 폴 경고

```
get_foul_warning(board: OFCBoard) -> list[str]:
  """
  배치 진행 중에도 현재 상태에서 폴 위험을 감지.
  빈 슬롯 = HIGH_CARD(0)으로 처리하여 보수적 경고.
  """
  warnings = []

  back_h  = evaluate_hand(board.back)  if board.back  else HandType(0)
  mid_h   = evaluate_hand(board.mid)   if board.mid   else HandType(0)
  front_h = evaluate_hand(board.front) if board.front else HandType(0)

  if back_h < mid_h:
    warnings.append("경고: Back 라인이 Mid보다 약합니다 (Foul 위험)")
  if mid_h < front_h:
    warnings.append("경고: Mid 라인이 Front보다 약합니다 (Foul 위험)")

  if len(board.front) < 3:
    warnings.append("알림: Front 라인 미완성 (배치 전 반드시 확인)")

  return warnings
```

## 5. 경제 시스템 설계

### 5.1 골드 계산 수식

```
라운드 총 수입 = 기본 수입(5) + 이자 수입 + 연승/연패 보너스

이자 수입 = min(floor(보유_골드 / 10), 5)

연승/연패 보너스:
  streak == 2: +1
  streak == 3: +1 (누적 +2)
  streak >= 5: +3 (상한)
```

### 5.2 이자 계산 테이블

| 보유 골드 | 이자 수입 | 합산 최소 수입 |
|---------|---------|------------|
| 0~9골드  | 0 | 5 |
| 10~19골드 | +1 | 6 |
| 20~29골드 | +2 | 7 |
| 30~39골드 | +3 | 8 |
| 40~49골드 | +4 | 9 |
| 50골드+  | +5 (최대) | 10 |

### 5.3 라운드 수입 흐름

```
  라운드 시작
       |
       v
  +----+--------------------+
  |  기본 수입: +5 골드      |
  +----+--------------------+
       |
       v
  +----+--------------------+
  |  이자 계산               |
  |  interest = min(        |
  |    floor(gold / 10), 5) |
  |  gold += interest       |
  +----+--------------------+
       |
       v
  +----+--------------------+
  |  연승/연패 보너스         |
  |  streak_bonus = 0       |
  |  if streak == 2: +1     |
  |  if streak == 3: +1     |
  |  if streak >= 5: +3     |
  |  (연승/연패 중 해당 적용) |
  +----+--------------------+
       |
       v
  +----+--------------------+
  |  준비 페이즈 시작         |
  |  플레이어 행동 (구매/배치) |
  +----+--------------------+
       |
       v
  +----+--------------------+
  |  전투 페이즈              |
  |  승패 결과 → streak 갱신  |
  +------------------------+
```

### 5.4 별 강화(Star Upgrade) 트리거 조건

```
try_star_upgrade(player: Player) -> Card | None:

  # 같은 카드(랭크 + 수트 동일) 3장이 벤치에 있으면 자동 합성 시도
  card_counts = Counter((c.rank, c.suit, c.stars) for c in player.bench)

  for (rank, suit, stars), count in card_counts.items():
    if count >= 3 and stars < 3:
      # 3장 제거 → 1장 (stars+1) 생성
      remove 3 cards from bench where rank==rank, suit==suit, stars==stars
      new_card = Card(rank=rank, suit=suit, stars=stars+1)
      player.bench.append(new_card)
      # 풀 반환 없음 (PRD §4.5.3)
      return new_card

  return None

조건 요약:
  1성 × 3 → 2성 (랭크+수트 동일)
  2성 × 3 → 3성 (동일 조건, 최대)
  3성은 더 이상 합성 불가
```

### 5.5 상점 드롭 확률 (레벨별)

```
  +-------+--------+--------+--------+--------+--------+
  | 레벨  | 1코스트 | 2코스트 | 3코스트 | 4코스트 | 5코스트 |
  +-------+--------+--------+--------+--------+--------+
  | 1     | 100%   | 0%     | 0%     | 0%     | 0%     |
  | 2     | 70%    | 30%    | 0%     | 0%     | 0%     |
  | 3     | 60%    | 35%    | 5%     | 0%     | 0%     |
  | 4     | 50%    | 35%    | 15%    | 0%     | 0%     |
  | 5     | 40%    | 35%    | 20%    | 5%     | 0%     |
  | 6     | 30%    | 35%    | 25%    | 10%    | 0%     |
  | 7     | 20%    | 30%    | 30%    | 15%    | 5%     |
  | 8     | 15%    | 25%    | 30%    | 20%    | 10%    |
  | 9     | 10%    | 20%    | 25%    | 25%    | 20%    |
  +-------+--------+--------+--------+--------+--------+
```

## 6. 게임 루프 시퀀스

### 6.1 전체 라운드 진행 시퀀스

```
  GameState        RoundManager      Player A          Player B
      |                  |               |                  |
      |--start_round()--->|               |                  |
      |                  |--income()----->|                  |
      |                  |--income()----->|                  |  (동시)
      |                  |               |                  |
      |                  |               |<--[준비 페이즈]-->|
      |                  |               |  구매/배치/합성   |
      |                  |               |  (35초 또는 입력)|
      |                  |               |                  |
      |                  |<--ready()-----|                  |
      |                  |<--ready()-----|------------------|
      |                  |               |                  |
      |                  |--check_foul()->|                  |
      |                  |--check_foul()->|                  |
      |                  |               |                  |
      |                  |--resolve_combat(A.board, B.board) |
      |                  |               |                  |
      |                  |--apply_damage->|                  |
      |                  |--apply_damage->|                  |
      |                  |               |                  |
      |                  |--update_streak|                  |
      |<--round_result()--|               |                  |
      |                  |               |                  |
      |--is_game_over()? |               |                  |
      |  YES: end_game() |               |                  |
      |  NO:  next_round()|              |                  |
```

### 6.2 전투 판정 흐름

```
  resolve_combat(board_a, board_b):

  1. Foul 적용
     +-- check_foul(board_a) → foul_a
     +-- check_foul(board_b) → foul_b
     +-- 폴 발생 라인에 apply_foul_penalty()

  2. 3라인 핸드 판정
     back_result  = compare_hands(
       board_a.get_hand('back'),
       board_b.get_hand('back')
     )
     mid_result   = compare_hands(...)
     front_result = compare_hands(...)

  3. 승자 집계
     wins_a = [+1 결과 수], wins_b = [−1 결과 수]
     scoop_a = (wins_a == 3), scoop_b = (wins_b == 3)

  4. 피해 계산
     damage_a = wins_a × 2 + (2 if scoop_a else 0)
     damage_b = wins_b × 2 + (2 if scoop_b else 0)

     if hula_a: damage_a *= 4
     if hula_b: damage_b *= 4

  5. HP 적용
     player_b.hp -= damage_a
     player_a.hp -= damage_b
```

### 6.3 훌라(×4) 선언 조건 및 처리

```
  훌라 선언 가능 조건 (POC 간소화):
    배치된 카드 중 같은 수트 2장 이상이 되는 수트가 3종류 이상 활성화
    → count_synergies(board) >= 3

  count_synergies(board: OFCBoard) -> int:
    all_cards = board.back + board.mid + board.front
    suit_counts = Counter(c.suit for c in all_cards)
    # 2장 이상인 수트 수 = 활성 시너지 수
    return sum(1 for cnt in suit_counts.values() if cnt >= 2)

  declare_hula(player, board) -> bool:
    if count_synergies(board) >= 3:
      player.hula_declared = True
      return True
    return False  # 조건 미충족 → 선언 불가, 패널티 없음
    # (조건 충족 후 선언 시도만 허용)

  훌라 실패 패널티:
    # 선언했으나 전투 결과 패배 시 → 별도 패널티 없음 (POC 단순화)
    # Full Dev에서는 OFC 로열티 -25% 적용
```

## 7. TDD 테스트 설계

### 7.1 테스트 파일 구조 (pytest)

```
  tests/
  ├── __init__.py
  ├── test_card.py       # Card, Rank, Suit, SharedCardPool
  ├── test_hand.py       # 핸드 판정 100케이스 + 타이브레이커
  ├── test_board.py      # OFCBoard, Foul 판정 20케이스
  ├── test_economy.py    # 골드/이자/연승연패/별강화
  ├── test_combat.py     # CombatResolver, HP, 훌라
  └── test_game.py       # 5라운드 통합 시뮬레이션
```

### 7.2 핵심 테스트 케이스 목록

#### test_card.py

| 테스트 함수 | 검증 내용 |
|------------|---------|
| `test_rank_order` | 2 < 3 < ... < A 순서 정렬 확인 |
| `test_suit_beats` | SPADE→HEART, HEART→DIAMOND, DIAMOND→CLUB, CLUB→SPADE 4가지 |
| `test_card_cost` | Rank별 cost 반환 값 확인 |
| `test_pool_initialize` | 52종 × 등급별 복사본 수 총합 정확 |
| `test_pool_draw_and_deplete` | 특정 카드를 복사본 수만큼 드로우 후 0 확인 |
| `test_pool_return_card` | 매각 시 풀에 1장 반환 |
| `test_card_is_enhanced` | stars=1 → False, stars=2 → True |

#### test_hand.py (100케이스)

| 테스트 함수 | 검증 내용 |
|------------|---------|
| `test_royal_flush` | 10-J-Q-K-A 동수트 → ROYAL_FLUSH |
| `test_straight_flush` | 4-5-6-7-8 동수트 → STRAIGHT_FLUSH |
| `test_four_of_a_kind` | 동일 랭크 4장 → FOUR_OF_A_KIND |
| `test_full_house` | 3+2 조합 → FULL_HOUSE |
| `test_flush` | 5장 동수트 비연속 → FLUSH |
| `test_straight` | A-2-3-4-5 (로우) → STRAIGHT |
| `test_straight_ace_high` | 10-J-Q-K-A → STRAIGHT (Royal 아닌 경우) |
| `test_three_of_a_kind` | 동일 랭크 3장 → THREE_OF_A_KIND |
| `test_two_pair` | 2가지 페어 → TWO_PAIR |
| `test_one_pair` | 1가지 페어 → ONE_PAIR |
| `test_high_card` | 패턴 없음 → HIGH_CARD |
| `test_front_3cards_no_straight` | 3장 A-2-3 → ONE_PAIR 또는 HIGH_CARD |
| `test_tiebreaker_hand_type` | FLUSH vs STRAIGHT → FLUSH 승 |
| `test_tiebreaker_enhanced_count` | 같은 핸드, 2성 많은 쪽 승 |
| `test_tiebreaker_suit_cycle` | 같은 핸드+강화, SPADE vs HEART → SPADE 승 |
| `test_tiebreaker_suit_cycle_reverse` | CLUB vs SPADE → CLUB 승 |
| `test_mixed_suit_dominant` | 혼합 수트 dominant_suit 선택 |
| `test_same_suit_high_rank_wins` | 동일 dominant_suit → 고랭크 승 |
| `test_enhanced_count_calculation` | 2성+3성 카드 수 정확 집계 |
| `test_100_random_hands` | 100개 무작위 핸드 → 오판정 0 (smoke test) |

#### test_board.py (20케이스)

| 테스트 함수 | 검증 내용 |
|------------|---------|
| `test_valid_placement_back_gt_mid_gt_front` | Back>Mid>Front → Foul 없음 |
| `test_valid_placement_equal_hands` | Back=Mid=Front → Foul 없음 (동률 허용) |
| `test_foul_mid_stronger_than_back` | Mid > Back → Foul: back |
| `test_foul_front_stronger_than_mid` | Front > Mid → Foul: mid |
| `test_foul_penalty_degrades_one_level` | FLUSH → STRAIGHT (패널티 후) |
| `test_foul_penalty_minimum` | HIGH_CARD → HIGH_CARD 유지 |
| `test_foul_warning_partial_placement` | 미완성 배치에서 경고 반환 |
| `test_place_card_slot_limit` | front 4번째 배치 시 False |
| `test_place_duplicate_prevention` | 동일 카드 중복 배치 방지 |
| `test_get_hand_results_all_lines` | 3라인 모두 HandResult 반환 |

#### test_economy.py

| 테스트 함수 | 검증 내용 |
|------------|---------|
| `test_interest_0_gold` | 0골드 → 이자 0 |
| `test_interest_10_gold` | 10골드 → 이자 1 |
| `test_interest_50_gold` | 50골드 → 이자 5 (최대) |
| `test_interest_100_gold` | 100골드 → 이자 5 (상한 유지) |
| `test_streak_bonus_2` | 연승 2 → +1 |
| `test_streak_bonus_5` | 연승 5 → +3 |
| `test_round_income_total` | 10골드 보유, 연승 3 → 5+1+2=8 |
| `test_star_upgrade_1to2` | 같은 카드 3장 → 2성 |
| `test_star_upgrade_2to3` | 2성 3장 → 3성 |
| `test_star_upgrade_max` | 3성은 합성 불가 |
| `test_buy_card_success` | 충분한 골드 → 구매 성공, 골드 차감 |
| `test_buy_card_insufficient_gold` | 골드 부족 → 구매 실패 |
| `test_sell_card_returns_gold` | 매각 → 코스트만큼 골드 반환 |
| `test_sell_card_pool_return` | 1성 매각 → 풀 1장 반환 |

#### test_combat.py

| 테스트 함수 | 검증 내용 |
|------------|---------|
| `test_scoop_3_0` | 3라인 전승 → scoop=True, damage=8 |
| `test_split_2_1` | 2:1 승 → damage=4 |
| `test_split_1_2` | 1:2 패 → 상대 damage=4 |
| `test_draw_0_0` | 3라인 모두 동률 → damage=0 |
| `test_hula_multiplier_x4` | 훌라 선언 성공 → damage ×4 |
| `test_hula_requires_3_synergies` | 시너지 2개 → 훌라 선언 불가 |
| `test_foul_applied_before_combat` | 폴 패널티 적용 후 판정 |
| `test_hp_reduction` | combat 후 player.hp 감소 정확 |

#### test_game.py

| 테스트 함수 | 검증 내용 |
|------------|---------|
| `test_5_round_simulation_no_crash` | 5라운드 자동 완주 — 크래시 없음 |
| `test_game_over_hp_zero` | HP ≤ 0 즉시 종료 |
| `test_winner_by_hp` | 5라운드 후 HP 높은 쪽 승자 |
| `test_round_num_increments` | 라운드 번호 증가 확인 |

### 7.3 커버리지 달성 계획

```
  목표: 핵심 로직 ≥ 80% 커버리지

  +------------------+------------------+----------+
  | 모듈             | 예상 케이스 수    | 커버리지  |
  +------------------+------------------+----------+
  | card.py / pool.py| 7케이스          | ~90%     |
  | hand.py          | 20+80 = 100케이스| ~95%     |
  | board.py         | 20케이스         | ~90%     |
  | economy.py       | 14케이스         | ~85%     |
  | combat.py        | 8케이스          | ~85%     |
  | game.py          | 4케이스          | ~75%     |
  +------------------+------------------+----------+
  | 전체             | ~153케이스       | ≥80%     |
  +------------------+------------------+----------+

실행 명령:
  pytest tests/ -v --cov=src --cov-report=term-missing
```

## 8. 기술 스택 확정

| 레이어 | 기술 | 선택 이유 |
|--------|------|---------|
| **런타임** | Python 3.11+ | `match-case`, `StrEnum`, `tomllib` 내장. 게임 로직에 최적 |
| **도메인 모델** | `dataclasses` + `enum.IntEnum` | 외부 의존 없음. 빠른 프로토타이핑 |
| **테스트** | `pytest` | 단순 함수 테스트에 최적. 픽스처/파라미터화 강력 |
| **커버리지** | `pytest-cov` | 80% 기준 검증 필수 |
| **린트** | `ruff` | 속도 빠름, Black + flake8 대체, CI 통합 용이 |
| **UI** | CLI (`input()` + `print()`) | POC 즉시 검증 가능. FastAPI는 Should Have 이후 |
| **빌드 자동화** | `Makefile` | 단순 명령 단축. cross-platform 대안은 `just` |
| **패키지 설정** | `pyproject.toml` | PEP 517/518 표준. ruff 설정 통합 |

### pyproject.toml 구조

```toml
[project]
name = "card-ofc"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = []

[project.optional-dependencies]
dev = ["pytest>=7.0", "pytest-cov>=4.0", "ruff>=0.3"]

[tool.ruff]
line-length = 100
select = ["E", "F", "W", "I"]

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "-v --tb=short"
```

### Makefile 명령

```makefile
test:
	pytest tests/ -v --cov=src --cov-report=term-missing

test-hand:
	pytest tests/test_hand.py -v

lint:
	ruff check src/ tests/ --fix

clean:
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -name "*.pyc" -delete
```

## 9. 구현 파일 목록

| 파일 경로 | 역할 | 구현 Phase | 의존 모듈 |
|----------|------|-----------|---------|
| `src/__init__.py` | 패키지 초기화 | Phase 1 | - |
| `src/card.py` | `Card`, `Rank`, `Suit` Enum 정의 | Phase 1 | 없음 |
| `src/pool.py` | `SharedCardPool` — 52종×n장 공유 풀 | Phase 1 | `card.py` |
| `src/hand.py` | `HandType`, `HandResult`, `evaluate_hand`, `compare_hands` | Phase 1 | `card.py` |
| `src/board.py` | `OFCBoard`, `FoulResult`, `check_foul`, `get_foul_warning` | Phase 2 | `card.py`, `hand.py` |
| `src/economy.py` | `round_income`, `calc_interest`, `try_star_upgrade`, 상점 드로우 | Phase 3 | `card.py`, `pool.py` |
| `src/combat.py` | `CombatResult`, `CombatResolver`, `count_synergies`, `declare_hula` | Phase 4 | `board.py`, `hand.py` |
| `src/game.py` | `GameState`, `RoundManager` — 전체 루프 오케스트레이터 | Phase 4 | 모든 도메인 |
| `tests/__init__.py` | 테스트 패키지 초기화 | Phase 1 | - |
| `tests/test_card.py` | Card/Pool 단위 테스트 7케이스 | Phase 1 | `src/card.py`, `src/pool.py` |
| `tests/test_hand.py` | 핸드 판정 100케이스 | Phase 1 | `src/hand.py` |
| `tests/test_board.py` | OFC Foul 판정 20케이스 | Phase 2 | `src/board.py` |
| `tests/test_economy.py` | 경제 시스템 14케이스 | Phase 3 | `src/economy.py` |
| `tests/test_combat.py` | 전투+훌라 8케이스 | Phase 4 | `src/combat.py` |
| `tests/test_game.py` | 5라운드 통합 4케이스 | Phase 5 | `src/game.py` |
| `cli/__init__.py` | CLI 패키지 초기화 | Phase 5 | - |
| `cli/main.py` | 2인 로컬 대전 진입점 — `run_poc_game()` | Phase 5 | `src/game.py` |
| `pyproject.toml` | 패키지/린트/테스트 설정 | Phase 1 | - |
| `Makefile` | 빌드 자동화 단축 명령 | Phase 1 | - |

**신규 생성 총 파일 수**: 19개
**수정 예정**: `CLAUDE.md` (빌드/테스트 명령 갱신, Phase 5 완료 후)

## 10. 위험 요소 및 완화 방안

| # | 위험 요소 | 설명 | 완화 방안 |
|---|---------|------|---------|
| R1 | **포커 핸드 판정 엣지 케이스** | 로우 스트레이트(A-2-3-4-5), 혼합 수트 dominant_suit 결정, 3장 제약 핸드 판정의 엣지 케이스가 복잡 | TDD 100케이스 선행 작성 (test_hand.py) — 모든 엣지 케이스를 Red 단계에서 명세화 후 구현 |
| R2 | **OFC Foul 판정 타이밍** | 준비 페이즈 중 실시간으로 폴 경고를 표시해야 하는 UI-로직 연동 복잡성 | `get_foul_warning()`을 순수 함수로 분리. 배치 시마다 호출하여 CLI 즉시 출력. 상태 저장 없이 stateless 처리 |
| R3 | **수트 순환 우위 순환 참조** | ♣ > ♠ 조건이 직관적이지 않아 구현 시 방향 오류 발생 가능 | `beats(attacker, defender): (attacker.value % 4) + 1 == defender.value` 공식 1줄로 고정. 별도 테이블 금지 |

---

## 부록: 핸드 강도 빠른 참조

```
  약 ──────────────────────────────────────────────── 강

  HC  OP  TP  3K  ST  FL  FH  4K  SF  RF
   1   2   3   4   5   6   7   8   9  10

  HC = High Card     OP = One Pair      TP = Two Pair
  3K = Three of a Kind  ST = Straight   FL = Flush
  FH = Full House    4K = Four of a Kind
  SF = Straight Flush    RF = Royal Flush

  Front(3장) 최강 핸드: 3K (스리카인드)
  Mid/Back(5장) 최강 핸드: RF (로열 플러시)
```

## 부록: 수트 순환 우위 빠른 참조

```
  ♠ SPADE(4) → ♥ HEART(3) : SPADE 이김
  ♥ HEART(3) → ♦ DIAMOND(2): HEART 이김
  ♦ DIAMOND(2) → ♣ CLUB(1) : DIAMOND 이김
  ♣ CLUB(1) → ♠ SPADE(4)  : CLUB 이김

  공식: (attacker.value % 4) + 1 == defender.value
```
