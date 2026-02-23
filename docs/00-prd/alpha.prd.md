# Trump Card Auto Chess — Alpha 단계 PRD

**버전**: 1.0.0
**작성일**: 2026-02-20
**기반**: POC 완료 보고서 (poc.report.md) + PRD v4.0
**목적**: Alpha 단계 구현을 위한 요구사항 정의

---

## 목차

1. [배경 및 목적](#1-배경-및-목적)
2. [요구사항 목록](#2-요구사항-목록)
3. [기능 범위](#3-기능-범위)
4. [비기능 요구사항](#4-비기능-요구사항)
5. [제약사항](#5-제약사항)
6. [우선순위](#6-우선순위)
7. [구현 범위 및 단계](#7-구현-범위-및-단계)

---

## 1. 배경 및 목적

### 1.1 POC 결과 요약

Trump Card Auto Chess POC(Proof of Concept)는 PDCA Phase 1~5를 완료하고 176개 TDD 테스트를 전부 통과했다. 핵심 5가지 가설(H1~H5)이 코드 레벨에서 검증됐으며, 2인 로컬 대전 CLI(`cli/main.py`)가 정상 동작한다.

| 구분 | 결과 |
|------|------|
| 총 테스트 | 176개 전체 PASS |
| 린트 | ruff PASS |
| 핵심 가설 | H1~H5 모두 코드 구현 완료 |
| POC 구현 파일 | src/ 7개, tests/ 6개, cli/ 1개 |

**구현 완료 범위**:
- OFC 3라인 배치 + Foul 판정 (`board.py`)
- 포커 핸드 판정 + 3단계 타이브레이커 (`hand.py`)
- TFT 이자 경제 + 연승/연패 + 별 강화 (`economy.py`)
- 공유 카드 풀 관리 (`pool.py`)
- 3라인 전투 해결 + 훌라 ×4 (`combat.py`)
- 게임 루프 + 라운드 매니저 (`game.py`)

### 1.2 POC 범위 외 항목 (Alpha 구현 대상)

POC에서 의도적으로 제외된 5개 항목이 Alpha 단계 구현 대상이다.

| 항목 | 현재 상태 | Alpha 목표 |
|------|-----------|-----------|
| 상점 레벨별 드롭률 가중치 | 균일 무작위 샘플링 | PRD §10.6 레벨별 확률 테이블 실제 적용 |
| 증강체 시스템 | 미구현 | Silver 증강체 파일럿 3종 구현 |
| 홀덤 이벤트 | 미구현 | Flop/Turn/River 공유 이벤트 카드 시스템 |
| 스톱(×8) + 판타지랜드 | 훌라 ×4만 구현 | 스톱 선언 조건/처리 + 판타지랜드 진입 |
| 3~4인 매칭 | 2인 하드코딩 | RoundManager 다인 지원 |

### 1.3 Alpha 목표

Alpha 단계는 POC에서 검증된 핵심 메커니즘 위에 **게임 깊이를 더하는 5개 기능**을 추가하는 것이 목표다.

- 상점 경제 현실화: 레벨별 드롭률 가중치로 고코스트 카드 희소성 반영
- 전략 레이어 확장: 증강체로 게임마다 다른 빌드 방향 제공
- 라운드 이벤트 도입: 홀덤 이벤트로 정적인 전투에 동적 변화 추가
- 극적 역전 완성: 스톱(×8) 선언 + 판타지랜드 진입으로 하이라이트 강화
- 멀티플레이어 기반: 3~4인 확장으로 실제 PvP 경험 진입점 제공

---

## 2. 요구사항 목록

### A1. 상점 레벨별 드롭률 가중치

**기반**: PRD §10.6 (레벨별 상점 드롭 확률 테이블)

**현재 문제**: `SharedCardPool.random_draw_n(n, level)` 메서드에 `level` 파라미터가 인터페이스로 존재하지만 실제 가중치를 적용하지 않는다. 현재는 등급 무관 균일 무작위 샘플링이다. 레벨 1 플레이어가 5코스트 Mythic 카드(A)를 드로우하는 비정상 상황이 가능하다.

**요구사항**:

레벨별 코스트 드롭 확률 테이블을 `pool.py`에 구현한다.

| 레벨 | 1코스트 | 2코스트 | 3코스트 | 4코스트 | 5코스트 |
|------|--------|--------|--------|--------|--------|
| 1 | 75% | 20% | 5% | 0% | 0% |
| 2 | 75% | 20% | 5% | 0% | 0% |
| 3 | 55% | 30% | 15% | 0% | 0% |
| 4 | 55% | 30% | 15% | 0% | 0% |
| 5 | 35% | 35% | 25% | 5% | 0% |
| 6 | 20% | 35% | 30% | 14% | 1% |
| 7 | 15% | 25% | 35% | 20% | 5% |
| 8 | 10% | 15% | 35% | 30% | 10% |
| 9 | 5% | 10% | 25% | 35% | 25% |

**기술 상세**:

- `LEVEL_DROP_RATES: dict[int, list[float]]` 상수 정의 (level → [1cost%, 2cost%, 3cost%, 4cost%, 5cost%])
- `random_draw_n(n, level)`:
  1. `level`을 기반으로 코스트 가중치 선택
  2. 해당 코스트 카드 중 풀에 남은 카드만 후보로 필터링
  3. `random.choices(population, weights, k=n)` 적용
  4. 드로우된 카드 즉시 풀에서 차감
- 풀에 해당 코스트 카드가 없으면 인접 코스트로 폴백 (낮은 코스트 우선)
- `Player.level` 필드를 `economy.py`에서 관리 (현재 미구현 → 추가 필요)

**영향 파일**:
- `src/pool.py` — `LEVEL_DROP_RATES` 추가, `random_draw_n` 로직 변경
- `src/economy.py` — `Player.level` 필드 + `level_up()` 메서드 추가
- `tests/test_card.py` — 레벨별 드롭률 검증 테스트 추가

### A2. 증강체 시스템 (Augment)

**기반**: PRD §5.7 (Silver/Gold/Prismatic 증강체 시스템)

**현재 문제**: `Player` 구조에 `augments` 필드가 없고 증강체 관련 코드가 전무하다. Alpha에서는 Silver 증강체 3종을 파일럿으로 구현하여 시스템 기반을 확립한다.

**요구사항**:

#### A2.1 증강체 데이터 모델

```python
@dataclass
class Augment:
    id: str               # 고유 식별자 (예: "economist")
    name: str             # 표시 이름 (예: "경제학자")
    tier: str             # "silver" | "gold" | "prismatic"
    description: str      # 효과 설명
    effect_type: str      # "passive" | "trigger"
```

#### A2.2 Silver 증강체 파일럿 3종

| ID | 이름 | 효과 | 구현 대상 |
|----|------|------|---------|
| `economist` | 경제학자 | 이자 수입 상한 5→6골드 | `economy.py:calc_interest()` 상한 변경 |
| `suit_mystery` | 수트의 신비 | 선택 수트 1개 시너지 카운트 +1 (영구) | `combat.py:count_synergies()` 보정 추가 |
| `lucky_shop` | 행운의 상점 | 매 라운드 상점 공개 +1장 (5→6장) | `game.py` 상점 드로우 수 변경 |

#### A2.3 증강체 획득 타이밍 (단순화 — Alpha 범위)

- Alpha에서는 라운드 2-4 종료 시 Silver 증강체 3개 중 1개 선택으로 제한
- Gold/Prismatic은 STANDARD 단계에서 구현

#### A2.4 Player 통합

```python
# economy.py Player 추가 필드
augments: list[Augment] = field(default_factory=list)

def add_augment(self, augment: Augment) -> None: ...
def has_augment(self, augment_id: str) -> bool: ...
```

**기술 상세**:

- `src/augment.py` 신규 파일: `Augment` dataclass + `SILVER_AUGMENTS` 상수 (3종)
- `economy.py:calc_interest()` — `economist` 증강체 보유 시 `min(gold // 10, 6)` 반환
- `combat.py:count_synergies()` — `suit_mystery` 증강체 보유 시 선택 수트 카운트 +1
- `game.py:GameState` — `augment_selection_round` 처리 로직 추가

**영향 파일**:
- `src/augment.py` — 신규 생성 (Augment 데이터 모델, SILVER_AUGMENTS)
- `src/economy.py` — Player.augments 필드 + calc_interest 수정
- `src/combat.py` — count_synergies 증강체 보정 추가
- `src/game.py` — 증강체 선택 페이즈 추가
- `tests/test_augment.py` — 신규 테스트 파일

### A3. 홀덤 이벤트 (Flop/Turn/River)

**기반**: PRD §8 (홀덤 이벤트 시스템)

**현재 문제**: 홀덤 이벤트 시스템이 전혀 구현되지 않았다. 전투 페이즈는 항상 동일한 조건으로 진행된다.

**요구사항**:

#### A3.1 이벤트 카드 구조

각 스테이지의 라운드 1~3마다 공유 이벤트 카드가 공개된다.

| 라운드 | 단계 | 공개 카드 수 | 누적 |
|--------|------|-----------|------|
| 스테이지 X의 1번째 | Flop | 3장 동시 | 3장 |
| 스테이지 X의 2번째 | Turn | 1장 추가 | 4장 |
| 스테이지 X의 3번째 | River | 1장 추가 | 5장 |

#### A3.2 Alpha 파일럿 이벤트 카드 목록 (5종)

| ID | 이름 | 효과 | 단계 |
|----|------|------|------|
| `suit_bonus_spade` | 스페이드 우위 | 이번 라운드 ♠ 수트 시너지 카운트 +1 | Flop |
| `double_interest` | 이자 배가 | 이번 라운드 이자 수입 ×2 | Flop |
| `foul_amnesty` | 폴 면제 | 이번 라운드 Foul 패널티 미적용 | Turn |
| `scoop_bonus` | 스쿠프 강화 | 스쿠프 시 추가 피해 +4 (기존 +2에서) | Turn |
| `low_card_power` | 로우카드 역전 | 이번 라운드 하이카드 비교 역전 (낮은 랭크 우선) | River |

#### A3.3 데이터 모델

```python
@dataclass
class HoldemEvent:
    id: str
    name: str
    phase: str            # "flop" | "turn" | "river"
    description: str
    effect_type: str      # "suit_boost" | "economy" | "foul" | "combat"

@dataclass
class HoldemState:
    stage: int
    flop: list[HoldemEvent]  # 3장
    turn: HoldemEvent | None
    river: HoldemEvent | None
    active_events: list[HoldemEvent]  # 현재 라운드 적용 이벤트
```

#### A3.4 전투 적용 로직

1. `RoundManager.start_combat_phase()` 호출 시 `HoldemState.active_events` 수집
2. `CombatResolver.resolve(board_a, board_b, events)` 시그니처 확장
3. 각 이벤트 `effect_type`에 따라 전투 파라미터 조정
4. CLI 출력: 현재 활성 이벤트 목록 표시

**기술 상세**:

- `src/holdem.py` 신규 파일: `HoldemEvent`, `HoldemState`, `PILOT_EVENTS` (5종)
- `src/combat.py` — `resolve()` 메서드에 `events` 파라미터 추가, 이벤트 효과 적용
- `src/game.py` — `GameState.holdem_state` 필드 추가, 라운드별 이벤트 진행 관리
- CLI — 전투 전 활성 이벤트 목록 출력

**영향 파일**:
- `src/holdem.py` — 신규 생성
- `src/combat.py` — resolve 시그니처 + 이벤트 처리 로직
- `src/game.py` — HoldemState 통합
- `tests/test_holdem.py` — 신규 테스트 파일
- `tests/test_combat.py` — 이벤트 적용 전투 테스트 추가

### A4. 스톱(×8) 선언 및 판타지랜드

**기반**: PRD §9.2 (스톱 선언), §6.6 (판타지랜드)

**현재 문제**:
- 훌라 ×4는 구현됐으나, 스톱 ×8 선언 조건 및 처리가 없다.
- 판타지랜드 진입 조건(Front QQ+ 달성) 판정 로직이 없다.

**요구사항**:

#### A4.1 스톱(×8) 선언

| 스톱 타입 | 조건 | 효과 |
|---------|------|------|
| **로우 스톱** | 훌라 선언 성공 + 상대 HP ≤ 10 | HP 피해 × 8 |
| **하이 스톱** | 훌라 선언 성공 + 3라인 스쿠프 + 로열 플러시 보유 | HP 피해 × 8 + 로열티 최대 |

**스톱 선언 처리 로직**:

```
1. 훌라 선언 성공 여부 확인 (winner_lines >= 2, synergies >= 3)
2. 스톱 조건 추가 검증:
   - 로우 스톱: opponent.hp <= 10
   - 하이 스톱: scoop == True AND back_hand.type == ROYAL_FLUSH
3. 조건 충족 시 damage_multiplier = 8 (훌라 ×4 대체, 중첩 불가)
4. CombatResult.stop_applied = True
```

**배수 중첩 규칙**:
- 스톱 선언 성공 시 훌라 ×4는 무효화, 스톱 ×8이 최우선
- OFC 로열티는 배수와 별도 덧셈

#### A4.2 판타지랜드

| 항목 | 조건/내용 |
|------|---------|
| **진입 조건** | Front 라인에서 QQ (퀸 원페어) 이상 달성 |
| **유지 조건** | 판타지랜드 중 Front에서 스리카인드 이상 달성 시 다음 라운드 유지 |
| **진입 효과** | 다음 라운드 공유 풀에서 13장 동시 드로우, 필요 카드 선택 후 나머지 반환 |
| **폴 면제** | 판타지랜드 진입 라운드 Foul 판정 자동 면제 |

**판타지랜드 판정 로직**:

```python
# board.py 또는 game.py에 추가
def check_fantasyland(board: OFCBoard) -> bool:
    """Front 라인 QQ+ 원페어 이상 달성 여부 판정"""
    front_hand = evaluate_hand(board.front)
    if front_hand.type == HandType.PAIR:
        # 페어를 구성하는 랭크가 Q(12) 이상인지 확인
        return front_hand.primary_rank >= Rank.QUEEN
    return front_hand.type > HandType.PAIR  # 스리카인드 이상

# Player 추가 필드
in_fantasyland: bool = False
fantasyland_next: bool = False
```

**영향 파일**:
- `src/combat.py` — `CombatResult` 에 `stop_applied` 필드 추가, 스톱 판정 로직
- `src/board.py` — `check_fantasyland()` 함수 추가
- `src/economy.py` — `Player.in_fantasyland`, `Player.fantasyland_next` 필드 추가
- `src/game.py` — 판타지랜드 상태 관리, 다음 라운드 13장 드로우 처리
- `tests/test_combat.py` — 스톱 선언 테스트 추가
- `tests/test_board.py` — 판타지랜드 판정 테스트 추가

### A5. 3~4인 매칭 확장

**기반**: PRD §13 (매칭 및 생존)

**현재 문제**: `RoundManager.start_combat_phase()`가 `players[0]` vs `players[1]` 2인 하드코딩이다. `GameState.players`는 리스트 구조로 다인 확장을 의도했지만 실제 매칭 로직이 없다.

**요구사항**:

#### A5.1 라운드 매칭 로직

```
생존 플레이어 수 N 기준:
- N = 2: 1 vs 1 (기존 동일)
- N = 3: 3인 라운드 로빈 (3쌍 중 2쌍 전투, 1명 바이)
- N = 4: 2쌍 동시 전투 (랜덤 매칭)
- N = 5~8: (STANDARD 단계 확장)
```

#### A5.2 매칭 규칙

| 조건 | 규칙 |
|------|------|
| 같은 상대 3연속 금지 | `match_history` 추적으로 방지 |
| 바이(Bye) 처리 | 바이 플레이어는 해당 라운드 전투 없음, 골드 수입만 |
| HP 0 탈락 | 탈락 플레이어는 `players`에서 제거 |

#### A5.3 데이터 모델 변경

```python
# game.py GameState 변경
@dataclass
class GameState:
    players: list[Player]
    pool: SharedCardPool
    round_number: int
    phase: str
    match_history: dict[str, list[str]]  # player_id → 최근 3명 상대 ID
    combat_pairs: list[tuple[int, int]]  # 현재 라운드 매칭 쌍

# game.py RoundManager 변경
def generate_matchups(players: list[Player]) -> list[tuple[int, int]]:
    """생존 플레이어 수에 따라 전투 쌍 생성. 같은 상대 3연속 방지."""
    ...

def start_combat_phase(self) -> list[CombatResult]:
    """모든 매칭 쌍에 대해 CombatResolver.resolve() 실행"""
    ...
```

#### A5.4 CLI 확장

- `cli/main.py` — 플레이어 수 선택 프롬프트 추가 (2~4인)
- 각 매칭 쌍 전투 결과 순차 출력
- 탈락 플레이어 제거 및 생존자 상태 업데이트

**영향 파일**:
- `src/game.py` — `GameState.match_history`, `generate_matchups()`, `start_combat_phase()` 리팩토링
- `cli/main.py` — 플레이어 수 선택 + 다인 전투 루프
- `tests/test_game.py` — 3인/4인 매칭 테스트 추가

---

## 3. 기능 범위

### Must Have (Alpha 필수 구현)

| 요구사항 | 이유 |
|---------|------|
| A1. 상점 레벨별 드롭률 가중치 | 경제 시스템의 핵심. 레벨업 의미 부여 없이는 다른 기능이 불완전 |
| A2. 증강체 Silver 3종 | 게임 깊이의 핵심. 매 게임 다른 빌드 방향 제공 |
| A4. 스톱(×8) 선언 | 훌라 ×4와 세트. PRD의 배수 시스템 완성 |
| A4. 판타지랜드 판정 | OFC 3라인의 핵심 보상 메커니즘 |

### Should Have (구현 권장)

| 요구사항 | 이유 |
|---------|------|
| A3. 홀덤 이벤트 파일럿 5종 | 라운드 동적 변화. 파일럿 규모로 기반 구축 |
| A5. 3~4인 매칭 | 실제 PvP 진입점. 2인 이상 구조 확인 |

### Won't Have (Alpha 제외)

| 항목 | 제외 이유 | 다음 단계 |
|------|---------|---------|
| Gold/Prismatic 증강체 | Silver 파일럿 검증 후 확장 | STANDARD |
| 홀덤 이벤트 전체 30종 | 파일럿 5종으로 시스템 검증 선행 | STANDARD |
| 8인 PvP | 5~8인 매칭 복잡도 높음 | STANDARD |
| 아이템 파츠 조합 시스템 | PRD §12.4. 증강체와 우선순위 충돌 | STANDARD |
| 네트워크 멀티플레이어 | 로컬 CLI 기반 유지 | STANDARD+ |
| 레벨업 XP 시스템 전체 | A1은 레벨 파라미터만, XP 수집 로직은 단순화 | STANDARD |

---

## 4. 비기능 요구사항

### 4.1 테스트 커버리지

| 항목 | 기준 |
|------|------|
| 기존 176개 테스트 | 전체 유지 (리그레션 없음) |
| 신규 테스트 커버리지 | 신규 코드 80% 이상 |
| TDD 원칙 | Red → Green → Refactor 순서 준수 |

**테스트 파일별 최소 케이스 수**:

| 파일 | 최소 케이스 |
|------|-----------|
| `tests/test_augment.py` | 15개 이상 |
| `tests/test_holdem.py` | 15개 이상 |
| `tests/test_card.py` (확장) | 기존 24개 + 드롭률 테스트 10개+ |
| `tests/test_combat.py` (확장) | 기존 15개 + 스톱 선언 5개+ |
| `tests/test_board.py` (확장) | 기존 21개 + 판타지랜드 5개+ |
| `tests/test_game.py` (확장) | 기존 18개 + 3~4인 매칭 8개+ |

**Alpha 완료 기준**: `pytest tests/ -v` 전체 PASS (기존 176개 + 신규 58개+ = 234개+)

### 4.2 코드 품질

| 항목 | 기준 |
|------|------|
| 린트 | `ruff check src/ --fix` PASS |
| 타입 힌트 | 신규 public 함수 전체 type annotation 필수 |
| 모듈 크기 | 신규 파일 200줄 이하 권장 |

### 4.3 성능

| 항목 | 기준 |
|------|------|
| 단일 라운드 처리 | 100ms 이내 (전투 + 이벤트 + 증강체 포함) |
| 1000 라운드 시뮬레이션 | 10초 이내 (자동화 밸런스 테스트용) |

---

## 5. 제약사항

### 5.1 아키텍처 제약

| 항목 | 제약 |
|------|------|
| 기반 아키텍처 | POC 레이어 구조 유지 (`card → pool → hand → board → combat → game`) |
| 의존성 방향 | 하위 모듈이 상위 모듈을 import 금지 (예: `pool.py`가 `game.py` import 불가) |
| 신규 모듈 위치 | `src/` 디렉토리 내부 (예: `src/augment.py`, `src/holdem.py`) |
| CLI 기반 유지 | Alpha는 GUI/웹 전환 없이 `cli/main.py` 확장 |

### 5.2 기술 제약

| 항목 | 제약 |
|------|------|
| Python 버전 | 3.11+ (`match/case`, `dataclass(slots=True)` 사용 가능) |
| 외부 의존성 | `pyproject.toml`에 없는 패키지 추가 금지 (표준 라이브러리 + 기존 dev 의존성만) |
| 패키지 구조 | `pip install -e ".[dev]"` 정상 동작 유지 |

### 5.3 게임 설계 제약

| 항목 | 제약 |
|------|------|
| 카드 풀 구조 | PRD §4.5.1 등급별 복사본 수 유지 (Common 29장, Rare 22장 등) |
| 이자 공식 | `min(gold // 10, 5)` 기본 공식 유지 (economist 증강체로만 상한 변경) |
| 훌라 조건 | `winner_lines >= 2 AND synergies >= 3` 기존 조건 유지 |
| Foul 패널티 | `-1 핸드 등급` 유지 (PRD §6.3) |

---

## 6. 우선순위

### 6.1 구현 우선순위 (P1 → P5)

| 순위 | 요구사항 | 이유 |
|------|---------|------|
| **P1** | A1. 상점 레벨별 드롭률 가중치 | 다른 모든 기능의 기반. `Player.level` 필드 없이 A2~A5 완성 불가 |
| **P2** | A4. 스톱(×8) + 판타지랜드 | 독립 구현 가능. 기존 combat/board 모듈 확장만 필요 |
| **P2** | A2. 증강체 Silver 3종 | A1과 병렬 가능. `Player.level` 완료 후 착수 가능 |
| **P3** | A3. 홀덤 이벤트 파일럿 | A1~A2 완료 후 `GameState` 안정화 이후 추가 |
| **P4** | A5. 3~4인 매칭 | 홀덤 이벤트 적용 후 다인 전투 검증 |

### 6.2 의존성 그래프

```
A1 (레벨 드롭률)
  └─ Player.level 필드 확립
        ├─ A2 (증강체 Silver) — Player.augments 필드
        │     └─ economy.py / combat.py 통합
        └─ A3 (홀덤 이벤트) — GameState.holdem_state
              └─ A5 (3~4인 매칭) — RoundManager 리팩토링

A4 (스톱 + 판타지랜드)  — combat.py / board.py 독립 확장
```

A1은 블로킹 의존성. A4는 독립 병렬 구현 가능.

---

## 7. 구현 범위 및 단계

### 7.1 요구사항별 구현 상세

| 요구사항 | 복잡도 | 신규 파일 | 수정 파일 | 예상 테스트 추가 수 |
|---------|--------|---------|---------|---------------|
| A1. 드롭률 가중치 | MEDIUM | 없음 | `pool.py`, `economy.py` | 10개+ |
| A2. 증강체 Silver | MEDIUM | `augment.py` | `economy.py`, `combat.py`, `game.py` | 15개+ |
| A3. 홀덤 이벤트 | MEDIUM | `holdem.py` | `combat.py`, `game.py`, `cli/main.py` | 15개+ |
| A4. 스톱+판타지랜드 | LOW~MEDIUM | 없음 | `combat.py`, `board.py`, `economy.py`, `game.py` | 10개+ |
| A5. 3~4인 매칭 | MEDIUM | 없음 | `game.py`, `cli/main.py` | 8개+ |

**총 예상**: 신규 파일 2개, 수정 파일 6개, 신규 테스트 58개+

### 7.2 Phase별 구현 계획

#### Phase Alpha-1 (기반 확립)

**목표**: A1 + A4 완료 (독립 구현 2개)

| 작업 | 파일 | 내용 |
|------|------|------|
| `Player.level` 필드 추가 | `economy.py` | level: int = 1, level_up() 메서드 |
| `LEVEL_DROP_RATES` 상수 | `pool.py` | 9레벨×5코스트 확률 테이블 |
| `random_draw_n` 로직 변경 | `pool.py` | 레벨 기반 가중치 샘플링 |
| `check_fantasyland` 추가 | `board.py` | Front QQ+ 판정 함수 |
| 스톱 판정 로직 추가 | `combat.py` | CombatResult.stop_applied, 스톱 조건 |
| `Player.in_fantasyland` | `economy.py` | 판타지랜드 상태 필드 |

#### Phase Alpha-2 (증강체 + 이벤트)

**목표**: A2 + A3 완료

| 작업 | 파일 | 내용 |
|------|------|------|
| `Augment` 데이터 모델 | `augment.py` | dataclass + SILVER_AUGMENTS 3종 |
| `Player.augments` 통합 | `economy.py` | add_augment, has_augment |
| 증강체 효과 적용 | `economy.py`, `combat.py` | economist 이자 상한, suit_mystery 시너지 |
| `HoldemEvent` 데이터 모델 | `holdem.py` | dataclass + PILOT_EVENTS 5종 |
| `GameState.holdem_state` | `game.py` | HoldemState 필드 추가 |
| `resolve()` 이벤트 파라미터 | `combat.py` | events 파라미터 + 효과 적용 |

#### Phase Alpha-3 (다인 매칭)

**목표**: A5 완료 + 전체 통합 검증

| 작업 | 파일 | 내용 |
|------|------|------|
| `generate_matchups()` | `game.py` | 3~4인 매칭 쌍 생성 |
| `match_history` 추적 | `game.py` | 3연속 같은 상대 방지 |
| CLI 플레이어 수 선택 | `cli/main.py` | 2~4인 선택 프롬프트 |
| 전체 통합 테스트 | `tests/test_game.py` | 3인/4인 풀 게임 시뮬레이션 |

### 7.3 완료 기준 체크리스트

```
Alpha 완료 조건:
[ ] pytest tests/ -v → 234개+ 전체 PASS (기존 176 + 신규 58+)
[ ] ruff check src/ --fix → PASS
[ ] python cli/main.py --auto → 4인 1게임 크래시 없이 완료
[ ] A1: level=9 플레이어가 5코스트 카드 25% 확률로 드로우 검증
[ ] A2: economist 증강체 보유 시 이자 상한 6골드 확인
[ ] A3: Flop 이벤트 활성화 시 전투 결과에 효과 반영 확인
[ ] A4: 스톱 조건 충족 시 damage × 8 적용 확인
[ ] A4: Front QQ 달성 시 판타지랜드 플래그 True 확인
[ ] A5: 3인 매칭에서 바이 플레이어 1명 올바른 처리 확인
```
