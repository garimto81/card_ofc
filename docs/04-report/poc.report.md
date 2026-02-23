# Trump Card Auto Chess POC — PDCA 완료 보고서

**프로젝트**: Trump Card Auto Chess
**버전**: POC v1.0
**작성일**: 2026-02-19
**PDCA 사이클**: Phase 1-5 완료
**기반 PRD**: `docs/01-plan/card-autochess.prd.md` (v4.0)

---

## 목차

1. [개요](#1-개요)
2. [구현 결과 요약](#2-구현-결과-요약)
3. [아키텍처 구성](#3-아키텍처-구성)
4. [핵심 가설 검증](#4-핵심-가설-검증)
5. [버그 수정 및 개선 이력](#5-버그-수정-및-개선-이력)
6. [POC 범위 외 항목](#6-poc-범위-외-항목)
7. [다음 단계 권장](#7-다음-단계-권장)

---

## 1. 개요

### 1.1 프로젝트 정보

Trump Card Auto Chess는 52장 트럼프 덱 × TFT 경제 시스템 × OFC 3라인 핸드 배치 전략을 결합한 8인 PvP 카드 오토체스 게임이다.

본 보고서는 PDCA(Plan-Do-Check-Act) 방법론에 따라 Phase 1(PRD)부터 Phase 5(QA/검증)까지 완료된 POC(Proof of Concept) 개발의 최종 결과를 정리한다.

### 1.2 PDCA 사이클 개요

```
  Phase 1 (Plan)   → PRD 작성 완료
        |
  Phase 2 (Plan)   → 기술 설계 완료 (poc.design.md)
        |
  Phase 3 (Do)     → TDD 구현 완료 (Red → Green → Refactor)
        |
  Phase 4 (Check)  → QA 검증 + Code Review 완료
        |
  Phase 5 (Act)    → 결과 보고 + 다음 단계 정의 (현재)
```

### 1.3 POC 목표

POC는 다음 5가지 핵심 가설을 검증 가능한 상태로 구현하는 것을 목표로 했다:

| 가설 ID | 가설 내용 |
|---------|---------|
| H1 | OFC 3라인 배치 강제 규칙이 충분한 전략적 긴장감을 제공하는가 |
| H2 | 포커 핸드 판정 규칙이 플레이어에게 명확하게 이해되는가 |
| H3 | TFT 이자 경제 시스템이 저축 vs 소비 딜레마를 유발하는가 |
| H4 | 공유 카드 풀이 플레이어 간 카드 경쟁 긴장감을 생성하는가 |
| H5 | 훌라 선언 순간이 게임의 하이라이트가 되는가 |

---

## 2. 구현 결과 요약

### 2.1 생성 파일 현황

| 분류 | 파일 | 역할 |
|------|------|------|
| 소스 | `src/card.py` | Card, Rank, Suit 도메인 모델 |
| 소스 | `src/pool.py` | SharedCardPool (공유 카드 풀) |
| 소스 | `src/hand.py` | 포커 핸드 판정 엔진 + 타이브레이커 |
| 소스 | `src/board.py` | OFCBoard, Foul 판정, 패널티 |
| 소스 | `src/economy.py` | Player, 이자/연승연패/구매매각 |
| 소스 | `src/combat.py` | CombatResolver, 훌라 시너지 검증 |
| 소스 | `src/game.py` | GameState, RoundManager |
| 테스트 | `tests/test_card.py` | Card/Pool 단위 테스트 (24개) |
| 테스트 | `tests/test_hand.py` | 핸드 판정 테스트 (63개) |
| 테스트 | `tests/test_board.py` | OFCBoard/Foul 테스트 (21개) |
| 테스트 | `tests/test_combat.py` | 전투 해결 테스트 (15개) |
| 테스트 | `tests/test_economy.py` | 경제 시스템 테스트 (35개) |
| 테스트 | `tests/test_game.py` | 게임 루프 통합 테스트 (18개) |
| CLI | `cli/main.py` | 2인 로컬 대전 CLI 진행기 |
| 설정 | `pyproject.toml` | 패키지/테스트/린트 설정 |
| 문서 | `CLAUDE.md` | 프로젝트 개요 및 개발 규칙 |

**총 15개 파일** (src 7개, tests 6개, cli 1개, 설정/문서 2개)

### 2.2 테스트 현황

| 테스트 파일 | 케이스 수 | 비고 |
|------------|---------|------|
| `test_hand.py` | 63개 | 모든 포커 핸드 타입, 타이브레이커, 엣지 케이스, 스모크 테스트 |
| `test_economy.py` | 35개 | 이자 계산, 연승/연패, 구매/매각, 별 강화 |
| `test_board.py` | 21개 | 카드 배치, Foul 판정, 경고 시스템 |
| `test_game.py` | 18개 | 게임 상태, 라운드 관리, 통합 시뮬레이션 |
| `test_card.py` | 24개 | 랭크/수트 순서, 비용, 강화 판정, 풀 초기화 |
| `test_combat.py` | 15개 | 전투 해결, 데미지 계산, 훌라 배수 |
| **합계** | **176개** | **전체 통과 (PASS)** |

### 2.3 품질 지표

| 지표 | 결과 |
|------|------|
| pytest 전체 통과 | 176 / 176 PASS |
| ruff 린트 | PASS (28건 자동 수정 완료) |
| Foul 판정 케이스 | 20케이스 이상 커버 |
| 핸드 판정 스모크 | 100개 무작위 핸드 크래시 없음 |
| compare_hands 반대칭 검증 | 30회 무작위 페어 전수 통과 |

---

## 3. 아키텍처 구성

### 3.1 모듈 구조

```
  card_ofc/
  ├── src/
  │   ├── card.py      — 도메인 모델 (Card, Rank, Suit)
  │   ├── pool.py      — 공유 카드 풀 (SharedCardPool)
  │   ├── hand.py      — 핸드 판정 엔진 (evaluate_hand, compare_hands)
  │   ├── board.py     — OFC 보드 (OFCBoard, FoulResult)
  │   ├── economy.py   — 경제 시스템 (Player)
  │   ├── combat.py    — 전투 해결 (CombatResolver, count_synergies)
  │   └── game.py      — 게임 루프 (GameState, RoundManager)
  ├── tests/
  │   ├── test_card.py
  │   ├── test_hand.py
  │   ├── test_board.py
  │   ├── test_combat.py
  │   ├── test_economy.py
  │   └── test_game.py
  ├── cli/
  │   └── main.py      — 2인 로컬 대전 CLI
  └── pyproject.toml
```

### 3.2 의존성 그래프

```
  card.py (Rank, Suit, Card)
       |
       +-------> pool.py (SharedCardPool)
       |
       +-------> hand.py (HandType, HandResult, evaluate_hand, compare_hands)
                      |
                      +-------> board.py (OFCBoard, FoulResult)
                      |              |
                      |              v
                      +-------> combat.py (CombatResolver, count_synergies)
                                     |
                      economy.py     |
                      (Player) ------+-------> game.py (GameState, RoundManager)
                                                    |
                                                    v
                                               cli/main.py
```

### 3.3 핵심 모듈 설명

#### card.py — 도메인 모델

`Rank` (IntEnum, 2~14)와 `Suit` (IntEnum, 1~4)를 기반으로 `Card` dataclass를 정의한다. 핵심 메서드:

- `cost` property: 랭크 기준 비용 반환 (Common=1, Rare=2, Epic=3, Legendary=4, Mythic=5)
- `beats_suit(other)`: 수트 순환 우위 판정. 공식 `(defender.value % 4) + 1 == attacker.value`

수트 순환 우위: SPADE(4) > HEART(3) > DIAMOND(2) > CLUB(1) > SPADE(4)

#### pool.py — 공유 카드 풀

PRD §4.5.1 기준 등급별 복사본 수로 초기화:

| 등급 | 랭크 범위 | 복사본 수 | 4수트 합계 |
|------|---------|---------|---------|
| Common | 2, 3, 4 (3종) | 29장 | 348장 |
| Rare | 5, 6, 7 (3종) | 22장 | 264장 |
| Epic | 8, 9, 10 (3종) | 18장 | 216장 |
| Legendary | J, Q, K (3종) | 12장 | 144장 |
| Mythic | A (1종) | 10장 | 40장 |
| **합계** | **13종 × 4수트** | | **1,012장** |

#### hand.py — 핸드 판정 엔진

`evaluate_hand(cards)` 함수가 포커 핸드를 판정하고 `HandResult`를 반환한다.

**3단계 타이브레이커** (`compare_hands`):
1. HandType 강도 비교 (ROYAL_FLUSH=10 ~ HIGH_CARD=1)
2. enhanced_count (별 강화 카드 수) 비교
3. dominant_suit 수트 순환 우위 비교

**Front 라인(3장) 제약**: STRAIGHT, FLUSH, FULL_HOUSE, FOUR_OF_A_KIND, STRAIGHT_FLUSH, ROYAL_FLUSH 불가. 최강 = THREE_OF_A_KIND.

`apply_foul_penalty(hand)`: Foul 발생 라인의 HandType을 -1등급 강등 (최하 HIGH_CARD 유지).

#### board.py — OFC 보드

`OFCBoard`는 front(최대 3칸), mid(최대 5칸), back(최대 5칸) 3라인으로 구성된다.

`check_foul()`: Back ≥ Mid ≥ Front 핸드 강도 의무 위반 시 `FoulResult(has_foul=True, foul_lines=[...])` 반환.

#### economy.py — 경제 시스템

`Player`는 HP, 골드, 레벨, 벤치, 연승/연패 스트릭을 추적한다.

- `calc_interest()`: `min(gold // 10, 5)` — 10골드마다 +1이자, 최대 5
- `streak_bonus()`: 연승/연패 2연 +1, 3연 +2, 5연 +3
- `round_income()`: 기본 5 + 이자 + 스트릭 보너스
- `try_star_upgrade()`: 같은 (랭크, 수트, 별) 3장 → 다음 별 합성

#### combat.py — 전투 해결

`CombatResolver.resolve(board_a, board_b)`:
1. 각 보드 Foul 판정 (패널티 라인 적용)
2. back/mid/front 3라인 `compare_hands` 비교
3. 승리 라인 수 계산 → 3:0이면 Scoop(+2 보너스)
4. 훌라 조건 검증: `winner_lines >= 2 AND count_synergies(board) >= 3`
5. 훌라 성공 시 `damage × 4`

`count_synergies(board)`: 같은 수트 2장 이상인 수트 수 = 활성 시너지 수.

#### game.py — 게임 루프

- `GameState`: 플레이어 목록, 풀, 라운드 번호, 페이즈 상태를 보유
- `RoundManager`: prep(골드 지급) → combat(3라인 전투) → result(라운드 종료/보드 리셋) 사이클 관리

---

## 4. 핵심 가설 검증

### 4.1 검증 현황

| 가설 | 구현 상태 | 검증 방법 | 미검증 항목 |
|------|---------|---------|-----------|
| H1: OFC 3라인 전략성 | 구현 완료 | board.py Foul 판정 + CLI 경고 표시 | 실제 플레이어 인터뷰 (5판+) |
| H2: 포커 핸드 판정 명확성 | 구현 완료 | 176개 TDD 케이스 전체 통과 | 플레이어 이해도 측정 |
| H3: TFT 이자 경제 딜레마 | 구현 완료 | economy.py 단위 테스트 35개 | 밸런스 시뮬레이션 자동화 |
| H4: 공유 풀 경쟁 긴장감 | 구현 완료 | SharedCardPool 경쟁 시나리오 테스트 | 다인 플레이 확장 |
| H5: 훌라 선언 하이라이트 | 구현 완료 | count_synergies 3개+ 자격 검증 | 실제 선언 빈도 측정 |

### 4.2 H1: OFC 3라인 전략성

**구현 내용**: `OFCBoard.check_foul()`이 Back ≥ Mid ≥ Front 핸드 강도 의무를 강제한다. 위반 시 `FoulResult(has_foul=True)`와 함께 어느 라인이 Foul인지 반환한다. `apply_foul_penalty()`가 해당 라인의 HandType을 -1등급 강등한다.

**CLI 확인 경로**: `cli/main.py`의 `get_foul_warning()`이 배치 중 실시간 경고를 출력한다.

**검증 케이스**: `tests/test_board.py`의 `TestFoulDetection` (6개 케이스) — 정상 배치, Back < Mid Foul, Mid < Front Foul, 양쪽 동시 Foul.

### 4.3 H2: 포커 핸드 판정 명확성

**구현 내용**: `evaluate_hand(cards)`가 5장 전체 핸드 (ROYAL_FLUSH ~ HIGH_CARD)와 3장 Front 라인 제한 핸드를 판정한다. `compare_hands(h1, h2)`가 3단계 타이브레이커로 승패를 결정한다.

**검증 케이스**: `tests/test_hand.py` 63개 케이스:
- 5장 핸드 타입 전수 (18개)
- 3장 Front 라인 제약 (6개)
- HandResult 필드 검증 (7개)
- 핸드 비교 (10개)
- beats_suit 단위 (11개)
- 설계 문서 엣지 케이스 EC1~EC8 (8개)
- 무작위 스모크 (3개)

### 4.4 H3: TFT 이자 경제 딜레마

**구현 내용**: `Player.calc_interest()`가 `min(gold // 10, 5)` 공식으로 이자를 계산한다. 이자 최대화 임계점인 50골드까지 저축하면 매 라운드 +5 이자를 받지만, 카드 구매 기회를 잃는 트레이드오프가 발생한다.

**검증 케이스**: `tests/test_economy.py`의 `TestInterestCalculation` (9개) — 0, 9, 10, 20, 35, 40, 50, 100, 200 골드 경계값 검증.

### 4.5 H4: 공유 풀 경쟁 긴장감

**구현 내용**: `SharedCardPool`이 등급별 총 1,012장의 카드를 관리한다. `draw()` 성공/실패로 카드 품귀 현상을 표현하며, `random_draw_n()`이 드로우 후 풀에서 즉시 차감한다.

**검증 케이스**: `tests/test_card.py`의 `TestSharedCardPool` (8개) — 초기화 총수, 드로우/고갈, 반환, 등급별 복사본 수.

### 4.6 H5: 훌라 선언 하이라이트

**구현 내용**: `CombatResolver.resolve()`에서 훌라 선언 자격을 `winner_lines >= 2 AND count_synergies(board) >= 3`으로 검증한다. 자격 미달 시 `hula_applied=False`로 무시되며, 성공 시 `damage × 4`가 적용된다.

**검증 케이스**: `tests/test_combat.py`의 훌라 관련 케이스 — `test_hula_multiplier_x4`, `test_hula_multiplier_x4_scoop`, `test_hula_not_applied_when_lose`.

---

## 5. 버그 수정 및 개선 이력

### 5.1 Phase 3 구현 단계

| 단계 | 파일 | 수정 내용 | 심각도 |
|------|------|---------|------|
| Phase 3 구현 | `card.py`, `hand.py` | `beats_suit` 수트 순환 우위 공식 오류 수정 — 초기 `attacker.value > defender.value` 단순 비교에서 `(defender.value % 4) + 1 == attacker.value` 순환 공식으로 교체 | HIGH |

### 5.2 Phase 3.2 Architect 검증

| 단계 | 파일 | 수정 내용 | 심각도 |
|------|------|---------|------|
| Phase 3.2 | `hand.py` | `apply_foul_penalty()` 함수 추가 — 전투 Foul 패널티를 `CombatResolver`에서 `hand.py`로 이관하여 관심사 분리 | MEDIUM |

### 5.3 Phase 4.2 Code Review

| 단계 | 파일 | 수정 내용 | 심각도 |
|------|------|---------|------|
| Phase 4.2 | `pool.py` | 등급 경계값 PRD §4.5.1 기준으로 정정 — `Rank.FIVE`를 Common(29장)에서 Rare(22장)로 수정, `_get_copy_count` 기준선 재조정 | CRITICAL |
| Phase 4.2 | `board.py` | 유효하지 않은 라인명 방어 처리 추가 — `place_card()`/`remove_card()`에 `ValueError` 발생 로직 추가 | HIGH |
| Phase 4.2 | `combat.py` | 훌라 시너지 자격 검증 추가 — `hula_a and winner_lines_a >= 2 and synergies_a >= 3` 조건 추가 (PRD §7 기준) | HIGH |

---

## 6. POC 범위 외 항목

이번 POC에서 검증 범위로 포함하지 않은 항목들이다. 다음 개발 단계 (STANDARD 복잡도) 진입 시 우선순위를 판단할 참고 목록으로 사용한다.

### 6.1 8인 PvP 멀티플레이어

현재 POC는 2인 로컬 대전(CLI)만 지원한다. `GameState`의 `players` 목록 구조는 다인 확장을 고려해 설계됐으나, 라운드 매칭 로직(`RoundManager.start_combat_phase()`)이 2인 하드코딩 상태다.

### 6.2 증강체 시스템

PRD §6에서 정의된 Silver/Gold/Prismatic 증강체 시스템은 구현되지 않았다. `Player` 구조에 `augments` 필드 확장이 필요하다.

### 6.3 아이템 파츠 조합

PRD §8의 아이템 파츠 조합 시스템은 POC 범위 외다.

### 6.4 상점 레벨별 드롭률 가중치

`SharedCardPool.random_draw_n(n, level=1)`의 `level` 파라미터가 인터페이스로 존재하지만, 실제 드롭률 가중치(PRD §4.5.2 레벨별 확률 테이블)는 적용되지 않았다. 현재는 단순 균일 무작위 샘플링이다.

### 6.5 판타지랜드 및 스톱(×8) 선언

훌라 ×4 배수까지는 구현됐으나, 스톱 조건 달성 시의 ×8 선언 및 판타지랜드 진입 조건은 구현되지 않았다.

### 6.6 홀덤 이벤트 (Flop/Turn/River)

PRD §3의 공유 이벤트 카드(Flop 5장, Turn 5장, River 5장) 시스템은 구현되지 않았다.

---

## 7. 다음 단계 권장

### 7.1 즉시 실행 가능 (이번 POC 결과물 활용)

| 우선순위 | 항목 | 방법 |
|---------|------|------|
| 1순위 | 2인 로컬 대전 실제 플레이 테스트 | `python cli/main.py` 5판 이상 진행 |
| 2순위 | H1-H5 가설 인터뷰 진행 | Foul 발생률, 훌라 선언 수용도, 핸드 판정 명확성 측정 |
| 3순위 | 경제 밸런스 시뮬레이션 자동화 | `economy.py` + `game.py` 기반 N판 자동 시뮬레이션 |

### 7.2 다음 개발 단계 (STANDARD 복잡도)

| 항목 | 설명 |
|------|------|
| 상점 레벨별 드롭률 | `random_draw_n(n, level)` 실제 가중치 적용 (PRD §4.5.2) |
| 증강체 기초 구현 | Silver 증강체 3종 파일럿 구현 |
| 3~4인 확장 | `RoundManager` 매칭 로직 다인 지원 |
| 홀덤 이벤트 | Flop/Turn/River 공유 카드 이벤트 시스템 |

### 7.3 진행 명령어

```bash
# POC 실행 (자동 모드)
python cli/main.py --auto

# POC 실행 (인터랙티브 모드)
python cli/main.py

# 전체 테스트
cd C:/claude/card_ofc
pytest tests/ -v

# 린트
ruff check src/ --fix
```

---

## 부록: 파일별 라인 수

| 파일 | 라인 수 | 주요 내용 |
|------|---------|---------|
| `src/card.py` | 69 | Card, Rank, Suit, beats_suit |
| `src/pool.py` | 63 | SharedCardPool, _get_copy_count |
| `src/hand.py` | 174 | HandType, HandResult, evaluate_hand, compare_hands, apply_foul_penalty |
| `src/board.py` | 95 | OFCBoard, FoulResult, check_foul, get_foul_warning |
| `src/economy.py` | 90 | Player, 이자/스트릭/구매/매각/별강화 |
| `src/combat.py` | 115 | CombatResolver, count_synergies, CombatResult |
| `src/game.py` | 91 | GameState, RoundManager |
| `cli/main.py` | 204 | 2인 CLI 대전 진행기 |
| `tests/` (합계) | ~600 | 176개 테스트 케이스 |
