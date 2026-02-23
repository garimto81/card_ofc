# STANDARD 단계 구현 계획서

**버전**: 1.0.0
**작성일**: 2026-02-23
**기반**: standard.prd.md v1.0 + alpha.design.md v1.0
**작성자**: planner

---

## 목차

1. [작업 개요 — S1~S9 요구사항별 코드 상태 vs 변경 명세](#1-작업-개요)
2. [구현 순서 — 3 Phase 의존성 체인](#2-구현-순서)
3. [파일별 변경 명세](#3-파일별-변경-명세)
4. [TDD 테스트 계획](#4-tdd-테스트-계획)
5. [위험 요소](#5-위험-요소)
6. [완료 기준](#6-완료-기준)

---

## 1. 작업 개요

### 1.1 현재 코드베이스 상태 (Alpha 완료 기준)

| 파일 | 라인 수 | 상태 요약 |
|------|---------|---------|
| `src/game.py` | 186줄 | GameState, RoundManager, generate_matchups(2~4인) 구현 |
| `src/economy.py` | 110줄 | Player, buy_card, sell_card, try_star_upgrade 구현 |
| `src/combat.py` | 192줄 | CombatResolver, count_synergies, 스톱×8 구현 |
| `src/board.py` | 126줄 | OFCBoard, check_fantasyland 구현 |
| `cli/main.py` | 204줄 | 2인 로컬 대전 CLI, --auto 모드 지원 |

### 1.2 S1~S9 요구사항별 현황

#### S1. 판타지랜드 13장 드로우 + CLI

| 항목 | 현재 상태 | 필요 변경 |
|------|---------|---------|
| `Player.in_fantasyland` 필드 | 구현 완료 (`economy.py:21`) | 없음 |
| `player.fantasyland_next` 전환 | `game.py:160-164` 구현 완료 | 없음 |
| 13장 드로우 분기 | **미구현** — `start_prep_phase()`에 분기 없음 | `game.py:start_prep_phase()` FL 분기 추가 |
| 나머지 카드 풀 반환 | **미구현** | `game.py:start_prep_phase()` 반환 로직 추가 |
| FL 배치 CLI UI | **미구현** | `cli/main.py` 전용 화면 추가 |
| FL 유지 조건 자동 판정 | **미구현** — `end_round()`에 Front 스리카인드 체크 없음 | `game.py:end_round()` 유지 조건 추가 |

**Alpha 코드 주석 근거**: `alpha.design.md:§5.6` — "13장 드로우/반환 인터랙션은 STANDARD 단계에서 구현"

#### S2. CLI Windows 인코딩 수정

| 항목 | 현재 상태 | 필요 변경 |
|------|---------|---------|
| `cli/main.py` 인코딩 설정 | **없음** — 파일 상단에 stdout 재설정 코드 없음 | `sys.stdout.reconfigure(encoding='utf-8')` 추가 |

**현재 위험**: `cli/main.py:1`에 인코딩 설정 없음. Windows cp949 환경에서 `--`, `×`, `♠♥♦♣` 깨짐.

#### S3. 증강체 선택 CLI UI

| 항목 | 현재 상태 | 필요 변경 |
|------|---------|---------|
| `AugmentPool.offer_augments()` | `game.py:_offer_augments()` 자동 선택만 구현 (`game.py:181-185`) | CLI 선택 메뉴 노출 필요 |
| 라운드 2/4 종료 시 UI 출력 | **미구현** | `cli/main.py` — 증강체 선택 프롬프트 추가 |
| `--auto` 자동 선택 | `game.py:185` 자동 선택 구현 완료 | `cli/main.py`에서 조건 분기만 추가 |

**Alpha 코드 근거**: `game.py:181` — "_offer_augments: Alpha 범위: 자동 선택"

#### S4. low_card_power 이벤트 전투 효과

| 항목 | 현재 상태 | 필요 변경 |
|------|---------|---------|
| `low_card_power` HoldemEvent 정의 | `holdem.py:PILOT_EVENTS`에 정의 완료 | 없음 |
| `combat.py` 이벤트 처리 블록 | `scoop_bonus`, `suit_bonus_spade`, `foul_amnesty` 구현. **`low_card_power` 누락** | `combat.py:resolve()` 이벤트 블록 추가 |
| 타이브레이커 역전 로직 | **미구현** | `compare_hands()` 또는 `resolve()` 내 역전 처리 |

**Alpha 코드 근거**: `alpha.design.md:§4.5` — "low_card_power 이벤트: Alpha 범위 외 (STANDARD 이연)"

#### S5. 8인 멀티플레이어 확장

| 항목 | 현재 상태 | 필요 변경 |
|------|---------|---------|
| `generate_matchups()` | 2~4인 지원 (`game.py:133-150`). N>4 시 `ValueError` 발생 | 5~8인 분기 추가 |
| 바이 처리 | `_get_bye_counts()`, `_record_bye()` 구현 완료 | 5~8인 공정 바이 분배 확장 |
| `cli/main.py` 플레이어 수 선택 | 2~4인 범위 — 현재 코드 미존재 (고정 2인) | 2~8인으로 확장 |

**현재 코드**: `game.py:150` — `raise ValueError("Alpha 지원 플레이어 수: 2~4. 현재: {n}")`

#### S6. 판타지랜드 보드 리셋 버그

| 항목 | 현재 상태 | 필요 변경 |
|------|---------|---------|
| `end_round()` 보드 리셋 | `game.py:158-166` — **판타지랜드 플레이어도 무조건 리셋** | `in_fantasyland=True` 조건 분기 추가 |

**버그 코드 확인** (`game.py:157-166`):
```
for player in self.state.players:
    if player.fantasyland_next:
        player.in_fantasyland = True
        player.fantasyland_next = False
    else:
        player.in_fantasyland = False
    # 버그: FL 진입 플레이어도 무조건 리셋됨
    player.board = OFCBoard()   # ← S6 버그 라인
```

**수정 방향**: `in_fantasyland=True`가 된 플레이어(방금 전환된 플레이어)는 보드 리셋 제외.

#### S7. HP 음수 처리 및 탈락 판정

| 항목 | 현재 상태 | 필요 변경 |
|------|---------|---------|
| `Player.apply_damage()` | **미구현** | `economy.py` 메서드 추가 |
| HP 음수 허용 여부 | `game.py:61-62` — `players[1].hp -= result_a.damage` 직접 차감, 음수 허용 | `apply_damage()` 사용으로 변경 |
| 탈락 판정 로직 | `game.py:173` — `[p for p in ... if p.hp > 0]` 로 탈락 처리 | 탈락 직후 출력 메시지 필요 |
| 게임 종료 조건 | `game.py:21-26` `is_game_over()` 구현 완료 | `cli/main.py` 우승자 선언 확인 |

**현재 탈락 처리**: `end_round()` 마지막에 hp>0 필터링. **전투 직후 탈락 처리가 없음** — S7은 전투 시점 탈락 감지 + CLI 메시지 요구.

#### S8. 별 강화 자동 호출 검증 및 보장

| 항목 | 현재 상태 | 필요 변경 |
|------|---------|---------|
| `try_star_upgrade()` 구현 | `economy.py:89-109` 구현 완료 | 없음 |
| `buy_card()` 내 자동 호출 | `economy.py:69-77` — **`try_star_upgrade()` 호출 없음** | `buy_card()` 후 자동 호출 삽입 |
| 별 강화 CLI 메시지 | **없음** | `cli/main.py` 메시지 추가 |

**버그 코드** (`economy.py:69-77`):
```python
def buy_card(self, card, pool):
    if not self.can_buy(card): return False
    if not pool.draw(card.rank, card.suit): return False
    self.gold -= card.cost
    self.bench.append(card)
    return True   # ← try_star_upgrade() 미호출
```

#### S9. 샵 시스템 플레이어 연동

| 항목 | 현재 상태 | 필요 변경 |
|------|---------|---------|
| `Player.shop_cards` 필드 | **없음** | `economy.py:Player` 필드 추가 |
| `start_prep_phase()` 드로우 | `game.py:43-48` — 골드 지급만, 상점 드로우 없음 | `pool.random_draw_n(5, player.level)` 연동 |
| 샵 CLI UI | **없음** | `cli/main.py` 상점 출력 + 구매/패스 프롬프트 |
| `buy_card()` pool 차감 | `economy.py:73` — `pool.draw()` 호출 완료 | 없음 (구현됨) |
| `sell_card()` pool 반환 | `economy.py:86` — `pool.return_card()` 호출 완료 | 없음 (구현됨) |

---

## 2. 구현 순서

### Phase 의존성 체인 개요

```
  STANDARD-1 (P1 버그 수정)
  +-----------+   +-----------+   +-----------+
  | S6 FL     |   | S8 별강화  |   | S7 HP/    |
  | 보드리셋  |   | 자동호출  |   | 탈락판정  |
  | 버그수정  |   | 검증/보장 |   | 구현      |
  +-----+-----+   +-----+-----+   +-----+-----+
        |               |               |
        v               v               v
  [독립 수정]     [독립 수정]       [필수 선행]
                                        |
                  +---------------------+
                  |
                  v
  STANDARD-2 (P2 핵심 기능)
  +-----------+              +-----------+
  | S9 샵     |              | S1 FL     |
  | 시스템    |<-- S7 전제  | 13장 드로우|
  | 연동      |              | + CLI UI  |
  +-----+-----+              +-----+-----+
        |                          |
        +----------+---------------+
                   |
                   v
  [game.py:start_prep_phase() 공유 구간 — 순차 진행 필수]

                   |
                   v
  STANDARD-3 (P3 UX + P4 확장)
  +-----------+   +-----------+   +-----------+   +-----------+
  | S2 CLI    |   | S3 증강체  |   | S4 low_   |   | S5 8인   |
  | 인코딩    |   | 선택 UI   |   | card_power|   | 매칭 확장 |
  +-----+-----+   +-----+-----+   +-----+-----+   +-----+-----+
  [독립]          [S9 완료 권장] [독립]            [S7 완료 후]
```

### STANDARD-1: P1 버그 수정 (블로킹 제거)

**목표**: 게임 루프 안정화. S6, S8, S7 완료.
**병렬 처리 가능**: S6, S8은 독립적으로 동시 수정 가능.

| 순서 | 작업 | 파일 | 세부 내용 |
|------|------|------|---------|
| 1-A | S6 FL 보드 리셋 버그 수정 | `src/game.py` | `end_round()` — `in_fantasyland=True` 플레이어 보드 리셋 제외 |
| 1-B | S8 `buy_card()` 별강화 자동 호출 | `src/economy.py` | `buy_card()` 반환 전 `try_star_upgrade()` 호출 삽입 |
| 1-C | S7 `apply_damage()` 메서드 추가 | `src/economy.py` | `max(0, self.hp - amount)` 구현 |
| 1-D | S7 탈락 판정 + 멀티플레이어 전투 연결 | `src/game.py` | `start_combat_phase()` 완전 재구현 — `generate_matchups()` 연동 + HP 차감 후 탈락 감지 |
| 1-E | S8 별강화 CLI 메시지 | `cli/main.py` | 합성 발생 시 "★ 2성 합성 완료!" 출력 |
| 1-F | S7 탈락 메시지 | `cli/main.py` | 탈락 선언 + 우승자 출력 |
| 1-G | 회귀 테스트 | `tests/test_game.py`, `tests/test_economy.py` | S6/S7/S8 각 케이스 |

### STANDARD-2: P2 핵심 기능 완성

**목표**: 게임 루프 완성. S9, S1 완료.
**선행 조건**: STANDARD-1 전체 완료 필수.

| 순서 | 작업 | 파일 | 세부 내용 |
|------|------|------|---------|
| 2-A | S9 `Player.shop_cards` 필드 추가 | `src/economy.py` | `shop_cards: list = field(default_factory=list)` |
| 2-B | S9 `start_prep_phase()` 드로우 연동 | `src/game.py` | `pool.random_draw_n(5 or 6, player.level)` → `player.shop_cards` |
| 2-C | S9 샵 CLI UI | `cli/main.py` | 상점 카드 목록 출력 + 구매/패스 프롬프트 |
| 2-D | S1 FL 13장 드로우 분기 | `src/game.py` | `start_prep_phase()` — `in_fantasyland=True` 시 13장 드로우 |
| 2-E | S1 FL 배치 CLI UI | `cli/main.py` | 13장 목록 + 배치 선택 화면 |
| 2-F | S1 FL 유지 조건 자동 판정 | `src/game.py` | `end_round()` — Front THREE_OF_A_KIND+ → `fantasyland_next=True` |
| 2-G | 통합 테스트 | `tests/test_game.py` | 샵 구매 → 별강화 → 전투 E2E |

### STANDARD-3: P3 UX 개선 + P4 확장

**목표**: S2, S3, S4 완료 (+ 여유 시 S5).
**선행 조건**: STANDARD-1 완료. S3은 S9 완료 권장.

| 순서 | 작업 | 파일 | 세부 내용 |
|------|------|------|---------|
| 3-A | S2 stdout UTF-8 강제 | `cli/main.py` | `sys.stdout.reconfigure(encoding='utf-8')` 최상단 |
| 3-B | S3 증강체 선택 프롬프트 | `cli/main.py` | 라운드 2/4 종료 시 3종 선택 UI |
| 3-C | S3 `--auto` 자동 선택 유지 | `cli/main.py` | 자동 모드 분기 확인 |
| 3-D | S4 `low_card_power` 전투 효과 | `src/combat.py` | 이벤트 블록 — 최고 랭크 비교 역전 |
| 3-E | S4 이벤트 효과 테스트 | `tests/test_combat.py` | low_card_power 활성/비활성 케이스 |
| 3-F | S5 8인 매칭 확장 (선택) | `src/game.py`, `cli/main.py` | N=5~8 `generate_matchups()` + 바이 공정 분배 |
| 3-G | S5 8인 매칭 테스트 (선택) | `tests/test_game.py` | 5~8인 매칭 쌍 생성 검증 |

---

## 3. 파일별 변경 명세

### 3.1 `src/economy.py`

**현재**: 110줄

#### 변경 1 — S7: `apply_damage()` 메서드 추가

- **위치**: `sell_card()` 메서드 직후 (약 line 88)
- **내용**:
  ```
  def apply_damage(self, amount: int) -> None:
      """HP 차감. 음수 방지 (최소 0)."""
      self.hp = max(0, self.hp - amount)
  ```
- **수용 기준**: `hp=5, apply_damage(10)` → `hp==0` 검증

#### 변경 2 — S8: `buy_card()` 후 `try_star_upgrade()` 자동 호출

- **위치**: `economy.py:77` — `return True` 직전
- **변경 전**:
  ```python
  self.bench.append(card)
  return True
  ```
- **변경 후**:
  ```python
  self.bench.append(card)
  self.try_star_upgrade()  # 3장 조건 자동 확인
  return True
  ```
- **수용 기준**: 같은 카드 3회 구매 후 `len(bench)==1` + `bench[0].stars==2`

#### 변경 3 — S9: `Player.shop_cards` 필드 추가

- **위치**: `Player` dataclass 필드 선언부 (line 22 부근)
- **내용**:
  ```
  shop_cards: list = field(default_factory=list)  # 현재 라운드 상점 드로우 결과
  ```
- **수용 기준**: `Player(name="P")` 생성 후 `shop_cards == []`

### 3.2 `src/game.py`

**현재**: 186줄

#### 변경 1 — S6: `end_round()` FL 보드 리셋 제외

- **위치**: `game.py:158-166`
- **변경 전**:
  ```python
  for player in self.state.players:
      if player.fantasyland_next:
          player.in_fantasyland = True
          player.fantasyland_next = False
      else:
          player.in_fantasyland = False
      player.board = OFCBoard()  # 무조건 리셋
  ```
- **변경 후**:
  ```python
  for player in self.state.players:
      if player.fantasyland_next:
          player.in_fantasyland = True
          player.fantasyland_next = False
      else:
          player.in_fantasyland = False
      # 판타지랜드 진입/유지 플레이어는 보드 리셋 제외
      if not player.in_fantasyland:
          player.board = OFCBoard()
  ```
- **수용 기준**: FL 진입 플레이어 `end_round()` 후 `board != OFCBoard()` (비어있지 않음)

#### 변경 2 — S1/S6: `end_round()` FL 유지 조건 자동 판정

- **위치**: `game.py:end_round()` — 판타지랜드 전환 블록 내
- **내용**: FL 중인 플레이어 Front THREE_OF_A_KIND+ 달성 시 `fantasyland_next=True` 설정
  ```
  # FL 유지 조건: 판타지랜드 중 Front 스리카인드 이상
  if player.in_fantasyland and player.board.front:
      from src.hand import evaluate_hand, HandType
      front_hand = evaluate_hand(player.board.front)
      if front_hand.hand_type >= HandType.THREE_OF_A_KIND:
          player.fantasyland_next = True
  ```
- **수용 기준**: FL 중 Front THREE_OF_A_KIND 배치 → `fantasyland_next==True`

#### 변경 3 — S9: `start_prep_phase()` 샵 드로우 연동

- **위치**: `game.py:43-48` — 골드 지급 후
- **변경 전**: 골드 지급만
- **변경 후**:
  ```python
  # 상점 드로우 (lucky_shop 증강체 시 6장)
  shop_size = 6 if player.has_augment("lucky_shop") else 5
  player.shop_cards = self.state.pool.random_draw_n(shop_size, player.level)
  ```
- **수용 기준**: `start_prep_phase()` 후 각 플레이어 `len(shop_cards) == 5`

#### 변경 4 — S1: `start_prep_phase()` FL 13장 드로우 분기

- **위치**: `game.py:43` — 준비 단계 시작 시
- **내용**:
  ```python
  if player.in_fantasyland:
      # FL 플레이어: 공유 풀에서 13장 드로우
      player.shop_cards = self.state.pool.random_draw_n(13, player.level)
  else:
      shop_size = 6 if player.has_augment("lucky_shop") else 5
      player.shop_cards = self.state.pool.random_draw_n(shop_size, player.level)
  ```
- **수용 기준**: `in_fantasyland=True` 플레이어 → `len(shop_cards) == 13`

#### 변경 4-B — S1: `_return_unplaced_cards()` 헬퍼 추가 및 FL 미배치 카드 반환

- **방식**: "배치 완료 후 즉시 반환" 채택 — CLI FL 배치 UI 루프 종료 시점에 처리
- **위치**: `game.py` — `start_prep_phase()` 또는 별도 헬퍼 함수로 분리
- **내용**:
  ```python
  def _return_unplaced_cards(self, player) -> None:
      """FL 배치 완료 후 보드에 배치되지 않은 카드를 풀로 반환."""
      placed = (
          list(player.board.front)
          + list(player.board.mid)
          + list(player.board.back)
      )
      placed_set = set(id(c) for c in placed)
      for card in player.shop_cards:
          if id(card) not in placed_set:
              self.state.pool.return_card(card)
      player.shop_cards = []
  ```
- **호출 시점**: `cli/main.py` FL 배치 루프 종료 직후 → `manager._return_unplaced_cards(player)` 호출
- **수용 기준**: "FL 13장 드로우 후 미배치 카드가 pool로 완전 반환됨 — 8인 전체 FL 드로우 시 pool 고갈 없음"

#### 변경 5 — S5: `generate_matchups()` 5~8인 확장 + `_pick_pairs_n_players()` 신설

- **위치**: `game.py:133-150` — `generate_matchups()` 내
- **변경 전**: N>4 시 `ValueError`
- **변경 후**: N=5 (2쌍+바이1), N=6 (3쌍), N=7 (3쌍+바이1), N=8 (4쌍) 분기 추가
- **재설계 사유**: 기존 `_pick_pairs_avoid_repeat()`은 `len(remaining) == 2` 고정 분기로 4인 전용 로직. 5~8인에서 동작 불가.
- **신설 함수**: `_pick_pairs_n_players(active, history)` — 기존 `_pick_pairs_avoid_repeat()` 대체
  ```
  짝수 인원 → N//2 쌍 생성
  홀수 인원 → match_history 기반 바이 1명 선정 → 나머지 N-1명으로 (N-1)//2 쌍 생성
  3연속 동일 상대 금지 → match_history 필터링 유지
  ```
- **수용 기준**: `generate_matchups()` N=5~8 각각 정상 쌍 반환, 3연속 동일 상대 없음

#### 변경 6 — S5/S7: `start_combat_phase()` 완전 재구현 — `generate_matchups()` 연결

- **위치**: `src/game.py:50-81` — `start_combat_phase()` 전체
- **현재 문제**: `len(players) == 2` 고정 분기로만 동작. `generate_matchups()` 미호출.
- **재구현 내용**:
  ```
  1. active_players = hp > 0인 플레이어 목록
  2. matchups = self.generate_matchups(active_players, self.state.match_history)
  3. for (p1, p2) in matchups:
       result = CombatResolver.resolve(p1.board, p2.board, events=...)
       p1.apply_damage(result.damage_to_p1)
       p2.apply_damage(result.damage_to_p2)
       # 탈락 즉시 감지
       if p1.hp == 0: <탈락 처리>
       if p2.hp == 0: <탈락 처리>
  4. bye_player (바이 대상): 전투 없이 라운드 통과 — 기본 골드 수령만
  ```
- **바이 처리**: `generate_matchups()` 반환값에서 바이 플레이어를 별도 추출 또는 `matchups` 외 나머지 active_players로 판별
- **영향 파일**: `src/game.py` — `start_combat_phase()` 단독 변경
- **수용 기준**: N=2~8 모든 인원에서 `start_combat_phase()` 호출 시 올바른 쌍 전투 + 바이 처리 완료

### 3.3 `src/combat.py`

**현재**: 192줄

#### 변경 1 — S4: `low_card_power` 이벤트 처리 블록

- **위치**: `game.py:resolve()` — `suit_bonus_spade` 처리 블록 이후 (약 line 119)
- **내용**: 이벤트 활성 시 `compare_hands()` 타이브레이커 3단계(최고 랭크)를 역전시키는 플래그 전달
- **구현 방식**: `resolve()` 내 라인별 비교 루프에서 `low_card_power` 활성 시 비교 결과 역전 적용
  ```python
  low_card_power_active = (
      events is not None
      and any(getattr(e, 'id', None) == "low_card_power" for e in events)
  )
  ```
  각 라인 비교 시:
  ```python
  cmp = compare_hands(h_a, h_b, reverse_rank=low_card_power_active)
  ```
  또는 `resolve()` 후처리 단계에서 동점 라인만 역전.
- **수용 기준**: `low_card_power` 활성 + 타이브레이커 상황 → 낮은 랭크 우선 승리

> **구현 전략 결정 필요**: `compare_hands()`에 `reverse_rank` 파라미터를 추가하거나, `resolve()` 내부에서 타이브레이커 로직을 직접 재구현. 기존 `compare_hands()` 시그니처 변경이 필요하면 `hand.py` 수정 범위 확대.

### 3.4 `cli/main.py`

**현재**: 204줄

#### 변경 1 — S2: stdout UTF-8 강제

- **위치**: `cli/main.py` 최상단 (import 전)
- **내용**:
  ```python
  import sys
  import io
  if hasattr(sys.stdout, 'reconfigure'):
      sys.stdout.reconfigure(encoding='utf-8')
  else:
      sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
  ```
- **수용 기준**: Windows cp949 환경 `--auto` 실행 시 `UnicodeEncodeError` 없음

#### 변경 2 — S3: 증강체 선택 프롬프트

- **위치**: `run_poc_game()` 내 `manager.end_round()` 호출 후
- **내용**: 라운드 2/4 종료 후 `auto_mode=False` 시 선택 메뉴 출력, `auto_mode=True` 시 자동 선택 유지
- **수용 기준**: 라운드 2/4 후 증강체 3종 목록 출력 + 번호 입력 → `player.augments`에 추가됨

#### 변경 3 — S9: 상점 UI

- **위치**: `run_poc_game()` — prep 단계 보드 설정 전
- **내용**: `player.shop_cards` 출력 + `--auto` 모드 시 첫 카드 자동 구매
- **수용 기준**: prep 단계에서 상점 카드 5장 목록 출력 확인

#### 변경 4 — S1: FL 배치 UI

- **위치**: `run_poc_game()` — FL 플레이어 prep 단계 분기
- **내용**: `in_fantasyland=True` 플레이어 → 13장 목록 + 배치 선택 화면
- **수용 기준**: FL 플레이어 prep 단계에서 13장 목록 출력 + 배치 후 나머지 반환 확인

#### 변경 5 — S7: 탈락 메시지 + 우승자 선언

- **위치**: `run_poc_game()` — 라운드 종료 후
- **내용**: 탈락 플레이어 감지 → "플레이어 X 탈락!" 출력 + 1명 생존 시 우승자 선언
- **수용 기준**: HP 0 플레이어 탈락 선언 메시지 출력 확인

#### 변경 6 — S8: 별강화 메시지

- **위치**: `run_poc_game()` — 구매 처리 후
- **내용**: `buy_card()` 반환값 확인 후 `try_star_upgrade()` 결과 메시지 출력
- **참고**: `buy_card()` 내부에서 `try_star_upgrade()` 자동 호출(S8 economy.py 변경)이 완료되면 CLI는 결과 메시지만 출력
- **수용 기준**: 3장 구매 후 "★ {카드명} 2성 합성 완료!" 메시지 출력

---

## 4. TDD 테스트 계획

### 4.1 테스트 파일별 추가 케이스 (총 26개+)

#### `tests/test_game.py` — 12개+ 추가 (현재 33개)

| # | 클래스/함수명 | 검증 내용 | 입력 | 기대값 |
|---|-------------|---------|------|------|
| 1 | `TestFantasylandReset::test_fl_player_board_not_reset` | S6: FL 진입 플레이어 보드 리셋 제외 | `player.in_fantasyland=True` → `end_round()` | `player.board != OFCBoard()` (기존 배치 유지) |
| 2 | `TestFantasylandReset::test_non_fl_player_board_reset` | S6: 일반 플레이어 보드 정상 리셋 | `player.in_fantasyland=False` → `end_round()` | `player.board == OFCBoard()` |
| 3 | `TestFantasylandReset::test_fl_exit_board_reset` | S6: FL 탈출 후 다음 라운드 정상 리셋 | FL 탈출 후 `end_round()` | 보드 리셋됨 |
| 4 | `TestFantasylandKeep::test_fl_keep_condition_three_of_a_kind` | S1: Front 스리카인드 → FL 유지 | Front THREE_OF_A_KIND 배치 + `end_round()` | `fantasyland_next==True` |
| 5 | `TestFantasylandKeep::test_fl_keep_condition_not_met` | S1: Front 하이카드 → FL 유지 안 됨 | Front HIGH_CARD + `end_round()` | `fantasyland_next==False` |
| 6 | `TestShopDraw::test_prep_phase_shop_draw_5_cards` | S9: prep 후 상점 5장 드로우 | `start_prep_phase()` | `len(player.shop_cards) == 5` |
| 7 | `TestShopDraw::test_lucky_shop_draw_6_cards` | S9: lucky_shop 증강체 → 6장 드로우 | `player.has_augment("lucky_shop")` + prep | `len(player.shop_cards) == 6` |
| 8 | `TestShopDraw::test_fl_player_draws_13_cards` | S1: FL 플레이어 → 13장 드로우 | `player.in_fantasyland=True` + prep | `len(player.shop_cards) == 13` |
| 9 | `TestElimination::test_hp_zero_eliminated_end_round` | S7: HP 0 → 라운드 종료 후 탈락 처리 | HP=0 플레이어 + `end_round()` | `len(state.players) == 1` (또는 is_alive 플래그) |
| 10 | `TestElimination::test_game_over_one_survivor` | S7: 1명 생존 → `is_game_over()==True` | HP=0 상태 후 `is_game_over()` | `True` |
| 11 | `TestMatchups5to8::test_5player_matchup` | S5: 5인 → 2쌍 + 바이 1명 | N=5 `generate_matchups()` | `len(pairs) == 2` |
| 12 | `TestMatchups5to8::test_6player_matchup` | S5: 6인 → 3쌍 | N=6 `generate_matchups()` | `len(pairs) == 3` |

#### `tests/test_economy.py` — 8개+ 추가 (현재 26개)

| # | 클래스/함수명 | 검증 내용 | 입력 | 기대값 |
|---|-------------|---------|------|------|
| 1 | `TestApplyDamage::test_apply_damage_normal` | S7: 정상 데미지 적용 | `hp=100, apply_damage(30)` | `hp==70` |
| 2 | `TestApplyDamage::test_apply_damage_zero_floor` | S7: 음수 방지 | `hp=5, apply_damage(10)` | `hp==0` |
| 3 | `TestApplyDamage::test_apply_damage_zero` | S7: 0 데미지 | `hp=50, apply_damage(0)` | `hp==50` |
| 4 | `TestStarUpgradeAuto::test_buy_3_same_card_auto_upgrade` | S8: 3장 구매 → 자동 2성 합성 | 같은 카드 3회 `buy_card()` | `bench[0].stars==2`, `len(bench)==1` |
| 5 | `TestStarUpgradeAuto::test_buy_2_same_card_no_upgrade` | S8: 2장만 → 합성 없음 | 같은 카드 2회 `buy_card()` | `len(bench)==2`, `bench[0].stars==1` |
| 6 | `TestStarUpgradeAuto::test_buy_returns_upgraded_card` | S8: 합성 후 반환값 확인 | 3장 구매 후 bench 확인 | `bench[0].stars == 2` |
| 7 | `TestShopCards::test_shop_cards_default_empty` | S9: 초기 `shop_cards` 빈 리스트 | `Player(name="P")` | `player.shop_cards == []` |
| 8 | `TestShopCards::test_shop_cards_assignable` | S9: `shop_cards` 할당 가능 | `player.shop_cards = [card]` | `len(player.shop_cards) == 1` |

#### `tests/test_combat.py` — 4개+ 추가 (현재 32개)

| # | 클래스/함수명 | 검증 내용 | 입력 | 기대값 |
|---|-------------|---------|------|------|
| 1 | `TestLowCardPower::test_low_card_power_inactive_normal` | S4: 이벤트 없을 때 정상 비교 | `events=[]` + 동점 상황 | 높은 랭크 우선 |
| 2 | `TestLowCardPower::test_low_card_power_active_reversal` | S4: 이벤트 활성 시 역전 | `events=[low_card_power]` + 동점 상황 | 낮은 랭크 우선 |
| 3 | `TestLowCardPower::test_low_card_power_no_effect_different_hand_type` | S4: 핸드 강도 차이 있을 때 역전 없음 | `events=[low_card_power]` + 핸드 강도 차이 | 강한 핸드 승리 (역전 없음) |
| 4 | `TestLowCardPower::test_low_card_power_tiebreak_only` | S4: 타이브레이커 3단계만 역전 | `events=[low_card_power]` + 핸드타입/강화수 동일 + 랭크 차이 | 낮은 랭크 우선 |

#### `tests/test_board.py` — 2개+ 추가 (현재 36개)

| # | 클래스/함수명 | 검증 내용 | 입력 | 기대값 |
|---|-------------|---------|------|------|
| 1 | `TestFantasylandKeepCondition::test_front_three_of_a_kind_triggers_keep` | S1: Front 스리카인드 → FL 유지 조건 | Front THREE_OF_A_KIND | `check_fantasyland(board) == True` |
| 2 | `TestFantasylandKeepCondition::test_front_one_pair_queen_triggers_enter` | S1: FL 진입 조건(QQ+) 확인 | Front QQ 페어 | `check_fantasyland(board) == True` |

### 4.2 TDD 실행 순서

```
  Red 단계 (테스트 먼저 작성)
  +--------------------------------------------+
  | 1. test_game.py: S6/S7/S8/S9/S1 케이스 작성 |
  | 2. test_economy.py: S7/S8/S9 케이스 작성     |
  | 3. test_combat.py: S4 케이스 작성            |
  | 4. test_board.py: S1 유지 조건 케이스 작성   |
  +--------------------------------------------+
                      |
                      v
  Green 단계 (최소 구현으로 통과)
  +--------------------------------------------+
  | STANDARD-1 구현 → pytest STANDARD-1 PASS    |
  | STANDARD-2 구현 → pytest STANDARD-2 PASS    |
  | STANDARD-3 구현 → pytest STANDARD-3 PASS    |
  +--------------------------------------------+
                      |
                      v
  Refactor 단계
  +--------------------------------------------+
  | ruff check src/ --fix → PASS               |
  | 전체 pytest 287개+ PASS 확인                |
  +--------------------------------------------+
```

---

## 5. 위험 요소

### R1. S1(FL 13장 드로우)과 S9(샵 시스템) — `game.py:start_prep_phase()` 충돌

**위험 수준**: HIGH

**충돌 구조**:
```
  start_prep_phase() 현재
  |
  +-- 골드 지급 (line 46-48)
  |
  [미구현: S9 샵 드로우 추가 예정]
  [미구현: S1 FL 분기 추가 예정]
```

S9와 S1 모두 `start_prep_phase()` 내 `player` 루프에서 `pool.random_draw_n()`을 호출한다. 동시 수정 시:
- FL 플레이어가 13장을 드로우한 뒤 일반 상점 드로우 5장을 추가 드로우하는 **이중 드로우 버그** 가능
- 풀에서 카드 수가 과도하게 차감되어 다른 플레이어 드로우 실패

**해결 방법**:
1. S9 먼저 구현 (일반 5장 상점 드로우 연동 완료)
2. S9 테스트 PASS 후 S1 FL 분기를 `if player.in_fantasyland:` 블록으로 독립 처리
3. FL 플레이어는 상점 드로우 블록을 완전히 건너뜀 (else 분기)
4. 구조 예시:
   ```python
   if player.in_fantasyland:
       player.shop_cards = pool.random_draw_n(13, player.level)
   else:
       shop_size = 6 if player.has_augment("lucky_shop") else 5
       player.shop_cards = pool.random_draw_n(shop_size, player.level)
   ```

**Edge Case 1**: FL 플레이어가 풀에서 13장 드로우 후 나머지를 반환할 때 반환 시점을 어디서 처리할지 명확히 해야 함. 배치 완료 후 즉시 반환 vs 라운드 종료 시 반환.

**Edge Case 2**: 풀 카드 수가 13장 미만일 때 (`pool.random_draw_n(13, level)` 가용 카드 부족) — `random_draw_n`이 가용 카드 수만큼만 반환하는 기존 폴백 로직으로 처리 가능하나, 테스트로 명시적 검증 필요.

### R2. S6(FL 보드 리셋) — 플래그 전환 순서 의존성

**위험 수준**: MEDIUM

**현재 코드** (`game.py:159-166`):
```python
if player.fantasyland_next:
    player.in_fantasyland = True   # 여기서 True로 변경됨
    player.fantasyland_next = False
else:
    player.in_fantasyland = False

player.board = OFCBoard()  # 이 시점에 in_fantasyland는 이미 변경됨
```

S6 수정 후 조건: `if not player.in_fantasyland: player.board = OFCBoard()`

**문제**: `in_fantasyland`가 **방금 True로 설정된 플레이어**(이번 라운드부터 FL 진입)는 보드를 유지해야 하는가?

- PRD §S1 의도: FL 진입 라운드에 13장을 새로 받으므로, 이전 보드 유지보다는 FL용 드로우로 새 보드를 구성하는 것이 맞음
- **결론**: `in_fantasyland=True` 상태인 플레이어는 보드 리셋 제외 + FL 13장 드로우로 새 배치를 시작

**Edge Case 1**: `fantasyland_next=True`인 상태에서 `end_round()`가 두 번 연속 호출되는 테스트 시나리오 — 단위 테스트로 명시 검증 필요.

**Edge Case 2**: FL 중 `check_fantasyland()` 조건 미달 → `in_fantasyland=False` + 보드 리셋 → 해당 라운드 정상 카드 드로우. 이 전환 흐름이 `end_round()` 단일 호출로 완성되는지 확인 필요.

### R3. S8(별강화 자동 호출) — `buy_card()` 반환값 의미 변경

**위험 수준**: LOW

`buy_card()` 반환값: `True` = 구매 성공, `False` = 구매 실패.
S8 수정 후 `try_star_upgrade()` 호출이 추가되어도 반환값은 그대로 유지됨. 그러나 `try_star_upgrade()` 가 `Card | None` 을 반환하므로 이를 `buy_card()` 호출부에서 활용하려면 별도 처리 필요.

**Edge Case**: 3장 구매 중 마지막 구매에서 `try_star_upgrade()` 성공 → `buy_card()` 반환은 `True`. 그러나 `bench`에서 3장이 1장(2성)으로 교체되므로, 호출부에서 `len(bench)` 변화로 합성 여부를 감지할 수 있음.

### R4. S4(`low_card_power`) — `compare_hands()` 시그니처 변경 범위

**위험 수준**: MEDIUM

`low_card_power` 효과는 "타이브레이커 3단계(최고 랭크 비교)에서 낮은 랭크가 우선"이다. 현재 `compare_hands()`는 `hand.py`에 정의되어 있으며 `reverse_rank` 파라미터가 없다.

**구현 선택지**:
1. `compare_hands(h_a, h_b, reverse_rank=False)` 파라미터 추가 → `hand.py` 수정 필요, 기존 테스트 영향 없음(기본값)
2. `resolve()` 내부에서 `low_card_power` 활성 시 `compare_hands()` 결과를 후처리로 역전 → `hand.py` 수정 없음, 로직 복잡도 증가

**권장**: 선택지 1 (명확성), 단 `hand.py` 수정 시 기존 `test_hand.py` 전체 통과 재확인 필수.

**Edge Case**: 핸드 강도가 동일하고 강화 카드 수도 동일하며 최고 랭크도 동일한 완전 동점 상황 → `low_card_power` 역전 불가. 기존 동점 처리(cmp=0) 유지.

---

## 6. 완료 기준

### 6.1 정량 완료 기준

```
  [필수]
  [ ] pytest tests/ -v
      기존 261개 PASS (리그레션 없음)
      신규 26개+ PASS
      합계 287개+ PASS

  [ ] ruff check src/ --fix → PASS (린트 에러 0)

  [ ] python cli/main.py --auto
      4인 1게임 크래시 없이 완료
      탈락 메시지 + 우승자 출력 확인
```

### 6.2 기능별 완료 기준

| ID | 요구사항 | 완료 확인 방법 |
|----|---------|-------------|
| S6 | FL 보드 리셋 버그 | `test_fl_player_board_not_reset` PASS + `--auto` FL 진입 라운드 후 보드 유지 확인 |
| S7 | HP 탈락 판정 | `test_apply_damage_zero_floor` PASS + `--auto` 탈락 메시지 출력 확인 |
| S8 | 별강화 자동 호출 | `test_buy_3_same_card_auto_upgrade` PASS + CLI 합성 메시지 출력 확인 |
| S9 | 샵 시스템 연동 | `test_prep_phase_shop_draw_5_cards` PASS + prep 단계 상점 5장 출력 확인 |
| S1 | FL 13장 드로우 | `test_fl_player_draws_13_cards` PASS + FL 플레이어 13장 목록 출력 확인 |
| S2 | CLI 인코딩 | Windows 환경 `--auto` 실행 시 UnicodeEncodeError 없음 |
| S3 | 증강체 선택 UI | 라운드 2/4 종료 시 증강체 선택 메뉴 출력 (`--auto` 외) |
| S4 | low_card_power | `test_low_card_power_active_reversal` PASS |
| S5 | 8인 매칭 (선택) | `test_5player_matchup`, `test_6player_matchup` PASS |

### 6.3 커밋 전략

**Conventional Commit 형식** 준수:

| Phase | 커밋 메시지 예시 |
|-------|--------------|
| STANDARD-1 시작 | `test(game): S6 FL 보드 리셋 버그 회귀 테스트 추가` |
| STANDARD-1 구현 | `fix(game): S6 end_round() FL 플레이어 보드 리셋 제외` |
| STANDARD-1 구현 | `fix(economy): S8 buy_card() 후 try_star_upgrade 자동 호출 추가` |
| STANDARD-1 구현 | `feat(economy): S7 Player.apply_damage() 메서드 추가` |
| STANDARD-2 시작 | `test(game): S9 샵 드로우 연동 테스트 추가` |
| STANDARD-2 구현 | `feat(economy): S9 Player.shop_cards 필드 추가` |
| STANDARD-2 구현 | `feat(game): S9 start_prep_phase() 샵 드로우 연동` |
| STANDARD-2 구현 | `feat(game): S1 FL 플레이어 13장 드로우 분기 구현` |
| STANDARD-3 시작 | `test(combat): S4 low_card_power 이벤트 테스트 추가` |
| STANDARD-3 구현 | `fix(cli): S2 Windows stdout UTF-8 강제 설정` |
| STANDARD-3 구현 | `feat(cli): S3 증강체 선택 UI 추가 (라운드 2/4)` |
| STANDARD-3 구현 | `feat(combat): S4 low_card_power 이벤트 효과 구현` |
| STANDARD-3 구현 (선택) | `feat(game): S5 5~8인 매칭 generate_matchups() 확장` |
| 최종 검증 | `test: STANDARD 287개+ PASS 최종 검증` |
