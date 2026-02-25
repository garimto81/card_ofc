class_name Combat
extends RefCounted

## 3라인 전투 판정
## Python combat.py (CombatResolver) 기반 GDScript 포팅
## OFC 3라인: Back(5칸) / Mid(5칸) / Front(3칸)

## board 딕셔너리 구조:
## { "back": Array[Card], "mid": Array[Card], "front": Array[Card] }
##
## 반환 딕셔너리:
## {
##   "lines_won": int,    # 이긴 라인 수
##   "lines_lost": int,   # 진 라인 수
##   "damage": int,       # 입힌 데미지
##   "scoop": bool,       # 3:0 스쿠프 여부
##   "hula": bool,        # 훌라 조건 충족 여부
##   "line_results": Dictionary  # {back:int, mid:int, front:int} +1승/-1패/0무
## }

const LINE_NAMES = ["back", "mid", "front"]

var _evaluator: HandEvaluator

func _init() -> void:
	_evaluator = HandEvaluator.new()

func resolve(board1: Dictionary, board2: Dictionary, round_num: int = 1) -> Dictionary:
	## 두 보드의 3라인 전투 판정
	## board1 기준: 양수=board1 승, 음수=board2 승

	# Foul 판정 (Back >= Mid >= Front 위반 시)
	var b1_foul = _check_foul(board1)
	var b2_foul = _check_foul(board2)

	var line_results: Dictionary = {}

	# 각 라인별 핸드 비교
	for line_name in LINE_NAMES:
		var cards1: Array = board1.get(line_name, [])
		var cards2: Array = board2.get(line_name, [])

		var h1 = _evaluator.evaluate_hand(cards1)
		var h2 = _evaluator.evaluate_hand(cards2)

		# Foul 페널티 적용
		if b1_foul.get(line_name, false):
			h1 = _evaluator.apply_foul_penalty(h1)
		if b2_foul.get(line_name, false):
			h2 = _evaluator.apply_foul_penalty(h2)

		line_results[line_name] = _evaluator.compare_hands(h1, h2)

	# 승패 집계
	var lines_won = 0
	var lines_lost = 0
	for line_name in LINE_NAMES:
		var result = line_results.get(line_name, 0)
		if result > 0:
			lines_won += 1
		elif result < 0:
			lines_lost += 1

	# 스쿠프 보너스 (3:0 완승/완패)
	var scoop = (lines_won == 3) or (lines_lost == 3)

	# 스테이지별 기본 데미지 (라운드 기반 간소화)
	var stage_damage = _calc_stage_damage(round_num)

	# 데미지 계산: |net_lines| + 스쿠프 보너스(+2)
	var net_lines = lines_won - lines_lost
	var damage = (abs(net_lines) + (2 if scoop else 0)) * stage_damage

	# 훌라 조건 체크 (board1 기준)
	var hula = _check_hula(board1)

	return {
		"lines_won": lines_won,
		"lines_lost": lines_lost,
		"damage": damage,
		"scoop": scoop,
		"hula": hula,
		"line_results": line_results
	}

func _check_foul(board: Dictionary) -> Dictionary:
	## Back >= Mid >= Front 위반 감지
	## 위반 라인에 foul=true 표시
	var h_back = _evaluator.evaluate_hand(board.get("back", []))
	var h_mid = _evaluator.evaluate_hand(board.get("mid", []))
	var h_front = _evaluator.evaluate_hand(board.get("front", []))

	var foul = {"back": false, "mid": false, "front": false}

	# Back < Mid → mid가 foul
	if _evaluator.compare_hands(h_back, h_mid) < 0:
		foul["mid"] = true

	# Mid < Front → front가 foul
	if _evaluator.compare_hands(h_mid, h_front) < 0:
		foul["front"] = true

	return foul

func _check_hula(board: Dictionary) -> bool:
	## 훌라 조건: 같은 수트 카드 3장 이상 (간소화)
	## 실제 PRD: winner>=2 + synergy>=3 → ×4 선언 가능
	var suit_counts: Dictionary = {}
	for line_name in LINE_NAMES:
		for card in board.get(line_name, []):
			suit_counts[card.suit] = suit_counts.get(card.suit, 0) + 1
	for cnt in suit_counts.values():
		if cnt >= 3:
			return true
	return false

func _calc_stage_damage(round_num: int) -> int:
	## 라운드 기반 스테이지 데미지 계산
	## PRD §7 기준 간소화
	if round_num <= 3: return 2
	elif round_num <= 6: return 3
	elif round_num <= 9: return 4
	return 5

func check_foul_public(board: Dictionary) -> Dictionary:
	## 외부에서 Foul 체크 가능하도록 public 래퍼
	return _check_foul(board)
