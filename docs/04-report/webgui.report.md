# Trump Card Auto Chess — Web GUI PDCA 완료 보고서

**프로젝트**: Trump Card Auto Chess
**버전**: Web GUI v1.0
**작성일**: 2026-02-23
**PDCA 사이클**: Web GUI Phase (Phase 5 완료)
**기반**: STANDARD 완료 보고서 (293 테스트 PASS)

---

## 목차

1. [배경 및 목표](#1-배경-및-목표)
2. [구현 결과 요약](#2-구현-결과-요약)
3. [PDCA 진행 결과](#3-pdca-진행-결과)
4. [구현된 기능 (W1~W7)](#4-구현된-기능-w1w7)
5. [기술 결정 사항](#5-기술-결정-사항)
6. [알려진 제한사항](#6-알려진-제한사항)
7. [실행 방법 가이드](#7-실행-방법-가이드)
8. [결론](#8-결론)

---

## 1. 배경 및 목표

### 1.1 요청 배경

STANDARD 단계까지 구현된 Trump Card Auto Chess는 CLI 전용 인터페이스로 동작했다. 사용자는 터미널에 익숙하지 않은 플레이어도 게임을 체험할 수 있는 브라우저 기반 플레이어블 GUI 버전을 요청했다.

| CLI 한계 | 설명 |
|----------|------|
| 진입 장벽 | 터미널 환경에 익숙하지 않은 사용자는 게임 체험 불가 |
| 카드 배치 직관성 | 텍스트 입력 방식 — 클릭 기반 UX 대비 열등 |
| 시각적 피드백 부재 | 전투 결과, 핸드 강도, 보드 상태를 텍스트로만 표현 |

### 1.2 목표

기존 `src/` 백엔드 11개 모듈(293 테스트 PASS)을 **변경 없이 재사용**하면서, Flask REST API 레이어와 Vanilla JS 프론트엔드를 추가해 브라우저에서 2인 로컬 대전이 가능한 Web GUI를 구현한다.

---

## 2. 구현 결과 요약

### 2.1 핵심 지표

| 항목 | 이전 (STANDARD) | 이후 (Web GUI) |
|------|----------------|----------------|
| 전체 테스트 | 293개 PASS | **319개 PASS** |
| 신규 테스트 | - | 26개 (test_serializer 12 + test_web_api 14) |
| 신규 파일 | - | 9개 (web/ 6개 + tests/ 2개 + pyproject.toml 수정) |
| src/ 변경 | - | **0건 (변경 없음)** |
| 린트 | ruff PASS | ruff PASS |

### 2.2 신규 파일 목록

| 파일 경로 | 역할 | 구현 단계 |
|-----------|------|----------|
| `web/__init__.py` | 패키지 초기화 | T1 |
| `web/app.py` | Flask 라우터 + 게임 인스턴스 관리 | T1 |
| `web/serializer.py` | GameState → JSON 직렬화 레이어 | T1 |
| `web/static/index.html` | SPA 메인 페이지 (시작/보드/결과 화면) | T2 |
| `web/static/style.css` | 카드/보드/상점/모달 스타일 | T2 |
| `web/static/game.js` | UI 상태 기계 + API 호출 + DOM 렌더링 | T3~T5 |
| `tests/test_serializer.py` | 직렬화 단위 테스트 12개 | T1 |
| `tests/test_web_api.py` | Flask API 엔드포인트 테스트 14개 | T1 |
| `pyproject.toml` | `flask` 의존성 추가 | T1 |

### 2.3 검증 결과 요약

| 검증 항목 | 담당 | 결과 |
|----------|------|------|
| 전체 테스트 통과 | QA | PASS (319/319) |
| 린트 품질 | QA | PASS (ruff 0건) |
| API 엔드포인트 | QA | PASS (6종) |
| 아키텍처 적합성 (Phase 3.2) | Architect | **APPROVE** |
| 구현 완료 검증 (Phase 4.2) | Architect | **APPROVE** |
| 코드 품질 리뷰 | code-reviewer | **APPROVE** (CRITICAL 0건) |

---

## 3. PDCA 진행 결과

### 3.1 Phase 0.5 — PRD 작성

**산출물**: `docs/00-prd/webgui.prd.md` (605줄)

Web GUI 전환 이유, W1~W7 기능 요구사항, API 명세, 비기능 요구사항(응답 시간 <200ms, 동시 세션 1개), 제약사항(WebSocket 제외, CDN 금지)을 정의했다.

### 3.2 Phase 1 — 구현 계획 (HEAVY)

**산출물**: `docs/01-plan/webgui.plan.md`

Planner가 신규 파일 8개 목록, API 상세, GameState 직렬화 설계, Frontend 상태 기계, 카드 배치 UX, Task 분해(T1~T5), 테스트 계획을 수립했다. Architect가 `threaded=False`, `next_round` 7번째 action_type, 미구매 shop_cards 풀 반환, `remove_card` 테스트 케이스 4가지 권장사항을 제시하며 APPROVE했다. Critic도 계획의 완전성을 확인하고 APPROVE했다.

### 3.3 Phase 2 — 기술 설계 문서

**산출물**: `docs/02-design/webgui.design.md` (1,252줄)

계층 다이어그램, app.py 상세 설계(6개 엔드포인트 전체 의사코드), serializer.py 설계(Card/Board/Player/GameState 직렬화 스펙), HTML/CSS 설계(컴포넌트 레이아웃), JavaScript 설계(상태 기계 FSM), 테스트 설계를 포함했다.

### 3.4 Phase 3 — 구현 (T1~T5)

**Task 분해 및 진행:**

| Task | 내용 | 결과 |
|------|------|------|
| T1 | web/app.py + web/serializer.py + 테스트 2개 | 완료 (26 tests PASS) |
| T2 | web/static/index.html + style.css | 완료 |
| T3 | game.js — 시작/상태 렌더링 | 완료 |
| T4 | game.js — 상점/배치 인터랙션 | 완료 |
| T5 | game.js — 전투/결과/다음 라운드 | 완료 |

Architect Phase 3.2 중간 검증에서 직렬화 레이어 완전성, API 라우터 설계, Foul 패널티 노출 방식을 확인하고 **APPROVE**했다.

### 3.5 Phase 4 — QA 검증

**QA 6종 전체 PASS:**

| QA 항목 | 명령 | 결과 |
|---------|------|------|
| 전체 테스트 | `pytest` | 319 PASS (0.35s) |
| 린트 | `ruff check src/ --fix` | PASS (0건) |
| 직렬화 테스트 | `pytest tests/test_serializer.py -v` | 12 PASS |
| API 테스트 | `pytest tests/test_web_api.py -v` | 14 PASS |
| 서버 기동 확인 | `python web/app.py` | 정상 기동 |
| 브라우저 접속 | http://localhost:5000 | 정상 렌더링 |

Architect Phase 4.2 최종 검증에서 319 테스트 PASS, src/ 무결성, API 엔드포인트 완전성을 확인하고 **APPROVE**했다. code-reviewer도 CRITICAL 0건으로 **APPROVE**했다.

---

## 4. 구현된 기능 (W1~W7)

| 기능 ID | 기능명 | 설명 |
|---------|--------|------|
| W1 | 게임 시작 | 2인 게임 초기화 (`POST /api/start`) |
| W2 | 상태 조회 | 현재 GameState JSON 반환 (`GET /api/state`) |
| W3 | 상점 카드 구매 | 상점에서 카드 구매 + 핸드 추가 (`POST /api/action` + `buy_card`) |
| W4 | 카드 배치 | 핸드 → Front/Mid/Back 슬롯 배치 (`POST /api/action` + `place_card`) |
| W5 | 전투 실행 | 준비 완료 시 전투 판정 + 데미지 계산 (`POST /api/action` + `ready`) |
| W6 | 다음 라운드 | 보드 리셋 + 골드 지급 + 새 라운드 시작 (`POST /api/action` + `next_round`) |
| W7 | 게임 리셋 | 전체 상태 초기화 (`POST /api/reset`) |

### 4.1 API 엔드포인트 상세

| 엔드포인트 | 메서드 | 설명 |
|------------|--------|------|
| `/` | GET | index.html SPA 반환 |
| `/api/start` | POST | 게임 초기화 (player_count: 2) |
| `/api/state` | GET | 현재 GameState JSON 반환 |
| `/api/action` | POST | action_type + payload 처리 (buy_card/place_card/ready/next_round 등) |
| `/api/reset` | POST | 게임 상태 초기화 |
| `/static/<path>` | GET | CSS/JS 정적 파일 서빙 |

---

## 5. 기술 결정 사항

Architect 권장사항 4가지를 전부 반영했다.

| 결정 | 내용 | 이유 |
|------|------|------|
| `app.run(threaded=False)` | Flask 단일 스레드 실행 | GameState가 Thread-safe하지 않음 — 단일 세션 전제로 단순화 |
| `next_round` 7번째 action_type | `action_type="next_round"` 전용 엔드포인트 | 라운드 전환 로직 명시적 분리 |
| 미구매 shop_cards 풀 반환 | 라운드 종료 시 구매하지 않은 상점 카드를 SharedCardPool에 반납 | 카드 풀 무결성 유지 |
| `remove_card` 테스트 케이스 | test_web_api.py에 카드 제거 시나리오 포함 | 배치 후 핸드 상태 변경 검증 필요 |

**src/ 변경 없음**: 기존 11개 모듈(293 테스트)을 단 한 줄도 수정하지 않고 재사용했다. 이는 레이어 분리 설계의 유효성을 증명한다.

---

## 6. 알려진 제한사항

code-reviewer가 MINOR 4건을 식별했다. CRITICAL/MAJOR 0건으로 서비스 운영에는 지장 없다.

| 번호 | 수준 | 위치 | 내용 |
|------|------|------|------|
| M1 | MINOR | `web/static/game.js` | `innerHTML` 사용 — 서버 데이터가 안전하므로 실질적 XSS 위험 없으나, 잠재적 위험 존재 |
| M2 | MINOR | `web/static/index.html` | 4인 이상 UI 레이아웃 미구현 — 현재 2인 대전만 지원 |
| M3 | MINOR | `web/app.py` | 단일 전역 게임 인스턴스 — 멀티 세션 지원 불가 (설계 제약, 단일 세션 전제) |
| M4 | MINOR | `web/serializer.py` | Augment 직렬화 미포함 — 증강체 선택 UI가 없으므로 현재 단계에서 불필요 |

---

## 7. 실행 방법 가이드

### 7.1 의존성 설치

```bash
# Flask 포함 전체 의존성 설치
pip install flask
pip install -e ".[dev]"
```

### 7.2 서버 실행

```bash
# web/app.py 직접 실행
python C:/claude/card_ofc/web/app.py
```

서버 기동 후 브라우저에서 http://localhost:5000 접속.

### 7.3 게임 플레이 순서

```
1. 브라우저에서 http://localhost:5000 접속
2. "게임 시작" 버튼 클릭 → 2인 게임 초기화
3. 상점에서 카드 구매 (골드 소비)
4. 구매한 카드를 Front/Mid/Back 슬롯에 배치
5. "준비 완료" 버튼 클릭 → 전투 판정
6. 전투 결과 확인 후 "다음 라운드" 진행
7. 체력 0이 되면 게임 종료
```

### 7.4 테스트 실행

```bash
# 전체 테스트 (319개)
pytest

# Web GUI 관련 테스트만
pytest tests/test_serializer.py tests/test_web_api.py -v

# 린트 검사
ruff check src/ --fix
```

---

## 8. 결론

Trump Card Auto Chess Web GUI v1.0이 완료됐다.

**핵심 성과:**
- 기존 `src/` 11개 모듈을 변경 없이 재사용해 레이어 분리 원칙을 준수했다.
- 319개 테스트 전체 PASS — STANDARD 대비 26개 신규 테스트 추가로 웹 레이어 품질을 보증했다.
- Architect 2회(Phase 3.2, Phase 4.2) + code-reviewer 모두 APPROVE를 받아 품질 게이트를 통과했다.
- 브라우저만으로 2인 로컬 대전이 가능한 플레이어블 GUI 버전을 제공한다.

**다음 단계 후보:**
- M2 해결: 4인 이상 UI 레이아웃 구현
- M4 해결: 증강체 선택 UI 추가
- WebSocket 기반 실시간 멀티플레이어 확장
- 모바일 반응형 레이아웃 적용
