class_name HUD
extends CanvasLayer

## HUD 오버레이 — 전투 결과 팝업 및 게임 오버 패널
## GameScene에서 add_child()로 붙여 사용

signal close_requested
signal return_to_main_requested

@onready var combat_result_panel: PanelContainer = $CombatResultPanel
@onready var result_label: RichTextLabel = $CombatResultPanel/VBoxContainer/ResultLabel
@onready var close_button: Button = $CombatResultPanel/VBoxContainer/CloseButton

@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var winner_label: Label = $GameOverPanel/VBoxContainer/WinnerLabel
@onready var return_button: Button = $GameOverPanel/VBoxContainer/ReturnButton

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	return_button.pressed.connect(_on_return_pressed)

func show_combat_result(result: Dictionary) -> void:
	## 전투 결과 팝업 표시
	var lines_won: int = result.get("lines_won", 0)
	var lines_lost: int = result.get("lines_lost", 0)
	var damage: int = result.get("damage", 0)
	var scoop: bool = result.get("scoop", false)
	var hula: bool = result.get("hula", false)

	var msg = "승리 라인: [b]%d[/b]  /  패배 라인: [b]%d[/b]\n\n" % [lines_won, lines_lost]

	if scoop:
		msg += "[color=gold][b][스쿠프! 3:0 완승][/b][/color]\n"
	if hula:
		msg += "[color=cyan][훌라 선언 가능! x4 배수][/color]\n"

	if lines_won > lines_lost:
		msg += "[color=lime]플레이어 승리![/color]\n"
	elif lines_lost > lines_won:
		msg += "[color=red]AI 승리...[/color]\n"
	else:
		msg += "[color=gray]무승부[/color]\n"

	msg += "\n데미지: %d" % damage

	result_label.text = msg
	combat_result_panel.visible = true

func hide_combat_result() -> void:
	combat_result_panel.visible = false

func show_game_over(player_won: bool) -> void:
	## 게임 오버 팝업 표시
	if player_won:
		winner_label.text = "플레이어 승리!"
	else:
		winner_label.text = "AI 승리... 패배"
	game_over_panel.visible = true

func _on_close_pressed() -> void:
	hide_combat_result()
	emit_signal("close_requested")

func _on_return_pressed() -> void:
	emit_signal("return_to_main_requested")
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
