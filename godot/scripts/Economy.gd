class_name Economy
extends RefCounted

## 경제 시스템
## Python economy.py (Player) 기반 GDScript 포팅
## TFT 경제: 기본골드 + 이자 + 연승/연패 보너스

# 레벨업 필요 XP 테이블 (레벨 9 = 최대)
const XP_TABLE: Dictionary = {
	1: 2, 2: 4, 3: 6, 4: 10,
	5: 20, 6: 36, 7: 56, 8: 80
}

var gold: int = 0
var level: int = 1
var xp: int = 0
var win_streak: int = 0
var loss_streak: int = 0

func calc_interest() -> int:
	## 이자 = min(floor(gold / 10), 5)
	return min(gold / 10, 5)

func streak_bonus() -> int:
	## 연승/연패 보너스: 2연=+1, 3~4연=+2, 5+연=+3
	var streak = max(win_streak, loss_streak)
	if streak >= 5: return 3
	elif streak >= 3: return 2
	elif streak >= 2: return 1
	return 0

func round_income(base: int = 5) -> int:
	## 라운드 수입: 기본 + 이자 + 연승/연패 보너스
	return base + calc_interest() + streak_bonus()

func earn_gold(amount: int) -> void:
	gold += amount

func spend_gold(amount: int) -> bool:
	## 골드 소비. 부족 시 false 반환
	if gold < amount:
		return false
	gold -= amount
	return true

func buy_xp() -> bool:
	## XP 구매: 4골드 소모, XP +4 획득, 자동 레벨업
	## 레벨 9(최대)이거나 골드 부족 시 false
	if level >= 9:
		return false
	if not spend_gold(4):
		return false
	xp += 4
	_try_level_up()
	return true

func _try_level_up() -> void:
	## XP 임계값 충족 시 자동 레벨업. 초과 XP 이월.
	while level < 9 and xp >= XP_TABLE.get(level, 999):
		xp -= XP_TABLE[level]
		level += 1

func record_win() -> void:
	win_streak += 1
	loss_streak = 0

func record_loss() -> void:
	loss_streak += 1
	win_streak = 0

func record_draw() -> void:
	win_streak = 0
	loss_streak = 0

func xp_needed() -> int:
	## 다음 레벨까지 필요한 XP
	if level >= 9:
		return 0
	return XP_TABLE.get(level, 0) - xp

func can_afford(cost: int) -> bool:
	return gold >= cost
