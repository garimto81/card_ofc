# 상점 레벨별 드롭률 구현 Work Plan

## 배경 (Background)

- **요청 내용**: `random_draw_n(n, level)` 메서드의 `level` 파라미터가 현재 무시됨
- **해결하려는 문제**: PRD §10.6에 정의된 레벨별 드롭 확률이 미구현 상태.
  현재 구현은 가용 카드 중 균등 무작위 샘플링(`random.sample`)만 수행함.

### 현재 코드 (버그)

  파일: `C:\claude\card_ofc\src\pool.py`, line 49-62

```
  def random_draw_n(self, n: int, level: int = 1) -> list:
      available = [
          Card(rank, suit)
          for (rank, suit), count in self._pool.items()
          if count > 0
      ]
      if not available:
          return []
      selected = random.sample(available, min(n, len(available)))  # level 미사용
      ...
```

---

## 구현 범위 (Scope)

### 포함
- `random_draw_n`에 레벨별 코스트 가중치 적용
- 레벨 → 코스트 확률 상수 테이블 정의 (모듈 상단)
- 가용 카드가 없는 코스트 티어 확률 재분배 로직
- 레벨 범위 클램핑 (1 미만 → 1, 9 초과 → 9)
- `tests/test_card.py`에 드롭률 테스트 케이스 추가

### 제외
- 상점 UI, 경제 시스템 변경 없음
- 다른 draw 메서드(`draw`, `return_card`) 변경 없음
- 코스트 티어 매핑(`Card.cost` 프로퍼티) 변경 없음 — 이미 구현됨

---

## 영향 파일 (Affected Files)

### 수정 예정
- `C:\claude\card_ofc\src\pool.py` — 드롭률 상수 추가 + `random_draw_n` 로직 교체

### 추가 테스트 케이스 (기존 파일 확장)
- `C:\claude\card_ofc\tests\test_card.py` — 드롭률 통계 검증 테스트 4건 추가

---

## 코스트 티어 매핑 (PRD §4.3)

```
  코스트 | Rank 범위 | Card.cost 값 (card.py line 40-48 기준)
  --------|-----------|--------------------------------------
  1코스트 | 2 ~ 5     | cost == 1   (rank <= 5)
  2코스트 | 6 ~ 8     | cost == 2   (rank <= 8)
  3코스트 | 9 ~ J(11) | cost == 3   (rank <= 11)
  4코스트 | Q(12)~K   | cost == 4   (rank <= 13)
  5코스트 | A(14)     | cost == 5
```

## 드롭 확률 테이블 (PRD §10.6)

```
  레벨 | 1코스트 | 2코스트 | 3코스트 | 4코스트 | 5코스트
  -----|--------|--------|--------|--------|--------
  1-2  |  75%   |  20%   |   5%   |   0%   |   0%
  3-4  |  55%   |  30%   |  15%   |   0%   |   0%
  5    |  35%   |  35%   |  25%   |   5%   |   0%
  6    |  20%   |  35%   |  30%   |  14%   |   1%
  7    |  15%   |  25%   |  35%   |  20%   |   5%
  8    |  10%   |  15%   |  35%   |  30%   |  10%
  9    |   5%   |  10%   |  25%   |  35%   |  25%
```

---

## 위험 요소 (Risks)

1. **확률 재분배 시 수치 왜곡**
   - 특정 코스트 티어 카드가 풀에서 고갈됐을 때 해당 확률을 나머지 티어에 비례 분배해야 함.
   - 단순 제거 후 합산하면 총합 < 100% 되어 `random.choices`가 오동작 가능.
   - 완료 조건: 재분배 후 weights 합이 항상 > 0 보장.

2. **레벨 1-2 통합 경계 처리**
   - PRD는 레벨 1과 2를 동일 확률로 묶음. 레벨 3과 4도 동일.
   - `_get_level_weights(level)` 헬퍼가 정확히 매핑하지 않으면 경계값(1, 2, 3, 4, 5)에서 오동작.
   - 완료 조건: 레벨 1, 2 모두 75/20/5/0/0 반환, 레벨 3, 4 모두 55/30/15/0/0 반환.

3. **풀 전체 고갈 시 무한루프 위험**
   - 모든 코스트 티어가 고갈되면 weights 합이 0 → `random.choices` 예외 발생.
   - 이미 `if not available: return []` 가드가 있으므로 선처리됨.
   - 완료 조건: 빈 풀에서 `random_draw_n` 호출 시 빈 리스트 반환 (기존 테스트 커버).

4. **통계 테스트 확률적 실패**
   - 드롭률 검증은 대수의 법칙 기반. 샘플 수가 적으면 간헐적 실패.
   - n=1000 이상 드로우 후 비율 범위(±10%)로 완화된 검증 사용.

---

## 태스크 목록 (Tasks)

### Task 1: 레벨별 가중치 상수 테이블 정의

**설명**: `pool.py` 상단에 `_LEVEL_WEIGHTS` 딕셔너리 상수 추가.

**수행 방법**:
- `pool.py` 상단 import 블록 직후 상수 정의
- key: 레벨 정수, value: 코스트 1~5 가중치 리스트 `[w1, w2, w3, w4, w5]`
- 레벨 1, 2 → 동일 항목, 레벨 3, 4 → 동일 항목 (PRD 테이블 기준)

**구조**:
```
  _LEVEL_WEIGHTS = {
    1: [75, 20,  5,  0,  0],
    2: [75, 20,  5,  0,  0],
    3: [55, 30, 15,  0,  0],
    4: [55, 30, 15,  0,  0],
    5: [35, 35, 25,  5,  0],
    6: [20, 35, 30, 14,  1],
    7: [15, 25, 35, 20,  5],
    8: [10, 15, 35, 30, 10],
    9: [ 5, 10, 25, 35, 25],
  }
```

**Acceptance Criteria**:
- 모든 레벨(1-9)이 키로 존재
- 각 레벨의 가중치 합 == 100
- 레벨 1, 2가 동일한 리스트 값 반환

---

### Task 2: `_get_cost_weight` 헬퍼 함수 추가

**설명**: 가용 카드 목록과 레벨을 받아 카드별 가중치 리스트를 반환하는 헬퍼 구현.

**수행 방법**:
- `_get_copy_count` 함수 아래 `_get_card_weights(available: list, level: int) -> list` 추가
- 로직 흐름:

```
  흐름도:

  available 카드들 → card.cost로 코스트 티어 분류
         |
         v
  레벨 → _LEVEL_WEIGHTS[clamp(level, 1, 9)] → 기본 가중치 배열
         |
         v
  각 코스트 티어별 가용 카드 수 확인
  가용 카드 0인 티어 → 해당 가중치 0으로 마스킹
         |
         v
  마스킹된 비율로 각 카드에 가중치 할당
  (티어 내 카드들은 균등 분할)
         |
         v
  weights 리스트 반환 (len == len(available))
```

- 레벨 클램핑: `level = max(1, min(9, level))`
- 재분배: 0으로 마스킹 후 `random.choices` 자체 정규화 활용 (weights 합이 양수이면 OK)

**Acceptance Criteria**:
- 반환 리스트 길이 == `len(available)`
- 레벨 1에서 cost==1 카드의 weights 합이 전체 대비 약 75%
- 풀이 비어있을 때 호출되지 않음 (caller에서 가드)

---

### Task 3: `random_draw_n` 로직 교체

**설명**: 기존 `random.sample` → `random.choices` (가중치 기반) 방식으로 교체.

**수행 방법**:
- `pool.py` line 59: `random.sample` 제거
- 가중치 계산 후 중복 없이 n장 선택하는 로직 구현

**구현 패턴**:
```
  available = [...가용 카드...]
  weights = _get_card_weights(available, level)
  selected = []
  remaining = available[:]
  remaining_w = weights[:]
  for _ in range(min(n, len(available))):
      chosen = random.choices(remaining, weights=remaining_w, k=1)[0]
      selected.append(chosen)
      idx = remaining.index(chosen)
      remaining.pop(idx)
      remaining_w.pop(idx)
```

**Acceptance Criteria**:
- 동일 카드 중복 선택 없음
- 선택된 카드 수 == `min(n, len(available))`
- 선택된 카드가 풀에서 차감됨 (기존 `draw()` 호출 유지)

---

### Task 4: 레벨 범위 테스트 추가

**설명**: 유효/무효 레벨 경계에서 오동작 없음을 검증.

**대상 파일**: `C:\claude\card_ofc\tests\test_card.py`

**테스트 케이스**:

```python
class TestRandomDrawNDropRate:
    def test_level_clamp_low(self):
        """레벨 0 → 레벨 1과 동일 동작 (예외 없음)"""
        pool = SharedCardPool(); pool.initialize()
        cards = pool.random_draw_n(5, level=0)
        assert len(cards) == 5

    def test_level_clamp_high(self):
        """레벨 10 → 레벨 9와 동일 동작 (예외 없음)"""
        pool = SharedCardPool(); pool.initialize()
        cards = pool.random_draw_n(5, level=10)
        assert len(cards) == 5

    def test_empty_pool_returns_empty(self):
        """초기화 없는 풀(빈 풀)에서 빈 리스트 반환"""
        pool = SharedCardPool()
        cards = pool.random_draw_n(5, level=1)
        assert cards == []
```

**Acceptance Criteria**:
- 레벨 0, 10 입력 시 예외 미발생
- 빈 풀 호출 시 `[]` 반환

---

### Task 5: 드롭률 통계 검증 테스트 추가

**설명**: 레벨 1과 레벨 9에서 기대 드롭률 범위를 통계적으로 검증.

**대상 파일**: `C:\claude\card_ofc\tests\test_card.py`

**테스트 케이스**:

```python
    def test_level1_low_cost_dominant(self):
        """레벨 1: 1코스트 비율 >= 60% (기대 75%, ±15% 허용)"""
        pool = SharedCardPool(); pool.initialize()
        cards = pool.random_draw_n(500, level=1)
        cost1_ratio = sum(1 for c in cards if c.cost == 1) / len(cards)
        assert cost1_ratio >= 0.60

    def test_level9_high_cost_dominant(self):
        """레벨 9: 4+5코스트 합산 >= 50% (기대 60%, ±10% 허용)"""
        pool = SharedCardPool(); pool.initialize()
        cards = pool.random_draw_n(500, level=9)
        high_cost_ratio = sum(1 for c in cards if c.cost >= 4) / len(cards)
        assert high_cost_ratio >= 0.50
```

**Acceptance Criteria**:
- 1000회 연속 실행에서 99% 이상 통과 (허용 범위 충분히 완화됨)
- 레벨 1 → cost==1 우세, 레벨 9 → cost>=4 우세 명확히 차별화

---

## 구현 흐름 다이어그램

```
  random_draw_n(n, level) 호출
           |
           v
  available = [풀에 count > 0인 카드]
           |
           +---(비어있음?)---> return []
           |
           v
  level = clamp(level, 1, 9)
           |
           v
  base_weights = _LEVEL_WEIGHTS[level]   # [w1, w2, w3, w4, w5]
           |
           v
  각 카드에 가중치 할당:
    card.cost==1 → base_weights[0] / (cost1 카드 수)
    card.cost==2 → base_weights[1] / (cost2 카드 수)
    ...
    가용 카드 없는 코스트 → 해당 가중치 0 (자동 제외)
           |
           v
  n회 반복:
    random.choices(remaining, weights, k=1) → 선택
    선택 카드를 remaining에서 제거
           |
           v
  선택된 카드들 draw() 처리 → 반환
```

---

## 커밋 전략 (Commit Strategy)

### Commit 1 — 상수 + 헬퍼 함수 (Task 1, 2)
```
feat(pool): 레벨별 드롭 확률 상수 테이블 및 가중치 헬퍼 추가

PRD §10.6 기반 _LEVEL_WEIGHTS 상수 정의 (레벨 1-9).
_get_card_weights() 헬퍼로 가용 카드별 코스트 가중치 계산.
가용 카드 없는 티어는 자동 0 마스킹으로 재분배.
```

### Commit 2 — 핵심 로직 교체 (Task 3)
```
fix(pool): random_draw_n에 레벨 기반 가중치 드로우 적용

random.sample 균등 샘플링을 random.choices 가중치 방식으로 교체.
level 파라미터가 실제 드롭 확률에 반영됨 (PRD §10.6 준수).
```

### Commit 3 — 테스트 추가 (Task 4, 5)
```
test(pool): 레벨별 드롭률 검증 테스트 5건 추가

레벨 경계값 클램핑, 빈 풀 방어, 통계적 드롭률 범위 검증.
레벨 1 저코스트 우세, 레벨 9 고코스트 우세 시나리오 포함.
```
