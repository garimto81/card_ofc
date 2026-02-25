class_name CardNode
extends Panel

## 카드 시각 노드
## 카드 데이터를 받아 라벨로 표시, 클릭 이벤트 발생

signal card_clicked(card_node: CardNode)

var card_data: Card
var is_in_bench: bool = true
var line_name: String = ""
var slot_index: int = -1

@onready var rank_label: Label = $VBoxContainer/RankLabel
@onready var suit_label: Label = $VBoxContainer/SuitLabel
@onready var stars_label: Label = $VBoxContainer/StarsLabel

func setup(c: Card) -> void:
	card_data = c
	_update_display()

func _update_display() -> void:
	if not card_data:
		return
	if rank_label:
		rank_label.text = card_data.rank_name()
	if suit_label:
		suit_label.text = card_data.suit_symbol()
	if stars_label:
		stars_label.text = "★".repeat(card_data.stars)
	if card_data.is_red():
		modulate = Color(1.0, 0.85, 0.85)
	else:
		modulate = Color(0.85, 0.85, 1.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			emit_signal("card_clicked", self)
