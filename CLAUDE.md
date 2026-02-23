# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## 프로젝트 개요

**Trump Card Auto Chess** — 52장 트럼프 덱 × TFT 경제 시스템 × OFC 3라인 핸드 배치 전략을 결합한 8인 PvP 카드 오토체스 게임.

- **PRD**: `docs/01-plan/card-autochess.prd.md` (v3.0, 1,438줄)
- **기술 설계**: `docs/02-design/poc.design.md`
- **현재 단계**: POC 구현 완료 (src/ + cli/ + tests/ 작성됨), QA & 검증 단계

---

## 빌드/테스트 명령

```bash
# 의존성 설치 (dev 포함)
pip install -e ".[dev]"

# 전체 테스트
pytest

# 개별 파일 테스트
pytest tests/test_hand.py -v
pytest tests/test_combat.py -v

# 린트
ruff check src/ --fix

# POC CLI 실행 (대화형)
python cli/main.py

# POC CLI 자동 모드 (Enter 없이 전체 진행)
python cli/main.py --auto
```

---

## 코드 아키텍처

### 레이어 구조

```
cli/main.py          ← 사용자 입출력, 게임 루프, 데모 보드 설정
     |
src/game.py          ← GameState, RoundManager (라운드/페이즈 관리)
src/combat.py        ← CombatResolver (3라인 전투 판정, 훌라, 데미지)
     |
src/board.py         ← OFCBoard (Front/Mid/Back 배치, Foul 감지)
src/hand.py          ← evaluate_hand(), compare_hands() (핸드 판정)
src/economy.py       ← Player (골드, 이자, 연승/연패, 별 강화)
src/card.py          ← Card, Rank, Suit (기반 도메인 모델)
src/pool.py          ← SharedCardPool (카드 풀 관리, 레벨별 드롭률)
```

### 모듈별 책임

| 모듈 | 핵심 클래스/함수 | 설명 |
|------|-----------------|------|
| `card.py` | `Card`, `Rank`, `Suit` | 수트 순환 우위: `(defender.suit % 4) + 1 == attacker.suit` |
| `hand.py` | `evaluate_hand()`, `compare_hands()` | Front(3장) = 스트레이트/플러시 불가. 비교: 핸드강도 → 강화카드수 → 수트우위 → 최고랭크 |
| `board.py` | `OFCBoard`, `FoulResult` | Back≥Mid≥Front 위반 감지. Foul 라인은 HandType -1 강등 |
| `economy.py` | `Player` | 이자=min(gold//10, 5), 연승/연패 보너스(2연=+1, 3~4연=+2, 5+연=+3) |
| `pool.py` | `SharedCardPool` | 52종 × 등급별 복사본. `random_draw_n(n, level)` = 레벨 기반 가중치 드로우 |
| `combat.py` | `CombatResolver` | Foul 적용 후 3라인 비교. 스쿠프(3:0)+2 추가. 훌라=winner≥2 + synergy≥3 → ×4 |
| `game.py` | `GameState`, `RoundManager` | 페이즈: prep→combat→result→prep. 라운드 종료 시 보드 리셋 |

---

## 핵심 게임 메커니즘 (구현 참조)

| 메커니즘 | 설명 |
|----------|------|
| **카드 시스템** | 52장 덱, 랭크 2~A (A=최강), 수트 ♠♥♦♣ |
| **OFC 3라인 배치** | Back(5칸) ≥ Mid(5칸) ≥ Front(3칸) 강도 유지 의무, 위반 시 Foul 패널티 |
| **TFT 경제** | 라운드당 기본 5골드 + 이자(10골드마다 +1, 최대 5) |
| **별 강화** | 같은 rank+suit+stars 3장 → stars+1 합성 (최대 3성). `economy.py:try_star_upgrade()` |
| **포커 핸드 판정** | 표준 포커 핸드 강도 → 강화 카드 수 → 수트 순환 우위(♠>♥>♦>♣>♠) |
| **훌라 배수** | 승리 라인 ≥ 2 + 수트 시너지 ≥ 3 → 데미지 ×4 선언 가능 |
| **카드 비용** | rank 2~5=1골드, 6~8=2골드, 9~J=3골드, Q~K=4골드, A=5골드 |

---

## 개발 단계 순서

```
Phase 1 (완료): PRD 작성 → docs/01-plan/card-autochess.prd.md ✅
Phase 2 (완료): 기술 설계 → docs/02-design/poc.design.md ✅
Phase 3 (완료): TDD 테스트 작성 → tests/ ✅
Phase 4 (완료): POC 구현 → src/ + cli/ ✅
Phase 5 (진행): QA & 검증
```

---

## 개발 규칙

- **언어**: 한글 출력, 기술 용어는 영어 유지
- **TDD**: 테스트 먼저 작성 (Red → Green → Refactor)
- **경로**: 절대 경로만 사용

---

## 문서 구조

PRD 주요 섹션 참조:
- 게임 루프 → §3 (핵심 게임 루프 & 라운드 구조)
- 카드 규칙 → §4 (카드 시스템), 풀 구조 → §4.5.1
- 경제 시스템 → §5 (골드/이자/연승연패)
- 전투 판정 → §7 (핸드 비교 규칙, Foul 패널티)
- 샵 드롭률 → §10.6 (레벨별 코스트 확률 테이블)
- UI/UX → §12 (UI/UX 사양)
