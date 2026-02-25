class_name BoardView
extends VBoxContainer

## 보드 뷰 컴포넌트
## Back/Mid/Front 라인과 Bench를 시각적으로 표시
## Board.tscn에 연결되는 스크립트

signal board_card_clicked(line_name: String, slot_index: int)
signal bench_card_clicked(bench_index: int)

@onready var back_line: HBoxContainer = $BackSection/BackLine
@onready var mid_line: HBoxContainer = $MidSection/MidLine
@onready var front_line: HBoxContainer = $FrontSection/FrontLine
@onready var bench_area: HBoxContainer = $BenchSection/BenchArea

var card_node_scene = preload("res://scenes/CardNode.tscn")

const LINE_MAP_KEYS = ["back", "mid", "front"]

func refresh(player_board: Dictionary, player_bench: Array) -> void:
	## 보드 + 벤치 카드 표시 갱신
	_clear(back_line)
	_clear(mid_line)
	_clear(front_line)
	_clear(bench_area)

	var line_containers: Dictionary = {
		"back": back_line,
		"mid": mid_line,
		"front": front_line
	}

	for line_name in LINE_MAP_KEYS:
		var container: HBoxContainer = line_containers[line_name]
		var cards: Array = player_board.get(line_name, [])
		for i in range(cards.size()):
			var cn: CardNode = card_node_scene.instantiate()
			container.add_child(cn)
			cn.setup(cards[i])
			cn.is_in_bench = false
			cn.line_name = line_name
			cn.slot_index = i
			cn.card_clicked.connect(_on_board_card_clicked.bind(line_name, i))

	for i in range(player_bench.size()):
		var cn: CardNode = card_node_scene.instantiate()
		bench_area.add_child(cn)
		cn.setup(player_bench[i])
		cn.is_in_bench = true
		cn.slot_index = i
		cn.card_clicked.connect(_on_bench_card_clicked.bind(i))

func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func _on_board_card_clicked(line_name: String, slot_index: int) -> void:
	emit_signal("board_card_clicked", line_name, slot_index)

func _on_bench_card_clicked(bench_index: int) -> void:
	emit_signal("bench_card_clicked", bench_index)
