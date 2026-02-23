# Trump Card Auto Chess — STANDARD 단계 PRD

**버전**: 1.0.0
**작성일**: 2026-02-23
**기반**: Alpha 완료 보고서 (`alpha.report.md`) + POC 검증 보고서 (`poc-verification.report.md`)
**목적**: STANDARD 단계 구현을 위한 요구사항 정의

---

## 목차

1. [배경 및 목적](#1-배경-및-목적)
2. [요구사항 목록](#2-요구사항-목록)
3. [기능 범위](#3-기능-범위)
4. [비기능 요구사항](#4-비기능-요구사항)
5. [제약사항](#5-제약사항)
6. [우선순위](#6-우선순위)
7. [구현 단계](#7-구현-단계)

---

## 1. 배경 및 목적

### 1.1 Alpha 완료 상태

Trump Card Auto Chess Alpha 단계는 POC 핵심 5가지 메커니즘 위에 증강체(A2), 홀덤 이벤트(A3), 스톱×8 + 판타지랜드 진입 판정(A4), 3~4인 매칭(A5), 레벨 드롭률 가중치(A1)를 추가하고 261개 테스트 전부 통과했다. Architect APPROVE 및 code-reviewer APPROVE를 받아 Alpha 완료가 선언됐다.

| 항목 | Alpha 완료 상태 |
|------|---------------|
| 총 테스트 | 261개 전체 PASS |
| 린트 | ruff PASS |
| 구현 모듈 | `src/` 9개 (augment.py, holdem.py 신규 포함) |
| CLI | `cli/main.py` — 2~4인 자동 모드 동작 |

### 1.2 STANDARD 진입 이유

Alpha 완료 보고서 §5(미완성 항목)와 POC 검증 보고서 §7(개선 과제)에서 총 9개 후속 작업이 STANDARD 이연 항목으로 확정됐다. 이 항목들은 세 가지 범주로 분류된다.

- **버그**: 판타지랜드 보드 리셋 오류(I3), HP 음수 처리 미구현(I6)
- **미통합 핵심 기능**: 판타지랜드 13장 드로우 UI, 샵 시스템 플레이어 연동(I2), 별 강화 자동 호출 검증(I5)
- **UX 개선**: CLI 인코딩 오류, 증강체 선택 CLI UI(I4), low_card_power 이벤트 효과
- **확장**: 8인 멀티플레이어 매칭(I1)

### 1.3 STANDARD 목표

Alpha에서 검증된 시스템 위에 게임 루프를 완성하고, 식별된 버그를 제거하며, 핵심 UX를 플레이어에게 노출하는 것이 목표다.

---

## 2. 요구사항 목록

### S1. 판타지랜드 13장 드로우 + CLI 인터페이스

**기반**: Alpha A4에서 진입 판정 플래그(`in_fantasyland`, `fantasyland_next`)만 구현됨. 실제 13장 드로우 및 선택 UI 미구현.

**요구사항**:

- `game.py:start_prep_phase()` — `in_fantasyland=True` 플레이어에게 공유 풀에서 13장 드로우
- 플레이어는 13장 중 필요 카드(최대 13장)를 보드에 배치하고 나머지 반환
- `cli/main.py` — 판타지랜드 모드 진입 시 전용 배치 UI 출력 (13장 목록 + 배치 선택 프롬프트)
- 판타지랜드 중 Front 스리카인드 이상 달성 → `fantasyland_next=True` (유지 조건 자동 판정)

**영향 파일**: `src/game.py`, `cli/main.py`

---

### S2. CLI Windows 인코딩 수정

**기반**: Alpha 보고서 §4 — "'--' 문자 깨짐, utf-8 강제" LOW 우선순위로 이연됨.

**요구사항**:

- `cli/main.py` 최상단에 `sys.stdout.reconfigure(encoding='utf-8')` 또는 `io.TextIOWrapper` 적용
- Windows cp949 환경에서 `--`, `×`, `♠♥♦♣` 등 특수 문자 정상 출력 확인
- `--auto` 모드에서 UnicodeEncodeError 발생하지 않을 것

**영향 파일**: `cli/main.py`

---

### S3. 증강체 선택 CLI UI

**기반**: `src/augment.py` + `AugmentPool.offer_augments()`는 구현됐으나 CLI 선택 메뉴가 없어 자동 선택만 동작함(Alpha §5).

**요구사항**:

- 라운드 2/4 종료 시 `AugmentPool.offer_augments(3)` 호출 → 3종 증강체 목록 출력
- 플레이어가 번호(1~3)를 입력하면 `Player.add_augment()` 실행
- `--auto` 모드에서는 첫 번째 증강체 자동 선택 (기존 동작 유지)
- 이미 보유한 증강체는 중복 제공되지 않도록 `has_augment()` 검사

**영향 파일**: `cli/main.py`, `src/game.py`

---

### S4. low_card_power 이벤트 전투 효과 구현

**기반**: `src/holdem.py:PILOT_EVENTS`에 `low_card_power` 이벤트가 정의됐으나 `src/combat.py`에 전투 효과가 적용되지 않음(Alpha §5).

**요구사항**:

- `CombatResolver.resolve()` 내 이벤트 처리 블록에 `low_card_power` 케이스 추가
- 이 이벤트 활성 시 타이브레이커 3단계(최고 랭크 비교)에서 낮은 랭크가 우선하도록 역전
- `suit_bonus_spade`, `scoop_bonus` 처리 방식과 동일한 패턴으로 구현

**영향 파일**: `src/combat.py`, `tests/test_combat.py`

---

### S5. 8인 멀티플레이어 확장

**기반**: Alpha A5에서 3~4인 매칭 구현 완료. 5~8인은 STANDARD 이연(alpha.prd.md §3 Won't Have).

**요구사항**:

- `src/game.py:generate_matchups()` — 5~8인 매칭 쌍 생성 지원
  - N=5: 2쌍 전투 + 바이 1명
  - N=6: 3쌍 동시 전투
  - N=7: 3쌍 전투 + 바이 1명
  - N=8: 4쌍 동시 전투
- 3연속 같은 상대 금지 규칙 5~8인에도 동일 적용
- 바이 횟수 공정 분배 (`_get_bye_counts`/`_record_bye`) 5~8인 확장
- `cli/main.py` — 플레이어 수 선택 프롬프트 2~8인으로 확장

**영향 파일**: `src/game.py`, `cli/main.py`, `tests/test_game.py`

---

### S6. 판타지랜드 보드 리셋 버그 수정

**기반**: POC 검증 보고서 §7.1 I3 — `game.py:166` 라운드 종료 시 판타지랜드 진입 플레이어의 보드도 초기화됨. HIGH 우선순위 버그.

**요구사항**:

- `game.py:end_round()` 보드 리셋 로직에서 `player.in_fantasyland=True`인 플레이어 제외
- 판타지랜드 유지 조건(`fantasyland_next=True`) 플레이어도 보드 리셋 제외
- 판타지랜드 탈출 후(조건 미충족) 해당 라운드 종료 시 정상 리셋
- 회귀 테스트 추가 (`tests/test_game.py`)

**영향 파일**: `src/game.py`, `tests/test_game.py`

---

### S7. HP 음수 처리 및 탈락 판정

**기반**: POC 검증 보고서 §7.3 I6 — `economy.py:Player.hp` 음수 허용. 탈락 판정 로직 부재. LOW 우선순위이나 게임 종료 조건 완성에 필수.

**요구사항**:

- `economy.py:Player.apply_damage(amount)` 메서드 추가 — `self.hp = max(0, self.hp - amount)`
- `game.py:RoundManager` — 전투 후 `hp <= 0` 플레이어를 `eliminated` 상태로 전환
- `GameState.players` 에서 탈락 플레이어 제거 (또는 `is_alive` 플래그 관리)
- 게임 종료 조건: 생존 플레이어 1명만 남으면 게임 종료 및 우승자 출력
- `cli/main.py` — 탈락 플레이어 제거 메시지 출력

**영향 파일**: `src/economy.py`, `src/game.py`, `cli/main.py`, `tests/test_economy.py`, `tests/test_game.py`

---

### S8. 별 강화 자동 호출 검증 및 보장

**기반**: POC 검증 보고서 §7.2 I5 — `try_star_upgrade()` 카드 구매 시 자동 호출 여부 CLI 흐름에서 명확히 검증 필요. MEDIUM 우선순위.

**요구사항**:

- `economy.py:Player.buy_card()` 실행 후 즉시 `try_star_upgrade()` 자동 호출 확인
- 미호출 상태이면 `buy_card()` 내부에 `try_star_upgrade()` 호출 삽입
- 별 강화 발생 시 CLI 출력 메시지 추가 ("★ {카드명} 2성 합성 완료!")
- `tests/test_economy.py` — 3장 구매 후 2성 자동 합성 E2E 테스트 추가

**영향 파일**: `src/economy.py`, `cli/main.py`, `tests/test_economy.py`

---

### S9. 샵 시스템 플레이어 연동

**기반**: POC 검증 보고서 §7.1 I2 — `Shop` 클래스와 `Player.buy_card()`/`sell_card()` 연결 미완성. `pool.random_draw_n()` level 파라미터가 prep 페이즈에 실제 연동되지 않음. HIGH 우선순위.

**요구사항**:

- `game.py:start_prep_phase()` — 각 플레이어 `level`을 기반으로 `pool.random_draw_n(5, player.level)` 호출 → 상점 카드 5장 제공
- `Player.shop_cards: list[Card]` 필드 추가 — 현재 라운드 상점 드로우 결과 저장
- `cli/main.py` — prep 페이즈에서 상점 카드 목록 출력 + 구매/패스 선택 UI
- 구매 시 `Player.buy_card()` → `pool` 차감 연동
- 판매 시 `Player.sell_card()` → `pool` 반환 연동
- `--auto` 모드: 상점 카드 중 보드 미배치 슬롯이 있으면 첫 카드 자동 구매

**영향 파일**: `src/game.py`, `src/economy.py`, `cli/main.py`, `tests/test_game.py`

---

## 3. 기능 범위

### Must Have (STANDARD 필수 구현)

| 요구사항 | 이유 |
|---------|------|
| S6. 판타지랜드 보드 리셋 버그 | 명확한 로직 오류. 방치 시 판타지랜드 시스템 전체 신뢰도 훼손 |
| S7. HP 음수 처리 및 탈락 판정 | 게임 종료 조건 없이 무한 루프 가능. 게임 루프 완성 필수 |
| S8. 별 강화 자동 호출 보장 | 핵심 경제 기능. 검증 실패 시 수정 + 테스트 보강 필요 |
| S9. 샵 시스템 플레이어 연동 | 경제-전투 루프의 핵심. 드롭률 가중치(A1)가 실제로 작동하는 유일한 경로 |
| S1. 판타지랜드 13장 드로우 | Alpha에서 플래그만 구현됨. OFC 3라인 핵심 보상 미완성 상태 |

### Should Have (구현 권장)

| 요구사항 | 이유 |
|---------|------|
| S3. 증강체 선택 CLI UI | 모듈 구현됨, CLI 연결만 필요. 플레이어 전략 경험 완성 |
| S4. low_card_power 이벤트 효과 | 5종 이벤트 중 1종 미구현. 홀덤 이벤트 시스템 완성도 |
| S2. CLI 인코딩 수정 | Windows 환경 사용성 직결. 수정 범위 매우 한정적 |

### Won't Have (STANDARD 제외)

| 항목 | 제외 이유 | 다음 단계 |
|------|---------|---------|
| Gold/Prismatic 증강체 | Silver 검증 선행. 증강체 밸런스 데이터 축적 필요 | RELEASE |
| 홀덤 이벤트 전체 30종 확장 | 파일럿 5종 완성 후 확장 | RELEASE |
| 네트워크 멀티플레이어 | CLI 기반 유지. 아키텍처 전환 필요 | POST-RELEASE |
| 아이템 파츠 조합 시스템 | PRD §12.4. 증강체와 우선순위 충돌 | POST-RELEASE |
| S5. 8인 멀티플레이어 | Should Have 수준. Must Have 완료 후 여유 시 구현 | RELEASE 또는 STANDARD+ |

---

## 4. 비기능 요구사항

### 4.1 테스트 커버리지

| 항목 | 기준 |
|------|------|
| 기존 261개 테스트 | 전체 유지 (리그레션 없음) |
| 신규 테스트 커버리지 | 신규/수정 코드 80% 이상 |
| TDD 원칙 | Red → Green → Refactor 순서 준수 |

**테스트 파일별 예상 추가 케이스 수**:

| 파일 | 현재 | 추가 예상 | 비고 |
|------|------|---------|------|
| `tests/test_game.py` | 33개 | +12개+ | S6 보드리셋, S9 샵연동, S5 8인 매칭 |
| `tests/test_economy.py` | 26개 | +8개+ | S7 HP/탈락, S8 별강화 E2E |
| `tests/test_combat.py` | 32개 | +4개+ | S4 low_card_power |
| `tests/test_board.py` | 36개 | +2개+ | S1 판타지랜드 유지 조건 |

**STANDARD 완료 기준**: `pytest tests/ -v` 전체 PASS (기존 261개 + 신규 26개+ = 287개+)

### 4.2 코드 품질

| 항목 | 기준 |
|------|------|
| 린트 | `ruff check src/ --fix` PASS |
| 타입 힌트 | 신규 public 함수 전체 type annotation 필수 |
| 모듈 크기 | 신규 파일 200줄 이하 권장 |

### 4.3 성능

| 항목 | 기준 |
|------|------|
| 단일 라운드 처리 | 100ms 이내 (8인 전투 포함) |
| 8인 1게임 시뮬레이션 | 크래시 없이 완료 (`--auto` 모드) |

---

## 5. 제약사항

### 5.1 아키텍처 제약

| 항목 | 제약 |
|------|------|
| 기반 레이어 구조 | `card → pool → hand → board → combat → game → cli` 유지 |
| 의존성 방향 | 하위 모듈이 상위 모듈 import 금지 |
| CLI 기반 유지 | STANDARD는 GUI/웹 전환 없이 `cli/main.py` 확장 |
| 신규 모듈 위치 | `src/` 디렉토리 내부 |

### 5.2 기술 제약

| 항목 | 제약 |
|------|------|
| Python 버전 | 3.11+ |
| 외부 의존성 | 표준 라이브러리 + 기존 dev 의존성만 (신규 패키지 추가 금지) |
| 패키지 구조 | `pip install -e ".[dev]"` 정상 동작 유지 |

### 5.3 게임 설계 제약

| 항목 | 제약 |
|------|------|
| 이자 공식 | `min(gold // 10, 5)` 기본 공식 유지 (economist 증강체 상한 변경만 허용) |
| 훌라 조건 | `winner_lines >= 2 AND synergies >= 3` 기존 조건 유지 |
| Foul 패널티 | `-1 핸드 등급` 유지 (PRD §6.3) |
| 카드 풀 구조 | PRD §4.5.1 등급별 복사본 수 유지 |

---

## 6. 우선순위

### 6.1 구현 우선순위

| 순위 | ID | 요구사항 | 분류 | 이유 |
|------|-----|---------|------|------|
| **P1** | S6 | 판타지랜드 보드 리셋 버그 | 버그 | `game.py:166` 명확한 로직 오류, 수정 범위 한정적 |
| **P1** | S8 | 별 강화 자동 호출 검증 | 버그/검증 | 핵심 경제 루프 신뢰도. 호출 여부 확인 후 즉시 수정 |
| **P1** | S7 | HP 음수 처리 및 탈락 판정 | 버그 | 게임 종료 조건 부재. 무한 루프 위험 |
| **P2** | S1 | 판타지랜드 13장 드로우 | 핵심 기능 | Alpha 플래그 구현의 실질적 완성. OFC 핵심 보상 |
| **P2** | S9 | 샵 시스템 플레이어 연동 | 핵심 기능 | 드롭률 가중치(A1)와 경제 시스템의 실제 연동 경로 |
| **P3** | S2 | CLI 인코딩 수정 | UX | 수정 범위 극소. Windows 사용성 필수 |
| **P3** | S3 | 증강체 선택 CLI UI | UX | 모듈 구현됨, CLI 연결만 필요 |
| **P3** | S4 | low_card_power 이벤트 효과 | UX | 기존 이벤트 처리 패턴 재사용. 구현 공수 낮음 |
| **P4** | S5 | 8인 멀티플레이어 확장 | 확장 | 3~4인 구조 재사용. 여유 시 구현 |

### 6.2 의존성 그래프

```
S6 (보드 리셋 버그) ─── 독립 수정
S8 (별강화 검증)   ─── 독립 수정/보강
S7 (HP/탈락)      ─── 독립 수정
     |
     └─ S9 (샵 연동) ─── Player.apply_damage() 필요
           |
           └─ S1 (FL 13장 드로우) ─── prep_phase 공유 (병렬 가능)

S2 (인코딩) ──── 독립 (단일 파일 수정)
S3 (증강체 UI) ─ S9 prep_phase 완성 후 권장
S4 (low_card_power) ─ 독립 (combat.py 이벤트 블록 추가)
S5 (8인 매칭) ─── S7 탈락 판정 완성 후 착수
```

P1 항목(S6, S8, S7)은 병렬 구현 가능. S9와 S1은 `game.py:start_prep_phase()` 공유 구간이므로 S7 완료 후 순차 진행 권장.

---

## 7. 구현 단계

### Phase STANDARD-1: P1 버그 수정 (블로킹 제거)

**목표**: S6 + S8 + S7 완료 — 게임 루프 안정화

| 작업 | 파일 | 내용 |
|------|------|------|
| FL 보드 리셋 조건 추가 | `src/game.py` | `end_round()` — `in_fantasyland` 플레이어 리셋 제외 |
| 별강화 자동 호출 확인/삽입 | `src/economy.py` | `buy_card()` 후 `try_star_upgrade()` 보장 |
| 별강화 CLI 메시지 | `cli/main.py` | 합성 발생 시 출력 추가 |
| `apply_damage()` 추가 | `src/economy.py` | `max(0, self.hp - amount)` |
| 탈락 판정 로직 | `src/game.py` | `hp <= 0` → eliminated 전환 + 게임 종료 조건 |
| 탈락 메시지 출력 | `cli/main.py` | 탈락 선언 + 우승자 출력 |
| 회귀 테스트 추가 | `tests/test_game.py`, `tests/test_economy.py` | S6/S7/S8 각 케이스 |

### Phase STANDARD-2: P2 핵심 기능 완성

**목표**: S1 + S9 완료 — 게임 루프 완성

| 작업 | 파일 | 내용 |
|------|------|------|
| `Player.shop_cards` 필드 | `src/economy.py` | 현재 라운드 상점 카드 저장 |
| 샵 드로우 연동 | `src/game.py` | `start_prep_phase()` — `pool.random_draw_n(5, player.level)` |
| 구매/판매 pool 연동 | `src/economy.py`, `src/game.py` | `buy_card()` pool 차감, `sell_card()` pool 반환 |
| 샵 CLI UI | `cli/main.py` | 상점 목록 출력 + 구매/패스 프롬프트 |
| FL 13장 드로우 | `src/game.py` | `start_prep_phase()` — FL 플레이어 13장 드로우 분기 |
| FL 배치 CLI UI | `cli/main.py` | FL 전용 13장 목록 + 배치 선택 화면 |
| FL 유지 조건 자동 판정 | `src/game.py` | `end_round()` — Front 스리카인드+ → `fantasyland_next=True` |
| 통합 테스트 | `tests/test_game.py` | 샵 구매 → 별강화 → 전투 E2E |

### Phase STANDARD-3: P3 UX 개선 + P4 확장

**목표**: S2 + S3 + S4 완료 (+ 여유 시 S5)

| 작업 | 파일 | 내용 |
|------|------|------|
| stdout UTF-8 강제 | `cli/main.py` | `sys.stdout.reconfigure(encoding='utf-8')` |
| 증강체 선택 프롬프트 | `cli/main.py` | 라운드 2/4 종료 시 3종 선택 UI |
| auto 모드 증강체 자동 선택 | `cli/main.py` | 첫 번째 증강체 자동 선택 유지 |
| low_card_power 전투 효과 | `src/combat.py` | 이벤트 블록 — 최고 랭크 비교 역전 |
| 이벤트 효과 테스트 | `tests/test_combat.py` | low_card_power 활성/비활성 케이스 |
| 8인 매칭 확장 (S5) | `src/game.py`, `cli/main.py` | N=5~8 generate_matchups() + 바이 공정 분배 |
| 8인 매칭 테스트 (S5) | `tests/test_game.py` | 5~8인 매칭 쌍 생성 검증 |

### 7.1 완료 기준 체크리스트

```
STANDARD 완료 조건:
[ ] pytest tests/ -v → 287개+ 전체 PASS (기존 261 + 신규 26+)
[ ] ruff check src/ --fix → PASS
[ ] python cli/main.py --auto → 4인 1게임 크래시 없이 완료 (탈락 → 우승자 출력)
[ ] S6: FL 진입 플레이어 라운드 종료 후 보드 유지 확인
[ ] S7: HP 0 이하 플레이어 탈락 처리 + 우승자 선언 동작 확인
[ ] S8: 3장 구매 후 자동 별강화 합성 + CLI 메시지 출력 확인
[ ] S9: prep 페이즈에서 상점 드로우 → 구매 → pool 차감 흐름 동작 확인
[ ] S1: FL 플레이어 prep 페이즈에서 13장 드로우 분기 동작 확인
[ ] S2: Windows 환경 --auto 실행 시 UnicodeEncodeError 없음
[ ] S3: 라운드 2/4 종료 시 증강체 선택 UI 출력 (--auto 외)
[ ] S4: low_card_power 활성 시 최고 랭크 타이브레이커 역전 확인
```
